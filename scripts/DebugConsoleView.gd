extends "res://scripts/DebugViewBase.gd"

# CONSOLE: the way to do literally anything the other tabs don't have a button for. Two pages:
#   Console    type an expression or an assignment and it runs against the live game (player.coins = 500, units[0].hp = 1,
#              A.set_level(main, 20)...). `help` says what is in scope. Up / Down recalls what you typed. (DebugConsole.gd)
#   Inspector  pick you, the game, a party member or any unit on the battle grid, and every variable it has is a row you can edit;
#              a Dictionary, an Array or another object has an Open button that steps into it. (DebugInspector.gd)
# Every edit goes through the same code, so what the Inspector does is what the Console does.

const ConsoleScript := preload("res://scripts/DebugConsole.gd")
const InspectorScript := preload("res://scripts/DebugInspector.gd")

const MAX_ROWS := 120            # variables shown at once in the Inspector (search to narrow)
const MAX_LINES := 300           # lines the Console keeps
const EXAMPLES := ["help", "props player coin", "player.coins = 5000", "units", "A.set_level(main, 30)", "main.battle_turn"]

var cs: Dictionary = {}          # the Console's remembered state (menu.state.console)
var ins: Dictionary = {}         # the Inspector's (menu.state.inspect)
var _out_box: VBoxContainer = null
var _out_scroll: ScrollContainer = null
var _input: LineEdit = null

# Makes sure the menu's shared state holds this tab's two memories (the Console's lines and history; where the Inspector is).
static func ensure_state(state: Dictionary) -> void:
	if not state.has("console"):
		state["console"] = {"page": "Console", "lines": [{"t": "out", "s": "Type  help  for what you can do. Anything you type runs against the live game."}], "history": [], "pos": 0}
	if not state.has("inspect"):
		state["inspect"] = {"root": "player", "path": [], "search": "", "engine": false}

func build() -> void:
	clear()
	ensure_state(menu.state)
	cs = menu.state.console
	ins = menu.state.inspect
	var k := DebugKitScript
	var top := k.hbox(self, 8)
	top.position = Vector2.ZERO
	top.size = Vector2(size.x, 44)
	for page_name in ["Console", "Inspector"]:
		var pn: String = page_name
		top.add_child(k.button(pn, func():
			cs["page"] = pn
			refresh()
		, pn == str(cs.page)))
	if str(cs.page) == "Console":
		_console_page()
	else:
		_inspector_page()

# The text box that should have the keyboard when the tab opens.
func preferred_focus():
	return _input if str(cs.get("page", "Console")) == "Console" and _input != null and is_instance_valid(_input) else null

# --- the Console page ---------------------------------------------------------------------------------------------------------

func _console_page() -> void:
	var k := DebugKitScript
	var out_h: float = size.y - 52.0 - 96.0
	var framed: Array = k.framed_scroll(Vector2(size.x, out_h), "panel_steel")
	framed[0].position = Vector2(0, 52)
	add_child(framed[0])
	_out_scroll = framed[0].get_child(0)
	_out_box = framed[1]
	for line in cs.lines:
		_draw_line(str(line.t), str(line.s))
	_scroll_to_end()
	var examples := k.flow(self)
	examples.position = Vector2(0, size.y - 92)
	examples.size = Vector2(size.x, 40)
	var label := PixelKit.label("Try:", "body", PixelKit.DIM)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	examples.add_child(label)
	for ex in EXAMPLES:
		var text: String = ex
		examples.add_child(k.button(text, func():
			_input.text = text
			_input.caret_column = text.length()
			_input.grab_focus()
		))
	var row := k.hbox(self, 8)
	row.position = Vector2(0, size.y - 44)
	row.size = Vector2(size.x, 42)
	_input = k.line_edit("", 400, "Type here and press Enter")
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.text_submitted.connect(func(t): _submit(t))
	_input.gui_input.connect(_input_key)
	row.add_child(_input)
	row.add_child(k.button("Run", func(): _submit(_input.text), true))
	row.add_child(k.button("Clear", func():
		cs.lines.clear()
		for c in _out_box.get_children():
			_out_box.remove_child(c)
			c.queue_free()
	, false, "", "Empties this list."))

func _input_key(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not ev.pressed:
		return
	if ev.keycode == KEY_UP or ev.keycode == KEY_DOWN:
		var history: Array = cs.history
		if history.is_empty():
			return
		cs["pos"] = clampi(int(cs.pos) + (-1 if ev.keycode == KEY_UP else 1), 0, history.size())
		_input.text = str(history[int(cs.pos)]) if int(cs.pos) < history.size() else ""
		_input.caret_column = _input.text.length()
		DebugKitScript.fit_line_edit(_input)
		_input.accept_event()

func _submit(raw: String) -> void:
	var text := raw.strip_edges()
	if text == "":
		return
	_input.text = ""
	if text == "clear":
		cs.lines.clear()
		for c in _out_box.get_children():
			_out_box.remove_child(c)
			c.queue_free()
		return
	var history: Array = cs.history
	if history.is_empty() or str(history[history.size() - 1]) != text:
		history.append(text)
		if history.size() > 100:
			history.pop_front()
	cs["pos"] = history.size()
	_push("in", "> " + text)
	var r: Dictionary = ConsoleScript.run(main, text)
	for line in r.lines:
		_push("out" if bool(r.ok) else "err", str(line))
	if not bool(r.ok) and r.lines.is_empty():
		_push("err", str(r.msg))
	menu.report({"ok": bool(r.ok), "msg": str(r.msg)})
	_scroll_to_end()
	_input.grab_focus()

func _push(kind: String, text: String) -> void:
	cs.lines.append({"t": kind, "s": text})
	while cs.lines.size() > MAX_LINES:
		cs.lines.pop_front()
		if _out_box != null and _out_box.get_child_count() > 0:
			var first: Node = _out_box.get_child(0)
			_out_box.remove_child(first)
			first.queue_free()
	_draw_line(kind, text)

func _draw_line(kind: String, text: String) -> void:
	var color: Color = PixelKit.GOLD3 if kind == "in" else (PixelKit.BAD if kind == "err" else PixelKit.CREAM)
	var l: Label = DebugKitScript.note(_out_box, text, color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _scroll_to_end() -> void:
	if _out_scroll == null or not is_inside_tree():
		return
	await get_tree().process_frame
	if _out_scroll != null and is_instance_valid(_out_scroll):
		_out_scroll.scroll_vertical = int(_out_scroll.get_v_scroll_bar().max_value)

# --- the Inspector page -------------------------------------------------------------------------------------------------------

func _inspector_page() -> void:
	var k := DebugKitScript
	var page := k.vbox(self, 6)
	page.position = Vector2(0, 52)
	page.size = Vector2(size.x, size.y - 52.0)
	# what to look at
	var roots := k.flow(page)
	var chosen: String = str(ins.root)
	var root_list: Array = InspectorScript.roots(main)
	var known := false
	for r in root_list:
		if str(r.id) == chosen:
			known = true
	if not known:
		chosen = "player"
		ins["root"] = "player"
		ins["path"] = []
	for r in root_list:
		var id: String = str(r.id)
		roots.add_child(k.button(str(r.label), func():
			ins["root"] = id
			ins["path"] = []
			ins["search"] = ""
			refresh()
		, id == chosen))
	# where you are inside it, and the search
	var res: Dictionary = InspectorScript.resolve(main, chosen, ins.path)
	if not bool(res.ok):
		ins["path"] = []
		res = InspectorScript.resolve(main, chosen, [])
	var bar := k.hbox(page, 8)
	if not (ins.path as Array).is_empty():
		bar.add_child(k.button("Up", func():
			(ins.path as Array).pop_back()
			ins["search"] = ""
			refresh()
		))
	var where := PixelKit.label(str(res.label), "body", PixelKit.GOLD3)
	where.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(where)
	k.fill(bar)
	if res.value is Object:
		bar.add_child(k.button("Engine variables: %s" % ("on" if bool(ins.engine) else "off"), func():
			ins["engine"] = not bool(ins.engine)
			refresh()
		, bool(ins.engine), "", "Also lists the engine's own variables (a node's position, collision settings...)."))
	bar.add_child(k.search_field(str(ins.search), func(t):
		ins["search"] = t
		_fill_rows()
	, "Search names"))
	# the rows
	var framed: Array = k.framed_scroll(Vector2(0, 100), "panel_steel")
	framed[0].size_flags_vertical = Control.SIZE_EXPAND_FILL
	framed[0].custom_minimum_size = Vector2(0, 100)
	page.add_child(framed[0])
	_out_box = framed[1]
	_out_scroll = framed[0].get_child(0)
	_fill_rows()

func _fill_rows() -> void:
	var k := DebugKitScript
	for c in _out_box.get_children():
		_out_box.remove_child(c)
		c.queue_free()
	var res: Dictionary = InspectorScript.resolve(main, str(ins.root), ins.path)
	if not bool(res.ok):
		k.note(_out_box, "That is gone (the battle ended, or the member left). Pick something above.")
		return
	var holder = res.value
	var items: Array = InspectorScript.entries(holder, str(ins.search), bool(ins.engine))
	if items.is_empty():
		k.note(_out_box, "Nothing here%s." % (" matches '%s'" % str(ins.search) if str(ins.search) != "" else ""))
		return
	var shown := 0
	for item in items:
		if shown >= MAX_ROWS:
			k.note(_out_box, "... %d more. Type a name in the search box to narrow it." % (items.size() - MAX_ROWS), PixelKit.GOLD3)
			break
		_row(holder, str(res.label), item.key, item.value)
		shown += 1

func _row(holder, label: String, key, value) -> void:
	var k := DebugKitScript
	var r := k.hbox(_out_box, 8)
	r.custom_minimum_size = Vector2(0, 40)
	var name_label := PixelKit.label(str(key), "body", PixelKit.CREAM)
	name_label.custom_minimum_size = Vector2(300, 0)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.tooltip_text = str(key)
	name_label.mouse_filter = Control.MOUSE_FILTER_STOP
	r.add_child(name_label)
	var full_label := "%s.%s" % [label, str(key)] if not (holder is Array or holder is Dictionary) else "%s[%s]" % [label, InspectorScript._key_text(key)]
	var apply := func(text: String): act(InspectorScript.apply_edit(holder, key, text, full_label))
	var kind: String = InspectorScript.editor_for(value)
	match kind:
		"int", "float":
			var step: float = 1.0 if kind == "int" else 0.1
			r.add_child(k.button("−", func(): apply.call(InspectorScript.field_text(value - step if kind == "float" else int(value) - 1))))
			var field := k.line_edit(InspectorScript.field_text(value), 120)
			field.alignment = HORIZONTAL_ALIGNMENT_CENTER
			field.text_submitted.connect(func(t): apply.call(t))
			r.add_child(field)
			r.add_child(k.button("+", func(): apply.call(InspectorScript.field_text(value + step if kind == "float" else int(value) + 1))))
		"bool":
			var sw: PixelButton = k.button("On" if bool(value) else "Off", func(): apply.call("off" if bool(value) else "on"), bool(value))
			sw.custom_minimum_size = Vector2(96, 0)
			r.add_child(sw)
		"text", "vector2i", "vector2", "color":
			var field2 := k.line_edit(InspectorScript.field_text(value), 260)
			field2.text_submitted.connect(func(t): apply.call(t))
			r.add_child(field2)
		"open":
			var note := PixelKit.label(InspectorScript.summary(value), "body", PixelKit.DIM)
			note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			r.add_child(note)
			r.add_child(k.button("Open", func():
				(ins.path as Array).append(key)
				ins["search"] = ""
				refresh()
			))
		_:
			var text := PixelKit.label(InspectorScript.summary(value), "body", PixelKit.DIM)
			text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			r.add_child(text)
