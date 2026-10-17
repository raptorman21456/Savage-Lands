extends VBoxContainer
class_name SpecialsBox

# A weapon's (or a member's) specials as a short list with ONE description box under it, showing whichever you hover or click -- the
# pointing arrow marks the one being read. A special that is not usable yet (the hero has not learned it at the Dojo) is greyed, shows
# why on the right instead of its cost, and says so at the top of its description.
#
# specials: [{n, c (cost text), d (description), lock (text shown instead of the cost, "" = usable), hint (put before d when locked)}]

signal picked(index: int)

var _rows: Array = []
var _list: Array = []
var _box: PanelContainer = null
var selected := 0

func setup(specials: Array, start_index: int = 0) -> void:
	_list = specials
	add_theme_constant_override("separation", 0)
	selected = clampi(start_index, 0, maxi(0, specials.size() - 1))
	if specials.is_empty():
		add_child(PixelKit.label("No specials.", "body", PixelKit.DIM))
		return
	for i in specials.size():
		var s: Dictionary = specials[i]
		var row := PanelContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var inner := HBoxContainer.new()
		inner.name = "Row"
		inner.add_theme_constant_override("separation", 8)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(inner)
		var cursor := PixelKit.icon("ui_cursor", 32)
		cursor.name = "Cursor"
		inner.add_child(cursor)
		var locked: bool = str(s.get("lock", "")) != ""
		var name_label := PixelKit.label(str(s.get("n", "")), "body", PixelKit.DIM if locked else PixelKit.CREAM)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(name_label)
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(spacer)
		var cost := PixelKit.label(str(s.get("lock", s.get("c", ""))), "body", PixelKit.BAD if locked else PixelKit.DIM)
		cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(cost)
		row.mouse_entered.connect(select.bind(i))
		row.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: select(i))
		add_child(row)
		_rows.append(row)
	_box = InvWidgets.desc_box("", PixelKit.CREAM, 76)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	add_child(gap)
	add_child(_box)
	select(selected)

func select(index: int) -> void:
	if _list.is_empty():
		return
	selected = clampi(index, 0, _list.size() - 1)
	for i in _rows.size():
		var on: bool = i == selected
		_rows[i].add_theme_stylebox_override("panel", PixelKit.padded("button", 0, 0) if on else StyleBoxEmpty.new())
		_rows[i].get_node("Row/Cursor").modulate = Color(1, 1, 1, 1) if on else Color(1, 1, 1, 0)
	var s: Dictionary = _list[selected]
	var text := str(s.get("d", ""))
	if str(s.get("lock", "")) != "" and str(s.get("hint", "")) != "":
		text = str(s.hint) + " " + text
	_box.get_meta("label").text = text
	picked.emit(selected)
