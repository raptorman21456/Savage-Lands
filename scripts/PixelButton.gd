extends PanelContainer
class_name PixelButton

# A button made of the pixel kit's frames: a raised violet plaque that lights up on hover, sinks when pressed, and turns gold when it
# is the one chosen (`on`). It is exactly as wide as its icon (2x) and its words -- it never cuts a word short with an ellipsis. It
# reports `pressed` on release, like a Button.

signal pressed

var _label: Label = null
var _icon: TextureRect = null
var _row: HBoxContainer = null
var _hover := false
var _down := false
var on := false:
	set(v):
		on = v
		_restyle()
var disabled := false:
	set(v):
		disabled = v
		modulate = Color(1, 1, 1, 0.5) if v else Color(1, 1, 1, 1)
		mouse_default_cursor_shape = Control.CURSOR_ARROW if v else Control.CURSOR_POINTING_HAND
		_restyle()
var text: String = "":
	get:
		return _label.text if _label != null else ""
	set(v):
		if _label != null:
			_label.text = v
			_label.visible = v != ""

static func make(text_in: String, icon_name: String = "", on_pressed: Callable = Callable(), is_on: bool = false) -> PixelButton:
	var b := PixelButton.new()
	b._build(text_in, icon_name)
	b.on = is_on
	if on_pressed.is_valid():
		b.pressed.connect(on_pressed)
	return b

func _build(text_in: String, icon_name: String) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 8)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_row)
	if icon_name != "":
		_icon = PixelKit.icon(icon_name, 32)
		_row.add_child(_icon)
	_label = PixelKit.label(text_in)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.visible = text_in != ""
	_row.add_child(_label)
	mouse_entered.connect(func(): _hover = true; _restyle())
	mouse_exited.connect(func(): _hover = false; _down = false; _restyle())
	_restyle()

func _frame_name() -> String:
	if _down and not disabled:
		return "button_press"
	if on:
		return "button_on"
	if _hover and not disabled:
		return "button_hover"
	return "button"

func _restyle() -> void:
	if _label == null:
		return
	add_theme_stylebox_override("panel", PixelKit.padded(_frame_name(), 6, 0))
	_label.add_theme_color_override("font_color", PixelKit.GOLD4 if on else PixelKit.CREAM)

func _gui_input(event: InputEvent) -> void:
	if disabled or not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		_down = true
		_restyle()
	else:
		var was_down := _down
		_down = false
		_restyle()
		if was_down and get_rect().size.x > 0.0 and Rect2(Vector2.ZERO, size).has_point(event.position):
			pressed.emit()
	accept_event()
