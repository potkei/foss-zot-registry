# syntax=docker/dockerfile:1
# =============================================================================
# SOURCE BUILD — Go Projects (PRIORITY)
# Compiles from official upstream release archive for Go-based FOSS projects.
# Handles go.mod patches and go.sum regeneration automatically.
# BuildKit cache mounts persist Go module + build caches across builds.
#
# zot build notes:
#   - Uses `make binary` which embeds pre-built ZUI assets from GitHub
#     (ZUI_VERSION=commit-111cb8e → https://github.com/project-zot/zui/releases)
#   - Builder stage requires outbound internet access for ZUI asset download
#   - Binary output: bin/zot-linux-amd64
#   - Port: 5000
#
# Go version probe: go.mod requires 1.25.7 → using golang:1.25.7-bookworm
#
# Container runtime compatibility:
#   Docker 23+ (BuildKit default)  — full cache mount support
#   Podman 4.2+ / Buildah 1.28+   — partial cache mount support
#   Podman <4.2                    — cache directives ignored, builds still work
# =============================================================================

ARG BASE_IMAGE=gcr.io/distroless/base-nossl-debian12:nonroot
ARG GO_VERSION=1.25.7
ARG UPSTREAM_VERSION=2.1.15
ARG UPSTREAM_ARCHIVE_URL=https://github.com/project-zot/zot/archive/refs/tags/v2.1.15.tar.gz
ARG UPSTREAM_SHA256=183525bc4ffdf031c6c7e40a013f888f3a1f9a7acc149baa01cd6adc00f59b23
ARG UPSTREAM_GPG_URL=
ARG PROJECT_NAME=zot
ARG BUILD_DATE
ARG VCS_REF
ARG OUR_VERSION=${UPSTREAM_VERSION}-r1

# =============================================================================
# Stage 1: Download & Verify
# =============================================================================
FROM golang:${GO_VERSION}-bookworm AS downloader

ARG UPSTREAM_ARCHIVE_URL
ARG UPSTREAM_SHA256
ARG UPSTREAM_GPG_URL

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    curl gnupg ca-certificates patch make

WORKDIR /build

RUN curl -fsSL "${UPSTREAM_ARCHIVE_URL}" -o source.archive && \
    echo "${UPSTREAM_SHA256}  source.archive" | sha256sum --check --strict && \
    echo "SHA256 verified"

RUN if [ -n "${UPSTREAM_GPG_URL}" ]; then \
      curl -fsSL "${UPSTREAM_GPG_URL}" -o source.archive.sig && \
      gpg --verify source.archive.sig source.archive && \
      echo "GPG verified"; \
    fi

RUN if echo "${UPSTREAM_ARCHIVE_URL}" | grep -qE '\.tar\.gz$|\.tgz$'; then \
      tar -xzf source.archive; \
    elif echo "${UPSTREAM_ARCHIVE_URL}" | grep -q '\.tar\.bz2$'; then \
      tar -xjf source.archive; \
    elif echo "${UPSTREAM_ARCHIVE_URL}" | grep -q '\.tar\.xz$'; then \
      tar -xJf source.archive; \
    elif echo "${UPSTREAM_ARCHIVE_URL}" | grep -q '\.zip$'; then \
      apt-get install -y unzip && unzip source.archive; \
    fi && \
    mv $(ls -d */ | head -1) source/

# =============================================================================
# Stage 2: Apply CVE Patches
# =============================================================================
FROM downloader AS patcher

COPY patches/ /patches/

# Apply source code patches (skip .skip marker files)
RUN if ls /patches/*.patch 1>/dev/null 2>&1; then \
      for p in $(ls /patches/*.patch | sort); do \
        echo "Applying: $(basename $p)..." && \
        patch -p1 -d /build/source/ < "$p" || \
        { echo "FAILED: $p" && exit 1; }; \
      done; \
    fi

# Regenerate go.sum if any go.mod patch was applied
# go.sum contains cryptographic hashes — cannot be hand-patched
# Cache mount persists Go module downloads across builds
RUN --mount=type=cache,target=/go/pkg/mod \
    cd /build/source && \
    if ls /patches/*gomod*.patch /patches/*go-mod*.patch 2>/dev/null | head -1 | grep -q .; then \
      echo "go.mod patch detected — regenerating go.sum..." && \
      GONOSUMCHECK=* GOFLAGS=-mod=mod go mod tidy && \
      echo "go.sum regenerated successfully"; \
    else \
      echo "No go.mod patches — downloading dependencies normally" && \
      go mod download; \
    fi

# =============================================================================
# Stage 3: Compile
# =============================================================================
FROM patcher AS builder

ARG PROJECT_NAME

WORKDIR /build/source

# Build zot with all extensions including embedded UI
# make binary: downloads zui pre-built assets (ZUI_VERSION=commit-111cb8e) from
# https://github.com/project-zot/zui and embeds via go:embed
# Requires outbound internet for ZUI asset download during build
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    make binary OS=linux ARCH=amd64

# Collect binary and generate default config
RUN mkdir -p /install && \
    cp bin/zot-linux-amd64 /install/${PROJECT_NAME} && \
    printf '{\n  "storage": {\n    "rootDirectory": "/var/lib/registry"\n  },\n  "http": {\n    "address": "0.0.0.0",\n    "port": "5000",\n    "compat": ["docker2s2"]\n  },\n  "log": {\n    "level": "info"\n  }\n}\n' > /install/config.json

# Verify the binary
RUN file /install/${PROJECT_NAME} && \
    /install/${PROJECT_NAME} version 2>/dev/null || true

# =============================================================================
# Stage 4: Minimal Runtime (distroless — no shell, minimal attack surface)
# =============================================================================
FROM ${BASE_IMAGE} AS runtime

ARG PROJECT_NAME
ARG UPSTREAM_VERSION
ARG OUR_VERSION
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.title="${PROJECT_NAME} (Go patched fork)" \
      org.opencontainers.image.version="${OUR_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      build.strategy="source-go" \
      build.upstream.version="${UPSTREAM_VERSION}" \
      build.our.version="${OUR_VERSION}"

COPY --from=builder /install/${PROJECT_NAME} /usr/local/bin/${PROJECT_NAME}
COPY --from=builder /install/config.json /etc/zot/config.json
# Apache-2.0 compliance: NOTICE file must be included in all distributions
COPY --from=builder /build/source/NOTICE /NOTICE

USER nonroot:nonroot

EXPOSE 5000
ENTRYPOINT ["/usr/local/bin/zot"]
CMD ["serve", "/etc/zot/config.json"]
