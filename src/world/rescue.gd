extends "res://src/world/interactable.gd"
## 구출 대상 제자 (본편 §7 5구역, §8): sits bound until the room is clear, ↑ frees them. The rescue is a
## permanent flag (never undone by death, §10), then the disciple walks off along the safe route and is
## gone on re-entry. No escort, no HP (기획). Uses the 10차 disciple sheets (idle / bow / walk).

var rescue_id := ""
var who := "disciple_m"
var exit_dir := -1.0
var sprite: ClipSprite
var _leaving := false
var _gone := false


func _ready() -> void:
	super()
	label = "제자 풀어주기"
	sprite = ClipSprite.new()
	sprite.setup(Anim.sheets[who])
	sprite.set_facing(-exit_dir)
	sprite.z_index = 1
	add_child(sprite)
	if Game.flag("rescued:" + rescue_id):
		_gone = true
		visible = false


func available() -> bool:
	if _gone or _leaving:
		return false
	var lv := get_parent()
	return not (lv is Level and lv._enemy_count > 0)


func _use() -> void:
	Game.set_flag("rescued:" + rescue_id, true)
	_leaving = true
	label = ""
	sprite.play("bow", true)
	Juice.fx("parry_perfect_fx", global_position + Vector2(0, -24))
	Game.notice.emit("제자를 구출했습니다 — 안전 경로로 보냅니다")
	Dialogue.say("제자", "단주님… 끈을, 끈을 늘리지 않으셨군요.")
	Dialogue.say("위지란", "가. 뒤는 보지 말고. 쌍등객잔에서 봐.")


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


func _draw_body() -> void:
	if not _leaving and not _gone:
		draw_rect(Rect2(-14, -30, 28, 3), Color(0.75, 0.15, 0.2))   # the binding cord
