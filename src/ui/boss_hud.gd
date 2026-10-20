extends Control
## Boss bar for any BossBase on one dark panel at x 214–586, y 4–44: the dialogue box's widest span, centred
## on x 400 like it, 12 px clear of the player status panel (598) and clear above the dialogue box (46).
## Portrait plate (or a drawn bust crest), name + current pattern/state, HP numbers, HP bar in the 9차 frame
## art with the late-phase notch and a draining damage trail, and under it the posture bar with its 자세 label
## in a right-hand column (the label is taller than the bar, so it can't sit under the HP frame). The posture
## bar drains as the 무방비 countdown while the boss is staggered. Empties and fades out after the boss falls.

const ZONE_X0 := 214.0
const ZONE_X1 := 586.0
const PAD := 6.0                         # content inset, as on the player status panel
const PANEL := Rect2(ZONE_X0, 4, ZONE_X1 - ZONE_X0, 41)   # rows 4–44
const PLATE := Rect2(ZONE_X0 + PAD, 8, 32, 32)   # framed 7–40, centred in the panel
const BAR_X := 259.0                     # bars and text start right of the plate
const TEXT_R := ZONE_X1 - PAD            # hp numbers and 자세 end here
const NAME_SIZE := 14                    # both builds: 15+ leaves < 2 px between its ink and the panel edge / hp frame
const NAME_BASE := 18.0                  # 14 px Hangul inks ~6.4–19.7: ≥ 2 px under the panel edge (4)
const HP_Y := 21.0                       # hp frame rows 21–34 (rail 22–33): its rail ≥ 2 px under the name ink
const POSTURE_Y := 35.0                  # posture frame 35–42
const LABEL_BASE := 42.0                 # 자세 inks ≤ 43 at 12 px (touch), centred on the posture bar
const CAP := 10.0                        # frame end caps (source px); the frame interior is transparent
const HP_FILL := Color(0.94, 0.74, 0.42)
const TRAIL := Color(1.0, 0.95, 0.85, 0.85)
const POSTURE_FILL := Color(0.86, 0.83, 0.76)
const POSTURE_FULL := Color(1.0, 0.62, 0.45)
const OPEN := Color(1.0, 0.7, 0.38)      # 무방비: the same word and colour as the overhead tag (enemy_base TAG_OPEN)
const TRACK := Color(0.08, 0.05, 0.05, 0.92)
const FADE_AFTER := 2.2                  # s after defeat before the bar fades (0.6 s)
# Bust crests for bosses without HUD art, in their sprite colours: [x, y, w, h, colour] rects or
# [x, y, r, colour] dots on the 32 px plate.
const CRESTS := {
	"미레유": [[0, 0, 32, 32, Color(0.1, 0.11, 0.2)], [6, 25, 20, 7, Color(0.2, 0.25, 0.5)],
		[10, 11, 12, 14, Color(0.9, 0.78, 0.66)], [8, 5, 16, 7, Color(0.75, 0.2, 0.15)],
		[7, 10, 4, 13, Color(0.75, 0.2, 0.15)], [21, 10, 4, 13, Color(0.75, 0.2, 0.15)],
		[11, 15, 10, 2, Color(0.85, 0.7, 0.3)], [26, 6, 3.5, Color(1.0, 0.62, 0.25)], [26, 6, 1.5, Color(1, 1, 0.9)]],
	"엘로디": [[0, 0, 32, 32, Color(0.09, 0.12, 0.19)], [6, 25, 20, 7, Color(0.96, 0.96, 0.98)],
		[10, 11, 12, 13, Color(0.9, 0.8, 0.7)], [9, 23, 14, 3, Color(0.75, 0.78, 0.85)],
		[8, 5, 16, 7, Color(0.6, 0.8, 0.95)], [7, 10, 4, 13, Color(0.6, 0.8, 0.95)], [21, 10, 4, 13, Color(0.6, 0.8, 0.95)],
		[13, 16, 2, 2, Color(0.2, 0.25, 0.4)], [17, 16, 2, 2, Color(0.2, 0.25, 0.4)],
		[26, 8, 1, 14, Color(0.8, 0.82, 0.9)], [26.5, 24, 3.5, Color(0.85, 0.7, 0.3)], [26.5, 24, 1.5, Color(1.0, 0.95, 0.8)]],
}

var boss: Node
var _trail := -1.0                       # hp shown by the trail, eases down to hp after a short hold
var _trail_hold := 0.0
var _gone_t := 0.0
var _t := 0.0
var _boss_id := 0                       # instance the trail/fade state belongs to
var _stagger_len := 0.0                 # longest stagger_left seen in the current stagger (its full length)
var _portraits := {"티아넬": Anim.ui_tex("tianel_hud_portrait")}   # boss_name → 32px HUD portrait


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if boss == null or not is_instance_valid(boss):
		return
	_t += delta
	var st: EnemyStatus = boss.status
	if boss.get_instance_id() != _boss_id:
		_boss_id = boss.get_instance_id()
		_trail = st.hp
		_gone_t = 0.0
	var down := _down()
	if st.hp < _trail:
		_trail_hold -= delta
		if _trail_hold <= 0.0 or down:   # a beaten boss's trail empties in < 0.7 s, well before the fade
			_trail = maxf(st.hp, _trail - st.max_hp * (1.5 if down else 0.5) * delta)
	else:
		_trail = st.hp
		_trail_hold = 0.45
	_stagger_len = maxf(_stagger_len, st.stagger_left) if st.staggered() else 0.0
	_gone_t = _gone_t + delta if down else 0.0
	modulate.a = clampf(1.0 - (_gone_t - FADE_AFTER) / 0.6, 0.0, 1.0)
	queue_redraw()


func _down() -> bool:
	return boss.get("beaten") == true or not boss.status.alive()


func _draw() -> void:
	if boss == null or not is_instance_valid(boss):
		return
	var st: EnemyStatus = boss.status
	var who: String = String(boss.get("boss_name")) if boss.get("boss_name") != null else "보스"
	# one dark base under everything, like the player status panel: the name and numbers read over the
	# bright B1 trunk and sky
	UiText.panel(self, PANEL)
	# portrait plate: art, else a bust crest, else a framed monogram
	UiText.panel(self, PLATE.grow(1), 0.85)
	if _portraits.has(who):
		draw_texture(_portraits[who], PLATE.position)
	elif CRESTS.has(who):
		for s in CRESTS[who]:
			if s.size() == 5:
				draw_rect(Rect2(PLATE.position + Vector2(s[0], s[1]), Vector2(s[2], s[3])), s[4])
			else:
				draw_circle(PLATE.position + Vector2(s[0], s[1]), s[2], s[3])
	else:
		draw_rect(PLATE.grow(-2), Color(0.95, 0.72, 0.35, 0.6), false, 1.0)
		var ps := UiText.sz(UiText.XL)
		UiText.centered(self, PLATE.get_center().x, roundf(PLATE.get_center().y + ps * 0.47), who.left(1), ps, UiText.ACCENT)
	# name, state, hp numbers on one baseline
	UiText.draw(self, Vector2(BAR_X, NAME_BASE), who, NAME_SIZE, Color(1.0, 0.88, 0.7))
	var hp_text := "%d / %d" % [int(ceil(st.hp)), int(st.max_hp)]
	var num_size := UiText.sz(UiText.S)
	var num_w := UiText.width(hp_text, num_size)
	UiText.draw(self, Vector2(roundf(TEXT_R - num_w), NAME_BASE), hp_text, num_size, UiText.INK)
	var stagger := st.staggered() and not _down()
	var state := ""
	var state_color := Color(1.0, 0.8, 0.5)
	if _down():
		state = "제압"   # never the last pattern name: a beaten boss must not look mid-attack
		state_color = UiText.DIM
	elif stagger:
		state = "무방비"   # the posture bar below counts it down
		state_color = OPEN
	elif boss.get("pattern") is Dictionary and not (boss.get("pattern") as Dictionary).is_empty():
		state = String((boss.get("pattern") as Dictionary).get("name", ""))
	if state != "":
		var sx := roundf(BAR_X + UiText.width(who, NAME_SIZE) + 10.0)
		if UiText.width(state, num_size) <= TEXT_R - num_w - 10.0 - sx:
			UiText.draw(self, Vector2(sx, NAME_BASE), state, num_size, state_color)
	# both bars stop short of the 자세 column at the right
	var label_size := UiText.sz(UiText.XS)
	var label_w := UiText.width("자세", label_size)
	var w := roundf(TEXT_R - label_w - 5.0 - BAR_X)
	# hp bar: track (also backs the end caps' see-through interior), damage trail, fill, notch, frame
	draw_rect(Rect2(BAR_X + 3, HP_Y + 3, w - 6, 8), TRACK)
	var hp_inner := Rect2(BAR_X + CAP, HP_Y + 3, w - CAP * 2, 8)
	var trail_f := clampf(_trail / st.max_hp, 0.0, 1.0)
	var hp_f := clampf(st.hp / st.max_hp, 0.0, 1.0)
	draw_rect(Rect2(hp_inner.position, Vector2(hp_inner.size.x * trail_f, 8)), TRAIL)
	draw_rect(Rect2(hp_inner.position, Vector2(hp_inner.size.x * hp_f, 8)), HP_FILL)
	draw_rect(Rect2(hp_inner.position, Vector2(hp_inner.size.x * hp_f, 2)), Color(1, 0.9, 0.66))
	_frame(Rect2(0, 0, 420, 14), Rect2(BAR_X, HP_Y, w, 14))
	var late: Variant = boss.get("late_fraction")
	var late_x := roundf(hp_inner.position.x + hp_inner.size.x * (float(late) if late != null else 0.6))
	draw_rect(Rect2(late_x - 1, HP_Y + 1, 2, 12), Color(0.95, 0.72, 0.35))
	draw_rect(Rect2(late_x - 1, HP_Y + 3, 2, 8), Color(0.25, 0.15, 0.1))
	# posture bar: fills toward a stagger and pulses near it; while staggered it is full and drains with
	# the time left, so the break reads as a countdown instead of an empty bar (add_posture zeroes posture)
	draw_rect(Rect2(BAR_X + 3, POSTURE_Y + 2, w - 6, 4), TRACK)
	var p_inner := Rect2(BAR_X + CAP, POSTURE_Y + 2, w - CAP * 2, 4)
	var pf := clampf(st.stagger_left / _stagger_len if stagger and _stagger_len > 0.0 else st.posture / st.posture_max, 0.0, 1.0)
	var hot := pf >= 0.8 or stagger
	var p_col := POSTURE_FULL if hot else POSTURE_FILL
	if hot and not stagger:
		p_col = p_col.lerp(Color(1.0, 0.95, 0.85), 0.3 + 0.3 * sin(_t * 12.0))
	draw_rect(Rect2(p_inner.position, Vector2(p_inner.size.x * pf, 4)), p_col)
	_frame(Rect2(0, 18, 420, 8), Rect2(BAR_X, POSTURE_Y, w, 8))
	UiText.draw(self, Vector2(roundf(TEXT_R - label_w), LABEL_BASE), "자세", label_size, POSTURE_FULL if hot else POSTURE_FILL)


## 3-slice of a 9차 frame strip: end caps as drawn, the rail stretched from a notch-free stretch.
func _frame(src: Rect2, dst: Rect2) -> void:
	var tex := Anim.boss_hud_texture
	var h := src.size.y
	draw_texture_rect_region(tex, Rect2(dst.position, Vector2(CAP, h)), Rect2(src.position, Vector2(CAP, h)))
	draw_texture_rect_region(tex, Rect2(dst.position + Vector2(CAP, 0), Vector2(dst.size.x - CAP * 2, h)), Rect2(src.position + Vector2(20, 0), Vector2(100, h)))
	draw_texture_rect_region(tex, Rect2(dst.end.x - CAP, dst.position.y, CAP, h), Rect2(src.end.x - CAP, src.position.y, CAP, h))
