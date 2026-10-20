extends Node2D
## Greybox look for a solid rectangle (platform / cover / floor piece).

var rect := Rect2()
var color := Color(0.3, 0.22, 0.16)


func _draw() -> void:
	draw_rect(rect, color)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3)), color.lightened(0.25))
	draw_rect(rect, color.darkened(0.35), false, 1.0)
