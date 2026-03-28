# zot-fork

Managed fork of [zot](https://github.com/project-zot/zot) — OCI-native container registry with CVE security patches applied before compilation.

| | |
|---|---|
| Upstream | [project-zot/zot](https://github.com/project-zot/zot) |
| Version | 2.1.15-r1 |
| License | Apache-2.0 |
| Build | Source (Go 1.25.7, `make binary` with embedded UI) |
| Port | 5000 |
| Registry | `local/zot` |
| K8s namespace | `platform` |

## Quick start

```bash
# Build from source
make build

# Run locally
docker compose -f .local/docker-compose.run.yml up

# Access registry API
curl http://localhost:5000/v2/

# Access web UI (served by zot at /ui/)
open http://localhost:5000/ui/
```

## Build strategies

| Strategy | Command | Notes |
|---|---|---|
| Source (default) | `BUILD_STRATEGY=source make build` | Compiles from `Dockerfile.go` |
| Binary (fallback) | `BUILD_STRATEGY=binary make build` | Requires tech lead approval |

## CVE patching

See [cve-patch skill](.agents/skills/cve-patch.md) and [SECURITY.md](SECURITY.md).

Patches live in `patches/` and are applied before compilation. Each patch requires a `# CVE:` header.
