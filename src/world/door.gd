extends "res://src/world/interactable.gd"
## Map exit: ↑ travels to target_level/spawn. `requires` names a flag that must be set (e.g. a boss beaten).

var target_level := ""
var target_spawn := "start"
var requires := ""


func available() -> bool:
	return requires == "" or Game.flag(requires)


func _use() -> void:
	Game.travel(target_level, target_spawn)


func _draw_body() -> void:
	var open := available()
	draw_rect(Rect2(-24, -74, 6, 74), Color(0.36, 0.25, 0.16))
	draw_rect(Rect2(18, -74, 6, 74), Color(0.36, 0.25, 0.16))
	draw_rect(Rect2(-28, -80, 56, 6), Color(0.45, 0.3, 0.18))
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	var col := Color(1.0, 0.72, 0.3, 0.3 + 0.25 * pulse) if open else Color(0.5, 0.45, 0.5, 0.25)
	for i in 3:
		draw_arc(Vector2(0, -38), 14.0 + i * 5.0 + pulse * 2.0, 0.0, TAU, 24, col, 2.0)
	if not open:
		draw_string(Anim.font, Vector2(-30, -96), "닫힘", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.8, 0.6, 0.6))
