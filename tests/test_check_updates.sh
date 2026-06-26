#!/usr/bin/env bash
# Tests for check-updates.sh — drift detection against the manifest.

# A freshly-assembled project is in sync with the shared repo it came from. This is
# the key guard that setup.sh and check-updates.sh agree on what gets installed
# (including the two-tier generic+asset template walk).
test_check_clean_after_setup_generic() {
  local p; p="$(make_project)"
  do_setup "$p" generic --no-repo >/dev/null 2>&1 || fail "setup exited $?"
  local out; out="$(do_check "$p" --no-pull)" || fail "check exited $?"
  assert_match "$out" "Up to date"
}

test_check_clean_after_setup_godot() {
  local p; p="$(make_project)"
  do_setup "$p" godot-game --no-repo >/dev/null 2>&1 || fail "setup exited $?"
  local out; out="$(do_check "$p" --no-pull)" || fail "check exited $?"
  assert_match "$out" "Up to date"
}

test_check_reports_and_reinstalls_missing() {
  local p; p="$(make_project)"
  do_setup "$p" godot-game --no-repo >/dev/null 2>&1 || fail "setup exited $?"
  rm -f "$p/scripts/run_tests.sh"

  local out rc=0
  out="$(do_check "$p" --no-pull)" || rc=$?
  assert_eq "$rc" "3" "actionable drift -> exit 3"
  assert_match "$out" "MISSING"

  do_check "$p" --no-pull --apply >/dev/null 2>&1 || fail "apply exited $?"
  assert_exec "$p/scripts/run_tests.sh"   # reinstalled, exec bit preserved
}

test_check_reports_locally_modified_and_respects_force() {
  local p; p="$(make_project)"
  do_setup "$p" generic --no-repo >/dev/null 2>&1 || fail "setup exited $?"
  printf '\nlocal edit\n' >> "$p/.claude/commands/code-review.md"

  local out; out="$(do_check "$p" --no-pull)"
  assert_match "$out" "LOCALLY MODIFIED"

  # --apply alone must not clobber a local edit...
  do_check "$p" --no-pull --apply >/dev/null 2>&1
  assert_grep "$p/.claude/commands/code-review.md" "local edit"
  # ...but --force overwrites it back to the shared copy.
  do_check "$p" --no-pull --apply --force >/dev/null 2>&1
  grep -q "local edit" "$p/.claude/commands/code-review.md" && fail "--force should have overwritten the local edit"
  return 0
}

test_check_reports_snippet_drift_only() {
  local p; p="$(make_project)"
  do_setup "$p" generic --no-repo >/dev/null 2>&1 || fail "setup exited $?"
  # Simulate an upstream snippet change in a private fixture copy.
  SHARED_FIXTURE="$(make_fixture)"
  printf '\nNEW UPSTREAM LINE\n' >> "$SHARED_FIXTURE/generic/claude-snippets/bash-conventions.md"

  local out; out="$(do_check "$p" --no-pull)"
  assert_match "$out" "SNIPPET DRIFT"
  # Snippet drift is report-only: --apply must never rewrite CLAUDE.md.
  local before; before="$(cat "$p/CLAUDE.md")"
  do_check "$p" --no-pull --apply >/dev/null 2>&1
  assert_eq "$(cat "$p/CLAUDE.md")" "$before" "CLAUDE.md untouched by --apply"
}

test_check_reports_and_applies_new_command() {
  local p; p="$(make_project)"
  do_setup "$p" generic --no-repo >/dev/null 2>&1 || fail "setup exited $?"
  # Add a brand-new generic command upstream.
  SHARED_FIXTURE="$(make_fixture)"
  printf -- '---\ndescription: x\n---\nhi\n' > "$SHARED_FIXTURE/generic/commands/brand-new.md"

  local out; out="$(do_check "$p" --no-pull)"
  assert_match "$out" "NEW"
  do_check "$p" --no-pull --apply >/dev/null 2>&1 || fail "apply exited $?"
  assert_file "$p/.claude/commands/brand-new.md"
}

test_check_no_manifest_fallback_requires_type() {
  local p; p="$(make_project)"
  do_setup "$p" generic --no-repo >/dev/null 2>&1 || fail "setup exited $?"
  rm -f "$p/.claude/.template-manifest"
  # Non-interactive with no --type is an error.
  assert_status 1 "no manifest, no --type" do_check "$p" --no-pull
  # With --type it falls back to a content comparison and reports up to date.
  local out; out="$(do_check "$p" --no-pull --type generic)" || fail "fallback exited $?"
  assert_match "$out" "Up to date"
}
