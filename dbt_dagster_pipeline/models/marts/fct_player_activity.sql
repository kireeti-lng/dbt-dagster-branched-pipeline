{#
  fct_player_activity -- unified, deduplicated activity fact across all games.

  Full-rebuild table, partitioned by event day and clustered by game_name. The
  cluster_by mirrors the cost-discipline pattern from geo-play: one shared table,
  game-scoped pruning instead of per-game table duplication.

  Dedup is by the natural grain (game_name + player_key + event_timestamp): if the
  same event lands twice (it does -- the generator injects duplicates), keep one.
#}

{{
  config(
    materialized='table',
    partition_by={'field': 'event_timestamp', 'data_type': 'timestamp', 'granularity': 'day'},
    cluster_by=['game_name']
  )
}}

with unioned as (
    select * from {{ ref('int_player_activity_unioned') }}
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
