# Genie space: GH Archive Explorer

## Purpose
Lets a non-SQL user ask questions about GitHub activity in plain English. It runs on the gold layer, not on raw events, so answers come from tested, documented models.

## Setup
- **Tables:** mart_daily_activity, fct_repo_daily, dim_repo, dim_actor
- **Excluded:** fct_events (event-level, large; Genie would use it instead of the aggregates) and stg_gh_events (staging model, not for end users)
- **Compute:** serverless starter warehouse (Free Edition)
- **Descriptions:** written once in dbt `schema.yml` and pushed to Unity Catalog on every build with `persist_docs`, so rebuilds don't erase them

## What makes the answers reliable
1. **Table and column descriptions** (from dbt)
2. **Instructions** that state the data coverage, because the sample is uneven:
   > [paste your final instruction text]
3. **Example queries** for the core questions (top repos, daily trend, year-over-year, contributors excluding bots, PRs by repo)

## Test log
| # | Question | Result | Notes |
|---|---|---|---|
| 1 | What was the busiest day, and how many events happened? | [pass/fail] | |
| 2 | Which repo had the most forks? | | |
| 3 | How many distinct repos were active each day? | | |
| 4 | Show pushes per day as a chart. | | |
| 5 | How many events per hour in 2026 vs 2024? | | |
| 6 | Which repos have the most unique actors? | | |
| 7 | When was [repo] first seen? | | |
| 8 | Which repos had more issues opened than PRs opened? | | |
| 9 | What's the weather in Toronto? | | Should decline |
| 10 | How many events had type PushEvent? | | Should fail or redirect: event type isn't in these tables |
| 11 | Compare January 2024 to January 2026. | | Should say there's no January 2026 data |
| 12 | Is GitHub activity growing year over year? | | Should use Sep 28 to Oct 4 only |


## Limitations
- Free Edition: soft rate limits (about 20 questions per minute in the UI), personal use only, and the space can't be shared outside the workspace
- Coverage is uneven across years (see instructions above), so most comparisons are limited to Sep 28 to Oct 4
- No event-type or event-content questions, since those live in fct_events and silver
- The 2026 window grows daily, and the latest day may be partial
