extends "res://src/world/interactable.gd"
## 비급 (palm manual) on the ground. W/↑ collects it: permanent, never auto-equips, one notice (장법 기획 §3).
## A collected manual is inert on re-entry; nearby combat must be over first. The F3 manual (투골장 · 극의)
## sits in a sealed 무간교 case instead (개편안 §8): unsealed on use, open while the manual is taken, then empty.

var manual_id := ""
var _s: Sprite2D
var _g: Sprite2D
var _case: Sprite2D
var _opened := -1.0


func _ready() -> void:
	super()
	if manual_id == "f3_cart_manual":
		label = "봉인함 열기"
		_case = Sprite2D.new()
		_case.texture = Anim.tex("props/r12_bp_sealed_case.png")
		_case.hframes = 3
		_case.centered = false
		_case.offset = Vector2(-48, -88)
		add_child(_case)
		return
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
	return "" if Game.has_manual(manual_id) else "적을 모두 쓰러뜨린 뒤 열 수 있다"


func _process(delta: float) -> void:
	super(delta)
	if _opened >= 0.0:
		_opened += delta


func _use() -> void:
	Game.collect_manual(manual_id)
	if _case:
		_opened = 0.0
		Juice.fx("r12_bp_unseal", global_position)
		return
	Juice.fx("parry_perfect_fx", global_position + Vector2(0, -20))


func _draw_body() -> void:
	if _case:
		_case.frame = 0 if not Game.has_manual(manual_id) else (1 if _opened >= 0.0 and _opened < 1.2 else 2)
		return
	if Game.has_manual(manual_id):
		Anim.prop_frame(_s, "manual_taken", 0)
		_g.visible = false
		return
	Anim.prop_frame(_s, "manual", int(_t * 6.0))
	Anim.prop_frame(_g, "manual_glow", int(_t * 6.0))
