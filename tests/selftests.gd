extends Node
## Headless acceptance tests (`-- --test=all`). Each suite drives the live scene with physics ticks and
## prints PASS/FAIL lines; the process exits 1 on any failure. Saving is disabled so runs never touch
## the player's real save file.

var suite := "all"
var fails: Array = []
var main: Node2D


func _ready() -> void:
	main = get_parent()
	Game.save_enabled = false
	Game.save = Game.default_save()
	Game.session_flags.clear()
	_run()


func _check(ok: bool, name: String, info: String = "") -> void:
	print("%s %s %s" % ["PASS" if ok else "FAIL", name, info])
	if not ok:
		fails.append(name)


func _pf(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _player() -> Player:
	return main.player


func _run() -> void:
	await _pf(5)
	if suite == "qa":
		await _qa()
		return
	if suite == "deathprobe":
		await _goto("f2")
		var p := _player()
		Game.reach_checkpoint("f2", "mid")
		p.global_position = Vector2(2118, 300)
		await _pf(int(0.5 * 120))
		p._take_damage(999)
		for i in 14:
			await _pf(60)
			print("probe t=%.1f dead=%s x=%.0f hp=%d death_t=%.2f fade_t=%.2f level=%s" % [i * 0.5, p.dead, p.global_position.x, p.hp, main._death_t, main._fade_t, main.level.id])
		get_tree().quit(0)
		return
	if suite == "fxleak":
		await _goto("t0")
		var p := _player()
		p.global_position = Vector2(1800, 300)
		await _pf(2)
		for style in PalmStyles.ids():
			Game.save.palms.unlocked = PalmStyles.ids().duplicate()
			Game.save.palms.equipped = style
			p.style_id = style
			p.on_palm_changed()
			for d in get_tree().get_nodes_in_group("enemy"):
				if d.has_method("reset_state"):
					d.reset_state()
			p.reset_state(1840)
			p.global_position = Vector2(1840, 300)
			p.qi = 100.0
			p.gauge = 100.0
			await _pf(2)
			for n in 2:
				await _swing(p, 3)
				await _pf(30)
			Juice.clear()
			p.qi = 100.0
			p.aim = Vector2.RIGHT
			p.press_heavy()
			await _pf(90)
			Juice.clear()
			p.press_dash(Vector2(1, 0))
			await _pf(40)
			p.global_position = Vector2(1840, 300)
			p.aim = Vector2.RIGHT
			p.pull_cooldown = 0.0
			p.qi = 100.0
			p.press_pull()
			await _pf(60)
			Juice.clear()
			p.press_parry(1.0)
			await _pf(60)
			p.qi = 100.0
			p.gauge = 100.0
			p.tremor_left = 0.0
			p.ult_cooldown = 0.0
			p.press_ultimate()
			await _pf(int(3.0 * 120))
			Juice.clear()
		await _pf(int(4.0 * 120))
		var left: Array = []
		for n in get_tree().get_root().find_children("*", "", true, false):
			var scr = n.get_script()
			if scr and (scr.resource_path.ends_with("fx.gd") or scr.resource_path.ends_with("ghost.gd")):
				left.append("%s first=%s count=%s loop=%s life=%s parent=%s" % [n.name, n.get("first"), n.get("count"), n.get("loop"), n.get("life"), n.get_parent().name])
		print("FXLEAK frozen=%s left=%d %s" % [Juice.frozen(), left.size(), left])
		get_tree().quit(0)
		return
	if suite == "clickprobe":
		await _goto("f1")
		var pm = main.pause_menu
		pm.open()
		await _pf(3)
		print("probe rect=%s palm=%s visible=%s" % [pm.get_global_rect(), main.palm_menu.get_global_rect(), pm.visible])
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		ev.position = get_viewport().get_final_transform() * Vector2(400, 314)   # window space: the viewport maps it back
		ev.global_position = ev.position
		get_viewport().push_input(ev)
		await _pf(3)
		print("probe after click page=%s selected=%d" % [pm.page, pm.selected])
		get_tree().quit(0)
		return
	if suite == "drillprobe":
		await _goto("t0")
		var p := _player()
		p.global_position = Vector2(2400, 300)
		await _pf(int(1.5 * 120))
		var m: Node = main.level._spawned["parry_drill"][0]
		var hits := 0
		var last_hp: float = m.status.hp
		for i in 30:
			var dx: float = m.global_position.x - p.global_position.x
			if absf(dx) > 60.0:
				p.global_position.x = m.global_position.x - signf(dx) * 50.0
			p.aim = Vector2(signf(dx), 0)
			Juice.clear()
			p.press_attack()
			await _pf(40)
			if m.status.hp < last_hp:
				hits += 1
			last_hp = m.status.hp
			print("drill i=%d state=%s pattern=%s hp=%.0f hits=%d px=%.0f mx=%.0f cands=%s cd=%s pending=%s recent=%s" % [i, m.state, m.get("pattern_id"), m.status.hp, hits, p.global_position.x, m.global_position.x, m._candidates(), m.cooldowns, m._pending_first, m.get("recent")])
		get_tree().quit(0)
		return
	if suite == "innprobe":
		Game.save = Game.default_save()
		await _goto("b1")
		var p := _player()
		p.global_position = Vector2(320, 300)
		await _pf(4)
		var boss = main.level._spawned["arena"][0]
		boss._cancel_pattern()
		boss.state = boss.State.IDLE
		boss.status.hp = 3.0
		boss.global_position = Vector2(380, 300)
		p.global_position = Vector2(330, 300)
		p.aim = Vector2.RIGHT
		Juice.clear()
		p.press_attack()
		await _pf(60)
		print("probe boss hp=%.0f alive=%s beaten=%s flag=%s walls=%d count=%d" % [boss.status.hp, boss.status.alive(), boss.beaten, Game.flag("b1_tianel_beaten"), main.level._walls.size(), main.level._enemy_count])
		p.global_position = Vector2(760, 300)
		await _pf(6)
		var used := false
		for it in get_tree().get_nodes_in_group("interactable"):
			if it.try_use():
				used = true
		await _pf(int(0.8 * 120))
		print("probe door used=%s level=%s px=%.0f fade=%.2f" % [used, main.level.id, p.global_position.x, main._fade_t])
		get_tree().quit(0)
		return
	if suite == "returnprobe":
		Game.save = Game.default_save()
		Game.session_flags.clear()
		await _goto("f1")
		var p := _player()
		Game.reach_checkpoint("f1", "before_boss")
		Game.travel("b1", "start")
		await _pf(int(0.8 * 120))
		p.global_position = Vector2(320, 300)
		await _pf(4)
		var boss = main.level._spawned["arena"][0]
		boss._cancel_pattern()
		boss.state = boss.State.IDLE
		boss.status.hp = 3.0
		boss.global_position = Vector2(380, 300)
		p.global_position = Vector2(330, 300)
		p.aim = Vector2.RIGHT
		Juice.clear()
		p.press_attack()
		await _pf(60)
		print("probe after kill: flag=%s cleared=%s" % [Game.flag("b1_tianel_beaten"), Game.flag("cleared:b1:arena")])
		Game.respawn()
		await _pf(int(0.8 * 120))
		print("probe respawned: level=%s px=%.0f" % [main.level.id, p.global_position.x])
		p.global_position = Vector2(3340, 300)
		await _pf(6)
		var used := false
		for it in get_tree().get_nodes_in_group("interactable"):
			if it.try_use():
				used = true
		await _pf(int(0.8 * 120))
		print("probe f1 door used=%s level=%s enemies=%s walls=%d count=%d" % [used, main.level.id, main.level._spawned.keys(), main.level._walls.size(), main.level._enemy_count])
		p.global_position = Vector2(320, 300)
		await _pf(6)
		print("probe b1 again: spawned=%s walls=%d hud=%s" % [main.level._spawned.keys(), main.level._walls.size(), main.boss_hud.visible])
		p.global_position = Vector2(760, 300)
		await _pf(6)
		used = false
		for it in get_tree().get_nodes_in_group("interactable"):
			if it.try_use():
				used = true
		await _pf(int(0.8 * 120))
		print("probe inn door used=%s level=%s" % [used, main.level.id])
		get_tree().quit(0)
		return
	if suite == "doorprobe":
		Game.save = Game.default_save()
		await _goto("f1", "from_b1")
		var p := _player()
		await _pf(2)
		Input.action_press("move_right")
		await _pf(84)
		Input.action_release("move_right")
		Input.action_press("move_left")
		await _pf(19)
		Input.action_release("move_left")
		await _pf(10)
		var door: Node = null
		for it in get_tree().get_nodes_in_group("interactable"):
			if String(it.get_script().resource_path.get_file()) == "door.gd":
				door = it
		print("probe px=%.0f door x=%.0f near=%s avail=%s label=%s" % [p.global_position.x, door.global_position.x, door.near, door.available(), door.label])
		Input.action_press("interact")
		Input.action_press("jump")
		await _pf(2)
		Input.action_release("interact")
		Input.action_release("jump")
		await _pf(int(0.9 * 120))
		print("probe after W: level=%s fade=%.2f" % [main.level.id, main._fade_t])
		get_tree().quit(0)
		return
	if suite == "walk":
		var bot := Node.new()
		bot.set_script(preload("res://tests/walk_bot.gd"))
		bot.main = main
		add_child(bot)
		await bot.run()
		print("WALK anomalies %d %s" % [bot.anomalies.size(), bot.anomalies])
		get_tree().quit(0)
		return
	if suite in ["all", "palm"]:
		await _palm()
	if suite in ["all", "save"]:
		await _save()
	if suite in ["all", "projectile"]:
		await _projectile()
	if suite in ["all", "room"]:
		await _room()
	if suite in ["all", "checkpoint"]:
		await _checkpoint()
	if suite in ["all", "tianel"]:
		await _tianel()
	if suite in ["all", "pull"]:
		await _pull()
	if suite in ["all", "tutorial"]:
		await _tutorial()
	if suite in ["all", "menu"]:
		await _menu()
	if suite in ["all", "ledge"]:
		await _ledge()
	if suite in ["all", "minions"]:
		await _minions()
	if suite in ["all", "mireille"]:
		await _mireille()
	if suite in ["all", "elodie"]:
		await _elodie()
	print("SELFTEST %d failures %s" % [fails.size(), fails])
	get_tree().quit(0 if fails.is_empty() else 1)


func _goto(level_id: String, spawn := "start") -> void:
	main._load_level(level_id, spawn)
	await _pf(3)


## A fresh dummy next to the player for hit tests.
func _dummy(dx: float) -> Node2D:
	var d := Node2D.new()
	d.set_script(preload("res://src/enemies/dummy.gd"))
	d.position = _player().global_position + Vector2(dx, 0)
	main.level.add_child(d)
	await _pf(1)
	return d


func _swing(p: Player, n: int) -> void:
	for i in n:
		Juice.clear()
		p.aim = Vector2.RIGHT
		p.press_attack()
		await _pf(26)
		Juice.clear()
		await _pf(8)


# ---------- 장법 ----------

func _palm() -> void:
	await _goto("t0")
	var p := _player()
	Juice.clear()
	# unknown / unowned ids are refused; 흑월장 is always owned
	_check(not Game.equip_palm("nonsense") and Game.equipped_palm() == "black_moon", "palm: unknown id rejected")
	# equipping needs a rest point
	Game.save.palms.unlocked.append("formation_breaker")
	Game.at_rest_point = false
	_check(not Game.equip_palm("formation_breaker"), "palm: no equip away from a rest point")
	Game.at_rest_point = true
	p.reset_state(1660)
	p.global_position = Vector2(1660, 300)
	await _pf(2)
	var qi0 := p.qi
	p.rift = 40.0
	_check(Game.equip_palm("formation_breaker") and p.style_id == "formation_breaker" and p.qi == qi0 and p.rift == 40.0, "palm: equip at rest keeps resources", "qi=%.0f rift=%.0f" % [p.qi, p.rift])
	# the first strike of the new style still gets the counter (semantic combo_index, not identity)
	p.counter_left = 1.0
	p.aim = Vector2.RIGHT
	p.press_attack()
	_check(p.counter_armed and int(p.swing.combo_index) == 0, "palm: counter on the first strike of any style")
	await _pf(90)   # let the combo window close so both measurements are first strikes
	# 쇄진장 lunges farther than 흑월장
	var d := await _dummy(300.0)
	var x0 := p.global_position.x
	p.aim = Vector2.RIGHT
	p.press_attack()
	await _pf(14)
	var lunge_fb := p.global_position.x - x0
	await _pf(90)
	Game.at_rest_point = true
	Game.equip_palm("black_moon")
	await _pf(2)
	x0 = p.global_position.x
	p.press_attack()
	await _pf(14)
	var lunge_bm := p.global_position.x - x0
	_check(lunge_fb > lunge_bm + 8.0, "palm: 쇄진장 first strike reaches farther", "fb=%.0f bm=%.0f" % [lunge_fb, lunge_bm])
	await _pf(40)
	# 투골장: injury 2 on the second strike, capped at 3 overall; heavy consumes once
	Game.save.palms.unlocked.append("bone_piercing")
	Game.at_rest_point = true
	Game.equip_palm("bone_piercing")
	await _pf(40)
	await _pf(2)
	d.global_position = p.global_position + Vector2(40, 0)
	d.reset_state()
	await _pf(90)
	p.press_attack()
	await _pf(26)
	p.press_attack()
	await _pf(26)
	var inj_after_two: int = d.status.injury
	d.global_position = p.global_position + Vector2(30, 0)   # the lunges may have carried the player past it; 침장 never hits behind
	Juice.clear()   # headless hitstops are wall-clock: never let one swallow the next press
	await _pf(12)
	p.press_attack()
	await _pf(60)   # 침장 winds up 0.26 s
	var inj_after_three: int = d.status.injury
	_check(inj_after_two == 3 and inj_after_three == 0, "palm: 투골장 injury 1+2 caps at 3, third strike bursts once", "after2=%d after3=%d" % [inj_after_two, inj_after_three])
	# 회란장 multi-hit: two dummies, one gauge grant per attack
	await _pf(60)
	Game.save.palms.unlocked.append("returning_tide")
	Game.at_rest_point = true
	Game.equip_palm("returning_tide")
	await _pf(40)
	await _pf(2)
	var d2 := await _dummy(-40.0)
	d.global_position = p.global_position + Vector2(40, 0)
	d.reset_state()
	d2.reset_state()
	p.gauge = 0.0
	p.press_attack()
	await _pf(26)
	p.press_attack()   # 환장: 360°
	await _pf(26)
	_check(d.status.hp < d.status.max_hp and d2.status.hp < d2.status.max_hp and p.gauge <= CombatConfig.GAUGE_PER_ATTACK * 2.0, "palm: 회란장 hits both sides, gauge once per attack", "gauge=%.0f" % p.gauge)
	d.queue_free()
	d2.queue_free()
	Game.equip_palm("black_moon")
	Game.at_rest_point = false


# ---------- save ----------

func _save() -> void:
	Game.save = Game.default_save()
	Game.session_flags.clear()
	var ok := Game.collect_manual("f1_outpost_manual")
	var twice := Game.collect_manual("f1_outpost_manual")
	_check(ok and not twice and Game.unlocked_palms().has("formation_breaker"), "save: manual once, unlocks its style")
	Game.set_flag("cleared:f1:r1", false)
	Game.set_flag("b1_tianel_beaten", true)
	Game.session_flags.clear()   # death discards session clears
	_check(not Game.flag("cleared:f1:r1") and Game.flag("b1_tianel_beaten"), "save: session clears die with the player, permanent flags stay")
	# validation: an unowned equipped id falls back
	Game.save.palms.equipped = "bone_piercing"
	Game._validate_palms()
	_check(Game.equipped_palm() == "black_moon", "save: unowned equipped style falls back to 흑월장")
	Game.save.palms.unlocked = ["garbage"]
	Game._validate_palms()
	_check(Game.unlocked_palms() == ["black_moon"], "save: unknown style ids dropped")
	Game.save = Game.default_save()


# ---------- projectile parry ----------

func _projectile() -> void:
	await _goto("t0")
	var p := _player()
	Juice.clear()
	p.reset_state(2000)
	p.global_position = Vector2(2000, 300)
	await _pf(2)
	var hp0 := p.hp
	var shooter := Node2D.new()
	shooter.set_script(preload("res://src/enemies/scout_archer.gd"))
	shooter.position = Vector2(2200, 300)
	main.level.add_child(shooter)
	await _pf(1)
	shooter.activate(p)
	shooter.state = shooter.S.RECOVER   # never shoots on its own during the test
	shooter.state_time = -99.0
	# arrow from the right, perfect parry → no damage, destroyed, posture +25 on the shooter
	var arrow := _arrow(shooter, Vector2(2080, 276), Vector2(-440, 0))
	await _pf(8)
	p.press_parry(1.0)
	await _pf(14)
	var perfect_ok: bool = p.hp == hp0 and not is_instance_valid(arrow) and shooter.status.posture == 25.0
	_check(perfect_ok, "projectile: perfect parry destroys the arrow and adds posture", "hp=%d posture=%.0f" % [p.hp, shooter.status.posture])
	# no parry → damage, arrow consumed
	await _pf(30)
	p.reset_state(2000)
	p.global_position = Vector2(2000, 300)
	await _pf(2)
	var arrow2 := _arrow(shooter, Vector2(2080, 276), Vector2(-440, 0))
	await _pf(30)
	_check(p.hp == 100 - 12 and not is_instance_valid(arrow2), "projectile: unparried arrow deals 12 and is consumed", "hp=%d" % p.hp)
	# dash i-frames: it passes through
	await _pf(30)
	p.reset_state(2000)
	p.global_position = Vector2(2000, 300)
	await _pf(2)
	var arrow3 := _arrow(shooter, Vector2(2060, 276), Vector2(-440, 0))
	await _pf(6)
	p.press_dash(Vector2(1, 0))
	await _pf(10)
	_check(p.hp == 100, "projectile: dash i-frames pass the arrow", "hp=%d" % p.hp)
	# archers do not start a shot off-camera
	await _pf(40)
	shooter.global_position = Vector2(200, 300)
	shooter.state = shooter.S.IDLE
	shooter.state_time = 0.0
	await _pf(80)
	_check(shooter.state == shooter.S.IDLE and shooter.shots == 0, "projectile: archer never aims off-camera", "state=%d shots=%d" % [shooter.state, shooter.shots])
	shooter.queue_free()


func _arrow(shooter: Node, at: Vector2, vel: Vector2) -> Node:
	var a := Node2D.new()
	a.set_script(preload("res://src/enemies/projectile.gd"))
	a.position = at
	a.velocity = vel
	a.shooter = shooter
	var hit := HitEvent.new()
	hit.attacker = shooter
	shooter.instance += 1
	hit.instance_id = shooter.instance
	hit.hit_id = 1
	hit.raw_direct = 12.0
	hit.knockback = 120.0
	hit.parry_class = CombatConfig.ParryClass.NORMAL
	hit.posture_damage = CombatConfig.POSTURE_NORMAL
	hit.label = "test arrow"
	a.hit = hit
	main.level.add_child(a)
	return a


# ---------- rooms ----------

func _room() -> void:
	Game.save = Game.default_save()
	Game.session_flags.clear()
	await _goto("f1")
	var p := _player()
	Juice.clear()
	var lv: Level = main.level
	var placed: Array = lv._spawned.get("r1", [])
	_check(placed.size() == 2 and not placed[0].active and lv._walls.is_empty(), "room: soldiers stand in place before entry, asleep, no walls", "n=%d" % placed.size())
	p.global_position = Vector2(300, 300)
	await _pf(4)
	var locked: bool = lv.active_room.get("id", "") == "r1" and lv._walls.size() == 2 and lv._enemy_count == 2
	_check(locked, "room: entering r1 spawns 2 soldiers and walls both ends", "walls=%d enemies=%d" % [lv._walls.size(), lv._enemy_count])
	# the player cannot leave through the wall
	p.global_position = Vector2(740, 300)
	Input.action_press("move_right")
	await _pf(40)
	Input.action_release("move_right")
	_check(p.global_position.x < 775.0, "room: locked wall holds the player", "x=%.0f" % p.global_position.x)
	# killing both clears and unlocks (session flag)
	for e in lv._spawned["r1"]:
		e.status.hp = 1.0
		e.on_hit({"hp_damage": 1, "burst": 0, "killed": true}, 1.0, 0.0)
		e.status.hp = 0.0
		e.on_hit({"hp_damage": 0, "burst": 0, "killed": true}, 1.0, 0.0)
	await _pf(2)
	_check(lv._walls.is_empty() and Game.flag("cleared:f1:r1") and not Game.save.flags.has("cleared:f1:r1"), "room: clear opens the walls as a session flag")
	# reloading after a checkpoint keeps the clear; without one it is gone
	Game.reach_checkpoint("f1", "entry")
	await _goto("f1")
	p.global_position = Vector2(300, 300)
	await _pf(4)
	_check(main.level._enemy_count == 0, "room: cleared room stays clear after the checkpoint")


# ---------- checkpoint / respawn ----------

func _checkpoint() -> void:
	Game.save = Game.default_save()
	Game.session_flags.clear()
	await _goto("f1")
	var p := _player()
	Game.reach_checkpoint("f1", "entry")
	Game.collect_manual("f1_outpost_manual")
	Game.set_flag("cleared:f1:r2", false)
	p.qi = 55.0
	p.gauge = 40.0
	p.hp = 1
	p._take_damage(1)
	_check(p.dead, "checkpoint: player dies")
	await _pf(220)   # death delay + fade (1.6 s + 0.3 s)
	for i in 30:
		await get_tree().process_frame
	var back: bool = Game.level_id == "f1" and not p.dead and p.hp == 100
	_check(back, "checkpoint: respawn at the last checkpoint, healed", "level=%s hp=%d" % [Game.level_id, p.hp])
	_check(Game.has_manual("f1_outpost_manual") and not Game.flag("cleared:f1:r2"), "checkpoint: manual kept, later room clear reset")
	_check(absf(p.qi - CombatConfig.QI_MAX) < 1.0 and p.gauge == 0.0, "checkpoint: resources restored from the first-arrival snapshot", "qi=%.0f gauge=%.0f" % [p.qi, p.gauge])


# ---------- tianel ----------

func _tianel() -> void:
	Game.save = Game.default_save()
	Game.session_flags.clear()
	await _goto("b1")
	var p := _player()
	Juice.clear()
	p.global_position = Vector2(300, 300)
	await _pf(4)
	var lv: Level = main.level
	var boss = lv._spawned["arena"][0]
	_check(boss != null and main.boss_hud.visible, "tianel: spawns on entering the arena with a boss bar")
	boss.rng.seed = 3
	boss.state = boss.State.IDLE
	boss.state_time = 10.0
	# every base pattern gets introduced before any variation; a move is never followed by a move
	var moves_in_a_row := 0
	var prev_move := false
	var variation_early := false
	for i in 10:
		boss.state = boss.State.IDLE
		boss.state_time = 10.0
		boss._chain_next = ""
		boss.global_position = Vector2(560, 300)
		p.global_position = Vector2(400, 300)
		await _pf(2)
		if boss.state == boss.State.PATTERN:
			var is_move: bool = bool(boss.pattern.get("move", false))
			if is_move and prev_move:
				moves_in_a_row += 1
			prev_move = is_move
			if boss.pattern.has("variant_of") and boss.seen.size() < 4:
				variation_early = true
			boss._cancel_pattern()
			boss.cooldowns.clear()
	_check(moves_in_a_row == 0 and not variation_early, "tianel: no two repositions in a row, no early variation", str(boss.log_lines))
	# late set: root_ripple chains into wind_shot without a decision wait
	boss.status.hp = boss.max_hp * 0.5
	boss.on_hit({"hp_damage": 1, "burst": 0, "killed": false}, 1.0, 0.0)
	_check(boss.late, "tianel: late set at 60%")
	boss._cancel_pattern()
	boss.cooldowns.clear()
	boss.state = boss.State.IDLE
	boss._start_pattern("root_ripple")
	var n := 0
	while boss.state == boss.State.PATTERN and n < 400:
		await _pf(1)
		n += 1
	await _pf(2)
	_check(boss.pattern_id == "wind_shot" and boss.state == boss.State.PATTERN, "tianel: 뿌리의 파문 chains straight into 바람 한 발 when late", boss.pattern_id)
	# the root wave is unparryable and travels: a parry still takes 16
	boss._chain_next = ""
	boss._cancel_pattern()
	p.reset_state(300)
	p.global_position = Vector2(300, 300)
	boss.global_position = Vector2(560, 300)
	boss.state = boss.State.IDLE
	boss._start_pattern("root_ripple")
	await _pf(int(0.6 * 120))
	p.press_parry(1.0)
	await _pf(int(1.2 * 120))
	_check(p.hp == 68, "tianel: both root waves ignore the parry (16 + 16)", "hp=%d" % p.hp)
	# a perfect parry on an arrow adds posture; four of them stagger her
	boss._cancel_pattern()
	boss.status.posture = 75.0
	boss.status.posture_last_add = boss.status.time
	p.reset_state(500)
	p.global_position = Vector2(500, 300)   # inside the cover line: 60px of flight ≈ 0.11 s
	boss.global_position = Vector2(560, 300)
	boss.state = boss.State.IDLE
	boss._start_pattern("wind_shot")
	await _pf(int(0.47 * 120))   # first arrow leaves at 0.45, 60px at 700px/s → arrives ≈ 0.54
	p.press_parry(1.0)
	await _pf(24)
	_check(boss.state == boss.State.STAGGER and p.hp == 100, "tianel: perfect-parried arrow staggers at posture 100", "state=%d hp=%d posture=%.0f" % [boss.state, p.hp, boss.status.posture])
	# defeat opens the door flag
	boss.status.hp = 1.0
	boss.on_hit({"hp_damage": 1, "burst": 0, "killed": true}, 1.0, 0.0)
	boss.status.hp = 0.0
	boss.on_hit({"hp_damage": 0, "burst": 0, "killed": true}, 1.0, 0.0)
	await _pf(2)
	_check(Game.flag("b1_tianel_beaten") and boss.beaten, "tianel: defeat sets the permanent flag")


# ---------- 일시정지 메뉴 · 훈련장 ----------

func _menu() -> void:
	Game.save = Game.default_save()
	Game.session_flags.clear()
	await _goto("f1")
	var p := _player()
	Game.reach_checkpoint("f1", "mid")
	Game.set_flag("b1_tianel_beaten")
	var pm = main.pause_menu
	pm.open()
	await _pf(2)
	_check(pm.visible and Game.paused, "menu: Esc menu opens and pauses")
	pm._activate("resume")
	await _pf(2)
	_check(not pm.visible and not Game.paused, "menu: 계속하기 resumes")
	pm.open()
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = get_viewport().get_final_transform() * Vector2(400, 314)
	ev.global_position = ev.position
	get_viewport().push_input(ev)
	await _pf(3)
	_check(pm.page == "confirm", "menu: a mouse click on 처음부터 works while paused", pm.page)
	pm.page = "main"
	pm.close()
	pm.open()
	pm._activate("reset")
	_check(pm.page == "confirm", "menu: 처음부터 asks for confirmation")
	pm._activate("back")
	_check(pm.page == "main" and Game.flag("b1_tianel_beaten"), "menu: 아니요 keeps the progress")
	pm._activate("reset")
	pm._activate("wipe")
	await _pf(int(0.8 * 120))
	_check(not Game.paused and main.level.id == "t0" and not Game.flag("b1_tianel_beaten") and Game.save.checkpoint.level == "t0" and main.cutscene.visible, "menu: 예 wipes the save and restarts at T0 with the card", "level=%s paused=%s flag=%s cp=%s card=%s seen=%s" % [main.level.id, Game.paused, Game.flag("b1_tianel_beaten"), Game.save.checkpoint.level, main.cutscene.visible, Game.save.skip_intro_seen])
	# the parry drill master wakes when its room is entered (regression: crashed on a missing field)
	p.global_position = Vector2(2400, 300)
	await _pf(6)
	var master: Node = null
	for e in main.level._spawned.get("parry_drill", []):
		master = e
	_check(master != null and master.get("_active") == true, "drill: entering the yard's drill room activates 목각교두")
	# it keeps striking however often it is hit: count pattern starts over 12 s while being hit every 0.33 s
	var starts := 0
	var last_state: int = -1
	for i in 36:
		var dx: float = master.global_position.x - p.global_position.x
		if absf(dx) > 60.0:
			p.global_position.x = master.global_position.x - signf(dx) * 50.0
		p.aim = Vector2(signf(dx) if dx != 0.0 else 1.0, 0)
		Juice.clear()
		p.press_attack()
		for k in 40:
			await _pf(1)
			if int(master.state) == 3 and last_state != 3:
				starts += 1
			last_state = int(master.state)
	_check(starts >= 4, "drill: the master keeps striking after many hits (no two-in-a-row stall)", "starts=%d" % starts)
	# W at the rest point opens the palm menu with her still on the floor, so equipping works
	await _goto("f1")
	Game.save.palms.unlocked = ["black_moon", "formation_breaker"]
	p.global_position = Vector2(3050, 300)
	await _pf(4)
	Input.action_press("interact")
	Input.action_press("jump")
	await _pf(1)
	for it in get_tree().get_nodes_in_group("interactable"):
		if it.try_use():
			break
	await _pf(2)
	Input.action_release("interact")
	Input.action_release("jump")
	var can: bool = main.palm_menu.visible and Game.can_equip_now()
	var equipped: bool = Game.equip_palm("formation_breaker")
	_check(can and equipped and Game.equipped_palm() == "formation_breaker", "rest: W opens the palm menu without a hop and equipping works", "menu=%s can=%s" % [main.palm_menu.visible, Game.can_equip_now()])
	main.palm_menu.close()


# ---------- 얇은 발판 · 적 착지 ----------

func _ledge() -> void:
	Game.save = Game.default_save()
	await _goto("t0")
	var p := _player()
	Juice.clear()
	# the landing lip (800,185 120×14) is one-way: a jump from right under it passes up through and lands on top
	p.reset_state(860)
	p.global_position = Vector2(860, 300)
	await _pf(2)
	Input.action_press("jump")
	await _pf(40)
	Input.action_release("jump")
	await _pf(2)
	Input.action_press("jump")
	await _pf(140)
	Input.action_release("jump")
	_check(p.is_on_floor() and absf(p.global_position.y - 185.0) < 1.0, "ledge: jumping from below passes through the lip and lands on it", "y=%.0f" % p.global_position.y)
	# S drops through it
	Input.action_press("crouch")
	await _pf(3)
	Input.action_release("crouch")
	await _pf(60)
	_check(p.global_position.y > 290.0, "ledge: S on a ledge drops through to the floor", "y=%.0f" % p.global_position.y)
	# a down dash drops too; the thick tutorial wall still blocks from below
	p.reset_state(860)
	p.global_position = Vector2(860, 185)
	await _pf(3)
	p.press_dash(Vector2(0, 1))
	await _pf(60)
	var dropped: bool = p.global_position.y > 290.0
	p.reset_state(470)
	p.global_position = Vector2(470, 300)
	await _pf(2)
	Input.action_press("move_right")
	await _pf(60)
	Input.action_release("move_right")
	_check(dropped and p.global_position.x < 560.0, "ledge: a down dash drops through; thick walls stay solid", "x=%.0f" % p.global_position.x)
	# an archer hopping off its log lands on the floor instead of hovering
	await _goto("f1")
	p.global_position = Vector2(1000, 300)
	await _pf(4)
	var archer: Node = main.level._spawned["r2"][0]
	archer.activate(p)
	archer.global_position = Vector2(1120, 236)
	archer.ground_y = 236.0
	p.global_position = Vector2(1180, 236)   # right next to it on the log: it hops away left, off the trunk's end
	await _pf(int(1.2 * 120))
	_check(absf(archer.global_position.y - 300.0) < 1.0 and absf(archer.ground_y - 300.0) < 1.0, "enemy: a hop off the log lands on the floor", "y=%.0f ground=%.0f x=%.0f" % [archer.global_position.y, archer.ground_y, archer.global_position.x])


# ---------- F2 졸개·장치 ----------

func _minions() -> void:
	Game.save = Game.default_save()
	Game.session_flags.clear()
	await _goto("f2")
	var p := _player()
	Juice.clear()
	var lv: Level = main.level
	var shield: Node = null
	for e in lv._spawned.get("r1", []):
		if e.get("guarding") != null:
			shield = e
	_check(shield != null and lv._spawned.get("r2", []).size() == 1, "f2: shield soldier and mage are pre-placed", str(lv._spawned.keys()))
	# the guard halves a front hit (the number shown shrinks too); a rear hit lands in full and breaks it
	shield.activate(p)
	shield.facing = -1.0
	shield.guarding = true
	p.global_position = shield.global_position + Vector2(-60, 0)
	var r := {"hp_damage": 20, "burst": 0, "killed": false}
	shield.status.hp = 110.0   # the resolver already took 20
	shield.on_hit(r, 1.0, 0.0)
	_check(int(shield.status.hp) == 120 and int(r.hp_damage) == 10, "shield: front hit halved through the guard", "hp=%.0f shown=%d" % [shield.status.hp, int(r.hp_damage)])
	p.global_position = shield.global_position + Vector2(60, 0)
	var r2 := {"hp_damage": 20, "burst": 0, "killed": false}
	shield.status.hp = 100.0
	shield.on_hit(r2, 1.0, 0.0)
	_check(int(shield.status.hp) == 100 and shield.broken_left > 0.0, "shield: rear hit lands in full and breaks the guard", "hp=%.0f" % shield.status.hp)
	# an injury burst from the front breaks it as well
	shield.broken_left = 0.0
	shield.guarding = true
	p.global_position = shield.global_position + Vector2(-60, 0)
	var r3 := {"hp_damage": 24, "burst": 3, "killed": false}
	shield.status.hp = 76.0
	shield.on_hit(r3, 1.0, 0.0)
	_check(int(shield.status.hp) == 76 and shield.broken_left > 0.0, "shield: injury burst passes the guard and breaks it")
	# a mage mid-cast is interrupted by any hit
	var mage: Node = lv._spawned["r2"][0]
	mage.activate(p)
	mage.state = mage.S.CAST_BOLT
	mage.state_time = 0.3
	mage.on_hit({"hp_damage": 5, "burst": 0, "killed": false}, 1.0, 0.0)
	_check(mage.state == mage.S.INTERRUPTED, "mage: a hit during the cast interrupts it")
	# the floor rune is fixed where the player stood when the cast began
	p.reset_state(1000)
	p.global_position = Vector2(1000, 300)
	mage.global_position = Vector2(1180, 300)
	mage.state = mage.S.IDLE
	mage.state_time = 0.0
	mage.casts = 1   # next cast is the ground rune
	mage.can_retreat = false
	await _pf(int(0.5 * 120))
	var cast_started: bool = mage.state == mage.S.CAST_GROUND
	var zone_x: float = mage.zone.get_center().x
	p.global_position = Vector2(880, 300)
	await _pf(int(1.2 * 120))
	_check(cast_started and absf(zone_x - 1000.0) < 2.0 and p.hp == 100, "mage: ground rune locks to the start position and misses a player who moved", "state=%d zone=%.0f hp=%d" % [mage.state, zone_x, p.hp])
	# a purify zone flags the player while inside and fades 0.5 s after leaving
	var z := Node2D.new()
	z.set_script(preload("res://src/world/purify_zone.gd"))
	z.position = p.global_position
	lv.add_child(z)
	await _pf(2)
	var inside: bool = p.purified()
	p.global_position += Vector2(300, 0)
	await _pf(int(0.7 * 120))
	_check(inside and not p.purified(), "purify: inside flags the player, gone 0.5 s after leaving", "inside=%s after=%s" % [inside, p.purified()])
	z.queue_free()
	# 격석: standing on a plate when it bursts costs 12, unparryable
	p.reset_state(2180)
	p.global_position = Vector2(2180, 300)
	for h in lv.get_children():
		if h.get("phase") != null and absf(h.position.x - 2180.0) < 1.0:
			h._t = 0.98
	await _pf(8)
	_check(p.hp == 88, "hazard: the plate burst hits 12", "hp=%d" % p.hp)


# ---------- B2 미레유 ----------

func _mireille() -> void:
	Game.save = Game.default_save()
	Game.session_flags.clear()
	await _goto("b2")
	var p := _player()
	Juice.clear()
	p.global_position = Vector2(300, 300)
	await _pf(4)
	var lv: Level = main.level
	var boss = lv._spawned["arena"][0]
	_check(boss != null and main.boss_hud.visible and boss.get("boss_name") == "미레유", "mireille: spawns on entering the arena with a boss bar")
	boss.rng.seed = 5
	boss.state = boss.State.IDLE
	# 좌표 소각 locks the player's position once: stepping out before it fires avoids it
	p.reset_state(300)
	p.global_position = Vector2(300, 300)
	boss.global_position = Vector2(560, 300)
	boss._start_pattern("burn")
	await _pf(int(0.15 * 120))
	var zone: Rect2 = boss._zone_rects.get(1, Rect2())
	p.global_position = Vector2(120, 300)
	await _pf(int(0.8 * 120))
	_check(absf(zone.get_center().x - 300.0) < 2.0 and p.hp == 100, "mireille: 좌표 소각 is saved once and never follows", "zone=%.0f hp=%d" % [zone.get_center().x, p.hp])
	boss._cancel_pattern()
	boss.state = boss.State.IDLE
	p.global_position = Vector2(300, 300)
	boss._start_pattern("burn")
	await _pf(int(0.95 * 120))
	_check(p.hp == 82, "mireille: standing in the saved spot takes 18 (unparryable)", "hp=%d" % p.hp)
	# 세 칸 봉쇄 seals two different lanes; the third stays safe
	boss._cancel_pattern()
	boss.state = boss.State.IDLE
	p.reset_state(400)
	p.global_position = Vector2(400, 300)   # middle lane
	boss.global_position = Vector2(560, 300)
	boss._start_pattern("seal")
	await _pf(int(0.45 * 120))
	var first_lane: int = boss._used_lanes[0] if boss._used_lanes.size() > 0 else -1
	var second_lane: int = boss._used_lanes[1] if boss._used_lanes.size() > 1 else -1
	var safe := 3 - first_lane - second_lane
	p.global_position = Vector2(float(lv.data.lanes[safe][0]) + 133.0, 300)
	await _pf(int(1.0 * 120))
	_check(first_lane == 1 and second_lane != 1 and second_lane >= 0 and p.hp == 100, "mireille: 세 칸 봉쇄 takes the player's lane + one other, the third lane is safe", "lanes=%s hp=%d" % [str(boss._used_lanes), p.hp])
	# 가설 장벽: front hits deal half (bursts pass), then a 0.6 s opening when it drops
	boss._cancel_pattern()
	boss.state = boss.State.IDLE
	boss.global_position = Vector2(560, 300)
	p.global_position = Vector2(400, 300)
	boss._start_pattern("barrier")
	await _pf(int(0.40 * 120))
	var up: bool = boss.barrier_left > 0.0
	boss.status.hp = boss.max_hp - 40.0
	var rb := {"hp_damage": 40, "burst": 0, "killed": false}
	boss.on_hit(rb, 1.0, 0.0)
	var half_ok: bool = int(boss.max_hp - boss.status.hp) == 20 and int(rb.hp_damage) == 20
	var rb2 := {"hp_damage": 40, "burst": 2, "killed": false}
	boss.status.hp -= 40.0
	boss.on_hit(rb2, 1.0, 0.0)
	_check(up and half_ok and int(boss.max_hp - boss.status.hp) == 60, "mireille: 가설 장벽 halves front hits, injury bursts pass", "left=%.1f hp=%.0f" % [boss.barrier_left, boss.status.hp])
	boss.barrier_left = 0.001
	boss._cancel_pattern()
	boss.state = boss.State.IDLE
	boss.state_time = 10.0
	await _pf(4)
	_check(boss.barrier_recover > 0.0 and boss.state == boss.State.IDLE, "mireille: the plate drop leaves 0.6 s with no new pattern", "recover=%.2f state=%d" % [boss.barrier_recover, boss.state])
	# 좌표 이동 puts her in the lane farthest from the player
	boss.barrier_recover = 0.0
	boss.perches = []
	boss.global_position = Vector2(400, 300)
	p.global_position = Vector2(150, 300)
	boss._start_pattern("blink")
	await _pf(int(0.30 * 120))
	_check(boss.global_position.x > 600.0, "mireille: blink lands in the far lane", "x=%.0f" % boss.global_position.x)
	# late: 세 칸 봉쇄 chains into 가설 장벽
	boss._cancel_pattern()
	boss.status.hp = boss.max_hp * 0.5
	boss.on_hit({"hp_damage": 1, "burst": 0, "killed": false}, 1.0, 0.0)
	boss.cooldowns.clear()
	boss.state = boss.State.IDLE
	p.global_position = Vector2(150, 300)
	boss._start_pattern("seal")
	var n := 0
	while boss.state == boss.State.PATTERN and n < 400:
		await _pf(1)
		n += 1
	await _pf(2)
	_check(boss.late and boss.pattern_id == "barrier", "mireille: late 세 칸 봉쇄 chains straight into 가설 장벽", boss.pattern_id)
	boss.status.hp = 1.0
	boss.on_hit({"hp_damage": 1, "burst": 0, "killed": true}, 1.0, 0.0)
	boss.status.hp = 0.0
	boss.on_hit({"hp_damage": 0, "burst": 0, "killed": true}, 1.0, 0.0)
	await _pf(2)
	_check(Game.flag("b2_mireille_beaten") and Game.flag("picked:b2_transfer_record"), "mireille: defeat sets the flag and hands over the transfer record")


# ---------- B3 엘로디 ----------

func _elodie() -> void:
	Game.save = Game.default_save()
	Game.session_flags.clear()
	await _goto("b3")
	var p := _player()
	Juice.clear()
	p.global_position = Vector2(300, 300)
	await _pf(4)
	var lv: Level = main.level
	var boss = lv._spawned["arena"][0]
	_check(boss != null and boss.get("boss_name") == "엘로디", "elodie: spawns on entering the shrine")
	boss.rng.seed = 7
	boss.state = boss.State.IDLE
	# 정화 기도: inside the disc the player is purified and ticks 6 every 0.35 s
	p.reset_state(460)
	p.global_position = Vector2(460, 300)
	boss.global_position = Vector2(560, 300)
	boss._start_pattern("prayer")
	await _pf(int(1.4 * 120))
	_check(p.purified() and p.hp <= 88 and p.hp >= 76, "elodie: 정화 기도 purifies and ticks 6 inside the disc (knockback too small to eject)", "hp=%d purified=%s" % [p.hp, p.purified()])
	# 태양 낙인 locks the player's lane at the start; moving lanes avoids it
	boss._cancel_pattern()
	boss.state = boss.State.IDLE
	p.reset_state(400)
	p.global_position = Vector2(400, 300)
	boss._start_pattern("brand")
	await _pf(int(0.1 * 120))
	var lane: int = boss._used_lanes[0] if boss._used_lanes.size() > 0 else -1
	p.global_position = Vector2(150, 300)
	await _pf(int(1.0 * 120))
	_check(lane == 1 and p.hp == 100, "elodie: 태양 낙인 takes the locked lane only", "lane=%d hp=%d" % [lane, p.hp])
	# 백향 행렬: the incense wall purifies as it passes and hits 12 unparryable
	boss._cancel_pattern()
	boss.state = boss.State.IDLE
	p.reset_state(400)
	p.global_position = Vector2(400, 300)
	boss.global_position = Vector2(560, 300)
	boss._start_pattern("march")
	await _pf(int(0.5 * 120))
	p.press_parry(1.0)
	await _pf(int(0.8 * 120))
	_check(p.hp == 88 and p.purified(), "elodie: 백향 행렬 ignores the parry and purifies", "hp=%d" % p.hp)
	# late: 백향 행렬 chains into 은사슬 횡타
	boss._cancel_pattern()
	boss.status.hp = boss.max_hp * 0.5
	boss.on_hit({"hp_damage": 1, "burst": 0, "killed": false}, 1.0, 0.0)
	boss.cooldowns.clear()
	boss.state = boss.State.IDLE
	boss._start_pattern("march")
	var n := 0
	while boss.state == boss.State.PATTERN and n < 500:
		await _pf(1)
		n += 1
	await _pf(2)
	_check(boss.late and boss.pattern_id == "sweep", "elodie: late 백향 행렬 chains into 은사슬 횡타", boss.pattern_id)
	# defeat: flag, the bound disciple can be freed, the way home opens
	boss._cancel_pattern()
	boss.status.hp = 1.0
	boss.on_hit({"hp_damage": 1, "burst": 0, "killed": true}, 1.0, 0.0)
	boss.status.hp = 0.0
	boss.on_hit({"hp_damage": 0, "burst": 0, "killed": true}, 1.0, 0.0)
	await _pf(3)
	var rescue: Node = null
	for it in get_tree().get_nodes_in_group("interactable"):
		if it.get("rescue_id") != null:
			rescue = it
	var could: bool = rescue != null and rescue.available()
	if rescue:
		rescue._use()
	_check(Game.flag("b3_elodie_beaten") and could and Game.flag("rescued:b3_c"), "elodie: defeat opens the rescue and the flag is permanent", "could=%s" % could)


# ---------- screenshots (windowed): `-- --test=qa` ----------

func _qa() -> void:
	# Every screen a player sees, one capture each (names: qa-<area>-<state>; touch runs add "touch-").
	var p := _player()
	p.input_locked = true
	Game.save.skip_intro_seen = ["departure", "route", "b2", "b3", "return"]   # the cutscene gets its own capture below
	# --- T0: intro dialogue + map title + first sign, then the long signs, dummies, door
	await _goto("t0")
	p.global_position = Vector2(220, 300)
	await _pf(30)
	await _snap("qa-t0-intro")
	Dialogue.clear()
	p.global_position = Vector2(940, 300)
	await _pf(4)
	await _snap("qa-t0-sign-long")
	p.global_position = Vector2(1300, 300)
	await _pf(4)
	await _snap("qa-t0-cliff")
	p.global_position = Vector2(1830, 300)
	p.aim = Vector2.RIGHT
	await _pf(4)
	Juice.clear()
	p.press_attack()
	await _pf(40)
	await _snap("qa-t0-dummies-damage")
	p._say("내공 부족")
	Game.notice.emit("장법 「쇄진장」을 발견했습니다. 다음 휴식 지점에서 장착할 수 있습니다.")
	await _pf(4)
	await _snap("qa-t0-notices")
	p.global_position = Vector2(2920, 300)
	await _pf(4)
	await _snap("qa-t0-door")
	p.global_position = Vector2(2560, 300)
	await _pf(int(2.2 * 120))
	await _snap("qa-t0-drill")
	# --- cutscene overlay on first entry
	Game.save.skip_intro_seen = []
	await _goto("t0")
	await _pf(100)
	await _snap("qa-t0-cutscene")
	Game.save.skip_intro_seen = ["departure", "route"]
	# --- F1: archer, room fight, pull reticle + cast, manual on the roof, rest point + palm menu
	await _goto("f1")
	p.global_position = Vector2(1000, 300)
	await _pf(60)
	await _snap("qa-f1-archer")
	p.global_position = Vector2(1490, 300)
	p.aim = Vector2(1, 0)
	await _pf(6)
	await _snap("qa-f1-pull-reticle")
	p.press_pull()
	await _pf(3)
	await _snap("qa-f1-pull")
	Juice.clear()
	p.global_position = Vector2(1695, 70)
	await _pf(4)
	await _snap("qa-f1-manual-prompt")
	Game.collect_manual("f1_outpost_manual")
	p.global_position = Vector2(3050, 300)
	await _pf(20)
	await _snap("qa-f1-rest")
	main.palm_menu.open()
	await _pf(2)
	await _snap("qa-menu-palm")
	main.palm_menu.selected = 2
	main.palm_menu.queue_redraw()
	await _pf(2)
	await _snap("qa-menu-palm-locked")
	main.palm_menu.close()
	await _pf(2)
	# --- B1 boss: entry dialogue + boss bar, patterns
	await _goto("b1")
	p.global_position = Vector2(320, 300)
	await _pf(20)
	await _snap("qa-b1-entry")
	var boss = main.level._spawned["arena"][0]
	boss.state = boss.State.IDLE
	boss._start_pattern("leaf_fan")
	await _pf(int(0.5 * 120))
	await _snap("qa-b1-leaves")
	boss._cancel_pattern()
	boss.state = boss.State.IDLE
	boss._start_pattern("ash_rain")
	await _pf(int(1.2 * 120))
	await _snap("qa-b1-rain")
	boss._cancel_pattern()
	boss.state = boss.State.IDLE
	boss._start_pattern("root_ripple")
	await _pf(int(0.75 * 120))
	await _snap("qa-b1-root")
	boss._cancel_pattern()
	boss.status.stagger_left = 1.5
	boss.state = boss.State.STAGGER
	await _pf(4)
	await _snap("qa-b1-stagger")
	# --- H0 hub
	Dialogue.clear()
	await _goto("h0")
	await _pf(20)
	await _snap("qa-h0")
	p.global_position = Vector2(640, 300)
	await _pf(4)
	await _snap("qa-h0-renata")
	# --- F2: room 1 (shield + soldiers), mage cast, plates, rescue + pickup prompts
	await _goto("f2")
	p.global_position = Vector2(400, 300)
	await _pf(50)
	await _snap("qa-f2-room1")
	var shield: Node = null
	for e in main.level._spawned.get("r1", []):
		if e.get("guarding") != null:
			shield = e
	if shield:
		shield.broken_left = 0.5
		await _pf(2)
		await _snap("qa-f2-shield-broken")
	_clear_rooms()
	p.global_position = Vector2(1000, 300)
	await _pf(70)
	await _snap("qa-f2-mage")
	p.global_position = Vector2(2200, 300)
	await _pf(70)
	await _snap("qa-f2-plates")
	_clear_rooms()
	for r in main.level.rooms:
		r.entered = true
	main.level.active_room = {}
	main.level._enemy_count = 0
	p.global_position = Vector2(3040, 300)
	await _pf(4)
	await _snap("qa-f2-rescue-prompt")
	p.global_position = Vector2(2640, 300)
	await _pf(4)
	await _snap("qa-f2-pickup-prompt")
	# --- B2 미레유
	await _goto("b2")
	p.global_position = Vector2(400, 300)
	await _pf(20)
	await _snap("qa-b2-entry")
	var m = main.level._spawned["arena"][0]
	m.state = m.State.IDLE
	m._start_pattern("seal")
	await _pf(int(0.85 * 120))
	await _snap("qa-b2-seal")
	m._cancel_pattern()
	m.state = m.State.IDLE
	m._start_pattern("barrier")
	await _pf(int(0.6 * 120))
	await _snap("qa-b2-barrier")
	m._cancel_pattern()
	m.state = m.State.IDLE
	m._start_pattern("burn")
	await _pf(int(0.4 * 120))
	await _snap("qa-b2-burn")
	# --- F3: incense zone, purify HUD line, archer on the steps
	await _goto("f3")
	p.global_position = Vector2(1000, 300)
	await _pf(40)
	var keeper: Node = null
	for e in main.level._spawned.get("r2", []):
		if e.has_method("_lay_zone"):
			keeper = e
	if keeper:
		keeper._lay_zone()
		p.global_position = Vector2(keeper.global_position.x - 20.0, 300)
	await _pf(10)
	await _snap("qa-f3-incense")
	_clear_rooms()
	p.global_position = Vector2(1760, 300)
	await _pf(40)
	await _snap("qa-f3-steps")
	# --- B3 엘로디
	await _goto("b3")
	p.global_position = Vector2(430, 300)
	await _pf(20)
	await _snap("qa-b3-entry")
	var el = main.level._spawned["arena"][0]
	el.state = el.State.IDLE
	el._start_pattern("prayer")
	await _pf(int(0.9 * 120))
	await _snap("qa-b3-prayer")
	el._cancel_pattern()
	el.state = el.State.IDLE
	el._start_pattern("sweep")
	await _pf(int(0.40 * 120))
	await _snap("qa-b3-sweep")
	el._cancel_pattern()
	el.status.hp = 0.0
	el.on_hit({"hp_damage": 0, "burst": 0, "killed": true}, 1.0, 0.0)
	await _pf(30)
	p.global_position = Vector2(660, 300)
	await _pf(4)
	await _snap("qa-b3-after")
	# --- low HP + tremor + death
	p.hp = 12
	p.tremor_left = 2.0
	await _pf(4)
	await _snap("qa-status-low")
	p._take_damage(999)
	await _pf(60)
	await _snap("qa-death")
	print("QA saved")
	get_tree().quit(0)


## Kill every enemy of the current level and open its walls (QA: teleporting past locked rooms).
func _clear_rooms() -> void:
	var lv: Level = main.level
	for rid in lv._spawned:
		for e in lv._spawned[rid]:
			if is_instance_valid(e) and e.status.alive():
				e.status.hp = 0.0
				e.on_hit({"hp_damage": 0, "burst": 0, "killed": true}, 1.0, 0.0)
	lv._enemy_count = 0
	lv._unlock()


func _snap(name: String) -> void:
	for k in 2:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var prefix := "touch-" if main.touch_controls != null else ""
	get_viewport().get_texture().get_image().save_png("res://shots/%s%s.png" % [prefix, name])


# ---------- 월인 ----------

func _pull() -> void:
	Game.save = Game.default_save()
	await _goto("f1")
	var p := _player()
	Juice.clear()
	p.reset_state(60)
	p.global_position = Vector2(60, 300)
	await _pf(2)
	var d := await _dummy(140.0)
	p.aim = Vector2.RIGHT
	await _pf(2)
	_check(p.pull_candidate == d, "pull: reticle candidate is the dummy in the cone")
	var qi0 := p.qi
	var ok := p.press_pull()
	await _pf(30)
	_check(ok and absf(d.global_position.x - p.global_position.x) < 50.0 and p.qi <= qi0 - Player.PULL_QI + 6.0, "pull: normal enemy yanked to the hand, 내공 20", "dx=%.0f qi=%.0f" % [d.global_position.x - p.global_position.x, p.qi])
	_check(not p.press_pull(), "pull: cooldown blocks a second cast")
	# behind the aim: no target
	p.pull_cooldown = 0.0
	d.global_position = p.global_position + Vector2(-100, 0)
	_check(not p.press_pull(), "pull: nothing in the aim cone → refused")
	d.queue_free()
	# a boss cannot be moved: the thread pulls the player instead
	Game.save = Game.default_save()
	await _goto("b1")
	Juice.clear()
	p.global_position = Vector2(320, 300)
	await _pf(4)
	var boss = main.level._spawned["arena"][0]
	boss._cancel_pattern()
	boss.state = boss.State.IDLE
	boss.state_time = -99.0
	boss.global_position = Vector2(470, 300)
	p.global_position = Vector2(320, 300)
	p.pull_cooldown = 0.0
	p.aim = Vector2.RIGHT
	await _pf(2)
	var bx0: float = boss.global_position.x
	var okb := p.press_pull()
	await _pf(40)
	_check(okb and boss.global_position.x == bx0 and p.global_position.x > 380.0, "pull: boss stays, the player is reeled in", "px=%.0f" % p.global_position.x)


# ---------- tutorial course (physics gates) ----------

func _run_right(ticks: int) -> void:
	Input.action_press("move_right")
	await _pf(ticks)
	Input.action_release("move_right")


func _tutorial() -> void:
	Game.save = Game.default_save()
	await _goto("t0")
	var p := _player()
	Juice.clear()
	# 1. the 115px wall: a single jump never clears it, jump + air jump does
	p.reset_state(470)
	p.global_position = Vector2(470, 300)
	await _pf(2)
	Input.action_press("move_right")
	Input.action_press("jump")
	await _pf(120)
	Input.action_release("move_right")
	Input.action_release("jump")
	var single_x := p.global_position.x
	p.reset_state(470)
	p.global_position = Vector2(470, 300)
	await _pf(2)
	Input.action_press("move_right")
	Input.action_press("jump")
	await _pf(40)
	Input.action_release("jump")
	await _pf(2)
	Input.action_press("jump")   # 허공답월 near the apex
	await _pf(130)
	Input.action_release("move_right")
	Input.action_release("jump")
	_check(single_x < 560.0 and p.global_position.x > 800.0 and p.global_position.y <= 186.0, "tutorial: wall needs the air jump", "single=%.0f double=%.0f y=%.0f" % [single_x, p.global_position.x, p.global_position.y])
	# 2. the broken bridge: running in drops into the pit and returns to the footing; a dash crosses
	p.reset_state(1000)
	p.global_position = Vector2(1000, 300)
	await _pf(2)
	await _run_right(60)
	await _pf(40)
	var fell_back: bool = p.global_position.x < 1070.0 and p.global_position.y <= 300.5
	p.reset_state(1046)
	p.global_position = Vector2(1046, 300)   # at the edge, as the sign says
	await _pf(2)
	Input.action_press("move_right")
	p.press_dash(Vector2(1, 0))
	await _pf(40)
	Input.action_release("move_right")
	_check(fell_back and p.global_position.x > 1140.0 and p.is_on_floor(), "tutorial: bridge needs a ground dash", "x=%.0f y=%.0f" % [p.global_position.x, p.global_position.y])
	# 3. the 180px cliff: jump + air jump fall short; jump + air jump + upward air dash lands on top
	p.reset_state(1330)
	p.global_position = Vector2(1330, 300)
	await _pf(2)
	Input.action_press("jump")
	await _pf(40)
	Input.action_release("jump")
	await _pf(2)
	Input.action_press("jump")
	await _pf(100)
	Input.action_release("jump")
	var without_dash_y := p.global_position.y
	p.reset_state(1330)
	p.global_position = Vector2(1330, 300)
	await _pf(2)
	Input.action_press("jump")
	await _pf(40)
	Input.action_release("jump")
	await _pf(2)
	Input.action_press("jump")
	await _pf(30)
	Input.action_release("jump")
	Input.action_press("move_right")
	p.press_dash(Vector2(0.45, -1).normalized())
	await _pf(90)
	Input.action_release("move_right")
	_check(without_dash_y > 150.0 and p.global_position.y <= 121.0 and p.global_position.x >= 1380.0, "tutorial: cliff needs the upward air dash", "nodash_y=%.0f y=%.0f x=%.0f" % [without_dash_y, p.global_position.y, p.global_position.x])
