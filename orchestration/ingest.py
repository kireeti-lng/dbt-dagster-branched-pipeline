"""
Raw ingestion: land source files into BigQuery, exactly as received.

Local stand-in for a dlt pipeline. No transformation -- column names/types are
whatever the game emitted (BigQuery autodetects them). Normalisation happens later
in the dbt staging layer.

Datasets: tables land in `<DBT_DATASET_PREFIX>raw` inside GCP_PROJECT. The dataset
is created if it doesn't exist. The same prefix/project are read by dbt, so both
sides agree on where data lives.

Auth: Application Default Credentials (run `gcloud auth application-default login`)
or GOOGLE_APPLICATION_CREDENTIALS.

Run standalone:  python orchestration/ingest.py
"""


import json
import os
from datetime import datetime, timezone
from pathlib import Path

from google.cloud import bigquery
from google.cloud.exceptions import NotFound



PROJECT_ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = PROJECT_ROOT / "data" / "raw"

from dotenv import load_dotenv

load_dotenv()

GCP_PROJECT = os.getenv("GCP_PROJECT")

if not GCP_PROJECT:
    raise ValueError("GCP_PROJECT environment variable is not set")
BQ_LOCATION = os.environ.get("BQ_LOCATION", "US")
DATASET_PREFIX = os.environ.get("DBT_DATASET_PREFIX", "")
RAW_DATASET = f"{DATASET_PREFIX}raw"


def _client() -> bigquery.Client:
    return bigquery.Client(project=GCP_PROJECT, location=BQ_LOCATION)


def _ensure_dataset(client: bigquery.Client) -> None:
    ds_id = f"{GCP_PROJECT}.{RAW_DATASET}"
    try:
        client.get_dataset(ds_id)
    except NotFound:
        ds = bigquery.Dataset(ds_id)
        ds.location = BQ_LOCATION
        client.create_dataset(ds)


def _load_jsonl_to_raw(client: bigquery.Client, source_file: str, table: str) -> int:
    """Load a JSONL file into raw.<table> (truncate-and-replace). Returns row count."""
    _ensure_dataset(client)
    table_id = f"{GCP_PROJECT}.{RAW_DATASET}.{table}"

    # Read rows and stamp an ingestion time (ISO8601 -> BigQuery autodetects TIMESTAMP).
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
    job.result()  # wait for completion
    return client.get_table(table_id).num_rows


def ingest_game_a() -> int:
    client = _client()
    return _load_jsonl_to_raw(client, "game_a_events.jsonl", "raw_game_a_events")


def ingest_game_b() -> int:
    client = _client()
    return _load_jsonl_to_raw(client, "game_b_events.jsonl", "raw_game_b_events")


if __name__ == "__main__":
    a = ingest_game_a()
    b = ingest_game_b()
    print(f"{RAW_DATASET}.raw_game_a_events: {a} rows")
    print(f"{RAW_DATASET}.raw_game_b_events: {b} rows")
