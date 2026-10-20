extends "res://src/world/interactable.gd"
## Side-path rewards (본편 §10 보상): `tonic` restores 40 HP once (permanent flag, no farming), `record`
## shows a line of war/transfer record text and is kept as a flag. Greybox drawings until the 11차 props.

var kind := "tonic"
var pickup_id := ""
var text := ""


func _ready() -> void:
	super()
	label = "회복약" if kind == "tonic" else "기록 읽기"


func taken() -> bool:
	return Game.flag("picked:" + pickup_id)


func available() -> bool:
	return not taken()


func _use() -> void:
	Game.set_flag("picked:" + pickup_id, true)
	var p := get_tree().get_first_node_in_group("player") as Player
	if kind == "tonic" and p:
		p.hp = mini(CombatConfig.PLAYER_MAX_HP, p.hp + 40)
		Juice.flash(p.global_position + Vector2(0, -26), 18.0)
		Game.notice.emit("회복약: 체력 +40")
	else:
		Game.notice.emit(text if text != "" else "기록을 읽었다")


func _draw_body() -> void:
	if taken():
		return
	var bob := sin(_t * 3.0) * 2.0
	if kind == "tonic":
		draw_rect(Rect2(-5, -18 + bob, 10, 14), Color(0.55, 0.12, 0.2))
		draw_rect(Rect2(-3, -22 + bob, 6, 4), Color(0.8, 0.7, 0.5))
		draw_rect(Rect2(-6, -12 + bob, 12, 2), Color(0.9, 0.2, 0.25))
	else:
		draw_rect(Rect2(-11, -14 + bob, 22, 12), Color(0.85, 0.8, 0.65))
		draw_rect(Rect2(-11, -14 + bob, 22, 12), Color(0.45, 0.35, 0.2), false, 1.0)
		draw_rect(Rect2(-2, -11 + bob, 4, 6), Color(0.85, 0.7, 0.3))
