class_name LevelH0
## H0 쌍등객잔 (본편 §6): non-combat hub placeholder for the first slice — rest, palm menu, the next
## route is not built yet. Weapons are left at the door: attacks are disabled by the level flag.

static func data() -> Dictionary:
	return {
		"id": "h0", "name": "쌍등객잔", "width": 900.0, "ground_y": 300.0, "backdrop": "inn", "no_combat": true,
		"spawns": {"start": Vector2(80, 300)},
		"platforms": [],
		"props": [
			{"type": "checkpoint", "x": 160, "id": "inn"},
			{"type": "rest", "x": 420},
			{"type": "sign", "x": 600, "text": "레나타: 「연구소에 아직 옮겨지지 않은 포로가 있어. …무기는 문밖에.」"},
			{"type": "door", "x": 840, "to": "f2", "spawn": "start", "label": "단층 임시 연구소 (제작 중)", "requires": "never"},
		],
		"rooms": [{"id": "hall", "x0": 0, "x1": 900, "lines": [["레나타", "어서 와. 등불 두 개 켜진 집은 여기뿐이야."], ["위지란", "정보 사러 왔어. 만두 값은 쳐줄게."]]}],
		"camera": {"top": -60, "bottom": 400},
	}
