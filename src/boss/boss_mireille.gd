extends "res://src/boss/boss_base.gd"
## B2 미레유 오클랭, 실패한 가설 (본편 §7). Core: position-locked telegraphs and attack order.
## Hard tuning like 티아넬: telegraphs 0.5~0.95 s, lane-wide zones, late (≤60%) chains with a 0.18 s
## decision, and blinks across the room. Patterns: 적색 관측탄(+2발 변주), 좌표 소각(ZONE, saved once),
## 세 칸 봉쇄(LANE ×2, one lane always safe), 가설 장벽(BARRIER 2.5 s → 0.6 s open), 좌표 이동(blink + shot).
## 11차 sheet (128 cell, hand/orb anchors) + boss_mireille_fx clips; the strike data is unchanged.

var boss_name := "미레유"
var sprite: ClipSprite
var _charge_fx: Sprite2D
var _plate_fx: Sprite2D


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
	sprite = ClipSprite.new()
	sprite.setup(Anim.sheets["mireille"])
	sprite.z_index = 2
	add_child(sprite)
	sprite.play("intro", true)


func _on_late() -> void:
	decision_wait = 0.18
	Dialogue.say("미레유", "가설이 틀렸네. …다시. 이번엔 전부 기록할 거야.", 0.0, "portrait_mireille_shaken")


func patterns() -> Dictionary:
	return {
		"observe": {"name": "적색 관측탄", "dmin": 90.0, "recover": 0.45, "cooldown": 1.1, "pose": "orb_gather",
			"strikes": [{"t": 0.50, "shape": "PROJ", "count": 1, "speed": 640.0, "raw": 15.0, "cls": N, "lock_lead": 0.12, "clip": "observe_orb", "hit_clip": "observe_orb_hit", "parried_clip": "observe_orb_parried"}],
			"chain_to": "burn"},
		"observe_twin": {"name": "적색 쌍관측탄", "variant_of": "observe", "dmin": 90.0, "recover": 0.45, "cooldown": 1.1, "pose": "orb_gather_twin",
			"strikes": [{"t": 0.55, "shape": "PROJ", "count": 1, "speed": 680.0, "raw": 15.0, "cls": N, "lock_lead": 0.12, "clip": "observe_orb", "hit_clip": "observe_orb_hit", "parried_clip": "observe_orb_parried", "fx": "orb_twin_split"},
				{"t": 0.75, "shape": "PROJ", "count": 1, "speed": 680.0, "raw": 15.0, "cls": N, "lock_lead": 0.10, "warn_from": 0.55, "clip": "observe_orb", "hit_clip": "observe_orb_hit", "parried_clip": "observe_orb_parried", "pose": "orb_gather_twin"}]},
		"burn": {"name": "좌표 소각", "recover": 0.5, "cooldown": 2.0, "pose": "burn_mark",
			"strikes": [{"t": 0.60, "dur": 0.25, "shape": "ZONE", "w": 140.0, "h": 70.0, "lock": 0.05, "raw": 18.0, "cls": U, "warn_clip": "burn_circle", "fx": "burn_flash"}],
			"chain_to": "observe"},
		"seal": {"name": "세 칸 봉쇄", "recover": 0.55, "cooldown": 3.0, "pose": "seal_chant",
			"strikes": [{"t": 0.55, "dur": 0.30, "shape": "LANE", "lane": "player", "h": 160.0, "lock": 0.0, "raw": 20.0, "cls": U, "warn_clip": "seal_rune", "fx": "seal_burst"},
				{"t": 0.95, "dur": 0.30, "shape": "LANE", "lane": "other", "h": 160.0, "lock": 0.40, "raw": 20.0, "cls": U, "warn_from": 0.40, "warn_clip": "seal_rune", "fx": "seal_burst", "pose": "seal_chant"}],
			"chain_to": "barrier"},
		"barrier": {"name": "가설 장벽", "recover": 0.3, "cooldown": 7.0, "weight": 0.8, "pose": "barrier_up",
			"strikes": [{"t": 0.30, "shape": "BARRIER", "hold": 2.5, "cls": U, "raw": 0.0}]},
		"blink": {"name": "좌표 이동", "recover": 0.4, "cooldown": 2.5, "move": true, "weight": 1.3, "pose": "blink_out",
			"moves": [{"from": 0.20, "to": 0.20, "blink": "far"}],
			"strikes": [{"t": 0.65, "shape": "PROJ", "count": 1, "speed": 640.0, "raw": 14.0, "cls": N, "lock_lead": 0.12, "clip": "observe_orb", "hit_clip": "observe_orb_hit", "parried_clip": "observe_orb_parried", "warn_from": 0.20, "pose": "orb_gather"}],
			"chain_to": "seal"},
	}


func _anchor(key: String) -> Vector2:
	if sprite:
		return sprite.anchor("orb" if key == "orb" else "hand")
	return Vector2(facing * 16.0, -34.0)


func _on_state(s: int) -> void:
	_free_charge()
	match s:
		State.INTRO:
			sprite.play("intro", true)
		State.IDLE:
			if sprite.clip != "barrier_hold" and sprite.clip != "blink_in":
				sprite.play("idle")
		State.STAGGER:
			_drop_barrier()
			sprite.play("stagger_in", true)
		State.DEAD:
			_drop_barrier()
			sprite.play("defeat", true)
			var lv = Game.level
			if lv and lv.art:
				var ring: Node2D = lv.art.swap_decor("b2_observation_ring_0", "b2_observation_ring_1")
				if ring:
					Juice.fx("ring_break", ring.global_position + Vector2(100, 200))
			Dialogue.say("미레유", "…표본이 아니라. 이름이 있었구나, 전부.", 0.0, "portrait_mireille_shaken")
			Dialogue.say("위지란", "이송 기록. 내놔. 네 연구는 거기서 끝이야.", 0.0, "portrait_wi_jiran_angry")
			Dialogue.say("미레유", "엘로디에게 갔어. 백향 이송로. …처형당하게 두진 못해. 그래서 주는 거야.", 0.0, "portrait_mireille_shaken")
			Game.set_flag("b2_mireille_beaten")
			Game.set_flag("picked:b2_transfer_record")
			Game.notice.emit("관측진을 부쉈습니다 — 이송 기록을 얻었습니다")
		State.PATTERN:
			sprite.play(String(pattern.get("pose", "idle")), true)
			if pattern_id in ["observe", "observe_twin"]:
				_charge_fx = Juice.fx("orb_charge", _anchor("hand"), Vector2.RIGHT, 1.0, false, self)


func _free_charge() -> void:
	if is_instance_valid(_charge_fx):
		_charge_fx.queue_free()
	_charge_fx = null


func _drop_barrier() -> void:
	if is_instance_valid(_plate_fx):
		_plate_fx.queue_free()
	_plate_fx = null
	barrier_left = 0.0


func _on_barrier_hit() -> void:
	Juice.fx("barrier_hit", global_position + Vector2(facing * 22.0, -56.0))


func _on_barrier_down() -> void:
	if is_instance_valid(_plate_fx):
		Juice.fx("barrier_crack", _plate_fx.global_position)
	_drop_barrier()
	sprite.play("barrier_down", true)


func _on_blink() -> void:
	Juice.fx("blink_pages", global_position + Vector2(0, -30))
	sprite.play("blink_out", true)


func _after_blink() -> void:
	Juice.fx("blink_pages", global_position + Vector2(0, -30))
	sprite.play("blink_in", true)


func _strike_fx(s: Dictionary) -> void:
	match String(s.shape):
		"PROJ":
			_free_charge()
			sprite.play("orb_release", true)
			if s.has("fx"):
				Juice.fx(String(s.fx), _muzzle())
			Juice.shake(2.0, 0.0)
		"ZONE":
			sprite.play("burn_fire", true)
			Juice.shake(5.0, 0.0)
		"LANE":
			sprite.play("seal_fire", true)
			Juice.shake(6.0, 0.0)
		"BARRIER":
			_plate_fx = Juice.fx("barrier_plate", Vector2(facing * 22.0, -56.0), Vector2.RIGHT, 1.0, false, self)
			sprite.play("barrier_hold", true)


func _process(delta: float) -> void:
	super(delta)
	if Juice.frozen():
		return
	sprite.set_facing(facing)
	sprite.position = Vector2(kick, 0)
	sprite.modulate = Color(2, 2, 2) if flash > 0.0 else Color.WHITE
	if is_instance_valid(_charge_fx):
		_charge_fx.position = _anchor("hand")
	if is_instance_valid(_plate_fx):
		_plate_fx.position = Vector2(facing * 22.0, -56.0)
	match state:
		State.STAGGER:
			if sprite.clip == "stagger_in" and sprite._done:
				sprite.play("stagger", true)
			elif status.stagger_left < 0.2 and sprite.clip == "stagger":
				sprite.play("stagger_out", true)
		State.PATTERN:
			if sprite._done and sprite.clip in ["orb_release", "burn_fire", "seal_fire", "blink_in"]:
				var nxt := _next_strike()
				sprite.play(String(nxt.get("pose", pattern.get("pose", "idle"))) if not nxt.is_empty() else "idle", true)
			elif sprite.clip == "blink_out" and sprite._done and pattern_time < 0.2:
				pass
		State.IDLE:
			if barrier_left <= 0.0 and sprite.clip in ["barrier_hold", "barrier_up"]:
				sprite.play("barrier_down", true)
			elif sprite.clip != "idle" and (sprite._done or sprite.clip in ["orb_gather", "orb_gather_twin", "burn_mark", "seal_chant"]):
				if sprite.clip != "barrier_hold":
					sprite.play("idle", true)
	sprite.tick(delta)
