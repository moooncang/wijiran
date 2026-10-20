extends Node2D
## Impact flash: a white disc that shrinks away over 0.045s. Freezes during hitstop like every clip.

var radius := 8.0
var _t := 0.0


func _process(delta: float) -> void:
	if Juice.frozen():
		return
	_t += delta
	if _t >= 0.045:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := 1.0 - _t / 0.045
	draw_circle(Vector2.ZERO, radius * (0.6 + 0.4 * k), Color(1, 0.95, 0.86, 0.9 * k))
