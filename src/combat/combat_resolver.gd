class_name CombatResolver
## Single place where hits turn into numbers. Player→enemy: resolve_outgoing. Enemy→player: resolve_incoming
## (the parry decision from 기획서 13장). Both return a result Dictionary; callers only apply side effects.

enum Kind { IGNORED, INVULNERABLE, NORMAL, PARTIAL, PERFECT }


## Player attack `a` (an ATTACKS row) landing on `status`. `counter` marks the perfect-parry counter 초승.
static func resolve_outgoing(a: Dictionary, status: EnemyStatus, key: String, counter: bool) -> Dictionary:
	var r := {"kind": Kind.IGNORED, "hp_damage": 0, "injury_before": status.injury, "injury_after": status.injury, "killed": false, "burst": 0}
	if status.already_hit(key) or not status.alive():
		return r
	status.mark_hit(key)
	var internal := 0.0
	if a.get("injury_burst", false):
		var stacks := status.consume_injury()
		internal = stacks * float(a.get("burst_per_stack", CombatConfig.BURST_PER_STACK))
		r.burst = stacks
	var dmg := CombatConfig.final_damage(float(a.damage), internal, status.armor_rate)
	var before := status.hp
	status.hp = maxf(0.0, status.hp - dmg)
	r.kind = Kind.NORMAL
	r.hp_damage = int(before - status.hp)
	if not a.get("injury_burst", false) and dmg > 0:
		status.add_injury(CombatConfig.COUNTER_INJURY if counter else int(a.get("injury", 0)))
	r.injury_after = status.injury
	r.killed = status.hp == 0.0
	return r


## Enemy hit → player. Decides IGNORED / INVULNERABLE / PERFECT / PARTIAL / NORMAL and the damage to apply.
## `p` is the Player; it exposes parry_elapsed() (-1 when not parrying), parry_facing, protected_from(hit).
static func resolve_incoming(hit: HitEvent, p) -> Dictionary:
	var r := {"kind": Kind.IGNORED, "hp_damage": 0, "knockback": 0.0, "elapsed": -1.0, "posture_added": 0.0}
	if p.dead or p.resolved_hits.has(hit.key()):
		return r
	p.resolved_hits[hit.key()] = true
	if p.protected_from(hit):
		r.kind = Kind.INVULNERABLE
		return r
	var elapsed: float = p.parry_elapsed()
	r.elapsed = elapsed
	var eligible: bool = elapsed >= 0.0 and _in_front(hit, p)   # every hit parries; UNPARRYABLE ("X") only in the perfect window
	var normal := CombatConfig.final_damage(hit.raw_direct, hit.raw_internal, p.armor_rate)
	if eligible and elapsed < CombatConfig.PARRY_PERFECT_END - 1e-6:
		r.kind = Kind.PERFECT
		r.posture_added = hit.posture_damage
		return r
	if eligible and elapsed < CombatConfig.PARRY_PARTIAL_END - 1e-6 and hit.parry_class == CombatConfig.ParryClass.NORMAL:
		r.kind = Kind.PARTIAL
		r.hp_damage = CombatConfig.final_damage(hit.raw_direct, hit.raw_internal, p.armor_rate, CombatConfig.PARTIAL_DAMAGE_RATE)
		r.knockback = hit.knockback * CombatConfig.PARTIAL_KNOCKBACK_RATE
		return r
	r.kind = Kind.NORMAL
	r.hp_damage = normal
	r.knockback = hit.knockback
	return r


## Front half-plane test against the facing locked at parry start. Overlapping origins fall back to the
## attack's travel direction; with neither, the hit cannot be parried.
static func _in_front(hit: HitEvent, p) -> bool:
	var to_hit: Vector2 = hit.origin - (p.global_position + p.TORSO)
	if to_hit.length_squared() < 1.0:
		to_hit = -hit.direction
		if to_hit.length_squared() < 0.01:
			return false
	return to_hit.x * p.parry_facing >= 0.0
