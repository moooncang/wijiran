extends "res://src/world/interactable.gd"
## Tutorial signpost: shows its text while the player stands near (T0 조작 안내).

var text := ""
var _s: Sprite2D


func _ready() -> void:
	super()
	label = ""
	radius = 60.0
	_s = Anim.prop_sprite("sign")
	add_child(_s)


func _draw_body() -> void:
	if near:
		draw_string(Anim.font, Vector2(-80, -70), text, HORIZONTAL_ALIGNMENT_LEFT, 160, 8, Color(1, 0.95, 0.85))
