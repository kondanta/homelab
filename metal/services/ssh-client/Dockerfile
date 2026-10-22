FROM alpine:3.24.3
LABEL org.opencontainers.image.source="https://github.com/kondanta/homelab"
# ssh refuses to run for a uid with no passwd entry ("No user exists for uid 1000"), and
# Kubernetes does not create one, so the uid the cluster job runs as must exist here.
# No home dir: jobs pass -i / -o UserKnownHostsFile explicitly.
RUN apk add --no-cache openssh-client-default \
 && adduser -D -H -u 1000 -h /tmp ssh
USER 1000:1000
