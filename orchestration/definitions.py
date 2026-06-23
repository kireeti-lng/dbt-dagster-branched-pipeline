"""
Dagster orchestration for the multi-tenant gaming data platform.

Asset graph (what depends on what):

    raw_game_a_events ┐
                      ├─> [ dbt: stg_* -> int_* -> fct_* ]
    raw_game_b_events ┘

The two ingestion assets land raw JSONL into DuckDB. Their asset keys are
["raw", "raw_game_a_events"] / ["raw", "raw_game_b_events"], which match the
asset keys dagster-dbt assigns to the dbt SOURCES of the same name. That name
match is what auto-wires the dependency -- dbt models run only after ingestion.

Run the UI:   dagster dev -f orchestration/definitions.py
Materialize:  click "Materialize all" in the UI, or use the daily schedule.
"""

import sys
from pathlib import Path

# Ensure this file's directory is importable regardless of how Dagster loads it
# (`dagster dev -f ...`, `dagster definitions validate -f ...`, or direct import).
sys.path.insert(0, str(Path(__file__).resolve().parent))

from dagster import (
    AssetExecutionContext,
    AssetKey,
    Definitions,
    ScheduleDefinition,
    asset,
    define_asset_job,
    sensor,
    RunRequest,
    SensorEvaluationContext,
)
from dagster_dbt import DbtCliResource, DbtProject, dbt_assets

from ingest import ingest_game_a, ingest_game_b

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
dbt_project.prepare_if_dev()  # ensures manifest exists when running `dagster dev`


# ---------------------------------------------------------------------------
# Raw ingestion assets (the dlt-equivalent in your real stack)
# Asset keys deliberately match the dbt source keys: ["raw", "<table>"].
# ---------------------------------------------------------------------------
@asset(key=AssetKey(["raw", "raw_game_a_events"]), compute_kind="python", group_name="ingestion")
def raw_game_a_events(context: AssetExecutionContext):
    rows = ingest_game_a()
    context.log.info(f"Landed {rows} rows into raw.raw_game_a_events")
    context.add_output_metadata({"rows": rows})


@asset(key=AssetKey(["raw", "raw_game_b_events"]), compute_kind="python", group_name="ingestion")
def raw_game_b_events(context: AssetExecutionContext):
    rows = ingest_game_b()
    context.log.info(f"Landed {rows} rows into raw.raw_game_b_events")
    context.add_output_metadata({"rows": rows})


# ---------------------------------------------------------------------------
# dbt assets: every model becomes a Dagster asset. `dbt build` runs models+tests.
# ---------------------------------------------------------------------------
@dbt_assets(manifest=dbt_project.manifest_path)
def gaming_dbt_assets(context: AssetExecutionContext, dbt: DbtCliResource):
    yield from dbt.cli(["build"], context=context).stream()


# ---------------------------------------------------------------------------
# Job, schedule, sensor
# ---------------------------------------------------------------------------
# One job that materializes the whole graph (ingestion + dbt).
full_refresh_job = define_asset_job(name="gaming_platform_job", selection="*")

# Daily schedule. In production you'd split ingestion vs transform cadences.
daily_schedule = ScheduleDefinition(
    name="daily_gaming_refresh",
    job=full_refresh_job,
    cron_schedule="0 6 * * *",  # 06:00 every day
)


# Optional sensor: kicks off a run when new raw files appear on disk.
# (Mtime-based here for the local demo; in prod this is a source-freshness or
#  object-store-notification sensor.)
@sensor(job=full_refresh_job, name="raw_files_arrival_sensor", minimum_interval_seconds=30)
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
# Definitions: the single object Dagster loads.
# ---------------------------------------------------------------------------
defs = Definitions(
    assets=[raw_game_a_events, raw_game_b_events, gaming_dbt_assets],
    jobs=[full_refresh_job],
    schedules=[daily_schedule],
    sensors=[raw_files_arrival_sensor],
    resources={
        "dbt": DbtCliResource(project_dir=dbt_project),
    },
)
