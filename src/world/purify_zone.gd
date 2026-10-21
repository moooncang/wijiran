extends Node2D
## 정화 구역 (본편 §8): white incense laid on the floor. While the player's feet are inside, the player's
## injury-burst damage is reduced (Player.purify); nothing else changes. Lives `life` seconds.
## Art: the 11차 purify_zone loop (160×36 on the floor) with its in/out bursts; the "정화" tag stays on the
## world-text layer so bodies never cover it.

const TINT := Color(0.86, 0.93, 1.0)   # hud.gd PURIFY: the tag and the HUD's 정화 status line read as one thing

var radius := 80.0
var height := 36.0
var life := 12.0
var _t := 0.0
var _label: Node2D
var _art: Sprite2D
var _ending := false


func _ready() -> void:
	add_to_group("purify_zone")
	z_index = -1
	_label = Node2D.new()
	_label.z_as_relative = false
	_label.z_index = Interactable.UI_Z
	_label.modulate.a = 0.0
	_label.draw.connect(_draw_label)
	add_child(_label)
	Juice.fx("purify_zone_in", global_position)
	_art = Juice.fx("purify_zone", Vector2.ZERO, Vector2.RIGHT, 1.0, false, self)
	_art.z_index = 0


func rect() -> Rect2:
	return Rect2(global_position.x - radius, global_position.y - height, radius * 2.0, height)


func _physics_process(dt: float) -> void:
	if Juice.frozen():
		return
	_t += dt
	life -= dt
	if life <= 0.0:
		if not _ending:
			_ending = true
			Juice.fx("purify_zone_out", global_position)
		queue_free()
		return
	var p := Game.player
	if p and rect().intersects(p.hurt_rect()):
		p.purify(0.5)
	if is_instance_valid(_art):
		_art.modulate.a = clampf(life, 0.0, 1.0)   # the strip thins out over its last second
	_label.modulate.a = clampf(life * 3.0, 0.0, 1.0)
	_label.queue_redraw()   # re-placed as the camera moves


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
