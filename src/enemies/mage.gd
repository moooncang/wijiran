extends "res://src/enemies/enemy_base.gd"
## 백은 마탑 견습 마법사 (본편 §9, F2). Two casts that alternate: a straight bolt after a 0.7 s hold, and a
## floor rune (90×26, unparryable) fixed at the player's feet when the cast starts, firing after 1.0 s.
## Any hit during a cast interrupts it (0.8 s helpless). One short step back when the player closes in,
## never twice in a row. Greybox body until the 11차 sheet.

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
var _retreat_from := 0.0
var _retreat_dir := 1.0


func _setup() -> void:
	hurt_top = -52.0
	hurt_half_width = 10.0
	status.max_hp = 55.0
	status.hp = 55.0


func _cancel_attack() -> void:
	state = S.RECOVER
	state_time = 0.0


func _on_stagger() -> void:
	state = S.RECOVER
	state_time = -1.0


func _on_damaged(_r: Dictionary, _push: float) -> void:
	if state in [S.CAST_BOLT, S.CAST_GROUND]:
		state = S.INTERRUPTED
		state_time = 0.0
		instance += 1
		Juice.flash(global_position + Vector2(facing * 12.0, -36.0), 8.0)


func _hand() -> Vector2:
	return global_position + Vector2(facing * 12.0, -34.0)


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
				if casts % 2 == 1:
					state = S.CAST_BOLT
				else:
					state = S.CAST_GROUND
					var px := player.global_position.x
					zone = Rect2(px - 45.0, player.global_position.y - 26.0 if player.is_on_floor() else ground_y - 26.0, 90.0, 26.0)
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
				Juice.fx("land_dust", Vector2(zone.get_center().x, zone.end.y))
				Juice.flash(zone.get_center(), 14.0)
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


func _retreat_space() -> float:
	var away := -1.0 if player.global_position.x > global_position.x else 1.0
	var target := global_position.x + away * RETREAT_DIST
	var lv = Game.level
	if lv and (target < lv.player.world_min_x + 30.0 or target > lv.player.world_max_x - 30.0):
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
	p.hit = hit
	get_parent().add_child(p)
	Juice.fx("mark_flash", _hand())


func _draw_body() -> void:
	draw_figure(self, 50.0, Color(0.88, 0.88, 0.94), Color(0.85, 0.72, 0.6), facing, status.alive())
	if not status.alive():
		return
	draw_rect(Rect2(-facing * 14.0 - 5.0, -46, 10, 7), Color(0.2, 0.25, 0.45))   # floating book
	match state:
		S.CAST_BOLT:
			var from := _hand() - global_position
			var col := Color(1, 0.3, 0.25, 0.9) if locked else Color(0.6, 0.75, 1.0, 0.5)
			draw_line(from, from + aim_dir * 480.0, col, 2.0 if locked else 1.0)
			draw_circle(from, 3.0 + 4.0 * clampf(state_time / BOLT_TIME, 0.0, 1.0), Color(0.7, 0.85, 1.0, 0.8))
			draw_string(Anim.font, Vector2(-5, hurt_top - 26), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.9, 0.4))
		S.CAST_GROUND:
			draw_telegraph(self, Rect2(zone.position - global_position, zone.size), true, clampf(state_time / GROUND_TIME, 0.0, 1.0))
			draw_string(Anim.font, Vector2(-5, hurt_top - 26), "X", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.85, 0.83, 0.78))
		S.INTERRUPTED:
			draw_string(Anim.font, Vector2(-16, hurt_top - 26), "시전 끊김", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 0.8, 0.5))
