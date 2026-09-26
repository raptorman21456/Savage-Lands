extends SceneTree

# The town's venue slots (Main.gd:TOWN_LAYOUT) and the reserved outskirts
# footprints (pond, race track) are pure geometry, so this checks it as
# geometry: nothing overlaps, no door trigger sits in a street or another
# building, nothing pokes through the wall, and the world is big enough that
# the outskirts venues have wilderness around them. Same print-and-eyeball
# convention as every other test here -- an "(expected X)" that diverges is a
# failure.

const GATE_GAP := 240.0

func _footprint(entry: Dictionary) -> Rect2:
	return Rect2(entry.pos - entry.size / 2.0, entry.size)

# Same convention as Main._place_building: the door's CENTER sits 6px below
# the footprint's bottom edge.
func _door_rect(entry: Dictionary) -> Rect2:
	var center: Vector2 = entry.pos + Vector2(0, entry.size.y / 2.0 + 6.0)
	return Rect2(center - entry.door / 2.0, entry.door)

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var layout: Dictionary = main.TOWN_LAYOUT
	var town_size: Vector2 = main.TOWN_SIZE
	var town_local := Rect2(Vector2.ZERO, town_size)
	var center: Vector2 = town_size / 2.0

	# The two 240-wide streets between the four gates, plus the castle and
	# the fountain -- decorative, but still not somewhere a door trigger or
	# another building may sit.
	var street_ns := Rect2(center.x - GATE_GAP / 2.0, 0, GATE_GAP, town_size.y)
	var street_ew := Rect2(0, center.y - GATE_GAP / 2.0, town_size.x, GATE_GAP)
	var castle := Rect2(Vector2(center.x, 260) - Vector2(320, 288) / 2.0, Vector2(320, 288))
	var fountain := Rect2(center - Vector2(120, 108) / 2.0, Vector2(120, 108))

	print("world is the bigger 4800x3400 map: %s (expected true)" % [main.WORLD_SIZE == Vector2(4800, 3400)])
	print("all %d layout slots are non-empty and every built kind has one: %s (expected true)" % [
		layout.size(), layout.size() >= 13 and main.TOWN_BUILT_KINDS.all(func(k): return layout.has(k))
	])

	var kinds: Array = layout.keys().filter(func(k): return not layout[k].get("outside", false))
	var outside_kinds: Array = layout.keys().filter(func(k): return layout[k].get("outside", false))
	var all_inside := true
	var footprint_overlap := false
	var door_in_other_building := false
	var door_overlap := false
	var in_street := false
	var hits_castle_or_fountain := false
	for i in kinds.size():
		var a: Dictionary = layout[kinds[i]]
		var fa: Rect2 = _footprint(a)
		var da: Rect2 = _door_rect(a)
		# Kept 40px off the wall on every side, doors included.
		if not town_local.grow(-40.0).encloses(fa) or not town_local.grow(-40.0).encloses(da):
			all_inside = false
			print("  outside the walls: %s" % [kinds[i]])
		if fa.intersects(street_ns) or fa.intersects(street_ew) or da.intersects(street_ns) or da.intersects(street_ew):
			in_street = true
			print("  in a street: %s" % [kinds[i]])
		if fa.intersects(castle) or fa.intersects(fountain) or da.intersects(castle) or da.intersects(fountain):
			hits_castle_or_fountain = true
			print("  touches castle/fountain: %s" % [kinds[i]])
		for j in kinds.size():
			if i == j:
				continue
			var b: Dictionary = layout[kinds[j]]
			if i < j:
				if fa.intersects(_footprint(b)):
					footprint_overlap = true
					print("  footprints overlap: %s / %s" % [kinds[i], kinds[j]])
				if da.intersects(_door_rect(b)):
					door_overlap = true
					print("  doors overlap: %s / %s" % [kinds[i], kinds[j]])
			if da.intersects(_footprint(b)):
				door_in_other_building = true
				print("  %s's door sits inside %s" % [kinds[i], kinds[j]])
	print("every footprint and door sits 40px clear of the wall: %s (expected true)" % [all_inside])
	print("no two buildings overlap: %s (expected false)" % [footprint_overlap])
	print("no two door triggers overlap: %s (expected false)" % [door_overlap])
	print("no door trigger sits inside another building: %s (expected false)" % [door_in_other_building])
	print("no building or door blocks a gate-to-gate street: %s (expected false)" % [in_street])
	print("nothing overlaps the castle or fountain: %s (expected false)" % [hits_castle_or_fountain])

	# Gate guards stand 150px either side of each gate, just inside the wall.
	var guards: Array = [
		Vector2(center.x - 150, 36), Vector2(center.x + 150, 36),
		Vector2(center.x - 150, town_size.y - 36), Vector2(center.x + 150, town_size.y - 36),
		Vector2(36, center.y - 150), Vector2(36, center.y + 150),
		Vector2(town_size.x - 36, center.y - 150), Vector2(town_size.x - 36, center.y + 150),
	]
	var guard_hit := false
	for g in guards:
		var guard_rect := Rect2(g - Vector2(16, 16), Vector2(32, 32))
		for kind in kinds:
			if guard_rect.intersects(_footprint(layout[kind])) or guard_rect.intersects(_door_rect(layout[kind])):
				guard_hit = true
				print("  a gate guard overlaps %s" % [kind])
	print("no gate guard overlaps a building or door: %s (expected false)" % [guard_hit])

	# The built venues really are where the table says (and in the map's
	# numbering order).
	var positions_match := true
	for kind in main.TOWN_BUILT_KINDS:
		if not main.town_building_positions.has(kind) or main.town_building_positions[kind] != main.TOWN_AREA_ORIGIN + layout[kind].pos:
			positions_match = false
	print("every built venue was placed at its layout slot: %s (expected true), count=%d (expected %d, plaza plus outskirts)" % [
		positions_match, main.town_building_positions.size(), main.TOWN_BUILT_KINDS.size() + main.TOWN_OUTSKIRTS_KINDS.size()
	])

	# Outskirts venues: the door trigger sits outside the walls, inside its own
	# footprint's rect, clear of the fence gap's walls.
	var pond_rect: Rect2 = main.FISHING_POND_RECT
	var track_rect: Rect2 = main.RACE_TRACK_RECT
	for kind in outside_kinds:
		var door_center: Vector2 = main.TOWN_AREA_ORIGIN + layout[kind].pos
		var door_rect := Rect2(door_center - layout[kind].door / 2.0, layout[kind].door)
		var zone: Rect2 = track_rect if kind == "horse_racing" else pond_rect
		print("%s's door is outside the walls (%s, expected false for in-town) and touching its own venue's ground (%s, expected true)" % [
			kind, main._in_town_area(door_center), zone.grow(80.0).encloses(door_rect)
		])
		print("...and is registered in the map's building list: %s (expected true)" % [main.town_building_positions.has(kind)])

	# Outskirts: the pond and race track sit outside the walls, off each other,
	# well inside the world, and protected from decorations/enemy spawns.
	var pond: Rect2 = main.FISHING_POND_RECT
	var track: Rect2 = main.RACE_TRACK_RECT
	var world := Rect2(Vector2.ZERO, main.WORLD_SIZE)
	print("pond and race track sit outside the town and off each other: %s (expected false)" % [
		pond.intersects(main.TOWN_AREA_RECT) or track.intersects(main.TOWN_AREA_RECT) or pond.intersects(track)
	])
	print("both have 300px of wilderness around them inside the world: %s (expected true)" % [
		world.grow(-300.0).encloses(pond) and world.grow(-300.0).encloses(track)
	])
	print("the protected zone covers the town, pond and track but not open wilderness: town=%s pond=%s track=%s wild=%s (expected true true true false)" % [
		main._in_protected_zone(main.TOWN_AREA_RECT.get_center()),
		main._in_protected_zone(pond.get_center()),
		main._in_protected_zone(track.get_center()),
		main._in_protected_zone(main.PLAYER_SPAWN_POSITION),
	])
	print("...but only the plaza counts as being in town for the HUD label: pond_in_town=%s (expected false)" % [main._in_town_area(pond.get_center())])

	var any_deco_protected := false
	for d in main.deco_nodes:
		if main._in_protected_zone(d.position):
			any_deco_protected = true
			break
	print("no scattered decoration lands in the town, pond or track: %s (expected false), decorations=%d" % [any_deco_protected, main.deco_nodes.size()])
	var any_spawn_protected := false
	for i in 300:
		if main._in_protected_zone(main._random_enemy_spawn_position()):
			any_spawn_protected = true
			break
	print("300 enemy spawn rolls never land in the town, pond or track: %s (expected false)" % [any_spawn_protected])
	print("the player still spawns just outside the town, inside the world: outside=%s inside_world=%s (expected true true)" % [
		not main._in_town_area(main.PLAYER_SPAWN_POSITION), world.has_point(main.PLAYER_SPAWN_POSITION)
	])

	quit()
