extends Control
## 장법 메뉴 (장법 기획 §7): Tab toggles. Left: owned styles (undiscovered ones show as unknown entries);
## right: role, strikes, traits, costs, one strength and one caution, equip state. Equipping only works at
## a rest point while neutral; elsewhere the button says so. Opening pauses the game (menu pause, not hitstop).

var selected := 0
var _open := false


func _ready() -> void:
	add_to_group("palm_menu")
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)


func open() -> void:
	_open = true
	visible = true
	var ids := PalmStyles.ids()
	selected = maxi(0, ids.find(Game.equipped_palm()))
	Game.set_paused(true)
	queue_redraw()


func close() -> void:
	_open = false
	visible = false
	Game.set_paused(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		if _open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
		return
	if not _open:
		return
	var ids := PalmStyles.ids()
	if event.is_action_pressed("ui_down") or event.is_action_pressed("crouch"):
		selected = (selected + 1) % ids.size()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("interact"):
		selected = (selected - 1 + ids.size()) % ids.size()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("attack_key"):
		var id: String = ids[selected]
		if Game.unlocked_palms().has(id):
			if not Game.equip_palm(id):
				Game.notice.emit("휴식 지점에서 장착할 수 있습니다")
	elif event.is_action_pressed("ui_cancel"):
		close()
	queue_redraw()


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.02, 0.01, 0.03, 0.82))
	var font := Anim.font
	draw_string(font, Vector2(60, 50), "장법  (Tab 닫기 · ↑↓ 선택 · J/Enter 장착)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.9, 0.8))
	var ids := PalmStyles.ids()
	var y := 90.0
	for i in ids.size():
		var id: String = ids[i]
		var owned: bool = Game.unlocked_palms().has(id)
		var s := PalmStyles.style(id)
		var col := Color(1, 0.95, 0.9) if owned else Color(0.45, 0.4, 0.45)
		if i == selected:
			draw_rect(Rect2(50, y - 14, 200, 22), Color(0.6, 0.15, 0.2, 0.5))
		var name: String = ("%s %s" % [s.name, s.hanja]) if owned else "미발견 장법"
		if id == Game.equipped_palm():
			name += "  ● 장착 중"
		draw_string(font, Vector2(60, y), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)
		y += 30
	var sid: String = ids[selected]
	if not Game.unlocked_palms().has(sid):
		draw_string(font, Vector2(290, 100), "비급을 찾으면 열립니다.", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.7, 0.65, 0.7))
		return
	var st := PalmStyles.style(sid)
	var x := 290.0
	var ty := 92.0
	var lines: Array = [
		["%s %s" % [st.name, st.hanja], 12, Color(1, 0.85, 0.7)],
		[String(st.role), 9, Color(0.95, 0.93, 0.9)],
		["", 8, Color.WHITE],
	]
	for i in 3:
		var a: Dictionary = st.light[i]
		lines.append(["%d타 %s — %s" % [i + 1, a.name, _kind_text(a)], 9, Color(0.9, 0.88, 0.85)])
	var h: Dictionary = st.heavy
	lines.append(["강화 %s — %s · 내공 %d · 마열 +%d" % [h.name, _kind_text(h), int(h.qi_cost), int(h.rift_gain)], 9, Color(0.9, 0.88, 0.85)])
	lines.append(["", 8, Color.WHITE])
	lines.append(["특성: " + String(st.traits), 9, Color(0.85, 0.9, 0.95)])
	lines.append(["장점: " + String(st.strength), 9, Color(0.8, 0.95, 0.8)])
	lines.append(["주의: " + String(st.caution), 9, Color(1, 0.8, 0.7)])
	lines.append(["", 8, Color.WHITE])
	if sid == Game.equipped_palm():
		lines.append(["장착 중", 10, Color(1, 0.9, 0.6)])
	elif Game.can_equip_now():
		lines.append(["[J / Enter] 장착", 10, Color(1, 0.95, 0.85)])
	else:
		lines.append(["휴식 지점에서 장착할 수 있습니다", 10, Color(0.8, 0.7, 0.7)])
	for l in lines:
		draw_string(font, Vector2(x, ty), l[0], HORIZONTAL_ALIGNMENT_LEFT, 460, l[1], l[2])
		ty += 20 if l[1] >= 10 else 16


func _kind_text(a: Dictionary) -> String:
	var k := String(a.kind)
	var base: String = {"thrust": "전방 돌진 타격", "spin": "몸 주위 원형 타격", "burst": "손끝 발경 · 내상 폭발", "front_burst": "전방 발경 · 내상 폭발"}.get(k, k)
	if a.get("injury_burst", false):
		base += " (×%d/스택)" % int(a.burst_per_stack)
	elif int(a.get("injury", 0)) > 0:
		base += " · 내상 +%d" % int(a.injury)
	if String(a.get("targets", "multi")) == "single":
		base += " · 단일 대상"
	return base
