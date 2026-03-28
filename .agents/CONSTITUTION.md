# AI Constitution — Shared (All AI Tools)

> This is the master constitution for all AI assistants operating in this repository.
> Claude Code → also read `CLAUDE.md` at repo root.
> GitHub Copilot → also read `.github/copilot-instructions.md`.
> Cursor → also read `.cursor/rules/main.mdc`.
> Windsurf → also read `.windsurfrules` at repo root.
> OpenAI Codex → also read `.codex/instructions.md`.

---

## What This Repository Is

A managed fork of an open source project. We download official release archives (tarball/zip),
apply our own CVE security patches, compile from source, and ship container images — faster
than upstream can release fixes.

**We do NOT git-clone upstream. We download official release archives only.**

---

## Non-Negotiable Rules (All AI Tools)

### 1. Build Priority

Source build (`Dockerfile` / `Dockerfile.go`) is ALWAYS preferred.
Binary (`Dockerfile.binary`) is FALLBACK only — temporary, documented in CHANGELOG.
Never delete either Dockerfile.

**Source build flow:**
```
Download archive → verify SHA256 (+ GPG optional) → extract
→ apply patches in order → compile → runtime image (approved base)
```

Binary fallback requires tech lead approval + CHANGELOG entry.
Single toggle: `BUILD_STRATEGY=source|binary` controls CI, local, and Helm consistently.

### 2. Versioning

Format: `{upstream_version}-r{N}` — examples: `6.0.0-r1`, `6.0.0-r2`, `6.1.0-r1`

- Revision resets to `r1` when upstream version changes
- Git tag = Docker tag = Helm `appVersion` = `package.json` version (all must match)
- CHANGELOG entry must map each `-rN` to the CVE ID(s) it addresses
- Go projects: `go.sum` is never hand-patched — always regenerated via `go mod tidy` in Dockerfile

### 3. Branch Names

```
main                          ← stable, always deployable
release/6.0.0-r1              ← name matches version tag exactly
hotfix/6.0.0-CVE-2024-1234   ← CVE patch → PR targets matching release branch
hotfix/6.0.0-fix-description ← non-CVE hotfix
feature/description           ← features → PR targets main or release branch
chore/description             ← maintenance → PR targets main
```

Hotfix naming: `hotfix/{upstream_version}-{CVE-ID}` — version prefix makes the target release
line immediately clear. Multiple CVEs: `hotfix/6.0.0-CVE-2024-1234-CVE-2024-5678`.
No direct push to `main`.

**Merge flow:**
```
hotfix/6.0.0-CVE-2024-1234 → PR + review + security sign-off → release/6.0.0-r2
                                                                       ↓ full pipeline passes
                                                                     main ← tag 6.0.0-r2
```

### 4. Script Files

All shell/Python/batch scripts stored with `.txt` extension: `build.sh.txt`, `scan.py.txt`.
Enterprise security policy blocks executable extensions.
When onboarding or running for the first time, the `onboard-foss-project` skill translates
them back to original extensions and sets executable permissions.
**Never rename `.txt` back to `.sh`/`.py`/`.bat` manually — use the skill.**

### 5. Secrets

- Never commit secrets, credentials, tokens, or keys
- `.cicd/docker-resources/secrets/` is mount-only and fully gitignored
- No secrets in build args — use Docker secrets or runtime environment injection
- If you see a secret in code, stop and alert the user

### 6. Patches

**Naming:** `patches/0001-CVE-2024-1234-fix-description.patch`

**Required header in every patch file:**
```
# CVE:           CVE-2024-1234
# Upstream-PR:   https://github.com/upstream/pull/456  (or NONE / pending)
# Upstream-Fix:  not-fixed | fixed-in-6.2.0 | wont-fix | pending
# Keep-on-sync:  yes | no | check
# Contributed:   YYYY-MM-DD  (date we submitted upstream PR)
# Notes:         Drop when upgrading to >= 6.2.0
```

`Keep-on-sync` values: `no` = upstream fixed it (drop on upgrade), `yes` = custom (always re-apply),
`check` = upstream PR open (verify on sync).

Never skip checksum verification of upstream archives.

**Patch application in Dockerfile:**
```dockerfile
RUN for p in $(ls /patches/*.patch | sort); do patch -p1 < "$p" || exit 1; done
```

### 7. Confirmations Required

- Never push to remote without explicit human confirmation
- Never merge PRs without explicit human confirmation
- Never activate binary fallback without tech lead approval

### 8. Local Dev Tooling

- All local compose files and tool Dockerfiles live in `.local/` — never in `.cicd/`
- `.cicd/` is for CI/CD pipeline config only (Jenkins, scan configs, scripts, secrets)
- `scan-versions.env` and `scan-exceptions.yml` stay in `.cicd/` — shared between local and CI
- All `.local/` compose services must use `pull_policy: missing`
- Build-based services must declare `image: foss-*:local` for local image caching

### 9. Python Tool Images

- Tool images (checkov, semgrep, mkdocs-material) use `python:*-slim` + `uv`
- `uv` binary copied from `ghcr.io/astral-sh/uv` — never installed via pip
- Version pinned via `ARG` in Dockerfile + build arg in compose

### 10. Security Mandates

- Base image versions pinned — no `latest` tags in Dockerfiles
- All images must pass CVE scan before push; exceptions in `.cicd/scan-exceptions.yml` with expiry
- SBOM generated on every release via Syft (CycloneDX format), attached as image attestation
- Images signed on every release via Cosign
- GPG signature verified for upstream archives where available

### 11. Runtime Image Policy (priority order)

Runtime stages must use the smallest possible base to minimise CVE surface:

| Priority | Base | When to use |
|---|---|---|
| 1 — preferred | `scratch` | Compiled binaries (Go static, C/C++ static) or JVM with jlink + copied JRE/glibc |
| 2 — fallback | `gcr.io/distroless/*` | When scratch is impractical (e.g. complex dynamic linking, missing /proc requirements) |
| 3 — last resort | `*-slim` / Alpine | Only when distroless is blocked by a documented dependency; requires CHANGELOG entry |
| ✗ prohibited | Full OS images | Never use ubuntu, debian, ubi, jammy, etc. as runtime base |

**JVM projects:** use `jlink` to produce a custom minimal JRE, copy it plus all `ldd`-resolved shared
libraries into `scratch`. Non-root execution via numeric UID (`USER 10001:10001`) — no `useradd`
in scratch.

**Go projects:** compile with `CGO_ENABLED=0 GOOS=linux` to produce a fully static binary, then
`FROM scratch` with only the binary, CA certs, and a minimal `/etc/passwd`.

Downgrading from scratch → distroless → slim requires a CHANGELOG entry explaining why scratch
was not feasible.

---

## Team Rules

### Review & Approval

- Minimum 1 reviewer approval before merge to any branch
- CVE patches require security team sign-off before merge to release branch
- Binary fallback activation requires tech lead approval + CHANGELOG entry

### CVE Response SLA

| Severity | CVSS | Patch SLA | Binary fallback if blocked |
|---|---|---|---|
| Critical | ≥ 9.0 | 24 hours | Yes |
| High | 7.0–8.9 | 72 hours | After 72h |
| Medium | 4.0–6.9 | Next release | No |
| Low | < 4.0 | Next release | No |

### Dependency Blocker & Cooldown

- Document blocker in CHANGELOG under `[BLOCKED]`: CVE ID, blocking dep, expected resolution, owner
- Wait 72 hours after upstream publishes before adopting (let community surface regressions)
- Exception: critical CVE — adopt immediately after checksum verified
- If blocker resolves: re-run full pipeline from scratch (no cached layers)

### Re-run Tests When Changed

| Changed path | Action |
|---|---|
| `patches/**` | Full source build + all tests |
| `Dockerfile` or `Dockerfile.go` | Full source build + all tests |
| `Dockerfile.binary` | Binary build + all tests |
| `helm/**` | Helm lint + deploy test |
| `.cicd/docker-resources/scripts/**` | All pipeline stages |
| `.cicd/scan-versions.env` | Re-run all scans with new scanner versions |
| `.local/Dockerfile.*` | Rebuild affected tool image + re-run its scan stage |
| `.local/docker-compose.*.yml` | Validate compose config + smoke test affected stack |
| `projects/<name>/**` (monorepo) | That subproject's pipeline only |

Always re-run full pipeline when: merging to `main`, applying CVE patch, switching `BUILD_STRATEGY`.
Never skip tests — do not use `--no-verify`, skip flags, or bypass scan gates.

---

## Skill Directory

| Need | Skill File |
|---|---|
| Apply a CVE patch | `.agents/skills/cve-patch.md` |
| Switch source ↔ binary build | `.agents/skills/build-strategy-switch.md` |
| Onboard a new FOSS project | `.agents/skills/onboard-foss-project.md` |
| Release a new version | `.agents/skills/release.md` |
| Check upstream for new version | `.agents/skills/upstream-sync.md` |
| Contribute patch back to upstream | `.agents/skills/upstream-contribute.md` |
| Run security scans | `.agents/skills/security-scan.md` |
| Patch a Go dependency CVE | `.agents/skills/go-dependency-patch.md` |
| Add project to monorepo | `.agents/skills/monorepo-add-project.md` |

---

## Folder Map

```
.agents/skills/     Shared AI runbooks (all tools)
.claude/commands/   Claude Code slash commands
.github/            Copilot instructions, workflows, PR templates
.cursor/rules/      Cursor rules
.codex/             Codex instructions
.windsurfrules      Windsurf rules (root file)
.cicd/              CI/CD pipeline only — Jenkins, scan configs, scripts (.txt), secrets
  scan-versions.env     Scanner version pins (shared: local + CI)
  scan-exceptions.yml   Accepted CVE exceptions with expiry (CI-enforced)
  jenkins_config.yml    Jenkins pipeline definition
  docker-resources/     Scripts (.sh.txt) and secrets (mount-only, gitignored)
.local/             Local dev tooling — compose files + tool Dockerfiles (NOT CI/CD)
  docker-compose.build.yaml       Build product image locally
  docker-compose.run.yml          Run product image locally after build
  docker-compose.scan.yml         Full local scan stack (SonarQube + all scanners)
  docker-compose.scan.external.yml  Connect to external SonarQube
  docker-compose.registry.yml     Local OCI registry (registry:2) + UI
  docker-compose.docs.yml         Serve MkDocs documentation
  Dockerfile.docs                 MkDocs Material built via uv
  Dockerfile.checkov              Checkov built via uv
  Dockerfile.semgrep              Semgrep built via uv
docs/               MkDocs documentation content (mkdocs.yml stays at root)
helm/               Kubernetes Helm chart
patches/            CVE patch files (source build only)
projects/           Monorepo subprojects (if applicable)
reports/            Scan output — gitignored
Dockerfile          Product source build — C/generic (PRIORITY)
Dockerfile.go       Product source build — Go-specific (PRIORITY)
Dockerfile.binary   Product binary fallback
mkdocs.yml          MkDocs config (root — auto-discovered by mkdocs)
build.sh            Main entrypoint: build / scan / release / docs / registry / push-local
Makefile            Shortcut aliases for build.sh and compose commands
init.sh             First-run setup — run once after repo creation from template
```

---

## Monorepo Addendum

When operating in monorepo mode (`projects/` directory exists):
- Root `CLAUDE.md` governs all subprojects
- Subprojects may have their own `CLAUDE.md` to override project-specific rules only
- Root `.cicd/` provides shared scripts; subproject `.cicd/` extends them
- CI detects monorepo mode by presence of `projects/` and generates parallel stages
- Run `make onboard` or `./projects/build-all.sh --add` to add a new subproject

---

## Language & Build Tool Detection

When onboarding a project, the AI must auto-detect the language and build tool from
the upstream archive contents or repository — **never ask the user unless ambiguous**.

### Detection Signals

Inspect the archive listing (`tar -tzf archive.tar.gz | head -60`) or the upstream
source tree. Match the first signal found, top-to-bottom:

| Signal file(s) in source root | Language | Build tool | Dockerfile to use |
|---|---|---|---|
| `go.mod` | Go | `go build` | `Dockerfile.go` |
| `Cargo.toml` | Rust | `cargo build` | `Dockerfile` (generic) |
| `CMakeLists.txt` | C/C++ | CMake + Ninja/Make | `Dockerfile` |
| `configure` or `configure.ac` | C/C++ | Autotools → Make | `Dockerfile` |
| `Makefile` (no other signal) | C/C++ | Make | `Dockerfile` |
| `meson.build` | C/C++ | Meson + Ninja | `Dockerfile` |
| `pom.xml` | Java | Maven | `Dockerfile` |
| `build.gradle` or `build.gradle.kts` | Java/Kotlin | Gradle | `Dockerfile` |
| `pyproject.toml` | Python | uv / poetry / hatch | `Dockerfile` |
| `setup.py` (no `pyproject.toml`) | Python | setuptools | `Dockerfile` |
| `package.json` + `node_modules` absent | Node.js | npm / yarn / pnpm | `Dockerfile` |
| `Gemfile` | Ruby | Bundler + Rake | `Dockerfile` |
| `*.csproj` or `*.sln` | .NET/C# | dotnet | `Dockerfile` |
| `composer.json` | PHP | Composer | `Dockerfile` |

### Builder Base Images

**Rule: Always pin to the current stable version number — never use `latest` tag, never silently pin an old version.**

`ubuntu:latest` → **prohibited**. `ubuntu:24.04` → **required** (pinned to current LTS).

Before writing any Dockerfile, verify the current stable release of each base image:

| Build tool | Builder base pattern | How to verify current stable |
|---|---|---|
| Go | `golang:<X.Y.Z>-bookworm` | https://hub.docker.com/_/golang — match upstream `go.mod` `go` directive |
| Rust | `rust:<X.Y.Z>-slim-bookworm` | https://hub.docker.com/_/rust — match upstream `Cargo.toml` edition |
| CMake / Autotools / Make / Meson | `ubuntu:<YY.MM>` (current LTS) | https://hub.docker.com/_/ubuntu — use current LTS e.g. `24.04` |
| Maven | `maven:<X.Y.Z>-eclipse-temurin-<N>` | https://hub.docker.com/_/maven — match upstream `pom.xml` Java version |
| Gradle | `gradle:<X.Y>-jdk<N>` | https://hub.docker.com/_/gradle — match upstream `build.gradle` sourceCompatibility |
| Python | `python:<X.Y>-slim-bookworm` | https://hub.docker.com/_/python — match upstream `pyproject.toml` `requires-python` |
| Node.js | `node:<X.Y.Z>-bookworm-slim` | https://hub.docker.com/_/node — match upstream `package.json` `engines.node` |
| Java (runtime) | `eclipse-temurin:<N>-jre-noble` | https://hub.docker.com/_/eclipse-temurin — use current LTS or latest GA JDK |

### Progressive Version Probe

Always try **latest stable** first; step down one minor version on each build failure; floor = upstream's own minimum requirement. Never silently pin an old version.

**Steps:** latest → build → pass? done, record in Dockerfile comment + CHANGELOG → fail? note error, step down → repeat until pass or floor hit → if all fail: report every version + error, ask user.

**Record on fallback** (Dockerfile comment + CHANGELOG):
```dockerfile
# Base: python:3.12-slim-bookworm
# Attempted: 3.14 (error: ...), 3.13 (error: ...)
# Pinned 3.12 — first version that compiles cleanly. Revisit when upstream supports 3.13+.
```

### Builder Stage Package Installs

Install only what the detected build system needs — no blanket dev toolchains. Always append `&& rm -rf /var/lib/apt/lists/*`. Examples: CMake needs `cmake make gcc g++`; Autotools needs `autoconf automake libtool make gcc g++`; Meson needs `meson ninja-build gcc g++`.

### When to Ask the User

Ask **only** if: no detection signal found (try one level deeper first), two conflicting signals present, or detected tool requires an explicit version pin. Otherwise auto-detect and report.

---

## Future Roadmap

Items planned but not yet implemented. AI tools must NOT implement these speculatively.

**Near-term:**
- Multi-arch builds — `linux/amd64` + `linux/arm64` via BuildKit `--platform`
- Automated upstream sync — scheduled CI job detecting new upstream releases, opening PRs
- SBOM diff on PRs — compare SBOM between base and PR to surface new dependencies
- `.local/docker-compose.run.override.yml` pattern — per-project runtime config override

**Medium-term:**
- Reusable GitHub Actions — extract CI steps into composite actions for downstream repos
- Helm chart testing — `helm unittest` + `ct lint` in CI pipeline
- Image provenance attestation — full SLSA level 2 via `slsa-github-generator`
- Dependabot for scanner versions — auto-PR on new scanner image releases

**Long-term:**
- Policy-as-code — OPA/Conftest policies for Helm + Dockerfile compliance checks
- VEX documents — Vulnerability Exploitability eXchange alongside SBOM attestations
- Air-gapped registry mode — all tool images mirrored to internal registry before use
- Template sync bot — propagate template fixes to downstream repos via automated PRs

---

*Version: 1.5.0 | Updated: 2026-03-26*
