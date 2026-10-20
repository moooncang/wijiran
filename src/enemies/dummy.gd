extends Node2D
## Training dummy: flashes white, snaps back with a spring, leans away from the hit, respawns when broken.
## Holds an EnemyStatus like every other enemy so injury stacks and the hit ledger work the same way.

var status := EnemyStatus.new()
var hurt_top := -52.0   # drawn at 0.7x to match the 48px player
var flash := 0.0
var kick := 0.0
var kick_v := 0.0
var respawn := 0.0
var _s: Sprite2D


func _ready() -> void:
	add_to_group("enemy")


func reset_state() -> void:
	status.reset()
	flash = 0.0
	kick = 0.0
	kick_v = 0.0
	respawn = 0.0


func on_hit(r: Dictionary, push: float, kick_px: float) -> void:
	flash = 0.12 if r.hp_damage >= 30 else 0.08
	kick += push * kick_px
	kick_v = 0.0
	if r.killed:
		respawn = 1.3


func _process(delta: float) -> void:
	if Juice.frozen():
		return
	status.tick(delta)
	flash = maxf(0.0, flash - delta)
	kick_v += (-kick * 500.0 - kick_v * 30.0) * delta
	kick += kick_v * delta
	if not status.alive():
		respawn -= delta
		if respawn <= 0.0:
			status.reset()
	modulate.a = 0.3 if not status.alive() else 1.0
	queue_redraw()


func _draw() -> void:
	if _s == null:
		_s = Anim.prop_sprite("target_dummy")
		_s.z_index = 1
		add_child(_s)
	var i := 1 if flash > 0.0 else (2 if absf(kick) > 2.0 else 0)
	Anim.prop_frame(_s, "target_dummy", i)
	_s.position = Vector2(kick, 0)
	_s.modulate = Color(2, 2, 2) if flash > 0.0 else (Color(1, 1, 1, 0.3) if not status.alive() else Color.WHITE)
	draw_rect(Rect2(-16, -68, 32, 2), Color(0.25, 0.2, 0.25))
	draw_rect(Rect2(-16, -68, 32 * status.hp / status.max_hp, 2), Color(0.85, 0.44, 0.53))
	load("res://src/enemies/enemy_base.gd")._draw_injury(self, status.injury, Vector2(16, -42))


## 월인 target practice: the dummy slides over too.
func pull_to(point: Vector2) -> void:
	global_position.x = point.x
	flash = 0.1
