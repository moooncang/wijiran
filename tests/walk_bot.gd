extends Node
## Playthrough bot (`-- --test=walk`): plays the whole act with real inputs — walks right, escalates
## jump → air jump → air dash → ground dash when blocked, fights what stands in reach, parries telegraphs,
## uses doors/manuals/rescues/pickups, dies once per field map after its mid checkpoint to exercise the
## respawn, and cheat-kills bosses once their bar is up (patterns have their own tests). Every frame it
## checks invariants a player would call a bug and prints them as "ANOMALY level: text" (deduped).

const MAX_LEVEL_TIME := 320.0
const ORDER := ["t0", "f1", "b1", "h0", "f2", "b2", "f3", "b3", "h0"]

var main: Node2D
var anomalies: Array = []
var log_lines: Array = []
var deaths := 0
var _seen: Dictionary = {}
var _died_here := false
var _level_t := 0.0
var _stuck_t := 0.0
var _escalate := 0
var _last_x := 0.0
var _best_x := -INF
var _mark_x := -INF
var _attack_t := 0.0
var _boss_seen_t := -1.0
var _fight_x := 0.0
var _fight_stuck := 0.0


func _pf(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func p() -> Player:
	return main.player


func lv() -> Level:
	return main.level


func note(kind: String, text := "") -> void:
	var key := "%s|%s" % [kind, text]
	if _seen.has(key):
		return
	_seen[key] = true
	anomalies.append("%s @%s %s" % [kind, lv().id if lv() else "?", text])
	print("ANOMALY %s @%s x=%.0f t=%.1f %s" % [kind, lv().id if lv() else "?", p().global_position.x, _level_t, text])


func say(text: String) -> void:
	log_lines.append(text)
	print("WALK " + text)


func _release_all() -> void:
	for a in ["move_left", "move_right", "jump", "crouch"]:
		if Input.is_action_pressed(a):
			Input.action_release(a)


func run() -> void:
	Game.save = Game.default_save()
	Game.session_flags.clear()
	Game.save.skip_intro_seen = ["departure", "route"]
	var step := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--from="):
			step = maxi(0, ORDER.find(a.substr(7)))
	main._load_level(ORDER[step], "start")
	await _pf(3)
	while step < ORDER.size():
		var id: String = ORDER[step]
		if lv().id != id:
			note("wrong-level", "expected %s got %s" % [id, lv().id])
			break
		say("--- %s (%s) start x=%.0f hp=%d" % [id, lv().data.get("name", ""), p().global_position.x, p().hp])
		var ok := await _play_level(id)
		if not ok:
			note("level-timeout", "did not reach the exit of %s in %.0fs" % [id, MAX_LEVEL_TIME])
			break
		step += 1
		if step == ORDER.size():
			break
		# wait for the travel fade to land in the next level
		var waited := 0
		while lv().id == id and waited < 240:
			await _pf(1)
			waited += 1
		await _pf(6)
	say("=== done: deaths=%d anomalies=%d" % [deaths, anomalies.size()])


## Returns true once the level's exit door was used.
func _play_level(id: String) -> bool:
	_level_t = 0.0
	_stuck_t = 0.0
	_escalate = 0
	_died_here = false
	_last_x = p().global_position.x
	_best_x = _last_x
	_mark_x = _last_x
	_boss_seen_t = -1.0
	var frames := 0
	var level_node := lv()
	while _level_t < MAX_LEVEL_TIME:
		if lv() != level_node:
			# the level changed under us (respawn reload or travel): if it is the same id keep playing, else done
			level_node = lv()
			if level_node.id != id:
				return true
		if Juice.frozen():
			await _pf(1)
			continue
		_level_t += 1.0 / 120.0
		frames += 1
		_invariants(id)
		if p().dead:
			_release_all()
			deaths += 1
			say("died in %s at x=%.0f (hp snapshot restores)" % [id, p().global_position.x])
			var w := 0
			while (p().dead or main._fade_t >= 0.0) and w < 600:
				await _pf(1)
				w += 1
			await _pf(4)
			if lv().id != id:
				say("respawned into %s" % lv().id)
				return lv().id != id and ORDER.find(lv().id) > ORDER.find(id)
			continue
		if Game.paused:
			var pm := get_tree().get_first_node_in_group("palm_menu")
			if pm and pm.visible:
				pm.close()
			await _pf(1)
			continue
		# one scripted death per field map after passing its middle: exercises checkpoint + respawn
		if id.begins_with("f") and not _died_here and p().global_position.x > lv().width * 0.62:
			_died_here = true
			say("scripted death at x=%.0f" % p().global_position.x)
			p()._take_damage(999)
			await _pf(2)
			continue
		if await _use_interactables(id):
			return true
		var e := _enemy_in_reach()
		if e != null:
			await _fight(e)
			_stuck_t = 0.0
		else:
			await _advance()
		await _pf(1)
	_release_all()
	return false


func _use_interactables(id: String) -> bool:
	for it in get_tree().get_nodes_in_group("interactable"):
		if not it.near or not it.available():
			continue
		var cls := String(it.get_script().resource_path.get_file())
		match cls:
			"door.gd":
				var to := String(it.target_level)
				say("door → %s" % to)
				_release_all()
				it.try_use()
				return true
			"manual_pickup.gd", "rescue.gd", "pickup.gd":
				say("use %s" % cls)
				it.try_use()
			"checkpoint.gd":
				pass
	# a door that is near but not available: tell why
	for it in get_tree().get_nodes_in_group("interactable"):
		if it.near and String(it.get_script().resource_path.get_file()) == "door.gd" and not it.available():
			note("door-locked", "%s needs %s" % [it.target_level, it.requires])
	return false


func _enemy_in_reach() -> Node:
	var best: Node = null
	var bd := 900.0 if lv()._walls.size() > 0 else 120.0
	for d in get_tree().get_nodes_in_group("enemy"):
		if d.get("status") == null or not d.status.alive():
			continue
		if d.has_method("invulnerable") and d.invulnerable():
			continue
		if d.get("active") != null and not d.active:
			continue
		if d.get("respawn") != null or d.get("drill") == true:   # training dummies respawn, the drill master never dies
			continue
		var dx: float = d.global_position.x - p().global_position.x
		var dy: float = absf(d.global_position.y - p().global_position.y)
		if absf(dx) < bd and dy < 70.0:
			bd = absf(dx)
			best = d
	return best


func _projectile_incoming() -> bool:
	var pl := p()
	for pr in get_tree().get_nodes_in_group("projectile"):
		var to: Vector2 = pl.global_position + Vector2(0, -24) - pr.global_position
		if to.length() < 70.0 and to.normalized().dot(pr.velocity.normalized()) > 0.6:
			return true
	return false


func _fight(e: Node) -> void:
	var pl := p()
	if e.status.is_boss:
		if _boss_seen_t < 0.0:
			_boss_seen_t = _level_t
			if not main.boss_hud.visible:
				note("boss-no-bar", "boss active but the boss bar is hidden")
		if _level_t - _boss_seen_t > 2.0:
			say("cheat-kill boss %s" % String(e.get("boss_name")))
			e.status.hp = 1.0
			e.on_hit({"hp_damage": 1, "burst": 0, "killed": true}, 1.0, 0.0)
			e.status.hp = 0.0
			e.on_hit({"hp_damage": 0, "burst": 0, "killed": true}, 1.0, 0.0)
			return
	_release_all()
	var dir := signf(e.global_position.x - pl.global_position.x)
	if dir == 0.0:
		dir = 1.0
	pl.aim = Vector2(dir, 0)
	pl.facing = dir
	# telegraphed strike coming: parry it
	var telegraph := false
	if e.get("pattern") is String and String(e.pattern) != "" and e.get("attack_time") != null:
		telegraph = float(e.attack_time) < 0.45
	if _projectile_incoming() and pl.action() == Player.Action.FREE:
		var nearest := _nearest_projectile()
		pl.press_parry(signf(nearest.x - pl.global_position.x) if nearest.x != pl.global_position.x else dir)
		return
	if telegraph and pl.action() == Player.Action.FREE:
		pl.press_parry(dir)
		return
	_attack_t += 1.0 / 120.0
	if _attack_t >= 0.22:
		_attack_t = 0.0
		if absf(e.global_position.x - pl.global_position.x) > 64.0 or absf(e.global_position.y - pl.global_position.y) > 40.0:
			Input.action_press("move_right" if dir > 0.0 else "move_left")
			if absf(pl.global_position.x - _fight_x) < 2.0 or e.global_position.y < pl.global_position.y - 40.0:
				_fight_stuck += 0.22
				if _fight_stuck > 0.4:   # blocked by cover or the enemy stands higher: hop
					_fight_stuck = 0.0
					Input.action_press("jump")
					await _pf(30)
					Input.action_release("jump")
					await _pf(2)
					Input.action_press("jump")
					await _pf(30)
					Input.action_release("jump")
			else:
				_fight_stuck = 0.0
			_fight_x = pl.global_position.x
		else:
			pl.press_attack()


func _nearest_projectile() -> Vector2:
	var best := Vector2.INF
	var bd := INF
	for pr in get_tree().get_nodes_in_group("projectile"):
		var d: float = pr.global_position.distance_to(p().global_position)
		if d < bd:
			bd = d
			best = pr.global_position
	return best


func _advance() -> void:
	var pl := p()
	if _projectile_incoming() and pl.action() == Player.Action.FREE:
		var nearest := _nearest_projectile()
		pl.press_parry(signf(nearest.x - pl.global_position.x) if nearest.x != pl.global_position.x else 1.0)
	Input.action_press("move_right")
	if Input.is_action_pressed("move_left"):
		Input.action_release("move_left")
	pl.aim = Vector2(1, -0.2).normalized()
	var x := pl.global_position.x
	if x > _best_x + 2.0:
		_best_x = x
		_stuck_t = 0.0
		if x > _mark_x + 60.0:   # real progress past the obstacle: start the ladder over
			_mark_x = x
			_escalate = 0
	else:
		_stuck_t += 1.0 / 120.0
	if _stuck_t > 0.45:
		_stuck_t = 0.0
		_escalate += 1
		say("stuck at x=%.0f → try %d" % [x, _escalate])
		await _try_move(_escalate)


## Escalating ways past an obstacle: jump; jump + air jump; jump + air jump + up-forward dash; ground dash.
func _try_move(level: int) -> void:
	var pl := p()
	match level % 5:
		1:
			Input.action_press("jump")
			await _pf(30)
			Input.action_release("jump")
		2:
			Input.action_press("jump")
			await _pf(36)
			Input.action_release("jump")
			await _pf(3)
			Input.action_press("jump")
			await _pf(40)
			Input.action_release("jump")
		3:
			Input.action_press("jump")
			await _pf(36)
			Input.action_release("jump")
			await _pf(3)
			Input.action_press("jump")
			await _pf(26)
			Input.action_release("jump")
			pl.press_dash(Vector2(0.45, -1).normalized())
			await _pf(40)
		4:
			pl.press_dash(Vector2(1, 0))
			await _pf(30)
		0:
			# back off and run at it
			Input.action_release("move_right")
			Input.action_press("move_left")
			await _pf(50)
			Input.action_release("move_left")
			Input.action_press("move_right")
			await _pf(20)
			Input.action_press("jump")
			await _pf(36)
			Input.action_release("jump")
			await _pf(3)
			Input.action_press("jump")
			await _pf(20)
			Input.action_release("jump")
			pl.press_dash(Vector2(1, -0.6).normalized())
			await _pf(40)


func _invariants(id: String) -> void:
	var pl := p()
	var l := lv()
	if pl.global_position.y > l.ground_y + 150.0:
		note("below-floor", "y=%.0f" % pl.global_position.y)
	if pl.global_position.x < -60.0 or pl.global_position.x > l.width + 60.0:
		note("outside-level", "x=%.0f" % pl.global_position.x)
	if l._enemy_count < 0:
		note("negative-enemy-count", str(l._enemy_count))
	if l._walls.size() > 0 and l._enemy_count == 0 and not l.active_room.is_empty():
		note("walls-with-no-enemies", "room %s" % l.active_room.get("id", ""))
	if main.boss_hud.visible and (main.boss_hud.boss == null or not is_instance_valid(main.boss_hud.boss)):
		note("boss-bar-without-boss")
	if Dialogue.queue.size() > 8:
		note("dialogue-flood", "%d queued" % Dialogue.queue.size())
	for d in get_tree().get_nodes_in_group("enemy"):
		if d.get("status") == null or not d.status.alive():
			continue
		if d.get("room_x0") != null and d.get("active") == true and not d.status.is_boss:
			if d.global_position.x < float(d.room_x0) - 200.0 or d.global_position.x > float(d.room_x1) + 200.0:
				note("enemy-far-from-room", "%s room %.0f-%.0f" % [d.get_script().resource_path.get_file(), d.room_x0, d.room_x1])
		if d.get("aim_dir") != null and d.get("state") != null and d.get("locked") != null:
			if int(d.state) == 1 and absf(d.global_position.x - pl.global_position.x) > 480.0:
				note("archer-aims-from-afar", "dx=%.0f" % absf(d.global_position.x - pl.global_position.x))
		if d.get("pattern_time") != null and d.get("state") != null and d.status.is_boss:
			if int(d.state) == 2 and float(d.pattern_time) > 6.0:
				note("boss-pattern-stuck", "%s %.1fs" % [d.get("pattern_id"), d.pattern_time])
	if pl.global_position.y > l.ground_y + 0.5 and pl.is_on_floor():
		note("player-sunk-in-floor", "y=%.1f" % pl.global_position.y)
