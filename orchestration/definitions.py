"""
Dagster orchestration for the multi-tenant gaming data platform.

Asset graph (what depends on what):

    raw_game_a_events ┐
                      ├─> [ dbt: stg_* -> int_* -> fct_* ]
    raw_game_b_events ┘

The two ingestion assets land raw JSONL into BigQuery. Their asset keys are
["raw", "raw_game_a_events"] / ["raw", "raw_game_b_events"], which match the
asset keys dagster-dbt assigns to the dbt SOURCES of the same name. That name
match is what auto-wires the dependency -- dbt models run only after ingestion.

Run the UI:
    dagster dev
"""

from pathlib import Path

from dagster import (
    AssetExecutionContext,
    AssetKey,
    Definitions,
    ScheduleDefinition,
    RunRequest,
    SensorEvaluationContext,
    asset,
    define_asset_job,
    sensor,
)

from dagster_dbt import (
    DbtCliResource,
    DbtProject,
    dbt_assets,
)

from .ingest import ingest_game_a, ingest_game_b


# ---------------------------------------------------------------------------
# Paths & dbt project
# ---------------------------------------------------------------------------

ORCH_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = ORCH_DIR.parent
DBT_PROJECT_DIR = PROJECT_ROOT / "dbt_dagster_pipeline"

dbt_project = DbtProject(
    project_dir=DBT_PROJECT_DIR,
    profiles_dir=DBT_PROJECT_DIR,
)

# Generates manifest automatically during `dagster dev`
dbt_project.prepare_if_dev()


# ---------------------------------------------------------------------------
# Raw ingestion assets
# ---------------------------------------------------------------------------

@asset(
    key=AssetKey(["raw", "raw_game_a_events"]),
    compute_kind="python",
    group_name="ingestion",
)
def raw_game_a_events(context: AssetExecutionContext):
    rows = ingest_game_a()
    context.log.info(f"Landed {rows} rows into raw.raw_game_a_events")
    context.add_output_metadata({"rows": rows})


@asset(
    key=AssetKey(["raw", "raw_game_b_events"]),
    compute_kind="python",
    group_name="ingestion",
)
def raw_game_b_events(context: AssetExecutionContext):
    rows = ingest_game_b()
    context.log.info(f"Landed {rows} rows into raw.raw_game_b_events")
    context.add_output_metadata({"rows": rows})


# ---------------------------------------------------------------------------
# dbt Assets
# ---------------------------------------------------------------------------

@dbt_assets(manifest=dbt_project.manifest_path)
def gaming_dbt_assets(
    context: AssetExecutionContext,
    dbt: DbtCliResource,
):
    yield from dbt.cli(["build"], context=context).stream()


# ---------------------------------------------------------------------------
# Job
# ---------------------------------------------------------------------------

full_refresh_job = define_asset_job(
    name="gaming_platform_job",
    selection="*",
)


# ---------------------------------------------------------------------------
# Schedule
# ---------------------------------------------------------------------------

daily_schedule = ScheduleDefinition(
    name="daily_gaming_refresh",
    job=full_refresh_job,
    cron_schedule="0 6 * * *",
)


# ---------------------------------------------------------------------------
# Sensor
# ---------------------------------------------------------------------------

@sensor(
    job=full_refresh_job,
    name="raw_files_arrival_sensor",
    minimum_interval_seconds=30,
)
def raw_files_arrival_sensor(context: SensorEvaluationContext):
    raw_dir = PROJECT_ROOT / "data" / "raw"

    files = sorted(raw_dir.glob("*.jsonl"))
    if not files:
        return

    latest_mtime = max(f.stat().st_mtime for f in files)
    last_seen = float(context.cursor) if context.cursor else 0.0

    if latest_mtime > last_seen:
        context.update_cursor(str(latest_mtime))
        yield RunRequest(run_key=f"raw-{latest_mtime:.0f}")


# ---------------------------------------------------------------------------
# Definitions
# ---------------------------------------------------------------------------

defs = Definitions(
    assets=[
        raw_game_a_events,
        raw_game_b_events,
        gaming_dbt_assets,
    ],
    jobs=[
        full_refresh_job,
    ],
    schedules=[
        daily_schedule,
    ],
    sensors=[
        raw_files_arrival_sensor,
    ],
    resources={
        "dbt": DbtCliResource(
            project_dir=DBT_PROJECT_DIR,
        ),
    },
)
