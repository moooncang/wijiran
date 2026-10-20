extends CanvasItem
## Fades out over `life` seconds, optionally rising, then frees itself. Used for afterimages and damage numbers.

var life := 0.15
var rise := 0.0
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
	modulate.a = _start_alpha * (1.0 - t)
	if rise != 0.0:
		set("position", get("position") - Vector2(0, rise * delta))
