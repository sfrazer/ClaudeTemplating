#!/usr/bin/env bash
# run.sh — the test harness entrypoint. Discovers every test_* function in
# tests/test_*.sh and runs each in its own subshell against a throwaway copy of
# this repo's assets (so nothing here touches the network or the real repo).
#
#   ./tests/run.sh            # run all tests
#   ./tests/run.sh setup      # run only tests whose file is test_setup.sh
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
source "$DIR/lib.sh"

# --- Per-run scratch + a .git-less fixture of the shared repo --------------------
# setup.sh only tries to `git pull` the shared repo when it has a .git dir, so a
# plain copy of the asset trees keeps the tests offline and side-effect free.
TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/cttest.XXXXXX")"
export TEST_TMP
trap 'rm -rf "$TEST_TMP"' EXIT

SHARED_FIXTURE="$TEST_TMP/shared"
export SHARED_FIXTURE
mkdir -p "$SHARED_FIXTURE"
for d in generic godot love2d interviews; do
  cp -R "$REPO_ROOT/$d" "$SHARED_FIXTURE/"
done

# --- Load test files (optionally filtered by name) ------------------------------
filter="${1:-}"
shopt -s nullglob
for tf in "$DIR"/test_*.sh; do
  [[ -n "$filter" && "$(basename "$tf")" != "test_$filter.sh" ]] && continue
  # shellcheck source=/dev/null
  source "$tf"
done
shopt -u nullglob

# --- Run every test_* function --------------------------------------------------
passed=0
failed=0
failures=()
while IFS= read -r fn; do
  if ( "$fn" ); then
    echo "  ok   $fn"
    passed=$((passed + 1))
  else
    echo "  FAIL $fn"
    failed=$((failed + 1))
    failures+=("$fn")
  fi
done < <(declare -F | awk '{print $3}' | grep '^test_' | sort)

echo
echo "================================================"
if [[ $failed -eq 0 ]]; then
  echo "PASS — $passed test(s)"
  exit 0
fi
echo "FAIL — $failed of $((passed + failed)) test(s) failed:"
printf '  - %s\n' "${failures[@]}"
exit 1
