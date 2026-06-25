extends Node

# Autoload: captures a screenshot after WAIT_FRAMES rendered frames then quits.
# Activated by godot_screenshot.sh via a temporary project.godot override.
# Output path is read from OS environment variable SCREENSHOT_PATH,
# defaulting to /tmp/godot_screenshot.png.

const WAIT_FRAMES: int = 8

var _frames_waited: int = 0


func _process(_delta: float) -> void:
	_frames_waited += 1
	if _frames_waited < WAIT_FRAMES:
		return
	var path: String = OS.get_environment("SCREENSHOT_PATH")
	if path.is_empty():
		path = "/tmp/godot_screenshot.png"
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(path)
	print("Screenshot saved: ", path)
	get_tree().quit()
