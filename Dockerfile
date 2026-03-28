# syntax=docker/dockerfile:1
# =============================================================================
# SOURCE BUILD — PRIORITY
# Compiles from official upstream release archive.
# Apply CVE patches before compilation for maximum security.
# Use this Dockerfile for C, C++, and generic compiled FOSS projects.
# For Go projects use Dockerfile.go
#
# BuildKit cache mounts (--mount=type=cache) persist across builds to avoid
# redundant downloads. SHA256 verification ALWAYS runs regardless of cache.
# Caches are per-language — uncomment the section matching your project.
#
# Container runtime compatibility:
#   Docker 23+ (BuildKit default)  — full cache mount support
#   Podman 4.2+ / Buildah 1.28+   — partial cache mount support
#   Podman <4.2                    — cache directives ignored, builds still work
# =============================================================================

# -----------------------------------------------------------------------------
# Build arguments — override via docker-compose.build.yaml or CLI
# -----------------------------------------------------------------------------
ARG BASE_IMAGE=ubuntu:22.04
ARG BUILDER_IMAGE=ubuntu:22.04
ARG UPSTREAM_VERSION=REPLACE_ME
ARG UPSTREAM_ARCHIVE_URL=REPLACE_ME
ARG UPSTREAM_SHA256=REPLACE_ME
ARG UPSTREAM_GPG_URL=
ARG PROJECT_NAME=REPLACE_ME
ARG BUILD_DATE
ARG VCS_REF
ARG OUR_VERSION=${UPSTREAM_VERSION}-r1

# =============================================================================
# Stage 1: Download & Verify
# =============================================================================
FROM ${BUILDER_IMAGE} AS downloader

ARG UPSTREAM_ARCHIVE_URL
ARG UPSTREAM_SHA256
ARG UPSTREAM_GPG_URL

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    curl \
    gnupg \
    ca-certificates

WORKDIR /build

# Download upstream release archive
RUN curl -fsSL "${UPSTREAM_ARCHIVE_URL}" -o source.archive && \
    echo "Downloaded: ${UPSTREAM_ARCHIVE_URL}"

# Verify SHA256 checksum — NEVER skip this
RUN echo "${UPSTREAM_SHA256}  source.archive" | sha256sum --check --strict && \
    echo "SHA256 checksum verified"

# Verify GPG signature if available
RUN if [ -n "${UPSTREAM_GPG_URL}" ]; then \
      curl -fsSL "${UPSTREAM_GPG_URL}" -o source.archive.sig && \
      gpg --verify source.archive.sig source.archive && \
      echo "GPG signature verified"; \
    else \
      echo "No GPG URL provided — skipping GPG verification"; \
    fi

# Extract archive (supports .tar.gz, .tar.bz2, .tar.xz, .zip)
RUN if echo "${UPSTREAM_ARCHIVE_URL}" | grep -qE '\.tar\.gz$|\.tgz$'; then \
      tar -xzf source.archive; \
    elif echo "${UPSTREAM_ARCHIVE_URL}" | grep -q '\.tar\.bz2$'; then \
      tar -xjf source.archive; \
    elif echo "${UPSTREAM_ARCHIVE_URL}" | grep -q '\.tar\.xz$'; then \
      tar -xJf source.archive; \
    elif echo "${UPSTREAM_ARCHIVE_URL}" | grep -q '\.zip$'; then \
      apt-get update && apt-get install -y --no-install-recommends unzip && \
      unzip source.archive; \
    else \
      echo "ERROR: Unknown archive format" && exit 1; \
    fi && \
    # Move extracted directory to consistent name
    mv $(ls -d */ | head -1) source/

# =============================================================================
# Stage 2: Apply CVE Patches
# =============================================================================
FROM downloader AS patcher

COPY patches/ /patches/

# Apply patches in numeric order — fail hard if any patch fails
RUN if ls /patches/*.patch 1>/dev/null 2>&1; then \
      for p in $(ls /patches/*.patch | sort); do \
        echo "Applying patch: $(basename $p)..." && \
        patch -p1 -d /build/source/ < "$p" || \
        { echo "FAILED to apply patch: $p" && exit 1; }; \
      done; \
      echo "All patches applied successfully"; \
    else \
      echo "No patches to apply"; \
    fi

# =============================================================================
# Stage 3: Compile from Source
# =============================================================================
FROM patcher AS builder

ARG UPSTREAM_VERSION
ARG PROJECT_NAME

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    autoconf \
    automake \
    libtool \
    pkg-config

WORKDIR /build/source

# =============================================================================
# Build commands — uncomment the section matching your project language.
# Cache mounts persist across builds so dependencies aren't re-downloaded.
# SHA256 archive verification (Stage 1) ALWAYS runs regardless of cache state.
# =============================================================================

# --- C / C++ (default) — e.g. ClickHouse, nginx, redis -----------------------
RUN ./configure \
      --prefix=/usr/local \
      --disable-debug \
      --enable-security \
    && make -j"$(nproc)" \
    && make install DESTDIR=/install

# --- Java / Maven — e.g. Apache Flink, Kafka, Elasticsearch ------------------
# RUN --mount=type=cache,target=/root/.m2/repository \
#     mvn -B -DskipTests package -pl . && \
#     cp target/*.jar /install/app.jar

# --- Java / Gradle — e.g. Apache Flink (newer), Kafka Streams ----------------
# RUN --mount=type=cache,target=/root/.gradle/caches \
#     --mount=type=cache,target=/root/.gradle/wrapper \
#     ./gradlew build -x test --no-daemon && \
#     cp build/libs/*.jar /install/app.jar

# --- Python / pip — e.g. Apache Superset, Airflow ----------------------------
# RUN --mount=type=cache,target=/root/.cache/pip \
#     pip install --no-cache-dir --prefix=/install -r requirements.txt

# --- Node.js / npm — e.g. Apache Superset frontend, Grafana ------------------
# RUN --mount=type=cache,target=/root/.npm \
#     npm ci && npm run build

# --- Node.js / yarn ----------------------------------------------------------
# RUN --mount=type=cache,target=/usr/local/share/.cache/yarn \
#     yarn install --frozen-lockfile && yarn build

# --- Rust / cargo — e.g. Vector, Quickwit ------------------------------------
# RUN --mount=type=cache,target=/usr/local/cargo/registry \
#     --mount=type=cache,target=/build/source/target \
#     cargo build --release && \
#     cp target/release/${PROJECT_NAME} /install/${PROJECT_NAME}

# =============================================================================
# Stage 4: Runtime Image (minimal attack surface)
# =============================================================================
FROM ${BASE_IMAGE} AS runtime

ARG PROJECT_NAME
ARG UPSTREAM_VERSION
ARG OUR_VERSION
ARG BUILD_DATE
ARG VCS_REF

# OCI standard labels
LABEL org.opencontainers.image.title="${PROJECT_NAME} (patched fork)" \
      org.opencontainers.image.version="${OUR_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.source="https://github.com/REPLACE_ORG/REPLACE_REPO" \
      build.strategy="source" \
      build.upstream.version="${UPSTREAM_VERSION}" \
      build.our.version="${OUR_VERSION}"

# Install runtime dependencies only (not build tools)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates

# Copy compiled binary from builder
COPY --from=builder /install/usr/local/bin/${PROJECT_NAME} /usr/local/bin/${PROJECT_NAME}

# Run as non-root
RUN useradd --system --no-create-home --shell /usr/sbin/nologin appuser
USER appuser

# TODO: Replace with project-specific port and command
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/REPLACE_ME"]
