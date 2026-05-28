#!/bin/sh
set -e

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
export PGPASSWORD="$POSTGRES_PASSWORD"

echo "[$(date)] Starting backup"

for DB in $POSTGRES_DBS; do
  FILENAME="${DB}_${TIMESTAMP}.sql.gz"
  echo "[$(date)] Dumping: $DB"

  pg_dump \
    -h "$POSTGRES_HOST" \
    -U "$POSTGRES_USER" \
    -d "$DB" \
    --no-password \
    | gzip > "/tmp/$FILENAME"

  echo "[$(date)] Uploading: $FILENAME"
  aws s3 cp "/tmp/$FILENAME" "s3://${S3_BUCKET}/${DB}/${FILENAME}" \
    --endpoint-url "$S3_ENDPOINT"

  rm "/tmp/$FILENAME"
  echo "[$(date)] Done: $DB"
done

# Prune old backups — keep the BACKUP_KEEP_DAYS most recent per database.
# busybox head doesn't support negative counts, so we calculate how many to
# delete first and pass a positive count to head.
if [ -n "$BACKUP_KEEP_DAYS" ] && [ "$BACKUP_KEEP_DAYS" -gt 0 ]; then
  for DB in $POSTGRES_DBS; do
    TOTAL=$(aws s3 ls "s3://${S3_BUCKET}/${DB}/" \
        --endpoint-url "$S3_ENDPOINT" \
      | wc -l)
    TO_DELETE=$(( TOTAL - BACKUP_KEEP_DAYS ))
    if [ "$TO_DELETE" -gt 0 ]; then
      aws s3 ls "s3://${S3_BUCKET}/${DB}/" \
          --endpoint-url "$S3_ENDPOINT" \
        | sort \
        | head -n "$TO_DELETE" \
        | awk '{print $4}' \
        | while read -r fname; do
            [ -z "$fname" ] && continue
            aws s3 rm "s3://${S3_BUCKET}/${DB}/${fname}" \
              --endpoint-url "$S3_ENDPOINT"
            echo "[$(date)] Pruned: $fname"
          done
    fi
  done
fi

echo "[$(date)] Backup complete"
