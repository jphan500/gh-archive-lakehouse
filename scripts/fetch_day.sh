#!/usr/bin/env bash
# usage: ./scripts/fetch_day.sh 2024-01-01 [profile]
set -euo pipefail
DAY=$1
PROFILE=${2:-gh-free}
VOL="dbfs:/Volumes/workspace/gh_archive/raw"
TMP=$(mktemp -d)
for h in $(seq 0 23); do
  f="$DAY-$h.json.gz"
  curl -fsS -o "$TMP/$f" "https://data.gharchive.org/$f"
  gzip -t "$TMP/$f"
  databricks fs cp "$TMP/$f" "$VOL/$f" -p "$PROFILE" --overwrite
  rm "$TMP/$f"
done
rmdir "$TMP"
