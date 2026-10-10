extends SceneTree

# Building interiors (scripts/Interior.gd, Main.gd "Building interiors"): every venue's room builds, you can walk from
# the doorway to the counter, the door fades you in and out, the camera and the world outside are held still while
# you are in there.

const IN := preload("res://scripts/Interior.gd")

func _init() -> void:
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.free()
	main.enemies_alive = 0

	print("Eleven venues have a room: %d (expected 11)" % [IN.DEFS.size()])
	var bad_reach := []
	var bad_entry := []
	var overlapping := []
	for kind in IN.DEFS:
		var room = main._get_interior(kind)
		var def: Dictionary = IN.DEFS[kind]
		await physics_frame
		# the doorway, the counter and everything between must be walkable
		var entry: Vector2 = room.entry_point()
		var trade: Array = def.trade
		var target: Vector2 = room.origin + Vector2(float(trade[0]), float(trade[1]))
		player.global_position = entry
		await physics_frame
		await physics_frame
		if player.test_move(player.global_transform, Vector2.ZERO):
			bad_entry.append(kind)
		var steps := 0
		var blocked := false
		var here := entry
		# walk toward the counter in short hops, sliding round furniture the way a player would
		while here.distance_to(target) > 24.0 and steps < 200:
			var dir: Vector2 = (target - here).normalized()
			var hop: Vector2 = dir * 20.0
			player.global_position = here
			if player.test_move(player.global_transform, hop):
				var slid := false
				for alt in [Vector2(-dir.y, dir.x), Vector2(dir.y, -dir.x)]:
					if not player.test_move(player.global_transform, (dir * 0.4 + alt).normalized() * 20.0):
						here += (dir * 0.4 + alt).normalized() * 20.0
						slid = true
						break
				if not slid:
					blocked = true
					break
			else:
				here += hop
			steps += 1
		if blocked or here.distance_to(target) > 24.0:
			bad_reach.append(kind)
		# every piece of furniture and the counter stay inside the walls
		var inner := Rect2(Vector2(IN.WALL, IN.WALL), room.size - Vector2(IN.WALL, IN.WALL) * 2.0)
		for t in def.things:
			if not inner.grow(40.0).has_point(Vector2(float(t[1]), float(t[2]))):
				overlapping.append("%s:%s" % [kind, t[0]])
	# walking to a counter opens that venue's menu: shut whatever opened
	main._close_open_town_panels()
	main.hud.hide_shop()
	main.shop_open = false
	paused = false
	print("The player appears in free space at every doorway: problems=%s (expected [])" % [bad_entry])
	print("...and can walk from the doorway to the counter in every venue: problems=%s (expected [])" % [bad_reach])
	print("...and no furniture sits in or past a wall: %s (expected [])" % [overlapping])

	# --- the door, the counter, the doorway
	var door_pos := Vector2(10000, 9000)
	var world_before: Vector2 = door_pos
	player.global_position = door_pos
	main.enemies_alive = 0
	var goblin = main._spawn_one_enemy(main.EnemyScript, door_pos + Vector2(900, 0))
	main._enter_interior("shop", door_pos)
	await create_timer(1.6).timeout
	var room = main._get_interior("shop")
	print("Walk through the door and you are inside: in_interior=%s (expected true), standing in the room: %s (expected true)" % [main.in_interior, room.rect().has_point(player.global_position)])
	print("The camera is held inside the room: limits %s..%s (expected the room's corners %s..%s)" % [Vector2(main.camera.limit_left, main.camera.limit_top), Vector2(main.camera.limit_right, main.camera.limit_bottom), room.rect().position, room.rect().end])
	print("The wild is held still while you are inside: enemy still moving=%s (expected false)" % [(is_instance_valid(goblin) and goblin.is_physics_processing())])
	print("The HUD names the room: '%s' (expected General Store)" % [main.hud.world_label.text])
	# walk up to the counter: the shop opens
	var counter: Array = IN.DEFS.shop.trade
	player.global_position = room.origin + Vector2(float(counter[0]), float(counter[1]) + 100.0)
	await physics_frame
	player.global_position = room.origin + Vector2(float(counter[0]), float(counter[1]))
	await physics_frame
	await physics_frame
	await physics_frame
	print("Walking up to the counter opens the shop: shop_open=%s (expected true)" % [main.shop_open])
	main.hud.hide_shop()
	main.shop_open = false
	paused = false
	# step into the doorway: back outside, just below the door
	player.global_position = room.origin + Vector2(room.size.x * 0.5, room.size.y - 100.0)
	await physics_frame
	player.global_position = room.origin + Vector2(room.size.x * 0.5, room.size.y - IN.WALL * 0.5)
	await physics_frame
	await physics_frame
	await create_timer(1.6).timeout
	print("Stepping into the doorway puts you back outside: in_interior=%s (expected false), %.0f px below the door (expected 120)" % [main.in_interior, player.global_position.y - door_pos.y])
	print("...the camera is free again: limits to %s (expected %s) and the wild moves again: %s (expected true)" % [Vector2(main.camera.limit_right, main.camera.limit_bottom), main.WORLD_SIZE, (is_instance_valid(goblin) and goblin.is_physics_processing())])
	# a second visit reuses the same room
	main._enter_interior("shop", door_pos)
	await create_timer(1.6).timeout
	print("A second visit goes to the same room (built once): %s (expected true)" % [main._get_interior("shop") == room])
	quit()
