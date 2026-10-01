# Databricks notebook source
spark.sql("""
CREATE TABLE IF NOT EXISTS workspace.gh_archive.silver_events (
  event_id STRING, 
  event_type STRING, 
  actor_id BIGINT, 
  actor_login STRING,
  repo_id BIGINT, 
  repo_name STRING, 
  is_public BOOLEAN, 
  created_at TIMESTAMP,
  event_date DATE, 
  payload STRING, 
  source_file STRING, 
  ingested_at TIMESTAMP)
  """)
spark.sql("""
CREATE TABLE IF NOT EXISTS workspace.gh_archive.silver_quarantine (
  raw_json STRING, 
  source_file STRING, 
  ingested_at TIMESTAMP,
  reason STRING, 
  quarantined_at TIMESTAMP)
  """)

# COMMAND ----------

SILVER = "workspace.gh_archive.silver_events"
QUAR = "workspace.gh_archive.silver_quarantine"

PARSED_SQL = """
SELECT v,
  try_cast(v:id AS STRING) AS event_id,
  try_cast(v:type AS STRING) AS event_type,
  try_cast(v:actor.id AS BIGINT) AS actor_id,
  try_cast(v:actor.login AS STRING) AS actor_login,
  try_cast(v:repo.id AS BIGINT) AS repo_id,
  try_cast(v:repo.name AS STRING) AS repo_name,
  try_cast(v:public AS BOOLEAN) AS is_public,
  try_cast(v:created_at AS TIMESTAMP) AS created_at,
  CAST(v:payload AS STRING) AS payload,
  raw_json, source_file, ingested_at
FROM (SELECT try_parse_json(raw_json) AS v, raw_json, source_file, ingested_at
      FROM {src})
"""

def process_batch(batch_df, batch_id):
    s = batch_df.sparkSession
    src = f"bronze_batch_{batch_id}"
    parsed = f"parsed_{batch_id}"
    batch_df.createOrReplaceTempView(src)
    s.sql(f"CREATE OR REPLACE TEMP VIEW {parsed} AS " + PARSED_SQL.format(src=src))
    s.sql(f"""
      INSERT INTO {QUAR}
      SELECT raw_json, source_file, ingested_at,
        CASE WHEN v IS NULL THEN 'invalid_json'
             WHEN event_id IS NULL THEN 'missing_id'
             ELSE 'missing_created_at' END,
        current_timestamp()
      FROM {parsed} WHERE v IS NULL OR event_id IS NULL OR created_at IS NULL""")
    s.sql(f"""
      MERGE INTO {SILVER} t
      USING (
        SELECT event_id, event_type, actor_id, actor_login, repo_id, repo_name,
               is_public, created_at, CAST(created_at AS DATE) AS event_date,
               payload, source_file, ingested_at
        FROM (SELECT *, row_number() OVER (
                PARTITION BY event_id ORDER BY ingested_at, source_file) AS rn
              FROM {parsed}
              WHERE v IS NOT NULL AND event_id IS NOT NULL AND created_at IS NOT NULL)
        WHERE rn = 1
      ) s ON t.event_id = s.event_id
      WHEN NOT MATCHED THEN INSERT *""")
    s.sql(f"DROP VIEW IF EXISTS {parsed}")
    s.catalog.dropTempView(src)

(spark.readStream
  .option("skipChangeCommits", "true")
  .table("workspace.gh_archive.bronze_events")
  .writeStream
  .foreachBatch(process_batch)
  .option("checkpointLocation", "/Volumes/workspace/gh_archive/checkpoints/silver_events")
  .trigger(availableNow=True)
  .start()
  .awaitTermination())

# COMMAND ----------

# MAGIC %sql
# MAGIC SELECT
# MAGIC  (SELECT count(*) FROM workspace.gh_archive.bronze_events) AS bronze_rows,
# MAGIC  (SELECT count(*) FROM workspace.gh_archive.silver_events) AS silver_rows,
# MAGIC  (SELECT count(*) FROM workspace.gh_archive.silver_quarantine) AS quarantined

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Event counts by type
# MAGIC SELECT event_type, count(*) AS cnt
# MAGIC FROM workspace.gh_archive.silver_events
# MAGIC GROUP BY event_type
# MAGIC ORDER BY cnt DESC;
# MAGIC
# MAGIC -- Data quality: NULLs and duplicates in event_id
# MAGIC -- SELECT
# MAGIC --   count(*) AS total_rows,
# MAGIC --   count(CASE WHEN event_id IS NULL THEN 1 END) AS null_event_ids,
# MAGIC --   count(*) - count(DISTINCT event_id) AS duplicate_count
# MAGIC -- FROM workspace.gh_archive.silver_events

# COMMAND ----------

# MAGIC %sql
# MAGIC CREATE OR REPLACE VIEW workspace.gh_archive.silver_missing_hours AS
# MAGIC WITH loaded AS (
# MAGIC   SELECT DISTINCT to_timestamp(regexp_extract(source_file,
# MAGIC     '([0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{1,2})', 1), 'yyyy-MM-dd-H') AS h
# MAGIC   FROM workspace.gh_archive.silver_events),
# MAGIC loaded_ok AS (SELECT h FROM loaded WHERE h IS NOT NULL),
# MAGIC bounds AS (SELECT min(h) lo, max(h) hi FROM loaded_ok),
# MAGIC expected AS (SELECT explode(sequence(lo, hi, INTERVAL 1 HOUR)) AS h FROM bounds)
# MAGIC SELECT e.h AS missing_hour
# MAGIC FROM expected e LEFT ANTI JOIN loaded_ok l ON e.h = l.h

# COMMAND ----------

# MAGIC %sql
# MAGIC SELECT * FROM workspace.gh_archive.silver_missing_hours