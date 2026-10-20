extends Control
## Boss bar for any BossBase (name, HP with the 60% late mark, posture, state text). The 9차 frame art
## is used when present; the bar stays readable without it.

var boss: Node


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if boss == null or not is_instance_valid(boss):
		return
	var vp := get_viewport_rect().size
	var x := (vp.x - 400.0) * 0.5
	var y := 10.0
	var st: EnemyStatus = boss.status
	draw_rect(Rect2(x - 2, y - 2, 404, 12), Color(0.1, 0.07, 0.06))
	draw_rect(Rect2(x, y, 400 * clampf(st.hp / st.max_hp, 0.0, 1.0), 8), Color(0.94, 0.78, 0.44))
	var late_x := x + 400.0 * float(boss.get("late_fraction") if boss.get("late_fraction") != null else 0.6)
	draw_rect(Rect2(late_x - 1, y - 2, 2, 12), Color(0.3, 0.2, 0.15))
	draw_rect(Rect2(x, y + 14, 400 * clampf(st.posture / st.posture_max, 0.0, 1.0), 3), Color(0.85, 0.82, 0.75))
	var name: String = String(boss.get("boss_name")) if boss.get("boss_name") != null else "보스"
	if name == "티아넬":
		draw_texture(Anim.ui_tex("tianel_hud_portrait"), Vector2(x - 40, y - 2))
	draw_string(Anim.font, Vector2(x, y + 32), "%s  %d / %d" % [name, int(ceil(st.hp)), int(st.max_hp)], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.98, 0.9, 0.75))
	var text := ""
	if boss.get("beaten") == true or not st.alive():
		text = "돌파"
	elif st.staggered():
		text = "기절 %.1f" % st.stagger_left
	elif boss.get("pattern") is Dictionary and not (boss.get("pattern") as Dictionary).is_empty():
		text = String((boss.get("pattern") as Dictionary).get("name", ""))
	if text != "":
		draw_string(Anim.font, Vector2(x + 260, y + 32), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 0.8, 0.5))
