extends "res://scripts/OverworldMap.gd"

# The overworld as the Map Editor shows it: the REAL OverworldMap (the same ground, walls, trees, set pieces and roads the game builds),
# but instead of keeping the rooms round a player built, it keeps the rooms in front of the editor's camera. And after an edit it
# rebuilds only the rooms the edit touched.

const EDITOR_MAX_ROOMS := 12          # most rooms built at once
const EDITOR_MIN_ZOOM := 0.06         # zoomed out further than this, no rooms are built (the ground alone is drawn)
# The castle town and the race track outside it are built by the game itself (Main.gd), not here: nothing is scattered over them.
const TOWN_SIZE := Vector2(1800, 1250)
const TOWN_RECT := Rect2(Vector2(33600, 23800) / 2.0 - TOWN_SIZE / 2.0, TOWN_SIZE)
const RACE_TRACK_RECT := Rect2(TOWN_RECT.position + Vector2(1900, 40), Vector2(640, 490))

var view_rect := Rect2()
var view_zoom := 1.0

func start() -> void:
	protected_check = func(p: Vector2) -> bool: return TOWN_RECT.grow(150.0).has_point(p) or RACE_TRACK_RECT.grow(150.0).has_point(p)
	build()

# Keeps built the rooms in view (nearest the middle first, built a little each frame), and lets go of the far ones.
func update_view(view: Rect2, zoom: float) -> void:
	view_rect = view
	view_zoom = zoom
	RoomsScript.ensure_built()
	if zoom < EDITOR_MIN_ZOOM:
		for id in _rooms.keys():
			_unload_room(id)
		_pending.clear()
		_wanted = {}
		return
	var near: Array = []
	for r in RoomsScript.rooms:
		if r.rect.intersects(view.grow(200.0)):
			near.append(r)
	var centre := view.get_center()
	near.sort_custom(func(a, b): return _rect_distance(a.rect, centre) < _rect_distance(b.rect, centre))
	_wanted = {}
	for i in mini(near.size(), EDITOR_MAX_ROOMS):
		_wanted[near[i].id] = true
	var keep := _wanted.duplicate()
	for r in RoomsScript.rooms:
		if r.rect.intersects(view.grow(1800.0)) and keep.size() < EDITOR_MAX_ROOMS + 6:
			keep[r.id] = true
	for id in _rooms.keys():
		if not keep.has(id):
			_unload_room(id)
	_pending.clear()
	for i in mini(near.size(), EDITOR_MAX_ROOMS):
		var id: String = near[i].id
		if not _rooms.has(id):
			_pending.append(id)
	# the room in the middle of the view (after a jump to it) is built at once, the others a little each frame
	var middle: Dictionary = RoomsScript.room_at(centre)
	if _wanted.has(middle.id) and not _rooms.has(middle.id):
		_pending.erase(middle.id)
		_start_room(middle, true)

# After the data changed (Rooms.reset() already done): throws away every built room touching one of `cells` (Vector2i) and builds
# the ones in view again; the room under the camera is finished at once so the change shows immediately.
func rebuild_cells(cells: Array, everything: bool = false) -> void:
	RoomsScript.ensure_built()
	var zones: Array = []
	for c in cells:
		var rect := Rect2(Vector2(WorldMapScript.col_x(c.x), WorldMapScript.row_y(c.y)), Vector2.ZERO)
		rect.end = Vector2(WorldMapScript.col_x(c.x + 1), WorldMapScript.row_y(c.y + 1))
		zones.append(rect.grow(12.0))
	for id in _rooms.keys():
		# a room half way through being built is dropped too (it would never finish: the queue is cleared below) and starts again
		var gone: bool = everything or not bool(_rooms[id].done)
		if not gone:
			var rect_here: Rect2 = _rooms[id].room.rect
			for z in zones:
				if rect_here.intersects(z):
					gone = true
					break
		if gone:
			_unload_room(id)
	_pending.clear()
	_work.clear()
	update_view(view_rect, view_zoom)
	var centre_room: Dictionary = RoomsScript.room_at(view_rect.get_center())
	for id in _wanted:
		if not _rooms.has(id) and id == centre_room.id:
			_start_room(RoomsScript.by_id(id), true)
	if everything:
		flush()

# The whole continent again (a landmark or region changed): the ground is repainted too.
func rebuild_everything() -> void:
	for id in _rooms.keys():
		_unload_room(id)
	for child in get_children():
		child.queue_free()
	_rooms = {}
	_pending = []
	_work = []
	_wanted = {}
	_ground_nodes = []
	_landmark_clearings = []
	_current_id = ""
	build()
	update_view(view_rect, view_zoom)
	var centre_room: Dictionary = RoomsScript.room_at(view_rect.get_center())
	if _wanted.has(centre_room.id) and not _rooms.has(centre_room.id):
		_start_room(centre_room, true)

func has_room_built(id: String) -> bool:
	return _rooms.has(id) and bool(_rooms[id].done)
