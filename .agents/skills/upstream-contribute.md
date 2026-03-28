# Skill: Upstream Contribute

Submit one of our CVE patches back to the upstream project as a pull request.

## Purpose
Contribute our fix to upstream so the community benefits, and so we can eventually
drop the patch when upstream ships the fix in a release.

## Prerequisites
- Patch file exists in `patches/` with complete header
- GitHub CLI (`gh`) available
- Write access to a fork of the upstream repository

## Steps

### Step 1 — Select Patch to Contribute
Ask user which patch to contribute (or list patches with `Upstream-PR: NONE`).

Confirm:
1. Patch file name?
2. Upstream repo URL? (e.g., `https://github.com/upstream/project`)
3. Your GitHub username / org for the fork?

### Step 2 — Fork Upstream Repository
```bash
# Fork via GitHub CLI
gh repo fork <upstream_org>/<upstream_repo> --clone --remote
cd <upstream_repo>
```

### Step 3 — Create Branch on Fork
```bash
git checkout -b fix/CVE-2024-1234
```

### Step 4 — Apply Our Patch
```bash
# Apply the patch to the upstream source (from git, not archive)
git apply /path/to/our/repo/patches/0001-CVE-2024-1234-fix-buffer-overflow.patch
```

If patch does not apply cleanly (upstream git tree differs from archive):
- Manually apply the change to the affected files
- `git diff` to verify the change matches the intent of the patch

### Step 5 — Commit
```bash
git add .
git commit -m "fix: CVE-2024-1234 fix buffer overflow in input handling

This patch fixes a buffer overflow vulnerability in the network input
handler. Without bounds checking, a malicious remote peer can send
oversized input causing heap corruption.

CVE: CVE-2024-1234
CVSS: 9.1 (Critical)
References: https://nvd.nist.gov/vuln/detail/CVE-2024-1234"
```

### Step 6 — Push and Create PR
```bash
git push origin fix/CVE-2024-1234

gh pr create \
  --title "fix: CVE-2024-1234 buffer overflow in input handling" \
  --body "$(cat <<'EOF'
## Summary
Fix a buffer overflow vulnerability in the network input handler (CVE-2024-1234, CVSS 9.1 Critical).

## Problem
Without bounds checking on user-supplied input, a malicious remote peer can send oversized
data causing heap corruption and potential remote code execution.

## Fix
Add bounds checking via `strncpy` with explicit null termination, replacing the unsafe `strcpy` call.

## Testing
- Existing test suite passes
- Added test case with oversized input (see `test/test_network.c`)

## References
- CVE: CVE-2024-1234
- NVD: https://nvd.nist.gov/vuln/detail/CVE-2024-1234
EOF
)"
```

### Step 7 — Update Our Patch Header
After PR is created, update the patch file header:
```patch
# CVE:           CVE-2024-1234
# Upstream-PR:   https://github.com/upstream/project/pull/456   ← add this
# Upstream-Fix:  pending                                          ← update to pending
# Keep-on-sync:  check                                           ← update to check
# Contributed:   2026-03-25                                      ← add date
```

Commit the updated patch header:
```bash
git add patches/0001-CVE-2024-1234-*.patch
git commit -m "chore: update patch header with upstream PR URL"
```

## Validation
- [ ] Upstream fork created and patch applied correctly
- [ ] PR created with clear description including CVE ID and CVSS score
- [ ] Our patch header updated with PR URL and `Contributed` date
- [ ] `Keep-on-sync` changed from `yes` to `check`
- [ ] `Upstream-Fix` changed to `pending`

## Rollback
No rollback needed — upstream PR can simply be closed if the approach changes.
Our patch remains in `patches/` regardless.

## Related
- Skill: `upstream-sync.md` — monitor whether the upstream PR merged
- Skill: `cve-patch.md` — how the patch was originally created
- Doc: `docs/patch-management.md`
