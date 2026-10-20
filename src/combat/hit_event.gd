class_name HitEvent
extends RefCounted
## One enemy strike delivered to the player. (instance_id, hit_id) identifies it; a multi-hit attack
## shares instance_id and issues a new hit_id per strike.

var attacker: Node
var instance_id := 0
var hit_id := 0
var origin := Vector2.ZERO          # where the strike happens (hand / projectile's last position)
var direction := Vector2.RIGHT      # attack travel direction; fallback for the front check when origin overlaps
var raw_direct := 0.0
var raw_internal := 0.0
var knockback := 0.0                # px/s impulse away from origin
var hitstun := CombatConfig.HURT_STUN
var parry_class: int = CombatConfig.ParryClass.NORMAL
var posture_damage := CombatConfig.POSTURE_NORMAL
var ignore_invulnerability := false
var label := ""
var hit_fx := ""                    # effect clip played at the player when the hit lands (boss attacks)
var projectile: Node = null         # set by a Projectile so the player can report the outcome back


func key() -> String:
	return "%d:%d" % [instance_id, hit_id]
