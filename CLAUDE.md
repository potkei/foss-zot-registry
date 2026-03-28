# Claude Code — FOSS Boilerplate

> **Read `.agents/CONSTITUTION.md` first.** This file is the Claude Code adapter only.
> Full rules, folder map, team SLAs, patch format, and roadmap live in CONSTITUTION.md.

---

## Critical Rules (quick ref — details in CONSTITUTION.md)

- **Source build always first**: `Dockerfile` / `Dockerfile.go` — never default to binary
- **Runtime image priority**: `scratch` → `distroless` → `*-slim` — never full OS images
- **Version format**: `{upstream}-r{N}` — e.g. `6.0.0-r1` → `6.0.0-r2` → `6.1.0-r1`
- **Hotfix branches**: `hotfix/{upstream_version}-{CVE-ID}` — e.g. `hotfix/6.0.0-CVE-2024-1234`
- **Script files**: `.sh.txt` extension only — enterprise policy blocks `.sh`
- **No `latest` tags** in any Dockerfile — pin to explicit version (`ubuntu:24.04`, `eclipse-temurin:25-jdk-noble`)
- **No push / merge** without explicit human confirmation

---

## Folder Separation (strict)

| Path | Purpose |
|---|---|
| `.cicd/` | CI/CD pipeline only — Jenkins, scan configs, `.env`, secrets |
| `.local/` | Local dev only — compose files, tool Dockerfiles |
| `Dockerfile`, `Dockerfile.go`, `Dockerfile.binary` | Always at repo root — never moved |
| `mkdocs.yml` | Always at repo root — MkDocs auto-discovers it |

`.cicd/scan-versions.env` is shared between local and CI — do not duplicate it.

---

## AI Behavior Directives

| Trigger | Action |
|---|---|
| Asked to build | Default to source build (`Dockerfile`) |
| Asked to run locally | Use `.local/docker-compose.run.yml` |
| Asked to patch a CVE | Branch `hotfix/{version}-{CVE-ID}`, follow `.agents/skills/cve-patch.md` |
| Asked to onboard a new FOSS project | Follow `.agents/skills/onboard-foss-project.md` |
| Asked to switch build strategy | Follow `.agents/skills/build-strategy-switch.md` |
| Asked to release | Follow `.agents/skills/release.md` |
| Asked to sync upstream | Follow `.agents/skills/upstream-sync.md` |
| Asked to contribute patch upstream | Follow `.agents/skills/upstream-contribute.md` |
| Asked to run security scan | Follow `.agents/skills/security-scan.md` |
| Go project CVE in dependency | Follow `.agents/skills/go-dependency-patch.md` |
| Editing a Dockerfile | Preserve all three variants (source, Go, binary) |
| Noticing a `latest` tag | Flag it and suggest current stable pinned version (verify on Docker Hub first) |
| Finding secrets in code | Refuse to commit; alert user immediately |
| Editing `.local/` tool Dockerfiles | Keep `python:*-slim` + `uv` pattern — never fat images |
| Adding a new `.local/` compose service | Add `pull_policy: missing`; add `image:` if `build:` is used |

---

## Programming Language Version Policy

- `latest` **tag** is prohibited — always pin to an explicit version number (`ubuntu:24.04`, not `ubuntu:latest`)
- **Always attempt the latest stable first** — never pre-emptively use an older version
- **Progressive probe on failure**: latest → latest-1 minor → latest-2 minor → … until build passes
  - Floor: never go below the version the upstream FOSS project itself requires
  - If all versions fail: report every attempt + error, then ask user which version to risk
- **Document the probe result** in Dockerfile comment + CHANGELOG: versions tried, errors, chosen version, revisit note
- Never silently pin an old version — always show what was attempted and why it was chosen
- Details and full algorithm: CONSTITUTION.md §Progressive Version Probe

---

## Prohibited

- No unrequested features, refactoring, or "improvements"
- No merge or push without explicit human confirmation
- No bypassing checksum verification or scan gates
- No `latest` tags in any Dockerfile
- No `.sh` / `.py` / `.bat` script files committed (use `.txt`)
- No compose files or tool Dockerfiles placed in `.cicd/`
- No moving `Dockerfile*` out of repo root
- No moving `mkdocs.yml` out of repo root
- No touching `.cicd/docker-resources/secrets/`

---

*Constitution version: 1.5.0 | Last updated: 2026-03-26*
