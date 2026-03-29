with base as (
    select * from {{ ref('mart_champion_win_rates') }}
),

lagged as (
    select
        *,
        LAG(win_rate_pct) OVER (
            PARTITION BY champion_name, position ORDER BY patch
        )                           as prev_patch_win_rate,
        LAG(games_played) OVER (
            PARTITION BY champion_name, position ORDER BY patch
        )                           as prev_patch_games,
        LAG(patch) OVER (
            PARTITION BY champion_name, position ORDER BY patch
        )                           as prev_patch
    from base
)

select
    *,
    ROUND(win_rate_pct - prev_patch_win_rate, 2)                as win_rate_delta,
    ROUND(SAFE_DIVIDE(
        games_played - prev_patch_games, prev_patch_games
    ) * 100, 1)                                                 as pick_rate_change_pct,
    case
        when win_rate_pct - prev_patch_win_rate >  3 then 'Buffed / Rising'
        when win_rate_pct - prev_patch_win_rate < -3 then 'Nerfed / Falling'
        else 'Stable'
    end                                                         as meta_shift_label

from lagged
where prev_patch is not null