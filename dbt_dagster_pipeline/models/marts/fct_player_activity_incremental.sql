{#
  fct_player_activity_incremental -- same grain & logic as fct_player_activity,
  but only processes NEW rows each run. Three distinct concerns working together:

  1. WATERMARK (what to fetch): on an incremental run, pull only source rows newer
     than the max event_timestamp already loaded, minus a small lookback window so
     LATE-ARRIVING rows just behind the watermark aren't missed.

  2. DEDUP (collapse repeats): row_number() over the natural key keeps one row per
     (game, player, event_time), so re-scanned/late/duplicate rows don't multiply.

  3. MERGE/UPSERT (how to land): incremental_strategy='merge' on unique_key means a
     re-processed key REPLACES its prior row rather than appending -- idempotent.

  Partitioned + clustered like the full table; merge prunes by partition.
  Backfill: run with --full-refresh to rebuild from scratch.
#}

{{
  config(
    materialized='incremental',
    unique_key='activity_key',
    incremental_strategy='merge',
    partition_by={'field': 'event_timestamp', 'data_type': 'timestamp', 'granularity': 'day'},
    cluster_by=['game_name'],
    on_schema_change='append_new_columns'
  )
}}

with unioned as (
    select * from {{ ref('int_player_activity_unioned') }}

    {% if is_incremental() %}
    -- Only new rows, minus a lookback window for late arrivals.
    where event_timestamp > (
        select timestamp_sub(
                   coalesce(max(event_timestamp), timestamp '1900-01-01 00:00:00'),
                   interval {{ var('event_lookback_hours', 0) }} hour
               )
        from {{ this }}
    )
    {% endif %}
),

deduped as (
    select
        *,
        row_number() over (
            partition by game_name, player_key, event_timestamp
            order by load_timestamp desc
        ) as _rn
    from unioned
)

select
    {{ surrogate_key(['game_name', 'player_key', 'event_timestamp']) }} as activity_key,
    player_key,
    player_name,
    player_progress,
    player_score,
    game_name,
    event_timestamp,
    load_timestamp
from deduped
where _rn = 1
