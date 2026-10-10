extends SceneTree

# The room layer (scripts/Rooms.gd): the grid, merged rooms, who is in which room, neighbours, edge barriers and
# every room's personality.

const WM := preload("res://scripts/WorldMap.gd")
const RM := preload("res://scripts/Rooms.gd")

func _init() -> void:
	var t0 := Time.get_ticks_msec()
	RM.ensure_built()
	print("Building every room takes well under a second: %d ms (expected < 1500)" % [Time.get_ticks_msec() - t0])
	print("The continent is an 11 x 11 grid with many cells merged into long, tall and great rooms: %d rooms (expected 60-105)" % [RM.rooms.size()])

	# --- the grid tiles the map with no gaps and no overlaps
	var area := 0.0
	var inside := true
	for r in RM.rooms:
		area += r.rect.get_area()
		if r.rect.position.x < 0.0 or r.rect.position.y < 0.0 or r.rect.end.x > WM.SIZE.x + 0.5 or r.rect.end.y > WM.SIZE.y + 0.5:
			inside = false
	print("The rooms tile the whole map exactly: area %.0f vs %.0f (expected equal), all inside the map: %s (expected true)" % [area, WM.SIZE.x * WM.SIZE.y, inside])
	var overlaps := 0
	for i in RM.rooms.size():
		for j in range(i + 1, RM.rooms.size()):
			if RM.rooms[i].rect.grow(-1.0).intersects(RM.rooms[j].rect.grow(-1.0)):
				overlaps += 1
	print("...and never overlap: %d (expected 0)" % [overlaps])
	var plain: Dictionary = {}
	for r in RM.rooms:
		if r.span == Vector2i(1, 1) and r.kind == "wild":
			plain = r
			break
	print("An ordinary room is about four screens wide: %.0f x %.0f (expected about 3055 x 2164)" % [plain.rect.size.x, plain.rect.size.y])

	# --- who is where
	var wrong := 0
	for r in RM.rooms:
		for p in [r.rect.position + Vector2(5, 5), r.rect.end - Vector2(5, 5), r.rect.get_center()]:
			if RM.room_at(p).id != r.id:
				wrong += 1
	print("room_at finds the right room for corners and centres of all rooms: wrong=%d (expected 0)" % [wrong])
	print("The Castle Town is the middle room: '%s' (%s), kind %s (expected The Castle Town, safe)" % [RM.room_at(WM.SIZE / 2.0).name, RM.room_at(WM.SIZE / 2.0).id, RM.room_at(WM.SIZE / 2.0).kind])
	var spawn_room: Dictionary = RM.room_at(WM.spawn_position())
	print("You wake in '%s' at room (%d,%d), %.0f px from its west edge (expected Where You Woke, (4,3), about 700), region %s (expected woods_edge)" % [spawn_room.name, spawn_room.cell.x, spawn_room.cell.y, WM.spawn_position().x - spawn_room.rect.position.x, WM.region_at(WM.spawn_position()).id])
	var heart: Dictionary = RM.room_at(WM.landmark("heartwood").pos)
	print("The HeartWood has a 2 x 2 room of its own: %s span %s, %.0f x %.0f (expected heartwood, (2, 2), about 6109 x 4327), kind %s (expected boss)" % [heart.id, heart.span, heart.rect.size.x, heart.rect.size.y, heart.kind])
	var ruins: Dictionary = RM.room_at(WM.landmark("ruins").pos)
	print("The ruined settlement fills a wide 2 x 1 room: %s span %s (expected ruins, (2, 1))" % [ruins.id, ruins.span])
	var crater: Dictionary = RM.room_at(WM.landmark("crater").pos)
	print("The crater has a tall 1 x 2 room: %s span %s (expected crater, (1, 2)), kind %s (expected boss)" % [crater.id, crater.span, crater.kind])
	var pesca: Dictionary = RM.room_at(WM.landmark("pesca").pos)
	print("Pesca has a 2 x 2 room, safe: %s span %s kind %s (expected pesca, (2, 2), safe)" % [pesca.id, pesca.span, pesca.kind])
	print("The ranch room is safe too: %s (expected safe)" % [RM.room_at(WM.landmark("ranch").pos).kind])
	var bosses := []
	for l in WM.landmarks:
		if l.boss != "":
			var r: Dictionary = RM.room_at(l.pos)
			bosses.append("%s:%s" % [l.id, r.kind])
	print("Every boss landmark sits in a boss room: %s (expected 6 x boss)" % [bosses])
	var every_landmark_room := true
	for l in WM.landmarks:
		if not (l.id in RM.room_at(l.pos).landmarks):
			every_landmark_room = false
	print("Rooms know their landmarks: %s (expected true)" % [every_landmark_room])

	# --- neighbours
	var middle: Dictionary = RM.room_at(WM.SIZE / 2.0)
	print("A room in the middle has up to 8 neighbours (fewer where they are merged): %d (expected 4-8), loaded set %d (expected 5-9)" % [RM.neighbours(middle).size(), RM.loaded_set(middle).size()])
	var corner: Dictionary = RM.room_at(Vector2(10, 10))
	print("A corner room has 3: %d (expected 3)" % [RM.neighbours(corner).size()])
	print("The HeartWood's big room has 12 neighbours around its rim (some may be merged): %d (expected between 8 and 12)" % [RM.neighbours(heart).size()])
	var sym := true
	for r in RM.rooms:
		for n in RM.neighbours(r):
			var back := false
			for q in RM.neighbours(n):
				if q.id == r.id:
					back = true
			if not back:
				sym = false
	print("Being a neighbour is mutual: %s (expected true)" % [sym])
	print("Rooms near a point: a point deep in a room is in just that room (margin 100): %d (expected 1), at a corner of up to four rooms (margin 100): %d (expected 2-4)" % [RM.rooms_near(plain.rect.get_center(), 100.0).size(), RM.rooms_near(Vector2(WM.col_x(3), WM.row_y(6)), 100.0).size()])

	# --- edges: the ways through a shared side
	var edge_list: Array = RM.edges(middle)
	print("The middle room has 4 edges (one per side): %d (expected 4)" % [edge_list.size()])
	print("The town room is open all round: %s (expected true)" % [edge_list.all(func(e): return e.openings == [[0.0, 1.0]])])
	print("Edge lists of the HeartWood room cover all its cell sides: %d (expected 8)" % [RM.edges(heart).size()])
	var wide_open := 0
	var wide := 0
	var gaps := 0
	var two_gaps := 0
	var mismatch := 0
	var bad_gap := 0
	for r in RM.rooms:
		for e in RM.edges(r):
			var other_edges: Array = RM.edges(e.other)
			var found := false
			for oe in other_edges:
				if oe.key == e.key:
					found = true
					if oe.openings != e.openings:
						mismatch += 1
			if not found:
				mismatch += 1
			if e.openings.size() == 1 and e.openings[0][0] == 0.0 and e.openings[0][1] == 1.0:
				wide_open += 1
			elif e.openings.size() == 1 and (float(e.openings[0][1]) - float(e.openings[0][0])) * float(e.length) > RM.GAP_WIDTH_MAX + 1.0:
				wide += 1
			else:
				gaps += 1
				if e.openings.size() == 2:
					two_gaps += 1
			for o in e.openings:
				if float(o[0]) < 0.0 or float(o[1]) > 1.0 or float(o[1]) - float(o[0]) < 0.05:
					bad_gap += 1
	print("Sides: %d wide open, %d wide openings, %d narrow gaps (%d of them two gaps); both rooms agree on every one: mismatches=%d (expected 0), malformed openings=%d (expected 0)" % [wide_open, wide, gaps, two_gaps, mismatch, bad_gap])
	print("Every room can be left (at least one opening on a side that has a neighbour): %s (expected true)" % [RM.rooms.all(func(r): return RM.exits(r).size() >= 1)])
	print("The spawn room opens wide to the plains on its east side and has trails on the others: east=%s (expected [[0.0, 1.0]]), others narrow: %s (expected true)" % [RM.edges(spawn_room).filter(func(e): return e.side == "e")[0].openings, RM.edges(spawn_room).filter(func(e): return e.side != "e").all(func(e): return e.openings.size() == 1 and (float(e.openings[0][1]) - float(e.openings[0][0])) * float(e.length) < 800.0)])
	print("Exits carry where, which way in and how wide: %s (expected pos/n/width)" % [RM.exits(middle)[0].keys().filter(func(k): return k in ["pos", "n", "width"])])

	# --- shapes: every room's floor
	var t_shapes := Time.get_ticks_msec()
	var worst_ms := 0
	var archetypes := {}
	var floors := []
	var disconnected := 0
	var exit_not_floor := 0
	var landmark_not_floor := 0
	var repairs := 0
	for r in RM.rooms:
		var t1 := Time.get_ticks_msec()
		var L = RM.layout(r)
		worst_ms = maxi(worst_ms, Time.get_ticks_msec() - t1)
		archetypes[r.layout] = int(archetypes.get(r.layout, 0)) + 1
		floors.append(L.floor_fraction)
		repairs += L.repairs
		for ex in RM.exits(r):
			if L.sample(ex.pos + ex.n * 20.0) <= 0.0:
				exit_not_floor += 1
		for d in RM.structure_discs(r):
			if L.sample(d[0]) <= 0.0:
				landmark_not_floor += 1
	floors.sort()
	print("Every room's shape builds: %d layouts in %d ms, worst %d ms (expected worst under 400)" % [RM.rooms.size(), Time.get_ticks_msec() - t_shapes, worst_ms])
	print("Shapes in use: %s (expected 10+ different)" % [archetypes])
	print("How much of a room is floor: least %.0f%%, median %.0f%%, most %.0f%% (expected least > 15%%, most < 100%%)" % [floors[0] * 100.0, floors[floors.size() / 2] * 100.0, floors[floors.size() - 1] * 100.0])
	print("Every opening leads onto floor: not floor=%d (expected 0); every landmark stands on floor: %d (expected 0); paths that had to be carved to keep it connected: %d (expected few)" % [exit_not_floor, landmark_not_floor, repairs])

	# the two sides of a shared edge line up: floor meets floor and solid meets solid along the whole line
	var checked := 0
	var disagree := 0
	for r in RM.rooms:
		var L = RM.layout(r)
		for e in RM.edges(r):
			var LO = RM.layout(e.other)
			for k in 24:
				var t := (float(k) + 0.5) / 24.0
				var p: Vector2 = Vector2(e.from).lerp(e.to, t)
				# nudge a hair into each room (samples exactly on the line are ambiguous)
				var a: float = L.sample(p + e.inward * 3.0)
				var b: float = LO.sample(p - e.inward * 3.0)
				checked += 1
				if (a > 0.0) != (b > 0.0):
					disagree += 1
	print("Along every shared edge the two rooms agree what is floor and what is solid: %d disagreements in %d samples (expected under 1%%)" % [disagree, checked])

	# the outline collision exists and is a reasonable size
	var seg_total := 0
	for r in RM.rooms:
		seg_total += RM.layout(r).segments().size() / 2
	print("Collision outlines: %d segments over all rooms, %.0f per room (expected 20-600 per room)" % [seg_total, float(seg_total) / float(RM.rooms.size())])
	# the field gives the distance to the edge in the right ballpark: a point 150 px inside the floor edge reads about 150
	var L0 = RM.layout(spawn_room)
	print("The spawn room is a clearing with trails, about half floor: floor fraction %.2f (expected 0.3-0.7)" % [L0.floor_fraction])
	var rebuilt = RM.RoomLayoutScript.generate(spawn_room, RM.exits(spawn_room), RM.structure_discs(spawn_room))
	print("A shape is the same every time it is built: %s (expected true)" % [rebuilt.field == L0.field])

	# --- the hand-made rooms (RoomData.gd)
	var authored: Array = RM.rooms.filter(func(r): return r.authored)
	print("Hand-made rooms are in the world: %d (expected 70 or more), almost all with a shape of their own: %d (expected all but Pesca)" % [authored.size(), authored.filter(func(r): return r.layout == "authored").size()])
	var bad_pairs := []
	for key in RM.RoomDataScript.EDGES:
		var halves: PackedStringArray = str(key).split("|")
		var a := halves[0].split(",")
		var b := halves[1].split(",")
		var apart: int = absi(int(a[0]) - int(b[0])) + absi(int(a[1]) - int(b[1]))
		if apart != 1:
			bad_pairs.append(key)
	print("Every hand-made side names two neighbouring cells: bad=%s (expected [])" % [bad_pairs])
	var spawn_door: Array = RM.edges(spawn_room).filter(func(e): return e.side == "w")[0].openings
	print("A hand-made doorway is exactly where it was put: the trail west of where you wake is %.0f px wide, centred %.0f px down (expected 480, 1082): %s" % [(float(spawn_door[0][1]) - float(spawn_door[0][0])) * 2164.0, (float(spawn_door[0][1]) + float(spawn_door[0][0])) * 0.5 * 2164.0, spawn_door])
	print("...a side marked closed has no opening: %s (expected [])" % [RM.edges(RM.room_at(Vector2(WM.col_x(0) + 100.0, WM.row_y(2) + 100.0))).filter(func(e): return e.side == "e")[0].openings])
	var named_authored: Array = authored.filter(func(r): return r.name != "").map(func(r): return r.name)
	print("Only the places worth a name in the hand-made rooms have one: %s (expected a minority: 15 or so, the places worth finding)" % [named_authored])
	var floors_ok := true
	for r in authored:
		var Lr = RM.layout(r)
		if Lr.floor_fraction < 0.12 or Lr.repairs > 4:
			floors_ok = false
	print("Every hand-made room has a good amount of floor and needed no big repairs: %s (expected true)" % [floors_ok])

	# --- roads
	var OWM := preload("res://scripts/OverworldMap.gd")
	var off_floor := []
	var road_points := 0
	for road in RM.RoomDataScript.ROADS:
		var pts: Array = []
		for p in road.points:
			pts.append(OWM._cell_to_px(p))
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var n := int(a.distance_to(b) / 150.0)
			for k in n + 1:
				var q: Vector2 = a.lerp(b, float(k) / float(maxi(n, 1)))
				road_points += 1
				var room_here: Dictionary = RM.room_at(q)
				if RM.layout(room_here).sample(q) < 0.0:
					off_floor.append("%s@%s" % [room_here.id, Vector2i(q / 100.0)])
	print("Every road runs on ground you can stand on: %d of %d sample points are in a wall: %s (expected 0)" % [off_floor.size(), road_points, off_floor.slice(0, 6)])
	print("The north road starts at the town's north gate and reaches the ruins: starts %s (expected near (16800, 11400)), ends %s (expected near the ruins %s)" % [OWM._cell_to_px(RM.RoomDataScript.ROADS[1].points[0]), OWM._cell_to_px(RM.RoomDataScript.ROADS[1].points[RM.RoomDataScript.ROADS[1].points.size() - 1]), WM.landmark("ruins").pos])

	# --- personalities
	var variants := {}
	var kinds := {}
	for r in RM.rooms:
		variants[r.variant] = int(variants.get(r.variant, 0)) + 1
		kinds[r.kind] = int(kinds.get(r.kind, 0)) + 1
	print("Rooms by kind: %s (expected sea, safe: 3, boss: 6, wild)" % [kinds])
	print("There are plenty of different kinds of room: %d variants in use (expected > 25)" % [variants.size()])
	var named := 0
	var no_enemies := 0
	for r in RM.rooms:
		if r.name != "":
			named += 1
		if r.kind in ["wild", "boss"] and r.enemies.is_empty() and WM.region(r.region).enemies.is_empty():
			no_enemies += 1
		if r.kind in ["wild", "boss"] and r.target <= 0:
			no_enemies += 100
	print("Only notable rooms have a name: named=%d of %d (expected a minority); every wild or boss room has something living in it: problems=%d (expected 0)" % [named, RM.rooms.size(), no_enemies])
	var sea_target := true
	for r in RM.rooms:
		if r.kind in ["sea", "safe"] and r.target != 0:
			sea_target = false
	print("Safe rooms and open sea hold no roaming enemies: %s (expected true)" % [sea_target])
	var again := true
	var first := {}
	for r in RM.rooms:
		first[r.id] = r.variant
	RM._built = false
	RM.ensure_built()
	for r in RM.rooms:
		if first[r.id] != r.variant:
			again = false
	print("Rebuilding gives exactly the same rooms: %s (expected true)" % [again])
	var names := []
	for row in RM.ROWS:
		var line := ""
		for col in RM.COLS:
			var r: Dictionary = RM.room_at(Vector2(WM.col_x(col) + 10, WM.row_y(row) + 10))
			line += "%-22s" % [r.name.substr(0, 20)]
		names.append(line)
	print("--- the continent, room by room ---")
	for line in names:
		print(line)
	quit()
