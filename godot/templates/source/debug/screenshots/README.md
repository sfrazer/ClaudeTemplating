# Screenshots

Home for screenshot captures worth keeping as visual-regression references, and for any
reusable scenario scripts that drive a scene into a non-default state.

Most captures are throwaway — render with `/screenshot-check` (or
`source/debug/tests/godot_screenshot.sh`) to a `/tmp` path, look at it, discard it. Only
commit a capture (and its `SCREENSHOT_SETUP` scenario script) here when a particular
state is worth tracking over time.

See the `SCREENSHOT_SETUP` hook documented in `screenshot_helper.gd` and the
`/screenshot-check` command for how to capture interaction-dependent states.
