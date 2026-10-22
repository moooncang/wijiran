class_name PalmStyles
## 장법 데이터 (장법-발견과-장착-시스템-기획서.md, 2026-10-21 장법 4종 개편안). One equip slot swaps the whole
## main-attack set: three light strikes + one heavy. Every strike dictionary is consumed by Player unchanged,
## so the player code never branches on a style id. Meaning-based flags replace identity checks:
##   combo_index 0..2 (counter eligibility = first strike), is_heavy, injury_mode "add" | "burst".
## 흑월장 keeps the legacy immediate strikes (kind thrust / spin / burst). The other three are "timeline"
## strikes (개편안 §6-8): `time` is the whole motion, and everything is keyed to seconds from its start —
##   moves  [{from, to, dist}]                        forward travel (horizontal on the ground, along the aim in the air)
##   fx     [{t, clip, at: "torso"|"hand", follow}]   art; `follow` rides the body and dies with a cancel
##   events [{t, shape, ...}]                         damage: one ledger entry per (attack, event index, target)
##     front  {len, w}            box from the hand along the facing, read once at t
##     circle {r}                 around the torso, once at t
##     sweep  {until, w, reach}   the body's path from t to until (쇄진장 진입장)
##     ring   {until, r0, r1, w, art, hold, lead, pull}   band of radius r0→r1 around the cast point, checked every tick
##     scar   {fire, len, w, art, art_t}  a crack at the hand that fires at `fire` even if the swing is cancelled
##     path   {fire, grow, w, art}        the ground actually run over until `grow`, fired at `fire` (쇄진장 파진)
##   damage, injury (add), burst (per-stack, consumes), fx (impact clip), hit_stop, shake, kick, crack (inner crack art on a burst)
## "desc" (per strike) is display-only: the palm menu's one-line description of that strike.

const DEFAULT_ID := "black_moon"

const STYLES := {
	"black_moon": {
		"name": "흑월장", "role": "범용 · 입문. 붙어서 즉시 타격하고 발경한다.",
		"traits": "전방 도달 보통 · 다수 가능 · 균형", "strength": "상황을 가리지 않는 고른 성능.", "caution": "전문 영역에서는 다른 장법보다 효율이 낮다.",
		"icon": "palm_black_moon", "source": "",
		"light": [
			{"name": "초승", "desc": "전방 돌진 타격", "kind": "thrust", "damage": 12, "injury": 1, "reach": 70.0, "arc": 40.0, "time": 0.07, "windup": 0.0, "lunge": 440.0, "hit_stop": 0.06, "shake": 5.0, "kick": 14, "fx": "thrust_hit", "smear": "thrust_line", "cooldown": 0.04},
			{"name": "반월", "desc": "몸 주위 원형 타격", "kind": "spin", "damage": 16, "injury": 1, "reach": 52.0, "arc": 360.0, "time": 0.12, "windup": 0.0, "lunge": 320.0, "hit_stop": 0.07, "shake": 6.0, "kick": 16, "fx": "spin_hit", "smear": "spin_whirl", "cooldown": 0.05},
			{"name": "만월", "desc": "손끝 발경 · 내상 폭발", "kind": "burst", "damage": 30, "injury_burst": true, "burst_per_stack": 8.0, "reach": 54.0, "arc": 0.0, "time": 0.10, "windup": 0.24, "lunge": 360.0, "hit_stop": 0.16, "shake": 11.0, "kick": 26, "fx": "burst_hit", "smear": "burst_core", "fx_scale": 1.0, "cooldown": 0.22},
		],
		"heavy": {"name": "강화 만월", "desc": "넓은 손끝 발경 · 내상 폭발", "kind": "burst", "damage": 42, "injury_burst": true, "burst_per_stack": 12.0, "reach": 64.0, "arc": 0.0, "time": 0.11, "windup": 0.28, "lunge": 400.0, "hit_stop": 0.18, "shake": 13.0, "kick": 30, "fx": "burst_hit", "smear": "burst_core", "fx_scale": 1.25, "cooldown": 0.26, "qi_cost": 25.0, "rift_gain": 30.0},
	},
	"formation_breaker": {
		"name": "쇄진장", "role": "직선 돌파. 몸은 앞으로 빠져나가고, 남겨둔 장력이 뒤늦게 터진다.",
		"traits": "전방 도달 높음 · 지연 장흔 · 단일 방향", "strength": "적이 들어올 자리 선점, 접근 후 이탈, 좁은 길.", "caution": "장흔에서 벗어나는 적을 놓치고 후방 포위에 약하다.\n전진 중에도 무적은 없다.",
		"icon": "palm_formation_breaker", "source": "f1_outpost_manual",
		"light": [
			{"name": "진입장", "desc": "64px 돌진, 지나간 길을 쓸어 타격", "kind": "timeline", "pose": "thrust", "time": 0.18, "cooldown": 0.04,
				"moves": [{"from": 0.04, "to": 0.12, "dist": 64.0}],
				"fx": [{"t": 0.04, "clip": "r12_fb_enter", "at": "torso", "follow": true}],
				"events": [{"t": 0.04, "until": 0.12, "shape": "sweep", "w": 28.0, "reach": 24.0, "damage": 12, "injury": 1, "fx": "thrust_hit", "hit_stop": 0.06, "shake": 5.0, "kick": 14}]},
			{"name": "쐐기장", "desc": "전방 80px 쐐기 찌르기", "kind": "timeline", "pose": "thrust", "time": 0.18, "cooldown": 0.04,
				"fx": [{"t": 0.05, "clip": "r12_fb_wedge", "at": "hand"}],
				"events": [{"t": 0.05, "shape": "front", "len": 80.0, "w": 32.0, "damage": 14, "injury": 1, "fx": "thrust_hit", "hit_stop": 0.07, "shake": 6.0, "kick": 16}]},
			{"name": "잔진", "desc": "손앞에 장흔을 남기고 0.18초 뒤 폭발 · 내상 폭발", "kind": "timeline", "pose": "burst", "time": 0.60, "cooldown": 0.22,
				"events": [{"t": 0.16, "fire": 0.34, "shape": "scar", "len": 112.0, "w": 36.0, "damage": 32, "burst": 8.0, "fx": "burst_hit", "hit_stop": 0.16, "shake": 11.0, "kick": 28,
					"art": ["r12_fb_scar", "r12_fb_scar_charge", "r12_fb_scar_burst"], "art_t": [0.0, 0.08, 0.18]}]},
		],
		"heavy": {"name": "파진", "desc": "100px 돌파 후 지나간 길 전체가 한 번 발경 · 내상 폭발", "kind": "timeline", "pose": "burst", "time": 0.80, "cooldown": 0.26, "qi_cost": 25.0, "rift_gain": 30.0,
			"moves": [{"from": 0.24, "to": 0.36, "dist": 100.0}],
			"events": [{"t": 0.24, "fire": 0.52, "grow": 0.36, "shape": "path", "w": 44.0, "damage": 42, "burst": 12.0, "fx": "burst_hit", "hit_stop": 0.18, "shake": 13.0, "kick": 32,
				"art": ["r12_fb_path", "r12_fb_path_burst"], "art_t": [0.0, 0.28]}]},
	},
	"returning_tide": {
		"name": "회란장", "role": "다수전. 기환이 몸에서 멀어졌다 돌아온다 — 왕복 거리와 적 위치를 맞춘다.",
		"traits": "전방 도달 없음 · 왕복 고리 · 좌우 동시", "strength": "좌우 동시 대응, 반경 끝의 적 압박.", "caution": "왕복 전 취소하면 피해를 잃고, 고리 중심을 벗어난 적에게는 빗나간다.",
		"icon": "palm_returning_tide", "source": "f2_storage_manual",
		"light": [
			{"name": "개환", "desc": "반경 24→68px 확장 고리", "kind": "timeline", "pose": "spin", "time": 0.18, "cooldown": 0.04,
				"events": [{"t": 0.03, "until": 0.12, "shape": "ring", "r0": 24.0, "r1": 68.0, "w": 22.0, "art": "r12_rt_l1_out", "damage": 12, "injury": 1, "fx": "rt_push_hit", "hit_stop": 0.05, "shake": 4.0, "kick": 0}]},
			{"name": "회환", "desc": "반경 76→20px 수축 고리", "kind": "timeline", "pose": "spin", "time": 0.18, "cooldown": 0.05,
				"events": [{"t": 0.03, "until": 0.12, "lead": 0.03, "shape": "ring", "r0": 76.0, "r1": 20.0, "w": 22.0, "art": "r12_rt_l2_in", "damage": 16, "injury": 1, "fx": "rt_push_hit", "hit_stop": 0.07, "shake": 6.0, "kick": 0}]},
			{"name": "만조", "desc": "나가는 띠 12, 돌아오는 띠 18 · 내상 폭발", "kind": "timeline", "pose": "spin", "time": 0.60, "cooldown": 0.22,
				"events": [{"t": 0.12, "until": 0.22, "hold": 0.08, "shape": "ring", "r0": 24.0, "r1": 100.0, "w": 26.0, "art": "r12_rt_l3_out", "damage": 12, "fx": "rt_push_hit", "hit_stop": 0.06, "shake": 5.0, "kick": 0},
					{"t": 0.30, "until": 0.44, "shape": "ring", "r0": 100.0, "r1": 20.0, "w": 26.0, "art": "r12_rt_l3_in", "damage": 18, "burst": 8.0, "pull": 12.0, "fx": "r12_rt_return_hit", "hit_stop": 0.14, "shake": 10.0, "kick": 0}]},
		],
		"heavy": {"name": "회천", "desc": "반경 120px까지 왕복하는 큰 고리 · 내상 폭발", "kind": "timeline", "pose": "spin", "time": 0.80, "cooldown": 0.26, "qi_cost": 25.0, "rift_gain": 30.0,
			"events": [{"t": 0.20, "until": 0.34, "hold": 0.08, "shape": "ring", "r0": 24.0, "r1": 120.0, "w": 30.0, "art": "r12_rt_e_out", "damage": 16, "fx": "rt_push_hit", "hit_stop": 0.08, "shake": 6.0, "kick": 0},
				{"t": 0.42, "until": 0.58, "shape": "ring", "r0": 120.0, "r1": 20.0, "w": 30.0, "art": "r12_rt_e_in", "damage": 26, "burst": 12.0, "pull": 12.0, "fx": "r12_rt_return_hit", "hit_stop": 0.18, "shake": 13.0, "kick": 0}]},
	},
	"bone_piercing": {
		"name": "투골장 · 극의", "role": "후반 성장 보상. 넓은 장력으로 압박하고 다중 발경으로 끝낸다.",
		"traits": "전방 도달 높음 · 넓은 범위 · 2단 발경", "strength": "기본 연계부터 강하고, 무간붕천은 작은 필살기다.", "caution": "무간붕천은 내공 40 · 마열 45에 준비가 길다.\n정화 구역에서는 폭발이 약해진다.",
		"icon": "palm_bone_piercing", "source": "f3_cart_manual",
		"light": [
			{"name": "천문", "desc": "거대 장인 · 전방 96px", "kind": "timeline", "pose": "thrust", "time": 0.20, "cooldown": 0.04,
				"moves": [{"from": 0.0, "to": 0.06, "dist": 24.0}],
				"fx": [{"t": 0.06, "clip": "r12_bp_heaven_palm", "at": "hand"}],
				"events": [{"t": 0.06, "shape": "front", "len": 96.0, "w": 48.0, "damage": 18, "injury": 1, "fx": "thrust_hit", "hit_stop": 0.06, "shake": 5.0, "kick": 14}]},
			{"name": "겹월", "desc": "월륜 뒤 겹장 · 반경 84px 한 번", "kind": "timeline", "pose": "spin", "time": 0.22, "cooldown": 0.05,
				"fx": [{"t": 0.0, "clip": "r12_bp_moon_small", "at": "torso", "follow": true}, {"t": 0.08, "clip": "r12_bp_fold_palms", "at": "torso"}],
				"events": [{"t": 0.08, "shape": "circle", "r": 84.0, "damage": 24, "injury": 1, "fx": "spin_hit", "hit_stop": 0.07, "shake": 6.0, "kick": 18}]},
			{"name": "관천", "desc": "수렴 뒤 두 번의 전방 발경 · 두 번째에 내상 폭발", "kind": "timeline", "pose": "burst", "time": 0.60, "cooldown": 0.22,
				"fx": [{"t": 0.0, "clip": "r12_bp_gather", "at": "hand", "follow": true}, {"t": 0.22, "clip": "r12_bp_wave_first", "at": "hand"}, {"t": 0.34, "clip": "r12_bp_wave_final", "at": "hand"}],
				"events": [{"t": 0.22, "shape": "front", "len": 136.0, "w": 72.0, "damage": 18, "fx": "burst_hit", "hit_stop": 0.08, "shake": 6.0, "kick": 14},
					{"t": 0.34, "shape": "front", "len": 136.0, "w": 72.0, "damage": 30, "burst": 12.0, "crack": true, "fx": "burst_hit", "hit_stop": 0.16, "shake": 11.0, "kick": 26}]},
		],
		"heavy": {"name": "무간붕천", "desc": "월륜 전개 → 첫 장력 30 → 거대 장인 50 · 내상당 20 폭발", "kind": "timeline", "pose": "burst", "time": 1.00, "cooldown": 0.30, "qi_cost": 40.0, "rift_gain": 45.0,
			"fx": [{"t": 0.0, "clip": "r12_bp_moon_great", "at": "torso", "follow": true}, {"t": 0.40, "clip": "r12_bp_heavy_first", "at": "hand"}, {"t": 0.54, "clip": "r12_bp_heavy_final", "at": "hand"}],
			"events": [{"t": 0.40, "shape": "front", "len": 180.0, "w": 100.0, "damage": 30, "fx": "burst_hit", "hit_stop": 0.035, "shake": 3.0, "kick": 16},
				{"t": 0.54, "shape": "front", "len": 180.0, "w": 100.0, "damage": 50, "burst": 20.0, "crack": true, "fx": "burst_hit", "hit_stop": 0.07, "shake": 5.0, "kick": 32}]},
	},
}

const MANUALS := {   # manual item id → style; the pickup location owns the id (기획 §3 저장)
	"f1_outpost_manual": "formation_breaker",
	"f2_storage_manual": "returning_tide",
	"f3_cart_manual": "bone_piercing",
}


static func ids() -> Array:
	return STYLES.keys()


static func style(id: String) -> Dictionary:
	return STYLES.get(id, STYLES[DEFAULT_ID])


## Strike i (0..2) of a style, tagged with the semantic flags the player reads.
static func light(id: String, i: int) -> Dictionary:
	var s: Dictionary = style(id)
	var a: Dictionary = s.light[clampi(i, 0, 2)].duplicate()
	a.combo_index = clampi(i, 0, 2)
	a.is_heavy = false
	return _tag(a, id)


static func heavy(id: String) -> Dictionary:
	var a: Dictionary = style(id).heavy.duplicate()
	a.combo_index = -1
	a.is_heavy = true
	return _tag(a, id)


static func _tag(a: Dictionary, id: String) -> Dictionary:
	a.style = id
	a.injury_mode = "burst" if (a.get("injury_burst", false) or a.is_heavy) else "add"
	a.targets = a.get("targets", "multi")
	a.arc = a.get("arc", 0.0)        # the arm pose reads these for timeline strikes too
	a.windup = a.get("windup", 0.0)
	return a
