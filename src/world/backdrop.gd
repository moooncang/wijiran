extends Node2D
## Greybox backdrops per map style, drawn once; placeholders until the painted layers arrive (yard,
## forest and clearing only show if a painted map fails to load). Rules for every style: dark and
## low-contrast where the HUD and dialogue sit (the top ~130 px of the view), nothing bright or round
## near the floor that could pass for a projectile, orb, pickup or purify zone, and filled below the
## ground line so pits and camera shake never show the clear colour. Fills reach PAD past both map ends
## (the touch camera runs 200 px past them, plus shake); repeating pieces keep their grid from x=-200.

const PAD := 400.0

var style := "yard"
var width := 1600.0
var ground_y := 300.0
var platforms: Array = []   # level platform rects: no gate beam may line up with a walkable step


func _draw() -> void:
	draw_rect(Rect2(-PAD, ground_y, width + 2.0 * PAD, 400), Color(0.03, 0.03, 0.04))   # under the ground
	var sky := Rect2(-PAD, -400, width + 2.0 * PAD, ground_y + 400)
	match style:
		"yard":
			draw_rect(sky, Color(0.09, 0.09, 0.14))
			for i in int(width / 150.0) + 2:
				var x := i * 150.0 - 100.0
				var top := ground_y - 150.0 - (i % 3) * 20.0
				draw_rect(Rect2(x, top, 60, ground_y - top), Color(0.11, 0.12, 0.18))
				draw_colored_polygon(PackedVector2Array([Vector2(x - 14, top), Vector2(x + 30, top - 26), Vector2(x + 74, top)]), Color(0.11, 0.12, 0.18))
			draw_rect(Rect2(-PAD, ground_y - 330, width + 2.0 * PAD, 90), Color(0.13, 0.15, 0.22))  # the sheared mountain face
		"forest":
			draw_rect(sky, Color(0.07, 0.08, 0.07))
			for i in int(width / 90.0) + 3:
				var x := i * 90.0 - 120.0 + (i % 2) * 30.0
				var h := 170.0 + (i * 37 % 90)
				var burnt := i % 3 != 0
				draw_rect(Rect2(x, ground_y - h, 14, h), Color(0.12, 0.1, 0.09) if burnt else Color(0.16, 0.2, 0.12))
				if burnt:
					draw_line(Vector2(x + 7, ground_y - h), Vector2(x + 34, ground_y - h - 40), Color(0.12, 0.1, 0.09), 4.0)
				else:
					draw_circle(Vector2(x + 7, ground_y - h - 10), 26.0, Color(0.14, 0.22, 0.12))
			draw_rect(Rect2(-PAD, ground_y - 8, width + 2.0 * PAD, 8), Color(0.2, 0.16, 0.1))
		"clearing":
			draw_rect(sky, Color(0.08, 0.1, 0.09))
			draw_rect(Rect2(width * 0.5 - 90, ground_y - 330, 180, 330), Color(0.16, 0.13, 0.1))  # the half world-tree stump
			draw_circle(Vector2(width * 0.5, ground_y - 330), 120.0, Color(0.14, 0.2, 0.12))
			for i in int(width / 120.0) + 2:
				var x := i * 120.0 - 60.0
				draw_rect(Rect2(x, ground_y - 110, 10, 110), Color(0.11, 0.1, 0.09))
		"lab":
			_lab()
		"shrine":
			_shrine()
		_:
			draw_rect(sky, Color(0.1, 0.1, 0.12))


## 단층 임시 연구소 / 관측실: a panelled wall under a ceiling slab and roof truss, pillars every 160 px,
## one brass pipe run bracketed to them that feeds murky specimen tanks on plinths (every third bay holds
## an observation board instead), and lamps hanging from the slab with faint light cones.
func _lab() -> void:
	var g := ground_y
	var x0 := -PAD
	var w := width + 2.0 * PAD
	var ceil_y := g - 300.0
	var truss := Color(0.07, 0.075, 0.1)
	draw_rect(Rect2(x0, -400, w, ceil_y + 400), Color(0.045, 0.05, 0.07))   # roof space
	for i in range(-2, int(w / 160.0) + 2):
		var tx := -200.0 + i * 160.0
		draw_line(Vector2(tx, ceil_y), Vector2(tx + 80, ceil_y - 60), truss, 3.0)
		draw_line(Vector2(tx + 80, ceil_y - 60), Vector2(tx + 160, ceil_y), truss, 3.0)
	draw_rect(Rect2(x0, ceil_y - 66, w, 8), truss)
	LevelArt.vgrad(self, Rect2(x0, ceil_y, w, 300), Color(0.07, 0.075, 0.11), Color(0.12, 0.13, 0.18))   # wall
	draw_rect(Rect2(x0, g - 70, w, 70), Color(0.085, 0.09, 0.125))   # wainscot
	draw_rect(Rect2(x0, g - 70, w, 2), Color(0.15, 0.16, 0.22))
	draw_rect(Rect2(x0, g - 6, w, 6), Color(0.05, 0.05, 0.07))       # skirting
	draw_rect(Rect2(x0, ceil_y, w, 24), Color(0.09, 0.1, 0.14))      # ceiling slab
	draw_rect(Rect2(x0, ceil_y + 24, w, 2), Color(0.15, 0.16, 0.22))
	var pipe_y := g - 210.0
	var lamp := Color(0.9, 0.8, 0.55, 0.06)
	var lamp_end := Color(0.9, 0.8, 0.55, 0.0)
	for i in range(-2, int(width / 160.0) + 5):
		var x := i * 160.0 - 80.0
		var mid := x + 89.0   # centre of the bay between this pillar and the next
		# pillar with capital, base and a highlight edge; every third one cracked
		draw_rect(Rect2(x, ceil_y + 26, 18, 268), Color(0.13, 0.14, 0.2))
		draw_rect(Rect2(x, ceil_y + 26, 2, 268), Color(0.17, 0.18, 0.25))
		draw_rect(Rect2(x - 4, ceil_y + 26, 26, 8), Color(0.15, 0.16, 0.22))
		draw_rect(Rect2(x - 4, g - 14, 26, 8), Color(0.15, 0.16, 0.22))
		if posmod(i, 3) == 2:   # a 2 px groove with its lit lip beside it, so it reads as a crack, not a stray line
			var crack := PackedVector2Array([Vector2(x + 5, g - 230), Vector2(x + 11, g - 205), Vector2(x + 6, g - 182), Vector2(x + 12, g - 160)])
			draw_polyline(crack, Color(0.17, 0.18, 0.25), 1.0)
			crack = Transform2D(0.0, Vector2(-1.5, 0)) * crack
			draw_polyline(crack, Color(0.085, 0.09, 0.13), 2.0)
		if posmod(i, 3) == 1:
			# observation board: chalk notes on a dark slate
			draw_rect(Rect2(mid - 40, g - 176, 80, 54), Color(0.2, 0.16, 0.12))
			draw_rect(Rect2(mid - 37, g - 173, 74, 48), Color(0.08, 0.11, 0.1))
			for k in 4:
				draw_line(Vector2(mid - 31, g - 163 + k * 10), Vector2(mid - 1 + posmod(i * 13 + k * 17, 32), g - 163 + k * 10), Color(0.6, 0.65, 0.6, 0.18), 1.0)
		else:
			# specimen tank on a plinth, fed from the pipe
			var tx := mid - 28.0
			draw_rect(Rect2(mid - 2, pipe_y, 4, 80), Color(0.3, 0.24, 0.14))
			draw_rect(Rect2(tx - 6, g - 134, 68, 6), Color(0.16, 0.17, 0.22))
			draw_rect(Rect2(tx - 4, g - 128, 64, 88), Color(0.12, 0.14, 0.18))
			draw_rect(Rect2(tx, g - 124, 56, 80), Color(0.12, 0.21, 0.21))
			draw_rect(Rect2(tx, g - 124, 56, 2), Color(0.22, 0.34, 0.32))
			# the specimen: a curled silhouette off-centre, tethered to the cap, a few faint bubbles
			var murk := Color(0.08, 0.145, 0.145)
			draw_polyline(PackedVector2Array([Vector2(mid + 9, g - 124), Vector2(mid + 9, g - 109), Vector2(mid + 5, g - 101)]), murk, 2.0)
			draw_set_transform(Vector2(mid - 6, g - 74), 0.45, Vector2(1.0, 1.45))
			draw_circle(Vector2.ZERO, 12.0, murk)
			draw_set_transform(Vector2(mid + 4, g - 94), -0.3, Vector2(1.15, 1.0))
			draw_circle(Vector2.ZERO, 8.0, murk)
			draw_set_transform(Vector2.ZERO)
			for b in 3:
				draw_arc(Vector2(mid + 17 + (b % 2) * 4, g - 58 - b * 19), 1.5 + b * 0.3, 0.0, TAU, 8, Color(0.55, 0.8, 0.75, 0.16), 1.0)
			draw_rect(Rect2(tx + 5, g - 120, 2, 72), Color(1, 1, 1, 0.06))      # glass sheen
			draw_rect(Rect2(tx - 8, g - 40, 72, 34), Color(0.09, 0.095, 0.13))
			draw_rect(Rect2(tx - 8, g - 40, 72, 2), Color(0.15, 0.16, 0.21))
		# lamp on a cord from the slab (beside the tank, or over the board), its light fading to the floor
		var lx := mid if posmod(i, 3) == 1 else mid + 48.0
		draw_line(Vector2(lx, ceil_y + 26), Vector2(lx, g - 230), Color(0.06, 0.06, 0.08), 1.0)
		draw_colored_polygon(PackedVector2Array([Vector2(lx - 5, g - 230), Vector2(lx + 5, g - 230), Vector2(lx + 9, g - 223), Vector2(lx - 9, g - 223)]), Color(0.2, 0.19, 0.2))
		draw_polygon(PackedVector2Array([Vector2(lx - 8, g - 223), Vector2(lx + 8, g - 223), Vector2(lx + 46, g - 70), Vector2(lx - 46, g - 70)]), PackedColorArray([lamp, lamp, lamp_end, lamp_end]))
		draw_rect(Rect2(lx - 3, g - 223, 6, 2), Color(0.75, 0.66, 0.45, 0.6))
	# the brass pipe run, bracketed at each pillar
	draw_rect(Rect2(x0, pipe_y, w, 6), Color(0.34, 0.27, 0.15))
	draw_rect(Rect2(x0, pipe_y, w, 1), Color(0.46, 0.37, 0.21))
	for i in range(-2, int(width / 160.0) + 5):
		draw_rect(Rect2(i * 160.0 - 78.0, pipe_y - 2, 14, 10), Color(0.24, 0.19, 0.11))


## 백향 이송로 / 향당: a dusk-plum sky with faint incense haze, a far hillside of temple roofs barely
## lighter than the sky (canvas ~110-160 with the camera low, under the HUD), nearer halls, paired gate
## pillars with a lintel and a small name plaque, the transport camp's low tents on the ground, braziers
## with a thin smoke line, and a soft incense haze at the floor. All muted so white-robed enemies and
## gold orbs stay brightest.
func _shrine() -> void:
	var g := ground_y
	var x0 := -PAD
	var w := width + 2.0 * PAD
	var dusk := Color(0.065, 0.05, 0.085)
	var horizon := Color(0.19, 0.145, 0.2)
	draw_rect(Rect2(x0, -400, w, g + 80), dusk)
	LevelArt.vgrad(self, Rect2(x0, g - 320, w, 320), dusk, horizon)
	var haze := Color(0.85, 0.8, 0.88, 0.028)
	for hy in [g - 360.0, g - 290.0]:   # two soft bands of incense drifting high in the empty sky
		LevelArt.vgrad(self, Rect2(x0, hy - 20.0, w, 20.0), Color(haze, 0.0), haze)
		LevelArt.vgrad(self, Rect2(x0, hy, w, 26.0), haze, Color(haze, 0.0))
	# far hillside: a ridge line with small temple roofs on it, at most ~0.03 over the sky behind it
	var far_top := dusk.lerp(horizon, 0.3) + Color(0.025, 0.022, 0.03, 0.0)
	var far_low := dusk.lerp(horizon, 170.0 / 320.0)   # the sky at ground-150: the hill's foot melts into it
	var ridge := PackedVector2Array()
	var cols := PackedColorArray()
	var n := int(w / 40.0) + 2
	for i in n:
		var x := x0 + i * 40.0
		ridge.append(Vector2(x, _ridge_y(x)))
		cols.append(far_top)
	ridge.append(Vector2(x0 + (n - 1) * 40.0, g - 150.0))
	ridge.append(Vector2(x0, g - 150.0))
	cols.append(far_low)
	cols.append(far_low)
	draw_polygon(ridge, cols)
	for j in range(-1, int(w / 330.0) + 2):   # a roof every ~330 px, staggered, sitting on the ridge
		var rx := -200.0 + j * 330.0 + posmod(j * 71, 120)
		var ry := maxf(_ridge_y(rx), g - 222.0)   # roofs stay under canvas ~110: the HUD sits above
		var hw := 26.0 + posmod(j * 37, 14)
		draw_rect(Rect2(rx - hw * 0.6, ry - 10.0, hw * 1.2, 12.0), far_top)
		draw_colored_polygon(PackedVector2Array([Vector2(rx - hw, ry - 8.0), Vector2(rx - hw * 0.7, ry - 16.0), Vector2(rx + hw * 0.7, ry - 16.0), Vector2(rx + hw, ry - 8.0), Vector2(rx + hw * 0.8, ry - 10.0), Vector2(rx - hw * 0.8, ry - 10.0)]), far_top)
	for j in range(-1, int(w / 260.0) + 2):   # nearer halls
		var x := -200.0 + j * 260.0 + posmod(j, 2) * 40.0
		var hb := 70.0 + float(posmod(j * 53, 50))
		draw_rect(Rect2(x + 22, g - hb, 136, hb), Color(0.125, 0.095, 0.145))
		draw_colored_polygon(PackedVector2Array([Vector2(x - 6, g - hb + 4), Vector2(x + 30, g - hb - 24), Vector2(x + 150, g - hb - 24), Vector2(x + 186, g - hb + 4), Vector2(x + 160, g - hb), Vector2(x + 20, g - hb)]), Color(0.105, 0.08, 0.125))
		draw_rect(Rect2(x + 30, g - hb - 26, 120, 2), Color(0.16, 0.12, 0.18))
	var pillar := Color(0.25, 0.2, 0.26)
	var base := Color(0.21, 0.17, 0.22)
	var tent := Color(0.31, 0.27, 0.32)
	for k in range(-1, int(w / 420.0) + 2):
		var x := -200.0 + k * 420.0 + 60.0
		# a gate whose lintel/tie-beam band crosses a walkable step would pass for part of it (F3's
		# shooter perch): that one is left out
		var beams := Rect2(x - 28, g - 199, 176, 40)
		if not platforms.any(func(r: Rect2) -> bool: return r.intersects(beams)):
			draw_rect(Rect2(x, g - 181, 10, 181), pillar)
			draw_rect(Rect2(x + 110, g - 181, 10, 181), pillar)
			draw_rect(Rect2(x - 3, g - 10, 16, 10), base)
			draw_rect(Rect2(x + 107, g - 10, 16, 10), base)
			# lintel and tie-beam: darker than the step platforms they share heights with, the lintel's ends
			# upturned and no lit top edge, so neither reads as walkable; a flat plaque instead of a disc (an orb)
			draw_colored_polygon(PackedVector2Array([Vector2(x - 28, g - 199), Vector2(x - 14, g - 191), Vector2(x + 134, g - 191), Vector2(x + 148, g - 199),
				Vector2(x + 140, g - 185), Vector2(x + 132, g - 181), Vector2(x - 12, g - 181), Vector2(x - 20, g - 185)]), Color(0.2, 0.16, 0.21))
			draw_rect(Rect2(x - 6, g - 164, 132, 5), Color(0.19, 0.15, 0.2))
			draw_rect(Rect2(x + 54, g - 181, 12, 17), pillar.darkened(0.25))
		var bx := x + 60.0
		draw_colored_polygon(PackedVector2Array([Vector2(bx - 9, g - 14), Vector2(bx + 9, g - 14), Vector2(bx + 5, g - 6), Vector2(bx - 5, g - 6)]), Color(0.2, 0.16, 0.15))
		draw_rect(Rect2(bx - 2, g - 6, 4, 6), Color(0.17, 0.13, 0.13))
		var smoke := PackedVector2Array()
		for s in 8:
			smoke.append(Vector2(bx + sin(s * 0.9 + k) * 4.0, g - 16 - s * 14))
		draw_polyline(smoke, Color(0.85, 0.82, 0.88, 0.1), 1.5)
		for t in 2:
			var tx := x + 170.0 + t * 96.0
			var th := 54.0 - t * 10.0
			draw_colored_polygon(PackedVector2Array([Vector2(tx, g), Vector2(tx + th * 0.7, g - th), Vector2(tx + th * 1.4, g)]), tent)
			draw_colored_polygon(PackedVector2Array([Vector2(tx + th * 0.55, g), Vector2(tx + th * 0.7, g - th * 0.5), Vector2(tx + th * 0.85, g)]), Color(0.14, 0.11, 0.15))
			draw_line(Vector2(tx + th * 0.7, g - th), Vector2(tx + th * 0.7, g - th - 7), Color(0.26, 0.22, 0.27), 1.0)
	LevelArt.vgrad(self, Rect2(x0, g - 60, w, 60), Color(0.85, 0.8, 0.88, 0.0), Color(0.85, 0.8, 0.88, 0.07))   # incense haze
	draw_rect(Rect2(x0, g - 4, w, 4), Color(0.12, 0.1, 0.13))


## The far ridge's height at x: two slow waves, between ground-226 and ground-196.
func _ridge_y(x: float) -> float:
	return ground_y - 196.0 - 18.0 * (0.5 + 0.5 * sin(x * 0.0093)) - 12.0 * (0.5 + 0.5 * sin(x * 0.0281 + 2.0))
