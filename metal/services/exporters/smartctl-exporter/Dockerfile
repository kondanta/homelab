FROM alpine:3.21
LABEL org.opencontainers.image.source="https://github.com/kondanta/homelab"

ARG TARGETARCH

# renovate: datasource=github-releases depName=prometheus-community/smartctl_exporter
ARG VERSION=0.14.0

RUN apk add --no-cache smartmontools ca-certificates wget \
    && wget -O /tmp/smartctl_exporter.tar.gz \
        "https://github.com/prometheus-community/smartctl_exporter/releases/download/v${VERSION}/smartctl_exporter-${VERSION}.linux-${TARGETARCH}.tar.gz" \
    && tar -xzf /tmp/smartctl_exporter.tar.gz \
        --strip-components=1 \
        -C /usr/local/bin \
        "smartctl_exporter-${VERSION}.linux-${TARGETARCH}/smartctl_exporter" \
    && rm /tmp/smartctl_exporter.tar.gz \
    && chmod +x /usr/local/bin/smartctl_exporter

EXPOSE 9633
ENTRYPOINT ["/usr/local/bin/smartctl_exporter"]
