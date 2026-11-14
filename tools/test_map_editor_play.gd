extends SceneTree

# The Map Editor's "Play here" (MapEditorPlay.gd): a walker with the player's body and speed is put on open ground in the picked room, the camera
# follows it at the game's zoom, trees and walls stop it, Shift runs, the rooms round it are built as it goes, it walks through edits that
# are not saved yet, and Esc / P / the button bring you back to the editor without touching the map data. Each line states what it checked.
# Nothing is written to res://data (the editor here points its saves at a scratch folder).
#
#   Godot --headless --path . --script res://tools/test_map_editor_play.gd

const MapDataScript := preload("res://scripts/MapData.gd")
const RoomsScript := preload("res://scripts/Rooms.gd")
const PlayerScript := preload("res://scripts/Player.gd")

var ed = null
var _real_before := {}

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _open():
	var e = load("res://MapEditor.tscn").instantiate()
	e.data_dir = "user://map_play_test"
	root.add_child(e)
	await process_frame
	await process_frame
	return e

func _floor_depth(pos: Vector2) -> float:
	return RoomsScript.layout(RoomsScript.room_at(pos)).sample(pos)

func _init() -> void:
	await process_frame
	await process_frame
	root.size = Vector2i(1152, 648)
	for kind in MapDataScript.KINDS:
		_real_before[kind] = FileAccess.get_file_as_string(MapDataScript.file_path(kind))
	ed = await _open()

	print("--- the button, the key and the way in")
	var has_button := false
	var buttons: Array = []
	_find_buttons(ed.ui, buttons)
	for b in buttons:
		if b.text == "Play here":
			has_button = true
	print("the top bar has a Play here button: %s (expected true)" % [has_button])
	print("nothing is playing at first: %s (expected false); the panels are showing: %s (expected true)" % [ed.play.active, ed.ui.visible])

	print("--- starting in the picked room")
	ed.pick_cell(Vector2i(4, 3))
	ed.focus_room()
	var dirty_before: bool = ed.dirty
	var undo_before: int = ed.undo_stack.size()
	var doc_before: String = var_to_str(ed.doc)
	ed.play_here()
	await _frames(8)
	print("Play here starts the walker: active=%s, a Walker is in the scene: %s (expected true, true)" % [ed.play.active, ed.get_node_or_null("Walker") != null])
	var room: Dictionary = RoomsScript.room_at(ed.play.body.global_position)
	print("it stands in the picked room, %d,%d (expected 4,3)" % [room.cell.x, room.cell.y])
	print("...on open ground, %d px inside the floor's edge (expected over 100): %s" % [int(_floor_depth(ed.play.body.global_position)), _floor_depth(ed.play.body.global_position) > 100.0])
	print("the editor's panels are hidden while you play: %s (expected true)" % [not ed.ui.visible])
	print("the camera is on the walker at the game's zoom: zoom %s (expected 1.6), distance %d px (expected under 4)" % [ed.camera.zoom.x, int(ed.camera.position.distance_to(ed.play.body.global_position))])
	print("the banner names the room: '%s' (expected to include Where You Woke)" % [ed.play.banner_text()])
	print("the body is the player's: radius %d (expected %d), walking speed %d px/s (expected %d)" % [int(ed.play.body.get_child(0).shape.radius), int(PlayerScript.BODY_RADIUS), int(ed.play.speed_now()), int(PlayerScript.AGILITY_START)])

	print("--- walking")
	var start: Vector2 = ed.play.body.global_position
	ed.play.test_dir = Vector2(1, 0)
	await _frames(60)
	var moved: float = ed.play.body.global_position.x - start.x
	print("a second of walking east covers about the walking speed: %d px (expected near 180, between 120 and 200)" % [int(moved)])
	ed.play.test_dir = Vector2.ZERO
	await _frames(6)
	var at_rest: Vector2 = ed.play.body.global_position
	await _frames(10)
	print("with no key down it stands still: %s (expected true)" % [ed.play.body.global_position.distance_to(at_rest) < 1.0])
	ed.play.test_run = true
	var before_run: Vector2 = ed.play.body.global_position
	ed.play.test_dir = Vector2(0, 1)
	await _frames(30)
	var ran: float = ed.play.body.global_position.y - before_run.y
	print("holding Shift runs about three times as fast: half a second covers %d px (expected near 270, between 150 and 300)" % [int(ran)])
	ed.play.test_run = false
	ed.play.test_dir = Vector2.ZERO
	print("the camera kept up: %d px from the walker (expected under 4)" % [int(ed.camera.position.distance_to(ed.play.body.global_position))])

	print("--- walls stop it")
	var spot: Vector2 = ed.play.body.global_position
	# find the nearest edge of the floor in the four directions (a trail can run on for a whole room, so the nearest is the real wall),
	# put the walker 70 px inside it, and walk straight at it
	var best_dir := Vector2.ZERO
	var best_dist := 1.0e9
	var edge: Vector2 = spot
	for d in [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
		var p: Vector2 = spot
		var travelled := 0.0
		while travelled < 1500.0 and _floor_depth(p) > 0.0:
			p += d * 10.0
			travelled += 10.0
		if travelled < best_dist:
			best_dist = travelled
			best_dir = d
			edge = p
	var inside: Vector2 = edge - best_dir * 70.0
	ed.play.body.global_position = inside
	ed.play.body.velocity = Vector2.ZERO
	await _frames(4)
	ed.play.test_dir = best_dir
	var lowest := 1.0e9
	for i in 120:
		await physics_frame
		lowest = minf(lowest, _floor_depth(ed.play.body.global_position))
	ed.play.test_dir = Vector2.ZERO
	var depth: float = _floor_depth(ed.play.body.global_position)
	print("the nearest wall is %d px away, to the %s: it was walked into for two seconds" % [int(best_dist), best_dir])
	print("two seconds of walking into the wall: the walker was never off the floor, its lowest depth %d px (expected above -25)" % [int(lowest)])
	print("...and it reached the wall and stayed against it: it ends %d px inside the edge (expected under 40; the body is 16 px wide)" % [int(depth)])

	print("--- rooms are built as it goes")
	# the broad path east out of Where You Woke, from past the ring of stones, run along it for several rooms: the walker must never be standing in a
	# room that has not been built yet (the rooms are built ahead of it)
	var here_room: Dictionary = RoomsScript.room_at(spot)
	var path_start := Vector2(here_room.rect.position.x + 1300.0, here_room.rect.position.y + 1082.0)
	ed.play.body.global_position = path_start
	ed.play.body.velocity = Vector2.ZERO
	await _frames(20)
	ed.play.test_run = true
	ed.play.test_dir = Vector2(1, 0)
	var unbuilt_frames := 0
	var rooms_seen := {}
	for i in 330:
		await physics_frame
		var in_room: Dictionary = RoomsScript.room_at(ed.play.body.global_position)
		rooms_seen[str(in_room.id)] = true
		if not ed.world.has_room_built(str(in_room.id)):
			unbuilt_frames += 1
	ed.play.test_run = false
	ed.play.test_dir = Vector2.ZERO
	var crossed: Dictionary = RoomsScript.room_at(ed.play.body.global_position)
	print("running east for five and a half seconds crosses into other rooms: %d rooms visited (%s) (expected 2 or more)" % [rooms_seen.size(), ", ".join(rooms_seen.keys())])
	print("...and never once stood in a room that was not built yet: %d frames (expected 0)" % [unbuilt_frames])
	print("...ending in %s, on floor %d px deep (expected a room other than r4_3, depth over 0)" % [str(crossed.id), int(_floor_depth(ed.play.body.global_position))])

	print("--- coming back")
	ed.play.test_dir = Vector2.ZERO
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	ed._unhandled_input(key)
	await process_frame
	print("Esc comes back: active=%s, panels showing=%s (expected false, true)" % [ed.play.active, ed.ui.visible])
	print("the walker is gone: %s (expected true)" % [ed.get_node_or_null("Walker") == null])
	var back_room: Dictionary = RoomsScript.room_at(ed.cam_pos)
	print("you walked into another room, so the editor picked it and fitted it: looking at room %d,%d, picked %d,%d (expected the room it ended in, %d,%d, both times)" % [back_room.cell.x, back_room.cell.y, ed.room_cell.x, ed.room_cell.y, crossed.cell.x, crossed.cell.y])
	print("playing changed nothing in the map data: doc the same=%s, undo steps %d -> %d (expected equal), unsaved flag %s -> %s (expected equal)" % [var_to_str(ed.doc) == doc_before, undo_before, ed.undo_stack.size(), dirty_before, ed.dirty])

	print("--- staying in the room: the editor looks as it did")
	ed.pick_cell(Vector2i(0, 0))
	ed.focus_room()
	var cam_before: Vector2 = ed.cam_pos
	var zoom_before: float = ed.zoom
	ed.play_here()
	await _frames(10)
	print("started in the Fairy Ring: %d,%d (expected 0,0)" % [RoomsScript.room_at(ed.play.body.global_position).cell.x, RoomsScript.room_at(ed.play.body.global_position).cell.y])
	var p_key := InputEventKey.new()
	p_key.keycode = KEY_P
	p_key.pressed = true
	ed._unhandled_input(p_key)
	await process_frame
	print("P comes back: active=%s (expected false)" % [ed.play.active])
	print("the view is exactly as it was: camera moved %d px (expected 0), zoom %s -> %s (expected equal)" % [int(ed.cam_pos.distance_to(cam_before)), snappedf(zoom_before, 0.001), snappedf(ed.zoom, 0.001)])
	ed.play_here()
	await _frames(5)
	ed.play_here()
	await process_frame
	print("pressing the button again while playing comes back too: active=%s (expected false)" % [ed.play.active])

	print("--- an edit that is not saved yet is what you walk through")
	ed.pick_cell(Vector2i(6, 6))            # the Ranch: drawn by the generator until it is made hand-made
	var was_made: bool = ed.is_handmade()
	ed.make_handmade()
	await process_frame
	await process_frame
	print("the Ranch room was hand-made before: %s, now: %s, unsaved: %s (expected false, true, true)" % [was_made, ed.is_handmade(), ed.dirty])
	ed.play_here()
	await _frames(12)
	var ranch: Dictionary = RoomsScript.room_at(ed.play.body.global_position)
	print("Play here starts inside it, on its new floor: room %d,%d (expected 6,6), %d px inside the edge (expected over 100)" % [ranch.cell.x, ranch.cell.y, int(_floor_depth(ed.play.body.global_position))])
	var edit_depth_ok: bool = _floor_depth(ed.play.body.global_position) > 100.0
	ed.play_here()
	await process_frame
	print("and the edit is still unsaved afterwards: %s (expected true)" % [ed.dirty])

	print("--- starting from the mouse and from the sea")
	var wanted := Vector2(RoomsScript.room_at(Vector2(16800, 11900)).rect.get_center())
	ed.play_here(wanted)
	await _frames(10)
	print("P starts where it is told: %d px from the point asked (expected under 700, the nearest open ground to it)" % [int(ed.play.body.global_position.distance_to(wanted))])
	ed.play_here()
	await process_frame
	ed.pick_cell(Vector2i(0, 10))
	ed.play_here()
	await _frames(8)
	var sea_start: Vector2 = ed.play.body.global_position if ed.play.active else Vector2.INF
	print("from the open sea it starts on the nearest land, or says there is none: active=%s, depth %s (expected true and over 100)" % [ed.play.active, int(_floor_depth(sea_start)) if ed.play.active else "n/a"])
	if ed.play.active:
		ed.play_here()
		await process_frame

	print("--- the real data was not touched")
	var untouched := true
	for kind in MapDataScript.KINDS:
		if FileAccess.get_file_as_string(MapDataScript.file_path(kind)) != _real_before[kind]:
			untouched = false
	print("the shipped data files in res://data are exactly as they were: %s (expected true)" % [untouched])
	print("(ranch edit seen: %s)" % [edit_depth_ok])
	quit()

func _find_buttons(node: Node, out: Array) -> void:
	if node is PixelButton:
		out.append(node)
	for c in node.get_children():
		_find_buttons(c, out)
