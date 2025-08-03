# 使用 Docker 内置的架构变量
ARG TARGETPLATFORM
ARG BUILDPLATFORM
FROM --platform=$TARGETPLATFORM rustlang/rust:nightly-bookworm-slim AS builder

# 从平台信息中提取架构
ARG TARGETPLATFORM

WORKDIR /app

# 根据目标平台设置架构变量并安装依赖
RUN case "$TARGETPLATFORM" in \
    "linux/amd64") \
        TARGETARCH="amd64" \
        ;; \
    "linux/arm64") \
        TARGETARCH="arm64" \
        ;; \
    *) \
        echo "Unsupported platform: $TARGETPLATFORM" && exit 1 \
        ;; \
    esac && \
    apt-get update && apt-get install -y --no-install-recommends build-essential protobuf-compiler nodejs npm musl-tools && \
    rm -rf /var/lib/apt/lists/* && \
    case "$TARGETARCH" in \
        amd64) rustup target add x86_64-unknown-linux-musl ;; \
        arm64) rustup target add aarch64-unknown-linux-musl ;; \
        *) echo "Unsupported architecture for rustup: $TARGETARCH" && exit 1 ;; \
    esac

COPY . .

# 构建应用
RUN case "$TARGETPLATFORM" in \
    "linux/amd64") \
        TARGET_TRIPLE="x86_64-unknown-linux-musl"; \
        TARGET_CPU="x86-64-v3" \
        ;; \
    "linux/arm64") \
        TARGET_TRIPLE="aarch64-unknown-linux-musl"; \
        TARGET_CPU="neoverse-n1" \
        ;; \
    *) \
        echo "Unsupported platform: $TARGETPLATFORM" && exit 1 \
        ;; \
    esac && \
    RUSTFLAGS="-C link-arg=-s -C target-feature=+crt-static -C target-cpu=$TARGET_CPU" \
    cargo build --bin cursor-api --release --target=$TARGET_TRIPLE && \
    cp target/$TARGET_TRIPLE/release/cursor-api /app/cursor-api

# 运行阶段
FROM scratch

WORKDIR /app

COPY --from=builder /app/cursor-api .

ENV PORT=3000
EXPOSE ${PORT}

USER 1001

ENTRYPOINT ["/app/cursor-api"]
