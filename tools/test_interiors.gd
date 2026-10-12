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

	print("Twenty-six rooms: the town's eleven venues, Pesca's six houses, the Lizen Encampment's six tents and the Ranch's three buildings: %d (expected 26)" % [IN.DEFS.size()])
	var bad_reach := []
	var bad_entry := []
	var overlapping := []
	for kind in IN.DEFS:
		var room = main._get_interior(kind)
		var def: Dictionary = IN.DEFS[kind]
		await physics_frame
		# the doorway, the counter and everything between must be walkable
		var entry: Vector2 = room.entry_point()
		var target: Vector2 = room.origin + IN.goal_of(kind)
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

	# --- Pesca's six houses: out in the world, each with a door, a room of its own and the counter of a town venue
	var houses: Array = main.OverworldMapScript.pesca_buildings()
	var bad_doors := []
	var bad_venues := []
	for h in houses:
		if not IN.DEFS.has(IN.venue_of(h.interior)) or IN.venue_of(h.interior) == h.interior:
			bad_venues.append(h.interior)
		var d: Vector2 = h.door
		for p in [d, d + Vector2(0, 120.0)]:
			player.global_position = p
			await physics_frame
			await physics_frame
			if player.test_move(player.global_transform, Vector2.ZERO) or main.WorldMapScript.is_blocked(p):
				bad_doors.append("%s@%s" % [h.interior, p])
	print("Pesca has six houses, each with its own room that trades as one of the town's venues: %d houses (expected 6), problems=%s (expected [])" % [houses.size(), bad_venues])
	print("...each door, and the spot you come out on, is open ground: problems=%s (expected [])" % [bad_doors])
	# (still standing in the shop's room from the last visit: step out of it first)
	var shop_room = main._get_interior("shop")
	player.global_position = shop_room.origin + Vector2(shop_room.size.x * 0.5, shop_room.size.y - 100.0)
	await physics_frame
	player.global_position = shop_room.origin + Vector2(shop_room.size.x * 0.5, shop_room.size.y - IN.WALL * 0.5)
	await physics_frame
	await physics_frame
	await create_timer(1.6).timeout
	var tavern_house: Dictionary = houses[0]
	var tavern_door: Vector2 = tavern_house.door
	player.global_position = tavern_door + Vector2(0, 90.0)
	await physics_frame
	player.global_position = tavern_door
	await physics_frame
	await physics_frame
	await create_timer(1.6).timeout
	var tavern_room = main._get_interior(tavern_house.interior)
	print("Walk into the first house's door and you are inside its room: in_interior=%s (expected true), room '%s' (expected The Salty Gull), standing in it: %s (expected true)" % [main.in_interior, main.hud.world_label.text, tavern_room.rect().has_point(player.global_position)])
	var counter2: Array = IN.DEFS.pesca_tavern.trade
	player.global_position = tavern_room.origin + Vector2(float(counter2[0]), float(counter2[1]) + 100.0)
	await physics_frame
	player.global_position = tavern_room.origin + Vector2(float(counter2[0]), float(counter2[1]))
	await physics_frame
	await physics_frame
	await physics_frame
	print("Its counter opens the tavern's menu: a town panel is open=%s (expected true)" % [main._any_town_panel_open()])
	main._close_open_town_panels()
	paused = false
	player.global_position = tavern_room.origin + Vector2(tavern_room.size.x * 0.5, tavern_room.size.y - 100.0)
	await physics_frame
	player.global_position = tavern_room.origin + Vector2(tavern_room.size.x * 0.5, tavern_room.size.y - IN.WALL * 0.5)
	await physics_frame
	await physics_frame
	await create_timer(1.6).timeout
	print("The doorway puts you back on Pesca's boardwalk, %.0f px below the door (expected 120): in_interior=%s (expected false), the town label is not shown: %s (expected true)" % [player.global_position.y - tavern_door.y, main.in_interior, not main.was_in_town])

	# --- the Lizen Encampment's six tents: a door each, a room of nothing to trade but a little loot lying about
	var tents: Array = main.OverworldMapScript.lizen_buildings()
	var bad_tent_doors := []
	for h in tents:
		for p in [h.door, h.return]:
			player.global_position = p
			await physics_frame
			await physics_frame
			if player.test_move(player.global_transform, Vector2.ZERO) or main.WorldMapScript.is_blocked(p):
				bad_tent_doors.append("%s@%s" % [h.interior, p])
	var no_trade := tents.all(func(h): return not IN.DEFS[h.interior].has("trade"))
	print("The Lizen Encampment has six tents, each with a room of its own and nothing to trade: %d tents (expected 6), no counters %s (expected true)" % [tents.size(), no_trade])
	print("...each door, and the spot you come out on beside it, is open ground: problems=%s (expected [])" % [bad_tent_doors])
	var tent: Dictionary = tents[0]
	player.global_position = tent.door + Vector2(0, 60.0)
	await physics_frame
	player.global_position = tent.door
	await physics_frame
	await physics_frame
	await create_timer(1.6).timeout
	var war_room = main._get_interior(tent.interior)
	var coins_before: int = player.coins
	var loot: Array = IN.DEFS[tent.interior].loot[0]
	player.global_position = war_room.origin + Vector2(float(loot[2]), float(loot[3]) + 80.0)
	await physics_frame
	player.global_position = war_room.origin + Vector2(float(loot[2]), float(loot[3]))
	await physics_frame
	await physics_frame
	await physics_frame
	print("Walk into the first tent: in_interior=%s (expected true), room '%s' (expected The War Tent); picking up its coins pays: %d -> %d (expected +%d)" % [main.in_interior, main.hud.world_label.text, coins_before, player.coins, int(loot[1])])
	player.global_position = war_room.origin + Vector2(war_room.size.x * 0.5, war_room.size.y - 100.0)
	await physics_frame
	player.global_position = war_room.origin + Vector2(war_room.size.x * 0.5, war_room.size.y - IN.WALL * 0.5)
	await physics_frame
	await physics_frame
	await create_timer(1.6).timeout
	print("The doorway puts you back in the avenue beside the tent: in_interior=%s (expected false), %.0f px from the spot beside the door (expected 0)" % [main.in_interior, player.global_position.distance_to(tent.return)])

	# --- the Ranch's three buildings: the barn takes bets on the horses, the farmhouse puts you up, the smokehouse sells meat
	var ranch_houses: Array = main.OverworldMapScript.ranch_buildings()
	var bad_ranch_doors := []
	var bad_ranch_venues := []
	for h in ranch_houses:
		if not main.town_panels.has(IN.venue_of(h.interior)):
			bad_ranch_venues.append(h.interior)
		for p in [h.door, h.return]:
			player.global_position = p
			await physics_frame
			await physics_frame
			if player.test_move(player.global_transform, Vector2.ZERO) or main.WorldMapScript.is_blocked(p):
				bad_ranch_doors.append("%s@%s" % [h.interior, p])
	print("The Ranch has three buildings, each trading as a town venue with a menu: %d buildings (expected 3), problems=%s (expected [])" % [ranch_houses.size(), bad_ranch_venues])
	print("...each door, and the spot you come out on in the yard, is open ground: problems=%s (expected [])" % [bad_ranch_doors])
	var barn: Dictionary = ranch_houses[0]
	player.global_position = barn.door + Vector2(0, 60.0)
	await physics_frame
	player.global_position = barn.door
	await physics_frame
	await physics_frame
	await create_timer(1.6).timeout
	var barn_room = main._get_interior(barn.interior)
	var barn_in: bool = main.in_interior
	var barn_name: String = main.hud.world_label.text
	var barn_goal: Vector2 = IN.goal_of(barn.interior)
	player.global_position = barn_room.origin + barn_goal + Vector2(0, 100.0)
	await physics_frame
	player.global_position = barn_room.origin + barn_goal
	await physics_frame
	await physics_frame
	await physics_frame
	print("Walk into the barn: in_interior=%s (expected true), room '%s' (expected The Barn); its counter opens the racing menu: a town panel is open=%s (expected true)" % [barn_in, barn_name, main._any_town_panel_open()])
	main._close_open_town_panels()
	paused = false
	player.global_position = barn_room.origin + Vector2(barn_room.size.x * 0.5, barn_room.size.y - 100.0)
	await physics_frame
	player.global_position = barn_room.origin + Vector2(barn_room.size.x * 0.5, barn_room.size.y - IN.WALL * 0.5)
	await physics_frame
	await physics_frame
	await create_timer(1.6).timeout
	print("The doorway puts you back in the yard below the barn door: in_interior=%s (expected false), %.0f px from the spot below the door (expected 0)" % [main.in_interior, player.global_position.distance_to(barn.return)])
	quit()
