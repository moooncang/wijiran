extends CanvasLayer
## Autoload "Dialogue": a queue of short speaker lines shown at the top of the screen, never blocking
## play (본편: 대화는 짧게, 전투를 끊지 않는다). Dialogue.say(who, text) enqueues; lines auto-advance.
## who == "" is narration (no name row, dimmer text); a name ending in 기록 is a record (dim title, no
## face). Every say() in one frame is one event, and an event's lines are one run with its own "1/2"
## count and one layout, so lines swap without the frame or the text start jumping. The box is centred
## on the screen axis within x 214–586 (the boss bar's span) from y 46: clear of the player status to
## the right and the notice toast below.

const PORTRAITS := {"위지란": "portrait_wi_jiran_neutral", "티아넬": "portrait_tianel_cold", "제자": "portrait_disciple", "레나타": "portrait_renata", "구출된 제자": "portrait_disciple_relieved", "미레유": "portrait_mireille_proud", "엘로디": "portrait_elodie_serene"}
const BossHud := preload("res://src/ui/boss_hud.gd")   # CRESTS: the bar's bust for bosses without art
const AXIS_X := 400.0   # screen centre: the boss bar, notice toast and map title share it
const MAX_W := 372.0    # 2 × (boss bar end 586 − axis): always centred, never past the bar's ends
const BOX_Y := 46.0
const MIN_W := 280.0
const PAD_Y := 6.0      # top/bottom inset: clear of the frame's top line and bottom knots
const PAD_L := 16.0     # text inset when there is no face: clear of the left knot ornament
const PAD_R := 10.0
const FACE := 48.0
const FACE_X := 12.0
const GAP := 3          # extra px between wrapped lines (NanumGothic's line height is only size+1)
const FADE := 0.25      # s: fade-out after a run's last line, and of a line cut short by a new event
const TOUCH_UP := 2     # touch: name/body one step past sz() (a phone shows the canvas small); 2 rows end by y 120
const CLAUSE_END := ".?!…,"   # a wrapped row may end after these without splitting a phrase

var queue: Array = []
var current: Dictionary = {}
var left := 0.0
var _shown := 0         # lines shown in the current run, for the "1/3" cue
var _age := 0.0
var _burst := -1        # process frame of the latest say(): a later frame is a new event
var _event := 0         # id of the latest event; each queued line carries its event's id
var _run_event := -1    # event of the run on screen
var _run_x := 0.0       # text start, box width, inner height and body size: fixed for the run
var _run_w := 0.0
var _run_h := 0.0
var _run_body := 0
var _box: Control
var _frame: NinePatchRect
var _portrait: TextureRect
var _plate: Control     # the face's framed plate, like the boss bar's bust; a boss without art gets its crest in it at 1.5×
var _crest_who := ""
var _name: Label
var _count: Label
var _label: Label


func _ready() -> void:
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS
	_box = Control.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.visible = false
	add_child(_box)
	_frame = NinePatchRect.new()
	_frame.texture = Anim.ui_tex("dialogue_frame")
	# The knot ornaments reach 11 px into the 32 px art (the manifest's 8 px slice cut them and smeared
	# them along the edges): wider margins keep them whole, and tiling repeats the gold edge pattern.
	_frame.patch_margin_left = 12
	_frame.patch_margin_top = 11
	_frame.patch_margin_right = 6
	_frame.patch_margin_bottom = 11
	_frame.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	_frame.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_frame)
	_plate = Control.new()   # added before the portrait so the art sits on it
	_plate.position = Vector2(FACE_X, PAD_Y)
	_plate.size = Vector2(FACE, FACE)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.draw.connect(_draw_plate)
	_box.add_child(_plate)
	_portrait = TextureRect.new()
	_portrait.position = _plate.position
	_portrait.size = _plate.size
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_portrait)
	_name = _add_label()
	_count = _add_label()
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label = _add_label()
	_label.add_theme_constant_override("line_spacing", GAP)


func _add_label() -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(l)
	return l


## interrupt (boss phase/defeat, room entry): earlier events' unshown lines are dropped and the line on
## screen fades out, so the new event is not stuck behind a stale taunt. interrupt = false (a freed
## prisoner, an NPC, a record) queues behind the running exchange instead of cutting it.
func say(who: String, text: String, seconds: float = 0.0, portrait := "", interrupt := true) -> void:
	text = text.replace("…", "...")   # the font's … is three faint mid-height dots; baseline dots read
	var frame := Engine.get_process_frames()
	if frame != _burst:
		_burst = frame
		_event += 1
	if interrupt:
		queue = queue.filter(func(l): return l.event == _event)
		if not current.is_empty() and current.event != _event and not _same(current, who, text):
			left = minf(left, FADE)
	# The same line from a second trigger (two prisoners freed back to back) is not repeated.
	if _same(current, who, text) or queue.any(func(l): return _same(l, who, text)):
		return
	# On screen long enough to read (~0.09 s per Korean character, never under 2.2 s).
	var read := clampf(0.6 + text.length() * 0.09, 2.2, 8.0)
	queue.append({"who": who, "text": text, "portrait": portrait if portrait != "" else String(PORTRAITS.get(who, "")), "seconds": maxf(seconds, read), "event": _event})


static func _same(line: Dictionary, who: String, text: String) -> bool:
	return line.get("who") == who and line.get("text") == text


func clear() -> void:
	queue.clear()
	current = {}
	left = 0.0
	_shown = 0
	_run_event = -1
	_box.visible = false


func _process(delta: float) -> void:
	# Hold (hidden, clock stopped) under the palm menu, the entry cutscene and the death card: no line is
	# missed or bleeds through (respawn reloads the level, which clears the queue).
	var held := Game.paused or _cutscene_up() or (is_instance_valid(Game.player) and Game.player.dead)
	_box.visible = not held and not current.is_empty()
	if held:
		return
	if not current.is_empty():
		left -= delta
		_age += delta
		if left <= 0.0:
			current = {}
			_box.visible = false
	if current.is_empty():
		if queue.is_empty():
			return
		_show(queue.pop_front())
	var more := _more()
	var total := _shown + more
	_count.text = "%d/%d" % [_shown, total] if total > 1 else ""
	# Ease in the first line of a run and out after the last; lines in between swap without blinking.
	var a := 1.0
	if _shown == 1:
		a = minf(a, _age / 0.15)
	if more == 0:
		a = minf(a, left / FADE)
	_box.modulate.a = clampf(a, 0.0, 1.0)


## Queued lines still to come in the current run (the queue is in event order).
func _more() -> int:
	var n := 0
	for l in queue:
		if l.event != current.event:
			break
		n += 1
	return n


func _cutscene_up() -> bool:
	var s := get_tree().current_scene
	var c = s.get("cutscene") if s else null
	return c is CanvasItem and c.visible


func _face(line: Dictionary) -> String:
	var pk := String(line.portrait)
	return pk if pk != "" and Anim.ui.has(pk) else ""


func _has_face(line: Dictionary) -> bool:
	return _face(line) != "" or BossHud.CRESTS.has(String(line.who))


static func _record(who: String) -> bool:
	return who.ends_with("기록")


## The boss bar's bust plate (dark fill, 1 px edge) at face size: the busts' flat-cut edges become its
## edges instead of hanging in the box, and art portraits and drawn crests sit in the same frame.
func _draw_plate() -> void:
	UiText.panel(_plate, Rect2(Vector2.ZERO, _plate.size).grow(1), 0.85)
	_plate.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * (FACE / 32.0))
	for s in BossHud.CRESTS.get(_crest_who, []):
		if s.size() == 5:
			_plate.draw_rect(Rect2(s[0], s[1], s[2], s[3]), s[4])
		else:
			_plate.draw_circle(Vector2(s[0], s[1]), s[2], s[3])


func _show(line: Dictionary) -> void:
	if line.event != _run_event:   # a new event starts a fresh run: its own count and layout
		_run_event = line.event
		_shown = 0
	current = line
	left = float(line.seconds)
	_age = 0.0
	_shown += 1
	var f := UiText.font()
	var up := TOUCH_UP if UiText.touch else 0
	var who := String(line.who)
	# One layout for the whole run: the face column if any line has a face, and the box fits the
	# widest/tallest line, so nothing moves between lines.
	var run := [line] + queue.slice(0, _more())
	if _shown == 1:
		_run_x = PAD_L
		_run_w = MIN_W
		_run_h = 0.0
		for l in run:
			if _has_face(l):
				_run_x = FACE_X + FACE + 8.0
		# The touch bump gives way (down to sz(M)) for a run with a line that would need a third row, or
		# that one size smaller breaks at a clause end instead of mid-phrase.
		_run_body = UiText.sz(UiText.M) + up
		while _run_body > UiText.sz(UiText.M) and run.any(func(l): return _cramped(String(l.text), _run_body, MAX_W - _run_x - PAD_R)):
			_run_body -= 1
	var name_size := UiText.sz(UiText.M if _record(who) else UiText.L) + up
	var body_size := _run_body
	var count_size := UiText.sz(UiText.XS)
	var name_h := f.get_height(name_size)
	var line_h := f.get_height(body_size)
	# Solid frame behind: no outline needed. A record's title is a small dim header over its text.
	UiText.style_label(_name, name_size, UiText.DIM if _record(who) else UiText.ACCENT, 0)
	UiText.style_label(_count, count_size, UiText.DIM, 0)
	UiText.style_label(_label, body_size, UiText.INK if who != "" else UiText.DIM, 0)
	var total := _shown + run.size() - 1
	var count_w := UiText.width("%d/%d" % [total, total], count_size) + 12.0 if total > 1 else 0.0
	var wrapped := PackedStringArray()
	var block := 0.0
	for i in run.size():
		var l: Dictionary = run[i]
		var rows := _wrap(String(l.text), body_size, MAX_W - _run_x - PAD_R)
		var named := String(l.who) != ""
		var body_w := 0.0
		for r in rows:
			body_w = maxf(body_w, UiText.width(r, body_size))
		var head := UiText.width(String(l.who), name_size) + count_w if named else 0.0
		var b := (name_h + 3.0 if named else 0.0) + rows.size() * line_h + (rows.size() - 1) * GAP
		_run_w = clampf(maxf(_run_w, ceilf(_run_x + maxf(body_w, head) + 2.0 + PAD_R)), MIN_W, MAX_W)
		_run_h = maxf(_run_h, b)
		if i == 0:
			wrapped = rows
			block = b
	var face := _run_x > PAD_L
	var pk := _face(line)
	_portrait.visible = pk != ""
	if _portrait.visible:
		_portrait.texture = Anim.ui_tex(pk)
	_crest_who = who if pk == "" and BossHud.CRESTS.has(who) else ""
	_plate.visible = pk != "" or _crest_who != ""
	_plate.queue_redraw()
	_name.visible = who != ""
	_count.visible = who != ""
	_name.text = who
	_label.text = "\n".join(wrapped)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if who != "" else HORIZONTAL_ALIGNMENT_CENTER
	# Height: the run's tallest block (at least the face), this line and the face centred in it.
	var w := _run_w
	var h := ceilf(maxf(_run_h, FACE if face else 0.0) + PAD_Y * 2.0)
	var top := PAD_Y + floorf((h - PAD_Y * 2.0 - block) * 0.5)
	if not face:
		# Hangul ink fills the ascent but not the last row's descent: 1 px lower and 1 px shorter so the
		# gaps to the top and bottom frame lines match.
		top += 1.0
		h -= 1.0
	_box.position = Vector2(roundf(AXIS_X - w * 0.5), BOX_Y)
	_box.size = Vector2(w, h)
	_frame.size = _box.size
	_portrait.position.y = floorf((h - FACE) * 0.5)
	_plate.position.y = _portrait.position.y
	var text_w := w - _run_x - PAD_R
	_name.position = Vector2(_run_x, top)
	_name.size = Vector2(text_w, name_h)
	# Small counter on the name's baseline, right-aligned.
	_count.position = Vector2(_run_x, top + f.get_ascent(name_size) - f.get_ascent(count_size))
	_count.size = Vector2(text_w, f.get_height(count_size))
	var body_y := top + (name_h + 3.0 if who != "" else 0.0)
	_label.position = Vector2(_run_x, body_y)
	_label.size = Vector2(text_w, h - PAD_Y - body_y)
	_box.visible = true


## Word wrap at spaces: Korean breaks per 어절 (the shaper would split words between syllables), and a
## wrapped line is balanced so the last row isn't a single dangling word.
## shortcut: one word wider than max_w overflows its line, fine for these short spoken lines.
static func _wrap(text: String, size: int, max_w: float) -> PackedStringArray:
	var lines := _greedy(text, size, max_w)
	if lines.size() == 2:
		return _split2(text, size, max_w, lines)
	var w := ceilf(UiText.width(text, size) / lines.size())
	while w < max_w:
		var tight := _greedy(text, size, w)
		if tight.size() == lines.size():
			return tight
		w += 6.0
	return lines


## Needs a third row at `size`, or one size down it breaks cleanly where it now cuts a phrase.
static func _cramped(text: String, size: int, max_w: float) -> bool:
	var rows := _wrap(text, size, max_w)
	return rows.size() > 2 or (not _clean(rows) and _clean(_wrap(text, size - 1, max_w)))


## One row, or two split at a clause end.
static func _clean(rows: PackedStringArray) -> bool:
	return rows.size() == 1 or (rows.size() == 2 and rows[0].right(1) in CLAUSE_END)


## Two rows: the most even break, unless a break after a sentence or clause end (. ? ! … ,) is within
## 50% of it, so a phrase is not cut in two ("잿더미를 밟는 / 발소리는"). The game's clause breaks
## that fit measure up to ~1.47× the even split; at 1.3 several fell back to a mid-phrase break.
static func _split2(text: String, size: int, max_w: float, fallback: PackedStringArray) -> PackedStringArray:
	var words := text.split(" ", false)
	var best := fallback
	var best_w := INF
	var punct := fallback
	var punct_w := INF
	for i in range(1, words.size()):
		var a := " ".join(words.slice(0, i))
		var b := " ".join(words.slice(i))
		var w := maxf(UiText.width(a, size), UiText.width(b, size))
		if w > max_w:
			continue
		if w < best_w:
			best_w = w
			best = PackedStringArray([a, b])
		if w < punct_w and a.right(1) in CLAUSE_END:
			punct_w = w
			punct = PackedStringArray([a, b])
	return punct if punct_w <= best_w * 1.5 else best


static func _greedy(text: String, size: int, max_w: float) -> PackedStringArray:
	var out := PackedStringArray()
	var cur := ""
	for word in text.split(" ", false):
		var t: String = word if cur == "" else cur + " " + word
		if cur != "" and UiText.width(t, size) > max_w:
			out.append(cur)
			cur = word
		else:
			cur = t
	out.append(cur)
	return out
