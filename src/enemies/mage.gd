extends "res://src/enemies/enemy_base.gd"
## 백은 마탑 견습 마법사 (본편 §9, F2). Two casts that alternate: a straight bolt after a 0.7 s hold, and a
## floor rune (90×26, unparryable) fixed at the player's feet when the cast starts, firing after 1.0 s.
## Any hit during a cast interrupts it (0.8 s helpless). One short step back when the player closes in,
## never twice in a row. 11차 sheet (96 cell, hand anchor) + fx_minions clips.

const KEEP_MIN := 140.0
const RETREAT_RANGE := 90.0
const RETREAT_DIST := 100.0
const BOLT_TIME := 0.70
const BOLT_LOCK := 0.15
const GROUND_TIME := 1.00
const INTERRUPT_TIME := 0.80
const BOLT_SPEED := 430.0

enum S { IDLE, CAST_BOLT, CAST_GROUND, INTERRUPTED, RECOVER, RETREAT }

var state: int = S.IDLE
var state_time := 0.0
var aim_dir := Vector2.LEFT
var locked := false
var can_retreat := true
var casts := 0
var zone := Rect2()
var sprite: ClipSprite
var _retreat_from := 0.0
var _retreat_dir := 1.0
var _release_t := 0.0
var _glow: Sprite2D
var _rune: Sprite2D


func _setup() -> void:
	hurt_top = -54.0
	hurt_half_width = 10.0
	status.max_hp = 55.0
	status.hp = 55.0
	sprite = ClipSprite.new()
	sprite.setup(Anim.sheets["mage"])
	sprite.z_index = 2
	add_child(sprite)


func _cancel_attack() -> void:
	state = S.RECOVER
	state_time = 0.0
	_free_cast_fx()


func _on_stagger() -> void:
	state = S.RECOVER
	state_time = -1.0
	_free_cast_fx()


func _on_damaged(_r: Dictionary, _push: float) -> void:
	if state in [S.CAST_BOLT, S.CAST_GROUND]:
		state = S.INTERRUPTED
		state_time = 0.0
		instance += 1
		_free_cast_fx()
		Juice.flash(_hand(), 8.0)


func _free_cast_fx() -> void:
	for n in [_glow, _rune]:
		if is_instance_valid(n):
			n.queue_free()
	_glow = null
	_rune = null


func _hand() -> Vector2:
	return global_position + sprite.anchor("hand")


func _ai(dt: float) -> void:
	if status.staggered() or status.recoil_left > 0.0:
		return
	state_time += dt
	var dx := player.global_position.x - global_position.x
	match state:
		S.IDLE:
			facing = -1.0 if dx < 0.0 else 1.0
			if absf(dx) < RETREAT_RANGE and can_retreat and _retreat_space() != 0.0:
				_begin_retreat()
			elif state_time >= 0.4 and Game.level and Game.level.camera_sees(global_position):
				instance += 1
				casts += 1
				state_time = 0.0
				locked = false
				_glow = Juice.fx("cast_glow", sprite.anchor("hand"), Vector2.RIGHT, 1.0, false, self)
				if casts % 2 == 1:
					state = S.CAST_BOLT
				else:
					state = S.CAST_GROUND
					var px := player.global_position.x
					zone = Rect2(px - 45.0, player.global_position.y - 26.0 if player.is_on_floor() else ground_y - 26.0, 90.0, 26.0)
					_rune = Juice.fx("ground_rune", Vector2(zone.get_center().x, zone.end.y))
		S.CAST_BOLT:
			if not locked:
				facing = -1.0 if dx < 0.0 else 1.0
				aim_dir = (player.global_position + Vector2(0, -24) - _hand()).normalized()
				if state_time >= BOLT_TIME - BOLT_LOCK:
					locked = true
			if state_time >= BOLT_TIME:
				_shoot()
				state = S.RECOVER
				state_time = 0.0
				can_retreat = true
		S.CAST_GROUND:
			if state_time >= GROUND_TIME:
				_strike(1, zone, 14.0, CombatConfig.ParryClass.UNPARRYABLE, 90.0, 0.0, Vector2(clampf(player.global_position.x, zone.position.x, zone.end.x), zone.end.y), "바닥 주문")
				_free_cast_fx()
				Juice.fx("ground_burst", Vector2(zone.get_center().x, zone.end.y))
				_release_t = 0.15
				state = S.RECOVER
				state_time = -0.3
				can_retreat = true
		S.INTERRUPTED:
			if state_time >= INTERRUPT_TIME:
				state = S.RECOVER
				state_time = 0.4
		S.RECOVER:
			if state_time >= 1.2:
				state = S.IDLE
				state_time = 0.0
		S.RETREAT:
			var u := clampf(state_time / 0.30, 0.0, 1.0)
			global_position.x = _retreat_from + _retreat_dir * RETREAT_DIST * u
			global_position.y = ground_y - 40.0 * 4.0 * u * (1.0 - u) * 0.5
			if u >= 1.0:
				global_position.y = ground_y
				state = S.IDLE
				state_time = 0.2
	if is_instance_valid(_glow):
		_glow.position = sprite.anchor("hand")


func _retreat_space() -> float:
	var away := -1.0 if player.global_position.x > global_position.x else 1.0
	var target := global_position.x + away * RETREAT_DIST
	var lv = Game.level
	if lv and (target < lv.player.world_min_x + 30.0 or target > lv.player.world_max_x - 30.0):
		return 0.0
	if target < room_x0 + 20.0 or target > room_x1 - 20.0:   # never hops out of its own room
		return 0.0
	return away


func _begin_retreat() -> void:
	state = S.RETREAT
	state_time = 0.0
	_retreat_from = global_position.x
	_retreat_dir = _retreat_space()
	can_retreat = false
	Juice.fx("backstep_dust", global_position, Vector2(_retreat_dir, 0))


func _shoot() -> void:
	_free_cast_fx()
	_release_t = 0.15
	var p := Node2D.new()
	p.set_script(preload("res://src/enemies/projectile.gd"))
	p.position = _hand()
	p.velocity = aim_dir * BOLT_SPEED
	p.shooter = self
	p.color = Color(0.62, 0.77, 1.0)
	p.clip = "mage_bolt"
	p.hit_clip = "mage_bolt_hit"
	p.parried_clip = "mage_bolt_parried"
	var hit := HitEvent.new()
	hit.attacker = self
	hit.instance_id = instance
	hit.hit_id = 1
	hit.raw_direct = 12.0
	hit.knockback = 110.0
	hit.parry_class = CombatConfig.ParryClass.NORMAL
	hit.posture_damage = CombatConfig.POSTURE_NORMAL
	hit.label = "직선 탄"
	hit.hit_fx = "mage_bolt_hit"
	p.hit = hit
	get_parent().add_child(p)
	Juice.fx("mark_flash", _hand())


func _process(delta: float) -> void:
	super(delta)
	if Juice.frozen():
		return
	_release_t = maxf(0.0, _release_t - delta)
	sprite.set_facing(facing)
	sprite.position = Vector2(kick, 0)
	sprite.modulate = Color(2, 2, 2) if flash > 0.0 else (Color(1, 1, 1, 0.5) if not status.alive() else Color.WHITE)
	if not status.alive():
		sprite.play("death")
	elif status.staggered():
		sprite.play("stagger")
	elif state == S.INTERRUPTED:
		sprite.play("interrupted")
	elif hurt_left > 0.0 and state not in [S.CAST_BOLT, S.CAST_GROUND]:
		sprite.play("hurt")
	elif state == S.CAST_BOLT:
		sprite.play("cast_bolt")
	elif state == S.CAST_GROUND:
		sprite.play("cast_ground")
	elif _release_t > 0.0:
		sprite.play("bolt_release")
	elif state == S.RETREAT:
		sprite.play("step_back")
	else:
		sprite.play("idle")
	sprite.tick(delta)


func _draw_telegraphs() -> void:
	if not status.alive():
		return
	match state:
		S.CAST_BOLT:
			var from := _hand() - global_position
			var col := Color(1, 0.3, 0.25, 0.9) if locked else Color(0.6, 0.75, 1.0, 0.5)
			var d := aim_dir if locked or player == null else (player.global_position + Vector2(0, -24) - _hand()).normalized()
			draw_line(from, from + d * 480.0, col, 2.0 if locked else 1.0)
		S.CAST_GROUND:
			draw_telegraph(self, Rect2(zone.position - global_position, zone.size), true, clampf(state_time / GROUND_TIME, 0.0, 1.0))


func _tag() -> Array:
	match state:
		S.CAST_BOLT:
			return ["!", TAG_WARN]
		S.CAST_GROUND:
			return ["X", TAG_UNPARRY]
		S.INTERRUPTED:
			return ["시전 끊김", TAG_OPEN]
	return []
