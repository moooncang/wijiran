extends Node
## Game-feel helpers: hitstop, camera shake, effect clips (effects_v9 metadata driven), ghosts, numbers.

var camera  # GameCamera
var world: Node2D
var _stop_until := 0
var debug_fx := false


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
		"hit_direction":
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


func damage_number(at: Vector2, value: int) -> void:
	var l := Label.new()
	l.text = str(value)
	l.position = at + Vector2(-6, -50)
	l.z_index = 50
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", Color(1, 0.89, 0.81))
	l.set_script(preload("res://src/world/ghost.gd"))
	l.set("life", 0.6)
	l.set("rise", 30.0)
	world.add_child(l)
