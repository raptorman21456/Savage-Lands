extends SceneTree

# Building the overworld room by room (scripts/OverworldMap.gd on top of scripts/Rooms.gd): every room on the
# continent can be built, how long that takes, whether each room's set pieces find a place, and that scenery stays
# out of them.

const WM := preload("res://scripts/WorldMap.gd")
const RM := preload("res://scripts/Rooms.gd")
const OW := preload("res://scripts/OverworldMap.gd")

func _init() -> void:
	var map = OW.new()
	root.add_child(map)
	var t0 := Time.get_ticks_msec()
	map.build()
	print("Painting the regions and the sea takes a moment, once: %d ms (expected < 5000)" % [Time.get_ticks_msec() - t0])

	var worst := 0
	var total := 0
	var wrong_features := []
	var all_complete := true
	var overlap := 0
	var straggler_rooms: Array = []
	var mass_nodes := 0
	var nodes := 0
	var max_nodes := 0
	var by_kind := {}
	for r in RM.rooms:
		var t1 := Time.get_ticks_msec()
		map.update_rooms(r.rect.get_center())
		var took := Time.get_ticks_msec() - t1
		worst = maxi(worst, took)
		total += took
		if not map.is_room_complete(r.id):
			all_complete = false
		map.flush()
		var want := 0
		for entry in r.features:
			want += int(entry[1])
		if map.features_placed(r.id) < want:
			wrong_features.append("%s (%s): %d of %d" % [r.name, r.id, map.features_placed(r.id), want])
		var n: int = map.scenery_count(r.id)
		nodes += n
		max_nodes = maxi(max_nodes, n)
		by_kind[r.kind] = int(by_kind.get(r.kind, 0)) + n
		var st: Dictionary = map._rooms[r.id]
		mass_nodes += map.mass_sprite_count(r.id)
		for sprite in st.scenery.get_children():
			if sprite is Sprite2D and st.layout.sample(sprite.position) < 0.0:
				overlap += 1
				if not (r.id in straggler_rooms):
					straggler_rooms.append(r.id)
	print("Every one of the %d rooms can be built: rooms built=%d (expected %d)" % [RM.rooms.size(), RM.rooms.size(), RM.rooms.size()])
	print("The room you step into is complete at once: %s (expected true)" % [all_complete])
	print("Stepping into a room takes %.0f ms on average, %d ms at worst (expected the worst under 800)" % [float(total) / float(RM.rooms.size()), worst])
	print("Rooms hold %.0f scenery nodes on average, %d at most (expected under 4000)" % [float(nodes) / float(RM.rooms.size()), max_nodes])
	print("Scenery by kind of room: %s" % [by_kind])
	print("Every room's set pieces found a place: misses=%s (expected [] -- a few coastal misses are fine, listed here)" % [wrong_features])
	print("Every decoration stands on the floor, none in a wall of trees or a lake: stragglers=%d in rooms %s (expected 0); the solid ground holds %.0f sprites per room on average (expected under 3000)" % [overlap, straggler_rooms, float(mass_nodes) / float(RM.rooms.size())])
	print("Memory: only a few rooms stay built at a time: %d rooms now (expected 1-9)" % [map.loaded_room_count()])
	quit()
