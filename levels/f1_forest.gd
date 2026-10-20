class_name LevelF1
## F1 불탄 수림길 (본편 §5): five sections teaching a melee fighter to reach archers. Two of the four
## fights lock the room (전멸전 최대 2구역). The 쇄진장 manual sits on a side path that needs the air
## jump + air dash (장법 기획 §5 획득 제안). Covers are indestructible blocks.

static func data() -> Dictionary:
	return {
		"id": "f1", "name": "불탄 수림길", "width": 3400.0, "ground_y": 300.0, "backdrop": "forest", "map_key": "F1",
		"art": {"p0": "f1_log_a", "p1": "f1_root_a", "p2": "f1_root_b", "p3": "f1_log_b", "p4": "f1_roof_a", "p5": "f1_roof_b", "p6": "f1_roof_c", "v0": "f1_cover_a", "v1": "f1_cover_b"},
		"decor": [["f1_tree_0", 120, 300], ["f1_tree_2", 640, 300], ["f1_vine_1", 900, 300], ["f1_tree_1", 1240, 300], ["f1_outpost", 1560, 300], ["f1_tree_3", 2000, 300], ["f1_vine_0", 2300, 300], ["f1_tree_4", 2620, 300], ["f1_tree_5", 3200, 300], ["f1_vine_2", 2880, 300]],
		"spawns": {"start": Vector2(80, 300), "from_b1": Vector2(3300, 300)},
		"platforms": [
			Rect2(1056, 236, 128, 20),                       # 2. the fallen trunk the scout stands on (log art 128×20)
			Rect2(1860, 210, 100, 16), Rect2(2060, 160, 100, 16),  # 4. root gate: two heights
			Rect2(2340, 230, 128, 20),
			# side path to the manual: up and across (air jump + air dash) — outpost roofs 70×12
			Rect2(1320, 180, 70, 12), Rect2(1470, 110, 70, 12), Rect2(1660, 70, 70, 12),
		],
		"covers": [Rect2(1500, 260, 40, 40), Rect2(2180, 260, 40, 40)],
		"props": [
			{"type": "checkpoint", "x": 60, "id": "entry"},
			{"type": "manual", "x": 1695, "y": 70, "id": "f1_outpost_manual"},
			{"type": "mark", "x": 3100, "clip": "disciple_mark"},
			{"type": "sign", "x": 1300, "text": "무너진 동방 초소: 위로 가는 길 끝에 무언가 보인다"},
			{"type": "checkpoint", "x": 2560, "id": "mid"},
			{"type": "rest", "x": 3050}, {"type": "dummy", "x": 3140},
			{"type": "checkpoint", "x": 2980, "id": "before_boss"},
			{"type": "door", "x": 3340, "to": "b1", "spawn": "start", "label": "반쪽 성목의 공터 — 티아넬"},
		],
		"rooms": [
			{"id": "r1", "name": "버려진 감시길", "x0": 220, "x1": 760, "lock": true,
				"enemies": [{"type": "soldier", "x": 560}, {"type": "soldier", "x": 700, "combo": true}],
				"lines": [["위지란", "탄 냄새. …여기, 내가 태웠지."]]},
			{"id": "r2", "name": "쓰러진 나무", "x0": 860, "x1": 1260,
				"enemies": [{"type": "archer", "x": 1120, "y": 236}]},
			{"id": "r3", "name": "갈라진 둔덕", "x0": 1400, "x1": 1800, "lock": true,
				"enemies": [{"type": "soldier", "x": 1600}, {"type": "soldier", "x": 1680, "combo": true}, {"type": "archer", "x": 1760}]},
			{"id": "r4", "name": "뿌리의 문", "x0": 1820, "x1": 2460,
				"enemies": [{"type": "archer", "x": 1910, "y": 210}, {"type": "archer", "x": 2110, "y": 160}]},
			{"id": "r5", "name": "성목 앞 쉼터", "x0": 2900, "x1": 3400,
				"lines": [["위지란", "…매듭 끈 조각. 여기까진 끌려왔어."]]},
		],
		"camera": {"top": -120, "bottom": 400},
	}
