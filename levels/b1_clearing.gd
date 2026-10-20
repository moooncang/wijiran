class_name LevelB1
## B1 반쪽 성목의 공터 (본편 §5): one-screen arena, wide centre, two low ledges (perches) and two cover
## stumps. Tianel spawns when the player passes the gate; beating her opens the exit door.

static func data() -> Dictionary:
	return {
		"id": "b1", "name": "반쪽 성목의 공터", "width": 800.0, "ground_y": 300.0, "backdrop": "clearing", "map_key": "B1",
		"art": {"p0": "b1_perch_left", "p1": "b1_perch_right", "v0": "b1_cover_a", "v1": "b1_cover_b"},
		"decor": [["b1_wall_left", 0, 300], ["b1_wall_right", 736, 300]],
		"spawns": {"start": Vector2(90, 300)},
		"platforms": [Rect2(60, 230, 110, 14), Rect2(630, 230, 110, 14)],
		"covers": [Rect2(250, 262, 34, 38), Rect2(430, 262, 34, 38)],
		"props": [
			{"type": "door", "x": 760, "to": "h0", "spawn": "start", "label": "숲길 통과 — 쌍등객잔", "requires": "b1_tianel_beaten"},
		],
		"rooms": [
			{"id": "arena", "x0": 150, "x1": 800, "lock": true, "enemies": [{"type": "tianel", "x": 560}],
				"lines": [["티아넬", "물러가라, 인간. 잿더미를 밟는 발소리는 멀리서도 들린다."], ["위지란", "길을 비켜. 네 숲은 안 태워. 오늘은."]]},
		],
		"camera": {"top": -50, "bottom": 400},
		"perches": [Vector2(115, 230), Vector2(685, 230)],
	}
