extends RefCounted
class_name BattleStyle

# The look of the battle screen -- dark fantasy panels: near-black plum, bronze-gold frames, parchment text, corners cut
# straight and drawn without smoothing (no rounding, no anti-aliasing, no soft shadows: it has to sit beside the pixel art).
# One place for the colours and the corner cut so the screen (HUD.gd), the dodge/block popup and the weapon attack popup all read
# as one thing.

const PANEL_BG := Color(0.09, 0.08, 0.12, 0.97)
const PANEL_BORDER := Color(0.62, 0.48, 0.2, 1.0)
const PANEL_TRIM := Color(0.29, 0.23, 0.11, 1.0)
const GOLD := Color(0.88, 0.72, 0.29)
const ALLY_BLUE := Color(0.35, 0.63, 1.0)
const ENEMY_RED := Color(0.88, 0.31, 0.35)
const TEXT := Color(0.91, 0.86, 0.75)
const DIM := Color(0.6, 0.56, 0.47)
const GOOD := Color(0.5, 1.0, 0.6)
const BAD := Color(1.0, 0.4, 0.35)

# How much of each corner is cut off, in pixels (the one knob for "blocky" vs "sleek"): panels, cards, popups and lists get CORNER;
# buttons, portrait frames, chips and tiles get CORNER_SMALL. Bars are square.
const CORNER := 6
const CORNER_SMALL := 3

# The size of the timing popups (dodge, block, attack) and where they sit: the right-hand column, clear of the grid, above the bottom bar.
const POPUP_SIZE := Vector2(320, 244)
const POPUP_CANVAS_POS := Vector2(12, 78)
const POPUP_CANVAS_SIZE := Vector2(296, 150)

# The pixel look for any StyleBoxFlat: the corners cut off straight (a single segment, not a curve) and drawn without anti-aliasing,
# so an edge is a hard staircase of pixels rather than a smooth blend.
static func chamfer(sb: StyleBoxFlat, radius: int) -> StyleBoxFlat:
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 1
	sb.anti_aliasing = false
	return sb

# A box with cut corners. `shadow` is kept for the callers that float a panel, but a floating panel no longer wears a soft drop shadow:
# a blurred shadow is exactly the smoothness the pixel look rules out.
static func box(bg: Color, border: Color, border_width: int, radius: int, _shadow: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	return chamfer(sb, radius)

# The frame every battle panel wears: cut corners and a thin bronze border.
static func panel_style(border: Color = PANEL_BORDER, border_width: int = 1, radius: int = CORNER, shadow: bool = true) -> StyleBoxFlat:
	return box(PANEL_BG, border, border_width, radius, shadow)

# Where a timing popup sits for a window of this size.
static func popup_position(view: Vector2, size: Vector2 = POPUP_SIZE) -> Vector2:
	return Vector2(view.x - size.x - 24.0, view.y - 14.0 - 30.0 - 12.0 - size.y).round()
