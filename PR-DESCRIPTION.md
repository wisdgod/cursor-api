# 多架构 Docker 支持 - Pull Request

## 📋 更改概述

这个 PR 为 cursor2api 项目添加了完整的多架构 Docker 支持，解决了在不同 CPU 架构（AMD64 和 ARM64）上部署时遇到的兼容性问题。

## 🚀 主要改进

### 1. **自动架构检测**
- 使用 Docker 内置的 `$TARGETPLATFORM` 变量替代手动指定的 `$TARGETARCH`
- 支持自动检测目标平台：`linux/amd64` 和 `linux/arm64`
- 无需手动配置，一次构建适配多个架构

### 2. **修复构建错误**
- 修复了 RUSTFLAGS 语法错误（从 `cargo build ... -- -C ...` 改为环境变量设置）
- 正确设置 RUSTFLAGS 为环境变量：`RUSTFLAGS="..." cargo build ...`
- 解决了 "unexpected argument '-C' found" 错误

### 3. **修复.env文件缺失问题**
- 在Docker运行阶段添加`.env`文件复制
- 解决容器启动时`Failed to load .env: path not found`错误
- 确保环境变量能够正确加载到容器中

### 4. **改进代码可读性**
- 将复杂的单行命令分解为多行格式
- 添加了详细的注释说明
- 更好的错误处理和调试信息

## 🔧 技术细节

### Dockerfile 主要更改：

**之前：**
```dockerfile
ARG TARGETARCH
FROM --platform=linux/${TARGETARCH} rustlang/rust:nightly-bookworm-slim AS builder
ARG TARGETARCH
```

**现在：**
```dockerfile
# 运行阶段
FROM scratch

WORKDIR /app

COPY --from=builder /app/cursor-api .
COPY --from=builder /app/.env .  # 新添加：复制环境变量文件

ENV PORT=3000
EXPOSE ${PORT}
```

### 环境变量文件支持：

**之前：**
```dockerfile
# 运行阶段只复制二进制文件
COPY --from=builder /app/cursor-api .
```

**现在：**
```dockerfile
# 运行阶段复制二进制文件和环境配置
COPY --from=builder /app/cursor-api .
COPY --from=builder /app/.env .
```

### 构建过程改进：

**之前：**
```dockerfile
RUN case "$TARGETARCH" in amd64) ... ;; esac && RUSTFLAGS="..." cargo build ... -- -C ...
```

**现在：**
```dockerfile
RUN case "$TARGETPLATFORM" in \
    "linux/amd64") \
        TARGET_TRIPLE="x86_64-unknown-linux-musl"; \
        TARGET_CPU="x86-64-v3" \
        ;; \
    "linux/arm64") \
        TARGET_TRIPLE="aarch64-unknown-linux-musl"; \
        TARGET_CPU="neoverse-n1" \
        ;; \
    esac && \
    RUSTFLAGS="-C link-arg=-s -C target-feature=+crt-static -C target-cpu=$TARGET_CPU" \
    cargo build --bin cursor-api --release --target=$TARGET_TRIPLE
```

## 🧪 测试方法

### 在 AMD64 系统上测试：
```bash
docker-compose up -d
```

### 在 ARM64 系统上测试：
```bash
docker-compose up -d
```

### 多架构构建测试：
```bash
docker buildx build --platform linux/amd64,linux/arm64 -t cursor2api:test .
```

## 🎯 解决的问题

1. **平台兼容性错误**：
   - ❌ `failed to parse platform linux/: "" is an invalid component`
   - ✅ 自动检测并使用正确的平台标识符

2. **Cargo 构建错误**：
   - ❌ `error: unexpected argument '-C' found`
   - ✅ 正确设置 RUSTFLAGS 环境变量

3. **架构支持**：
   - ❌ 需要手动指定架构参数
   - ✅ 自动检测并支持多架构

4. **环境变量加载**：
   - ❌ `Failed to load .env: path not found`
   - ✅ 正确复制并加载.env配置文件

## 📦 部署影响

- **向后兼容**：现有的部署脚本无需修改
- **自动适配**：在任何支持的架构上运行 `docker-compose up -d` 都能正常工作
- **性能优化**：保持了原有的优化设置（musl、静态链接、CPU 优化）

## 🔍 代码审查要点

1. **Dockerfile 语法**：检查多行 RUN 命令的正确性
2. **平台支持**：确认 AMD64 和 ARM64 的配置正确
3. **构建优化**：验证 RUSTFLAGS 和目标架构设置
4. **错误处理**：确认不支持的平台会正确报错

## 📈 后续改进建议

1. 考虑添加 CI/CD 流水线来自动测试多架构构建
2. 可以添加构建缓存优化来加速构建过程
3. 考虑支持更多架构（如 RISC-V）

---

**测试状态**：✅ 已在本地验证  
**影响范围**：Docker 构建和部署  
**风险等级**：低（仅改进现有功能）
