extends "res://src/boss/boss_base.gd"
## B1 티아넬, 잿가지의 녹궁 (본편 §5) — hard tuning: every telegraph is short, every pattern covers a
## large part of the arena, and late (≤60%) she chains two patterns back to back with a 0.2 s decision.
## Greybox silhouette; the real sheet and the oversized effects are in the 10차 request.
## Patterns: 바람 두 발 (two fast arrows), 다섯 갈래 잎 (5-way fan), 뿌리의 파문 (root waves both ways,
## twice), 가지 바꾸기 (perch hop + fan), 잿비 (arrow rain over 5 of 7 columns), 질풍 질주 (wind charge
## through the arena with a trailing blade). Variation: 지연 사격 with its own double-string cue.

const ARROW := Color(0.78, 0.9, 0.55)
var boss_name := "티아넬"


func _boss_setup() -> void:
	hurt_top = -60.0
	hurt_half_width = 11.0
	max_hp = 900.0
	armor = 0.10
	status.max_hp = max_hp
	status.hp = max_hp
	status.armor_rate = armor
	decision_wait = 0.32
	intro_time = 0.9
	stagger_time = 2.0
	fx_scale = 2.2


func _on_late() -> void:
	decision_wait = 0.18
	Dialogue.say("티아넬", "…바람이 떨린다. 그것이 너의 답인가.")


func patterns() -> Dictionary:
	return {
		"wind_shot": {"name": "바람 두 발", "dmin": 100.0, "recover": 0.55, "cooldown": 1.2,
			"strikes": [{"t": 0.45, "shape": "PROJ", "count": 1, "speed": 700.0, "raw": 14.0, "cls": N, "lock_lead": 0.12},
				{"t": 0.70, "shape": "PROJ", "count": 1, "speed": 760.0, "raw": 14.0, "cls": N, "lock_lead": 0.10, "warn_from": 0.45}],
			"chain_to": "leaf_fan"},
		"wind_shot_delayed": {"name": "바람 두 발 (지연)", "variant_of": "wind_shot", "dmin": 100.0, "recover": 0.55, "cooldown": 1.2,
			"strikes": [{"t": 0.80, "shape": "PROJ", "count": 1, "speed": 780.0, "raw": 16.0, "cls": N, "lock_lead": 0.12},
				{"t": 1.00, "shape": "PROJ", "count": 1, "speed": 780.0, "raw": 16.0, "cls": N, "lock_lead": 0.10, "warn_from": 0.80}]},
		"leaf_fan": {"name": "다섯 갈래 잎", "dmin": 80.0, "recover": 0.6, "cooldown": 1.8,
			"strikes": [{"t": 0.55, "shape": "PROJ", "count": 5, "spread": 30.0, "speed": 560.0, "raw": 12.0, "cls": N, "lock_lead": 0.15}],
			"chain_to": "root_ripple"},
		"root_ripple": {"name": "뿌리의 파문", "recover": 0.65, "cooldown": 2.4,
			"strikes": [{"t": 0.60, "dur": 0.1, "shape": "WAVE", "w": 60.0, "h": 34.0, "speed": 620.0, "travel": 1.2, "raw": 16.0, "cls": U, "both": true},
				{"t": 1.15, "dur": 0.1, "shape": "WAVE", "w": 60.0, "h": 34.0, "speed": 680.0, "travel": 1.2, "raw": 16.0, "cls": U, "both": true, "warn_from": 0.60}],
			"chain_to": "wind_shot"},
		"branch_switch": {"name": "가지 바꾸기", "recover": 0.6, "cooldown": 4.5, "move": true, "weight": 1.3,
			"moves": [{"from": 0.30, "to": 0.30, "to_perch": true}],
			"strikes": [{"t": 0.75, "shape": "PROJ", "count": 3, "spread": 16.0, "speed": 640.0, "raw": 13.0, "cls": N, "lock_lead": 0.12}],
			"chain_to": "ash_rain"},
		"ash_rain": {"name": "잿비", "recover": 0.8, "cooldown": 5.0, "weight": 0.9,
			"strikes": [{"t": 0.85, "shape": "RAIN", "columns": 7, "safe": 2, "speed": 820.0, "raw": 15.0, "cls": U, "h": 400.0, "w": 70.0}],
			"chain_to": "charge"},
		"charge": {"name": "질풍 질주", "dmin": 60.0, "recover": 0.7, "cooldown": 4.0, "move": true,
			"moves": [{"from": 0.40, "to": 0.70, "dist": "through", "gap": 120.0}],
			"strikes": [{"t": 0.40, "dur": 0.30, "shape": "MOVE", "w": 90.0, "h": 60.0, "z": 0.0, "raw": 18.0, "cls": H}],
			"chain_to": "leaf_fan"},
	}


func _anchor(key: String) -> Vector2:
	if key == "muzzle":
		return Vector2(facing * 12.0, -38.0)
	return Vector2(facing * 14.0, -40.0)


func _on_state(s: int) -> void:
	if s == State.STAGGER:
		Juice.fx("hat_spin", Vector2(0, -70), Vector2.RIGHT, 1.0, false, self)
	elif s == State.DEAD:
		Dialogue.say("티아넬", "…지나가라, 인간. 숲은 기억한다.")
		Dialogue.say("위지란", "기억해. 나도 전부 기억하니까.")
		Game.set_flag("b1_tianel_beaten")


func _strike_fx(s: Dictionary) -> void:
	match String(s.shape):
		"WAVE":
			Juice.fx("stomp_pulse_half", global_position, Vector2(facing, 0), 1.0, false, null, fx_scale)
			Juice.fx("stomp_pulse_half", global_position, Vector2(-facing, 0), 1.0, false, null, fx_scale)
			Juice.shake(6.0, 0.0)
		"PROJ":
			Juice.fx("mark_flash", _muzzle(), Vector2.RIGHT, 1.0, false, null, fx_scale)
			Juice.shake(2.0, 0.0)
		"RAIN":
			Juice.shake(5.0, 0.0)
		"MOVE":
			Juice.fx("dash_burst", global_position + Vector2(0, -30), Vector2(facing, 0), 1.0, false, null, fx_scale)
			Juice.shake(4.0, facing * 4.0)


func _draw_body() -> void:
	var alive := status.alive()
	var f := facing
	var kx := kick
	var tunic := Color(0.28, 0.52, 0.3) if alive else Color(0.3, 0.3, 0.3, 0.5)
	var skin := Color(0.9, 0.82, 0.72)
	var hair := Color(0.55, 0.82, 0.45)
	if flash > 0.0:
		tunic = Color(2, 2, 2)
	var crouch: float = 6.0 if state == State.STAGGER else 0.0
	draw_rect(Rect2(kx - 7, -26 + crouch, 5, 26 - crouch), Color(0.35, 0.25, 0.18))
	draw_rect(Rect2(kx + 2, -26 + crouch, 5, 26 - crouch), Color(0.35, 0.25, 0.18))
	draw_rect(Rect2(kx - 8, -52 + crouch, 16, 28), tunic)
	draw_rect(Rect2(kx - 9, -40 + crouch, 18, 8), Color(0.45, 0.3, 0.18))
	draw_circle(Vector2(kx, -58 + crouch), 7.0, skin)
	draw_rect(Rect2(kx - 8, -64 + crouch, 16, 8), hair)
	draw_rect(Rect2(kx - f * 10, -56 + crouch, 4, 34), hair)
	draw_line(Vector2(kx - f * 6, -62 + crouch), Vector2(kx - f * 15, -68 + crouch), skin, 2.0)
	var bow_c := Vector2(kx + f * 12, -40 + crouch)
	draw_arc(bow_c, 22.0, (-PI * 0.5 if f > 0 else PI * 0.5), (PI * 0.5 if f > 0 else PI * 1.5), 14, Color(0.1, 0.09, 0.08), 3.0)
	draw_circle(bow_c + Vector2(f * 20, -8), 2.0, Color(0.6, 0.9, 0.4))
	if state == State.PATTERN and pattern_id == "wind_shot_delayed":
		draw_line(bow_c + Vector2(0, -22), bow_c + Vector2(-f * 8, 0), Color(0.9, 0.95, 0.8, 0.8), 1.0)
		draw_line(bow_c + Vector2(0, 22), bow_c + Vector2(-f * 8, 0), Color(0.9, 0.95, 0.8, 0.8), 1.0)
	if state == State.PATTERN and pattern_id == "charge":
		draw_line(Vector2(kx, -40), Vector2(kx - f * 60, -40), Color(0.8, 1.0, 0.8, 0.5), 6.0)  # wind blade trail
	if state == State.DEAD:
		draw_string(Anim.font, Vector2(-30, -80), "물러섬", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.8, 0.9, 0.7))
