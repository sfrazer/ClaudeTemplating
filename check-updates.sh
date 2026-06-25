#!/usr/bin/env bash
# check-updates.sh — report (and optionally apply) shared-repo changes to commands,
# snippets, and templates installed in the current project.
#
# Run from a project root. Compares installed files against the shared repo using
# the install manifest written by setup.sh (.claude/.template-manifest).
#
# Usage:
#   ./check-updates.sh                 # report drift, exit non-zero if any
#   ./check-updates.sh --apply         # copy new/updated commands & templates in
#   ./check-updates.sh --apply --force # also overwrite locally-modified files
#   ./check-updates.sh --no-pull       # skip the git pull of the shared repo
#   ./check-updates.sh --type <type>   # project type, for the no-manifest fallback
#
# Exit codes: 0 = up to date (or all drift applied), 3 = actionable drift remains.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# --- Parse flags ----------------------------------------------------------------
APPLY=false
FORCE=false
PULL=true
TYPE_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)   APPLY=true ;;
    --force)   FORCE=true ;;
    --no-pull) PULL=false ;;
    --type)    TYPE_ARG="${2:-}"; shift ;;
    -h|--help)
      sed -n '2,/^# Exit codes/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "ERROR: unknown argument '$1'" >&2; exit 1 ;;
  esac
  shift
done

SHARED_REPO="$(resolve_shared_repo)" || exit 1
PROJECT_ROOT="$(pwd)"
MANIFEST="$PROJECT_ROOT/.claude/.template-manifest"

$PULL && pull_shared_repo "$SHARED_REPO"

# enumerate_candidates <project-type> — print "category src-rel dest-rel" for every
# file the shared repo would install for this type.
enumerate_candidates() {
  local type="$1" asset f
  asset="$(asset_dir_for "$type")"
  shopt -s nullglob
  for f in "$SHARED_REPO/generic/commands"/*.md; do
    echo "command ${f#$SHARED_REPO/} .claude/commands/$(basename "$f")"
  done
  for f in "$SHARED_REPO/generic/claude-snippets"/*.md; do
    echo "snippet ${f#$SHARED_REPO/} CLAUDE.md"
  done
  if [[ "$asset" != "generic" ]]; then
    for f in "$SHARED_REPO/$asset/commands"/*.md; do
      echo "command ${f#$SHARED_REPO/} .claude/commands/$(basename "$f")"
    done
    for f in "$SHARED_REPO/$asset/claude-snippets"/*.md; do
      echo "snippet ${f#$SHARED_REPO/} CLAUDE.md"
    done
  fi
  shopt -u nullglob
  if [[ -d "$SHARED_REPO/$asset/templates" ]]; then
    while IFS= read -r f; do
      echo "template ${f#$SHARED_REPO/} ${f#$SHARED_REPO/$asset/templates/}"
    done < <(find "$SHARED_REPO/$asset/templates" -type f ! -name .DS_Store)
  fi
}

# Report buckets (display strings).
rep_new=(); rep_update=(); rep_missing=(); rep_modified=(); rep_snippet=(); rep_removed=()
# Applicable items (parallel arrays) — things --apply can copy.
ap_src=(); ap_srcabs=(); ap_destabs=(); ap_cat=(); ap_kind=()
uptodate=0

add_applicable() {
  ap_src+=("$1"); ap_srcabs+=("$2"); ap_destabs+=("$3"); ap_cat+=("$4"); ap_kind+=("$5")
}

if [[ -f "$MANIFEST" ]]; then
  # ===== Manifest mode =====================================================
  MANIFEST_TYPE="$(grep '^type=' "$MANIFEST" | head -1 | cut -d= -f2)"
  if [[ -z "${MANIFEST_TYPE:-}" || -z "$(asset_dir_for "$MANIFEST_TYPE")" ]]; then
    echo "ERROR: manifest has missing or unknown project type." >&2
    exit 1
  fi
  if [[ -n "$TYPE_ARG" && "$TYPE_ARG" != "$MANIFEST_TYPE" ]]; then
    echo "ERROR: --type '$TYPE_ARG' conflicts with manifest type '$MANIFEST_TYPE'." >&2
    echo "       --type is only for the no-manifest fallback; omit it here." >&2
    exit 1
  fi

  # Parse manifest entries into parallel arrays.
  m_cat=(); m_hash=(); m_src=(); m_dest=()
  snippets_tracked=false
  while IFS= read -r line; do
    case "$line" in
      ""|\#*|type=*|generated=*|claude_md=*) continue ;;
    esac
    read -r c h s d <<< "$line"
    m_cat+=("$c"); m_hash+=("$h"); m_src+=("$s"); m_dest+=("$d")
    [[ "$c" == "snippet" ]] && snippets_tracked=true
  done < "$MANIFEST"

  index_of() { # echo index of $1 in m_src, or -1
    local target="$1" i
    [[ ${#m_src[@]} -eq 0 ]] && { echo "-1"; return; }
    for i in "${!m_src[@]}"; do
      [[ "${m_src[$i]}" == "$target" ]] && { echo "$i"; return; }
    done
    echo "-1"
  }

  echo "Project type: $MANIFEST_TYPE"
  echo "Shared repo:  $SHARED_REPO"
  echo

  cand_src_list=""
  while read -r ccat csrc cdest; do
    cand_src_list="$cand_src_list $csrc"
    src_abs="$SHARED_REPO/$csrc"
    cur_src="$(file_hash "$src_abs")"
    idx="$(index_of "$csrc")"

    if [[ "$idx" -lt 0 ]]; then
      # Not in manifest → newly added upstream.
      if [[ "$ccat" == "snippet" ]]; then
        $snippets_tracked && rep_new+=("snippet  $csrc  (NEW — merge into CLAUDE.md by hand)")
        continue
      fi
      rep_new+=("$ccat  $cdest  (NEW)")
      add_applicable "$csrc" "$src_abs" "$PROJECT_ROOT/$cdest" "$ccat" "new"
      continue
    fi

    recorded="${m_hash[$idx]}"

    if [[ "$ccat" == "snippet" ]]; then
      if [[ "$cur_src" != "$recorded" ]]; then
        rep_snippet+=("$csrc  (changed upstream — CLAUDE.md may be stale)")
      else
        uptodate=$((uptodate + 1))
      fi
      continue
    fi

    dest_abs="$PROJECT_ROOT/$cdest"
    cur_dest="$(file_hash "$dest_abs")"
    if [[ -z "$cur_dest" ]]; then
      rep_missing+=("$cdest  (installed previously, now missing)")
      add_applicable "$csrc" "$src_abs" "$dest_abs" "$ccat" "missing"
    elif [[ "$cur_dest" == "$recorded" ]]; then
      if [[ "$cur_src" != "$recorded" ]]; then
        rep_update+=("$cdest")
        add_applicable "$csrc" "$src_abs" "$dest_abs" "$ccat" "update"
      else
        uptodate=$((uptodate + 1))
      fi
    else
      note=""
      [[ "$cur_src" != "$recorded" ]] && note="  (and upstream changed)"
      rep_modified+=("$cdest$note")
      add_applicable "$csrc" "$src_abs" "$dest_abs" "$ccat" "modified"
    fi
  done < <(enumerate_candidates "$MANIFEST_TYPE")

  # Sources in the manifest that the shared repo no longer offers.
  if [[ ${#m_src[@]} -gt 0 ]]; then
    for i in "${!m_src[@]}"; do
      case " $cand_src_list " in
        *" ${m_src[$i]} "*) : ;;
        *) rep_removed+=("${m_src[$i]}  (no longer in shared repo)") ;;
      esac
    done
  fi

else
  # ===== Fallback mode (no manifest) =======================================
  echo "No manifest found at .claude/.template-manifest."
  echo "Falling back to a direct content comparison (cannot tell local edits from"
  echo "upstream updates). Re-run setup.sh to generate a manifest for precise checks."
  echo

  MANIFEST_TYPE="$TYPE_ARG"
  if [[ -z "$MANIFEST_TYPE" ]]; then
    if [[ -t 0 ]]; then
      echo "Select the project type:"
      select choice in "${PROJECT_TYPES[@]}"; do
        [[ -n "${choice:-}" ]] && { MANIFEST_TYPE="$choice"; break; }
      done
    else
      echo "ERROR: no manifest and no --type given. Pass --type <project-type>." >&2
      exit 1
    fi
  fi
  if [[ -z "$(asset_dir_for "$MANIFEST_TYPE")" ]]; then
    echo "ERROR: unknown project type '$MANIFEST_TYPE'. Supported: ${PROJECT_TYPES[*]}" >&2
    exit 1
  fi
  snippets_tracked=false

  while read -r ccat csrc cdest; do
    [[ "$ccat" == "snippet" ]] && continue  # CLAUDE.md is hand-assembled; not tracked here
    src_abs="$SHARED_REPO/$csrc"
    dest_abs="$PROJECT_ROOT/$cdest"
    if [[ ! -f "$dest_abs" ]]; then
      rep_new+=("$ccat  $cdest  (not installed)")
      add_applicable "$csrc" "$src_abs" "$dest_abs" "$ccat" "new"
    elif [[ "$(file_hash "$src_abs")" != "$(file_hash "$dest_abs")" ]]; then
      rep_modified+=("$cdest  (differs from shared)")
      add_applicable "$csrc" "$src_abs" "$dest_abs" "$ccat" "modified"
    else
      uptodate=$((uptodate + 1))
    fi
  done < <(enumerate_candidates "$MANIFEST_TYPE")
fi

# --- Print the report -----------------------------------------------------------
# Print "title" then one "  - item" per remaining arg. Call only with >0 items so
# empty-array expansion never happens (bash 3.2 + set -u safe).
print_section() {
  local title="$1"; shift
  echo "$title"
  printf '  - %s\n' "$@"
  echo
}

n_new=${#rep_new[@]}; n_update=${#rep_update[@]}; n_missing=${#rep_missing[@]}
n_modified=${#rep_modified[@]}; n_snippet=${#rep_snippet[@]}; n_removed=${#rep_removed[@]}

[[ $n_new      -gt 0 ]] && print_section "NEW (available upstream):"    "${rep_new[@]}"
[[ $n_update   -gt 0 ]] && print_section "UPDATE (changed upstream):"   "${rep_update[@]}"
[[ $n_missing  -gt 0 ]] && print_section "MISSING (re-installable):"    "${rep_missing[@]}"
[[ $n_modified -gt 0 ]] && print_section "LOCALLY MODIFIED:"           "${rep_modified[@]}"
[[ $n_snippet  -gt 0 ]] && print_section "SNIPPET DRIFT (report-only):" "${rep_snippet[@]}"
[[ $n_removed  -gt 0 ]] && print_section "REMOVED UPSTREAM (info):"     "${rep_removed[@]}"

total_actionable=$((n_new + n_update + n_missing + n_modified + n_snippet))

if [[ $total_actionable -eq 0 ]]; then
  echo "Up to date ($uptodate tracked files in sync)."
  exit 0
fi

# --- Apply ----------------------------------------------------------------------
applied=0
if $APPLY && [[ ${#ap_src[@]} -gt 0 ]]; then
  echo "Applying..."
  for i in "${!ap_src[@]}"; do
    kind="${ap_kind[$i]}"
    if [[ "$kind" == "modified" ]] && ! $FORCE; then
      echo "  skip (locally modified): ${ap_destabs[$i]#$PROJECT_ROOT/}"
      continue
    fi
    mkdir -p "$(dirname "${ap_destabs[$i]}")"
    cp "${ap_srcabs[$i]}" "${ap_destabs[$i]}"
    echo "  wrote: ${ap_destabs[$i]#$PROJECT_ROOT/}"
    applied=$((applied + 1))

    # Refresh manifest state (manifest mode only).
    if [[ -f "$MANIFEST" ]]; then
      newhash="$(file_hash "${ap_srcabs[$i]}")"
      idx="$(index_of "${ap_src[$i]}")"
      if [[ "$idx" -lt 0 ]]; then
        m_cat+=("${ap_cat[$i]}"); m_hash+=("$newhash")
        m_src+=("${ap_src[$i]}"); m_dest+=("${ap_destabs[$i]#$PROJECT_ROOT/}")
      else
        m_hash[$idx]="$newhash"
      fi
    fi
  done
  echo

  if [[ -f "$MANIFEST" && $applied -gt 0 ]]; then
    {
      echo "# ClaudeTemplating install manifest — managed by setup.sh; do not edit"
      echo "type=$MANIFEST_TYPE"
      echo "generated=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      echo
      echo "# <category> <source-sha256> <source-rel-path> <dest-rel-path>"
      for i in "${!m_src[@]}"; do
        echo "${m_cat[$i]} ${m_hash[$i]} ${m_src[$i]} ${m_dest[$i]}"
      done
    } > "$MANIFEST"
    echo "Manifest refreshed."
  fi
fi

if $APPLY && [[ $n_snippet -gt 0 ]]; then
  echo "NOTE: snippet changes are not applied automatically — reconcile CLAUDE.md by hand."
fi

# --- Exit code ------------------------------------------------------------------
remaining=$((total_actionable - applied))
if [[ $remaining -gt 0 ]]; then
  $APPLY || echo "Run with --apply to install new/updated commands and templates."
  exit 3
fi
exit 0
