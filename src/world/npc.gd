extends Node2D
## Standing NPC from a 10차 sheet (disciple_m / disciple_f / renata): idle loop, talk/bow when the
## player is near. Non-interactive beyond that in the first slice.

var who := "disciple_m"
var face := -1.0
var sprite: ClipSprite
var _near := false


func _ready() -> void:
	sprite = ClipSprite.new()
	sprite.setup(Anim.sheets[who])
	sprite.set_facing(face)
	sprite.z_index = 1
	add_child(sprite)


func _process(delta: float) -> void:
	if Juice.frozen():
		return
	var p := get_tree().get_first_node_in_group("player")
	var near: bool = p != null and absf(p.global_position.x - global_position.x) < 70.0
	if near and not _near:
		sprite.play("talk" if sprite.sheet.clips.has("talk") else "bow", true)
	elif not near and _near:
		sprite.play("idle", true)
	if near and sprite.clip == "bow" and sprite._done:
		sprite.play("idle", true)
	_near = near
	if p:
		sprite.set_facing(1.0 if p.global_position.x > global_position.x else -1.0)
	sprite.tick(delta)
