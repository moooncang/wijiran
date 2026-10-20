extends "res://src/world/interactable.gd"
## Map exit: W/↑ travels to target_level/spawn; the prompt reads "→ destination" (label from the level data:
## the place, plus " — boss" for a boss room). `requires` names a flag that must be set (e.g. a boss
## beaten); until then standing here says why it is shut.

var target_level := ""
var target_spawn := "start"
var requires := ""
var _s: Sprite2D


func _ready() -> void:
	super()
	label = "→ " + label
	_s = Anim.prop_sprite("door_closed")
	add_child(_s)


func available() -> bool:
	return requires == "" or Game.flag(requires)


func locked_hint() -> String:
	return "닫힘 — 적을 쓰러뜨리면 열린다"


func _use() -> void:
	Game.travel(target_level, target_spawn)


func _draw_body() -> void:
	if available():
		Anim.prop_frame(_s, "door_open", int(_t * 6.0))
	else:
		Anim.prop_frame(_s, "door_closed", 0)
