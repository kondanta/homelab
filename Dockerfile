FROM rust:latest as builder
WORKDIR /usr/src/homelab
ADD . .
RUN rustup target add x86_64-unknown-linux-musl
RUN apt-get update && apt-get install -y musl-tools musl musl-dev
RUN cargo build --release --target x86_64-unknown-linux-musl --locked

FROM alpine:latest as runtime
RUN echo "alpine"

FROM runtime as collector
COPY --from=builder /usr/src/homelab/target/x86_64-unknown-linux-musl/release/collector /usr/local/bin/collector
CMD [ "/usr/local/bin/collector" ]

FROM runtime as waker
COPY --from=builder /usr/src/homelab/target/x86_64-unknown-linux-musl/release/waker /usr/local/bin/waker
CMD [ "/usr/local/bin/waker" ]

FROM runtime as quard
COPY --from=builder /usr/src/homelab/target/x86_64-unknown-linux-musl/release/quard /usr/local/bin/quard
CMD [ "/usr/local/bin/quard" ]

