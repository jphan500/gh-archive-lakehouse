# Databricks notebook source
from pyspark.sql import functions as F

(spark.readStream
  .format("cloudFiles")
  .option("cloudFiles.format", "text")
  .load("/Volumes/workspace/gh_archive/raw/")
  .select(
      F.col("value").alias("raw_json"),
      F.col("_metadata.file_path").alias("source_file"),
      F.col("_metadata.file_modification_time").alias("file_modified_at"),
      F.current_timestamp().alias("ingested_at"))
  .writeStream
  .option("checkpointLocation", "/Volumes/workspace/gh_archive/checkpoints/bronze_events")
  .trigger(availableNow=True)
  .toTable("workspace.gh_archive.bronze_events"))

# COMMAND ----------

# MAGIC %sql
# MAGIC SELECT count(*) AS rows, count(DISTINCT source_file) AS files
# MAGIC FROM workspace.gh_archive.bronze_events

# COMMAND ----------

# MAGIC %sql
# MAGIC SELECT source_file, count(*) AS rows
# MAGIC FROM workspace.gh_archive.bronze_events
# MAGIC GROUP BY source_file
# MAGIC ORDER BY source_file

# COMMAND ----------

try:
    spark.read.text("/Volumes/workspace/gh_archive/raw/2024-01-09-0.json.gz").count()
except Exception as e:
    msg = str(e)
    for line in msg.splitlines():
        if "Caused by" in line or "EOF" in line or "gzip" in line.lower() or "zlib" in line.lower():
            print(line[:400])