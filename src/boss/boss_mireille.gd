extends "res://src/boss/boss_base.gd"
## B2 미레유 오클랭, 실패한 가설 (본편 §7). Core: position-locked telegraphs and attack order.
## Hard tuning like 티아넬: telegraphs 0.5~0.95 s, lane-wide zones, late (≤60%) chains with a 0.18 s
## decision, and blinks across the room. Patterns: 적색 관측탄(+2발 변주), 좌표 소각(ZONE, saved once),
## 세 칸 봉쇄(LANE ×2, one lane always safe), 가설 장벽(BARRIER 2.5 s → 0.6 s open), 좌표 이동(blink + shot).
## Greybox body (robe, red hair, the mood orb) until the 11차 sheet; strike data is final.

var boss_name := "미레유"
var _orb_size := 6.0
var _orb_col := Color(1.0, 0.65, 0.2)


func _boss_setup() -> void:
	hurt_top = -56.0
	hurt_half_width = 11.0
	max_hp = 1000.0
	armor = 0.10
	status.max_hp = max_hp
	status.hp = max_hp
	status.armor_rate = armor
	decision_wait = 0.30
	intro_time = 0.9
	stagger_time = 2.0


func _on_late() -> void:
	decision_wait = 0.18
	Dialogue.say("미레유", "가설이 틀렸네. …다시. 이번엔 전부 기록할 거야.")


func patterns() -> Dictionary:
	return {
		"observe": {"name": "적색 관측탄", "dmin": 90.0, "recover": 0.45, "cooldown": 1.1, "pose": "orb_gather",
			"strikes": [{"t": 0.50, "shape": "PROJ", "count": 1, "speed": 640.0, "raw": 15.0, "cls": N, "lock_lead": 0.12, "clip": "observe_orb"}],
			"chain_to": "burn"},
		"observe_twin": {"name": "적색 쌍관측탄", "variant_of": "observe", "dmin": 90.0, "recover": 0.45, "cooldown": 1.1, "pose": "orb_gather_twin",
			"strikes": [{"t": 0.55, "shape": "PROJ", "count": 1, "speed": 680.0, "raw": 15.0, "cls": N, "lock_lead": 0.12, "clip": "observe_orb"},
				{"t": 0.75, "shape": "PROJ", "count": 1, "speed": 680.0, "raw": 15.0, "cls": N, "lock_lead": 0.10, "warn_from": 0.55, "clip": "observe_orb"}]},
		"burn": {"name": "좌표 소각", "recover": 0.5, "cooldown": 2.0, "pose": "burn_mark",
			"strikes": [{"t": 0.60, "dur": 0.25, "shape": "ZONE", "w": 140.0, "h": 70.0, "lock": 0.05, "raw": 18.0, "cls": U, "clip": "burn_circle"}],
			"chain_to": "observe"},
		"seal": {"name": "세 칸 봉쇄", "recover": 0.55, "cooldown": 3.0, "pose": "seal_chant",
			"strikes": [{"t": 0.55, "dur": 0.30, "shape": "LANE", "lane": "player", "h": 160.0, "lock": 0.0, "raw": 20.0, "cls": U},
				{"t": 0.95, "dur": 0.30, "shape": "LANE", "lane": "other", "h": 160.0, "lock": 0.40, "raw": 20.0, "cls": U, "warn_from": 0.40}],
			"chain_to": "barrier"},
		"barrier": {"name": "가설 장벽", "recover": 0.3, "cooldown": 7.0, "weight": 0.8, "pose": "barrier_up",
			"strikes": [{"t": 0.30, "shape": "BARRIER", "hold": 2.5, "cls": U, "raw": 0.0}]},
		"blink": {"name": "좌표 이동", "recover": 0.4, "cooldown": 2.5, "move": true, "weight": 1.3, "pose": "blink_out",
			"moves": [{"from": 0.20, "to": 0.20, "blink": "far"}],
			"strikes": [{"t": 0.65, "shape": "PROJ", "count": 1, "speed": 640.0, "raw": 14.0, "cls": N, "lock_lead": 0.12, "clip": "observe_orb", "warn_from": 0.20}],
			"chain_to": "seal"},
	}


func _anchor(key: String) -> Vector2:
	if key == "muzzle":
		return Vector2(facing * 16.0, -34.0)
	return Vector2(facing * 14.0, -36.0)


func _on_state(s: int) -> void:
	match s:
		State.DEAD:
			Dialogue.say("미레유", "…표본이 아니라. 이름이 있었구나, 전부.")
			Dialogue.say("위지란", "이송 기록. 내놔. 네 연구는 거기서 끝이야.")
			Dialogue.say("미레유", "엘로디에게 갔어. 백향 이송로. …처형당하게 두진 못해. 그래서 주는 거야.")
			Game.set_flag("b2_mireille_beaten")
			Game.set_flag("picked:b2_transfer_record")
			Game.notice.emit("관측진을 부쉈습니다 — 이송 기록을 얻었습니다")
		State.STAGGER:
			_orb_size = 3.0


func _on_barrier_hit() -> void:
	Juice.flash(global_position + Vector2(facing * 22.0, -56.0), 8.0)


func _on_barrier_down() -> void:
	Juice.fx("backstep_dust", global_position + Vector2(facing * 22.0, 0), Vector2(facing, 0))


func _on_blink() -> void:
	Juice.fx("backstep_dust", global_position, Vector2(facing, 0))
	Juice.flash(global_position + Vector2(0, -30), 16.0)


func _strike_fx(s: Dictionary) -> void:
	match String(s.shape):
		"PROJ":
			Juice.fx("mark_flash", _muzzle())
			Juice.shake(2.0, 0.0)
		"ZONE":
			var r: Rect2 = _zone_rects.get(int(s.id), Rect2())
			if r.size != Vector2.ZERO:
				Juice.flash(Vector2(r.get_center().x, r.end.y - 10.0), 26.0)
				Juice.fx("land_dust", Vector2(r.get_center().x, r.end.y))
			Juice.shake(5.0, 0.0)
		"LANE":
			var r: Rect2 = _zone_rects.get(int(s.id), Rect2())
			if r.size != Vector2.ZERO:
				for k in 3:
					Juice.flash(Vector2(r.position.x + r.size.x * (k + 0.5) / 3.0, r.end.y - 20.0), 18.0)
			Juice.shake(6.0, 0.0)
		"BARRIER":
			Juice.flash(global_position + Vector2(facing * 22.0, -56.0), 14.0)


func _process(delta: float) -> void:
	super(delta)
	if Juice.frozen():
		return
	# the mood orb: calm orange, grows gold when late, shrinks to a bean while staggered
	var target := 10.0 if late else 6.0
	if state == State.STAGGER:
		target = 3.0
	_orb_size = lerpf(_orb_size, target, 6.0 * delta)
	_orb_col = Color(1.0, 0.82, 0.3) if late else Color(1.0, 0.65, 0.2)


func _draw_body() -> void:
	var alive := status.alive()
	draw_figure(self, 56.0, Color(0.93, 0.93, 0.97), Color(0.9, 0.78, 0.66), facing, alive, true)
	if not alive:
		return
	var ink := Color(0.07, 0.04, 0.07)
	var book := Rect2(-facing * 12.0 - 4.0, -30, 8, 6)   # chained grimoire at the hip
	draw_rect(book, Color(0.3, 0.3, 0.45))
	draw_rect(book, ink, false, 1.0)
	var orb_y := -70.0 + sin(clock * 3.0) * 2.0
	draw_circle(Vector2(0, orb_y), _orb_size + 2.0, Color(_orb_col.r, _orb_col.g, _orb_col.b, 0.35))
	draw_circle(Vector2(0, orb_y), _orb_size, _orb_col)
	draw_circle(Vector2(0, orb_y), _orb_size * 0.4, Color(1, 1, 0.9))
	if state == State.PATTERN and pattern_id in ["observe", "observe_twin", "blink"]:
		var m := _muzzle() - global_position
		var nxt := _next_strike()
		if not nxt.is_empty():
			var u := clampf(pattern_time / float(nxt.t), 0.0, 1.0)
			draw_circle(m, 3.0 + 9.0 * u, Color(1.0, 0.7, 0.25, 0.7))
			if pattern_id == "observe_twin":
				draw_circle(m + Vector2(0, -10), 2.0 + 6.0 * u, Color(1.0, 0.7, 0.25, 0.7))


func _draw_dress(a: float) -> void:
	var mantle := PackedVector2Array([Vector2(-9, -40), Vector2(9, -40), Vector2(10, -33), Vector2(-10, -33)])   # short navy mantle
	draw_colored_polygon(mantle, Color(0.2, 0.25, 0.5, a))
	mantle.append(mantle[0])
	draw_polyline(mantle, Color(0.07, 0.04, 0.07, a), 1.0)
	draw_hair(self, 56.0, Color(0.75, 0.2, 0.15, a), facing, 6.0)   # red waves to the shoulders, face open
	draw_rect(Rect2(facing * 4.0 - 3.0, -50, 6, 3), Color(0.85, 0.7, 0.3, a), false, 1.0)   # gold spectacles


func _overhead_top() -> float:
	return -86.0   # above the mood orb (y -70, up to 12 px)
