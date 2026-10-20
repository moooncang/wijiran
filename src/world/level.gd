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
var _spawned: Dictionary = {}     # room id → [enemies]
var _enemy_count := 0
var _safe := Vector2.ZERO          # last grounded spot over real floor (pit respawn, 본편 §4)


func build(d: Dictionary, p: Player, cam: Camera2D) -> void:
	data = d
	id = String(d.id)
	ground_y = float(d.get("ground_y", 300.0))
	width = float(d.get("width", 1600.0))
	player = p
	camera = cam
	_build_backdrop()
	for seg in d.get("floor", [[-200.0, width + 200.0]]):
		_solid(Rect2(float(seg[0]), ground_y, float(seg[1]) - float(seg[0]), 60), Color(0.14, 0.11, 0.1))
	for r in d.get("ceilings", []):
		_solid(r, Color(0.2, 0.17, 0.15))
	for r in d.get("platforms", []):
		_solid(r, Color(0.3, 0.22, 0.16))
	for r in d.get("covers", []):
		_solid(r, Color(0.22, 0.2, 0.18))
	for pr in d.get("props", []):
		_build_prop(pr)
	for rd in d.get("rooms", []):
		rooms.append({"id": String(rd.id), "name": String(rd.get("name", "")), "x0": float(rd.x0), "x1": float(rd.x1), "lock": bool(rd.get("lock", false)), "enemies": rd.get("enemies", []), "lines": rd.get("lines", []), "entered": false})
	var cb: Dictionary = d.get("camera", {})
	camera.set_bounds(0, int(cb.get("top", -60)), int(width), int(cb.get("bottom", ground_y + 100)))
	player.world_min_x = 20.0
	player.world_max_x = width - 20.0


func spawn_point(spawn_id: String) -> Vector2:
	var s: Dictionary = data.get("spawns", {})
	if s.has(spawn_id):
		return s[spawn_id]
	return Vector2(80, ground_y)


func cleared(room_id: String) -> bool:
	return Game.flag("cleared:%s:%s" % [id, room_id])


# ---------- building ----------

func _build_backdrop() -> void:
	var bd := Node2D.new()
	bd.set_script(preload("res://src/world/backdrop.gd"))
	bd.style = String(data.get("backdrop", "yard"))
	bd.width = width
	bd.ground_y = ground_y
	bd.z_index = -5
	add_child(bd)


func _solid(r: Rect2, col: Color) -> void:
	solids.append(r)
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	body.add_child(shape)
	body.position = r.get_center()
	add_child(body)
	var art := Node2D.new()
	art.set_script(preload("res://src/world/solid_art.gd"))
	art.rect = r
	art.color = col
	art.z_index = -1
	add_child(art)


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
	for line in r.lines:
		Dialogue.say(String(line[0]), String(line[1]))
	if r.enemies.is_empty() or cleared(r.id):
		return
	var list: Array = []
	for e in r.enemies:
		var n := _spawn_enemy(e)
		if n:
			list.append(n)
	_spawned[r.id] = list
	_enemy_count = list.size()
	if r.lock:
		_lock(r)


func _spawn_enemy(e: Dictionary) -> Node2D:
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
		"tianel":
			n = Node2D.new()
			n.set_script(preload("res://src/boss/tianel.gd"))
			n.perches = data.get("perches", [])
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
	n.died.connect(_on_enemy_died)
	add_child(n)
	n.activate(player)
	return n


func _on_enemy_died(_enemy: Node) -> void:
	_enemy_count -= 1
	if _enemy_count <= 0 and not active_room.is_empty():
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
	player.world_min_x = r.x0 + 12.0
	player.world_max_x = r.x1 - 12.0


func _unlock() -> void:
	for w in _walls:
		w.queue_free()
	_walls.clear()
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
