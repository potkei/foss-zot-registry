#!/usr/bin/env bats
# =============================================================================
# test_jsonq.bats — jsonq binary compatibility tests
#
# Goal: the Go-built jsonq binary must handle every jq query pattern used
#       across all scripts in this project. Zero failures allowed.
#
# Covers all distinct patterns from .cicd/docker-resources/scripts/*.sh.txt
# =============================================================================

load helpers/setup

setup() {
  JQ="${REPO_ROOT}/.tools/bin/jq"
  if [ ! -x "$JQ" ]; then
    skip "jsonq binary not built — run init.sh first"
  fi

  # Minimal package.json fixture
  PKG_JSON="$(mktemp)"
  cat > "$PKG_JSON" <<'EOF'
{
  "name": "redis-fork",
  "version": "7.2.4-r1",
  "registry": "ghcr.io/example",
  "upstream": {
    "name": "redis",
    "version": "7.2.4",
    "archiveUrl": "https://download.redis.io/releases/redis-7.2.4.tar.gz",
    "sha256": "abc123def456",
    "binaryUrl": "https://example.com/redis-7.2.4-linux-amd64.tar.gz",
    "binarySha256": "def456abc123"
  },
  "scripts": {
    "build": "build-source"
  }
}
EOF

  # Minimal Trivy report fixture
  TRIVY_JSON="$(mktemp)"
  cat > "$TRIVY_JSON" <<'EOF'
{
  "Results": [
    {
      "Target": "redis-fork:7.2.4-r1",
      "Vulnerabilities": [
        {"VulnerabilityID": "CVE-2024-0001", "Severity": "CRITICAL", "PkgName": "openssl", "InstalledVersion": "1.1.1"},
        {"VulnerabilityID": "CVE-2024-0002", "Severity": "HIGH",     "PkgName": "curl",    "InstalledVersion": "7.0.0"},
        {"VulnerabilityID": "CVE-2024-0003", "Severity": "MEDIUM",   "PkgName": "zlib",    "InstalledVersion": "1.2.11"}
      ]
    }
  ]
}
EOF

  # Minimal Gitleaks report fixture
  GITLEAKS_JSON="$(mktemp)"
  cat > "$GITLEAKS_JSON" <<'EOF'
[
  {"RuleID": "aws-access-key", "File": "config.yaml", "StartLine": 42},
  {"RuleID": "generic-password", "File": ".env", "StartLine": 7}
]
EOF

  # Minimal Semgrep report fixture
  SEMGREP_JSON="$(mktemp)"
  cat > "$SEMGREP_JSON" <<'EOF'
{"results": [{"check_id": "rule1"}, {"check_id": "rule2"}]}
EOF
}

teardown() {
  rm -f "$PKG_JSON" "$TRIVY_JSON" "$GITLEAKS_JSON" "$SEMGREP_JSON"
}

# ---------------------------------------------------------------------------
# package.json simple field reads (used in build-source, build-binary, etc.)
# ---------------------------------------------------------------------------

@test "reads .upstream.name from package.json" {
  run "$JQ" -r '.upstream.name' "$PKG_JSON"
  [ "$status" -eq 0 ]
  [ "$output" = "redis" ]
}

@test "reads .upstream.version from package.json" {
  run "$JQ" -r '.upstream.version' "$PKG_JSON"
  [ "$status" -eq 0 ]
  [ "$output" = "7.2.4" ]
}

@test "reads .version from package.json" {
  run "$JQ" -r '.version' "$PKG_JSON"
  [ "$status" -eq 0 ]
  [ "$output" = "7.2.4-r1" ]
}

@test "reads .registry from package.json" {
  run "$JQ" -r '.registry' "$PKG_JSON"
  [ "$status" -eq 0 ]
  [ "$output" = "ghcr.io/example" ]
}

@test "reads .upstream.archiveUrl from package.json" {
  run "$JQ" -r '.upstream.archiveUrl' "$PKG_JSON"
  [ "$status" -eq 0 ]
  [ "$output" = "https://download.redis.io/releases/redis-7.2.4.tar.gz" ]
}

@test "reads .upstream.sha256 from package.json" {
  run "$JQ" -r '.upstream.sha256' "$PKG_JSON"
  [ "$status" -eq 0 ]
  [ "$output" = "abc123def456" ]
}

@test "reads .upstream.binaryUrl from package.json" {
  run "$JQ" -r '.upstream.binaryUrl' "$PKG_JSON"
  [ "$status" -eq 0 ]
  [ "$output" = "https://example.com/redis-7.2.4-linux-amd64.tar.gz" ]
}

@test "reads .upstream.binarySha256 from package.json" {
  run "$JQ" -r '.upstream.binarySha256' "$PKG_JSON"
  [ "$status" -eq 0 ]
  [ "$output" = "def456abc123" ]
}

@test "reads nested .scripts.build from package.json" {
  run "$JQ" -r '.scripts.build' "$PKG_JSON"
  [ "$status" -eq 0 ]
  [ "$output" = "build-source" ]
}

@test "fallback with // operator for missing field" {
  run "$JQ" -r '.upstream.name // .name // "foss-project"' "$PKG_JSON"
  [ "$status" -eq 0 ]
  [ "$output" = "redis" ]
}

# ---------------------------------------------------------------------------
# Trivy JSON report queries (used in scan-cve, scan-aggregate)
# ---------------------------------------------------------------------------

@test "counts CRITICAL vulnerabilities in Trivy report" {
  run "$JQ" '[.Results[].Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length' "$TRIVY_JSON"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

@test "counts HIGH vulnerabilities in Trivy report" {
  run "$JQ" '[.Results[].Vulnerabilities[]? | select(.Severity=="HIGH")] | length' "$TRIVY_JSON"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

@test "formats CRITICAL and HIGH findings from Trivy report" {
  run "$JQ" -r '.Results[].Vulnerabilities[]? | select(.Severity=="CRITICAL" or .Severity=="HIGH") | "\(.Severity) \(.VulnerabilityID) \(.PkgName) \(.InstalledVersion)"' "$TRIVY_JSON"
  [ "$status" -eq 0 ]
  [[ "$output" == *"CRITICAL CVE-2024-0001 openssl 1.1.1"* ]]
  [[ "$output" == *"HIGH CVE-2024-0002 curl 7.0.0"* ]]
}

# ---------------------------------------------------------------------------
# Gitleaks JSON report queries (used in scan-secrets, scan-aggregate)
# ---------------------------------------------------------------------------

@test "counts findings in Gitleaks report using length" {
  run "$JQ" 'length' "$GITLEAKS_JSON"
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
}

@test "formats Gitleaks findings with RuleID and location" {
  run "$JQ" -r '.[] | "  \(.RuleID): \(.File):\(.StartLine)"' "$GITLEAKS_JSON"
  [ "$status" -eq 0 ]
  [[ "$output" == *"aws-access-key: config.yaml:42"* ]]
}

# ---------------------------------------------------------------------------
# Semgrep JSON report queries (used in scan-aggregate)
# ---------------------------------------------------------------------------

@test "counts Semgrep results using .results | length" {
  run "$JQ" '.results | length' "$SEMGREP_JSON"
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
}

# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------

@test "returns exit code 5 on bad filter" {
  run "$JQ" '.nonexistent_fn()' "$PKG_JSON"
  [ "$status" -ne 0 ]
}

@test "handles stdin input (no file argument)" {
  run bash -c "echo '{\"key\":\"val\"}' | '$JQ' -r '.key'"
  [ "$status" -eq 0 ]
  [ "$output" = "val" ]
}
