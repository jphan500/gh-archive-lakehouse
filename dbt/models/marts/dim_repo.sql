select
    repo_id,
    max_by(repo_name, event_at) as repo_name,
    min(event_at) as first_seen_at,
    max(event_at) as last_seen_at,
    count(*) as event_count
from {{ ref('fct_events') }}
where repo_id is not null
group by repo_id
