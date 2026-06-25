import json
import os
from datetime import datetime, timezone
from pathlib import Path

from dotenv import load_dotenv
from google.cloud import bigquery
from google.cloud.exceptions import NotFound

PROJECT_ROOT = Path(__file__).resolve().parents[1]
ENV_PATH = PROJECT_ROOT / ".env"
load_dotenv(dotenv_path=ENV_PATH)

RAW_DIR = PROJECT_ROOT / "data" / "raw"

def _get_gcp_project() -> str:
    project = os.getenv("GCP_PROJECT")
    if not project:
        raise ValueError(
            f"GCP_PROJECT environment variable is not set. Checked: {ENV_PATH}"
        )
    return project

def _client() -> bigquery.Client:
    return bigquery.Client(project=_get_gcp_project(), location=os.getenv("BQ_LOCATION", "US"))

def _ensure_dataset(client: bigquery.Client) -> None:
    gcp_project = _get_gcp_project()
    dataset_prefix = os.getenv("DBT_DATASET_PREFIX", "")
    raw_dataset = f"{dataset_prefix}raw"
    ds_id = f"{gcp_project}.{raw_dataset}"
    try:
        client.get_dataset(ds_id)
    except NotFound:
        ds = bigquery.Dataset(ds_id)
        ds.location = os.getenv("BQ_LOCATION", "US")
        client.create_dataset(ds)

def _load_jsonl_to_raw(client: bigquery.Client, source_file: str, table: str) -> int:
    gcp_project = _get_gcp_project()
    dataset_prefix = os.getenv("DBT_DATASET_PREFIX", "")
    raw_dataset = f"{dataset_prefix}raw"

    _ensure_dataset(client)
    table_id = f"{gcp_project}.{raw_dataset}.{table}"

    ingested_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    rows = []
    with (RAW_DIR / source_file).open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            rec = json.loads(line)
            rec["_ingested_at"] = ingested_at
            rows.append(rec)

    job_config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.NEWLINE_DELIMITED_JSON,
        autodetect=True,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
    )
    job = client.load_table_from_json(rows, table_id, job_config=job_config)
    job.result()
    return client.get_table(table_id).num_rows



def ingest_game_a() -> int:
    client = _client()
    return _load_jsonl_to_raw(
        client,
        "game_a_events.jsonl",
        "raw_game_a_events",
    )


def ingest_game_b() -> int:
    client = _client()
    return _load_jsonl_to_raw(
        client,
        "game_b_events.jsonl",
        "raw_game_b_events",
    )


if __name__ == "__main__":
    a = ingest_game_a()
    b = ingest_game_b()

    dataset_prefix = os.getenv("DBT_DATASET_PREFIX", "")
    raw_dataset = f"{dataset_prefix}raw"

    print(f"{raw_dataset}.raw_game_a_events: {a} rows")
    print(f"{raw_dataset}.raw_game_b_events: {b} rows")