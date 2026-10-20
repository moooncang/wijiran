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
	p.reset_state(600)
	p.global_position = Vector2(600, 300)
	await _pf(2)
	var hp0 := p.hp
	var shooter := Node2D.new()
	shooter.set_script(preload("res://src/enemies/scout_archer.gd"))
	shooter.position = Vector2(800, 300)
	main.level.add_child(shooter)
	await _pf(1)
	shooter.activate(p)
	shooter.state = shooter.S.RECOVER   # never shoots on its own during the test
	shooter.state_time = -99.0
	# arrow from the right, perfect parry → no damage, destroyed, posture +25 on the shooter
	var arrow := _arrow(shooter, Vector2(680, 276), Vector2(-440, 0))
	await _pf(8)
	p.press_parry(1.0)
	await _pf(14)
	var perfect_ok: bool = p.hp == hp0 and not is_instance_valid(arrow) and shooter.status.posture == 25.0
	_check(perfect_ok, "projectile: perfect parry destroys the arrow and adds posture", "hp=%d posture=%.0f" % [p.hp, shooter.status.posture])
	# no parry → damage, arrow consumed
	await _pf(30)
	p.reset_state(600)
	p.global_position = Vector2(600, 300)
	await _pf(2)
	var arrow2 := _arrow(shooter, Vector2(680, 276), Vector2(-440, 0))
	await _pf(30)
	_check(p.hp == 100 - 12 and not is_instance_valid(arrow2), "projectile: unparried arrow deals 12 and is consumed", "hp=%d" % p.hp)
	# dash i-frames: it passes through
	await _pf(30)
	p.reset_state(600)
	p.global_position = Vector2(600, 300)
	await _pf(2)
	var arrow3 := _arrow(shooter, Vector2(660, 276), Vector2(-440, 0))
	await _pf(6)
	p.press_dash(Vector2(1, 0))
	await _pf(10)
	_check(p.hp == 100, "projectile: dash i-frames pass the arrow", "hp=%d" % p.hp)
	# archers do not start a shot off-camera
	await _pf(40)
	shooter.global_position = Vector2(2100, 300)
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
	p.global_position = Vector2(300, 300)
	await _pf(4)
	var lv: Level = main.level
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
	await _pf(int(0.9 * 120))
	p.press_parry(1.0)
	await _pf(int(0.7 * 120))
	_check(p.hp == 84, "tianel: root wave ignores the parry (16 damage)", "hp=%d" % p.hp)
	# a perfect parry on an arrow adds posture; four of them stagger her
	boss._cancel_pattern()
	boss.status.posture = 75.0
	boss.status.posture_last_add = boss.status.time
	p.reset_state(500)
	p.global_position = Vector2(500, 300)   # inside the cover line: 60px of flight ≈ 0.11 s
	boss.global_position = Vector2(560, 300)
	boss.state = boss.State.IDLE
	boss._start_pattern("wind_shot")
	await _pf(int(0.72 * 120))
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


# ---------- screenshots (windowed): `-- --test=qa` ----------

func _qa() -> void:
	var p := _player()
	p.input_locked = true
	await _goto("t0")
	p.global_position = Vector2(1500, 300)
	await _snap("qa-t0")
	await _goto("f1")
	p.global_position = Vector2(1000, 300)
	await _pf(60)
	await _snap("qa-f1-archer")
	p.global_position = Vector2(1560, 300)
	await _pf(40)
	await _snap("qa-f1-room3")
	Game.save = Game.default_save()
	await _goto("b1")
	p.global_position = Vector2(320, 300)
	await _pf(4)
	var boss = main.level._spawned["arena"][0]
	boss.state = boss.State.IDLE
	boss._start_pattern("three_leaves")
	await _pf(int(0.7 * 120))
	await _snap("qa-b1-leaves")
	boss._cancel_pattern()
	boss.state = boss.State.IDLE
	boss._start_pattern("root_ripple")
	await _pf(int(1.1 * 120))
	await _snap("qa-b1-root")
	await _goto("h0")
	await _snap("qa-h0")
	print("QA saved")
	get_tree().quit(0)


func _snap(name: String) -> void:
	for k in 2:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	get_viewport().get_texture().get_image().save_png("res://shots/%s.png" % name)
