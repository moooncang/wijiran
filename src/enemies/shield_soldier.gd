extends "res://src/enemies/enemy_base.gd"
## 성약군 방패병 (본편 §9, F2 첫 등장). Two behaviours: a front guard that halves hits from the front
## while it walks in, and a telegraphed shield bash (0.5 s) that lunges 60px. Weak points: anything from
## behind lands in full, and an injury burst (or a rear hit) breaks the guard open for 0.6 s.
## Greybox body until the 11차 sheet (idle/walk/guard/guard_hit/bash_ready/bash/break/hurt/recoil/stagger/death).

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
var _lunged := 0.0


func _setup() -> void:
	hurt_top = -56.0
	hurt_half_width = 13.0
	status.max_hp = 130.0
	status.hp = 130.0


func _cancel_attack() -> void:
	pattern = ""
	decide_wait = 0.5


func _on_stagger() -> void:
	pattern = ""
	guarding = false


## Front hits through the guard deal half (never injury bursts); rear hits or bursts break the guard.
func _on_damaged(r: Dictionary, _push: float) -> void:
	var from_front: bool = player != null and (player.global_position.x - global_position.x) * facing > 0.0
	if guarding and broken_left == 0.0 and from_front and int(r.get("burst", 0)) == 0:
		var refund := int(r.hp_damage) - int(r.hp_damage) / 2
		status.hp = minf(status.max_hp, status.hp + refund)
		r.hp_damage = int(r.hp_damage) - refund
		Juice.fx("parry_partial_fx", global_position + Vector2(facing * 18.0, -34.0), Vector2(facing, 0))
	elif guarding and (not from_front or int(r.get("burst", 0)) > 0):
		broken_left = BREAK_TIME
		guarding = false
		pattern = ""
		Juice.flash(global_position + Vector2(facing * 14.0, -34.0), 10.0)


func _ai(dt: float) -> void:
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
		_strike(1, box, 14.0, CombatConfig.ParryClass.NORMAL, 170.0, CombatConfig.POSTURE_NORMAL, global_position + Vector2(facing * 26.0, -30.0), "방패 밀기")
		Juice.fx("run_dust", global_position, Vector2.RIGHT, facing)
	if attack_time >= BASH_END:
		pattern = ""
		decide_wait = 0.8


func _draw_body() -> void:
	draw_figure(self, 54.0, Color(0.5, 0.53, 0.6), Color(0.85, 0.72, 0.6), facing, status.alive())
	if not status.alive():
		return
	var sx := facing * 10.0
	if broken_left > 0.0:
		# guard broken: the shield swings wide
		draw_rect(Rect2(sx + facing * 10.0 - 6.0, -30, 12, 30), Color(0.72, 0.74, 0.8))
		draw_string(Anim.font, Vector2(-14, hurt_top - 26), "무방비", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 0.8, 0.5))
	else:
		var wind := pattern == "bash" and attack_time < BASH_T
		var ox := -facing * 8.0 if wind else 0.0
		draw_rect(Rect2(sx + ox + (0.0 if facing > 0.0 else -12.0), -50, 12, 42), Color(0.62, 0.65, 0.72) if guarding or wind else Color(0.45, 0.47, 0.52))
		draw_circle(Vector2(sx + ox + facing * 6.0, -30), 4.0, Color(0.85, 0.7, 0.3))   # sun badge
		if wind:
			draw_string(Anim.font, Vector2(-6, hurt_top - 26), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.9, 0.4))
			var box := Rect2(Vector2(8.0 if facing > 0.0 else -50.0 - BASH_LUNGE, -40.0), Vector2(42.0 + BASH_LUNGE, 40.0))
			draw_telegraph(self, box, false, clampf(attack_time / BASH_T, 0.0, 1.0))
