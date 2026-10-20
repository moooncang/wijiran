extends Control
## 장법 메뉴 (장법 기획 §7): Tab (or the rest point) toggles. Left: owned styles (undiscovered ones show as
## unknown "?" entries); right: role, strikes, traits, one strength and one caution, and the equip button.
## Equipping only works at a rest point while neutral; elsewhere a hint beside the button says so, and a
## refused press shakes it. Opening pauses the game (menu pause, not hitstop). Rows and buttons also take
## clicks/taps, so the touch build (no Tab/J keys; its on-screen buttons pause with the game) can use it.

const LIST_W := 236.0
const DESC_W := 480.0
const GAP := 20.0
const PANEL_MIN_H := 300.0
const PANEL_BOTTOM := 392.0   # panels end here and grow upward: main's menu-time notice starts at y 403
const HEADER_H := 26.0
const HEADER_H_TOUCH := 44.0  # touch: the 닫기 button is the only way out, so it gets a finger-sized 80×44
const CLOSE_W_TOUCH := 80.0
# Safe text area inside the r10 panel art: the tassel hangs in the top-left (to x 46, y 136) and gold frets
# fill the other corners (40 px), so content keeps this far from the panel edges (plus a little air).
const IN_L := 58.0
const IN_T := 16.0
const IN_R := 32.0
const IN_B := 18.0
const LIST_T := 34.0          # list rows start under the top-right fret (it ends ~28 px into the panel)
const LEADING := 3.0          # extra px between wrapped lines, as in the dialogue box
const BTN_ART := Vector2(80, 24)        # equip button art, drawn at _btn_scale()
const PLATE := Rect2(16, 3, 56, 13)     # its plate fill in art px; a knot hangs on the left, a fret on the right
const GLINT := Rect2(16.5, 2, 57, 1)    # the active art's dotted jade glint (x 17..72; half a px spare for scaled sampling)
# The plate's own colours, reused for the header 닫기 button so both buttons read as one set.
const PLATE_EDGE := Color("141218")
const PLATE_GOLD := Color("c9a45a")
const PLATE_FILL := Color("6c243a")
const PLATE_LIT := Color("9d3040")
# Opaque: the game is paused, and anything showing through (HUD bars, key panel, boss bar, dialogue) reads as
# garbled text behind the menu.
const BACKDROP := Color(0.02, 0.01, 0.03)
const NAME_COL := Color(1, 0.85, 0.7)
const DIVIDER := Color(0.78, 0.58, 0.42, 0.3)
const ROW_SEL := Color(0.55, 0.14, 0.2, 0.6)
const ROW_HOVER := Color(0.55, 0.14, 0.2, 0.25)
const WARN_TIME := 1.6

var selected := 0
var _open := false
var _warn_t := 0.0     # after a refused equip: the hint turns WARN and shakes
var _press := ""       # hit target under the pointer press; buttons act on release over the same target
var _hover := ""       # hit target under the mouse (PC only), lightly tinted
var _row_rects: Array[Rect2] = []
var _equip_rect := Rect2()
var _close_rect := Rect2()


func _ready() -> void:
	add_to_group("palm_menu")
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP   # while visible, clicks/taps stop here instead of reaching the HUD
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func open() -> void:
	if _blocked():
		return
	_open = true
	visible = true
	_warn_t = 0.0
	_press = ""
	_set_hover("")
	selected = maxi(0, PalmStyles.ids().find(Game.equipped_palm()))
	Game.set_paused(true)
	queue_redraw()


func close() -> void:
	_open = false
	visible = false
	_set_hover("")
	Game.set_paused(false)


## Never over the travel fade (its layer sits above the menu and would freeze half-black), the death card
## (pausing would stop the respawn timer) or the first-entry cutscene card. Same lookup as dialogue.gd.
func _blocked() -> bool:
	if is_instance_valid(Game.player) and Game.player.dead:
		return true
	var s := get_tree().current_scene
	if s == null:
		return false
	for k in ["cutscene", "death_screen"]:
		var c = s.get(k)
		if c is CanvasItem and c.visible:
			return true
	var fade = s.get("_fade_t")
	return fade is float and fade >= 0.0


func _process(delta: float) -> void:
	if _warn_t > 0.0:
		_warn_t -= delta
		queue_redraw()


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
	var n := PalmStyles.ids().size()
	if event.is_action_pressed("ui_down") or event.is_action_pressed("crouch"):
		_select((selected + 1) % n)
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("interact"):
		_select((selected - 1 + n) % n)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("attack_key"):
		_try_equip()
	elif event.is_action_pressed("ui_cancel"):
		close()
	else:
		return
	get_viewport().set_input_as_handled()
	queue_redraw()


## The tree is paused while the menu is up and GUI picking does not run then: clicks and taps are taken
## here (delivered to always-processing nodes) and routed to the same handler.
func _input(event: InputEvent) -> void:
	if _open and (event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch):
		_gui_input(event)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if not UiText.touch:   # a tap's emulated motion would leave a stale hover behind
			_set_hover(_hit(event.position))
		return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	accept_event()
	var hit := _hit(event.position)
	if event.pressed:
		_press = hit
		if hit.is_valid_int():
			_select(int(hit))
	else:
		var pressed := _press
		_press = ""
		if hit == pressed:   # on release, so closing never hands the game a fresh attack press
			if hit == "close":
				close()
				return
			if hit == "equip":
				_try_equip()
	queue_redraw()


func _set_hover(h: String) -> void:
	if h == _hover:
		return
	_hover = h
	mouse_default_cursor_shape = Control.CURSOR_ARROW if h == "" else Control.CURSOR_POINTING_HAND
	queue_redraw()


func _hit(p: Vector2) -> String:
	if _close_rect.grow(6.0).has_point(p):
		return "close"
	if _equip_rect.grow(6.0).has_point(p):
		return "equip"
	for i in _row_rects.size():
		if _row_rects[i].has_point(p):
			return str(i)
	return ""


func _select(i: int) -> void:
	if i != selected:
		selected = i
		_warn_t = 0.0   # a warning belongs to the row it was raised on


func _try_equip() -> void:
	var id: String = PalmStyles.ids()[selected]
	if id == Game.equipped_palm():
		return
	if not Game.unlocked_palms().has(id) or not Game.equip_palm(id):
		_warn_t = WARN_TIME


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), BACKDROP)
	var ids := PalmStyles.ids()
	var inner_w := DESC_W - IN_L - IN_R
	var content_h := 0.0   # tallest style, so the panels keep one size while browsing
	for id in ids:
		content_h = maxf(content_h, _desc(id, Vector2.ZERO, inner_w, false))
	var hh := HEADER_H_TOUCH if UiText.touch else HEADER_H
	var panel_h := clampf(IN_T + content_h + 14.0 + BTN_ART.y * _btn_scale() + IN_B, PANEL_MIN_H, PANEL_BOTTOM - hh - 16.0)
	var left := roundf((vp.x - LIST_W - GAP - DESC_W) * 0.5)
	var list := Rect2(left, PANEL_BOTTOM - panel_h, LIST_W, panel_h)
	var desc := Rect2(list.end.x + GAP, list.position.y, DESC_W, panel_h)
	_header(Rect2(left, list.position.y - 8.0 - hh, desc.end.x - left, hh))
	_panel("palm_list_panel", list)
	_panel("palm_description_panel", desc)
	_list(list)
	var sid: String = ids[selected]
	_equip_rect = Rect2()
	if Game.unlocked_palms().has(sid):
		_desc(sid, desc.position + Vector2(IN_L, IN_T), inner_w, true)
		_equip_row(sid, desc)
	else:
		_locked(desc)


## Panel art drawn to any height: the margins cover the tassel and corner frets, so only plain border and fill stretch.
func _panel(key: String, r: Rect2) -> void:
	var at := Anim.ui_tex(key) as AtlasTexture
	var sb := StyleBoxTexture.new()
	sb.texture = at.atlas
	sb.region_rect = at.region
	sb.texture_margin_left = 48.0
	sb.texture_margin_top = 140.0
	sb.texture_margin_right = 40.0
	sb.texture_margin_bottom = 40.0
	draw_style_box(sb, r)


func _header(r: Rect2) -> void:
	var title := UiText.sz(UiText.XL)
	var m := UiText.sz(UiText.M)
	var s := UiText.sz(UiText.S)
	UiText.draw(self, Vector2(r.position.x + 6.0, _baseline(r, title)), "장법", title, UiText.ACCENT, 0)
	var cw := maxf(UiText.width("닫기", m) + 28.0, CLOSE_W_TOUCH if UiText.touch else 0.0)
	_close_rect = Rect2(r.end.x - cw, r.position.y, cw, r.size.y)
	var fill := PLATE_FILL
	if _press == "close":
		fill = PLATE_LIT
	elif _hover == "close":
		fill = PLATE_FILL.lerp(PLATE_LIT, 0.5)
	draw_rect(_close_rect, PLATE_EDGE)
	draw_rect(_close_rect.grow(-1.0), PLATE_GOLD)
	draw_rect(_close_rect.grow(-2.0), fill)
	UiText.centered(self, _close_rect.get_center().x, _baseline(_close_rect, m), "닫기", m, UiText.INK, 0)
	var hint := "목록을 눌러 선택 · 장착 버튼으로 장착" if UiText.touch else "W/S 선택 · J 장착 · Tab 닫기"
	UiText.draw(self, Vector2(_close_rect.position.x - 12.0 - UiText.width(hint, s), _baseline(r, s)), hint, s, UiText.DIM, 0)


func _list(r: Rect2) -> void:
	var ids := PalmStyles.ids()
	var m := UiText.sz(UiText.M)
	var tag := UiText.sz(UiText.S)
	var f := UiText.font()
	var row_h := 36.0 if UiText.touch else 32.0
	var found := 0
	_row_rects.clear()
	for i in ids.size():
		var id: String = ids[i]
		var owned: bool = Game.unlocked_palms().has(id)
		found += int(owned)
		var s := PalmStyles.style(id)
		# x 54..208 clears the tassel knot (left) and the right border; rows start below the top-right fret
		var row := Rect2(r.position.x + 54.0, r.position.y + LIST_T + i * (row_h + 2.0), LIST_W - 82.0, row_h)
		_row_rects.append(row)
		if i == selected:
			draw_rect(row, ROW_SEL)
			draw_rect(Rect2(row.position, Vector2(2, row.size.y)), UiText.ACCENT)
		elif _hover == str(i):
			draw_rect(row, ROW_HOVER)
		var icon := row.position + Vector2(6, roundf((row_h - 24.0) * 0.5))
		if owned:
			draw_texture(Anim.ui_tex(String(s.icon)), icon)
		else:
			_unknown_mark(icon + Vector2(12, 12), 11.0, UiText.sz(16))
		var base := _baseline(row, m)
		UiText.draw(self, Vector2(row.position.x + 36.0, base), String(s.name) if owned else "미발견 장법", m, UiText.INK if owned else UiText.DIM, 0)
		if owned and id == Game.equipped_palm():
			# a small badge on the name's baseline, so it reads as a tag and not as part of the name
			var tw := UiText.width("장착 중", tag)
			var badge := Rect2(row.end.x - 6.0 - tw - 8.0, base - f.get_ascent(tag) - 2.0, tw + 8.0, f.get_height(tag) + 4.0)
			UiText.panel(self, badge, 0.9)
			UiText.draw(self, Vector2(badge.position.x + 4.0, base), "장착 중", tag, UiText.ACCENT, 0)
	# progress footer in the otherwise empty lower half, centred between the bottom frets
	UiText.centered(self, r.get_center().x, r.end.y - IN_B - 4.0, "발견 %d / %d" % [found, ids.size()], UiText.sz(UiText.S), UiText.DIM, 0)


## Neutral "unknown" mark: a bold '?' in a 2 px dim ring, so an undiscovered entry never reads as a real
## style's icon (nor as a thin placeholder glyph).
func _unknown_mark(c: Vector2, radius: float, size: int) -> void:
	var col := UiText.DIM
	draw_circle(c, radius, Color(col, 0.12))
	draw_arc(c, radius - 1.0, 0.0, TAU, 48, Color(col, 0.75), 2.0)
	var p := Vector2(roundf(c.x - UiText.width("?", size) * 0.5), _baseline(Rect2(c - Vector2(radius, radius), Vector2(radius, radius) * 2.0), size))
	draw_string_outline(UiText.font(), p, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, size, 2, col)   # same-colour outline = bold
	draw_string(UiText.font(), p, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## Undiscovered style: a large unknown mark and how to unlock it, centred in the description panel.
func _locked(desc: Rect2) -> void:
	var cx := roundf(desc.get_center().x)
	var cy := roundf(desc.get_center().y - 30.0)
	_unknown_mark(Vector2(cx, cy), 30.0, UiText.sz(32))
	UiText.centered(self, cx, cy + 56.0, "미발견 장법", UiText.sz(UiText.L), UiText.DIM, 0)
	UiText.centered(self, cx + _shake(), cy + 80.0, "비급을 찾으면 열립니다.", UiText.sz(UiText.M), UiText.WARN if _warn_t > 0.0 else UiText.DIM, 0)


## Description column at `pos`, `w` wide; returns its height. With draw_it false it only measures.
func _desc(sid: String, pos: Vector2, w: float, draw_it: bool) -> float:
	var m := UiText.sz(UiText.M)
	var big := UiText.sz(UiText.L)
	var y := pos.y
	var st := PalmStyles.style(sid)
	y += _text(Vector2(pos.x, y), w, String(st.name), big, UiText.ACCENT, draw_it) + 4.0
	y += _text(Vector2(pos.x, y), w, String(st.role), m, UiText.INK, draw_it)
	y = _divider(pos.x, y, w, draw_it)
	var h: Dictionary = st.heavy
	var rows := []
	for i in 3:
		rows.append(["%d타" % (i + 1), String(st.light[i].name), _kind_text(st.light[i])])
	# the label already says 강화, so "강화 만월" shows as 강화 | 만월
	# its burst rate moves to the second line beside the costs, so line 1 fits the column in every style (touch too)
	rows.append(["강화", String(h.name).trim_prefix("강화 "), "%s · 내공 -%d · 마열 +%d" % [_kind_text(h, true), int(h.qi_cost), int(h.rift_gain)]])
	var lab_w := UiText.width("강화", m) + 10.0
	var name_w := 0.0   # widest strike name of ANY style, so the description column stays put while browsing
	for id in PalmStyles.ids():
		var s := PalmStyles.style(id)
		for a in s.light + [s.heavy]:
			name_w = maxf(name_w, UiText.width(String(a.name).trim_prefix("강화 "), m))
	name_w += 12.0
	for row in rows:
		_text(Vector2(pos.x, y), lab_w, row[0], m, UiText.DIM, draw_it)
		_text(Vector2(pos.x + lab_w, y), name_w, row[1], m, NAME_COL, draw_it)
		y += _text(Vector2(pos.x + lab_w + name_w, y), w - lab_w - name_w, row[2], m, UiText.INK, draw_it) + LEADING
	y = _divider(pos.x, y - LEADING, w, draw_it)
	for row in [["특성", st.traits, Color(0.75, 0.85, 1.0)], ["장점", st.strength, Color(0.7, 0.95, 0.7)], ["주의", st.caution, UiText.WARN]]:
		_text(Vector2(pos.x, y), lab_w, row[0], m, row[2], draw_it)
		y += _text(Vector2(pos.x + lab_w, y), w - lab_w, String(row[1]), m, UiText.INK, draw_it) + LEADING
	return y - LEADING - pos.y


## Touch: integer 2× so the M label has air inside the plate (and a finger-sized target); PC keeps 1.5×.
func _btn_scale() -> float:
	return 2.0 if UiText.touch else 1.5


## Equip button in the panel's bottom-right (clear of the corner fret) with its label centred on the plate.
func _equip_row(sid: String, desc: Rect2) -> void:
	var equipped := sid == Game.equipped_palm()
	var can := Game.can_equip_now()
	var k := _btn_scale()
	var bsize := BTN_ART * k
	var bp := Vector2(desc.end.x - 44.0 - bsize.x, desc.end.y - IN_B - bsize.y)
	var tint := Color.WHITE
	if not equipped and not can:
		tint = Color(0.6, 0.6, 0.6)
	elif not equipped and _press == "equip":
		tint = Color(1.3, 1.3, 1.3)
	elif not equipped and _hover == "equip":
		tint = Color(1.15, 1.15, 1.15)
	# lit maroon plate (like 닫기) whenever it can be pressed or is in use; the dark plate only when it can't
	draw_texture_rect(Anim.ui_tex("equip_button" if not equipped and not can else "equip_button_active"), Rect2(bp, bsize), false, tint)
	if equipped:
		draw_rect(Rect2(bp + GLINT.position * k, GLINT.size * k), PLATE_GOLD)   # solid gold, like the plate's bottom edge
	var m := UiText.sz(UiText.M)
	var plate := Rect2(bp + PLATE.position * k, PLATE.size * k)
	var col := UiText.ACCENT if equipped else (UiText.INK if can else UiText.DIM)
	UiText.centered(self, plate.get_center().x, _baseline(plate, m), "장착 중" if equipped else "장착", m, col, 0)
	if equipped:
		return
	_equip_rect = Rect2(bp, bsize)
	if not can:
		# left of the button's knot; at a rest point the refusal is about the player's state, not the place
		var msg := "지금은 장착할 수 없습니다." if Game.at_rest_point else "휴식 지점에서만 장착할 수 있습니다."
		var hx := desc.position.x + IN_L
		var hw := bp.x - 8.0 - hx
		if UiText.width(msg, m) > hw:
			msg = msg.replace(" 장착", "\n장착")   # two balanced lines beside the larger touch button
		var hy := roundf(plate.get_center().y - _text(Vector2.ZERO, hw, msg, m, col, false) * 0.5)
		_text(Vector2(hx + _shake(), hy), hw, msg, m, UiText.WARN if _warn_t > 0.0 else UiText.DIM, true)


## Short horizontal jolt at the start of a refusal warning.
func _shake() -> float:
	var t := WARN_TIME - _warn_t
	return roundf(sin(t * 55.0) * 2.5) if _warn_t > 0.0 and t < 0.35 else 0.0


## Wrapped block with its top-left at `p`, lines LEADING apart; returns its height.
func _text(p: Vector2, w: float, text: String, size: int, col: Color, draw_it: bool) -> float:
	var lines := _wrap_words(text, size, w).split("\n")
	var f := UiText.font()
	var lh := f.get_height(size) + LEADING
	if draw_it:
		for i in lines.size():
			UiText.draw(self, Vector2(p.x, roundf(p.y + f.get_ascent(size) + i * lh)), lines[i], size, col, 0)
	return lines.size() * lh - LEADING


## Breaks only at spaces so Korean words stay whole (the font wraps mid-word); a lone "·" stays on its line.
func _wrap_words(text: String, size: int, w: float) -> String:
	var out := PackedStringArray()
	for para in text.split("\n"):
		var line := ""
		for word in para.split(" "):
			var next := word if line == "" else line + " " + word
			if line != "" and word != "·" and UiText.width(next, size) > w:
				out.append(line)
				line = word
			else:
				line = next
		out.append(line)
	return "\n".join(out)


func _divider(x: float, y: float, w: float, draw_it: bool) -> float:
	if draw_it:
		draw_rect(Rect2(x, y + 6.0, w, 1.0), DIVIDER)
	return y + 13.0


## Baseline that centres one line of `size` vertically in `r`.
func _baseline(r: Rect2, size: int) -> float:
	var f := UiText.font()
	return roundf(r.position.y + (r.size.y - f.get_height(size)) * 0.5 + f.get_ascent(size))


## One line per strike: its own display text ("desc"), plus what it does to 내상. `own_line` puts the
## burst rate on a new line instead of in brackets.
func _kind_text(a: Dictionary, own_line := false) -> String:
	var base := String(a.get("desc", a.kind))
	if a.get("injury_burst", false):
		if not base.contains("내상 폭발"):
			base += " · 내상 폭발"
		var rate := "내상 1당 피해 %d" % int(a.burst_per_stack)
		base += "\n" + rate if own_line else " (%s)" % rate
	elif int(a.get("injury", 0)) > 0:
		base += " · 내상 +%d" % int(a.injury)
	return base   # "단일 대상" lives in the style traits instead of on every strike
