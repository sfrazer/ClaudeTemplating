#!/usr/bin/env bash
# Tests for lib/common.sh — the supported-type contract and helpers.

test_common_asset_dir_mapping() {
  # shellcheck source=/dev/null
  source "$COMMON"
  assert_eq "$(asset_dir_for generic)"    "generic" "generic maps to generic"
  assert_eq "$(asset_dir_for godot-game)" "godot"   "godot-game maps to godot"
  assert_eq "$(asset_dir_for nonsense)"   ""        "unknown type maps to empty"
}

test_common_project_types_contract() {
  # shellcheck source=/dev/null
  source "$COMMON"
  assert_match " ${PROJECT_TYPES[*]} " " generic "
  assert_match " ${PROJECT_TYPES[*]} " " godot-game "
}

test_common_file_hash_matches_shasum() {
  # shellcheck source=/dev/null
  source "$COMMON"
  local f="$TEST_TMP/hash-me.txt"
  printf 'hello\n' > "$f"
  assert_eq "$(file_hash "$f")" "$(shasum -a 256 "$f" | awk '{print $1}')" "sha256"
}

test_common_file_hash_missing_is_empty() {
  # shellcheck source=/dev/null
  source "$COMMON"
  assert_eq "$(file_hash "$TEST_TMP/does-not-exist")" "" "missing file -> empty hash"
}

test_common_resolve_shared_repo() {
  # shellcheck source=/dev/null
  source "$COMMON"
  # Present directory is echoed back.
  assert_eq "$(CLAUDE_SHARED_REPO="$SHARED_FIXTURE" resolve_shared_repo)" "$SHARED_FIXTURE" "resolves to set repo"
  # Missing directory returns non-zero with guidance.
  local rc=0
  ( CLAUDE_SHARED_REPO="$TEST_TMP/nope-not-here" resolve_shared_repo ) >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "1" "missing repo errors"
}
