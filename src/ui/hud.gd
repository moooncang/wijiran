extends Control
## Combat HUD (기획서 14장): HP, 내공, 마열 with erosion warning, 월식 gauge, tremor time, parry grade stamp.
## Icons come from hud.png (16px); numbers are always drawn beside bars so colour is never the only cue.

var player: Player
var show_skills := true   # touch devices use on-screen buttons instead of the key panel
var _stamp_left := 0.0
var _stamp := ""
var _last_parry := ""


func _process(delta: float) -> void:
	if player == null:
		return
	if player.last_parry != _last_parry:
		_last_parry = player.last_parry
		if _last_parry.begins_with("PERFECT"):
			_stamp = "parry_perfect"
			_stamp_left = 0.8
		elif _last_parry.begins_with("PARTIAL"):
			_stamp = "parry_partial"
			_stamp_left = 0.8
	_stamp_left = maxf(0.0, _stamp_left - delta)
	queue_redraw()


func _icon(name: String, at: Vector2) -> void:
	var i := int(Anim.hud_icons[name])
	draw_texture_rect_region(Anim.hud_texture, Rect2(at, Vector2(16, 16)), Rect2((i % 8) * 16, (i / 8) * 16, 16, 16))


func _bar(at: Vector2, w: float, value: float, max_value: float, color: Color, text: String) -> void:
	draw_rect(Rect2(at, Vector2(w, 6)), Color(0.12, 0.1, 0.14))
	draw_rect(Rect2(at, Vector2(w * clampf(value / max_value, 0.0, 1.0), 6)), color)
	draw_string(Anim.font, at + Vector2(w + 4, 6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.9, 0.88, 0.9))


## One line per skill: key, name, requirement, and the live reason it is or is not usable (기획서 14장).
func _skill_lines() -> Array:
	var grounded_free: bool = player.action() == Player.Action.FREE and player.is_on_floor() and not player.crouching and not player.swinging()
	var lines: Array = []
	var st := PalmStyles.style(player.style_id)
	lines.append(["좌클릭/J", String(st.name), "%s → %s → %s" % [st.light[0].name, st.light[1].name, st.light[2].name], not player.swinging() and player.swing_cooldown == 0.0])
	lines.append(["Space", "패링", "완전 0.10초 · 부분 0.25초", player.action() == Player.Action.FREE])
	var dash_reason := "재사용 %.1f" % player.dash_cooldown if player.dash_cooldown > 0.0 else ""
	lines.append(["Shift", "잔월보", "마우스 방향 360° · 무적 0.02~0.13초", player.dash_cooldown == 0.0 and (player.is_on_floor() or player.air_dash_available), dash_reason if dash_reason != "" else ("" if player.is_on_floor() or player.air_dash_available else "공중 1회 사용함")])
	lines.append(["W", "허공답월", "공중에서 1회", player.air_jump_available, "" if player.air_jump_available else "착지 후 회복"])
	var heavy_reason := ""
	if player.tremor_left > 0.0:
		heavy_reason = "수전증 %.1f" % player.tremor_left
	elif player.qi < float(st.heavy.qi_cost):
		heavy_reason = "내공 부족 %d/%d" % [int(player.qi), int(st.heavy.qi_cost)]
	elif not grounded_free:
		heavy_reason = "지상 대기 중에만"
	var pull_reason := ""
	if player.pull_cooldown > 0.0:
		pull_reason = "재사용 %.1f" % player.pull_cooldown
	elif player.qi < Player.PULL_QI:
		pull_reason = "내공 부족 %d/20" % int(player.qi)
	lines.append(["우클릭/F", "월인", "조준 방향 적을 당김 · 보스면 내가 끌려감 · 내공 20", pull_reason == "", pull_reason])
	lines.append(["E", String(st.heavy.name), "내공 %d · 마열 +%d%s" % [int(st.heavy.qi_cost), int(st.heavy.rift_gain), " · 과열 ×1.2" if player.overheated() else ""], heavy_reason == "", heavy_reason])
	var ult_reason := ""
	if player.tremor_left > 0.0:
		ult_reason = "수전증 %.1f" % player.tremor_left
	elif player.ult_cooldown > 0.0:
		ult_reason = "재사용 %.0f초" % player.ult_cooldown
	elif player.gauge < CombatConfig.ULT_GAUGE_COST:
		ult_reason = "게이지 %d/100" % int(player.gauge)
	elif player.qi < CombatConfig.ULT_QI_COST:
		ult_reason = "내공 부족 %d/60" % int(player.qi)
	elif not grounded_free:
		ult_reason = "지상 대기 중에만"
	lines.append(["Q", "월식", "내공 60 · 게이지 100 · 반경 150", ult_reason == "", ult_reason])
	return lines


func _draw() -> void:
	if player == null:
		return
	var vp := get_viewport_rect().size
	var x := vp.x - 192.0
	var y := 8.0
	# skill panel, bottom right
	var font := Anim.font
	var py := vp.y - 18.0 - 11.0 * 7
	for line in (_skill_lines() if show_skills else []):
		var ok: bool = line[3]
		var reason: String = line[4] if line.size() > 4 else ""
		var col := Color(0.85, 0.95, 0.8) if ok else Color(0.55, 0.5, 0.55)
		draw_string(font, Vector2(vp.x - 300, py), "%s  %s" % [line[0], line[1]], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
		draw_string(font, Vector2(vp.x - 190, py), line[2] if reason == "" else reason, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, col if reason == "" else Color(1, 0.7, 0.55))
		py += 11
	_icon("hp", Vector2(x, y))
	_bar(Vector2(x + 20, y + 5), 90, player.hp, CombatConfig.PLAYER_MAX_HP, Color(0.85, 0.3, 0.4), str(player.hp))
	y += 18
	_icon("energy", Vector2(x, y))
	_bar(Vector2(x + 20, y + 5), 90, player.qi, CombatConfig.QI_MAX, Color(0.4, 0.6, 0.95), "%d" % int(player.qi))
	y += 18
	_icon("heat", Vector2(x, y))
	var heat_text := "%d" % int(player.rift)
	if player.eroded:
		heat_text += " 침식"
	elif player.overheated():
		heat_text += " 과열"
	_bar(Vector2(x + 20, y + 5), 90, player.rift, CombatConfig.RIFT_MAX, Color(0.95, 0.5, 0.2) if not player.eroded else Color(0.6, 0.1, 0.3), heat_text)
	y += 18
	_icon("ultimate", Vector2(x, y))
	var ult_text := "%d" % int(player.gauge)
	if player.ult_cooldown > 0.0:
		ult_text += " 대기 %.0f" % player.ult_cooldown
	_bar(Vector2(x + 20, y + 5), 90, player.gauge, CombatConfig.ULT_GAUGE_COST, Color(0.75, 0.3, 0.8), ult_text)
	y += 18
	if player.tremor_left > 0.0:
		_icon("tremor", Vector2(x, y))
		draw_string(Anim.font, Vector2(x + 20, y + 11), "수전증 %.1f" % player.tremor_left, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.8, 0.5))
	if _stamp_left > 0.0:
		_icon(_stamp, Vector2(300, 60))
		draw_string(Anim.font, Vector2(318, 71), "PERFECT" if _stamp == "parry_perfect" else "PARTIAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE if _stamp == "parry_perfect" else Color(0.7, 0.7, 0.75))
	if player.notice_left > 0.0:
		draw_string(Anim.font, Vector2(280, 90), player.notice, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 0.75, 0.6))
