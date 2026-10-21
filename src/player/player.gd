extends CharacterBody2D
class_name Player
## 위지란 (v9, Dungreed-style): small hand-drawn body (48px, few frames) + a detached front arm that
## rotates toward the cursor and swings on click. Attacks are code (arc + lunge + smear + hitstop), not
## frames. Space parry, hurt/death, 360° dash, air jump, 강화 만월 (E), 월식 (Q), 마열/침식/수전증 stay
## as designed in 위지란-플레이어-전투-구현기획서.md. Units: 800x450 viewport px.

const RUN_SPEED := 340.0
const WALK_SPEED := 95.0
const CROUCH_SPEED := 62.0
const ACCEL := 4200.0
const BRAKE := 5200.0
const AIR_ACCEL := 3400.0
const JUMP_SPEED := 430.0
const JUMP_CUT := 130.0
const RISE_GRAVITY := 1150.0
const FALL_GRAVITY := 1800.0
const JUMP_BUFFER := 0.14
const COYOTE := 0.085
const DASH_DURATION := 0.16     # 잔월보: 360° toward the cursor, gravity off, ~130 px
const DASH_COOLDOWN := 0.28
const DASH_SPEED := 980.0
const DASH_END_SPEED := 420.0
const RUN_CYCLE := 110.0
var world_min_x := 50.0   # area bounds; main swaps them when travelling
var world_max_x := 1800.0
const TORSO := Vector2(0, -26)
const EPS := 1e-6
const ARM_SCALE := 1.0          # arm_v2 parts are drawn at body scale (18px sleeve, 6px hand)
const HAND_SCALE := 1.0
const COMBO_WINDOW := 0.6

enum Action { FREE, DASH, PARRY, PARRY_RECOVERY, ULTIMATE, HURT, DEAD }

# Swing definitions. time = swing length, windup = pull-back before the swing (moon/heavy), arc in degrees,
# reach from the shoulder, lunge px/s toward the cursor. injury: stacks added; injury_burst: 만월 detonation.
# kind: "thrust" (straight rush along the aim), "spin" (360 degree whirl around the body), "burst" (gather qi
# for windup seconds, then detonate around the hand). Every swing lunges toward the cursor.
# Strikes come from the equipped 장법 (PalmStyles): three lights + one heavy per style. The dictionaries
# carry semantic flags (combo_index, is_heavy, injury_mode, targets, kind) so nothing here compares
# identities. These aliases keep the 흑월장 baseline reachable for tests.
var style_id: String = PalmStyles.DEFAULT_ID
var combat_enabled := true     # 쌍등객잔: weapons stay at the door
# 월인(月引): a qi thread toward the cursor. Normal enemies are yanked to the hand (interrupting them);
# a boss cannot be moved, so the thread pulls 위지란 to the boss instead. No damage, no i-frames.
const PULL_RANGE := 190.0
const PURIFY_BURST_RATE := 0.7
const PULL_CONE := 0.55         # cos of the half-angle around the aim
const PULL_QI := 20.0
const PULL_COOLDOWN := 3.0
const PULL_SPEED := 1100.0
var pull_cooldown := 0.0
var pull_target: Node = null
var pull_left := 0.0            # seconds of self-pull remaining (boss case)
var pull_candidate: Node = null  # what a right click would pull right now (enemies draw the reticle)
var purify_left := 0.0           # 정화 (본편 §8): inside white incense, injury bursts deal 30% less; fades 0.5 s after leaving

# --- movement ---
var facing := 1.0
var aim := Vector2.RIGHT
var clock := 0.0
var jump_buffer := 0.0
var coyote := COYOTE
var dash_time := 0.0
var dash_remaining := 0.0
var dash_cooldown := 0.0
var dash_dir := Vector2.RIGHT
var air_dash_available := true
var air_jump_available := true
var air_jump_time := 0.0
var jump_count := 0
var air_time := 0.0
var landing := 0.0
var gait := 0.0
var prev_gait := 0.0
var walking := false
var crouching := false
var _was_on_floor := true
var _ghost_tick := 0

# --- swings ---
var swing: Dictionary = {}       # empty = not swinging
var swing_t := 0.0               # negative during the wind-up
var swing_dir := 1.0
var swing_cooldown := 0.0
var combo_count := 0
var combo_timer := 0.0
var attack_instance := 0
var counter_armed := false
var hits := 0
var damage := 0
var _gauge_given := false
var _burst_rate := 1.0
var _recovery_extra := 0.0
var _lunged := false

# --- defense / resources ---
var hp: int = CombatConfig.PLAYER_MAX_HP
var armor_rate: float = CombatConfig.PLAYER_ARMOR
var dead := false
var death_time := 0.0
var parry_time := -1.0
var parry_ticks := -1
var parry_attempts := 0
var parry_facing := 1.0
var parry_recovery := 0.0
var hurt_left := 0.0
var protect_left := 0.0
var counter_left := 0.0
var qi: float = CombatConfig.QI_MAX
var rift := 0.0
var rift_hold := 0.0
var eroded := false
var gauge := 0.0
var ult_time := -1.0
var ult_cooldown := 0.0
var ult_burst_done := false
var tremor_left := 0.0
var resolved_hits: Dictionary = {}
var incoming: Array = []
var last_parry := "—"
var notice := ""
var notice_left := 0.0

# --- nodes ---
var sprite: Sprite2D
var arm_root: Node2D
var _aura: Sprite2D     # dash_aura, lives while dashing
var _gather: Sprite2D   # gather clip, lives while the burst winds up
var _rush: Sprite2D     # looping rush aura (쇄진장 관진), freed when the swing ends
var _drop_left := 0.0   # seconds left ignoring one-way ledges (S or a down dash on a ledge)
var _purify_fx: Sprite2D # purified_aura loop while 정화 is on
var sleeve: Sprite2D
var hand: Sprite2D
var qi_fx: Sprite2D
var guard: Sprite2D
var _body_clip := "idle"
var _body_index := 0
var _mouse_seen := false
var input_locked := false   # QA captures: ignore the real keyboard so a focused window cannot move the player
var touch_mode := false     # on-screen stick aims instead of the mouse
var touch_aim := Vector2.ZERO
var aim_point := Vector2.ZERO   # world point the cursor is at (camera target); shoulder + aim*100 without a mouse


func _ready() -> void:
	add_to_group("player")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 30)
	shape.shape = rect
	shape.position = Vector2(0, -15)
	add_child(shape)
	collision_mask = 3   # 1 = solids, 2 = one-way ledges (dropped while _drop_left runs)
	sprite = Sprite2D.new()
	sprite.texture = Anim.body_texture
	sprite.hframes = 8
	sprite.vframes = int(Anim.body_texture.get_height() / Anim.cell)
	sprite.centered = false
	sprite.offset = -Anim.pivot
	sprite.z_index = 3
	add_child(sprite)
	arm_root = Node2D.new()
	arm_root.z_index = 4
	add_child(arm_root)
	sleeve = Anim.make_part("arm_sleeve")
	sleeve.scale = Vector2(ARM_SCALE, ARM_SCALE)
	arm_root.add_child(sleeve)
	hand = Anim.make_part("hand_open")
	var wrist: Array = Anim.parts.arm_sleeve.wrist
	hand.position = Vector2(wrist[0] - Anim.parts.arm_sleeve.pivot[0], wrist[1] - Anim.parts.arm_sleeve.pivot[1])
	hand.scale = Vector2(HAND_SCALE, HAND_SCALE)
	sleeve.add_child(hand)
	qi_fx = Anim.make_part("qi_palm")
	qi_fx.position = Vector2(4, 0)
	qi_fx.visible = false
	hand.add_child(qi_fx)
	guard = Anim.make_part("arm_guard")
	guard.scale = Vector2(ARM_SCALE, ARM_SCALE)
	guard.z_index = 4
	guard.visible = false
	add_child(guard)


## 15. full reset (R).
func reset_state(x: float) -> void:
	style_id = Game.equipped_palm()
	global_position = Vector2(x, 300)
	velocity = Vector2.ZERO
	facing = 1.0
	swing = {}
	swing_cooldown = 0.0
	combo_count = 0
	dash_remaining = 0.0
	dash_cooldown = 0.0
	jump_buffer = 0.0
	landing = 0.0
	hits = 0
	damage = 0
	air_jump_available = true
	air_dash_available = true
	air_jump_time = 0.0
	jump_count = 0
	hp = CombatConfig.PLAYER_MAX_HP
	dead = false
	death_time = 0.0
	parry_time = -1.0
	parry_ticks = -1
	parry_recovery = 0.0
	hurt_left = 0.0
	protect_left = 0.0
	counter_left = 0.0
	counter_armed = false
	qi = CombatConfig.QI_MAX
	rift = 0.0
	rift_hold = 0.0
	eroded = false
	gauge = 0.0
	ult_time = -1.0
	ult_cooldown = 0.0
	tremor_left = 0.0
	pull_cooldown = 0.0
	pull_left = 0.0
	pull_target = null
	resolved_hits.clear()
	incoming.clear()
	last_parry = "—"
	notice = ""


func action() -> int:
	if dead:
		return Action.DEAD
	if hurt_left > 0.0:
		return Action.HURT
	if ult_time >= 0.0:
		return Action.ULTIMATE
	if parry_time >= 0.0:
		return Action.PARRY
	if parry_recovery > 0.0:
		return Action.PARRY_RECOVERY
	if dash_remaining > 0.0:
		return Action.DASH
	return Action.FREE


func swinging() -> bool:
	return not swing.is_empty()


const NOTICE_TIME := 1.6   # long enough to read a short line; the HUD shows it bottom-centre and fades the end


## Short feedback toast. Says what is blocked; live countdowns stay in the HUD so the toast never shows a stale number.
func _say(msg: String) -> void:
	notice = msg
	notice_left = NOTICE_TIME


# ---------- input entry points ----------

## Left click: the equipped style's light chain (0 → 1 → 2 inside the combo window). Allowed while free,
## airborne, or mid-dash (the swing cuts the dash).
func press_attack() -> bool:
	if not combat_enabled or action() not in [Action.FREE, Action.DASH] or swinging() or swing_cooldown > 0.0 or crouching:
		return false
	if combo_timer == 0.0:
		combo_count = 0
	_start_swing(PalmStyles.light(style_id, combo_count))
	combo_count = (combo_count + 1) % 3
	combo_timer = COMBO_WINDOW
	return true


## E / right click: the style's heavy strike (grounded free; its own 내공 cost and 마열 gain, 장법 기획 §6).
## Overheat rate and erosion recovery are snapshotted at start; costs are paid once, never refunded.
func press_heavy() -> bool:
	if not combat_enabled or action() != Action.FREE or swinging() or crouching:
		return false
	if not is_on_floor():
		_say("강화 · 지상에서만")   # touch has no key panel to explain a silent press
		return false
	if tremor_left > 0.0:
		_say("수전증 · 강화 불가")
		return false
	var h := PalmStyles.heavy(style_id)
	if qi < float(h.qi_cost):
		_say("강화 · 내공 부족")
		return false
	_burst_rate = CombatConfig.OVERHEAT_BURST_RATE if (eroded or rift >= CombatConfig.OVERHEAT_RIFT) else 1.0
	_recovery_extra = CombatConfig.HEAVY_RECOVERY_EXTRA + (CombatConfig.EROSION_RECOVERY_EXTRA if eroded else 0.0)
	_start_swing(h)
	qi -= float(h.qi_cost)
	_add_rift(float(h.rift_gain))
	return true


## Right click: 월인. Picks the nearest enemy inside the aim cone and range; pays 내공 20 once.
func press_pull() -> bool:
	if not combat_enabled or action() != Action.FREE or swinging():
		return false
	if pull_cooldown > 0.0:
		_say("월인 · 재사용 중")
		return false
	if qi < PULL_QI:
		_say("월인 · 내공 부족")
		return false
	var origin := _shoulder_world()
	var best: Node = _pull_candidate()
	if best == null:
		_say("월인 · 대상 없음")
		Juice.fx("pull_fail", _hand_world(), aim)
		return false
	qi -= PULL_QI
	pull_cooldown = PULL_COOLDOWN
	facing = 1.0 if best.global_position.x >= global_position.x else -1.0
	var target_p: Vector2 = best.global_position + Vector2(0, -24)
	var to_target: Vector2 = target_p - origin
	var bd := to_target.length()
	# the thread: its stretch band (cell x 20..176 = 156px) scaled to the distance, caps kept proportional
	Juice.fx("pull_thread", origin, to_target.normalized(), facing, false, null, 1.0, Vector2(maxf(0.3, bd / 156.0), 1.6)).set("life", 0.22)
	_pull_line(origin, target_p)
	Juice.fx("pull_cast", origin, to_target.normalized(), 1.0, false, null, 1.4)
	Juice.fx("pull_hook", target_p, to_target.normalized(), 1.0, false, null, 1.8)
	Juice.flash(origin, 10.0)
	Juice.flash(target_p, 14.0)
	Juice.hitstop(0.05)
	if best.status.is_boss:
		pull_target = best
		pull_left = 0.3
		_end_swing()
		Juice.fx("pull_self", TORSO, to_target.normalized(), 1.0, false, self).set("life", 0.3)
	elif best.has_method("pull_to"):
		best.pull_to(global_position + Vector2(facing * 34.0, 0))
		Juice.fx("pull_drag", best.global_position, Vector2(-facing, 0), 1.0, false, null, 1.5).set("life", 0.2)
	return true


## True while the floor under her is a one-way ledge (layer 2).
func _on_ledge() -> bool:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().y < -0.5 and c.get_collider() is StaticBody2D and (c.get_collider() as StaticBody2D).collision_layer == 2:
			return true
	return false


func _drop_through() -> void:
	_drop_left = 0.22
	collision_mask = 1
	global_position.y += 2.0
	crouching = false


## A door, lantern, manual, rescue or rest point that W would use right now.
func _near_usable() -> bool:
	for it in get_tree().get_nodes_in_group("interactable"):
		if it.near and it.label != "" and it.available():
			return true
	return false


## 정화 영역이 매 프레임 부른다: 나간 뒤 0.5초면 정상. 중첩 없음, 내상 스택은 그대로 (기획 §8).
func purify(seconds: float) -> void:
	purify_left = maxf(purify_left, seconds)


func purified() -> bool:
	return purify_left > 0.0


## 11차 purified_aura loop around the torso while 정화 is on.
func _step_purify_fx() -> void:
	if purified() and not dead:
		if not is_instance_valid(_purify_fx):
			_purify_fx = Juice.fx("purified_aura", TORSO, Vector2.RIGHT, 1.0, false, self)
			_purify_fx.z_index = 4
	else:
		_free(_purify_fx)


## Nearest living enemy inside the 월인 cone and range, or null.
func _pull_candidate() -> Node:
	var best: Node = null
	var bd := INF
	var origin := _shoulder_world()
	for d in get_tree().get_nodes_in_group("enemy"):
		if d.get("status") == null or not d.status.alive():
			continue
		if d.has_method("invulnerable") and d.invulnerable():
			continue
		var to: Vector2 = (d.global_position + Vector2(0, -24)) - origin
		var dist := to.length()
		if dist > PULL_RANGE or dist < 1.0 or to.normalized().dot(aim) < PULL_CONE:
			continue
		if dist < bd:
			bd = dist
			best = d
	return best


## A bright additive line from the shoulder to the target that fades over 0.3 s: the sprite thread alone is 6px thin.
func _pull_line(from: Vector2, to: Vector2) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([from, to])
	line.width = 4.0
	line.default_color = Color(1.0, 0.9, 0.55)
	line.z_index = 42
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	line.material = mat
	Juice.world.add_child(line)
	var tw := line.create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.3).set_delay(0.06)
	tw.finished.connect(line.queue_free)


func _step_pull(dt: float) -> void:
	if pull_target == null or not is_instance_valid(pull_target):
		pull_left = 0.0
		return
	pull_left -= dt
	var to: Vector2 = pull_target.global_position - global_position
	if absf(to.x) < 44.0 or pull_left <= 0.0:
		pull_left = 0.0
		pull_target = null
		velocity.x *= 0.3
		return
	velocity.x = signf(to.x) * PULL_SPEED
	if not is_on_floor():
		velocity.y = minf(velocity.y, 0.0)


## 장법 교체 (Game.equip_palm): only the combo state resets (기획 §4).
func on_palm_changed() -> void:
	style_id = Game.equipped_palm()
	combo_count = 0
	combo_timer = 0.0
	counter_left = 0.0
	counter_armed = false


func _start_swing(a: Dictionary) -> void:
	if dash_remaining > 0.0:
		dash_remaining = 0.0
	swing = a
	swing_t = -float(a.windup)
	swing_dir = -swing_dir
	attack_instance += 1
	_gauge_given = false
	_lunged = false
	facing = 1.0 if aim.x >= 0.0 else -1.0
	counter_armed = int(a.get("combo_index", -1)) == 0 and counter_left > 0.0   # first strike of any style
	counter_left = 0.0
	if not bool(a.get("is_heavy", false)):
		_burst_rate = 1.0
		_recovery_extra = 0.0
	if float(a.windup) <= 0.0:
		_release_swing()
	else:
		_free(_gather)
		_gather = Juice.fx("gather", TORSO + aim * 14.0, Vector2.RIGHT, 1.0, false, self)


## The arc starts: lunge toward the cursor and spawn the smear at the shoulder.
func _release_swing() -> void:
	_lunged = true
	var lunge_speed: float = float(swing.lunge) * (CombatConfig.COUNTER_LUNGE_RATE if counter_armed else 1.0)
	var lunge := aim * lunge_speed
	if is_on_floor():
		lunge = Vector2(signf(aim.x) * lunge_speed if aim.x != 0.0 else 0.0, 0.0)
	else:
		lunge.y *= 0.6
	if absf(lunge.x) > absf(velocity.x) or signf(lunge.x) != signf(velocity.x):
		velocity.x = lunge.x
	if not is_on_floor():
		velocity.y = lunge.y if lunge.y < 0.0 else maxf(velocity.y, lunge.y)
	var kind := String(swing.kind)
	var mag := float(swing.get("fx_scale", 1.0))
	var smear := String(swing.get("smear", ""))
	var aura := String(swing.get("aura", "rush_aura"))
	if kind == "thrust":
		Juice.fx(smear, _shoulder_world(), aim, facing, swing_dir < 0.0, null, mag)
		if aura != "":
			_free(_rush)
			_rush = Juice.fx(aura, TORSO, aim, 1.0, false, self)  # wind shell on the body during the rush
			_rush.set("life", 0.6)   # looping clip: a hard cap so it can never outlive the swing
	elif kind == "spin":
		# orbit in two layers so it wraps the body: back sheet behind, front sheet in front
		var c: Dictionary = Anim.effects.get(smear, {})
		if c.has("layers"):
			Juice.fx_layered(smear, TORSO, aim, facing, swing_dir < 0.0, self, mag)
		elif smear == "spin_whirl":
			Juice.fx("spin_whirl_back", TORSO, aim, facing, swing_dir < 0.0, self)
			Juice.fx("spin_whirl_front", TORSO, aim, facing, swing_dir < 0.0, self)
		else:
			Juice.fx(smear, TORSO, aim, facing, false, self, mag)
	else:
		_free(_gather)
		var dir := aim if kind == "front_burst" else Vector2.RIGHT
		Juice.fx(smear, _hand_world(), dir, facing, false, null, mag)
		Juice.shake(6.0, aim.x * 4.0)
	Juice.ghost(sprite, 0.12, 0.35)


## The player's hurt box in world space (feet-anchored, crouch lowers it).
func hurt_rect() -> Rect2:
	if dead:
		return Rect2()   # a body takes no hits
	var h := hurt_height()
	return Rect2(global_position.x - 10.0, global_position.y - h, 20.0, h)


func _free(n) -> void:  # untyped: a freed reference is a valid argument here
	if is_instance_valid(n):
		n.queue_free()


func _end_swing() -> void:
	_free(_gather)
	_free(_rush)
	if swing.is_empty():
		return
	swing_cooldown = float(swing.cooldown) + _recovery_extra
	swing = {}
	_recovery_extra = 0.0
	counter_armed = false


func press_jump() -> void:
	jump_buffer = JUMP_BUFFER


## Shift: dash toward dir (the cursor). Cancels swings; one air dash per flight.
func press_dash(dir: Vector2) -> bool:
	if action() != Action.FREE or dash_cooldown > 0.0:
		return false
	if not is_on_floor():
		if not air_dash_available:
			return false
		air_dash_available = false
	_end_swing()
	dash_dir = dir.normalized() if dir.length() > 0.01 else Vector2(facing, 0)
	if is_on_floor() and dash_dir.y > 0.0:
		if dash_dir.y > 0.7 and _on_ledge():
			_drop_through()   # a dash aimed down on a thin ledge falls through it
		else:
			dash_dir = Vector2(signf(dash_dir.x) if dash_dir.x != 0.0 else facing, 0)  # no dashing into the floor
	if dash_dir.x != 0.0:
		facing = signf(dash_dir.x)
	dash_remaining = DASH_DURATION
	dash_time = 0.0
	dash_cooldown = DASH_COOLDOWN
	crouching = false
	landing = 0.0
	if is_on_floor():
		Juice.fx("dash_burst", global_position + TORSO, dash_dir)
	else:
		Juice.fx("air_dash_spark", global_position + TORSO)
	_free(_aura)
	Juice.fx("dash_aura_in", TORSO, dash_dir, 1.0, false, self)  # one lead-in frame over the loop
	_aura = Juice.fx("dash_aura", TORSO, dash_dir, 1.0, false, self)
	return true



## 5. Space parry: one attempt per press, no buffer. Cancels a swing.
func press_parry(direction: float) -> bool:
	if action() != Action.FREE:
		return false
	_end_swing()
	parry_facing = signf(direction) if direction != 0.0 else facing
	facing = parry_facing
	parry_time = 0.0
	parry_ticks = 0
	parry_attempts += 1
	crouching = false
	if not is_on_floor():
		velocity.x *= CombatConfig.PARRY_AIR_SPEED_KEEP
	return true


## 10. 월식 (Q): grounded free, 내공 ≥ 60, gauge 100, no cooldown, no tremor.
func press_ultimate() -> bool:
	if action() != Action.FREE or swinging() or crouching:
		return false
	if not is_on_floor():
		_say("월식 · 지상에서만")
		return false
	if tremor_left > 0.0:
		_say("수전증 · 월식 불가")
		return false
	if ult_cooldown > 0.0:
		_say("월식 · 재사용 중")
		return false
	if gauge < CombatConfig.ULT_GAUGE_COST:
		_say("월식 · 게이지 부족")
		return false
	if qi < CombatConfig.ULT_QI_COST:
		_say("월식 · 내공 부족")
		return false
	qi -= CombatConfig.ULT_QI_COST
	gauge = 0.0
	rift = CombatConfig.RIFT_MAX
	rift_hold = CombatConfig.RIFT_DECAY_DELAY
	_update_erosion()
	ult_cooldown = CombatConfig.ULT_COOLDOWN
	ult_time = 0.0
	ult_burst_done = false
	velocity.x = 0.0
	return true


# ---------- resources ----------

func _add_rift(amount: float) -> void:
	rift = clampf(rift + amount, 0.0, CombatConfig.RIFT_MAX)
	if amount > 0.0:
		rift_hold = CombatConfig.RIFT_DECAY_DELAY
	_update_erosion()


func _update_erosion() -> void:
	if not eroded and rift >= CombatConfig.EROSION_ENTER:
		eroded = true
	elif eroded and rift <= CombatConfig.EROSION_EXIT:
		eroded = false


func overheated() -> bool:
	return eroded or rift >= CombatConfig.OVERHEAT_RIFT


func _end_ultimate(interrupted: bool) -> void:
	ult_time = -1.0
	tremor_left = CombatConfig.TREMOR_DURATION
	if interrupted:
		_say("월식 중단")


# ---------- tick ----------

func _try_jump() -> bool:
	if jump_buffer <= 0.0 or action() != Action.FREE:
		return false
	if is_on_floor() or coyote > 0.0:
		jump_buffer = 0.0
		coyote = 0.0
		velocity.y = -JUMP_SPEED
		air_time = 0.0
		landing = 0.0
		crouching = false
		jump_count += 1
		return true
	if air_jump_available:
		jump_buffer = 0.0
		air_jump_available = false
		velocity.y = -CombatConfig.AIR_JUMP_SPEED
		var move := Input.get_axis("move_left", "move_right")
		if move != 0.0:
			velocity.x = signf(move) * CombatConfig.AIR_JUMP_SIDE_SPEED
			facing = signf(move)
		air_time = 0.0
		air_jump_time = 0.16
		jump_count += 1
		Juice.fx("air_jump_fx", global_position + Vector2(0, 2))
		Juice.ghost(sprite, 0.18, 0.4)
		return true
	jump_buffer = 0.0
	return false


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_seen = true


func _shoulder_world() -> Vector2:
	return global_position + Anim.shoulder(_body_clip, _body_index, facing)


func _hand_world() -> Vector2:
	return _shoulder_world() + aim * 20.0


func _physics_process(dt: float) -> void:
	var move := 0.0 if input_locked else Input.get_axis("move_left", "move_right")
	var controls_walk := Input.is_action_pressed("walk") and not input_locked
	var controls_crouch := Input.is_action_pressed("crouch") and not input_locked
	var jump_held := Input.is_action_pressed("jump") and not input_locked
	if touch_mode:
		if not dead:
			aim = touch_aim.normalized() if touch_aim != Vector2.ZERO else Vector2(facing, 0)
		aim_point = _shoulder_world() + aim * 100.0
	else:
		if not dead and _mouse_seen:
			var to_mouse := get_global_mouse_position() - _shoulder_world()
			if to_mouse.length() > 1.0:
				aim = to_mouse.normalized()
		aim_point = get_global_mouse_position() if _mouse_seen else _shoulder_world() + aim * 100.0
	if not dead:
		# 2. same-tick priority: parry > dash > ultimate > heavy > jump > attack.
		var started := false
		if Input.is_action_just_pressed("parry"):
			started = press_parry(move)
		if not started and Input.is_action_just_pressed("dash"):
			var kdir := Vector2(move, -1.0 if jump_held else (1.0 if controls_crouch else 0.0))   # 잔월보 follows the keys, not the mouse
			started = press_dash(aim if touch_mode else (kdir if kdir != Vector2.ZERO else Vector2(facing, 0)))
		if not started and Input.is_action_just_pressed("ultimate"):
			started = press_ultimate()
		if not started and Input.is_action_just_pressed("heavy_attack"):
			started = press_heavy()
		if not started and Input.is_action_just_pressed("skill_pull"):
			started = press_pull()
		if Input.is_action_just_pressed("jump") and not (Input.is_action_just_pressed("interact") and _near_usable()):
			press_jump()   # W at a door/rest point/manual is the use, not a hop (the palm menu needs her on the floor)
		if Input.is_action_just_pressed("crouch") and is_on_floor() and _on_ledge():
			_drop_through()
		if not started and (Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("attack_key")):
			press_attack()
	if Juice.frozen():
		incoming.clear()
		_update_visual()
		return

	_resolve_incoming()

	clock += dt
	jump_buffer = maxf(0.0, jump_buffer - dt)
	dash_cooldown = maxf(0.0, dash_cooldown - dt)
	swing_cooldown = maxf(0.0, swing_cooldown - dt)
	combo_timer = maxf(0.0, combo_timer - dt)
	if combo_timer == 0.0 and not swinging():
		combo_count = 0
	landing = maxf(0.0, landing - dt)
	protect_left = maxf(0.0, protect_left - dt)
	counter_left = maxf(0.0, counter_left - dt)
	air_jump_time = maxf(0.0, air_jump_time - dt)
	notice_left = maxf(0.0, notice_left - dt)
	ult_cooldown = maxf(0.0, ult_cooldown - dt)
	tremor_left = maxf(0.0, tremor_left - dt)
	pull_cooldown = maxf(0.0, pull_cooldown - dt)
	purify_left = maxf(0.0, purify_left - dt)
	_step_purify_fx()
	if _drop_left > 0.0:
		_drop_left = maxf(0.0, _drop_left - dt)
		if _drop_left == 0.0:
			collision_mask = 3
	queue_redraw()
	pull_candidate = _pull_candidate() if combat_enabled and not dead and pull_cooldown == 0.0 and qi >= PULL_QI else null
	if pull_left > 0.0:
		_step_pull(dt)
	if not dead:
		qi = minf(CombatConfig.QI_MAX, qi + CombatConfig.QI_REGEN * dt)
		if rift_hold > 0.0:
			rift_hold = maxf(0.0, rift_hold - dt)
		elif rift > 0.0:
			rift = maxf(0.0, rift - CombatConfig.RIFT_DECAY_RATE * dt)
			_update_erosion()
	var grounded := is_on_floor()
	coyote = COYOTE if grounded else maxf(0.0, coyote - dt)
	var act := action()
	walking = controls_walk
	crouching = controls_crouch and grounded and act == Action.FREE and not swinging()

	if act == Action.FREE:
		_try_jump()

	match act:
		Action.DEAD, Action.HURT:
			if act == Action.HURT:
				hurt_left = maxf(0.0, hurt_left - dt)
			else:
				death_time += dt
			velocity.x = move_toward(velocity.x, 0.0, BRAKE * 0.5 * dt)
		Action.ULTIMATE:
			_step_ultimate(dt)
		Action.PARRY:
			parry_ticks += 1
			parry_time = parry_ticks / float(Engine.physics_ticks_per_second)
			if parry_time >= CombatConfig.PARRY_FAIL_END - EPS:
				parry_time = -1.0
				parry_ticks = -1
			if grounded:
				velocity.x = move_toward(velocity.x, 0.0, BRAKE * dt)
		Action.PARRY_RECOVERY:
			parry_recovery = maxf(0.0, parry_recovery - dt)
			if grounded:
				velocity.x = move_toward(velocity.x, 0.0, BRAKE * dt)
		Action.DASH:
			dash_time += dt
			dash_remaining = maxf(0.0, dash_remaining - dt)
			velocity = dash_dir * lerpf(DASH_SPEED, DASH_END_SPEED, minf(1.0, dash_time / DASH_DURATION))
			if dash_remaining == 0.0:
				velocity = dash_dir * RUN_SPEED
				_free(_aura)
				if is_on_floor():
					Juice.fx("dash_end", global_position, Vector2.RIGHT, facing)
		Action.FREE:
			if swinging():
				_step_swing(dt)
				velocity.x = move_toward(velocity.x, 0.0, BRAKE * 0.6 * dt)
			elif pull_left > 0.0:
				pass  # carried by the thread
			else:
				if move == 0.0 and grounded:
					facing = 1.0 if aim.x >= 0.0 else -1.0
				_step_move(dt, move, grounded)

	if dash_remaining > 0.0:
		pass  # dash ignores gravity
	elif not grounded:
		air_time += dt
		if not jump_held and velocity.y < -JUMP_CUT:
			velocity.y = -JUMP_CUT
		velocity.y += (RISE_GRAVITY if velocity.y < 0.0 else FALL_GRAVITY) * dt
	elif velocity.y > 0.0:
		velocity.y = 0.0

	move_and_slide()
	global_position.x = clampf(global_position.x, world_min_x, world_max_x)

	if is_on_floor() and not _was_on_floor:
		air_jump_available = true
		air_dash_available = true
		landing = 0.10
		Juice.fx("land_dust", global_position + Vector2(0, -2))
	_was_on_floor = is_on_floor()

	_ghost_tick += 1
	if dash_remaining > 0.0:
		Juice.ghost(sprite, 0.16, 0.35)  # every tick: a solid trail instead of a drawn streak
	elif swinging() and swing_t >= 0.0:
		if _ghost_tick % 2 == 0:
			Juice.ghost(sprite, 0.14, 0.3)
	elif absf(velocity.x) > 300.0 and _ghost_tick % 5 == 0:
		Juice.ghost(sprite, 0.08, 0.1)

	_update_visual()


func _step_swing(dt: float) -> void:
	swing_t += dt
	if not _lunged and swing_t >= 0.0:
		_release_swing()
	var kind := String(swing.kind)
	var window_end: float = float(swing.time) * (0.95 if kind == "spin" else (0.5 if kind in ["burst", "front_burst"] else 0.7))
	if swing_t >= 0.0 and swing_t < window_end:
		_check_hits()
	if kind in ["burst", "front_burst"] and swing_t < 0.0 and _ghost_tick % 4 == 0:
		Juice.ghost(sprite, 0.2, 0.2)  # gathering: pulsing afterimages
	if swing_t >= float(swing.time):
		_end_swing()


func _step_move(dt: float, move: float, grounded: bool) -> void:
	var speed := CROUCH_SPEED if crouching else (WALK_SPEED if walking else RUN_SPEED)
	if move != 0.0:
		if velocity.x * move < 0.0:
			velocity.x = 0.0
		facing = signf(move)
	var accel := (AIR_ACCEL if not grounded else ACCEL) if move != 0.0 else BRAKE
	velocity.x = move_toward(velocity.x, move * speed, accel * dt)
	if absf(velocity.x) > 1.0:
		var cycle := 40.0 if crouching else (70.0 if walking else RUN_CYCLE)
		gait = fmod(gait + absf(velocity.x * dt) / cycle, 1.0)
		if grounded and not walking and not crouching and int(gait * 2.0) != int(prev_gait * 2.0):
			Juice.fx("run_dust", global_position + Vector2(-facing * 6, 0), Vector2.RIGHT, facing)
		prev_gait = gait


## 10. 월식: 0.30 s prep → one burst → recovery to 0.85 s.
func _step_ultimate(dt: float) -> void:
	var before := ult_time
	ult_time += dt
	velocity.x = 0.0
	if not ult_burst_done and before < CombatConfig.ULT_PREP and ult_time >= CombatConfig.ULT_PREP:
		ult_burst_done = true
		_ultimate_burst()
	if ult_time >= CombatConfig.ULT_TOTAL - EPS:
		_end_ultimate(false)


func _ultimate_burst() -> void:
	var centre := global_position + TORSO
	attack_instance += 1
	Juice.ultimate_ring(centre, CombatConfig.ULT_RADIUS)
	Juice.hitstop(0.10)
	Juice.shake(10.0, 0.0)
	var a := {"damage": CombatConfig.ULT_DIRECT, "injury_burst": true, "burst_per_stack": CombatConfig.ULT_BURST_PER_STACK * (PURIFY_BURST_RATE if purified() else 1.0)}
	for d in get_tree().get_nodes_in_group("enemy"):
		if d.has_method("invulnerable") and d.invulnerable():
			continue
		var base: Vector2 = d.global_position
		var hw := _half_w(d)
		var nearest := Vector2(clampf(centre.x, base.x - hw, base.x + hw), clampf(centre.y, base.y + d.hurt_top, base.y))
		if nearest.distance_to(centre) > CombatConfig.ULT_RADIUS:
			continue
		var r := CombatResolver.resolve_outgoing(a, d.status, "%d:%d" % [attack_instance, d.get_instance_id()], false)
		if r.kind == CombatResolver.Kind.IGNORED:
			continue
		hits += 1
		damage += r.hp_damage
		d.on_hit(r, signf(base.x - centre.x) if base.x != centre.x else facing, 20.0)
		Juice.damage_number(base, r.hp_damage)


# ---------- player → enemy ----------

const HURT_HALF_W := 12.0

func _check_hits() -> void:
	var a := swing
	var atk := a
	var rate := (_burst_rate if bool(a.get("is_heavy", false)) else 1.0) * (PURIFY_BURST_RATE if purified() else 1.0)
	if bool(a.get("injury_burst", false)) and rate != 1.0:
		atk = a.duplicate()
		atk.burst_per_stack = float(a.get("burst_per_stack", CombatConfig.BURST_PER_STACK)) * rate
	var shoulder := _shoulder_world()
	var kind := String(a.kind)
	var centre := _hand_world() if kind in ["burst", "front_burst"] else shoulder
	var single := String(a.get("targets", "multi")) == "single"
	var targets: Array = get_tree().get_nodes_in_group("enemy")
	if single:
		# 투골장: the nearest enemy in front, chosen at the moment of the strike (기획 §5)
		var best: Node = null
		var bd := INF
		for d in targets:
			var dxs: float = (d.global_position.x - global_position.x) * facing
			if dxs < -4.0:
				continue
			var dd: float = absf(d.global_position.x - global_position.x)
			if dd < bd:
				bd = dd
				best = d
		targets = [best] if best != null else []
	for d in targets:
		if d.has_method("invulnerable") and d.invulnerable():
			continue  # phase change: no damage, no injury, no gauge
		var base: Vector2 = d.global_position
		var top: float = d.hurt_top
		var hw := _half_w(d)
		if kind == "front_burst" and (base.x - global_position.x) * facing < -hw:
			continue  # 쇄진장·투골장 발경: no judgement behind the body
		var probes: Array = []
		if kind == "thrust":
			for k in [0.4, 0.7, 1.0]:
				probes.append(shoulder + aim * float(a.reach) * float(k))
		else:
			# radial: nearest point of the hurt box to the centre, if inside reach
			var nearest := Vector2(clampf(centre.x, base.x - hw, base.x + hw), clampf(centre.y, base.y + top, base.y))
			if nearest.distance_to(centre) <= float(a.reach):
				probes.append(nearest)
		for p in probes:
			if kind == "thrust" and (absf(p.x - base.x) > hw or p.y < base.y + top or p.y > base.y):
				continue
			var r := CombatResolver.resolve_outgoing(atk, d.status, "%d:%d" % [attack_instance, d.get_instance_id()], counter_armed)
			if r.kind == CombatResolver.Kind.IGNORED:
				break
			hits += 1
			damage += r.hp_damage
			if r.hp_damage > 0 and not _gauge_given:
				_gauge_given = true
				gauge = minf(100.0, gauge + CombatConfig.GAUGE_PER_ATTACK)
			var push := signf(aim.x) if aim.x != 0.0 else facing
			var out_dir: Vector2 = (Vector2(base.x, base.y + top * 0.5) - centre).normalized() if kind != "thrust" else aim
			if out_dir.length() < 0.1:
				out_dir = aim
			if bool(a.get("push_normal", false)):
				push = signf(base.x - global_position.x) if base.x != global_position.x else facing  # 회란장: outward
			var kick_px := float(a.kick)
			if d.get("status") != null and d.status.is_boss:
				kick_px = minf(kick_px, 6.0)  # bosses are never displaced by the player (기획 §5)
			d.on_hit(r, push, kick_px)
			Juice.flash(p, 7.0 if kind == "burst" else 5.0)
			Juice.fx(String(a.fx), p, out_dir, facing, false, null, float(a.get("fx_scale", 1.0)))
			Juice.hitstop(float(a.hit_stop))
			Juice.shake(float(a.shake), push * 5.0)
			Juice.ghost(sprite, 0.16, 0.45)
			Juice.damage_number(base, r.hp_damage)
			break


# ---------- enemy → player ----------

func parry_elapsed() -> float:
	return parry_time


## Height of the hurt box above the feet; crouching ducks under P2_D's 40px floor.
func hurt_height() -> float:
	return 30.0 if crouching else 46.0


## Enemies may be wider than the default 12px half width (the boss is 22).
static func _half_w(d: Node) -> float:
	var v = d.get("hurt_half_width")
	return float(v) if v != null else HURT_HALF_W


func protected_from(hit: HitEvent) -> bool:
	if hit.ignore_invulnerability:
		return false
	if protect_left > 0.0:
		return true
	if dash_remaining > 0.0 and dash_time >= CombatConfig.DASH_IFRAME_START and dash_time < CombatConfig.DASH_IFRAME_END:
		return true
	if ult_time >= CombatConfig.ULT_IFRAME_START and ult_time < CombatConfig.ULT_IFRAME_END:
		return true
	return false


func receive_hit(hit: HitEvent) -> void:
	incoming.append(hit)


func _resolve_incoming() -> void:
	if incoming.is_empty():
		return
	incoming.sort_custom(func(a, b): return a.instance_id < b.instance_id if a.instance_id != b.instance_id else a.hit_id < b.hit_id)
	for hit in incoming:
		var r := CombatResolver.resolve_incoming(hit, self)
		_apply_incoming(hit, r)
	incoming.clear()


func _apply_incoming(hit: HitEvent, r: Dictionary) -> void:
	var away := signf(global_position.x - hit.origin.x)
	if away == 0.0:
		away = -parry_facing if parry_time >= 0.0 else -facing
	if hit.projectile and is_instance_valid(hit.projectile) and r.kind in [CombatResolver.Kind.IGNORED, CombatResolver.Kind.INVULNERABLE]:
		hit.projectile.on_resolved(r.kind)
	match r.kind:
		CombatResolver.Kind.IGNORED, CombatResolver.Kind.INVULNERABLE:
			if r.kind == CombatResolver.Kind.INVULNERABLE:
				last_parry = "INVULNERABLE %s" % hit.label
			return
		CombatResolver.Kind.PERFECT:
			last_parry = "PERFECT t=%.3f %s posture+%d" % [r.elapsed, hit.label, int(r.posture_added)]
			parry_time = -1.0
			parry_ticks = -1
			parry_recovery = CombatConfig.PARRY_PERFECT_RECOVERY
			protect_left = CombatConfig.PROTECT_PERFECT
			qi = minf(CombatConfig.QI_MAX, qi + CombatConfig.PERFECT_QI)
			_add_rift(CombatConfig.PERFECT_RIFT)
			gauge = minf(100.0, gauge + CombatConfig.PERFECT_GAUGE)
			counter_left = CombatConfig.COUNTER_WINDOW
			if hit.attacker and hit.attacker.has_method("on_parried"):
				hit.attacker.on_parried(r.posture_added)
			Juice.fx("parry_perfect_fx", hit.origin)
			Juice.hitstop(CombatConfig.HITSTOP_PERFECT)
			Juice.shake(3.0, -away * 3.0)
		CombatResolver.Kind.PARTIAL:
			last_parry = "PARTIAL t=%.3f %s dmg=%d" % [r.elapsed, hit.label, r.hp_damage]
			parry_time = -1.0
			parry_ticks = -1
			_take_damage(r.hp_damage)
			if not dead:
				parry_recovery = CombatConfig.PARRY_PARTIAL_RECOVERY
				protect_left = CombatConfig.PROTECT_PARTIAL
				velocity.x = away * r.knockback
				counter_left = 0.0
			Juice.fx("parry_partial_fx", hit.origin, Vector2.RIGHT, parry_facing)
			Juice.hitstop(CombatConfig.HITSTOP_PARTIAL)
			Juice.damage_number(global_position, r.hp_damage)
		CombatResolver.Kind.NORMAL:
			last_parry = "HIT t=%.3f %s dmg=%d" % [r.elapsed, hit.label, r.hp_damage]
			parry_time = -1.0
			parry_ticks = -1
			parry_recovery = 0.0
			if ult_time >= 0.0:
				_end_ultimate(true)
			_end_swing()
			_take_damage(r.hp_damage)
			if not dead:
				hurt_left = hit.hitstun
				protect_left = CombatConfig.PROTECT_HURT
				velocity.x = away * r.knockback
				counter_left = 0.0
			if hit.hit_fx != "":
				Juice.fx(hit.hit_fx, global_position + TORSO, Vector2(-away, 0))
			Juice.hitstop(0.05)
			Juice.shake(4.0, away * 4.0)
			Juice.damage_number(global_position, r.hp_damage)
	if hit.projectile and is_instance_valid(hit.projectile):
		hit.projectile.on_resolved(r.kind)


func _take_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)
	if hp == 0 and not dead:
		dead = true
		death_time = 0.0
		_end_swing()
		parry_time = -1.0
		parry_recovery = 0.0
		hurt_left = 0.0
		ult_time = -1.0
		velocity.x = 0.0


# ---------- visuals ----------

## Body clip + local frame for the current state.
func _pick_body() -> Array:
	match action():
		Action.DEAD:
			return ["death", mini(int(death_time / 0.12), 2)]
		Action.HURT:
			return ["hurt", 0]
		Action.ULTIMATE:
			return ["parry", 1 if ult_time >= CombatConfig.ULT_PREP else 0]
		Action.PARRY:
			return ["parry", 0]
		Action.PARRY_RECOVERY:
			return ["parry", 1]
		Action.DASH:
			return ["dash", 0 if dash_time < DASH_DURATION * 0.6 else 1]
	if not is_on_floor():
		if air_jump_time > 0.0 or velocity.y < -60.0:
			return ["jump", 0]
		if velocity.y < 60.0:
			return ["jump", 1]
		return ["jump", 2]
	if landing > 0.0 and absf(velocity.x) < 1.0:
		return ["land", 0]
	if crouching:
		return ["crouch", int(gait * 2.0) % 2 if absf(velocity.x) > 1.0 else 0]
	if absf(velocity.x) > 1.0:
		return ["run", int(gait * 6.0) % 6]
	return ["idle", int(clock / 0.36) % 2]


func phase() -> String:
	match action():
		Action.DEAD:
			return "사망"
		Action.HURT:
			return "피격"
		Action.ULTIMATE:
			return "월식 · %s" % ("준비" if ult_time < CombatConfig.ULT_PREP else "회수")
		Action.PARRY:
			var w := "완전" if parry_time < CombatConfig.PARRY_PERFECT_END else ("부분" if parry_time < CombatConfig.PARRY_PARTIAL_END else "실패 회수")
			return "패링 · %s %.3f" % [w, parry_time]
		Action.PARRY_RECOVERY:
			return "패링 성공 회수"
		Action.DASH:
			return "잔월보"
	if swinging():
		return "%s%s · %s" % [swing.name, "(반격)" if counter_armed else "", "준비" if swing_t < 0.0 else "타격"]
	if not is_on_floor():
		return "점프" if air_jump_available else "허공답월"
	if crouching:
		return "앉기"
	if absf(velocity.x) > 1.0:
		return "걷기" if walking else "보법 달리기"
	return "대기"


func _update_visual() -> void:
	var pick := _pick_body()
	_body_clip = pick[0]
	_body_index = pick[1]
	sprite.frame = Anim.slot(_body_clip, _body_index)
	sprite.flip_h = facing < 0.0
	sprite.position = Vector2(randf_range(-1.5, 1.5), 0) if Juice.frozen() else Vector2.ZERO
	sprite.modulate = Color(1, 0.6, 0.6) if action() == Action.HURT else Color.WHITE
	var act := action()
	if act != Action.DASH:
		_free(_aura)
	var shoulder := Anim.shoulder(_body_clip, _body_index, facing)
	# Arm: hidden while hurt/dead/ultimate; the guard piece replaces it while parrying.
	var guarding := act in [Action.PARRY, Action.PARRY_RECOVERY]
	arm_root.visible = act in [Action.FREE, Action.DASH]
	guard.visible = guarding
	guard.position = shoulder
	guard.scale = Vector2(ARM_SCALE * facing, ARM_SCALE)
	if arm_root.visible:
		arm_root.position = shoulder
		arm_root.scale = Vector2(1, -1 if facing < 0.0 else 1)
		var offset := 0.0
		if swinging():
			var arc := deg_to_rad(float(swing.arc))
			var kind := String(swing.kind)
			if kind in ["burst", "front_burst"]:
				if swing_t < 0.0:
					offset = PI * 0.75 * (1.0 - (-swing_t) / float(swing.windup) * 0.4)  # pulled to the chest while gathering
				else:
					offset = 0.0  # thrust the palm out
			elif kind == "spin":
				offset = swing_dir * TAU * clampf(swing_t / float(swing.time), 0.0, 1.0)
			else:
				offset = swing_dir * lerpf(-arc * 0.5, arc * 0.5, clampf(swing_t / float(swing.time), 0.0, 1.0))
		arm_root.rotation = aim.angle() + offset
		var palm := swinging()
		Anim.part_frame(hand, "hand_palm" if palm else "hand_open", 0)
		var big := swinging() and String(swing.kind) in ["burst", "front_burst"]
		qi_fx.visible = swinging()
		if qi_fx.visible:
			Anim.part_frame(qi_fx, "qi_moon" if big else "qi_palm", int(clock * 12.0))
			var pulse := 1.0
			if big and swing_t < 0.0:
				pulse = 1.0 + 0.6 * (1.0 - (-swing_t) / float(swing.windup))  # grows while gathering
			qi_fx.scale = Vector2(pulse, pulse)
