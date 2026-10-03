select
    event_date,
    count(*) as events,
    count(distinct actor_id) as active_actors,
    count(distinct repo_id) as active_repos,
    count_if(event_type = 'WatchEvent') as stars,
    count_if(event_type = 'ForkEvent') as forks,
    count_if(event_type = 'PushEvent') as pushes,
    count_if(event_type = 'PullRequestEvent' and event_action = 'opened') as prs_opened,
    count(distinct hour(event_at)) as hours_covered
from {{ ref('fct_events') }}
group by event_date
