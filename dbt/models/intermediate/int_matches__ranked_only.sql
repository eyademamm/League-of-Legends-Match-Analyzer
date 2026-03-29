select *
from {{ ref('int_matches__team_context') }}
where queue_id = 420
  and position is not null  -- exclude games with missing position data