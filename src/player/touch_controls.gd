extends Control
## On-screen controls for touch devices: a floating stick on the left (move; its direction is also the
## aim for attacks and the 360° dash) and skill buttons on the right. Buttons drive the same InputMap
## actions the keyboard uses, so the player code is untouched. Shown only when a touchscreen exists.

const PAD_RADIUS := 46.0
const DEAD := 0.28
# name: [centre (viewport px), radius, action, label]
const BUTTONS := {
	"attack": [Vector2(708, 392), 34.0, "attack_key", "장법"],
	"dash": [Vector2(636, 338), 25.0, "dash", "잔월보"],
	"jump": [Vector2(766, 330), 25.0, "jump", "점프"],
	"parry": [Vector2(628, 408), 25.0, "parry", "패링"],
	"heavy": [Vector2(700, 300), 21.0, "heavy_attack", "강화"],
	"pull": [Vector2(580, 352), 21.0, "skill_pull", "월인"],
	"ult": [Vector2(760, 262), 21.0, "ultimate", "월식"],
	"portal": [Vector2(60, 280), 19.0, "interact", "포탈"],
	"reset": [Vector2(770, 120), 15.0, "reset", "R"],
}

var player: Player
var pad_touch := -1
var pad_origin := Vector2.ZERO
var pad_vec := Vector2.ZERO
var _button_touch: Dictionary = {}   # touch index → button name
var _held: Dictionary = {}           # button name → true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var idx: int = event.index
		if event.pressed:
			var b := _button_at(event.position)
			if b != "":
				_button_touch[idx] = b
				_held[b] = true
				Input.action_press(String(BUTTONS[b][2]))
				get_viewport().set_input_as_handled()
			elif event.position.x < get_viewport_rect().size.x * 0.45 and pad_touch < 0:  # the control itself has no size inside the layer
				pad_touch = idx
				pad_origin = event.position
				pad_vec = Vector2.ZERO
				get_viewport().set_input_as_handled()
		else:
			if _button_touch.has(idx):
				var b: String = _button_touch[idx]
				_button_touch.erase(idx)
				_held.erase(b)
				Input.action_release(String(BUTTONS[b][2]))
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
	queue_redraw()


func _button_at(p: Vector2) -> String:
	for b in BUTTONS:
		if p.distance_to(BUTTONS[b][0]) <= float(BUTTONS[b][1]) + 6.0:
			return b
	return ""


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
	if on and not Input.is_action_pressed(action):
		Input.action_press(action)
	elif not on and Input.is_action_pressed(action):
		Input.action_release(action)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var font := Anim.font
	# stick
	var base := pad_origin if pad_touch >= 0 else Vector2(96, 372)
	draw_circle(base, PAD_RADIUS + 4.0, Color(0.1, 0.08, 0.1, 0.45))
	draw_arc(base, PAD_RADIUS + 4.0, 0.0, TAU, 32, Color(1, 0.9, 0.8, 0.5), 2.0)
	draw_circle(base + pad_vec * PAD_RADIUS, 18.0, Color(1, 0.85, 0.7, 0.55 if pad_touch >= 0 else 0.3))
	if pad_touch < 0:
		draw_string(font, base + Vector2(-16, 4), "이동", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.6))
	# buttons
	for b in BUTTONS:
		var c: Vector2 = BUTTONS[b][0]
		var r: float = BUTTONS[b][1]
		var on: bool = _held.has(b)
		var col := Color(0.85, 0.3, 0.3, 0.75) if on else Color(0.12, 0.08, 0.12, 0.5)
		if b == "attack":
			col = Color(0.9, 0.35, 0.3, 0.85) if on else Color(0.45, 0.12, 0.18, 0.6)
		draw_circle(c, r, col)
		draw_arc(c, r, 0.0, TAU, 32, Color(1, 0.9, 0.8, 0.7), 2.0)
		var label: String = BUTTONS[b][3]
		draw_string(font, c + Vector2(-label.length() * 4.5, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 0.97, 0.92))
