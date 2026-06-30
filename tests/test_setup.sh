#!/usr/bin/env bash
# Tests for setup.sh — assembly of a fresh project.

test_setup_generic_assembles_expected_files() {
  local p; p="$(make_project)"
  do_setup "$p" generic --no-repo >/dev/null 2>&1 || fail "setup generic exited $?"
  assert_file "$p/.claude/commands/code-review.md"
  assert_file "$p/.claude/commands/run-tests.md"
  assert_file "$p/CLAUDE.md"
  assert_file "$p/INTERVIEW.md"
  assert_file "$p/.claude/.template-manifest"
  # The bash-conventions contract is concatenated into CLAUDE.md.
  assert_contains "$p/CLAUDE.md" "Prefer the simplest, standalone command"
  # The code-review command points at the wrapper, not an inline brace expansion.
  assert_contains "$p/.claude/commands/code-review.md" "scripts/code_review.sh"
}

test_setup_ships_generic_script_to_every_type() {
  # The /code-review wrapper is a generic template; it must reach a godot project too.
  local p; p="$(make_project)"
  do_setup "$p" godot --no-repo >/dev/null 2>&1 || fail "setup godot exited $?"
  assert_exec "$p/scripts/code_review.sh"
  assert_exec "$p/scripts/run_tests.sh"
  assert_exec "$p/source/debug/tests/godot_screenshot.sh"
}

test_setup_scripts_are_executable() {
  local p; p="$(make_project)"
  do_setup "$p" generic --no-repo >/dev/null 2>&1 || fail "setup exited $?"
  assert_exec "$p/scripts/code_review.sh"
}

test_setup_generates_settings_with_allow_rules() {
  local p; p="$(make_project)"
  do_setup "$p" godot --no-repo >/dev/null 2>&1 || fail "setup exited $?"
  assert_file "$p/.claude/settings.json"
  # Exact (bare) rules — the primary case, since the scripts are invoked bare.
  assert_grep "$p/.claude/settings.json" '"Bash\(scripts/code_review.sh\)"'
  assert_grep "$p/.claude/settings.json" '"Bash\(scripts/run_tests.sh\)"'
  assert_grep "$p/.claude/settings.json" '"Bash\(source/debug/tests/godot_screenshot.sh\)"'
  # Wildcard (with-args) and ./-prefixed forms also present.
  assert_grep "$p/.claude/settings.json" '"Bash\(scripts/run_tests.sh \*\)"'
  assert_grep "$p/.claude/settings.json" '"Bash\(\./scripts/run_tests.sh\)"'
  # Generic projects should not get a run_tests rule (no such script shipped).
  local g; g="$(make_project)"
  do_setup "$g" generic --no-repo >/dev/null 2>&1 || fail "setup generic exited $?"
  grep -q 'run_tests.sh' "$g/.claude/settings.json" && fail "generic settings.json should not mention run_tests.sh"
  return 0
}

test_setup_preserves_existing_settings_json() {
  local p; p="$(make_project)"
  mkdir -p "$p/.claude"
  printf '{"permissions":{"allow":["Bash(mine:*)"]}}\n' > "$p/.claude/settings.json"
  local out; out="$(do_setup "$p" generic --no-repo 2>&1)" || fail "setup exited $?"
  assert_contains "$p/.claude/settings.json" "Bash(mine:*)"
  grep -q 'code_review' "$p/.claude/settings.json" && fail "should not have rewritten settings.json"
  assert_match "$out" "left untouched"
}

test_setup_preserves_existing_claude_md() {
  local p; p="$(make_project)"
  printf 'KEEP ME\n' > "$p/CLAUDE.md"
  do_setup "$p" generic --no-repo >/dev/null 2>&1 || fail "setup exited $?"
  assert_eq "$(cat "$p/CLAUDE.md")" "KEEP ME" "existing CLAUDE.md untouched"
}

test_setup_manifest_records_templates_and_snippets() {
  local p; p="$(make_project)"
  do_setup "$p" godot --no-repo >/dev/null 2>&1 || fail "setup exited $?"
  assert_contains "$p/.claude/.template-manifest" "generic/templates/scripts/code_review.sh"
  assert_contains "$p/.claude/.template-manifest" "godot/templates/scripts/run_tests.sh"
  assert_contains "$p/.claude/.template-manifest" "type=godot"
}

test_setup_game_overlay_shared_by_godot() {
  # Game types pull in the shared "game" interview overlay; generic gets none.
  local p; p="$(make_project)"
  do_setup "$p" godot --no-repo >/dev/null 2>&1 || fail "setup godot exited $?"
  assert_contains "$p/INTERVIEW.md" "## Overlay: Game"
  local g; g="$(make_project)"
  do_setup "$g" generic --no-repo >/dev/null 2>&1 || fail "setup generic exited $?"
  grep -q "## Overlay:" "$g/INTERVIEW.md" && fail "generic INTERVIEW.md should have no overlay"
  return 0
}

test_setup_unknown_type_fails() {
  local p; p="$(make_project)"
  assert_status 1 "unknown type" do_setup "$p" not-a-type --no-repo
}
