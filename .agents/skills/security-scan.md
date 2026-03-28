# Skill: Security Scan

Run all security scans locally and produce a consolidated report.

## Purpose
Run the full scan stack (CVE, SAST, dependencies, secrets, IaC) using Docker — no installation
required. Supports local stack (auto-setup) and external SonarQube (token mode).

## Prerequisites
- Docker running locally
- Image already built (for container CVE scan)
- For external SonarQube: `SONAR_HOST_URL` and `SONAR_TOKEN` set

## Steps

### Step 1 — Determine Scan Mode
```bash
if [ -n "$SONAR_TOKEN" ] && [ -n "$SONAR_HOST_URL" ]; then
  echo "External SonarQube mode: $SONAR_HOST_URL"
  COMPOSE_FILE="docker-compose.scan.external.yml"
else
  echo "Local stack mode (spinning up SonarQube)"
  COMPOSE_FILE="docker-compose.scan.yml"
fi
```

Or use build.sh:
```bash
./build.sh --scan                          # auto-detect mode
./build.sh --scan --sast                   # SAST only
./build.sh --scan --cve                    # container CVE only
./build.sh --scan --deps                   # dependency check only
SONAR_TOKEN=xxx ./build.sh --scan          # external mode
```

### Step 2 — Run Scans
```bash
docker compose -f $COMPOSE_FILE up --abort-on-container-exit
```

This runs in parallel:
- **Hadolint** — Dockerfile lint (runs first, before build)
- **Checkov** — Helm + Dockerfile IaC misconfiguration
- **Semgrep** — lightweight SAST (no server needed)
- **SonarQube** — full SAST (local or external)
- **Trivy** — container CVE + embedded secrets + SBOM
- **OWASP Dependency-Check** — build dependency CVEs
- **Gitleaks** — secrets in git history

### Step 3 — Review Results

**Reports location:**
```
reports/
    hadolint.txt
    checkov.json
    semgrep.json
    trivy.json
    dependency-check.html    ← open in browser
    gitleaks.json
    scan-summary.txt         ← aggregated pass/fail per tool
```

SonarQube: open `http://localhost:9000` (local mode) or `$SONAR_HOST_URL` (external).

**Reading `scan-summary.txt`:**
```
PASS  hadolint        0 issues
PASS  checkov         0 critical misconfigs
FAIL  trivy           2 HIGH CVEs found (see reports/trivy.json)
PASS  semgrep         0 findings
PASS  dependency-check 0 known CVEs in build deps
PASS  gitleaks        0 secrets found
WARN  sonarqube       Quality gate: see dashboard
```

### Step 4 — Triage Findings

**For Trivy CVE findings:**
1. Check if CVE is in `.trivyignore` (accepted exception with expiry)
2. If new finding — assess severity:
   - Critical/High → invoke `cve-patch.md` skill immediately
   - Medium/Low → add to next release backlog
3. If accepting risk → add to `.trivyignore` with expiry date and justification

**`.trivyignore` format:**
```
# CVE-2024-9999 — false positive, not applicable to our use case
# Accepted by: <name> | Expiry: 2026-06-01 | Ticket: SEC-123
CVE-2024-9999
```

**For SonarQube findings:**
- Critical/Blocker → must fix before release
- Major → fix within 2 sprints
- Minor/Info → backlog

### Step 5 — Update scan-exceptions.yml
For any accepted risks:
```yaml
exceptions:
  - cve: CVE-2024-9999
    reason: "Not applicable — we do not use the vulnerable code path"
    accepted_by: "security-team"
    expiry: "2026-06-01"
    ticket: "SEC-123"
```

## Validation
- [ ] All scans completed (check `reports/scan-summary.txt`)
- [ ] Zero unexcepted Critical/High CVEs
- [ ] SonarQube quality gate passes
- [ ] Any new findings triaged and either patched or documented in exceptions

## Related
- Skill: `cve-patch.md` — if new CVEs found
- Doc: `docs/scanning.md`
- Files: `docker-compose.scan.yml`, `docker-compose.scan.external.yml`, `.trivyignore`
