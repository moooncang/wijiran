extends SceneTree
# Usage: godot --headless -s tools/crop.gd -- <in.png> <out.png> <x> <y> <w> <h> <scale>
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var img := Image.load_from_file(a[0])
	var r := Rect2i(int(a[2]), int(a[3]), int(a[4]), int(a[5]))
	var c := img.get_region(r)
	c.resize(c.get_width() * int(a[6]), c.get_height() * int(a[6]), Image.INTERPOLATE_NEAREST)
	c.save_png(a[1])
	print("saved ", a[1], " ", c.get_size())
	quit(0)
