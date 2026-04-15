{{ config(
    materialized='table',
    cluster_by=["champion_name", "position", "patch"]
) }}

with total_games_per_patch as (
    select
        patch,
        position,
        SUM(games_played) as total_games
    from {{ ref('mart_champion_win_rates') }}
    group by patch, position
),

base as (
    select
        m.*,
        t.total_games
    from {{ ref('mart_champion_win_rates') }} m
    left join total_games_per_patch t
        on m.patch = t.patch
        and m.position = t.position
),

lagged as (
    select
        *,
        LAG(win_rate_pct) OVER (
            PARTITION BY champion_name, position ORDER BY CAST(SPLIT(patch, '.')[OFFSET(0)] AS INT64),
             CAST(SPLIT(patch, '.')[OFFSET(1)] AS INT64)
        )                           as prev_patch_win_rate,
        LAG(pick_rate_pct) OVER (
            PARTITION BY champion_name, position ORDER BY CAST(SPLIT(patch, '.')[OFFSET(0)] AS INT64),
             CAST(SPLIT(patch, '.')[OFFSET(1)] AS INT64)
        )                           as prev_patch_pick_rate,
        LAG(patch) OVER (
            PARTITION BY champion_name, position ORDER BY CAST(SPLIT(patch, '.')[OFFSET(0)] AS INT64),
             CAST(SPLIT(patch, '.')[OFFSET(1)] AS INT64)
        )                           as prev_patch
    from (
        select
            *,
            ROUND(SAFE_DIVIDE(games_played, total_games) * 100, 2) as pick_rate_pct
        from base
    )
)

select
    *,
    ROUND(win_rate_pct - prev_patch_win_rate, 2)                as win_rate_delta,
    ROUND(pick_rate_pct - prev_patch_pick_rate, 2)              as pick_rate_delta,
    case
        when win_rate_pct - prev_patch_win_rate >  3 then 'Buffed / Rising'
        when win_rate_pct - prev_patch_win_rate < -3 then 'Nerfed / Falling'
        else 'Stable'
    end                                                         as meta_shift_label

from lagged
where prev_patch is not null