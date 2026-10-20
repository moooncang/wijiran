extends CanvasItem
## Fades out over `life` seconds, optionally rising, then frees itself. Used for afterimages and damage numbers.

var life := 0.15
var rise := 0.0
var hold := 0.0   # fraction of `life` shown at full alpha before the fade starts (damage numbers)
var _age := 0.0
var _start_alpha := 1.0


func _ready() -> void:
	_start_alpha = modulate.a


func _process(delta: float) -> void:
	if Juice.frozen():
		return
	_age += delta
	var t := _age / life
	if t >= 1.0:
		queue_free()
		return
	modulate.a = _start_alpha * clampf((1.0 - t) / (1.0 - hold), 0.0, 1.0)
	if rise != 0.0:
		set("position", get("position") - Vector2(0, rise * 2.0 * (1.0 - t) * delta))   # eases out; total distance = rise * life
