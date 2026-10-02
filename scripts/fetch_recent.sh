#!/usr/bin/env bash
# Runs on a Linux GitHub runner. Fetches the last 24 hours of files not yet in the volume.
set -uo pipefail
VOL="dbfs:/Volumes/workspace/gh_archive/raw"
TMP=$(mktemp -d)
existing=$(databricks fs ls "$VOL")
failed=0
for back in $(seq 24 -1 2); do
  f="$(date -u -d "$back hours ago" +%Y-%m-%d-%-H).json.gz"
  if grep -qF "$f" <<< "$existing"; then continue; fi
  code=$(curl -sS --retry 3 --retry-delay 5 -o "$TMP/$f" -w "%{http_code}" "https://data.gharchive.org/$f" || true)
  if [[ "$code" == "404" ]]; then echo "not in archive yet (404): $f"; rm -f "$TMP/$f"; continue; fi
  if [[ "$code" != "200" ]]; then echo "download failed ($code): $f"; failed=$((failed+1)); rm -f "$TMP/$f"; continue; fi
  if ! gzip -t "$TMP/$f"; then echo "corrupt download: $f"; failed=$((failed+1)); rm -f "$TMP/$f"; continue; fi
  if databricks fs cp "$TMP/$f" "$VOL/$f" --overwrite; then echo "uploaded $f"; else echo "upload failed: $f"; failed=$((failed+1)); fi
  rm -f "$TMP/$f"
done
if [[ $failed -gt 0 ]]; then exit 1; fi
