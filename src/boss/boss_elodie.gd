extends "res://src/boss/boss_base.gd"
## B3 엘로디 아르장, 백향의 심문관 (본편 §8). Core: 정화 areas and where to counter from.
## Hard tuning: telegraphs 0.45~0.9 s, the chain sweeps 260px, a lane-wide sun brand, a travelling incense
## wall that purifies, a 300px prayer disc that purifies and ticks, and a chain leap over the player.
## Late (≤60%): 백향 행렬 → 은사슬 횡타, 태양 낙인 → 정화 기도, decision 0.18 s. Variation: the double
## wind (a return strike). The prayer is cancelled only by a stagger (posture), never by a single hit.
## Greybox body (white vestments, pale-blue hair, the sun censer) until the 11차 sheet; strike data is final.

var boss_name := "엘로디"
var _swing := 0.0


func _boss_setup() -> void:
	hurt_top = -60.0
	hurt_half_width = 11.0
	max_hp = 1100.0
	armor = 0.12
	status.max_hp = max_hp
	status.hp = max_hp
	status.armor_rate = armor
	decision_wait = 0.30
	intro_time = 0.9
	stagger_time = 2.0


func _on_late() -> void:
	decision_wait = 0.18
	Dialogue.say("엘로디", "…향이 반쯤 탔습니다, 이교도. 기도는 이제부터입니다.")


func patterns() -> Dictionary:
	return {
		"sweep": {"name": "은사슬 횡타", "dmax": 280.0, "recover": 0.5, "cooldown": 1.2, "pose": "chain_wind",
			"strikes": [{"t": 0.45, "dur": 0.10, "shape": "F", "w": 260.0, "h": 40.0, "z": 20.0, "raw": 18.0, "cls": N, "clip": "chain_sweep_fx"}],
			"chain_to": "brand"},
		"sweep_double": {"name": "은사슬 횡타 (회수)", "variant_of": "sweep", "dmax": 280.0, "recover": 0.5, "cooldown": 1.2, "pose": "chain_wind_double",
			"strikes": [{"t": 0.50, "dur": 0.10, "shape": "F", "w": 260.0, "h": 40.0, "z": 20.0, "raw": 16.0, "cls": N, "clip": "chain_sweep_fx"},
				{"t": 0.90, "dur": 0.10, "shape": "F", "w": 260.0, "h": 40.0, "z": 20.0, "raw": 16.0, "cls": N, "warn_from": 0.50, "clip": "chain_return_fx"}]},
		"brand": {"name": "태양 낙인", "recover": 0.55, "cooldown": 2.6, "pose": "brand_raise",
			"strikes": [{"t": 0.70, "dur": 0.25, "shape": "LANE", "lane": "player", "h": 160.0, "lock": 0.0, "raw": 22.0, "cls": U}],
			"chain_to": "prayer"},
		"march": {"name": "백향 행렬", "recover": 0.6, "cooldown": 3.0, "pose": "march_call",
			"strikes": [{"t": 0.50, "dur": 0.10, "shape": "WAVE", "w": 90.0, "h": 50.0, "speed": 300.0, "travel": 2.4, "raw": 12.0, "cls": U, "purify": true, "clip": "incense_march"}],
			"chain_to": "sweep"},
		"prayer": {"name": "정화 기도", "recover": 0.5, "cooldown": 6.0, "weight": 0.9, "pose": "prayer",
			"strikes": [{"t": 0.60, "dur": 1.40, "shape": "AURA", "r": 150.0, "tick": 0.40, "raw": 6.0, "cls": U, "purify": true, "knockback": 10.0}]},
		"leap": {"name": "사슬 도약", "dmin": 60.0, "recover": 0.45, "cooldown": 3.5, "move": true, "weight": 1.2, "pose": "chain_leap",
			"moves": [{"from": 0.15, "to": 0.50, "dist": "through", "gap": 110.0, "leap": 90.0}],
			"retargets": [0.52],
			"strikes": [{"t": 0.90, "dur": 0.10, "shape": "F", "w": 260.0, "h": 40.0, "z": 20.0, "raw": 16.0, "cls": N, "warn_from": 0.52, "clip": "chain_sweep_fx"}],
			"chain_to": "march"},
	}


func _anchor(_key: String) -> Vector2:
	return Vector2(facing * 18.0, -40.0)


func _on_state(s: int) -> void:
	match s:
		State.DEAD:
			Juice.flash(global_position + Vector2(facing * 20.0, -6.0), 22.0)
			Dialogue.say("엘로디", "…향이 꺼졌습니다. 심문은 여기까지입니다, 이교도.")
			Dialogue.say("위지란", "이름은 위지란이야. 제자들 데려간다. 네 의문은 네가 안고 가.")
			Game.set_flag("b3_elodie_beaten")
			Game.notice.emit("향로가 떨어졌다 · 제자를 데리고 이탈")
		State.PATTERN:
			if pattern_id == "prayer":
				Juice.ultimate_ring(global_position + Vector2(0, -30), 150.0)


func _strike_fx(s: Dictionary) -> void:
	match String(s.shape):
		"F":
			_swing = 0.25
			var r := _zone_rect(s)
			Juice.flash(Vector2(r.position.x if facing < 0.0 else r.end.x, r.get_center().y), 10.0)
			Juice.shake(4.0, facing * 3.0)
		"LANE":
			var r: Rect2 = _zone_rects.get(int(s.id), Rect2())
			if r.size != Vector2.ZERO:
				for k in 3:
					Juice.flash(Vector2(r.position.x + r.size.x * (k + 0.5) / 3.0, r.end.y - 30.0), 20.0)
			Juice.shake(6.0, 0.0)
		"WAVE":
			Juice.fx("backstep_dust", global_position, Vector2(facing, 0))
			Juice.shake(3.0, 0.0)
		"AURA":
			Juice.flash(global_position + Vector2(0, -30), 30.0)


func _process(delta: float) -> void:
	super(delta)
	if not Juice.frozen():
		_swing = maxf(0.0, _swing - delta)


func _draw_body() -> void:
	var alive := status.alive()
	draw_figure(self, 60.0, Color(0.96, 0.96, 0.98), Color(0.9, 0.8, 0.7), facing, alive)
	var a := 1.0 if alive else 0.4
	draw_rect(Rect2(-9, -62, 18, 12), Color(0.6, 0.8, 0.95, a))        # pale-blue hair
	draw_rect(Rect2(-9, -46, 18, 4), Color(0.75, 0.78, 0.85, a))        # silver embroidery / high collar
	# the chain censer: hangs at rest, snaps out on a sweep
	var hand := Vector2(facing * 10.0, -34.0)
	var censer := hand + (Vector2(facing * 60.0, 4.0) if _swing > 0.0 else Vector2(facing * 6.0, 26.0 + sin(clock * 2.0) * 2.0))
	draw_line(hand, censer, Color(0.8, 0.82, 0.9, a), 2.0)
	draw_circle(censer, 6.0, Color(0.85, 0.7, 0.3, a))
	draw_circle(censer, 2.5, Color(1.0, 0.95, 0.8, a))
	if alive and not beaten:
		for i in 3:
			draw_circle(censer + Vector2(sin(clock * 1.5 + i) * 5.0, -8.0 - i * 7.0), 3.0 - i * 0.5, Color(1, 1, 1, 0.35 - i * 0.08))
	elif beaten:
		draw_circle(Vector2(facing * 20.0, -6.0), 6.0, Color(0.85, 0.7, 0.3, 0.8))   # dropped censer
	if state == State.PATTERN and pattern_id == "prayer" and pattern_time >= 0.6:
		draw_arc(Vector2(0, -30), 150.0, 0.0, TAU, 56, Color(0.95, 0.97, 1.0, 0.25), 8.0)
