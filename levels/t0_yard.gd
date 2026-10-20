class_name LevelT0
## T0 천흑산 잔등 연무장 (본편 §4). The course cannot be finished without each movement skill:
##   1. 무너진 계단 — a 115px wall: a single jump tops out at ~80px, jump + 허공답월 reaches ~130.
##   2. 끊긴 다리 — a 90px pit under a 60px ceiling: no jump fits, a ground 잔월보 (130px + carry) does.
##   3. 단면 절벽 — a 180px wall: jump + air jump reach 130; only an upward air dash adds the rest.
##   4. 공격 연습 / 월인 / 패링 연습 / 출정문.
## Falling into a pit returns the player to the last footing (no damage).

static func data() -> Dictionary:
	return {
		"id": "t0", "name": "천흑산 잔등 연무장", "width": 3000.0, "ground_y": 300.0, "backdrop": "yard",
		"spawns": {"start": Vector2(120, 300), "from_f1": Vector2(2880, 300)},
		"floor": [[-200.0, 1060.0], [1150.0, 3200.0]],
		"platforms": [
			Rect2(560, 185, 240, 115),            # 1. the wall (115 tall) — jump + air jump
			Rect2(800, 185, 120, 14),              # landing lip
			Rect2(1380, 120, 60, 180),             # 3. the cliff (180 tall) — needs an upward air dash
			Rect2(1440, 120, 120, 14),
		],
		"ceilings": [Rect2(1000, 60, 270, 180)],   # 2. the broken bridge: 60px headroom over the 90px pit
		"props": [
			{"type": "sign", "x": 220, "text": "A/D 이동 · W 점프 · 공중에서 W 허공답월 · Shift 마우스 방향 잔월보"},
			{"type": "checkpoint", "x": 300, "id": "yard"},
			{"type": "sign", "x": 480, "text": "무너진 계단: 점프 중에 W 한 번 더 — 허공답월로만 넘는다"},
			{"type": "sign", "x": 940, "text": "끊긴 다리: 천장이 낮아 못 뛴다. 끝까지 걸어가 마우스를 앞에 두고 Shift 잔월보"},
			{"type": "sign", "x": 1300, "text": "단면 절벽: 점프 → 허공답월 → 위를 조준하고 Shift. 공중 잔월보는 한 번"},
			{"type": "checkpoint", "x": 1620, "id": "upper"},
			{"type": "sign", "x": 1760, "text": "공격 연습: 좌클릭 3연계 · E 강화 초식 · Q 월식 · 우클릭 월인(적 당기기)"},
			{"type": "dummy", "x": 1880}, {"type": "dummy", "x": 1980}, {"type": "dummy", "x": 2120},
			{"type": "rest", "x": 2240},
			{"type": "sign", "x": 2360, "text": "패링 연습: 목각교두의 단타를 Space로. 완전 0.10초 · 부분 0.25초"},
			{"type": "door", "x": 2920, "to": "f1", "spawn": "start", "label": "출정문 — 불탄 수림길"},
		],
		"rooms": [
			{"id": "intro", "x0": 0, "x1": 460, "lines": [["위지란", "돌아올 때까지 매듭 늘리지 마. 너희 이름, 다 기억하니까."], ["제자", "단주님… 북부 피난로 조가 돌아오지 않았습니다."]]},
			{"id": "parry_drill", "x0": 2320, "x1": 2860, "enemies": [{"type": "mokgak_drill", "x": 2600}]},
		],
		"camera": {"top": -160, "bottom": 400},
	}
