extends Node2D
## F2 격석 측정대 (본편 §7 4구역): a floor plate that heats up on a 3 s cycle — 1.0 s red-dot telegraph,
## then a 0.2 s unparryable burst 48×40. `phase` offsets plates so the room has a rhythm to read.
## Art: 11차 props stone_plate_off / hot (while warning) / burst.

const PERIOD := 3.0
const WARN := 1.0
const BURST := 0.2
const W := 48.0
const H := 40.0
const Telegraph := preload("res://src/enemies/enemy_base.gd")

var phase := 0.0
var _t := 0.0
var _fired := -1
var _top := 0.0   # local y of the surface the plate lies on (a dais over the floor point)
var _s: Sprite2D


func _ready() -> void:
	z_index = 1
	_t = phase
	var lv := get_parent()
	if lv is Level:
		for r: Rect2 in lv.data.get("platforms", []):
			if r.position.x <= position.x and position.x <= r.end.x and r.position.y < position.y and r.end.y >= position.y:
				_top = minf(_top, r.position.y - position.y)
	_s = Anim.prop_sprite("stone_plate_off")
	_s.position = Vector2(0, _top)
	add_child(_s)


func _zone() -> Rect2:
	return Rect2(global_position.x - W * 0.5, global_position.y - H, W, H)


func _physics_process(dt: float) -> void:
	if Juice.frozen():
		return
	_t += dt
	var cycle := int(_t / PERIOD)
	var u := fmod(_t, PERIOD)
	var p := Game.player
	if u >= WARN and u < WARN + BURST and _fired != cycle and p and not p.dead and _zone().intersects(p.hurt_rect()):
		_fired = cycle
		var hit := HitEvent.new()
		hit.attacker = self
		hit.instance_id = cycle + 1
		hit.hit_id = 1
		hit.origin = Vector2(clampf(p.global_position.x, _zone().position.x, _zone().end.x), global_position.y)
		hit.direction = Vector2(signf(p.global_position.x - global_position.x) if p.global_position.x != global_position.x else 1.0, 0)
		hit.raw_direct = 12.0
		hit.knockback = 80.0
		hit.hitstun = CombatConfig.HURT_STUN
		hit.parry_class = CombatConfig.ParryClass.UNPARRYABLE
		hit.posture_damage = 0.0
		hit.label = "격석"
		p.receive_hit(hit)
	if u < WARN:
		Anim.prop_frame(_s, "stone_plate_hot", int(_t * 8.0))
	elif u < WARN + 0.36:
		Anim.prop_frame(_s, "stone_plate_burst", int((u - WARN) / 0.12))
	else:
		Anim.prop_frame(_s, "stone_plate_off", 0)
	queue_redraw()


func _draw() -> void:
	var u := fmod(_t, PERIOD)
	if u < WARN:
		Telegraph.draw_telegraph(self, Rect2(-W * 0.5, -H, W, H), true, clampf(u / WARN, 0.0, 1.0))
