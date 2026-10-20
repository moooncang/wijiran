extends "res://src/enemies/enemy_base.gd"
## 서방 검병 (reused 56px soldier sheet). Two behaviours (본편 §9): approach + single slash, and a
## telegraphed triple combo when the player stays in reach. Weak to perfect parries (recoil) and the
## recovery after a swing. Strike times are data; the clip is stretched so impact frames land on them.

const REACH := 70.0
const WALK := 110.0
const STOP := 52.0
const PATTERNS := {
	"slash": {"name": "검격", "clip": "attack_slash", "cls": CombatConfig.ParryClass.NORMAL, "times": [0.50], "raw": 14.0, "knockback": 140.0, "posture": CombatConfig.POSTURE_NORMAL, "end": 0.95},
	"triple": {"name": "3연격", "clip": "attack_triple", "cls": CombatConfig.ParryClass.NORMAL, "times": [0.55, 0.90, 1.25], "raw": 10.0, "knockback": 100.0, "posture": CombatConfig.POSTURE_NORMAL, "end": 1.75},
}

var combo_ready := false
var sprite: Sprite2D
var sheet: Dictionary
var pattern := ""
var attack_time := 0.0
var _frame_times: Array = []
var _fired: Dictionary = {}
var decide_wait := 0.0
var attacks_done := 0
var unaware_of_palm := true


func _setup() -> void:
	hurt_top = -56.0
	hurt_half_width = 12.0
	status.max_hp = 90.0
	status.hp = 90.0
	sheet = Anim.enemy
	sprite = Sprite2D.new()
	sprite.texture = sheet.texture
	sprite.hframes = int(sheet.columns)
	sprite.vframes = int(sheet.texture.get_height() / sheet.cell)
	sprite.centered = false
	sprite.offset = -sheet.pivot
	sprite.z_index = 2
	add_child(sprite)


func _clip(name: String) -> Dictionary:
	return sheet.clips[name]


func _cancel_attack() -> void:
	pattern = ""
	decide_wait = 0.45


func _on_stagger() -> void:
	pattern = ""


func _ai(dt: float) -> void:
	if status.staggered() or status.recoil_left > 0.0 or hurt_left > 0.0:
		pattern = ""
		return
	var dx := player.global_position.x - global_position.x
	if pattern == "":
		facing = -1.0 if dx < 0.0 else 1.0
		decide_wait = maxf(0.0, decide_wait - dt)
		var level := absf(player.global_position.y - global_position.y) < 50.0
		if absf(dx) > STOP + 10.0 or not level:
			global_position.x += facing * WALK * dt
		elif decide_wait == 0.0:
			# the player who stays in reach eats the combo; otherwise one clean swing
			_start(("triple" if combo_ready and attacks_done % 2 == 1 else "slash"))
		return
	var p: Dictionary = PATTERNS[pattern]
	var before := attack_time
	attack_time += dt
	for i in p.times.size():
		var t: float = p.times[i]
		if before < t and attack_time >= t:
			var origin := global_position + Vector2(facing * 36.0, -34.0)
			var box := Rect2(global_position.x + (8.0 if facing > 0.0 else -REACH), global_position.y - 60.0, REACH - 8.0, 60.0)
			_strike(i + 1, box, float(p.raw), int(p.cls), float(p.knockback), float(p.posture), origin, "%s#%d" % [p.name, i + 1])
			Juice.fx("run_dust", origin + Vector2(0, 30), Vector2.RIGHT, facing)
	if attack_time >= float(p.end):
		pattern = ""
		attacks_done += 1
		decide_wait = 0.6


func _start(id: String) -> void:
	pattern = id
	attack_time = 0.0
	instance += 1
	_frame_times = _plan_frames(PATTERNS[id])


func _plan_frames(p: Dictionary) -> Array:
	var c := _clip(p.clip)
	var n := int(c.count)
	var impacts: Array = c.get("impacts", [int(c.get("impact", 0))])
	var anchors: Array = [[0, 0.0]]
	for i in impacts.size():
		anchors.append([int(impacts[i]), float(p.times[i])])
	anchors.append([n, float(p.end)])
	var out: Array = []
	for k in range(anchors.size() - 1):
		var f0: int = anchors[k][0]
		var f1: int = anchors[k + 1][0]
		var t0: float = anchors[k][1]
		var t1: float = anchors[k + 1][1]
		for f in range(f0, f1):
			out.append([f, t0 + (t1 - t0) * float(f - f0) / float(maxi(1, f1 - f0))])
	return out


func frame() -> int:
	if not status.alive():
		var d := _clip("death")
		return int(d.first) + mini(int(dead_time * 8.0), int(d.count) - 1)
	if status.staggered():
		var s := _clip("stagger")
		return int(s.first) + int(clock * 6.0) % int(s.count)
	if status.recoil_left > 0.0:
		var r := _clip("recoil")
		return int(r.first) + (0 if status.recoil_left > CombatConfig.NORMAL_ENEMY_RECOIL * 0.5 else 1)
	if hurt_left > 0.0:
		return int(_clip("hurt").first) + 1
	if pattern != "":
		var c := _clip(PATTERNS[pattern].clip)
		var local := 0
		for ft in _frame_times:
			if attack_time >= ft[1]:
				local = ft[0]
		return int(c.first) + local
	if active and absf(player.global_position.x - global_position.x) > STOP + 10.0:
		var w := _clip("walk")
		return int(w.first) + int(clock * 8.0) % int(w.count)
	var i := _clip("idle")
	return int(i.first) + int(clock * 6.0) % int(i.count)


func _process(delta: float) -> void:
	super(delta)
	sprite.frame = frame()
	sprite.flip_h = facing < 0.0
	sprite.position = Vector2(kick, 0)
	sprite.modulate = Color(2, 2, 2) if flash > 0.0 else Color(1, 1, 1, corpse_alpha(dead_time))   # dead: death clip, then fade out


func _tag() -> Array:
	return ["!", TAG_WARN] if pattern != "" and attack_time < float(PATTERNS[pattern].times[0]) else []


func _overhead_top() -> float:
	return -50.0   # the sheet's helmet top (hurt_top stands ~8 px above it)
