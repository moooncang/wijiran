extends Node2D
## Greybox look for a solid rectangle, dressed by the map's backdrop style. `rect` is always the exact
## collision box and walking surface, with a 3 px highlight on top as the walking edge.
## - floor pieces (`depth` > 0): the fill carries on below the 60 px collision rect (the camera sees
##   ground+100 plus shake), darkening fast, in stone courses that grow taller and fainter with depth;
##   a boss arena's lane boundaries (`lanes`) get a deep groove through the walking edge instead;
## - covers: a stone block with darker sides and a chipped corner;
## - thin platforms in mid-air: lab = a plank on metal legs down to the floor, shrine = a beam with end
##   caps hung on two ropes that fade into the dark;
## - anything else (crates, carts, walls, daises): lab = crates with a cross-brace (low ones: panels),
##   other styles = plank boards between end posts.

const COURSES := [3.0, 16.0, 34.0, 56.0, 84.0, 120.0]   # paving seams below the walking edge

var rect := Rect2()
var color := Color(0.3, 0.22, 0.16)
var depth := 0.0
var style := ""          # map backdrop style ("lab", "shrine", ...)
var cover := false
var floor_y := 300.0     # where legs stand
var lanes: Array = []    # [[x0, x1], ...] boss floor sections (floor pieces only)


func _draw() -> void:
	if depth > 0.0:
		_floor()
	elif cover:
		_block()
	elif rect.size.y <= 20.0 and rect.end.y < floor_y - 1.0:
		_ledge()
	else:
		_boards()
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3)), color.lightened(0.25))
	for x in _lane_seams():   # through the walking edge, with a lit lip on the right, fading down ~40 px
		var lip := color.lightened(0.4)
		LevelArt.vgrad(self, Rect2(x - 1.0, rect.position.y, 2.0, 44.0), Color(0, 0, 0, 0.6), Color(0, 0, 0, 0.0))
		LevelArt.vgrad(self, Rect2(x + 1.0, rect.position.y + 3.0, 1.0, 40.0), Color(lip, 0.5), Color(lip, 0.0))


## Inner lane boundaries inside this piece.
func _lane_seams() -> Array:
	var out := []
	for i in range(1, lanes.size()):
		var x := roundf(float(lanes[i][0]))
		if x > rect.position.x and x < rect.end.x:
			out.append(x)
	return out


func _floor() -> void:
	var p := rect.position
	var w := rect.size.x
	var mid := color.darkened(0.45)
	var deep := color.darkened(0.8)
	LevelArt.vgrad(self, Rect2(p, Vector2(w, 60.0)), color, mid)
	LevelArt.vgrad(self, Rect2(p.x, p.y + 60.0, w, 80.0), mid, deep)
	draw_rect(Rect2(p.x, p.y + 140.0, w, rect.size.y + depth - 140.0), deep)
	var seams := _lane_seams()
	for c in COURSES.size() - 1:
		var y0: float = p.y + COURSES[c]
		var y1: float = p.y + COURSES[c + 1]
		var a := 0.34 - 0.06 * c   # seams fade with depth
		if c > 0:
			draw_line(Vector2(p.x, y0), Vector2(rect.end.x, y0), Color(0, 0, 0, a), 1.0)
			draw_line(Vector2(p.x, y0 + 1.0), Vector2(rect.end.x, y0 + 1.0), Color(1, 1, 1, a * 0.12), 1.0)
		var step := 64.0 + 16.0 * c   # joints spread out lower down, staggered course to course
		var x := floorf(p.x / step) * step + (step * 0.5 if c % 2 == 1 else 0.0)
		while x < rect.end.x:
			if x > p.x and not seams.any(func(s: float) -> bool: return absf(s - x) < 16.0):   # keep lane seams alone
				draw_line(Vector2(x, y0), Vector2(x, y1), Color(0, 0, 0, a), 1.0)
			x += step


func _block() -> void:
	var p := rect.position
	var e := rect.end
	var side := color.darkened(0.3)
	draw_rect(rect, color)
	draw_rect(Rect2(p.x, p.y, 4, rect.size.y), side)
	draw_rect(Rect2(e.x - 4, p.y, 4, rect.size.y), side)
	draw_rect(Rect2(p.x, e.y - 4, rect.size.x, 4), color.darkened(0.45))   # foot in shadow
	var bed := roundf(p.y + rect.size.y * 0.55)
	draw_line(Vector2(p.x + 4, bed), Vector2(e.x - 4, bed), color.darkened(0.25), 1.0)
	# a chipped corner just under the walking edge
	var c := Vector2(e.x, p.y + 3)
	draw_colored_polygon(PackedVector2Array([c, c + Vector2(0, 8), c + Vector2(-7, 0)]), color.darkened(0.55))
	draw_line(c + Vector2(-7, 0), c + Vector2(0, 8), color.lightened(0.12), 1.0)


func _ledge() -> void:
	var p := rect.position
	var e := rect.end
	var h := rect.size.y
	if style == "shrine":
		var rope := Color(0.42, 0.35, 0.26)
		for f in [0.22, 0.78]:
			var x := roundf(p.x + rect.size.x * f)
			LevelArt.vgrad(self, Rect2(x - 1, p.y - 46, 2, 46), Color(rope, 0.0), rope)
		draw_rect(rect, color)
		for f in [0.22, 0.78]:   # the rope wrapped round the beam
			draw_rect(Rect2(roundf(p.x + rect.size.x * f) - 2, p.y + 3, 4, h - 3), rope.darkened(0.25))
		var cap := color.darkened(0.35)
		draw_rect(Rect2(p.x, p.y, 6, h + 3), cap)
		draw_rect(Rect2(e.x - 6, p.y, 6, h + 3), cap)
	else:
		if style == "lab":   # thin metal legs down to the floor, behind the plank
			var metal := Color(0.2, 0.21, 0.26)
			for x in [p.x + 6.0, e.x - 9.0]:
				draw_rect(Rect2(x, e.y, 3, floor_y - e.y), metal)
				draw_rect(Rect2(x, e.y, 1, floor_y - e.y), metal.lightened(0.15))
				draw_rect(Rect2(x - 2, floor_y - 2, 7, 2), metal.darkened(0.25))
		draw_rect(rect, color)
		var x := p.x + 46.0
		while x < e.x - 20.0:   # plank joints
			draw_line(Vector2(x, p.y + 3), Vector2(x, e.y - 2), color.darkened(0.3), 1.0)
			x += 46.0
	draw_rect(Rect2(p.x, e.y - 2, rect.size.x, 2), color.darkened(0.35))   # underside


func _boards() -> void:
	var p := rect.position
	var e := rect.end
	var s := rect.size
	var line := color.darkened(0.3)
	if style == "lab" and s.y >= 30.0:
		# crates: a darker frame, board lines and a cross-brace
		var n := maxi(1, roundi(s.x / clampf(s.y, 40.0, 64.0)))
		var cw := s.x / n
		for k in n:
			var c := Rect2(p.x + k * cw, p.y, cw, s.y)
			draw_rect(c, line)
			draw_rect(c.grow(-3), color)
			var y := c.position.y + 15.0
			while y < c.end.y - 6.0:
				draw_line(Vector2(c.position.x + 3, y), Vector2(c.end.x - 3, y), color.darkened(0.15), 1.0)
				y += 12.0
			draw_line(c.position + Vector2(5, s.y - 5), c.position + Vector2(cw - 5, 7), line, 3.0)
	elif style == "lab":
		# a low plinth: panels with joints and a shadowed foot
		draw_rect(rect, color)
		var n := maxi(1, roundi(s.x / 50.0))
		for k in range(1, n):
			var x := roundf(p.x + s.x * k / n)
			draw_line(Vector2(x, p.y + 3), Vector2(x, e.y - 3), line, 1.0)
		draw_rect(Rect2(p.x, e.y - 3, s.x, 3), color.darkened(0.45))
	else:
		# plank boards between two end posts
		draw_rect(rect, color)
		var y := p.y + 11.0
		while y < e.y - 3.0:
			draw_line(Vector2(p.x, y), Vector2(e.x, y), line, 1.0)
			y += 9.0
		draw_rect(Rect2(p.x, p.y, 5, s.y), color.darkened(0.25))
		draw_rect(Rect2(e.x - 5, p.y, 5, s.y), color.darkened(0.25))
		draw_rect(Rect2(p.x, e.y - 3, s.x, 3), color.darkened(0.45))
