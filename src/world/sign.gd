extends "res://src/world/interactable.gd"
## Tutorial signpost: shows its text while the player stands near (T0 조작 안내).

var text := ""


func _ready() -> void:
	super()
	label = ""
	radius = 60.0


func _draw_body() -> void:
	draw_rect(Rect2(-2, -40, 4, 40), Color(0.35, 0.25, 0.16))
	draw_rect(Rect2(-22, -56, 44, 18), Color(0.5, 0.38, 0.24))
	if near:
		draw_string(Anim.font, Vector2(-80, -70), text, HORIZONTAL_ALIGNMENT_LEFT, 160, 8, Color(1, 0.95, 0.85))
