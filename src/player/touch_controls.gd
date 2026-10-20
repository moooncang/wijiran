extends Control
## On-screen controls for touch devices: a floating stick on the left (move; its direction is also the
## aim for attacks and the 360° dash) and skill buttons on the right. Buttons drive the same InputMap
## actions the keyboard uses, so the player code is untouched. Shown only on touch builds.
## Layout (canvas px): stick bottom-left, buttons inside x 540–800 / y 230–450, clear of the top-right
## status block. 상호작용 shows only next to something usable; 복귀 (back to the checkpoint) must be held.
## Runs while paused so touches held when the palm menu opens still get released; the menu itself takes taps.
## Controls something stands under (the player, an enemy and its overhead bar, a fallen boss, a usable door /
## rescue / rest point, a hazard plate) fade their fill so it stays readable; names stay legible and cooldown
## seconds never fade. 상호작용 never fades: it is the "press now" cue. While the player is dead everything is
## released, inert and drawn faint under the death card. Under the first-entry card the controls fade out with it.
## Where combat is off (쌍등객잔) the combat buttons are hidden, like the PC key panel.
## Turned to portrait (the shell's rotate prompt covers the canvas) every touch is released and the game pauses
## until landscape is back.

const PAD_RADIUS := 46.0
const PAD_HOME := Vector2(92, 384)
const DEAD := 0.28
const SLOP := 6.0          # extra touch radius around each button
const RESET_HOLD := 0.5    # seconds: 복귀 throws away the fight, so a stray thumb must not trigger it
const FADED := 0.3         # fill alpha of a control with something under it (its ring and name keep more)
const LABEL_FADED := 0.75  # a faded control's name never drops below this, so it reads over busy scenery
const OVERHEAD := 18.0     # px above an enemy's hurt_top: its HP bar and 무방비 tag
const COMBAT_ONLY := ["attack", "heavy", "pull", "ult", "parry"]
const HazardPlate := preload("res://src/world/hazard_plate.gd")
# name: [centre (viewport px), radius, action, label]
const BUTTONS := {
	"attack": [Vector2(728, 394), 33.0, "attack_key", "장법"],
	"jump": [Vector2(764, 318), 25.0, "jump", "점프"],
	"dash": [Vector2(648, 418), 25.0, "dash", "잔월보"],
	"parry": [Vector2(664, 344), 24.0, "parry", "패링"],
	"heavy": [Vector2(716, 282), 22.0, "heavy_attack", "강화"],
	"interact": [Vector2(622, 274), 31.0, "interact", "상호작용"],
	"pull": [Vector2(588, 354), 22.0, "skill_pull", "월인"],
	"ult": [Vector2(580, 414), 22.0, "ultimate", "월식"],
	"reset": [Vector2(772, 252), 17.0, "", "복귀"],   # no action: fires Game.respawn() after the hold
}

var player: Player
var pad_touch := -1
var pad_origin := Vector2.ZERO
var pad_vec := Vector2.ZERO
var _button_touch: Dictionary = {}   # touch index → button name
var _held: Dictionary = {}           # button name → seconds held (-1 once 복귀 has fired)
var _fade: Dictionary = {}           # button name / "pad" → alpha multiplier, eased toward FADED or 1
var _shown: Dictionary = {"interact": 0.0}   # button name → 0..1, eased in and out with _wanted()
var _portrait := false
var _rotation_paused := false   # this node paused the game for portrait; only then does it unpause


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for a in BUTTONS:   # layout guard: every button inside its zone, no two touch areas overlapping
		var ca: Vector2 = BUTTONS[a][0]
		var ra: float = BUTTONS[a][1]
		assert(Rect2(540, 230, 260, 220).grow(-ra).has_point(ca), "touch button %s leaves its zone" % a)
		for b in BUTTONS:
			assert(a == b or ca.distance_to(BUTTONS[b][0]) >= ra + float(BUTTONS[b][1]) + SLOP * 2.0, "touch buttons %s/%s overlap" % [a, b])


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var idx: int = event.index
		if event.pressed:
			if get_tree().paused or _dead() or _card() > 0.0:   # palm menu: it takes its own taps; dead / card: nothing to drive
				return
			var b := _button_at(event.position)
			if b != "":
				_button_touch[idx] = b
				_held[b] = 0.0
				_set_action(String(BUTTONS[b][2]), true)
				get_viewport().set_input_as_handled()
			elif event.position.x < get_viewport_rect().size.x * 0.45 and pad_touch < 0:  # the control itself has no size inside the layer
				pad_touch = idx
				pad_origin = event.position
				pad_vec = Vector2.ZERO
				get_viewport().set_input_as_handled()
		else:
			if _button_touch.has(idx):
				var b: String = _button_touch[idx]
				if b == "reset" and float(_held[b]) >= 0.0 and player:   # let go before it fired: say how it works
					player._say("길게 눌러 복귀")
				_button_touch.erase(idx)
				_held.erase(b)
				_set_action(String(BUTTONS[b][2]), false)
				get_viewport().set_input_as_handled()
			elif idx == pad_touch:
				pad_touch = -1
				pad_vec = Vector2.ZERO
				_apply_pad()
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == pad_touch:
		pad_vec = (event.position - pad_origin) / PAD_RADIUS
		if pad_vec.length() > 1.0:
			pad_vec = pad_vec.normalized()
		_apply_pad()
		get_viewport().set_input_as_handled()


## Nearest shown button whose (slightly enlarged) circle contains p; one fading in or out takes taps past half way.
func _button_at(p: Vector2) -> String:
	var best := ""
	var best_d := SLOP
	for b in BUTTONS:
		if float(_shown.get(b, 1.0)) <= 0.5:
			continue
		var d: float = p.distance_to(BUTTONS[b][0]) - float(BUTTONS[b][1])
		if d <= best_d:
			best = b
			best_d = d
	return best


## Whether a button belongs on screen: 상호작용 next to something usable, combat buttons where combat is on.
func _wanted(b: String) -> bool:
	if b == "interact":
		return not _dead() and _can_interact()
	return player == null or player.combat_enabled or b not in COMBAT_ONLY


## Same test main uses for ↑, minus label-less things (signs) where pressing does nothing.
func _can_interact() -> bool:
	for it in get_tree().get_nodes_in_group("interactable"):
		if it.near and it.label != "" and it.available():
			return true
	return false


## Stick → move_left/right + crouch actions, and the aim vector for the player.
func _apply_pad() -> void:
	var left := pad_vec.x < -DEAD
	var right := pad_vec.x > DEAD
	_set_action("move_left", left)
	_set_action("move_right", right)
	_set_action("crouch", pad_vec.y > 0.75 and absf(pad_vec.x) < 0.5)
	if player:
		player.touch_aim = pad_vec if pad_vec.length() > DEAD else Vector2.ZERO


func _set_action(action: String, on: bool) -> void:
	if action == "":
		return
	if on and not Input.is_action_pressed(action):
		Input.action_press(action)
	elif not on and Input.is_action_pressed(action):
		Input.action_release(action)


func _dead() -> bool:
	return player != null and player.dead


## Lets go of every held button and the stick (the player died with a thumb down).
func _release_all() -> void:
	for idx in _button_touch:
		_set_action(String(BUTTONS[_button_touch[idx]][2]), false)
	_button_touch.clear()
	_held.clear()
	pad_touch = -1
	pad_vec = Vector2.ZERO
	_apply_pad()


## Screen rects the controls must not hide: the player, every live enemy with its overhead bar and tag, a
## fallen boss, anything usable (exit door, rescue, rest point) and hazard plates (their telegraph).
func _bodies() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if player:
		out.append(_box(player, 14.0, -54.0))
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.visible and (e.status.is_boss or e.status.alive()):
			var hw = e.get("hurt_half_width")   # the training dummy has none
			out.append(_box(e, 12.0 if hw == null else float(hw), float(e.hurt_top) - OVERHEAD))
	for it in get_tree().get_nodes_in_group("interactable"):
		if it.visible and it.label != "" and (it.near or it.available()):   # its art, and its prompt pill while one shows
			out.append(_box(it, 16.0, Interactable.PROMPT_BOTTOM - Interactable.pill_height() if it.shows_pill() else -56.0))
	if is_instance_valid(Game.level):
		for n in Game.level.get_children():
			if n.get_script() == HazardPlate:
				out.append(_box(n, HazardPlate.W * 0.5, -HazardPlate.H))
	return out


## Screen rect (plus 6 px) of something standing on n's origin: half_width each side, from `top` (< 0) to the feet.
func _box(n: CanvasItem, half_width: float, top: float) -> Rect2:
	var o := n.get_global_transform_with_canvas().origin
	return Rect2(o + Vector2(-half_width, top), Vector2(half_width * 2.0, -top)).grow(6.0)


## Opacity of main's first-entry card (0 when none is up).
func _card() -> float:
	var s := get_tree().current_scene
	var c = s.get("cutscene") if s else null
	return c.modulate.a if c is CanvasItem and c.visible else 0.0


## Where the stick is drawn: the touch-down point (or home) kept fully on screen; input keeps the real origin.
func _pad_base() -> Vector2:
	var m := PAD_RADIUS + 10.0
	return (pad_origin if pad_touch >= 0 else PAD_HOME).clamp(Vector2(m, m), get_viewport_rect().size - Vector2(m, m))


func _process(delta: float) -> void:
	_check_rotation()
	if _dead() and (pad_touch >= 0 or not _button_touch.is_empty()):
		_release_all()
	if _held.has("reset") and float(_held["reset"]) >= 0.0:
		_held["reset"] = float(_held["reset"]) + delta
		if float(_held["reset"]) >= RESET_HOLD:
			_held["reset"] = -1.0
			if not Game.paused:
				Game.respawn()
	# fade (eased, so walking past does not flicker) any control something stands under; held ones stay solid
	var bodies := _bodies()
	for k in BUTTONS.keys() + ["pad"]:
		var c: Vector2 = _pad_base() if k == "pad" else BUTTONS[k][0]
		var r: float = PAD_RADIUS + 4.0 if k == "pad" else float(BUTTONS[k][1])
		var held: bool = pad_touch >= 0 if k == "pad" else _held.has(k)
		var under: bool = k != "interact" and not held and bodies.any(func(body: Rect2) -> bool: return body.grow(r).has_point(c))
		_fade[k] = move_toward(float(_fade.get(k, 1.0)), FADED if under else 1.0, delta * 6.0)
		if k != "pad":   # in and out at the pace of the world prompt beside 상호작용
			_shown[k] = move_toward(float(_shown.get(k, 1.0)), 1.0 if _wanted(k) else 0.0, delta / Interactable.FADE)
	modulate.a = 1.0 - _card()
	queue_redraw()


## Portrait: the shell covers the canvas with its rotate prompt, so let go of every thumb and hold the fight
## until landscape is back. A pause someone else owns (the palm menu) is left alone both ways.
func _check_rotation() -> void:
	var win := get_window().size
	var portrait := win.y > win.x
	if portrait == _portrait:
		return
	_portrait = portrait
	if portrait:
		_release_all()
		_rotation_paused = not Game.paused
		if _rotation_paused:
			Game.set_paused(true)
	elif _rotation_paused:
		_rotation_paused = false
		Game.set_paused(false)


## True when pressing would do something; otherwise the button is drawn dim.
func _usable(b: String) -> bool:
	if player == null:
		return true
	match b:
		"attack":
			return player.combat_enabled
		"dash":
			return player.is_on_floor() or player.air_dash_available
		"heavy":
			return player.combat_enabled and player.tremor_left == 0.0 and player.qi >= float(PalmStyles.heavy(player.style_id).qi_cost)
		"pull":
			return player.combat_enabled and player.pull_cooldown == 0.0 and player.qi >= Player.PULL_QI
		"ult":
			return player.tremor_left == 0.0 and player.ult_cooldown == 0.0 and player.gauge >= CombatConfig.ULT_GAUGE_COST and player.qi >= CombatConfig.ULT_QI_COST
	return true


## Seconds until a cooling skill is back (0 = not cooling), shown on its button like the PC panel's "재사용".
func _cooldown(b: String) -> float:
	if player == null:
		return 0.0
	match b:
		"pull":
			return player.pull_cooldown
		"ult":
			return player.ult_cooldown
	return 0.0


## Rim progress 0..1 (1 = nothing to show): cooldown recharge, 월식 gauge, 복귀 hold.
func _charge(b: String) -> float:
	if player == null:
		return 1.0
	match b:
		"pull":
			return 1.0 - player.pull_cooldown / Player.PULL_COOLDOWN
		"ult":
			if player.ult_cooldown > 0.0:
				return 1.0 - player.ult_cooldown / CombatConfig.ULT_COOLDOWN
			return clampf(player.gauge / CombatConfig.ULT_GAUGE_COST, 0.0, 1.0)
		"reset":
			if _held.has("reset") and float(_held["reset"]) >= 0.0:
				return float(_held["reset"]) / RESET_HOLD
	return 1.0


func _draw() -> void:
	if get_tree().paused or modulate.a <= 0.0:   # the palm menu / entry card covers the screen; nothing of ours shows through
		return
	var dead := _dead()
	var dim := 0.25 if dead else 1.0   # dead: inert, faint under the death card
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
	# stick
	var active := pad_touch >= 0
	var base := _pad_base()
	var a: float = dim * float(_fade.get("pad", 1.0))
	draw_circle(base, PAD_RADIUS + 4.0, Color(0.1, 0.07, 0.1, (0.38 if active else 0.22) * a))
	_ring(base, PAD_RADIUS + 4.0, Color(UiText.ACCENT, (0.6 if active else 0.35) * a))
	var knob := base + pad_vec * PAD_RADIUS
	draw_circle(knob, 18.0, Color(1, 0.85, 0.7, (0.55 if active else 0.3) * a))
	if not active:
		_label(knob, "이동", UiText.sz(UiText.XS), Color(UiText.INK, 0.85 * dim * maxf(float(_fade.get("pad", 1.0)), LABEL_FADED)))
	# buttons
	for b in BUTTONS:
		var shown := float(_shown.get(b, 1.0))
		if shown <= 0.0:
			continue
		var c: Vector2 = BUTTONS[b][0]
		var r: float = BUTTONS[b][1]
		var usable := _usable(b)
		var fade := float(_fade.get(b, 1.0))
		a = dim * shown * fade
		var fill := Color(0.1, 0.06, 0.1, 0.2)   # light, so sprites and telegraphs read through
		if b == "attack":
			fill = Color(0.5, 0.12, 0.18, 0.5)
		elif b == "interact":
			fill = Color(0.42, 0.28, 0.12, 0.6)
		if _held.has(b):
			fill = Color(0.88, 0.34, 0.3, 0.78)
		elif not usable:
			fill.a *= 0.45
		fill.a *= a
		draw_circle(c, r, fill)
		var ring_a := dim * shown * (0.25 + 0.75 * fade)   # the outline stays findable while faded, but fainter
		_ring(c, r, Color(UiText.ACCENT, (0.8 if usable else 0.3) * ring_a))
		var charge := _charge(b)
		if charge > 0.02 and charge < 1.0:
			draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * charge, 40, Color(UiText.INK if b == "reset" else UiText.ACCENT, ring_a), 3.0, true)
		if (b == "interact" or b == "ult") and usable and not dead:   # "press me now": 상호작용 nearby, 월식 charged
			draw_arc(c, r + 3.5, 0.0, TAU, 40, Color(UiText.ACCENT, (0.3 + 0.45 * pulse) * ring_a), 2.0, true)
		var label: String = BUTTONS[b][3]
		# only fill and ring dim: the outlined name stays readable over the world, the seconds never fade
		var col := Color(UiText.INK if usable else UiText.DIM, dim * shown * maxf(fade, LABEL_FADED))
		var cd := _cooldown(b)
		if cd > 0.0:   # name above, whole seconds left below, rounded up like the HUD's "재사용 3"
			_label(c + Vector2(0, -6), label, UiText.sz(UiText.XS), col)
			_label(c + Vector2(0, 7), "%d" % ceili(cd), UiText.sz(UiText.S), Color(UiText.ACCENT, dim * shown))
		else:
			_label(c, label, _fit(label, r, UiText.sz(UiText.M if b == "attack" else UiText.S)), col)


## Warm gold ring (the UI's frame colour) with a 1-px dark rim outside, so it reads on bright scenery.
func _ring(c: Vector2, r: float, col: Color) -> void:
	draw_arc(c, r + 1.5, 0.0, TAU, 48, Color(UiText.OUTLINE, UiText.OUTLINE.a * col.a), 1.0, true)
	draw_arc(c, r, 0.0, TAU, 48, col, 2.0, true)


## Largest size ≤ start (never below XS) whose label stays inside the circle with a margin.
func _fit(label: String, r: float, start: int) -> int:
	var size := start
	while size > UiText.sz(UiText.XS) and UiText.width(label, size) > r * 2.0 - 12.0:
		size -= 1
	return size


## One line centred on a point; unlike UiText.centered its outline fades with the text.
func _label(c: Vector2, text: String, size: int, col: Color) -> void:
	var f := UiText.font()
	var pos := Vector2(roundf(c.x - UiText.width(text, size) * 0.5), c.y + roundf((f.get_ascent(size) - f.get_descent(size)) * 0.5))
	draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(UiText.OUTLINE, UiText.OUTLINE.a * col.a))
	draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
