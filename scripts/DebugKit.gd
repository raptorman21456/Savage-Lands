extends RefCounted

# The small pieces the Debug menu's tabs are made of, all in the pixel kit (PixelKit / PixelButton / InvCard): keyboard-reachable
# buttons, a number field with steps, rows of choices, a search box that fits what is typed, section titles, card grids. Nothing here
# knows what the game is; the views (Debug*View.gd) put these together and DebugActions & co. do the work.

const DebugButtonScript := preload("res://scripts/DebugButton.gd")
const DebugCardScript := preload("res://scripts/DebugCard.gd")

const ROW_H := 40.0

# --- buttons ----------------------------------------------------------------------------------------------------------------

static func button(text: String, on_pressed: Callable = Callable(), on: bool = false, icon_name: String = "", tip: String = "") -> PixelButton:
	var b: PixelButton = DebugButtonScript.new()
	b._build(text, icon_name)
	b.on = on
	b.tooltip_text = tip
	if on_pressed.is_valid():
		b.pressed.connect(on_pressed)
	return b

# A button that can be switched off: greyed, and skipped by the arrow keys.
static func set_enabled(b: PixelButton, enabled: bool) -> void:
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE

# An On / Off switch: the button says which, and pressing it calls on_set(new_value).
static func toggle(label_text: String, value: bool, on_set: Callable) -> PixelButton:
	var b := button("%s: %s" % [label_text, "On" if value else "Off"], func(): on_set.call(not value), value)
	return b

# --- layout -----------------------------------------------------------------------------------------------------------------

static func vbox(parent: Node, separation: int = 6) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if parent != null:
		parent.add_child(v)
	return v

static func hbox(parent: Node, separation: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	if parent != null:
		parent.add_child(h)
	return h

# Children wrap onto the next line when the row is full.
static func flow(parent: Node, h_sep: int = 4, v_sep: int = 4) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", h_sep)
	f.add_theme_constant_override("v_separation", v_sep)
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if parent != null:
		parent.add_child(f)
	return f

static func spacer(parent: Node, height: float = 8.0) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent != null:
		parent.add_child(s)
	return s

static func fill(parent: Node) -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent != null:
		parent.add_child(s)
	return s

# A gold title with a rule under it.
static func section(parent: Node, text: String) -> Label:
	spacer(parent, 10.0)
	var l := PixelKit.label(text, "body", PixelKit.GOLD3)
	parent.add_child(l)
	parent.add_child(PixelKit.rule())
	spacer(parent, 2.0)
	return l

# A dim wrapped paragraph.
static func note(parent: Node, text: String, color: Color = PixelKit.DIM) -> Label:
	var l := PixelKit.label(text, "body", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(0, 0)
	if parent != null:
		parent.add_child(l)
	return l

# A row with a fixed-width label on the left; put the controls in the returned box.
static func row(parent: Node, label_text: String, label_w: float = 230.0, tip: String = "") -> HBoxContainer:
	var h := hbox(parent, 8)
	h.custom_minimum_size = Vector2(0, ROW_H)
	var l := PixelKit.label(label_text)
	l.custom_minimum_size = Vector2(label_w, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.tooltip_text = tip
	l.mouse_filter = Control.MOUSE_FILTER_STOP if tip != "" else Control.MOUSE_FILTER_IGNORE
	h.add_child(l)
	return h

# A choice among a few things: options are [id, label] pairs; the current one is lit; on_pick(id) is called.
static func choice_row(parent: Node, options: Array, current, on_pick: Callable) -> HFlowContainer:
	var f := flow(parent)
	for opt in options:
		var id = opt[0]
		f.add_child(button(str(opt[1]), on_pick.bind(id), id == current))
	return f

# A scrolling area with the pixel scroll bar; it scrolls to keep the keyboard focus in view.
static func scroll(area: Vector2) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.follow_focus = true
	PixelKit.style_scroll(s)
	s.custom_minimum_size = area
	s.size = area
	return s

# A framed panel with a scroll area inside; returns [panel, the VBox to fill].
static func framed_scroll(area: Vector2, frame_name: String = "panel_steel") -> Array:
	var panel := PixelKit.panel(frame_name, 8, 4)
	panel.custom_minimum_size = area
	panel.size = area
	var s := scroll(Vector2.ZERO)
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(s)
	var box := vbox(s, 4)
	return [panel, box]

# --- text fields ------------------------------------------------------------------------------------------------------------

static func line_edit(text: String, min_w: float = 90.0, placeholder: String = "") -> LineEdit:
	var e := LineEdit.new()
	e.text = text
	e.placeholder_text = placeholder
	e.add_theme_stylebox_override("normal", PixelKit.padded("inset", 6, 0))
	e.add_theme_stylebox_override("focus", PixelKit.padded("button_hover", 6, 0))
	e.add_theme_stylebox_override("read_only", PixelKit.padded("inset", 6, 0))
	e.add_theme_font_override("font", PixelKit.font("body"))
	e.add_theme_font_size_override("font_size", PixelKit.font_size("body"))
	e.add_theme_color_override("font_color", PixelKit.CREAM)
	e.add_theme_color_override("font_placeholder_color", PixelKit.DIM)
	e.add_theme_color_override("caret_color", PixelKit.GOLD3)
	e.add_theme_color_override("selection_color", Color(PixelKit.V3, 0.7))
	e.custom_minimum_size = Vector2(min_w, ROW_H)
	e.context_menu_enabled = false
	e.select_all_on_focus = true
	e.caret_blink = true
	e.set_meta("min_w", min_w)
	e.text_changed.connect(func(_t): fit_line_edit(e))
	fit_line_edit(e)
	return e

# Exactly as wide as what is typed (never narrower than it started).
static func fit_line_edit(e: LineEdit, max_w: float = 520.0) -> void:
	var f: Font = PixelKit.font("body")
	var txt: String = e.text if e.text != "" else e.placeholder_text
	var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, PixelKit.font_size("body")).x + 16.0 + 12.0 + 12.0
	e.custom_minimum_size.x = clampf(w, float(e.get_meta("min_w", 90.0)), max_w)
	e.size.x = e.custom_minimum_size.x

static func search_field(text: String, on_change: Callable, placeholder: String = "Search") -> LineEdit:
	var e := line_edit(text, 120.0, placeholder)
	e.text_changed.connect(func(t): on_change.call(t))
	return e

# A number you can step with buttons or type (Enter applies). opts: {min, max, steps: [1, 10], float: false, width}.
# on_set(new_value) is called with the clamped value; the view rebuilds afterwards and shows the result.
static func number(parent: Node, value, on_set: Callable, opts: Dictionary = {}) -> HBoxContainer:
	var h := hbox(parent, 4)
	var lo = opts.get("min", 0)
	var hi = opts.get("max", 999999)
	var steps: Array = opts.get("steps", [1, 10])
	var as_float: bool = bool(opts.get("float", false))
	var apply := func(v):
		on_set.call(clampf(float(v), float(lo), float(hi)) if as_float else clampi(int(v), int(lo), int(hi)))
	for i in range(steps.size() - 1, -1, -1):
		var st = steps[i]
		h.add_child(button("−%s" % _fmt(st), func(): apply.call(value - st)))
	var field := line_edit(_fmt(value), float(opts.get("width", 100.0)))
	field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	field.text_submitted.connect(func(t): apply.call(t.to_float() if as_float else t.to_int()))
	h.add_child(field)
	for st in steps:
		h.add_child(button("+%s" % _fmt(st), func(): apply.call(value + st)))
	return h

static func _fmt(v) -> String:
	if typeof(v) == TYPE_FLOAT and not is_equal_approx(float(v), round(float(v))):
		return ("%.2f" % float(v)).rstrip("0").rstrip(".")
	return str(int(v))

# --- cards ------------------------------------------------------------------------------------------------------------------

# An InvCard the keyboard can reach. info as InvCard.setup takes it; `held` lights it with the white "worn" frame (something you have),
# `picked` with the gold one (the one chosen).
static func card(info: Dictionary, held: bool, picked: bool, on_pick: Callable, on_use: Callable = Callable()) -> Panel:
	var c: Panel = DebugCardScript.new()
	c.setup(info)
	c.worn = held
	c.picked = picked
	c.pressed.connect(on_pick)
	if on_use.is_valid():
		c.double_pressed.connect(on_use)
		c.set_meta("on_use", on_use)
	return c

# --- keeping your place across a rebuild ----------------------------------------------------------------------------------------

# Every control under `root` the keyboard can land on, in tree order.
static func focusables(root: Node) -> Array:
	var out: Array = []
	_collect_focusables(root, out)
	return out

static func _collect_focusables(n: Node, out: Array) -> void:
	if n is Control and n.focus_mode != Control.FOCUS_NONE and n.is_visible_in_tree():
		out.append(n)
	for c in n.get_children():
		_collect_focusables(c, out)

static func scrolls(root: Node) -> Array:
	var out: Array = []
	_collect_scrolls(root, out)
	return out

static func _collect_scrolls(n: Node, out: Array) -> void:
	if n is ScrollContainer:
		out.append(n)
	for c in n.get_children():
		_collect_scrolls(c, out)

# What to remember before a view is rebuilt: how far each scroll area is scrolled, and which focusable control has focus.
static func snapshot(root: Node) -> Dictionary:
	var focus_index := -1
	var owner: Control = root.get_viewport().gui_get_focus_owner() if root.is_inside_tree() else null
	if owner != null:
		focus_index = focusables(root).find(owner)
	var offsets: Array = []
	for s in scrolls(root):
		offsets.append(int(s.scroll_vertical))
	return {"focus": focus_index, "scroll": offsets}

# Puts it back, once the new content has been laid out (a frame later).
static func restore(root: Node, snap: Dictionary) -> void:
	if not root.is_inside_tree():
		return
	await root.get_tree().process_frame
	if not is_instance_valid(root) or not root.is_inside_tree():
		return
	var areas: Array = scrolls(root)
	for i in mini(areas.size(), snap.scroll.size()):
		areas[i].scroll_vertical = int(snap.scroll[i])
	var idx: int = int(snap.focus)
	if idx >= 0:
		var items: Array = focusables(root)
		if not items.is_empty():
			var target: Control = items[mini(idx, items.size() - 1)]
			target.set_meta("quiet_focus", true)       # a card must not take this as a choice
			target.grab_focus()
			if target.has_focus():
				target.set_meta("quiet_focus", false)  # (focus_entered has fired by now; if the control was already focused it never will)
