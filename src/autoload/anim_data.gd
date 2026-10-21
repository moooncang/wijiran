extends Node
## Autoload "Anim": v9 asset manifests (body clips with per-frame shoulder, arm/qi parts, effects_v9),
## the 56px soldier sheet, the v8 ultimate ring sheet and the HUD icons. Slot numbers live in data.

const ROOT := "res://assets/v9/"
const V8 := "res://assets/v8/"
const R10 := "res://assets/r10/"
const R11 := "res://assets/r11/"
const ROOTS := [R11, ROOT, R10]      # manifests name files relative to one of these (newest first: r11 replaces fx_pull)

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
# 10차 (본편 1구간)
var sheets: Dictionary = {}          # name → {texture, cell, columns, pivot, clips}: scout, scout_human, tianel, disciple_m/f, renata
var props: Dictionary = {}           # manifest_props.json clips
var props_r11: Dictionary = {}       # manifest_props_r11.json clips (own sheet + a top layer sheet for tall props)
var props_r11_texture: Texture2D
var props_r11_top: Texture2D
var props_texture: Texture2D
var ui: Dictionary = {}              # key → {file, rect, nine_slice}
var bg: Dictionary = {}              # manifest_bg.json maps
var terrain: Dictionary = {}         # manifest_terrain.json assets
var cutscenes: Dictionary = {}
var _tex_cache: Dictionary = {}


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
	enemy = load_sheet("manifest_soldier.json")   # 11차 96px 검병 (same clips/impacts as the 56px demo sheet)
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
	# 10차: effect clips (each names its sheet/cell), character sheets, props, ui, backgrounds, terrain
	for file in ["manifest_tianel_fx.json", "manifest_arrow.json", "manifest_pull.json", "manifest_palms.json", "manifest_mireille_fx.json", "manifest_elodie_fx.json", "manifest_minion_fx.json", "manifest_player_add.json"]:
		var fxm: Dictionary = _load_json(_find(file))   # r11 first: its manifest_pull.json (thread v2 + pull_mark) replaces the 10차 one
		if fxm.has("effect_clips"):
			fxm = fxm.effect_clips
		for k in fxm:
			if fxm[k] is Dictionary and fxm[k].has("first"):
				effects[k] = fxm[k]
	if effects.has("ash_arrow"):
		effects["ash_arrow"].orientation = "fixed"   # drawn falling (vertical) in the sheet; hit_direction turned it on its side
	for name in ["scout", "scout_human", "tianel", "disciple_m", "disciple_f", "renata", "mireille", "elodie", "shield", "mage", "incense"]:
		sheets[name] = load_sheet("manifest_%s.json" % name)
	var pm: Dictionary = _load_json(R10 + "manifest_props.json")
	props = pm.clips
	props_texture = load(R10 + pm.props.file)
	var pm11: Dictionary = _load_json(R11 + "manifest_props_r11.json")
	props_r11 = pm11.clips
	props_r11_texture = load(R11 + pm11.props.file)
	props_r11_top = load(R11 + "props_r11_top.png")
	ui = _load_json(R10 + "manifest_ui.json").assets
	ui.merge(_load_json(R11 + "manifest_ui_r11.json").assets)
	bg = _load_json(R11 + "manifest_bg.json").maps   # 11차 lists all eight maps (the r10 ones via reuse/ paths: tex() falls back to the file name)
	terrain = _load_json(R10 + "manifest_terrain.json").assets
	terrain.merge(_load_json(R11 + "manifest_terrain_r11.json").assets)
	cutscenes = _load_json(R10 + "manifest_cutscenes.json").assets
	cutscenes.merge(_load_json(R11 + "manifest_cutscenes_r11.json").assets)


## Sheet for an effect clip: the default effects file, or the clip's own "sheet" file.
func effect_sheet(file: String) -> Texture2D:
	if file == "":
		return effect_texture
	if not _effect_sheets.has(file):
		_effect_sheets[file] = tex(file)
	return _effect_sheets[file]


## A texture by manifest-relative file name, searched in every asset root (cached).
func tex(file: String) -> Texture2D:
	if _tex_cache.has(file):
		return _tex_cache[file]
	for r in ROOTS:
		for sub in ["", "terrain/", "ui/"]:
			if ResourceLoader.exists(r + sub + file):
				_tex_cache[file] = load(r + sub + file)
				return _tex_cache[file]
	if file.get_file() != file:   # manifests may name a path (terrain/x.png, reuse/r10/x.png): the file name alone is unique
		return tex(file.get_file())
	push_error("Anim: missing texture " + file)
	return null


func _find(file: String) -> String:
	for r in ROOTS:
		if FileAccess.file_exists(r + file):
			return r + file
	return ROOT + file


## UI piece as an AtlasTexture (portraits, icons, panels).
func ui_tex(key: String) -> Texture2D:
	var d: Dictionary = ui[key]
	var r: Array = d.rect
	var at := AtlasTexture.new()
	at.atlas = tex(String(d.file))
	at.region = Rect2(r[0], r[1], r[2], r[3])
	return at


## Sprite2D playing one prop clip (checkpoint, door, manual, dummy, ...); pivot (32,60) at the origin.
## 11차 props live on their own sheet; tall ones carry a second "top" layer drawn 48 px higher.
func prop_sprite(clip: String) -> Sprite2D:
	var s := Sprite2D.new()
	var r11 := props_r11.has(clip) and not props.has(clip)
	s.texture = props_r11_texture if r11 else props_texture
	s.hframes = 8
	s.vframes = int(s.texture.get_height() / 64)
	s.centered = false
	s.offset = Vector2(-32, -60)
	if r11 and props_r11[clip].has("layers"):
		var t := Sprite2D.new()
		t.texture = props_r11_top
		t.hframes = 8
		t.vframes = int(props_r11_top.get_height() / 64)
		t.centered = false
		t.offset = Vector2(-32, -60 - 48)
		s.add_child(t)
		s.set_meta("top", t)
	prop_frame(s, clip, 0)
	return s


func prop_frame(s: Sprite2D, clip: String, i: int) -> void:
	var c: Dictionary = props[clip] if props.has(clip) else props_r11[clip]
	s.frame = int(c.first) + (i % int(c.count))
	if s.has_meta("top"):
		(s.get_meta("top") as Sprite2D).frame = s.frame


## Per-frame anchor (bow_tip, muzzle, arrow_tip, hand_ground) of a 10차 sheet, as a feet-relative offset.
## Sheets face left; facing -1 draws as-is, +1 mirrors.
func anchor(sheet: Dictionary, clip: String, i: int, key: String, facing: float) -> Vector2:
	var c: Dictionary = sheet.clips[clip]
	var table: Dictionary = c.get(key, {})
	var k := str(clampi(i, 0, int(c.count) - 1))
	if not table.has(k):
		return Vector2(facing * 12.0, -40.0)
	var p := Vector2(table[k][0], table[k][1])
	return cell_to_local(p, -facing, sheet.pivot)


func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	assert(f != null, "missing " + path)
	var data = JSON.parse_string(f.get_as_text())
	assert(data is Dictionary, "bad json " + path)
	return data


func load_sheet(manifest_file: String) -> Dictionary:
	var m: Dictionary = _load_json(_find(manifest_file))
	return {
		"texture": tex(String(m.character.file)),
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
