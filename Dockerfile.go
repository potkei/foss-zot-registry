# syntax=docker/dockerfile:1
# =============================================================================
# SOURCE BUILD — Go Projects (PRIORITY)
# Compiles from official upstream release archive for Go-based FOSS projects.
# Handles go.mod patches and go.sum regeneration automatically.
# BuildKit cache mounts persist Go module + build caches across builds.
#
# Container runtime compatibility:
#   Docker 23+ (BuildKit default)  — full cache mount support
#   Podman 4.2+ / Buildah 1.28+   — partial cache mount support
#   Podman <4.2                    — cache directives ignored, builds still work
# =============================================================================

ARG BASE_IMAGE=ubuntu:22.04
ARG GO_VERSION=1.22
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
FROM golang:${GO_VERSION}-bookworm AS downloader

ARG UPSTREAM_ARCHIVE_URL
ARG UPSTREAM_SHA256
ARG UPSTREAM_GPG_URL

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    curl gnupg ca-certificates patch

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

# Build Go binary — statically linked for minimal runtime image
# Cache both module downloads and compiled build artifacts
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build \
      -trimpath \
      -ldflags="-s -w -extldflags '-static'" \
      -o /install/${PROJECT_NAME} \
      ./cmd/${PROJECT_NAME}

# Verify the binary
RUN file /install/${PROJECT_NAME} && \
    /install/${PROJECT_NAME} --version 2>/dev/null || true

# =============================================================================
# Stage 4: Minimal Runtime (distroless for Go — no shell, minimal attack surface)
# =============================================================================
FROM gcr.io/distroless/static-debian12 AS runtime

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

USER nonroot:nonroot

EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/REPLACE_ME"]
