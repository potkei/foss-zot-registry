# Skill: Release

Perform a full release: version bump, SBOM, image signing, CHANGELOG, git tag, push.

## Purpose
Bump the revision, generate SBOM attestation, sign the image, update all version references,
create git tag, and push to registry. Releases only happen from `main` after `release/*` merges.

## Prerequisites
- All CVE patches applied and merged to `release/<version>-rN` branch
- CI pipeline passing on release branch
- Cosign and Syft available (via scan compose or installed)
- Registry credentials configured in `.cicd/docker-resources/secrets/registry-credentials.env`

## Steps

### Step 1 — Confirm Release Details
Ask the user:
1. Current upstream version? (e.g., `6.0.0`)
2. Current revision? (e.g., `r2`) — or determine from `package.json`
3. Is this a new upstream version bump or a new revision? (determines version string)
4. CVE IDs included in this release?

Determine new version:
```bash
# Read current from package.json
current=$(jq -r .version package.json)
# e.g. "6.0.0-r1" → new version = "6.0.0-r2"
```

### Step 2 — Bump Version Everywhere
Update all version references atomically:

**`package.json`:** `"version": "6.0.0-r2"`

**`helm/Chart.yaml`:**
```yaml
version: 1.0.1        # chart version (bump patch)
appVersion: 6.0.0-r2  # app version = our version format
```

**`helm/values.yaml`:**
```yaml
image:
  tag: 6.0.0-r2
  buildStrategy: source   # or binary — whichever is active
  upstreamVersion: 6.0.0
```

### Step 3 — Update CHANGELOG.md
```markdown
## [6.0.0-r2] - YYYY-MM-DD
### Security
- Fix CVE-2024-1234 (CVSS 9.1 Critical) — buffer overflow in input handling
- Fix CVE-2024-5678 (CVSS 7.5 High) — path traversal in file handler
### Build
- Build strategy: source
- Base image: registry.company.com/base/ubuntu:22.04-20240301
- Upstream archive: https://example.com/releases/6.0.0.tar.gz
- Archive SHA256: abc123...
```

### Step 4 — Build Final Image
```bash
BUILD_STRATEGY=source IMAGE_TAG=6.0.0-r2 ./build.sh
```

### Step 5 — Generate SBOM
```bash
# Generate CycloneDX SBOM
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  anchore/syft:latest \
  packages <image>:6.0.0-r2 \
  -o cyclonedx-json > reports/sbom-6.0.0-r2.cdx.json

# Attach SBOM as image attestation
cosign attest --predicate reports/sbom-6.0.0-r2.cdx.json \
  --type cyclonedx <image>:6.0.0-r2
```

### Step 6 — Sign Image
```bash
cosign sign <registry>/<image>:6.0.0-r2
```

### Step 7 — Run Final Scan
```bash
./build.sh --scan
# Must pass: zero Critical/High CVEs (unless in .trivyignore with expiry)
```

### Step 8 — Merge and Tag
```bash
# Merge release branch to main
git checkout main
git merge --no-ff release/6.0.0-r2
git tag -s 6.0.0-r2 -m "Release 6.0.0-r2

CVE fixes:
- CVE-2024-1234 (CVSS 9.1 Critical)
- CVE-2024-5678 (CVSS 7.5 High)"

git push origin main
git push origin 6.0.0-r2
```

### Step 9 — Push Image to Registry
```bash
docker push <registry>/<image>:6.0.0-r2
# Promote: dev → staging → prod via Harbor
```

### Step 10 — Update build.lock
```
upstream_version=6.0.0
our_version=6.0.0-r2
archive_url=https://example.com/releases/6.0.0.tar.gz
archive_sha256=abc123...
patches_applied=0001-CVE-2024-1234 0002-CVE-2024-5678
base_image=registry.company.com/base/ubuntu:22.04@sha256:...
build_date=2026-03-25T12:00:00Z
build_strategy=source
sbom=reports/sbom-6.0.0-r2.cdx.json
```

## Validation
- [ ] Version bumped consistently in package.json, helm/Chart.yaml, helm/values.yaml
- [ ] CHANGELOG updated with CVE IDs, CVSS scores, archive URL, SHA256
- [ ] Image built from source (or documented binary fallback reason)
- [ ] SBOM generated and attached as attestation
- [ ] Image signed with Cosign
- [ ] Final CVE scan passes (zero unexcepted Critical/High)
- [ ] Git tag signed and pushed
- [ ] Image pushed to registry
- [ ] build.lock updated

## Related
- Skill: `security-scan.md`
- Skill: `upstream-contribute.md` — submit patches before release if not done
- Doc: `docs/versioning.md`
