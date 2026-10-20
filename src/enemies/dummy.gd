extends Node2D
## Training dummy: flashes white, snaps back with a spring, leans away from the hit, respawns when broken.
## Holds an EnemyStatus like every other enemy so injury stacks and the hit ledger work the same way.

var status := EnemyStatus.new()
var hurt_top := -52.0   # drawn at 0.7x to match the 48px player
var flash := 0.0
var kick := 0.0
var kick_v := 0.0
var respawn := 0.0


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
	var lit := flash > 0.0
	draw_set_transform(Vector2(kick, 0), kick * 0.012, Vector2(0.7, 0.7))
	draw_rect(Rect2(-18, -3, 36, 4), Color(0.1, 0.06, 0.11))
	draw_rect(Rect2(-3, -75, 7, 75), Color.WHITE if lit else Color(0.34, 0.26, 0.31))
	draw_rect(Rect2(-12, -65, 25, 45), Color.WHITE if lit else Color(0.47, 0.38, 0.42))
	draw_rect(Rect2(-24, -56, 48, 6), Color.WHITE if lit else Color(0.47, 0.38, 0.42))
	draw_rect(Rect2(-13, -51, 27, 3), Color(0.63, 0.43, 0.46))
	draw_rect(Rect2(-13, -37, 27, 3), Color(0.63, 0.43, 0.46))
	draw_circle(Vector2(0, -75), 8, Color.WHITE if lit else Color(0.71, 0.51, 0.53))
	draw_set_transform(Vector2.ZERO, 0.0)
	draw_rect(Rect2(-16, -68, 32, 2), Color(0.25, 0.2, 0.25))
	draw_rect(Rect2(-16, -68, 32 * status.hp / status.max_hp, 2), Color(0.85, 0.44, 0.53))
	load("res://src/enemies/enemy_base.gd")._draw_injury(self, status.injury, Vector2(16, -42))
