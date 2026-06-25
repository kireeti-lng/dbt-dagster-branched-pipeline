{#
  Deterministic dataset routing for BigQuery.

  Each layer's +schema (raw/staging/intermediate/marts) becomes a BigQuery DATASET,
  optionally prefixed via DBT_DATASET_PREFIX so prototype datasets are clearly named
  and isolated from your existing geo-play datasets.

  Default dbt behaviour would prefix with the target dataset (e.g. marts_staging);
  we use the custom name verbatim (plus the env prefix) instead.

  This is the same generate_schema_name pattern used in the real geo-play project for
  dataset-per-layer (and, extended with a tenant token, dataset-per-client) routing.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set prefix = env_var('DBT_DATASET_PREFIX', '') -%}
    {%- if custom_schema_name is none -%}
        {{ prefix }}{{ target.schema }}
    {%- else -%}
        {{ prefix }}{{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
