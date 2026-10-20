class_name LevelT0
## T0 천흑산 잔등 연무장 (본편 §4): 출정 준비 → 무너진 계단 → 공격 연습 → 패링 연습 → 출정문.
## Nothing here gates progress: the door opens at once (체험판 경험자 생략 가능).

static func data() -> Dictionary:
	return {
		"id": "t0", "name": "천흑산 잔등 연무장", "width": 2200.0, "ground_y": 300.0, "backdrop": "yard",
		"spawns": {"start": Vector2(120, 300), "from_f1": Vector2(2080, 300)},
		"platforms": [Rect2(560, 240, 90, 14), Rect2(700, 190, 90, 14), Rect2(860, 140, 90, 14), Rect2(1010, 200, 110, 14)],
		"props": [
			{"type": "sign", "x": 220, "text": "A/D 이동 · W 점프 · 공중 W 허공답월 · Shift 마우스 방향 잔월보"},
			{"type": "checkpoint", "x": 300, "id": "yard"},
			{"type": "sign", "x": 520, "text": "무너진 계단: 점프 → 2단 점프 → 공중 대시로 오르기"},
			{"type": "sign", "x": 1240, "text": "공격 연습: 좌클릭 3연계 · E 강화 · Q 월식"},
			{"type": "dummy", "x": 1340}, {"type": "dummy", "x": 1440}, {"type": "dummy", "x": 1540},
			{"type": "rest", "x": 1660},
			{"type": "sign", "x": 1760, "text": "패링 연습: 목각교두의 단타를 Space로 받아낸다. 완전 0.10초 · 부분 0.25초"},
			{"type": "door", "x": 2120, "to": "f1", "spawn": "start", "label": "출정문 — 불탄 수림길"},
		],
		"rooms": [
			{"id": "intro", "x0": 0, "x1": 480, "lines": [["위지란", "돌아올 때까지 매듭 늘리지 마. 너희 이름, 다 기억하니까."], ["제자", "단주님… 북부 피난로 조가 돌아오지 않았습니다."]]},
			{"id": "parry_drill", "x0": 1720, "x1": 2060, "enemies": [{"type": "mokgak_drill", "x": 1900}]},
		],
		"camera": {"top": -140, "bottom": 400},
	}
