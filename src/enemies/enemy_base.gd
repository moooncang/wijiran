extends Node2D
class_name EnemyBase
## Shared enemy shell: EnemyStatus, hurt box, hit/parry hooks the player calls, flash/kick feedback,
## HP + posture bars, death signal for room clearing. Subclasses implement _ai(dt) and _draw_body().
## Group "enemy" is what the player's hit probes iterate. `unaware_of_palm`: 서방 enemies cannot read
## 기, so the first 초승 of a fight always lands (세계관 02 읽히지 않는 힘) — a parry-less window.

signal died(enemy: Node)

var status := EnemyStatus.new()
var hurt_top := -56.0
var hurt_half_width := 12.0
var facing := -1.0
var player: Player
var active := false
var flash := 0.0
var kick := 0.0
var kick_v := 0.0
var hurt_left := 0.0
var clock := 0.0
var instance := 0
var dead_time := 0.0
var _died_emitted := false
var ground_y := 300.0
var _pull_to := Vector2.ZERO
var _pull_left := 0.0


func _ready() -> void:
	add_to_group("enemy")
	ground_y = global_position.y
	_setup()


func _setup() -> void:
	pass


func activate(p: Player) -> void:
	player = p
	active = true
	facing = -1.0 if p.global_position.x < global_position.x else 1.0


func invulnerable() -> bool:
	return not status.alive()


func reset_state() -> void:
	status.reset()
	flash = 0.0
	kick = 0.0
	hurt_left = 0.0
	_died_emitted = false
	dead_time = 0.0


func on_hit(r: Dictionary, push: float, kick_px: float) -> void:
	if not active and Game.player:
		activate(Game.player)   # hit from outside its room: wakes up instead of standing still
	flash = 0.12 if r.hp_damage >= 30 else 0.08
	kick += push * kick_px
	kick_v = 0.0
	hurt_left = 0.18
	_on_damaged(r, push)
	if not status.alive() and not _died_emitted:
		_died_emitted = true
		_on_death()
		died.emit(self)


func _on_damaged(_r: Dictionary, _push: float) -> void:
	pass


func _on_death() -> void:
	pass


## Perfect parry on one of our strikes: normal enemies recoil, bosses only build posture.
func on_parried(posture_damage: float) -> void:
	if status.add_posture(posture_damage):
		_on_stagger()
	elif not status.is_boss:
		_cancel_attack()
		status.recoil_left = CombatConfig.NORMAL_ENEMY_RECOIL


func _on_stagger() -> void:
	_cancel_attack()


func _cancel_attack() -> void:
	pass


func _physics_process(dt: float) -> void:
	if Juice.frozen():
		return
	clock += dt
	status.tick(dt)
	hurt_left = maxf(0.0, hurt_left - dt)
	if not status.alive():
		dead_time += dt
		return
	if _pull_left > 0.0:
		_pull_left -= dt
		var u := clampf(1.0 - _pull_left / 0.16, 0.0, 1.0)
		global_position.x = lerpf(global_position.x, _pull_to.x, u)
		global_position.y = ground_y
		return
	if not active or player == null:
		return
	_ai(dt)


## 월인: yanked next to the player over 0.16 s; whatever it was doing is cut (bosses never receive this).
func pull_to(point: Vector2) -> void:
	_pull_to = point
	_pull_left = 0.16
	hurt_left = 0.25
	_cancel_attack()
	Juice.fx("backstep_dust", global_position, Vector2(signf(point.x - global_position.x), 0))


func _ai(_dt: float) -> void:
	pass


func _process(delta: float) -> void:
	if not Juice.frozen():
		flash = maxf(0.0, flash - delta)
		kick_v += (-kick * 500.0 - kick_v * 30.0) * delta
		kick += kick_v * delta
	queue_redraw()


## Deliver one strike to the player if its box overlaps the player's hurt rect. Returns true when sent.
func _strike(hit_id: int, box: Rect2, raw: float, cls: int, knockback: float, posture: float, origin: Vector2, label: String, hit_fx := "") -> bool:
	if not box.intersects(player.hurt_rect()):
		return false
	var hit := HitEvent.new()
	hit.attacker = self
	hit.instance_id = instance
	hit.hit_id = hit_id
	hit.origin = origin
	hit.direction = Vector2(facing, 0)
	hit.raw_direct = raw
	hit.knockback = knockback
	hit.parry_class = cls
	hit.posture_damage = posture
	hit.label = label
	hit.hit_fx = hit_fx
	player.receive_hit(hit)
	return true


func _draw() -> void:
	_draw_body()
	if status.alive():
		draw_rect(Rect2(-22, hurt_top - 20, 44, 3), Color(0.25, 0.2, 0.25))
		draw_rect(Rect2(-22, hurt_top - 20, 44 * status.hp / status.max_hp, 3), Color(0.85, 0.44, 0.53))
		if status.posture > 0.0:
			draw_rect(Rect2(-22, hurt_top - 15, 44 * status.posture / status.posture_max, 2), Color(0.95, 0.8, 0.3))
		_draw_injury(self, status.injury, Vector2(20, hurt_top + 12))
		if Game.player and Game.player.pull_candidate == self:
			_draw_pull_mark()


## 월인 reticle: a pulsing gold crescent + arrow over the enemy the right click would pull right now.
func _draw_pull_mark() -> void:
	var a := 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.012)
	var gold := Color(1.0, 0.86, 0.45, a)
	var y := hurt_top - 38.0
	draw_arc(Vector2(0, y), 9.0, 0.3, PI - 0.3, 14, gold, 2.5, true)
	draw_colored_polygon(PackedVector2Array([Vector2(0, y + 14), Vector2(-4, y + 7), Vector2(4, y + 7)]), gold)
	draw_string(Anim.font, Vector2(-8, y - 6), "월인", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, gold)


func _draw_body() -> void:
	pass


## Hitbox-exact translucent red dot field filling in toward the strike (shared by bosses, mages, hazards).
static func draw_telegraph(node: CanvasItem, local: Rect2, unparryable: bool, progress: float) -> void:
	var alpha := 0.28 + 0.45 * progress
	var dot := Color(1.0, 0.22, 0.2, alpha)
	var pitch := 8.0 if progress < 0.5 else 5.0
	var y := local.position.y + 2.0
	var row := 0
	while y < local.end.y - 1.0:
		var x := local.position.x + 2.0 + (pitch * 0.5 if row % 2 == 1 else 0.0)
		while x < local.end.x - 1.0:
			node.draw_rect(Rect2(x, y, 2, 2), dot)
			x += pitch
		y += pitch
		row += 1
	node.draw_rect(local, Color(1.0, 0.3, 0.25, 0.55 + 0.4 * progress), false, 2.0)
	if progress > 0.75:
		node.draw_rect(local.grow(2.0), Color(1.0, 0.85, 0.7, (progress - 0.75) * 2.0), false, 1.0)
	if unparryable:
		node.draw_rect(Rect2(local.position.x, local.end.y - 3.0, local.size.x, 3.0), Color(1.0, 0.25, 0.2, 0.7 + 0.3 * progress))


## Same field clipped to a disc (정화 기도 등 원형 판정).
static func draw_telegraph_disc(node: CanvasItem, centre: Vector2, r: float, progress: float) -> void:
	var alpha := 0.28 + 0.45 * progress
	var dot := Color(1.0, 0.22, 0.2, alpha)
	var pitch := 8.0 if progress < 0.5 else 5.0
	var y := centre.y - r
	var row := 0
	while y < centre.y + r:
		var x := centre.x - r + (pitch * 0.5 if row % 2 == 1 else 0.0)
		while x < centre.x + r:
			if Vector2(x, y).distance_to(centre) <= r:
				node.draw_rect(Rect2(x, y, 2, 2), dot)
			x += pitch
		y += pitch
		row += 1
	node.draw_arc(centre, r, 0.0, TAU, 48, Color(1.0, 0.3, 0.25, 0.55 + 0.4 * progress), 2.0)


## Greybox humanoid (no sheet yet): body, head, legs; faces `facing`.
static func draw_figure(node: CanvasItem, h: float, body: Color, head: Color, facing: float, alive := true) -> void:
	var a := 1.0 if alive else 0.35
	var b := Color(body.r, body.g, body.b, a)
	node.draw_rect(Rect2(-9, -h * 0.72, 18, h * 0.5), b)
	node.draw_rect(Rect2(-7, -h * 0.22, 5, h * 0.22), b)
	node.draw_rect(Rect2(2, -h * 0.22, 5, h * 0.22), b)
	node.draw_circle(Vector2(0, -h * 0.84), h * 0.13, Color(head.r, head.g, head.b, a))
	node.draw_rect(Rect2(facing * 6.0 - 1.0, -h * 0.86, 2, 2), Color(0.1, 0.05, 0.08, a))


## Up to 3 dark-red diamonds beside the torso (shared with dummies).
static func _draw_injury(node: CanvasItem, stacks: int, at: Vector2) -> void:
	for i in stacks:
		var c := at + Vector2(0, i * 7)
		node.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -3), c + Vector2(3, 0), c + Vector2(0, 3), c + Vector2(-3, 0)]), Color(0.45, 0.11, 0.22))
		node.draw_rect(Rect2(c + Vector2(-1, -1), Vector2(1, 1)), Color.WHITE)
