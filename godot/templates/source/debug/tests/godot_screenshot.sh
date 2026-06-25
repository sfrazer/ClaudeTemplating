#!/usr/bin/env bash
# godot_screenshot.sh — render a Godot scene, save a screenshot, check for errors
#
# Temporarily adds a screenshot autoload to project.godot, runs the project
# headlessly (or with display), saves a PNG, then restores project.godot.
#
# Usage:
#   godot_screenshot.sh [--preview] [scene_path] [output_png]
#
# Arguments (any order):
#   --preview      Open result in Preview.app after capture (macOS)
#   scene_path     res:// path to run as main scene (optional; uses project default)
#   output_png     Where to save the result (default: /tmp/godot_screenshot.png)
#
# Exits non-zero if any SCRIPT ERROR or ERROR lines appear in the log.

set -euo pipefail

PREVIEW=false
SCENE=""
OUTPUT="/tmp/godot_screenshot.png"
LOG="/tmp/godot_screenshot.log"

for arg in "$@"; do
  case "$arg" in
    --preview) PREVIEW=true ;;
    res://*) SCENE="$arg" ;;
    *.png) OUTPUT="$arg" ;;
  esac
done

GODOT=$(command -v godot4 2>/dev/null \
  || command -v godot 2>/dev/null \
  || echo "/Applications/Godot.app/Contents/MacOS/Godot")

if [[ ! -x "$GODOT" ]]; then
  echo "ERROR: Godot not found at $GODOT" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PROJECT_GODOT="$PROJECT_ROOT/project.godot"
PROJECT_GODOT_BAK="$PROJECT_ROOT/project.godot.screenshot_bak"
HELPER_PATH="res://source/debug/tests/screenshot_helper.gd"

cp "$PROJECT_GODOT" "$PROJECT_GODOT_BAK"

cleanup() {
  if [[ -f "$PROJECT_GODOT_BAK" ]]; then
    mv "$PROJECT_GODOT_BAK" "$PROJECT_GODOT"
  fi
}
trap cleanup EXIT

{
  cat "$PROJECT_GODOT_BAK"
  echo ""
  echo "[autoload]"
  echo ""
  echo "ScreenshotHelper=\"*$HELPER_PATH\""
} > "$PROJECT_GODOT"

ARGS=("--path" "$PROJECT_ROOT")
if [[ -n "$SCENE" ]]; then
  ARGS+=("--scene" "$SCENE")
fi

export SCREENSHOT_PATH="$OUTPUT"

echo "Rendering..."
"$GODOT" "${ARGS[@]}" > "$LOG" 2>&1 || true

if grep -qE "^ERROR|SCRIPT ERROR" "$LOG"; then
  echo "=== Errors detected ===" >&2
  grep -E "^ERROR|SCRIPT ERROR" "$LOG" >&2
  exit 1
fi

if [[ -f "$OUTPUT" ]]; then
  echo "Screenshot saved: $OUTPUT"
  if $PREVIEW; then
    open "$OUTPUT"
  fi
else
  echo "WARNING: Screenshot file not written. Check $LOG for details." >&2
fi

exit 0
