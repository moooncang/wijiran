extends CanvasLayer
## Autoload "Dialogue": a queue of short speaker lines shown at the top of the screen, never blocking
## play (본편: 대화는 짧게, 전투를 끊지 않는다). Dialogue.say(who, text) enqueues; lines auto-advance.

var queue: Array = []
var current: Dictionary = {}
var left := 0.0
var _label: Label
var _name: Label
var _panel: Panel


func _ready() -> void:
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = Panel.new()
	_panel.position = Vector2(200, 60)
	_panel.size = Vector2(400, 44)
	_panel.visible = false
	_panel.self_modulate = Color(0.08, 0.06, 0.08, 0.85)
	add_child(_panel)
	_name = Label.new()
	_name.position = Vector2(8, 4)
	_name.add_theme_font_size_override("font_size", 9)
	_name.add_theme_color_override("font_color", Color(1, 0.75, 0.6))
	_panel.add_child(_name)
	_label = Label.new()
	_label.position = Vector2(8, 18)
	_label.size = Vector2(384, 24)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 9)
	_label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.9))
	_panel.add_child(_label)


func say(who: String, text: String, seconds: float = 0.0) -> void:
	queue.append({"who": who, "text": text, "seconds": seconds if seconds > 0.0 else clampf(1.6 + text.length() * 0.06, 2.0, 6.0)})


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
		_panel.visible = true
