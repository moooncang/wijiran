extends Node2D
class_name Interactable
## Base for things the player uses with ↑/W when standing on them (door, checkpoint, manual, rest point).
## Draws a prompt when near; subclasses implement _use() and _draw_body().

var label := ""
var radius := 26.0
var near := false
var used := false
var _t := 0.0


func _ready() -> void:
	add_to_group("interactable")
	z_index = 1


func _process(delta: float) -> void:
	_t += delta
	var p := get_tree().get_first_node_in_group("player")
	near = p != null and absf(p.global_position.x - global_position.x) < radius and absf(p.global_position.y - global_position.y) < 40.0
	queue_redraw()


func try_use() -> bool:
	if not near or not available():
		return false
	_use()
	return true


func available() -> bool:
	return true


func _use() -> void:
	pass


func _draw() -> void:
	_draw_body()
	if near and available():
		draw_string(Anim.font, Vector2(-40, -86), "↑ " + label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 0.95, 0.85))
	elif label != "":
		draw_string(Anim.font, Vector2(-36, -86), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.7, 0.65, 0.6, 0.8))


func _draw_body() -> void:
	pass
