extends RefCounted
class_name PixelKit

# The one pixel language the new menus are built in. One art pixel is SCALE (2) screen pixels, and everything is a multiple of
# that: the icons (16 -> 32), weapon art (32 -> 64), the older 16px item art (16 -> 64), the frames (drawn by tools/gen_ui_kit.gd in
# the same style as the icons: same outline, palette ramps, top-left light) and the fonts, used at their native pixel grid with a
# hard 2px shadow. This file holds the palette, the fonts, the frames and the few widgets every screen reuses.
#
# Fonts are the free (OFL) Jersey 10 / Jersey 15 / Jacquard 12 in assets/fonts/. Jacquard's ornate blackletter is kept for a Mythic
# weapon's name alone. If a font file is missing the default font is used instead, so nothing breaks.

const UIIconsScript := preload("res://scripts/UIIcons.gd")

const SCALE := 2

# --- palette: all lifted from the icon ramps -------------------------------------------------------------------------------------------
const INK := Color("16100e")
const V0 := Color("0d0918")
const V1 := Color("1c1433")
const V2 := Color("30254f")
const V3 := Color("54419a")
const V4 := Color("8a6fdc")
const GOLD1 := Color("94661a")
const GOLD3 := Color("efc23c")
const GOLD4 := Color("fff3a8")
const CREAM := Color("f2eee4")
const DIM := Color("a39d8c")
const GOOD := Color("8be08f")
const BAD := Color("f2676a")
const BLUE := Color("7fb0ff")
const SHADOW := Color("0d0918")

# The small type under a weapon's name ("Gold · Legendary") is coloured by quality.
const QUALITY_TEXT := {
	"Starter": Color("a39d8c"), "Broken": Color("9a88b0"), "Worn": Color("d8d2c2"), "Fine": Color("cfcfd8"),
	"Masterwork": Color("7fb0ff"), "Legendary": Color("ffd84a"), "Mythic": Color("f2677f"),
}
const RARITY_COLORS := {
	"common": Color("d9d9cc"), "uncommon": Color("73d973"), "rare": Color("73a6ff"), "epic": Color("d980ff"),
}

const FONT_PATHS := {
	"body": "res://assets/fonts/Jersey10-Regular.ttf",
	"head": "res://assets/fonts/Jersey15-Regular.ttf",
	"myth": "res://assets/fonts/Jacquard12-Regular.ttf",
}
# Each font at its native grid: body 10 -> 20px, headings 15 -> 30px, blackletter 12 -> 24px (2 screen pixels per font pixel).
const FONT_SIZES := {"body": 20, "head": 30, "myth": 24}

static var _fonts := {}
static var _frames := {}

# --- fonts ----------------------------------------------------------------------------------------------------------------------------------

static func font(kind: String = "body") -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var path: String = FONT_PATHS.get(kind, FONT_PATHS.body)
	var f: Font = null
	if ResourceLoader.exists(path):
		f = load(path)
	elif FileAccess.file_exists(path):
		var raw := FontFile.new()
		raw.load_dynamic_font(path)
		f = raw
	if f is FontFile:
		# A pixel font: no smoothing, no hinting, no half-pixel placement, or its pixels blur.
		f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		f.hinting = TextServer.HINTING_NONE
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		f.generate_mipmaps = false
	if f == null:
		f = ThemeDB.fallback_font
	_fonts[kind] = f
	return f

static func font_size(kind: String = "body") -> int:
	return int(FONT_SIZES.get(kind, 20))

# A Label in the pixel type: the kind's font and size, a colour, and the hard 2px shadow every piece of text wears.
static func label(text: String, kind: String = "body", color: Color = CREAM) -> Label:
	var l := Label.new()
	l.text = text
	style_label(l, kind, color)
	return l

static func style_label(l: Label, kind: String = "body", color: Color = CREAM) -> void:
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", font_size(kind))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", SHADOW)
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("line_spacing", 0)

# A label that wraps at `width` (autofit by height).
static func wrapped(text: String, width: float, kind: String = "body", color: Color = CREAM) -> Label:
	var l := label(text, kind, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l

# --- frames ---------------------------------------------------------------------------------------------------------------------------------

# One of the 9-slice frames in assets/ui/kit (see UIIcons.KIT_MARGINS), upscaled SCALE times with no smoothing so its pixels match
# the icons', as a StyleBoxTexture whose margins are already in screen pixels. Shared and cached: duplicate() before changing one.
static func frame(frame_name: String) -> StyleBoxTexture:
	if _frames.has(frame_name):
		return _frames[frame_name]
	var sb := StyleBoxTexture.new()
	var src: Texture2D = UIIconsScript.kit(frame_name)
	if src != null:
		var img: Image = src.get_image()
		img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
		sb.texture = ImageTexture.create_from_image(img)
		var m: int = int(UIIconsScript.KIT_MARGINS.get(frame_name, 4)) * SCALE
		sb.texture_margin_left = m
		sb.texture_margin_right = m
		sb.texture_margin_top = m
		sb.texture_margin_bottom = m
	_frames[frame_name] = sb
	return sb

# A frame with extra breathing room inside (content margins in screen pixels, on top of the frame's own border).
static func padded(frame_name: String, pad_x: float, pad_y: float) -> StyleBoxTexture:
	var sb: StyleBoxTexture = frame(frame_name).duplicate()
	sb.content_margin_left = sb.texture_margin_left + pad_x
	sb.content_margin_right = sb.texture_margin_right + pad_x
	sb.content_margin_top = sb.texture_margin_top + pad_y
	sb.content_margin_bottom = sb.texture_margin_bottom + pad_y
	return sb

# A PanelContainer wearing a frame ("panel" for the window, "panel_steel" for a panel inside it, "inset" for a sunken box).
static func panel(frame_name: String = "panel_steel", pad_x: float = 0.0, pad_y: float = 0.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", padded(frame_name, pad_x, pad_y) if pad_x != 0.0 or pad_y != 0.0 else frame(frame_name))
	return p

# A plain Panel (no container sizing) wearing a frame, for things placed by position.
static func panel_box(frame_name: String) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", frame(frame_name))
	return p

# --- pictures -------------------------------------------------------------------------------------------------------------------------------

# A UI icon (stat_*, tab_*, sub_*, pin_*, face_*) at `px` screen pixels square: 32 = 2x.
static func icon(icon_name: String, px: int = 32) -> TextureRect:
	return UIIconsScript.rect(icon_name, px)

# Any picture at `px` screen pixels square (64 for weapon art at 2x and the 16px art at 4x), crisp.
static func art(texture: Texture2D, px: int = 64) -> TextureRect:
	var r := TextureRect.new()
	r.texture = texture
	r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

# A texture from a res:// path (imported, or a raw PNG just dropped in), or null.
static func texture_at(path: String) -> Texture2D:
	if path == "":
		return null
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		return ImageTexture.create_from_image(img) if img != null else null
	return null

# --- small pieces ---------------------------------------------------------------------------------------------------------------------------

# The little badge on a card (its number, who wears it).
static func chip(text: String, color: Color = GOLD3) -> PanelContainer:
	var c := PanelContainer.new()
	c.add_theme_stylebox_override("panel", padded("chip", 2, 0))
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(text, "body", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(l)
	return c

# A two-tone rule between rows of a list.
static func rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color("241a3f")
	r.custom_minimum_size = Vector2(0, 2)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

# A flat pixel bar (XP, volume): a sunken track with a lit fill, `ratio` 0..1.
static func bar(width: float, ratio: float, fill: Color = BLUE) -> Control:
	var track := panel("inset")
	track.custom_minimum_size = Vector2(width, 32)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 16)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(holder)
	var fill_rect := ColorRect.new()
	fill_rect.color = fill
	fill_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill_rect.anchor_right = clampf(ratio, 0.0, 1.0)
	holder.add_child(fill_rect)
	var lip := ColorRect.new()
	lip.color = fill.lightened(0.45)
	lip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	lip.anchor_right = clampf(ratio, 0.0, 1.0)
	lip.offset_bottom = 4
	holder.add_child(lip)
	return track

# Pixel scroll bars for a ScrollContainer: a sunken track and a raised grabber, 16px wide.
static func style_scroll(scroll: ScrollContainer) -> void:
	# A ScrollContainer leaves room for its bar by the bar's own minimum size (the width of its arrow icons), not by a custom minimum,
	# so the arrows become blank 20px-wide strips: the bar then takes its 20px out of the content instead of lying on top of it.
	var blank_v := _blank_icon(20, 1)
	var blank_h := _blank_icon(1, 20)
	for bar_node in [scroll.get_v_scroll_bar(), scroll.get_h_scroll_bar()]:
		var track: StyleBoxTexture = frame("inset").duplicate()
		var grab: StyleBoxTexture = frame("button").duplicate()
		bar_node.add_theme_stylebox_override("scroll", track)
		bar_node.add_theme_stylebox_override("grabber", grab)
		bar_node.add_theme_stylebox_override("grabber_highlight", frame("button_hover"))
		bar_node.add_theme_stylebox_override("grabber_pressed", frame("button_press"))
		bar_node.custom_minimum_size = Vector2(20, 20)
		var blank: ImageTexture = blank_v if bar_node is VScrollBar else blank_h
		for icon_name in ["increment", "increment_highlight", "increment_pressed", "decrement", "decrement_highlight", "decrement_pressed"]:
			bar_node.add_theme_icon_override(icon_name, blank)

static func _blank_icon(w: int, h: int) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)

# A slider in the pixel kit: a sunken track, a gold fill, and a small gold block for a handle (drawn here, upscaled with no smoothing).
static var _grabber: ImageTexture = null

static func grabber_texture() -> ImageTexture:
	if _grabber != null:
		return _grabber
	var w := 8
	var h := 16
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			var edge: bool = x == 0 or y == 0 or x == w - 1 or y == h - 1
			if (x == 0 or x == w - 1) and (y == 0 or y == h - 1):
				continue
			var c := INK
			if not edge:
				c = GOLD4 if (x == 1 or y == 1) else (GOLD1 if (x == w - 2 or y == h - 2) else GOLD3)
			img.set_pixel(x, y, c)
	img.resize(w * SCALE, h * SCALE, Image.INTERPOLATE_NEAREST)
	_grabber = ImageTexture.create_from_image(img)
	return _grabber

static func style_slider(slider: HSlider) -> void:
	slider.add_theme_stylebox_override("slider", padded("inset", 0, 8))
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD3
	fill.content_margin_top = 8
	fill.content_margin_bottom = 8
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	for icon_name in ["grabber", "grabber_highlight", "grabber_disabled"]:
		slider.add_theme_icon_override(icon_name, grabber_texture())
	slider.custom_minimum_size = Vector2(0, 40)

# What quality a weapon shows its glow for: its tier name, or "Starter" for the Club (no tier).
static func quality_of(weapon: Dictionary) -> String:
	return str(weapon.get("tier_name", "")) if str(weapon.get("tier_name", "")) != "" else "Starter"
