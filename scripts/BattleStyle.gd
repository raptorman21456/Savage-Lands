extends RefCounted
class_name BattleStyle

# The look of the battle screen -- dark fantasy panels: near-black plum, bronze-gold frames, parchment text, softly rounded
# with a gentle shadow under anything that floats. One place for the colours and the roundness so the screen (HUD.gd), the
# dodge/block popup and the weapon attack popup all read as one thing.

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

# How round things are, in pixels (the one knob for "blocky" vs "sleek"): panels, cards, popups and lists get CORNER; buttons,
# portrait frames, chips and tiles get CORNER_SMALL. Bars are always fully rounded ends.
const CORNER := 12
const CORNER_SMALL := 7

# The size of the timing popups (dodge, block, attack) and where they sit: the right-hand column, clear of the grid, above the bottom bar.
const POPUP_SIZE := Vector2(320, 244)
const POPUP_CANVAS_POS := Vector2(12, 78)
const POPUP_CANVAS_SIZE := Vector2(296, 150)

# A rounded box: `shadow` adds the soft drop shadow floating panels wear.
static func box(bg: Color, border: Color, border_width: int, radius: int, shadow: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	if shadow:
		sb.shadow_color = Color(0, 0, 0, 0.45)
		sb.shadow_size = 9
		sb.shadow_offset = Vector2(0, 3)
	return sb

# The frame every battle panel wears: rounded, a thin bronze border, a soft shadow.
static func panel_style(border: Color = PANEL_BORDER, border_width: int = 1, radius: int = CORNER, shadow: bool = true) -> StyleBoxFlat:
	return box(PANEL_BG, border, border_width, radius, shadow)

# Where a timing popup sits for a window of this size.
static func popup_position(view: Vector2, size: Vector2 = POPUP_SIZE) -> Vector2:
	return Vector2(view.x - size.x - 24.0, view.y - 14.0 - 30.0 - 12.0 - size.y).round()
