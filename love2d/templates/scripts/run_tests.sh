#!/bin/bash
# Runs the Lua test suite with busted. Reads .busted at the project root (or busted's
# own defaults, e.g. the spec/ directory) and exits non-zero if any tests fail. Resolves
# busted from BUSTED_BIN, then busted on PATH.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -n "${BUSTED_BIN:-}" ]]; then
  BUSTED="$BUSTED_BIN"
elif command -v busted >/dev/null 2>&1; then
  BUSTED="busted"
else
  echo "ERROR: busted not found. Install it (luarocks install busted) or set BUSTED_BIN." >&2
  exit 1
fi

# Capture busted's exit code, report it on its own line, and propagate it. Reporting it
# here means callers never need `${PIPESTATUS[0]}` (which can't be auto-approved) to learn
# the result through a pipe.
set +e
"$BUSTED"
rc=$?
set -e

echo "run_tests.sh: busted exited with code $rc"
exit "$rc"
