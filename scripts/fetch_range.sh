#!/usr/bin/env bash
# usage: fetch_range.sh START_DATE END_DATE  (YYYY-MM-DD, UTC, inclusive). Linux only.
set -uo pipefail
START=$1
END=$2
VOL="dbfs:/Volumes/workspace/gh_archive/raw"
TMP=$(mktemp -d)
existing=$(databricks fs ls "$VOL")
uploaded=0; skipped=0; not_in_archive=0; failed=0
d="$START"
while [[ ! "$d" > "$END" ]]; do
  for h in $(seq 0 23); do
    f="$d-$h.json.gz"
    if grep -qF "$f" <<< "$existing"; then skipped=$((skipped+1)); continue; fi
    code=$(curl -sS --retry 3 --retry-delay 5 -o "$TMP/$f" -w "%{http_code}" "https://data.gharchive.org/$f" || true)
    if [[ "$code" == "404" ]]; then echo "NOT IN ARCHIVE (404): $f"; not_in_archive=$((not_in_archive+1)); rm -f "$TMP/$f"; continue; fi
    if [[ "$code" != "200" ]]; then echo "DOWNLOAD FAILED ($code): $f"; failed=$((failed+1)); rm -f "$TMP/$f"; continue; fi
    if ! gzip -t "$TMP/$f"; then echo "CORRUPT DOWNLOAD: $f"; failed=$((failed+1)); rm -f "$TMP/$f"; continue; fi
    if databricks fs cp "$TMP/$f" "$VOL/$f" --overwrite; then
      uploaded=$((uploaded+1)); echo "uploaded $f"
    else
      echo "UPLOAD FAILED: $f"; failed=$((failed+1))
    fi
    rm -f "$TMP/$f"
  done
  d=$(date -u -d "$d + 1 day" +%Y-%m-%d)
done
echo "SUMMARY uploaded=$uploaded skipped=$skipped not_in_archive=$not_in_archive failed=$failed"
if [[ $failed -gt 0 ]]; then exit 1; fi
