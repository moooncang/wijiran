extends Node2D
## A looping prop clip from props.png placed in the world (e.g. the disciple's dropped mark).

var clip := "disciple_mark"
var _s: Sprite2D
var _t := 0.0


func _ready() -> void:
	_s = Anim.prop_sprite(clip)
	add_child(_s)


func _process(delta: float) -> void:
	_t += delta
	var c: Dictionary = Anim.props[clip]
	Anim.prop_frame(_s, clip, int(_t * float(c.get("fps", 6))))
