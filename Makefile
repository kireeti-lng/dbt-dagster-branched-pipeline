# Convenience targets. Run `make help` to list them.
# Reads GCP_PROJECT / BQ_LOCATION / DBT_DATASET_PREFIX from your environment
# (e.g. `set -a; source .env; set +a`).

.PHONY: help install auth data ingest build run dagster clean drop-datasets

help:
	@echo "make install        - install python deps"
	@echo "make auth            - log in with Application Default Credentials"
	@echo "make data            - generate sample raw data (>50 rows/game)"
	@echo "make ingest          - load raw data into BigQuery (<prefix>raw dataset)"
	@echo "make build           - run dbt build (models + tests)"
	@echo "make run             - data + ingest + dbt build (full pipeline, no UI)"
	@echo "make dagster         - launch Dagster UI at http://localhost:3000"
	@echo "make clean           - remove local dbt target artifacts"
	@echo "make drop-datasets   - DELETE the prototype BigQuery datasets (careful)"

install:
	pip install -r requirements.txt

auth:
	gcloud auth application-default login

data:
	python scripts/generate_sample_data.py

ingest:
	python orchestration/ingest.py

build:
	cd dbt_project && dbt build --profiles-dir .

run: data ingest build
	@echo "Pipeline complete. Inspect results in BigQuery (project=$$GCP_PROJECT)."

dagster:
	dagster dev -f orchestration/definitions.py

clean:
	rm -rf dbt_project/target dbt_project/dbt_packages dbt_project/logs

# Drops the four prefixed datasets. Requires the `bq` CLI (part of gcloud).
drop-datasets:
	@for layer in raw staging intermediate marts; do \
		echo "dropping $$GCP_PROJECT:$(DBT_DATASET_PREFIX)$$layer"; \
		bq rm -r -f -d "$$GCP_PROJECT:$(DBT_DATASET_PREFIX)$$layer" || true; \
	done
