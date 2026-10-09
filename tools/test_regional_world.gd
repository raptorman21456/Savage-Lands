extends SceneTree

# The regional overworld as Main.gd runs it: where you wake, what spawns where, danger tiers, boss landmarks,
# scenery streaming, the HUD that follows you.

const WM := preload("res://scripts/WorldMap.gd")

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
	print("Scenery is streamed around you: %d chunks (expected 25)" % [main.overworld_map.loaded_chunk_count()])
	var group_enemies: Array = main.get_tree().get_nodes_in_group("enemies")
	print("A ring of enemies waits nearby: %d (expected 12), none on top of you: %s (expected true)" % [group_enemies.size(), group_enemies.all(func(e): return e.global_position.distance_to(player.global_position) >= main.SPAWN_RING_MIN - 1.0)])
	var allowed := ["Goblin", "Wolf", "Gnome", "Orc", "Traitor Wolf"]
	print("...and only what lives in the woods' edge: %s (expected all in %s)" % [_names(group_enemies).filter(func(n): return not (n in allowed)), allowed])

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
		if main._in_protected_zone(spot.pos, 150.0) or not spot.region.walkable or spot.region.enemies.is_empty():
			bad_spot += 1
	print("Spawn spots (200 tries from the town) are never in the town, water or a safe region: bad=%d (expected 0)" % [bad_spot])

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
	main._fill_ambient_population(main.AMBIENT_TARGET)
	print("...and the ring is topped back up: %d near you (expected about 12)" % [main._enemies_near(player.global_position, main.AMBIENT_RADIUS)])

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

	# --- scenery is the same every time
	var chunk_a: int = main.overworld_map.get_child_count()
	player.global_position = Vector2(0.6, 0.3) * WM.SIZE
	main.overworld_map.update_chunks(player.global_position)
	var children_here: int = main.overworld_map._chunks[Vector2i(int(player.global_position.x / 1024.0), int(player.global_position.y / 1024.0))].get_child_count()
	player.global_position = Vector2(0.3, 0.3) * WM.SIZE
	main.overworld_map.update_chunks(player.global_position)
	player.global_position = Vector2(0.6, 0.3) * WM.SIZE
	main.overworld_map.update_chunks(player.global_position)
	await process_frame
	var children_again: int = main.overworld_map._chunks[Vector2i(int(player.global_position.x / 1024.0), int(player.global_position.y / 1024.0))].get_child_count()
	print("A chunk you leave and come back to has exactly the same scenery: %d then %d (expected equal and > 0), chunks loaded %d (expected 25)" % [children_here, children_again, main.overworld_map.loaded_chunk_count()])

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
