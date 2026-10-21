extends "res://src/enemies/enemy_base.gd"
## 성휘 교단 향지기 (본편 §9, F3). Low HP, back-line first: a short staff strike (0.4 s telegraph) up close,
## and a 1.2 s kneel that lays a 정화 구역 (160×36 white incense strip, 12 s) under itself — interrupted by
## any hit. It keeps one zone at a time and prefers to cast from a distance. 11차 sheet (96 cell, staff_tip).

const WALK := 70.0
const STOP := 60.0
const STRIKE_T := 0.40
const STRIKE_END := 0.85
const CAST_TIME := 1.20
const CAST_COOLDOWN := 6.0

enum S { IDLE, STRIKE, CAST, INTERRUPTED, RECOVER }

var state: int = S.IDLE
var state_time := 0.0
var cast_cd := 1.0
var zone_node: Node2D
var sprite: ClipSprite
var _moving := false
var _done_t := 0.0


func _setup() -> void:
	hurt_top = -52.0
	hurt_half_width = 10.0
	status.max_hp = 50.0
	status.hp = 50.0
	sprite = ClipSprite.new()
	sprite.setup(Anim.sheets["incense"])
	sprite.z_index = 2
	add_child(sprite)


func _cancel_attack() -> void:
	state = S.RECOVER
	state_time = 0.0


func _on_stagger() -> void:
	state = S.RECOVER
	state_time = -1.0


func _on_damaged(_r: Dictionary, _push: float) -> void:
	if state == S.CAST:
		state = S.INTERRUPTED
		state_time = 0.0
		Juice.flash(global_position + Vector2(0, -30), 8.0)


func _ai(dt: float) -> void:
	_moving = false
	if status.staggered() or status.recoil_left > 0.0 or hurt_left > 0.0:
		return
	state_time += dt
	cast_cd = maxf(0.0, cast_cd - dt)
	var dx := player.global_position.x - global_position.x
	match state:
		S.IDLE:
			facing = -1.0 if dx < 0.0 else 1.0
			var zone_alive := is_instance_valid(zone_node)
			if cast_cd == 0.0 and not zone_alive and absf(dx) > 70.0:
				state = S.CAST
				state_time = 0.0
				instance += 1
			elif absf(dx) > STOP + 10.0:
				global_position.x += facing * WALK * dt
				_moving = true
			elif state_time >= 0.5:
				state = S.STRIKE
				state_time = 0.0
				instance += 1
		S.STRIKE:
			if state_time >= STRIKE_T and not status.already_hit("strike:%d" % instance):
				status.mark_hit("strike:%d" % instance)
				var box := Rect2(global_position.x + (8.0 if facing > 0.0 else -44.0), ground_y - 36.0, 36.0, 30.0)
				_strike(1, box, 10.0, CombatConfig.ParryClass.NORMAL, 110.0, CombatConfig.POSTURE_NORMAL, global_position + sprite.anchor("staff_tip"), "지팡이 타격", "staff_hit")
			if state_time >= STRIKE_END:
				state = S.RECOVER
				state_time = 0.3
		S.CAST:
			if state_time >= CAST_TIME:
				_lay_zone()
				_done_t = 0.25
				state = S.RECOVER
				state_time = 0.0
		S.INTERRUPTED:
			if state_time >= 0.7:
				state = S.RECOVER
				state_time = 0.3
				cast_cd = 2.0
		S.RECOVER:
			if state_time >= 0.9:
				state = S.IDLE
				state_time = 0.0


func _lay_zone() -> void:
	zone_node = Node2D.new()
	zone_node.set_script(preload("res://src/world/purify_zone.gd"))
	zone_node.position = Vector2(global_position.x, ground_y)
	get_parent().add_child(zone_node)
	cast_cd = CAST_COOLDOWN


func _process(delta: float) -> void:
	super(delta)
	if Juice.frozen():
		return
	_done_t = maxf(0.0, _done_t - delta)
	sprite.set_facing(facing)
	sprite.position = Vector2(kick, 0)
	sprite.modulate = Color(2, 2, 2) if flash > 0.0 else (Color(1, 1, 1, 0.5) if not status.alive() else Color.WHITE)
	if not status.alive():
		sprite.play("death")
	elif status.staggered():
		sprite.play("stagger")
	elif status.recoil_left > 0.0:
		sprite.play("recoil")
	elif state == S.INTERRUPTED or (hurt_left > 0.0 and state != S.STRIKE):
		sprite.play("hurt")
	elif state == S.STRIKE:
		sprite.play("strike_ready" if state_time < STRIKE_T else "strike")
	elif state == S.CAST:
		sprite.play("kneel_cast")
	elif _done_t > 0.0:
		sprite.play("cast_done")
	elif _moving:
		sprite.play("walk")
	else:
		sprite.play("idle")
	sprite.tick(delta)


func _draw_telegraphs() -> void:
	if not status.alive():
		return
	match state:
		S.STRIKE:
			if state_time < STRIKE_T:
				draw_telegraph(self, Rect2(Vector2(8.0 if facing > 0.0 else -44.0, -36.0), Vector2(36.0, 30.0)), false, clampf(state_time / STRIKE_T, 0.0, 1.0))
		S.CAST:
			# the strip it is about to lay (purify_zone 160×36), growing from the keeper
			var u := clampf(state_time / CAST_TIME, 0.0, 1.0)
			var r := Rect2(-80.0 * u, -36.0, 160.0 * u, 36.0)
			draw_rect(r, Color(1, 1, 1, 0.08 + 0.12 * u))
			draw_rect(r, Color(0.9, 0.9, 1.0, 0.35 + 0.4 * u), false, 1.0)


func _tag() -> Array:
	match state:
		S.STRIKE:
			if state_time < STRIKE_T:
				return ["!", TAG_WARN]
		S.CAST:
			return ["정화 기도", Color(0.95, 0.95, 1.0)]
		S.INTERRUPTED:
			return ["기도 끊김", TAG_OPEN]
	return []
