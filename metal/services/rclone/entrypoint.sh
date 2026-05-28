#!/bin/sh
set -e

if [ -z "$SYNC_SCHEDULE" ]; then
  echo "SYNC_SCHEDULE is not set" >&2
  exit 1
fi

echo "$SYNC_SCHEDULE /usr/local/bin/sync.sh >> /proc/1/fd/1 2>&1" \
  > /var/spool/cron/crontabs/root

echo "Sync scheduled: $SYNC_SCHEDULE"
echo "Buckets: $SYNC_BUCKETS"

crond -f -l 2
