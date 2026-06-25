extends Node

# Autoload: captures a screenshot after a number of rendered frames, then quits.
# Activated by godot_screenshot.sh via a temporary project.godot override.
#
# Output path is read from the SCREENSHOT_PATH environment variable, defaulting to
# /tmp/godot_screenshot.png. The frame count is read from SCREENSHOT_WAIT_FRAMES,
# defaulting to DEFAULT_WAIT_FRAMES (high enough to let streaming/procedural
# _ready chains settle). Quits with code 1 if the image cannot be written.

const DEFAULT_WAIT_FRAMES: int = 30
const DEFAULT_PATH: String = "/tmp/godot_screenshot.png"

var _frames_waited: int = 0
var _wait_frames: int = DEFAULT_WAIT_FRAMES


func _ready() -> void:
	var env_frames: String = OS.get_environment("SCREENSHOT_WAIT_FRAMES")
	if env_frames.is_valid_int():
		_wait_frames = maxi(1, env_frames.to_int())


func _process(_delta: float) -> void:
	_frames_waited += 1
	if _frames_waited < _wait_frames:
		return
	var path: String = OS.get_environment("SCREENSHOT_PATH")
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
