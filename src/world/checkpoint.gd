extends "res://src/world/interactable.gd"
## Lantern checkpoint: touching it commits session room clears, snapshots resources on first arrival,
## heals, and becomes the respawn point (본편 §10). Automatic on contact; ↑ re-lights it (heal again).

var cp_id := ""
var level_id := ""
var lit := false


func _ready() -> void:
	super()
	label = "체크포인트"
	radius = 30.0


func _process(delta: float) -> void:
	super(delta)
	if near and not lit:
		_use()


func _use() -> void:
	lit = true
	Game.reach_checkpoint(level_id, cp_id)
	var p := get_tree().get_first_node_in_group("player") as Player
	if p:
		p.hp = CombatConfig.PLAYER_MAX_HP
		p.resolved_hits.clear()
	Game.notice.emit("기록되었습니다")


func _draw_body() -> void:
	draw_rect(Rect2(-3, -60, 6, 60), Color(0.3, 0.22, 0.14))
	draw_rect(Rect2(-12, -72, 24, 16), Color(0.5, 0.2, 0.15) if lit else Color(0.3, 0.2, 0.18))
	var glow := Color(1.0, 0.7, 0.3, 0.5 + 0.3 * sin(_t * 4.0)) if lit else Color(0.4, 0.35, 0.3, 0.4)
	draw_circle(Vector2(0, -64), 5.0, glow)
	if lit:
		draw_circle(Vector2(0, -64), 14.0, Color(1.0, 0.7, 0.3, 0.12))
