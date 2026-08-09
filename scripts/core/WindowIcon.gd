extends Node

## Autoload: WindowIcon
## Sets the OS window/taskbar icon at startup.
##
## The taskbar shows the icon of the running process, not the shortcut that
## launched it, so without this the game shows Godot's default robot while the
## desktop shortcut shows the throne. Godot cannot load .ico at runtime, so this
## uses a PNG generated from the same source as tools/Godsfall.ico.
##
## The call is deferred a frame: setting the icon before the window exists is
## silently ignored, which leaves the default robot in place.

const ICON_PATH := "res://icon_window.png"


func _ready() -> void:
	await get_tree().process_frame
	_apply()


func _apply() -> void:
	# Load through the resource system, not Image.load_from_file(): the latter
	# warns "this will not work on export" on every launch, which would pollute
	# logs/errors.log. This requires icon_window.png.import to exist.
	var tex: Texture2D = load(ICON_PATH)
	if tex == null:
		push_error("WindowIcon: could not load %s" % ICON_PATH)
		return

	var img := tex.get_image()
	if img == null:
		push_error("WindowIcon: %s has no image data" % ICON_PATH)
		return

	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)

	DisplayServer.set_icon(img)
