extends Node

# THE MAP EDITOR (title screen > Map Editor). It shows the real overworld -- the same renderer the game uses (MapEditorWorld, an
# OverworldMap) -- with a free camera, and lets you change the hand-made map data (res://data/*.json, see MapData.gd / RoomData.gd) by
# mouse and by typing numbers: pick a room, then edit its name, ground, enemies, floor shapes, decoration, set pieces and doorways;
# move the named places; lay roads; tune a region's danger and residents. Every change shows at once. Save writes the data files (the old
# ones are kept in res://data/backups/); nothing the editor does touches your save files (SaveData.sandbox_active is on, like the Sandbox).
#
# This file holds the editor's state and everything that CHANGES the map. The pictures on top of the map (MapEditorOverlay.gd) and the
# panels (MapEditorUI.gd) only read from it and call back into it.

const SaveDataScript := preload("res://scripts/SaveData.gd")
const WorldMapScript := preload("res://scripts/WorldMap.gd")
const RoomsScript := preload("res://scripts/Rooms.gd")
const RoomDataScript := preload("res://scripts/RoomData.gd")
const MapDataScript := preload("res://scripts/MapData.gd")
const ShapesScript := preload("res://scripts/MapEditorShapes.gd")
const WorldScript := preload("res://scripts/MapEditorWorld.gd")
const UIScript := preload("res://scripts/MapEditorUI.gd")
const OverlayScript := preload("res://scripts/MapEditorOverlay.gd")
const OverworldMapScript := preload("res://scripts/OverworldMap.gd")
const PlayScript := preload("res://scripts/MapEditorPlay.gd")

const TABS := ["room", "floor", "decor", "props", "doors", "world"]
const TAB_NAMES := {"room": "Room", "floor": "Floor", "decor": "Decor", "props": "Props", "doors": "Doors", "world": "World"}
const WORLD_TABS := ["landmarks", "roads", "regions"]
const UNDO_MAX := 100
const ZOOM_MIN := 0.015
const ZOOM_MAX := 1.6
const SNAPS := [0.0, 10.0, 20.0, 40.0, 80.0, 160.0]
const PAN_SPEED := 760.0                   # screen px per second
const HANDLE_PX := 11.0                    # how close (screen px) the mouse must be to grab a handle
# Who can live in a room (the keys of Main.REGION_ENEMY_SCRIPTS) and which minibosses a region can have (Main.MINIBOSS_SCRIPTS).
const ENEMY_KEYS := ["goblin", "orc", "archer", "brute", "shade", "wolf", "centaur_pack", "fae_hut", "gnome_pack", "shadelet", "disgraced_mage", "fire_mage", "hermoid", "earth_mage", "gale_mage", "treant", "voidwing", "empowered_mage"]
const ENEMY_NAMES := {"goblin": "Goblin", "orc": "Orc", "archer": "Archer", "brute": "Brute", "shade": "Shade", "wolf": "Wolf",
	"centaur_pack": "Centaur pack", "fae_hut": "Fae hut", "gnome_pack": "Gnome pack",
	"shadelet": "Shadelet", "disgraced_mage": "Disgraced Mage", "fire_mage": "Fire Mage", "hermoid": "Hermoid", "earth_mage": "Earth Mage", "gale_mage": "Gale Mage", "treant": "Treant", "voidwing": "Voidwing", "empowered_mage": "Empowered Mage"}
const MINIBOSS_KEYS := ["", "black_dragonlet", "iron_construct", "lava_construct", "voidwing_swarm", "water_construct", "stone_construct", "frost_construct", "wyrm_hole"]
const MINIBOSS_NAMES := {"": "None", "black_dragonlet": "Black dragonlet", "iron_construct": "Steel construct",
	"lava_construct": "Magma construct", "voidwing_swarm": "Voidwing swarm",
	"water_construct": "Water construct", "stone_construct": "Stone construct", "frost_construct": "Frost construct", "wyrm_hole": "Wyrm-Hole"}
const ROAD_STYLES := ["", "boards", "ash", "snow", "sand", "crystal"]
const ROAD_STYLE_NAMES := {"": "Dirt", "boards": "Boards", "ash": "Ash", "snow": "Snow", "sand": "Sand", "crystal": "Crystal"}
# Landmarks the game's code puts at fixed spots (the town in the middle, where you wake, Pesca's houses and docks), so they cannot be
# moved here: their number is only shown.
const FIXED_LANDMARKS := ["spawn", "town", "pesca"]

# --- the document being edited ----------------------------------------------------------------------------------------------
var data_dir := MapDataScript.DIR        # where Save writes (the tests point it at a scratch folder)
var doc: Dictionary = {}                 # rooms, edges, roads, landmarks, regions: the working copy
var pushed_doc: Dictionary = {}          # what the built world currently shows
var saved_texts: Dictionary = {}         # kind -> the file's text when it was last loaded or saved
var undo_stack: Array = []
var redo_stack: Array = []
var dirty := false
var load_report: Array = []              # what was wrong with the data files when they were read

# --- what is on screen --------------------------------------------------------------------------------------------------------
var world                                # MapEditorWorld
var camera: Camera2D
var ui                                   # MapEditorUI
var overlay                              # MapEditorOverlay
var play                                 # MapEditorPlay: the walker for Play here
var cam_pos := Vector2(16800, 11900)
var zoom := 0.05
var view_changed := true

# --- what is picked ----------------------------------------------------------------------------------------------------------
var room_cell := Vector2i(-1, -1)        # the picked room's top-left cell
var tab := "room"
var world_tab := "landmarks"
var sel_i := -1                          # the picked shape / decoration / set piece / road / (landmark by id below)
var sel_id := ""                         # the picked doorway side ("4,3|5,3"), landmark id or region id
var sel_pt := -1                         # the picked point of a road
var armed: Dictionary = {}               # something chosen to be put down next: {type, kind, mode, points}
var new_mode := "floor"                  # what a new shape is: floor, cut or bridge
var snap_step := 20.0
var grid_on := true
var show_all_doors := false
var drag: Dictionary = {}
var _pan: Dictionary = {}
var _space_down := false

func _ready() -> void:
	# Whatever happens in here must never reach the real save files (the same switch the Sandbox uses).
	SaveDataScript.sandbox_active = true
	SaveDataScript.sandbox_data = {}
	_open_document()
	world = WorldScript.new()
	world.name = "World"
	add_child(world)
	world.start()
	camera = Camera2D.new()
	camera.position_smoothing_enabled = false
	add_child(camera)
	camera.make_current()
	ui = UIScript.new()
	ui.name = "UI"
	add_child(ui)
	ui.setup(self)
	overlay = ui.overlay
	play = PlayScript.new()
	play.name = "Play"
	add_child(play)
	play.setup(self)
	# open on the room you wake in, close enough to see the real thing (Home, or a click on the little map, goes anywhere else)
	pick_at(WorldMapScript.spawn_position())
	focus_room()
	_apply_camera()

func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	# Leaving the editor (saved or not): the game goes back to reading what is on disk, never the editor's unsaved working copy.
	RoomDataScript.read_files(MapDataScript.DIR)
	RoomsScript.reset()
	WorldMapScript.reset()

# --- the document ------------------------------------------------------------------------------------------------------------------

func _open_document() -> void:
	doc = RoomDataScript.document()
	RoomsScript.reset()
	WorldMapScript.reset()
	WorldMapScript.ensure_built()
	doc.landmarks = MapDataScript.landmark_entries(WorldMapScript.landmarks)
	doc.regions = MapDataScript.region_entries(WorldMapScript.regions)
	load_report = RoomDataScript.report.duplicate()
	saved_texts = {}
	for kind in MapDataScript.KINDS:
		var path := MapDataScript.file_path(kind, data_dir)
		var on_disk := ""
		if FileAccess.file_exists(path):
			on_disk = FileAccess.get_file_as_string(path)
		# a text read back from disk would differ from ours only in the _about line if someone edited it; compare what we would write
		saved_texts[kind] = on_disk
	pushed_doc = MapDataScript.copy(doc)
	undo_stack = []
	redo_stack = []
	_refresh_dirty()

func _refresh_dirty() -> void:
	dirty = false
	for kind in MapDataScript.KINDS:
		if MapDataScript.serialize(kind, doc[kind]) != str(saved_texts.get(kind, "")):
			dirty = true
			break
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_title("Savage Lands - Map Editor%s" % (" *" if dirty else ""))

func unsaved_kinds() -> Array:
	var out: Array = []
	for kind in MapDataScript.KINDS:
		if MapDataScript.serialize(kind, doc[kind]) != str(saved_texts.get(kind, "")):
			out.append(kind)
	return out

func push_undo() -> void:
	undo_stack.append(MapDataScript.copy(doc))
	if undo_stack.size() > UNDO_MAX:
		undo_stack.pop_front()
	redo_stack.clear()

func undo() -> void:
	if undo_stack.is_empty():
		toast("Nothing to undo")
		return
	redo_stack.append(MapDataScript.copy(doc))
	doc = undo_stack.pop_back()
	_after_history_step()

func redo() -> void:
	if redo_stack.is_empty():
		toast("Nothing to redo")
		return
	undo_stack.append(MapDataScript.copy(doc))
	doc = redo_stack.pop_back()
	_after_history_step()

func _after_history_step() -> void:
	drag = {}
	armed = {}
	_clamp_selection()
	changed(false)

# After every change to the document: the map is rebuilt where it changed, the "unsaved" mark is worked out, the panels and pictures redraw.
func changed(refresh_ui: bool = true) -> void:
	sync_world()
	_refresh_dirty()
	if refresh_ui and ui != null:
		ui.refresh()
	if overlay != null:
		overlay.queue_redraw()

# Makes the built world match the document: compares it with what the world was last built from and rebuilds just what differs.
func sync_world() -> void:
	var diff := _diff(pushed_doc, doc)
	if not diff.any:
		return
	RoomDataScript.use(doc)
	RoomsScript.reset()
	if diff.full:
		WorldMapScript.reset()
		WorldMapScript.ensure_built()
	RoomsScript.ensure_built()
	pushed_doc = MapDataScript.copy(doc)
	if world != null:
		if diff.full:
			world.rebuild_everything()
		else:
			world.rebuild_cells(diff.cells.keys(), diff.all)
	if ui != null and ui.minimap != null:
		ui.minimap.queue_redraw()

func _diff(old: Dictionary, now: Dictionary) -> Dictionary:
	var cells := {}
	var out := {"any": false, "cells": cells, "all": false, "full": false}
	var keys := {}
	for k in old.rooms:
		keys[k] = true
	for k in now.rooms:
		keys[k] = true
	for k in keys:
		var a = old.rooms.get(k, null)
		var b = now.rooms.get(k, null)
		if not MapDataScript.same(a, b):
			_add_room_cells(cells, str(k), a)
			_add_room_cells(cells, str(k), b)
	var ekeys := {}
	for k in old.edges:
		ekeys[k] = true
	for k in now.edges:
		ekeys[k] = true
	for k in ekeys:
		if not MapDataScript.same(old.edges.get(k, null), now.edges.get(k, null)):
			for c in MapDataScript.parse_edge(str(k)):
				cells[c] = true
	if not MapDataScript.same(old.roads, now.roads):
		out.all = true
	if not MapDataScript.same(old.landmarks, now.landmarks) or not MapDataScript.same(old.regions, now.regions):
		out.full = true
	out.any = not cells.is_empty() or out.all or out.full
	return out

func _add_room_cells(cells: Dictionary, key: String, data) -> void:
	var c := MapDataScript.parse_cell(key)
	if c == Vector2i(-1, -1):
		return
	var span := Vector2i(1, 1)
	if typeof(data) == TYPE_DICTIONARY and data.has("span"):
		span = Vector2i(int(data.span[0]), int(data.span[1]))
	for dy in span.y:
		for dx in span.x:
			cells[Vector2i(c.x + dx, c.y + dy)] = true

# Writes the data files that changed (keeping a backup of each old one). Returns true when everything was written.
func save() -> bool:
	var wrote: Array = []
	var backups: Array = []
	for kind in MapDataScript.KINDS:
		if MapDataScript.serialize(kind, doc[kind]) == str(saved_texts.get(kind, "")):
			continue
		var res: Dictionary = MapDataScript.write(kind, doc[kind], data_dir)
		if not res.ok:
			toast("Could not save: %s" % res.error, true)
			_refresh_dirty()
			return false
		saved_texts[kind] = MapDataScript.serialize(kind, doc[kind])
		wrote.append(MapDataScript.FILE_NAMES[kind])
		if res.backup != "":
			backups.append(res.backup)
	_refresh_dirty()
	if ui != null:
		ui.refresh()
	if wrote.is_empty():
		toast("Nothing to save: the files already match")
	else:
		toast("Saved %s%s" % [", ".join(wrote), " (the old ones are kept in data/backups)" if not backups.is_empty() else ""])
	return true

func toast(text_in: String, bad: bool = false) -> void:
	if ui != null:
		ui.toast(text_in, bad)

# --- the camera ------------------------------------------------------------------------------------------------------------------

func viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size

func w2s(p: Vector2) -> Vector2:
	return (p - cam_pos) * zoom + viewport_size() * 0.5

func s2w(p: Vector2) -> Vector2:
	return (p - viewport_size() * 0.5) / zoom + cam_pos

func view_world_rect() -> Rect2:
	var size := viewport_size() / zoom
	return Rect2(cam_pos - size * 0.5, size)

func _apply_camera() -> void:
	zoom = clampf(zoom, ZOOM_MIN, ZOOM_MAX)
	cam_pos = Vector2(clampf(cam_pos.x, -400.0, WorldMapScript.SIZE.x + 400.0), clampf(cam_pos.y, -400.0, WorldMapScript.SIZE.y + 400.0))
	if camera != null:
		camera.position = cam_pos
		camera.zoom = Vector2(zoom, zoom)
	if world != null:
		world.update_view(view_world_rect(), zoom)
	if overlay != null:
		overlay.queue_redraw()
	if ui != null and ui.minimap != null:
		ui.minimap.queue_redraw()
	view_changed = false

func set_view(centre: Vector2, new_zoom: float) -> void:
	cam_pos = centre
	zoom = new_zoom
	_apply_camera()

# Zooms so `rect` (world) fills the free part of the window, and puts it in the middle of that part.
func fit_rect(rect: Rect2, margin: float = 0.9) -> void:
	var free: Rect2 = ui.free_area() if ui != null else Rect2(Vector2.ZERO, viewport_size())
	var z := minf(free.size.x / maxf(rect.size.x, 1.0), free.size.y / maxf(rect.size.y, 1.0)) * margin
	zoom = clampf(z, ZOOM_MIN, ZOOM_MAX)
	cam_pos = rect.get_center() - (free.get_center() - viewport_size() * 0.5) / zoom
	_apply_camera()

func focus_world() -> void:
	fit_rect(Rect2(Vector2.ZERO, WorldMapScript.SIZE), 0.98)

func focus_room() -> void:
	var r := room()
	if not r.is_empty():
		fit_rect(r.rect, 0.94)

func focus_point(p: Vector2, at_zoom: float = 0.0) -> void:
	var free: Rect2 = ui.free_area() if ui != null else Rect2(Vector2.ZERO, viewport_size())
	if at_zoom > 0.0:
		zoom = clampf(at_zoom, ZOOM_MIN, ZOOM_MAX)
	cam_pos = p - (free.get_center() - viewport_size() * 0.5) / zoom
	_apply_camera()

func zoom_by(factor: float, around_screen: Vector2) -> void:
	var before := s2w(around_screen)
	zoom = clampf(zoom * factor, ZOOM_MIN, ZOOM_MAX)
	cam_pos += before - s2w(around_screen)
	_apply_camera()

func _process(delta: float) -> void:
	if camera == null:
		return
	if play != null and play.active:
		return                      # Play here: the walker moves the camera
	var dir := Vector2.ZERO
	if not _typing():
		if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
			dir.x -= 1.0
		if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
			dir.x += 1.0
		if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
			dir.y -= 1.0
		if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
			dir.y += 1.0
	if dir != Vector2.ZERO and not Input.is_key_pressed(KEY_CTRL):
		var fast := 3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0
		cam_pos += dir.normalized() * PAN_SPEED * fast * delta / zoom
		_apply_camera()
	elif view_changed:
		_apply_camera()

# True while a text box has the keyboard (so the letter keys type instead of moving the camera).
func _typing() -> bool:
	var owner_node := get_viewport().gui_get_focus_owner()
	return owner_node is LineEdit

# --- rooms: who is picked ---------------------------------------------------------------------------------------------------

func cell_rect(c: Vector2i) -> Rect2:
	return Rect2(Vector2(WorldMapScript.col_x(c.x), WorldMapScript.row_y(c.y)), Vector2(WorldMapScript.col_x(c.x + 1) - WorldMapScript.col_x(c.x), WorldMapScript.row_y(c.y + 1) - WorldMapScript.row_y(c.y)))

func has_room() -> bool:
	return room_cell != Vector2i(-1, -1)

func room_key() -> String:
	return MapDataScript.cell_key(room_cell.x, room_cell.y)

# The picked room as the game builds it now ({} when none is picked).
func room() -> Dictionary:
	if not has_room():
		return {}
	RoomsScript.ensure_built()
	return RoomsScript.room_at(cell_rect(room_cell).get_center())

func is_handmade() -> bool:
	return has_room() and doc.rooms.has(room_key())

# The picked room's hand-made data (the live dictionary: change it only through the editing functions below).
func room_data() -> Dictionary:
	return doc.rooms.get(room_key(), {})

func room_origin() -> Vector2:
	var r := room()
	return r.rect.position if not r.is_empty() else Vector2.ZERO

func pick_at(pos: Vector2) -> void:
	RoomsScript.ensure_built()
	var r: Dictionary = RoomsScript.room_at(pos)
	if has_room() and r.cell == room_cell:
		return
	room_cell = r.cell
	sel_i = -1
	sel_id = "" if tab != "world" else sel_id
	sel_pt = -1
	armed = {}
	if ui != null:
		ui.refresh()
	if overlay != null:
		overlay.queue_redraw()

func pick_cell(c: Vector2i) -> void:
	pick_at(cell_rect(c).get_center())

func _clamp_selection() -> void:
	if not has_room():
		return
	if tab in ["floor", "decor", "props"]:
		var list: Array = room_data().get(list_key(), [])
		if sel_i >= list.size():
			sel_i = -1
	if tab == "world" and world_tab == "roads" and sel_i >= doc.roads.size():
		sel_i = -1

func set_tab(name_in: String) -> void:
	tab = name_in
	sel_i = -1
	sel_pt = -1
	sel_id = ""
	armed = {}
	if tab == "world":
		world_tab = world_tab if world_tab in WORLD_TABS else "landmarks"
	if ui != null:
		ui.refresh()
	if overlay != null:
		overlay.queue_redraw()

func set_world_tab(name_in: String) -> void:
	world_tab = name_in
	sel_i = -1
	sel_pt = -1
	sel_id = ""
	armed = {}
	if ui != null:
		ui.refresh()
	if overlay != null:
		overlay.queue_redraw()

# --- room settings ---------------------------------------------------------------------------------------------------------------

# Turns a room the generator draws into a hand-made one: a plain oval of the right ground for its country, to shape from there.
func make_handmade() -> void:
	if not has_room() or is_handmade():
		return
	var r := room()
	RoomsScript.ensure_built()
	var mass: String = str(r.mass)
	if mass == "":
		mass = str(RoomsScript.MASS["wall"].get(r.group, "thicket"))
	var size: Vector2 = r.rect.size
	push_undo()
	doc.rooms[room_key()] = {
		"mass": mass,
		"shape": [["ell", int(roundf(size.x * 0.5)), int(roundf(size.y * 0.5)), int(roundf(size.x * 0.34)), int(roundf(size.y * 0.34))]],
		"decor": [],
	}
	if r.span != Vector2i(1, 1):
		doc.rooms[room_key()]["span"] = [r.span.x, r.span.y]
	changed()
	toast("%s is hand-made now: a plain oval to shape" % room_key())

# Gives the room back to the generator (its hand-made data is dropped; Undo brings it back).
func make_generated() -> void:
	if not is_handmade():
		return
	push_undo()
	doc.rooms.erase(room_key())
	sel_i = -1
	changed()
	toast("%s is drawn by the generator again (Undo brings it back)" % room_key())

# Puts the room back to the values the game shipped with.
func revert_room_to_factory() -> void:
	if not has_room():
		return
	var factory: Dictionary = RoomDataScript.factory("rooms")
	push_undo()
	if factory.has(room_key()):
		doc.rooms[room_key()] = factory[room_key()]
	else:
		doc.rooms.erase(room_key())
	sel_i = -1
	changed()
	toast("%s is back to the shipped values" % room_key())

func is_factory_room() -> bool:
	var factory: Dictionary = RoomDataScript.factory("rooms")
	if factory.has(room_key()):
		return is_handmade() and MapDataScript.same(factory[room_key()], doc.rooms[room_key()])
	return not is_handmade()

# Sets one field of the hand-made room ("name", "mass", "target"...); `value == null` removes it.
func set_room_field(field: String, value) -> void:
	if not is_handmade():
		return
	if MapDataScript.same(room_data().get(field, null), value):
		return
	push_undo()
	if value == null:
		doc.rooms[room_key()].erase(field)
	else:
		doc.rooms[room_key()][field] = value
	changed()

func set_room_span(cols: int, rows: int) -> void:
	if not is_handmade():
		return
	cols = clampi(cols, 1, MapDataScript.COLS - room_cell.x)
	rows = clampi(rows, 1, MapDataScript.ROWS - room_cell.y)
	# the new cells must not belong to another hand-made room
	for key in doc.rooms:
		if key == room_key():
			continue
		var c := MapDataScript.parse_cell(str(key))
		var sp: Array = doc.rooms[key].get("span", [1, 1])
		for dy in int(sp[1]):
			for dx in int(sp[0]):
				var cell := Vector2i(c.x + dx, c.y + dy)
				if cell.x >= room_cell.x and cell.x < room_cell.x + cols and cell.y >= room_cell.y and cell.y < room_cell.y + rows:
					toast("That would run into the hand-made room at %s" % key, true)
					ui.refresh()
					return
	if cols == 1 and rows == 1:
		set_room_field("span", null)
	else:
		set_room_field("span", [cols, rows])

# A copy of the table of the region this room is in (a starting point for a room's own list of residents).
func region_table_copy(r: Dictionary) -> Array:
	return (WorldMapScript.region(str(r.region)).get("enemies", []) as Array).duplicate(true)

# The residents list: [[enemy, weight], ...]; null = use the region's own table.
func set_residents(list) -> void:
	set_room_field("enemies", list)

func add_resident(enemy: String) -> void:
	var list: Array = room_data().get("enemies", []).duplicate(true)
	for e in list:
		if e[0] == enemy:
			e[1] = int(e[1]) + 1
			set_residents(list)
			return
	list.append([enemy, 1])
	set_residents(list)

func set_resident_weight(i: int, w: int) -> void:
	var list: Array = room_data().get("enemies", []).duplicate(true)
	if i < 0 or i >= list.size():
		return
	if w <= 0:
		list.remove_at(i)
	else:
		list[i][1] = w
	set_residents(list)

# --- shapes, decoration and set pieces -----------------------------------------------------------------------------------

func list_key(t: String = "") -> String:
	match (t if t != "" else tab):
		"floor":
			return "shape"
		"decor":
			return "decor"
		"props":
			return "props"
	return ""

func parse_item(t: String, raw: Array) -> Dictionary:
	match t:
		"floor":
			return ShapesScript.parse_op(raw)
		"decor":
			return ShapesScript.parse_decor(raw)
		"props":
			return ShapesScript.parse_prop(raw)
	return {}

func build_item(t: String, m: Dictionary) -> Array:
	match t:
		"floor":
			return ShapesScript.build_op(m)
		"decor":
			return ShapesScript.build_decor(m)
		"props":
			return ShapesScript.build_prop(m)
	return []

# The picked room's items for a tab, as models.
func item_models(t: String = "") -> Array:
	var key := list_key(t)
	var out: Array = []
	if key == "" or not is_handmade():
		return out
	var tt := t if t != "" else tab
	for raw in room_data().get(key, []):
		if typeof(raw) == TYPE_ARRAY and not raw.is_empty():
			out.append(parse_item(tt, raw))
	return out

func item_count() -> int:
	return (room_data().get(list_key(), []) as Array).size()

func selected_model() -> Dictionary:
	var list: Array = room_data().get(list_key(), [])
	if sel_i < 0 or sel_i >= list.size():
		return {}
	return parse_item(tab, list[sel_i])

# Replaces item i with an edited model, as one undo step. `fn` gets the model and changes it.
func edit_item(i: int, fn: Callable) -> void:
	var key := list_key()
	var list: Array = room_data().get(key, [])
	if i < 0 or i >= list.size():
		return
	var m := parse_item(tab, list[i])
	fn.call(m)
	var raw := build_item(tab, m)
	if MapDataScript.same(raw, list[i]):
		return
	push_undo()
	doc.rooms[room_key()][key][i] = raw
	changed()

func add_item(model: Dictionary) -> void:
	if not is_handmade():
		return
	var key := list_key()
	push_undo()
	if not doc.rooms[room_key()].has(key):
		doc.rooms[room_key()][key] = []
	doc.rooms[room_key()][key].append(build_item(tab, model))
	sel_i = doc.rooms[room_key()][key].size() - 1
	changed()

func delete_item(i: int) -> void:
	var key := list_key()
	var list: Array = room_data().get(key, [])
	if i < 0 or i >= list.size():
		return
	push_undo()
	doc.rooms[room_key()][key].remove_at(i)
	sel_i = -1
	changed()

func duplicate_item(i: int) -> void:
	var key := list_key()
	var list: Array = room_data().get(key, [])
	if i < 0 or i >= list.size():
		return
	var m := parse_item(tab, list[i])
	var off := Vector2(120, 120)
	if tab == "floor":
		ShapesScript.op_move(m, off)
	elif tab == "decor":
		ShapesScript.decor_move(m, off)
	else:
		m.c += off
	add_item(m)

func select_item(i: int) -> void:
	sel_i = i
	if ui != null:
		ui.refresh()
	if overlay != null:
		overlay.queue_redraw()

# Chooses a kind to put down next (a click, or a drag, in the room puts it there).
func arm(what: Dictionary) -> void:
	if not is_handmade():
		toast("Make the room hand-made first (Room tab)", true)
		return
	armed = what
	sel_i = -1
	if ui != null:
		ui.refresh()
	if overlay != null:
		overlay.queue_redraw()

func disarm() -> void:
	if armed.is_empty():
		return
	armed = {}
	drag = {}
	if ui != null:
		ui.refresh()
	if overlay != null:
		overlay.queue_redraw()

func set_new_mode(mode: String) -> void:
	new_mode = mode
	if not armed.is_empty() and armed.get("type", "") == "shape":
		armed.mode = mode
	if selected_model().is_empty() or tab != "floor":
		if ui != null:
			ui.refresh()
		return
	# with a shape picked, the buttons turn that shape into a floor / a cut / a bridge
	edit_item(sel_i, func(m): m.mode = mode)

# --- doorways ------------------------------------------------------------------------------------------------------------------

func edge_name_for(a: Vector2i, b: Vector2i) -> String:
	var first_is_a: bool = a.y < b.y or (a.y == b.y and a.x < b.x)
	return "%d,%d|%d,%d" % ([a.x, a.y, b.x, b.y] if first_is_a else [b.x, b.y, a.x, a.y])

# Every cell side of the picked room that borders another room: [{name, cell, other_cell, side, from, to, length, inward, spec, openings}]
# where spec is what edges.json says ("open", "closed", [[centre, width]...]) or null when the generator decides, and openings the
# openings that result (as fractions along the side).
func room_sides() -> Array:
	var out: Array = []
	var r := room()
	if r.is_empty():
		return out
	for dy in r.span.y:
		for dx in r.span.x:
			var cx: int = r.cell.x + dx
			var cy: int = r.cell.y + dy
			for side in ["n", "e", "s", "w"]:
				var nx := cx
				var ny := cy
				var inward := Vector2.ZERO
				match side:
					"n":
						ny -= 1
						inward = Vector2(0, 1)
					"s":
						ny += 1
						inward = Vector2(0, -1)
					"e":
						nx += 1
						inward = Vector2(-1, 0)
					"w":
						nx -= 1
						inward = Vector2(1, 0)
				if nx < 0 or ny < 0 or nx >= MapDataScript.COLS or ny >= MapDataScript.ROWS:
					continue
				var other: Dictionary = RoomsScript.room_at(cell_rect(Vector2i(nx, ny)).get_center())
				if other.id == r.id:
					continue
				var rect := cell_rect(Vector2i(cx, cy))
				var a := Vector2.ZERO
				var b := Vector2.ZERO
				match side:
					"n":
						a = rect.position
						b = Vector2(rect.end.x, rect.position.y)
					"s":
						a = Vector2(rect.position.x, rect.end.y)
						b = rect.end
					"w":
						a = rect.position
						b = Vector2(rect.position.x, rect.end.y)
					"e":
						a = Vector2(rect.end.x, rect.position.y)
						b = rect.end
				var name_in := edge_name_for(Vector2i(cx, cy), Vector2i(nx, ny))
				var length := a.distance_to(b)
				var key: String = RoomsScript._edge_key("%d,%d" % [cx, cy], "%d,%d" % [nx, ny])
				out.append({
					"name": name_in, "cell": Vector2i(cx, cy), "other_cell": Vector2i(nx, ny), "side": side, "from": a, "to": b, "length": length,
					"inward": inward, "spec": doc.edges.get(name_in, null), "other": other,
					"openings": RoomsScript._openings(r, other, key, length, name_in),
				})
	return out

func side_by_name(name_in: String) -> Dictionary:
	for s in room_sides():
		if s.name == name_in:
			return s
	return {}

# The doorways of a side as [[centre, width], ...] (px along the side from its start): what its spec says, or what the generator
# currently makes of it.
func doorways_of(side: Dictionary) -> Array:
	var spec = side.spec
	if typeof(spec) == TYPE_ARRAY:
		return spec.duplicate(true)
	var out: Array = []
	if typeof(spec) == TYPE_STRING:
		if spec == "open":
			out.append([ShapesScript.n(side.length * 0.5), ShapesScript.n(side.length)])
		return out
	for o in side.openings:
		out.append([ShapesScript.n((float(o[0]) + float(o[1])) * 0.5 * side.length), ShapesScript.n((float(o[1]) - float(o[0])) * side.length)])
	return out

# Sets what a side is: "generated" (remove the entry), "open", "closed", or a list of doorways.
func set_edge(name_in: String, spec) -> void:
	var current = doc.edges.get(name_in, null)
	if typeof(spec) == TYPE_STRING and spec == "generated":
		spec = null
	if MapDataScript.same(current, spec):
		return
	push_undo()
	if spec == null:
		doc.edges.erase(name_in)
	else:
		doc.edges[name_in] = spec
	changed()

func edit_doorways(name_in: String, fn: Callable) -> void:
	var side := side_by_name(name_in)
	if side.is_empty():
		return
	var list := doorways_of(side)
	fn.call(list)
	set_edge(name_in, list if not list.is_empty() else "closed")

func select_side(name_in: String) -> void:
	sel_id = name_in
	if ui != null:
		ui.refresh()
	if overlay != null:
		overlay.queue_redraw()

# --- landmarks, roads, regions ----------------------------------------------------------------------------------------------

func landmark_entry(id: String) -> Dictionary:
	for l in doc.landmarks:
		if l.id == id:
			return l
	return {}

func edit_landmark(id: String, fn: Callable) -> void:
	for i in doc.landmarks.size():
		if doc.landmarks[i].id == id:
			var before = MapDataScript.copy(doc.landmarks[i])
			var e: Dictionary = MapDataScript.copy(doc.landmarks[i])
			fn.call(e)
			if MapDataScript.same(before, e):
				return
			push_undo()
			doc.landmarks[i] = e
			changed()
			return

func road_point_world(p: Array) -> Vector2:
	return OverworldMapScript._cell_to_px(p)

static func px_to_cell(p: Vector2) -> Array:
	var ic := 0
	for i in MapDataScript.COLS:
		if p.x >= float(WorldMapScript.col_x(i)):
			ic = i
	var ir := 0
	for j in MapDataScript.ROWS:
		if p.y >= float(WorldMapScript.row_y(j)):
			ir = j
	var x0 := float(WorldMapScript.col_x(ic))
	var x1 := float(WorldMapScript.col_x(ic + 1))
	var y0 := float(WorldMapScript.row_y(ir))
	var y1 := float(WorldMapScript.row_y(ir + 1))
	return [snappedf(float(ic) + (p.x - x0) / (x1 - x0), 0.001), snappedf(float(ir) + (p.y - y0) / (y1 - y0), 0.001)]

func edit_road(i: int, fn: Callable) -> void:
	if i < 0 or i >= doc.roads.size():
		return
	var before = MapDataScript.copy(doc.roads[i])
	var r: Dictionary = MapDataScript.copy(doc.roads[i])
	fn.call(r)
	if MapDataScript.same(before, r):
		return
	push_undo()
	doc.roads[i] = r
	changed()

func add_road(points_world: Array) -> void:
	var pts: Array = []
	for p in points_world:
		pts.append(px_to_cell(p))
	push_undo()
	doc.roads.append({"width": 90, "points": pts})
	sel_i = doc.roads.size() - 1
	sel_pt = -1
	changed()

func delete_road(i: int) -> void:
	if i < 0 or i >= doc.roads.size():
		return
	push_undo()
	doc.roads.remove_at(i)
	sel_i = -1
	sel_pt = -1
	changed()

func edit_region(id: String, fn: Callable) -> void:
	var before = doc.regions.get(id, null)
	if before == null:
		return
	var r: Dictionary = MapDataScript.copy(before)
	fn.call(r)
	if MapDataScript.same(before, r):
		return
	push_undo()
	doc.regions[id] = r
	changed()

# --- checking the map ---------------------------------------------------------------------------------------------------------

# Looks the whole map over for the mistakes that are easy to make by hand. Returns [[sentence, "bad" | "note", cell or null], ...]; empty
# when there is nothing to say.
func check_map() -> Array:
	RoomsScript.ensure_built()
	var out: Array = []
	# 1. every room that is land can be walked to from where you wake, through the doorways as they are now
	var start: Dictionary = RoomsScript.room_at(WorldMapScript.spawn_position())
	var seen := {start.id: true}
	var queue: Array = [start]
	while not queue.is_empty():
		var r: Dictionary = queue.pop_back()
		for e in RoomsScript.edges(r):
			var wide := false
			for o in e.openings:
				if (float(o[1]) - float(o[0])) * float(e.length) >= 120.0:
					wide = true
			if wide and not seen.has(e.other.id):
				seen[e.other.id] = true
				queue.append(e.other)
	for r in RoomsScript.rooms:
		if str(r.kind) != "sea" and not seen.has(r.id):
			out.append(["You cannot walk to room %d,%d%s: every way in is closed or blocked." % [r.cell.x, r.cell.y, (" (%s)" % r.name) if str(r.name) != "" else ""], "bad", r.cell])
	# 2. no named place stands out in the deep sea
	for l in WorldMapScript.landmarks:
		if WorldMapScript.is_blocked(l.pos):
			var home: Dictionary = RoomsScript.room_at(l.pos)
			out.append(["%s stands in deep water, where nobody can reach it. Move it onto land." % str(l.name), "bad", home.cell])
	# 3. the hand-made rooms
	for key in doc.rooms:
		var data: Dictionary = doc.rooms[key]
		var c := MapDataScript.parse_cell(str(key))
		var r2: Dictionary = RoomsScript.room_at(cell_rect(c).get_center())
		for e2 in data.get("enemies", []):
			if not (str(e2[0]) in ENEMY_KEYS):
				out.append(["Room %s lists an enemy the game does not know: %s." % [key, str(e2[0])], "bad", c])
		var outside := 0
		for t in ["decor", "props"]:
			for raw in data.get(t, []):
				var m: Dictionary = parse_item(("decor" if t == "decor" else "props"), raw)
				var p: Vector2 = ShapesScript.decor_center(m) if t == "decor" else m.c
				if not Rect2(Vector2.ZERO, r2.rect.size).has_point(p):
					outside += 1
		if outside > 0:
			out.append(["Room %s has %d decoration or set piece outside the room." % [key, outside], "note", c])
	# 4. the regions' residents
	for id in doc.regions:
		for e3 in doc.regions[id].enemies:
			if not (str(e3[0]) in ENEMY_KEYS):
				out.append(["Region %s lists an enemy the game does not know: %s." % [str(doc.regions[id].name), str(e3[0])], "bad", null])
	return out

# --- the mouse and keyboard -----------------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if camera == null:
		return
	if play != null and play.active:
		# while you play, the walker reads the keyboard itself; only P and Esc do anything here (they come back to the editor)
		if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_P or event.keycode == KEY_ESCAPE):
			play.stop()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		_on_mouse_button(event)
	elif event is InputEventMouseMotion:
		_on_mouse_motion(event)
	elif event is InputEventKey:
		_on_key(event)

func _on_mouse_button(event: InputEventMouseButton) -> void:
	var screen: Vector2 = event.position
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		zoom_by(1.18, screen)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		zoom_by(1.0 / 1.18, screen)
	elif event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_pan = {"from": screen, "cam": cam_pos, "moved": false, "button": event.button_index}
		else:
			var was_click: bool = not _pan.is_empty() and not bool(_pan.moved)
			var button: int = int(_pan.get("button", 0))
			_pan = {}
			if was_click and button == MOUSE_BUTTON_RIGHT:
				_right_click(s2w(screen))
	elif event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _space_down:
				_pan = {"from": screen, "cam": cam_pos, "moved": false, "button": MOUSE_BUTTON_LEFT}
			else:
				_left_press(s2w(screen), event.double_click)
		else:
			if not _pan.is_empty() and int(_pan.button) == MOUSE_BUTTON_LEFT:
				var was: Dictionary = _pan
				_pan = {}
				if was.has("pick") and not bool(was.moved):
					_pick_or_deselect(was.pick)
			else:
				_left_release(s2w(screen))

func _on_mouse_motion(event: InputEventMouseMotion) -> void:
	var screen: Vector2 = event.position
	if not _pan.is_empty():
		if screen.distance_to(_pan.from) > 3.0:
			_pan.moved = true
		if bool(_pan.moved):
			cam_pos = _pan.cam - (screen - _pan.from) / zoom
			_apply_camera()
		return
	var w := s2w(screen)
	if not drag.is_empty():
		_drag_to(w)
	if ui != null:
		ui.set_cursor_info(w)
	if overlay != null and (not armed.is_empty() or not drag.is_empty()):
		overlay.queue_redraw()
	_update_cursor(w)

# The mouse pointer says what a click would do: a cross while something is being put down, a hand over a square to grab, a move arrow
# over something that can be picked up.
func _update_cursor(w: Vector2) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var shape := Input.CURSOR_ARROW
	if not drag.is_empty():
		shape = Input.CURSOR_DRAG
	elif not armed.is_empty():
		shape = Input.CURSOR_CROSS
	else:
		var hit := hit_test(w)
		if not hit.is_empty():
			shape = Input.CURSOR_POINTING_HAND if hit.type == "handle" else Input.CURSOR_MOVE
	Input.set_default_cursor_shape(shape)

func _on_key(event: InputEventKey) -> void:
	if event.keycode == KEY_SPACE:
		if not (event.pressed and _typing()):
			_space_down = event.pressed
		return
	if event.pressed and not event.echo and event.keycode == KEY_ESCAPE and _typing():
		get_viewport().gui_release_focus()           # Esc leaves a number or text box (what was typed is taken)
		get_viewport().set_input_as_handled()
		return
	if not event.pressed or event.echo or _typing():
		return
	var ctrl: bool = event.ctrl_pressed or event.meta_pressed
	match event.keycode:
		KEY_Z:
			if ctrl:
				if event.shift_pressed:
					redo()
				else:
					undo()
				get_viewport().set_input_as_handled()
		KEY_Y:
			if ctrl:
				redo()
				get_viewport().set_input_as_handled()
		KEY_S:
			if ctrl:
				save()
				get_viewport().set_input_as_handled()
		KEY_D:
			if ctrl and tab in ["floor", "decor", "props"] and sel_i >= 0:
				duplicate_item(sel_i)
				get_viewport().set_input_as_handled()
		KEY_DELETE, KEY_BACKSPACE:
			delete_selected()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			if ui != null and ui.close_popups():
				pass
			elif not armed.is_empty() or not drag.is_empty():
				_cancel_drag()
				disarm()
			elif sel_i >= 0 or sel_id != "":
				sel_i = -1
				sel_id = ""
				sel_pt = -1
				ui.refresh()
				overlay.queue_redraw()
		KEY_ENTER, KEY_KP_ENTER:
			_finish_polyline()
		KEY_HOME:
			focus_world()
		KEY_F:
			focus_room()
		KEY_P:
			if not ctrl:
				play_here(_mouse_start())
		KEY_G:
			grid_on = not grid_on
			ui.refresh_top()
			overlay.queue_redraw()
		KEY_M:
			ui.toggle_minimap()
		KEY_TAB:
			ui.toggle_panel()
			get_viewport().set_input_as_handled()
		KEY_R:
			if not ctrl:
				rebuild_room()
		KEY_F1, KEY_SLASH:
			ui.toggle_help()
		KEY_EQUAL, KEY_KP_ADD:
			zoom_by(1.25, viewport_size() * 0.5)
		KEY_MINUS, KEY_KP_SUBTRACT:
			zoom_by(0.8, viewport_size() * 0.5)

# PLAY HERE: walk the map yourself (see MapEditorPlay.gd). `at` is where to start (Vector2.INF = the picked room, or what you are looking at);
# calling it while you are playing comes back to the editor instead.
func play_here(at: Vector2 = Vector2.INF) -> void:
	if play == null:
		return
	if play.active:
		play.stop()
	else:
		play.start(at)

# With P, the walker starts where the mouse is when it is over the map (not over the panel or the top bar).
func _mouse_start() -> Vector2:
	if ui == null or DisplayServer.get_name() == "headless":
		return Vector2.INF
	var m: Vector2 = get_viewport().get_mouse_position()
	return s2w(m) if ui.free_area().has_point(m) else Vector2.INF

func cycle_snap() -> void:
	var i := SNAPS.find(snap_step)
	snap_step = SNAPS[(i + 1) % SNAPS.size()]
	if ui != null:
		ui.refresh_top()
	if overlay != null:
		overlay.queue_redraw()

func toggle_grid() -> void:
	grid_on = not grid_on
	if ui != null:
		ui.refresh_top()
	if overlay != null:
		overlay.queue_redraw()

# Throws away and rebuilds the picked room (and the ones beside it) from the data: what you see is what the game will build.
func rebuild_room() -> void:
	if not has_room():
		return
	var cells: Array = []
	var r := room()
	for dy in r.span.y:
		for dx in r.span.x:
			cells.append(Vector2i(r.cell.x + dx, r.cell.y + dy))
	RoomDataScript.use(doc)
	RoomsScript.reset()
	RoomsScript.ensure_built()
	world.rebuild_cells(cells)
	toast("Rebuilt %s" % room_key())

# --- clicking in the world ----------------------------------------------------------------------------------------------------

func _local(world_pos: Vector2) -> Vector2:
	return world_pos - room_origin()

func _snapped_local(world_pos: Vector2) -> Vector2:
	return ShapesScript.snap_v(_local(world_pos), snap_step)

func _left_press(w: Vector2, double: bool) -> void:
	if not armed.is_empty():
		_place_armed(w, double)
		return
	var hit := hit_test(w)
	if hit.is_empty():
		# on empty ground a click picks the room under it, a drag moves the map
		_pan = {"from": w2s(w), "cam": cam_pos, "moved": false, "button": MOUSE_BUTTON_LEFT, "pick": w}
		return
	match hit.type:
		"handle":
			_begin_handle_drag(hit, w)
		"item":
			_select_hit(hit)
			_begin_move_drag(hit, w)

func _pick_or_deselect(w: Vector2) -> void:
	var r: Dictionary = RoomsScript.room_at(w)
	if has_room() and r.cell == room_cell:
		if sel_i >= 0 or sel_id != "":
			sel_i = -1
			sel_id = ""
			sel_pt = -1
			ui.refresh()
			overlay.queue_redraw()
		return
	pick_at(w)

func _left_release(_w: Vector2) -> void:
	if drag.is_empty():
		return
	_finish_drag()

func _right_click(_w: Vector2) -> void:
	if not armed.is_empty():
		if _finish_polyline():
			return
		disarm()
		return
	# right-click on a point of the picked path / polygon / road removes it
	var hit := hit_test(_w)
	if not hit.is_empty() and hit.type == "handle" and str(hit.id).begins_with("p"):
		_remove_point(int(str(hit.id).substr(1)))

func delete_selected() -> void:
	match tab:
		"floor", "decor", "props":
			if sel_i >= 0:
				delete_item(sel_i)
		"doors":
			if sel_id != "":
				set_edge(sel_id, "generated")
		"world":
			if world_tab == "roads" and sel_i >= 0:
				if sel_pt >= 0 and doc.roads[sel_i].points.size() > 2:
					_remove_point(sel_pt)
				else:
					delete_road(sel_i)

func _remove_point(index: int) -> void:
	if tab == "floor" and sel_i >= 0:
		var m := selected_model()
		if m.has("pts") and m.pts.size() > (2 if m.kind == "path" else 3):
			edit_item(sel_i, func(mm): mm.pts.remove_at(index))
	elif tab == "world" and world_tab == "roads" and sel_i >= 0:
		edit_road(sel_i, func(r):
			if r.points.size() > 2:
				r.points.remove_at(index))
		sel_pt = -1

# --- hit testing ---------------------------------------------------------------------------------------------------------------------

# What is under a world point, for the active tab: {type: "handle", id, ...} for a square of the picked item, {type: "item", index, ...}
# for the body of an item, or {} for nothing.
func hit_test(w: Vector2) -> Dictionary:
	var reach := HANDLE_PX / zoom
	match tab:
		"floor", "decor", "props":
			if not is_handmade() or room_cell == Vector2i(-1, -1):
				return {}
			var o := room_origin()
			var local := w - o
			# the picked item's handles first
			if sel_i >= 0:
				var m := selected_model()
				if not m.is_empty():
					var best := {}
					var best_d := reach
					for h in _handles_of(tab, m):
						var d: float = (h.pos as Vector2).distance_to(local)
						if d <= best_d:
							best_d = d
							best = {"type": "handle", "id": h.id}
					if not best.is_empty():
						return best
			# then the bodies, smallest first
			var models := item_models()
			var found := -1
			var found_score := INF
			for i in models.size():
				var score := _body_score(tab, models[i], local, 24.0 / zoom)
				if score >= 0.0 and score < found_score:
					found_score = score
					found = i
			if found >= 0:
				return {"type": "item", "index": found}
		"doors":
			return _hit_doors(w)
		"world":
			return _hit_world(w)
	return {}

func _handles_of(t: String, m: Dictionary) -> Array:
	match t:
		"floor":
			return ShapesScript.op_handles(m)
		"decor":
			return ShapesScript.decor_handles(m)
		"props":
			return [{"id": "c", "pos": m.c}]
	return []

# -1 when the point is not on the item; otherwise a smaller number for a "tighter" hit (so a small shape inside a big one wins).
func _body_score(t: String, m: Dictionary, local: Vector2, near: float) -> float:
	match t:
		"floor":
			return ShapesScript.op_area(m) if ShapesScript.op_contains(m, local) else -1.0
		"decor":
			var best := INF
			for p in ShapesScript.decor_points(m):
				best = minf(best, (p as Vector2).distance_to(local))
			if m.kind in ["orchard", "bed", "boulders"]:
				var half := Vector2(float(maxi(int(m.cols), 1) - 1), float(maxi(int(m.rows), 1) - 1)) * float(m.spacing) * 0.5
				if Rect2(m.c - half - Vector2(near, near), half * 2.0 + Vector2(near, near) * 2.0).has_point(local):
					return 1.0e6 + half.length()
			return best if best <= near else -1.0
		"props":
			var radius := maxf(ShapesScript.prop_radius(m.kind) * 0.5, near)
			return (m.c as Vector2).distance_to(local) if (m.c as Vector2).distance_to(local) <= radius else -1.0
	return -1.0

func _hit_doors(w: Vector2) -> Dictionary:
	var reach := 26.0 / zoom
	# handles of the picked side's doorways
	if sel_id != "":
		var side := side_by_name(sel_id)
		if not side.is_empty():
			var list := doorways_of(side)
			var along: Vector2 = (side.to - side.from).normalized()
			for i in list.size():
				var centre: Vector2 = side.from + along * float(list[i][0])
				var half: float = float(list[i][1]) * 0.5
				var checks := [["c%d" % i, centre], ["a%d" % i, centre - along * half], ["b%d" % i, centre + along * half]]
				for c in checks:
					if (c[1] as Vector2).distance_to(w) <= HANDLE_PX / zoom:
						return {"type": "handle", "id": c[0]}
	for side in room_sides():
		var d := dist_to_segment(w, side.from, side.to)
		if d <= reach:
			return {"type": "item", "name": side.name}
	return {}

static func dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	return ShapesScript.dist_to_segment(p, a, b)

func _hit_world(w: Vector2) -> Dictionary:
	match world_tab:
		"landmarks":
			var best := {}
			var best_d := 26.0 / zoom
			for l in WorldMapScript.landmarks:
				var d: float = (l.pos as Vector2).distance_to(w)
				if d <= best_d:
					best_d = d
					best = {"type": "item", "id": l.id}
			return best
		"roads":
			if sel_i >= 0 and sel_i < doc.roads.size():
				var pts: Array = doc.roads[sel_i].points
				for k in pts.size():
					if road_point_world(pts[k]).distance_to(w) <= HANDLE_PX / zoom:
						return {"type": "handle", "id": "p%d" % k}
				for k in pts.size() - 1:
					var mid := road_point_world(pts[k]).lerp(road_point_world(pts[k + 1]), 0.5)
					if mid.distance_to(w) <= HANDLE_PX / zoom:
						return {"type": "handle", "id": "m%d" % k}
			# the nearest road whose line passes within a few px (or within its own half width) of the click
			var best_i := -1
			var best_dist := INF
			for i in doc.roads.size():
				var pp: Array = doc.roads[i].points
				var reach_here: float = maxf(14.0 / zoom, float(doc.roads[i].width) * 0.5)
				for k in pp.size() - 1:
					var d2 := dist_to_segment(w, road_point_world(pp[k]), road_point_world(pp[k + 1]))
					if d2 <= reach_here and d2 < best_dist:
						best_dist = d2
						best_i = i
			if best_i >= 0:
				return {"type": "item", "index": best_i}
		"regions":
			var r := WorldMapScript.region_at(w)
			return {"type": "item", "id": r.id}
	return {}

func _select_hit(hit: Dictionary) -> void:
	match tab:
		"floor", "decor", "props":
			sel_i = int(hit.index)
		"doors":
			sel_id = str(hit.name)
		"world":
			match world_tab:
				"landmarks":
					sel_id = str(hit.id)
				"roads":
					if sel_i != int(hit.index):
						sel_pt = -1
					sel_i = int(hit.index)
				"regions":
					sel_id = str(hit.id)
	ui.refresh()
	overlay.queue_redraw()

# --- dragging --------------------------------------------------------------------------------------------------------------------

func _begin_handle_drag(hit: Dictionary, w: Vector2) -> void:
	drag = {"type": "handle", "id": str(hit.id), "tab": tab, "start": w, "moved": false, "undone": false}
	if tab == "world":
		sel_pt = int(str(hit.id).substr(1)) if str(hit.id).begins_with("p") else -1

func _begin_move_drag(_hit: Dictionary, w: Vector2) -> void:
	drag = {"type": "move", "tab": tab, "start": w, "moved": false, "undone": false}
	match tab:
		"floor", "decor", "props":
			drag.model = selected_model()
		"world":
			if world_tab == "landmarks" and sel_id not in FIXED_LANDMARKS:
				drag.pos = landmark_pos(sel_id)
			elif world_tab == "roads" and sel_i >= 0:
				drag.points = MapDataScript.copy(doc.roads[sel_i].points)
			else:
				drag = {}       # a region, a doorway side or a place fixed by the game's code: it can be picked but not dragged
		_:
			drag = {}

func landmark_pos(id: String) -> Vector2:
	var e := landmark_entry(id)
	return Vector2(float(e.pos[0]), float(e.pos[1])) if not e.is_empty() else Vector2.ZERO

func _cancel_drag() -> void:
	if drag.is_empty():
		return
	if bool(drag.get("undone", false)):
		# the drag had started changing the document: put it back
		doc = undo_stack.pop_back() if not undo_stack.is_empty() else doc
		changed()
	drag = {}

func _drag_to(w: Vector2) -> void:
	if drag.is_empty():
		return
	if drag.type == "create":
		drag.current = w
		overlay.queue_redraw()
		return
	if not drag.moved:
		if w.distance_to(drag.start) * zoom < 3.0:
			return
		drag.moved = true
		push_undo()
		drag.undone = true
	match drag.type:
		"handle":
			_apply_handle(w)
		"move":
			_apply_move(w)
	_refresh_after_drag_step()

func _refresh_after_drag_step() -> void:
	overlay.queue_redraw()
	ui.refresh_throttled()

func _apply_handle(w: Vector2) -> void:
	var local := _snapped_local(w)
	match drag.tab:
		"floor":
			var list: Array = doc.rooms[room_key()].shape
			var m := ShapesScript.parse_op(list[sel_i])
			var id: String = ShapesScript.op_drag(m, str(drag.id), local, snap_step)
			drag.id = id
			list[sel_i] = ShapesScript.build_op(m)
		"decor":
			var list2: Array = doc.rooms[room_key()].decor
			var m2 := ShapesScript.parse_decor(list2[sel_i])
			ShapesScript.decor_drag(m2, str(drag.id), local, snap_step)
			list2[sel_i] = ShapesScript.build_decor(m2)
		"props":
			var list3: Array = doc.rooms[room_key()].props
			var m3 := ShapesScript.parse_prop(list3[sel_i])
			m3.c = local
			list3[sel_i] = ShapesScript.build_prop(m3)
		"doors":
			_apply_door_handle(w)
		"world":
			if world_tab == "roads" and sel_i >= 0:
				var pts: Array = doc.roads[sel_i].points
				var hid: String = str(drag.id)
				if hid.begins_with("m"):
					var k := int(hid.substr(1))
					var mid: Array = px_to_cell(road_point_world(pts[k]).lerp(road_point_world(pts[k + 1]), 0.5))
					pts.insert(k + 1, mid)
					drag.id = "p%d" % (k + 1)
					sel_pt = k + 1
					hid = str(drag.id)
				var idx := int(hid.substr(1))
				pts[idx] = px_to_cell(w)

func _apply_move(w: Vector2) -> void:
	# a body drag moves things by whole grid steps (so a thing that was off the grid stays in step with what it was beside)
	var delta: Vector2 = ShapesScript.snap_v(w - drag.start, snap_step)
	match drag.tab:
		"floor":
			var m: Dictionary = MapDataScript.copy(drag.model)
			ShapesScript.op_move(m, delta)
			doc.rooms[room_key()].shape[sel_i] = ShapesScript.build_op(m)
		"decor":
			var m2: Dictionary = MapDataScript.copy(drag.model)
			ShapesScript.decor_move(m2, delta)
			doc.rooms[room_key()].decor[sel_i] = ShapesScript.build_decor(m2)
		"props":
			var m3: Dictionary = MapDataScript.copy(drag.model)
			m3.c += delta
			doc.rooms[room_key()].props[sel_i] = ShapesScript.build_prop(m3)
		"world":
			if world_tab == "landmarks" and sel_id not in FIXED_LANDMARKS:
				var target: Vector2 = drag.pos + delta
				for l in doc.landmarks:
					if l.id == sel_id:
						l.pos = [ShapesScript.n(target.x), ShapesScript.n(target.y)]
			elif world_tab == "roads" and sel_i >= 0:
				var moved: Array = []
				var free_delta: Vector2 = w - drag.start
				for p in drag.points:
					var wp: Vector2 = road_point_world(p) + free_delta
					moved.append(px_to_cell(wp))
				doc.roads[sel_i].points = moved

func _finish_drag() -> void:
	var was := drag
	drag = {}
	if was.type == "create":
		_finish_create(was)
		return
	if bool(was.get("moved", false)):
		# dragged back to where it started: nothing changed, so no undo step either
		if bool(was.get("undone", false)) and not undo_stack.is_empty() and MapDataScript.same(undo_stack.back(), doc, 0.0):
			undo_stack.pop_back()
		changed()
	else:
		overlay.queue_redraw()

func _apply_door_handle(w: Vector2) -> void:
	var side := side_by_name(sel_id)
	if side.is_empty():
		return
	var along: Vector2 = (side.to - side.from).normalized()
	var t: float = ShapesScript.snap((w - side.from).dot(along), snap_step)
	t = clampf(t, 0.0, side.length)
	var list := doorways_of(side)
	var id := str(drag.id)
	var i := int(id.substr(1))
	if i >= list.size():
		return
	var centre: float = float(list[i][0])
	var width: float = float(list[i][1])
	match id[0]:
		"c":
			centre = t
		"a":
			var hi := centre + width * 0.5
			width = maxf(hi - t, 60.0)
			centre = hi - width * 0.5
		"b":
			var lo := centre - width * 0.5
			width = maxf(t - lo, 60.0)
			centre = lo + width * 0.5
	list[i] = [ShapesScript.n(centre), ShapesScript.n(width)]
	doc.edges[sel_id] = list

# --- putting things down -----------------------------------------------------------------------------------------------------

func _place_armed(w: Vector2, double: bool) -> void:
	var r := room()
	if r.is_empty() or not r.rect.has_point(w):
		toast("Click inside the picked room to put it down", true)
		return
	var local := _snapped_local(w)
	match str(armed.type):
		"shape":
			var kind: String = str(armed.kind)
			if kind in ["path", "poly"]:
				if not armed.has("points"):
					armed.points = []
				if double:
					_finish_polyline()
					return
				armed.points.append(local)
				overlay.queue_redraw()
				ui.refresh_top()
			else:
				drag = {"type": "create", "kind": kind, "start": w, "current": w}
		"decor":
			var kind2: String = str(armed.kind)
			if kind2 == "row" and not armed.has("a"):
				armed.a = local
				overlay.queue_redraw()
				return
			var m := ShapesScript.default_decor(kind2, local)
			if kind2 == "row":
				m.a = armed.a
				m.b = local if local.distance_to(armed.a) > 40.0 else (armed.a as Vector2) + Vector2(600, 0)
			tab = "decor"
			armed = {}
			add_item(m)
		"prop":
			var m4 := {"kind": str(armed.kind), "c": local, "flavour": "water" if armed.kind == "pond" else ""}
			tab = "props"
			armed = {}
			add_item(m4)
		"road":
			if not armed.has("points"):
				armed.points = []
			if double:
				_finish_polyline()
				return
			armed.points.append(w)
			overlay.queue_redraw()
			ui.refresh_top()

# Enter or a double-click or a right-click finishes a path / polygon / road being drawn. True if there was one to finish.
func _finish_polyline() -> bool:
	if armed.is_empty() or not armed.has("points"):
		return false
	var pts: Array = armed.points
	var kind: String = str(armed.get("kind", ""))
	var type_name: String = str(armed.type)
	if type_name == "road":
		if pts.size() < 2:
			toast("A road needs at least two points", true)
			return true
		armed = {}
		add_road(pts)
		return true
	var need := 2 if kind == "path" else 3
	if pts.size() < need:
		toast("Click %d points or more, then press Enter" % need, true)
		return true
	var m := {"mode": new_mode, "kind": kind, "pts": pts.duplicate()}
	if kind == "path":
		m.width = 400.0
	armed = {}
	tab = "floor"
	add_item(m)
	return true

func _finish_create(d: Dictionary) -> void:
	var kind: String = str(d.kind)
	var a := _snapped_local(d.start)
	var b := _snapped_local(d.current)
	var m := ShapesScript.default_op(kind, new_mode, a)
	var off: Vector2 = b - a
	if off.length() * zoom > 12.0:
		match kind:
			"ell":
				m.rx = maxf(absf(off.x), 40.0)
				m.ry = maxf(absf(off.y), 40.0)
			"disc":
				m.r = maxf(off.length(), 40.0)
			"box":
				m.hx = maxf(absf(off.x), 40.0)
				m.hy = maxf(absf(off.y), 40.0)
	armed = {}
	tab = "floor"
	add_item(m)

# Whether anything is being drawn right now (the overlay shows a ghost of it).
func drawing_points() -> Array:
	return armed.get("points", [])
