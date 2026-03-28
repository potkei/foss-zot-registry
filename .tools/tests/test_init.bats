#!/usr/bin/env bats
# =============================================================================
# test_init.bats — init.sh smoke tests
#
# Goals:
#   - All 4 required directories are created: patches/ reports/ docs/ helm/
#   - Every .sh.txt file in the repo is translated to a .sh file
#   - Generated .sh files are executable (Unix only)
#   - jq version detection function correctly identifies good/bad versions
#   - Docker or Podman is available
# =============================================================================

load helpers/setup

setup() {
  # Run init in a clean temp dir that mirrors the repo layout
  TEST_DIR="$(mktemp -d)"
  cp -r "${REPO_ROOT}/." "${TEST_DIR}/"
  # Remove any pre-existing generated .sh files so translation is tested fresh
  find "${TEST_DIR}" -name "*.sh" ! -name "*.sh.txt" \
    -not -path "*/.git/*" -not -path "*/.tools/*" -delete 2>/dev/null || true

  # Temp bin dir for jq mocks
  MOCK_BIN="$(mktemp -d)"
}

teardown() {
  rm -rf "${TEST_DIR}" "${MOCK_BIN}"
}

# Helper: create a fake jq binary that reports a specific version
mock_jq() {
  local version="$1"
  cat > "${MOCK_BIN}/jq" << EOF
#!/bin/bash
echo "jq-${version}"
EOF
  chmod +x "${MOCK_BIN}/jq"
  export PATH="${MOCK_BIN}:${PATH}"
}

# Helper: source _jq_version_ok from init.sh.txt into current shell
load_jq_version_fn() {
  local fn_file
  fn_file="$(mktemp)"
  sed -n '/_jq_version_ok()/,/^}/p' "${REPO_ROOT}/init.sh.txt" > "$fn_file"
  # shellcheck disable=SC1090
  source "$fn_file"
  rm -f "$fn_file"
}

# ---------------------------------------------------------------------------
# Directory creation
# ---------------------------------------------------------------------------

@test "init.sh creates patches/ directory" {
  rm -rf "${TEST_DIR}/patches"
  bash "${TEST_DIR}/init.sh.txt" >/dev/null 2>&1 || true
  [ -d "${TEST_DIR}/patches" ]
}

@test "init.sh creates reports/ directory" {
  rm -rf "${TEST_DIR}/reports"
  bash "${TEST_DIR}/init.sh.txt" >/dev/null 2>&1 || true
  [ -d "${TEST_DIR}/reports" ]
}

@test "init.sh creates docs/ directory" {
  rm -rf "${TEST_DIR}/docs"
  bash "${TEST_DIR}/init.sh.txt" >/dev/null 2>&1 || true
  [ -d "${TEST_DIR}/docs" ]
}

@test "init.sh creates helm/ directory" {
  rm -rf "${TEST_DIR}/helm"
  bash "${TEST_DIR}/init.sh.txt" >/dev/null 2>&1 || true
  [ -d "${TEST_DIR}/helm" ]
}

# ---------------------------------------------------------------------------
# Script translation: .sh.txt → .sh (scoped to this repo only)
# ---------------------------------------------------------------------------

@test "init.sh translates all .sh.txt files to .sh" {
  bash "${TEST_DIR}/init.sh.txt" >/dev/null 2>&1 || true
  local untranslated=()
  while IFS= read -r f; do
    target="${f%.txt}"
    [ -f "$target" ] || untranslated+=("${f#${TEST_DIR}/}")
  done < <(find "${TEST_DIR}" -name "*.sh.txt" -not -path "*/.git/*" -not -path "*/.tools/*")
  [ "${#untranslated[@]}" -eq 0 ] || {
    echo "Not translated:"
    printf '  %s\n' "${untranslated[@]}"
    return 1
  }
}

@test "translated .sh files are executable on non-Windows systems" {
  uname -s | grep -qiE 'mingw|msys|cygwin' && skip "Windows: chmod +x not applicable"
  bash "${TEST_DIR}/init.sh.txt" >/dev/null 2>&1 || true
  local non_exec=()
  while IFS= read -r f; do
    target="${f%.txt}"
    [ -f "$target" ] && [ ! -x "$target" ] && non_exec+=("${target#${TEST_DIR}/}")
  done < <(find "${TEST_DIR}" -name "*.sh.txt" -not -path "*/.git/*" -not -path "*/.tools/*")
  [ "${#non_exec[@]}" -eq 0 ] || {
    echo "Not executable after translation:"
    printf '  %s\n' "${non_exec[@]}"
    return 1
  }
}

# ---------------------------------------------------------------------------
# jq version detection unit tests
# ---------------------------------------------------------------------------

@test "jq version check: accepts jq-1.6" {
  load_jq_version_fn
  mock_jq "1.6"
  _jq_version_ok
}

@test "jq version check: accepts jq-1.7.1" {
  load_jq_version_fn
  mock_jq "1.7.1"
  _jq_version_ok
}

@test "jq version check: accepts jq-2.0" {
  load_jq_version_fn
  mock_jq "2.0"
  _jq_version_ok
}

@test "jq version check: rejects jq-1.5" {
  load_jq_version_fn
  mock_jq "1.5"
  run _jq_version_ok
  [ "$status" -ne 0 ]
}

@test "jq version check: rejects jq-1.3" {
  load_jq_version_fn
  mock_jq "1.3"
  run _jq_version_ok
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# Script references — guard against missing companion scripts
# ---------------------------------------------------------------------------

@test "patches/verify.sh.txt exists in repo" {
  [ -f "${REPO_ROOT}/patches/verify.sh.txt" ]
}

@test "build-source.sh.txt guards verify.sh call with existence check" {
  grep -q '\[ -x.*patches/verify.sh' \
    "${REPO_ROOT}/.cicd/docker-resources/scripts/build-source.sh.txt"
}

# ---------------------------------------------------------------------------
# Container runtime
# ---------------------------------------------------------------------------

@test "docker or podman is available" {
  command -v docker >/dev/null 2>&1 || command -v podman >/dev/null 2>&1
}
