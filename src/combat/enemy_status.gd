class_name EnemyStatus
extends RefCounted
## HP, armor, internal injury stacks, posture/stagger and the per-target hit ledger shared by
## dummies, training enemies and bosses. Advance with tick(dt) from the owner's physics step
## (skip the call while Juice.frozen() so everything freezes together).

var max_hp := 100.0
var hp := 100.0
var armor_rate := 0.0
var is_boss := false
var injury := 0
var injury_expire := 0.0
var posture := 0.0
var posture_max := CombatConfig.POSTURE_MAX
var posture_last_add := -INF
var stagger_left := 0.0
var immune_left := 0.0
var recoil_left := 0.0
var time := 0.0
var resolved: Dictionary = {}   # "instance:hit" → true


func reset() -> void:
	hp = max_hp
	injury = 0
	injury_expire = 0.0
	posture = 0.0
	posture_last_add = -INF
	stagger_left = 0.0
	immune_left = 0.0
	recoil_left = 0.0
	resolved.clear()


func tick(dt: float) -> void:
	time += dt
	if injury > 0 and time >= injury_expire:
		injury = 0
	if stagger_left > 0.0:
		stagger_left = maxf(0.0, stagger_left - dt)
		if stagger_left == 0.0:
			immune_left = CombatConfig.STAGGER_IMMUNITY
	elif immune_left > 0.0:
		immune_left = maxf(0.0, immune_left - dt)
	recoil_left = maxf(0.0, recoil_left - dt)
	if posture > 0.0 and stagger_left == 0.0 and time - posture_last_add >= CombatConfig.POSTURE_DECAY_DELAY:
		posture = maxf(0.0, posture - CombatConfig.POSTURE_DECAY_RATE * dt)


func alive() -> bool:
	return hp > 0.0


func staggered() -> bool:
	return stagger_left > 0.0


func add_injury(n: int) -> void:
	injury = mini(CombatConfig.INJURY_MAX, injury + n)
	injury_expire = time + CombatConfig.INJURY_DURATION


func consume_injury() -> int:
	var n := injury
	injury = 0
	return n


## Returns true when this addition triggers a stagger. Nothing accumulates while staggered or immune.
func add_posture(amount: float) -> bool:
	if stagger_left > 0.0 or immune_left > 0.0:
		return false
	posture += amount
	posture_last_add = time
	if posture >= posture_max:
		posture = 0.0
		stagger_left = CombatConfig.STAGGER_DURATION
		return true
	return false


func already_hit(key: String) -> bool:
	return resolved.has(key)


func mark_hit(key: String) -> void:
	resolved[key] = true


func clear_instance(instance_id: int) -> void:
	for k in resolved.keys():
		if k.begins_with(str(instance_id) + ":"):
			resolved.erase(k)
