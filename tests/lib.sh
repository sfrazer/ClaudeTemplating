#!/usr/bin/env bash
# lib.sh — assertions and helpers for the test harness. Sourced by run.sh (which
# exports TEST_TMP and SHARED_FIXTURE) and by the test_*.sh files. Not executable
# on its own.
#
# A failing assertion prints a reason and `exit 1`s. Each test runs in its own
# subshell (see run.sh), so that aborts only the current test.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETUP="$REPO_ROOT/setup.sh"
CHECK="$REPO_ROOT/check-updates.sh"
# shellcheck disable=SC2034  # consumed by the test_*.sh files that source this
COMMON="$REPO_ROOT/lib/common.sh"

fail() { echo "    ASSERT FAILED: $*" >&2; exit 1; }

# A fresh, empty project directory under the per-run temp root.
make_project() { mktemp -d "$TEST_TMP/proj.XXXXXX"; }

# A fresh, *mutable* copy of the shared-repo assets, echoed as a path. Tests that
# simulate upstream drift reassign SHARED_FIXTURE to one of these (safe because each
# test runs in its own subshell) so they never disturb the run-wide fixture.
make_fixture() {
  local f; f="$(mktemp -d "$TEST_TMP/shared.XXXXXX")"
  local d
  for d in generic godot interviews; do cp -R "$REPO_ROOT/$d" "$f/"; done
  echo "$f"
}

# Run setup.sh / check-updates.sh against the fixture shared repo, from inside a
# project dir. Both forward their exit code and emit the script's output.
do_setup() { local p="$1"; shift; ( cd "$p" && CLAUDE_SHARED_REPO="$SHARED_FIXTURE" "$SETUP" "$@" ); }
do_check() { local p="$1"; shift; ( cd "$p" && CLAUDE_SHARED_REPO="$SHARED_FIXTURE" "$CHECK" "$@" ); }

# --- Assertions -----------------------------------------------------------------
assert_eq() { [[ "$1" == "$2" ]] || fail "${3:-values}: expected [$2], got [$1]"; }
assert_file() { [[ -f "$1" ]] || fail "expected file to exist: $1"; }
assert_exec() { [[ -x "$1" ]] || fail "expected executable file: $1"; }
refute_exists() { [[ ! -e "$1" ]] || fail "expected absent: $1"; }

# Fixed-string / regex search in a file.
assert_contains() { assert_file "$1"; grep -qF -- "$2" "$1" || fail "[$1] does not contain [$2]"; }
assert_grep()     { assert_file "$1"; grep -qE -- "$2" "$1" || fail "[$1] does not match /$2/"; }

# Fixed-string search in a string (e.g. captured output).
assert_match() { case "$1" in *"$2"*) : ;; *) fail "output does not contain [$2]: $1" ;; esac; }

# Run a command; assert it exits with the expected status.
assert_status() {
  local exp="$1" desc="$2"; shift 2
  local rc=0
  "$@" >/dev/null 2>&1 || rc=$?
  [[ "$rc" == "$exp" ]] || fail "$desc: expected exit $exp, got $rc"
}
