#!/bin/bash
# Runs the full GUT suite headless. Reads .gutconfig.json at the project root and
# exits non-zero if any tests fail. Resolves the Godot binary from GODOT_BIN, then
# godot4/godot on PATH, then the default macOS app location.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -n "${GODOT_BIN:-}" ]]; then
  GODOT="$GODOT_BIN"
elif command -v godot4 >/dev/null 2>&1; then
  GODOT="godot4"
elif command -v godot >/dev/null 2>&1; then
  GODOT="godot"
elif [[ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]]; then
  GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
else
  echo "ERROR: Godot binary not found. Set GODOT_BIN or put godot4/godot on PATH." >&2
  exit 1
fi

# Ensure assets/scripts are imported first. Required on a fresh clone / CI runner
# where no .godot/ cache exists yet. Fast and idempotent on an already-imported project.
"$GODOT" --headless --import >/dev/null 2>&1 || true

# IMPORTANT: use gut_cmdln.gd (extends SceneTree), not gut_cli.gd (extends Node).
# Capture GUT's exit code, report it on its own line, and propagate it. Reporting it
# here means callers never need `${PIPESTATUS[0]}` (which can't be auto-approved) to
# learn the result through a pipe.
set +e
"$GODOT" --headless -s res://addons/gut/gut_cmdln.gd
rc=$?
set -e

echo "run_tests.sh: GUT exited with code $rc"
exit "$rc"
