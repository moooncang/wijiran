extends Camera2D
## Follows the player, leaning toward the cursor (aim_point), with random shake and a directional kick on hits.
## Shake runs on unscaled time so it keeps moving during hitstop.

var shake := 0.0
var kick := 0.0
var _look := Vector2.ZERO
const LEAN := 0.4                      # fraction of the player→cursor vector the view moves
const LEAN_MAX := Vector2(160, 70)
var _player: Player


func setup(player: Player) -> void:
	_player = player
	position_smoothing_enabled = true
	position_smoothing_speed = 16.0
	set_bounds(0, -60, 1850, 400)  # ground is at y=300: keep ~100 px of floor below it, more sky above
	Juice.camera = self


func set_bounds(l: int, t: int, r: int, b: int) -> void:
	limit_left = l
	limit_top = t
	limit_right = r
	limit_bottom = b
	reset_smoothing()


func _process(delta: float) -> void:
	if _player == null:
		return
	var want := (_player.aim_point - _player.global_position) * LEAN
	want = want.clamp(-LEAN_MAX, LEAN_MAX)
	_look = _look.lerp(want, 1.0 - exp(-6.0 * delta))
	global_position = _player.global_position + Vector2(0, -70) + _look
	shake *= exp(-18.0 * delta)
	kick *= exp(-22.0 * delta)
	var s := shake if shake > 0.3 else 0.0
	offset = Vector2(kick + randf_range(-s, s), randf_range(-s, s) * 0.6)
