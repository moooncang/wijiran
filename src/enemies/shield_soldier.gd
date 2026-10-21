extends "res://src/enemies/enemy_base.gd"
## 성약군 방패병 (본편 §9, F2 첫 등장). Two behaviours: a front guard that halves hits from the front
## while it walks in, and a telegraphed shield bash (0.5 s) that lunges 60px. Weak points: anything from
## behind lands in full, and an injury burst (or a rear hit) breaks the guard open for 0.6 s.
## 11차 sheet (96 cell): idle/walk/guard/guard_hit/bash_ready/bash/break/hurt/recoil/stagger/death.

const WALK := 85.0
const STOP := 58.0
const GUARD_RANGE := 150.0
const BASH_T := 0.50
const BASH_END := 1.05
const BASH_LUNGE := 60.0
const BREAK_TIME := 0.6

var guarding := false
var pattern := ""
var attack_time := 0.0
var broken_left := 0.0
var decide_wait := 0.6
var sprite: ClipSprite
var _lunged := 0.0
var _block_t := 0.0
var _moving := false


func _setup() -> void:
	hurt_top = -54.0
	hurt_half_width = 13.0
	status.max_hp = 130.0
	status.hp = 130.0
	sprite = ClipSprite.new()
	sprite.setup(Anim.sheets["shield"])
	sprite.z_index = 2
	add_child(sprite)


func _cancel_attack() -> void:
	pattern = ""
	decide_wait = 0.5


func _on_stagger() -> void:
	pattern = ""
	guarding = false


func _shield_point() -> Vector2:
	return global_position + sprite.anchor("shield_center")


## Front hits through the guard deal half (never injury bursts); rear hits or bursts break the guard.
func _on_damaged(r: Dictionary, _push: float) -> void:
	var from_front: bool = player != null and (player.global_position.x - global_position.x) * facing > 0.0
	if guarding and broken_left == 0.0 and from_front and int(r.get("burst", 0)) == 0:
		var refund := int(r.hp_damage) - int(r.hp_damage) / 2
		status.hp = minf(status.max_hp, status.hp + refund)
		r.hp_damage = int(r.hp_damage) - refund
		_block_t = 0.2
		Juice.mark_guarded(global_position)   # its number shows as a blocked hit
		Juice.fx("shield_block", _shield_point(), Vector2(facing, 0))
	elif guarding and (not from_front or int(r.get("burst", 0)) > 0):
		broken_left = BREAK_TIME
		guarding = false
		pattern = ""
		Juice.fx("guard_break", _shield_point(), Vector2(facing, 0))


func _ai(dt: float) -> void:
	_moving = false
	if status.staggered() or status.recoil_left > 0.0 or hurt_left > 0.0:
		pattern = ""
		return
	if broken_left > 0.0:
		broken_left = maxf(0.0, broken_left - dt)
		return
	var dx := player.global_position.x - global_position.x
	if pattern == "":
		facing = -1.0 if dx < 0.0 else 1.0
		guarding = absf(dx) < GUARD_RANGE
		decide_wait = maxf(0.0, decide_wait - dt)
		var level := absf(player.global_position.y - global_position.y) < 50.0
		if absf(dx) > STOP + 10.0 or not level:
			global_position.x += facing * (WALK * 0.7 if guarding else WALK) * dt
			_moving = true
		elif decide_wait == 0.0:
			pattern = "bash"
			attack_time = 0.0
			_lunged = 0.0
			instance += 1
		return
	var before := attack_time
	attack_time += dt
	if attack_time >= BASH_T - 0.08 and _lunged < BASH_LUNGE:
		var step := minf(BASH_LUNGE - _lunged, BASH_LUNGE / 0.08 * dt)
		_lunged += step
		global_position.x += facing * step
	if before < BASH_T and attack_time >= BASH_T:
		var box := Rect2(global_position.x + (8.0 if facing > 0.0 else -50.0), ground_y - 40.0, 42.0, 40.0)
		_strike(1, box, 14.0, CombatConfig.ParryClass.NORMAL, 170.0, CombatConfig.POSTURE_NORMAL, _shield_point(), "방패 밀기")
		Juice.fx("bash_dust", global_position, Vector2(facing, 0))
	if attack_time >= BASH_END:
		pattern = ""
		decide_wait = 0.8


func _process(delta: float) -> void:
	super(delta)
	if Juice.frozen():
		return
	_block_t = maxf(0.0, _block_t - delta)
	sprite.set_facing(facing)
	sprite.position = Vector2(kick, 0)
	sprite.modulate = Color(2, 2, 2) if flash > 0.0 else (Color(1, 1, 1, 0.5) if not status.alive() else Color.WHITE)
	if not status.alive():
		sprite.play("death")
	elif status.staggered():
		sprite.play("stagger")
	elif status.recoil_left > 0.0:
		sprite.play("recoil")
	elif broken_left > 0.0:
		sprite.play("break")
	elif pattern == "bash":
		sprite.play("bash_ready" if attack_time < BASH_T else "bash")
	elif hurt_left > 0.0:
		sprite.play("hurt")
	elif _block_t > 0.0:
		sprite.play("guard_hit")
	elif _moving:
		sprite.play("walk")
	elif guarding:
		sprite.play("guard")
	else:
		sprite.play("idle")
	sprite.tick(delta)


func _draw_telegraphs() -> void:
	if status.alive() and pattern == "bash" and attack_time < BASH_T:
		var box := Rect2(Vector2(8.0 if facing > 0.0 else -50.0 - BASH_LUNGE, -40.0), Vector2(42.0 + BASH_LUNGE, 40.0))
		draw_telegraph(self, box, false, clampf(attack_time / BASH_T, 0.0, 1.0))


func _tag() -> Array:
	if broken_left > 0.0:
		return ["무방비", TAG_OPEN]
	return ["!", TAG_WARN] if pattern == "bash" and attack_time < BASH_T else []
