extends CanvasLayer

# The Map Editor's panels, all in the pixel kit: the top bar (Exit, Save, Undo...), the right panel with its tabs (Room, Floor, Decor, Props,
# Doors, World) and the inspector under them, the little map of the 11 x 11 world, the help sheet, the status line, pop-up choosers and
# the "leave without saving?" box. The inspector is simply rebuilt from the editor's state whenever that changes (once per frame at most),
# keeping the keyboard on the same number field if you were typing in one.

const WidgetsScript := preload("res://scripts/MapEditorWidgets.gd")
const ShapesScript := preload("res://scripts/MapEditorShapes.gd")
const OverlayScript := preload("res://scripts/MapEditorOverlay.gd")
const WorldMapScript := preload("res://scripts/WorldMap.gd")
const RoomsScript := preload("res://scripts/Rooms.gd")
const MapDataScript := preload("res://scripts/MapData.gd")
const MapEditorScript := preload("res://scripts/MapEditor.gd")

const PANEL_W := 436.0
const TOP_H := 56.0
const STATUS_H := 32.0
const BODY_W := PANEL_W - 60.0          # the room inside the panel for the inspector's rows
const MINIMAP_CELL := 16

var ed
var overlay
var minimap
var _root: Control
var _top: PanelContainer
var _top_row: HBoxContainer
var _panel: PanelContainer
var _tab_row: HFlowContainer
var _scroll: ScrollContainer
var _body: VBoxContainer
var _status_hint: Label
var _status_cursor: Label
var _toast_box: PanelContainer
var _toast_label: Label
var _toast_age := 0.0
var _help: Control
var _popup_layer: Control
var _confirm: Control
var _minimap_frame: PanelContainer
var _title_label: Label
var _unsaved_chip: Control
var _snap_button: PixelButton
var _grid_button: PixelButton
var _save_button: PixelButton
var _undo_button: PixelButton
var _redo_button: PixelButton
var _tab_buttons := {}
var _refresh_queued := false
var _next_uid := 0
var _cursor_world := Vector2.ZERO
var panel_shown := true

func setup(editor) -> void:
	ed = editor
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	overlay = OverlayScript.new()
	overlay.ed = ed
	_root.add_child(overlay)
	_build_minimap()
	_build_top()
	_build_panel()
	_build_status()
	_build_toast()
	_build_help()
	_popup_layer = Control.new()
	_popup_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_popup_layer)
	refresh_top()
	_rebuild_body()
	if not ed.load_report.is_empty():
		toast("%d problem%s in the map data files -- see Room tab" % [ed.load_report.size(), "" if ed.load_report.size() == 1 else "s"], true)
	else:
		toast("Click a room to pick it. Press F1 for help.")

func free_area() -> Rect2:
	var vp: Vector2 = ed.viewport_size()
	var w := vp.x - (PANEL_W + 8.0 if panel_shown else 0.0)
	return Rect2(0.0, TOP_H, maxf(w, 64.0), maxf(vp.y - TOP_H - STATUS_H, 64.0))

func _process(delta: float) -> void:
	if _toast_age > 0.0:
		_toast_age -= delta
		if _toast_age <= 0.0:
			_toast_box.visible = false

# --- small factories ---------------------------------------------------------------------------------------------------------------

func _btn(text_in: String, cb: Callable, on: bool = false, icon: String = "") -> PixelButton:
	return PixelButton.make(text_in, icon, func():
		_commit_typing()
		cb.call(), on)

# Whatever number or text is being typed is taken (as if Enter was pressed) before a button acts.
func _commit_typing() -> void:
	var owner_node := get_viewport().gui_get_focus_owner()
	if owner_node is LineEdit:
		owner_node.release_focus()

func _num(label_text: String, value: float, on_commit: Callable, step: float = 10.0, min_v: float = -1.0e9, max_v: float = 1.0e9, integer: bool = true):
	var f = WidgetsScript.num(label_text, value, on_commit, step, min_v, max_v, integer)
	_register_field(f)
	return f

func _text_field(label_text: String, value: String, on_commit: Callable, placeholder: String = "", edit_w: float = 200.0):
	var f = WidgetsScript.text(label_text, value, on_commit, placeholder, edit_w)
	_register_field(f)
	return f

func _register_field(f) -> void:
	f.uid = _next_uid
	f.edit.set_meta("uid", _next_uid)
	_next_uid += 1

func _add(c: Control) -> void:
	_body.add_child(c)

func _gap(h: float = 8.0) -> void:
	_add(WidgetsScript.gap(h))

func _section(text_in: String) -> void:
	_add(WidgetsScript.gap(6.0))
	_add(WidgetsScript.title(text_in))

func _note(text_in: String, color: Color = PixelKit.DIM) -> void:
	_add(WidgetsScript.wrapped(text_in, BODY_W, color))

func _row(items: Array) -> void:
	_add(WidgetsScript.button_row(items, BODY_W))

# --- the top bar ----------------------------------------------------------------------------------------------------------------

func _build_top() -> void:
	_top = PixelKit.panel("panel_steel", 6, 0)
	_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top.offset_bottom = TOP_H
	_root.add_child(_top)
	_top_row = HBoxContainer.new()
	_top_row.add_theme_constant_override("separation", 6)
	_top.add_child(_top_row)
	_title_label = PixelKit.label("Map Editor", "head", PixelKit.GOLD3)
	_title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_top_row.add_child(_title_label)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(10, 0)
	_top_row.add_child(spacer)
	_top_row.add_child(_btn("Exit", _on_exit))
	_save_button = _btn("Save", func(): ed.save())
	_top_row.add_child(_save_button)
	_undo_button = _btn("Undo", func(): ed.undo())
	_top_row.add_child(_undo_button)
	_redo_button = _btn("Redo", func(): ed.redo())
	_top_row.add_child(_redo_button)
	_grid_button = _btn("Grid", func(): ed.toggle_grid())
	_top_row.add_child(_grid_button)
	_snap_button = _btn("Snap", func(): ed.cycle_snap())
	_top_row.add_child(_snap_button)
	_top_row.add_child(_btn("Rebuild room", func(): ed.rebuild_room()))
	_top_row.add_child(_btn("Check map", func(): run_check()))
	_top_row.add_child(_btn("Help", func(): toggle_help()))
	var grow := Control.new()
	grow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_row.add_child(grow)
	_unsaved_chip = PixelKit.chip("Unsaved changes", PixelKit.GOLD3)
	_unsaved_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_top_row.add_child(_unsaved_chip)

# The parts of the top bar that depend on the editor's state.
func refresh_top() -> void:
	if _top == null:
		return
	_unsaved_chip.visible = ed.dirty
	_save_button.on = ed.dirty
	_undo_button.disabled = ed.undo_stack.is_empty()
	_redo_button.disabled = ed.redo_stack.is_empty()
	_grid_button.on = ed.grid_on
	_snap_button.text = "Snap off" if ed.snap_step <= 0.0 else "Snap %d" % int(ed.snap_step)
	_snap_button.on = ed.snap_step > 0.0
	_update_hint()

func _on_exit() -> void:
	if ed.dirty:
		_show_confirm()
	else:
		leave()

func leave() -> void:
	get_tree().change_scene_to_file("res://TitleScreen.tscn")

func _show_confirm() -> void:
	if _confirm != null:
		return
	_confirm = Control.new()
	_confirm.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm.add_child(shade)
	var box := PixelKit.panel("panel", 18, 14)
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_confirm.add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	box.add_child(col)
	col.add_child(WidgetsScript.title("Leave the Map Editor?"))
	col.add_child(WidgetsScript.wrapped("You have changes that are not saved: %s." % ", ".join(ed.unsaved_kinds().map(func(k): return MapDataScript.FILE_NAMES[k])), 420.0, PixelKit.CREAM))
	col.add_child(WidgetsScript.button_row([
		_btn("Save and leave", func():
			if ed.save():
				leave()),
		_btn("Leave without saving", func(): leave()),
		_btn("Stay", func(): _close_confirm()),
	], 420.0))
	_root.add_child(_confirm)

func _close_confirm() -> void:
	if _confirm != null:
		_confirm.queue_free()
		_confirm = null

# --- the right panel ------------------------------------------------------------------------------------------------------------

func _build_panel() -> void:
	_panel = PixelKit.panel("panel", 2, 6)
	_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_panel.offset_left = -PANEL_W
	_panel.offset_top = TOP_H + 4.0
	_panel.offset_bottom = -(STATUS_H + 4.0)
	_panel.offset_right = -4.0
	_root.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_panel.add_child(col)
	_tab_row = HFlowContainer.new()
	_tab_row.add_theme_constant_override("h_separation", -2)    # the frames have a little clear border of their own
	_tab_row.add_theme_constant_override("v_separation", 4)
	col.add_child(_tab_row)
	for t in MapEditorScript.TABS:
		var b := _btn(MapEditorScript.TAB_NAMES[t], func(): ed.set_tab(t))
		_tab_row.add_child(b)
		_tab_buttons[t] = b
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	PixelKit.style_scroll(_scroll)
	col.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	_body.custom_minimum_size = Vector2(BODY_W, 0)
	_scroll.add_child(_body)

func toggle_panel() -> void:
	panel_shown = not panel_shown
	_panel.visible = panel_shown
	_minimap_frame.offset_left = 10.0
	ed.view_changed = true

func toggle_minimap() -> void:
	_minimap_frame.visible = not _minimap_frame.visible

func close_popups() -> bool:
	var closed := false
	if _confirm != null:
		_close_confirm()
		closed = true
	if _help != null and _help.visible:
		_help.visible = false
		closed = true
	for c in _popup_layer.get_children():
		c.queue_free()
		closed = true
	return closed

# Asks for the inspector to be rebuilt; many calls in one frame make one rebuild, after the click or key that caused them has finished.
func refresh() -> void:
	refresh_top()
	if not _refresh_queued:
		_refresh_queued = true
		call_deferred("_rebuild_body")

func refresh_throttled() -> void:
	refresh()

func _rebuild_body() -> void:
	_refresh_queued = false
	if _body == null:
		return
	# keep the keyboard on the same field
	var focus_uid := -1
	var focus_owner := get_viewport().gui_get_focus_owner()
	var caret := 0
	if focus_owner is LineEdit and focus_owner.has_meta("uid"):
		focus_uid = int(focus_owner.get_meta("uid"))
		caret = focus_owner.caret_column
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_next_uid = 0
	for t in _tab_buttons:
		_tab_buttons[t].on = t == ed.tab
	match ed.tab:
		"room":
			_build_room_tab()
		"floor":
			_build_floor_tab()
		"decor":
			_build_decor_tab()
		"props":
			_build_props_tab()
		"doors":
			_build_doors_tab()
		"world":
			_build_world_tab()
	if focus_uid >= 0:
		_restore_focus.call_deferred(focus_uid, caret)

func _restore_focus(uid: int, caret: int) -> void:
	for n in _all_line_edits(_body):
		if n.has_meta("uid") and int(n.get_meta("uid")) == uid:
			n.grab_focus()
			n.caret_column = caret
			return

func _all_line_edits(node: Node) -> Array:
	var out: Array = []
	for c in node.get_children():
		if c is LineEdit:
			out.append(c)
		out.append_array(_all_line_edits(c))
	return out

# --- status line and toasts ----------------------------------------------------------------------------------------------------

func _build_status() -> void:
	var bar := PixelKit.panel("inset", 8, 0)
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -STATUS_H
	_root.add_child(bar)
	var row := HBoxContainer.new()
	bar.add_child(row)
	_status_hint = PixelKit.label("", "body", PixelKit.CREAM)
	_status_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_status_hint)
	_status_cursor = PixelKit.label("", "body", PixelKit.DIM)
	row.add_child(_status_cursor)

# One short line saying what a click does now (short enough never to need cutting: the status bar is one line wide).
func _update_hint() -> void:
	if _status_hint == null:
		return
	var text_in := ""
	if not ed.armed.is_empty():
		match str(ed.armed.type):
			"shape":
				if str(ed.armed.kind) in ["path", "poly"]:
					text_in = "Click points, then Enter or double-click. Esc cancels."
				else:
					text_in = "Drag inside the room to draw it. Esc cancels."
			"decor":
				text_in = "Click where the row ends." if ed.armed.has("a") else "Click inside the room to put it down. Esc cancels."
			"prop":
				text_in = "Click inside the room to put it down. Esc cancels."
			"road":
				text_in = "Click along the road, then Enter or double-click. Esc cancels."
	else:
		match ed.tab:
			"room":
				text_in = "Click a room to pick it. Drag the map to move it."
			"floor":
				text_in = "Drag a shape to move it, its squares to resize it."
			"decor":
				text_in = "Drag it or its squares. Ctrl+D copies."
			"props":
				text_in = "Drag a set piece to move it."
			"doors":
				text_in = "Click a side, then drag the squares on its doorways."
			"world":
				text_in = "Drag a place or a road point. Right-click a point removes it."
	_status_hint.text = text_in

func set_cursor_info(world_pos: Vector2) -> void:
	_cursor_world = world_pos
	if _status_cursor == null:
		return
	var local := ""
	if ed.has_room() and not ed.room().is_empty() and ed.room().rect.has_point(world_pos):
		var l: Vector2 = world_pos - ed.room_origin()
		local = "   room %d, %d" % [int(l.x), int(l.y)]
	_status_cursor.text = "x %d  y %d%s   zoom %d%%" % [int(world_pos.x), int(world_pos.y), local, int(ed.zoom * 100.0)]

func _build_toast() -> void:
	_toast_box = PixelKit.panel("panel_steel", 10, 4)
	_toast_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast_box.offset_bottom = -(STATUS_H + 14.0)
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.visible = false
	_root.add_child(_toast_box)
	_toast_label = PixelKit.label("", "body", PixelKit.CREAM)
	_toast_box.add_child(_toast_label)

func toast(text_in: String, bad: bool = false) -> void:
	if _toast_box == null:
		return
	_toast_label.text = text_in
	_toast_label.add_theme_color_override("font_color", PixelKit.BAD if bad else PixelKit.CREAM)
	_toast_box.visible = true
	_toast_age = 5.0 if bad else 3.5

# --- the help sheet -----------------------------------------------------------------------------------------------------------

const HELP_LINES := [
	["MOVING AROUND", ""],
	["Arrow keys / W A S D", "move the view (hold Shift to go faster)"],
	["Mouse wheel  or  + / -", "zoom in and out (only the editor's view)"],
	["Drag the empty map  or  right / middle mouse", "or hold Space and drag over anything"],
	["Home  /  F", "see the whole world  /  fit the picked room"],
	["PICKING", ""],
	["Click a room, or its square on the little map", "to pick it. The tabs on the right edit it."],
	["EDITING", ""],
	["Click a shape, tree row or set piece", "to select it; drag it to move it"],
	["Drag the small white squares", "to resize it. Drag the faint ones to add a point."],
	["Right-click a point", "to remove it. Delete removes the selected thing."],
	["The + buttons on each tab", "arm a new shape; then click or drag in the room"],
	["Type in a number box, press Enter", "to set it exactly. - and + step it (Shift = x10)."],
	["Ctrl+D  Ctrl+Z  Ctrl+Y  Ctrl+S", "copy, undo, redo, save"],
	["Esc", "cancel what you are drawing, or put the selection down"],
	["G  /  R  /  Tab  /  M", "grid  /  rebuild room  /  hide panel  /  hide little map"],
	["CHECKING AND SAVING", ""],
	["Check map", "finds rooms you cannot walk to and places stuck in walls"],
	["Save writes res://data/*.json", "the old files are kept in data/backups. Nothing touches your saves."],
]

func _build_help() -> void:
	_help = Control.new()
	_help.set_anchors_preset(Control.PRESET_FULL_RECT)
	_help.mouse_filter = Control.MOUSE_FILTER_STOP
	_help.visible = false
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help.add_child(shade)
	var box := PixelKit.panel("panel", 18, 12)
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_help.add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	box.add_child(col)
	col.add_child(WidgetsScript.title("Map Editor help"))
	for line in HELP_LINES:
		if str(line[1]) == "":
			var h := PixelKit.label(str(line[0]), "body", PixelKit.GOLD3)
			col.add_child(h)
		else:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			var k := PixelKit.label(str(line[0]), "body", PixelKit.CREAM)
			k.custom_minimum_size = Vector2(330, 0)
			row.add_child(k)
			row.add_child(PixelKit.label(str(line[1]), "body", PixelKit.DIM))
			col.add_child(row)
	var bottom := HBoxContainer.new()
	bottom.add_child(_btn("Close", func(): _help.visible = false))
	col.add_child(WidgetsScript.gap(6.0))
	col.add_child(bottom)
	_root.add_child(_help)

func toggle_help() -> void:
	_help.visible = not _help.visible

# --- a pop-up chooser -------------------------------------------------------------------------------------------------------------

# options: [[id, text], ...]. Calls on_pick(id) when one is clicked.
func choose(title_in: String, options: Array, current: String, on_pick: Callable, columns: int = 2) -> void:
	close_popups()
	var shade := Control.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			close_popups())
	var tint := ColorRect.new()
	tint.color = Color(0, 0, 0, 0.45)
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(tint)
	var box := PixelKit.panel("panel", 14, 10)
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	shade.add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	box.add_child(col)
	col.add_child(WidgetsScript.title(title_in))
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	col.add_child(grid)
	for o in options:
		var id: String = str(o[0])
		grid.add_child(_btn(str(o[1]), func():
			close_popups()
			on_pick.call(id), id == current))
	col.add_child(_btn("Cancel", func(): close_popups()))
	_popup_layer.add_child(shade)

# The map check's answer in a pop-up: one line per problem, each with a button that goes to the room it is about.
func run_check() -> void:
	var problems: Array = ed.check_map()
	var lines: Array = []
	if problems.is_empty():
		lines.append(["Nothing wrong found: every room can be walked to from where you wake and every named place stands on floor.", PixelKit.GOOD, null])
	for p in problems:
		lines.append([str(p[0]), PixelKit.BAD if p[1] == "bad" else PixelKit.CREAM, p[2]])
	show_lines("Map check", lines)

func show_lines(title_in: String, lines: Array) -> void:
	close_popups()
	var shade := Control.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			close_popups())
	var tint := ColorRect.new()
	tint.color = Color(0, 0, 0, 0.45)
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(tint)
	var box := PixelKit.panel("panel", 14, 10)
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	shade.add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	box.add_child(col)
	col.add_child(WidgetsScript.title(title_in))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, minf(60.0 + 52.0 * float(lines.size()), 340.0))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	PixelKit.style_scroll(scroll)
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.custom_minimum_size = Vector2(572, 0)
	scroll.add_child(list)
	for l in lines:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var words := WidgetsScript.wrapped(str(l[0]), 470.0, l[1])
		row.add_child(words)
		if l[2] != null:
			var cell: Vector2i = l[2]
			row.add_child(_btn("Go there", func():
				close_popups()
				ed.pick_cell(cell)
				ed.focus_room()))
		list.add_child(row)
	col.add_child(_btn("Close", func(): close_popups()))
	_popup_layer.add_child(shade)

# A labelled button that shows the current choice and opens the chooser.
func _chooser_row(label_text: String, current_text: String, title_in: String, options: Array, current: String, on_pick: Callable, columns: int = 2) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var l := PixelKit.label(label_text, "body", PixelKit.DIM)
	l.custom_minimum_size = Vector2(WidgetsScript.LABEL_W, 0)
	row.add_child(l)
	row.add_child(_btn(current_text, func(): choose(title_in, options, current, on_pick, columns)))
	_add(row)

# --- the minimap ---------------------------------------------------------------------------------------------------------------

class Minimap extends Control:
	var ed
	var _colors := {}
	const GROUND_COLORS := {
		"grass": Color(0.36, 0.62, 0.32), "sand": Color(0.82, 0.72, 0.46), "swamp": Color(0.38, 0.45, 0.25), "rock": Color(0.5, 0.48, 0.5),
		"snow": Color(0.86, 0.92, 0.96), "ash": Color(0.38, 0.27, 0.26), "void": Color(0.36, 0.22, 0.56), "water": Color(0.2, 0.42, 0.72),
	}

	func setup(editor, cell_px: int) -> void:
		ed = editor
		custom_minimum_size = Vector2(cell_px * MapDataScript.COLS, cell_px * MapDataScript.ROWS)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		recolor()

	func recolor() -> void:
		_colors = {}
		for j in MapDataScript.ROWS:
			for i in MapDataScript.COLS:
				var rect: Rect2 = ed.cell_rect(Vector2i(i, j))
				var region: Dictionary = WorldMapScript.region_at(rect.get_center())
				var base: Color = GROUND_COLORS.get(str(region.ground), Color(0.4, 0.4, 0.4))
				_colors[Vector2i(i, j)] = base * Color(region.tint.r, region.tint.g, region.tint.b, 1.0) if str(region.ground) != "water" else base

	func _cell_px() -> float:
		return size.x / float(MapDataScript.COLS)

	func _draw() -> void:
		if ed == null:
			return
		var cp := _cell_px()
		RoomsScript.ensure_built()
		for j in MapDataScript.ROWS:
			for i in MapDataScript.COLS:
				var c := Vector2i(i, j)
				var col: Color = _colors.get(c, Color.GRAY)
				draw_rect(Rect2(Vector2(i, j) * cp, Vector2(cp, cp)), col)
				if ed.doc.rooms.has(MapDataScript.cell_key(i, j)):
					draw_rect(Rect2(Vector2(i, j) * cp + Vector2(cp * 0.5 - 1.5, cp * 0.5 - 1.5), Vector2(3, 3)), Color(1, 1, 1, 0.75))
		# the room borders (merged rooms draw as one)
		for r in RoomsScript.rooms:
			var p: Vector2 = Vector2(r.cell) * cp
			var s: Vector2 = Vector2(r.span) * cp
			draw_rect(Rect2(p, s), Color(0, 0, 0, 0.55), false, 1.0)
		if ed.has_room():
			var pr: Dictionary = ed.room()
			if not pr.is_empty():
				draw_rect(Rect2(Vector2(pr.cell) * cp, Vector2(pr.span) * cp), PixelKit.GOLD3, false, 2.0)
		# where the camera is looking
		var view: Rect2 = ed.view_world_rect()
		var k := cp / float(WorldMapScript.col_x(1))
		var ky := cp / float(WorldMapScript.row_y(1))
		var vr := Rect2(view.position.x * k, view.position.y * ky, view.size.x * k, view.size.y * ky)
		draw_rect(vr.intersection(Rect2(Vector2.ZERO, size)), Color(1, 1, 1, 0.9), false, 1.0)
		for l in WorldMapScript.landmarks:
			draw_circle(Vector2(l.pos.x * k, l.pos.y * ky), 1.8, Color("fff3a8"))

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var cp := _cell_px()
			var c := Vector2i(clampi(int(event.position.x / cp), 0, MapDataScript.COLS - 1), clampi(int(event.position.y / cp), 0, MapDataScript.ROWS - 1))
			ed.pick_cell(c)
			ed.focus_room()
			accept_event()

func _build_minimap() -> void:
	_minimap_frame = PixelKit.panel("panel_steel", 4, 4)
	_minimap_frame.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_minimap_frame.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_minimap_frame.offset_left = 10.0
	_minimap_frame.offset_bottom = -(STATUS_H + 10.0)
	_root.add_child(_minimap_frame)
	minimap = Minimap.new()
	minimap.setup(ed, MINIMAP_CELL)
	_minimap_frame.add_child(minimap)

# =============================================================================================================================
# THE TABS
# =============================================================================================================================

func _room_title(full: bool = false) -> void:
	var r: Dictionary = ed.room()
	var words := "Room %s" % ed.room_key()
	if not r.is_empty() and str(r.name) != "":
		words += "  " + str(r.name)
	_add(WidgetsScript.title(words))
	if full and not r.is_empty():
		var region: Dictionary = WorldMapScript.region(str(r.region))
		_add(WidgetsScript.caption("%s, danger %d" % [str(region.get("name", "")), int(r.tier)]))

func _needs_room() -> bool:
	if not ed.has_room():
		_add(WidgetsScript.wrapped("Click a room on the map first.", BODY_W, PixelKit.DIM))
		return true
	return false

func _needs_handmade() -> bool:
	if _needs_room():
		return true
	if not ed.is_handmade():
		_note("This room is drawn by the generator. Make it hand-made on the Room tab to shape it yourself.")
		_row([_btn("Make it hand-made", func(): ed.make_handmade())])
		return true
	return false

# --- Room ----------------------------------------------------------------------------------------------------------------------

func _build_room_tab() -> void:
	if _needs_room():
		return
	_room_title(true)
	var r: Dictionary = ed.room()
	if not ed.is_handmade():
		_gap(4.0)
		_note("This room is drawn by the generator, so it can change when other rooms do. Make it hand-made to design it: it starts as a plain oval you can reshape.")
		_row([_btn("Make it hand-made", func(): ed.make_handmade())])
		_note("Region: %s. Kind: %s." % [str(WorldMapScript.region(str(r.region)).get("name", "")), str(r.kind)])
	else:
		var data: Dictionary = ed.room_data()
		_gap(2.0)
		_add(_text_field("Name", str(data.get("name", "")), func(t: String): ed.set_room_field("name", t if t.strip_edges() != "" else null), "(none)", 220.0))
		_note("Only rooms worth finding need a name.")
		var mass: String = str(data.get("mass", ""))
		_chooser_row("Ground", str(ShapesScript.MASS_NAMES.get(mass, mass)), "What the walls are made of", MapDataScript.MASSES.map(func(m): return [m, ShapesScript.MASS_NAMES.get(m, m)]), mass, func(id: String): ed.set_room_field("mass", id))
		var span: Array = data.get("span", [1, 1])
		_add(_num("Cells wide", float(span[0]), func(v: float): ed.set_room_span(int(v), int(span[1])), 1.0, 1.0, 6.0))
		_add(_num("Cells tall", float(span[1]), func(v: float): ed.set_room_span(int(span[0]), int(v)), 1.0, 1.0, 6.0))
		_section("Who lives here")
		if r.kind in ["safe", "sea"]:
			_note("This is a %s room: no wild enemies roam here." % r.kind)
		else:
			_add(_num("Roaming", float(data.get("target", 3)), func(v: float): ed.set_room_field("target", int(v)), 1.0, 0.0, 30.0))
			_note("How many enemies are kept in the room (before the game's scaling).")
			var own: bool = data.has("enemies")
			_row([_btn("Region's usual", func(): ed.set_residents(null), not own), _btn("Own list", func(): ed.set_residents(ed.room_data().get("enemies", ed.region_table_copy(r))), own)])
			if own:
				_enemy_list(data.enemies, func(i: int, w: int): ed.set_resident_weight(i, w), func(key: String): ed.add_resident(key))
			else:
				var region_table: Array = WorldMapScript.region(str(r.region)).get("enemies", [])
				_note("Uses the region's table: %s." % _enemy_words(region_table), PixelKit.DIM)
		_section("This room")
		_row([
			_btn("Revert to shipped", func(): ed.revert_room_to_factory()),
			_btn("Hand it back to the generator", func(): ed.make_generated()),
		])
	_row([_btn("Fit on screen (F)", func(): ed.focus_room()), _btn("Rebuild (R)", func(): ed.rebuild_room())])
	if not ed.load_report.is_empty():
		_section("Problems loading the data")
		for line in ed.load_report:
			_note(str(line), PixelKit.BAD)

func _enemy_words(table: Array) -> String:
	var parts: Array = []
	for e in table:
		parts.append("%s %d" % [MapEditorScript.ENEMY_NAMES.get(str(e[0]), str(e[0])), int(e[1])])
	return ", ".join(parts) if not parts.is_empty() else "none"

# Rows of [enemy, weight] with a - + and a way to add one.
func _enemy_list(list: Array, on_weight: Callable, on_add: Callable) -> void:
	for i in list.size():
		var e: Array = list[i]
		_add(_num(MapEditorScript.ENEMY_NAMES.get(str(e[0]), str(e[0])), float(e[1]), func(v: float): on_weight.call(i, int(v)), 1.0, 0.0, 99.0))
	var options: Array = []
	for k in MapEditorScript.ENEMY_KEYS:
		options.append([k, MapEditorScript.ENEMY_NAMES[k]])
	_row([_btn("+ Add an enemy", func(): choose("Add an enemy", options, "", on_add, 2))])
	_note("A bigger number means that enemy turns up more often. 0 removes it.")

# --- Floor ---------------------------------------------------------------------------------------------------------------------

func _build_floor_tab() -> void:
	if _needs_room():
		return
	_room_title()
	if _needs_handmade():
		return
	_note("The floor you can walk on is made of shapes. Floor shapes add ground, Cut shapes carve it away, Bridge shapes lay a path over a gap.")
	var mode: String = ed.new_mode
	var picked: Dictionary = ed.selected_model()
	if not picked.is_empty():
		mode = str(picked.mode)
	_add(WidgetsScript.caption("A new shape is a" if picked.is_empty() else "This shape is a"))
	_row([_btn("Floor", func(): ed.set_new_mode("floor"), mode == "floor"), _btn("Cut", func(): ed.set_new_mode("cut"), mode == "cut"), _btn("Bridge", func(): ed.set_new_mode("bridge"), mode == "bridge")])
	var adds: Array = []
	for k in ["ell", "disc", "box", "path", "poly"]:
		adds.append(_btn("+ " + ShapesScript.KIND_NAMES[k], func(): ed.arm({"type": "shape", "kind": k, "mode": ed.new_mode}), ed.armed.get("kind", "") == k and ed.armed.get("type", "") == "shape"))
	_row(adds)
	_item_list("floor")
	if not picked.is_empty():
		_section(ShapesScript.op_label(picked))
		_floor_fields(picked)

func _item_list(t: String) -> void:
	var models: Array = ed.item_models(t)
	if models.is_empty():
		_note("Nothing here yet." if t != "floor" else "No shapes: the room has no hand-made floor.", PixelKit.DIM)
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	for i in models.size():
		var label_text := ""
		match t:
			"floor":
				label_text = "%d  %s" % [i + 1, ShapesScript.op_label(models[i])]
			"decor":
				label_text = "%d  %s" % [i + 1, ShapesScript.decor_label(models[i])]
			"props":
				label_text = "%d  %s" % [i + 1, ShapesScript.PROP_NAMES.get(models[i].kind, models[i].kind)]
		var b := _btn(label_text, func(): ed.select_item(i), i == ed.sel_i)
		box.add_child(b)
	_add(box)

func _floor_fields(m: Dictionary) -> void:
	var i: int = ed.sel_i
	match m.kind:
		"ell":
			_add(_num("Centre X", m.c.x, func(v: float): ed.edit_item(i, func(mm): mm.c.x = v)))
			_add(_num("Centre Y", m.c.y, func(v: float): ed.edit_item(i, func(mm): mm.c.y = v)))
			_add(_num("Half width", m.rx, func(v: float): ed.edit_item(i, func(mm): mm.rx = v), 10.0, 20.0, 9000.0))
			_add(_num("Half height", m.ry, func(v: float): ed.edit_item(i, func(mm): mm.ry = v), 10.0, 20.0, 9000.0))
		"disc":
			_add(_num("Centre X", m.c.x, func(v: float): ed.edit_item(i, func(mm): mm.c.x = v)))
			_add(_num("Centre Y", m.c.y, func(v: float): ed.edit_item(i, func(mm): mm.c.y = v)))
			_add(_num("Radius", m.r, func(v: float): ed.edit_item(i, func(mm): mm.r = v), 10.0, 20.0, 9000.0))
		"box":
			_add(_num("Centre X", m.c.x, func(v: float): ed.edit_item(i, func(mm): mm.c.x = v)))
			_add(_num("Centre Y", m.c.y, func(v: float): ed.edit_item(i, func(mm): mm.c.y = v)))
			_add(_num("Half width", m.hx, func(v: float): ed.edit_item(i, func(mm): mm.hx = v), 10.0, 20.0, 9000.0))
			_add(_num("Half height", m.hy, func(v: float): ed.edit_item(i, func(mm): mm.hy = v), 10.0, 20.0, 9000.0))
			_add(_num("Round corners", m.rad, func(v: float): ed.edit_item(i, func(mm): mm.rad = v), 10.0, 0.0, 2000.0))
			_add(_num("Turn (degrees)", m.deg, func(v: float): ed.edit_item(i, func(mm): mm.deg = v), 5.0, -360.0, 360.0, false))
		"path":
			_add(_num("Width", m.width, func(v: float): ed.edit_item(i, func(mm): mm.width = v), 20.0, 20.0, 5000.0))
			_point_fields(m, i)
		"poly":
			_point_fields(m, i)
	_row([_btn("Copy", func(): ed.duplicate_item(i)), _btn("Delete", func(): ed.delete_item(i))])

# Each point as one box, "x, y".
func _point_fields(m: Dictionary, i: int) -> void:
	for k in m.pts.size():
		var p: Vector2 = m.pts[k]
		_add(_text_field("Point %d" % (k + 1), "%s, %s" % [str(ShapesScript.n(p.x)), str(ShapesScript.n(p.y))], func(t: String):
			var parts := t.split(",")
			if parts.size() == 2 and parts[0].strip_edges().is_valid_float() and parts[1].strip_edges().is_valid_float():
				ed.edit_item(i, func(mm): mm.pts[k] = Vector2(float(parts[0]), float(parts[1])))
			else:
				ed.ui.refresh(), "x, y", 170.0))
	_note("Drag the white squares on the map; drag a faint one to add a point; right-click a point to remove it.")

# --- Decor ---------------------------------------------------------------------------------------------------------------------

func _build_decor_tab() -> void:
	if _needs_room():
		return
	_room_title()
	if _needs_handmade():
		return
	var data: Dictionary = ed.room_data()
	_note("Neat arrangements of trees, bushes, flowers and stones.")
	if not data.has("decor"):
		_note("This room has no hand-placed decoration, so the game scatters a few tidy stands of its own. Place your own to take over.", PixelKit.CREAM)
	var adds: Array = []
	for k in MapDataScript.DECOR_KINDS:
		adds.append(_btn("+ " + ShapesScript.DECOR_NAMES[k], func(): ed.arm({"type": "decor", "kind": k}), ed.armed.get("kind", "") == k and ed.armed.get("type", "") == "decor"))
	_row(adds)
	_item_list("decor")
	var m: Dictionary = ed.selected_model()
	if not m.is_empty():
		_section(ShapesScript.decor_label(m))
		_decor_fields(m)
	if data.has("decor"):
		_row([_btn("Let the game scatter stands here instead", func(): ed.set_room_field("decor", null))])
	else:
		_row([_btn("No decoration at all", func(): ed.set_room_field("decor", []))])

func _item_chooser(m: Dictionary, i: int) -> void:
	var cur: String = str(m.get("item", "tall"))
	_chooser_row("Made of", str(ShapesScript.ITEM_NAMES.get(cur, cur)), "What it is made of", MapDataScript.DECOR_ITEMS.map(func(k): return [k, ShapesScript.ITEM_NAMES[k]]), cur, func(id: String): ed.edit_item(i, func(mm): mm.item = id), 1)

func _decor_fields(m: Dictionary) -> void:
	var i: int = ed.sel_i
	match m.kind:
		"orchard", "boulders", "bed":
			_add(_num("Centre X", m.c.x, func(v: float): ed.edit_item(i, func(mm): mm.c.x = v)))
			_add(_num("Centre Y", m.c.y, func(v: float): ed.edit_item(i, func(mm): mm.c.y = v)))
			_add(_num("Columns", m.cols, func(v: float): ed.edit_item(i, func(mm): mm.cols = int(v)), 1.0, 1.0, 40.0))
			_add(_num("Rows", m.rows, func(v: float): ed.edit_item(i, func(mm): mm.rows = int(v)), 1.0, 1.0, 40.0))
			if m.kind != "bed":
				_add(_num("Spacing", m.spacing, func(v: float): ed.edit_item(i, func(mm): mm.spacing = v), 10.0, 20.0, 600.0))
		"row":
			_item_chooser(m, i)
			_add(_num("Start X", m.a.x, func(v: float): ed.edit_item(i, func(mm): mm.a.x = v)))
			_add(_num("Start Y", m.a.y, func(v: float): ed.edit_item(i, func(mm): mm.a.y = v)))
			_add(_num("End X", m.b.x, func(v: float): ed.edit_item(i, func(mm): mm.b.x = v)))
			_add(_num("End Y", m.b.y, func(v: float): ed.edit_item(i, func(mm): mm.b.y = v)))
			_add(_num("Spacing", m.spacing, func(v: float): ed.edit_item(i, func(mm): mm.spacing = v), 10.0, 20.0, 600.0))
		"ring":
			_item_chooser(m, i)
			_add(_num("Centre X", m.c.x, func(v: float): ed.edit_item(i, func(mm): mm.c.x = v)))
			_add(_num("Centre Y", m.c.y, func(v: float): ed.edit_item(i, func(mm): mm.c.y = v)))
			_add(_num("Radius", m.radius, func(v: float): ed.edit_item(i, func(mm): mm.radius = v), 10.0, 40.0, 4000.0))
			_add(_num("How many", m.count, func(v: float): ed.edit_item(i, func(mm): mm.count = int(v)), 1.0, 1.0, 60.0))
		"pair":
			_item_chooser(m, i)
			_add(_num("Middle X", m.c.x, func(v: float): ed.edit_item(i, func(mm): mm.c.x = v)))
			_add(_num("Middle Y", m.c.y, func(v: float): ed.edit_item(i, func(mm): mm.c.y = v)))
			_add(_num("Apart X (half)", m.d.x, func(v: float): ed.edit_item(i, func(mm): mm.d.x = v)))
			_add(_num("Apart Y (half)", m.d.y, func(v: float): ed.edit_item(i, func(mm): mm.d.y = v)))
	_row([_btn("Copy", func(): ed.duplicate_item(i)), _btn("Delete", func(): ed.delete_item(i))])

# --- Props ---------------------------------------------------------------------------------------------------------------------

func _build_props_tab() -> void:
	if _needs_room():
		return
	_room_title()
	if _needs_handmade():
		return
	_note("Set pieces: a camp, standing stones, a pond, ruined walls and more. Each keeps floor clear round it.")
	var options: Array = MapDataScript.PROP_KINDS.map(func(k): return [k, ShapesScript.PROP_NAMES[k]])
	_row([_btn("+ Add a set piece", func(): choose("Add a set piece", options, "", func(id: String): ed.arm({"type": "prop", "kind": id}), 2))])
	if ed.armed.get("type", "") == "prop":
		_note("Click inside the room to put the %s down." % str(ShapesScript.PROP_NAMES.get(ed.armed.kind, ed.armed.kind)), PixelKit.GOLD3)
	_item_list("props")
	var m: Dictionary = ed.selected_model()
	if not m.is_empty():
		var i: int = ed.sel_i
		_section(str(ShapesScript.PROP_NAMES.get(m.kind, m.kind)))
		_chooser_row("Kind", str(ShapesScript.PROP_NAMES.get(m.kind, m.kind)), "Kind of set piece", options, str(m.kind), func(id: String): ed.edit_item(i, func(mm): mm.kind = id), 2)
		_add(_num("X", m.c.x, func(v: float): ed.edit_item(i, func(mm): mm.c.x = v)))
		_add(_num("Y", m.c.y, func(v: float): ed.edit_item(i, func(mm): mm.c.y = v)))
		if m.kind == "pond":
			var flavours: Array = ShapesScript.FLAVOURS.map(func(f): return [f, f.capitalize()])
			_chooser_row("Filled with", str(m.flavour).capitalize() if str(m.flavour) != "" else "Water", "What fills it", flavours, str(m.flavour), func(id: String): ed.edit_item(i, func(mm): mm.flavour = id), 2)
		_row([_btn("Copy", func(): ed.duplicate_item(i)), _btn("Delete", func(): ed.delete_item(i))])

# --- Doors ---------------------------------------------------------------------------------------------------------------------

const SIDE_NAMES := {"n": "North", "s": "South", "e": "East", "w": "West"}

func _build_doors_tab() -> void:
	if _needs_room():
		return
	_room_title()
	_note("Where the room opens onto its neighbours. A doorway is shared: the room next door sees the same gap.")
	var sides: Array = ed.room_sides()
	if sides.is_empty():
		_note("This room has no neighbours.")
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	for s in sides:
		var what := "game decides"
		if typeof(s.spec) == TYPE_STRING:
			what = str(s.spec)
		elif typeof(s.spec) == TYPE_ARRAY:
			what = "%d doorway%s" % [s.spec.size(), "" if s.spec.size() == 1 else "s"]
		var name_in: String = s.name
		box.add_child(_btn("%s of %d,%d: %s" % [SIDE_NAMES[s.side], s.cell.x, s.cell.y, what], func(): ed.select_side(name_in), ed.sel_id == name_in))
	_add(box)
	if ed.sel_id == "":
		return
	var side: Dictionary = ed.side_by_name(ed.sel_id)
	if side.is_empty():
		return
	_section("%s of %d,%d" % [SIDE_NAMES[side.side], side.cell.x, side.cell.y])
	_add(WidgetsScript.caption("Between %d,%d and %d,%d" % [side.cell.x, side.cell.y, side.other_cell.x, side.other_cell.y]))
	var mode := "generated"
	if typeof(side.spec) == TYPE_STRING:
		mode = str(side.spec)
	elif typeof(side.spec) == TYPE_ARRAY:
		mode = "doorways"
	var name_here: String = side.name
	_row([
		_btn("Game decides", func(): ed.set_edge(name_here, "generated"), mode == "generated"),
		_btn("Wide open", func(): ed.set_edge(name_here, "open"), mode == "open"),
		_btn("Closed", func(): ed.set_edge(name_here, "closed"), mode == "closed"),
		_btn("Doorways", func(): ed.set_edge(name_here, ed.doorways_of(side) if not ed.doorways_of(side).is_empty() else [[ShapesScript.n(side.length * 0.5), 520]]), mode == "doorways"),
	])
	if mode == "doorways":
		var list: Array = side.spec
		for k in list.size():
			_add(_num("Doorway %d centre" % (k + 1), float(list[k][0]), func(v: float): ed.edit_doorways(name_here, func(l): l[k][0] = ShapesScript.n(v)), 20.0, 0.0, side.length))
			_add(_num("Doorway %d width" % (k + 1), float(list[k][1]), func(v: float): ed.edit_doorways(name_here, func(l): l[k][1] = ShapesScript.n(v)), 20.0, 60.0, side.length))
		_row([
			_btn("+ Another doorway", func(): ed.edit_doorways(name_here, func(l): l.append([ShapesScript.n(side.length * 0.5), 400]))),
			_btn("Remove last", func(): ed.edit_doorways(name_here, func(l): l.pop_back()), false),
		])
	_note("Along the side is measured in px from its top or left end (it is %d long)." % int(side.length))

# --- World ---------------------------------------------------------------------------------------------------------------------

func _build_world_tab() -> void:
	_add(WidgetsScript.title("The whole world"))
	var sub: Array = []
	for t in MapEditorScript.WORLD_TABS:
		sub.append(_btn({"landmarks": "Places", "roads": "Roads", "regions": "Regions"}[t], func(): ed.set_world_tab(t), ed.world_tab == t))
	_row(sub)
	match ed.world_tab:
		"landmarks":
			_build_landmarks()
		"roads":
			_build_roads()
		"regions":
			_build_regions()

func _build_landmarks() -> void:
	_note("The named places. Drag one on the map, or type where it goes.")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	for l in ed.doc.landmarks:
		var id: String = l.id
		box.add_child(_btn(str(l.name), func():
			ed.sel_id = id
			ed.focus_point(ed.landmark_pos(id), maxf(ed.zoom, 0.12))
			ed.ui.refresh(), ed.sel_id == id))
	_add(box)
	if ed.sel_id == "":
		return
	var e: Dictionary = ed.landmark_entry(ed.sel_id)
	if e.is_empty():
		return
	var id2: String = ed.sel_id
	_section(str(e.name))
	_add(_text_field("Name", str(e.name), func(t: String): ed.edit_landmark(id2, func(en): en.name = t if t.strip_edges() != "" else en.name), "", 220.0))
	if id2 in MapEditorScript.FIXED_LANDMARKS:
		_note("The game's code puts this place at a fixed spot (the town, where you wake, Pesca's houses), so it cannot be moved here.", PixelKit.DIM)
	else:
		_add(_num("X", float(e.pos[0]), func(v: float): ed.edit_landmark(id2, func(en): en.pos = [ShapesScript.n(v), en.pos[1]]), 20.0, 0.0, WorldMapScript.SIZE.x))
		_add(_num("Y", float(e.pos[1]), func(v: float): ed.edit_landmark(id2, func(en): en.pos = [en.pos[0], ShapesScript.n(v)]), 20.0, 0.0, WorldMapScript.SIZE.y))
	_add(_num("Size (radius)", float(e.radius), func(v: float): ed.edit_landmark(id2, func(en): en.radius = ShapesScript.n(v)), 20.0, 40.0, 4000.0))
	_note("A place takes its boss room with it: the room it lands in becomes its room, and the room it left turns into ordinary country.")

func _build_roads() -> void:
	_note("Roads drawn across the land. Drag a point; drag a faint square to add one; right-click a point to remove it.")
	_row([_btn("+ New road", func(): ed.armed = {"type": "road", "points": []}; ed.sel_i = -1; ed.ui.refresh(); ed.overlay.queue_redraw(), ed.armed.get("type", "") == "road")])
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	for i in ed.doc.roads.size():
		var r: Dictionary = ed.doc.roads[i]
		box.add_child(_btn("%d  %s, %d wide, %d points" % [i + 1, MapEditorScript.ROAD_STYLE_NAMES.get(str(r.get("style", "")), "Dirt"), int(r.width), r.points.size()], func():
			ed.sel_i = i
			ed.sel_pt = -1
			ed.focus_point(ed.road_point_world(ed.doc.roads[i].points[0]), maxf(ed.zoom, 0.08))
			ed.ui.refresh(), i == ed.sel_i))
	_add(box)
	if ed.sel_i < 0 or ed.sel_i >= ed.doc.roads.size():
		return
	var i2: int = ed.sel_i
	var road: Dictionary = ed.doc.roads[i2]
	_section("Road %d" % (i2 + 1))
	_add(_num("Width", float(road.width), func(v: float): ed.edit_road(i2, func(r): r.width = ShapesScript.n(v)), 10.0, 20.0, 600.0))
	var style: String = str(road.get("style", ""))
	_chooser_row("Surface", str(MapEditorScript.ROAD_STYLE_NAMES.get(style, style)), "What the road is made of", MapEditorScript.ROAD_STYLES.map(func(s): return [s, MapEditorScript.ROAD_STYLE_NAMES[s]]), style, func(id: String): ed.edit_road(i2, func(r):
		if id == "":
			r.erase("style")
		else:
			r.style = id), 2)
	for k in road.points.size():
		var p: Array = road.points[k]
		_add(_text_field("Point %d" % (k + 1), "%s, %s" % [str(p[0]), str(p[1])], func(t: String):
			var parts := t.split(",")
			if parts.size() == 2 and parts[0].strip_edges().is_valid_float() and parts[1].strip_edges().is_valid_float():
				ed.edit_road(i2, func(r): r.points[k] = [snappedf(float(parts[0]), 0.001), snappedf(float(parts[1]), 0.001)])
			else:
				ed.ui.refresh(), "col, row", 170.0))
	_note("Points are in cells: 5.5, 5.5 is the middle of the cell at column 5, row 5.")
	_row([_btn("Delete road", func(): ed.delete_road(i2))])

func _build_regions() -> void:
	_note("Each region's danger and who lives there (a room's own list wins). Click the map to pick the region under it.")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	for r in WorldMapScript.regions:
		var id: String = r.id
		if not ed.doc.regions.has(id):
			continue
		box.add_child(_btn("%s (%d)" % [str(ed.doc.regions[id].name), int(ed.doc.regions[id].tier)] if id != "ocean" else "The Ocean", func():
			ed.sel_id = id
			ed.ui.refresh()
			ed.overlay.queue_redraw(), ed.sel_id == id))
	_add(box)
	if ed.sel_id == "" or not ed.doc.regions.has(ed.sel_id):
		return
	var id2: String = ed.sel_id
	var reg: Dictionary = ed.doc.regions[id2]
	_section(str(reg.name))
	_add(_text_field("Name", str(reg.name), func(t: String): ed.edit_region(id2, func(r): r.name = t if t.strip_edges() != "" else r.name), "", 220.0))
	_add(_num("Danger (1-8)", float(reg.tier), func(v: float): ed.edit_region(id2, func(r): r.tier = int(v)), 1.0, 1.0, 8.0))
	var mini: String = str(reg.miniboss)
	_chooser_row("Miniboss", str(MapEditorScript.MINIBOSS_NAMES.get(mini, mini)), "Which miniboss walks this region", MapEditorScript.MINIBOSS_KEYS.map(func(k): return [k, MapEditorScript.MINIBOSS_NAMES[k]]), mini, func(id: String): ed.edit_region(id2, func(r): r.miniboss = id), 2)
	_section("Who lives here")
	_enemy_list(reg.enemies, func(i: int, w: int):
		ed.edit_region(id2, func(r):
			if w <= 0:
				r.enemies.remove_at(i)
			else:
				r.enemies[i][1] = w), func(key: String):
		ed.edit_region(id2, func(r):
			for e in r.enemies:
				if e[0] == key:
					e[1] = int(e[1]) + 1
					return
			r.enemies.append([key, 1])))
	_note("The region's outline is still drawn in scripts/WorldMap.gd.")
