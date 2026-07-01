#!/usr/bin/env bash
# common.sh — shared helpers for setup.sh and check-updates.sh.
# Source this file; do not execute it directly.

# Supported project types and their asset directory inside the shared repo.
# Part of the sourced contract: setup.sh and check-updates.sh both rely on
# PROJECT_TYPES (menus/validation), asset_dir_for (type -> folder mapping), and
# overlay_for (type -> interview overlay). Any new script that sources this file
# gets the same supported-type set.
# shellcheck disable=SC2034  # consumed by scripts that source this file
PROJECT_TYPES=("generic" "godot" "love2d" "puppet")

# asset_dir_for <project-type> — echo the asset folder for a project type, or
# empty string if the type is unknown. (Type and folder happen to match today,
# but the mapping is kept explicit so a type can diverge from its folder.)
asset_dir_for() {
  case "$1" in
    generic) echo "generic" ;;
    godot)   echo "godot" ;;
    love2d)  echo "love2d" ;;
    puppet)  echo "puppet" ;;
    *)       echo "" ;;
  esac
}

# overlay_for <project-type> — echo the interview overlay basename (without the
# .md extension) for a project type, or empty string if the type has no overlay.
# Game types share a single "game" overlay; puppet has its own; generic has none.
overlay_for() {
  case "$1" in
    godot|love2d) echo "game" ;;
    puppet)       echo "puppet" ;;
    *)            echo "" ;;
  esac
}

# resolve_shared_repo — echo the shared repo path, or return 1 with guidance if it
# cannot be found. Honours CLAUDE_SHARED_REPO, defaulting to ~/.claude-shared.
# Call as: SHARED_REPO="$(resolve_shared_repo)" || exit 1
resolve_shared_repo() {
  local repo="${CLAUDE_SHARED_REPO:-$HOME/.claude-shared}"
  if [[ ! -d "$repo" ]]; then
    cat >&2 <<EOF
ERROR: shared commands repo not found at: $repo

Set CLAUDE_SHARED_REPO to the location of this repo, e.g.:

    export CLAUDE_SHARED_REPO=/path/to/ClaudeTemplating

or clone/symlink it to the default location:

    git clone <repo-url> ~/.claude-shared
EOF
    return 1
  fi
  echo "$repo"
}

# pull_shared_repo <repo> — best-effort fast-forward pull of the shared repo.
# Never fails the caller; warns and continues on error.
pull_shared_repo() {
  local repo="$1"
  if [[ -d "$repo/.git" ]]; then
    echo "Pulling latest from shared repo..."
    git -C "$repo" pull --ff-only || \
      echo "WARNING: could not pull shared repo (continuing with local copy)." >&2
    echo
  fi
}

# file_hash <path> — echo the sha256 of a file, or empty string if missing.
# Uses shasum (present on macOS; sha256sum is not).
file_hash() {
  local path="$1"
  [[ -f "$path" ]] || return 0
  shasum -a 256 "$path" | awk '{print $1}'
}
