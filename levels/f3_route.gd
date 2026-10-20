class_name LevelF3
## F3 백향 이송로 (본편 §8): a mixed column under white incense. Two lock rooms (수레터, 심문소 외곽).
## 향지기 lay 정화 zones — the back line to clear first; the 성약군 사수 reuses the scout AI with the
## human skin on the gate steps. The 투골장 manual sits on the abandoned cart.

static func data() -> Dictionary:
	return {
		"id": "f3", "name": "백향 이송로", "width": 3400.0, "ground_y": 300.0, "backdrop": "shrine",
		"spawns": {"start": Vector2(80, 300), "from_b3": Vector2(3300, 300)},
		"platforms": [
			Rect2(560, 260, 130, 40),                                   # 1. the abandoned cart → manual
			Rect2(1100, 230, 120, 14),                                  # 2. incense post
			Rect2(1700, 240, 100, 16), Rect2(1820, 180, 100, 16), Rect2(1940, 120, 100, 16),   # 3. gate steps (the shooter on top)
			Rect2(2500, 250, 160, 50),                                  # 4. interrogation wall
			Rect2(3100, 276, 200, 24),                                  # 5. the dais before the shrine
		],
		"covers": [Rect2(900, 260, 40, 40), Rect2(2300, 260, 40, 40)],
		"props": [
			{"type": "checkpoint", "x": 60, "id": "entry"},
			{"type": "sign", "x": 150, "text": "비워진 수레터: 흰 천막, 태양 깃발. 향 냄새가 코를 찌른다"},
			{"type": "manual", "x": 625, "y": 260, "id": "f3_cart_manual"},
			{"type": "sign", "x": 820, "text": "향지기: 정화 구역 안에서는 내상 폭발이 30% 약해진다 — 후열부터 끊어라"},
			{"type": "pickup", "x": 1500, "kind": "tonic", "id": "f3_tonic"},
			{"type": "checkpoint", "x": 2050, "id": "mid"},
			{"type": "pickup", "x": 2700, "kind": "record", "id": "f3_record", "text": "이송 기록: 「이교도 4 — 향당. 향이 다 타기 전까지 심문」"},
			{"type": "sign", "x": 2870, "text": "향당 앞: 안쪽에서 제자 목소리가 들린다"},
			{"type": "rest", "x": 2950},
			{"type": "checkpoint", "x": 3020, "id": "before_boss"},
			{"type": "mark", "x": 3070, "clip": "disciple_mark"},
			{"type": "door", "x": 3340, "to": "b3", "spawn": "start", "label": "향당 — 엘로디"},
		],
		"rooms": [
			{"id": "r1", "name": "비워진 수레터", "x0": 220, "x1": 760, "lock": true,
				"enemies": [{"type": "soldier", "x": 480}, {"type": "soldier", "x": 620, "combo": true}, {"type": "shield", "x": 710}],
				"lines": [["위지란", "수레는 비었고 냄새만 남았네. 서둘러야겠어."]]},
			{"id": "r2", "name": "향 피우는 초소", "x0": 860, "x1": 1300,
				"enemies": [{"type": "soldier", "x": 1050}, {"type": "incense", "x": 1200}]},
			{"id": "r3", "name": "산문 계단", "x0": 1400, "x1": 2000,
				"enemies": [{"type": "shield", "x": 1700}, {"type": "archer", "x": 1990, "y": 120, "human": true}]},
			{"id": "r4", "name": "심문소 외곽", "x0": 2100, "x1": 2600, "lock": true,
				"enemies": [{"type": "soldier", "x": 2250}, {"type": "soldier", "x": 2380, "combo": true}, {"type": "incense", "x": 2470}]},
			{"id": "r5", "name": "향당 앞", "x0": 2900, "x1": 3400,
				"lines": [["제자", "(안쪽에서) …단주님? 단주님이세요?"], ["위지란", "기다려. 향이 다 타기 전에 간다."]]},
		],
		"camera": {"top": -140, "bottom": 400},
	}
