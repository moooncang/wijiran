class_name LevelB2
## B2 관측실 (본편 §7): a flat one-screen room with two low platforms and a floor that reads as three
## sections (the lanes 세 칸 봉쇄 and 태양 낙인 use). 미레유 spawns when the player passes the gate;
## beating her opens the way to 백향 이송로.

static func data() -> Dictionary:
	return {
		"id": "b2", "name": "관측실", "width": 800.0, "ground_y": 300.0, "backdrop": "lab", "map_key": "B2",
		"art": {"p0": "b2_platform", "p1": "b2_platform"},
		"decor": [["b2_instrument_0", 20, 300], ["b2_observation_ring_0", 300, 290], ["b2_instrument_1", 700, 300], ["b2_partition", 262, 300, false], ["b2_partition", 529, 300, false]],
		"spawns": {"start": Vector2(80, 300)},
		"platforms": [Rect2(80, 240, 140, 14), Rect2(580, 240, 140, 14)],
		"covers": [],
		"props": [
			{"type": "door", "x": 760, "to": "f3", "spawn": "start", "label": "백향 이송로", "requires": "b2_mireille_beaten"},
		],
		"rooms": [
			{"id": "arena", "x0": 140, "x1": 800, "lock": true, "cleared_by": "b2_mireille_beaten", "enemies": [{"type": "mireille", "x": 560}],
				"lines": [["미레유", "표본 3호가 걸어 들어오네. 가설대로야. …읽히지 않아. 왜 안 읽히지?"], ["위지란", "표본? 이름이 있어, 전부. 네 이름은 몰라도 되고."]]},
		],
		"camera": {"top": -50, "bottom": 400},
		"perches": [Vector2(150, 240), Vector2(650, 240)],
		"lanes": [[0.0, 266.0], [266.0, 533.0], [533.0, 800.0]],
	}
