extends "res://src/boss/boss_base.gd"
## B3 엘로디 아르장, 백향의 심문관 (본편 §8). Core: 정화 areas and where to counter from.
## Hard tuning: telegraphs 0.45~0.9 s, the chain sweeps 260px, a lane-wide sun brand, a travelling incense
## wall that purifies, a 300px prayer disc that purifies and ticks, and a chain leap over the player.
## Late (≤60%): 백향 행렬 → 은사슬 횡타, 태양 낙인 → 정화 기도, decision 0.18 s. Variation: the double
## wind (a return strike). The prayer is cancelled only by a stagger (posture), never by a single hit.
## 11차 sheet (128 cell, hand/censer anchors) + boss_elodie_fx clips; the strike data is unchanged.

var boss_name := "엘로디"
var sprite: ClipSprite
var _circle_fx: Sprite2D
var _arc_fx: Sprite2D


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
	sprite = ClipSprite.new()
	sprite.setup(Anim.sheets["elodie"])
	sprite.z_index = 2
	add_child(sprite)
	sprite.play("intro", true)


func _on_late() -> void:
	decision_wait = 0.18
	Dialogue.say("엘로디", "…향이 반쯤 탔습니다, 이교도. 기도는 이제부터입니다.", 0.0, "portrait_elodie_doubt")


func patterns() -> Dictionary:
	return {
		"sweep": {"name": "은사슬 횡타", "dmax": 280.0, "recover": 0.5, "cooldown": 1.2, "pose": "chain_wind",
			"strikes": [{"t": 0.45, "dur": 0.10, "shape": "F", "w": 260.0, "h": 40.0, "z": 20.0, "raw": 18.0, "cls": N, "clip": "chain_sweep_fx", "hit_fx": "censer_impact"}],
			"chain_to": "brand"},
		"sweep_double": {"name": "은사슬 되감기", "variant_of": "sweep", "dmax": 280.0, "recover": 0.5, "cooldown": 1.2, "pose": "chain_wind_double",
			"strikes": [{"t": 0.50, "dur": 0.10, "shape": "F", "w": 260.0, "h": 40.0, "z": 20.0, "raw": 16.0, "cls": N, "clip": "chain_sweep_fx", "hit_fx": "censer_impact"},
				{"t": 0.90, "dur": 0.10, "shape": "F", "w": 260.0, "h": 40.0, "z": 20.0, "raw": 16.0, "cls": N, "warn_from": 0.50, "clip": "chain_return_fx", "hit_fx": "censer_impact"}]},
		"brand": {"name": "태양 낙인", "recover": 0.55, "cooldown": 2.6, "pose": "brand_raise",
			"strikes": [{"t": 0.70, "dur": 0.25, "shape": "LANE", "lane": "player", "h": 160.0, "lock": 0.0, "raw": 22.0, "cls": U, "warn_clip": "sun_brand", "fx": "sun_brand_burst"}],
			"chain_to": "prayer"},
		"march": {"name": "백향 행렬", "recover": 0.6, "cooldown": 3.0, "pose": "march_call",
			"strikes": [{"t": 0.50, "dur": 0.10, "shape": "WAVE", "w": 90.0, "h": 50.0, "speed": 300.0, "travel": 2.4, "raw": 12.0, "cls": U, "purify": true, "clip": "incense_march"}],
			"chain_to": "sweep"},
		"prayer": {"name": "정화 기도", "recover": 0.5, "cooldown": 6.0, "weight": 0.9, "pose": "prayer",
			"strikes": [{"t": 0.60, "dur": 1.40, "shape": "AURA", "r": 150.0, "tick": 0.40, "raw": 6.0, "cls": U, "purify": true, "knockback": 10.0}]},
		"leap": {"name": "사슬 도약", "dmin": 60.0, "recover": 0.45, "cooldown": 3.5, "move": true, "weight": 1.2, "pose": "chain_leap",
			"moves": [{"from": 0.15, "to": 0.50, "dist": "through", "gap": 110.0, "leap": 90.0}],
			"retargets": [0.52],
			"strikes": [{"t": 0.90, "dur": 0.10, "shape": "F", "w": 260.0, "h": 40.0, "z": 20.0, "raw": 16.0, "cls": N, "warn_from": 0.52, "clip": "chain_sweep_fx", "hit_fx": "censer_impact", "pose": "chain_wind"}],
			"chain_to": "march"},
	}


func _anchor(key: String) -> Vector2:
	if sprite:
		return sprite.anchor("censer" if key == "censer" else "hand")
	return Vector2(facing * 18.0, -40.0)


func _on_state(s: int) -> void:
	_free_fx()
	match s:
		State.INTRO:
			sprite.play("intro", true)
		State.IDLE:
			sprite.play("idle")
		State.STAGGER:
			sprite.play("stagger_in", true)
		State.DEAD:
			sprite.play("defeat", true)
			Juice.fx("censer_drop", global_position + Vector2(facing * 20.0, 0))
			var lv = Game.level
			if lv and lv.art:
				lv.art.swap_decor("b3_censer_stand_0", "b3_censer_stand_1")
			Dialogue.say("엘로디", "…향이 꺼졌습니다. 심문은 여기까지입니다, 이교도.", 0.0, "portrait_elodie_doubt")
			Dialogue.say("위지란", "이름은 위지란이야. 제자들 데려간다. 네 의문은 네가 안고 가.", 0.0, "portrait_wi_jiran_angry")
			Game.set_flag("b3_elodie_beaten")
			Game.notice.emit("향로가 떨어졌습니다 — 제자를 데리고 이곳을 벗어나세요")
		State.PATTERN:
			sprite.play(String(pattern.get("pose", "idle")), true)
			if pattern_id == "leap":
				_arc_fx = Juice.fx("chain_leap_arc", Vector2(0, -60), Vector2.RIGHT, 1.0, false, self)


func _free_fx() -> void:
	for n in [_circle_fx, _arc_fx]:
		if is_instance_valid(n):
			n.queue_free()
	_circle_fx = null
	_arc_fx = null


func _on_parried_fx() -> void:
	if player:
		Juice.fx("chain_parried", player.global_position + Vector2(0, -26))


func _strike_fx(s: Dictionary) -> void:
	match String(s.shape):
		"F":
			var clip := String(s.get("clip", "chain_sweep_fx"))
			var hand := global_position + _anchor("hand")
			if clip == "chain_return_fx":
				sprite.play("chain_return", true)
				Juice.fx(clip, hand + Vector2(facing * 260.0, 0), Vector2(facing, 0))
			else:
				sprite.play("chain_sweep", true)
				Juice.fx(clip, hand, Vector2(facing, 0))
			Juice.shake(4.0, facing * 3.0)
		"LANE":
			sprite.play("brand_fire", true)
			Juice.shake(6.0, 0.0)
		"WAVE":
			sprite.play("march_release", true)
			Juice.fx("incense_march_in", global_position + Vector2(facing * 40.0, 0), Vector2(facing, 0))
			Juice.shake(3.0, 0.0)
		"AURA":
			Juice.fx("purify_circle_in", global_position + Vector2(0, -30))
			_circle_fx = Juice.fx("purify_circle", Vector2(0, -30), Vector2.RIGHT, 1.0, false, self)
			_circle_fx.set("life", float(s.get("dur", 1.4)))


func _process(delta: float) -> void:
	super(delta)
	if Juice.frozen():
		return
	sprite.set_facing(facing)
	sprite.position = Vector2(kick, 0)
	sprite.modulate = Color(2, 2, 2) if flash > 0.0 else Color.WHITE
	match state:
		State.STAGGER:
			if sprite.clip == "stagger_in" and sprite._done:
				sprite.play("stagger", true)
			elif status.stagger_left < 0.2 and sprite.clip == "stagger":
				sprite.play("stagger_out", true)
		State.PATTERN:
			if pattern_id == "leap" and pattern_time >= 0.50 and is_instance_valid(_arc_fx):
				_arc_fx.queue_free()
				_arc_fx = null
			if pattern_id == "prayer" and pattern_time >= 2.0 and sprite.clip == "prayer":
				sprite.play("prayer_end", true)
				Juice.fx("purify_circle_out", global_position + Vector2(0, -30))
			if sprite._done and sprite.clip in ["chain_sweep", "chain_return"]:
				var nxt := _next_strike()
				sprite.play(String(nxt.get("pose", "chain_recover")) if not nxt.is_empty() else "chain_recover", true)
			elif sprite._done and sprite.clip in ["brand_fire", "march_release"]:
				sprite.play("idle", true)
		State.IDLE:
			if sprite.clip != "idle" and (sprite._done or sprite.clip in ["chain_wind", "chain_wind_double", "brand_raise", "march_call", "prayer"]):
				sprite.play("idle", true)
	sprite.tick(delta)
