class_name LevelH0
## H0 쌍등객잔 (본편 §6): non-combat hub placeholder for the first slice — rest, palm menu, the next
## route is not built yet. Weapons are left at the door: attacks are disabled by the level flag.

static func data() -> Dictionary:
	return {
		"id": "h0", "name": "쌍등객잔", "width": 900.0, "ground_y": 300.0, "backdrop": "inn", "no_combat": true, "map_key": "H0", "cutscene": "route", "cutscene_after": [["b3_elodie_beaten", "b3"], ["b3_elodie_beaten", "return"]],
		"decor": [["h0_lantern_blue_0", 300, 220, false], ["h0_lantern_red_0", 560, 220, false], ["h0_dumplings", 470, 262, false]],
		"spawns": {"start": Vector2(80, 300)},
		"platforms": [],
		"props": [
			{"type": "checkpoint", "x": 160, "id": "inn"},
			{"type": "rest", "x": 420},
			{"type": "npc", "x": 640, "who": "renata", "face": -1.0},
			{"type": "door", "x": 840, "to": "f2", "spawn": "start", "label": "단층 임시 연구소"},
		],
		"rooms": [{"id": "hall", "x0": 0, "x1": 900, "lines": [["레나타", "어서 와. 등불 두 개 켜진 집은 여기뿐이야."], ["위지란", "정보 사러 왔어. 만두 값은 쳐줄게."]],
			"lines_flag": "b3_elodie_beaten", "lines_after": [["구출된 제자", "단주님… 끈을 봐도 될까요."], ["위지란", "…봐. 이번엔 매듭이 늘지 않았어."], ["레나타", "만두 값은 외상이야. 살아 돌아왔으니까."]]}],
		"camera": {"top": -60, "bottom": 400},
	}
