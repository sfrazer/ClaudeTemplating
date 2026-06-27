extends Node

# Autoload: lets a scene settle, optionally drives it into a non-default state via a
# setup hook, captures a screenshot, then quits. Activated by godot_screenshot.sh via a
# temporary project.godot override.
#
# Environment (all read here, inherited from godot_screenshot.sh's process):
#   SCREENSHOT_PATH         Where to save the PNG (default: /tmp/godot_screenshot.png).
#   SCREENSHOT_WAIT_FRAMES  Frames to wait before the setup hook + capture (default 30;
#                           high enough to let streaming/procedural _ready chains settle).
#   SCREENSHOT_SETUP        Optional res:// path to a GDScript with a `setup(scene)`
#                           method, run after the wait and before capture, to put the
#                           scene in the state you want to photograph (select something,
#                           drive input, load data). `setup` may be a coroutine (it is
#                           awaited), so it can `await get_tree().process_frame` itself.
#                           `scene` is `get_tree().current_scene`.
#
# Quits 0 on success, 1 if the setup hook can't be loaded or the image can't be written.

const DEFAULT_WAIT_FRAMES: int = 30
const DEFAULT_PATH: String = "/tmp/godot_screenshot.png"


func _ready() -> void:
	# Drive the whole flow as a coroutine so the optional setup hook can await frames.
	_run()


func _run() -> void:
	var wait_frames := DEFAULT_WAIT_FRAMES
	var env_frames := OS.get_environment("SCREENSHOT_WAIT_FRAMES")
	if env_frames.is_valid_int():
		wait_frames = maxi(1, env_frames.to_int())

	for _i in wait_frames:
		await get_tree().process_frame

	if not await _run_setup_hook():
		return  # the hook already reported the error and quit

	# One more frame so any setup-driven redraw (e.g. queue_redraw) is rendered.
	await get_tree().process_frame
	_capture_and_quit()


# Runs SCREENSHOT_SETUP's `setup(scene)` if set. Returns false (after quitting with an
# error) when the script is configured but unusable; true otherwise (including when no
# hook is configured).
func _run_setup_hook() -> bool:
	var setup_path := OS.get_environment("SCREENSHOT_SETUP")
	if setup_path.is_empty():
		return true

	if not ResourceLoader.exists(setup_path):
		return _fail("SCREENSHOT_SETUP script not found: %s" % setup_path)
	var script := load(setup_path) as GDScript
	if script == null:
		return _fail("SCREENSHOT_SETUP is not a GDScript: %s" % setup_path)
	var runner: Object = script.new()
	if not runner.has_method("setup"):
		return _fail("SCREENSHOT_SETUP script has no setup(scene) method: %s" % setup_path)

	# `setup` may or may not be a coroutine; awaiting handles both.
	await runner.setup(get_tree().current_scene)
	return true


func _capture_and_quit() -> void:
	var path := OS.get_environment("SCREENSHOT_PATH")
	if path.is_empty():
		path = DEFAULT_PATH
	var image: Image = get_viewport().get_texture().get_image()
	var err: int = image.save_png(path)
	if err != OK:
		push_error("Screenshot save failed (error %d) for path: %s" % [err, path])
		get_tree().quit(1)
		return
	print("Screenshot saved: ", path)
	get_tree().quit(0)


func _fail(message: String) -> bool:
	push_error(message)
	get_tree().quit(1)
	return false
