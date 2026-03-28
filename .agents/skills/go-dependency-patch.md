# Skill: Go Dependency Patch

Handle CVE patching for Go FOSS projects, including dependency CVEs and go.mod updates.

## Purpose
Go projects have special constraints: go.sum cannot be hand-patched, major version bumps
break import paths, and module checksums are verified cryptographically. This skill
covers all Go-specific CVE scenarios.

## Prerequisites
- Language is Go (confirm via `jq -r .upstream.language package.json`)
- Use `Dockerfile.go` not `Dockerfile`
- Go toolchain available inside builder container

## Four CVE Scenarios

---

### Scenario A — CVE in Project's Own Go Code (Easiest)

No special Go handling needed. Patch the `.go` source file normally.

```patch
# CVE:           CVE-2024-1234
# Upstream-PR:   NONE
# Upstream-Fix:  not-fixed
# Keep-on-sync:  yes
# Notes:         Patch .go source directly, go.mod/go.sum unchanged
--- a/internal/handler/http.go
+++ b/internal/handler/http.go
@@ -45,6 +45,7 @@
-    buf := make([]byte, userLen)
+    if userLen > MaxInputSize { return ErrInputTooLarge }
+    buf := make([]byte, userLen)
```

Follow `cve-patch.md` skill exactly. No extra steps.

---

### Scenario B — CVE in a Go Dependency (go.mod update needed)

#### Step 1 — Identify the vulnerable dependency
```bash
# Check which dependency has the CVE
go list -m -json all | jq '.Path + "@" + .Version'
# Find the vulnerable one: e.g. golang.org/x/net@v0.17.0
```

#### Step 2 — Create go.mod patch
```patch
# CVE:           CVE-2024-5678
# Upstream-PR:   NONE
# Upstream-Fix:  not-fixed
# Keep-on-sync:  yes
# Notes:         Bumps golang.org/x/net to fix CVE. go.sum regenerated in Dockerfile.
--- a/go.mod
+++ b/go.mod
@@ -12,7 +12,7 @@
-    golang.org/x/net v0.17.0
+    golang.org/x/net v0.20.0
```

#### Step 3 — Create go.sum skip marker
Create a `.skip` marker file alongside the patch:
```bash
touch patches/0002-CVE-2024-5678-gosum-regen.skip
```
This tells the Dockerfile patch loop that go.sum will be regenerated, not patched.

#### Step 4 — Dockerfile.go handles go.sum regeneration
The `Dockerfile.go` handles this automatically:
```dockerfile
# After applying patches, check if go.mod was changed
RUN if ls /patches/*gomod*.patch /patches/*go-mod*.patch 2>/dev/null | head -1; then \
      GONOSUMCHECK=* GOFLAGS=-mod=mod go mod tidy && \
      echo "go.sum regenerated after go.mod patch"; \
    fi
```

#### Step 5 — Name patches consistently
```
patches/
    0002-CVE-2024-5678-gomod-bump-golang-x-net.patch   ← contains go.mod change only
    0002-CVE-2024-5678-gosum-regen.skip                 ← marker for Dockerfile
```

---

### Scenario C — Use go.mod replace directive (Preferred for dependency CVE)

When you cannot or do not want to bump the dependency version globally.

#### Step 1 — Create patch that adds replace directive
```patch
# CVE:           CVE-2024-5678
# Upstream-PR:   NONE
# Upstream-Fix:  not-fixed
# Keep-on-sync:  yes
# Notes:         Uses replace directive to point at our patched fork of x/net
--- a/go.mod
+++ b/go.mod
@@ -25,3 +25,7 @@
+
+replace (
+    golang.org/x/net => github.com/our-org/x-net-patched v0.17.0-r1
+)
```

#### Step 2 — Maintain the patched fork
Our fork of the dependency (`github.com/our-org/x-net-patched`) follows the same
boilerplate structure — it is itself a managed fork of the Go dependency.

#### Step 3 — Document in patch header
```patch
# Notes: Uses replace directive. Our fork: github.com/our-org/x-net-patched
#        Drop replace when upstream x/net releases fix and project upgrades.
```

---

### Scenario D — Vendor the Dependency (Last Resort)

When replace directive is also blocked (e.g., upstream explicitly disallows it).

#### Step 1 — Vendor
```bash
go mod vendor
# Copy patched version of the dependency into vendor/
cp -r /patched-dep/golang.org/x/net vendor/golang.org/x/net
```

#### Step 2 — Add vendor directory changes as patch
```patch
# CVE:           CVE-2024-5678
# Notes:         Vendors golang.org/x/net with CVE fix applied inline.
#                MAINTENANCE BURDEN: must update vendor/ on every upstream sync.
#                Prefer Scenario B or C when possible.
--- a/vendor/golang.org/x/net/http2/transport.go
+++ b/vendor/golang.org/x/net/http2/transport.go
@@ -100,6 +100,7 @@
 ...
```

---

### Major Version Bump Blocked

If upstream is slow to release `v2` but CVE requires it:

1. **Backport the fix to current major** — apply CVE fix without bumping major (preferred)
2. Document in patch header:
```patch
# Notes: Major bump blocked — backporting CVE fix to v1.x
#        Tech lead approval: <name> on YYYY-MM-DD
#        Revisit when upstream releases v2 or CVE fix lands in v1.x
```

Never force a major version bump in a fork — it breaks all import paths for consumers.

## Validation
- [ ] Correct Dockerfile variant used (`Dockerfile.go`)
- [ ] go.sum regenerated (not hand-patched)
- [ ] `.skip` marker created for any go.mod patches
- [ ] Build compiles successfully with patched dependency
- [ ] `go mod verify` passes inside container
- [ ] Trivy confirms CVE no longer present in image

## Related
- Skill: `cve-patch.md` — base patch workflow
- Doc: `docs/go-projects.md`
