extends SceneTree
## Renders the 1타 impact frame rotated 0/15/30/45° at 2x with NEAREST (top) and LINEAR (bottom) filtering.
func _initialize() -> void:
	await process_frame
	var tex: Texture2D = load("res://assets/v8/character.png")
	var vp := SubViewport.new()
	vp.size = Vector2i(4 * 200, 2 * 200)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color(0.18, 0.18, 0.22)
	bg.size = vp.size
	vp.add_child(bg)
	for row in 2:
		for i in 4:
			var s := Sprite2D.new()
			s.texture = tex
			s.hframes = 8
			s.vframes = int(tex.get_height() / 96)
			s.frame = 35  # attack1 impact
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if row == 0 else CanvasItem.TEXTURE_FILTER_LINEAR
			s.position = Vector2(i * 200 + 100, row * 200 + 100)
			s.scale = Vector2(2, 2)
			s.rotation_degrees = i * 15.0
			vp.add_child(s)
	for i in 4:
		await process_frame
	var img := vp.get_texture().get_image()
	img.save_png("res://shots/v8/rotation-test.png")
	print("saved rotation test")
	quit(0)
