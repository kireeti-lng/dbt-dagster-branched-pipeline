{#
  Game B (Racing) -> canonical schema. Source field names differ completely from
  Game A, yet the OUTPUT column list is byte-for-byte identical -- that uniformity
  is what lets the union layer stay trivial.

  Note: `timestamp` is a reserved word in BigQuery, so it's backtick-quoted.

  Canonical mapping for Game B:
    player_key      <- user_id        (already a string)
    player_name     <- display_name
    player_progress <- rank
    player_score    <- score
    game_name       <- literal 'game_b'
    event_timestamp <- timestamp
    load_timestamp  <- current_timestamp()
#}

with source as (
    select * from {{ source('raw_tables', 'raw_game_b_events') }}
),

canonical as (
    select
        cast(user_id as string)           as player_key,
        display_name                      as player_name,
        rank                              as player_progress,
        score                             as player_score,
        'game_b'                          as game_name,
        cast(`timestamp` as timestamp)    as event_timestamp,
        current_timestamp()               as load_timestamp
    from source
)

select * from canonical
