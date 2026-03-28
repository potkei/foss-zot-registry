# GitHub Copilot Instructions

> Read `.agents/CONSTITUTION.md` first — it is the master ruleset for all AI tools in this repo.

## What This Repo Does

Managed fork of an open source project. Downloads official release archives (NOT git clone),
applies CVE security patches, compiles from source, and ships patched container images.

## Critical Rules

1. **Source build priority** — always suggest `Dockerfile` / `Dockerfile.go` over `Dockerfile.binary`
2. **Version format** — `{upstream_version}-r{N}` e.g. `6.0.0-r1`, `6.0.0-r2`, `6.1.0-r1`
3. **Branch names** — `release/6.0.0-r1`, `hotfix/6.0.0-CVE-2024-1234`, `feature/description`, `chore/description`
4. **Scripts stored as `.txt`** — `build.sh.txt`, `scan.py.txt` — enterprise policy, never `.sh`
5. **No secrets committed** — `.cicd/docker-resources/secrets/` is gitignored, mount-only
6. **No `latest` tags** — always pin base image versions in Dockerfiles
7. **Patch headers required** — every `.patch` file needs CVE, Upstream-PR, Keep-on-sync fields
8. **Never push without confirmation** — always ask before pushing or merging
9. **`.local/` vs `.cicd/`** — compose files and tool Dockerfiles go in `.local/`; `.cicd/` is pipeline only
10. **`pull_policy: missing`** — all `.local/` compose services must set this; add `image:` if `build:` is used
11. **Python tool images** — use `python:*-slim` + `uv` (copied from `ghcr.io/astral-sh/uv`) — never fat images
12. **Runtime image priority** — `scratch` (static binary) → `gcr.io/distroless/*` → `*-slim` — full OS images (ubuntu/debian) prohibited as runtime base; downgrade requires CHANGELOG entry
13. **Language auto-detect** — infer from `go.mod` → Go, `Cargo.toml` → Rust, `CMakeLists.txt` → C/C++, `pom.xml` → Java, `pyproject.toml` → Python, etc.; never ask unless ambiguous. Full table: CONSTITUTION §Language & Build Tool Detection
14. **Version probe** — always try latest stable base image first; step down one minor on failure; floor = upstream's minimum requirement; never silently pin old version. Full algorithm: CONSTITUTION §Progressive Version Probe

## Skills in `.agents/skills/`

- `cve-patch.md` — applying CVE patches
- `build-strategy-switch.md` — switching source/binary
- `onboard-foss-project.md` — setting up a new FOSS project
- `release.md` — releasing a new version
- `upstream-sync.md` — checking upstream for new releases
- `upstream-contribute.md` — contributing patches back upstream
- `security-scan.md` — running all security scans
- `go-dependency-patch.md` — Go-specific CVE patching
- `monorepo-add-project.md` — adding a subproject in monorepo mode

## Code Style

- Shell scripts: POSIX-compatible where possible, `set -euo pipefail` at top
- Dockerfiles: multi-stage, `ARG` before `FROM` for build args, pinned base images
- YAML: 2-space indent, quoted strings for values that could be misinterpreted
- Helm: follow existing templates in `helm/templates/`

---

*Synced to CONSTITUTION.md v1.5.0 | Updated: 2026-03-26*
