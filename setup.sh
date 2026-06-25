#!/usr/bin/env bash
# setup.sh — assemble Claude Code commands, snippets, templates, and an interview
# prompt into the current project, based on a chosen project type.
#
# Usage:
#   ./setup.sh                 # interactive menu
#   ./setup.sh godot-game      # skip the menu
#
# The shared commands repo (the repo this script lives in) is located via the
# CLAUDE_SHARED_REPO environment variable, defaulting to ~/.claude-shared.

set -euo pipefail

# --- Supported project types ----------------------------------------------------
# Each project type maps to an asset directory inside the shared repo. The asset
# directory holds commands/, claude-snippets/, and (optionally) templates/.
PROJECT_TYPES=("generic" "godot-game")

asset_dir_for() {
  case "$1" in
    generic)    echo "generic" ;;
    godot-game) echo "godot" ;;
    *)          echo "" ;;
  esac
}

# --- Resolve the shared repo ----------------------------------------------------
SHARED_REPO="${CLAUDE_SHARED_REPO:-$HOME/.claude-shared}"

if [[ ! -d "$SHARED_REPO" ]]; then
  cat >&2 <<EOF
ERROR: shared commands repo not found at: $SHARED_REPO

Set CLAUDE_SHARED_REPO to the location of this repo, e.g.:

    export CLAUDE_SHARED_REPO=/path/to/ClaudeTemplating

or clone/symlink it to the default location:

    git clone <repo-url> ~/.claude-shared
EOF
  exit 1
fi

# --- Choose the project type ----------------------------------------------------
PROJECT_TYPE="${1:-}"

if [[ -z "$PROJECT_TYPE" ]]; then
  echo "Select a project type:"
  select choice in "${PROJECT_TYPES[@]}"; do
    if [[ -n "${choice:-}" ]]; then
      PROJECT_TYPE="$choice"
      break
    fi
    echo "Invalid selection — try again."
  done
fi

ASSET_DIR_NAME="$(asset_dir_for "$PROJECT_TYPE")"
if [[ -z "$ASSET_DIR_NAME" ]]; then
  echo "ERROR: unknown project type '$PROJECT_TYPE'. Supported: ${PROJECT_TYPES[*]}" >&2
  exit 1
fi

GENERIC_DIR="$SHARED_REPO/generic"
ASSET_DIR="$SHARED_REPO/$ASSET_DIR_NAME"
PROJECT_ROOT="$(pwd)"

echo "Project type: $PROJECT_TYPE  (assets: $ASSET_DIR_NAME)"
echo "Shared repo:  $SHARED_REPO"
echo "Target:       $PROJECT_ROOT"
echo

# --- Pull the latest shared repo ------------------------------------------------
if [[ -d "$SHARED_REPO/.git" ]]; then
  echo "Pulling latest from shared repo..."
  git -C "$SHARED_REPO" pull --ff-only || \
    echo "WARNING: could not pull shared repo (continuing with local copy)." >&2
  echo
fi

# --- Create target directories --------------------------------------------------
mkdir -p "$PROJECT_ROOT/.claude/commands"
mkdir -p "$PROJECT_ROOT/docs/wiki"
mkdir -p "$PROJECT_ROOT/scripts"

# --- Copy command files ---------------------------------------------------------
copied_commands=()

copy_commands_from() {
  local dir="$1"
  if [[ -d "$dir/commands" ]]; then
    shopt -s nullglob
    for f in "$dir/commands"/*.md; do
      cp "$f" "$PROJECT_ROOT/.claude/commands/"
      copied_commands+=("$(basename "$f")")
    done
    shopt -u nullglob
  fi
}

copy_commands_from "$GENERIC_DIR"
if [[ "$ASSET_DIR_NAME" != "generic" ]]; then
  copy_commands_from "$ASSET_DIR"
fi

# --- Copy templates (preserve structure, do not overwrite) ----------------------
copied_templates=false
if [[ -d "$ASSET_DIR/templates" ]]; then
  # -n: never overwrite existing files in the project.
  cp -Rn "$ASSET_DIR/templates/." "$PROJECT_ROOT/" 2>/dev/null || true
  copied_templates=true
fi

# --- Assemble CLAUDE.md ---------------------------------------------------------
claude_created=false
if [[ -f "$PROJECT_ROOT/CLAUDE.md" ]]; then
  echo "CLAUDE.md already exists — leaving it untouched."
else
  {
    cat "$GENERIC_DIR/claude-snippets/wiki-contract.md"
    echo
    cat "$GENERIC_DIR/claude-snippets/git-workflow.md"
    echo

    if [[ "$ASSET_DIR_NAME" != "generic" && -d "$ASSET_DIR/claude-snippets" ]]; then
      shopt -s nullglob
      for f in $(printf '%s\n' "$ASSET_DIR/claude-snippets"/*.md | sort); do
        cat "$f"
        echo
      done
      shopt -u nullglob
    fi

    cat <<'EOF'
## Project

<!-- Fill this in (or let INTERVIEW.md fill it in for you). -->

**Name:** TODO

**Description:** TODO

### Wiki

| Document | Read when... |
|----------|--------------|
| docs/wiki/product-brief.md | TODO |

### Project Structure

```
TODO
```
EOF
  } > "$PROJECT_ROOT/CLAUDE.md"
  claude_created=true
fi

# --- Assemble INTERVIEW.md ------------------------------------------------------
{
  cat "$SHARED_REPO/interviews/base.md"
  overlay="$SHARED_REPO/interviews/overlays/$PROJECT_TYPE.md"
  if [[ -f "$overlay" ]]; then
    echo
    echo
    cat "$overlay"
  fi
} > "$PROJECT_ROOT/INTERVIEW.md"

# --- Summary --------------------------------------------------------------------
echo
echo "=== Setup complete ==="
echo "Commands copied to .claude/commands/:"
for c in "${copied_commands[@]}"; do
  echo "  - $c"
done
if [[ "$copied_templates" == true ]]; then
  echo "Templates copied from $ASSET_DIR_NAME/templates/ (existing files preserved)."
fi
if [[ "$claude_created" == true ]]; then
  echo "CLAUDE.md assembled (fill in the ## Project section)."
fi
echo "INTERVIEW.md assembled."
echo
echo "Next steps:"
echo "  1. Run INTERVIEW.md in a fresh Claude Code session to complete project setup."
echo "  2. Review and commit the assembled files to your project repo."
