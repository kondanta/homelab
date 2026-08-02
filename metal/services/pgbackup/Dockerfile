FROM postgres:18.4-alpine
LABEL org.opencontainers.image.source="https://github.com/kondanta/homelab"
RUN apk add --no-cache aws-cli curl dcron tzdata
COPY backup.sh /usr/local/bin/backup.sh
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /usr/local/bin/backup.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
