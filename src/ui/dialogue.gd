extends CanvasLayer
## Autoload "Dialogue": a queue of short speaker lines shown at the top of the screen, never blocking
## play (본편: 대화는 짧게, 전투를 끊지 않는다). Dialogue.say(who, text) enqueues; lines auto-advance.

var queue: Array = []
var current: Dictionary = {}
var left := 0.0
var _label: Label
var _name: Label
var _panel: Panel
var _portrait: TextureRect
var _frame: NinePatchRect
const PORTRAITS := {"위지란": "portrait_wi_jiran_neutral", "티아넬": "portrait_tianel_cold", "제자": "portrait_disciple", "레나타": "portrait_renata", "구출된 제자": "portrait_disciple_f"}


func _ready() -> void:
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = Panel.new()
	_panel.position = Vector2(176, 56)
	_panel.size = Vector2(448, 54)
	_panel.visible = false
	_panel.self_modulate = Color(0, 0, 0, 0)
	add_child(_panel)
	_frame = NinePatchRect.new()
	_frame.texture = Anim.ui_tex("dialogue_frame")
	var ns: Array = Anim.ui.dialogue_frame.get("nine_slice", [8, 8, 8, 8])
	_frame.patch_margin_left = int(ns[0])
	_frame.patch_margin_top = int(ns[1])
	_frame.patch_margin_right = int(ns[2])
	_frame.patch_margin_bottom = int(ns[3])
	_frame.size = _panel.size
	_panel.add_child(_frame)
	_portrait = TextureRect.new()
	_portrait.position = Vector2(4, 3)
	_portrait.size = Vector2(48, 48)
	_panel.add_child(_portrait)
	_name = Label.new()
	_name.position = Vector2(58, 5)
	_name.add_theme_font_size_override("font_size", 9)
	_name.add_theme_color_override("font_color", Color(1, 0.75, 0.6))
	_panel.add_child(_name)
	_label = Label.new()
	_label.position = Vector2(58, 20)
	_label.size = Vector2(380, 30)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 9)
	_label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.9))
	_panel.add_child(_label)


func say(who: String, text: String, seconds: float = 0.0, portrait := "") -> void:
	queue.append({"who": who, "text": text, "portrait": portrait if portrait != "" else String(PORTRAITS.get(who, "")), "seconds": seconds if seconds > 0.0 else clampf(1.6 + text.length() * 0.06, 2.0, 6.0)})


func clear() -> void:
	queue.clear()
	current = {}
	left = 0.0
	_panel.visible = false


func _process(delta: float) -> void:
	if Game.paused:
		return
	if left > 0.0:
		left -= delta
		if left <= 0.0:
			current = {}
			_panel.visible = false
	if current.is_empty() and not queue.is_empty():
		current = queue.pop_front()
		left = float(current.seconds)
		_name.text = String(current.who)
		_label.text = String(current.text)
		var pk := String(current.get("portrait", ""))
		_portrait.visible = pk != "" and Anim.ui.has(pk)
		if _portrait.visible:
			_portrait.texture = Anim.ui_tex(pk)
		_panel.visible = true
