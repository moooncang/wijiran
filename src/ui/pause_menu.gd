extends Control
## 일시정지 메뉴 (Esc / touch ≡): 계속하기 · 장법 메뉴 · 조작법 · 처음부터 다시(진행 초기화, 확인 단계).
## Pausing uses the same tree pause as the palm menu. Rows take keys (W/S·↑↓, J/Enter/Space) and
## clicks/taps. The reset wipes the save file and restarts at T0 with the first-entry card again.

const BACKDROP := Color(0.02, 0.01, 0.03, 0.96)
const ROW_SEL := Color(0.55, 0.14, 0.2, 0.6)
const ROW_H := 36.0
const ROWS := [["계속하기", "resume"], ["장법 메뉴", "palms"], ["조작법", "controls"], ["처음부터 다시", "reset"]]
const CONFIRM := [["아니요, 돌아가기", "back"], ["예, 모두 지우고 처음부터", "wipe"]]

var selected := 0
var page := "main"   # main | controls | confirm
var _open := false
var _row_rects: Array = []


func _ready() -> void:
	add_to_group("pause_menu")
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)


func is_open() -> bool:
	return _open


func open() -> void:
	if _blocked():
		return
	var palms := get_tree().get_first_node_in_group("palm_menu")
	if palms and palms.visible:
		palms.close()
	_open = true
	visible = true
	page = "main"
	selected = 0
	Game.set_paused(true)
	queue_redraw()


func close() -> void:
	_open = false
	visible = false
	Game.set_paused(false)


## Not over the travel fade, the death card or the first-entry card (same rule as the palm menu).
func _blocked() -> bool:
	if is_instance_valid(Game.player) and Game.player.dead:
		return true
	var s := get_tree().current_scene
	if s == null:
		return false
	for k in ["cutscene", "death_screen"]:
		var c = s.get(k)
		if c is CanvasItem and c.visible:
			return true
	var fade = s.get("_fade_t")
	return fade is float and fade >= 0.0


func _rows() -> Array:
	match page:
		"confirm":
			return CONFIRM
		"controls":
			return [["돌아가기", "back"]]
	return ROWS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		var palms := get_tree().get_first_node_in_group("palm_menu")
		if not _open and palms and palms.visible:   # Esc in the palm menu just closes it
			palms.close()
			get_viewport().set_input_as_handled()
			return
		if _open:
			if page == "main":
				close()
			else:
				page = "main"
				selected = 0
		else:
			open()
		get_viewport().set_input_as_handled()
		queue_redraw()
		return
	if not _open:
		return
	var n := _rows().size()
	if event.is_action_pressed("ui_down") or event.is_action_pressed("crouch"):
		selected = (selected + 1) % n
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("interact"):
		selected = (selected - 1 + n) % n
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("attack_key") or event.is_action_pressed("parry"):
		_activate(String(_rows()[selected][1]))
	elif event.is_action_pressed("ui_cancel"):
		if page == "main":
			close()
		else:
			page = "main"
			selected = 0
	else:
		return
	get_viewport().set_input_as_handled()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	var pressed := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pos = event.position
		pressed = true
	elif event is InputEventScreenTouch and event.pressed:
		pos = event.position
		pressed = true
	if not pressed:
		return
	for i in _row_rects.size():
		if (_row_rects[i] as Rect2).has_point(pos):
			selected = i
			_activate(String(_rows()[i][1]))
			accept_event()
			queue_redraw()
			return


func _activate(action: String) -> void:
	match action:
		"resume":
			close()
		"palms":
			close()
			var palms := get_tree().get_first_node_in_group("palm_menu")
			if palms:
				palms.open()
		"controls":
			page = "controls"
			selected = 0
		"reset":
			page = "confirm"
			selected = 0
		"back":
			page = "main"
			selected = 0
		"wipe":
			_wipe()


## 진행 초기화: the save file goes, flags and palms reset, and the game restarts at T0 (card included).
func _wipe() -> void:
	Game.wipe_save()
	Game.write_save()
	close()
	Game.notice.emit("진행을 지웠습니다. 처음부터 시작합니다.")
	Game.travel("t0", "start")


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), BACKDROP)
	var cx := vp.x * 0.5
	_row_rects.clear()
	match page:
		"controls":
			_draw_controls(cx)
		"confirm":
			UiText.centered(self, cx, 150, "정말 처음부터 다시 시작할까요?", UiText.sz(UiText.L), UiText.ACCENT, 0)
			UiText.centered(self, cx, 176, "저장된 진행(체크포인트·구출·비급·장법)이 모두 지워집니다.", UiText.sz(UiText.M), UiText.WARN, 0)
			_draw_rows(cx, 220)
		_:
			UiText.centered(self, cx, 110, "일시정지", UiText.sz(UiText.XL), UiText.ACCENT, 0)
			var lv := Game.level
			var where := String(lv.data.get("name", "")) if lv else ""
			UiText.centered(self, cx, 136, where, UiText.sz(UiText.S), UiText.DIM, 0)
			_draw_rows(cx, 170)
			var hint := "W/S 선택 · J/Enter 결정 · Esc 닫기" if not UiText.touch else "항목을 누르세요 · 계속하기로 돌아갑니다"
			UiText.centered(self, cx, vp.y - 24, hint, UiText.sz(UiText.XS), UiText.DIM, 0)


func _draw_rows(cx: float, top: float) -> void:
	var rows := _rows()
	var w := 300.0 if UiText.touch else 260.0
	for i in rows.size():
		var r := Rect2(cx - w * 0.5, top + i * (ROW_H + 6.0), w, ROW_H)
		_row_rects.append(r)
		if i == selected:
			draw_rect(r, ROW_SEL)
		draw_rect(r, UiText.PANEL_EDGE, false, 1.0)
		var danger: bool = String(rows[i][1]) in ["reset", "wipe"]
		UiText.centered(self, cx, r.position.y + ROW_H * 0.5 + 5.0, String(rows[i][0]), UiText.sz(UiText.M), UiText.WARN if danger else UiText.INK, 0)


func _draw_controls(cx: float) -> void:
	UiText.centered(self, cx, 60, "조작법", UiText.sz(UiText.L), UiText.ACCENT, 0)
	var lines: Array = []
	if UiText.touch:
		lines = [["왼쪽 스틱", "이동 · 조준 방향 · 아래로 앉기"], ["점프", "점프 · 공중에서 한 번 더 허공답월"], ["잔월보", "스틱 방향 대시 (공중 1회)"],
			["장법", "3연계 공격"], ["강화", "강화 초식 (내공 소모)"], ["월인", "조준 방향 적 당기기"], ["패링", "완전 0.10초 · 부분 0.25초"],
			["월식", "절초 (게이지 100)"], ["상호작용", "문 · 비급 · 휴식 · 구출"], ["복귀 (길게)", "마지막 등불로"]]
	else:
		lines = [["A / D", "이동"], ["W", "점프 · 공중에서 W 허공답월 · 문/비급 앞에서 상호작용"], ["Shift", "잔월보 — 마우스 방향 대시 (공중 1회)"],
			["좌클릭 / J", "장법 3연계"], ["E", "강화 초식 (내공 소모)"], ["우클릭 / F", "월인 — 조준 방향 적 당기기"], ["Space", "패링 (완전 0.10초 · 부분 0.25초)"],
			["Q", "월식 (게이지 100)"], ["S", "앉기"], ["Tab", "장법 메뉴"], ["R", "마지막 등불로 복귀"], ["Esc", "일시정지"]]
	var y := 92.0
	for l in lines:
		UiText.draw(self, Vector2(cx - 230, y), String(l[0]), UiText.sz(UiText.M), UiText.ACCENT, 0)
		UiText.draw(self, Vector2(cx - 110, y), String(l[1]), UiText.sz(UiText.M), UiText.INK, 0)
		y += 22
	_draw_rows(cx, y + 10)
