#!/bin/sh
set -e

if [ -z "$BACKUP_SCHEDULE" ]; then
  echo "BACKUP_SCHEDULE is not set" >&2
  exit 1
fi

# Write crontab, forwarding output to container stdout/stderr
echo "$BACKUP_SCHEDULE /usr/local/bin/backup.sh >> /proc/1/fd/1 2>&1" \
  > /var/spool/cron/crontabs/root

echo "Backup scheduled: $BACKUP_SCHEDULE"
echo "Databases: $POSTGRES_DBS"

exec dcron -f -l 2
