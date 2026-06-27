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

**Capturing a non-default state (setup hook).** Some visuals only exist after
interaction — selection handles, a drag/hover state, a loaded view. Set
`SCREENSHOT_SETUP` to a `res://` GDScript with a `setup(scene)` method; the helper runs
it after the scene settles and before capture. `setup` may be a coroutine, so it can
`await get_tree().process_frame` and then drive nodes or feed synthetic input.
`scene` is `get_tree().current_scene`.

```
SCREENSHOT_SETUP=res://path/to/scenario.gd \
  source/debug/tests/godot_screenshot.sh res://path/to/scene.tscn /tmp/task_screenshot.png
```

```gdscript
# scenario.gd — throwaway unless the state is worth keeping as a reusable scenario
extends RefCounted
func setup(scene: Node) -> void:
    await scene.get_tree().process_frame
    scene.some_node.do_something()   # select, drag, load, etc.
```

Keep scenario scripts throwaway (delete after capturing) unless a particular state earns
a permanent home. Tune timing with `SCREENSHOT_WAIT_FRAMES` (default 30). A misconfigured
`SCREENSHOT_SETUP` (missing script or no `setup` method) fails fast with a non-zero exit.

2. Check the exit code. A non-zero exit means errors were detected in the log —
   review them before proceeding.
3. If the screenshot was saved, examine it visually and confirm the scene renders
   as expected.
4. If errors are present, address them before marking the task complete.
