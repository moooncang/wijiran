extends "res://src/enemies/enemy_base.gd"
## 녹궁 정찰병 (elf scout; `human` = 성약군 사수 skin, same AI — 본편 §8). Aim telegraph (a thin line
## that locks 0.15 s before the shot), one arrow, cooldown; a single short retreat hop when the player
## closes in, never twice in a row (§9). No new shot starts while off-camera (§5).
## 10차 sheet: idle / aim(hold) / shoot(impact 0) / retreat / hurt / recoil / stagger / death; the arrow
## leaves from the aim clip's arrow_tip anchor.

const KEEP_MIN := 150.0
const KEEP_MAX := 280.0
const AIM_TIME := 0.60
const LOCK_LEAD := 0.15
const COOLDOWN := 1.3
const RETREAT_RANGE := 90.0
const RETREAT_DIST := 120.0
const ARROW_SPEED := 440.0

enum S { IDLE, AIM, RECOVER, RETREAT }

var human := false
var state: int = S.IDLE
var state_time := 0.0
var aim_dir := Vector2.LEFT
var locked := false
var can_retreat := true
var shots := 0
var _retreat_from := 0.0
var _retreat_dir := 1.0
var sprite: ClipSprite


func _setup() -> void:
	hurt_top = -52.0
	hurt_half_width = 10.0
	status.max_hp = 60.0
	status.hp = 60.0
	sprite = ClipSprite.new()
	sprite.setup(Anim.sheets["scout_human" if human else "scout"])
	sprite.z_index = 2
	add_child(sprite)


func _cancel_attack() -> void:
	state = S.RECOVER
	state_time = 0.0
	locked = false


func _on_stagger() -> void:
	state = S.RECOVER
	state_time = -1.0   # stays helpless for the stagger


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
			elif state_time >= 0.35 and Game.level and Game.level.camera_sees(global_position):
				state = S.AIM
				state_time = 0.0
				locked = false
				instance += 1
				sprite.play("aim", true)
		S.AIM:
			if not locked:
				facing = -1.0 if dx < 0.0 else 1.0
				aim_dir = (player.global_position + Vector2(0, -24) - _bow()).normalized()
				if state_time >= AIM_TIME - LOCK_LEAD:
					locked = true
			if state_time >= AIM_TIME:
				_shoot()
				state = S.RECOVER
				state_time = 0.0
				can_retreat = true   # a shot re-arms the retreat (no two retreats in a row)
		S.RECOVER:
			if state_time >= COOLDOWN:
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
				Juice.fx("land_dust", global_position)


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
	sprite.play("retreat", true)
	Juice.fx("backstep_dust", global_position, Vector2(_retreat_dir, 0))


func _bow() -> Vector2:
	if sprite and sprite.clip in ["aim", "shoot", "idle"]:
		return global_position + sprite.anchor("arrow_tip")
	return global_position + Vector2(facing * 10.0, -30.0)


func _shoot() -> void:
	shots += 1
	sprite.play("shoot", true)
	var p := Node2D.new()
	p.set_script(preload("res://src/enemies/projectile.gd"))
	p.position = _bow()
	p.velocity = aim_dir * ARROW_SPEED
	p.shooter = self
	p.clip = "arrow"
	p.hit_clip = "arrow_hit"
	p.parried_clip = "arrow_parried"
	p.stick_clip = "arrow_stick"
	var hit := HitEvent.new()
	hit.attacker = self
	hit.instance_id = instance
	hit.hit_id = 1
	hit.raw_direct = 12.0
	hit.knockback = 120.0
	hit.parry_class = CombatConfig.ParryClass.NORMAL
	hit.posture_damage = CombatConfig.POSTURE_NORMAL
	hit.label = "화살"
	hit.hit_fx = "arrow_hit"
	p.hit = hit
	get_parent().add_child(p)
	Juice.fx("mark_flash", _bow())


func _process(delta: float) -> void:
	super(delta)
	if Juice.frozen():
		return
	sprite.set_facing(facing)
	sprite.position = Vector2(kick, 0)
	sprite.modulate = Color(2, 2, 2) if flash > 0.0 else (Color(1, 1, 1, 0.5) if not status.alive() else Color.WHITE)
	if not status.alive():
		sprite.play("death")
	elif status.staggered():
		sprite.play("stagger")
	elif status.recoil_left > 0.0:
		sprite.play("recoil")
	elif hurt_left > 0.0 and state != S.AIM:
		sprite.play("hurt")
	elif state == S.AIM:
		sprite.play("aim")
	elif state == S.RETREAT:
		sprite.play("retreat")
	elif state == S.RECOVER and sprite.clip == "shoot" and not sprite._done:
		pass
	else:
		sprite.play("idle")
	sprite.tick(delta)


func _draw_body() -> void:
	if state == S.AIM and status.alive():
		var from := _bow() - global_position
		var col := Color(1, 0.3, 0.25, 0.9) if locked else Color(1, 0.8, 0.4, 0.5)
		draw_line(from, from + aim_dir * 520.0, col, 2.0 if locked else 1.0)
		draw_string(Anim.font, Vector2(-5, hurt_top - 26), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.9, 0.4))
