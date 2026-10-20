extends Node2D
class_name Projectile
## A straight-flying strike (arrow, bolt). Hits the player once through the normal HitEvent path; the
## player reports the outcome back via on_resolved so a perfect parry destroys the shot and feeds posture
## to the shooter, i-frames let it pass, anything else consumes it. Stops in solids. Greybox arrow art.

var velocity := Vector2.RIGHT * 420.0
var life := 2.6
var shooter: Node
var hit: HitEvent
var radius := 5.0
var color := Color(0.85, 0.9, 0.7)
var _sent := false
var _stuck := false
var _player: Player


func _ready() -> void:
	add_to_group("projectile")
	z_index = 6
	_player = get_tree().get_first_node_in_group("player") as Player


func _physics_process(dt: float) -> void:
	if Juice.frozen():
		return
	life -= dt
	if life <= 0.0:
		queue_free()
		return
	if _stuck:
		return
	var next := global_position + velocity * dt
	var lv = Game.level
	if lv and lv.has_method("blocked") and lv.blocked(next):
		_stuck = true
		life = 0.6
		return
	global_position = next
	if not _sent and _player and _player.hurt_rect().has_point(global_position):
		_sent = true
		hit.origin = global_position
		hit.direction = velocity.normalized()
		hit.projectile = self
		_player.receive_hit(hit)


## Called by the player after the hit resolved.
func on_resolved(kind: int) -> void:
	match kind:
		CombatResolver.Kind.PERFECT:
			Juice.fx("parry_perfect_fx", global_position)
			queue_free()
		CombatResolver.Kind.INVULNERABLE:
			_sent = false   # i-frames: it flies on and may hit later
		_:
			queue_free()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var d := velocity.normalized()
	var tail := -d * 16.0
	draw_line(tail, d * 6.0, Color(0.5, 0.35, 0.2), 2.0)
	draw_line(d * 4.0, d * 10.0, color, 3.0)
	draw_line(tail, tail + Vector2(-d.y, d.x) * 3.0, Color(0.5, 0.8, 0.4), 2.0)
	draw_line(tail, tail - Vector2(-d.y, d.x) * 3.0, Color(0.5, 0.8, 0.4), 2.0)
