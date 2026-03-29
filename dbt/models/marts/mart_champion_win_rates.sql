{{ config(
    materialized='table',
    cluster_by=["champion_name", "position", "patch"]
) }}


select
    champion_name,
    patch,
    position,
    games_played,
    wins,
    win_rate_pct,
    avg_kda,
    avg_gpm,
    avg_dpm,
    avg_kp_pct,
    avg_dmg_share_pct,
    avg_vision_score,
    RANK() OVER (PARTITION BY patch, position ORDER BY win_rate_pct DESC) as win_rate_rank,
    RANK() OVER (PARTITION BY patch, position ORDER BY games_played DESC) as popularity_rank

from {{ ref('int_champions__patch_stats') }}
where queue_id = 420
  and games_played >= 10