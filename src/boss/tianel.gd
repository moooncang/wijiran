extends "res://src/boss/boss_base.gd"
## B1 티아넬, 잿가지의 녹궁 (본편 §5). Greybox: drawn silhouette; the real sheet comes with the 10차
## delivery. Four base patterns, late (≤60%) chains, one variation with its own cue. She never flees
## twice in a row and every move is followed by a stationary pattern with a guaranteed opening.

const ARROW := Color(0.78, 0.9, 0.55)
var boss_name := "티아넬"


func _boss_setup() -> void:
	hurt_top = -60.0
	hurt_half_width = 11.0
	max_hp = 600.0
	armor = 0.10
	status.max_hp = max_hp
	status.hp = max_hp
	status.armor_rate = armor
	decision_wait = 0.5
	intro_time = 1.0
	stagger_time = 2.2


func patterns() -> Dictionary:
	return {
		# 바람 한 발: bow drawn level, line locks, one fast arrow. Opening after the shot.
		"wind_shot": {"name": "바람 한 발", "dmin": 110.0, "recover": 0.75, "cooldown": 1.5,
			"strikes": [{"t": 0.70, "shape": "PROJ", "count": 1, "speed": 560.0, "raw": 14.0, "cls": N, "lock_lead": 0.15}],
			"chain_to": ""},
		# variation: the string is held longer and a second string line shows from the start (distinct cue)
		"wind_shot_delayed": {"name": "바람 한 발 (지연)", "variant_of": "wind_shot", "dmin": 110.0, "recover": 0.75, "cooldown": 1.5,
			"strikes": [{"t": 1.10, "shape": "PROJ", "count": 1, "speed": 600.0, "raw": 16.0, "cls": N, "lock_lead": 0.15}]},
		# 세 갈래 잎: three leaves fan out from the arrow tip; gaps are the answer, closer = tighter
		"three_leaves": {"name": "세 갈래 잎", "dmin": 90.0, "recover": 0.85, "cooldown": 2.5,
			"strikes": [{"t": 0.80, "shape": "PROJ", "count": 3, "spread": 18.0, "speed": 500.0, "raw": 12.0, "cls": N, "lock_lead": 0.2}]},
		# 뿌리의 파문: roots surge along the floor; jump it, hit her while she stands still
		"root_ripple": {"name": "뿌리의 파문", "recover": 1.0, "cooldown": 3.0,
			"strikes": [{"t": 0.90, "dur": 0.1, "shape": "WAVE", "w": 44.0, "h": 24.0, "speed": 520.0, "travel": 1.1, "raw": 16.0, "cls": U}],
			"chain_to": "wind_shot"},
		# 가지 바꾸기: a wind ring marks the perch, she lands there and shoots once; a fixed opening follows
		"branch_switch": {"name": "가지 바꾸기", "dmax": 220.0, "recover": 0.9, "cooldown": 6.0, "move": true, "weight": 1.2,
			"moves": [{"from": 0.45, "to": 0.45, "to_perch": true}],
			"strikes": [{"t": 1.05, "shape": "PROJ", "count": 1, "speed": 540.0, "raw": 14.0, "cls": N, "lock_lead": 0.15}],
			"chain_to": "three_leaves"},
	}


func _anchor(key: String) -> Vector2:
	if key == "muzzle":
		return Vector2(facing * 12.0, -38.0)
	return Vector2(facing * 14.0, -40.0)


func _on_late() -> void:
	Dialogue.say("티아넬", "…바람이 떨린다. 그것이 너의 답인가.")


func _on_state(s: int) -> void:
	if s == State.STAGGER:
		Juice.fx("hat_spin", Vector2(0, -70), Vector2.RIGHT, 1.0, false, self)
	elif s == State.DEAD:
		Dialogue.say("티아넬", "…지나가라, 인간. 숲은 기억한다.")
		Dialogue.say("위지란", "기억해. 나도 전부 기억하니까.")
		Game.set_flag("b1_tianel_beaten")


func _strike_fx(s: Dictionary) -> void:
	if String(s.shape) == "WAVE":
		Juice.fx("stomp_pulse_half", global_position, Vector2(facing, 0))
		Juice.shake(4.0, 0.0)
	elif String(s.shape) == "PROJ":
		Juice.shake(2.0, 0.0)


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
	draw_rect(Rect2(kx - 9, -40 + crouch, 18, 8), Color(0.45, 0.3, 0.18))  # corset
	draw_circle(Vector2(kx, -58 + crouch), 7.0, skin)
	draw_rect(Rect2(kx - 8, -64 + crouch, 16, 8), hair)
	draw_rect(Rect2(kx - f * 10, -56 + crouch, 4, 34), hair)  # long hair behind
	draw_line(Vector2(kx - f * 6, -62 + crouch), Vector2(kx - f * 15, -68 + crouch), skin, 2.0)
	# the black longbow with new shoots
	var bow_c := Vector2(kx + f * 12, -40 + crouch)
	draw_arc(bow_c, 22.0, (-PI * 0.5 if f > 0 else PI * 0.5), (PI * 0.5 if f > 0 else PI * 1.5), 14, Color(0.1, 0.09, 0.08), 3.0)
	draw_circle(bow_c + Vector2(f * 20, -8), 2.0, Color(0.6, 0.9, 0.4))
	if state == State.PATTERN and not pattern.is_empty() and pattern_id == "wind_shot_delayed":
		# second string: the delayed-shot cue
		draw_line(bow_c + Vector2(0, -22), bow_c + Vector2(-f * 8, 0), Color(0.9, 0.95, 0.8, 0.8), 1.0)
		draw_line(bow_c + Vector2(0, 22), bow_c + Vector2(-f * 8, 0), Color(0.9, 0.95, 0.8, 0.8), 1.0)
	if state == State.DEAD:
		draw_string(Anim.font, Vector2(-30, -80), "물러섬", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.8, 0.9, 0.7))
