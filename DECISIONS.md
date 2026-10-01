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
