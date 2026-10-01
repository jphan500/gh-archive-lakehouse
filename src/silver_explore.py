# Databricks notebook source
# MAGIC %sql
# MAGIC SELECT raw_json FROM workspace.gh_archive.bronze_events LIMIT 3

# COMMAND ----------

# MAGIC %sql
# MAGIC SELECT
# MAGIC   try_cast(v:id AS STRING) AS event_id,
# MAGIC   try_cast(v:type AS STRING) AS event_type,
# MAGIC   try_cast(v:actor.id AS BIGINT) AS actor_id,
# MAGIC   try_cast(v:repo.name AS STRING) AS repo_name,
# MAGIC   try_cast(v:created_at AS TIMESTAMP) AS created_at
# MAGIC FROM (SELECT try_parse_json(raw_json) AS v
# MAGIC       FROM workspace.gh_archive.bronze_events LIMIT 1000)