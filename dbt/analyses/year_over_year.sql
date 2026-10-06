WITH days AS (
  SELECT *, CASE
      WHEN event_date BETWEEN '2024-09-28' AND '2024-10-04' THEN '2024'
      WHEN event_date BETWEEN '2025-09-28' AND '2025-10-04' THEN '2025'
      WHEN event_date BETWEEN '2026-09-28' AND '2026-10-04' THEN '2026'
    END AS period
  FROM workspace.gold.mart_daily_activity
  WHERE hours_covered = 24 AND dayofweek(event_date) BETWEEN 2 AND 6
)
SELECT period, count(*) AS weekdays,
  round(avg(events)) AS avg_events, round(avg(active_actors)) AS avg_users,
  round(avg(active_repos)) AS avg_repos, round(avg(stars)) AS avg_stars,
  round(avg(forks)) AS avg_forks, round(avg(prs_opened)) AS avg_prs_opened,
  round(avg(events / active_actors), 1) AS events_per_user
FROM days WHERE period IS NOT NULL GROUP BY period ORDER BY period;

WITH days AS (
  SELECT *, CASE
      WHEN event_date BETWEEN '2024-09-28' AND '2024-10-04' THEN '2024'
      WHEN event_date BETWEEN '2025-09-28' AND '2025-10-04' THEN '2025'
      WHEN event_date BETWEEN '2026-09-28' AND '2026-10-04' THEN '2026'
    END AS period
  FROM workspace.gold.mart_daily_activity
  WHERE hours_covered = 24 AND dayofweek(event_date) BETWEEN 2 AND 6
),
mix AS (
  SELECT d.period, e.event_type, count(*) AS events
  FROM workspace.gold.fct_events e JOIN days d USING (event_date)
  WHERE d.period IS NOT NULL
  GROUP BY d.period, e.event_type
)
SELECT period, event_type, events,
  round(100.0 * events / sum(events) OVER (PARTITION BY period), 1) AS pct
FROM mix ORDER BY period, events DESC


