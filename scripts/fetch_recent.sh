#!/usr/bin/env bash
# Runs on a Linux GitHub runner. Fetches recent hourly files not yet in the volume.
set -euo pipefail
VOL="dbfs:/Volumes/workspace/gh_archive/raw"
TMP=$(mktemp -d)
existing=$(databricks fs ls "$VOL")
for back in 6 5 4 3 2; do
  ts=$(date -u -d "$back hours ago" +%Y-%m-%d-%-H)
  f="$ts.json.gz"
  if echo "$existing" | grep -qF "$f"; then echo "skip $f (already there)"; continue; fi
  if ! curl -fsS -o "$TMP/$f" "https://data.gharchive.org/$f"; then echo "not available yet: $f"; continue; fi
  gzip -t "$TMP/$f"
  databricks fs cp "$TMP/$f" "$VOL/$f"
  rm "$TMP/$f"
  echo "uploaded $f"
done
