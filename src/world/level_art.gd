extends Node2D
class_name LevelArt
## Painted map (10차 manifest_bg/terrain): three parallax layers whose visual ground (y=450 in the art)
## sits on the level floor, a ground-surface tile strip on every floor segment, terrain blocks and
## platform tiles over the solid rects, and free decor sprites. An "under" layer behind everything fills
## what the art leaves open: earth below each floor segment that carries the tiles' rock body on down into
## the dark (so the strip reads as the top of the ground, not a slab over a void), and the sky colour above
## the art (a high camera on T0 sees past its top edge). Gaps between floor segments are chasms: the
## backdrop fades into a black drop, darker than that earth, under the map's pit-lip pieces.

const DEPTH := 400.0   # fill below the ground and above the art: the view reaches ground+100 plus shake
const TILE := 96.0     # ground tile width
const TRIM := 3.0      # a tile's outlined side columns: kept only at strip ends, so joints leave no hairline
const STEP := TILE - 2.0 * TRIM
const PLAIN := 50      # hash threshold for an accent; with two plain tiles after each one the strip is ~75 % plain
## never as accents: a rope plank in rock reads as a bridge, cave rock in the inn's boards as a hole,
## the brown earth block on grey ash as a loose crate
const NO_ACCENT := ["rope", "h0_stone", "f1_earth"]
const ART_NUDGE := {"B1": 5.0}   # B1's layers stop 4 px short of their ground line: sink them under the strip
const SEAMS := [62.0, 88.0, 122.0]   # faint strata in the earth below the strip

var map_key := "T0"
var ground_y := 300.0
var width := 1600.0
var _plain: Texture2D            # the first manifest tile is the plainest: most of the strip
var _accents: Array = []         # the others, one at a time between plain runs
var _surface := Color(0.2, 0.2, 0.22)   # average walking-surface colour of the plain tile
var _earth := Color(0.1, 0.1, 0.12)     # the plain tile's rock body, a shade darker: the ground under the strip
var _fill := Color(0.1, 0.1, 0.14)
var _sky := Color(0.1, 0.1, 0.14)
var _art_top := 0.0
var _floors: Array = []      # Vector2(x0, x1) per floor segment
var _lips: Array = []        # Vector2(x0, x1) of pit-lip pieces: the tile strip stops where they start
var _under: Node2D
var _draw_list: Array = []   # [{tex, pos, size, src}] drawn in _draw over the strip (no per-sprite nodes)


func build(level: Level, key: String) -> void:
	map_key = key
	ground_y = level.ground_y
	width = level.width
	var m: Dictionary = Anim.bg[key]
	_fill = Color(String(m.get("ground_fill", "#1b1a24")))
	_art_top = ground_y - float(m.get("visual_ground_y", 450)) + float(ART_NUDGE.get(key, 0.0))
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
		s.position = Vector2(0, _art_top)
		par.add_child(s)
		add_child(par)
		if i == 0 and s.texture:
			# the sky above the art: its top row stretched up (a flat colour shows as a band where it varies)
			var top := Sprite2D.new()
			top.texture = s.texture
			top.centered = false
			top.region_enabled = true
			top.region_rect = Rect2(0, 0, s.texture.get_width(), 1)
			top.scale.y = DEPTH
			top.position = Vector2(0, _art_top - DEPTH)
			par.add_child(top)
			var img := s.texture.get_image()
			if img:
				_sky = img.get_pixel(0, 0)
				_sky.a = 1.0
	_under = Node2D.new()
	_under.z_index = -12   # behind the parallax layers (-10..-8): only shows where they end
	_under.draw.connect(_draw_under)
	add_child(_under)
	for t in m.get("ground_tiles", []):
		var f := String(t).get_file()
		if _plain == null:
			_plain = Anim.tex(f)
		elif not NO_ACCENT.any(func(n: String) -> bool: return f.contains(n)):
			_accents.append(Anim.tex(f))
	_surface = _avg_colour(_plain, 2, 14)
	_earth = _avg_colour(_plain, 30, 44).darkened(0.3)
	z_index = -1


## Ground surface strip over a floor segment (tiled in _draw, so pit lips added later still cut it).
func add_floor(x0: float, x1: float) -> void:
	_floors.append(Vector2(x0, x1))
	_under.queue_redraw()
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
	var t := Anim.tex(String(d.file).get_file())
	var pos := at - Vector2(0, float(d.size[1]))   # anchored at the bottom-left on the ground
	if at.y > ground_y and t != null:
		# hangs below the walking surface (a pit lip): it replaces the strip's end instead of hiding behind it
		_draw_list.append({"tex": t, "pos": pos, "size": t.get_size(), "src": Rect2(Vector2.ZERO, t.get_size())})
		_lips.append(Vector2(pos.x, pos.x + t.get_width()))
		queue_redraw()
		return
	var s := Sprite2D.new()
	s.texture = t
	s.centered = false
	s.position = pos
	s.z_index = -2 if behind else 2
	add_child(s)


func _draw() -> void:
	var segs := _floors.duplicate()
	segs.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	for k in segs.size():
		var f: Vector2 = segs[k]
		if k > 0 and f.x > segs[k - 1].y:
			_draw_pit(segs[k - 1].y, f.x)
		var open := Vector2.ZERO   # strip ends that butt against a lip piece: joints, no outlined side
		for l in _lips:   # a lip piece over a strip end takes that end's place
			if l.x <= f.x and l.y > f.x:
				f.x = l.y
				open.x = TRIM
			if l.y >= f.y and l.x < f.y:
				f.y = l.x
				open.y = TRIM
		draw_rect(Rect2(f.x, ground_y, f.y - f.x, 16.0), _surface)   # behind the tiles' rounded top corners
		_draw_strip(f.x, f.y, open)
	for e in _draw_list:
		draw_texture_rect_region(e.tex, Rect2(e.pos, e.size), e.src)


## The tile strip: mostly the plain tile, accents picked by a hash of the tile slot (stable between
## runs), at least two plain tiles between accents so no rhythm shows. Only the strip's free ends keep a
## tile's outlined side; every joint (and an `open` end: x left, y right) butts trimmed tile bodies.
func _draw_strip(x0: float, x1: float, open := Vector2.ZERO) -> void:
	var x := x0
	var run := 0       # plain tiles since the last accent: a strip (and so every pit lip) starts plain
	var cut := open.x  # source columns skipped on the left
	while x < x1:
		var h := posmod(hash(int(floorf(x / STEP)) + map_key.hash()), 100)
		var t := _plain
		if run >= 2 and h >= PLAIN and not _accents.is_empty():
			t = _accents[h % _accents.size()]
		run = run + 1 if t == _plain else 0
		var left := x1 - x
		# the last tile ends on its right side (outlined unless open); the others stop short of theirs
		var end := TILE - open.y
		var src := Rect2(end - left, 0, left, 48) if left <= end - cut else Rect2(cut, 0, TILE - TRIM - cut, 48)
		draw_texture_rect_region(t, Rect2(Vector2(x, ground_y), src.size), src)
		x += src.size.x
		cut = TRIM


## A gap in the floor: the backdrop sinks into a black drop (no hard top edge, darker than the earth
## beside it), with the earth's rock faces under both lips fading into the dark.
func _draw_pit(a: float, b: float) -> void:
	var black := Color(0.015, 0.012, 0.02)
	var top := ground_y - 8.0   # over the parallax art's bottom rows, which would read as a ledge across the gap
	vgrad(self, Rect2(a, top, b - a, 24.0), Color(black, 0.0), black)
	draw_rect(Rect2(a, top + 24.0, b - a, DEPTH), black)
	var deep := ground_y + 90.0
	for lip in [[a, 10.0], [b, -10.0]]:
		var x: float = lip[0]
		var x2: float = x + float(lip[1])
		draw_polygon(PackedVector2Array([Vector2(x, ground_y), Vector2(x2, ground_y), Vector2(x2, deep), Vector2(x, deep)]),
			PackedColorArray([_earth, Color(_earth, 0.0), Color(black, 0.0), black]))


func _draw_under() -> void:
	var x0 := -400.0
	var w := width + 800.0
	var deep := _fill.darkened(0.85)
	_under.draw_rect(Rect2(x0, _art_top - DEPTH, w, DEPTH + 2.0), _sky)
	# from a little above the ground: a layer that stops short of its ground line never shows the clear colour
	_under.draw_rect(Rect2(x0, ground_y - 8.0, w, DEPTH + 8.0), _fill.darkened(0.75))
	for f in _floors:
		var fw: float = f.y - f.x
		_under.draw_rect(Rect2(f.x, ground_y, fw, 30.0), _earth)   # behind the tiles' ragged rock bottoms
		vgrad(_under, Rect2(f.x, ground_y + 30.0, fw, 110.0), _earth, deep)
		_under.draw_rect(Rect2(f.x, ground_y + 140.0, fw, DEPTH - 140.0), deep)
		for k in SEAMS.size():   # strata, fading with depth
			var y: float = ground_y + SEAMS[k]
			var a := 0.3 - 0.08 * k
			_under.draw_line(Vector2(f.x, y), Vector2(f.y, y), Color(0, 0, 0, a), 1.0)
			_under.draw_line(Vector2(f.x, y + 1.0), Vector2(f.y, y + 1.0), Color(1, 1, 1, a * 0.1), 1.0)


## Average opaque colour of a tile's rows y0..y1 (away from the rounded sides): 2-14 is the walking
## surface, 30-44 the rock body.
static func _avg_colour(t: Texture2D, y0: int, y1: int) -> Color:
	var img := t.get_image() if t else null
	var sum := Color(0, 0, 0, 0)
	if img and not img.is_empty():
		for y in range(y0, mini(y1, img.get_height())):
			for x in range(8, img.get_width() - 8):
				var c := img.get_pixel(x, y)
				if c.a > 0.5:
					sum += Color(c.r, c.g, c.b, 1.0)
	return Color(sum.r / sum.a, sum.g / sum.a, sum.b / sum.a) if sum.a > 0.0 else Color(0.2, 0.2, 0.22)


## Vertical gradient rect (shared by the greybox backdrop and solids).
static func vgrad(ci: CanvasItem, r: Rect2, top: Color, bottom: Color) -> void:
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), PackedColorArray([top, top, bottom, bottom]))
