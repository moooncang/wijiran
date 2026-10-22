extends Sprite2D
## Plays one effect clip. Scaled time, so it freezes during hitstop.

var first := 0
var count := 1
var fps := 24.0
var durs: Array = []   # 12차: per-frame seconds instead of a fps (the great moon's unfold / fold)
var loop := false
var hold := false      # stay on the last frame until the owner frees it (a scar waiting to burst)
var life := 0.0        # looping clips: seconds before a 0.2 s fade-out (0 = lives until the owner frees it)
var _t := 0.0
var _alpha := 1.0      # the clip's own opacity (decorative moons sit at 0.3)


func _ready() -> void:
	_alpha = modulate.a


func _process(delta: float) -> void:
	if Juice.frozen():
		return
	_t += delta
	if loop and life > 0.0 and _t >= life:
		modulate.a = _alpha * (1.0 - (_t - life) / 0.2)
		if _t >= life + 0.2:
			queue_free()
			return
	var at := _index()
	var i: int = at[0]
	if i >= count:
		if loop:
			i = i % count
		elif hold:
			frame = first + count - 1
			return
		else:
			queue_free()
			return
	frame = first + i
	if not loop and not hold and i == count - 1:
		modulate.a = _alpha * (1.0 - float(at[1]) * 0.7)  # the last frame fades instead of popping out


## [frame index, fraction into that frame]
func _index() -> Array:
	if durs.is_empty():
		var x := _t * fps
		return [int(x), x - floorf(x)]
	var acc := 0.0
	for k in durs.size():
		var d := float(durs[k])
		if _t < acc + d:
			return [k, (_t - acc) / d]
		acc += d
	return [durs.size(), 0.0]
