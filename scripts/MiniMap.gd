extends Control
class_name MiniMap

# A small framed picture of the whole continent (WorldMap.gd's regions, shrunk) with a dot for you, the castle
# town and the boss landmarks. Lives in the overworld HUD's corner so the 33,600-pixel world is easy to read.
# The regions are painted once; only the dots move.

const WorldMapScript := preload("res://scripts/WorldMap.gd")

const MAP_PX := Vector2(196, 139)
const GROUND_COLORS := {
	"grass": Color(0.33, 0.58, 0.27), "sand": Color(0.82, 0.72, 0.42), "swamp": Color(0.32, 0.42, 0.26),
	"rock": Color(0.52, 0.5, 0.52), "snow": Color(0.82, 0.9, 0.95), "ash": Color(0.46, 0.22, 0.17),
	"void": Color(0.24, 0.12, 0.4), "water": Color(0.2, 0.42, 0.78),
}
const FRAME_COLOR := Color(0.55, 0.42, 0.18)

var player_pos := Vector2.ZERO
var _scale := Vector2.ONE
var _overlay: Control   # drawn after the region shapes, so the dots and the frame sit on top of them

func _init() -> void:
	custom_minimum_size = MAP_PX
	size = MAP_PX
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func _ready() -> void:
	WorldMapScript.ensure_built()
	_scale = MAP_PX / WorldMapScript.SIZE
	for r in WorldMapScript.regions:
		var poly := Polygon2D.new()
		var pts := PackedVector2Array()
		for p in r.polygon:
			pts.append(p * _scale)
		poly.polygon = pts
		poly.color = region_color(r)
		add_child(poly)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.size = MAP_PX
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)

static func region_color(r: Dictionary) -> Color:
	var base: Color = GROUND_COLORS.get(r.ground, Color(0.4, 0.4, 0.4))
	var tint: Color = r.tint
	return Color(clampf(base.r * (0.55 + 0.45 * tint.r), 0.0, 1.0), clampf(base.g * (0.55 + 0.45 * tint.g), 0.0, 1.0), clampf(base.b * (0.55 + 0.45 * tint.b), 0.0, 1.0))

func set_player(pos: Vector2) -> void:
	if pos.distance_squared_to(player_pos) < 25.0:
		return
	player_pos = pos
	if _overlay != null:
		_overlay.queue_redraw()

func _draw_overlay() -> void:
	for l in WorldMapScript.landmarks:
		var at: Vector2 = l.pos * _scale
		if l.kind == "town":
			_overlay.draw_rect(Rect2(at - Vector2(3, 3), Vector2(6, 6)), Color(1.0, 0.85, 0.3))
			_overlay.draw_rect(Rect2(at - Vector2(3, 3), Vector2(6, 6)), Color(0.2, 0.15, 0.05), false, 1.0)
		elif l.kind == "boss":
			_overlay.draw_circle(at, 2.2, Color(0.9, 0.2, 0.2))
	var me: Vector2 = player_pos * _scale
	_overlay.draw_circle(me, 4.0, Color(0, 0, 0, 0.8))
	_overlay.draw_circle(me, 2.6, Color(1.0, 1.0, 1.0))
	_overlay.draw_rect(Rect2(Vector2.ZERO, MAP_PX), FRAME_COLOR, false, 2.0)
