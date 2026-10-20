extends Control
## Combat HUD (기획서 14장): HP, 내공, 마열 with erosion warning, 월식 gauge, tremor time, parry grade stamp.
## Icons come from hud.png (16px); every bar has a label and a number so colour is never the only cue.
## Layout (canvas px, UI 정리 2026-10-21): status block top-right, panel x 598–796 from y 4 (the boss
## bar's top) to ≤ 116; PC key panel bottom-right with the same right edge, ending y 446: three skill rows
## (from y 388, under the floor line at ~350) outside the tutorial yard, all seven there (from y 320), and
## nearly gone while the player or an enemy stands behind it; parry stamp centre y 190–215; player notices
## bottom-centre from y 372. All text goes through UiText, at whole-pixel x (fractional x thinned 11 px strokes).

const L := 604.0          # icon column (16 px icons, centre L + 8)
const R := 790.0          # content right edge: values and key states end here
const PANEL_X := L - 6.0  # both HUD panels keep 6 px around their content and end 4 px from the screen edge
const PANEL_R := R + 6.0
const PANEL_Y := 4.0      # same top as the boss bar
const TOP := 8.0          # first bar row
const TEXT_X := L + 21.0  # labels, palm name and status text share one column
const BAR_H := 6.0
const SEP := 5.0          # gap + 1 px rule + gap between the 월식 bar and the equipped palm
const PALM_H := 20.0      # palm row band: the 24 px palm cell has 2 px of empty margin around 20 px art
const KEY_CAP := 16.0     # key cap height: a 12 px label with its descender (Space's p) clear of the frame
const KEY_ROW := 17.0     # key panel pitch: caps 1 px apart
const KEY_FADED := 0.1    # key panel alpha while someone stands behind it: out of the way, not ghost text
const TRAIL := Color(0.45, 0.16, 0.22)   # recently lost HP: darker and duller than the fill, so the bar never reads full
const HP := Color(0.85, 0.3, 0.4)
const HP_PULSE := Color(1.0, 0.62, 0.68)   # low-HP throb brightens the fill instead of fading it
const TRAIL_HOLD := 0.45  # s before the trail drains (the boss bar does the same)
const OFF := Color(0.55, 0.5, 0.55)       # skill blocked right now
const LABEL := Color(0.9, 0.86, 0.82)     # bar labels: DIM grey lost the thin left stroke of 마 at 11 px
const TREMOR := Color(1.0, 0.8, 0.5)
const PURIFY := Color(0.86, 0.93, 1.0)
const PARTIAL := Color(0.86, 0.7, 0.58)   # muted warm: grey read like a disabled state
const STAMP_TIME := 0.8
const TOAST_FADE := 0.25
# widest texts the key panel's state column must hold
const STATE_SAMPLES := ["게이지 100/100", "착지 후 회복", "재사용 20", "지상에서만", "내공 부족"]
const VALUE_SAMPLES := ["100 침식", "재사용 20"]   # widest texts of the bar rows' right-aligned value column

var player: Player
var show_skills := true   # touch devices use on-screen buttons instead of the key panel
var _stamp_left := 0.0
var _stamp_perfect := true
var _last_parry := ""
var _last_recovery := 0.0
var _hp_trail := 0.0
var _trail_hold := 0.0
var _toast_text := ""
var _toast_age := 0.0
var _keys_rect := Rect2()
var _palm_key := ""
var _palm_tex: Texture2D
# child layers so the key panel, the toast and the stamp each fade as a whole (panel edge included)
var _keys: Control
var _toast: Control
var _stamp: Control


func _ready() -> void:
	_keys = _child(_draw_keys)
	_toast = _child(_draw_toast)
	_stamp = _child(_draw_stamp)


func _child(fn: Callable) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.visible = false   # _process decides; otherwise the key panel flashes for one frame on touch builds
	c.draw.connect(fn)
	add_child(c)
	return c


func _process(delta: float) -> void:
	if player == null:
		return
	# a fresh grade always raises parry_recovery, so two identical parries in a row both stamp
	if player.last_parry != _last_parry or player.parry_recovery > _last_recovery:
		_last_parry = player.last_parry
		if _last_parry.begins_with("PERFECT") or _last_parry.begins_with("PARTIAL"):
			_stamp_perfect = _last_parry.begins_with("PERFECT")
			_stamp_left = STAMP_TIME
	_last_recovery = player.parry_recovery
	_stamp_left = maxf(0.0, _stamp_left - delta)
	# damage trail: holds briefly, then drains half the bar per second; gone at once on death (no fake HP left)
	var hp := float(player.hp)
	if player.dead or hp >= _hp_trail:
		_hp_trail = hp
		_trail_hold = TRAIL_HOLD
	else:
		_trail_hold -= delta
		if _trail_hold <= 0.0:
			_hp_trail = maxf(hp, _hp_trail - CombatConfig.PLAYER_MAX_HP * 0.5 * delta)
	# a dead or unarmed (객잔) character has nothing to press: no key panel, no toasts
	_keys.visible = show_skills and player.combat_enabled and not player.dead
	if _keys.visible:
		_keys.modulate.a = move_toward(_keys.modulate.a, KEY_FADED if _keys_covering() else 1.0, delta * 6.0)
	var toast_on: bool = not player.dead and player.notice_left > 0.0 and player.notice != ""
	# the rise replays only for a new toast: mashing a blocked button just keeps the same one up
	if toast_on and (not _toast.visible or player.notice != _toast_text):
		_toast_text = player.notice
		_toast_age = 0.0
	_toast_age += delta
	_toast.visible = toast_on
	_toast.modulate.a = clampf(player.notice_left / TOAST_FADE, 0.0, 1.0)
	_stamp.visible = _stamp_left > 0.0 and not player.dead
	_stamp.modulate.a = minf(clampf((STAMP_TIME - _stamp_left) / 0.06, 0.0, 1.0), clampf(_stamp_left / 0.3, 0.0, 1.0))
	queue_redraw()
	for c in [_keys, _toast, _stamp]:
		if c.visible:
			c.queue_redraw()


## True while the player or a living, on-screen enemy stands where the key panel would hide it. Props and
## doors never count: they would keep the panel faded for a whole room with nobody near them.
func _keys_covering() -> bool:
	var vw := get_viewport_rect().size.x
	var nodes: Array = get_tree().get_nodes_in_group("enemy")
	nodes.append(player)
	for n in nodes:
		if not (n is CanvasItem) or not n.is_visible_in_tree():
			continue
		var st = n.get("status")
		if st != null and not st.alive():
			continue
		var p: Vector2 = n.get_global_transform_with_canvas().origin   # feet, in screen px
		if p.x >= 0.0 and p.x <= vw and _keys_rect.intersects(Rect2(p.x - 14.0, p.y - 48.0, 28.0, 48.0)):
			return true
	return false


func _icon(ci: CanvasItem, name: String, at: Vector2) -> void:
	var i := int(Anim.hud_icons[name])
	ci.draw_texture_rect_region(Anim.hud_texture, Rect2(at, Vector2(16, 16)), Rect2((i % 8) * 16, (i / 8) * 16, 16, 16))


func _fh(size: int) -> float:
	return UiText.font().get_height(size)


## Baseline that centres one line of `size` text in a band of height `h` starting at `top`.
func _baseline(top: float, h: float, size: int) -> float:
	var f := UiText.font()
	return roundf(top + (h - f.get_height(size)) * 0.5 + f.get_ascent(size))


## One line ending at `right`, started on a whole pixel: Godot's own right alignment left a fractional x,
## and at 11 px under the 1.6× window scale that dropped thin horizontal strokes (F → Γ, e → c).
func _right(ci: CanvasItem, right: float, base: float, text: String, size: int, color: Color, outline: int) -> void:
	UiText.draw(ci, Vector2(roundf(right - UiText.width(text, size)), base), text, size, color, outline)


## Every cooldown reads the same way, whole seconds rounded up, in the key panel and the 월식 row.
func _wait(seconds: float) -> String:
	return "재사용 %d" % ceili(seconds)


## One status row: icon, label, framed bar, value. Columns are sized for the widest label/value so bars never
## shift; values are right-aligned to the panel's inner edge. `trail` (≥ value) shows recently lost HP.
func _bar_row(y: float, row: float, icon: String, label: String, value: float, max_value: float, color: Color, text: String, text_color: Color = UiText.INK, trail: float = -1.0) -> void:
	var s := UiText.sz(UiText.S)
	var vw := 0.0
	for t in VALUE_SAMPLES:
		vw = maxf(vw, UiText.width(t, s))
	var bx := roundf(TEXT_X + UiText.width("마열", s) + 4.0)
	var bw := roundf(R - vw - 4.0 - bx)
	var by := y + roundf((row - BAR_H) * 0.5)
	var base := _baseline(y, row, s)
	_icon(self, icon, Vector2(L, y + floorf((row - 16.0) * 0.5)))
	UiText.draw(self, Vector2(TEXT_X, base), label, s, LABEL, 2)
	draw_rect(Rect2(bx - 1.0, by - 1.0, bw + 2.0, BAR_H + 2.0), UiText.OUTLINE)
	draw_rect(Rect2(bx, by, bw, BAR_H), Color(0.17, 0.14, 0.19))
	if trail > value:
		draw_rect(Rect2(bx, by, roundf(bw * clampf(trail / max_value, 0.0, 1.0)), BAR_H), TRAIL)
	draw_rect(Rect2(bx, by, roundf(bw * clampf(value / max_value, 0.0, 1.0)), BAR_H), color)
	_right(self, R, base, text, s, text_color, 2)


## One row per key: [key, name, usable now, state, state colour] (기획서 14장). Long descriptions live in
## the palm menu. A ready skill shows no state; a row dims only for a real blocker (cooldown, resource,
## tremor, airborne, parry recovery), never for a swing or a dash. The four movement/defence rows are listed
## only in the tutorial yard that teaches them; afterwards the panel keeps the three skills, whose rows carry
## cooldown and resource states, and stays under the floor line.
func _skill_lines() -> Array:
	var st := PalmStyles.style(player.style_id)
	var grounded := player.is_on_floor()
	var lines: Array = []
	if Game.level_id == "t0":
		lines.append(["좌클릭/J", "공격", true, "", UiText.DIM])
		lines.append(["Space", "패링", player.parry_recovery == 0.0, "", UiText.DIM])
		var dash_ok: bool = player.dash_cooldown == 0.0 and (grounded or player.air_dash_available)
		# the 0.28 s dash cooldown only dims the row: a number would flash by unreadably on every dash
		lines.append(["Shift", "잔월보", dash_ok, "" if dash_ok or player.dash_cooldown > 0.0 else "착지 후 회복", UiText.DIM])
		lines.append(["W", "허공답월", player.air_jump_available, "" if player.air_jump_available else "착지 후 회복", UiText.DIM])
	var pull := ""
	if player.pull_cooldown > 0.0:
		pull = _wait(player.pull_cooldown)
	elif player.qi < Player.PULL_QI:
		pull = "내공 부족"
	lines.append(["우클릭/F", "월인", pull == "", pull, UiText.WARN])
	var heavy := ""
	if player.tremor_left > 0.0:
		heavy = "수전증"   # the countdown lives in the status line, top right
	elif player.qi < float(st.heavy.qi_cost):
		heavy = "내공 부족"
	elif not grounded:
		heavy = "지상에서만"
	lines.append(["E", String(st.heavy.name), heavy == "", heavy, UiText.WARN])
	var ult := ""
	var ult_color := UiText.WARN
	if player.tremor_left > 0.0:
		ult = "수전증"
	elif player.ult_cooldown > 0.0:
		ult = _wait(player.ult_cooldown)
	elif player.gauge < CombatConfig.ULT_GAUGE_COST:
		ult = "게이지 %d/%d" % [int(player.gauge), int(CombatConfig.ULT_GAUGE_COST)]
		ult_color = UiText.DIM   # charging is progress, not a warning
	elif player.qi < CombatConfig.ULT_QI_COST:
		ult = "내공 부족"
	elif not grounded:
		ult = "지상에서만"
	lines.append(["Q", "월식", ult == "", ult, ult_color])
	return lines


## PC key panel, bottom-right on its own backing: key cap, skill name, right-aligned state.
func _draw_keys() -> void:
	var lines := _skill_lines()
	# caps and states at 12 px: at 11 px the 1.6× window scale dropped thin strokes (Shift's t, F's middle bar)
	var ks := UiText.sz(UiText.S + 1)
	var ns := UiText.sz(UiText.M)   # names: at 11 px the ㅓ of 허공답월 thinned to one pixel
	var kw := 0.0
	var nw := 0.0
	var sw := 0.0
	for line in lines:
		kw = maxf(kw, UiText.width(line[0], ks))
		nw = maxf(nw, UiText.width(line[1], ns))
	for t in STATE_SAMPLES:
		sw = maxf(sw, UiText.width(t, ks))
	kw = roundf(kw + 16.0)   # 8 px a side
	var w := roundf(6.0 + kw + 6.0 + nw + 8.0 + sw + 6.0)
	var h := KEY_ROW * lines.size() - (KEY_ROW - KEY_CAP) + 8.0   # 4 px margin above the first cap and under the last
	_keys_rect = Rect2(PANEL_R - w, get_viewport_rect().size.y - 4.0 - h, w, h)
	UiText.panel(_keys, _keys_rect)
	var caps: Array[Rect2] = []
	for i in lines.size():
		caps.append(Rect2(_keys_rect.position.x + 6.0, _keys_rect.position.y + 4.0 + KEY_ROW * i, kw, KEY_CAP))
	# every cap first, every label after, so no cap can paint over a neighbouring row's glyphs
	for i in lines.size():
		var ok: bool = lines[i][2]
		_keys.draw_rect(caps[i], Color(0.22, 0.16, 0.19) if ok else Color(0.12, 0.1, 0.12))
		_keys.draw_rect(caps[i], Color(UiText.PANEL_EDGE, 0.6 if ok else 0.25), false, 1.0)
	for i in lines.size():
		var line: Array = lines[i]
		var cap := caps[i]
		var ok: bool = line[2]
		var state: String = line[3]
		# ink centred in the 14 px inside the frame: caps' tops 2 px under it, Space's p 1 px above it
		var kb := cap.position.y + KEY_CAP - 4.0
		UiText.centered(_keys, cap.get_center().x, kb, line[0], ks, UiText.INK if ok else OFF, 0)
		UiText.draw(_keys, Vector2(cap.end.x + 6.0, _baseline(cap.position.y, KEY_CAP, ns)), line[1], ns, UiText.INK if ok else OFF, 0)
		if state != "":
			_right(_keys, _keys_rect.end.x - 6.0, kb, state, ks, line[4], 0)


## The status line under the palm row (수전증 / 정화): a 16 px icon or a ring marker, then the text;
## `extra` (" · 정화" while both are up) follows in the purify tint.
func _status_line(top: float, h: float, text: String, color: Color, icon: String, extra: String) -> void:
	var s := UiText.sz(UiText.S)
	var mid := top + h * 0.5
	if icon != "":
		_icon(self, icon, Vector2(L, floorf(mid - 8.0)))
	else:   # a small ring in the line's tint, like the ring around the player
		draw_arc(Vector2(L + 8.0, mid), 4.5, 0.0, TAU, 24, UiText.OUTLINE, 3.5, true)
		draw_arc(Vector2(L + 8.0, mid), 4.5, 0.0, TAU, 24, color, 1.5, true)
	var base := _baseline(top, h, s)
	UiText.draw(self, Vector2(TEXT_X, base), text, s, color, 2)
	if extra != "":
		UiText.draw(self, Vector2(roundf(TEXT_X + UiText.width(text, s)), base), extra, s, PURIFY, 2)


func _draw() -> void:
	if player == null:
		return
	var s := UiText.sz(UiText.S)
	var row := _fh(s) + (2.0 if UiText.touch else 3.0)   # touch text is 2 px taller: keeps the block above y 116
	var line_h := _fh(s) + 1.0
	var armed: bool = player.combat_enabled   # 객잔: only 체력 means anything there
	var full: bool = armed and not player.dead   # palm row and status line
	# one status line at most, so the block never grows into the notice band: tremor and purify share it
	var status: Array = []   # [text, colour, icon, purify suffix]
	if full and player.tremor_left > 0.0:
		status = ["수전증 %.1f" % player.tremor_left, TREMOR, "tremor", " · 정화" if player.purified() else ""]
	elif full and player.purified():
		status = ["정화 · 내상 폭발 위력 -30%", PURIFY, "", ""]
	# status block backing, sized to what is shown (a dead character keeps only the bars)
	var bottom := TOP + row * (4.0 if armed else 1.0)
	if full:
		bottom += SEP + PALM_H + (line_h if not status.is_empty() else 0.0)
	UiText.panel(self, Rect2(PANEL_X, PANEL_Y, PANEL_R - PANEL_X, bottom + 3.0 - PANEL_Y))
	var y := TOP
	var hp_low: bool = player.hp <= CombatConfig.PLAYER_MAX_HP * 0.3 and not player.dead
	var hp_color := HP
	if hp_low:   # ~1.5 Hz throb so low HP is noticed while watching the fight
		hp_color = HP.lerp(HP_PULSE, 0.5 - 0.5 * cos(Time.get_ticks_msec() * 0.001 * TAU * 1.5))
	_bar_row(y, row, "hp", "체력", player.hp, CombatConfig.PLAYER_MAX_HP, hp_color, str(player.hp), UiText.WARN if hp_low else UiText.INK, _hp_trail)
	y += row
	if not armed:
		return
	_bar_row(y, row, "energy", "내공", player.qi, CombatConfig.QI_MAX, Color(0.4, 0.6, 0.95), "%d" % int(player.qi))
	y += row
	var heat_text := "%d" % int(player.rift)
	if player.eroded:
		heat_text += " 침식"
	elif player.overheated():
		heat_text += " 과열"
	_bar_row(y, row, "heat", "마열", player.rift, CombatConfig.RIFT_MAX, Color(0.95, 0.5, 0.2) if not player.eroded else Color(0.75, 0.16, 0.38), heat_text, UiText.WARN if player.overheated() else UiText.INK)
	y += row
	var waiting: bool = player.ult_cooldown > 0.0
	_bar_row(y, row, "ultimate", "월식", player.gauge, CombatConfig.ULT_GAUGE_COST, Color(0.75, 0.3, 0.8), _wait(player.ult_cooldown) if waiting else "%d" % int(player.gauge), UiText.DIM if waiting else UiText.INK)
	y += row
	if not full:
		return
	# a faint rule sets the equipped palm apart: its crescent art read like a second 내공 icon
	draw_rect(Rect2(L, y + 2.0, R - L, 1.0), Color(UiText.PANEL_EDGE, 0.3))
	y += SEP
	# equipped palm (장법 기획 §7): name only; the key panel already says which key casts 월인
	var pst := PalmStyles.style(player.style_id)
	if _palm_key != String(pst.icon):
		_palm_key = String(pst.icon)
		_palm_tex = Anim.ui_tex(_palm_key)
	draw_texture(_palm_tex, Vector2(L - 4.0, y - 2.0))   # art centred on the icon column, 2 px inside the panel
	UiText.draw(self, Vector2(TEXT_X, _baseline(y, PALM_H, s)), String(pst.name), s, UiText.INK, 2)
	y += PALM_H
	if not status.is_empty():
		_status_line(y, line_h, status[0], status[1], status[2], status[3])


## Parry grade stamp, centre (y 190–215): fades in fast, drifts up 3 px, fades out over its last 0.3 s.
func _draw_stamp() -> void:
	var label := "완전 패링" if _stamp_perfect else "부분 패링"
	var ls := UiText.sz(UiText.L)
	var lift := roundf(3.0 * (1.0 - _stamp_left / STAMP_TIME))
	var x0 := roundf(get_viewport_rect().size.x * 0.5 - (20.0 + UiText.width(label, ls)) * 0.5)
	_icon(_stamp, "parry_perfect" if _stamp_perfect else "parry_partial", Vector2(x0, 194.0 - lift))
	UiText.draw(_stamp, Vector2(x0 + 20.0, _baseline(190.0 - lift, 25.0, ls)), label, ls, UiText.ACCENT if _stamp_perfect else PARTIAL)


## player._say feedback ("월인 · 내공 부족"): bottom-centre toast, clear of the dialogue box.
## Rises 3 px as a new toast appears; the alpha fade over the last TOAST_FADE s is set in _process.
func _draw_toast() -> void:
	var ns := UiText.sz(UiText.S)
	var rise := roundf(3.0 * clampf(1.0 - _toast_age / 0.15, 0.0, 1.0))
	var w := roundf(UiText.width(player.notice, ns) + 16.0)
	var r := Rect2(roundf(get_viewport_rect().size.x * 0.5 - w * 0.5), 372.0 + rise, w, _fh(ns) + 8.0)
	UiText.panel(_toast, r)
	UiText.draw(_toast, Vector2(r.position.x + 8.0, _baseline(r.position.y, r.size.y, ns)), player.notice, ns, UiText.WARN, 0)
