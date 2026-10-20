extends Node2D
class_name Interactable
## Base for things the player uses with W/↑ when standing on them (door, checkpoint, manual, rest point).
## Only the closest usable one in range shows a centred key prompt and answers the key, so neighbours
## never stack or steal the press; nothing is drawn while the player is away (idle labels were clutter).
## Subclasses implement _use(), _draw_body() and optionally locked_hint().

const PROMPT_BOTTOM := -62.0   # prompt pill bottom edge: clear of a standing head (48 px) and 60 px prop art
const UI_Z := 40               # world text above characters (≤4) and front art, below hit FX (41+)
const FADE := 0.12             # prompt / panel fade out (s); they appear at full strength at once
const NEAR_SLACK := 6.0        # stay "near" this much past the radius: no flicker at the edge
const HINT_DWELL := 0.4        # a locked hint waits until the player has stood here this long
# Screen zones world text stays out of (canvas px, screen layout plan).
const HUD_ZONE := Rect2(600, 0, 200, 120)        # player status block, top-right
const DIALOGUE_ZONE := Rect2(146, 0, 452, 128)   # dialogue box while a line plays (and the strip above it)
const TITLE_ZONE := Rect2(196, 146, 408, 40)     # map title band while it shows
const BOSS_ZONE := Rect2(186, 0, 416, 46)        # boss bar
const KEYS_ZONE := Rect2(556, 326, 244, 124)     # PC skill/key panel
const STICK_ZONE := Rect2(0, 290, 232, 160)      # touch stick

var label := ""
var radius := 26.0
var near := false
var used := false
var _t := 0.0
var _dwell := 0.0              # seconds the player has stood here, grounded and not fighting
var _ui: Node2D                # draws prompts on UI_Z so characters and art never cover them
var _drawn := Rect2()          # where _ui last drew its pill / panel (local), for the off-screen cut
static var _cluster := Rect2()   # touch: bounding box of every button's touch area (filled on first use)


func _ready() -> void:
	add_to_group("interactable")
	z_index = 1
	_ui = Node2D.new()
	_ui.z_as_relative = false
	_ui.z_index = UI_Z
	_ui.modulate.a = 0.0
	_ui.draw.connect(_draw_ui)
	add_child(_ui)


func _process(delta: float) -> void:
	_t += delta
	var p := get_tree().get_first_node_in_group("player") as Player
	var reach := radius + (NEAR_SLACK if near else 0.0)
	# a downed player is near nothing: no prompt, sign or hint over the death card
	near = p != null and not p.dead and absf(p.global_position.x - global_position.x) < reach and absf(p.global_position.y - global_position.y) < 40.0
	var still := near and p.is_on_floor() and p.action() == Player.Action.FREE and not p.swinging()
	_dwell = _dwell + delta if still else 0.0
	queue_redraw()
	# Shown at once, faded out; while fading out the last drawing stays (no redraw), so it does not blink.
	var show := shows_ui() and not cutscene_up(get_tree())
	_ui.modulate.a = 1.0 if show else move_toward(_ui.modulate.a, 0.0, delta / FADE)
	if show:
		_ui.queue_redraw()
	elif not on_screen(_ui, _drawn):   # a fading panel cut by the screen edge reads as broken text: gone at once
		_ui.modulate.a = 0.0


## True while a rect drawn in `ci`'s local space is wholly on screen (the camera may have moved since).
static func on_screen(ci: CanvasItem, r: Rect2) -> bool:
	return ci.get_viewport_rect().encloses(Rect2(ci.get_global_transform_with_canvas() * r.position, r.size))


## The first-entry cutscene card covers the screen: world text waits under it.
static func cutscene_up(tree: SceneTree) -> bool:
	var cut = tree.current_scene.get("cutscene") if tree.current_scene else null
	return cut is CanvasItem and cut.visible


func try_use() -> bool:
	if not focused():
		return false
	_use()
	return true


func available() -> bool:
	return true


## Shown (dim, no key) while the player stands here but cannot use it yet; "" shows nothing.
func locked_hint() -> String:
	return ""


func _use() -> void:
	pass


## The closest usable interactable in range: the only one with a prompt and the only one the key uses.
func focused() -> bool:
	if not (near and available()):
		return false
	var px: float = get_tree().get_first_node_in_group("player").global_position.x
	var d := absf(px - global_position.x)
	for it in get_tree().get_nodes_in_group("interactable"):
		if it != self and it.near and it.available() and absf(px - it.global_position.x) < d:
			return false
	return true


## A locked hint only after the player has stopped here, never mid-fight with a boss: dodging past
## a shut door or a bound disciple must not flash text over the action.
func _hint_shown() -> bool:
	return near and not available() and _dwell >= HINT_DWELL and locked_hint() != "" and not _boss_fight()


func _boss_fight() -> bool:
	for e in get_tree().get_nodes_in_group("enemy"):
		var st = e.get("status")
		if st != null and st.is_boss and st.alive():
			return true
	return false


func shows_pill() -> bool:
	return focused() or _hint_shown()


## Any world text from this object on screen now (NPC name tags give way to it).
func shows_ui() -> bool:
	return shows_pill()


func _draw() -> void:
	_draw_body()


func _draw_body() -> void:
	pass


func _draw_ui() -> void:
	if not shows_pill():
		return
	if focused():
		draw_prompt(label)
	else:
		draw_prompt(locked_hint(), false)


## Height of the prompt pill, so other world text (sign panels) can stack above it.
static func pill_height() -> float:
	return UiText.font().get_height(UiText.sz(UiText.S)) + 6.0


## Centred pill above the object: [W] text on a panel, kept on screen and clear of the HUD and controls.
## Touch builds show no key cap: the pulsing 상호작용 button is the cue.
func draw_prompt(text: String, with_key := true) -> void:
	if text == "":
		return
	var fs := UiText.sz(UiText.S)
	var cap := with_key and not UiText.touch
	var kw := UiText.width("W", fs) + 8.0 if cap else 0.0
	var gap := 5.0 if cap else 0.0
	var h := pill_height()
	var w := 6.0 + kw + gap + UiText.width(text, fs) + 6.0
	var r := place(_ui, Rect2(-w * 0.5, PROMPT_BOTTOM - h, w, h))
	_drawn = r
	UiText.panel(_ui, r, 0.86)
	var base := r.position.y + 3.0 + UiText.font().get_ascent(fs)
	var x := r.position.x + 6.0
	if cap:
		var box := Rect2(x, r.position.y + 2.0, kw, h - 4.0)
		_ui.draw_rect(box, Color(UiText.ACCENT, 0.16))
		_ui.draw_rect(box, UiText.ACCENT, false, 1.0)
		UiText.draw(_ui, Vector2(x + 4.0, base), "W", fs, UiText.ACCENT, 0)
		x += kw + gap
	UiText.draw(_ui, Vector2(x, base), text, fs, UiText.INK if with_key else UiText.DIM, 0)


## A local rect moved to the nearest free spot: on screen (8 px margin), off the HUD / dialogue / title /
## boss zones, the key panel or touch controls and the object itself, and preferably no more than 60 px
## beside its object. Tries sliding past each blocker (up to four hops) and keeps the cheapest move; with
## no free spot it stays put. Returned in `ci`'s local space, snapped to whole screen pixels. World props
## are unscaled (camera zoom 1).
static func place(ci: CanvasItem, r: Rect2) -> Rect2:
	var xf := ci.get_global_transform_with_canvas()
	var vs := ci.get_viewport_rect().size
	var ax := xf.origin.x
	var blocks := _blocks(ci)
	blocks.append(Rect2(ax - 12.0, xf.origin.y - 50.0, 24.0, 50.0))   # the object / whoever stands on it
	var home := _fit(Rect2(xf * r.position, r.size), vs)
	var slack := maxf(60.0, _off(home, ax))
	var best := home
	var best_cost := INF
	var open: Array[Rect2] = [home]
	for hop in 4:
		var next: Array[Rect2] = []
		for c in open:
			var b := Rect2()
			for k in blocks:
				if c.intersects(k):
					b = k
					break
			if not b.has_area():
				var d := c.position - home.position
				var cost := absf(d.x) + absf(d.y) * 1.25 + maxf(0.0, _off(c, ax) - slack) * 10.0
				if cost < best_cost:
					best = c
					best_cost = cost
				continue
			for m in [Vector2(b.position.x - 2.0 - c.end.x, 0), Vector2(b.end.x + 2.0 - c.position.x, 0), Vector2(0, b.position.y - 2.0 - c.end.y), Vector2(0, b.end.y + 2.0 - c.position.y)]:
				next.append(_fit(Rect2(c.position + m, c.size), vs))
		open = next
	return Rect2(xf.affine_inverse() * best.position.round(), r.size)


static func _fit(s: Rect2, vs: Vector2) -> Rect2:
	s.position = s.position.clamp(Vector2(8, 8), (vs - s.size - Vector2(8, 8)).max(Vector2(8, 8)))
	return s


## How far x lies outside the rect's span (0 when the rect is over it).
static func _off(s: Rect2, x: float) -> float:
	return maxf(0.0, maxf(s.position.x - x, x - s.end.x))


## Screen rects in use right now: the status block always; dialogue, title band and boss bar while shown;
## the key panel on PC; on touch the stick and the whole button cluster as one block (text threaded
## between the buttons, or under the pop-up 상호작용, read as part of them).
static func _blocks(ci: CanvasItem) -> Array[Rect2]:
	var out: Array[Rect2] = [HUD_ZONE]
	var tree := ci.get_tree()
	var main := tree.current_scene
	if not Dialogue.current.is_empty():
		out.append(DIALOGUE_ZONE)
	var band = main.get("title_band") if main else null
	if band is CanvasItem and band.modulate.a > 0.02:
		out.append(TITLE_ZONE)
	var boss = main.get("boss_hud") if main else null
	if boss is CanvasItem and boss.visible:
		out.append(BOSS_ZONE)
	if not UiText.touch:
		out.append(KEYS_ZONE)
		return out
	out.append(STICK_ZONE)
	if not _cluster.has_area():
		var consts := (load("res://src/player/touch_controls.gd") as Script).get_script_constant_map()
		var slop := float(consts.get("SLOP", 6.0))
		var defs: Dictionary = consts.get("BUTTONS", {})
		for b in defs:
			var e := float(defs[b][1]) + slop
			var sq := Rect2(Vector2(defs[b][0]) - Vector2(e, e), Vector2(e, e) * 2.0)
			_cluster = sq if not _cluster.has_area() else _cluster.merge(sq)
	out.append(_cluster)
	return out
