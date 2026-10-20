extends "res://src/boss/boss_base.gd"
## B1 티아넬, 잿가지의 녹궁 (본편 §5) — hard tuning: short telegraphs, arena-wide patterns, late (≤60%)
## chains with a 0.18 s decision. 10차 sheet + 256px effects: every pattern maps to a clip timeline
## (pull poses hold until the event), arrows carry their own looping art, waves and rain columns drag
## their effect sprites along, and the hitboxes stay the data in patterns().
## Patterns: 바람 두 발, 다섯 갈래 잎, 뿌리의 파문(양방향 2회), 가지 바꾸기(+3갈래), 잿비, 질풍 질주.
## Variation: 지연 사격 — draw_long shows a bright double string.

var boss_name := "티아넬"
var sprite: ClipSprite
var _charge_fx: Sprite2D
var _ring_fx: Sprite2D
var _ring_perch := Vector2.ZERO


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
	fx_scale = 1.0   # 10차 effects are drawn at their real size (judgement-sized)
	sprite = ClipSprite.new()
	sprite.setup(Anim.sheets["tianel"])
	sprite.z_index = 2
	add_child(sprite)
	sprite.play("intro", true)


func _on_late() -> void:
	decision_wait = 0.18
	Dialogue.say("티아넬", "…바람이 떨린다. 그것이 너의 답인가.", 0.0, "portrait_tianel_shaken")


func patterns() -> Dictionary:
	return {
		"wind_shot": {"name": "바람 두 발", "dmin": 100.0, "recover": 0.55, "cooldown": 1.2, "pose": "draw_level",
			"strikes": [{"t": 0.45, "shape": "PROJ", "count": 1, "speed": 700.0, "raw": 14.0, "cls": N, "lock_lead": 0.12, "clip": "wind_arrow"},
				{"t": 0.70, "shape": "PROJ", "count": 1, "speed": 760.0, "raw": 14.0, "cls": N, "lock_lead": 0.10, "warn_from": 0.45, "clip": "wind_arrow"}],
			"chain_to": "leaf_fan"},
		"wind_shot_delayed": {"name": "바람 두 발 (지연)", "variant_of": "wind_shot", "dmin": 100.0, "recover": 0.55, "cooldown": 1.2, "pose": "draw_long",
			"strikes": [{"t": 0.80, "shape": "PROJ", "count": 1, "speed": 780.0, "raw": 16.0, "cls": N, "lock_lead": 0.12, "clip": "wind_arrow"},
				{"t": 1.00, "shape": "PROJ", "count": 1, "speed": 780.0, "raw": 16.0, "cls": N, "lock_lead": 0.10, "warn_from": 0.80, "clip": "wind_arrow"}]},
		"leaf_fan": {"name": "다섯 갈래 잎", "dmin": 80.0, "recover": 0.6, "cooldown": 1.8, "pose": "draw_fan",
			"strikes": [{"t": 0.55, "shape": "PROJ", "count": 5, "spread": 30.0, "speed": 560.0, "raw": 12.0, "cls": N, "lock_lead": 0.15, "clip": "leaf_arrow", "fx": "leaf_fan5"}],
			"chain_to": "root_ripple"},
		"root_ripple": {"name": "뿌리의 파문", "recover": 0.65, "cooldown": 2.4, "pose": "root_call",
			"strikes": [{"t": 0.60, "dur": 0.1, "shape": "WAVE", "w": 60.0, "h": 34.0, "speed": 620.0, "travel": 1.2, "raw": 16.0, "cls": U, "both": true, "clip": "root_wave_twin"},
				{"t": 1.15, "dur": 0.1, "shape": "WAVE", "w": 60.0, "h": 34.0, "speed": 680.0, "travel": 1.2, "raw": 16.0, "cls": U, "both": true, "warn_from": 0.60, "clip": "root_wave_twin", "repose": true}],
			"chain_to": "wind_shot"},
		"branch_switch": {"name": "가지 바꾸기", "recover": 0.6, "cooldown": 4.5, "move": true, "weight": 1.3, "pose": "branch_leap",
			"moves": [{"from": 0.30, "to": 0.30, "to_perch": true}],
			"strikes": [{"t": 0.75, "shape": "PROJ", "count": 3, "spread": 16.0, "speed": 640.0, "raw": 13.0, "cls": N, "lock_lead": 0.12, "clip": "leaf_arrow", "pose": "draw_fan"}],
			"chain_to": "ash_rain"},
		"ash_rain": {"name": "잿비", "recover": 0.8, "cooldown": 5.0, "weight": 0.9, "pose": "rain_call",
			"strikes": [{"t": 0.85, "shape": "RAIN", "columns": 7, "safe": 2, "speed": 820.0, "raw": 15.0, "cls": U, "h": 400.0, "w": 70.0, "clip": "ash_arrow"}],
			"chain_to": "charge"},
		"charge": {"name": "질풍 질주", "dmin": 60.0, "recover": 0.7, "cooldown": 4.0, "move": true, "pose": "charge",
			"moves": [{"from": 0.40, "to": 0.70, "dist": "through", "gap": 120.0}],
			"strikes": [{"t": 0.40, "dur": 0.30, "shape": "MOVE", "w": 90.0, "h": 60.0, "z": 0.0, "raw": 18.0, "cls": H}],
			"chain_to": "leaf_fan"},
	}


func _anchor(key: String) -> Vector2:
	if sprite:
		return sprite.anchor("arrow_tip" if key == "muzzle" else "bow_tip")
	return Vector2(facing * 12.0, -38.0)


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
			sprite.play("withdraw", true)
			Dialogue.say("티아넬", "…지나가라, 인간. 숲은 기억한다.", 0.0, "portrait_tianel_shaken")
			Dialogue.say("위지란", "기억해. 나도 전부 기억하니까.", 0.0, "portrait_wi_jiran_neutral")
			Game.set_flag("b1_tianel_beaten")
		State.PATTERN:
			sprite.play(String(pattern.get("pose", "idle")), true)
			if pattern_id == "branch_switch":
				_ring_perch = _farthest_perch()
				if _ring_perch != Vector2.ZERO:
					_ring_fx = Juice.fx("wind_ring", _ring_perch)


func _free_fx() -> void:
	for n in [_charge_fx, _ring_fx]:
		if is_instance_valid(n):
			n.queue_free()
	_charge_fx = null
	_ring_fx = null


func _farthest_perch() -> Vector2:
	var best := Vector2.ZERO
	var bd := -1.0
	for p in perches:
		if (p as Vector2).distance_to(global_position) < 8.0:
			continue
		var d: float = absf((p as Vector2).x - player.global_position.x)
		if d > bd:
			bd = d
			best = p
	return best


func _on_perch() -> void:
	if is_instance_valid(_ring_fx):
		_ring_fx.queue_free()
	_ring_fx = null
	Juice.fx("wind_land", global_position)
	sprite.play("draw_fan", true)


## Strike-time visuals: the release pose, bow flash, fan burst, wave art, charge trail.
func _strike_fx(s: Dictionary) -> void:
	match String(s.shape):
		"PROJ":
			sprite.play("release", true)
			Juice.fx("bow_flash", _muzzle(), Vector2(facing, 0))
			if s.has("fx"):
				Juice.fx(String(s.fx), _muzzle(), _aim)
			Juice.shake(2.0, 0.0)
		"WAVE":
			if bool(s.get("repose", false)):
				sprite.play("root_call", true)
			Juice.fx("root_wave_in", global_position, Vector2(facing, 0))
			Juice.fx("root_wave_in", global_position, Vector2(-facing, 0))
			Juice.shake(6.0, 0.0)
		"RAIN":
			Juice.shake(5.0, 0.0)
		"MOVE":
			Juice.fx("charge_burst", global_position, Vector2(facing, 0))
			_charge_fx = Juice.fx("wind_charge", Vector2(0, -30), Vector2(facing, 0), 1.0, false, self)
			Juice.shake(4.0, facing * 4.0)


func _strike_flash(s: Dictionary) -> void:
	if String(s.shape) != "PROJ":
		super(s)


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
			if pattern_id == "charge":
				if pattern_time >= 0.70 and sprite.clip == "charge":
					sprite.play("charge_stop", true)
					if is_instance_valid(_charge_fx):
						_charge_fx.queue_free()
					_charge_fx = null
					Juice.fx("charge_burst", global_position, Vector2(facing, 0))
			elif sprite.clip == "release" and sprite._done:
				var nxt := _next_strike()
				sprite.play(String(nxt.get("pose", pattern.get("pose", "idle"))) if not nxt.is_empty() else "idle", true)
		State.IDLE:
			if sprite.clip != "idle" and (sprite._done or sprite.clip in ["draw_level", "draw_long", "draw_fan", "rain_call"]):
				sprite.play("idle", true)
	sprite.tick(delta)


func _draw_body() -> void:
	pass
