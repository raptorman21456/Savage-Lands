extends RefCounted

# Procedurally drawn pixel-art UI skins, shared by the title screen and the
# Church: a beveled bronze frame with rivets and chamfered corners around a
# banded gradient fill, as 9-slice StyleBoxTextures. Nothing to import -- each
# skin is built once from a tiny Image and cached. The project's default
# texture filter is Nearest, so the small source pixels scale up crisp and the
# gradient reads as a few retro colour bands rather than a smooth blend.

const BUTTON_SIZE := 20
const PIXEL_SCALE := 2
const BUTTON_MARGIN := 6 * PIXEL_SCALE
const PANEL_SIZE := 24
const PANEL_MARGIN := 9 * PIXEL_SCALE

const OUTLINE := Color(0.05, 0.03, 0.07)

static var _cache := {}

# kind: "normal", "hover", "pressed", "disabled" or "focus" (a bare gold ring
# drawn over whichever of the others is showing).
static func button_style(kind: String) -> StyleBoxTexture:
	var key := "button_%s" % kind
	if not _cache.has(key):
		var sb := StyleBoxTexture.new()
		sb.texture = ImageTexture.create_from_image(_scaled(_button_image(kind)))
		sb.texture_margin_left = BUTTON_MARGIN
		sb.texture_margin_right = BUTTON_MARGIN
		sb.texture_margin_top = BUTTON_MARGIN
		sb.texture_margin_bottom = BUTTON_MARGIN
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		_cache[key] = sb
	return _cache[key]

# The framed window every menu screen sits in: a double bronze frame with gold
# corner studs around a dark, slightly translucent fill.
static func panel_style(opaque: bool = false) -> StyleBoxTexture:
	var key := "panel_opaque" if opaque else "panel"
	if not _cache.has(key):
		var sb := StyleBoxTexture.new()
		sb.texture = ImageTexture.create_from_image(_scaled(_panel_image(opaque)))
		sb.texture_margin_left = PANEL_MARGIN
		sb.texture_margin_right = PANEL_MARGIN
		sb.texture_margin_top = PANEL_MARGIN
		sb.texture_margin_bottom = PANEL_MARGIN
		sb.content_margin_left = 30
		sb.content_margin_right = 30
		sb.content_margin_top = 22
		sb.content_margin_bottom = 22
		_cache[key] = sb
	return _cache[key]

# Applies the full skin (all five states plus a legible outlined label) to any
# Button.
static func skin_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", button_style("normal"))
	button.add_theme_stylebox_override("hover", button_style("hover"))
	button.add_theme_stylebox_override("pressed", button_style("pressed"))
	button.add_theme_stylebox_override("disabled", button_style("disabled"))
	button.add_theme_stylebox_override("focus", button_style("focus"))
	button.add_theme_color_override("font_color", Color(0.93, 0.9, 0.82))
	button.add_theme_color_override("font_disabled_color", Color(0.5, 0.48, 0.45))
	button.add_theme_color_override("font_outline_color", OUTLINE)
	button.add_theme_constant_override("outline_size", 4)

static func _button_image(kind: String) -> Image:
	var n := BUTTON_SIZE
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var frame_hi := Color(0.88, 0.7, 0.34)
	var frame_mid := Color(0.62, 0.48, 0.2)
	var frame_lo := Color(0.34, 0.24, 0.1)
	var inner := Color(0.1, 0.07, 0.05)
	var fill_top := Color(0.22, 0.2, 0.3)
	var fill_bottom := Color(0.09, 0.08, 0.14)
	var rivet := Color(0.95, 0.8, 0.45)
	match kind:
		"hover":
			frame_hi = Color(1.0, 0.94, 0.5)
			frame_mid = Color(1.0, 0.82, 0.24)
			frame_lo = Color(0.7, 0.48, 0.1)
			inner = Color(0.42, 0.27, 0.06)
			fill_top = Color(0.42, 0.29, 0.12)
			fill_bottom = Color(0.16, 0.1, 0.05)
			rivet = Color(1.0, 0.96, 0.7)
		"pressed":
			frame_hi = Color(0.34, 0.24, 0.1)
			frame_mid = Color(0.62, 0.48, 0.2)
			frame_lo = Color(0.88, 0.7, 0.34)
			inner = Color(0.05, 0.03, 0.02)
			fill_top = Color(0.07, 0.06, 0.1)
			fill_bottom = Color(0.16, 0.12, 0.08)
			rivet = Color(0.6, 0.48, 0.25)
		"disabled":
			frame_hi = Color(0.32, 0.31, 0.33)
			frame_mid = Color(0.24, 0.23, 0.25)
			frame_lo = Color(0.16, 0.15, 0.17)
			inner = Color(0.08, 0.08, 0.09)
			fill_top = Color(0.11, 0.11, 0.13)
			fill_bottom = Color(0.07, 0.07, 0.09)
			rivet = Color(0.28, 0.27, 0.3)
		"focus":
			frame_hi = Color(1.0, 0.9, 0.2)
			frame_mid = Color(1.0, 0.9, 0.2)
			frame_lo = Color(1.0, 0.9, 0.2)
	for y in n:
		for x in n:
			var cx: int = mini(x, n - 1 - x)
			var cy: int = mini(y, n - 1 - y)
			# Chamfered corners: the three outermost pixels of each corner are
			# left transparent.
			if cx + cy < 2:
				continue
			var d: int = mini(cx, cy)
			var top_left: bool = mini(x, y) <= mini(n - 1 - x, n - 1 - y)
			var color := Color(0, 0, 0, 0)
			if kind == "focus":
				# Just a two-pixel gold ring around the edge.
				if d <= 1:
					color = frame_mid
			elif d == 0:
				color = OUTLINE
			elif d == 1:
				color = frame_hi if top_left else frame_lo
			elif d == 2:
				color = frame_mid
			elif d == 3:
				color = inner
			else:
				color = fill_top.lerp(fill_bottom, float(y - 4) / float(n - 9))
			img.set_pixel(x, y, color)
	if kind != "focus":
		for corner in [Vector2i(4, 4), Vector2i(n - 5, 4), Vector2i(4, n - 5), Vector2i(n - 5, n - 5)]:
			img.set_pixelv(corner, rivet)
	return img

static func _panel_image(opaque: bool = false) -> Image:
	var n := PANEL_SIZE
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var gold := Color(1.0, 0.86, 0.34)
	var bronze_hi := Color(0.86, 0.68, 0.32)
	var bronze := Color(0.58, 0.44, 0.18)
	var bronze_lo := Color(0.3, 0.21, 0.08)
	var fill := Color(0.04, 0.03, 0.09, 1.0 if opaque else 0.84)
	for y in n:
		for x in n:
			var cx: int = mini(x, n - 1 - x)
			var cy: int = mini(y, n - 1 - y)
			var d: int = mini(cx, cy)
			var top_left: bool = mini(x, y) <= mini(n - 1 - x, n - 1 - y)
			var color := fill
			if d == 0:
				color = OUTLINE
			elif d == 1:
				color = bronze_hi if top_left else bronze_lo
			elif d == 2:
				color = bronze
			elif d == 3:
				color = OUTLINE
			elif d == 4:
				# A thin second frame just inside the first.
				color = bronze if not top_left else bronze_hi
			elif d == 5:
				color = Color(0.07, 0.05, 0.1, 1.0 if opaque else 0.9)
			img.set_pixel(x, y, color)
	# Gold studs in the four corners (inside the 9-slice's fixed corner cells).
	for corner in [Vector2i(3, 3), Vector2i(n - 4, 3), Vector2i(3, n - 4), Vector2i(n - 4, n - 4)]:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var p: Vector2i = corner + Vector2i(dx, dy)
				var stud: Color = gold if (dx == 0 and dy == 0) else bronze_hi
				img.set_pixelv(p, stud)
	return img

# Blows a skin's source image up by PIXEL_SCALE with no smoothing, so its
# bevels and rivets come out as chunky as the rest of the game's pixel art.
static func _scaled(img: Image) -> Image:
	img.resize(img.get_width() * PIXEL_SCALE, img.get_height() * PIXEL_SCALE, Image.INTERPOLATE_NEAREST)
	return img
