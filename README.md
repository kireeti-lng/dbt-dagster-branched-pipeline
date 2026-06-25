# Multi-Tenant Gaming Data Platform — BigQuery Prototype

A proof-of-concept for ingesting events from **multiple games with different schemas**,
normalising them into one **canonical model**, and unifying them through a **single
reusable Dagster + dbt pipeline** — running on **Google BigQuery**.

This is **Phase 1** (2 games, full ingestion → staging → union → marts, incremental
loading, tests). Phases 2 (onboard a 3rd game) and 3 (schema evolution) build on this
exact structure — see *Roadmap*.

> This is the BigQuery build, targeting your `geo-play` stack directly. The dbt SQL is
> warehouse-native GoogleSQL; the marts are partitioned by event day and clustered by
> `game_name` (the shared-table, game-pruned pattern, not per-game tables).

---

## Architecture

```
                          INGESTION (Python BigQuery client / dlt-equivalent)
   data/raw/game_a_events.jsonl ──┐
                                  ├─► <prefix>raw.raw_game_a_events ─┐
   data/raw/game_b_events.jsonl ──┘   <prefix>raw.raw_game_b_events ─┘
                                                                     │
                          ▼ dbt (orchestrated by Dagster) ▼          │
                                                                     │
   <prefix>staging.stg_game_a_events  (game A schema → canonical) ◄──┤  one thin model
   <prefix>staging.stg_game_b_events  (game B schema → canonical) ◄──┘  per game
                                  │
                                  ▼  UNION ALL (identical column lists)
   <prefix>intermediate.int_player_activity_unioned
                                  │
                ┌─────────────────┴──────────────────┐
                ▼                                     ▼
   <prefix>marts.fct_player_activity      <prefix>marts.fct_player_activity_incremental
   (full rebuild, deduped,                (watermark + dedup + MERGE upsert,
    partitioned + clustered)               partitioned + clustered)
```

Each layer is a BigQuery **dataset** (namespaced by `DBT_DATASET_PREFIX`). The only
game-specific code is the per-game staging model; everything downstream is game-agnostic.

### Canonical schema

| canonical column | game A (RPG) | game B (Racing) |
|---|---|---|
| `player_key`      | `player_id` (INT→STRING) | `user_id` (STRING) |
| `player_name`     | `username`   | `display_name` |
| `player_progress` | `level`      | `rank` |
| `player_score`    | `xp`         | `score` |
| `game_name`       | `'game_a'`   | `'game_b'` |
| `event_timestamp` | `event_time` | `` `timestamp` `` (reserved word, backtick-quoted) |
| `load_timestamp`  | `current_timestamp()` | `current_timestamp()` |

---

## Data flow

1. **Generate** — `scripts/generate_sample_data.py` writes JSONL to `data/raw/`
   (63 game-A rows, 60 game-B rows; a few exact duplicates injected so dedup has work).
2. **Ingest** — `orchestration/ingest.py` loads each file verbatim into the BigQuery
   `<prefix>raw` dataset (schema autodetect), adding only `_ingested_at`. Creates the
   dataset if absent.
3. **Stage** — each `stg_*` model maps its game's fields into the canonical schema.
4. **Union** — `int_player_activity_unioned` stacks all staged games.
5. **Mart** — `fct_player_activity` dedupes to grain `(game_name, player_key,
   event_timestamp)`; `fct_player_activity_incremental` maintains it via MERGE.

---

## Setup & run

**Prerequisites:** Python 3.10+, the `gcloud` SDK, and a GCP project where you can
create datasets (e.g. `lng-geo-play`).

```bash
# 1. Install
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# 2. Authenticate (Application Default Credentials — no key files)
gcloud auth application-default login

# 3. Configure. Copy and edit, then load into the shell.
cp .env.example .env
#   set GCP_PROJECT, BQ_LOCATION (match your existing datasets' region),
#   and DBT_DATASET_PREFIX.
set -a; source .env; set +a

# 4. Run the whole pipeline (no UI)
make run        # = generate data → load to BigQuery → dbt build (models + tests)
```

Step by step:

```bash
python scripts/generate_sample_data.py                 # write raw JSONL locally
python orchestration/ingest.py                          # load into <prefix>raw.*
cd dbt_project && dbt build --profiles-dir .            # transform + test
```

**Launch the Dagster UI:**

```bash
make dagster        # dagster dev -f orchestration/definitions.py
# open http://localhost:3000 → "Materialize all"
```

**Docker (optional):** `docker compose up` (mounts your ADC; reads GCP_PROJECT etc.
from your shell/.env).

---

## Expected output (Phase 1)

After `make run`, inspect in the BigQuery console or with `bq`:

| dataset.table | rows | note |
|---|---|---|
| `<prefix>raw.raw_game_a_events` | 63 | verbatim |
| `<prefix>raw.raw_game_b_events` | 60 | verbatim |
| `<prefix>staging.stg_game_a_events` | 63 | canonicalised |
| `<prefix>staging.stg_game_b_events` | 60 | canonicalised |
| `<prefix>intermediate.int_player_activity_unioned` | 123 | stacked |
| `<prefix>marts.fct_player_activity` | **118** | 5 duplicate events collapsed |
| `<prefix>marts.fct_player_activity_incremental` | 118 | same grain |

All **25 dbt nodes pass** (5 models + 20 tests). Quick check:

```bash
bq query --use_legacy_sql=false \
  "SELECT game_name, COUNT(*) FROM \`$GCP_PROJECT.${DBT_DATASET_PREFIX}marts.fct_player_activity\` GROUP BY 1"
# game_a | 60
# game_b | 58
```

### Incremental demo

Append new events, then run **without** `--full-refresh`: only new rows MERGE in, and a
second run with no new data leaves the table unchanged (idempotent). `--full-refresh`
rebuilds from scratch (backfill).

---

## Cost & BigQuery notes

- Marts are **partitioned by `event_timestamp` (day)** and **clustered by `game_name`** —
  queries that filter by date/game prune scanned bytes. One shared table, game-pruned,
  rather than per-game tables.
- `merge` incremental strategy prunes by partition on upsert.
- This prototype scans tiny data; on real volumes the partition/cluster choices are what
  keep slot/byte cost down.
- **Cleanup:** `make drop-datasets` removes the four prefixed datasets when you're done.

---

## Testing strategy

- **Source** — `not_null` on each game's id/timestamp; **source freshness** on `_ingested_at`.
- **Staging** — `not_null` on `player_key`/`event_timestamp`; `accepted_values` pins each
  model's `game_name` literal (catches a mis-wired staging model).
- **Marts** — `unique` + `not_null` on the surrogate `activity_key` (proves dedup worked),
  `accepted_values` on `game_name`. All run inside `dbt build`.

---

## Auth options summary

| Context | Method | How |
|---|---|---|
| Local dev (recommended) | ADC / oauth | `gcloud auth application-default login` |
| Local with key | service account | set `GOOGLE_APPLICATION_CREDENTIALS=/path/key.json` |
| CI (GitHub Actions) | Workload Identity Federation (keyless) | swap the auth handshake; models unchanged |

---

## Recommended tools — needed now vs later

| Tool | Needed now? | Why / when |
|---|---|---|
| **BigQuery** | ✅ Yes | The warehouse. |
| **dbt + Dagster** | ✅ Yes | Core of the exercise. |
| **dlt** | ⬜ Soon | Production ingestion (replaces the simple loader in `ingest.py`). Matches your real `@dlt_assets` factory pattern. |
| **GCS / object store** | ⬜ Later | A real landing zone for raw files before load. JSONL-on-disk is fine for the prototype. |
| **Great Expectations / Soda** | ⬜ Later | When you need richer DQ profiling beyond dbt's pass/fail. |
| **Kafka** | ❌ No | Real-time streaming; this is micro-batch. |

---

## How this maps to production geo-play

| Prototype | Production |
|---|---|
| `ingest.py` (BigQuery client) | dlt pipeline / `@dlt_assets` + `DagsterDltResource` |
| ADC / oauth | Workload Identity Federation from GitHub Actions |
| layer datasets via `generate_schema_name` | same macro, extended with a tenant token for dataset-per-client |
| local `surrogate_key` macro | `dbt_utils.generate_surrogate_key` |
| `make run` | GitHub Actions CI (Slim CI `--defer --state`) + Dagster schedule |

The dbt SQL is the same in both.

---

## Roadmap

- **Phase 1 (this repo)** — 2 games, full pipeline, incremental MERGE, tests. ✅
- **Phase 2** — onboard game C: add one `stg_game_c_events.sql`, one source entry, one
  line in the union. No downstream changes.
- **Phase 3** — schema evolution: game A adds `region` (additive); game B renames
  `score → total_score` (handled in staging, downstream untouched); game C nested JSON
  (flatten in staging). Plus detection / impact-analysis notes.
