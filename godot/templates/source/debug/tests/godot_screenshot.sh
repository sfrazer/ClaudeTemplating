#!/usr/bin/env bash
# godot_screenshot.sh — render a Godot scene, save a screenshot, check for errors
#
# Temporarily adds a screenshot autoload to project.godot, runs the project
# (with a display so the viewport renders), saves a PNG, then restores
# project.godot.
#
# Usage:
#   godot_screenshot.sh [--preview] [scene_path] [output_png]
#
# Arguments (any order):
#   --preview      Open result in Preview.app after capture (macOS)
#   scene_path     res:// path of a scene to run (optional; uses project default)
#   output_png     Where to save the result (default: /tmp/godot_screenshot.png)
#
# Environment:
#   GODOT_BIN              Path to the Godot binary (overrides PATH lookup). Use
#                          this rather than a shell alias — aliases are not visible
#                          to non-interactive scripts.
#   SCREENSHOT_WAIT_FRAMES Frames to wait before capture (read by the helper).
#
# Exits non-zero if Godot exits non-zero, writes no log, or logs an error line.

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

# GODOT_BIN wins; otherwise look for a real binary on PATH, then the macOS app.
GODOT="${GODOT_BIN:-$(command -v godot4 2>/dev/null \
  || command -v godot 2>/dev/null \
  || echo "/Applications/Godot.app/Contents/MacOS/Godot")}"

if [[ ! -x "$GODOT" ]]; then
  echo "ERROR: Godot not found at '$GODOT'. Put godot/godot4 on PATH or set GODOT_BIN." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PROJECT_GODOT="$PROJECT_ROOT/project.godot"
PROJECT_GODOT_BAK="$PROJECT_ROOT/project.godot.screenshot_bak"
HELPER_PATH="res://source/debug/tests/screenshot_helper.gd"

# Register the trap before the backup so an interruption between cp and trap can't
# leave a mangled project.godot. cleanup() is a no-op until the backup exists.
cleanup() {
  if [[ -f "$PROJECT_GODOT_BAK" ]]; then
    mv "$PROJECT_GODOT_BAK" "$PROJECT_GODOT"
  fi
}
trap cleanup EXIT

cp "$PROJECT_GODOT" "$PROJECT_GODOT_BAK"

# Add the ScreenshotHelper autoload WITHOUT clobbering existing autoloads. If the
# project already has an [autoload] section, insert our line right after its header;
# otherwise append a new section. (project.godot is INI-style; a second [autoload]
# section would shadow/merge unpredictably.)
AUTOLOAD_LINE="ScreenshotHelper=\"*$HELPER_PATH\""
if grep -qE '^\[autoload\]' "$PROJECT_GODOT_BAK"; then
  awk -v line="$AUTOLOAD_LINE" '
    { print }
    /^\[autoload\]/ && !done { print line; done=1 }
  ' "$PROJECT_GODOT_BAK" > "$PROJECT_GODOT"
else
  {
    cat "$PROJECT_GODOT_BAK"
    echo ""
    echo "[autoload]"
    echo ""
    echo "$AUTOLOAD_LINE"
  } > "$PROJECT_GODOT"
fi

ARGS=("--path" "$PROJECT_ROOT")
if [[ -n "$SCENE" ]]; then
  ARGS+=("--scene" "$SCENE")
fi

# SCREENSHOT_PATH is read by screenshot_helper.gd via OS.get_environment(); it
# reaches the helper because Godot inherits this script's environment.
export SCREENSHOT_PATH="$OUTPUT"

echo "Rendering..."
rc=0
"$GODOT" "${ARGS[@]}" > "$LOG" 2>&1 || rc=$?

if [[ $rc -ne 0 ]]; then
  echo "ERROR: Godot exited with status $rc. See $LOG." >&2
  [[ -s "$LOG" ]] && tail -n 20 "$LOG" >&2
  exit 1
fi

if [[ ! -s "$LOG" ]]; then
  echo "ERROR: Godot produced no output — it may have failed to start. See $LOG." >&2
  exit 1
fi

if grep -qE '(^|[[:space:]])(ERROR|SCRIPT ERROR|USER ERROR|USER SCRIPT ERROR)' "$LOG"; then
  echo "=== Errors detected ===" >&2
  grep -E '(^|[[:space:]])(ERROR|SCRIPT ERROR|USER ERROR|USER SCRIPT ERROR)' "$LOG" >&2
  exit 1
fi

if [[ -f "$OUTPUT" ]]; then
  echo "Screenshot saved: $OUTPUT"
  if $PREVIEW; then
    open "$OUTPUT"
  fi
else
  echo "ERROR: Screenshot file not written. Check $LOG for details." >&2
  exit 1
fi

exit 0
