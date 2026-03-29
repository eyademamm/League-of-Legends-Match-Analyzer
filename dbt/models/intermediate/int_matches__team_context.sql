with team_totals as (
    select
        game_id,
        team_id,
        SUM(kills)                              as team_kills,
        SUM(total_damage_dealt_to_champions)    as team_damage,
        SUM(gold_earned)                        as team_gold
    from {{ ref('stg_lol__matches') }}
    group by game_id, team_id
)

select
    m.*,
    t.team_kills,
    t.team_damage,
    t.team_gold,
    ROUND(SAFE_DIVIDE(m.kills + m.assists, t.team_kills) * 100, 1)              as kill_participation_pct,
    ROUND(SAFE_DIVIDE(m.total_damage_dealt_to_champions, t.team_damage) * 100, 1) as damage_share_pct,
    ROUND(SAFE_DIVIDE(m.gold_earned, t.team_gold) * 100, 1)                     as gold_share_pct

from {{ ref('int_matches__with_kda') }} m
left join team_totals t
    on m.game_id = t.game_id
    and m.team_id = t.team_id