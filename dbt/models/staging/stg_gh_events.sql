select
    event_id,
    event_type,
    actor_id,
    actor_login,
    repo_id,
    repo_name,
    is_public,
    created_at as event_at,
    event_date,
    get_json_object(payload, '$.action') as event_action,
    source_file,
    ingested_at
from {{ source('silver', 'silver_events') }}
