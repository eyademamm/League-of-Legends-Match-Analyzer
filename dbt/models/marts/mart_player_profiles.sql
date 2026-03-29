{{ config(
    materialized='table',
    cluster_by=["solo_tier", "most_played_position", "most_played_champion"]
) }}

select
    puuid,
    MAX(summoner_name)                                          as summoner_name,
    MAX(solo_tier)                                              as solo_tier,
    MAX(solo_rank)                                              as solo_rank,
    COUNT(DISTINCT game_id)                                     as total_games,
    COUNT(DISTINCT champion_name)                               as unique_champions_played,
    ROUND(AVG(kills), 2)                                        as avg_kills,
    ROUND(AVG(deaths), 2)                                       as avg_deaths,
    ROUND(AVG(assists), 2)                                      as avg_assists,
    ROUND(AVG(kda), 2)                                          as avg_kda,
    SUM(IF(is_winner, 1, 0))                                    as total_wins,
    ROUND(SAFE_DIVIDE(
        SUM(IF(is_winner, 1.0, 0.0)), COUNT(*)
    ) * 100, 1)                                                 as overall_win_rate_pct,
    -- BigQuery equivalent of mode()
    APPROX_TOP_COUNT(position, 1)[OFFSET(0)].value              as most_played_position,
    APPROX_TOP_COUNT(champion_name, 1)[OFFSET(0)].value         as most_played_champion

from {{ ref('int_matches__with_kda') }}
group by puuid