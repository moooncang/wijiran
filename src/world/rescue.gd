extends "res://src/world/interactable.gd"
## 구출 대상 제자 (본편 §7 5구역, §8): sits bound until the room is clear, W/↑ frees them. The rescue is a
## permanent flag (never undone by death, §10), then the disciple walks off along the safe route and is
## gone on re-entry. No escort, no HP (기획). Uses the 10차 disciple sheets (idle / bow / walk).

const CORD := Color(0.62, 0.12, 0.16)
const CORD_DARK := Color(0.3, 0.05, 0.08)

var rescue_id := ""
var who := "disciple_m"
var exit_dir := -1.0
var sprite: ClipSprite
var _leaving := false
var _gone := false
var _cord: Node2D               # the binding rope, drawn over the sprite


func _ready() -> void:
	super()
	label = "제자 풀어주기"
	sprite = ClipSprite.new()
	sprite.setup(Anim.sheets[who])
	sprite.set_facing(-exit_dir)
	sprite.z_index = 1
	add_child(sprite)
	_cord = Node2D.new()
	_cord.z_index = 1   # same layer as the sprite, added after it: drawn on top
	_cord.draw.connect(_draw_cord)
	add_child(_cord)
	if Game.flag("rescued:" + rescue_id):
		_gone = true
		visible = false


func available() -> bool:
	if _gone or _leaving:
		return false
	var lv := get_parent()
	return not (lv is Level and lv._enemy_count > 0)


func locked_hint() -> String:
	return "" if _gone or _leaving else "적을 모두 쓰러뜨린 뒤 풀어줄 수 있다"


func _use() -> void:
	# Only the first disciple freed in a visit speaks: the f2 pair stand 70 px apart.
	var first := true
	for it in get_tree().get_nodes_in_group("interactable"):
		if it != self and it.get_script() == get_script() and it._leaving:
			first = false
	Game.set_flag("rescued:" + rescue_id, true)
	_leaving = true
	label = ""
	_cord.visible = false
	sprite.play("bow", true)
	Juice.fx("parry_perfect_fx", global_position + Vector2(0, -24))
	Game.notice.emit("제자를 구출했습니다 — 안전 경로로 보냅니다")
	if first:   # queued behind a running exchange (B3 frees her inside Elodie's arena), never cutting it
		Dialogue.say("제자", "단주님… 끈을, 끈을 늘리지 않으셨군요.", 0.0, "portrait_disciple_f" if who == "disciple_f" else "", false)
		Dialogue.say("위지란", "가. 뒤는 보지 말고. 쌍등객잔에서 봐.", 0.0, "", false)


func _process(delta: float) -> void:
	super(delta)
	if Juice.frozen() or _gone:
		return
	if _leaving:
		if sprite.clip == "bow" and sprite._done:
			sprite.play("walk" if sprite.sheet.clips.has("walk") else "idle", true)
			sprite.set_facing(exit_dir)
		if sprite.clip == "walk":
			global_position.x += exit_dir * 70.0 * delta
			var lv := get_parent()
			if lv is Level and (global_position.x < -40.0 or global_position.x > lv.width + 40.0):
				_gone = true
				visible = false
	sprite.tick(delta)


## Rope wound twice around the chest and tied off at the side.
func _draw_cord() -> void:
	var s := -exit_dir   # the side the disciple faces: the knot sits there
	for y in [-33.0, -26.0]:
		_cord.draw_line(Vector2(-9, y + 3), Vector2(9, y - 1), CORD_DARK, 3.0)
		_cord.draw_line(Vector2(-9, y + 3), Vector2(9, y - 1), CORD, 1.6)
	var knot := Vector2(7.0 * s, -27.0)
	_cord.draw_circle(knot, 2.6, CORD_DARK)
	_cord.draw_circle(knot, 1.8, CORD)
	_cord.draw_line(knot, knot + Vector2(2.0 * s, 6.0), CORD, 1.4)   # the loose end
