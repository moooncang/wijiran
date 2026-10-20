extends Node2D
## Standing NPC from a 10차 sheet (disciple_m / disciple_f / renata): idle loop, talk/bow and a name tag
## over the head when the player is near. Someone with a line in LINES says it once per visit, in the
## dialogue box, the first time the player walks up. Non-interactive beyond that in the first slice.

const NAMES := {"renata": "레나타", "disciple_m": "제자", "disciple_f": "제자"}
# who → [line, flag that makes it stale ("" = never)]
const LINES := {"renata": ["연구소에 아직 옮겨지지 않은 포로가 있어. …무기는 문밖에.", "b3_elodie_beaten"]}
const TAG_BASELINE := -54.0   # just above the 48 px standing height
const REACH := 70.0

var who := "disciple_m"
var face := -1.0
var sprite: ClipSprite
var _near := false
var _said := false
var _tag: Node2D
var _tag_rect := Rect2()   # where the tag was last drawn (local)


func _ready() -> void:
	sprite = ClipSprite.new()
	sprite.setup(Anim.sheets[who])
	sprite.set_facing(face)
	sprite.z_index = 1
	add_child(sprite)
	_tag = Node2D.new()
	_tag.z_as_relative = false
	_tag.z_index = Interactable.UI_Z
	_tag.modulate.a = 0.0
	_tag.draw.connect(_draw_tag)
	add_child(_tag)


func _process(delta: float) -> void:
	# Show the tag at once, fade it out (the last drawing stays while it fades); hand over to a sign or prompt.
	var show: bool = _near and NAMES.has(who) and not Interactable.cutscene_up(get_tree())
	if show:
		for it in get_tree().get_nodes_in_group("interactable"):
			if it.shows_ui():   # a sign or prompt is up nearby: one block of text over the heads, not two
				show = false
				break
	_tag.modulate.a = 1.0 if show else move_toward(_tag.modulate.a, 0.0, delta / Interactable.FADE)
	if not show and not Interactable.on_screen(_tag, _tag_rect):   # never a tag cut by the screen edge
		_tag.modulate.a = 0.0
	if show:
		_tag.queue_redraw()
	if Juice.frozen():
		return
	var p := get_tree().get_first_node_in_group("player")
	var reach := REACH + (Interactable.NEAR_SLACK if _near else 0.0)
	var near: bool = p != null and not p.dead and absf(p.global_position.x - global_position.x) < reach
	if near and not _near:
		sprite.play("talk" if sprite.sheet.clips.has("talk") else "bow", true)
		_say()
	elif not near and _near:
		sprite.play("idle", true)
	if near and sprite.clip == "bow" and sprite._done:
		sprite.play("idle", true)
	_near = near
	if p:
		sprite.set_facing(1.0 if p.global_position.x > global_position.x else -1.0)
	sprite.tick(delta)


func _say() -> void:
	var line: Array = LINES.get(who, [])
	if _said or line.is_empty() or (line[1] != "" and Game.flag(line[1])):
		return
	_said = true
	Dialogue.say(NAMES[who], line[0], 0.0, "", false)   # waits for the room-entry exchange, never cuts it


func _draw_tag() -> void:
	var tag: String = NAMES.get(who, "")
	if tag == "":
		return
	var fs := UiText.sz(UiText.S)
	var f := UiText.font()
	var w := UiText.width(tag, fs)
	var r := Interactable.place(_tag, Rect2(-w * 0.5, TAG_BASELINE - f.get_ascent(fs), w, f.get_height(fs)))
	_tag_rect = r
	UiText.draw(_tag, Vector2(r.position.x, r.position.y + f.get_ascent(fs)), tag, fs, UiText.ACCENT)
