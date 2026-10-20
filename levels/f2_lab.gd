class_name LevelF2
## F2 단층 임시 연구소 (본편 §7): casters and room devices before head counts. Two lock rooms (반입장,
## 격석 측정대). The 회란장 manual sits on the specimen shelves (air jump + air dash). The open cell at the
## end holds two disciples to free; the rest were moved on (the transfer record comes from 미레유).

static func data() -> Dictionary:
	return {
		"id": "f2", "name": "단층 임시 연구소", "width": 3400.0, "ground_y": 300.0, "backdrop": "lab",
		"spawns": {"start": Vector2(80, 300), "from_b2": Vector2(3300, 300)},
		"platforms": [
			Rect2(480, 240, 120, 60),                        # 1. crate stack (over the shield line)
			Rect2(1100, 236, 140, 16),                       # 2. observation desk the mage casts from
			Rect2(1500, 220, 110, 14), Rect2(1700, 170, 110, 14),   # 3. specimen shelves → manual
			Rect2(2250, 276, 200, 24),                       # 4. measurement dais between the plates
		],
		"covers": [Rect2(900, 260, 40, 40), Rect2(1950, 260, 40, 40)],
		"props": [
			{"type": "checkpoint", "x": 60, "id": "entry"},
			{"type": "sign", "x": 150, "text": "반입장: 방패병은 정면이 단단하다 — 뒤로 넘거나 내상 폭발(E)로 방패를 벌려라||반입장: 방패병은 정면이 단단하다 — 뒤로 넘거나 내상 폭발(강화 버튼)로 방패를 벌려라"},
			{"type": "sign", "x": 880, "text": "관측 복도: 마법사는 시전 중에 맞으면 끊긴다 — 거리를 좁혀 먼저 쳐라"},
			{"type": "manual", "x": 1755, "y": 170, "id": "f2_storage_manual"},
			{"type": "pickup", "x": 1260, "kind": "tonic", "id": "f2_tonic"},
			{"type": "checkpoint", "x": 2000, "id": "mid"},
			{"type": "sign", "x": 2040, "text": "격석 측정대: 달아오르는 판 위에 서지 마라 — 싸울 자리를 골라라"},
			{"type": "hazard", "x": 2180, "phase": 0.0}, {"type": "hazard", "x": 2350, "phase": 1.0}, {"type": "hazard", "x": 2520, "phase": 2.0},
			{"type": "pickup", "x": 2640, "kind": "record", "id": "f2_war_record", "text": "전쟁 기록: 「표본 7, 이송 4, 잔류 2 — 심문관 인수」"},
			{"type": "sign", "x": 2830, "text": "열린 수용실: 남은 제자는 둘. 나머지는 이송됐다"},
			{"type": "rest", "x": 2890},
			{"type": "checkpoint", "x": 2960, "id": "before_boss"},
			{"type": "rescue", "x": 3040, "id": "f2_a", "who": "disciple_m", "exit": -1.0},
			{"type": "rescue", "x": 3110, "id": "f2_b", "who": "disciple_f", "exit": -1.0},
			{"type": "door", "x": 3340, "to": "b2", "spawn": "start", "label": "관측실 — 미레유"},
		],
		"rooms": [
			{"id": "r1", "name": "반입장", "x0": 220, "x1": 760, "lock": true,
				"enemies": [{"type": "soldier", "x": 520}, {"type": "soldier", "x": 640, "combo": true}, {"type": "shield", "x": 710}],
				"lines": [["위지란", "금 간 집에 쇠붙이를 들여놨네. …표본? 그 말, 다시 해 봐."]]},
			{"id": "r2", "name": "관측 복도", "x0": 860, "x1": 1300,
				"enemies": [{"type": "mage", "x": 1180, "y": 236}]},
			{"id": "r3", "name": "표본 보관실", "x0": 1400, "x1": 1800,
				"enemies": [{"type": "shield", "x": 1560}, {"type": "mage", "x": 1760}]},
			{"id": "r4", "name": "격석 측정대", "x0": 2100, "x1": 2600, "lock": true,
				"enemies": [{"type": "soldier", "x": 2240}, {"type": "mage", "x": 2400}, {"type": "soldier", "x": 2500, "combo": true}]},
			{"id": "r5", "name": "열린 수용실", "x0": 2800, "x1": 3400,
				"lines": [["제자", "단주님…! 둘뿐입니다. 나머지는 흰 옷들이 데려갔어요."], ["위지란", "알아. 기록부터 찾고, 너희부터 보낸다."]]},
		],
		"camera": {"top": -120, "bottom": 400},
	}
