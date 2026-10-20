extends Node2D
## Greybox backdrops per map style, drawn once. Replaced by painted layers in a later delivery.

var style := "yard"
var width := 1600.0
var ground_y := 300.0


func _draw() -> void:
	match style:
		"yard":
			draw_rect(Rect2(-200, -400, width + 400, ground_y + 400), Color(0.09, 0.09, 0.14))
			for i in int(width / 150.0) + 2:
				var x := i * 150.0 - 100.0
				var top := ground_y - 150.0 - (i % 3) * 20.0
				draw_rect(Rect2(x, top, 60, ground_y - top), Color(0.11, 0.12, 0.18))
				draw_colored_polygon(PackedVector2Array([Vector2(x - 14, top), Vector2(x + 30, top - 26), Vector2(x + 74, top)]), Color(0.11, 0.12, 0.18))
			draw_rect(Rect2(-200, ground_y - 330, width + 400, 90), Color(0.13, 0.15, 0.22))  # the sheared mountain face
		"forest":
			draw_rect(Rect2(-200, -400, width + 400, ground_y + 400), Color(0.07, 0.08, 0.07))
			for i in int(width / 90.0) + 3:
				var x := i * 90.0 - 120.0 + (i % 2) * 30.0
				var h := 170.0 + (i * 37 % 90)
				var burnt := i % 3 != 0
				draw_rect(Rect2(x, ground_y - h, 14, h), Color(0.12, 0.1, 0.09) if burnt else Color(0.16, 0.2, 0.12))
				if burnt:
					draw_line(Vector2(x + 7, ground_y - h), Vector2(x + 34, ground_y - h - 40), Color(0.12, 0.1, 0.09), 4.0)
				else:
					draw_circle(Vector2(x + 7, ground_y - h - 10), 26.0, Color(0.14, 0.22, 0.12))
			draw_rect(Rect2(-200, ground_y - 8, width + 400, 8), Color(0.2, 0.16, 0.1))
		"clearing":
			draw_rect(Rect2(-200, -400, width + 400, ground_y + 400), Color(0.08, 0.1, 0.09))
			draw_rect(Rect2(width * 0.5 - 90, ground_y - 330, 180, 330), Color(0.16, 0.13, 0.1))  # the half world-tree stump
			draw_circle(Vector2(width * 0.5, ground_y - 330), 120.0, Color(0.14, 0.2, 0.12))
			for i in int(width / 120.0) + 2:
				var x := i * 120.0 - 60.0
				draw_rect(Rect2(x, ground_y - 110, 10, 110), Color(0.11, 0.1, 0.09))
		_:
			draw_rect(Rect2(-200, -400, width + 400, ground_y + 400), Color(0.1, 0.1, 0.12))
