extends "res://src/world/interactable.gd"
## Side-path rewards (본편 §10 보상): `tonic` restores up to 40 HP once (permanent flag, no farming; it
## waits while health is full so it is never wasted), `record` is a war/transfer record read in the dialogue
## box ("제목: 「본문」" → speaker and line) and kept as a flag. Drawn in code until the 11차 props.

const TONIC_HEAL := 40

var kind := "tonic"
var pickup_id := ""
var text := ""


func _ready() -> void:
	super()
	label = "회복약 마시기" if kind == "tonic" else "기록 읽기"


func taken() -> bool:
	return Game.flag("picked:" + pickup_id)


func available() -> bool:
	return not taken() and not (kind == "tonic" and _full())


func locked_hint() -> String:
	return "체력이 가득하다" if kind == "tonic" and not taken() else ""


func _full() -> bool:
	var p := get_tree().get_first_node_in_group("player") as Player
	return p != null and p.hp >= CombatConfig.PLAYER_MAX_HP


func _use() -> void:
	Game.set_flag("picked:" + pickup_id, true)
	var p := get_tree().get_first_node_in_group("player") as Player
	if kind == "tonic" and p:
		var gain := mini(CombatConfig.PLAYER_MAX_HP, p.hp + TONIC_HEAL) - p.hp
		p.hp += gain
		Juice.flash(p.global_position + Vector2(0, -26), 18.0)
		Game.notice.emit("회복약: 체력 +%d" % gain)
		return
	var colon := text.find(": ")
	if colon > 0:   # up long enough to read; queued, so a running room-entry exchange is not cut
		Dialogue.say(text.left(colon), text.substr(colon + 2), 6.0, "", false)
	else:
		Dialogue.say("기록", text if text != "" else "글씨가 바래 읽을 수 없습니다.", 6.0, "", false)


func _draw_body() -> void:
	if taken():
		return
	var bob := sin(_t * 3.0) * 2.0
	if kind == "tonic":   # a small gourd: round belly, waist, cork and a cord
		var y := -4.0 + bob
		draw_circle(Vector2(0, y - 6), 6.0, Color(0.32, 0.06, 0.1))
		draw_circle(Vector2(0, y - 6), 5.0, Color(0.6, 0.13, 0.18))
		draw_circle(Vector2(0, y - 14), 3.8, Color(0.32, 0.06, 0.1))
		draw_circle(Vector2(0, y - 14), 3.0, Color(0.6, 0.13, 0.18))
		draw_rect(Rect2(-1.5, y - 20, 3, 3), Color(0.8, 0.68, 0.45))
		draw_line(Vector2(-3, y - 10.5), Vector2(3, y - 10.5), Color(0.9, 0.78, 0.4), 1.5)
		draw_circle(Vector2(-2, y - 8), 1.4, Color(1.0, 0.75, 0.75, 0.8))   # highlight
	else:   # a rolled scroll: paper between two dark dowel ends, tied with a red cord
		var y := -10.0 + bob
		draw_rect(Rect2(-9, y - 4, 18, 8), Color(0.86, 0.8, 0.64))
		draw_line(Vector2(-9, y - 1), Vector2(9, y - 1), Color(0.7, 0.62, 0.46), 1.0)
		for x in [-11.0, 9.0]:
			draw_rect(Rect2(x, y - 5, 2, 10), Color(0.3, 0.2, 0.12))
		draw_rect(Rect2(-1, y - 4, 2, 8), Color(0.7, 0.14, 0.16))
		draw_line(Vector2(0, y + 4), Vector2(-2, y + 8), Color(0.7, 0.14, 0.16), 1.2)
