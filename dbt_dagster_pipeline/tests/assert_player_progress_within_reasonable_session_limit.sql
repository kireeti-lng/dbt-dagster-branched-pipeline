-- This test flags single-session progress entries that exceed realistic game limits
select
    activity_key,
    player_key,
    player_progress
from {{ ref('fct_player_activity') }}
where player_progress > 50000 
