#!/bin/sh
set -e

echo "[$(date)] Starting sync"

for PATH_SPEC in $SYNC_BUCKETS; do
  echo "[$(date)] Syncing: $PATH_SPEC"
  rclone sync "garage:$PATH_SPEC" "proton:homelab/$PATH_SPEC" -v --exclude '_log_*'
  echo "[$(date)] Done: $PATH_SPEC"
done

if [ -n "${PUSHGATEWAY_URL}" ]; then
  echo "rclone_last_success_timestamp $(date +%s)" \
    | curl -s --data-binary @- "${PUSHGATEWAY_URL}/metrics/job/rclone_sync" || true
fi

echo "[$(date)] Sync complete"
