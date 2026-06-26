---
description: Run the Godot screenshot tool and analyse the output for errors and correct rendering.
argument-hint: "[res://path/to/scene.tscn] [output.png]"
---

Run the Godot screenshot tool and analyse the output for errors.

Run the helper bare — just the path and its arguments. Do not pipe, redirect, or chain
it with other commands (e.g. an `--import` step or `grep`); a compound line cannot be
statically analyzed and will prompt. Run any other steps as their own bare commands.

1. Run the screenshot helper script:

`source/debug/tests/godot_screenshot.sh`

To capture a specific scene:

`source/debug/tests/godot_screenshot.sh res://path/to/scene.tscn /tmp/task_screenshot.png`

To open the result in Preview after capture (macOS) (only do this if user requests seeing the screenshot):

`source/debug/tests/godot_screenshot.sh --preview res://path/to/scene.tscn /tmp/task_screenshot.png`

2. Check the exit code. A non-zero exit means errors were detected in the log —
   review them before proceeding.
3. If the screenshot was saved, examine it visually and confirm the scene renders
   as expected.
4. If errors are present, address them before marking the task complete.
