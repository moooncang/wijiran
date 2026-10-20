extends "res://src/world/interactable.gd"
## 비급 (palm manual) on the ground. W/↑ collects it: permanent, never auto-equips, one notice (장법 기획 §3).
## A collected manual is inert on re-entry; nearby combat must be over first.

var manual_id := ""
var _s: Sprite2D
var _g: Sprite2D


func _ready() -> void:
	super()
	label = "비급 줍기"
	_g = Anim.prop_sprite("manual_glow")
	add_child(_g)
	_s = Anim.prop_sprite("manual")
	add_child(_s)


func available() -> bool:
	if Game.has_manual(manual_id):
		return false
	var lv := get_parent()
	return not (lv is Level and lv._enemy_count > 0)


func locked_hint() -> String:
	return "" if Game.has_manual(manual_id) else "적을 모두 쓰러뜨린 뒤 주울 수 있다"


func _use() -> void:
	Game.collect_manual(manual_id)
	Juice.fx("parry_perfect_fx", global_position + Vector2(0, -20))


func _draw_body() -> void:
	if Game.has_manual(manual_id):
		Anim.prop_frame(_s, "manual_taken", 0)
		_g.visible = false
		return
	Anim.prop_frame(_s, "manual", int(_t * 6.0))
	Anim.prop_frame(_g, "manual_glow", int(_t * 6.0))
