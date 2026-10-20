extends Node2D
## Root scene: owns the current Level, the player, the camera and the UI layers; routes travel, death
## and interaction. Levels are data classes (levels/*.gd). `-- --level=f1 --spawn=start` starts elsewhere,
## `-- --test=all|palm|save|projectile|room|tianel|checkpoint` runs tests/selftests.gd, `-- --touch`
## forces the on-screen controls, `-- --wipe` clears the save.

static var LEVELS := {"t0": LevelT0, "f1": LevelF1, "b1": LevelB1, "h0": LevelH0}

var player: Player
var level: Level
var cam: Camera2D
var hud: Control
var boss_hud: Control
var palm_menu: Control
var touch_controls: Control
var notice_label: Label
var title_label: Label
var _fade: ColorRect
var _fade_t := -1.0
var _pending: Array = []       # [level_id, spawn_id]
var _death_t := -1.0
var _notice_left := 0.0
var title_band: TextureRect
var cutscene: TextureRect
var _cut_t := -1.0


func _ready() -> void:
	_setup_input()
	Juice.world = self
	var args := OS.get_cmdline_user_args()
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
	for a in args:
		if a.begins_with("--test="):
			var t := Node.new()
			t.set_script(preload("res://tests/selftests.gd"))
			t.suite = a.substr(7)
			add_child(t)


# ---------- levels ----------

func _load_level(level_id: String, spawn_id: String) -> void:
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
	_title_left = 2.5
	_death_t = -1.0
	var cut := String(level.data.get("cutscene", ""))
	if cut != "" and Anim.cutscenes.has(cut) and not Game.save.skip_intro_seen.has(cut):
		Game.save.skip_intro_seen.append(cut)
		Game.write_save()
		cutscene.texture = Anim.tex(String(Anim.cutscenes[cut].file))
		cutscene.visible = true
		_cut_t = 0.0


var _title_left := 0.0


func _on_travel(level_id: String, spawn_id: String) -> void:
	if _fade_t >= 0.0:
		return
	_pending = [level_id, spawn_id]
	_fade_t = 0.0


func _on_boss_spawned(boss: Node) -> void:
	boss_hud.boss = boss
	boss_hud.visible = true


# ---------- frame ----------

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("interact") and not Game.paused:
		for it in get_tree().get_nodes_in_group("interactable"):
			if it.try_use():
				break
	if Input.is_action_just_pressed("reset") and not Game.paused:
		Game.respawn()
	_step_fade(delta)
	_notice_left = maxf(0.0, _notice_left - delta)
	notice_label.visible = _notice_left > 0.0
	_title_left = maxf(0.0, _title_left - delta)
	title_label.modulate.a = clampf(_title_left, 0.0, 1.0)
	title_band.modulate.a = title_label.modulate.a
	if _cut_t >= 0.0:
		_cut_t += delta
		cutscene.modulate.a = clampf(minf(_cut_t * 2.0, (3.2 - _cut_t) * 2.0), 0.0, 1.0)
		if _cut_t >= 3.2:
			_cut_t = -1.0
			cutscene.visible = false
	if player.dead and _death_t < 0.0:
		_death_t = 0.0
	if _death_t >= 0.0:
		_death_t += delta
		if _death_t >= 1.6 and _fade_t < 0.0:
			_death_t = -1.0
			Game.respawn()


func _step_fade(delta: float) -> void:
	if _fade_t < 0.0:
		return
	_fade_t += delta
	if _fade_t < 0.25:
		_fade.color.a = _fade_t / 0.25
	elif _fade_t < 0.30:
		if _fade.color.a < 1.0:
			_fade.color.a = 1.0
			_load_level(_pending[0], _pending[1])
	elif _fade_t < 0.60:
		_fade.color.a = 1.0 - (_fade_t - 0.30) / 0.30
	else:
		_fade.color.a = 0.0
		_fade_t = -1.0


func _on_notice(text: String) -> void:
	notice_label.text = text
	_notice_left = 2.6


# ---------- ui ----------

func _build_ui() -> void:
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
	notice_label = Label.new()
	notice_label.position = Vector2(240, 118)
	notice_label.size = Vector2(320, 20)
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.add_theme_font_size_override("font_size", 10)
	notice_label.add_theme_color_override("font_color", Color(1, 0.85, 0.65))
	notice_label.visible = false
	layer.add_child(notice_label)
	title_band = TextureRect.new()
	title_band.texture = Anim.ui_tex("map_title")
	title_band.position = Vector2(200, 148)
	layer.add_child(title_band)
	title_label = Label.new()
	title_label.position = Vector2(0, 150)
	title_label.size = Vector2(800, 30)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.85))
	layer.add_child(title_label)
	cutscene = TextureRect.new()
	cutscene.position = Vector2(80, 45)
	cutscene.size = Vector2(640, 360)
	cutscene.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cutscene.stretch_mode = TextureRect.STRETCH_SCALE
	cutscene.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cutscene.visible = false
	layer.add_child(cutscene)
	add_child(layer)
	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 9
	palm_menu = Control.new()
	palm_menu.set_script(preload("res://src/ui/palm_menu.gd"))
	menu_layer.add_child(palm_menu)
	add_child(menu_layer)
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 10
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
	if "--touch" in OS.get_cmdline_user_args():
		return true
	return OS.has_feature("mobile_build")


func _setup_input() -> void:
	var map := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "jump": [KEY_W],
		"dash": [KEY_SHIFT], "walk": [KEY_CTRL], "crouch": [KEY_S], "attack_key": [KEY_J, KEY_X], "reset": [KEY_R],
		"parry": [KEY_SPACE], "heavy_attack": [KEY_E], "ultimate": [KEY_Q], "interact": [KEY_UP, KEY_W], "menu": [KEY_TAB], "skill_pull": [KEY_F],
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
