extends Camera2D
## Follows the player, leaning toward the cursor (aim_point), with random shake and a directional kick on hits.
## Shake runs on unscaled time so it keeps moving during hitstop.

var shake := 0.0
var kick := 0.0
var _look := Vector2.ZERO
const LEAN := 0.4                      # fraction of the player→cursor vector the view moves
const LEAN_MAX := Vector2(160, 70)
const TOUCH_PAD := 200                 # touch: how far the view may run past both map ends
const CUT := 250.0                     # a player jump longer than this in one frame (teleport, respawn) cuts
const FEET_MIN := 235                  # canvas y her feet never sit above: below the notice, map title and her prompt
var _player: Player
var _last := Vector2.INF
var _top := -60                        # the level's (or locked room's) own top limit
var _floor_y := 1.0e6                  # last on-floor y (not the live y, so a jump does not bob the view)


func setup(player: Player) -> void:
	_player = player
	position_smoothing_enabled = true
	position_smoothing_speed = 16.0
	limit_smoothed = true   # a room lock/clear glides to the new bounds instead of jumping
	set_bounds(0, -60, 1850, 400)  # ground is at y=300: keep ~100 px of floor below it, more sky above
	Juice.camera = self


## On touch builds a whole map (not a locked room or arena, which are narrower than the view) gets
## TOUCH_PAD more on each side: clamped to the map edge, a spawn at x=80 sat under the stick and an exit
## door under the right-hand buttons. The art, floors and backdrops all reach that far past the ends.
func set_bounds(l: int, t: int, r: int, b: int) -> void:
	var pad := TOUCH_PAD if UiText.touch and r - l >= int(get_viewport_rect().size.x) else 0
	limit_left = l - pad
	_top = t
	limit_top = mini(_top, int(_floor_y) - FEET_MIN)
	limit_right = r + pad
	limit_bottom = b   # no reset_smoothing here: main snaps the camera itself after a level load


func _process(delta: float) -> void:
	if _player == null:
		return
	var p := _player.global_position
	var cut := p.distance_squared_to(_last) > CUT * CUT
	_last = p
	if cut or _player.is_on_floor():
		_floor_y = p.y
	# a high perch (F1's roofs) raises the view so she stays clear of the top-centre UI; limit_smoothed glides it
	limit_top = mini(_top, int(_floor_y) - FEET_MIN)
	var want := (_player.aim_point - p) * LEAN
	want = want.clamp(-LEAN_MAX, LEAN_MAX)
	_look = want if cut else _look.lerp(want, 1.0 - exp(-6.0 * delta))
	global_position = p + Vector2(0, -70) + _look
	if cut:
		reset_smoothing()   # a teleport cuts to the new spot instead of sliding across the map
	shake *= exp(-18.0 * delta)
	kick *= exp(-22.0 * delta)
	var s := shake if shake > 0.3 else 0.0
	offset = Vector2(kick + randf_range(-s, s), randf_range(-s, s) * 0.6)
