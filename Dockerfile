# Optional containerised run. For local learning the native setup is simpler;
# this exists because the brief asked for it and as a bridge toward deployment.
FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .

ENV DAGSTER_HOME=/app/.dagster_home
RUN mkdir -p /app/.dagster_home

EXPOSE 3000
# GCP_PROJECT / BQ_LOCATION / DBT_DATASET_PREFIX come from the environment.
# Auth is mounted at runtime (see docker-compose.yml).
CMD ["sh", "-c", "python scripts/generate_sample_data.py && dagster dev -f orchestration/definitions.py -h 0.0.0.0 -p 3000"]
