class_name UiText
## Shared text rules for every screen (2026-10-21 가독성 정리). The canvas is 800×450 stretched
## (canvas_items) to the window, so a 10px glyph is ~16px at 1280×720 and ~9px on a small phone:
## nothing goes below XS. Everything drawn over the world gets a dark outline so it reads on any
## background. Use these helpers instead of raw draw_string so sizes and outlines stay consistent.

const XS := 10          # floor for any text (world labels, small HUD numbers)
const S := 11           # HUD lines, prompts, overhead labels
const M := 13           # dialogue body, menu body
const L := 15           # speaker names, menu headings
const XL := 20          # map titles
const INK := Color(0.97, 0.94, 0.9)
const DIM := Color(0.72, 0.68, 0.7)
const ACCENT := Color(1.0, 0.82, 0.6)
const WARN := Color(1.0, 0.72, 0.55)
const OUTLINE := Color(0.04, 0.02, 0.05, 0.95)
const PANEL := Color(0.06, 0.04, 0.07, 0.78)
const PANEL_EDGE := Color(0.78, 0.58, 0.42, 0.7)

static var touch := false   # set by main on touch builds: a phone shows the 800×450 canvas physically smaller


## Size for the current device: +2 on touch builds. Wrap every size you pass with this.
static func sz(size: int) -> int:
	return size + 2 if touch else size


static func font() -> Font:
	return Anim.font


static func width(text: String, size: int) -> float:
	return Anim.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## One line at a baseline position. `outline` 0 = none (only on solid panels).
static func draw(ci: CanvasItem, pos: Vector2, text: String, size: int = S, color: Color = INK, outline: int = 3, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, w: float = -1.0) -> void:
	if outline > 0:
		ci.draw_string_outline(Anim.font, pos, text, align, w, size, outline, OUTLINE)
	ci.draw_string(Anim.font, pos, text, align, w, size, color)


## One line centred on x (baseline y).
static func centered(ci: CanvasItem, centre_x: float, baseline_y: float, text: String, size: int = S, color: Color = INK, outline: int = 3) -> void:
	var w := width(text, size)
	draw(ci, Vector2(roundf(centre_x - w * 0.5), baseline_y), text, size, color, outline)


## Word-wrapped block inside `rect` (top-left = rect.position, first baseline = top + ascent).
## Returns the height used. Lines past the rect are cut, so callers size the rect from measure().
static func wrapped(ci: CanvasItem, rect: Rect2, text: String, size: int = M, color: Color = INK, outline: int = 0, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> float:
	var f := Anim.font
	var max_lines := maxi(1, int(rect.size.y / f.get_height(size)))
	var top := rect.position + Vector2(0, f.get_ascent(size))
	if outline > 0:
		ci.draw_multiline_string_outline(f, top, text, align, rect.size.x, size, max_lines, outline, OUTLINE)
	ci.draw_multiline_string(f, top, text, align, rect.size.x, size, max_lines, color)
	return minf(rect.size.y, measure(text, size, rect.size.x).y)


## Size of a wrapped block at `wrap_width`.
static func measure(text: String, size: int, wrap_width: float) -> Vector2:
	return Anim.font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, wrap_width, size)


## Translucent dark panel with a thin warm edge: the backing for any text block over the world.
static func panel(ci: CanvasItem, rect: Rect2, alpha: float = 0.78) -> void:
	ci.draw_rect(rect, Color(PANEL.r, PANEL.g, PANEL.b, alpha))
	ci.draw_rect(rect, PANEL_EDGE, false, 1.0)


## Same outline/size rules for Label nodes.
static func style_label(l: Label, size: int, color: Color = INK, outline: int = 4) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", outline)
