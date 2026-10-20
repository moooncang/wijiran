extends "res://src/enemies/enemy_base.gd"
class_name BossBase
## Generic boss runner (본편 §10 공통 골격): IDLE → PATTERN(telegraph → strikes → recover) → next,
## with STAGGER / PHASE / DEAD from anywhere. Patterns are data (see patterns()):
##   {"name", "dmin", "dmax", "recover", "cooldown", "weight", "late_only", "early_only", "chain_to",
##    "move": true,            # counts as a reposition: never two in a row (§5 거리 벌리기 연속 금지)
##    "strikes": [{"t", "dur", "shape": F|B|MOVE|PROJ|WAVE, ...}],
##    "moves": [{"from", "to", "dist"|"to_perch", "leap"}], "retargets": [t], "variant_of": id}
## Strike shapes: F(w,h,z) forward box, B(r,h,z) both sides, MOVE = F that follows the boss,
## PROJ {count, spread, speed, raw} arrows toward the aim locked at (t - lock_lead),
## WAVE {w, h, speed, travel} a floor box travelling forward for `travel` seconds.
## Telegraphs: hitbox-exact translucent red dot fields that fill in toward the strike; PROJ draws the
## locked aim line; head icon per class. Hit times are data, never animation.

const N := CombatConfig.ParryClass.NORMAL
const H := CombatConfig.ParryClass.PERFECT_ONLY
const U := CombatConfig.ParryClass.UNPARRYABLE
const STRIKE_DURATION := 0.08
const FLASH_LEAD := 0.12
const KNOCKBACK := {N: 100.0, H: 160.0, U: 80.0}
const POSTURE := {N: 25.0, H: 40.0, U: 0.0}
const PLAYER_HALF_W := 10.0

enum State { INTRO, IDLE, PATTERN, STAGGER, DEAD }

var max_hp := 600.0
var armor := 0.10
var late_fraction := 0.6             # §10: late pattern set from the next decision after HP ≤ 60%
var decision_wait := 0.45
var intro_time := 0.8
var stagger_time := 2.0
var arena_left := 0.0
var arena_right := 800.0
var perches: Array = []              # Vector2 landing spots for to_perch moves
var rng := RandomNumberGenerator.new()
var seed_value := 0
var state: int = State.INTRO
var state_time := 0.0
var late := false
var beaten := false
var fx_scale := 1.0                  # bosses: effect clips drawn this many times larger
var _rain: Array = []                # [{x, t_hit, hit_id, s, done}] falling arrow columns

var pattern_id := ""
var pattern: Dictionary = {}
var pattern_time := 0.0
var pattern_end := 0.0
var _fired: Dictionary = {}
var _flashed: Dictionary = {}
var _fx_done: Dictionary = {}
var _retargets_done: Dictionary = {}
var _waves: Array = []               # [{rect, vx, left, hit_id, s}]
var _aim: Vector2 = Vector2.LEFT
var _aim_locked := false
var cooldowns: Dictionary = {}
var seen: Dictionary = {}
var recent: Array = []
var last_was_move := false
var variation_counter := 0
var log_lines: Array = []
var _chain_next := ""


func _setup() -> void:
	status.is_boss = true
	status.max_hp = max_hp
	status.hp = max_hp
	status.armor_rate = armor
	seed_value = int(Time.get_ticks_usec() % 1000000)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_value = int(a.substr(7))
	rng.seed = seed_value
	_boss_setup()


func _boss_setup() -> void:
	pass


## Subclasses return their pattern table.
func patterns() -> Dictionary:
	return {}


func reset_state() -> void:
	super()
	status.max_hp = max_hp
	status.hp = max_hp
	state = State.INTRO
	state_time = 0.0
	late = false
	beaten = false
	_cancel_pattern()
	cooldowns.clear()
	seen.clear()
	recent.clear()
	last_was_move = false
	variation_counter = 0
	_chain_next = ""
	for w in _waves:
		pass
	_waves.clear()


func activate(p: Player) -> void:
	super(p)
	state = State.INTRO
	state_time = 0.0


func invulnerable() -> bool:
	return not active or not status.alive() or beaten


# ---------- hits ----------

func _on_damaged(_r: Dictionary, _push: float) -> void:
	if not late and status.hp <= max_hp * late_fraction and status.alive():
		late = true
		_on_late()


func _on_late() -> void:
	pass


func _on_death() -> void:
	beaten = true
	_cancel_pattern()
	_enter(State.DEAD)
	for pr in get_tree().get_nodes_in_group("projectile"):
		if pr.get("shooter") == self:
			pr.queue_free()
	_waves.clear()
	_rain.clear()


func _on_stagger() -> void:
	_cancel_pattern()
	for pr in get_tree().get_nodes_in_group("projectile"):
		if pr.get("shooter") == self:
			pr.queue_free()
	_waves.clear()
	_rain.clear()
	status.stagger_left = stagger_time
	_enter(State.STAGGER)


func _enter(s: int) -> void:
	state = s
	state_time = 0.0
	_on_state(s)
	queue_redraw()


func _on_state(_s: int) -> void:
	pass


# ---------- tick ----------

func _ai(dt: float) -> void:
	state_time += dt
	for k in cooldowns.keys():
		cooldowns[k] = maxf(0.0, cooldowns[k] - dt)
	_step_waves(dt)
	_step_rain(dt)
	match state:
		State.INTRO:
			if state_time >= intro_time:
				_enter(State.IDLE)
		State.IDLE:
			facing = -1.0 if player.global_position.x < global_position.x else 1.0
			if _chain_next != "" or state_time >= decision_wait:
				_decide()
		State.PATTERN:
			_step_pattern(dt)
		State.STAGGER:
			if not status.staggered():
				_enter(State.IDLE)
		State.DEAD:
			pass


func _distance_ok(id: String) -> bool:
	var p: Dictionary = patterns()[id]
	var d := absf(player.global_position.x - global_position.x)
	return d >= float(p.get("dmin", 0.0)) and d <= float(p.get("dmax", 9999.0))


func _candidates() -> Array:
	var out: Array = []
	var table := patterns()
	for id in table:
		var p: Dictionary = table[id]
		if p.has("variant_of"):
			continue
		if bool(p.get("late_only", false)) and not late:
			continue
		if bool(p.get("early_only", false)) and late:
			continue
		if cooldowns.get(id, 0.0) > 0.0 or not _distance_ok(id):
			continue
		if bool(p.get("move", false)) and last_was_move:
			continue
		out.append(id)
	return out


## §9-style selection: chained follow-ups first, then unseen patterns, then a weighted roll that
## skips the previous pattern; a variation replaces a base pattern every third pick once all are seen.
func _decide() -> void:
	if _chain_next != "" and _distance_ok(_chain_next):
		var cid := _chain_next
		_chain_next = ""
		_start_pattern(cid)
		return
	_chain_next = ""
	var cands := _candidates()
	if cands.is_empty():
		state_time = decision_wait * 0.5
		return
	var pool: Array = []
	for id in cands:
		if recent.is_empty() or recent[-1] != id:
			pool.append(id)
	if pool.is_empty():
		pool = cands
	var unseen: Array = []
	for id in pool:
		if not seen.has(id):
			unseen.append(id)
	if not unseen.is_empty():
		pool = unseen
	var id := _weighted_pick(pool)
	if unseen.is_empty():
		variation_counter += 1
		if variation_counter >= 3:
			var v := _variation_for(id)
			if v != "":
				id = v
				variation_counter = 0
	_start_pattern(id)


func _variation_for(id: String) -> String:
	var table := patterns()
	for k in table:
		if String(table[k].get("variant_of", "")) == id:
			return k
	return ""


func _weighted_pick(pool: Array) -> String:
	var table := patterns()
	var total := 0.0
	for id in pool:
		total += float(table[id].get("weight", 1.0))
	var roll := rng.randf() * total
	for id in pool:
		roll -= float(table[id].get("weight", 1.0))
		if roll <= 0.0:
			return id
	return pool[-1]


func _start_pattern(id: String) -> void:
	var table := patterns()
	pattern_id = id
	pattern = table[id].duplicate(true)
	pattern_time = 0.0
	instance += 1
	_fired.clear()
	_flashed.clear()
	_fx_done.clear()
	_retargets_done.clear()
	_aim_locked = false
	for m in pattern.get("moves", []):
		m.erase("px")
	var strikes: Array = pattern.strikes
	for i in strikes.size():
		var s: Dictionary = strikes[i]
		s.id = i + 1
		if not s.has("dur"):
			s.dur = STRIKE_DURATION
	var last: Dictionary = strikes[-1]
	pattern_end = float(last.t) + float(last.dur) + float(pattern.get("recover", 0.8))
	facing = -1.0 if player.global_position.x < global_position.x else 1.0
	var base_id := String(pattern.get("variant_of", id))
	cooldowns[base_id] = float(pattern.get("cooldown", 2.0))
	seen[base_id] = true
	recent.append(base_id)
	if recent.size() > 3:
		recent.pop_front()
	last_was_move = bool(pattern.get("move", false))
	log_lines.append(id)
	_enter(State.PATTERN)


func _cancel_pattern() -> void:
	pattern_id = ""
	pattern = {}
	_chain_next = ""
	queue_redraw()


func _finish_pattern() -> void:
	var chain := String(pattern.get("chain_to", "")) if late else ""
	_cancel_pattern()
	_chain_next = chain   # after the cancel, which clears it
	_enter(State.IDLE)


func _step_pattern(dt: float) -> void:
	var before := pattern_time
	pattern_time += dt
	for m in pattern.get("moves", []):
		var f := float(m.from)
		var to := float(m.to)
		if m.has("to_perch"):
			if before < f and pattern_time >= f:
				_teleport_to_perch(m)
			continue
		if pattern_time > f and before < to:
			if not m.has("px"):
				m.px = _resolve_dist(m)
				facing = -1.0 if player.global_position.x < global_position.x else 1.0
			var dist := float(m.px)
			var seg_dt := minf(pattern_time, to) - maxf(before, f)
			global_position.x = clampf(global_position.x + facing * dist / (to - f) * seg_dt, arena_left, arena_right)
			if m.has("leap"):
				var u := clampf((pattern_time - f) / (to - f), 0.0, 1.0)
				global_position.y = ground_y - 4.0 * float(m.leap) * u * (1.0 - u)
		if pattern_time >= to and before < to and m.has("leap"):
			global_position.y = ground_y
	for rt in pattern.get("retargets", []):
		if not _retargets_done.has(rt) and pattern_time >= float(rt):
			_retargets_done[rt] = true
			facing = -1.0 if player.global_position.x < global_position.x else 1.0
	for s in pattern.strikes:
		var t := float(s.t)
		var dur := float(s.dur)
		var hid := int(s.id)
		var shape := String(s.shape)
		if shape == "PROJ" and not _aim_locked and pattern_time >= t - float(s.get("lock_lead", 0.15)):
			_aim = (player.global_position + Vector2(0, -24) - _muzzle()).normalized()
			_aim_locked = true
		if not _flashed.has(hid) and pattern_time >= t - FLASH_LEAD:
			_flashed[hid] = true
			_strike_flash(s)
		if not _fx_done.has(hid) and pattern_time >= t:
			_fx_done[hid] = true
			_strike_fx(s)
			match shape:
				"PROJ":
					_fire_volley(s)
				"WAVE":
					_waves.append({"rect": _wave_rect(s, global_position.x), "vx": facing * float(s.speed), "left": float(s.travel), "hit_id": hid, "s": s})
					if bool(s.get("both", false)):
						var back: Dictionary = s.duplicate()
						var r2 := _wave_rect(s, global_position.x)
						r2.position.x = global_position.x - (12.0 if facing > 0.0 else -12.0 - float(s.get("w", 40.0))) - (float(s.get("w", 40.0)) if facing > 0.0 else 0.0)
						_waves.append({"rect": r2, "vx": -facing * float(s.speed), "left": float(s.travel), "hit_id": hid * 100, "s": back})
				"RAIN":
					_start_rain(s)
		if shape in ["F", "B", "MOVE"] and pattern_time >= t and pattern_time < t + dur and not _fired.has(hid):
			if _zone_rect(s).intersects(player.hurt_rect()):
				_fired[hid] = true
				_deliver(s, _zone_origin(s))
	if pattern_time >= pattern_end:
		_finish_pattern()
	queue_redraw()


func _teleport_to_perch(m: Dictionary) -> void:
	if perches.is_empty():
		return
	# the perch farthest from the player, never the one we stand on
	var best := Vector2.ZERO
	var bd := -1.0
	for p in perches:
		if (p as Vector2).distance_to(global_position) < 8.0:
			continue
		var d: float = absf((p as Vector2).x - player.global_position.x)
		if d > bd:
			bd = d
			best = p
	if bd < 0.0:
		return
	Juice.fx("backstep_dust", global_position, Vector2(facing, 0))
	global_position = best
	ground_y = best.y
	facing = -1.0 if player.global_position.x < global_position.x else 1.0
	Juice.fx("land_dust", global_position)
	_on_perch()


func _on_perch() -> void:
	pass


func _resolve_dist(m: Dictionary) -> float:
	var d = m.dist
	if d is float or d is int:
		return float(d)
	var dx := absf(player.global_position.x - global_position.x)
	match String(d):
		"player":
			return maxf(0.0, dx - float(m.get("gap", 24.0)))
		_:
			return dx + float(m.get("gap", 70.0))


## 잿비: pick the safe columns, then every other column gets a falling arrow 0.55 s later.
func _start_rain(s: Dictionary) -> void:
	var n := int(s.get("columns", 7))
	var safe := int(s.get("safe", 2))
	var safes: Array = []
	while safes.size() < safe:
		var c := rng.randi() % n
		if not safes.has(c):
			safes.append(c)
	var w := (arena_right - arena_left) / float(n)
	for i in n:
		_rain.append({"x": arena_left + (i + 0.5) * w, "w": w, "t_hit": 0.55, "safe": safes.has(i), "hit_id": int(s.id) * 1000 + i, "s": s, "fired": false})


func _step_rain(dt: float) -> void:
	var keep: Array = []
	for r in _rain:
		r.t_hit -= dt
		if r.t_hit <= 0.0 and not r.fired and not r.safe:
			r.fired = true
			var p := Node2D.new()
			p.set_script(preload("res://src/enemies/projectile.gd"))
			p.position = Vector2(r.x, ground_y - float(r.s.get("h", 400.0)))
			p.velocity = Vector2(0, float(r.s.get("speed", 800.0)))
			p.shooter = self
			p.radius = 7.0
			var hit := HitEvent.new()
			hit.attacker = self
			hit.instance_id = instance
			hit.hit_id = int(r.hit_id)
			hit.raw_direct = float(r.s.raw)
			hit.knockback = float(KNOCKBACK[int(r.s.cls)])
			hit.parry_class = int(r.s.cls)
			hit.posture_damage = 0.0
			hit.label = "%s" % pattern.get("name", "잿비")
			p.hit = hit
			get_parent().add_child(p)
		if r.t_hit > -0.6:
			keep.append(r)
	_rain = keep


func _step_waves(dt: float) -> void:
	var keep: Array = []
	for w in _waves:
		w.left -= dt
		var r: Rect2 = w.rect
		r.position.x += float(w.vx) * dt
		w.rect = r
		if r.intersects(player.hurt_rect()) and not _fired.has(int(w.hit_id)):
			_fired[int(w.hit_id)] = true
			_deliver(w.s, Vector2(r.get_center().x, ground_y))
		if w.left > 0.0 and r.position.x > arena_left - 100.0 and r.end.x < arena_right + 100.0:
			keep.append(w)
	_waves = keep


# ---------- geometry ----------

func _zone_rect(s: Dictionary) -> Rect2:
	var gy := ground_y
	var gx := global_position.x
	var h := float(s.get("h", 40.0))
	var z := float(s.get("z", 0.0))
	match String(s.shape):
		"F", "MOVE":
			var w := float(s.w)
			var x0 := gx + (12.0 if facing > 0.0 else -w)
			return Rect2(x0, gy - z - h, w - 12.0, h)
		"B":
			var r := float(s.r)
			return Rect2(gx - r, gy - z - h, r * 2.0, h)
	return Rect2()


func _wave_rect(s: Dictionary, x: float) -> Rect2:
	var w := float(s.get("w", 40.0))
	var h := float(s.get("h", 22.0))
	return Rect2(x + (12.0 if facing > 0.0 else -12.0 - w), ground_y - h, w, h)


func _zone_origin(s: Dictionary) -> Vector2:
	if int(s.cls) == U:
		var r := _zone_rect(s)
		return Vector2(clampf(player.global_position.x, r.position.x, r.end.x), ground_y)
	return global_position + _anchor("staff_tip")


func _anchor(_key: String) -> Vector2:
	return Vector2(facing * 20.0, -40.0)


func _muzzle() -> Vector2:
	return global_position + _anchor("muzzle")


func _deliver(s: Dictionary, origin: Vector2) -> void:
	var hit := HitEvent.new()
	hit.attacker = self
	hit.instance_id = instance
	hit.hit_id = int(s.id)
	hit.origin = origin
	hit.direction = Vector2(facing, 0)
	hit.raw_direct = float(s.raw)
	hit.knockback = float(KNOCKBACK[int(s.cls)])
	hit.hitstun = CombatConfig.HURT_STUN
	hit.parry_class = int(s.cls)
	hit.posture_damage = float(POSTURE[int(s.cls)])
	hit.hit_fx = String(s.get("hit_fx", ""))
	hit.label = "%s#%d" % [pattern.name, int(s.id)]
	player.receive_hit(hit)


func _fire_volley(s: Dictionary) -> void:
	var count := int(s.get("count", 1))
	var spread := deg_to_rad(float(s.get("spread", 0.0)))
	for i in count:
		var ang := 0.0 if count == 1 else lerpf(-spread, spread, float(i) / float(count - 1))
		var p := Node2D.new()
		p.set_script(preload("res://src/enemies/projectile.gd"))
		p.position = _muzzle()
		p.velocity = _aim.rotated(ang) * float(s.get("speed", 480.0))
		p.shooter = self
		p.color = Color(s.get("color", Color(0.85, 0.9, 0.7)))
		p.radius = 5.0 * maxf(1.0, fx_scale * 0.6)
		var hit := HitEvent.new()
		hit.attacker = self
		hit.instance_id = instance
		hit.hit_id = int(s.id) * 10 + i
		hit.raw_direct = float(s.raw)
		hit.knockback = float(KNOCKBACK[int(s.cls)])
		hit.parry_class = int(s.cls)
		hit.posture_damage = float(s.get("posture", POSTURE[int(s.cls)]))
		hit.label = "%s#%d" % [pattern.name, int(s.id)]
		p.hit = hit
		get_parent().add_child(p)


func _strike_flash(s: Dictionary) -> void:
	if String(s.shape) == "PROJ":
		Juice.fx("mark_flash", _muzzle())
	else:
		Juice.fx("mark_flash", _zone_origin(s))


func _strike_fx(_s: Dictionary) -> void:
	pass


# ---------- telegraph drawing ----------

func _next_strike() -> Dictionary:
	if pattern.is_empty():
		return {}
	for s in pattern.strikes:
		if not _fx_done.has(int(s.id)):
			return s
	return {}


func _draw() -> void:
	super()
	if state == State.PATTERN and not pattern.is_empty():
		for s in pattern.strikes:
			var hid := int(s.id)
			if _fx_done.has(hid):
				continue
			var w0 := float(s.get("warn_from", 0.0))
			if pattern_time < w0:
				continue
			var progress := clampf((pattern_time - w0) / maxf(0.05, float(s.t) - w0), 0.0, 1.0)
			match String(s.shape):
				"PROJ":
					_draw_aim(s, progress)
				"WAVE":
					var r := _wave_rect(s, global_position.x)
					var reach := float(s.speed) * float(s.travel)
					var path := Rect2(r.position.x + (0.0 if facing > 0.0 else -reach), r.position.y, r.size.x + reach, r.size.y)
					if bool(s.get("both", false)):
						path = Rect2(global_position.x - reach - float(s.get("w", 40.0)), r.position.y, 2.0 * reach + 2.0 * float(s.get("w", 40.0)), r.size.y)
					_draw_zone(path, int(s.cls), progress)
				"RAIN":
					draw_string(Anim.font, Vector2(-24, hurt_top - 44), "잿비", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.6, 0.5))
				_:
					_draw_zone(_zone_rect(s), int(s.cls), progress)
		var nxt := _next_strike()
		if not nxt.is_empty():
			var icon: String = ["!", "!!", "X"][int(nxt.cls)]
			var col: Color = [Color(1, 0.96, 0.88), Color(1, 0.7, 0.28), Color(0.85, 0.83, 0.78)][int(nxt.cls)]
			draw_string(Anim.font, Vector2(-5, hurt_top - 30), icon, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)
	for w in _waves:
		var r: Rect2 = w.rect
		draw_rect(Rect2(r.position - global_position, r.size), Color(1.0, 0.3, 0.2, 0.6))
	for r in _rain:
		if r.safe or r.fired:
			continue
		var prog := clampf(1.0 - r.t_hit / 0.55, 0.0, 1.0)
		_draw_zone(Rect2(float(r.x) - float(r.w) * 0.5 + 3.0, ground_y - 400.0, float(r.w) - 6.0, 400.0), U, prog)


func _draw_aim(s: Dictionary, progress: float) -> void:
	var from := _muzzle() - global_position
	var dir := _aim if _aim_locked else (player.global_position + Vector2(0, -24) - _muzzle()).normalized()
	var col := Color(1, 0.3, 0.25, 0.9) if _aim_locked else Color(1, 0.8, 0.4, 0.35 + 0.3 * progress)
	draw_line(from, from + dir * 600.0, col, 2.0 if _aim_locked else 1.0)
	var spread := deg_to_rad(float(s.get("spread", 0.0)))
	if spread > 0.0:
		draw_line(from, from + dir.rotated(spread) * 600.0, col, 1.0)
		draw_line(from, from + dir.rotated(-spread) * 600.0, col, 1.0)


func _draw_zone(r: Rect2, cls: int, progress: float) -> void:
	var local := Rect2(r.position - global_position, r.size)
	var alpha := 0.28 + 0.45 * progress
	var dot := Color(1.0, 0.22, 0.2, alpha)
	var pitch := 8.0 if progress < 0.5 else 5.0
	var y := local.position.y + 2.0
	var row := 0
	while y < local.end.y - 1.0:
		var x := local.position.x + 2.0 + (pitch * 0.5 if row % 2 == 1 else 0.0)
		while x < local.end.x - 1.0:
			draw_rect(Rect2(x, y, 2, 2), dot)
			x += pitch
		y += pitch
		row += 1
	draw_rect(local, Color(1.0, 0.3, 0.25, 0.55 + 0.4 * progress), false, 2.0)
	if progress > 0.75:
		draw_rect(local.grow(2.0), Color(1.0, 0.85, 0.7, (progress - 0.75) * 2.0), false, 1.0)
	if cls == U:
		draw_rect(Rect2(local.position.x, local.end.y - 3.0, local.size.x, 3.0), Color(1.0, 0.25, 0.2, 0.7 + 0.3 * progress))
