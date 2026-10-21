extends Node2D
## Root scene: owns the current Level, the player, the camera and the UI layers; routes travel, death
## and interaction. Levels are data classes (levels/*.gd). `-- --level=f1 --spawn=start` starts elsewhere,
## `-- --test=all` (or one suite name) runs tests/selftests.gd, `-- --touch`
## forces the on-screen controls, `-- --wipe` clears the save.

static var LEVELS := {"t0": LevelT0, "f1": LevelF1, "b1": LevelB1, "h0": LevelH0, "f2": LevelF2, "b2": LevelB2, "f3": LevelF3, "b3": LevelB3}

var player: Player
var level: Level
var cam: Camera2D
var hud: Control
var boss_hud: Control
var palm_menu: Control
var pause_menu: Control
var touch_controls: Control
var notice_box: Control        # Game.notice toast: one at a time, centred panel from NOTICE_Y
var notice_rect := Rect2()     # the toast's panel as last drawn (screen px; meaningful while _notice_text != "")
var _notice_text := ""         # the toast on screen ("" = none)
var _notice_lines := PackedStringArray()   # _notice_text wrapped at spaces
var _notice_top := NOTICE_Y    # picked when it shows: under the player when she stands where it would go
var _band_dim := 1.0           # title band alpha factor: BEHIND while the player is behind it
var _notice_low := false       # stays false: a wrapped toast now waits for the map title (enemy_base.gd reads it)
var _notices := PackedStringArray()        # queued texts; held while the cutscene card or death card is up
var _notice_tween: Tween
var title_label: Label
var _fade: ColorRect
var _fade_t := -1.0
var _pending: Array = []       # [level_id, spawn_id]
var _death_t := -1.0
var death_screen: Control      # dim + "쓰러졌다" during the death delay
var title_band: NinePatchRect
var cutscene: Control          # first-entry card: near-opaque wash with the framed image centred on it
var _cut_card: NinePatchRect    # framed card; the image is its child
var _cut_image: TextureRect
var _cut_t := -1.0
var _cut_queue: Array = []      # cards still to show after the current one
var _cut_caption := ""          # the route card names its stops (manifest "locations")

const TITLE_TIME := 2.5
const CUT_TIME := 3.2
const CUT_RECT := Rect2(144, 75, 512, 288)   # centred; the stop nameplate straddles its bottom (~y 352–377)
const CUT_DIM := 0.97          # the wash hides the HUD, key panel and touch buttons behind the card
const STOP_NAMES := {"단층 연구소": "단층 임시 연구소"}   # route-card stop → that map's own title
const NOTICE_W := 372.0        # the centre column (x 214–586, as the dialogue box and boss bar): longer ones wrap
const NOTICE_Y := 123.0        # under the dialogue box (ends ≤ 120); one line ends ≤ 146, ≥ 6 px above the band
const NOTICE_PAD := 5.0        # toast: panel edge to the Hangul ink, above the first line and below the last
const INK_UP := 0.83           # Hangul ink: ~0.83 em above the baseline, ~0.06 em below
const INK_DOWN := 0.06
const BEHIND := 0.3            # title band / toast alpha while the player (or her prompt) is behind them
const NOTICE_MENU_Y := 403.0   # palm menu open: the free strip under its panels (they end ~397)
const TITLE_Y := 152.0         # map title band top: copper rules at ~158 and ~183, knot tips to ~191
const TITLE_SCALE := 1.35      # band art ×1.35: 24 px between its rules fits the 20/22 px title with ≥ 2 px clear
const TITLE_CAP := 52          # band art: knot ornament width at each end (source px), kept whole when scaled
const DEATH_TIME := 1.6
const DialogueText := preload("res://src/ui/dialogue.gd")   # its space-only balanced wrap (_wrap)


func _ready() -> void:
	_setup_input()
	Juice.world = self
	var args := OS.get_cmdline_user_args()
	if OS.has_feature("web"):   # ?level=f1&spawn=start&wipe&touch → the same switches as the command line (QA)
		var q = JavaScriptBridge.eval("location.search", true)
		if q is String:
			for part in String(q).trim_prefix("?").split("&"):
				if part != "":
					args.append("--" + part)
	if "--wipe" in args:
		Game.wipe_save()
	player = Player.new()
	add_child(player)
	Game.player = player
	cam = Camera2D.new()
	cam.set_script(preload("res://src/world/game_camera.gd"))
	add_child(cam)
	cam.setup(player)
	cam.make_current()
	_build_ui()
	Game.travel_requested.connect(_on_travel)
	Game.notice.connect(_on_notice)
	var start_level := String(Game.save.checkpoint.level)
	var start_spawn := String(Game.save.checkpoint.spawn)
	for a in args:
		if a.begins_with("--level="):
			start_level = a.substr(8)
			start_spawn = "start"
		elif a.begins_with("--spawn="):
			start_spawn = a.substr(8)
	_load_level(start_level, start_spawn)
	if "--debug" in args:
		var dl := CanvasLayer.new()
		dl.layer = 12
		_dbg_label = Label.new()
		_dbg_label.position = Vector2(4, 4)
		_dbg_label.size = Vector2(792, 60)
		_dbg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_dbg_label.add_theme_font_size_override("font_size", 9)
		_dbg_label.add_theme_color_override("font_color", Color(1, 1, 0.6))
		_dbg_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_dbg_label.add_theme_constant_override("outline_size", 3)
		dl.add_child(_dbg_label)
		add_child(dl)
	for a in args:
		if a.begins_with("--test="):
			var t := Node.new()
			t.set_script(preload("res://tests/selftests.gd"))
			t.suite = a.substr(7)
			add_child(t)


# ---------- levels ----------

## `show_title` false (a respawn into the same map) skips the map title band.
func _load_level(level_id: String, spawn_id: String, show_title := true) -> void:
	if level_id != Game.level_id:
		_drop_notice(true)   # toasts from the map we left (a rescue right before the door) are stale here
	Game.wiping = false
	# a toast already seen belongs to the old map ("여기서 다시 시작합니다" would name the wrong place);
	# queued ones not shown yet still play here
	_drop_notice(false)
	if level:
		level.queue_free()
		level = null
	Juice.clear()
	Dialogue.clear()
	for n in get_tree().get_nodes_in_group("projectile"):
		n.queue_free()
	for n in get_children():
		if n.get_script() and n.get_script().resource_path.ends_with("fx.gd") or n.get_script() and n.get_script().resource_path.ends_with("ghost.gd"):
			n.queue_free()
	Game.at_rest_point = false
	var cls = LEVELS.get(level_id, LevelT0)
	level = Level.new()
	level.boss_spawned.connect(_on_boss_spawned)
	add_child(level)
	move_child(level, 0)
	level.build(cls.data(), player, cam)
	Game.level = level
	Game.level_id = level_id
	var at: Vector2 = level.spawn_point(spawn_id)
	player.reset_state(at.x)
	player.global_position = at
	player.combat_enabled = not bool(level.data.get("no_combat", false))
	Game.restore_snapshot(player)
	cam.global_position = at + Vector2(0, -70)
	cam.reset_smoothing()
	boss_hud.visible = false
	boss_hud.boss = null
	title_label.text = String(level.data.get("name", ""))
	_title_left = TITLE_TIME if show_title and title_label.text != "" else 0.0
	_death_t = -1.0
	death_screen.visible = false
	_cut_t = -1.0                  # a card from the previous level never carries over
	cutscene.visible = false
	hud.modulate.a = 1.0
	_cut_queue.clear()
	var cut := String(level.data.get("cutscene", ""))
	if cut != "" and Anim.cutscenes.has(cut) and not Game.save.skip_intro_seen.has(cut):
		_cut_queue.append(cut)
	for pair in level.data.get("cutscene_after", []):   # [flag, key]: result cards once their flag is set
		var key := String(pair[1])
		if Game.flag(String(pair[0])) and Anim.cutscenes.has(key) and not Game.save.skip_intro_seen.has(key):
			_cut_queue.append(key)
	if not _cut_queue.is_empty():
		for key in _cut_queue:
			Game.save.skip_intro_seen.append(key)
		Game.write_save()
		_start_card(String(_cut_queue.pop_front()))


var _title_left := 0.0


func _start_card(cut: String) -> void:
	_cut_image.texture = Anim.tex(String(Anim.cutscenes[cut].file))
	var stops := PackedStringArray()
	for s in Anim.cutscenes[cut].get("locations", []):
		stops.append(STOP_NAMES.get(s, s))
	_cut_caption = " → ".join(stops)
	_cut_image.queue_redraw()
	cutscene.modulate.a = 1.0      # the wash is up from the first frame (no flash of the map); the art fades in
	_cut_card.modulate.a = 0.0
	hud.modulate.a = 0.0
	cutscene.visible = true
	_cut_t = 0.0               # queued toasts wait for the card (_pump_notice) instead of sitting on its art


func _on_travel(level_id: String, spawn_id: String) -> void:
	_pending = [level_id, spawn_id]   # a request during a running fade replaces its destination instead of being dropped
	if _fade_t >= 0.3:
		_fade_t = 0.0   # the old level is already up: fade again
	elif _fade_t < 0.0:
		_fade_t = 0.0


func _on_boss_spawned(boss: Node) -> void:
	boss_hud.boss = boss
	boss_hud.visible = true


# ---------- frame ----------

var _dbg_t := 0.0


func _web_build() -> String:
	if OS.has_feature("web"):
		var v = JavaScriptBridge.eval("window.WIJIRAN_BUILD || \"\"", true)
		if v is String:
			return String(v)
	return "dev"


## Web QA: window.WIJIRAN_STATE mirrors the level, the player and the nearest usable thing twice a second.
func _web_state(delta: float) -> void:
	if not OS.has_feature("web"):
		return
	_dbg_t += delta
	if _dbg_t < 0.5:
		return
	_dbg_t = 0.0
	var usable := ""
	for it in get_tree().get_nodes_in_group("interactable"):
		if it.near:
			usable = "%s near avail=%s" % [it.label, it.available()]
	var st := {"level": Game.level_id, "x": roundf(player.global_position.x), "y": roundf(player.global_position.y), "paused": Game.paused, "fade": _fade_t, "usable": usable, "dead": player.dead}
	JavaScriptBridge.eval("window.WIJIRAN_STATE=%s" % JSON.stringify(st), true)


var _dbg_label: Label
var _dbg_presses := 0
var _dbg_used := ""


## Interact is polled in the physics tick, where the player already reads jump: the same W press reaches
## both the same way (polling it from _process missed presses on some browsers).
func _physics_process(_dt: float) -> void:
	if Input.is_action_just_pressed("interact") and not Game.paused:
		_dbg_presses += 1
		for it in get_tree().get_nodes_in_group("interactable"):
			if it.try_use():
				_dbg_used = "%s @%d" % [it.label, _dbg_presses]
				break


func _process(delta: float) -> void:
	if _dbg_label:
		var usable := ""
		for it in get_tree().get_nodes_in_group("interactable"):
			if it.near:
				usable += "[%s near=%s avail=%s focused=%s] " % [it.label, it.near, it.available(), it.focused()]
		_dbg_label.text = "build %s | level %s x=%d | paused=%s fade=%.2f cut=%.1f death=%.1f | interact presses=%d used=%s | %s | flags=%s" % [_web_build(), Game.level_id, int(player.global_position.x), Game.paused, _fade_t, _cut_t, _death_t, _dbg_presses, _dbg_used, usable, Game.save.flags.keys()]
	if Input.is_action_just_pressed("reset") and not Game.paused:
		Game.respawn()
	_step_fade(delta)
	_web_state(delta)
	if _cut_t >= 0.0:
		_cut_t += delta
		# the art fades in over the wash; at the end wash and art fade out together and the HUD comes back
		_cut_card.modulate.a = clampf(_cut_t * 2.0, 0.0, 1.0)
		cutscene.modulate.a = clampf((CUT_TIME - _cut_t) * 2.0, 0.0, 1.0)
		hud.modulate.a = 1.0 - cutscene.modulate.a
		if _cut_t >= CUT_TIME:
			_cut_t = -1.0
			cutscene.visible = false
			hud.modulate.a = 1.0
			if not _cut_queue.is_empty():
				_start_card(String(_cut_queue.pop_front()))
	else:
		_title_left = maxf(0.0, _title_left - delta)   # the map title waits for the cutscene card
	# short fade-out (0.4 s) so the band is either solid or gone, never a ghost over the world; it and the
	# toast thin out while the player stands behind them (the F1 manual sits on a roof right under them)
	var me := _player_screen_rect()
	_band_dim = move_toward(_band_dim, BEHIND if me.intersects(title_band.get_global_rect()) else 1.0, delta * 4.0)
	title_label.modulate.a = clampf(minf(_title_left * 2.5, (TITLE_TIME - _title_left) * 4.0), 0.0, 1.0) * _band_dim
	title_band.modulate.a = title_label.modulate.a
	var behind_toast := _notice_text != "" and not palm_menu.visible and me.intersects(notice_rect)
	notice_box.self_modulate.a = move_toward(notice_box.self_modulate.a, BEHIND if behind_toast else 1.0, delta * 4.0)
	if player.dead and _death_t < 0.0:
		_death_t = 0.0
		death_screen.visible = true
		_drop_notice(true)         # the death card is the only bright thing on screen
		_title_left = 0.0          # no ghosted map title above 쓰러졌다 (the band's layer is under the wash)
	if _death_t >= 0.0:
		_death_t += delta
		death_screen.modulate.a = clampf(_death_t / 0.5, 0.0, 1.0)
		if _death_t >= DEATH_TIME and _fade_t < 0.0:
			_death_t = -1.0
			Game.respawn()
	_pump_notice()


## An attack, jump or interact press (a tap on touch, whose buttons sleep under the card) ends the
## first-entry card early: it starts its fade-out at once.
func _input(event: InputEvent) -> void:
	if _cut_t < 0.5 or _cut_t >= CUT_TIME - 0.5:
		return
	if (event is InputEventScreenTouch and event.pressed) or event.is_action_pressed("attack") or event.is_action_pressed("attack_key") or event.is_action_pressed("jump") or event.is_action_pressed("interact"):
		_cut_t = CUT_TIME - 0.5


func _step_fade(delta: float) -> void:
	if _fade_t < 0.0:
		return
	_fade_t += delta
	if _fade_t < 0.25:
		_fade.color.a = _fade_t / 0.25
	elif _fade_t < 0.30:
		if _fade.color.a < 1.0:
			_fade.color.a = 1.0
			_load_level(_pending[0], _pending[1], _pending[0] != Game.level_id)   # respawns skip the title
	elif _fade_t < 0.60:
		_fade.color.a = 1.0 - (_fade_t - 0.30) / 0.30
	else:
		_fade.color.a = 0.0
		_fade_t = -1.0


## Notices queue instead of replacing each other (a boss's key-item line and the room's "구역 정리" fire
## in the same frame); a repeat of the text on screen or already queued is dropped.
func _on_notice(text: String) -> void:
	if text == _notice_text or _notices.has(text):
		return
	_notices.append(text)
	_pump_notice()


## Shows the next queued notice when the toast is free, no full-screen card is up and no travel fade is
## closing (it would play under the black and be dropped with the old map). A wrapped one waits out the
## map title (≤ 2.5 s): its second line would cover the band. A one-liner queued behind it fits above the
## band and goes first. The hold scales with length (~14 chars/s) so record lines can be read to the end.
func _pump_notice() -> void:
	if _notice_text != "" or _cut_t >= 0.0 or _death_t >= 0.0 or (_fade_t >= 0.0 and _fade_t < 0.3):
		return
	for i in _notices.size():
		var lines := DialogueText._wrap(_notices[i], UiText.sz(UiText.M), NOTICE_W - 24.0)
		if lines.size() > 1 and _title_left > 0.0:
			continue
		_notice_text = _notices[i]
		_notices.remove_at(i)
		_notice_lines = lines
		# raised where she stands (the F1 shrine roof puts her head at y ~142): under her feet, and under
		# the title band while it shows, instead of on her
		var me := _player_screen_rect()
		_notice_top = NOTICE_Y
		if _notice_rect_at(NOTICE_Y).intersects(me):
			_notice_top = me.end.y + 8.0
			if _title_left > 0.0:
				_notice_top = maxf(_notice_top, title_band.get_global_rect().end.y + 6.0)
		notice_box.modulate.a = 0.0
		notice_box.self_modulate.a = 1.0
		notice_box.queue_redraw()
		# runs while paused too: the palm menu raises notices ("「X」 장착") and the toast sits above it
		_notice_tween = notice_box.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_notice_tween.tween_property(notice_box, "modulate:a", 1.0, 0.06)   # a soft 4-frame fade-in, not a pop
		_notice_tween.tween_interval(clampf(1.2 + 0.07 * _notice_text.length(), 2.3, 5.0))
		_notice_tween.tween_property(notice_box, "modulate:a", 0.0, 0.3)
		_notice_tween.tween_callback(_notice_done)
		return


func _notice_done() -> void:
	_notice_text = ""
	_pump_notice()


## Takes the toast off screen for good (it is never replayed); `clear_queue` also drops the pending ones
## (death: they are stale after the respawn).
func _drop_notice(clear_queue: bool) -> void:
	if _notice_tween:
		_notice_tween.kill()
	if clear_queue:
		_notices.clear()
	_notice_text = ""
	notice_box.modulate.a = 0.0


## The toast panel with its top at `top`, centred: lines step by font height + the dialogue's GAP, and
## the Hangul ink sits NOTICE_PAD from the panel edge above and below.
func _notice_rect_at(top: float) -> Rect2:
	var size := UiText.sz(UiText.M)
	var w := 0.0
	for line in _notice_lines:
		w = maxf(w, UiText.width(line, size))
	var step := Anim.font.get_height(size) + DialogueText.GAP
	var h := roundf(step * (_notice_lines.size() - 1) + (INK_UP + INK_DOWN) * size + NOTICE_PAD * 2.0)
	return Rect2(roundf(get_viewport_rect().size.x * 0.5 - w * 0.5 - 12.0), top, roundf(w + 24.0), h)


## The player on screen, hair to feet, grown over the prompt pill of whatever she can use right here.
func _player_screen_rect() -> Rect2:
	var feet := player.get_global_transform_with_canvas().origin
	var r := Rect2(feet.x - 14.0, feet.y - 54.0, 28.0, 54.0)
	var ph := Interactable.pill_height()
	for it in get_tree().get_nodes_in_group("interactable"):
		if it is Interactable and it.shows_pill():
			var o: Vector2 = it.get_global_transform_with_canvas().origin
			r = r.merge(Rect2(o.x - 40.0, o.y + Interactable.PROMPT_BOTTOM - ph, 80.0, ph))
	return r


func _draw_notice() -> void:
	if _notice_text == "":
		return
	var size := UiText.sz(UiText.M)
	notice_rect = _notice_rect_at(NOTICE_MENU_Y if palm_menu.visible else _notice_top)   # never over the menu's list
	UiText.panel(notice_box, notice_rect, 0.92)
	var cx := get_viewport_rect().size.x * 0.5
	var base := roundf(notice_rect.position.y + NOTICE_PAD + INK_UP * size)
	var step := Anim.font.get_height(size) + DialogueText.GAP
	for i in _notice_lines.size():
		UiText.centered(notice_box, cx, base + step * i, _notice_lines[i], size, Color(1.0, 0.88, 0.7), 0)


## The palm menu pauses the tree (and _process with it): the toast moves to the menu's strip at full alpha.
func _on_menu_toggled() -> void:
	notice_box.self_modulate.a = 1.0
	notice_box.queue_redraw()


func _draw_death() -> void:
	var vp := get_viewport_rect().size
	death_screen.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.0, 0.02, 0.6))
	UiText.centered(death_screen, vp.x * 0.5, 214.0, "쓰러졌다", UiText.sz(28), Color(0.96, 0.52, 0.46))
	UiText.centered(death_screen, vp.x * 0.5, 244.0, "마지막 등불에서 다시 시작합니다", UiText.sz(UiText.M), UiText.INK)


func _draw_cutscene() -> void:
	cutscene.draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0.02, 0.01, 0.02, CUT_DIM))


## Route card stops: a nameplate straddling the card's bottom frame, drawn from the image's own draw
## signal (after its texture) so the art never covers it. Image-local coordinates.
func _draw_cut_caption() -> void:
	if _cut_caption == "":
		return
	var cs := UiText.sz(UiText.M)
	var h := Anim.font.get_height(cs) + 6.0
	var w := roundf(UiText.width(_cut_caption, cs) + 24.0)
	var cx := CUT_RECT.size.x * 0.5
	var r := Rect2(roundf(cx - w * 0.5), roundf(CUT_RECT.size.y + 3.0 - h * 0.5), w, h)
	UiText.panel(_cut_image, r, 1.0)
	UiText.centered(_cut_image, cx, r.position.y + 3.0 + Anim.font.get_ascent(cs), _cut_caption, cs, UiText.ACCENT, 0)


# ---------- ui ----------

func _build_ui() -> void:
	UiText.touch = _touch_device()   # before any size is picked
	var layer := CanvasLayer.new()
	hud = Control.new()
	hud.set_script(preload("res://src/ui/hud.gd"))
	hud.player = player
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	boss_hud = Control.new()
	boss_hud.set_script(preload("res://src/ui/boss_hud.gd"))
	boss_hud.visible = false
	layer.add_child(boss_hud)
	var vp := get_viewport_rect().size
	# map title band: the 400×30 art scaled ×1.35 with its knot ends whole and the plain rail between them
	# squeezed, so it stays 400 px wide (x 200–600) but has room for the title between its rules
	title_band = NinePatchRect.new()
	title_band.texture = Anim.ui_tex("map_title")
	title_band.patch_margin_left = TITLE_CAP
	title_band.patch_margin_right = TITLE_CAP
	title_band.size = Vector2(400.0 / TITLE_SCALE, 30.0)
	title_band.scale = Vector2(TITLE_SCALE, TITLE_SCALE)
	title_band.position = Vector2(roundf((vp.x - 400.0) * 0.5), TITLE_Y)
	title_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_band.modulate.a = 0.0
	layer.add_child(title_band)
	# Hangul ink runs ~0.83 em above the baseline and ~0.06 below: centre the ink (not the line box, whose
	# descent would push it up) on the band interior, art rows 5–22 between the rules. No outline: the
	# interior is opaque.
	var ts := UiText.sz(UiText.XL)
	title_label = Label.new()
	title_label.position = Vector2(0, roundf(TITLE_Y + 14.0 * TITLE_SCALE + 0.385 * ts) - Anim.font.get_ascent(ts))
	title_label.size = Vector2(vp.x, Anim.font.get_height(ts))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.modulate.a = 0.0
	UiText.style_label(title_label, ts, Color(0.98, 0.92, 0.84), 0)
	layer.add_child(title_label)
	add_child(layer)
	# death card: above touch buttons (5), cutscene (6) and dialogue (8) so nothing stays bright over the
	# dim; the palm menu (9) can't be open while dead
	var death_layer := CanvasLayer.new()
	death_layer.layer = 9
	death_screen = Control.new()
	death_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_screen.visible = false
	death_screen.draw.connect(_draw_death)
	death_layer.add_child(death_screen)
	add_child(death_layer)
	# first-entry card: above the touch buttons (5) and the HUD; dialogue (8) holds its lines while it is up
	var cut_layer := CanvasLayer.new()
	cut_layer.layer = 6
	cutscene = Control.new()
	cutscene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cutscene.visible = false
	cutscene.draw.connect(_draw_cutscene)
	# the dialogue box's knot frame (same slices as dialogue.gd) around the art; its dark interior sits
	# under the image, leaving a 3–4 px mat inside the gold rule. The art is its child and fades with it.
	_cut_card = NinePatchRect.new()
	_cut_card.texture = Anim.ui_tex("dialogue_frame")
	_cut_card.patch_margin_left = 12
	_cut_card.patch_margin_top = 11
	_cut_card.patch_margin_right = 6
	_cut_card.patch_margin_bottom = 11
	_cut_card.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	_cut_card.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	_cut_card.position = CUT_RECT.position - Vector2(10, 6)
	_cut_card.size = CUT_RECT.size + Vector2(16, 10)
	_cut_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cutscene.add_child(_cut_card)
	_cut_image = TextureRect.new()
	_cut_image.position = Vector2(10, 6)
	_cut_image.size = CUT_RECT.size
	_cut_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cut_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cut_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cut_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cut_image.draw.connect(_draw_cut_caption)
	_cut_card.add_child(_cut_image)
	cut_layer.add_child(cutscene)
	add_child(cut_layer)
	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 9
	palm_menu = Control.new()
	palm_menu.set_script(preload("res://src/ui/palm_menu.gd"))
	menu_layer.add_child(palm_menu)
	pause_menu = Control.new()
	pause_menu.set_script(preload("res://src/ui/pause_menu.gd"))
	menu_layer.add_child(pause_menu)
	add_child(menu_layer)
	# notices sit above the palm menu (equipping raises "「X」 장착"; drawn under its panels while open)
	# and below the travel fade
	var notice_layer := CanvasLayer.new()
	notice_layer.layer = 10
	notice_box = Control.new()
	notice_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice_box.draw.connect(_draw_notice)
	palm_menu.visibility_changed.connect(_on_menu_toggled)
	notice_layer.add_child(notice_box)
	add_child(notice_layer)
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 11
	_fade = ColorRect.new()
	_fade.color = Color(0.05, 0.03, 0.04, 0.0)
	_fade.size = get_viewport_rect().size
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(_fade)
	add_child(fade_layer)
	if _touch_device():
		player.touch_mode = true
		hud.show_skills = false
		for a in ["attack", "skill_pull"]:
			for ev in InputMap.action_get_events(a):
				if ev is InputEventMouseButton:
					InputMap.action_erase_event(a, ev)
		var touch_layer := CanvasLayer.new()
		touch_layer.layer = 5
		var tc := Control.new()
		tc.set_script(preload("res://src/player/touch_controls.gd"))
		tc.player = player
		touch_layer.add_child(tc)
		add_child(touch_layer)
		touch_controls = tc


func _touch_device() -> bool:
	if "--touch" in OS.get_cmdline_user_args() or (OS.has_feature("web") and "touch" in String(JavaScriptBridge.eval("location.search", true))):
		return true
	return OS.has_feature("mobile_build")


func _setup_input() -> void:
	var map := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "jump": [KEY_W],
		"dash": [KEY_SHIFT], "walk": [KEY_CTRL], "crouch": [KEY_S], "attack_key": [KEY_J, KEY_X], "reset": [KEY_R],
		"parry": [KEY_SPACE], "heavy_attack": [KEY_E], "ultimate": [KEY_Q], "interact": [KEY_UP, KEY_W], "menu": [KEY_TAB], "skill_pull": [KEY_F], "pause": [KEY_ESCAPE],
	}
	for action in map:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action)
		for key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", mb)
	var mb2 := InputEventMouseButton.new()
	mb2.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("skill_pull", mb2)   # E = 강화 초식, 우클릭/F = 월인
