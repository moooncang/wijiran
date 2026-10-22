extends Node
## Game-feel helpers: hitstop, camera shake, effect clips (effects_v9 metadata driven), ghosts, numbers.

const RISE := 24.0   # a damage number's total climb (ghost.gd: rise × life)

var camera  # GameCamera
var world: Node2D
var _stop_until := 0
var debug_fx := false
var _numbers: Array = []   # live damage-number Labels (meta "w" = text width), to stack bursts
var _guard_at := Vector2.INF   # where a guard halved the hit being resolved this physics tick
var _guard_frame := -1


## Full freeze (Dead Cells style): player, enemies and effect clips poll frozen() and skip their update.
## Engine.time_scale is deliberately not used: near-zero values stall Godot's main loop.
func hitstop(duration: float) -> void:
	_stop_until = maxi(_stop_until, Time.get_ticks_usec() + int(duration * 1_000_000.0))


func frozen() -> bool:
	return Time.get_ticks_usec() < _stop_until


func clear() -> void:
	_stop_until = 0


func shake(amount: float, kick_x: float) -> void:
	if camera:
		camera.shake = maxf(camera.shake, amount)
		camera.kick = kick_x


## Effect clip from effects_v9.png. Manifest fields: first/count/fps/loop, pivot (cell point placed at `at`),
## orientation: "hit_direction" rotates +x to `dir` (mirrored instead of rotating past 90° when dir.x < 0),
## "facing" only mirrors when facing < 0, "fixed" never rotates. `flip_v` mirrors across the direction
## (used for the swing arc direction). `parent` attaches the clip (dash_aura / spin_whirl / gather follow the body).
func fx(clip: String, at: Vector2, dir: Vector2 = Vector2.RIGHT, facing: float = 1.0, flip_v := false, parent: Node = null, scale_by := 1.0, stretch := Vector2.ONE) -> Sprite2D:
	var c: Dictionary = Anim.effects[clip]
	var s := Sprite2D.new()
	var cv = c.get("cell", Anim.effect_cell)
	var cell: int = int(cv[0]) if cv is Array else int(cv)  # manifests write cell as [w, h]
	s.texture = Anim.effect_sheet(String(c.get("sheet", "")))
	s.hframes = int(s.texture.get_width() / cell)
	s.vframes = int(s.texture.get_height() / cell)
	s.centered = false
	s.offset = Vector2(-c.pivot[0], -c.pivot[1])
	s.position = at
	s.z_index = int(c.get("z", 41))  # z -1 = behind the body it is attached to
	var sx := scale_by * stretch.x
	var sy := (-scale_by if flip_v else scale_by) * stretch.y
	match String(c.get("orientation", "fixed")):
		"hit_direction", "right", "left":   # 11차: "right" art points +x, "left" art is drawn pointing back; both follow dir
			if dir.x < 0.0:
				s.scale = Vector2(-sx, sy)
				s.rotation = dir.angle() - PI
			else:
				s.scale = Vector2(sx, sy)
				s.rotation = dir.angle()
		"facing":
			s.scale = Vector2(-sx if facing < 0.0 else sx, sy)
		_:
			s.scale = Vector2(sx, sy)
	s.set_script(preload("res://src/world/fx.gd"))
	s.set("first", int(c.first))
	s.set("count", int(c.count))
	s.set("fps", float(c.get("fps", 24.0)))
	s.set("loop", bool(c.get("loop", false)))
	s.set("durs", c.get("durs", []))
	s.set("hold", bool(c.get("hold_last", false)))
	s.modulate.a = float(c.get("opacity", 1.0))
	s.frame = int(c.first)  # before the first draw: hitstop can freeze _process for the clip's whole life
	(parent if parent else world).add_child(s)
	if debug_fx:
		print("fx %s at=%s gpos=%s gscale=%s rot=%.2f vframes=%d first=%d tex=%s parent=%s" % [clip, at, s.global_position, s.global_scale, s.global_rotation, s.vframes, int(c.first), s.texture.get_size(), (parent if parent else world).name])
	return s


## White disc for a few hundredths of a second at an effect's origin: the "start point" every impact needs.
func flash(at: Vector2, radius: float) -> void:
	var f := Node2D.new()
	f.position = at
	f.z_index = 42
	f.set_script(preload("res://src/world/flash.gd"))
	f.set("radius", radius)
	world.add_child(f)


## Two-layer effect (10차 rt_ring / 8차 liquid spin style): the clip's "layers" sheets are drawn behind
## (z -1) and in front of the parent with the same frames. Both layer files start at slot 0.
func fx_layered(clip: String, at: Vector2, dir: Vector2, facing: float, flip_v: bool, parent: Node, scale_by := 1.0) -> void:
	var c: Dictionary = Anim.effects[clip]
	var layers: Dictionary = c.layers
	for key in ["back", "front"]:
		var lc := c.duplicate()
		lc.sheet = layers[key]
		lc.first = 0
		var tmp := "%s__%s" % [clip, key]
		Anim.effects[tmp] = lc
		var s := fx(tmp, at, dir, facing, flip_v, parent, scale_by)
		if key == "back":
			s.z_index = -1


## The v8 128px ultimate ring, scaled so its 50px source radius matches `radius`.
func ultimate_ring(at: Vector2, radius: float) -> void:
	var s := Sprite2D.new()
	s.texture = Anim.ultimate_texture
	s.hframes = 8
	s.vframes = 1
	s.centered = false
	s.offset = Vector2(-64, -64)
	s.position = at
	s.z_index = 41
	var mag := radius / 50.0
	s.scale = Vector2(mag, mag)
	s.set_script(preload("res://src/world/fx.gd"))
	s.set("first", 0)
	s.set("count", 8)
	s.set("fps", 20.0)
	s.frame = 0
	world.add_child(s)


## Afterimage of a sprite (body or arm root's children are copied shallowly by the caller).
func ghost(src: Sprite2D, life: float, alpha: float) -> void:
	var g := Sprite2D.new()
	g.texture = src.texture
	g.hframes = src.hframes
	g.vframes = src.vframes
	g.frame = src.frame
	g.region_enabled = src.region_enabled
	g.region_rect = src.region_rect
	g.centered = src.centered
	g.offset = src.offset
	g.flip_h = src.flip_h
	g.texture_filter = src.texture_filter
	g.global_transform = src.global_transform
	g.modulate = Color(1, 0.75, 0.8, alpha)
	g.z_index = 2
	g.z_as_relative = false
	g.set_script(preload("res://src/world/ghost.gd"))
	g.set("life", life)
	world.add_child(g)


## A guard (shield front, 가설 장벽) halved the hit the enemy at `at` is taking now: its number reads as blocked.
func mark_guarded(at: Vector2) -> void:
	_guard_at = at
	_guard_frame = Engine.get_physics_frames()


## Hit number (`at` = feet): outlined, sized by the hit, a quick pop, then it rises and fades. Enemy hits
## pop beside the body at torso height, on the side away from the player, flipped only when that side is
## off the view the camera is heading for and never onto the player (it would read as damage taken), so
## they never cross the overhead stack or the player; damage taken stays over the player's head. A hit
## blocked by a guard is a size smaller, grey, without the pop. A number spawning over or just under a live
## one starts above it instead; the younger label rises faster, so the gap only grows. An enemy number whose
## climb would pass under the HUD (EnemyBase.ui_keep_out: player status, boss bar, dialogue) takes the other
## side, else starts just below that panel and holds still, stacking down past its own burst.
func damage_number(at: Vector2, value: int) -> void:
	if value <= 0:
		return
	_numbers = _numbers.filter(func(n): return is_instance_valid(n))
	# shortcut: player.gd passes its own global_position for damage taken; give damage_number a flag if that changes
	var taken: bool = Game.player != null and at == Game.player.global_position
	var blocked := not taken and at == _guard_at and Engine.get_physics_frames() == _guard_frame
	if blocked:
		_guard_frame = -1   # one mark, one number
	var tier := 2 if value >= 60 else (1 if value >= 25 else 0)
	var size := UiText.sz([UiText.S, UiText.M, UiText.L, UiText.XL][tier + (0 if blocked else 1)])
	var col := Color(1.0, 0.45, 0.42) if taken else (UiText.DIM if blocked else (Color(1.0, 0.8, 0.38) if value >= 25 else Color(1.0, 0.95, 0.88)))
	var l := Label.new()
	l.text = str(value)
	UiText.style_label(l, size, col)
	var w := UiText.width(l.text, size)
	var lh := UiText.font().get_height(size)
	var pos := at + Vector2(-w * 0.5, -58.0)
	var still := false
	if not taken:
		var vw := world.get_viewport_rect().size.x
		var view_l := _view_left(vw)
		var side := 1.0 if Game.player == null or at.x >= Game.player.global_position.x else -1.0
		var reach := at.x - view_l + side * (28.0 + w)
		if reach > vw - 4.0 or reach < 4.0:
			var flip_x := at.x + (-28.0 - w * 0.5 if side > 0.0 else 28.0 + w * 0.5)   # the flipped label's centre
			if Game.player == null or absf(flip_x - Game.player.global_position.x) > 40.0:
				side = -side
		pos = at + Vector2(28.0 if side > 0.0 else -28.0 - w, -46.0)   # clear of the bar / icon column and the 내상 diamonds
		# the view clamp only nudges: right after a cut the camera target can still be the old view
		pos.x = clampf(clampf(pos.x, view_l + 4.0, view_l + vw - 4.0 - w), at.x - 36.0 - w, at.x + 36.0)
	var start := pos
	pos = _stack(pos, w, lh, -1.0)
	if not taken:
		var zone := _hud_zone(pos, w, lh, RISE)
		if zone.has_area():
			var alt := _stack(Vector2(2.0 * at.x - start.x - w, start.y), w, lh, -1.0)   # the other side
			if (Game.player == null or absf(alt.x + w * 0.5 - Game.player.global_position.x) > 40.0) and not _hud_zone(alt, w, lh, RISE).has_area():
				pos = alt
			else:
				still = true
				pos = _stack(Vector2(pos.x, maxf(start.y, zone.end.y + 2.0 + size * 0.35)), w, lh, 1.0)   # 0.35: the pop's overshoot
	l.position = pos
	l.set_meta("w", w)
	l.z_index = 50
	l.set_script(preload("res://src/world/ghost.gd"))
	l.set("life", 0.75)
	l.set("rise", 0.0 if still else RISE / 0.75)
	l.set("hold", 0.5)
	world.add_child(l)
	_numbers.append(l)
	if not blocked:
		l.pivot_offset = Vector2(w * 0.5, size * 0.7)
		l.scale = Vector2(1.5, 1.5)
		l.create_tween().tween_property(l, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Steps a number at `pos` past the live ones it would overlap: up above them (dir -1) or down below them
## (+1). Each pass only moves one way, past a label it has not cleared yet.
func _stack(pos: Vector2, w: float, lh: float, dir: float) -> Vector2:
	var moved := true
	while moved:
		moved = false
		for n in _numbers:
			var ny: float = n.position.y
			if n.position.x >= pos.x + w or pos.x >= n.position.x + float(n.get_meta("w")):
				continue
			if dir < 0.0 and ny > pos.y - 40.0 and ny - lh - 4.0 < pos.y:
				pos.y = ny - lh - 4.0   # 4: clear of the new label's 1.5x pop
				moved = true
			elif dir > 0.0 and absf(ny - pos.y) < lh + 4.0:
				pos.y = ny + lh + 4.0
				moved = true
	return pos


## The HUD panel (world rect) a number at `pos` would pass under on its way up `rise` px, else Rect2().
func _hud_zone(pos: Vector2, w: float, lh: float, rise: float) -> Rect2:
	var xf := world.get_global_transform_with_canvas()
	var path := xf * Rect2(pos.x, pos.y - rise - 2.0, w, lh + rise + 2.0)
	for z in EnemyBase.ui_keep_out(false):
		if path.intersects(z):
			return xf.affine_inverse() * z
	return Rect2()


## World x of the view's left edge where the camera is heading: its smoothed transform lags behind after a
## teleport, respawn or room unlock, and would flip a number onto the player.
func _view_left(vw: float) -> float:
	if not is_instance_valid(camera):
		return (world.get_viewport().get_canvas_transform().affine_inverse() * Vector2.ZERO).x
	var half: float = vw * 0.5 / camera.zoom.x
	return clampf(camera.get_target_position().x, camera.limit_left + half, maxf(camera.limit_left + half, camera.limit_right - half)) - half
