# OpenAI Codex Instructions

Read `.agents/CONSTITUTION.md` first — master ruleset for all AI tools in this repo.

## Repository Purpose

Managed fork of a FOSS project. Downloads official release archives, applies CVE patches,
compiles from source, ships patched container images. No git-cloning of upstream.

## Non-Negotiable Rules

- Source build = priority (`Dockerfile` / `Dockerfile.go`). Binary = fallback only.
- Versioning: `{upstream_version}-r{N}` — e.g. `6.0.0-r1`, `6.0.0-r2`, `6.1.0-r1`
- Branches: `release/6.0.0-r1`, `hotfix/6.0.0-CVE-2024-1234`, `feature/description`, `chore/description`
- Scripts stored as `.sh.txt`, `.py.txt`, `.bat.txt` — translate via onboard skill
- No secrets committed. No `latest` base image tags.
- Patch files need complete headers (CVE, Upstream-PR, Keep-on-sync)
- `.local/` = compose files + tool Dockerfiles; `.cicd/` = pipeline only — never mix
- `.local/` compose services: `pull_policy: missing`; add `image:` on services with `build:`
- Python tool images: `python:*-slim` + `uv` from `ghcr.io/astral-sh/uv` — no fat images
- Runtime image priority: `scratch` (static) → `gcr.io/distroless/*` → `*-slim` — full OS images prohibited as runtime base; downgrade needs CHANGELOG entry
- Language auto-detect: `go.mod`→Go, `Cargo.toml`→Rust, `CMakeLists.txt`→C/C++, `pom.xml`→Java, `pyproject.toml`→Python — full table: CONSTITUTION §Language & Build Tool Detection
- Version probe: always try latest stable base image first; step down one minor on failure; floor = upstream's minimum; never silently pin — full algorithm: CONSTITUTION §Progressive Version Probe

## Skills in `.agents/skills/`

`cve-patch.md` | `build-strategy-switch.md` | `onboard-foss-project.md`
`release.md` | `upstream-sync.md` | `upstream-contribute.md`
`security-scan.md` | `go-dependency-patch.md` | `monorepo-add-project.md`

---

*Synced to CONSTITUTION.md v1.5.0 | Updated: 2026-03-26*
