extends SceneTree

# The regional overworld as Main.gd runs it: where you wake, what spawns where, danger tiers, boss landmarks,
# scenery streaming, the HUD that follows you.

const WM := preload("res://scripts/WorldMap.gd")
const RM := preload("res://scripts/Rooms.gd")

func _names(nodes: Array) -> Array:
	var out := []
	for n in nodes:
		out.append(n.get_display_name())
	return out

func _clear_enemies(main) -> void:
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.free()
	main.enemies_alive = 0

func _init() -> void:
	seed(20261015)
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player

	# --- waking up
	print("The regional world is the default: %s (expected true)" % [main.regional_world])
	print("You wake at the woods' edge: %s (expected %s), region %s (expected woods_edge)" % [player.global_position, WM.spawn_position(), main.current_region_id])
	print("...so the battle backdrop is the forest's: world %s (expected forest)" % [main.WORLDS[main.current_world_index].id])
	print("The label shows where you are, not a wave: '%s' (expected Central Lexia), danger pips lit: %d (expected 1)" % [main.hud.world_label.text, main.hud.danger_pips.filter(func(p): return p.color.g > 0.5 and p.color.r < 0.9 and p.color.a > 0.95).size()])
	var spawn_room: Dictionary = RM.room_at(player.global_position)
	print("You wake in the room '%s' (expected Where You Woke), and it is the room the game says you are in: %s (expected %s)" % [spawn_room.name, main.current_room_id, spawn_room.id])
	print("...the HUD names it under the region: '%s' (expected Where You Woke), and the room was announced: visited=%s (expected true)" % [main.hud.room_label.text, main.visited_rooms.has(spawn_room.id)])
	var built: Array = main.overworld_map.loaded_room_ids()
	built.sort()
	print("The room you wake in and the ones within reach are built: %d rooms %s (expected 6: the spawn room, its west, north and south neighbours, and the two corners west)" % [built.size(), built])
	var group_enemies: Array = main.get_tree().get_nodes_in_group("enemies")
	print("Each nearby room has its own roaming enemies: %d (expected 10-35), none within %d px of you: %s (expected true)" % [group_enemies.size(), int(main.ROOM_SPAWN_MIN), group_enemies.all(func(e): return e.global_position.distance_to(player.global_position) >= main.ROOM_SPAWN_MIN - 1.0)])
	print("...every one stands in a room that has wild enemies (not the sea, not a safe room): %s (expected true)" % [group_enemies.all(func(e): return RM.room_at(e.global_position).target > 0)])
	var per_room_ok := true
	for r in RM.rooms_near(player.global_position, main.ROOM_ACTIVE_MARGIN):
		if int(r.target) > 0 and main._enemies_in_room(r) < int(r.target):
			per_room_ok = false
	print("...and every room within reach has at least as many as it should: %s (expected true)" % [per_room_ok])

	# --- the map follows you
	var tests := {
		"heartwood_grove": WM.landmark("heartwood").pos + Vector2(0, 900),
		"desert": Vector2(0.93, 0.2) * WM.SIZE,
		"crater": WM.landmark("crater").pos + Vector2(0, 400),
		"frozen_wastes": Vector2(0.55, 0.9) * WM.SIZE,
		"voidlands": Vector2(0.9, 0.9) * WM.SIZE,
		"swamp": Vector2(0.1, 0.65) * WM.SIZE,
	}
	var worlds := {"heartwood_grove": "forest", "desert": "desert", "crater": "volcano", "frozen_wastes": "tundra", "voidlands": "voidlands", "swamp": "swamp"}
	for region_id in tests:
		player.global_position = tests[region_id]
		main._track_player_region()
		print("Walking into %s: region %s, battle world %s (expected %s)" % [region_id, main.current_region_id, main.WORLDS[main.current_world_index].id, worlds[region_id]])
	player.global_position = WM.landmark("pesca").pos
	main._track_player_region()
	print("In Pesca the danger pips go dark... the label says '%s' (expected Pesca), tier of the ground %d (expected 1)" % [main.hud.world_label.text, int(WM.region_at(player.global_position).tier)])

	# --- the town stays safe
	player.global_position = WM.SIZE / 2.0
	main._track_player_region()
	var bad_spot := 0
	for i in 200:
		var spot: Dictionary = main._regional_spawn_spot()
		if spot.is_empty():
			continue
		if main._in_protected_zone(spot.pos, 150.0) or not spot.region.walkable or spot.table.is_empty() or spot.room.target <= 0 or spot.room.kind in ["safe", "sea"]:
			bad_spot += 1
	print("Spawn spots (200 tries from the town) are never in the town, water or a safe room: bad=%d (expected 0)" % [bad_spot])

	# --- tiers scale the enemy and its reward
	_clear_enemies(main)
	var easy = main._spawn_one_enemy(main.EnemyScript, Vector2(0.37, 0.35) * WM.SIZE)
	var hard = main._spawn_one_enemy(main.EnemyScript, Vector2(0.9, 0.9) * WM.SIZE)
	print("Each roaming enemy carries its ground's danger: easy tier %d x%.2f (expected 1 x1.00), Voidlands tier %d x%.2f (expected 8 x4.20)" % [easy.get_meta("region_tier"), easy.get_meta("region_tier_power"), hard.get_meta("region_tier"), hard.get_meta("region_tier_power")])
	player.xp = 0
	player.level = 1
	player.xp_to_next = 99999  # far from a level-up, so the xp gained reads straight off
	var xp_before: int = player.xp
	easy.died.emit(20)
	var easy_xp: int = player.xp - xp_before
	player.xp = 0
	player.level = 1
	player.xp_to_next = 99999
	hard.died.emit(20)
	var hard_xp: int = player.xp
	print("...and the harder ground pays more: %d xp on easy ground, %d in the Voidlands (expected 20 then 41: x sqrt(4.2))" % [easy_xp, hard_xp])

	# --- letting go of what you left behind
	_clear_enemies(main)
	player.global_position = Vector2(0.37, 0.35) * WM.SIZE
	var near = main._spawn_one_enemy(main.EnemyScript, player.global_position + Vector2(500, 0))
	var far = main._spawn_one_enemy(main.EnemyScript, player.global_position + Vector2(main.DESPAWN_DISTANCE + 400.0, 0))
	main._release_far_enemies()
	await process_frame
	print("Enemies you have left far behind are let go (not killed): near alive=%s (expected true), far alive=%s (expected false), count=%d (expected 1)" % [is_instance_valid(near) and not near.is_queued_for_deletion(), is_instance_valid(far) and not far.is_queued_for_deletion(), main.enemies_alive])
	main._fill_ambient_population(99)
	var refilled := true
	for r in RM.rooms_near(player.global_position, main.ROOM_ACTIVE_MARGIN):
		if int(r.target) > 0 and main._enemies_in_room(r) < int(r.target):
			refilled = false
	print("...and the rooms near you are topped back up: every room has its share again: %s (expected true), %d enemies near you (expected 8-35)" % [refilled, main._enemies_near(player.global_position, 3500.0)])
	_clear_enemies(main)
	main._fill_ambient_population(2)
	print("A top-up adds only a few at a time (limit 2): %d (expected 2-6, clusters may overshoot)" % [main.get_tree().get_nodes_in_group("enemies").size()])

	# --- bosses stand on their landmarks
	_clear_enemies(main)
	main.landmark_bosses.clear()
	main.defeated_landmark_bosses.clear()
	var heart: Dictionary = WM.landmark("heartwood")
	player.global_position = heart.pos + Vector2(0, 2000)
	main._update_landmark_bosses()
	var elder = main.landmark_bosses.get("heartwood")
	print("Come near the HeartWood and the Elder Oak waits there: %s (expected Elder Oak), at the tree: %s (expected true), asleep: %s (expected true)" % [elder.get_display_name() if elder != null else "none", elder != null and elder.global_position.distance_to(heart.pos) < 1000.0, elder != null and not elder.is_physics_processing()])
	print("...only that one: bosses standing: %d (expected 1)" % [main.landmark_bosses.size()])
	player.global_position = heart.pos + Vector2(0, 700)
	main._update_landmark_bosses()
	print("Walk right up and it wakes: %s (expected true)" % [elder.is_physics_processing()])
	elder.died.emit(100)
	print("Beat it and the landmark is cleared for the run: %s (expected true)" % [main.defeated_landmark_bosses.has("heartwood")])
	elder.queue_free()
	await process_frame
	main._update_landmark_bosses()
	print("...it does not come back: bosses standing %d (expected 1, just the dead node's slot), new Elder Oak spawned: %s (expected false)" % [main.landmark_bosses.size(), main.landmark_bosses.get("heartwood") != null and is_instance_valid(main.landmark_bosses.get("heartwood")) and not main.landmark_bosses.get("heartwood").is_queued_for_deletion()])
	var six := 0
	for l in WM.landmarks:
		if l.boss != "":
			six += 1
			if not main.LANDMARK_BOSS_SCRIPTS.has(l.boss):
				six -= 100
	print("Every boss landmark has a boss script: %d (expected 6)" % [six])
	var minis_ok := true
	for r in WM.regions:
		if r.miniboss != "" and not main.MINIBOSS_SCRIPTS.has(r.miniboss):
			minis_ok = false
	var enemies_ok := true
	for r in WM.regions:
		for entry in r.enemies:
			if not main.REGION_ENEMY_SCRIPTS.has(entry[0]):
				enemies_ok = false
	print("Every miniboss and every enemy a region names exists: %s, %s (expected true, true)" % [minis_ok, enemies_ok])

	# --- rooms are built as you come near, and let go when you leave
	var overworld = main.overworld_map
	player.global_position = Vector2(0.6, 0.3) * WM.SIZE
	overworld.update_rooms(player.global_position)
	var room_here: Dictionary = RM.room_at(player.global_position)
	print("The room you step into is built at once: complete=%s (expected true); the ones around it wait their turn: %d pending (expected > 0)" % [overworld.is_room_complete(room_here.id), overworld.pending_room_count()])
	var frames := 0
	while overworld.pending_room_count() > 0 and frames < 300:
		await process_frame
		frames += 1
	print("...and they are built one after another over a few frames: %d frames (expected 1-120), nothing left pending: %s (expected true)" % [frames, overworld.pending_room_count() == 0])
	var children_here: int = overworld.scenery_count(room_here.id)
	player.global_position = Vector2(0.3, 0.6) * WM.SIZE
	overworld.update_rooms(player.global_position)
	overworld.flush()
	await process_frame
	print("A room you have left far behind is let go: loaded=%s (expected false)" % [overworld.is_room_loaded(room_here.id)])
	player.global_position = Vector2(0.6, 0.3) * WM.SIZE
	overworld.update_rooms(player.global_position)
	overworld.flush()
	await process_frame
	var children_again: int = overworld.scenery_count(room_here.id)
	print("A room you leave and come back to has exactly the same scenery: %d then %d (expected equal and > 0), rooms loaded %d (expected 1-9)" % [children_here, children_again, overworld.loaded_room_count()])

	# --- crossing from one room to the next
	_clear_enemies(main)
	var crossing: Dictionary = {}
	for r in RM.rooms:
		if r.kind != "wild" or r.land < 0.99 or not r.landmarks.is_empty():
			continue
		for ex in RM.exits(r):
			var beyond: Dictionary = RM.room_at(Vector2(ex.pos) - Vector2(ex.n) * 10.0)
			if ex.side == "e" and beyond.kind == "wild" and beyond.land >= 0.99 and beyond.landmarks.is_empty():
				crossing = {"room": r, "other": beyond, "exit": ex}
				break
		if not crossing.is_empty():
			break
	var ex: Dictionary = crossing.exit
	player.global_position = Vector2(ex.pos) + Vector2(ex.n) * 700.0
	main._track_player_room()
	overworld.update_rooms(player.global_position)
	var first_room: String = main.current_room_id
	overworld.flush()
	print("Walk toward a doorway: the room beyond is already built before you reach it: %s (expected true), you are in %s (expected %s)" % [overworld.is_room_loaded(crossing.other.id), first_room, crossing.room.id])
	player.global_position = Vector2(ex.pos) - Vector2(ex.n) * 60.0
	main._track_player_room()
	overworld.update_rooms(player.global_position)
	print("Cross it: you are in the next room at once, no loading: %s (expected %s), the HUD shows its name '%s' (expected '%s', blank when it has none), it counts as visited: %s (expected true)" % [main.current_room_id, crossing.other.id, main.hud.room_label.text, crossing.other.name, main.visited_rooms.has(crossing.other.id)])
	overworld.flush()
	print("...and the room you left is still built behind you: %s (expected true)" % [overworld.is_room_loaded(crossing.room.id)])

	# Solid ground: a wall of trees, rock or water follows the outline of a room's floor, with the doorways open.
	var shaped: Dictionary = {}
	for r in RM.rooms:
		if r.kind == "wild" and r.land >= 0.99 and r.mass != "" and RM.layout(r).segments().size() >= 40 and RM.layout(r).floor_fraction < 0.75:
			shaped = r
			break
	var layout = RM.layout(shaped)
	overworld.update_rooms(shaped.rect.get_center())
	overworld.flush()
	var segs: PackedVector2Array = layout.segments()
	var wall_mid := Vector2.ZERO
	var toward_floor := Vector2.ZERO
	for k in range(0, segs.size() - 1, 2):
		var a: Vector2 = segs[k]
		var b: Vector2 = segs[k + 1]
		var m: Vector2 = (a + b) * 0.5
		var tangent: Vector2 = (b - a).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		if a.distance_to(b) < 30.0 or not shaped.rect.grow(-400.0).has_point(m):
			continue
		for sign_n in [1.0, -1.0]:
			if layout.sample(m + normal * sign_n * 60.0) > 30.0 and layout.sample(m - normal * sign_n * 60.0) < -30.0:
				wall_mid = m
				toward_floor = normal * sign_n
		if wall_mid != Vector2.ZERO:
			break
	player.global_position = wall_mid + toward_floor * 50.0
	_clear_enemies(main)
	await physics_frame
	await physics_frame
	print("Room '%s' (%s, solid ground: %s): the wall at the edge of the floor refuses a step into it: %s (expected true)" % [shaped.id, shaped.layout, shaped.mass, player.test_move(player.global_transform, -toward_floor * 120.0)])
	print("...while a step along the floor is free: %s (expected true)" % [not player.test_move(player.global_transform, toward_floor * 30.0)])
	var door: Dictionary = RM.exits(shaped)[0]
	player.global_position = Vector2(door.pos) + Vector2(door.n) * 150.0
	await physics_frame
	await physics_frame
	print("...and the doorway '%s' is open: walking straight out through it is free: %s (expected true)" % [door.side, not player.test_move(player.global_transform, -Vector2(door.n) * 260.0)])

	# --- a room's own enemies
	var den: Dictionary = {}
	for r in RM.rooms:
		if r.kind == "wild" and r.land > 0.99 and not r.enemies.is_empty() and r.landmarks.is_empty() and WM.region(r.region).miniboss == "":
			den = r
			break
	if not den.is_empty():
		_clear_enemies(main)
		player.global_position = den.rect.get_center()
		main.in_battle = false
		overworld.update_rooms(player.global_position)
		main._track_player_room()
		main._fill_ambient_population(99)
		var keys := []
		for entry in den.enemies:
			keys.append(str(entry[0]))
		var allowed_names := []
		for k in keys:
			var probe_enemy = main.REGION_ENEMY_SCRIPTS[k].new()
			allowed_names.append(probe_enemy.get_display_name())
			probe_enemy.free()
		var inside := []
		for e in main.get_tree().get_nodes_in_group("enemies"):
			if den.rect.has_point(e.global_position):
				inside.append(e.get_display_name())
		var strangers := inside.filter(func(n): return not (n in allowed_names))
		print("'%s' has its own residents (%s): %d inside, outsiders=%s (expected [] and at least %d inside)" % [den.name, allowed_names, inside.size(), strangers, int(den.target)])
	else:
		print("(no room with its own enemy table found)")

	# --- the sea blocks the way
	var water: Node = main.overworld_map.get_node("DeepWater")
	print("The deep water is solid: %d collision piece(s) (expected 1)" % [water.get_child_count()])
	# Walk south down the beach until the next 120 px would be water, then try to step in.
	var probe := Vector2(0.20, 0.70) * WM.SIZE
	while not WM.is_blocked(probe + Vector2(0, 160)) and probe.y < WM.SIZE.y - 400.0:
		probe.y += 40.0
	player.global_position = probe
	await physics_frame
	await physics_frame
	print("The player cannot wade into the sea: standing at the shore (blocked ahead=%s, expected true), a step south is refused: %s (expected true), a step back north is free: %s (expected true)" % [WM.is_blocked(probe + Vector2(0, 160)), player.test_move(player.global_transform, Vector2(0, 160)), not player.test_move(player.global_transform, Vector2(0, -160))])
	player.global_position = WM.landmark("pesca").pos
	await physics_frame
	await physics_frame
	print("...but Pesca's headland is solid ground out in the water: a step around the dock is free: %s (expected true)" % [not player.test_move(player.global_transform, Vector2(20, 0))])
	print("Every region and landmark ring can be triangulated for drawing (no broken polygons): %s (expected true)" % [(func():
		for r in WM.regions:
			if Geometry2D.triangulate_polygon(r.polygon).is_empty():
				return false
		return true).call()])

	# --- the HUD
	main.hud.show_message("Hello")
	print("A message shows in a toast near the bottom of the screen: visible=%s (expected true), text=%s (expected Hello)" % [main.hud.message_toast.visible, main.hud.message_label.text])
	main.hud.update_minimap(Vector2(100, 100))
	print("The minimap follows you: %s (expected (100, 100))" % [main.hud.minimap.player_pos])
	main.hud.set_danger(8)
	print("Danger pips: all %d lit at tier 8: %s (expected true); none at tier 0: %s (expected true)" % [main.hud.danger_pips.size(), main.hud.danger_pips.all(func(p): return p.visible and p.color.a > 0.95 and p.color.r > 0.1 and (p.color.r + p.color.g) > 0.5), (func():
		main.hud.set_danger(0)
		return main.hud.danger_pips.all(func(p): return not p.visible)).call()])

	# --- the wave counter no longer swaps the world
	var world_before: int = main.current_world_index
	main.wave = 31
	main._advance_wave_tier()
	print("A new wave does not change the ground you stand on: world %d -> %d (expected the same)" % [world_before, main.current_world_index])
	quit()
