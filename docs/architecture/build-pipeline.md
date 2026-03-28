# Build Pipeline

## Overview

The build pipeline compiles upstream FOSS projects from official release archives with
security patches applied before compilation.

```mermaid
flowchart TD
    subgraph Download
        A1[Download release archive] --> A2[Verify SHA256 checksum]
        A2 --> A3[Verify GPG signature]
        A3 --> A4[Extract archive]
    end

    subgraph Patch
        B1[Copy patches/ into build] --> B2[Apply patches in numeric order]
        B2 --> B3[Fail hard if any patch fails]
    end

    subgraph Build
        C1[Install build dependencies] --> C2[Configure + compile]
        C2 --> C3[Install to staging dir]
    end

    subgraph Runtime
        D1[Minimal base image] --> D2[Copy compiled binary]
        D2 --> D3[Non-root user]
        D3 --> D4[OCI labels]
    end

    Download --> Patch --> Build --> Runtime
```

## Dockerfiles

| File | Language | Base Image |
|---|---|---|
| `Dockerfile` | C/C++/generic | Ubuntu 22.04 |
| `Dockerfile.go` | Go | golang + distroless |
| `Dockerfile.binary` | Any (pre-built) | Ubuntu 22.04 |

## Build Strategy Toggle

```bash
# Source build (default)
BUILD_STRATEGY=source ./build.sh

# Binary fallback
BUILD_STRATEGY=binary ./build.sh
```

The `BUILD_STRATEGY` variable controls CI, local builds, and Helm deployments consistently.
