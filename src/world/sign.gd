extends "res://src/world/interactable.gd"
## Tutorial signpost: shows its text in a wrapped panel above the sign while the player stands near.
## Text "PC||touch" keeps a second wording for touch builds (key names differ there); "제목: 본문"
## puts the heading on its own accent line. Never takes the use key, so a neighbouring rest point or door gets it.

const WRAP := 240.0          # PC wrap width (UiText.M)
const WRAP_TOUCH := 300.0    # touch: bigger font, a little wider so panels stay 2–3 rows and below the title band
const PAD := 7.0
const HEAD_GAP := 3.0        # extra space under the accent heading row

var text := ""
var _s: Sprite2D
var _rows := PackedStringArray()   # wrapped once: the heading (if any), then the body lines
var _titled := false


func _ready() -> void:
	super()
	label = ""
	radius = 60.0
	_s = Anim.prop_sprite("sign")
	add_child(_s)


func available() -> bool:
	return false


func shows_ui() -> bool:
	return near and text != ""


func _draw_ui() -> void:
	if not shows_ui():
		return
	var fs := UiText.sz(UiText.M)
	if _rows.is_empty():
		var parts := text.split("||")
		var msg: String = parts[parts.size() - 1] if UiText.touch else parts[0]
		var colon := msg.find(": ")
		_titled = colon > 0 and colon <= 12
		if _titled:
			_rows.append(msg.left(colon))
			msg = msg.substr(colon + 2)
		_rows.append_array(wrap_words(msg, fs, WRAP_TOUCH if UiText.touch else WRAP))
	var w := 0.0
	for row in _rows:
		w = maxf(w, UiText.width(row, fs))
	var lh := UiText.font().get_height(fs)
	var gap := HEAD_GAP if _titled else 0.0
	var h := lh * _rows.size() + gap + PAD * 2.0
	w = ceilf(w) + PAD * 2.0
	var bottom := PROMPT_BOTTOM - 4.0
	for it in get_tree().get_nodes_in_group("interactable"):
		if it.shows_pill():   # a neighbour's key prompt sits at the usual height: stack above it
			bottom -= pill_height() + 4.0
			break
	var r := place(_ui, Rect2(-w * 0.5, bottom - h, w, h))
	_drawn = r   # once the player walks off, the fading panel goes at once if the screen edge reaches it
	UiText.panel(_ui, r, 0.86)
	var base := r.position + Vector2(PAD, PAD + UiText.font().get_ascent(fs))
	for i in _rows.size():
		var heading := _titled and i == 0
		UiText.draw(_ui, base + Vector2(0, lh * i + (gap if i > 0 else 0.0)), _rows[i], fs, UiText.ACCENT if heading else UiText.INK, 0)


## Wrap at spaces only: the font's line breaker splits Hangul words mid-syllable ("잔월 / 보").
## Separators (· — →) stay with the word before them, "(…)" never breaks, and a phrase (up to a separator
## or a sentence end) stays on one line when it fits, so "공중에서 W 허공답월" is never split. Lines are
## balanced: the narrowest width that keeps the greedy line count, so no word is left alone on the last
## line. A "·" left at a line end is dropped. A single word wider than `width` keeps its own line.
static func wrap_words(text: String, fs: int, width: float) -> PackedStringArray:
	var words := PackedStringArray()
	var paren := false
	for word in text.split(" ", false):
		if not words.is_empty() and (paren or word in ["·", "—", "→"]):
			words[words.size() - 1] += " " + word
		else:
			words.append(word)
		paren = (paren or word.contains("(")) and not word.contains(")")
	var units := PackedStringArray()
	var phrase := PackedStringArray()
	for i in words.size():
		phrase.append(words[i])
		if i == words.size() - 1 or words[i].ends_with(".") or words[i].right(1) in ["·", "—", "→"]:
			var joined := " ".join(phrase)
			if UiText.width(joined, fs) <= width:
				units.append(joined)
			else:
				units.append_array(phrase)
			phrase.clear()
	var lines := _greedy(units, fs, width)
	if lines.size() > 1:
		var lo := 0.0
		var hi := width
		for i in 10:
			var mid := (lo + hi) * 0.5
			if _greedy(units, fs, mid).size() <= lines.size():
				hi = mid
			else:
				lo = mid
		lines = _greedy(units, fs, ceilf(hi))
	for i in lines.size():
		if lines[i].ends_with(" ·"):
			lines[i] = lines[i].left(-2)
	return lines


static func _greedy(units: PackedStringArray, fs: int, width: float) -> PackedStringArray:
	var out := PackedStringArray()
	var cur := ""
	for u in units:
		var t: String = u if cur == "" else cur + " " + u
		if cur != "" and UiText.width(t, fs) > width:
			out.append(cur)
			cur = u
		else:
			cur = t
	out.append(cur)
	return out
