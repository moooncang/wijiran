extends Node2D
## F2 격석 측정대 (본편 §7 4구역): a floor plate that heats up on a 3 s cycle — 1.0 s red-dot telegraph,
## then a 0.2 s unparryable burst 48×40. `phase` offsets plates so the room has a rhythm to read.

const PERIOD := 3.0
const WARN := 1.0
const BURST := 0.2
const W := 48.0
const H := 40.0
const Telegraph := preload("res://src/enemies/enemy_base.gd")

var phase := 0.0
var _t := 0.0
var _fired := -1


func _ready() -> void:
	z_index = 1
	_t = phase


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
	queue_redraw()


func _draw() -> void:
	var u := fmod(_t, PERIOD)
	draw_rect(Rect2(-W * 0.5, -6, W, 6), Color(0.35, 0.3, 0.2))
	draw_rect(Rect2(-W * 0.5 + 4, -5, W - 8, 3), Color(0.55, 0.45, 0.25))
	if u < WARN:
		Telegraph.draw_telegraph(self, Rect2(-W * 0.5, -H, W, H), true, clampf(u / WARN, 0.0, 1.0))
	elif u < WARN + BURST + 0.15:
		var a := 1.0 - (u - WARN) / (BURST + 0.15)
		draw_rect(Rect2(-W * 0.5, -H, W, H), Color(1.0, 0.75, 0.3, 0.55 * a))
		draw_rect(Rect2(-W * 0.5, -H, W, H), Color(1.0, 0.9, 0.6, a), false, 2.0)
