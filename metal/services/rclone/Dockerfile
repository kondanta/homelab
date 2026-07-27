FROM rclone/rclone:1.74.4
LABEL org.opencontainers.image.source="https://github.com/kondanta/homelab"
RUN apk add --no-cache dcron tzdata
COPY sync.sh /usr/local/bin/sync.sh
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /usr/local/bin/sync.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
