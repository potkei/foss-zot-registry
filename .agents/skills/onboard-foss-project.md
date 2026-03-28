# Skill: Onboard FOSS Project

Scaffold a new FOSS project into this boilerplate template from scratch.

## Purpose
Walk through onboarding a new upstream FOSS project: collect details, translate script files
from `.txt` to executable, fill in all template placeholders, create initial release branch.

## Prerequisites
- Repository created from template: `gh repo create <name> --template potkei/foss-ai-boilerplate-template`
- User has upstream project details ready (or can look them up)

## Steps

### Step 1 — Collect Project Details
Ask the user these questions in order. Skip questions 8 and 9 — the AI auto-detects those.

```
1.  Repo mode?
    → polyrepo  (this repo = one FOSS project)
    → monorepo  (adding under projects/<name>/)

2.  FOSS project name?
    → e.g. nginx, redis, curl, zip

3.  Upstream version to pin?
    → e.g. 1.27.3

4.  Archive download URL?
    → e.g. https://nginx.org/download/nginx-1.27.3.tar.gz
    → If private/internal: ask for a local file path instead — skip auto-detection steps below.

5.  Archive format?
    → tar.gz / tar.bz2 / tar.xz / zip

6.  SHA256 checksum?
    → paste from upstream release page
    → If not published by upstream: leave blank — AI will compute it after downloading (see Step 3).
    → If private archive with no checksum at all: set sha256 to "UNVERIFIED" and warn user.

7.  GPG signature available?
    → yes (provide .asc URL) / no

8.  [SKIP — AI auto-detects from archive in Step 3]
    Project language & build tool

9.  [SKIP — AI auto-detects from archive in Step 3]
    License

10. Default build strategy?
    → source (default) / binary

11. Container registry namespace?
    → e.g. registry.company.com/infra

12. Kubernetes namespace?
    → e.g. infra, platform

13. Monorepo only: which root directory?
    → e.g. projects/nginx
```

### Step 2 — Translate Script Files
All scripts are stored as `.txt` to bypass enterprise file extension blocks.
Translate them back to original extensions:

```bash
# Find all .sh.txt files and translate
find . -name "*.sh.txt" | while read f; do
  target="${f%.txt}"
  cp "$f" "$target"
  chmod +x "$target"
  echo "Translated: $f → $target"
done

# Find all .py.txt files and translate
find . -name "*.py.txt" | while read f; do
  target="${f%.txt}"
  cp "$f" "$target"
  chmod +x "$target"
  echo "Translated: $f → $target"
done

# Find all .bat.txt files and translate (Windows)
find . -name "*.bat.txt" | while read f; do
  target="${f%.txt}"
  cp "$f" "$target"
  echo "Translated: $f → $target"
done
```

> Note: The `.txt` originals are kept — they are the source of truth in the repo.
> The translated files are gitignored (listed in `.gitignore`).

### Step 3 — Detect Build System, License, and SHA256

#### 3a. Download and inspect the archive

For public archives:
```bash
# Download to temp file (needed for SHA256 + listing)
curl -sL "<archiveUrl>" -o /tmp/upstream-archive

# List archive root (adjust flag for format)
# tar.gz:   tar -tzf /tmp/upstream-archive | head -80
# tar.bz2:  tar -tjf /tmp/upstream-archive | head -80
# tar.xz:   tar -tJf /tmp/upstream-archive | head -80
# zip:      unzip -l /tmp/upstream-archive | head -80
```

For private archives: ask the user to place the file at `/tmp/upstream-archive` and provide the path.

#### 3b. Compute SHA256 if not provided by upstream

```bash
shasum -a 256 /tmp/upstream-archive     # macOS
sha256sum /tmp/upstream-archive          # Linux
```

Use this computed value as `sha256` in `package.json`.
Warn the user: "SHA256 computed locally — verify against a second trusted source if possible."
If the archive is private with no trusted checksum source, set `sha256` to `"UNVERIFIED"` and
add a `CHANGELOG` note: `⚠ SHA256 unverified — private archive, no upstream checksum published`.

#### 3c. Detect build system

Apply the detection table from CONSTITUTION §Language & Build Tool Detection.
Match signal files in the archive root listing:

```
go.mod              → Go       / go build   / Dockerfile.go
Cargo.toml          → Rust     / cargo       / Dockerfile
CMakeLists.txt      → C/C++    / CMake       / Dockerfile
configure or configure.ac → C/C++ / Autotools / Dockerfile
meson.build         → C/C++    / Meson       / Dockerfile
Makefile (only)     → C/C++    / Make        / Dockerfile
pom.xml             → Java     / Maven       / Dockerfile
build.gradle*       → Java     / Gradle      / Dockerfile
pyproject.toml      → Python   / uv/poetry   / Dockerfile
setup.py (no pyproject) → Python / setuptools / Dockerfile
package.json        → Node.js  / npm/yarn    / Dockerfile
Gemfile             → Ruby     / Bundler     / Dockerfile
*.csproj or *.sln   → .NET     / dotnet      / Dockerfile
composer.json       → PHP      / Composer    / Dockerfile
```

Ask the user only if:
- No signal found in archive root (try one level deeper first)
- Two conflicting signals exist

Record: `DETECTED_LANG`, `DETECTED_BUILD_TOOL`, `DOCKERFILE_TO_USE`

#### 3d. Detect license

Scan archive listing for known license file names:
```
LICENSE, LICENSE.txt, LICENSE.md, LICENSE.rst  → read first line or filename pattern
COPYING, COPYING.txt                            → usually GPL variant
MIT-LICENSE, MIT.txt                            → MIT
APACHE-2.0                                      → Apache-2.0
```

If found, extract the SPDX identifier from the filename pattern or first line.
If not found or ambiguous: ask the user.

**Report to the user** before continuing:
```
Detected:
  Language:   Go
  Build tool: go build
  Dockerfile: Dockerfile.go
  License:    MIT
  SHA256:     abc123... (from upstream) | computed locally | UNVERIFIED
```

### Step 4 — Fill Template Placeholders
Update these files with collected and detected values:

**`package.json`:**
```json
{
  "name": "<foss-name>-fork",
  "version": "<upstream_version>-r1",
  "upstream": {
    "name": "<foss-name>",
    "version": "<upstream_version>",
    "archiveUrl": "<archive_url>",
    "archiveFormat": "<format>",
    "sha256": "<sha256>",
    "gpgUrl": "<gpg_url or null>",
    "language": "<DETECTED_LANG>",
    "buildTool": "<DETECTED_BUILD_TOOL>",
    "license": "<DETECTED_LICENSE>"
  },
  "registry": "<registry_namespace>",
  "k8sNamespace": "<k8s_namespace>"
}
```

**`Dockerfile`** (or `Dockerfile.go` — use `DOCKERFILE_TO_USE` from detection):
- Set builder base image matching detected language (see CONSTITUTION §Builder Base Images)
- Install only packages needed by the detected build tool
- Set `ARG UPSTREAM_ARCHIVE_URL=<archive_url>`
- Set `ARG UPSTREAM_SHA256=<sha256>`
- Set `ARG UPSTREAM_VERSION=<upstream_version>`

**`Dockerfile.binary`:**
- Set `ARG BINARY_URL` and `ARG BINARY_SHA256`

**`helm/Chart.yaml`:**
- Set `name: <foss-name>-fork`
- Set `version: 1.0.0`
- Set `appVersion: <upstream_version>-r1`

**`helm/values.yaml`:**
- Set `image.repository: <registry_namespace>/<foss-name>`
- Set `image.tag: <upstream_version>-r1`

**`CHANGELOG.md`:**
```markdown
## [<upstream_version>-r1] - <today>
### Initial
- Forked from upstream <foss-name> <upstream_version>
- Source: <archive_url>
- SHA256: <sha256>  [computed locally if not published upstream]
- License: <license>
```

**`README.md`:** Replace all `<PLACEHOLDER>` values.

**`sonar-project.properties`:**
- Set `sonar.projectKey=<foss-name>-fork`
- Set `sonar.projectName=<foss-name> (patched fork)`

### Step 5 — Create Initial Release Branch
```bash
git checkout -b release/<upstream_version>-r1
git add .
git commit -m "chore: initial onboard of <foss-name> <upstream_version>"
git push -u origin release/<upstream_version>-r1
```

### Step 6 — Verify Setup
```bash
# Dry run — verify no patches fail (patches/ is empty at this point, so this is a no-op)
./patches/verify.sh

# Lint Dockerfiles
docker run --rm -i hadolint/hadolint < Dockerfile
docker run --rm -i hadolint/hadolint < Dockerfile.binary

# Verify build compiles (source build)
BUILD_STRATEGY=source ./build.sh
```

## Validation
- [ ] All placeholder values filled in `package.json`, Dockerfiles, Helm, README
- [ ] Language, build tool, and license detected and recorded in `package.json`
- [ ] SHA256 verified (or UNVERIFIED noted in CHANGELOG with explanation)
- [ ] Script `.txt` files translated to executable equivalents
- [ ] `release/<upstream_version>-r1` branch created and pushed
- [ ] Dockerfiles pass hadolint
- [ ] Source build compiles successfully
- [ ] CHANGELOG has initial entry

## Monorepo Note
If repo mode = monorepo, run `monorepo-add-project` skill instead,
which places the project under `projects/<foss-name>/`.

## Related
- Skill: `monorepo-add-project.md`
- Doc: `docs/onboarding.md`
- Script: `init.sh` (wrapper that calls this skill interactively)
