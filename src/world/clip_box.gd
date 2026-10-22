extends Node2D
## Clips its children to a forward box `length` × `width` from the origin (쇄진장 파진: the path art
## shows only the ground actually run over; the picture is never squashed, 12차 §5).

var length := 0.0
var width := 44.0


func _ready() -> void:
	clip_children = CanvasItem.CLIP_CHILDREN_ONLY


func _draw() -> void:
	draw_rect(Rect2(0.0, -width * 0.5, maxf(length, 1.0), width), Color.WHITE)
