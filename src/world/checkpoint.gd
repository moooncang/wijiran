extends "res://src/world/interactable.gd"
## Lantern checkpoint: touching it commits session room clears, snapshots resources on first arrival,
## heals, and becomes the respawn point (본편 §10). Automatic on contact; W/↑ re-lights it (heal again).

var cp_id := ""
var level_id := ""
var lit := false
var _s: Sprite2D
var _lit_t := -1.0
var _arriving := true   # first frame after the level loads: the player may have spawned on this lantern


func _ready() -> void:
	super()
	label = "쉬기 · 체력 회복"
	radius = 30.0
	_s = Anim.prop_sprite("checkpoint_off")
	add_child(_s)
	# Level.spawn_point only knows the map's spawns: register this lantern so a respawn lands here.
	var lv := get_parent() as Level
	if lv:
		lv.data.spawns[cp_id] = position
	lit = _is_saved()   # the current respawn point is already burning: no relight, no toast


func _process(delta: float) -> void:
	super(delta)
	if _lit_t >= 0.0:
		_lit_t += delta
	var fade = get_tree().current_scene.get("_fade_t")
	if (fade is float and fade >= 0.0) or Game.paused:
		return   # a map change is under way (a progress wipe restarts at T0): never re-save the lantern we are leaving
	if near and not lit:
		_use()
	_arriving = false


func _is_saved() -> bool:
	var c: Dictionary = Game.save.checkpoint
	return String(c.get("level", "")) == level_id and String(c.get("spawn", "")) == cp_id


func _use() -> void:
	var first := not lit
	var moved := not _is_saved()
	lit = true
	_lit_t = 0.0
	Game.reach_checkpoint(level_id, cp_id)
	var p := get_tree().get_first_node_in_group("player") as Player
	var healed := false
	if p:
		healed = p.hp < CombatConfig.PLAYER_MAX_HP
		p.hp = CombatConfig.PLAYER_MAX_HP
		p.resolved_hits.clear()
	if _arriving:   # spawned on it (map entry): lit silently, the title band and opening lines have the top
		return
	if first and moved:
		Game.notice.emit("등불을 밝혔습니다 — 여기서 다시 시작합니다")
	elif healed:   # W is also jump: hopping at a lit lantern at full health stays silent
		Game.notice.emit("체력을 회복했습니다")


## No "쉬기" pill at full health: the key would only make you jump.
func shows_pill() -> bool:
	var p := get_tree().get_first_node_in_group("player") as Player
	return super() and p != null and p.hp < CombatConfig.PLAYER_MAX_HP


func _draw_body() -> void:
	if _lit_t >= 0.0 and _lit_t < 0.2:
		Anim.prop_frame(_s, "checkpoint_lit", int(_lit_t * 20.0))
	elif lit:
		Anim.prop_frame(_s, "checkpoint_on", int(_t * 8.0))
	else:
		Anim.prop_frame(_s, "checkpoint_off", 0)
