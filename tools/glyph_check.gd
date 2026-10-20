extends SceneTree
## Prints which non-Hangul characters used in the game's strings are missing from NanumGothic.
func _init() -> void:
	var f: Font = load("res://assets/fonts/NanumGothic-Regular.ttf")
	var s := FileAccess.get_file_as_string("res://tools/glyphs.txt")
	var missing := ""
	for i in s.length():
		if not f.has_char(s.unicode_at(i)):
			missing += s[i] + "(U+%04X) " % s.unicode_at(i)
	print("MISSING: ", missing)
	quit()
