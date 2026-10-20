extends Node
## Autoload "Anim": v9 asset manifests (body clips with per-frame shoulder, arm/qi parts, effects_v9),
## the 56px soldier sheet, the v8 ultimate ring sheet and the HUD icons. Slot numbers live in data.

const ROOT := "res://assets/v9/"
const V8 := "res://assets/v8/"

var manifest: Dictionary = {}
var clips: Dictionary = {}
var parts: Dictionary = {}
var effects: Dictionary = {}
var cell := 64
var pivot := Vector2(32, 60)
var body_texture: Texture2D
var effect_texture: Texture2D
var _effect_sheets: Dictionary = {}  # file → Texture2D (clips may name their own sheet, e.g. 128px cells)
var effect_cell := 96
var part_textures: Dictionary = {}   # file → Texture2D
var enemy: Dictionary = {}           # {texture, cell, columns, pivot, clips}
var ultimate_texture: Texture2D      # v8 128px ring sheet (still the best ultimate burst)
var hud_texture: Texture2D
var hud_icons: Dictionary = {}
var font: Font
var boss: Dictionary = {}            # 128px 목각교두 sheet: {texture, cell, columns, pivot, clips}
var boss_parts: Dictionary = {}      # name → {sheet, cell, columns, first, pivot}
var boss_hud: Dictionary = {}        # manifest_boss_hud.json
var boss_hud_texture: Texture2D


func _ready() -> void:
	manifest = _load_json(ROOT + "manifest.json")
	clips = manifest.clips
	parts = manifest.parts
	effects = manifest.effect_clips
	cell = int(manifest.character.cell[0])
	pivot = Vector2(manifest.character.pivot[0], manifest.character.pivot[1])
	body_texture = load(ROOT + manifest.character.file)
	effect_texture = load(ROOT + manifest.effects.file)
	effect_cell = int(manifest.effects.cell[0])
	for name in parts:
		var f: String = parts[name].file
		if not part_textures.has(f):
			part_textures[f] = load(ROOT + f)
	enemy = load_sheet("manifest_enemy_soldier_56.json")
	ultimate_texture = load(V8 + "ultimate.png")
	var hud: Dictionary = _load_json(V8 + "manifest_hud.json")
	hud_texture = load(V8 + hud.file)
	hud_icons = hud.icons
	font = load("res://assets/fonts/NanumGothic-Regular.ttf")
	# boss (9차): body sheet + parts + its effect/mark clips merged into the effect table (each names its sheet)
	var bm: Dictionary = _load_json(ROOT + "manifest_boss.json")
	boss = load_sheet("manifest_boss.json")
	boss_parts = bm.parts
	for file in ["manifest_boss_fx.json", "manifest_boss_marks.json"]:
		var fxm: Dictionary = _load_json(ROOT + file)
		if fxm.has("effect_clips"):
			fxm = fxm.effect_clips
		for k in fxm:
			if fxm[k] is Dictionary and fxm[k].has("first"):
				effects[k] = fxm[k]
	boss_hud = _load_json(ROOT + "manifest_boss_hud.json")
	boss_hud_texture = load(ROOT + boss_hud.file)


## Sheet for an effect clip: the default effects file, or the clip's own "sheet" file.
func effect_sheet(file: String) -> Texture2D:
	if file == "":
		return effect_texture
	if not _effect_sheets.has(file):
		_effect_sheets[file] = load(ROOT + file)
	return _effect_sheets[file]


func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	assert(f != null, "missing " + path)
	var data = JSON.parse_string(f.get_as_text())
	assert(data is Dictionary, "bad json " + path)
	return data


func load_sheet(manifest_file: String) -> Dictionary:
	var m: Dictionary = _load_json(ROOT + manifest_file)
	return {
		"texture": load(ROOT + m.character.file),
		"cell": int(m.character.cell[0]),
		"columns": int(m.character.columns),
		"pivot": Vector2(m.character.pivot[0], m.character.pivot[1]),
		"clips": m.clips,
	}


func slot(clip: String, i: int) -> int:
	var c: Dictionary = clips[clip]
	return int(c.first) + clampi(i, 0, int(c.count) - 1)


func count(clip: String) -> int:
	return int(clips[clip].count)


## Shoulder of the (detached) front arm for a body frame, as an offset from the feet pivot.
func shoulder(clip: String, i: int, facing: float) -> Vector2:
	var c: Dictionary = clips[clip]
	var table: Dictionary = c.get("shoulder", {})
	var key := str(clampi(i, 0, int(c.count) - 1))
	var p: Vector2 = Vector2(table[key][0], table[key][1]) if table.has(key) else Vector2(29, 32)
	return cell_to_local(p, facing)


static func contact_in(table: Dictionary, clip: String, i: int) -> Variant:
	var c: Dictionary = table[clip]
	var contacts: Dictionary = c.get("contact", {})
	var key := str(i)
	if contacts.has(key):
		return Vector2(contacts[key][0], contacts[key][1])
	return null


## Cell coordinate → offset from the feet pivot in world units (facing applied).
func cell_to_local(p: Vector2, facing: float, piv: Vector2 = pivot) -> Vector2:
	return Vector2((p.x - piv.x) * facing, p.y - piv.y)


## Sprite2D for a part (arm_sleeve, hand_palm, qi_palm, ...): region of its sheet, pivot at origin.
func make_part(name: String) -> Sprite2D:
	var d: Dictionary = parts[name]
	var s := Sprite2D.new()
	s.texture = part_textures[d.file]
	var cw := int(d.cell[0])
	var cols := int(d.columns)
	var first := int(d.get("slot", d.get("first", 0)))
	s.region_enabled = true
	s.region_rect = Rect2((first % cols) * cw, (first / cols) * cw, cw, cw)
	s.centered = false
	s.offset = Vector2(-d.pivot[0], -d.pivot[1])
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return s


## Sprite for a boss overlay part (tablet, strokes, badge...): region of boss_parts.png, pivot at origin.
func boss_part(name: String) -> Sprite2D:
	var d: Dictionary = boss_parts[name]
	var s := Sprite2D.new()
	s.texture = effect_sheet(String(d.sheet))
	s.region_enabled = true
	s.centered = false
	s.offset = Vector2(-d.pivot[0], -d.pivot[1])
	boss_part_frame(s, name)
	return s


func boss_part_frame(s: Sprite2D, name: String) -> void:
	var d: Dictionary = boss_parts[name]
	var cw := int(d.cell[0])
	var cols := int(d.columns)
	var f := int(d.first)
	s.region_rect = Rect2((f % cols) * cw, (f / cols) * cw, cw, cw)


## Advance a looping part (qi) to frame i.
func part_frame(s: Sprite2D, name: String, i: int) -> void:
	var d: Dictionary = parts[name]
	var cw := int(d.cell[0])
	var cols := int(d.columns)
	var f := int(d.get("first", d.get("slot", 0))) + i % int(d.get("count", 1))
	s.region_rect = Rect2((f % cols) * cw, (f / cols) * cw, cw, cw)
