# Skill: Upstream Sync

Check if upstream has released a new version and assess patch compatibility.

## Purpose
Detect upstream drift, read patch headers to determine what to keep/drop/rebase,
and recommend an upgrade path without breaking existing CVE fixes.

## Prerequisites
- `package.json` has current upstream version and archive URL pattern
- `patches/` directory has patch files with correct headers

## Steps

### Step 1 — Check Current Pinned Version
```bash
current=$(jq -r '.upstream.version' package.json)
echo "Currently pinned: $current"
```

### Step 2 — Check Upstream for New Releases
Check the upstream project's release page for newer versions than what is pinned.
Look at:
- GitHub releases page
- Official project download page
- Mailing list / security advisories

Report to user:
```
Current pinned:  6.0.0
Latest upstream: 6.1.0  ← new version available
Security fixes in 6.1.0:
  - CVE-2024-1234 (FIXED) ← we already patched this
  - CVE-2024-9999 (NEW)   ← not in our patches
```

### Step 3 — Read All Patch Headers
For each patch in `patches/*.patch`, read the header and classify:

| Patch | Upstream-Fix | Action |
|---|---|---|
| `0001-CVE-2024-1234` | `fixed-in-6.1.0` | **DROP** when upgrading to 6.1.0 |
| `0002-CVE-2024-5678` | `not-fixed` | **KEEP** — rebase onto new version |
| `0003-NONCVE-custom` | `wont-fix` | **KEEP** — always re-apply |
| `0004-CVE-2024-AAAA` | `pending` | **CHECK** — verify if upstream PR merged |

### Step 4 — Dry-Run Patches Against New Version
```bash
# Download new upstream archive to temp location
curl -L <new_archive_url> -o /tmp/new-source.tar.gz
echo "<new_sha256>  /tmp/new-source.tar.gz" | sha256sum -c

# Extract
tar -xzf /tmp/new-source.tar.gz -C /tmp/

# Dry-run each patch
for p in patches/*.patch; do
  result=$(patch --dry-run -p1 -d /tmp/<source-dir>/ < "$p" 2>&1)
  if echo "$result" | grep -q "FAILED"; then
    echo "❌ NEEDS REBASE: $p"
  elif echo "$result" | grep -q "offset"; then
    echo "⚠️  APPLIES WITH OFFSET: $p (review recommended)"
  else
    echo "✅ APPLIES CLEANLY: $p"
  fi
done
```

### Step 5 — Report & Recommend
Present to user:
```
Upgrade assessment: 6.0.0 → 6.1.0

Patches to DROP (upstream fixed):
  ✅ 0001-CVE-2024-1234 — upstream fixed in 6.1.0

Patches to KEEP (apply cleanly):
  ✅ 0002-CVE-2024-5678 — applies cleanly to 6.1.0

Patches needing REBASE:
  ❌ 0003-NONCVE-custom — upstream changed src/file.c, rebase needed

New CVEs in 6.1.0 already fixed by upstream:
  ✅ CVE-2024-9999 — included in 6.1.0 release

Recommendation:
  Upgrade to 6.1.0, drop patch 0001, rebase patch 0003
  New version will be: 6.1.0-r1
```

### Step 6 — Create Upgrade Branch (if approved)
```bash
git checkout -b chore/upgrade-to-6.1.0
# Update package.json upstream version + URL + SHA256
# Remove dropped patches
# Rebase patches that need it
# Run full dry-run again to confirm all clean
git commit -m "chore: upgrade upstream from 6.0.0 to 6.1.0"
# Open PR targeting release/6.1.0-r1
```

## Validation
- [ ] All patch headers read and classified
- [ ] Dry-run completed against new archive
- [ ] Dropped patches removed
- [ ] Rebased patches verified to apply cleanly
- [ ] `package.json` updated with new version + URL + SHA256
- [ ] CHANGELOG updated with upgrade entry

## Related
- Skill: `cve-patch.md` — if new CVEs found that upstream hasn't fixed
- Skill: `release.md` — after upgrade is merged
- Doc: `docs/patch-management.md`
