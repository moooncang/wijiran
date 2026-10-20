extends "res://src/world/interactable.gd"
## Lantern checkpoint: touching it commits session room clears, snapshots resources on first arrival,
## heals, and becomes the respawn point (본편 §10). Automatic on contact; ↑ re-lights it (heal again).

var cp_id := ""
var level_id := ""
var lit := false
var _s: Sprite2D
var _lit_t := -1.0


func _ready() -> void:
	super()
	label = "체크포인트"
	radius = 30.0
	_s = Anim.prop_sprite("checkpoint_off")
	add_child(_s)


func _process(delta: float) -> void:
	super(delta)
	if near and not lit:
		_use()


func _use() -> void:
	lit = true
	_lit_t = 0.0
	Game.reach_checkpoint(level_id, cp_id)
	var p := get_tree().get_first_node_in_group("player") as Player
	if p:
		p.hp = CombatConfig.PLAYER_MAX_HP
		p.resolved_hits.clear()
	Game.notice.emit("기록되었습니다")


func _draw_body() -> void:
	if _lit_t >= 0.0 and _lit_t < 0.2:
		Anim.prop_frame(_s, "checkpoint_lit", int(_lit_t * 20.0))
	elif lit:
		Anim.prop_frame(_s, "checkpoint_on", int(_t * 8.0))
	else:
		Anim.prop_frame(_s, "checkpoint_off", 0)
	if _lit_t >= 0.0:
		_lit_t += 1.0 / 60.0
