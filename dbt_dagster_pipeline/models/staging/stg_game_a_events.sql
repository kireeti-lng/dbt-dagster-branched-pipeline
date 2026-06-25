{#
  Game A (RPG) -> canonical schema. The ONLY place game-A field knowledge lives.

  Canonical mapping for Game A:
    player_key      <- player_id   (cast to STRING so it unifies with Game B's ids)
    player_name     <- username
    player_progress <- level
    player_score    <- xp
    game_name       <- literal 'game_a'
    event_timestamp <- event_time
    load_timestamp  <- current_timestamp()
#}

with source as (
    select * from {{ source('raw_tables', 'raw_game_a_events') }}
),

canonical as (
    select
        cast(player_id as string)         as player_key,
        username                          as player_name,
        level                             as player_progress,
        xp                                as player_score,
        'game_a'                          as game_name,
        cast(event_time as timestamp)     as event_timestamp,
        current_timestamp()               as load_timestamp
    from source
)

select * from canonical
