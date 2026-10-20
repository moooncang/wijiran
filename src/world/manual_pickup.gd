extends "res://src/world/interactable.gd"
## 비급 (palm manual) on the ground. ↑ collects it: permanent, never auto-equips, one notice (장법 기획 §3).
## A collected manual is inert on re-entry; nearby combat must be over first.

var manual_id := ""


func _ready() -> void:
	super()
	label = "비급 줍기"


func available() -> bool:
	if Game.has_manual(manual_id):
		return false
	var lv := get_parent()
	return not (lv is Level and lv._enemy_count > 0)


func _use() -> void:
	Game.collect_manual(manual_id)
	Juice.fx("parry_perfect_fx", global_position + Vector2(0, -20))


func _draw_body() -> void:
	if Game.has_manual(manual_id):
		draw_rect(Rect2(-10, -8, 20, 8), Color(0.3, 0.25, 0.2))  # the empty case
		return
	var bob := sin(_t * 2.5) * 2.0
	draw_rect(Rect2(-11, -22 + bob, 22, 14), Color(0.86, 0.8, 0.66))
	draw_rect(Rect2(-11, -22 + bob, 22, 14), Color(0.3, 0.2, 0.14), false, 1.0)
	draw_rect(Rect2(-2, -22 + bob, 4, 14), Color(0.7, 0.15, 0.15))
	draw_circle(Vector2(0, -15 + bob), 18.0, Color(1.0, 0.6, 0.4, 0.08 + 0.05 * sin(_t * 4.0)))
