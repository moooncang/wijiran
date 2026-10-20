class_name LevelB3
## B3 향당 (본편 §8): a small symmetric shrine, flat floor in three sections, no pillars. 엘로디 spawns at
## the gate; once she is down the bound disciple can be freed and the way back to 쌍등객잔 opens.

static func data() -> Dictionary:
	return {
		"id": "b3", "name": "향당", "width": 800.0, "ground_y": 300.0, "backdrop": "shrine",
		"spawns": {"start": Vector2(80, 300)},
		"platforms": [],
		"covers": [],
		"props": [
			{"type": "rescue", "x": 640, "id": "b3_c", "who": "disciple_f", "exit": -1.0},
			{"type": "door", "x": 750, "to": "h0", "spawn": "start", "label": "쌍등객잔", "requires": "b3_elodie_beaten"},
		],
		"rooms": [
			{"id": "arena", "x0": 140, "x1": 800, "lock": true, "enemies": [{"type": "elodie", "x": 560}],
				"lines": [["엘로디", "이교도. 향이 타는 동안만 묻겠습니다. 그 붉은 끈은 무엇입니까."], ["위지란", "죽은 애들 이름. 하나 더 늘리러 온 건 아니야. 비켜."]]},
		],
		"camera": {"top": -50, "bottom": 400},
		"lanes": [[0.0, 266.0], [266.0, 533.0], [533.0, 800.0]],
	}
