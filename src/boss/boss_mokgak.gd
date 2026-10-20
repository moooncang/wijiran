extends Node2D
## 목각교두 (wooden training master), the first boss. Implements 목각교두-보스-컨셉과-로직-기획서.md:
## 3 phases × 4 patterns + 4 variations, data-driven strike timelines (hit times never depend on frame
## rate), telegraphs that match the hitboxes 1:1, posture/stagger from perfect parries, phase changes
## with invulnerability, seeded pattern selection. Visuals come from the 9차 sheets (manifest_boss*.json).

const N := CombatConfig.ParryClass.NORMAL
const H := CombatConfig.ParryClass.PERFECT_ONLY
const U := CombatConfig.ParryClass.UNPARRYABLE

const MAX_HP := 1200.0
const PHASE_HP := [800.0, 400.0]          # phase 2 at ≤800, phase 3 at ≤400
const ARMOR := 0.15
const WALK_SPEED := [100.0, 125.0, 145.0]
const DECISION_WAIT := [0.40, 0.28, 0.20]
const DASH_APPROACH := 430.0          # 경공: slide-dash when the player is far
const DASH_RANGE := 190.0
const APPROACH_STOP := 115.0
const STAGGER_WAIT := 0.60
const PHASE_CHANGE_TIME := 1.20
const STRIKE_DURATION := 0.08
const PULSE_DURATION := 0.10
const FLASH_LEAD := 0.12
const KNOCKBACK := {N: 100.0, H: 160.0, U: 80.0}
const POSTURE := {N: 25.0, H: 40.0, U: 0.0}
const LANE_W := 120.0
const LANE_MARGIN := 4.0
const PLAYER_HALF_W := 10.0

enum State { INTRO, IDLE, APPROACH, PATTERN, STAGGER, PHASE_CHANGE, DEAD }

# Strike shapes (boss foot origin, "forward" = facing): F(w,h,z) = x 12..w, y z..z+h above ground;
# B(r,h,z) = x -r..r. LANES = alternating floor lanes of the arena. MOVE = F that follows the boss while it
# slides. `t` is seconds from pattern start, `dur` the active time. Clips: [[start_t, clip], ...]; impact
# clips are anchored at their start so frame 0 (the smear) shows exactly at the hit time.
const PATTERNS := {
	"P1_A": {"phase": 1, "name": "목봉 찌르기", "dmin": 0.0, "dmax": 140.0, "recover": 0.65, "vars": ["V1"],
		"strikes": [{"t": 0.60, "shape": "F", "w": 110.0, "h": 40.0, "z": 12.0, "raw": 12.0, "cls": N, "fx": "thrust_wave"}],
		"clips": [[0.0, "thrust_pull"], [0.60, "thrust"]]},
	"P1_B": {"phase": 1, "name": "좌우 두 번", "dmin": 0.0, "dmax": 155.0, "recover": 0.75, "vars": ["V2"],
		"strikes": [{"t": 0.65, "shape": "F", "w": 125.0, "h": 46.0, "z": 8.0, "raw": 10.0, "cls": N, "fx": "swing_alt_wave"},
			{"t": 1.10, "shape": "F", "w": 125.0, "h": 46.0, "z": 8.0, "raw": 12.0, "cls": N, "fx": "swing_alt_wave"}],
		"clips": [[0.0, "swing_alt_pull"], [0.65, "swing_alt_L"], [0.85, "swing_alt_pull"], [1.10, "swing_alt_R"]]},
	"P1_C": {"phase": 1, "name": "교두의 꾸중", "dmin": 0.0, "dmax": 130.0, "recover": 1.00, "vars": [],
		"strikes": [{"t": 0.95, "shape": "F", "w": 100.0, "h": 88.0, "z": 0.0, "raw": 22.0, "cls": H, "fx": "overhead_smash"}],
		"clips": [[0.0, "overhead_pull"], [0.95, "overhead"]]},
	"P1_D": {"phase": 1, "name": "발목 쓸기", "dmin": 0.0, "dmax": 170.0, "recover": 0.80, "vars": [],
		"strikes": [{"t": 0.85, "shape": "B", "r": 130.0, "h": 18.0, "z": 0.0, "raw": 14.0, "cls": U, "fx": "sweep_low_half"}],
		"clips": [[0.0, "sweep_low_pull"], [0.85, "sweep_low"]]},
	"P2_A": {"phase": 2, "name": "삼절 목봉", "dmin": 0.0, "dmax": 160.0, "recover": 0.80, "vars": ["V1", "V2"],
		"strikes": [{"t": 0.55, "shape": "F", "w": 130.0, "h": 46.0, "z": 8.0, "raw": 10.0, "cls": N, "fx": "swing_alt_wave"},
			{"t": 0.95, "shape": "F", "w": 130.0, "h": 46.0, "z": 8.0, "raw": 10.0, "cls": N, "fx": "swing_alt_wave"},
			{"t": 1.50, "shape": "F", "w": 130.0, "h": 46.0, "z": 8.0, "raw": 14.0, "cls": N, "fx": "swing_alt_wave"}],
		"clips": [[0.0, "swing_alt_pull"], [0.55, "swing_alt_L"], [0.75, "swing_alt_pull"], [0.95, "swing_alt_R"], [1.15, "swing_alt_pull"], [1.50, "swing_alt_L"]]},
	"P2_B": {"phase": 2, "name": "미끄럼 찌르기", "dmin": 150.0, "dmax": 330.0, "recover": 0.80, "vars": ["V3"],
		"strikes": [{"t": 0.60, "dur": 0.28, "shape": "MOVE", "w": 76.0, "h": 44.0, "z": 8.0, "raw": 16.0, "cls": N, "fx": "thrust_wave", "fx_scale": 0.65}],
		"moves": [{"from": 0.60, "to": 0.88, "dist": 180.0}],
		"clips": [[0.0, "slide_pull"], [0.60, "slide"], [0.88, "thrust"]]},
	"P2_C": {"phase": 2, "name": "두 번 울리는 마루", "dmin": 0.0, "dmax": 220.0, "recover": 0.95, "vars": [],
		"strikes": [{"t": 0.85, "dur": 0.10, "shape": "B", "r": 180.0, "h": 20.0, "z": 0.0, "raw": 14.0, "cls": U, "fx": "stomp_pulse_half"},
			{"t": 1.45, "dur": 0.10, "shape": "B", "r": 180.0, "h": 20.0, "z": 0.0, "raw": 14.0, "cls": U, "fx": "stomp_pulse_half"}],
		"clips": [[0.0, "stomp_pull"], [0.85, "stomp"], [1.05, "stomp_pull"], [1.45, "stomp"]]},
	"P2_D": {"phase": 2, "name": "삿갓 높이 가르기", "dmin": 0.0, "dmax": 180.0, "recover": 0.75, "vars": [],
		"strikes": [{"t": 0.65, "shape": "B", "r": 145.0, "h": 42.0, "z": 40.0, "raw": 16.0, "cls": N, "fx": "swing_high_half"}],
		"clips": [[0.0, "swing_high_pull"], [0.65, "swing_high"]]},
	"P3_A": {"phase": 3, "name": "느린 마지막 수", "dmin": 0.0, "dmax": 165.0, "recover": 1.10, "vars": [],
		"strikes": [{"t": 0.55, "shape": "F", "w": 130.0, "h": 46.0, "z": 8.0, "raw": 10.0, "cls": N, "fx": "swing_alt_wave"},
			{"t": 0.95, "shape": "F", "w": 130.0, "h": 46.0, "z": 8.0, "raw": 10.0, "cls": N, "fx": "swing_alt_wave"},
			{"t": 1.75, "shape": "F", "w": 110.0, "h": 88.0, "z": 0.0, "raw": 22.0, "cls": H, "fx": "overhead_smash"}],
		"clips": [[0.0, "swing_alt_pull"], [0.55, "swing_alt_L"], [0.75, "swing_alt_pull"], [0.95, "swing_alt_R"], [1.15, "overhead_pull"], [1.75, "overhead"]], "big_last": true},
	"P1_E": {"phase": 1, "name": "비연 내려찍기", "dmin": 120.0, "dmax": 320.0, "recover": 0.90, "vars": [],
		"strikes": [{"t": 0.95, "shape": "F", "w": 100.0, "h": 88.0, "z": 0.0, "raw": 20.0, "cls": H, "fx": "overhead_smash"}],
		"moves": [{"from": 0.45, "to": 0.85, "dist": "player", "gap": 24.0, "leap": 90.0}],
		"clips": [[0.0, "stomp_pull"], [0.45, "hop"], [0.85, "overhead_pull"], [0.95, "overhead"]]},
	"P2_E": {"phase": 2, "name": "질풍 쌍찌르기", "dmin": 40.0, "dmax": 260.0, "recover": 0.75, "vars": [], "retargets": [0.80],
		"strikes": [{"t": 0.50, "dur": 0.22, "shape": "MOVE", "w": 70.0, "h": 40.0, "z": 10.0, "raw": 12.0, "cls": N, "fx": "thrust_wave", "fx_scale": 0.65},
			{"t": 1.05, "dur": 0.22, "shape": "MOVE", "w": 70.0, "h": 40.0, "z": 10.0, "raw": 12.0, "cls": N, "fx": "thrust_wave", "fx_scale": 0.65, "warn_from": 0.80}],
		"moves": [{"from": 0.50, "to": 0.72, "dist": "through", "gap": 90.0}, {"from": 1.05, "to": 1.27, "dist": "through", "gap": 90.0}],
		"clips": [[0.0, "slide_pull"], [0.50, "slide"], [0.72, "thrust"], [0.80, "retarget"], [0.95, "slide_pull"], [1.05, "slide"], [1.27, "thrust"]]},
	"P2_F": {"phase": 2, "name": "뒤돌아 쓸기", "dmin": 40.0, "dmax": 200.0, "recover": 0.80, "vars": [], "retargets": [0.78],
		"strikes": [{"t": 1.15, "shape": "B", "r": 130.0, "h": 18.0, "z": 0.0, "raw": 14.0, "cls": U, "fx": "sweep_low_half", "warn_from": 0.78}],
		"moves": [{"from": 0.40, "to": 0.75, "dist": "over", "gap": 70.0, "leap": 110.0}],
		"clips": [[0.0, "stomp_pull"], [0.40, "hop"], [0.75, "retarget"], [0.85, "sweep_low_pull"], [1.15, "sweep_low"]]},
	"P3_E": {"phase": 3, "name": "사방 목봉", "dmin": 0.0, "dmax": 250.0, "recover": 1.00, "vars": [],
		"strikes": [{"t": 0.45, "shape": "F", "w": 120.0, "h": 40.0, "z": 12.0, "raw": 12.0, "cls": N, "fx": "thrust_wave"},
			{"t": 1.10, "shape": "F", "w": 100.0, "h": 88.0, "z": 0.0, "raw": 20.0, "cls": H, "fx": "overhead_smash", "warn_from": 0.75},
			{"t": 1.60, "shape": "B", "r": 150.0, "h": 18.0, "z": 0.0, "raw": 14.0, "cls": U, "fx": "sweep_low_half", "warn_from": 1.20}],
		"moves": [{"from": 0.55, "to": 0.65, "dist": -60.0}, {"from": 0.75, "to": 1.05, "dist": "player", "gap": 24.0, "leap": 80.0}],
		"clips": [[0.0, "thrust_pull"], [0.45, "thrust"], [0.55, "backstep"], [0.75, "hop"], [1.05, "overhead_pull"], [1.10, "overhead"], [1.25, "sweep_low_pull"], [1.60, "sweep_low"]]},
	"P3_F": {"phase": 3, "name": "마루 울림 도약", "dmin": 0.0, "dmax": 320.0, "recover": 1.00, "vars": [],
		"strikes": [{"t": 0.70, "dur": 0.10, "shape": "B", "r": 180.0, "h": 20.0, "z": 0.0, "raw": 14.0, "cls": U, "fx": "stomp_pulse_half"},
			{"t": 1.25, "shape": "F", "w": 100.0, "h": 88.0, "z": 0.0, "raw": 20.0, "cls": H, "fx": "overhead_smash", "warn_from": 0.85}],
		"moves": [{"from": 0.85, "to": 1.20, "dist": "player", "gap": 24.0, "leap": 100.0}],
		"clips": [[0.0, "stomp_pull"], [0.70, "stomp"], [0.85, "hop"], [1.20, "overhead_pull"], [1.25, "overhead"]]},
	"P3_B": {"phase": 3, "name": "돌아서는 교두", "dmin": 0.0, "dmax": 175.0, "recover": 0.90, "vars": [], "retargets": [0.85],
		"strikes": [{"t": 0.55, "shape": "F", "w": 120.0, "h": 40.0, "z": 12.0, "raw": 12.0, "cls": N, "fx": "thrust_wave"},
			{"t": 1.25, "shape": "F", "w": 145.0, "h": 48.0, "z": 6.0, "raw": 16.0, "cls": N, "fx": "sweep_low_half", "fx_half": false, "warn_from": 0.85}],
		"clips": [[0.0, "thrust_pull"], [0.55, "thrust"], [0.85, "retarget"], [1.05, "sweep_low_pull"], [1.25, "sweep_low"]]},
	"P3_C": {"phase": 3, "name": "마루 세 칸 시험", "dmin": 0.0, "dmax": 9999.0, "recover": 1.00, "vars": [], "weight": 0.7, "cooldown": 8.0, "no_after_stagger": true,
		"strikes": [{"t": 0.90, "dur": 0.10, "shape": "LANES", "set": 0, "h": 20.0, "raw": 16.0, "cls": U, "fx": "lane_pulse"},
			{"t": 1.70, "dur": 0.10, "shape": "LANES", "set": 1, "h": 20.0, "raw": 16.0, "cls": U, "fx": "lane_pulse", "warn_from": 1.10}],
		"clips": [[0.0, "stomp_pull"], [0.40, "plant"], [0.90, "stomp"], [1.10, "plant"], [1.70, "stomp"]]},
	"P3_D": {"phase": 3, "name": "졸업 삼식", "dmin": 0.0, "dmax": 170.0, "recover": 1.20, "vars": ["V4"],
		"strikes": [{"t": 0.60, "shape": "F", "w": 120.0, "h": 40.0, "z": 12.0, "raw": 12.0, "cls": N, "fx": "thrust_wave"},
			{"t": 1.25, "shape": "F", "w": 105.0, "h": 88.0, "z": 0.0, "raw": 20.0, "cls": H, "fx": "overhead_smash"},
			{"t": 1.95, "shape": "B", "r": 150.0, "h": 18.0, "z": 0.0, "raw": 14.0, "cls": U, "fx": "sweep_low_half"}],
		"clips": [[0.0, "thrust_pull"], [0.60, "thrust"], [0.80, "overhead_pull"], [1.25, "overhead"], [1.45, "sweep_low_pull"], [1.95, "sweep_low"]]},
}
const PHASE_FIRST := {2: "P2_A", 3: "P3_A"}
const VARIATION_NAMES := {"V1": "한 박자 참기", "V2": "한 번 더", "V3": "헛딛고 내밀기", "V4": "종강 한 번 더"}
const NORMALS_FOR_VARIATION := [3, 2, 2]

var status := EnemyStatus.new()
var hurt_top := -80.0
var hurt_half_width := 22.0
var phase := 1
var state: int = State.INTRO
var state_time := 0.0
var facing := -1.0                    # sheet faces left; -1 = looking left (as drawn)
var arena_left := 90.0                # foot x limits (world)
var arena_right := 710.0
var lane_x0 := 40.0                   # world x of lane 0's left edge
var rng := RandomNumberGenerator.new()
var seed_value := 0
var dead_time := 0.0
var flash := 0.0
var _player: Player
var _active := false                  # ticks only while the fight is on (player in the arena)

# pattern run
var pattern_id := ""
var pattern: Dictionary = {}          # the (possibly varied) pattern being run
var variation := ""
var pattern_time := 0.0
var pattern_end := 0.0
var instance := 0
var _fired: Dictionary = {}           # hit_id → true
var _flashed: Dictionary = {}
var _fx_done: Dictionary = {}
var _retargets_done: Dictionary = {}
var ground_y := 300.0
var _move_x0 := 0.0
var _move_done := false
var lane_set := 0

# selection memory (기획서 8-9절)
var cooldowns: Dictionary = {}
var phase_seen: Dictionary = {}
var recent: Array = []                # last pattern ids, newest last
var skipped: Dictionary = {}          # id → times passed over while eligible
var normal_completed := 0
var variation_due := false
var normals_since_variation := 99
var last_variation := ""
var came_from_stagger := false
var _pattern_was_normal := false
var _approach_timer := 0.0

# visuals
var sprite: Sprite2D
var sheet: Dictionary
var parts: Dictionary
var tablet: Sprite2D
var belt: Sprite2D
var hat_crack: Sprite2D
var badge: Sprite2D
var strokes: Sprite2D
var stroke_big: Sprite2D
var arrow: Sprite2D
var mark: Sprite2D
var mark_cls := -1
var icon: Sprite2D
var icon_cls := -1
var hat_spin: Sprite2D
var trail: Sprite2D
var clock := 0.0
var _clip := "idle"
var _frame := 0
var kick := 0.0
var kick_v := 0.0
var log_lines: Array = []             # selection log for tests
var drill := false                    # T0 패링 연습: P1_A only, no phases, never dies
signal died(enemy: Node)
var debug := false


func _ready() -> void:
	add_to_group("enemy")
	status.is_boss = true
	status.max_hp = MAX_HP
	status.hp = MAX_HP
	status.armor_rate = ARMOR
	sheet = Anim.boss
	parts = Anim.boss_parts
	sprite = Sprite2D.new()
	sprite.texture = sheet.texture
	sprite.hframes = int(sheet.columns)
	sprite.vframes = int(sheet.texture.get_height() / sheet.cell)
	sprite.centered = false
	sprite.offset = -sheet.pivot
	sprite.z_index = 2
	add_child(sprite)
	tablet = _part("tablet_1")
	belt = _part("belt_loose")
	hat_crack = _part("hat_crack")
	badge = _part("badge_byeon_0")
	strokes = _part("stroke_1")
	stroke_big = _part("stroke_big")
	arrow = _part("arrow_turn_0")
	for s in [belt, hat_crack, badge, strokes, stroke_big, arrow]:
		s.visible = false
	seed_value = int(Time.get_ticks_usec() % 1000000)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_value = int(a.substr(7))
	rng.seed = seed_value
	reset_state()


func _part(name: String) -> Sprite2D:
	var s := Anim.boss_part(name)
	s.z_index = 3
	add_child(s)
	return s


## Tests: run one pattern (optionally varied) right now, skipping intro and selection.
func force_pattern(id: String, v: String = "") -> void:
	_active = true
	_pending_first = ""
	_start_pattern(id, v)


## Arena bounds: foot limits and the lane origin. Called by main after placing the boss.
func set_arena(left: float, right: float, lanes_x0: float) -> void:
	arena_left = left
	arena_right = right
	lane_x0 = lanes_x0


func reset_state() -> void:
	status.reset()
	status.posture_max = CombatConfig.POSTURE_MAX
	phase = 1
	state = State.INTRO
	state_time = 0.0
	dead_time = 0.0
	pattern_id = ""
	pattern = {}
	variation = ""
	_fired.clear()
	_flashed.clear()
	_fx_done.clear()
	cooldowns.clear()
	phase_seen.clear()
	recent.clear()
	skipped.clear()
	normal_completed = 0
	variation_due = false
	normals_since_variation = 99
	last_variation = ""
	came_from_stagger = false
	_active = false
	kick = 0.0
	kick_v = 0.0
	_clear_attachments()
	_apply_phase_look()
	queue_redraw()


## The player entered the arena: play the intro and start fighting.
## Level-spawned enemies are started with activate(); the arena is the room around the spawn point.
func activate(p: Player) -> void:
	set_arena(global_position.x - 160.0, global_position.x + 160.0, global_position.x - 360.0)
	begin(p)


func begin(p: Player) -> void:
	_player = p
	_active = true
	ground_y = global_position.y
	state = State.INTRO
	state_time = 0.0
	facing = -1.0 if p.global_position.x < global_position.x else 1.0


func invulnerable() -> bool:
	return state == State.PHASE_CHANGE or state == State.DEAD or not _active


# ---------- hits from the player ----------

func on_hit(r: Dictionary, push: float, kick_px: float) -> void:
	flash = 0.12 if r.hp_damage >= 30 else 0.08
	kick += push * minf(kick_px, 6.0)
	kick_v = 0.0
	var at := global_position + _anchor("tablet")
	if r.burst > 0 or r.hp_damage >= 40:
		Juice.fx("sawdust_burst", at)
	else:
		Juice.fx("sawdust", at + Vector2(push * 8.0, 0))
	if drill:
		status.hp = maxf(status.hp, status.max_hp * 0.5)   # the training dummy never breaks or escalates
		return
	if not status.alive():
		_enter(State.DEAD)
		died.emit(self)
		return
	_check_phase()


## A perfect parry on one of our strikes. Bosses only build posture; the strike itself is not interrupted
## unless the threshold is reached (기획서 10절).
func on_parried(posture_damage: float) -> void:
	var tip := global_position + _anchor("staff_tip")
	Juice.fx("parry_spark_h" if posture_damage >= POSTURE[H] else "parry_spark_n", tip, Vector2(facing, 0))
	if status.add_posture(posture_damage):
		_enter(State.STAGGER)


func _check_phase() -> void:
	var want := 1
	for i in PHASE_HP.size():
		if status.hp <= PHASE_HP[i]:
			want = i + 2
	if want > phase and state != State.PHASE_CHANGE:
		phase = want
		_enter(State.PHASE_CHANGE)


# ---------- state machine ----------

func _enter(s: int) -> void:
	state = s
	state_time = 0.0
	match s:
		State.STAGGER:
			_cancel_pattern()
			status.stagger_left = CombatConfig.STAGGER_DURATION  # add_posture set it; keep in sync when forced
			came_from_stagger = true
			Juice.fx("knot_fall", global_position + _anchor("tablet") + Vector2(0, 14))
			hat_spin = Juice.fx("hat_spin", _anchor("tablet") + Vector2(0, -58), Vector2.RIGHT, 1.0, false, self)
		State.PHASE_CHANGE:
			_cancel_pattern()
			status.stagger_left = 0.0
			status.immune_left = 0.0
			status.posture = 0.0
			status.injury = 0
			_free(hat_spin)
			Juice.fx("phase_ring", global_position + Vector2(0, -30))
			Juice.hitstop(0.08)
			Juice.shake(6.0, 0.0)
		State.DEAD:
			_cancel_pattern()
			_free(hat_spin)
			dead_time = 0.0
			_set_tablet("tablet_dark")
			Juice.fx("death_straw", global_position)
			Juice.hitstop(0.12)
			Juice.shake(8.0, 0.0)
		State.IDLE:
			pass
	queue_redraw()


func _physics_process(dt: float) -> void:
	if Juice.frozen():
		return
	clock += dt
	if not _active:
		return
	status.tick(dt)
	state_time += dt
	for k in cooldowns.keys():
		cooldowns[k] = maxf(0.0, cooldowns[k] - dt)
	if state != State.DEAD and not status.alive():
		_enter(State.DEAD)
	match state:
		State.INTRO:
			if state_time >= 0.6:
				_enter(State.IDLE)
		State.IDLE:
			if state_time >= (STAGGER_WAIT if came_from_stagger else DECISION_WAIT[phase - 1]):
				_decide()
		State.APPROACH:
			_step_approach(dt)
		State.PATTERN:
			_step_pattern(dt)
		State.STAGGER:
			if not status.staggered():
				_free(hat_spin)
				_enter(State.IDLE)
		State.PHASE_CHANGE:
			if state_time >= 0.30 and tablet.visible and _tablet_name() != "tablet_%d" % phase:
				_apply_phase_look()
				Juice.fx("tablet_glow", global_position + _anchor("tablet"))
			if state_time >= PHASE_CHANGE_TIME:
				_enter(State.IDLE)
				_force_first_pattern()
		State.DEAD:
			dead_time += dt


func _force_first_pattern() -> void:
	var id: String = PHASE_FIRST.get(phase, "")
	if id != "":
		if _distance_ok(id):
			_start_pattern(id, "")
		else:
			_enter(State.APPROACH)
			_pending_first = id


var _pending_first := ""


# ---------- selection (기획서 9절) ----------

func _distance_ok(id: String) -> bool:
	var p: Dictionary = PATTERNS[id]
	var d := absf(_player.global_position.x - global_position.x)
	return d >= float(p.dmin) and d <= float(p.dmax)


func _candidates() -> Array:
	var out: Array = []
	for id in PATTERNS:
		var p: Dictionary = PATTERNS[id]
		if int(p.phase) != phase:
			continue
		if drill and id != "P1_A":
			continue
		if cooldowns.get(id, 0.0) > 0.0:
			continue
		if not _distance_ok(id):
			continue
		if came_from_stagger and p.get("no_after_stagger", false):
			continue
		out.append(id)
	return out


func _decide() -> void:
	if _pending_first != "":
		if _distance_ok(_pending_first):
			var id := _pending_first
			_pending_first = ""
			_start_pattern(id, "")
			return
		_enter(State.APPROACH)
		return
	var cands := _candidates()
	if cands.is_empty():
		_enter(State.APPROACH)
		return
	# never the same pattern twice in a row (relaxed only when nothing else fits), never three in a row
	var filtered: Array = []
	for id in cands:
		if recent.size() >= 1 and recent[-1] == id:
			continue
		filtered.append(id)
	if filtered.is_empty():
		filtered = cands.duplicate()
		if recent.size() >= 2 and recent[-1] == recent[-2]:
			filtered.erase(recent[-1])
		if filtered.is_empty():
			_enter(State.APPROACH)
			return
	# first introduction of each pattern wins over everything else
	var unseen: Array = []
	for id in filtered:
		if not phase_seen.has(id):
			unseen.append(id)
	var pool: Array = unseen if not unseen.is_empty() else filtered
	# variation pending: prefer variation-capable patterns (after all four were introduced)
	var chosen_variation := ""
	if unseen.is_empty() and variation_due:
		var capable: Array = []
		for id in pool:
			var v := _pick_variation(id)
			if v != "":
				capable.append(id)
		if not capable.is_empty():
			pool = capable
	var id := _weighted_pick(pool)
	if unseen.is_empty() and variation_due:
		chosen_variation = _pick_variation(id)
	for other in cands:
		if other != id:
			skipped[other] = int(skipped.get(other, 0)) + 1
	skipped[id] = 0
	_start_pattern(id, chosen_variation)


func _weighted_pick(pool: Array) -> String:
	var weights: Array = []
	var total := 0.0
	for id in pool:
		var w: float = float(PATTERNS[id].get("weight", 1.0))
		if int(skipped.get(id, 0)) >= 3:
			w = 3.0
		weights.append(w)
		total += w
	var roll := rng.randf() * total
	for i in pool.size():
		roll -= weights[i]
		if roll <= 0.0:
			return pool[i]
	return pool[-1]


func _pick_variation(id: String) -> String:
	var vars: Array = PATTERNS[id].vars
	var options: Array = []
	for v in vars:
		if v == last_variation and vars.size() > 1:
			continue
		options.append(v)
	if options.is_empty():
		# the only candidate (e.g. V4 in phase 3) may repeat
		options = vars.duplicate()
	if options.is_empty():
		return ""
	return options[rng.randi() % options.size()]


# ---------- pattern lifecycle ----------

## Build the executed timeline: copy the base pattern and apply the variation (기획서 8절).
func _build(id: String, v: String) -> Dictionary:
	var p: Dictionary = PATTERNS[id].duplicate(true)
	var strikes: Array = p.strikes
	match v:
		"V1":
			var last: Dictionary = strikes[-1]
			var shift := 0.25
			if id == "P1_A":
				last.t = 0.85
				p.clips = [[0.0, "thrust_pull"], [0.85, "thrust"]]
			else:
				last.t = float(last.t) + shift
				var clips: Array = p.clips
				clips[-1][0] = float(clips[-1][0]) + shift
		"V2":
			var last: Dictionary = strikes[-1]
			var t_extra := float(last.t) + 0.55
			strikes.append({"t": t_extra, "shape": "F", "w": 110.0, "h": 40.0, "z": 12.0, "raw": 10.0, "cls": N, "fx": "thrust_wave"})
			var clips: Array = p.clips
			clips.append([float(last.t) + 0.25, "thrust_pull"])
			clips.append([t_extra, "thrust"])
			p.recover = float(p.recover) + 0.20
		"V3":
			# step back 32px over 0.10s at t=0.60, then the original slide 0.90~1.18
			var s: Dictionary = strikes[0]
			s.t = 0.90
			s.dur = 0.28
			p.moves = [{"from": 0.60, "to": 0.70, "dist": -32.0}, {"from": 0.90, "to": 1.18, "dist": 180.0}]
			p.clips = [[0.0, "backstep"], [0.60, "slide_pull"], [0.90, "slide"], [1.18, "thrust"]]
			p.recover = 0.90
		"V4":
			strikes.append({"t": 2.50, "shape": "F", "w": 120.0, "h": 40.0, "z": 12.0, "raw": 12.0, "cls": N, "fx": "thrust_wave"})
			var clips: Array = p.clips
			clips.append([2.15, "thrust_pull"])
			clips.append([2.50, "thrust"])
			p.recover = 1.40
	for i in strikes.size():
		var s: Dictionary = strikes[i]
		s.id = i + 1
		if not s.has("dur"):
			s.dur = PULSE_DURATION if s.cls == U else STRIKE_DURATION
	return p


func _start_pattern(id: String, v: String) -> void:
	pattern_id = id
	variation = v
	pattern = _build(id, v)
	pattern_time = 0.0
	instance += 1
	_fired.clear()
	_flashed.clear()
	_fx_done.clear()
	_retargets_done.clear()
	_move_x0 = global_position.x
	for m in pattern.get("moves", []):
		m.erase("px")
	_move_done = false
	var strikes: Array = pattern.strikes
	var last: Dictionary = strikes[-1]
	pattern_end = float(last.t) + float(last.dur) + float(pattern.recover)
	facing = -1.0 if _player.global_position.x < global_position.x else 1.0
	if id == "P3_C":
		lane_set = rng.randi() % 2
	cooldowns[id] = float(PATTERNS[id].get("cooldown", 2.0))
	phase_seen[id] = true
	recent.append(id)
	if recent.size() > 3:
		recent.pop_front()
	_pattern_was_normal = v == ""
	if v != "":
		last_variation = v
		variation_due = false
		normal_completed = 0
		normals_since_variation = 0
	came_from_stagger = false
	log_lines.append("%s%s" % [id, ("+" + v) if v != "" else ""])
	badge.visible = v != ""
	_update_strokes()
	_enter(State.PATTERN)


func _cancel_pattern() -> void:
	pattern_id = ""
	pattern = {}
	variation = ""
	_pending_first = ""
	badge.visible = false
	strokes.visible = false
	stroke_big.visible = false
	arrow.visible = false
	_free(mark)
	_free(icon)
	_free(trail)
	mark_cls = -1
	icon_cls = -1
	queue_redraw()


func _finish_pattern() -> void:
	# counts for the variation schedule (기획서 8절 삽입 주기)
	if _pattern_was_normal:
		normal_completed += 1
		normals_since_variation += 1
		if normal_completed >= NORMALS_FOR_VARIATION[phase - 1] and normals_since_variation >= 2 and _all_seen():
			variation_due = true
	_cancel_pattern()
	_enter(State.IDLE)


func _all_seen() -> bool:
	for id in PATTERNS:
		if int(PATTERNS[id].phase) == phase and not phase_seen.has(id):
			return false
	return true


func _step_pattern(dt: float) -> void:
	var before := pattern_time
	pattern_time += dt
	# movement segments (경공): slides, back-steps and leaps; "player"/"over"/"through" distances are
	# measured from the player when the move starts, so the boss lands where the player was.
	for m in pattern.get("moves", []):
		var f := float(m.from)
		var to := float(m.to)
		if pattern_time > f and before < to:
			if not m.has("px"):
				m.px = _resolve_dist(m)
				if m.has("leap") or String(str(m.dist)) in ["player", "over", "through"]:
					facing = -1.0 if _player.global_position.x < global_position.x else 1.0
			var dist := float(m.px)
			var seg_dt := minf(pattern_time, to) - maxf(before, f)
			global_position.x = clampf(global_position.x + facing * dist / (to - f) * seg_dt, arena_left, arena_right)
			if m.has("leap"):
				var u := clampf((pattern_time - f) / (to - f), 0.0, 1.0)
				global_position.y = ground_y - 4.0 * float(m.leap) * u * (1.0 - u)
			elif dist > 0.0 and trail == null:
				trail = Juice.fx("slide_trail", Vector2(0, 0), Vector2(facing, 0), facing, false, self)
		if pattern_time >= to and before < to:
			if m.has("leap"):
				global_position.y = ground_y
				Juice.fx("hop_dust", global_position, Vector2(facing, 0))
				Juice.shake(2.0, 0.0)
			if trail != null:
				_free(trail)
				trail = null
	# retargets: turn only if the player crossed to the other side (기획 P3_B); never spin mid-strike
	for rt in pattern.get("retargets", []):
		if not _retargets_done.has(rt) and pattern_time >= float(rt):
			_retargets_done[rt] = true
			var want := -1.0 if _player.global_position.x < global_position.x else 1.0
			if want != facing:
				facing = want
				arrow.visible = true
				Juice.fx("backstep_dust", global_position, Vector2(facing, 0))
	for s in pattern.strikes:
		var t := float(s.t)
		var dur := float(s.dur)
		var hid := int(s.id)
		if not _flashed.has(hid) and pattern_time >= t - FLASH_LEAD:
			_flashed[hid] = true
			Juice.fx("mark_flash", _strike_origin(s))
		if not _fx_done.has(hid) and pattern_time >= t:
			_fx_done[hid] = true
			_spawn_strike_fx(s)
			Juice.shake(3.0 if s.cls != H else 6.0, 0.0)
			_update_strokes()
		if pattern_time >= t and pattern_time < t + dur and not _fired.has(hid):
			if debug and not _fx_done.has(-hid):
				_fx_done[-hid] = true
				print("strike %s t=%.3f zone=%s player=%s overlap=%s facing=%.0f" % [hid, pattern_time, _zone_rect(s), _player_rect(), _overlaps(s), facing])
			if _overlaps(s):
				_fired[hid] = true
				_deliver(s)
	if pattern_time >= pattern_end:
		_finish_pattern()
	queue_redraw()


## Distance in px for a move: a number, or "player" (stop gap short of the player), "over" / "through"
## (land gap past the player).
func _resolve_dist(m: Dictionary) -> float:
	var d = m.dist
	if d is float or d is int:
		return float(d)
	var dx := absf(_player.global_position.x - global_position.x)
	match String(d):
		"player":
			return maxf(0.0, dx - float(m.get("gap", 24.0)))
		_:
			return dx + float(m.get("gap", 70.0))


## Where the boss will stand when strike s lands (moves still ahead are projected along the current facing).
func _predicted_x(s: Dictionary) -> float:
	var x := global_position.x
	for m in pattern.get("moves", []):
		var f := float(m.from)
		var to := float(m.to)
		if to <= pattern_time or f > float(s.t) + 1e-6:
			continue
		var dist: float = float(m.px) if m.has("px") else _resolve_dist(m)
		var frac := (minf(to, float(s.t)) - maxf(f, pattern_time)) / (to - f)
		x += facing * dist * clampf(frac, 0.0, 1.0)
	return clampf(x, arena_left, arena_right)


func _step_approach(dt: float) -> void:
	var dx := _player.global_position.x - global_position.x
	facing = -1.0 if dx < 0.0 else 1.0
	var far := absf(dx) > DASH_RANGE
	if absf(dx) > APPROACH_STOP:
		var speed: float = DASH_APPROACH if far else WALK_SPEED[phase - 1] * 1.6
		global_position.x = clampf(global_position.x + facing * speed * dt, arena_left, arena_right)
		if far and trail == null:
			trail = Juice.fx("slide_trail", Vector2(0, 0), Vector2(facing, 0), facing, false, self)
	if (not far or absf(dx) <= APPROACH_STOP) and trail != null:
		_free(trail)
		trail = null
	_approach_timer -= dt
	if _approach_timer <= 0.0:
		_approach_timer = 0.20
		if _pending_first != "":
			if _distance_ok(_pending_first):
				var id := _pending_first
				_pending_first = ""
				_start_pattern(id, "")
			return
		if not _candidates().is_empty():
			_enter(State.IDLE)
			state_time = DECISION_WAIT[phase - 1]  # decide on the next tick


# ---------- strikes ----------

## World rect of a strike's hitbox right now (facing applied). LANES returns the first lane; use _lane_rects.
func _zone_rect(s: Dictionary, gx_override: float = NAN) -> Rect2:
	var gy := ground_y
	var gx := global_position.x if is_nan(gx_override) else gx_override
	var h := float(s.h)
	var z := float(s.get("z", 0.0))
	match String(s.shape):
		"F", "MOVE":
			var w := float(s.w)
			var x0 := gx + (12.0 if facing > 0.0 else -w)
			return Rect2(x0, gy - z - h, w - 12.0, h)
		"B":
			var r := float(s.r)
			return Rect2(gx - r, gy - z - h, r * 2.0, h)
	return Rect2()


func _lane_rects(set_index: int) -> Array:
	var out: Array = []
	for i in 6:
		if i % 2 != set_index:
			continue
		out.append(Rect2(lane_x0 + i * LANE_W + LANE_MARGIN, global_position.y - 20.0, LANE_W - 2.0 * LANE_MARGIN, 20.0))
	return out


func _player_rect() -> Rect2:
	var hgt: float = _player.hurt_height()
	return Rect2(_player.global_position.x - PLAYER_HALF_W, _player.global_position.y - hgt, PLAYER_HALF_W * 2.0, hgt)


func _overlaps(s: Dictionary) -> bool:
	var pr := _player_rect()
	if String(s.shape) == "LANES":
		for r in _lane_rects(int(s.set)):
			if r.intersects(pr):
				return true
		return false
	return _zone_rect(s).intersects(pr)


## Melee origin = staff tip; floor attacks = the nearest floor point to the player inside the zone.
func _strike_origin(s: Dictionary) -> Vector2:
	if s.cls == U:
		var px := _player.global_position.x if _player else global_position.x
		var r: Rect2
		if String(s.shape) == "LANES":
			var best := Rect2()
			var bd := INF
			for lr in _lane_rects(int(s.set)):
				var d := absf(clampf(px, lr.position.x, lr.end.x) - px)
				if d < bd:
					bd = d
					best = lr
			r = best
		else:
			r = _zone_rect(s)
		return Vector2(clampf(px, r.position.x, r.end.x), global_position.y)
	return global_position + _anchor("staff_tip")


func _deliver(s: Dictionary) -> void:
	var hit := HitEvent.new()
	hit.attacker = self
	hit.instance_id = instance
	hit.hit_id = int(s.id)
	hit.origin = _strike_origin(s)
	hit.direction = Vector2(facing, 0)
	hit.raw_direct = float(s.raw)
	hit.knockback = float(KNOCKBACK[s.cls])
	hit.hitstun = CombatConfig.HURT_STUN
	hit.parry_class = int(s.cls)
	hit.posture_damage = float(POSTURE[s.cls])
	hit.ignore_invulnerability = false
	hit.hit_fx = "hit_player"
	hit.label = "%s#%d" % [pattern.name, int(s.id)]
	_player.receive_hit(hit)


func _spawn_strike_fx(s: Dictionary) -> void:
	var name := String(s.get("fx", ""))
	if name == "":
		return
	var c: Dictionary = Anim.effects[name]
	var dir := Vector2(facing, 0)
	var mag := float(s.get("fx_scale", 1.0))
	if String(s.shape) == "LANES":
		for r in _lane_rects(int(s.set)):
			Juice.fx(name, Vector2(r.get_center().x, global_position.y))
		return
	var vo: Array = c.get("visual_origin_from_foot", [0, 0])
	var at := global_position + Vector2(float(vo[0]) * facing, float(vo[1]))
	var half: bool = bool(c.get("mirror_half", false)) and bool(s.get("fx_half", true))
	if half:
		Juice.fx(name, at, Vector2.RIGHT, 1.0, false, null, mag)
		Juice.fx(name, at, Vector2.LEFT, 1.0, false, null, mag)
	else:
		Juice.fx(name, at, dir, facing, false, null, mag)


# ---------- anchors & visuals ----------

func _anchor(key: String) -> Vector2:
	var c: Dictionary = sheet.clips[_clip]
	var table: Dictionary = c.get(key, {})
	var k := str(_frame)
	var p: Vector2 = Vector2(table[k][0], table[k][1]) if table.has(k) else Vector2(60, 92)
	return Anim.cell_to_local(p, -facing, sheet.pivot)   # sheet faces left; facing -1 = as drawn


func _tablet_visible() -> bool:
	var c: Dictionary = sheet.clips[_clip]
	var t: Dictionary = c.get("tablet_visible", {})
	return bool(t.get(str(_frame), true))


func _tablet_name() -> String:
	return String(tablet.get_meta("part", ""))


func _set_tablet(name: String) -> void:
	Anim.boss_part_frame(tablet, name)
	tablet.set_meta("part", name)


func _apply_phase_look() -> void:
	_set_tablet("tablet_%d" % phase)
	belt.visible = phase >= 2
	hat_crack.visible = phase >= 3


func _update_strokes() -> void:
	if pattern.is_empty():
		strokes.visible = false
		stroke_big.visible = false
		return
	var remaining := 0
	for s in pattern.strikes:
		if not _fx_done.has(int(s.id)):
			remaining += 1
	var total: int = pattern.strikes.size()
	strokes.visible = total >= 2 and remaining > 0
	if strokes.visible:
		Anim.boss_part_frame(strokes, "stroke_%d" % clampi(remaining, 1, 4))
	stroke_big.visible = bool(pattern.get("big_last", false)) and remaining >= 1


## Current body clip + frame from the pattern timeline / state.
func _pick_body() -> void:
	match state:
		State.DEAD:
			var d: Dictionary = sheet.clips.death
			_clip = "death"
			_frame = mini(int(dead_time * float(d.fps)), int(d.count) - 1)
			return
		State.INTRO:
			_set_clip_time("intro", state_time, false)
			return
		State.STAGGER:
			var left: float = status.stagger_left
			if state_time < 2.0 / 12.0:
				_set_clip_time("stagger_in", state_time, false)
			elif left < 0.2:
				_set_clip_time("stagger_out", 0.2 - left, false)
			else:
				_set_clip_time("stagger", state_time, true)
			return
		State.PHASE_CHANGE:
			if state_time < 0.80:
				_set_clip_time("guard", 0.0, false)
			else:
				_set_clip_time("bow", state_time - 0.80, false)
			return
		State.APPROACH:
			if trail != null:
				_set_clip_time("slide", clock, true)
			else:
				_set_clip_time("hop", clock, true)
			return
		State.PATTERN:
			var clips: Array = pattern.clips
			var seg_start := 0.0
			var seg_clip := "idle"
			var seg_index := 0
			for i in clips.size():
				if pattern_time >= float(clips[i][0]):
					seg_start = float(clips[i][0])
					seg_clip = String(clips[i][1])
					seg_index = i
			if variation != "" and pattern_time < 0.20 and seg_index == 0 and seg_clip != "backstep":
				_set_clip_time("nod", pattern_time, false)
				return
			if global_position.y < ground_y - 1.0:
				_clip = "hop"   # airborne during a leap
				_frame = 2
				return
			var c: Dictionary = sheet.clips[seg_clip]
			_set_clip_time(seg_clip, pattern_time - seg_start, bool(c.get("loop", false)) or seg_clip == "slide")
			return
	_set_clip_time("idle", clock, true)


func _set_clip_time(name: String, t: float, loop: bool) -> void:
	var c: Dictionary = sheet.clips[name]
	var n := int(c.count)
	var i := int(maxf(0.0, t) * float(c.get("fps", 8)))
	_clip = name
	_frame = (i % n) if loop else mini(i, n - 1)


func _process(delta: float) -> void:
	if not Juice.frozen():
		flash = maxf(0.0, flash - delta)
		kick_v += (-kick * 500.0 - kick_v * 30.0) * delta
		kick += kick_v * delta
	_pick_body()
	var c: Dictionary = sheet.clips[_clip]
	sprite.frame = int(c.first) + _frame
	sprite.flip_h = facing > 0.0
	sprite.position = Vector2(kick, 0)
	sprite.modulate = Color(2, 2, 2) if flash > 0.0 else Color.WHITE
	# overlays follow the tablet anchor
	var ta := _anchor("tablet") + Vector2(kick, 0)
	var show_tablet := _tablet_visible() or state == State.DEAD
	tablet.visible = show_tablet
	tablet.position = ta
	belt.position = ta + Vector2(0, 16)
	hat_crack.position = ta + Vector2(0, -44)
	badge.position = ta + Vector2(-facing * 20.0, -4)
	strokes.position = ta + Vector2(facing * 22.0, -4)
	stroke_big.position = ta + Vector2(facing * 22.0, 14)
	arrow.position = Vector2(0, 8)
	if badge.visible:
		Anim.boss_part_frame(badge, "badge_byeon_%d" % (int(clock * 6.0) % 2))
	if arrow.visible:
		Anim.boss_part_frame(arrow, "arrow_turn_%d" % (int(clock * 6.0) % 2))
	if hat_spin and is_instance_valid(hat_spin):
		hat_spin.position = ta + Vector2(0, -58)
	_update_telegraph_sprites(ta)
	queue_redraw()


## The staff-tip mark and the head icon for the next pending strike (recreated when the class changes).
func _update_telegraph_sprites(ta: Vector2) -> void:
	var next: Dictionary = _next_strike()
	if next.is_empty() or state != State.PATTERN:
		_free(mark)
		_free(icon)
		mark = null
		icon = null
		mark_cls = -1
		icon_cls = -1
		return
	var cls := int(next.cls)
	var warned: bool = pattern_time >= float(next.get("warn_from", 0.0))
	if not warned:
		_free(mark)
		_free(icon)
		mark = null
		icon = null
		mark_cls = -1
		icon_cls = -1
		return
	if cls != icon_cls or icon == null or not is_instance_valid(icon):
		_free(icon)
		icon = Juice.fx(["icon_bang", "icon_bang2", "icon_x"][cls], Vector2.ZERO, Vector2.RIGHT, 1.0, false, self)
		icon_cls = cls
	icon.position = ta + Vector2(0, -70)
	if cls == U:
		_free(mark)
		mark = null
		mark_cls = -1
		return
	if cls != mark_cls or mark == null or not is_instance_valid(mark):
		_free(mark)
		mark = Juice.fx("mark_h" if cls == H else "mark_n", Vector2.ZERO, Vector2.RIGHT, 1.0, false, self)
		mark_cls = cls
	mark.position = _anchor("staff_tip") + Vector2(kick, 0)


func _next_strike() -> Dictionary:
	if pattern.is_empty():
		return {}
	for s in pattern.strikes:
		if not _fx_done.has(int(s.id)):
			return s
	return {}


func _clear_attachments() -> void:
	_free(mark)
	_free(icon)
	_free(trail)
	_free(hat_spin)
	mark = null
	icon = null
	trail = null
	hat_spin = null


func _free(n) -> void:
	if is_instance_valid(n):
		n.queue_free()


## Zones of pending strikes drawn 1:1 with the hitboxes: zone_fill tiles + danger edges for N/H,
## hatch tiles on the floor for U, lane hatching for P3_C. Also injury diamonds beside the tablet.
func _draw() -> void:
	if state == State.PATTERN and not pattern.is_empty():
		for s in pattern.strikes:
			var hid := int(s.id)
			if _fx_done.has(hid):
				continue
			var w0 := float(s.get("warn_from", 0.0))
			if pattern_time < w0:
				continue
			var progress := clampf((pattern_time - w0) / maxf(0.05, float(s.t) - w0), 0.0, 1.0)
			var cls := int(s.cls)
			if String(s.shape) == "LANES":
				for r in _lane_rects(int(s.set)):
					_draw_zone(r, cls, progress)
				continue
			_draw_zone(_zone_rect(s, _predicted_x(s)), cls, progress)
	load("res://src/enemies/enemy_base.gd")._draw_injury(self, status.injury, _anchor("tablet") + Vector2(-facing * 20.0, 12))


## Hitbox-exact danger zone: translucent red dot field (2px dots) whose density and brightness rise toward
## the strike, a red outline, and a solid bar on the floor edge for floor attacks. The class is told by the
## head icon / staff mark; the zone itself stays one colour so every attack reads the same way.
func _draw_zone(r: Rect2, cls: int, progress: float) -> void:
	var local := Rect2(r.position - global_position, r.size)
	var alpha := 0.28 + 0.45 * progress
	var dot := Color(1.0, 0.22, 0.2, alpha)
	var pitch := 8.0 if progress < 0.5 else 5.0
	var y := local.position.y + 2.0
	var row := 0
	while y < local.end.y - 1.0:
		var x := local.position.x + 2.0 + (pitch * 0.5 if row % 2 == 1 else 0.0)
		while x < local.end.x - 1.0:
			draw_rect(Rect2(x, y, 2, 2), dot)
			x += pitch
		y += pitch
		row += 1
	draw_rect(local, Color(1.0, 0.3, 0.25, 0.55 + 0.4 * progress), false, 2.0)
	if progress > 0.75:
		draw_rect(local.grow(2.0), Color(1.0, 0.85, 0.7, (progress - 0.75) * 2.0), false, 1.0)
	if cls == U:
		draw_rect(Rect2(local.position.x, local.end.y - 3.0, local.size.x, 3.0), Color(1.0, 0.25, 0.2, 0.7 + 0.3 * progress))
