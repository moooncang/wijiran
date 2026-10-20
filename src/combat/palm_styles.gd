class_name PalmStyles
## 장법 데이터 (장법-발견과-장착-시스템-기획서.md). One equip slot swaps the whole main-attack set:
## three light strikes + one heavy. Every strike dictionary is consumed by Player._start_swing unchanged,
## so the player code never branches on a style id. Meaning-based flags replace identity checks:
##   combo_index 0..2 (counter eligibility = first strike), is_heavy, injury_mode "add" | "burst",
##   targets "multi" | "single", kind "thrust" | "spin" | "burst" | "front_burst".
## Numbers are the 기획서 §6 relative targets applied per strike; 흑월장 is the measured v9 baseline.

const DEFAULT_ID := "black_moon"

const STYLES := {
	"black_moon": {
		"name": "흑월장", "hanja": "黑月掌", "role": "범용 · 입문. 방향과 적 수가 자주 바뀌는 전투에 안정적.",
		"traits": "전방 도달 보통 · 다수 가능 · 균형", "strength": "어떤 상황에서도 기본값 이상.", "caution": "전문 영역에서는 다른 장법보다 효율이 낮다.",
		"icon": "palm_black_moon", "source": "",
		"light": [
			{"name": "초승", "kind": "thrust", "damage": 12, "injury": 1, "reach": 70.0, "arc": 40.0, "time": 0.07, "windup": 0.0, "lunge": 440.0, "hit_stop": 0.06, "shake": 5.0, "kick": 14, "fx": "thrust_hit", "smear": "thrust_line", "cooldown": 0.04},
			{"name": "반월", "kind": "spin", "damage": 16, "injury": 1, "reach": 52.0, "arc": 360.0, "time": 0.12, "windup": 0.0, "lunge": 320.0, "hit_stop": 0.07, "shake": 6.0, "kick": 16, "fx": "spin_hit", "smear": "spin_whirl", "cooldown": 0.05},
			{"name": "만월", "kind": "burst", "damage": 30, "injury_burst": true, "burst_per_stack": 8.0, "reach": 54.0, "arc": 0.0, "time": 0.10, "windup": 0.24, "lunge": 360.0, "hit_stop": 0.16, "shake": 11.0, "kick": 26, "fx": "burst_hit", "smear": "burst_core", "fx_scale": 1.0, "cooldown": 0.22},
		],
		"heavy": {"name": "강화 만월", "kind": "burst", "damage": 42, "injury_burst": true, "burst_per_stack": 12.0, "reach": 64.0, "arc": 0.0, "time": 0.11, "windup": 0.28, "lunge": 400.0, "hit_stop": 0.18, "shake": 13.0, "kick": 30, "fx": "burst_hit", "smear": "burst_core", "fx_scale": 1.25, "cooldown": 0.26, "qi_cost": 25.0, "rift_gain": 30.0},
	},
	"formation_breaker": {
		"name": "쇄진장", "hanja": "碎陣掌", "role": "직선 돌파. 원거리 적에게 닿는 데 유리하고 좁은 전방에 집중.",
		"traits": "전방 도달 높음 · 뒤쪽 판정 없음 · 단일 방향", "strength": "궁수 접근과 한쪽 방향 돌파.", "caution": "후방에 취약하고 잘못 들어가면 피격 위험이 높다. 전진 중 무적 없음.",
		"icon": "palm_formation_breaker", "source": "f1_outpost_manual",
		"light": [
			{"name": "진입장", "kind": "thrust", "damage": 11, "injury": 1, "reach": 96.0, "arc": 30.0, "time": 0.08, "windup": 0.0, "lunge": 640.0, "hit_stop": 0.06, "shake": 5.0, "kick": 14, "fx": "thrust_hit", "smear": "fb_enter_line", "aura": "fb_rush_aura", "cooldown": 0.05},
			{"name": "쐐기장", "kind": "thrust", "damage": 15, "injury": 1, "reach": 80.0, "arc": 24.0, "time": 0.08, "windup": 0.0, "lunge": 380.0, "hit_stop": 0.07, "shake": 6.0, "kick": 16, "fx": "thrust_hit", "smear": "fb_wedge", "aura": "fb_rush_aura", "cooldown": 0.05},
			{"name": "파진장", "kind": "front_burst", "damage": 28, "injury_burst": true, "burst_per_stack": 8.0, "reach": 60.0, "arc": 0.0, "time": 0.10, "windup": 0.22, "lunge": 420.0, "hit_stop": 0.16, "shake": 11.0, "kick": 28, "fx": "burst_hit", "smear": "fb_break_front", "fx_scale": 1.0, "cooldown": 0.24},
		],
		"heavy": {"name": "강화 관진", "kind": "front_burst", "damage": 42, "injury_burst": true, "burst_per_stack": 12.0, "reach": 60.0, "arc": 0.0, "time": 0.12, "windup": 0.30, "lunge": 760.0, "hit_stop": 0.18, "shake": 13.0, "kick": 32, "fx": "burst_hit", "smear": "fb_heavy_front", "fx_scale": 1.0, "cooldown": 0.40, "qi_cost": 30.0, "rift_gain": 30.0},
	},
	"returning_tide": {
		"name": "회란장", "hanja": "回瀾掌", "role": "다수전. 넓게 때리고 적 사이에서 빠져나올 공간을 만든다.",
		"traits": "전방 도달 낮음 · 원형 범위 · 일반 적 밀어내기", "strength": "둘러싸인 전투, 근접 졸개 묶음 처리.", "caution": "적을 밀어내 연계가 끊기고 보스 단일 화력은 낮다.",
		"icon": "palm_returning_tide", "source": "f2_storage_manual",
		"light": [
			{"name": "개장", "kind": "thrust", "damage": 9, "injury": 1, "reach": 60.0, "arc": 70.0, "time": 0.08, "windup": 0.0, "lunge": 300.0, "hit_stop": 0.05, "shake": 4.0, "kick": 12, "fx": "rt_push_hit", "smear": "rt_open_arc", "aura": "", "cooldown": 0.05},
			{"name": "환장", "kind": "spin", "damage": 12, "injury": 1, "reach": 62.0, "arc": 360.0, "time": 0.13, "windup": 0.0, "lunge": 240.0, "hit_stop": 0.07, "shake": 6.0, "kick": 18, "fx": "rt_push_hit", "smear": "rt_ring", "fx_scale": 1.0, "cooldown": 0.06},
			{"name": "퇴조", "kind": "spin", "damage": 20, "injury_burst": true, "burst_per_stack": 6.0, "reach": 78.0, "arc": 360.0, "time": 0.14, "windup": 0.22, "lunge": 200.0, "hit_stop": 0.14, "shake": 10.0, "kick": 40, "fx": "rt_push_hit", "smear": "rt_tide", "fx_scale": 1.0, "cooldown": 0.26, "push_normal": true},
		],
		"heavy": {"name": "강화 회란", "kind": "spin", "damage": 32, "injury_burst": true, "burst_per_stack": 9.0, "reach": 92.0, "arc": 360.0, "time": 0.16, "windup": 0.32, "lunge": 160.0, "hit_stop": 0.18, "shake": 13.0, "kick": 44, "fx": "rt_push_hit", "smear": "rt_heavy", "fx_scale": 1.0, "cooldown": 0.34, "qi_cost": 30.0, "rift_gain": 30.0, "push_normal": true},
	},
	"bone_piercing": {
		"name": "투골장", "hanja": "透骨掌", "role": "단일 대상 · 내상 집중. 짧은 거리를 유지하며 기회를 기다린다.",
		"traits": "전방 도달 낮음 · 단일 대상 · 내상 2 부여", "strength": "가까이 붙는 중장갑 단일 적, 기절한 보스.", "caution": "다수전·거리 변화에 약하고 준비 중 공격받기 쉽다. 정화 구역에서는 폭발이 약해진다.",
		"icon": "palm_bone_piercing", "source": "f3_cart_manual",
		"light": [
			{"name": "점장", "kind": "thrust", "damage": 9, "injury": 1, "reach": 50.0, "arc": 30.0, "time": 0.07, "windup": 0.0, "lunge": 260.0, "hit_stop": 0.06, "shake": 4.0, "kick": 10, "fx": "thrust_hit", "smear": "bp_point", "aura": "", "fx_scale": 1.0, "cooldown": 0.04, "targets": "single"},
			{"name": "첩장", "kind": "thrust", "damage": 10, "injury": 2, "reach": 50.0, "arc": 30.0, "time": 0.08, "windup": 0.06, "lunge": 220.0, "hit_stop": 0.08, "shake": 5.0, "kick": 10, "fx": "thrust_hit", "smear": "bp_fold", "aura": "", "fx_scale": 1.0, "cooldown": 0.05, "targets": "single"},
			{"name": "침장", "kind": "front_burst", "damage": 14, "injury_burst": true, "burst_per_stack": 12.0, "reach": 50.0, "arc": 0.0, "time": 0.10, "windup": 0.26, "lunge": 240.0, "hit_stop": 0.16, "shake": 10.0, "kick": 18, "fx": "burst_hit", "smear": "bp_needle", "fx_scale": 1.0, "cooldown": 0.26, "targets": "single"},
		],
		"heavy": {"name": "강화 투골", "kind": "front_burst", "damage": 25, "injury_burst": true, "burst_per_stack": 18.0, "reach": 54.0, "arc": 0.0, "time": 0.12, "windup": 0.40, "lunge": 260.0, "hit_stop": 0.20, "shake": 13.0, "kick": 22, "fx": "burst_hit", "smear": "bp_heavy", "fx_scale": 1.0, "cooldown": 0.34, "qi_cost": 30.0, "rift_gain": 35.0, "targets": "single"},
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
	a.style = id
	a.injury_mode = "burst" if a.get("injury_burst", false) else "add"
	a.targets = a.get("targets", "multi")
	return a


static func heavy(id: String) -> Dictionary:
	var a: Dictionary = style(id).heavy.duplicate()
	a.combo_index = -1
	a.is_heavy = true
	a.style = id
	a.injury_mode = "burst"
	a.targets = a.get("targets", "multi")
	return a
