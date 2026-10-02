select
    event_date,
    repo_id,
    max_by(repo_name, event_at) as repo_name,
    count(*) as events,
    count(distinct actor_id) as unique_actors,
    count_if(event_type = 'WatchEvent') as stars,
    count_if(event_type = 'ForkEvent') as forks,
    count_if(event_type = 'PushEvent') as pushes,
    count_if(event_type = 'PullRequestEvent' and event_action = 'opened') as prs_opened,
    count_if(event_type = 'IssuesEvent' and event_action = 'opened') as issues_opened
from {{ ref('fct_events') }}
where repo_id is not null
group by event_date, repo_id
