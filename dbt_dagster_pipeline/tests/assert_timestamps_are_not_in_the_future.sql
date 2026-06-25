-- This test checks for rows where activity or load times occur in the future
select
    activity_key,
    event_timestamp,
    load_timestamp
from {{ ref('fct_player_activity') }}
where event_timestamp > current_timestamp()
   or load_timestamp > current_timestamp()
