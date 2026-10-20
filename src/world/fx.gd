extends Sprite2D
## Plays one effect clip. Scaled time, so it freezes during hitstop.

var first := 0
var count := 1
var fps := 24.0
var loop := false
var _t := 0.0


func _process(delta: float) -> void:
	if Juice.frozen():
		return
	_t += delta
	var i := int(_t * fps)
	if i >= count:
		if loop:
			i = i % count
		else:
			queue_free()
			return
	frame = first + i
	if not loop and i == count - 1:
		modulate.a = 1.0 - fmod(_t * fps, 1.0) * 0.7  # the last frame fades instead of popping out
