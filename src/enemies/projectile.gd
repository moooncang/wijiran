extends Node2D
class_name Projectile
## A straight-flying strike (arrow, bolt). Hits the player once through the normal HitEvent path; the
## player reports the outcome back via on_resolved so a perfect parry destroys the shot and feeds posture
## to the shooter, i-frames let it pass, anything else consumes it. Stops in solids. Drawn with a looping
## effect clip when `clip` is set (10차 arrows), a glowing orb when that clip has no art yet (mage_bolt,
## observe_orb), otherwise a greybox arrow.

const ORB_COLORS := {"observe_orb": Color(1.0, 0.45, 0.25)}   # orb tint per art-less clip (else `color`)

var velocity := Vector2.RIGHT * 420.0
var life := 2.6
var shooter: Node
var hit: HitEvent
var radius := 5.0
var color := Color(0.85, 0.9, 0.7)
var clip := ""              # looping art clip (arrow / wind_arrow / leaf_arrow / ash_arrow)
var hit_clip := ""          # played where it lands on the player
var parried_clip := ""      # played when perfectly parried
var stick_clip := ""        # left in a solid
var _sent := false
var _stuck := false
var _player: Player
var _art: Sprite2D
var _orb := false


func _ready() -> void:
	add_to_group("projectile")
	z_index = 6
	_player = get_tree().get_first_node_in_group("player") as Player
	_orb = clip != "" and not Anim.effects.has(clip)
	if clip != "" and not _orb:
		_art = Juice.fx(clip, Vector2.ZERO, velocity.normalized(), 1.0, false, self)
		_art.z_index = 0


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
		if _orb:   # an orb bursts on the wall instead of sticking like an arrow
			Juice.flash(global_position, 6.0)
			queue_free()
			return
		_stuck = true
		life = 0.6
		if stick_clip != "" and Anim.effects.has(stick_clip):
			Juice.fx(stick_clip, global_position, velocity.normalized())
			if _art:
				_art.visible = false
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
			Juice.fx(parried_clip if parried_clip != "" and Anim.effects.has(parried_clip) else "parry_perfect_fx", global_position, velocity.normalized())
			queue_free()
		CombatResolver.Kind.INVULNERABLE:
			_sent = false   # i-frames: it flies on and may hit later
		_:
			queue_free()


func _process(_delta: float) -> void:
	if _art == null:
		queue_redraw()


func _draw() -> void:
	if _art != null:
		return
	var d := velocity.normalized()
	var k := radius / 5.0
	if _orb:
		# its art clip is not in any manifest (mage_bolt, observe_orb): a glowing orb with a fading tail, not an arrow
		var col: Color = ORB_COLORS.get(clip, color)
		var r := radius * 1.2
		for i in 4:
			draw_circle(-d * (6.0 + 5.0 * i) * k, r * (0.85 - 0.17 * i), Color(col, 0.32 - 0.07 * i))
		draw_circle(Vector2.ZERO, r * 1.9, Color(col, 0.35))
		draw_circle(Vector2.ZERO, r, col)
		draw_circle(Vector2.ZERO, r * 0.45, Color(1.0, 0.98, 0.9))
		return
	var tail := -d * 16.0 * k
	draw_line(tail, d * 6.0 * k, Color(0.5, 0.35, 0.2), 2.0 * k)
	draw_line(d * 4.0 * k, d * 10.0 * k, color, 3.0 * k)
	if k > 1.2:
		draw_line(tail - d * 20.0 * k, tail, Color(0.8, 1.0, 0.8, 0.35), 5.0 * k)
	draw_line(tail, tail + Vector2(-d.y, d.x) * 3.0, Color(0.5, 0.8, 0.4), 2.0)
	draw_line(tail, tail - Vector2(-d.y, d.x) * 3.0, Color(0.5, 0.8, 0.4), 2.0)
