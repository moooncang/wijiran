extends Node2D
class_name LevelArt
## Painted map (10차 manifest_bg/terrain): three parallax layers whose visual ground (y=450 in the art)
## sits on the level floor, a ground-surface tile strip on every floor segment with a fill colour below,
## terrain blocks and platform tiles over the solid rects, and free decor sprites.

var map_key := "T0"
var ground_y := 300.0
var width := 1600.0
var _ground_tiles: Array = []
var _fill := Color(0.1, 0.1, 0.14)
var _draw_list: Array = []   # [{tex, pos, size}] drawn in _draw (no per-sprite nodes for tiles)


func build(level: Level, key: String) -> void:
	map_key = key
	ground_y = level.ground_y
	width = level.width
	var m: Dictionary = Anim.bg[key]
	_fill = Color(String(m.get("ground_fill", "#1b1a24")))
	var layer_size: Array = m.layer_size
	var par_scales: Array = m.get("parallax", [0.15, 0.4, 0.8])
	var files := [String(m.far), String(m.mid), String(m.near)]
	for i in 3:
		var par := Parallax2D.new()
		par.scroll_scale = Vector2(float(par_scales[i]), 1.0)
		par.repeat_size = Vector2(float(layer_size[0]), 0)
		par.repeat_times = 3
		par.z_index = -10 + i
		var s := Sprite2D.new()
		s.texture = Anim.tex(files[i])
		s.centered = false
		s.position = Vector2(0, ground_y - float(m.get("visual_ground_y", 450)))
		par.add_child(s)
		add_child(par)
	for t in m.get("ground_tiles", []):
		_ground_tiles.append(Anim.tex(String(t).get_file()))
	z_index = -1


## Ground surface strips over floor segments.
func add_floor(x0: float, x1: float) -> void:
	var x := x0
	var i := int(absf(x0) / 96.0)
	while x < x1:
		var t: Texture2D = _ground_tiles[i % _ground_tiles.size()]
		var w := minf(96.0, x1 - x)
		_draw_list.append({"tex": t, "pos": Vector2(x, ground_y), "size": Vector2(w, 48), "src": Rect2(0, 0, w, 48)})
		x += 96.0
		i += 1
	_draw_list.append({"fill": Rect2(x0, ground_y + 48, x1 - x0, 60)})
	queue_redraw()


## A terrain/platform piece by manifest name at a rect (stretched only if the art size differs).
func add_piece(name: String, r: Rect2) -> bool:
	if not Anim.terrain.has(name):
		return false
	var d: Dictionary = Anim.terrain[name]
	var t := Anim.tex(String(d.file).get_file() if String(d.file).begins_with("terrain/") else String(d.file))
	if t == null:
		return false
	_draw_list.append({"tex": t, "pos": r.position, "size": r.size, "src": Rect2(Vector2.ZERO, t.get_size())})
	queue_redraw()
	return true


## A platform built from left/mid/right 32×16 tiles (T0) or a single art piece.
func add_platform(prefix: String, r: Rect2) -> void:
	var l = Anim.terrain.get(prefix + "_left")
	var mid = Anim.terrain.get(prefix + "_mid")
	var rt = Anim.terrain.get(prefix + "_right")
	if l == null or mid == null or rt == null:
		return
	var tl := Anim.tex("t0_platform_left.png")
	var tm := Anim.tex("t0_platform_mid.png")
	var tr := Anim.tex("t0_platform_right.png")
	var x := r.position.x
	_draw_list.append({"tex": tl, "pos": Vector2(x, r.position.y), "size": Vector2(32, r.size.y), "src": Rect2(0, 0, 32, 16)})
	x += 32.0
	while x < r.end.x - 32.0:
		var w := minf(32.0, r.end.x - 32.0 - x)
		_draw_list.append({"tex": tm, "pos": Vector2(x, r.position.y), "size": Vector2(w, r.size.y), "src": Rect2(0, 0, w, 16)})
		x += 32.0
	_draw_list.append({"tex": tr, "pos": Vector2(r.end.x - 32.0, r.position.y), "size": Vector2(32, r.size.y), "src": Rect2(0, 0, 32, 16)})
	queue_redraw()


func add_decor(name: String, at: Vector2, behind := true) -> void:
	if not Anim.terrain.has(name):
		return
	var d: Dictionary = Anim.terrain[name]
	var s := Sprite2D.new()
	s.texture = Anim.tex(String(d.file).get_file())
	s.centered = false
	s.position = at - Vector2(0, float(d.size[1]))   # anchored at the bottom-left on the ground
	s.z_index = -2 if behind else 2
	add_child(s)


func _draw() -> void:
	for e in _draw_list:
		if e.has("fill"):
			draw_rect(e.fill, _fill)
		else:
			draw_texture_rect_region(e.tex, Rect2(e.pos, e.size), e.src)
