extends Sprite2D
class_name ClipSprite
## Plays clips of a 10차 character sheet ({texture, cell, columns, pivot, clips}). Sheets face left;
## set `facing` (+1 mirrors). Supports loop, hold_last (stay on the last frame), and per-frame
## durations. Anchors (muzzle, arrow_tip, ...) come from the manifest for the frame being shown.

var sheet: Dictionary
var clip := ""
var index := 0
var facing := -1.0
var _t := 0.0
var _done := false


func setup(s: Dictionary) -> void:
	sheet = s
	texture = s.texture
	hframes = int(s.columns)
	vframes = int(texture.get_height() / int(s.cell))
	centered = false
	offset = -(s.pivot as Vector2)
	play("idle")


## Start a clip; `restart` false keeps playing if already on it.
func play(name: String, restart := false) -> void:
	if not sheet.clips.has(name):
		return
	if clip == name and not restart:
		return
	clip = name
	index = 0
	_t = 0.0
	_done = false
	_apply()


func playing(name: String) -> bool:
	return clip == name and not _done


func count() -> int:
	return int(sheet.clips[clip].count)


func _apply() -> void:
	var c: Dictionary = sheet.clips[clip]
	frame = int(c.first) + clampi(index, 0, int(c.count) - 1)
	flip_h = facing > 0.0


func tick(dt: float) -> void:
	if clip == "" or _done:
		return
	var c: Dictionary = sheet.clips[clip]
	var n := int(c.count)
	var durs: Array = c.get("frame_durations", [])
	var dur: float = float(durs[mini(index, durs.size() - 1)]) if not durs.is_empty() else 1.0 / float(c.get("fps", 8))
	_t += dt
	while _t >= dur and not _done:
		_t -= dur
		if index + 1 < n:
			index += 1
		elif bool(c.get("loop", false)):
			index = 0
		else:
			_done = true   # hold_last or simply finished: stay on the last frame
		durs = c.get("frame_durations", [])
		dur = float(durs[mini(index, durs.size() - 1)]) if not durs.is_empty() else 1.0 / float(c.get("fps", 8))
	_apply()


func set_facing(f: float) -> void:
	facing = f
	flip_h = facing > 0.0


## Feet-relative world offset of a named anchor on the current frame.
func anchor(key: String) -> Vector2:
	return Anim.anchor(sheet, clip, index, key, facing)
