# Decisions Log

Short record of what I chose, what I rejected, and why.

## 1. Source: GH Archive
- Chose: GH Archive hourly event files (gzipped JSON).
- Why: real scale, new files arrive every hour (so ingestion is genuinely incremental), and the schema is messy and has changed over the years.
- Rejected: static datasets (NYC taxi, Kaggle CSVs), because they can't show incremental ingestion.
- Tradeoff: it's event data, not business data, so the gold layer has to model it into something meaningful.

## 2. Platform: Databricks Free Edition
- Chose: Free Edition (serverless only, no expiry stated, non-commercial use).
- Why: free, no trial clock, and it matches the skills I want to show (Auto Loader, Unity Catalog, Lakeflow).
- Limits I design around: serverless only, one small SQL warehouse, daily compute quotas, restricted outbound internet.

## 3. Ingestion: push files in, don't pull from Databricks
- Problem: Free Edition blocks outbound internet, so Databricks can't download from GH Archive. Confirmed with a DNS failure in a notebook.
- Chose: an external script downloads each hourly file and uploads it to a Unity Catalog Volume with the Databricks CLI. A scheduled GitHub Actions job will run it.
- Rejected: identity verification to unlock outbound access (chose not to use it), and a paid cloud account (cost).
- Tradeoff: the download step lives outside Databricks. It's a common landing-zone pattern, and Auto Loader can't tell the difference.
- Consequence: Kafka-into-Databricks isn't possible on this setup. If I do Kafka, it'll be a separate local project.

## 4. Bronze stores raw JSON as text
- Chose: Auto Loader with the text format. Each event is one raw string plus file metadata (source file, modified time, ingested time).
- Why: schema changes can't break ingestion, and I can reparse later without re-downloading.
- Rejected: parsing JSON directly at bronze, because a schema change would fail the pipeline at the first stage.
- Tradeoff: bronze isn't directly queryable. Silver does the parsing.

## 5. Incident: duplicate data from a test file
- What happened: my manual CLI upload test (`test-cli.json.gz`) was a copy of an existing hour. Auto Loader ingested it as a new file, so bronze showed 25 files instead of 24.
- Root cause: Auto Loader tracks files by name/path, not by content.
- Fix: deleted the test file and its rows. Silver will dedupe on the event `id`.

## 6. Incident: corrupt (truncated) file
- What I did: uploaded a gzip file cut off at 1 MB to simulate an interrupted download.
- What happened: the read failed with `FAILED_READ_FILE`, naming the file. Root cause in the trace: `EOFException: Unexpected end of input stream`.
- How I diagnosed it: the error named the file, the other files ingested fine, and `gzip -t` fails on a truncated copy.
- Fix implemented: `gzip -t` in the fetch script, so a corrupt download is stopped before it reaches the volume.
- Still to do: quarantine bad files and alert, plus a missing-hours check in silver so gaps get caught.
- Rejected: silently skipping corrupt files, because data loss goes unnoticed.

## 7. Measured numbers
- TODO: size of one hourly file, upload time per day, rows per day, bronze ingest runtime, total after backfill.

cd ~/gh-archive-lakehouse
cat >> DECISIONS.md << 'EOF'

## 8. Silver design
- Parse with try_parse_json (VARIANT) and try_ casts, so schema drift and bad rows can't crash the stream.
- Dedupe with MERGE on event_id (window function inside a batch, MERGE across batches). Source data itself contains a small number of duplicate events (bronze minus silver was about 135 rows of 53M, re-verify).
- Bad rows go to a quarantine table with a reason, instead of being dropped.
- Dedupe keeps the first arrival, so lineage can point at a copy.

## 9. Gold design (dbt)
- Star schema: fct_events (incremental, merge on event_id), dim_actor, dim_repo, fct_repo_daily (aggregated).
- Incremental filter uses ingested_at, not event time, because backfilled files arrive late.
- payload stays out of gold. Names use max_by on latest event, since repos get renamed.
- Custom test: fct_events row count must equal silver. It passed after the late-arriving backfill.

## 10. Incident: silent skips in the backfill
- Transient "connection reset" errors from the source were treated as "file not available", and one failure ended the whole run.
- Fix: retries, 404 vs other failures handled separately, per-file error handling, a summary line, and a 24-hour look-back on the hourly job.
- Result: uploaded=28 skipped=180 not_in_archive=8 (hours not yet published) failed=0.

## 11. Missing-hours check
- Checks every day that has data for 24 hours, ignoring the newest 7. It cannot see days with no files at all.
- Some gaps may be upstream (404). The pipeline records them instead of failing.

## 12. Drill: bad rows and schema drift
- Uploaded a file with an unexpected extra field, a row missing id, and a non-JSON line.
- Result: extra field ignored, the other two went to quarantine as missing_id and invalid_json, and the pipeline kept running.

## 13. Measured numbers
- One day: about 4.0M rows, 1.76 GB raw, bronze ingest about 54 seconds.
- Total: about 53M rows. Silver: 483 files, 20.7 GB before clustering.
- dbt build: about 100 to 117 seconds per run, incremental or not (full-rebuild tables and tests dominate).
- Clustering: TODO before/after query time, bytes read, file count.

## 14. What breaks at 10x
- TODO: your own list (MERGE lookup cost on silver, full rebuild of dims/marts, tests scanning full tables, serverless daily quota).
EOF