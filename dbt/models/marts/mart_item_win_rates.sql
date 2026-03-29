{{ config(
    materialized='table',
    cluster_by=["champion_name", "position", "patch"]
) }}

with items_unpivoted as (
    select
        game_id,
        puuid,
        champion_name,
        position,
        is_winner,
        patch,
        item_id
    from {{ ref('stg_lol__matches') }},
    UNNEST([item0, item1, item2, item3, item4, item5]) as item_id
    where queue_id = 420
),

filtered as (
    select * from items_unpivoted
    where item_id != 0
)

select
    item_id,
    champion_name,
    position,
    patch,
    COUNT(*)                                                    as games_with_item,
    ROUND(AVG(IF(is_winner, 1.0, 0.0)) * 100, 2)              as win_rate_with_item

from filtered
group by item_id, champion_name, position, patch
having COUNT(*) >= 10
-- removed ORDER BY — incompatible with BigQuery clustering