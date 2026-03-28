# Skill: Build Strategy Switch

Switch between source build (priority) and binary fallback — or back again.

## Purpose
Atomically flip `BUILD_STRATEGY` across all affected config files and document the reason.
This is always a temporary state — binary fallback must be reversed as soon as source is ready.

## Prerequisites
- Tech lead approval to activate binary fallback (not required to revert to source)
- Documented reason for the switch

## Steps

### Switching to Binary Fallback

#### Step 1 — Confirm Approval
Ask user:
1. Reason for switching to binary? (blocked upstream, broken patch, CVE hotfix urgency?)
2. Who approved? (tech lead name)
3. Expected duration? (e.g., 24 hours, until upstream releases fix)
4. Which upstream binary release URL and SHA256?

#### Step 2 — Update Environment Toggle
In `docker-compose.build.yaml`, set default:
```yaml
environment:
  BUILD_STRATEGY: binary
```

In `package.json`:
```json
"scripts": {
  "build": "BUILD_STRATEGY=binary ./build.sh.txt"
}
```

#### Step 3 — Verify Binary Dockerfile
Check `Dockerfile.binary` has correct:
- `ARG BINARY_URL` pointing to the correct upstream binary release
- `ARG BINARY_SHA256` with the correct checksum
- Base image pinned to approved internal registry

#### Step 4 — Update CHANGELOG.md
```markdown
## [BINARY FALLBACK ACTIVATED] - YYYY-MM-DD
- Switched to binary build strategy
- Reason: <reason>
- Approved by: <tech lead>
- Expected duration: <duration>
- Binary source: <URL>
- SHA256: <checksum>
- Revert by: <expected date>
```

#### Step 5 — Create Branch and PR
```bash
git checkout -b chore/activate-binary-fallback-YYYY-MM-DD
git add docker-compose.build.yaml package.json CHANGELOG.md
git commit -m "chore: activate binary fallback — <reason>"
# PR targets main (not release branch — this is operational)
```

---

### Switching Back to Source Build (Revert)

#### Step 1 — Update Toggle
```yaml
# docker-compose.build.yaml
environment:
  BUILD_STRATEGY: source
```

```json
// package.json
"build": "BUILD_STRATEGY=source ./build.sh.txt"
```

#### Step 2 — Update CHANGELOG.md
```markdown
## [SOURCE BUILD RESTORED] - YYYY-MM-DD
- Reverted to source build strategy
- Binary fallback was active for: <duration>
```

#### Step 3 — Verify Source Build Passes
```bash
BUILD_STRATEGY=source ./build.sh.txt
# Must pass full pipeline before merging
```

## Validation
- [ ] `docker-compose.build.yaml` reflects correct strategy
- [ ] `package.json` build script reflects correct strategy
- [ ] CHANGELOG updated with reason + approval (for binary) or restoration note (for source)
- [ ] CI pipeline passes with new strategy
- [ ] Both Dockerfiles remain functional (never delete either)

## Related
- Doc: `docs/build-strategy.md`
- Skill: `cve-patch.md` — preferred path instead of activating binary fallback
