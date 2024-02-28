#!/bin/bash

# Check docker network exists
docker network inspect homelab > /dev/null 2>&1 || docker network create homelab

# Run the containers
docker run -d \
    --rm \
    --hostname queue \
    --network=homelab \
    --name rabbitmq \
    -e RABBITMQ_DEFAULT_USER=guest \
    -e RABBITMQ_DEFAULT_PASS=guest \
    -p 8080:15672 \
    -p \
    5672:5672 rabbitmq:3-management

docker run -d \
    --rm \
    --network=homelab \
    --name jaeger \
    -e COLLECTOR_OTLP_ENABLED=true \
    -p 4317:4317 \
    -p 16686:16686 \
    jaegertracing/all-in-one:1.47

docker run -d \
    --rm \
    --network=homelab \
    --name collector \
    -p 4000:3000 \
    -e RUST_LOG=info \
    -e AMQP_URL="amqp://guest:guest@rabbitmq:5672" \
    -e OTLP_ENDPOINT="http://jaeger:4317" \
    collector

docker run -d \
    --rm \
    --network=homelab \
    --name quard \
    -p 3000:3000 \
    -e JWT_TOKEN="secret" \
    -e RUST_LOG=info \
    -e OTLP_ENDPOINT="http://jaeger:4317" \
    quard

docker run -d \
    --rm \
    --network=homelab \
    --name waker \
    -p 9092:9092 \
    -e MAC_ADDRESS="00:00:00:00:00:00" \
    -e RUST_LOG=info \
    waker