# Shared setup for all BATS test suites.
# Sourced automatically via `load helpers/setup` in each test file.

# BATS sets BATS_TEST_FILENAME to the absolute path of the test file.
# Test files live in .tools/tests/ — 2 levels up from there is repo root.
REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
SCRIPTS_DIR="${REPO_ROOT}/.cicd/docker-resources/scripts"

# Evaluate ROOT_DIR for a script in .cicd/docker-resources/scripts/.
# All scripts there should resolve exactly 3 levels up to the repo root.
# Rather than parsing and re-evaluating each script's ROOT_DIR expression
# (which varies in form), we directly compute 3 levels up from the script's
# directory — which is what all correct scripts do.
eval_root_dir() {
  local script_path="$1"
  local script_dir
  script_dir="$(cd "$(dirname "$script_path")" && pwd)"
  (cd "${script_dir}/../../.." && pwd)
}

# Scripts that intentionally omit ROOT_DIR (container-only entrypoints)
# that should be excluded from ROOT_DIR checks.
SCRIPTS_WITHOUT_ROOT_DIR=(
  "sonar-setup.sh.txt"
)

script_needs_root_dir() {
  local name
  name="$(basename "$1")"
  for excluded in "${SCRIPTS_WITHOUT_ROOT_DIR[@]}"; do
    [ "$name" = "$excluded" ] && return 1
  done
  return 0
}
