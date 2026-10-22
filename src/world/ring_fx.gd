extends Node2D
## 회란장 기환 (12차): one ring drawn as two half sprites — back under the fighters, front over them — at a
## fixed world origin. The frame follows the band's normalized travel time (the sheet is a position sample
## per frame, not an animation at a fps); an optional dim lead before and dim hold after, then freed.
## The damage is the player's (ring events in PalmStyles); this is art only, so a cancel just frees it.

var clip := ""      # r12 id prefix: <clip>_back / <clip>_front
var travel := 0.1   # seconds the band takes from r0 to r1
var lead := 0.0     # 회환: the first frame shown dim before the travel (the warning of the incoming band)
var hold := 0.0     # seconds the last frame stays dim after the travel (no damage then)
var _t := 0.0
var _back: Sprite2D
var _front: Sprite2D
var _count := 1


func _ready() -> void:
	_back = _sprite(clip + "_back", 1)    # under the bodies (player sprite z 3), over the ground
	_front = _sprite(clip + "_front", 41)
	_count = int(Anim.effects[clip + "_back"].count)
	_show(0, 0.25 if lead > 0.0 else 1.0)


func _sprite(id: String, z: int) -> Sprite2D:
	var c: Dictionary = Anim.effects[id]
	var s := Sprite2D.new()
	s.texture = Anim.effect_sheet(String(c.sheet))
	var cell := int(c.cell)
	s.hframes = int(s.texture.get_width() / cell)
	s.vframes = int(s.texture.get_height() / cell)
	s.centered = false
	s.offset = Vector2(-c.pivot[0], -c.pivot[1])
	s.z_index = z
	add_child(s)
	return s


func _show(i: int, a: float) -> void:
	_back.frame = i
	_front.frame = i
	_back.modulate.a = a
	_front.modulate.a = a


func _process(delta: float) -> void:
	if Juice.frozen():
		return
	_t += delta
	if _t < lead:
		return
	var u := (_t - lead) / travel
	if u <= 1.0:
		_show(int(roundf(u * float(_count - 1))), 1.0)
	elif _t - lead - travel < hold:
		_show(_count - 1, 0.25)
	else:
		queue_free()
