extends Node2D
class_name EnemyBase
## Shared enemy shell: EnemyStatus, hurt box, hit/parry hooks the player calls, flash/kick feedback,
## HP + posture bars, death signal for room clearing. Subclasses implement _ai(dt) and _draw_body().
## Group "enemy" is what the player's hit probes iterate. `unaware_of_palm`: 서방 enemies cannot read
## 기, so the first 초승 of a fight always lands (세계관 02 읽히지 않는 힘) — a parry-less window.

signal died(enemy: Node)

const TAG_WARN := Color(1.0, 0.9, 0.4)        # "!" wind-up
const TAG_OPEN := Color(1.0, 0.7, 0.38)       # 무방비 / 끊김: punish now (orange on a plate, apart from the gold 월인 mark)
const TAG_UNPARRY := Color(1.0, 0.35, 0.25)   # "X" cannot be parried (the most dangerous class reads red)
## Class tags drawn as the bold boss_marks.png icons the T0 parry drill uses: [clip, glyph width, tint].
## The cream art is tinted red for "X" so the unparryable class is the most alarming one.
const TAG_ICONS := {"!": ["icon_bang", 14.0, Color.WHITE], "!!": ["icon_bang2", 26.0, Color.WHITE], "X": ["icon_x", 28.0, Color(1.0, 0.45, 0.4)]}
## Only these follow an off-screen enemy to the screen edge; an opening you cannot see is noise there.
const THREAT_TAGS := ["!", "!!", "X", "정화 기도"]
const ICON_H := 28.0
const BAR_H := 9.0            # 1 rim + 3 HP + 1 gap + 3 posture + 1 rim
const PLATE := Vector2(4, 2)  # text tag plate padding
const OVER_Z := 45            # overhead layer: above fighters (2–4) and effect clips (41), under damage numbers (50)
## Canvas rects the overhead stack keeps out of (UI layout plan): the player-status block always, the boss
## bar while a boss HUD shows; the dialogue box, notice toast and map title band are added while visible.
const STATUS_RECT := Rect2(596, 2, 202, 116)   # hud.gd panel x 598–796, down to ~115 with the 정화 line, + 2 px
const BOSS_BAR_RECT := Rect2(190, 4, 408, 38)
const TOUCH_BUTTONS := Rect2(540, 230, 260, 220)
const NOTICE_TOP := 127.0     # main.gd NOTICE_Y / TITLE_Y + 32 (wrapped toast under the title band)
const NOTICE_LOW_TOP := 189.0
const SLIDE_MAX := 30.0

static var _ui_frame := -1
static var _ui_hard: Array = []    # HUD that stays up: player status, boss bar, dialogue box
static var _ui_rects: Array = []   # + the transient map title band and notice toast
static var _stack_frame := -1
static var _stacks: Array = []   # screen rects of the overhead stacks drawn this frame

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
var _over: Node2D


func _ready() -> void:
	add_to_group("enemy")
	ground_y = global_position.y
	_over = overlay(self, _draw_overlay)
	_setup()


## Child canvas at OVER_Z for the overhead stack and 내상 diamonds, so a jumping player, another enemy's
## sprite or a slash effect never hides a wind-up icon. `fn` draws onto the returned node.
static func overlay(owner: Node2D, fn: Callable) -> Node2D:
	var o := Node2D.new()
	o.z_index = OVER_Z
	o.z_as_relative = false
	o.draw.connect(fn)
	owner.add_child(o)
	return o


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
	_over.queue_redraw()


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
	_draw_telegraphs()


func _draw_overlay() -> void:
	if status.alive():
		_draw_injury(_over, status.injury, Vector2(20, hurt_top + 12))
		draw_overhead(_over, _overhead_top(), status, _tag())


func _draw_telegraphs() -> void:
	pass


## The state tag over the head: [] or [text, colour] ("!" wind-up, "무방비", "시전 끊김" ...).
func _tag() -> Array:
	return []


## Local y of the top of the drawn head; bodies drawn taller than hurt_top override it.
func _overhead_top() -> float:
	return hurt_top


## Bars and reticle grow with the +2 text on touch builds (a phone shows the canvas physically small).
static func _ui_k() -> float:
	return 1.25 if UiText.touch else 1.0


## Alpha of a corpse `t` s after death: full while it falls / plays its death clip, gone by 1.8 s.
static func corpse_alpha(t: float) -> float:
	return clampf((1.8 - t) / 0.8, 0.0, 1.0)


## Overhead stack with fixed gaps so nothing overlaps: HP/posture bars (normal enemies once touched; bosses
## have the boss HUD unless `force_bars`), the state tag (the bold boss_marks icons for "!" / "!!" / "X" like
## the T0 drill, text on a small plate otherwise, "무방비" whenever staggered — larger and breathing on a
## boss), then the 월인 reticle. Draw it on an overlay() node. It grows up from the head, 4 px clear of it,
## and stays inside the screen. A stack that would land on one already drawn this frame (two enemies on one
## spot) steps up past it. One that would leave the screen top or cross the HUD (ui_keep_out) first slides
## sideways up to SLIDE_MAX px, then leaves the reticle alone under the feet (pointing up) and keeps the rest
## above; a threat tag then may cover the transient title band / notice rather than land on the floor. Only
## when none of that fits does the whole stack grow down from the feet. An off-screen enemy only shows a
## threat tag, pinned to the screen edge with a chevron pointing at it.
static func draw_overhead(node: CanvasItem, top: float, st: EnemyStatus, tag: Array = [], force_bars := false) -> void:
	if st.staggered():
		tag = ["무방비", TAG_OPEN]
	var k := _ui_k()
	var bars := force_bars or (not st.is_boss and (st.hp < st.max_hp or st.posture > 0.0))
	# drawn on the enemy's overlay child, so the pull target is its parent
	var pull := Game.player != null and (Game.player.pull_candidate == node or Game.player.pull_candidate == node.get_parent())
	var text := String(tag[0]) if not tag.is_empty() else ""
	var col: Color = tag[1] if not tag.is_empty() else Color.WHITE
	var icon: Array = TAG_ICONS.get(text, [])
	var big := st.is_boss and text == "무방비"   # the boss's punish window reads as loud as its warnings
	var fs := UiText.sz(UiText.L if big else UiText.S)
	var tag_w := 0.0
	var tag_h := 0.0
	if text != "":
		tag_w = float(icon[1]) if not icon.is_empty() else roundf(UiText.width(text, fs)) + PLATE.x * 2.0
		tag_h = ICON_H if not icon.is_empty() else UiText.font().get_height(fs) + PLATE.y * 2.0
	var bar_h := BAR_H * k
	var ret := 19.0 * k + UiText.font().get_ascent(UiText.sz(UiText.XS)) if pull else 0.0   # 2 px clear + arrow and crescent + label
	var h := (bar_h + 3.0 if bars else 0.0) + (tag_h + 6.0 if text != "" else 0.0) + ret
	if h == 0.0:
		return
	var w := maxf(maxf(40.0 * k if bars else 0.0, tag_w), _reticle_w(k) if pull else 0.0)
	var xf := node.get_global_transform_with_canvas()
	var inv := xf.affine_inverse()
	var vp := node.get_viewport_rect().size
	var head := xf * Vector2(0, top - 4.0)
	if head.x < 0.0 or head.x > vp.x:
		if text in THREAT_TAGS:
			_draw_edge_tag(node, head, text, icon, col, fs, tag_w, tag_h, vp)
		return
	var cx := roundf(clampf(head.x, w * 0.5 + 2.0, vp.x - w * 0.5 - 2.0) - w * 0.5)
	var feet := roundf((xf * Vector2(0, 6.0)).y)
	var box := Rect2()
	var cut := 0.0   # the reticle's height when it goes under the feet alone
	for soft in ([true, false] if text in THREAT_TAGS else [true]):
		for c in ([0.0, ret] if pull and h > ret else [0.0]):
			if not box.has_area():
				box = _fit_above(cx, head.y, w, h - c, vp.x, soft)
				cut = c
	var dir := -1.0   # -1: the stack grows up from the head, +1: down from the feet
	if not box.has_area():
		dir = 1.0
		cut = 0.0
		box = _past_stacks(Rect2(cx, feet, w, h), 1.0)
	_stack_list().append(box)
	var x := (inv * box.get_center()).x
	var y := (inv * Vector2(0, box.end.y if dir < 0.0 else box.position.y)).y   # edge of the next element nearest the body
	if bars:
		draw_bars(node, y + (bar_h if dir > 0.0 else 0.0), st, x)
		y += dir * (bar_h + 3.0)
	if text != "":
		_draw_tag(node, Vector2(x, y + (tag_h if dir > 0.0 else 0.0)), text, icon, col, fs, big)
		y += dir * (tag_h + 6.0)
	if pull:
		if cut > 0.0:
			var rb := _past_stacks(Rect2(cx, feet, w, cut), 1.0)
			_stack_list().append(rb)
			_draw_pull_mark(node, inv * Vector2(rb.get_center().x, rb.position.y + 2.0), k, 1.0)
		else:
			_draw_pull_mark(node, Vector2(x, y + dir * 2.0), k, dir)


## The stack box `bh` tall above `head_y`, slid sideways if the HUD is in the way, or an empty Rect2 when it
## cannot fit there. `soft` false ignores the transient title band and notice toast.
static func _fit_above(cx: float, head_y: float, w: float, bh: float, vw: float, soft: bool) -> Rect2:
	var b := _past_stacks(Rect2(cx, roundf(head_y - bh), w, bh), -1.0)
	var dx := _slide(b, vw, soft) if _blocked(b, soft) else 0.0
	return Rect2(b.position + Vector2(dx, 0), b.size) if is_finite(dx) else Rect2()


## The HUD rects an overhead stack (or a damage number) keeps out of right now, built once per frame: the
## player-status block, the boss bar while it shows and the dialogue box, plus with `soft` the transient
## notice toast and map title band.
static func ui_keep_out(soft := true) -> Array:
	var f := Engine.get_process_frames()
	if f != _ui_frame:
		_ui_frame = f
		_ui_hard = [STATUS_RECT]
		var transient := []
		var m = Juice.world
		if is_instance_valid(m):
			var boss_hud = m.get("boss_hud")
			if boss_hud is CanvasItem and boss_hud.visible:
				_ui_hard.append(BOSS_BAR_RECT)
			var band = m.get("title_band")
			if band is Control and band.modulate.a > 0.01:
				# the band's art, not its control rect: the copper frame ends ~25.5 source px down; only the knot
				# ornaments at the ends (patch_margin wide) hang to the bottom of the rect
				var r: Rect2 = band.get_global_rect()
				var knot: float = band.patch_margin_left * band.scale.x
				transient.append(Rect2(r.position, Vector2(r.size.x, 25.5 * band.scale.y)))
				transient.append(Rect2(r.position, Vector2(knot, r.size.y)))
				transient.append(Rect2(r.end.x - knot, r.position.y, knot, r.size.y))
			var nb = m.get("notice_box")
			var lines = m.get("_notice_lines")
			if nb is CanvasItem and nb.modulate.a > 0.01 and lines is PackedStringArray and not lines.is_empty() and str(m.get("_notice_text")) != "":
				var size := UiText.sz(UiText.M)
				var lw := 0.0
				for line in lines:
					lw = maxf(lw, UiText.width(line, size))
				var top := NOTICE_LOW_TOP if bool(m.get("_notice_low")) else NOTICE_TOP
				transient.append(Rect2(m.get_viewport_rect().size.x * 0.5 - lw * 0.5 - 12.0, top, lw + 24.0, UiText.font().get_height(size) * lines.size() + 6.0))
		var box = Dialogue.get("_box")
		if box is Control and box.visible:
			_ui_hard.append(box.get_global_rect())
		_ui_rects = _ui_hard + transient
	return _ui_rects if soft else _ui_hard


## Screen rects of the overhead stacks drawn so far this frame.
static func _stack_list() -> Array:
	var f := Engine.get_process_frames()
	if f != _stack_frame:
		_stack_frame = f
		_stacks = []
	return _stacks


static func _blocked(box: Rect2, soft := true) -> bool:
	if box.position.y < 10.0:
		return true
	for z in ui_keep_out(soft):
		if box.intersects(z):
			return true
	return false


## Smallest sideways shift (≤ SLIDE_MAX, staying on screen) that takes `box` clear of the HUD, else INF.
static func _slide(box: Rect2, vw: float, soft := true) -> float:
	var best := INF
	for z in ui_keep_out(soft):
		if not box.intersects(z):
			continue
		for dx in [z.position.x - box.end.x - 1.0, z.end.x - box.position.x + 1.0]:
			var b := Rect2(box.position + Vector2(dx, 0), box.size)
			if absf(dx) <= SLIDE_MAX and absf(dx) < absf(best) and b.position.x >= 2.0 and b.end.x <= vw - 2.0 and not _blocked(b, soft):
				best = dx
	return best


## Steps `box` away from the body (dir -1 up, +1 down) past every stack already drawn this frame, so two
## enemies on one spot each keep their own bars and icon.
static func _past_stacks(box: Rect2, dir: float) -> Rect2:
	for i in 4:
		var moved := false
		for r in _stack_list():
			if box.intersects(r):
				box.position.y = r.position.y - 2.0 - box.size.y if dir < 0.0 else r.end.y + 2.0
				moved = true
		if not moved:
			break
	return box


static func _reticle_w(k: float) -> float:
	return maxf(24.0 * k, UiText.width("월인", UiText.sz(UiText.XS)) + 4.0)


## The threat tag of an off-screen enemy at the screen edge, at head height, with a chevron pointing out at
## it. Kept clear of the player-status block and, on touch builds, of the right-hand button column.
static func _draw_edge_tag(node: CanvasItem, head: Vector2, text: String, icon: Array, col: Color, fs: int, tag_w: float, tag_h: float, vp: Vector2) -> void:
	var side := 1.0 if head.x > vp.x else -1.0
	var cx := vp.x - tag_w * 0.5 - 18.0 if side > 0.0 else tag_w * 0.5 + 18.0
	var bottom := clampf(head.y, tag_h + 6.0, vp.y - 6.0)
	var reach := Rect2(cx - tag_w * 0.5 - 14.0, 0.0, tag_w + 28.0, 0.0)   # tag + chevron, x only
	if UiText.touch and side > 0.0 and bottom > TOUCH_BUTTONS.position.y - 8.0:
		bottom = TOUCH_BUTTONS.position.y - 8.0
	if Rect2(reach.position.x, bottom - tag_h, reach.size.x, tag_h).intersects(STATUS_RECT):
		bottom = STATUS_RECT.end.y + 4.0 + tag_h
	var at := node.get_global_transform_with_canvas().affine_inverse() * Vector2(cx, bottom)
	_draw_tag(node, at, text, icon, col, fs, false)
	_draw_chevron(node, at + Vector2(side * (tag_w * 0.5 + 4.0), -tag_h * 0.5), side, col)


## A state tag with its bottom centre at `at`: the bold icon, or the text on a small dark plate edged in its
## colour, so 무방비 / 끊김 never read like the pale 월인 label. `pulse`: a staggered boss's tag breathes.
static func _draw_tag(node: CanvasItem, at: Vector2, text: String, icon: Array, col: Color, fs: int, pulse: bool) -> void:
	if not icon.is_empty():
		_draw_icon(node, String(icon[0]), at, icon[2])
		return
	if pulse:
		col = col.lerp(Color(1.0, 0.96, 0.88), 0.3 + 0.3 * sin(Time.get_ticks_msec() * 0.009))
	var xf := node.get_global_transform_with_canvas()
	at = xf.affine_inverse() * (xf * at).round()
	var f := UiText.font()
	var tw := roundf(UiText.width(text, fs))
	var r := Rect2(at.x - tw * 0.5 - PLATE.x, at.y - f.get_height(fs) - PLATE.y * 2.0, tw + PLATE.x * 2.0, f.get_height(fs) + PLATE.y * 2.0)
	node.draw_rect(r, Color(UiText.PANEL, 0.85))
	node.draw_rect(r, Color(col, 0.8), false, 1.0)
	UiText.draw(node, Vector2(r.position.x + PLATE.x, r.end.y - PLATE.y - f.get_descent(fs)), text, fs, col, 2)


## HP (red) over posture (gold) in a warm-rimmed track, bottom edge at local y `bottom`, centred on `x`. The
## empty part of each track is a lighter wine so the remaining share reads on dark rock or night maps.
static func draw_bars(node: CanvasItem, bottom: float, st: EnemyStatus, x := 0.0) -> void:
	var k := _ui_k()
	var xf := node.get_global_transform_with_canvas()
	var o := Rect2(xf.affine_inverse() * (xf * Vector2(x - 19.0 * k, bottom - BAR_H * k)).round(), Vector2(38.0 * k, BAR_H * k))
	node.draw_rect(o.grow(k), Color(UiText.OUTLINE, 0.8))
	node.draw_rect(o, Color(0.85, 0.72, 0.55, 0.8))
	var inner := o.grow(-k)
	node.draw_rect(inner, Color(0.05, 0.03, 0.05, 0.95))
	var hp := Rect2(inner.position, Vector2(inner.size.x, 3.0 * k))
	var po := Rect2(inner.position.x, inner.end.y - 3.0 * k, inner.size.x, 3.0 * k)
	node.draw_rect(hp, Color(0.25, 0.18, 0.2, 0.9))
	node.draw_rect(po, Color(0.25, 0.18, 0.2, 0.9))
	node.draw_rect(Rect2(hp.position, Vector2(hp.size.x * clampf(st.hp / st.max_hp, 0.0, 1.0), hp.size.y)), Color(0.9, 0.36, 0.42))
	node.draw_rect(Rect2(po.position, Vector2(po.size.x * clampf(st.posture / st.posture_max, 0.0, 1.0), po.size.y)), Color(0.95, 0.8, 0.3))


## One boss_marks icon clip (2-frame blink at its fps), glyph bottom-centre at `at`, snapped to canvas pixels.
static func _draw_icon(node: CanvasItem, clip: String, at: Vector2, tint := Color.WHITE) -> void:
	var c: Dictionary = Anim.effects[clip]
	var tex := Anim.effect_sheet(String(c.get("sheet", "")))
	var cv = c.get("cell", Anim.effect_cell)
	var cell := float(cv[0]) if cv is Array else float(cv)
	var cols := int(tex.get_width() / cell)
	var f := int(c.first) + int(Time.get_ticks_msec() * float(c.get("fps", 6.0)) / 1000.0) % int(c.count)
	var xf := node.get_global_transform_with_canvas()
	var p := xf.affine_inverse() * (xf * at).round()
	var src := Rect2((f % cols) * cell, (f / cols) * cell, cell, cell)
	node.draw_texture_rect_region(tex, Rect2(p - Vector2(c.pivot[0], c.pivot[1]), Vector2(cell, cell)), src, tint)


## Small outlined arrowhead at `at` pointing along `dir` (±1): which way an off-screen threat is.
static func _draw_chevron(node: CanvasItem, at: Vector2, dir: float, col: Color) -> void:
	node.draw_colored_polygon(PackedVector2Array([at + Vector2(dir * 10.0, 0), at + Vector2(-dir, -7), at + Vector2(-dir, 7)]), UiText.OUTLINE)
	node.draw_colored_polygon(PackedVector2Array([at + Vector2(dir * 7.0, 0), at + Vector2(0, -5), at + Vector2(0, 5)]), col)


## 월인 reticle: a pulsing gold crescent + arrow whose tip sits at `tip`, pointing back at the body (`dir` -1:
## the reticle is above it, +1: below it) — what a right click would pull now. The label is a pale, slightly
## dim gold so it reads as a targeting mark, not as another state tag.
static func _draw_pull_mark(node: CanvasItem, tip: Vector2, k: float, dir := -1.0) -> void:
	var a := 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.012)
	var gold := Color(1.0, 0.86, 0.45)
	var x := tip.x
	var cy := tip.y + dir * 14.0 * k
	var a0 := 0.3 if dir < 0.0 else PI + 0.3   # cup opening away from the body
	node.draw_arc(Vector2(x, cy), 9.0 * k, a0, a0 + PI - 0.6, 14, UiText.OUTLINE, 5.0 * k, true)   # dark rim: reads on bright walls
	node.draw_arc(Vector2(x, cy), 9.0 * k, a0, a0 + PI - 0.6, 14, Color(gold, a), 2.5 * k, true)
	node.draw_colored_polygon(PackedVector2Array([Vector2(x, tip.y - dir * 1.5), Vector2(x - 5.5 * k, cy - dir * 6.0 * k), Vector2(x + 5.5 * k, cy - dir * 6.0 * k)]), UiText.OUTLINE)
	node.draw_colored_polygon(PackedVector2Array([tip, Vector2(x - 4.0 * k, cy - dir * 7.0 * k), Vector2(x + 4.0 * k, cy - dir * 7.0 * k)]), Color(gold, a))
	var fs := UiText.sz(UiText.XS)
	UiText.centered(node, x, cy - 3.0 * k if dir < 0.0 else cy + 3.0 * k + UiText.font().get_ascent(fs), "월인", fs, Color(1.0, 0.93, 0.72, 0.8))


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


## Greybox humanoid (no sheet yet), shaded so it sits beside the pixel-art sprites: a 2 px dark silhouette
## rim, light falling from above (a top-to-bottom gradient), a shaded back half, a lit front edge, a darker
## hem or belt, and a two-tone head; faces `facing`. Same footprint as before (18 px body, head at 0.84 h).
## Dead: it falls on its back over 0.25 s and fades out (corpse_alpha) instead of standing there as a ghost;
## the node's _draw_dress(alpha) is drawn inside the same fall.
static func draw_figure(node: CanvasItem, h: float, body: Color, head: Color, facing: float, alive := true, robe := false) -> void:
	var a := 1.0
	if not alive:
		var t := float(node.get("dead_time"))
		a = corpse_alpha(t)
		if a <= 0.0:
			return
		var u := clampf(t / 0.25, 0.0, 1.0)
		node.draw_set_transform(Vector2(0, -9.0 * u), -facing * PI * 0.5 * u * u)
	var ink := Color(0.07, 0.04, 0.07, a)
	var hi := Color(body.lightened(0.1), a)
	var lo := Color(body.darkened(0.14), a)
	var shade := Color(body.darkened(0.3), a)
	var edge := Color(body.lightened(0.35), a * 0.8)
	var back := -facing
	var top := -h * 0.72
	var waist := -h * 0.22
	if robe:
		var hem := -1.0
		var robe_pts := PackedVector2Array([Vector2(-8, top), Vector2(8, top), Vector2(10, hem), Vector2(-10, hem)])
		node.draw_polygon(robe_pts, PackedColorArray([hi, hi, lo, lo]))
		node.draw_colored_polygon(PackedVector2Array([Vector2(back * 8.0, top), Vector2(back * 1.0, top), Vector2(back * 2.0, hem), Vector2(back * 10.0, hem)]), shade)
		node.draw_colored_polygon(PackedVector2Array([Vector2(-9.6, hem - 3.0), Vector2(9.6, hem - 3.0), Vector2(10, hem), Vector2(-10, hem)]), Color(body.darkened(0.42), a))   # hem band
		node.draw_line(Vector2(facing * 2.0, top + 3.0), Vector2(facing * 3.0, hem - 3.0), Color(body.darkened(0.12), a), 1.0)   # front fold
		node.draw_line(Vector2(facing * 6.0, top + 2.0), Vector2(facing * 7.6, hem - 4.0), edge, 1.0)   # lit front edge
		robe_pts.append(robe_pts[0])
		node.draw_polyline(robe_pts, ink, 2.0)
		node.draw_rect(Rect2(-6, -2, 4, 2), ink)
		node.draw_rect(Rect2(2, -2, 4, 2), ink)
	else:
		for lx in [-7.0, 2.0]:
			var leg := Rect2(lx, waist, 5, h * 0.22)
			node.draw_rect(leg, shade if (lx < 0.0) == (back < 0.0) else lo)
			node.draw_rect(leg, ink, false, 1.0)
		var torso := Rect2(-9, top, 18, h * 0.5)
		node.draw_polygon(PackedVector2Array([torso.position, Vector2(torso.end.x, top), torso.end, Vector2(-9, torso.end.y)]), PackedColorArray([hi, hi, lo, lo]))
		node.draw_rect(Rect2(-9.0 if back < 0.0 else 3.0, top, 6, h * 0.5), shade)
		node.draw_line(Vector2(facing * 7.0, top + 2.0), Vector2(facing * 7.0, waist - 5.0), edge, 1.0)   # lit front edge
		node.draw_line(Vector2(-9, waist - 3.0), Vector2(9, waist - 3.0), Color(body.darkened(0.45), a), 2.0)   # belt
		node.draw_rect(torso, ink, false, 2.0)
	var hc := Vector2(0, -h * 0.84)
	var hr := h * 0.13
	node.draw_circle(hc, hr + 1.5, ink)
	node.draw_circle(hc, hr, Color(head.darkened(0.22), a))
	node.draw_circle(hc + Vector2(facing * 1.2, -0.4), hr - 1.3, Color(head, a))
	node.draw_rect(Rect2(facing * 6.0 - 1.0, -h * 0.86, 2, 2), ink)
	if node.has_method("_draw_dress"):
		node.call("_draw_dress", a)   # inside the fall transform: a corpse keeps its hair and collar
	if not alive:
		node.draw_set_transform(Vector2.ZERO, 0.0)


## Hair, hood, collar ... drawn over a draw_figure body at alpha `a`; called by draw_figure so the pieces fall
## with the corpse.
func _draw_dress(_a: float) -> void:
	pass


## Hair (or a hood / helmet in `col`) wrapped around a draw_figure head: a cap from the brow over the crown
## to the nape that leaves the face open, plus an optional `length` px fall down the back. Call it from
## _draw_dress with Color(col, a) so a corpse keeps it.
static func draw_hair(node: CanvasItem, h: float, col: Color, facing: float, length := 0.0, brow_deg := 25.0) -> void:
	var hc := Vector2(0, -h * 0.84)
	var r := h * 0.13 + 1.5
	var pts := PackedVector2Array()
	for i in 11:
		var ang := deg_to_rad(lerpf(-brow_deg, -225.0, i / 10.0))
		pts.append(hc + Vector2(cos(ang) * r * facing, sin(ang) * r))
	if length > 0.0:
		pts.append(hc + Vector2(-facing * (r - 1.0), r + length))
		pts.append(hc + Vector2(-facing * (r - 6.0), r + length - 2.0))
		pts.append(hc + Vector2(-facing * (r - 6.0), r * 0.3))
	node.draw_colored_polygon(pts, col)
	var sheen := PackedVector2Array()   # a light band over the crown: two-tone, not a flat cap
	for i in 5:
		var ang := deg_to_rad(lerpf(-45.0, -110.0, i / 4.0))
		sheen.append(hc + Vector2(cos(ang) * (r - 2.2) * facing, sin(ang) * (r - 2.2)))
	node.draw_polyline(sheen, Color(col.lightened(0.32), col.a * 0.9), 1.0)
	pts.append(pts[0])
	node.draw_polyline(pts, Color(0.07, 0.04, 0.07, col.a), 1.5)


## Up to 3 bright wine diamonds (8 px, dark rim) beside the torso: the 내상 stacks (shared with dummies).
static func _draw_injury(node: CanvasItem, stacks: int, at: Vector2) -> void:
	for i in stacks:
		var c := at + Vector2(0, i * 10)
		node.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -5), c + Vector2(5, 0), c + Vector2(0, 5), c + Vector2(-5, 0)]), UiText.OUTLINE)
		node.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -4), c + Vector2(4, 0), c + Vector2(0, 4), c + Vector2(-4, 0)]), Color(0.9, 0.25, 0.4))
		node.draw_rect(Rect2(c + Vector2(-1, -2), Vector2(1, 1)), Color(1.0, 0.85, 0.9))
