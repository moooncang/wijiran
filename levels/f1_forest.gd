class_name LevelF1
## F1 불탄 수림길 (본편 §5): five sections teaching a melee fighter to reach archers. Two of the four
## fights lock the room (전멸전 최대 2구역). The 쇄진장 manual sits on a side path that needs the air
## jump + air dash (장법 기획 §5 획득 제안). Covers are indestructible blocks.

static func data() -> Dictionary:
	return {
		"id": "f1", "name": "불탄 수림길", "width": 3400.0, "ground_y": 300.0, "backdrop": "forest",
		"spawns": {"start": Vector2(80, 300), "from_b1": Vector2(3300, 300)},
		"platforms": [
			Rect2(1060, 236, 120, 14),                       # 2. the fallen trunk the scout stands on
			Rect2(1860, 210, 100, 14), Rect2(2060, 160, 100, 14),  # 4. root gate: two heights
			Rect2(2360, 230, 90, 14),
			# side path to the manual: up and across (air jump + air dash)
			Rect2(1320, 180, 70, 12), Rect2(1470, 110, 70, 12), Rect2(1660, 70, 120, 12),
		],
		"covers": [Rect2(1500, 260, 40, 40), Rect2(2180, 262, 36, 38)],
		"props": [
			{"type": "checkpoint", "x": 60, "id": "entry"},
			{"type": "manual", "x": 1720, "y": 70, "id": "f1_outpost_manual"},
			{"type": "sign", "x": 1300, "text": "무너진 동방 초소: 위로 가는 길 끝에 무언가 보인다"},
			{"type": "checkpoint", "x": 2560, "id": "mid"},
			{"type": "rest", "x": 3050}, {"type": "dummy", "x": 3140},
			{"type": "checkpoint", "x": 2980, "id": "before_boss"},
			{"type": "door", "x": 3340, "to": "b1", "spawn": "start", "label": "반쪽 성목의 공터"},
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
				"lines": [["위지란", "…매듭 끈 조각. 여기까진 끌려왔어."], ["제자", "(떨어진 표식)"]]},
		],
		"camera": {"top": -120, "bottom": 400},
	}
