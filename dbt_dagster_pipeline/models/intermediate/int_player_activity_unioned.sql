{#
  Union layer. Combines every per-game staging model into one canonical stream.

  Because all staging models share a byte-identical column list, a plain UNION ALL
  is safe and explicit -- easy to read while learning. Onboarding a new game adds
  exactly one more select block here (see Phase 2).

  Production upgrade: replace this whole block with
      {{ dbt_utils.union_relations(relations=[ref('stg_game_a_events'), ...]) }}
  which unions by column NAME and tolerates differing column order automatically.
#}

with unioned as (
    select * from {{ ref('stg_game_a_events') }}
    union all
    select * from {{ ref('stg_game_b_events') }}
)

select * from unioned
