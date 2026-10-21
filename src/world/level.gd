extends Node2D
class_name Level

signal boss_spawned(boss: Node)
## A hand-built map from a data dictionary (levels/*.gd): floor, platforms, cover, props, and rooms.
## Rooms are camera sections (본편 §1); a locked room spawns its enemies on entry, walls both ends, and
## opens when every enemy is dead (at most two per map by design). Clears are session flags until a
## checkpoint commits them, so death resets only the rooms after the checkpoint (§10).
##
## data keys: id, name, width, ground_y, backdrop, spawns {id: Vector2}, platforms [Rect2],
##   covers [Rect2], props [{type, x, y?, ...}], rooms [{id, name, x0, x1, lock, enemies [{type, x, y?}], lines [[who, text]]}],
##   camera {top, bottom}

var data: Dictionary = {}
var id := ""
var ground_y := 300.0
var width := 1600.0
var solids: Array = []            # Rect2 (floor pieces, platforms, covers) for projectiles
var rooms: Array = []             # runtime room dicts
var active_room: Dictionary = {}
var player: Player
var camera: Camera2D
var _walls: Array = []
var _seals: Array = []            # drawn look of the walls (kept apart: tests count the bodies)
var _ends: Node2D                  # shade past the map ends: gives way to a lock's dim (an arena wall on a map end)
var _spawned: Dictionary = {}     # room id → [enemies]
var _enemy_count := 0
var _safe := Vector2.ZERO          # last grounded spot over real floor (pit respawn, 본편 §4)
var art: LevelArt
const FLOOR_TINT := {"lab": Color(0.14, 0.13, 0.16), "shrine": Color(0.2, 0.17, 0.19)}   # greybox floor per backdrop
## Locked-room seal and dim start this far above the ground: with the camera at its lowest (bottom limit
## ground+100) that is canvas y 130, below the tallest player-status block, so neither shows through it.
const SEAL_TOP := 220.0


func build(d: Dictionary, p: Player, cam: Camera2D) -> void:
	data = d
	id = String(d.id)
	ground_y = float(d.get("ground_y", 300.0))
	width = float(d.get("width", 1600.0))
	player = p
	camera = cam
	var painted: bool = d.has("map_key") and Anim.bg.has(String(d.map_key))
	if painted:
		art = LevelArt.new()
		add_child(art)
		art.build(self, String(d.map_key))
	else:
		_build_backdrop()
	var pieces: Dictionary = d.get("art", {})
	var floor_col: Color = FLOOR_TINT.get(String(d.get("backdrop", "")), Color(0.14, 0.11, 0.1))
	for seg in d.get("floor", [[-200.0, width + 200.0]]):
		_solid(Rect2(float(seg[0]), ground_y, float(seg[1]) - float(seg[0]), 60), floor_col, painted, 340.0)
		if painted:
			art.add_floor(float(seg[0]), float(seg[1]))
	var ceilings: Array = d.get("ceilings", [])
	for i in ceilings.size():
		var r: Rect2 = ceilings[i]
		var drawn: bool = painted and pieces.has("c%d" % i) and art.add_piece(String(pieces["c%d" % i]), r)
		_solid(r, Color(0.2, 0.17, 0.15), drawn)
	var plats: Array = d.get("platforms", [])
	for i in plats.size():
		var r: Rect2 = plats[i]
		var drawn := false
		if painted:
			var key := "p%d" % i
			if pieces.has(key):
				var name := String(pieces[key])
				if name == "t0_platform":
					art.add_platform(name, r)
					drawn = true
				else:
					drawn = art.add_piece(name, r)
		_solid(r, Color(0.3, 0.22, 0.16), drawn, 0.0, false, r.size.y <= 24.0)   # thin ledges: pass from below, drop through with S
	var covers: Array = d.get("covers", [])
	for i in covers.size():
		var r: Rect2 = covers[i]
		var drawn: bool = painted and pieces.has("v%d" % i) and art.add_piece(String(pieces["v%d" % i]), r)
		_solid(r, Color(0.22, 0.2, 0.18), drawn, 0.0, true)
	if painted:
		for dec in d.get("decor", []):
			art.add_decor(String(dec[0]), Vector2(float(dec[1]), float(dec[2])), bool(dec[3]) if dec.size() > 3 else true)
	_ends = Node2D.new()   # out-of-bounds shade past both map ends (z 5, like a locked room's dim)
	_ends.z_index = 5
	_ends.draw.connect(func() -> void:
		_draw_out(_ends, 0.0, -1.0)
		_draw_out(_ends, width, 1.0))
	add_child(_ends)
	for pr in d.get("props", []):
		_build_prop(pr)
	for rd in d.get("rooms", []):
		var room := {"id": String(rd.id), "name": String(rd.get("name", "")), "x0": float(rd.x0), "x1": float(rd.x1), "lock": bool(rd.get("lock", false)), "enemies": rd.get("enemies", []), "lines": rd.get("lines", []), "entered": false}
		if rd.has("cleared_by"):
			room.cleared_by = String(rd.cleared_by)
		if rd.has("lines_after"):
			room.lines_after = rd.lines_after
			room.lines_flag = String(rd.get("lines_flag", ""))
		rooms.append(room)
	for r in rooms:   # normal enemies are placed now and sleep; crossing the room line wakes them
		if r.enemies.is_empty() or cleared(r.id):
			continue
		var list: Array = []
		for e in r.enemies:
			if _pre_placed(e):
				var n := _spawn_enemy(e, r)
				if n:
					list.append(n)
		_spawned[r.id] = list
	var cb: Dictionary = d.get("camera", {})
	camera.set_bounds(0, int(cb.get("top", -60)), int(width), int(cb.get("bottom", ground_y + 100)))
	player.world_min_x = 20.0
	player.world_max_x = width - 20.0


func _pre_placed(e: Dictionary) -> bool:
	return String(e.type) in ["soldier", "archer", "shield", "mage", "incense"]


func _alive(list: Array) -> int:
	var n := 0
	for e in list:
		if is_instance_valid(e) and e.status.alive():
			n += 1
	return n


func spawn_point(spawn_id: String) -> Vector2:
	var s: Dictionary = data.get("spawns", {})
	if s.has(spawn_id):
		return s[spawn_id]
	return Vector2(80, ground_y)


func cleared(room_id: String) -> bool:
	if Game.flag("cleared:%s:%s" % [id, room_id]):
		return true
	for r in rooms:   # a boss arena stays clear once its boss is beaten (permanent flag), even after a death or reload
		if String(r.id) == room_id and r.has("cleared_by") and Game.flag(String(r.cleared_by)):
			return true
	return false


# ---------- building ----------

func _build_backdrop() -> void:
	var bd := Node2D.new()
	bd.set_script(preload("res://src/world/backdrop.gd"))
	bd.style = String(data.get("backdrop", "yard"))
	bd.width = width
	bd.ground_y = ground_y
	bd.platforms = data.get("platforms", [])
	bd.z_index = -5
	add_child(bd)


## `depth`: visual fill below the collision rect (floor pieces only; collision stays 60 px).
## `one_way`: a ledge on physics layer 2 that only blocks from above (the player drops through it on S / a down dash).
func _solid(r: Rect2, col: Color, painted := false, depth := 0.0, cover := false, one_way := false) -> void:
	solids.append(r)
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	if one_way:
		shape.one_way_collision = true
		body.collision_layer = 2
	body.add_child(shape)
	body.position = r.get_center()
	add_child(body)
	if painted:
		return
	var box := Node2D.new()
	box.set_script(preload("res://src/world/solid_art.gd"))
	box.rect = r
	box.color = col
	box.depth = depth
	box.style = String(data.get("backdrop", ""))
	box.cover = cover
	box.floor_y = ground_y
	if depth > 0.0:
		box.lanes = data.get("lanes", [])   # boss lane strikes: the floor shows its sections
	box.z_index = -1
	add_child(box)


func _build_prop(pr: Dictionary) -> void:
	var x := float(pr.x)
	var y := float(pr.get("y", ground_y))
	var node: Node2D
	match String(pr.type):
		"checkpoint":
			node = Node2D.new()
			node.set_script(preload("res://src/world/checkpoint.gd"))
			node.cp_id = String(pr.id)
			node.level_id = id
		"door":
			node = Node2D.new()
			node.set_script(preload("res://src/world/door.gd"))
			node.target_level = String(pr.to)
			node.target_spawn = String(pr.get("spawn", "start"))
			node.label = String(pr.get("label", "이동"))
			node.requires = String(pr.get("requires", ""))
		"manual":
			node = Node2D.new()
			node.set_script(preload("res://src/world/manual_pickup.gd"))
			node.manual_id = String(pr.id)
		"rest":
			node = Node2D.new()
			node.set_script(preload("res://src/world/rest_point.gd"))
		"dummy":
			node = Node2D.new()
			node.set_script(preload("res://src/enemies/dummy.gd"))
		"sign":
			node = Node2D.new()
			node.set_script(preload("res://src/world/sign.gd"))
			node.text = String(pr.text)
		"npc":
			node = Node2D.new()
			node.set_script(preload("res://src/world/npc.gd"))
			node.who = String(pr.who)
			node.face = float(pr.get("face", -1.0))
		"mark":
			node = Node2D.new()
			node.set_script(preload("res://src/world/prop_anim.gd"))
			node.clip = String(pr.get("clip", "disciple_mark"))
		"hazard":
			node = Node2D.new()
			node.set_script(preload("res://src/world/hazard_plate.gd"))
			node.phase = float(pr.get("phase", 0.0))
		"rescue":
			node = Node2D.new()
			node.set_script(preload("res://src/world/rescue.gd"))
			node.rescue_id = String(pr.id)
			node.who = String(pr.get("who", "disciple_m"))
			node.exit_dir = float(pr.get("exit", -1.0))
		"pickup":
			node = Node2D.new()
			node.set_script(preload("res://src/world/pickup.gd"))
			node.kind = String(pr.get("kind", "tonic"))
			node.pickup_id = String(pr.id)
			node.text = String(pr.get("text", ""))
		_:
			return
	node.position = Vector2(x, y)
	add_child(node)


# ---------- rooms ----------

func _physics_process(_dt: float) -> void:
	if player == null:
		return
	if player.is_on_floor() and not player.dead:
		_safe = player.global_position
	elif player.global_position.y > ground_y + 140.0 and _safe != Vector2.ZERO:
		# fell into a pit: back to the last footing, no damage (낙하 시 가까운 발판으로 복귀)
		player.global_position = _safe
		player.velocity = Vector2.ZERO
		player.air_jump_available = true
		player.air_dash_available = true
		Game.notice.emit("발판으로 복귀")
	var px := player.global_position.x
	for r in rooms:
		if px >= r.x0 and px <= r.x1:
			if not r.entered:
				r.entered = true
				_enter_room(r)
			break


func _enter_room(r: Dictionary) -> void:
	active_room = r
	var lines: Array = r.lines
	if r.has("lines_after") and Game.flag(String(r.get("lines_flag", ""))):
		lines = r.lines_after
	for line in lines:
		Dialogue.say(String(line[0]), String(line[1]))
	if r.enemies.is_empty() or cleared(r.id):
		return
	var list: Array = _spawned.get(r.id, [])
	for e in r.enemies:
		if not _pre_placed(e):
			var n := _spawn_enemy(e, r)
			if n:
				list.append(n)
	_spawned[r.id] = list
	for n in list:
		if is_instance_valid(n) and n.get("active") != true and n.status.alive():   # the demo master has no active flag
			n.activate(player)
	_enemy_count = _alive(list)
	if _enemy_count == 0:
		_on_enemy_died(null)   # all killed from outside before entering
	elif r.lock:
		_lock(r)


func _spawn_enemy(e: Dictionary, r: Dictionary = {}) -> Node2D:
	var n: Node2D
	match String(e.type):
		"soldier":
			n = Node2D.new()
			n.set_script(preload("res://src/enemies/soldier.gd"))
			n.combo_ready = bool(e.get("combo", false))
		"archer":
			n = Node2D.new()
			n.set_script(preload("res://src/enemies/scout_archer.gd"))
			n.human = bool(e.get("human", false))
		"shield":
			n = Node2D.new()
			n.set_script(preload("res://src/enemies/shield_soldier.gd"))
		"mage":
			n = Node2D.new()
			n.set_script(preload("res://src/enemies/mage.gd"))
		"incense":
			n = Node2D.new()
			n.set_script(preload("res://src/enemies/incense_keeper.gd"))
		"tianel", "mireille", "elodie":
			n = Node2D.new()
			n.set_script(load("res://src/boss/%s.gd" % {"tianel": "tianel", "mireille": "boss_mireille", "elodie": "boss_elodie"}[String(e.type)]))
			n.perches = data.get("perches", [])
			n.lanes = data.get("lanes", [])
			n.arena_left = float(active_room.x0) + 40.0
			n.arena_right = float(active_room.x1) - 40.0
			boss_spawned.emit(n)
		"mokgak_drill":
			n = Node2D.new()
			n.set_script(preload("res://src/boss/boss_mokgak.gd"))
			n.drill = true
		_:
			return null
	n.position = Vector2(float(e.x), float(e.get("y", ground_y)))
	if not r.is_empty() and n.get("room_x0") != null:
		n.room_x0 = float(r.x0)
		n.room_x1 = float(r.x1)
		n.home_x = float(e.x)
	n.died.connect(_on_enemy_died)
	add_child(n)
	return n


func _on_enemy_died(_enemy: Node) -> void:
	if active_room.is_empty() or Game.flag("cleared:%s:%s" % [id, active_room.id]):   # the session clear only: a boss flag set a frame earlier must not skip the unlock
		return
	_enemy_count = _alive(_spawned.get(active_room.id, []))
	if _enemy_count <= 0:
		Game.set_flag("cleared:%s:%s" % [id, active_room.id], false)
		_unlock()
		Game.notice.emit("구역 정리")


func _lock(r: Dictionary) -> void:
	camera.set_bounds(int(r.x0), camera.limit_top, int(r.x1), camera.limit_bottom)
	for x in [r.x0, r.x1]:
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(16, 600)
		shape.shape = rect
		body.add_child(shape)
		body.position = Vector2(x + (-8 if x == r.x0 else 8), ground_y - 200)
		add_child(body)
		_walls.append(body)
		# rooms are narrower than the view, so the wall must be seen: a seal band under the fighters (z 1,
		# over props past the wall) and the far side dimmed over them (z 5: under projectiles and world
		# text), so the next room's sleeping enemies do not read as part of this fight
		for z in [1, 5]:
			var n := Node2D.new()
			n.z_index = z
			n.modulate.a = 0.0
			n.draw.connect((_draw_seal if z == 1 else _draw_dim).bind(n, float(x), -1.0 if x == r.x0 else 1.0))
			add_child(n)
			n.create_tween().tween_property(n, "modulate:a", 1.0, 0.2)
			_seals.append(n)
	_ends.create_tween().tween_property(_ends, "modulate:a", 0.0, 0.2)   # the dim takes over: no doubled shade
	player.world_min_x = r.x0 + 12.0
	player.world_max_x = r.x1 - 12.0


## A locked-room wall at `x`; `out` is the side away from the room (-1 left, +1 right). A dark crimson
## band with a muted gold ward cord and talisman tags on the room side: a red edge read as one more
## telegraph outline in boss fights.
func _draw_seal(ci: Node2D, x: float, out: float) -> void:
	var ink := Color(0.34, 0.05, 0.08)
	var ward := Color(0.78, 0.58, 0.42, 0.9)
	var paper := Color(0.88, 0.8, 0.64, 0.85)
	var top := ground_y - SEAL_TOP
	var sink := 0.0 if UiText.touch else 60.0   # touch: the floor below the wall is the stick's zone
	for band in [[x if out > 0.0 else x - 7.0, 7.0, ink], [x if out > 0.0 else x - 2.0, 2.0, ward]]:   # the cord faces the room
		var bx: float = band[0]
		var bw: float = band[1]
		var c: Color = band[2]
		LevelArt.vgrad(ci, Rect2(bx, top, bw, 60.0), Color(c, 0.0), c)   # fades out below the HUD
		ci.draw_rect(Rect2(bx, top + 60.0, bw, SEAL_TOP - 60.0), c)
		if sink > 0.0:
			LevelArt.vgrad(ci, Rect2(bx, ground_y, bw, sink), c, Color(c, 0.0))   # sinks into the floor
	var rung := x - 3.0 if out > 0.0 else x - 7.0   # across the band and 3 px into the room
	var tag := x - 3.0 if out > 0.0 else x          # a paper tag hanging from the rung's room end
	var y := top + 20.0
	while y < ground_y - 10.0:
		var a := clampf((y - top) / 60.0, 0.0, 1.0)   # the same fade-in as the band
		ci.draw_rect(Rect2(rung, y, 10.0, 2.0), Color(ward, ward.a * a))
		ci.draw_rect(Rect2(tag, y + 2.0, 3.0, 6.0), Color(paper, paper.a * a))
		y += 28.0


## The far side of a locked-room wall, dimmed beside the seal band (not over it), fading in over the
## same range as the band so the status panel never sits half over a dimmed backdrop.
func _draw_dim(ci: Node2D, x: float, out: float) -> void:
	var x0 := x + 7.0 if out > 0.0 else x - 1207.0
	var dim := Color(0, 0, 0, 0.45)
	LevelArt.vgrad(ci, Rect2(x0, ground_y - SEAL_TOP, 1200.0, 60.0), Color(dim, 0.0), dim)
	ci.draw_rect(Rect2(x0, ground_y - SEAL_TOP + 60.0, 1200.0, SEAL_TOP + 440.0), dim)


## Past a map end (`x`, `out` as in _draw_seal): touch builds let the view run past both ends and a
## centred arena shows a strip beyond its wall, where floor and backdrop carry on but nobody can walk.
## The _draw_dim shade, faded in over 36 px from the edge, and a dark cut through the floor.
func _draw_out(ci: Node2D, x: float, out: float) -> void:
	var dim := Color(0, 0, 0, 0.45)
	var clear := Color(dim, 0.0)
	var top := ground_y - SEAL_TOP
	var xf := x + 36.0 * out
	var xe := x + 1200.0 * out
	for row in [[top, top + 60.0, clear], [top + 60.0, ground_y + 440.0, dim]]:
		var y0: float = row[0]
		var y1: float = row[1]
		var a: Color = row[2]   # the shade at the row's top: fading in below the HUD as _draw_dim does
		ci.draw_polygon(PackedVector2Array([Vector2(x, y0), Vector2(xf, y0), Vector2(xf, y1), Vector2(x, y1)]), PackedColorArray([clear, a, dim, clear]))
		ci.draw_polygon(PackedVector2Array([Vector2(xf, y0), Vector2(xe, y0), Vector2(xe, y1), Vector2(xf, y1)]), PackedColorArray([a, a, dim, dim]))
	LevelArt.vgrad(ci, Rect2(x if out > 0.0 else x - 3.0, ground_y, 3.0, 100.0), Color(0, 0, 0, 0.6), Color(0, 0, 0, 0.0))


func _unlock() -> void:
	for w in _walls:
		w.queue_free()
	_walls.clear()
	for s in _seals:
		var t: Tween = s.create_tween()
		t.tween_property(s, "modulate:a", 0.0, 0.2)
		t.tween_callback(s.queue_free)
	_seals.clear()
	_ends.create_tween().tween_property(_ends, "modulate:a", 1.0, 0.2)
	var cb: Dictionary = data.get("camera", {})
	camera.set_bounds(0, int(cb.get("top", -60)), int(width), int(cb.get("bottom", ground_y + 100)))
	player.world_min_x = 20.0
	player.world_max_x = width - 20.0


## Is a world point inside the camera's current view (archers never start a shot off-screen, §5)?
func camera_sees(p: Vector2) -> bool:
	var half := camera.get_viewport_rect().size * 0.5
	var c := camera.get_screen_center_position()
	return absf(p.x - c.x) <= half.x + 8.0 and absf(p.y - c.y) <= half.y + 8.0


func blocked(p: Vector2) -> bool:
	for r in solids:
		if r.has_point(p):
			return true
	return false
