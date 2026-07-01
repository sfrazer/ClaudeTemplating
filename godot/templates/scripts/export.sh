#!/bin/bash
# Exports a shareable, UNSIGNED macOS build to build/<APP_NAME>.app, driven by the
# `/export-build` command. Imports assets first so a headless export never trips over
# not-yet-imported textures, and so the ETC2/ASTC VRAM formats a universal/arm64 macOS
# export requires are present. Resolves the Godot binary from GODOT_BIN, then godot4/godot
# on PATH, then the default macOS app location. Reports and propagates the export exit code.
#
# Prerequisites: the macOS export TEMPLATES for this Godot version must be installed
# (Editor -> Manage Export Templates...), and the editor must be QUIT (it caches
# project.godot / export_presets.cfg in memory; the CLI reads what is on disk).
set -euo pipefail

# --- EDIT FOR YOUR PROJECT ------------------------------------------------------
# APP_NAME  — the name of the exported bundle, produced at build/<APP_NAME>.app.
# PRESET    — the export preset in export_presets.cfg to build. It must be a macOS
#             *unsigned* preset. "macOS (unsigned)" is a good name to give it.
APP_NAME="YourApp"
PRESET="macOS (unsigned)"
# --------------------------------------------------------------------------------

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

# Import assets/scripts first (idempotent). Required on a fresh clone where no .godot/
# cache exists, and after any asset/import-setting change (e.g. enabling ETC2 ASTC).
"$GODOT" --headless --import >/dev/null 2>&1 || true

mkdir -p build

# Export. Capture the exit code, report it on its own line, and propagate it so callers
# never need ${PIPESTATUS[0]} to learn the result.
set +e
"$GODOT" --headless --export-release "$PRESET" "build/$APP_NAME.app"
rc=$?
set -e

echo "export.sh: godot export exited with code $rc"
exit "$rc"
