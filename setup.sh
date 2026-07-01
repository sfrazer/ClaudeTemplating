#!/usr/bin/env bash
# setup.sh — assemble Claude Code commands, snippets, templates, and an interview
# prompt into the current project, based on a chosen project type.
#
# Usage:
#   ./setup.sh                 # interactive menu
#   ./setup.sh godot           # skip the menu
#
# By default, setup also creates a private GitHub repository for the project
# (via the GitHub CLI, gh) and wires it up as the 'origin' remote. It never
# reuses or overwrites an existing remote or GitHub repo — it aborts that step
# with a message instead. Control this with:
#   --no-repo                  # do not create a remote repository
#   --public                   # create the repo as public (default: private)
#
# The shared commands repo (the repo this script lives in) is located via the
# CLAUDE_SHARED_REPO environment variable, defaulting to ~/.claude-shared.
#
# Supported project types: generic, godot, love2d, puppet.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# --- Parse arguments ------------------------------------------------------------
CREATE_REPO=true
REPO_VISIBILITY=private
positional=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      sed -n '2,/^# Supported project types/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    --no-repo) CREATE_REPO=false; shift ;;
    --public)  REPO_VISIBILITY=public; shift ;;
    --private) REPO_VISIBILITY=private; shift ;;
    --)        shift; while [[ $# -gt 0 ]]; do positional+=("$1"); shift; done ;;
    -*)        echo "ERROR: unknown option '$1'. See --help." >&2; exit 1 ;;
    *)         positional+=("$1"); shift ;;
  esac
done

# --- Resolve the shared repo ----------------------------------------------------
SHARED_REPO="$(resolve_shared_repo)" || exit 1

# --- Choose the project type ----------------------------------------------------
PROJECT_TYPE="${positional[0]:-}"

if [[ -z "$PROJECT_TYPE" ]]; then
  if [[ ! -t 0 ]]; then
    echo "ERROR: no project type given and not running interactively." >&2
    echo "       Pass one as an argument, e.g. setup.sh godot" >&2
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
  manifest_lines+=("$category $(file_hash "$src") ${src#"$SHARED_REPO"/} $dest_rel")
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
# Templates compose like commands: generic templates ship to every project, then
# the asset type's templates layer on top (skipped for a generic project so the
# same tree is not walked twice). cp preserves the source mode, so files checked in
# executable (e.g. scripts/*.sh at 0755) arrive executable.
copied_templates=false
templates_skipped=0
provided_scripts=()   # rel-paths of installed *.sh — used to assemble settings.json
copy_templates_from() {
  local base="$1" tf rel dest
  [[ -d "$base" ]] || return 0
  copied_templates=true
  while IFS= read -r tf; do
    rel="${tf#"$base"/}"
    dest="$PROJECT_ROOT/$rel"
    mkdir -p "$(dirname "$dest")"
    if [[ -e "$dest" ]]; then
      templates_skipped=$((templates_skipped + 1))   # never overwrite an existing file
    else
      cp "$tf" "$dest"
    fi
    # A shipped shell script is meant to be run bare; collect it so settings.json
    # can auto-approve it. (Recorded even if the copy was skipped — the path, and
    # therefore the permission rule, is the same.)
    [[ "$rel" == *.sh ]] && provided_scripts+=("$rel")
    # Record the source regardless of whether we skipped a pre-existing file —
    # the checker compares against the project copy and flags local edits.
    record template "$tf" "$rel"
  done < <(find "$base" -type f ! -name .DS_Store)
}

copy_templates_from "$GENERIC_DIR/templates"
if [[ "$ASSET_DIR_NAME" != "generic" ]]; then
  copy_templates_from "$ASSET_DIR/templates"
fi

# --- Assemble .claude/settings.json ---------------------------------------------
# Emit permission allow-rules so the provided scripts auto-approve when run bare
# (the Bash Conventions snippet tells Claude to invoke them that way). For each
# script we allow four literal forms: an exact rule (the bare, no-argument command,
# which a trailing wildcard does NOT reliably match) and a `<cmd> *` wildcard (for
# trailing args), each for both the plain and ./-prefixed path (Bash rules match the
# literal string Claude sends, so those differ). The space-wildcard form is the one
# Claude Code itself writes on "allow and remember". An env-var prefix such as
# `CODE_REVIEW_MODEL=x scripts/code_review.sh` is a different literal string and is
# not covered — approve that once if you use it. Generated with plain bash (no jq);
# left untouched if the project already has a settings.json so hand-written rules
# are never clobbered.
settings_state=none
SETTINGS="$PROJECT_ROOT/.claude/settings.json"
if [[ ${#provided_scripts[@]} -gt 0 ]]; then
  if [[ -e "$SETTINGS" ]]; then
    settings_state=preexisting
  else
    # Build the unique, sorted rule list. Per script: exact + ` *` wildcard, for
    # both the plain and ./-prefixed path (four literal forms).
    rules=()
    sorted_rules=()
    for s in "${provided_scripts[@]}"; do
      rules+=("Bash($s)" "Bash($s *)" "Bash(./$s)" "Bash(./$s *)")
    done
    while IFS= read -r rule; do sorted_rules+=("$rule"); done \
      < <(printf '%s\n' "${rules[@]}" | sort -u)
    {
      echo '{'
      echo '  "permissions": {'
      echo '    "allow": ['
      n=${#sorted_rules[@]}
      for i in "${!sorted_rules[@]}"; do
        comma=','
        [[ $i -eq $((n - 1)) ]] && comma=''
        printf '      "%s"%s\n' "${sorted_rules[$i]}" "$comma"
      done
      echo '    ]'
      echo '  }'
      echo '}'
    } > "$SETTINGS"
    settings_state=assembled
  fi
fi

# --- Assemble CLAUDE.md ---------------------------------------------------------
# Snippet sources, in concatenation order: the generic snippets first in a fixed
# order (wiki-contract, git-workflow, then bash-conventions), then asset snippets
# alphabetically.
snippet_files=("$GENERIC_DIR/claude-snippets/wiki-contract.md" "$GENERIC_DIR/claude-snippets/git-workflow.md" "$GENERIC_DIR/claude-snippets/bash-conventions.md")
if [[ "$ASSET_DIR_NAME" != "generic" && -d "$ASSET_DIR/claude-snippets" ]]; then
  shopt -s nullglob
  asset_snippets=("$ASSET_DIR/claude-snippets"/*.md)
  shopt -u nullglob
  # Guard the array expansion: an empty array under `set -u` errors on bash 3.2.
  if [[ ${#asset_snippets[@]} -gt 0 ]]; then
    while IFS= read -r f; do
      snippet_files+=("$f")
    done < <(printf '%s\n' "${asset_snippets[@]}" | sort)
  fi
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
  overlay_name="$(overlay_for "$PROJECT_TYPE")"
  if [[ -n "$overlay_name" ]]; then
    overlay="$SHARED_REPO/interviews/overlays/$overlay_name.md"
    if [[ -f "$overlay" ]]; then
      echo
      echo
      cat "$overlay"
    fi
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

# --- Optionally create a GitHub remote repository -------------------------------
# On by default; suppress with --no-repo. This step is deliberately conservative:
# it refuses to touch a pre-existing 'origin' remote or a GitHub repo that
# already exists, aborting with a message instead. That guards against the
# classic footgun of rebuilding into a repository you forgot to delete.
repo_result=""
create_remote_repo() {
  local visibility="$1" name
  name="$(basename "$PROJECT_ROOT")"

  if ! command -v gh >/dev/null 2>&1; then
    echo "WARNING: GitHub CLI (gh) not found — skipping remote repo creation." >&2
    echo "         Install it (https://cli.github.com) or pass --no-repo to silence this." >&2
    repo_result="skipped (gh not installed)"
    return
  fi
  if ! gh auth status >/dev/null 2>&1; then
    echo "WARNING: gh is not authenticated — skipping remote repo creation." >&2
    echo "         Run 'gh auth login', or pass --no-repo to silence this." >&2
    repo_result="skipped (gh not authenticated)"
    return
  fi
  if git -C "$PROJECT_ROOT" remote get-url origin >/dev/null 2>&1; then
    echo "WARNING: a git remote 'origin' already exists — NOT creating or rewiring a repo." >&2
    echo "         Existing origin: $(git -C "$PROJECT_ROOT" remote get-url origin)" >&2
    repo_result="skipped (origin already configured)"
    return
  fi
  if gh repo view "$name" >/dev/null 2>&1; then
    echo "WARNING: a GitHub repo named '$name' already exists for this account —" >&2
    echo "         NOT touching it. Delete/rename it, create the remote manually, or pass" >&2
    echo "         --no-repo. (This avoids rebuilding into a repo you forgot to delete.)" >&2
    repo_result="skipped ('$name' already exists on GitHub)"
    return
  fi

  # gh repo create --source requires an existing local git repo to attach to.
  if [[ ! -d "$PROJECT_ROOT/.git" ]]; then
    git -C "$PROJECT_ROOT" init >/dev/null
  fi

  echo "Creating $visibility GitHub repository '$name'..."
  if gh repo create "$name" "--$visibility" --source="$PROJECT_ROOT" --remote=origin; then
    repo_result="created $visibility repo '$name' as 'origin' (nothing pushed yet)"
  else
    echo "WARNING: 'gh repo create' failed — see output above." >&2
    repo_result="failed (gh repo create error)"
  fi
}

if [[ "$CREATE_REPO" == true ]]; then
  create_remote_repo "$REPO_VISIBILITY"
else
  repo_result="skipped (--no-repo)"
fi

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
case "$settings_state" in
  assembled)   echo ".claude/settings.json assembled (allow-rules for the provided scripts)." ;;
  preexisting) echo ".claude/settings.json already exists — left untouched (add allow-rules for"
               echo "  the provided scripts by hand if you want them auto-approved)." ;;
esac
echo "INTERVIEW.md assembled."
echo "Manifest written to .claude/.template-manifest."
if [[ -n "$repo_result" ]]; then
  echo "Remote repo: $repo_result."
fi
echo
echo "Next steps:"
echo "  1. Run INTERVIEW.md in a fresh Claude Code session to complete project setup."
echo "  2. Review and commit the assembled files to your project repo."
echo "  3. Later, run check-updates.sh from this project to pull in shared changes."
