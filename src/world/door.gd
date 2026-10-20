extends "res://src/world/interactable.gd"
## Map exit: ↑ travels to target_level/spawn. `requires` names a flag that must be set (e.g. a boss beaten).

var target_level := ""
var target_spawn := "start"
var requires := ""
var _s: Sprite2D


func _ready() -> void:
	super()
	_s = Anim.prop_sprite("door_closed")
	add_child(_s)


func available() -> bool:
	return requires == "" or Game.flag(requires)


func _use() -> void:
	Game.travel(target_level, target_spawn)


func _draw_body() -> void:
	var open := available()
	if open:
		Anim.prop_frame(_s, "door_open", int(_t * 6.0))
	else:
		Anim.prop_frame(_s, "door_closed", 0)
		draw_string(Anim.font, Vector2(-30, -96), "닫힘", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.8, 0.6, 0.6))
