select
    actor_id,
    max_by(actor_login, event_at) as actor_login,
    min(event_at) as first_seen_at,
    max(event_at) as last_seen_at,
    count(*) as event_count
from {{ ref('fct_events') }}
where actor_id is not null
group by actor_id
