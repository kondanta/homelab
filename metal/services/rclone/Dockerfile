# Pinned to 1.74.4: 1.75.0 introduced a regression in the Proton Drive backend
# where 422 responses are mishandled, causing a 422->404 error sequence that
# breaks sync. See: https://github.com/rclone/rclone/issues/9722
FROM rclone/rclone:1.75.1
LABEL org.opencontainers.image.source="https://github.com/kondanta/homelab"
RUN apk add --no-cache curl dcron tzdata
COPY sync.sh /usr/local/bin/sync.sh
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /usr/local/bin/sync.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
