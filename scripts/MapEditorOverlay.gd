extends Control

# Everything the Map Editor draws ON TOP of the real map, in screen pixels so lines stay thin and text stays crisp at any zoom: the room
# grid, the picked room, its fine grid and rulers, the outlines and handles of its shapes / decoration / set pieces / doorways, the named
# places and roads, and a ghost of whatever is being put down. It only reads from the editor; it never changes anything.

const ShapesScript := preload("res://scripts/MapEditorShapes.gd")
const WorldMapScript := preload("res://scripts/WorldMap.gd")
const RoomsScript := preload("res://scripts/Rooms.gd")
const MapDataScript := preload("res://scripts/MapData.gd")
const WorldScript := preload("res://scripts/MapEditorWorld.gd")

const C_GRID := Color(1, 1, 1, 0.30)
const C_GRID_FINE := Color(1, 1, 1, 0.13)
const C_GRID_FINE_MAJOR := Color(1, 1, 1, 0.26)
const C_PICK := Color("efc23c")
const C_FLOOR := Color(0.45, 0.92, 1.0)
const C_CUT := Color(1.0, 0.42, 0.42)
const C_BRIDGE := Color(1.0, 0.86, 0.3)
const C_SEL := Color(1, 1, 1)
const C_OPEN := Color(0.45, 0.95, 0.5)
const C_CLOSED := Color(1.0, 0.4, 0.4)
const C_PROP := Color(0.85, 0.65, 1.0)
const C_LANDMARK := Color("fff3a8")
const C_ROAD := Color(1.0, 0.7, 0.3)
const ITEM_COLORS := {"tall": Color(0.5, 1.0, 0.5), "small": Color(0.7, 1.0, 0.4), "ground": Color(1.0, 0.8, 0.9), "stone": Color(0.8, 0.8, 0.85)}

var ed                                   # the MapEditor

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)     # (anchors alone would leave a node added to a parent at size 0)

func _draw() -> void:
	if ed == null or ed.camera == null:
		return
	var view: Rect2 = ed.view_world_rect()
	_draw_room_grid(view)
	_draw_town(view)
	if ed.has_room():
		_draw_picked_room(view)
	_draw_landmarks()
	if ed.tab == "world":
		_draw_world_tab()
	_draw_ghost()
	if ed.zoom < WorldScript.EDITOR_MIN_ZOOM:
		var free: Rect2 = ed.ui.free_area()
		_text(Vector2(free.get_center().x, free.position.y + 26.0), "Zoomed out: rooms are not built here. Use the mouse wheel to zoom in.", PixelKit.GOLD3, "body", true)

# --- helpers -----------------------------------------------------------------------------------------------------------------

func _s(p: Vector2) -> Vector2:
	return ed.w2s(p)

func _text(at: Vector2, text_in: String, color: Color = PixelKit.CREAM, kind: String = "body", centered: bool = false) -> void:
	var font: Font = PixelKit.font(kind)
	var size := PixelKit.font_size(kind)
	var pos := at
	if centered:
		pos.x -= font.get_string_size(text_in, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5
	draw_string(font, pos + Vector2(2, 2), text_in, HORIZONTAL_ALIGNMENT_LEFT, -1, size, PixelKit.SHADOW)
	draw_string(font, pos, text_in, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _poly(points: PackedVector2Array, color: Color, width: float = 1.5, closed: bool = true) -> void:
	if points.size() < 2:
		return
	var pts := PackedVector2Array()
	for p in points:
		pts.append(_s(p))
	if closed:
		pts.append(pts[0])
	draw_polyline(pts, color, width)

func _handle(world_pos: Vector2, color: Color = C_SEL, size: float = 9.0) -> void:
	var s := _s(world_pos)
	draw_rect(Rect2(s - Vector2(size, size) * 0.5 - Vector2(1, 1), Vector2(size, size) + Vector2(2, 2)), PixelKit.INK)
	draw_rect(Rect2(s - Vector2(size, size) * 0.5, Vector2(size, size)), color)

func _dashed(a: Vector2, b: Vector2, color: Color, width: float = 1.5, dash: float = 10.0) -> void:
	var sa := _s(a)
	var sb := _s(b)
	var len := sa.distance_to(sb)
	if len < 1.0:
		return
	var dir := (sb - sa) / len
	var t := 0.0
	while t < len:
		draw_line(sa + dir * t, sa + dir * minf(t + dash, len), color, width)
		t += dash * 2.0

# --- the world's room grid -------------------------------------------------------------------------------------------------------

func _draw_room_grid(view: Rect2) -> void:
	var sz: Vector2 = WorldMapScript.SIZE
	var free: Rect2 = ed.ui.free_area() if ed.ui != null else Rect2(Vector2.ZERO, size)
	for i in WorldMapScript.ROOM_COLS + 1:
		var x := float(WorldMapScript.col_x(i))
		if x < view.position.x - 5.0 or x > view.end.x + 5.0:
			continue
		draw_line(_s(Vector2(x, 0.0)), _s(Vector2(x, sz.y)), C_GRID, 1.0)
	for j in WorldMapScript.ROOM_ROWS + 1:
		var y := float(WorldMapScript.row_y(j))
		if y < view.position.y - 5.0 or y > view.end.y + 5.0:
			continue
		draw_line(_s(Vector2(0.0, y)), _s(Vector2(sz.x, y)), C_GRID, 1.0)
	# which cells are hand-made, a faint tint when seen from afar; every cell's "col,row" and the room's name when there is room for it
	RoomsScript.ensure_built()
	var cell_w: float = float(WorldMapScript.col_x(1)) * ed.zoom
	for j in WorldMapScript.ROOM_ROWS:
		for i in WorldMapScript.ROOM_COLS:
			var rect: Rect2 = ed.cell_rect(Vector2i(i, j))
			if not rect.intersects(view):
				continue
			var s0 := _s(rect.position)
			if ed.zoom < 0.2 and ed.doc.rooms.has(MapDataScript.cell_key(i, j)):
				draw_rect(Rect2(s0, rect.size * ed.zoom), Color(0.4, 1.0, 0.5, 0.07))
			if cell_w > 64.0:
				_text(s0 + Vector2(6, 18), "%d,%d" % [i, j], Color(1, 1, 1, 0.55))
	if cell_w > 90.0:
		for r in RoomsScript.rooms:
			if str(r.name) != "" and r.rect.intersects(view) and not (ed.has_room() and r.cell == ed.room_cell):
				var c: Vector2 = _s(r.rect.get_center())
				if free.has_point(c):
					_text(c - Vector2(0, 8), str(r.name), Color(1, 1, 1, 0.9), "body", true)

func _draw_town(view: Rect2) -> void:
	for pair in [[WorldScript.TOWN_RECT, "The Castle Town (built by the game)"], [WorldScript.RACE_TRACK_RECT, "Race track"]]:
		var rect: Rect2 = pair[0]
		if not rect.intersects(view) or ed.zoom < 0.04:
			continue
		var a := rect.position
		var b := Vector2(rect.end.x, rect.position.y)
		var c := rect.end
		var d := Vector2(rect.position.x, rect.end.y)
		for seg in [[a, b], [b, c], [c, d], [d, a]]:
			_dashed(seg[0], seg[1], Color(1, 0.9, 0.5, 0.7))
		if ed.zoom > 0.12:
			_text(_s(rect.position) + Vector2(6, 22), str(pair[1]), Color(1, 0.9, 0.5, 0.9))

# --- the picked room --------------------------------------------------------------------------------------------------------------

func _draw_picked_room(view: Rect2) -> void:
	var r: Dictionary = ed.room()
	if r.is_empty():
		return
	var rect: Rect2 = r.rect
	var s0 := _s(rect.position)
	var s1 := _s(rect.end)
	draw_rect(Rect2(s0, s1 - s0), Color(C_PICK, 0.05))
	draw_rect(Rect2(s0, s1 - s0), C_PICK, false, 3.0)
	var label: String = ed.room_key()
	if str(r.name) != "":
		label = "%s  %s" % [ed.room_key(), str(r.name)]
	label += "  (hand-made)" if ed.is_handmade() else "  (made by the generator)"
	var free: Rect2 = ed.ui.free_area()
	var corner := Vector2(maxf(s0.x, free.position.x), maxf(s0.y, free.position.y)) + Vector2(10, 22)
	if free.has_point(corner) and (s1.x - corner.x) > 160.0:
		_text(corner, label, C_PICK)
	if ed.grid_on and ed.zoom >= 0.05:
		_draw_fine_grid(rect, view)
	_draw_doorways(r)
	if ed.is_handmade():
		_draw_shapes()
		_draw_decor()
		_draw_props()

func _grid_step() -> float:
	var base: float = ed.snap_step if ed.snap_step > 0.0 else 100.0
	var step := base
	while step * ed.zoom < 14.0:
		step *= 2.0
	return step

func _draw_fine_grid(rect: Rect2, view: Rect2) -> void:
	var clip := rect.intersection(view)
	if clip.size.x <= 0.0 or clip.size.y <= 0.0:
		return
	var step := _grid_step()
	var o := rect.position
	var x0 := ceilf((clip.position.x - o.x) / step)
	var x1 := floorf((clip.end.x - o.x) / step)
	var y0 := ceilf((clip.position.y - o.y) / step)
	var y1 := floorf((clip.end.y - o.y) / step)
	var major := step * 5.0
	var ix := x0
	while ix <= x1:
		var x := o.x + ix * step
		var is_major := fmod(ix * step, major) < 0.5
		draw_line(_s(Vector2(x, clip.position.y)), _s(Vector2(x, clip.end.y)), C_GRID_FINE_MAJOR if is_major else C_GRID_FINE, 1.0)
		ix += 1.0
	var iy := y0
	while iy <= y1:
		var y := o.y + iy * step
		var is_major2 := fmod(iy * step, major) < 0.5
		draw_line(_s(Vector2(clip.position.x, y)), _s(Vector2(clip.end.x, y)), C_GRID_FINE_MAJOR if is_major2 else C_GRID_FINE, 1.0)
		iy += 1.0
	# the ruler: the room-local position every few lines along its top and left edge
	var label_step := step
	while label_step * ed.zoom < 70.0:
		label_step *= 2.0
	var lx := ceilf((clip.position.x - o.x) / label_step)
	while o.x + lx * label_step <= clip.end.x:
		var xx := o.x + lx * label_step
		var sp := _s(Vector2(xx, maxf(rect.position.y, view.position.y)))
		_text(sp + Vector2(4, 14), str(int(lx * label_step)), Color(1, 1, 1, 0.65))
		lx += 1.0
	var ly := ceilf((clip.position.y - o.y) / label_step)
	while o.y + ly * label_step <= clip.end.y:
		var yy := o.y + ly * label_step
		var sp2 := _s(Vector2(maxf(rect.position.x, view.position.x), yy))
		_text(sp2 + Vector2(4, -4), str(int(ly * label_step)), Color(1, 1, 1, 0.65))
		ly += 1.0

# --- doorways ---------------------------------------------------------------------------------------------------------------------

func _draw_doorways(r: Dictionary) -> void:
	var in_tab: bool = ed.tab == "doors"
	for side in ed.room_sides():
		var a: Vector2 = side.from
		var b: Vector2 = side.to
		var length: float = side.length
		var picked: bool = in_tab and side.name == ed.sel_id
		# the wall in red, the openings in green
		var wall_alpha := 0.9 if in_tab else 0.45
		draw_line(_s(a), _s(b), Color(C_CLOSED, wall_alpha), 3.0 if in_tab else 2.0)
		for o in side.openings:
			var p0: Vector2 = a.lerp(b, float(o[0]))
			var p1: Vector2 = a.lerp(b, float(o[1]))
			draw_line(_s(p0), _s(p1), Color(C_OPEN, 0.95 if in_tab else 0.6), 6.0 if in_tab else 4.0)
		if picked:
			draw_line(_s(a), _s(b), C_SEL, 1.0)
			var along: Vector2 = (b - a).normalized()
			var list: Array = ed.doorways_of(side)
			for i in list.size():
				var centre: Vector2 = a + along * float(list[i][0])
				var half: float = float(list[i][1]) * 0.5
				_handle(centre, C_OPEN)
				_handle(centre - along * half, C_SEL, 7.0)
				_handle(centre + along * half, C_SEL, 7.0)
		if in_tab and ed.zoom > 0.06:
			var mid: Vector2 = _s(a.lerp(b, 0.5)) + Vector2(side.inward) * 26.0
			var word := "generated"
			if typeof(side.spec) == TYPE_STRING:
				word = str(side.spec)
			elif typeof(side.spec) == TYPE_ARRAY:
				word = "%d doorway%s" % [side.spec.size(), "" if side.spec.size() == 1 else "s"]
			_text(mid, word, C_SEL if picked else Color(1, 1, 1, 0.8), "body", true)

# --- shapes, decoration, set pieces ----------------------------------------------------------------------------------------

func _origin() -> Vector2:
	return ed.room_origin()

func _draw_shapes() -> void:
	var in_tab: bool = ed.tab == "floor"
	var o := _origin()
	var models: Array = ed.item_models("floor")
	for i in models.size():
		var m: Dictionary = models[i]
		var picked: bool = in_tab and i == ed.sel_i
		var col: Color = C_FLOOR
		if m.mode == "cut":
			col = C_CUT
		elif m.mode == "bridge":
			col = C_BRIDGE
		var alpha := 0.95 if in_tab else 0.4
		var outline := ShapesScript.op_outline(m)
		var shifted := PackedVector2Array()
		for p in outline:
			shifted.append(p + o)
		_poly(shifted, C_SEL if picked else Color(col, alpha), 3.0 if picked else 1.6)
		if m.kind in ["path"]:
			var centre := PackedVector2Array()
			for p in m.pts:
				centre.append(p + o)
			_poly(centre, Color(col, alpha * 0.8), 1.0, false)
		if in_tab and ed.zoom > 0.07:
			var c: Vector2 = ShapesScript.op_center(m) + o
			_text(_s(c) + Vector2(-12, 6), str(i + 1), C_SEL if picked else Color(col, 0.9))
		if picked:
			for h in ShapesScript.op_handles(m):
				var is_mid: bool = str(h.id).begins_with("m")
				_handle(h.pos + o, Color(C_SEL, 0.55) if is_mid else C_SEL, 7.0 if is_mid else 10.0)

func _draw_decor() -> void:
	var in_tab: bool = ed.tab == "decor"
	var o := _origin()
	var models: Array = ed.item_models("decor")
	for i in models.size():
		var m: Dictionary = models[i]
		var picked: bool = in_tab and i == ed.sel_i
		var col: Color = ITEM_COLORS.get(str(m.get("item", "tall")), Color.WHITE)
		var sz := 5.0 if (in_tab or ed.zoom > 0.1) else 3.0
		for p in ShapesScript.decor_points(m):
			var s := _s(p + o)
			draw_rect(Rect2(s - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), Color(col, 1.0 if in_tab else 0.5))
		if picked:
			for h in ShapesScript.decor_handles(m):
				_handle(h.pos + o, C_SEL, 10.0)
			for p in ShapesScript.decor_points(m):
				draw_rect(Rect2(_s(p + o) - Vector2(4, 4), Vector2(8, 8)), C_SEL, false, 1.0)
		if in_tab and ed.zoom > 0.07:
			_text(_s(ShapesScript.decor_center(m) + o) + Vector2(-8, -12), str(i + 1), C_SEL if picked else col)

func _draw_props() -> void:
	var in_tab: bool = ed.tab == "props"
	var o := _origin()
	var models: Array = ed.item_models("props")
	for i in models.size():
		var m: Dictionary = models[i]
		var picked: bool = in_tab and i == ed.sel_i
		var radius_px: float = ShapesScript.prop_radius(m.kind) * ed.zoom
		var s := _s(m.c + o)
		draw_arc(s, radius_px, 0.0, TAU, 40, C_SEL if picked else Color(C_PROP, 0.9 if in_tab else 0.45), 2.0 if picked else 1.4)
		draw_circle(s, 4.0, C_SEL if picked else C_PROP)
		if ed.zoom > 0.05:
			_text(s + Vector2(0, -radius_px - 6) if radius_px > 14.0 else s + Vector2(8, -6), ShapesScript.PROP_NAMES.get(m.kind, m.kind), C_SEL if picked else C_PROP, "body", radius_px > 14.0)
		if picked:
			_handle(m.c + o, C_SEL, 10.0)

# --- named places, roads, regions ----------------------------------------------------------------------------------------------

func _draw_landmarks() -> void:
	var emphasised: bool = ed.tab == "world" and ed.world_tab == "landmarks"
	for l in WorldMapScript.landmarks:
		var s := _s(l.pos)
		if s.x < -40.0 or s.y < -40.0 or s.x > size.x + 40.0 or s.y > size.y + 40.0:
			continue
		var picked: bool = emphasised and ed.sel_id == l.id
		var col: Color = C_SEL if picked else C_LANDMARK
		var pts := PackedVector2Array([s + Vector2(0, -9), s + Vector2(9, 0), s + Vector2(0, 9), s + Vector2(-9, 0), s + Vector2(0, -9)])
		draw_colored_polygon(PackedVector2Array([pts[0], pts[1], pts[2], pts[3]]), Color(col, 0.9 if emphasised else 0.55))
		draw_polyline(pts, PixelKit.INK, 1.5)
		if emphasised or ed.zoom > 0.03:
			_text(s + Vector2(0, -16), str(l.name), col if emphasised else Color(col, 0.85), "body", true)
		if emphasised and ed.zoom > 0.04:
			draw_arc(s, float(l.radius) * ed.zoom, 0.0, TAU, 48, Color(col, 0.8), 1.5)
		if picked:
			_handle(l.pos, C_SEL, 11.0)

func _draw_world_tab() -> void:
	match ed.world_tab:
		"roads":
			for i in ed.doc.roads.size():
				var picked: bool = i == ed.sel_i
				var pts := PackedVector2Array()
				for p in ed.doc.roads[i].points:
					pts.append(_s(ed.road_point_world(p)))
				draw_polyline(pts, C_SEL if picked else Color(C_ROAD, 0.85), 3.0 if picked else 2.0)
				if picked:
					for k in pts.size():
						_handle(ed.road_point_world(ed.doc.roads[i].points[k]), C_SEL if k == ed.sel_pt else C_ROAD, 11.0 if k == ed.sel_pt else 9.0)
					for k in pts.size() - 1:
						_handle(ed.road_point_world(ed.doc.roads[i].points[k]).lerp(ed.road_point_world(ed.doc.roads[i].points[k + 1]), 0.5), Color(C_SEL, 0.5), 6.0)
		"regions":
			var id: String = ed.sel_id
			if id != "":
				var region: Dictionary = WorldMapScript.region(id)
				if not region.is_empty():
					_poly(region.polygon, C_PICK, 3.0)

# --- a ghost of what is being put down --------------------------------------------------------------------------------------

func _draw_ghost() -> void:
	if ed.armed.is_empty() and ed.drag.is_empty():
		return
	var mouse: Vector2 = ed.s2w(get_viewport().get_mouse_position())
	var o := _origin()
	if not ed.drag.is_empty() and ed.drag.type == "create":
		var a: Vector2 = ShapesScript.snap_v(ed.drag.start - o, ed.snap_step)
		var b: Vector2 = ShapesScript.snap_v(ed.drag.current - o, ed.snap_step)
		var m: Dictionary = ShapesScript.default_op(str(ed.drag.kind), ed.new_mode, a)
		var off := b - a
		match str(ed.drag.kind):
			"ell":
				m.rx = maxf(absf(off.x), 20.0)
				m.ry = maxf(absf(off.y), 20.0)
			"disc":
				m.r = maxf(off.length(), 20.0)
			"box":
				m.hx = maxf(absf(off.x), 20.0)
				m.hy = maxf(absf(off.y), 20.0)
		var outline := ShapesScript.op_outline(m)
		var shifted := PackedVector2Array()
		for p in outline:
			shifted.append(p + o)
		_poly(shifted, Color(C_SEL, 0.9), 2.0)
		return
	var points: Array = ed.drawing_points()
	if not points.is_empty():
		var pts := PackedVector2Array()
		for p in points:
			var wp: Vector2 = p if str(ed.armed.type) == "road" else (p + o)
			pts.append(wp)
			_handle(wp, C_SEL, 8.0)
		pts.append(mouse)
		_poly(pts, Color(C_SEL, 0.85), 2.0, false)
	elif ed.armed.get("type", "") == "decor" and ed.armed.has("a"):
		_handle(ed.armed.a + o, C_SEL, 8.0)
		_poly(PackedVector2Array([ed.armed.a + o, mouse]), Color(C_SEL, 0.85), 2.0, false)
	# the crosshair where the click will land
	var snapped := ShapesScript.snap_v(mouse - o, ed.snap_step) + o
	var s := _s(snapped)
	draw_line(s - Vector2(12, 0), s + Vector2(12, 0), C_SEL, 1.0)
	draw_line(s - Vector2(0, 12), s + Vector2(0, 12), C_SEL, 1.0)
