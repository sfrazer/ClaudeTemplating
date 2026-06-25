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
#
# Supported project types: generic, godot-game.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

case "${1:-}" in
  -h|--help)
    sed -n '2,/^# Supported project types/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 0 ;;
esac

# --- Resolve the shared repo ----------------------------------------------------
SHARED_REPO="$(resolve_shared_repo)" || exit 1

# --- Choose the project type ----------------------------------------------------
PROJECT_TYPE="${1:-}"

if [[ -z "$PROJECT_TYPE" ]]; then
  if [[ ! -t 0 ]]; then
    echo "ERROR: no project type given and not running interactively." >&2
    echo "       Pass one as an argument, e.g. setup.sh godot-game" >&2
    echo "       Supported: ${PROJECT_TYPES[*]}" >&2
    exit 1
  fi
  echo "Select a project type:"
  select choice in "${PROJECT_TYPES[@]}"; do
    if [[ -n "${choice:-}" ]]; then
      PROJECT_TYPE="$choice"
      break
    fi
    echo "Invalid selection — try again."
  done
  if [[ -z "$PROJECT_TYPE" ]]; then
    echo "ERROR: no project type selected." >&2
    exit 1
  fi
fi

ASSET_DIR_NAME="$(asset_dir_for "$PROJECT_TYPE")"
if [[ -z "$ASSET_DIR_NAME" ]]; then
  echo "ERROR: unknown project type '$PROJECT_TYPE'. Supported: ${PROJECT_TYPES[*]}" >&2
  exit 1
fi

GENERIC_DIR="$SHARED_REPO/generic"
ASSET_DIR="$SHARED_REPO/$ASSET_DIR_NAME"
PROJECT_ROOT="$(pwd)"
MANIFEST="$PROJECT_ROOT/.claude/.template-manifest"

echo "Project type: $PROJECT_TYPE  (assets: $ASSET_DIR_NAME)"
echo "Shared repo:  $SHARED_REPO"
echo "Target:       $PROJECT_ROOT"
echo

# --- Pull the latest shared repo ------------------------------------------------
pull_shared_repo "$SHARED_REPO"

# --- Create target directories --------------------------------------------------
mkdir -p "$PROJECT_ROOT/.claude/commands"
mkdir -p "$PROJECT_ROOT/docs/wiki"
mkdir -p "$PROJECT_ROOT/scripts"

# Manifest lines accumulated as files are installed:
#   <category> <source-sha256> <source-rel-path> <dest-rel-path>
manifest_lines=()
record() {
  local category="$1" src="$2" dest_rel="$3"
  manifest_lines+=("$category $(file_hash "$src") ${src#$SHARED_REPO/} $dest_rel")
}

# --- Copy command files ---------------------------------------------------------
copied_commands=()

copy_commands_from() {
  local dir="$1"
  if [[ -d "$dir/commands" ]]; then
    shopt -s nullglob
    for f in "$dir/commands"/*.md; do
      cp "$f" "$PROJECT_ROOT/.claude/commands/"
      copied_commands+=("$(basename "$f")")
      record command "$f" ".claude/commands/$(basename "$f")"
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
templates_skipped=0
if [[ -d "$ASSET_DIR/templates" ]]; then
  copied_templates=true
  while IFS= read -r tf; do
    rel="${tf#$ASSET_DIR/templates/}"
    dest="$PROJECT_ROOT/$rel"
    mkdir -p "$(dirname "$dest")"
    if [[ -e "$dest" ]]; then
      templates_skipped=$((templates_skipped + 1))   # never overwrite an existing file
    else
      cp "$tf" "$dest"
    fi
    # Record the source regardless of whether we skipped a pre-existing file —
    # the checker compares against the project copy and flags local edits.
    record template "$tf" "$rel"
  done < <(find "$ASSET_DIR/templates" -type f ! -name .DS_Store)
fi

# --- Assemble CLAUDE.md ---------------------------------------------------------
# Snippet sources, in concatenation order: the generic snippets first in a fixed
# order (wiki-contract, then git-workflow), then asset snippets alphabetically.
snippet_files=("$GENERIC_DIR/claude-snippets/wiki-contract.md" "$GENERIC_DIR/claude-snippets/git-workflow.md")
if [[ "$ASSET_DIR_NAME" != "generic" && -d "$ASSET_DIR/claude-snippets" ]]; then
  while IFS= read -r f; do
    snippet_files+=("$f")
  done < <(printf '%s\n' "$ASSET_DIR/claude-snippets"/*.md | sort)
fi

claude_created=false
if [[ -f "$PROJECT_ROOT/CLAUDE.md" ]]; then
  echo "CLAUDE.md already exists — leaving it untouched."
else
  {
    for f in "${snippet_files[@]}"; do
      cat "$f"
      echo
    done

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

# Record snippet sources unconditionally so check-updates can detect upstream
# snippet drift even when CLAUDE.md was hand-written (pre-existing). The checker
# compares each snippet's current source hash against the recorded one — that
# works regardless of CLAUDE.md's contents. The claude_md header below notes
# whether we assembled CLAUDE.md or left an existing one in place.
for f in "${snippet_files[@]}"; do
  record snippet "$f" "CLAUDE.md"
done

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

# --- Write the install manifest -------------------------------------------------
if [[ "$claude_created" == true ]]; then claude_md_state=assembled; else claude_md_state=preexisting; fi
{
  echo "# ClaudeTemplating install manifest — managed by setup.sh; do not edit"
  echo "type=$PROJECT_TYPE"
  echo "claude_md=$claude_md_state"
  echo "generated=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
  echo "# <category> <source-sha256> <source-rel-path> <dest-rel-path>"
  printf '%s\n' "${manifest_lines[@]}"
} > "$MANIFEST"

# --- Summary --------------------------------------------------------------------
echo
echo "=== Setup complete ==="
echo "Commands copied to .claude/commands/:"
for c in "${copied_commands[@]}"; do
  echo "  - $c"
done
if [[ "$copied_templates" == true ]]; then
  echo "Templates copied from $ASSET_DIR_NAME/templates/ (existing files preserved)."
  if [[ "$templates_skipped" -gt 0 ]]; then
    echo "  ($templates_skipped template file(s) already existed and were left untouched;"
    echo "   they will show as LOCALLY MODIFIED in check-updates until reconciled.)"
  fi
fi
if [[ "$claude_created" == true ]]; then
  echo "CLAUDE.md assembled (fill in the ## Project section)."
fi
echo "INTERVIEW.md assembled."
echo "Manifest written to .claude/.template-manifest."
echo
echo "Next steps:"
echo "  1. Run INTERVIEW.md in a fresh Claude Code session to complete project setup."
echo "  2. Review and commit the assembled files to your project repo."
echo "  3. Later, run check-updates.sh from this project to pull in shared changes."
