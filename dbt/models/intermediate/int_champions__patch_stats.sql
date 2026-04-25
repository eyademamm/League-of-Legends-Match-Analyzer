select
    champion_name,
    patch,
    position,
    queue_id,
    count(*)                                        as games_played,
    sum(case when is_winner then 1 else 0 end)      as wins,
    round(avg(case when is_winner then 1.0 else 0 end) * 100, 2) as win_rate_pct,
    round(avg(kills), 2)                            as avg_kills,
    round(avg(deaths), 2)                           as avg_deaths,
    round(avg(assists), 2)                          as avg_assists,
    round(avg(kda), 2)                              as avg_kda,
    round(avg(gold_per_minute), 1)                  as avg_gpm,
    round(avg(dpm), 1)                              as avg_dpm,
    round(avg(kill_participation_pct), 1)           as avg_kp_pct,
    round(avg(damage_share_pct), 1)                 as avg_dmg_share_pct,
    round(avg(vision_score), 1)                     as avg_vision_score

from {{ ref('int_matches__team_context') }}  -- or team_context version
where position is not null
group by champion_name, patch, position, queue_id