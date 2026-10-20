extends SceneTree
# Usage: godot --headless -s tools/upscale.gd -- <in.png> <out.png> <scale>
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var img := Image.load_from_file(a[0])
	img.resize(img.get_width() * int(a[2]), img.get_height() * int(a[2]), Image.INTERPOLATE_NEAREST)
	img.save_png(a[1])
	print("saved ", a[1], " ", img.get_size())
	quit(0)
