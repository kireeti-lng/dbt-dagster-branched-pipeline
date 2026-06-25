-- This test finds any player_key associated with more than one player_name
with player_name_counts as (
    select
        player_key,
        count(distinct player_name) as unique_names_count
    from {{ ref('fct_player_activity') }}
    group by 1
)

select
    player_key,
    unique_names_count
from player_name_counts
where unique_names_count > 1
