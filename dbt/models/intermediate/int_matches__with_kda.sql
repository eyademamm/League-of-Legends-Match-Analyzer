select
    *,
    ROUND(SAFE_DIVIDE(kills + assists, NULLIF(deaths, 0)), 2)       as kda,
    ROUND(SAFE_DIVIDE(gold_earned, game_duration / 60.0), 1)        as gold_per_minute,
    ROUND(SAFE_DIVIDE(
        total_damage_dealt_to_champions, game_duration / 60.0
    ), 1)                                                           as dpm,
    case
        when deaths = 0                              then 'Perfect KDA'
        when SAFE_DIVIDE(kills + assists, deaths) >= 5 then 'Excellent'
        when SAFE_DIVIDE(kills + assists, deaths) >= 3 then 'Good'
        when SAFE_DIVIDE(kills + assists, deaths) >= 1 then 'Average'
        else 'Poor'
    end                                                             as kda_tier

from {{ ref('stg_lol__matches') }}