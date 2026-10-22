extends Node
## Autoload "Game": progression state that outlives a level — save file, checkpoints and respawn,
## permanent flags vs. session flags, palm manuals and the equipped style, the pause gate.
## Rules from 본편-1막 §10 (저장·재도전) and 장법 기획 §3-4 (습득·장착).
##   - permanent: manuals, unlocked palms, equipped palm, world flags (boss beaten, rooms cleared before a checkpoint)
##   - session: rooms cleared since the last checkpoint (lost on death), current level/spawn until a checkpoint
##   - checkpoint snapshot: hp/qi/rift/gauge/ult cooldown restored on every retry (no charge farming by dying)

signal travel_requested(level_id: String, spawn_id: String)
signal palms_changed
signal flag_changed(name: String)
signal notice(text: String)

const SAVE_PATH := "user://wijiran_save.json"
const SAVE_VERSION := 1

var save: Dictionary = {}
var session_flags: Dictionary = {}
var paused := false
var at_rest_point := false
var level_id := ""
var player: Player
var level: Node
var save_enabled := true          # tests run with saving off
var wiping := false               # a progress reset is restarting the game: lanterns must not re-save until T0 is up


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_save()


# ---------- save file ----------

static func default_save() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"checkpoint": {"level": "t0", "spawn": "start"},
		"flags": {},
		"palms": {"unlocked": [PalmStyles.DEFAULT_ID], "equipped": PalmStyles.DEFAULT_ID, "manuals": []},
		"snapshot": {},
		"skip_intro_seen": [],
	}


func load_save() -> void:
	save = default_save()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		_merge(save, data)
	_validate_palms()


func write_save() -> void:
	if not save_enabled:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(save, "  "))


func wipe_save() -> void:
	save = default_save()
	session_flags.clear()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


static func _merge(base: Dictionary, src: Dictionary) -> void:
	for k in src:
		if base.has(k) and base[k] is Dictionary and src[k] is Dictionary:
			_merge(base[k], src[k])
		else:
			base[k] = src[k]


## 기획 §9: unknown ids never run; 흑월장 is always owned; an unowned equipped style falls back.
func _validate_palms() -> void:
	var p: Dictionary = save.palms
	var unlocked: Array = []
	for id in p.get("unlocked", []):
		if PalmStyles.STYLES.has(id) and not unlocked.has(id):
			unlocked.append(id)
	if not unlocked.has(PalmStyles.DEFAULT_ID):
		unlocked.push_front(PalmStyles.DEFAULT_ID)
	p.unlocked = unlocked
	if not unlocked.has(String(p.get("equipped", ""))):
		p.equipped = PalmStyles.DEFAULT_ID


# ---------- flags ----------

func flag(name: String) -> bool:
	return bool(save.flags.get(name, false)) or bool(session_flags.get(name, false))


## Permanent flags (boss beaten, rescued, manuals) write immediately; room clears stay in the session
## until the next checkpoint so death rewinds them (§10 사망 처리).
func set_flag(name: String, permanent: bool = true) -> void:
	if permanent:
		save.flags[name] = true
		write_save()
	else:
		session_flags[name] = true
	flag_changed.emit(name)


# ---------- palms ----------

func equipped_palm() -> String:
	return String(save.palms.equipped)


func unlocked_palms() -> Array:
	return save.palms.unlocked


func has_manual(manual_id: String) -> bool:
	return save.palms.manuals.has(manual_id)


## Picking up a manual: permanent, never auto-equips, one notice (기획 §3).
func collect_manual(manual_id: String) -> bool:
	if has_manual(manual_id) or not PalmStyles.MANUALS.has(manual_id):
		return false
	var style_id: String = PalmStyles.MANUALS[manual_id]
	save.palms.manuals.append(manual_id)
	if not save.palms.unlocked.has(style_id):
		save.palms.unlocked.append(style_id)
	write_save()
	palms_changed.emit()
	notice.emit("장법 「%s」을 발견했습니다. 다음 휴식 지점에서 장착할 수 있습니다." % PalmStyles.style(style_id).name)
	return true


func can_equip_now() -> bool:
	if not at_rest_point or player == null:
		return false
	return player.action() == Player.Action.FREE and not player.swinging() and player.is_on_floor() and not player.dead


## 기획 §4: one slot; only at a rest point while neutral; resets only the combo state; saved at once.
func equip_palm(id: String) -> bool:
	if not save.palms.unlocked.has(id) or not can_equip_now():
		return false
	if id == equipped_palm():
		return true
	save.palms.equipped = id
	write_save()
	player.on_palm_changed()
	if id == "bone_piercing" and not flag("bp_revealed"):
		set_flag("bp_revealed")
		player.reveal_palm()   # 투골장 · 극의: the manual opens under the great moon, once (개편안 §8)
	palms_changed.emit()
	notice.emit("「%s」 장착" % PalmStyles.style(id).name)
	return true


# ---------- checkpoints & travel ----------

## Reached a checkpoint: commit session clears, snapshot combat resources once (first arrival only).
func reach_checkpoint(cp_level: String, spawn_id: String) -> void:
	for k in session_flags:
		save.flags[k] = true
	session_flags.clear()
	var key := "%s/%s" % [cp_level, spawn_id]
	var is_new: bool = save.checkpoint.level != cp_level or save.checkpoint.spawn != spawn_id
	save.checkpoint = {"level": cp_level, "spawn": spawn_id}
	if is_new or save.snapshot.is_empty() or save.snapshot.get("key", "") != key:
		save.snapshot = {"key": key, "hp": CombatConfig.PLAYER_MAX_HP, "qi": player.qi if player else CombatConfig.QI_MAX, "rift": player.rift if player else 0.0, "gauge": player.gauge if player else 0.0, "ult_cooldown": player.ult_cooldown if player else 0.0}
	write_save()


func restore_snapshot(p: Player) -> void:
	var s: Dictionary = save.snapshot
	p.hp = int(s.get("hp", CombatConfig.PLAYER_MAX_HP))
	p.qi = float(s.get("qi", CombatConfig.QI_MAX))
	p.rift = float(s.get("rift", 0.0))
	p.gauge = float(s.get("gauge", 0.0))
	p.ult_cooldown = float(s.get("ult_cooldown", 0.0))


func travel(target_level: String, spawn_id: String) -> void:
	travel_requested.emit(target_level, spawn_id)


## Death: back to the last checkpoint with its snapshot; session room clears are dropped.
func respawn() -> void:
	session_flags.clear()
	travel_requested.emit(String(save.checkpoint.level), String(save.checkpoint.spawn))


func set_paused(v: bool) -> void:
	paused = v
	get_tree().paused = v
