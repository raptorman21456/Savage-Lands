extends RefCounted

# The small pieces the Map Editor's panels are made of, all in the pixel kit (PixelKit frames and fonts, PixelButton): a labelled number
# field with - and + buttons, a labelled text field, section titles, gaps. No stock Godot look anywhere: a LineEdit is given the kit's
# sunken frame and pixel font exactly the way the title screen's rename box is.

const LABEL_W := 112.0

# A number with a label, [-] [ 1234 ] [+]. Type a number and press Enter (or click away) to set it; the buttons step it (Shift = 10 times
# as much). Emits `committed(value)`.
class NumField extends HBoxContainer:
	signal committed(value: float)
	var edit: LineEdit
	var step := 10.0
	var min_v := -1.0e9
	var max_v := 1.0e9
	var integer := true
	var uid := -1
	var _value := 0.0
	var _shown := ""

	func setup(label_text: String, value: float, step_in: float, min_in: float, max_in: float, integer_in: bool, label_w: float) -> void:
		step = step_in
		min_v = min_in
		max_v = max_in
		integer = integer_in
		add_theme_constant_override("separation", 4)
		if label_text != "":
			var l := PixelKit.label(label_text, "body", PixelKit.DIM)
			l.custom_minimum_size = Vector2(label_w, 0)
			add_child(l)
		add_child(PixelButton.make("-", "", func(): _nudge(-1.0)))
		edit = LineEdit.new()
		edit.custom_minimum_size = Vector2(88, 40)
		edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
		edit.select_all_on_focus = true
		edit.add_theme_stylebox_override("normal", PixelKit.padded("inset", 4, 0))
		edit.add_theme_stylebox_override("focus", PixelKit.padded("inset", 4, 0))
		edit.add_theme_font_override("font", PixelKit.font("body"))
		edit.add_theme_font_size_override("font_size", PixelKit.font_size("body"))
		edit.add_theme_color_override("font_color", PixelKit.CREAM)
		edit.add_theme_color_override("caret_color", PixelKit.GOLD3)
		edit.add_theme_color_override("selection_color", Color(PixelKit.GOLD3, 0.4))
		edit.text_submitted.connect(_on_submit)
		edit.focus_exited.connect(_on_blur)
		add_child(edit)
		add_child(PixelButton.make("+", "", func(): _nudge(1.0)))
		set_value(value)

	func set_value(v: float) -> void:
		_value = v
		_shown = _format(v)
		edit.text = _shown

	func value() -> float:
		return _value

	func _format(v: float) -> String:
		if integer:
			return str(int(roundf(v)))
		var s := snappedf(v, 0.01)
		return str(int(s)) if s == roundf(s) else str(s)

	func _nudge(dir: float) -> void:
		var k := 10.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0
		_apply(_value + dir * step * k)

	func _on_submit(text: String) -> void:
		_read(text)
		edit.release_focus()

	func _on_blur() -> void:
		if edit.text != _shown:
			_read(edit.text)

	func _read(text: String) -> void:
		var t := text.strip_edges()
		if not (t.is_valid_float() or t.is_valid_int()):
			edit.text = _shown
			return
		_apply(float(t))

	func _apply(v: float) -> void:
		var c := clampf(v, min_v, max_v)
		if integer:
			c = roundf(c)
		set_value(c)
		committed.emit(c)

# A text field with a label: Enter or clicking away sets it. Emits `committed(text)`.
class TextField extends HBoxContainer:
	signal committed(text: String)
	var edit: LineEdit
	var uid := -1
	var _shown := ""

	func setup(label_text: String, value: String, placeholder: String, label_w: float, edit_w: float) -> void:
		add_theme_constant_override("separation", 4)
		if label_text != "":
			var l := PixelKit.label(label_text, "body", PixelKit.DIM)
			l.custom_minimum_size = Vector2(label_w, 0)
			add_child(l)
		edit = LineEdit.new()
		edit.custom_minimum_size = Vector2(edit_w, 40)
		edit.placeholder_text = placeholder
		edit.max_length = 40
		edit.add_theme_stylebox_override("normal", PixelKit.padded("inset", 6, 0))
		edit.add_theme_stylebox_override("focus", PixelKit.padded("inset", 6, 0))
		edit.add_theme_font_override("font", PixelKit.font("body"))
		edit.add_theme_font_size_override("font_size", PixelKit.font_size("body"))
		edit.add_theme_color_override("font_color", PixelKit.CREAM)
		edit.add_theme_color_override("font_placeholder_color", PixelKit.DIM)
		edit.add_theme_color_override("caret_color", PixelKit.GOLD3)
		edit.add_theme_color_override("selection_color", Color(PixelKit.GOLD3, 0.4))
		edit.text_submitted.connect(func(t: String): _read(t); edit.release_focus())
		edit.focus_exited.connect(func(): _read(edit.text))
		add_child(edit)
		_shown = value
		edit.text = value

	func _read(text: String) -> void:
		if text != _shown:
			_shown = text
			committed.emit(text)

# --- builders --------------------------------------------------------------------------------------------------------------------

static func num(label_text: String, value: float, on_commit: Callable, step: float = 10.0, min_v: float = -1.0e9, max_v: float = 1.0e9, integer: bool = true) -> NumField:
	var f := NumField.new()
	f.setup(label_text, value, step, min_v, max_v, integer, LABEL_W)
	f.committed.connect(on_commit)
	return f

static func text(label_text: String, value: String, on_commit: Callable, placeholder: String = "", edit_w: float = 190.0) -> TextField:
	var f := TextField.new()
	f.setup(label_text, value, placeholder, LABEL_W, edit_w)
	f.committed.connect(on_commit)
	return f

static func title(text_in: String) -> Label:
	return PixelKit.label(text_in, "head", PixelKit.GOLD3)

static func caption(text_in: String, color: Color = PixelKit.DIM) -> Label:
	return PixelKit.label(text_in, "body", color)

static func wrapped(text_in: String, width: float, color: Color = PixelKit.DIM) -> Label:
	return PixelKit.wrapped(text_in, width, "body", color)

static func gap(h: float = 8.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

# A row of buttons that wraps onto more lines when it would be wider than `width`.
static func button_row(buttons: Array, width: float) -> Control:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	flow.custom_minimum_size = Vector2(width, 0)
	for b in buttons:
		flow.add_child(b)
	return flow
