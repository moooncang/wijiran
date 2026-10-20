extends "res://src/world/interactable.gd"
## 휴식 지점: standing here allows palm equipping (Game.at_rest_point); W/↑ opens the palm menu.
## A target dummy is placed next to it by the level data so the new style can be tried (기획 §3).

var _was_near := false
var _s: Sprite2D


func _ready() -> void:
	super()
	label = "장법 장착"
	radius = 40.0
	_s = Anim.prop_sprite("rest_point")
	add_child(_s)


func _process(delta: float) -> void:
	super(delta)
	if near:
		Game.at_rest_point = true
	elif Game.at_rest_point and _was_near:
		Game.at_rest_point = false
	_was_near = near


func _use() -> void:
	var menu := get_tree().get_first_node_in_group("palm_menu")
	if menu:
		menu.open()


func _draw_body() -> void:
	Anim.prop_frame(_s, "rest_point", int(_t * 8.0))
