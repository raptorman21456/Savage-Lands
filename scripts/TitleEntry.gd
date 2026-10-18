extends Button
class_name TitleEntry

# One choice on the title screens, in the pixel kit. It is a real Button underneath, so the keyboard does the work: the arrow keys move
# between entries, Enter / Space / Z take the one chosen, and the mouse choosing is just hovering it (hover grabs the focus). Three looks:
#   "text"  big plain words with a gold cursor either side of the chosen one (the main menu, like Hollow Knight's)
#   "row"   a framed bar (difficulty, the file options); its frame goes gold when it is the chosen one
#   "card"  a framed card whose contents the caller builds inside it (the file select)
# `chosen_changed(on)` tells whoever built a card's insides to recolour them. The Button's own text is kept (readers and tests use it)
# but drawn invisible: the pixel label on top is what you see, with the kit's hard shadow.

signal chosen_changed(on: bool)

const CURSOR_PX := 32.0

var kind := "text"
var description := ""
var _face: Label = null
var _cursor_left: TextureRect = null
var _cursor_right: TextureRect = null

static func make(text_in: String, entry_kind: String = "text", on_pressed: Callable = Callable(), desc: String = "", min_size: Vector2 = Vector2.ZERO) -> TitleEntry:
	var e := TitleEntry.new()
	e._build(text_in, entry_kind, desc, min_size)
	if on_pressed.is_valid():
		e.pressed.connect(on_pressed)
	return e

func _build(text_in: String, entry_kind: String, desc: String, min_size: Vector2) -> void:
	kind = entry_kind
	description = desc
	text = text_in
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = min_size
	if kind == "text":
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for color_name in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color", "font_disabled_color"]:
		add_theme_color_override(color_name, Color(0, 0, 0, 0))
	var empty := StyleBoxEmpty.new()
	match kind:
		"row":
			_styles("button", "button_hover", "button_on", "button_press")
		"card":
			_styles("card", "card_hover", "card_pick", "card_pick")
		_:
			for state_name in ["normal", "hover", "pressed", "focus", "disabled"]:
				add_theme_stylebox_override(state_name, empty)
	if kind != "card":
		_face = PixelKit.label(text_in, "big" if kind == "text" else "head", PixelKit.CREAM)
		_face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_face.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# the words, centred; a text entry has a gold pointer either side that shows only while it is the one chosen (the space is always
		# kept, so choosing never moves the words)
		var line := HBoxContainer.new()
		line.set_anchors_preset(Control.PRESET_FULL_RECT)
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		line.add_theme_constant_override("separation", 14)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(line)
		if kind == "text":
			_cursor_left = PixelKit.icon("ui_cursor", int(CURSOR_PX))
			line.add_child(_cursor_left)
		line.add_child(_face)
		if kind == "text":
			_cursor_right = PixelKit.icon("ui_cursor", int(CURSOR_PX))
			_cursor_right.flip_h = true
			line.add_child(_cursor_right)
	mouse_entered.connect(_on_mouse_entered)
	focus_entered.connect(_on_focus_changed.bind(true))
	focus_exited.connect(_on_focus_changed.bind(false))
	_recolor()

func _styles(normal_frame: String, hover_frame: String, focus_frame: String, press_frame: String) -> void:
	add_theme_stylebox_override("normal", PixelKit.frame(normal_frame))
	add_theme_stylebox_override("hover", PixelKit.frame(hover_frame))
	add_theme_stylebox_override("focus", PixelKit.frame(focus_frame))
	add_theme_stylebox_override("pressed", PixelKit.frame(press_frame))
	add_theme_stylebox_override("disabled", PixelKit.frame(normal_frame))

# Changes the words on the entry (the Button's own text too, which tests and readers use).
func set_face_text(new_text: String) -> void:
	text = new_text
	if _face != null:
		_face.text = new_text
	queue_redraw()

func chosen() -> bool:
	return has_focus()

func _on_mouse_entered() -> void:
	if not disabled and is_visible_in_tree():
		grab_focus()

func _on_focus_changed(on: bool) -> void:
	_recolor()
	queue_redraw()
	chosen_changed.emit(on)

func _recolor() -> void:
	if _face == null:
		return
	var on := has_focus()
	if _cursor_left != null:
		_cursor_left.modulate.a = 1.0 if on else 0.0
		_cursor_right.modulate.a = 1.0 if on else 0.0
	if kind == "text":
		_face.add_theme_color_override("font_color", PixelKit.GOLD4 if on else Color(0.82, 0.78, 0.70))
	else:
		_face.add_theme_color_override("font_color", PixelKit.GOLD4 if on else PixelKit.CREAM)
