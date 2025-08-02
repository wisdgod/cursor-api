ARG TARGETARCH
FROM --platform=linux/${TARGETARCH} rustlang/rust:nightly-bookworm-slim AS builder

ARG TARGETARCH

WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends build-essential protobuf-compiler nodejs npm musl-tools && rm -rf /var/lib/apt/lists/* && case "$TARGETARCH" in amd64) rustup target add x86_64-unknown-linux-musl ;; arm64) rustup target add aarch64-unknown-linux-musl ;; *) echo "Unsupported architecture for rustup: $TARGETARCH" && exit 1 ;; esac

COPY . .
RUN case "$TARGETARCH" in amd64) TARGET_TRIPLE="x86_64-unknown-linux-musl"; TARGET_CPU="x86-64-v3" ;; arm64) TARGET_TRIPLE="aarch64-unknown-linux-musl"; TARGET_CPU="neoverse-n1" ;; *) echo "Unsupported architecture: $TARGETARCH" && exit 1 ;; esac && RUSTFLAGS="-C link-arg=-s -C target-feature=+crt-static -C target-cpu=$TARGET_CPU" cargo build --bin cursor-api --release --target=$TARGET_TRIPLE && cp target/$TARGET_TRIPLE/release/cursor-api /app/cursor-api

# 运行阶段
FROM scratch

WORKDIR /app

COPY --from=builder /app/cursor-api .

ENV PORT=3000
EXPOSE ${PORT}

USER 1001

ENTRYPOINT ["/app/cursor-api"]
