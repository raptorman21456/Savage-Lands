extends CanvasLayer
class_name TownPanel

# Shared shell for the town's venue panels (Dojo, Blacksmith, Butcher, Flea
# Market, Seer, Wishing Well, Horse Races, Fishing) -- the same overlay shape
# HealerPanel/TavernPanel/QuestBoardPanel each build by hand (CanvasLayer at
# layer 30, scrim, framed window, title row + Close button, _was_paused
# snapshot/restore on open/close), pulled up here so eight more panels don't
# each carry their own ~50 copied lines. The older panels are deliberately
# left alone.
#
# Subclasses override the small virtual hooks below; Main owns one instance of
# each (see Main.gd:town_panels) and closes whichever is open on Escape.

var _was_paused := false
var _player: Player = null
var window: Panel
var title_label: Label
var close_button: Button
# Rows/sections for the subclass to fill in _build_content.
var content: VBoxContainer

# --- Hooks subclasses override -------------------------------------------

func _panel_title() -> String:
	return "TOWN"

func _window_size() -> Vector2:
	return Vector2(560, 420)

func _build_content(_outer: VBoxContainer) -> void:
	pass

# Rebuild/refresh whatever the panel shows -- called on open() and by the
# subclass after any purchase or state change.
func _refresh() -> void:
	pass

func _on_opened() -> void:
	pass

func _on_closing() -> void:
	pass

# A panel that is mid-animation (a race, a fish on the line) can veto being
# closed -- Escape and the Close button both go through this.
func can_close() -> bool:
	return true

# --- Shell -----------------------------------------------------------------

func _ready() -> void:
	layer = 30
	visible = false
	_build_shell()
	_build_content(content)

func _build_shell() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.75)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)

	var window_size := _window_size()
	window = Panel.new()
	window.size = window_size
	var window_style := StyleBoxFlat.new()
	window_style.bg_color = Color(0.08, 0.08, 0.1)
	window_style.border_color = Color(0.4, 0.4, 0.45)
	window_style.set_border_width_all(3)
	window.add_theme_stylebox_override("panel", window_style)
	scrim.add_child(window)
	window.position = ((get_viewport().get_visible_rect().size - window_size) / 2).round()

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 20)
	window.add_child(margin)

	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	var title_row := HBoxContainer.new()
	content.add_child(title_row)
	title_label = Label.new()
	title_label.text = _panel_title()
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	title_row.add_child(title_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(spacer)
	close_button = Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(close)
	title_row.add_child(close_button)

func open(player_ref: Player) -> void:
	_player = player_ref
	# A second open() while already showing (two door triggers overlapping, or
	# a stray re-entry) must not re-snapshot _was_paused -- it would read the
	# already-paused tree and the panel would never restore the real state.
	if visible:
		_refresh()
		return
	_was_paused = get_tree().paused
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_refresh()
	visible = true
	_on_opened()

func close() -> void:
	if not visible or not can_close():
		return
	_on_closing()
	visible = false
	get_tree().paused = _was_paused

# --- Small shared helpers ------------------------------------------------

func _play_sfx(sfx_name: String) -> void:
	var parent := get_parent()
	if parent != null and parent.has_method("play_sfx"):
		parent.play_sfx(sfx_name)

func _make_label(text: String, font_size: int = 14, color: Color = Color(0.85, 0.85, 0.8)) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

# One "icon | name + blurb | price | action button" row -- what every vendor
# panel (Butcher, Baker, Tailor, Blacksmith, Seer, Dojo...) lists its wares as.
# icon_name is an assets/ filename stem; a missing icon just leaves the slot
# blank rather than erroring (same tolerance InventoryPanel's grid cells have).
func _make_shop_row(icon_name: String, title: String, description: String, price_text: String, button_text: String, button_disabled: bool, on_press: Callable, highlight: bool = false) -> PanelContainer:
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.12, 0.15, 0.92)
	style.border_color = Color(1.0, 0.85, 0.2) if highlight else Color(0.4, 0.4, 0.45)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	row.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	row.add_child(hbox)

	var icon_slot := Control.new()
	icon_slot.custom_minimum_size = Vector2(40, 40)
	hbox.add_child(icon_slot)
	var icon_path := "res://assets/%s.png" % icon_name
	if icon_name != "" and ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.texture = load(icon_path)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_slot.add_child(icon)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 2)
	hbox.add_child(text_box)
	var title_label_row := Label.new()
	title_label_row.text = title
	title_label_row.add_theme_font_size_override("font_size", 16)
	title_label_row.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if highlight else Color(0.92, 0.92, 0.88))
	text_box.add_child(title_label_row)
	text_box.add_child(_make_label(description, 12, Color(0.7, 0.7, 0.65)))

	if price_text != "":
		var price_label := Label.new()
		price_label.text = price_text
		price_label.add_theme_font_size_override("font_size", 14)
		price_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		price_label.custom_minimum_size = Vector2(64, 0)
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hbox.add_child(price_label)

	var button := Button.new()
	button.text = button_text
	button.disabled = button_disabled
	button.custom_minimum_size = Vector2(96, 32)
	if on_press.is_valid():
		button.pressed.connect(on_press)
	hbox.add_child(button)
	return row

# Blanks every child of a container -- the "queue_free and rebuild" refresh
# idiom the older panels use.
func _clear(container: Node) -> void:
	for child in container.get_children():
		# Detached first so the old rows vanish this frame instead of sitting
		# beside their replacements until queue_free actually runs.
		container.remove_child(child)
		child.queue_free()
