extends "res://src/world/interactable.gd"
## 휴식 지점: standing here allows palm equipping (Game.at_rest_point); ↑ opens the palm menu.
## A target dummy is placed next to it by the level data so the new style can be tried (기획 §3).

func _ready() -> void:
	super()
	label = "장법 (Tab)"
	radius = 40.0


func _process(delta: float) -> void:
	super(delta)
	if near:
		Game.at_rest_point = true
	elif Game.at_rest_point and _was_near:
		Game.at_rest_point = false
	_was_near = near


var _was_near := false


func _use() -> void:
	var menu := get_tree().get_first_node_in_group("palm_menu")
	if menu:
		menu.open()


func _draw_body() -> void:
	draw_rect(Rect2(-30, -6, 60, 6), Color(0.35, 0.25, 0.16))
	draw_rect(Rect2(-26, -34, 8, 28), Color(0.3, 0.22, 0.14))
	draw_rect(Rect2(18, -34, 8, 28), Color(0.3, 0.22, 0.14))
	draw_rect(Rect2(-30, -40, 60, 6), Color(0.45, 0.3, 0.18))
	draw_circle(Vector2(0, -52), 6.0, Color(1.0, 0.75, 0.4, 0.6 + 0.2 * sin(_t * 3.0)))
