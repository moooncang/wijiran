extends Node2D
## 정화 구역 (본편 §8): white incense laid on the floor. While the player's feet are inside, the player's
## injury-burst damage is reduced (Player.purify); nothing else changes. Lives `life` seconds.
## Drawn as a soft floor glow with rising smoke, a floor line and end ticks (no box: it is holy ground,
## not a hitbox). Code-drawn until the 11차 purify_zone clip.

const PUFFS := 10
const TINT := Color(0.86, 0.93, 1.0)   # hud.gd PURIFY: the tag and the HUD's 정화 status line read as one thing

var radius := 80.0
var height := 36.0
var life := 12.0
var _t := 0.0
var _label: Node2D   # "정화" over the zone's left end, on the world-text layer so bodies never cover it


func _ready() -> void:
	add_to_group("purify_zone")
	z_index = -1
	_label = Node2D.new()
	_label.z_as_relative = false
	_label.z_index = Interactable.UI_Z
	_label.modulate.a = 0.0
	_label.draw.connect(_draw_label)
	add_child(_label)


func rect() -> Rect2:
	return Rect2(global_position.x - radius, global_position.y - height, radius * 2.0, height)


func _physics_process(dt: float) -> void:
	if Juice.frozen():
		return
	_t += dt
	life -= dt
	if life <= 0.0:
		queue_free()
		return
	var p := Game.player
	if p and rect().intersects(p.hurt_rect()):
		p.purify(0.5)
	queue_redraw()
	_label.modulate.a = clampf(life * 3.0, 0.0, 1.0)   # full strength at once (no ghosted tag), fades with the zone's end
	_label.queue_redraw()   # re-placed as the camera moves


## Fades in over 0.3 s and out over the last second.
func _alpha() -> float:
	return clampf(minf(life, _t / 0.3), 0.0, 1.0)


func _draw() -> void:
	var a := _alpha()
	var r := radius
	# floor glow: strongest on the floor, gone at the top of the zone
	var glow := Color(0.95, 0.96, 1.0, 0.26 * a)
	var clear := Color(0.95, 0.96, 1.0, 0.0)
	draw_polygon(PackedVector2Array([Vector2(-r, 0), Vector2(r, 0), Vector2(r, -height), Vector2(-r, -height)]), PackedColorArray([glow, glow, clear, clear]))
	# smoke puffs rise from the floor, swell and fade
	for i in PUFFS:
		var u := fmod(_t * 0.45 + i * 0.37, 1.0)
		var x := -r + (i + 0.5) * r * 2.0 / PUFFS + sin(_t * 1.7 + i * 2.1) * 3.0
		draw_circle(Vector2(x, -2.0 - u * (height - 4.0)), 2.0 + u * 3.5, Color(0.95, 0.97, 1.0, 0.32 * a * (1.0 - u)))
	# the extent: a floor line with short end ticks
	var edge := Color(0.92, 0.9, 1.0, 0.7 * a)
	draw_line(Vector2(-r, -1), Vector2(r, -1), edge, 1.0)
	draw_line(Vector2(-r + 0.5, -1), Vector2(-r + 0.5, -6), edge, 1.0)
	draw_line(Vector2(r - 0.5, -1), Vector2(r - 0.5, -6), edge, 1.0)
	draw_circle(Vector2(0, -2), 6.0, Color(0.85, 0.7, 0.3, a))   # the sun badge at the centre


## Name over the zone's left end, off the centre where the keeper and the player stand; kept on screen
## and clear of the HUD / controls like the other world text, and not drawn while the zone is off screen.
func _draw_label() -> void:
	var x := _label.get_global_transform_with_canvas().origin.x
	if x + radius < 0.0 or x - radius > _label.get_viewport_rect().size.x:
		return
	var fs := UiText.sz(UiText.S)
	var asc := UiText.font().get_ascent(fs)
	var r := Interactable.place(_label, Rect2(-radius + 3.0, -height - 3.0 - asc, UiText.width("정화", fs), UiText.font().get_height(fs)))
	UiText.draw(_label, Vector2(r.position.x, r.position.y + asc), "정화", fs, TINT)
