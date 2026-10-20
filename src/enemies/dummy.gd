extends Node2D
## Training dummy: flashes white, snaps back with a spring, leans away from the hit, respawns when broken.
## Holds an EnemyStatus like every other enemy so injury stacks and the hit ledger work the same way.

const Base := preload("res://src/enemies/enemy_base.gd")

var status := EnemyStatus.new()
var hurt_top := -52.0   # drawn at 0.7x to match the 48px player
var flash := 0.0
var kick := 0.0
var kick_v := 0.0
var respawn := 0.0
var _s: Sprite2D
var _over: Node2D


func _ready() -> void:
	add_to_group("enemy")
	_over = Base.overlay(self, _draw_overlay)


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
	_over.queue_redraw()   # every frame, hitstop too: the per-frame overhead layout counts every stack
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


func _draw_overlay() -> void:
	Base._draw_injury(_over, status.injury, Vector2(16, -42))
	if status.alive():
		Base.draw_overhead(_over, -50.0, status)   # the post art ends near -48: the same 4 px gap as every head


## 월인 target practice: the dummy slides over too.
func pull_to(point: Vector2) -> void:
	global_position.x = point.x
	flash = 0.1
