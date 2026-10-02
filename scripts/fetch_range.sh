#!/usr/bin/env bash
# usage: fetch_range.sh START_DATE END_DATE  (YYYY-MM-DD, UTC, inclusive). Linux only.
set -euo pipefail
START=$1
END=$2
VOL="dbfs:/Volumes/workspace/gh_archive/raw"
TMP=$(mktemp -d)
existing=$(databricks fs ls "$VOL")
d="$START"
while [[ ! "$d" > "$END" ]]; do
  for h in $(seq 0 23); do
    f="$d-$h.json.gz"
    if echo "$existing" | grep -qF "$f"; then continue; fi
    if ! curl -fsS -o "$TMP/$f" "https://data.gharchive.org/$f"; then
      echo "not available: $f"; rm -f "$TMP/$f"; continue
    fi
    gzip -t "$TMP/$f"
    databricks fs cp "$TMP/$f" "$VOL/$f" --overwrite
    rm "$TMP/$f"
    echo "uploaded $f"
  done
  d=$(date -u -d "$d + 1 day" +%Y-%m-%d)
done
