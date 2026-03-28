#!/usr/bin/env bats
# =============================================================================
# test_root_dir.bats — ROOT_DIR resolution tests
#
# Goal: 100% of scripts in .cicd/docker-resources/scripts/ must resolve
#       ROOT_DIR to the repo root. Zero path-depth bugs allowed.
#
# Bug caught: build-source.sh.txt and build-binary.sh.txt used ../../../../
#             (4 levels) instead of ../../.. (3 levels), resolving to the
#             parent of the repo instead of the repo root.
# =============================================================================

load helpers/setup

setup() {
  EXPECTED_ROOT="${REPO_ROOT}"
}

# ---------------------------------------------------------------------------
# Static analysis — catch wrong traversal depth before scripts are even run
# ---------------------------------------------------------------------------

@test "no script uses 4-level traversal ../../../../ for ROOT_DIR" {
  local violations=()
  while IFS= read -r f; do
    if grep -q 'ROOT_DIR' "$f" && grep 'ROOT_DIR' "$f" | grep -qE '\.\./\.\./\.\./\.\.'; then
      violations+=("$(basename "$f")")
    fi
  done < <(find "${SCRIPTS_DIR}" -name "*.sh.txt")

  [ "${#violations[@]}" -eq 0 ] || {
    echo "Scripts with wrong ROOT_DIR depth (../../../../):"
    printf '  %s\n' "${violations[@]}"
    return 1
  }
}

@test "all filesystem scripts define ROOT_DIR" {
  local missing=()
  while IFS= read -r f; do
    script_needs_root_dir "$f" || continue
    grep -q 'ROOT_DIR=' "$f" || missing+=("$(basename "$f")")
  done < <(find "${SCRIPTS_DIR}" -name "*.sh.txt")

  [ "${#missing[@]}" -eq 0 ] || {
    echo "Scripts missing ROOT_DIR definition:"
    printf '  %s\n' "${missing[@]}"
    return 1
  }
}

# ---------------------------------------------------------------------------
# Dynamic evaluation — actually resolve ROOT_DIR and compare to repo root
# ---------------------------------------------------------------------------

@test "build-source ROOT_DIR resolves to repo root" {
  result=$(eval_root_dir "${SCRIPTS_DIR}/build-source.sh.txt")
  [ "$result" = "$EXPECTED_ROOT" ]
}

@test "build-binary ROOT_DIR resolves to repo root" {
  result=$(eval_root_dir "${SCRIPTS_DIR}/build-binary.sh.txt")
  [ "$result" = "$EXPECTED_ROOT" ]
}

@test "release ROOT_DIR resolves to repo root" {
  result=$(eval_root_dir "${SCRIPTS_DIR}/release.sh.txt")
  [ "$result" = "$EXPECTED_ROOT" ]
}

@test "scan-cve ROOT_DIR resolves to repo root" {
  result=$(eval_root_dir "${SCRIPTS_DIR}/scan-cve.sh.txt")
  [ "$result" = "$EXPECTED_ROOT" ]
}

@test "scan-sast ROOT_DIR resolves to repo root" {
  result=$(eval_root_dir "${SCRIPTS_DIR}/scan-sast.sh.txt")
  [ "$result" = "$EXPECTED_ROOT" ]
}

@test "scan-secrets ROOT_DIR resolves to repo root" {
  result=$(eval_root_dir "${SCRIPTS_DIR}/scan-secrets.sh.txt")
  [ "$result" = "$EXPECTED_ROOT" ]
}

@test "scan-dependencies ROOT_DIR resolves to repo root" {
  result=$(eval_root_dir "${SCRIPTS_DIR}/scan-dependencies.sh.txt")
  [ "$result" = "$EXPECTED_ROOT" ]
}

@test "scan-iac ROOT_DIR resolves to repo root" {
  result=$(eval_root_dir "${SCRIPTS_DIR}/scan-iac.sh.txt")
  [ "$result" = "$EXPECTED_ROOT" ]
}

@test "scan-all ROOT_DIR resolves to repo root" {
  result=$(eval_root_dir "${SCRIPTS_DIR}/scan-all.sh.txt")
  [ "$result" = "$EXPECTED_ROOT" ]
}

@test "scan-aggregate ROOT_DIR resolves to repo root" {
  result=$(eval_root_dir "${SCRIPTS_DIR}/scan-aggregate.sh.txt")
  [ "$result" = "$EXPECTED_ROOT" ]
}

@test "onboard-foss ROOT_DIR resolves to repo root" {
  result=$(eval_root_dir "${SCRIPTS_DIR}/onboard-foss.sh.txt")
  [ "$result" = "$EXPECTED_ROOT" ]
}
