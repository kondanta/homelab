#!/bin/sh
set -e

echo "[$(date)] Starting sync"

for PATH_SPEC in $SYNC_BUCKETS; do
  echo "[$(date)] Syncing: $PATH_SPEC"
  rclone sync "garage:$PATH_SPEC" "proton:homelab/$PATH_SPEC" -v --exclude '_log_*'
  echo "[$(date)] Done: $PATH_SPEC"
done

echo "[$(date)] Sync complete"
