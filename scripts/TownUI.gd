extends RefCounted
class_name TownUI

# The look shared by the "picker" town panels (the Dojo and the Blacksmith): the
# bronze pixel-art frame, a list of entries on the left, and a detail side on the
# right. Kept in one place so the two panels stay matched.

const PixelUIScript := preload("res://scripts/PixelUI.gd")

const GOLD := Color(1.0, 0.86, 0.36)
const DIM := Color(0.68, 0.68, 0.72)
const GOOD := Color(0.55, 0.95, 0.55)
const BAD := Color(1.0, 0.5, 0.45)
const STAMINA_BLUE := Color(0.55, 0.78, 1.0)
const PIP_EMPTY := Color(0.2, 0.19, 0.24)
const LIST_WIDTH := 262.0

# The window size both pickers use, capped to leave a margin around the game view.
static func picker_window_size(viewport_size: Vector2) -> Vector2:
	return Vector2(minf(viewport_size.x - 60.0, 900.0), minf(viewport_size.y - 30.0, 610.0))

# Swaps a TownPanel's plain window for the bronze frame and restyles its title and
# Close button to match.
static func apply_bronze_frame(panel: TownPanel) -> void:
	panel.window.add_theme_stylebox_override("panel", PixelUIScript.panel_style(true))
	panel.title_label.add_theme_font_size_override("font_size", 28)
	panel.title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	panel.title_label.add_theme_color_override("font_outline_color", PixelUIScript.OUTLINE)
	panel.title_label.add_theme_constant_override("outline_size", 6)
	PixelUIScript.skin_button(panel.close_button)

# The row under the title: the shopkeeper's line on the left, your coins on the right.
# Returns {speech: Label, coins: Label}.
static func add_top_row(outer: VBoxContainer) -> Dictionary:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	outer.add_child(top)
	var speech := _label("", 13, DIM)
	speech.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(speech)
	var coin_icon := TextureRect.new()
	coin_icon.texture = load("res://assets/coin.png")
	coin_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	coin_icon.custom_minimum_size = Vector2(26, 26)
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(coin_icon)
	var coins := Label.new()
	coins.add_theme_font_size_override("font_size", 22)
	coins.add_theme_color_override("font_color", GOLD)
	coins.add_theme_color_override("font_outline_color", PixelUIScript.OUTLINE)
	coins.add_theme_constant_override("outline_size", 5)
	top.add_child(coins)
	return {"speech": speech, "coins": coins}

# The body: the scrolling list on the left under `list_heading`, a divider, and the
# detail column on the right. Returns {list: VBoxContainer, detail: VBoxContainer}.
static func add_picker_body(outer: VBoxContainer, list_heading: String) -> Dictionary:
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	outer.add_child(body)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(LIST_WIDTH, 0)
	left.add_theme_constant_override("separation", 6)
	body.add_child(left)
	left.add_child(_label(list_heading, 12, DIM))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true  # keyboard navigation scrolls the list to the focused entry
	left.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(2, 0)
	divider.color = Color(0.36, 0.27, 0.12)
	body.add_child(divider)

	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 8)
	body.add_child(detail)
	return {"list": list, "detail": detail}

static func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

static func box(bg: Color, border: Color, border_width: int, radius: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style

# An icon on a dark plate tinted with `tint` (a tier colour for weapons). icon_px is the
# icon's on-screen size; keep it a whole multiple of the art's size so it stays crisp.
static func plate(texture: Texture2D, icon_px: Vector2, tint: Color) -> PanelContainer:
	var plate_box := PanelContainer.new()
	plate_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate_box.add_theme_stylebox_override("panel", box(tint.darkened(0.82), tint.darkened(0.35), 2, 6, 3))
	var icon := TextureRect.new()
	icon.texture = texture
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size = icon_px
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate_box.add_child(icon)
	return plate_box

# One row of the left list: a plate, a title, a row of pips (gold when filled) and an
# optional tag on the right (IN HAND, WORN...). `pips` is an Array of bools.
static func make_entry(plate_box: Control, title: String, pips: Array, tag: String, tag_color: Color) -> Button:
	var entry := Button.new()
	entry.custom_minimum_size = Vector2(0, 62)
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pad := MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_%s" % side, 7)
	entry.add_child(pad)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	pad.add_child(row)
	row.add_child(plate_box)

	var text_col := VBoxContainer.new()
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.alignment = BoxContainer.ALIGNMENT_CENTER
	text_col.add_theme_constant_override("separation", 4)
	row.add_child(text_col)
	var name_label := Label.new()
	name_label.text = title
	name_label.clip_text = true
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(0.94, 0.93, 0.88))
	text_col.add_child(name_label)
	var meta := HBoxContainer.new()
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta.add_theme_constant_override("separation", 4)
	text_col.add_child(meta)
	for filled in pips:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(11, 11)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.color = GOLD if filled else PIP_EMPTY
		meta.add_child(pip)
	var meta_spacer := Control.new()
	meta_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta.add_child(meta_spacer)
	if tag != "":
		var tag_label := Label.new()
		tag_label.text = tag
		tag_label.add_theme_font_size_override("font_size", 10)
		tag_label.add_theme_color_override("font_color", tag_color)
		meta.add_child(tag_label)
	return entry

static func style_entry(button: Button, selected: bool) -> void:
	var bg: Color = Color(0.19, 0.16, 0.08, 0.98) if selected else Color(0.11, 0.11, 0.14, 0.95)
	var border: Color = GOLD if selected else Color(0.38, 0.38, 0.44)
	var width := 3 if selected else 2
	button.add_theme_stylebox_override("normal", box(bg, border, width, 6, 0))
	button.add_theme_stylebox_override("pressed", box(bg.darkened(0.12), border, width, 6, 0))
	button.add_theme_stylebox_override("hover", box(bg.lightened(0.08), border.lightened(0.3), width, 6, 0))
	var focus: StyleBoxFlat = box(Color(0, 0, 0, 0), Color(1, 1, 1, 0.9), 2, 6, 0)
	focus.set_expand_margin_all(2)
	button.add_theme_stylebox_override("focus", focus)

# The detail header: a big plate, the name in gold, and up to three lines under it.
# `lines` is an Array of [text, color, size] triples.
static func make_header(plate_box: Control, title: String, lines: Array) -> HBoxContainer:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	header.add_child(plate_box)
	var titles := VBoxContainer.new()
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 3)
	header.add_child(titles)
	var name_label := Label.new()
	name_label.text = title
	name_label.add_theme_font_size_override("font_size", 26)
	name_label.add_theme_color_override("font_color", GOLD)
	name_label.add_theme_color_override("font_outline_color", PixelUIScript.OUTLINE)
	name_label.add_theme_constant_override("outline_size", 6)
	titles.add_child(name_label)
	for line in lines:
		var label := _label(line[0], line[2], line[1])
		label.max_lines_visible = 2
		titles.add_child(label)
	return header

# The right-hand column of a card: a price (coloured by whether you can pay) over a
# skinned action button. Returns {box: VBoxContainer, button: Button}. An empty
# price_text leaves the price off (already learned, maxed...).
static func make_action(price_text: String, affordable: bool, button_text: String, disabled: bool) -> Dictionary:
	var action := VBoxContainer.new()
	action.custom_minimum_size = Vector2(122, 0)
	action.alignment = BoxContainer.ALIGNMENT_CENTER
	action.add_theme_constant_override("separation", 4)
	if price_text != "":
		var price := Label.new()
		price.text = price_text
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price.add_theme_font_size_override("font_size", 14)
		price.add_theme_color_override("font_color", GOOD if affordable else BAD)
		action.add_child(price)
	var button := Button.new()
	button.custom_minimum_size = Vector2(122, 40)
	button.text = button_text
	button.disabled = disabled
	PixelUIScript.skin_button(button)
	action.add_child(button)
	return {"box": action, "button": button}
