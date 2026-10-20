extends Node2D
## 정화 구역 (본편 §8): a low white incense disc on the floor. While the player's feet are inside, the
## player's injury-burst damage is reduced (Player.purify); nothing else changes. Lives `life` seconds.
## Greybox until the 11차 purify_zone clip.

var radius := 80.0
var height := 36.0
var life := 12.0
var _t := 0.0


func _ready() -> void:
	add_to_group("purify_zone")
	z_index = -1


func rect() -> Rect2:
	return Rect2(global_position.x - radius, global_position.y - height, radius * 2.0, height)


func _physics_process(dt: float) -> void:
	if Juice.frozen():
		return
	_t += dt
	life -= dt
	if life <= 0.0:
		queue_free()
		return
	var p := Game.player
	if p and rect().intersects(p.hurt_rect()):
		p.purify(0.5)
	queue_redraw()


func _draw() -> void:
	var a := clampf(life, 0.0, 1.0) * 0.8
	draw_rect(Rect2(-radius, -height, radius * 2.0, height), Color(1, 1, 1, 0.14 * a))
	for i in 16:
		var x := -radius + (i + 0.5) * radius * 2.0 / 16.0
		var yy := -6.0 - 10.0 * absf(sin(_t * 2.0 + i))
		draw_circle(Vector2(x, yy), 5.0, Color(0.95, 0.97, 1.0, 0.35 * a))
	draw_rect(Rect2(-radius, -height, radius * 2.0, height), Color(0.9, 0.9, 1.0, 0.6 * a), false, 1.0)
	draw_circle(Vector2(0, -2), 6.0, Color(0.85, 0.7, 0.3, a))   # the sun badge at the centre
	draw_string(Anim.font, Vector2(-10, -height - 6), "정화", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, a))
