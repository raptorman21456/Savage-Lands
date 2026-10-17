extends Control
class_name InvMapView

# The Map tab: the continent as a schematic (not a live camera): every region painted, the rooms you have not been in dimmed (the one
# you stand in outlined), and the places you have found as pixel pins -- a house for a town / the ranch / the ruins, an anchor for the
# harbour, a red skull for a boss lair -- with a blue marker for you. Hover a pin for its name; zoom with + / - or the wheel; drag to pan.
# The town's venues you have found are listed down the right. Pins are always the same size, however far you zoom.

const WorldMapScript := preload("res://scripts/WorldMap.gd")
const RoomsScript := preload("res://scripts/Rooms.gd")
const MiniMapScript := preload("res://scripts/MiniMap.gd")

const LEGEND_W := 196.0
const PIN_PX := 32.0

var panel = null
var player = null
var main = null
var zoom := 1.0
var pan := Vector2.ZERO
var _dragging := false
var _drag_from := Vector2.ZERO
var _pins: Array = []        # [{rect: Rect2, name: String}] in view coordinates, rebuilt each draw
var _hover := ""
var _hover_label: Label = null
var _tex := {}

func setup(p_panel, p_player, p_main) -> void:
	panel = p_panel
	player = p_player
	main = p_main
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	for kind in ["town", "harbour", "boss", "here"]:
		_tex[kind] = load("res://scripts/UIIcons.gd").texture("pin_%s" % kind)
	_hover_label = PixelKit.label("", "body", PixelKit.GOLD3)
	_hover_label.position = Vector2(16, 12)
	_hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hover_label)
	var plus := PixelButton.make("+", "", func(): _zoom_by(0.4))
	plus.position = Vector2(size.x - LEGEND_W - 70, 10)
	add_child(plus)
	var minus := PixelButton.make("−", "", func(): _zoom_by(-0.4))
	minus.position = Vector2(size.x - LEGEND_W - 70, 62)
	add_child(minus)
	queue_redraw()

func _zoom_by(delta: float) -> void:
	zoom = clampf(zoom + delta, 1.0, 3.0)
	if zoom == 1.0:
		pan = Vector2.ZERO
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_by(0.2)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_by(-0.2)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			_drag_from = event.position
	elif event is InputEventMouseMotion:
		if _dragging and zoom > 1.0:
			pan += event.position - _drag_from
			_drag_from = event.position
			queue_redraw()
		_update_hover(event.position)

func _update_hover(at: Vector2) -> void:
	var name_here := ""
	for p in _pins:
		if p.rect.has_point(at):
			name_here = str(p.name)
	if name_here != _hover:
		_hover = name_here
		_hover_label.text = name_here
		queue_redraw()

func _map_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(size.x - LEGEND_W, size.y))

func _draw() -> void:
	if main == null:
		return
	_pins.clear()
	var area_size: Vector2 = main.WORLD_SIZE
	var box := _map_rect()
	var base_scale: float = minf(box.size.x / area_size.x, box.size.y / area_size.y)
	var scale_factor: float = base_scale * zoom
	var draw_size: Vector2 = area_size * scale_factor
	var origin: Vector2 = box.position + (box.size - draw_size) / 2.0 + pan
	var font: Font = PixelKit.font("body")
	var to_map := func(world_pos: Vector2) -> Vector2:
		return origin + world_pos * scale_factor
	draw_rect(Rect2(Vector2.ZERO, size), Color("0a0f12"), true)
	draw_rect(Rect2(origin, draw_size), Color(0.16, 0.22, 0.14), true)
	var all_seen: bool = player.talisman_bonus("reveal_all_locations") > 0.0
	if main.regional_world:
		for r in WorldMapScript.regions:
			var pts := PackedVector2Array()
			for p in r.polygon:
				pts.append(to_map.call(p))
			if pts.size() >= 3 and not Geometry2D.triangulate_polygon(pts).is_empty():
				draw_colored_polygon(pts, MiniMapScript.region_color(r))
		# The rooms: the ones you have not been in dimmed (Pathfinder's Compass shows them all), the one you stand in outlined.
		for rm in RoomsScript.rooms:
			var rect := Rect2(to_map.call(rm.rect.position), rm.rect.size * scale_factor)
			if not all_seen and not main.visited_rooms.has(rm.id):
				draw_rect(rect, Color(0, 0, 0, 0.42))
			draw_rect(rect, Color(0, 0, 0, 0.28), false, 1.0)
		var here: Dictionary = RoomsScript.room_at(player.global_position)
		draw_rect(Rect2(to_map.call(here.rect.position), here.rect.size * scale_factor), Color(1.0, 0.95, 0.5, 0.95), false, 2.0)
		for r in WorldMapScript.regions:
			if r.id in ["great_expanse", "woods", "volcano_hills", "swamp", "ocean", "frozen_wastes", "voidlands", "desert", "mountains"]:
				var centre: Vector2 = to_map.call(r.bounds.get_center() if r.id != "great_expanse" else Vector2(WorldMapScript.SIZE.x * 0.62, WorldMapScript.SIZE.y * 0.42))
				var label_text: String = "Lexian Peaks" if r.id == "mountains" else str(r.name)
				draw_string(font, centre + Vector2(-110, 0), label_text, HORIZONTAL_ALIGNMENT_CENTER, 220, PixelKit.font_size("body"), Color(1, 1, 1, 0.85))
		# the places: always found (a landmark is a place you could not miss), each a pin of its kind
		for l in WorldMapScript.landmarks:
			var kind := str(l.kind)
			var pin_kind := ""
			if kind == "boss":
				pin_kind = "boss"
			elif str(l.id) == "pesca":
				pin_kind = "harbour"
			elif kind in ["town", "ruins", "ranch"]:
				pin_kind = "town"
			if pin_kind != "":
				_draw_pin(pin_kind, to_map.call(l.pos), str(l.name))
	draw_rect(Rect2(origin, draw_size), Color(0.55, 0.55, 0.5), false, 2.0)
	# the town box the venues sit in
	var town_top_left: Vector2 = to_map.call(main.TOWN_AREA_ORIGIN)
	var town_draw_size: Vector2 = main.TOWN_SIZE * scale_factor
	draw_rect(Rect2(town_top_left, town_draw_size), Color(0.32, 0.3, 0.27), true)
	draw_rect(Rect2(town_top_left, town_draw_size), Color(0.7, 0.6, 0.3), false, 2.0)
	draw_string(font, town_top_left + Vector2(4, -6), "TOWN", HORIZONTAL_ALIGNMENT_LEFT, town_draw_size.x, PixelKit.font_size("body"), Color(0.9, 0.8, 0.5))
	# you
	var you: Vector2 = to_map.call(player.global_position)
	_draw_pin("here", you, "You are here")
	# the legend: what the pins mean, then the venues found in town
	_draw_legend(font)
	_hover_label.visible = true

func _draw_pin(kind: String, at: Vector2, label: String) -> void:
	var tex: Texture2D = _tex.get(kind)
	if tex == null:
		return
	# a pin's tip is the place: the picture stands on it
	var rect := Rect2(at - Vector2(PIN_PX / 2.0, PIN_PX - 4.0), Vector2(PIN_PX, PIN_PX))
	if not _map_rect().intersects(rect):
		return
	draw_texture_rect(tex, rect, false)
	_pins.append({"rect": rect, "name": label})

func _draw_legend(font: Font) -> void:
	var x := size.x - LEGEND_W + 12.0
	var y := 16.0
	var keys := [["town", "town, ranch, ruins"], ["harbour", "harbour"], ["boss", "a boss's lair"], ["here", "you"]]
	for k in keys:
		var tex: Texture2D = _tex.get(k[0])
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2(x, y), Vector2(PIN_PX, PIN_PX)), false)
		draw_string(font, Vector2(x + PIN_PX + 8.0, y + 24.0), str(k[1]), HORIZONTAL_ALIGNMENT_LEFT, LEGEND_W - PIN_PX - 24.0, PixelKit.font_size("body"), PixelKit.CREAM)
		y += 38.0
	y += 10.0
	draw_string(font, Vector2(x, y + 16.0), "Found in town", HORIZONTAL_ALIGNMENT_LEFT, LEGEND_W - 20.0, PixelKit.font_size("body"), PixelKit.DIM)
	y += 30.0
	var reveal_all: bool = player.talisman_bonus("reveal_all_locations") > 0.0
	for key in main.town_building_positions:
		if not reveal_all and not player.discovered_locations.get(key, false):
			continue
		var venue_name: String = main.TOWN_LAYOUT.get(key, {}).get("name", str(key).capitalize())
		draw_string(font, Vector2(x, y + 14.0), venue_name, HORIZONTAL_ALIGNMENT_LEFT, LEGEND_W - 20.0, PixelKit.font_size("body"), PixelKit.CREAM)
		y += 24.0
		if y > size.y - 20.0:
			break
