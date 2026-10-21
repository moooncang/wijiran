extends "res://src/world/interactable.gd"
## Side-path rewards (본편 §10 보상): `tonic` restores up to 40 HP once (permanent flag, no farming; it
## waits while health is full so it is never wasted), `record` is a war/transfer record read in the dialogue
## box ("제목: 「본문」" → speaker and line) and kept as a flag. 11차 props: tonic / tonic_pickup flash,
## transfer_record / war_record scrolls.

const TONIC_HEAL := 40

var kind := "tonic"
var pickup_id := ""
var text := ""
var _s: Sprite2D
var _clip := "tonic"
var _flash: Sprite2D
var _flash_t := -1.0


func _ready() -> void:
	super()
	label = "회복약 마시기" if kind == "tonic" else "기록 읽기"
	_clip = "tonic" if kind == "tonic" else ("transfer_record" if text.begins_with("이송") else "war_record")
	_s = Anim.prop_sprite(_clip)
	add_child(_s)
	_s.visible = not taken()


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
	_s.visible = false
	var p := get_tree().get_first_node_in_group("player") as Player
	if kind == "tonic" and p:
		var gain := mini(CombatConfig.PLAYER_MAX_HP, p.hp + TONIC_HEAL) - p.hp
		p.hp += gain
		_flash = Anim.prop_sprite("tonic_pickup")
		_flash.position = Vector2(0, -8)
		add_child(_flash)
		_flash_t = 0.0
		Juice.flash(p.global_position + Vector2(0, -26), 18.0)
		Game.notice.emit("회복약: 체력 +%d" % gain)
		return
	var colon := text.find(": ")
	if colon > 0:   # up long enough to read; queued, so a running room-entry exchange is not cut
		Dialogue.say(text.left(colon), text.substr(colon + 2), 6.0, "", false)
	else:
		Dialogue.say("기록", text if text != "" else "글씨가 바래 읽을 수 없습니다.", 6.0, "", false)


func _process(delta: float) -> void:
	super(delta)
	if Juice.frozen():
		return
	if _s.visible:
		Anim.prop_frame(_s, _clip, int(_t * 8.0))
	if _flash_t >= 0.0:
		_flash_t += delta
		if _flash_t >= 0.36:
			_flash.queue_free()
			_flash_t = -1.0
		else:
			Anim.prop_frame(_flash, "tonic_pickup", int(_flash_t / 0.12))


func _draw_body() -> void:
	pass
