extends SceneTree
# Usage: godot --headless -s tools/border_check.gd -- <sheet.png> <cell> <first> <count>
# Reports, per cell, opaque pixels touching the cell's 1px border (= art clipped by the cell) and the art bbox.
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var img := Image.load_from_file(a[0])
	var cell := int(a[1])
	var cols := img.get_width() / cell
	for i in range(int(a[2]), int(a[2]) + int(a[3])):
		var ox := (i % cols) * cell
		var oy := (i / cols) * cell
		var border := 0
		var minx := cell; var maxx := -1; var miny := cell; var maxy := -1
		for y in cell:
			for x in cell:
				if img.get_pixel(ox + x, oy + y).a > 0.5:
					minx = mini(minx, x); maxx = maxi(maxx, x); miny = mini(miny, y); maxy = maxi(maxy, y)
					if x == 0 or y == 0 or x == cell - 1 or y == cell - 1:
						border += 1
		print("slot %d border=%d bbox=[%d..%d, %d..%d]" % [i, border, minx, maxx, miny, maxy])
	quit(0)
