extends Panel
class_name InvCard

# A card in the inventory grid: a framed slot with the picture on a plate (the quality's rays turning behind it, for a weapon), a
# number badge at the top right, who else wears it at the top left, and the name along the bottom (a Mythic's name in the ornate
# blackletter; everything else in the plain pixel type). The frame says its state: steel at rest, brighter on hover, white while
# worn by the unit being dressed, gold when it is the one picked.
#
# Also builds the smaller framed tiles (the picture on the detail card, an Equipment slot) with the same plate-and-rays recipe.

signal pressed
signal double_pressed

const SIZE := Vector2(128, 152)
const PLATE := Vector2(104, 84)
const NAME_H := 44.0
const ART_PX := 64

var picked := false:
	set(v):
		picked = v
		_apply_frame()
var worn := false:
	set(v):
		worn = v
		_apply_frame()
var _hover := false
var info: Dictionary = {}

# info: {name, art: Texture2D, quality, key, number: String, holder: String (the other holder's name, "" for none),
#        dim: bool, tint: Color (the plate colour for things with no quality: potions, food), mythic: bool}
func setup(card_info: Dictionary) -> void:
	info = card_info
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = str(info.get("tooltip", ""))
	var inner := Control.new()
	inner.position = Vector2(12, 12)
	inner.size = SIZE - Vector2(24, 24)
	inner.clip_contents = true
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(inner)
	var bg := ColorRect.new()
	bg.color = PixelKit.V1
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(bg)
	var plate := InvCard.plate(info, PLATE, 28.0)
	inner.add_child(plate)
	var number := str(info.get("number", ""))
	if number != "":
		var chip := PixelKit.chip(number)
		chip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		chip.offset_top = 2
		chip.offset_right = -2
		inner.add_child(chip)
	var holder := str(info.get("holder", ""))
	if holder != "":
		var initial := PixelKit.chip(holder.substr(0, 1))
		initial.position = Vector2(2, 2)
		initial.tooltip_text = "With %s" % holder
		inner.add_child(initial)
	# wrapping and the minimum width go on before the size, or the label first grows to the whole unwrapped name
	var name_text := str(info.get("name", ""))
	var name_kind := "myth" if bool(info.get("mythic", false)) else "body"
	if name_kind == "myth" and _text_width(name_text, "myth") > PLATE.x:
		name_kind = "body"   # the ornate type is too tall for two lines: a name that won't fit on one falls back to the plain type (still maroon)
	var name_label := PixelKit.label(name_text, name_kind, PixelKit.QUALITY_TEXT.Mythic if bool(info.get("mythic", false)) else PixelKit.CREAM)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(PLATE.x, NAME_H)
	name_label.clip_text = true
	name_label.position = Vector2(0, PLATE.y)
	name_label.size = Vector2(PLATE.x, NAME_H)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(name_label)
	modulate = Color(1, 1, 1, 0.55) if bool(info.get("dim", false)) else Color(1, 1, 1, 1)
	mouse_entered.connect(func(): _hover = true; _apply_frame())
	mouse_exited.connect(func(): _hover = false; _apply_frame())
	_apply_frame()

static func _text_width(text: String, kind: String) -> float:
	return PixelKit.font(kind).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, PixelKit.font_size(kind)).x

func _apply_frame() -> void:
	var frame_name := "card"
	if worn and picked:
		frame_name = "card_worn_pick"
	elif picked:
		frame_name = "card_pick"
	elif worn:
		frame_name = "card_worn"
	elif _hover:
		frame_name = "card_hover"
	add_theme_stylebox_override("panel", PixelKit.frame(frame_name))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click:
			double_pressed.emit()
		else:
			pressed.emit()
		accept_event()

# --- shared recipes -------------------------------------------------------------------------------------------------------------------

# The picture on its plate: the quality's faint disc, the turning rays, then the art (64px: weapon art at 2x, the 16px art at 4x,
# icons at 4x). `area` is the plate's size in screen pixels, `half_art` the ray ring's radius in art pixels.
static func plate(card_info: Dictionary, area: Vector2, half_art: float) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = area
	holder.size = area
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var quality := str(card_info.get("quality", ""))
	var disc := ColorRect.new()
	disc.color = PixelRays.plate_color(quality) if quality != "" else Color(card_info.get("tint", Color(0, 0, 0, 0)))
	disc.set_anchors_preset(Control.PRESET_FULL_RECT)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(disc)
	if PixelRays.has_rays(quality):
		var rays := PixelRays.make(quality, str(card_info.get("key", card_info.get("name", ""))), area, half_art)
		holder.add_child(rays)
	var tex: Texture2D = card_info.get("art", null)
	if tex != null:
		var art_rect := PixelKit.art(tex, ART_PX)
		art_rect.position = ((area - Vector2(ART_PX, ART_PX)) / 2.0).floor()
		art_rect.modulate = Color(0.55, 0.55, 0.6) if bool(card_info.get("dim_art", false)) else Color(1, 1, 1)
		holder.add_child(art_rect)
	return holder

# A framed square tile holding a picture on its plate: the detail card's emblem, an Equipment slot. `outer` is the tile's side in
# screen pixels, `frame_name` one of the card frames.
static func tile(card_info: Dictionary, outer: int, frame_name: String = "card", half_art: float = 22.0) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(outer, outer)
	p.size = Vector2(outer, outer)
	p.add_theme_stylebox_override("panel", PixelKit.frame(frame_name))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := float(PixelKit.frame(frame_name).texture_margin_left)
	var inner := Control.new()
	inner.position = Vector2(m, m)
	inner.size = Vector2(outer, outer) - Vector2(m, m) * 2.0
	inner.clip_contents = true
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(inner)
	var bg := ColorRect.new()
	bg.color = PixelKit.V1
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(bg)
	inner.add_child(InvCard.plate(card_info, inner.size, half_art))
	return p
