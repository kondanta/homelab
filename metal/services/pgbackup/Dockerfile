FROM postgres:18.1-alpine
RUN apk add --no-cache aws-cli dcron tzdata
COPY backup.sh /usr/local/bin/backup.sh
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /usr/local/bin/backup.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
