extends SceneTree

# The Map Editor and the map data files behind it: the shipped data round-trips to the very same map, a missing or broken file falls back
# gracefully, every editing operation does what it says (shapes, decoration, set pieces, doorways, landmarks, roads, regions), undo and redo
# work, and Save writes the files and keeps a backup. Each line says what it checks and what it expects. It never writes res://data (every save
# goes to a scratch folder under user://map_test) and the editor switches SaveData into its in-memory mode, as the Sandbox does.
#
# Expect a few "WARNING: Map data: ..." lines and ONE engine "ERROR: Could not create directory" line in the log: they are the
# missing-file, broken-file and unwritable-folder cases being provoked on purpose.
#
#   Godot --headless --path . --script res://tools/test_map_editor.gd

const MapDataScript := preload("res://scripts/MapData.gd")
const RoomDataScript := preload("res://scripts/RoomData.gd")
const WorldMapScript := preload("res://scripts/WorldMap.gd")
const RoomsScript := preload("res://scripts/Rooms.gd")
const ShapesScript := preload("res://scripts/MapEditorShapes.gd")
const SaveDataScript := preload("res://scripts/SaveData.gd")

const SCRATCH := "user://map_test"
var _real_before := {}

func _init() -> void:
	await process_frame
	await process_frame
	root.size = Vector2i(1152, 648)
	await process_frame
	for kind in MapDataScript.KINDS:
		_real_before[kind] = FileAccess.get_file_as_string(MapDataScript.file_path(kind))
	_wipe(SCRATCH)
	await _data_layer()
	await _fallbacks()
	await _shapes_math()
	await _editor_basics()
	await _editing()
	await _doorways()
	await _world_edits()
	await _real_input()
	await _ui_wiring()
	await _checks()
	await _undo_and_save()
	await _ui_and_title()
	var untouched := true
	for kind in MapDataScript.KINDS:
		if FileAccess.get_file_as_string(MapDataScript.file_path(kind)) != _real_before[kind]:
			untouched = false
	print("The shipped data files in res://data were never touched by these tests: %s (expected true)" % [untouched])
	quit()

func _wipe(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		_wipe(dir + "/" + d)
		DirAccess.remove_absolute(dir + "/" + d)

# --- what the world is, as plain values --------------------------------------------------------------------------------------

func _snapshot() -> Dictionary:
	RoomsScript.reset()
	WorldMapScript.reset()
	RoomsScript.ensure_built()
	var rooms := {}
	var layouts := {}
	for r in RoomsScript.rooms:
		var keep := {}
		for k in ["id", "cell", "span", "rect", "name", "mass", "shape", "stands", "props", "enemies", "target", "kind", "layout", "authored", "landmarks", "region", "tier"]:
			keep[k] = MapDataScript.copy(r[k]) if (typeof(r[k]) == TYPE_ARRAY or typeof(r[k]) == TYPE_DICTIONARY) else r[k]
		keep["exits"] = RoomsScript.exits(r)
		rooms[r.id] = keep
		var layout = RoomsScript.layout(r)
		layouts[r.id] = {"field": layout.field.duplicate(), "floor": layout.floor_fraction, "repairs": layout.repairs}
	var lm := {}
	for l in WorldMapScript.landmarks:
		lm[l.id] = {"name": l.name, "pos": l.pos, "radius": l.radius, "boss": l.boss}
	var rg := {}
	for r in WorldMapScript.regions:
		rg[r.id] = {"name": r.name, "tier": r.tier, "enemies": MapDataScript.copy(r.enemies), "miniboss": r.miniboss}
	return {"rooms": rooms, "layouts": layouts, "landmarks": lm, "regions": rg, "roads": MapDataScript.copy(RoomDataScript.roads())}

func _count_diffs(a: Dictionary, b: Dictionary, what: String) -> Array:
	var diffs: Array = []
	if a.size() != b.size():
		diffs.append("%s: %d vs %d entries" % [what, a.size(), b.size()])
	for k in a:
		if not b.has(k):
			diffs.append("%s %s missing" % [what, k])
		elif not MapDataScript.same(a[k], b[k], 0.0):
			diffs.append("%s %s differs" % [what, k])
	return diffs

# =============================================================================================================================
# the data files
# =============================================================================================================================

func _data_layer() -> void:
	RoomDataScript.read_files()
	print("--- the data files ---")
	print("All five data files load from res://data: %s (expected file x5)" % [MapDataScript.KINDS.map(func(k): return RoomDataScript.sources[k])])
	print("...with nothing wrong with them: %s (expected [])" % [RoomDataScript.report])
	var factory_rooms: Dictionary = RoomDataScript.factory("rooms")
	var factory_edges: Dictionary = RoomDataScript.factory("edges")
	var factory_roads: Array = RoomDataScript.factory("roads")
	print("rooms.json holds the %d hand-made rooms the game shipped with, exactly: %s (expected 87 and true)" % [RoomDataScript.rooms().size(), MapDataScript.same(RoomDataScript.rooms(), factory_rooms, 0.0)])
	print("edges.json holds the %d doorways exactly: %s (expected 169 and true)" % [RoomDataScript.edges().size(), MapDataScript.same(RoomDataScript.edges(), factory_edges, 0.0)])
	print("roads.json holds the %d roads exactly: %s (expected 15 and true)" % [RoomDataScript.roads().size(), MapDataScript.same(RoomDataScript.roads(), factory_roads, 0.0)])
	var order_same := RoomDataScript.rooms().keys() == factory_rooms.keys()
	print("The rooms are listed in the same order as before (grouped by country): %s (expected true)" % [order_same])
	for kind in ["rooms", "edges", "roads"]:
		var text := MapDataScript.serialize(kind, RoomDataScript.document()[kind])
		var back: Dictionary = MapDataScript.read_text(kind, text)
		print("Writing %s out and reading it in again gives the same data: %s (expected ok and true), the file is %d lines (expected a readable few hundred, not thousands)" % [kind, back.status == "ok" and MapDataScript.same(back.data, RoomDataScript.document()[kind], 0.0), text.count("\n")])
	var on_disk := FileAccess.get_file_as_string(MapDataScript.file_path("rooms"))
	print("The file on disk is exactly what the editor would write: %s (expected true)" % [on_disk == MapDataScript.serialize("rooms", RoomDataScript.rooms())])

	# the same world: built from the constants, then from the files
	RoomDataScript.use({"rooms": factory_rooms, "edges": factory_edges, "roads": factory_roads, "landmarks": [], "regions": {}})
	var from_constants := _snapshot()
	RoomDataScript.read_files()
	var from_files := _snapshot()
	print("Built from the files, the world has %d rooms; built from the constants %d (expected equal)" % [from_files.rooms.size(), from_constants.rooms.size()])
	var diffs: Array = _count_diffs(from_constants.rooms, from_files.rooms, "room")
	print("Every room is identical (shape, decor, props, enemies, name, ground, doorways): differences %s (expected [])" % [diffs.slice(0, 5)])
	diffs = _count_diffs(from_constants.layouts, from_files.layouts, "layout")
	print("Every room's floor, sample by sample, is identical: differences %s (expected [])" % [diffs.slice(0, 5)])
	diffs = _count_diffs(from_constants.landmarks, from_files.landmarks, "landmark")
	print("Every landmark is where it was, with its name and size: differences %s (expected [])" % [diffs.slice(0, 5)])
	diffs = _count_diffs(from_constants.regions, from_files.regions, "region")
	print("Every region keeps its name, danger tier, residents and miniboss: differences %s (expected [])" % [diffs.slice(0, 5)])
	print("The roads are the same: %s (expected true)" % [MapDataScript.same(from_constants.roads, from_files.roads, 0.0)])
	var authored := 0
	for id in from_files.rooms:
		if from_files.rooms[id].authored:
			authored += 1
	print("Hand-made rooms in the built world: %d (expected 87), the generator fills the other %d" % [authored, from_files.rooms.size() - authored])
	# the files own the landmarks' and regions' numbers now; WorldMap.gd's own are the factory copy -- do the two still agree?
	RoomDataScript.use({"rooms": factory_rooms, "edges": factory_edges, "roads": factory_roads, "landmarks": [], "regions": {}})
	WorldMapScript.reset()
	WorldMapScript.ensure_built()
	var code_landmarks: Array = MapDataScript.landmark_entries(WorldMapScript.landmarks)
	var code_regions: Dictionary = MapDataScript.region_entries(WorldMapScript.regions)
	RoomDataScript.read_files()
	WorldMapScript.reset()
	print("landmarks.json still holds the values written in WorldMap.gd: %s (expected true; if false someone changed one without the other: run tools/convert_map_data.gd, or edit them in the Map Editor)" % [MapDataScript.same(RoomDataScript.landmarks(), code_landmarks, 0.001)])
	print("regions.json still holds the values written in WorldMap.gd: %s (expected true; same advice)" % [MapDataScript.same(RoomDataScript.regions(), code_regions, 0.001)])

# =============================================================================================================================
# missing and broken files
# =============================================================================================================================

func _fallbacks() -> void:
	print("--- missing and broken files ---")
	var good: Dictionary = RoomDataScript.document()
	# a folder with no files at all
	RoomDataScript.read_files(SCRATCH + "/missing")
	print("With no data files, every part falls back to the built-in values: %s (expected built-in x5)" % [MapDataScript.KINDS.map(func(k): return RoomDataScript.sources[k])])
	print("...and says so: %d warnings, the first: \"%s\" (expected 5 or more, naming the missing file)" % [RoomDataScript.report.size(), RoomDataScript.report[0]])
	var snap_missing := _snapshot()
	print("...and the world is still the shipped one: %d rooms, %d hand-made (expected 95 and 87)" % [snap_missing.rooms.size(), snap_missing.rooms.values().filter(func(r): return r.authored).size()])

	# a file that is not JSON
	for kind in MapDataScript.KINDS:
		MapDataScript.write(kind, good[kind], SCRATCH + "/broken")
	var f := FileAccess.open(SCRATCH + "/broken/rooms.json", FileAccess.WRITE)
	f.store_string("{ \"rooms\": { \"4,3\": [ oops")
	f.close()
	RoomDataScript.read_files(SCRATCH + "/broken")
	print("A rooms.json that is not valid JSON: rooms come from %s, the others from %s (expected built-in, then file)" % [RoomDataScript.sources.rooms, RoomDataScript.sources.edges])
	print("...with a warning that says where: \"%s\" (expected the file name and a line)" % [RoomDataScript.report[0]])
	print("...and the game still builds: %d rooms (expected 95)" % [_snapshot().rooms.size()])

	# one bad room among good ones
	var bad: Dictionary = good.duplicate(true)
	bad.rooms["1,0"].shape = [["ell", 100, "oops", 5, 5]]
	bad.rooms["2,0"].enemies = "goblins"
	bad.rooms["0,1"].span = [0, 2]
	bad.edges["0,0|3,3"] = "open"
	bad.edges["1,0|2,0"] = [[900]]
	bad.roads.append({"width": 90, "points": [[1, 1]]})
	for kind in MapDataScript.KINDS:
		MapDataScript.write(kind, bad[kind], SCRATCH + "/partly")
	RoomDataScript.read_files(SCRATCH + "/partly")
	print("A file with three bad rooms, two bad doorways and a bad road keeps the rest: %d rooms, %d doorways, %d roads (expected 84, 168, 15)" % [RoomDataScript.rooms().size(), RoomDataScript.edges().size(), RoomDataScript.roads().size()])
	print("...and names every problem: %d warnings: %s" % [RoomDataScript.report.size(), RoomDataScript.report.slice(0, 6)])
	var snap_partly := _snapshot()
	var gen_1_0: Dictionary = RoomsScript.room_at(Vector2(WorldMapScript.col_x(1) + 50, WorldMapScript.row_y(0) + 50))
	print("The room whose data was bad is drawn by the generator instead: authored=%s, still builds (expected false), %d rooms in all" % [gen_1_0.authored, snap_partly.rooms.size()])

	# the wrong kind of thing
	var wrong := FileAccess.open(SCRATCH + "/broken/roads.json", FileAccess.WRITE)
	wrong.store_string("{\"format\": 1, \"roads\": 7}")
	wrong.close()
	var wrong2 := FileAccess.open(SCRATCH + "/broken/landmarks.json", FileAccess.WRITE)
	wrong2.store_string("[1, 2, 3]")
	wrong2.close()
	RoomDataScript.read_files(SCRATCH + "/broken")
	print("A roads.json whose roads are not a list: %s; a landmarks.json that is not an object: %s (expected built-in, built-in)" % [RoomDataScript.sources.roads, RoomDataScript.sources.landmarks])
	print("A landmark file that names an unknown place or a missing field changes nothing else: %s (expected true)" % [_snapshot().landmarks.size() == 12])

	# put the real data back for the rest
	RoomDataScript.read_files(MapDataScript.DIR)

# =============================================================================================================================
# geometry
# =============================================================================================================================

func _shapes_math() -> void:
	print("--- shapes, decoration and set pieces as models ---")
	RoomDataScript.read_files()
	var ops := 0
	var op_bad := 0
	var decor := 0
	var decor_bad := 0
	var props := 0
	var props_bad := 0
	for key in RoomDataScript.rooms():
		var room: Dictionary = RoomDataScript.rooms()[key]
		for op in room.get("shape", []):
			ops += 1
			var m := ShapesScript.parse_op(op)
			var again := ShapesScript.parse_op(ShapesScript.build_op(m))
			if not MapDataScript.same(m, again) or ShapesScript.op_outline(m).size() < 3:
				op_bad += 1
		for op in room.get("decor", []):
			decor += 1
			var d := ShapesScript.parse_decor(op)
			if not MapDataScript.same(d, ShapesScript.parse_decor(ShapesScript.build_decor(d))) or ShapesScript.decor_points(d).is_empty():
				decor_bad += 1
		for p in room.get("props", []):
			props += 1
			var pm := ShapesScript.parse_prop(p)
			if not MapDataScript.same(pm, ShapesScript.parse_prop(ShapesScript.build_prop(pm))):
				props_bad += 1
	print("Every one of the %d shape ops in the game turns into an editable model and back unchanged: %d that do not (expected 0)" % [ops, op_bad])
	print("...every one of the %d decoration arrangements: %d that do not (expected 0)" % [decor, decor_bad])
	print("...every one of the %d set pieces: %d that do not (expected 0)" % [props, props_bad])
	var oval := ShapesScript.parse_op(["ell", 900, 1082, 720, 540])
	print("An oval is hit inside and not outside: %s %s (expected true false)" % [ShapesScript.op_contains(oval, Vector2(900, 1082)), ShapesScript.op_contains(oval, Vector2(900, 1700))])
	var cut := ShapesScript.parse_op(["-disc", 100, 100, 50])
	print("A cut disc keeps its mode and radius: %s, %s, %s (expected cut, disc, 50)" % [cut.mode, cut.kind, cut.r])
	var turned := ShapesScript.parse_op(["rbox", 500, 500, 200, 100, 45, 20])
	print("A turned box is a box that is turned: kind %s deg %s; a point down its long axis is inside %s, a point where the unturned box would reach is outside %s (expected box 45 true false)" % [turned.kind, turned.deg, ShapesScript.op_contains(turned, Vector2(641, 641)), ShapesScript.op_contains(turned, Vector2(695, 400))])
	print("A new path stays a path: %s (expected [\"path\", 400, 100, 200, 300, 400])" % [ShapesScript.build_op({"mode": "floor", "kind": "path", "width": 400.0, "pts": [Vector2(100, 200), Vector2(300, 400)]})])
	var model := ShapesScript.parse_op(["ell", 100, 100, 50, 50])
	ShapesScript.op_drag(model, "e", Vector2(260, 100), 20.0)
	print("Dragging an oval's east square to x=260 makes it 160 wide (snapped to 20): rx = %s (expected 160)" % [model.rx])
	var poly := ShapesScript.parse_op(["poly", 0, 0, 100, 0, 100, 100])
	var new_id := ShapesScript.op_drag(poly, "m0", Vector2(50, -40), 0.0)
	print("Pulling a polygon's midpoint adds a point: %d points, now dragging %s (expected 4 points, p1)" % [poly.pts.size(), new_id])

# =============================================================================================================================
# the editor
# =============================================================================================================================

var ed

func _new_editor(dir: String) -> Node:
	RoomDataScript.read_files()
	var e = load("res://MapEditor.tscn").instantiate()
	e.data_dir = dir
	root.add_child(e)
	return e

func _settle() -> void:
	for i in 3:
		await process_frame
	ed.world.flush()
	await process_frame

func _key(c: Vector2i) -> String:
	return MapDataScript.cell_key(c.x, c.y)

# A click then a drag and a release in the world, as the mouse would do it.
func _drag(from_w: Vector2, to_w: Vector2) -> void:
	ed._left_press(from_w, false)
	ed._drag_to(to_w)
	ed._left_release(to_w)

func _local_to_world(p: Vector2) -> Vector2:
	return ed.room_origin() + p

func _editor_basics() -> void:
	print("--- the editor opens ---")
	SaveDataScript.sandbox_active = false
	# opened on the shipped data folder (res://data), nothing has been edited, so nothing may be marked unsaved
	ed = _new_editor(MapDataScript.DIR)
	await _settle()
	print("Opened on the shipped data, the editor shows no unsaved changes: dirty=%s, still to save %s (expected false, [])" % [ed.dirty, ed.unsaved_kinds()])
	ed.queue_free()
	await process_frame
	await process_frame
	SaveDataScript.sandbox_active = false
	ed = _new_editor(SCRATCH + "/session")
	await _settle()
	ed.focus_room()
	await _settle()
	print("Opening the editor switches SaveData into its in-memory mode, so no save file can be touched: %s (expected true)" % [SaveDataScript.sandbox_active])
	print("It picks the room you wake in: %s %s, hand-made %s (expected 4,3 Where You Woke true)" % [ed.room_key(), str(ed.room().name), ed.is_handmade()])
	print("The world it shows is the real overworld renderer: an OverworldMap %s, with the picked room built: %s (expected true, true)" % [ed.world is OverworldMap, ed.world.has_room_built(ed.room().id)])
	print("Nothing is edited yet: undo steps %d (expected 0); in an empty folder everything counts as unsaved: %s (expected all five)" % [ed.undo_stack.size(), ed.unsaved_kinds()])
	print("The editor's own camera zoom is %.3f, nothing like the game's 1.6 (expected a small number); the game camera is untouched because there is no player here" % [ed.zoom])
	print("There is no player, no enemy and no HUD in the editor's scene: %s (expected true)" % [get_nodes_in_group("enemies").is_empty() and get_nodes_in_group("player").is_empty()])
	# picking
	ed.pick_cell(Vector2i(0, 2))
	print("Picking room (0,2): %s %s (expected 0,2 Hunter's Camp)" % [ed.room_key(), str(ed.room().name)])
	ed.pick_at(Vector2(WorldMapScript.col_x(9) + 100, WorldMapScript.row_y(6) + 100))
	print("Clicking in the world picks the room under it: %s (expected 9,6)" % [ed.room_key()])
	var generated_cell := Vector2i(-1, -1)
	for r in RoomsScript.rooms:
		if not r.authored and r.span == Vector2i(1, 1) and str(r.kind) == "sea" and r.cell.x > 0:
			generated_cell = r.cell
			break
	ed.pick_cell(generated_cell)
	print("A room the generator draws (%s) says so: hand-made %s (expected false)" % [ed.room_key(), ed.is_handmade()])
	ed.pick_cell(Vector2i(4, 3))
	ed.fit_rect(ed.room().rect)
	var view: Rect2 = ed.view_world_rect()
	print("Fitting a room shows all of it: %s (expected true)" % [view.encloses(ed.room().rect) or ed.ui.free_area().size.x * 1.2 > ed.room().rect.size.x * ed.zoom])
	var before_zoom: float = ed.zoom
	var around := Vector2(300, 300)
	var world_before: Vector2 = ed.s2w(around)
	ed.zoom_by(1.5, around)
	print("Zooming with the wheel keeps the point under the mouse still: moved %.2f px (expected under 0.5), zoom %.3f -> %.3f" % [ed.s2w(around).distance_to(world_before), before_zoom, ed.zoom])
	ed.set_view(Vector2(1000, 1000), 0.2)
	ed.cam_pos = Vector2(5000, 5000)
	ed._apply_camera()
	print("The camera follows the view: %s (expected (5000, 5000))" % [ed.camera.position])

# =============================================================================================================================
# editing a room
# =============================================================================================================================

func _editing() -> void:
	print("--- editing a room ---")
	ed.pick_cell(Vector2i(2, 0))        # The Old Orchard: an oval clearing with an orchard
	ed.set_tab("room")
	ed.focus_room()
	await _settle()
	ed.set_room_field("name", "The Test Orchard")
	await _settle()
	print("Renaming the room changes the built room at once: \"%s\" and the editor says unsaved: %s (expected The Test Orchard, true)" % [ed.room().name, ed.dirty])
	ed.set_room_field("mass", "rock")
	await _settle()
	print("Changing its ground changes the built room: %s (expected rock)" % [ed.room().mass])
	ed.set_room_field("target", 7)
	ed.add_resident("brute")
	await _settle()
	var enemies: Array = ed.room().enemies
	print("Residents and the roaming count change: target %d, enemies %s (expected 7, goblin 5, orc 1, brute 1)" % [ed.room().target, enemies])
	ed.set_residents(null)
	await _settle()
	print("Back to the region's usual enemies: the room's own list is empty: %s (expected [])" % [ed.room().enemies])
	ed.set_room_field("name", null)
	print("An empty name removes it: \"%s\" (expected empty)" % [ed.room().name])

	# --- shapes (in the room you wake in: a solid corner of forest at the top right is free to dig into)
	ed.pick_cell(Vector2i(4, 3))
	ed.set_tab("floor")
	ed.focus_room()
	await _settle()
	var shapes_before: int = ed.item_count()
	ed.set_new_mode("floor")
	ed.snap_step = 20.0
	var centre := _local_to_world(Vector2(2400, 560))
	var solid_before: float = RoomsScript.layout(ed.room()).sample(centre)
	ed.arm({"type": "shape", "kind": "ell", "mode": "floor"})
	ed._left_press(centre, false)
	ed._drag_to(centre + Vector2(300, 200))
	ed._left_release(centre + Vector2(300, 200))
	await _settle()
	var op: Array = ed.room_data().shape[ed.room_data().shape.size() - 1]
	print("Dragging out an oval adds it: %d shapes (was %d), the new one is %s (expected +1, [\"ell\", 2400, 560, 300, 200])" % [ed.item_count(), shapes_before, op])
	print("...it is picked, ready to move: sel %d (expected %d)" % [ed.sel_i, shapes_before])
	var layout = RoomsScript.layout(ed.room())
	print("...and the room's real floor now reaches it: depth at its centre was %.0f, now %.0f (expected below 0, then above 100)" % [solid_before, layout.sample(centre)])
	# move it by its body
	_drag(centre, centre + Vector2(103, 61))
	await _settle()
	op = ed.room_data().shape[shapes_before]
	print("Dragging its body moves it by whole grid steps: %s (expected [\"ell\", 2500, 620, 300, 200])" % [op])
	# resize by its east square
	var east := _local_to_world(Vector2(2500 + 300, 620))
	_drag(east, east + Vector2(100, 0))
	await _settle()
	op = ed.room_data().shape[shapes_before]
	print("Dragging its east square makes it wider: %s (expected [\"ell\", 2500, 620, 400, 200])" % [op])
	# type exact numbers
	ed.edit_item(shapes_before, func(m): m.ry = 250)
	print("Typing a number sets it exactly: %s (expected [\"ell\", 2500, 620, 400, 250])" % [ed.room_data().shape[shapes_before]])
	# cut it
	ed.set_new_mode("cut")
	print("With the shape picked, the Cut button turns it into a cut: %s (expected \"-ell\")" % [ed.room_data().shape[shapes_before][0]])
	await _settle()
	layout = RoomsScript.layout(ed.room())
	print("...and the floor there is gone: depth at its centre %.0f (expected below 0)" % [layout.sample(_local_to_world(Vector2(2500, 620)))])
	ed.set_new_mode("floor")
	ed.duplicate_item(shapes_before)
	print("Copy adds another beside it: %d shapes (expected %d)" % [ed.item_count(), shapes_before + 2])
	ed.delete_item(ed.sel_i)
	ed.delete_item(shapes_before)
	await _settle()
	print("Delete removes shapes: %d shapes (expected %d, as at the start)" % [ed.item_count(), shapes_before])
	# a path being drawn
	ed.arm({"type": "shape", "kind": "path", "mode": "floor"})
	ed._left_press(_local_to_world(Vector2(1000, 400)), false)
	ed._left_press(_local_to_world(Vector2(1400, 500)), false)
	ed._left_press(_local_to_world(Vector2(1800, 400)), false)
	ed._finish_polyline()
	print("Clicking points and pressing Enter makes a path: %s (expected [\"path\", 400, 1000, 400, 1400, 500, 1800, 400])" % [ed.room_data().shape[ed.room_data().shape.size() - 1]])
	var path_i: int = ed.sel_i
	ed.edit_item(path_i, func(m): m.pts.remove_at(1))
	print("Removing a point: %d points left (expected 2)" % [ShapesScript.parse_op(ed.room_data().shape[path_i]).pts.size()])
	ed.delete_item(path_i)
	# a polygon
	ed.arm({"type": "shape", "kind": "poly", "mode": "cut"})
	ed.new_mode = "cut"
	ed.armed.mode = "cut"
	ed._left_press(_local_to_world(Vector2(300, 300)), false)
	ed._left_press(_local_to_world(Vector2(500, 300)), false)
	ed._finish_polyline()
	print("A polygon needs three points: %d shapes (expected %d, nothing added yet)" % [ed.item_count(), shapes_before])
	ed._left_press(_local_to_world(Vector2(400, 500)), false)
	ed._finish_polyline()
	print("...with three it is made, as a cut: %s (expected [\"-poly\", 300, 300, 500, 300, 400, 500])" % [ed.room_data().shape[ed.room_data().shape.size() - 1]])
	ed.delete_item(ed.sel_i)
	ed.set_new_mode("floor")

	# --- decoration
	ed.set_tab("decor")
	var decor_before: int = ed.item_count()
	ed.arm({"type": "decor", "kind": "bed"})
	ed._left_press(_local_to_world(Vector2(1300, 300)), false)
	print("Putting down a flower bed: %s (expected [\"bed\", 1300, 300, 5, 3])" % [ed.room_data().decor[ed.room_data().decor.size() - 1]])
	var bed_i: int = ed.sel_i
	ed.edit_item(bed_i, func(m):
		m.cols = 6
		m.rows = 2)
	await _settle()
	print("Changing columns and rows: %s, which stand at %d spots (expected [\"bed\", 1300, 300, 6, 2] and 12)" % [ed.room_data().decor[bed_i], ShapesScript.decor_points(ShapesScript.parse_decor(ed.room_data().decor[bed_i])).size()])
	ed.arm({"type": "decor", "kind": "row"})
	ed._left_press(_local_to_world(Vector2(1000, 1600)), false)
	ed._left_press(_local_to_world(Vector2(1800, 1600)), false)
	print("A row takes two clicks: %s (expected [\"row\", \"tall\", 1000, 1600, 1800, 1600, 150])" % [ed.room_data().decor[ed.room_data().decor.size() - 1]])
	ed.arm({"type": "decor", "kind": "ring"})
	ed._left_press(_local_to_world(Vector2(800, 800)), false)
	ed.arm({"type": "decor", "kind": "pair"})
	ed._left_press(_local_to_world(Vector2(2400, 800)), false)
	print("Rings and pairs: %s and %s (expected [\"ring\", \"tall\", 800, 800, 300, 10] and [\"pair\", \"tall\", 2400, 800, 0, 200])" % [ed.room_data().decor[ed.room_data().decor.size() - 2], ed.room_data().decor[ed.room_data().decor.size() - 1]])
	print("Four new arrangements: %d (expected %d)" % [ed.item_count(), decor_before + 4])
	ed.delete_item(ed.item_count() - 1)
	ed.delete_item(ed.item_count() - 1)
	ed.delete_item(ed.item_count() - 1)
	ed.delete_item(ed.item_count() - 1)
	ed.set_room_field("decor", null)
	print("\"Let the game scatter stands\" removes the decor list: has decor %s (expected false)" % [ed.room_data().has("decor")])
	await _settle()

	# --- set pieces
	ed.set_tab("props")
	ed.arm({"type": "prop", "kind": "pond"})
	ed._left_press(_local_to_world(Vector2(2100, 1700)), false)
	print("A pond is placed with its water: %s (expected [\"pond\", 2100, 1700, \"water\"])" % [ed.room_data().props[0]])
	ed.edit_item(0, func(m):
		m.flavour = "lava"
		m.kind = "camp")
	print("It can be changed to another set piece: %s (expected [\"camp\", 2100, 1700, \"lava\"])" % [ed.room_data().props[0]])
	await _settle()
	print("The room builds with it: set pieces placed %d (expected 1)" % [ed.world.features_placed(ed.room().id)])
	ed.delete_item(0)

	# --- a generated room becomes hand-made, and back
	var gen := Vector2i(-1, -1)
	for r in RoomsScript.rooms:
		if not r.authored and r.span == Vector2i(1, 1) and r.cell.x < 10 and str(r.kind) == "sea":
			gen = r.cell
			break
	ed.pick_cell(gen)
	var made_before: int = ed.doc.rooms.size()
	ed.make_handmade()
	await _settle()
	print("Making a generated room (%s) hand-made adds a starter oval: %d rooms (expected %d), shape %s, hand-made now %s" % [_key(gen), ed.doc.rooms.size(), made_before + 1, ed.room_data().shape, ed.room().authored])
	ed.make_generated()
	await _settle()
	print("Handing it back removes it: %d rooms, authored %s (expected %d, false)" % [ed.doc.rooms.size(), ed.room().authored, made_before])
	ed.pick_cell(Vector2i(4, 3))
	print("The spawn room has been changed a lot by now: still as shipped? %s (expected false)" % [ed.is_factory_room()])
	ed.revert_room_to_factory()
	await _settle()
	print("Revert to shipped puts the room back exactly: %s (expected true)" % [ed.is_factory_room()])
	ed.pick_cell(Vector2i(2, 0))
	ed.revert_room_to_factory()
	ed.set_room_span(2, 1)
	print("A room cannot grow over another hand-made room: span %s (expected [1, 1] -- 3,0 is hand-made)" % [str(ed.room_data().get("span", [1, 1]))])
	ed.pick_cell(Vector2i(0, 4))
	ed.set_room_span(1, 2)
	print("...nor down over 0,5 (the Lizen camp is hand-made too): span %s (expected [1, 1])" % [str(ed.room_data().get("span", [1, 1]))])

# =============================================================================================================================
# doorways
# =============================================================================================================================

func _doorways() -> void:
	print("--- doorways ---")
	ed.pick_cell(Vector2i(4, 3))
	ed.set_tab("doors")
	await _settle()
	var sides: Array = ed.room_sides()
	var names: Array = sides.map(func(s): return s.name)
	print("The spawn room has four sides: %s (expected 4 including 4,3|5,3)" % [names])
	var east: Dictionary = ed.side_by_name("4,3|5,3")
	print("Its east side is open, as shipped: spec %s, opening %s (expected \"open\", [[0.0, 1.0]])" % [east.spec, east.openings])
	ed.set_edge("4,3|5,3", [[1082, 600]])
	await _settle()
	east = ed.side_by_name("4,3|5,3")
	print("Setting a doorway of 600 at 1082 on the 2164 px side gives the opening %.3f to %.3f of it (expected 0.361 to 0.639)" % [east.openings[0][0], east.openings[0][1]])
	var other_side: Dictionary = RoomsScript.edges(RoomsScript.room_at(Vector2(WorldMapScript.col_x(5) + 100, WorldMapScript.row_y(3) + 100))).filter(func(e): return e.side == "w")[0]
	print("The room next door sees the same gap: %.3f to %.3f (expected the same)" % [other_side.openings[0][0], other_side.openings[0][1]])
	ed.select_side("4,3|5,3")
	var side: Dictionary = ed.side_by_name("4,3|5,3")
	var along: Vector2 = (side.to - side.from).normalized()
	var centre_world: Vector2 = side.from + along * 1082.0
	_drag(centre_world, centre_world + along * 203.0)
	await _settle()
	print("Dragging a doorway's middle square moves the doorway (snapped): %s (expected [[1280, 600]])" % [ed.doc.edges["4,3|5,3"]])
	var upper: Vector2 = side.from + along * (1280.0 + 300.0)
	_drag(upper, upper + along * 100.0)
	await _settle()
	print("Dragging its far end widens it: %s (expected [[1330, 700]])" % [ed.doc.edges["4,3|5,3"]])
	ed.edit_doorways("4,3|5,3", func(l): l.append([300, 400]))
	print("A second doorway: %s (expected two)" % [ed.doc.edges["4,3|5,3"].size()])
	ed.set_edge("4,3|5,3", "closed")
	await _settle()
	east = ed.side_by_name("4,3|5,3")
	print("Closed means no opening: %s (expected [])" % [east.openings])
	ed.set_edge("4,3|5,3", "generated")
	print("\"Game decides\" removes the entry: has it %s (expected false)" % [ed.doc.edges.has("4,3|5,3")])
	ed.set_edge("4,3|5,3", "open")
	await _settle()

# =============================================================================================================================
# landmarks, roads, regions
# =============================================================================================================================

func _world_edits() -> void:
	print("--- landmarks, roads and regions ---")
	ed.set_tab("world")
	ed.set_world_tab("landmarks")
	var caves_before: Vector2 = WorldMapScript.landmark("caves").pos
	ed.sel_id = "caves"
	ed.edit_landmark("caves", func(e): e.pos = [32000, 14100])
	await _settle()
	print("Moving the Caves landmark moves it in the world: %s -> %s (expected (32000, 14100))" % [caves_before, WorldMapScript.landmark("caves").pos])
	ed.edit_landmark("caves", func(e): e.name = "The Deep Caves")
	print("...and renames it: %s (expected The Deep Caves)" % [WorldMapScript.landmark("caves").name])
	ed.sel_id = "ruins"
	var ruins_pos: Vector2 = ed.landmark_pos("ruins")
	ed.world_tab = "landmarks"
	_drag(ruins_pos, ruins_pos + Vector2(203, 0))
	await _settle()
	print("Dragging a landmark on the map moves it by whole grid steps: %s (expected (15472.5, 1082))" % [WorldMapScript.landmark("ruins").pos])
	ed.sel_id = "pesca"
	var pesca_before: Vector2 = ed.landmark_pos("pesca")
	var hit: Dictionary = ed.hit_test(pesca_before)
	ed._left_press(pesca_before, false)
	ed._drag_to(pesca_before + Vector2(500, 0))
	ed._left_release(pesca_before + Vector2(500, 0))
	print("Pesca cannot be dragged (its houses are placed by code): %s -> %s (expected unchanged)" % [pesca_before, ed.landmark_pos("pesca")])
	ed.undo()
	ed.undo()
	await _settle()
	print("Undo walks the landmarks back: caves %s, ruins %s (expected the original %s and (15272.5, 1082))" % [WorldMapScript.landmark("caves").pos, WorldMapScript.landmark("ruins").pos, caves_before])
	ed.redo()
	ed.redo()
	await _settle()

	# roads
	ed.set_world_tab("roads")
	var roads_before: int = ed.doc.roads.size()
	ed.armed = {"type": "road", "points": []}
	ed.armed.points = [Vector2(12000, 9000), Vector2(13000, 9500), Vector2(14000, 9000)]
	ed._finish_polyline()
	print("Clicking three points and pressing Enter lays a road: %d roads (expected %d), points %s" % [ed.doc.roads.size(), roads_before + 1, ed.doc.roads[ed.doc.roads.size() - 1].points])
	var road_i: int = ed.doc.roads.size() - 1
	ed.edit_road(road_i, func(r):
		r.width = 120
		r.style = "boards")
	print("Its width and surface can be set: %s (expected width 120, style boards)" % [{"w": ed.doc.roads[road_i].width, "s": ed.doc.roads[road_i].style}])
	ed.sel_i = road_i
	var p1: Vector2 = ed.road_point_world(ed.doc.roads[road_i].points[1])
	_drag(p1, p1 + Vector2(0, 400))
	print("Dragging a road point moves it: now at world y %.0f (expected about 9900)" % [ed.road_point_world(ed.doc.roads[road_i].points[1]).y])
	var px_back: Array = ed.px_to_cell(ed.road_point_world([5.295, 9.5]))
	print("Converting a position to cells and back is exact: %s (expected [5.295, 9.5])" % [px_back])
	ed._remove_point(1)
	print("Removing a point: %d points (expected 2)" % [ed.doc.roads[road_i].points.size()])
	ed.delete_road(road_i)
	print("Deleting the road: %d roads (expected %d)" % [ed.doc.roads.size(), roads_before])
	await _settle()

	# regions
	ed.set_world_tab("regions")
	var tier_before: int = WorldMapScript.region("woods").tier
	ed.edit_region("woods", func(r): r.tier = 5)
	await _settle()
	print("Changing a region's danger tier changes the world: %d -> %d (expected 2 -> 5); the room you wake in lies mostly in the Great Expanse, so it stays at tier %d (expected 1)" % [tier_before, WorldMapScript.region("woods").tier, ed.room().tier])
	var heart_room: Dictionary = RoomsScript.room_at(WorldMapScript.landmark("heartwood").pos)
	print("...the HeartWood's room belongs to its own grove region, so its tier stays: %d (expected 3)" % [heart_room.tier])
	var den_room: Dictionary = RoomsScript.room_at(Vector2(WorldMapScript.col_x(0) + 500, WorldMapScript.row_y(4) + 500))
	print("...and the Wolf Den, in the woods proper, now has tier %d (expected 5)" % [den_room.tier])
	ed.edit_region("woods", func(r):
		r.enemies.append(["brute", 2])
		r.miniboss = "voidwing")
	print("...its residents and miniboss: %s, %s (expected brute 2 added, voidwing)" % [WorldMapScript.region("woods").enemies.slice(-1), WorldMapScript.region("woods").miniboss])
	ed.edit_region("woods", func(r): r.name = "Wild Lexia")
	print("...and name: %s (expected Wild Lexia)" % [WorldMapScript.region("woods").name])
	ed.undo()
	ed.undo()
	ed.undo()
	await _settle()
	print("Undo puts it all back: tier %d, miniboss \"%s\", name %s (expected 2, empty, Central Lexia)" % [WorldMapScript.region("woods").tier, WorldMapScript.region("woods").miniboss, WorldMapScript.region("woods").name])

# =============================================================================================================================
# the real mouse and keyboard
# =============================================================================================================================

func _mouse_button(btn: int, pressed: bool, pos: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = btn
	ev.pressed = pressed
	ev.position = pos
	ev.global_position = pos
	return ev

func _mouse_move(pos: Vector2) -> InputEventMouseMotion:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	return ev

func _key_event(code: int, pressed: bool = true, ctrl: bool = false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	ev.ctrl_pressed = ctrl
	return ev

func _real_input() -> void:
	print("--- the mouse and keyboard, through the real input path ---")
	await _undo_everything()
	ed.set_tab("room")
	ed.pick_cell(Vector2i(4, 3))
	var target := Vector2(WorldMapScript.col_x(5) + 700, WorldMapScript.row_y(3) + 700)
	ed.focus_point(target, 0.15)
	await _settle()
	var screen: Vector2 = ed.w2s(target)
	root.push_input(_mouse_button(MOUSE_BUTTON_LEFT, true, screen))
	root.push_input(_mouse_button(MOUSE_BUTTON_LEFT, false, screen))
	print("A left click on the map picks the room under the mouse: %s (expected 5,3)" % [ed.room_key()])
	var cam_before_drag: Vector2 = ed.cam_pos
	var zoom_before_drag: float = ed.zoom
	root.push_input(_mouse_button(MOUSE_BUTTON_LEFT, true, Vector2(200, 400)))
	root.push_input(_mouse_move(Vector2(150, 380)))
	root.push_input(_mouse_button(MOUSE_BUTTON_LEFT, false, Vector2(150, 380)))
	print("Dragging the empty map with the left button moves the view and picks nothing: moved (%.0f, %.0f) (expected (%.0f, %.0f)), room still %s (expected 5,3)" % [ed.cam_pos.x - cam_before_drag.x, ed.cam_pos.y - cam_before_drag.y, 50.0 / zoom_before_drag, 20.0 / zoom_before_drag, ed.room_key()])
	var z0: float = ed.zoom
	root.push_input(_mouse_button(MOUSE_BUTTON_WHEEL_UP, true, Vector2(300, 300)))
	print("The mouse wheel zooms the editor's view: %.3f -> %.3f (expected larger, never above 1.6)" % [z0, ed.zoom])
	var cam0: Vector2 = ed.cam_pos
	var zoom1: float = ed.zoom
	root.push_input(_mouse_button(MOUSE_BUTTON_RIGHT, true, Vector2(400, 300)))
	root.push_input(_mouse_move(Vector2(300, 300)))
	root.push_input(_mouse_button(MOUSE_BUTTON_RIGHT, false, Vector2(300, 300)))
	print("Dragging with the right button pans the view by what the mouse moved: %.1f px of world (expected %.1f)" % [ed.cam_pos.x - cam0.x, 100.0 / zoom1])
	var cam1: Vector2 = ed.cam_pos
	root.push_input(_key_event(KEY_SPACE, true))
	root.push_input(_mouse_button(MOUSE_BUTTON_LEFT, true, Vector2(400, 300)))
	root.push_input(_mouse_move(Vector2(450, 340)))
	root.push_input(_mouse_button(MOUSE_BUTTON_LEFT, false, Vector2(450, 340)))
	root.push_input(_key_event(KEY_SPACE, false))
	print("Space and a left drag pans too, and picks nothing: moved (%.0f, %.0f) (expected (%.0f, %.0f)), room still %s (expected 5,3)" % [ed.cam_pos.x - cam1.x, ed.cam_pos.y - cam1.y, -50.0 / zoom1, -40.0 / zoom1, ed.room_key()])
	# dragging a shape's square with the mouse
	ed.pick_cell(Vector2i(4, 3))
	ed.set_tab("floor")
	ed.focus_room()
	ed.select_item(0)
	await _settle()
	var steps_at_start: int = ed.undo_stack.size()
	var east_world: Vector2 = ed.room_origin() + Vector2(900 + 720, 1082)
	var from: Vector2 = ed.w2s(east_world)
	var to: Vector2 = from + Vector2(200.0 * ed.zoom, 0.0)
	root.push_input(_mouse_button(MOUSE_BUTTON_LEFT, true, from))
	root.push_input(_mouse_move(to))
	root.push_input(_mouse_button(MOUSE_BUTTON_LEFT, false, to))
	await _settle()
	print("Pulling the oval's east square with the mouse: %s (expected [\"ell\", 900, 1082, 920, 540])" % [ed.room_data().shape[0]])
	print("...a whole drag is one undo step: %d (expected 1)" % [ed.undo_stack.size() - steps_at_start])
	root.push_input(_key_event(KEY_Z, true, true))
	await _settle()
	print("Ctrl+Z undoes it: %s (expected [\"ell\", 900, 1082, 720, 540])" % [ed.room_data().shape[0]])
	root.push_input(_key_event(KEY_Y, true, true))
	await _settle()
	print("Ctrl+Y does it again: %s (expected 920 wide)" % [ed.room_data().shape[0]])
	var count: int = ed.item_count()
	ed.select_item(1)
	root.push_input(_key_event(KEY_DELETE, true))
	await _settle()
	print("Delete removes the picked shape: %d shapes (expected %d)" % [ed.item_count(), count - 1])
	root.push_input(_key_event(KEY_Z, true, true))
	await _settle()
	print("...and Ctrl+Z brings it back: %d shapes (expected %d)" % [ed.item_count(), count])
	# a drag that ends where it started leaves no undo step
	var undo_before: int = ed.undo_stack.size()
	var oval_c: Vector2 = ed.room_origin() + Vector2(900, 1082)
	ed.select_item(0)
	var a: Vector2 = ed.w2s(oval_c + Vector2(100, 100))
	root.push_input(_mouse_button(MOUSE_BUTTON_LEFT, true, a))
	root.push_input(_mouse_move(a + Vector2(60, 0)))
	root.push_input(_mouse_move(a))
	root.push_input(_mouse_button(MOUSE_BUTTON_LEFT, false, a))
	print("Dragging something and putting it back where it was adds no undo step: %d (expected %d)" % [ed.undo_stack.size(), undo_before])
	# armed things
	ed.arm({"type": "shape", "kind": "ell", "mode": "floor"})
	root.push_input(_key_event(KEY_ESCAPE, true))
	print("Esc puts down what was picked up to draw: armed=%s (expected {})" % [ed.armed])
	var grid: bool = ed.grid_on
	root.push_input(_key_event(KEY_G, true))
	print("G switches the grid: %s -> %s (expected true -> false)" % [grid, ed.grid_on])
	root.push_input(_key_event(KEY_TAB, true))
	print("Tab hides the right panel: shown=%s, so the map gets the whole window: free width %d (expected false, 1152)" % [ed.ui.panel_shown, int(ed.ui.free_area().size.x)])
	root.push_input(_key_event(KEY_TAB, true))
	root.push_input(_key_event(KEY_HOME, true))
	print("Home shows the whole world: zoom %.3f (expected under 0.03)" % [ed.zoom])
	root.push_input(_key_event(KEY_F, true))
	print("F fits the picked room: zoom %.3f (expected above 0.1)" % [ed.zoom])
	root.push_input(_key_event(KEY_G, true))
	# the little map
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	var cp: float = ed.ui.minimap.size.x / 11.0
	click.position = Vector2(cp * 7.5, cp * 1.5)
	ed.ui.minimap._gui_input(click)
	print("Clicking a square of the little map picks that room: %s %s (expected 7,1 The Crater)" % [ed.room_key(), str(ed.room().name)])
	# how fast is an edit?
	ed.pick_cell(Vector2i(4, 3))
	ed.focus_room()
	await _settle()
	var t0 := Time.get_ticks_msec()
	ed.set_room_field("mass", "rock")
	ed.world.flush()
	var t1 := Time.get_ticks_msec()
	print("Changing the ground of the room you are looking at, and rebuilding it with every tree: %d ms (expected under 1500)" % [t1 - t0])
	ed.undo()
	await _settle()

# =============================================================================================================================
# the panels' own buttons and number boxes
# =============================================================================================================================

func _find(node: Node, test: Callable, out: Array) -> void:
	for c in node.get_children():
		if test.call(c):
			out.append(c)
		_find(c, test, out)

func _button_with(text_start: String, within: Node):
	var found: Array = []
	_find(within, func(n): return n is PixelButton and n.text.begins_with(text_start), found)
	return found[0] if not found.is_empty() else null

func _field_labelled(label_text: String):
	var found: Array = []
	_find(ed.ui._body, func(n): return n is HBoxContainer and n.get("edit") != null and n.get_child_count() > 0 and n.get_child(0) is Label and n.get_child(0).text == label_text, found)
	return found[0] if not found.is_empty() else null

func _undo_everything() -> void:
	while not ed.undo_stack.is_empty():
		ed.undo()
	await _settle()

func _ui_wiring() -> void:
	print("--- the panels' own buttons and number boxes ---")
	await _undo_everything()
	ed.pick_cell(Vector2i(4, 3))
	ed.set_tab("room")
	await _settle()
	var name_field = _field_labelled("Name")
	name_field.edit.text = "Typed Name"
	name_field.edit.text_submitted.emit("Typed Name")
	await _settle()
	print("Typing a name and pressing Enter in the Name box renames the room: \"%s\" (expected Typed Name)" % [ed.room_data().get("name", "")])
	var roam = _field_labelled("Roaming")
	roam.edit.text = "11"
	roam.edit.text_submitted.emit("11")
	await _settle()
	print("Typing 11 in the Roaming box sets it: %s (expected 11)" % [ed.room_data().get("target", -1)])
	roam = _field_labelled("Roaming")
	roam.edit.text = "lots"
	roam.edit.text_submitted.emit("lots")
	await _settle()
	roam = _field_labelled("Roaming")
	print("Typing a word instead of a number is refused and the box goes back: target %s, box shows %s (expected 11, 11)" % [ed.room_data().get("target", -1), roam.edit.text])
	var minus = roam.get_child(1)
	minus.pressed.emit()
	await _settle()
	print("The - button steps the number down: %s (expected 10)" % [ed.room_data().get("target", -1)])
	roam = _field_labelled("Roaming")
	roam.get_child(3).pressed.emit()
	await _settle()
	print("The + button steps it up: %s (expected 11)" % [ed.room_data().get("target", -1)])
	var ground_button = _button_with("Forest", ed.ui._body)
	print("The Ground button names the current ground: %s (expected found)" % [ground_button != null])
	ground_button.pressed.emit()
	var rock = _button_with("Rock", ed.ui._popup_layer)
	rock.pressed.emit()
	await _settle()
	print("Picking Rock in the pop-up changes the ground: %s, and the pop-up is gone: %s (expected rock, 0)" % [ed.room_data().get("mass", ""), ed.ui._popup_layer.get_child_count()])
	_button_with("Own list", ed.ui._body).pressed.emit()
	await _settle()
	var own: Array = ed.room_data().get("enemies", [])
	print("\"Own list\" starts from the region's table: %s (expected the region's goblins, orcs and so on)" % [own])
	_button_with("+ Add an enemy", ed.ui._body).pressed.emit()
	_button_with("Brute", ed.ui._popup_layer).pressed.emit()
	await _settle()
	print("Adding a Brute from the pop-up: %s (expected a brute at the end)" % [ed.room_data().enemies.back()])
	_button_with("Region's usual", ed.ui._body).pressed.emit()
	await _settle()
	print("\"Region's usual\" drops the list: has enemies %s (expected false)" % [ed.room_data().has("enemies")])
	# Floor tab
	ed.set_tab("floor")
	ed.select_item(0)
	await _settle()
	var half_w = _field_labelled("Half width")
	half_w.edit.text = "800"
	half_w.edit.text_submitted.emit("800")
	await _settle()
	print("Typing 800 in the oval's Half width box: %s (expected [\"ell\", 900, 1082, 800, 540])" % [ed.room_data().shape[0]])
	_button_with("Cut", ed.ui._body).pressed.emit()
	await _settle()
	print("The Cut button, with the shape picked, turns it into a cut: %s (expected -ell)" % [ed.room_data().shape[0][0]])
	_button_with("Floor", ed.ui._body).pressed.emit()
	await _settle()
	_button_with("+ Circle", ed.ui._body).pressed.emit()
	print("+ Circle arms the circle tool: %s (expected circle, i.e. disc, armed)" % [ed.armed])
	ed.disarm()
	_button_with("Delete", ed.ui._body).pressed.emit()
	await _settle()
	print("The Delete button removes the picked shape: %d shapes (expected 4)" % [ed.item_count()])
	ed.undo()
	ed.undo()
	ed.undo()
	await _settle()
	# Doors tab
	ed.set_tab("doors")
	await _settle()
	_button_with("East of", ed.ui._body).pressed.emit()
	await _settle()
	_button_with("Closed", ed.ui._body).pressed.emit()
	await _settle()
	print("Doors tab: picking the east side and pressing Closed: %s (expected closed)" % [ed.doc.edges["4,3|5,3"]])
	_button_with("Doorways", ed.ui._body).pressed.emit()
	await _settle()
	print("...then Doorways: %s (expected one doorway, 520 wide)" % [ed.doc.edges["4,3|5,3"]])
	var centre_box = _field_labelled("Doorway 1 centre")
	centre_box.edit.text = "700"
	centre_box.edit.text_submitted.emit("700")
	await _settle()
	print("...and its centre typed in: %s (expected [[700, 520]])" % [ed.doc.edges["4,3|5,3"]])
	_button_with("Game decides", ed.ui._body).pressed.emit()
	await _settle()
	print("...then Game decides: has an entry %s (expected false)" % [ed.doc.edges.has("4,3|5,3")])
	while ed.undo_stack.size() > 0 and not MapDataScript.same(ed.doc, RoomDataScript.document(), 0.0):
		ed.undo()
	# World tab
	ed.set_tab("world")
	ed.set_world_tab("landmarks")
	await _settle()
	_button_with("The Caves", ed.ui._body).pressed.emit()
	await _settle()
	var lx = _field_labelled("X")
	lx.edit.text = "31900"
	lx.edit.text_submitted.emit("31900")
	await _settle()
	print("World tab: picking The Caves and typing its X: %s (expected 31900)" % [ed.landmark_entry("caves").pos[0]])
	ed.undo()
	ed.set_world_tab("regions")
	ed.sel_id = "woods"
	ed.ui.refresh()
	await _settle()
	var tier_box = _field_labelled("Danger (1-8)")
	tier_box.edit.text = "7"
	tier_box.edit.text_submitted.emit("7")
	await _settle()
	print("Regions: typing a danger of 7 for the woods: tier %d (expected 7)" % [ed.doc.regions["woods"].tier])
	ed.undo()
	await _settle()
	ed.pick_cell(Vector2i(4, 3))
	while ed.undo_stack.size() > 0:
		ed.undo()
	await _settle()
	print("Everything undone again: nothing unsaved against the shipped data: %s (expected true)" % [MapDataScript.same(ed.doc, ed.pushed_doc, 0.0)])

# =============================================================================================================================
# the map check
# =============================================================================================================================

func _checks() -> void:
	print("--- the map check ---")
	await _undo_everything()
	var problems: Array = ed.check_map()
	print("The shipped map has nothing wrong with it: %s (expected [])" % [problems.map(func(p): return p[0])])
	# close every doorway of the Wolf Den (0,4): nobody can walk in
	ed.pick_cell(Vector2i(0, 4))
	var steps_before: int = ed.undo_stack.size()
	for s in ed.room_sides():
		ed.set_edge(s.name, "closed")
	var cut_off: Array = ed.check_map()
	print("Closing every doorway of the Wolf Den (0,4) is noticed: %s (expected one, naming room 0,4)" % [cut_off.map(func(p): return p[0])])
	while ed.undo_stack.size() > steps_before:
		ed.undo()
	await _settle()
	print("...undone, the map is fine again: %d problems (expected 0)" % [ed.check_map().size()])
	ed.edit_landmark("ruins", func(e): e.pos = [900, 22800])
	await _settle()
	cut_off = ed.check_map()
	print("A place dragged out into the deep sea is noticed: %s (expected one saying The Ruined Settlement stands in deep water)" % [cut_off.map(func(p): return p[0])])
	ed.undo()
	await _settle()
	ed.pick_cell(Vector2i(4, 3))
	ed.set_room_field("enemies", [["dragon", 3]])
	print("An enemy the game does not know is noticed: %s (expected one naming dragon)" % [ed.check_map().map(func(p): return p[0])])
	ed.undo()
	await _settle()

# =============================================================================================================================
# undo, redo and saving
# =============================================================================================================================

func _undo_and_save() -> void:
	print("--- undo, redo and saving ---")
	# a fresh editor on a folder that has the files already
	ed.queue_free()
	await process_frame
	await process_frame
	SaveDataScript.sandbox_active = false
	var dir := SCRATCH + "/save"
	ed = _new_editor(dir)
	await _settle()
	var first_save: bool = ed.save()
	print("The first save in an empty folder writes the files: %s, %s (expected true, all five)" % [first_save, DirAccess.get_files_at(dir)])
	print("...and the editor is clean: dirty=%s (expected false)" % [ed.dirty])
	print("...with no backups, as there was nothing to back up: %s (expected no folder)" % [DirAccess.dir_exists_absolute(dir + "/backups")])
	var original: Dictionary = MapDataScript.copy(ed.doc)
	ed.pick_cell(Vector2i(3, 0))
	ed.set_room_field("name", "Plaza One")
	ed.set_room_field("target", 9)
	ed.set_tab("floor")
	ed.arm({"type": "shape", "kind": "disc", "mode": "floor"})
	ed._left_press(_local_to_world(Vector2(1500, 1000)), false)
	ed._left_release(_local_to_world(Vector2(1500, 1000)))
	print("Three edits: %d undo steps, unsaved: %s %s (expected 3, true, [rooms])" % [ed.undo_stack.size(), ed.dirty, ed.unsaved_kinds()])
	ed.undo()
	ed.undo()
	ed.undo()
	await _settle()
	print("Undo three times: the document is as it was: %s, and the marker is gone: dirty=%s (expected true, false)" % [MapDataScript.same(ed.doc, original, 0.0), ed.dirty])
	print("The built room is as it was too: \"%s\", target %d (expected empty name, the shipped target)" % [ed.room().name, ed.room().target])
	ed.redo()
	ed.redo()
	ed.redo()
	await _settle()
	print("Redo three times: name \"%s\", target %d, shapes %d (expected Plaza One, 9, +1)" % [ed.room().name, ed.room().target, ed.item_count()])
	var rooms_text_before := FileAccess.get_file_as_string(dir + "/rooms.json")
	var saved: bool = ed.save()
	print("Saving: %s; rooms.json changed on disk: %s (expected true, true)" % [saved, FileAccess.get_file_as_string(dir + "/rooms.json") != rooms_text_before])
	print("The old rooms.json was kept: %s (expected one file named rooms_<date>_<time>.json, and only for rooms)" % [DirAccess.get_files_at(dir + "/backups")])
	var backups := DirAccess.get_files_at(dir + "/backups")
	var kept := FileAccess.get_file_as_string(dir + "/backups/" + backups[0]) if not backups.is_empty() else ""
	print("...and it is exactly what was there before the save: %s (expected true)" % [kept == rooms_text_before])
	var back: Dictionary = MapDataScript.read("rooms", dir)
	print("What was written reads back as the edited data: %s, name \"%s\" (expected ok, Plaza One)" % [back.status, str(back.data.get("3,0", {}).get("name", ""))])
	print("The marker clears after saving: dirty=%s, a second Save has nothing to do: %s (expected false, true)" % [ed.dirty, ed.save()])
	print("...and keeps no second backup: %d (expected 1)" % [DirAccess.get_files_at(dir + "/backups").size()])
	# the game reading the saved folder sees the edit
	RoomDataScript.read_files(dir)
	var snap := _snapshot()
	print("The game, reading that folder, builds the edited room: name \"%s\" target %d (expected Plaza One, 9)" % [snap.rooms["r3_0"].name, snap.rooms["r3_0"].target])
	RoomDataScript.read_files(MapDataScript.DIR)
	# saving into a folder that cannot be written
	var blocker := FileAccess.open(SCRATCH + "/blocker", FileAccess.WRITE)
	blocker.store_string("a file where a folder would have to be")
	blocker.close()
	ed.data_dir = SCRATCH + "/blocker/inside"
	ed.set_room_field("name", "x")
	print("(Godot prints its own 'Could not create directory' line next: that is the failure being provoked)")
	var bad_save: bool = ed.save()
	print("A save that cannot be written says so and keeps the changes: saved=%s, still unsaved=%s (expected false, true)" % [bad_save, ed.dirty])
	ed.data_dir = dir

# =============================================================================================================================
# the panels and the title screen
# =============================================================================================================================

func _ui_and_title() -> void:
	print("--- the panels and the title screen ---")
	ed.pick_cell(Vector2i(4, 3))
	var problems: Array = []
	for t in ed.TABS:
		ed.set_tab(t)
		await process_frame
		await process_frame
		var rows: int = ed.ui._body.get_child_count()
		if rows < 2:
			problems.append("%s: only %d rows" % [t, rows])
	for wt in ed.WORLD_TABS:
		ed.set_tab("world")
		ed.set_world_tab(wt)
		await process_frame
		await process_frame
	print("Every tab builds its panel without trouble: problems %s (expected [])" % [problems])
	var vp: Vector2 = ed.viewport_size()
	print("The window is %s (the default 1152 x 648 is what the layout is made for)" % [vp])
	ed.set_tab("room")
	await process_frame
	await process_frame
	# (how the words fit the buttons and rows is checked with the real fonts, by tools/test_map_editor_shots.gd: a headless run measures
	# text with a stand-in font)
	var panel: Control = ed.ui._panel
	var free: Rect2 = ed.ui.free_area()
	print("The right panel is %d px wide and the free part of the window for the map is %s (expected 432 and at least 700 x 500)" % [int(panel.size.x), free.size])
	print("The layer that draws grids, handles and place names covers the whole window: %s of %s (expected equal)" % [ed.overlay.size, ed.viewport_size()])
	ed.set_tab("floor")
	ed.select_item(0)
	await process_frame
	await process_frame
	print("With a shape picked the Floor tab lists its fields: %d rows (expected a dozen or so)" % [ed.ui._body.get_child_count()])
	ed.ui.toggle_help()
	print("The help sheet opens: %s (expected true); Esc-style closing: %s then visible %s (expected true false)" % [ed.ui._help.visible, ed.ui.close_popups(), ed.ui._help.visible])
	ed.ui.choose("Test", [["a", "Alpha"], ["b", "Beta"]], "a", func(id): pass)
	print("A chooser pop-up opens and closes: %d popup(s), closed=%s (expected 1, true)" % [ed.ui._popup_layer.get_child_count(), ed.ui.close_popups()])
	# leaving without saving must not leak the edits into the game
	ed.edit_landmark("heartwood", func(e): e.pos = [6200, 4400])
	ed.set_room_field("name", "Leaky")
	ed.queue_free()
	await process_frame
	await process_frame
	print("Leaving the editor without saving gives the game back the data on disk: heartwood at %s, room 4,3 \"%s\" (expected (6109.5, 4327.5), Where You Woke)" % [WorldMapScript.landmark("heartwood").pos, RoomsScript.room_at(Vector2(13000, 7500)).name])
	# the title screen entry
	var title = load("res://TitleScreen.tscn").instantiate()
	root.add_child(title)
	await process_frame
	await process_frame
	var found: bool = title.map_editor_button != null
	var labels: Array = []
	for c in title.main_menu_box.get_children():
		if c is TitleEntry:
			labels.append(c.text)
	print("The title screen's main menu lists: %s (expected ... Sandbox, Map Editor, Switch File ...)" % [labels])
	print("The Map Editor entry exists and sits right after Sandbox: %s (expected true)" % [found and labels.find("Map Editor") == labels.find("Sandbox") + 1])
	# the whole trip: press the entry, land in the editor, leave again
	SaveDataScript.sandbox_active = false
	title._on_map_editor_pressed()
	title.queue_free()
	for i in 8:
		await process_frame
	var opened: Node = root.get_node_or_null("MapEditor")
	print("Pressing Map Editor opens the editor scene: %s, with the save files switched to in-memory mode: %s (expected true, true)" % [opened != null, SaveDataScript.sandbox_active])
	if opened != null:
		print("...it opened on the shipped data with nothing to save: dirty=%s (expected false)" % [opened.dirty])
		opened.ui._on_exit()
		for i in 8:
			await process_frame
		var back: Node = root.get_node_or_null("TitleScreen")
		print("Exit with nothing unsaved goes straight back to the title screen: %s, and the real saves are live again: sandbox flag %s (expected true, false)" % [back != null, SaveDataScript.sandbox_active])
		if back != null:
			back.queue_free()
