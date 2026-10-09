extends SceneTree

# Batch B worlds (World Progression feature): Caves, Tundra and Mountains -- same
# end-to-end shape as test_batch_a_worlds.gd. Only Tundra's White Dragon is native; every
# other enemy here is a PLACEHOLDER reuse of a surviving miniboss/boss until these worlds
# get their own (Caves: Lava Construct / Elder Oak, Tundra: Black Dragonlet / White Dragon,
# Mountains: Voidwing / White Dragon).

func _check_world(main, wave_mini: int, wave_boss: int, world_name: String, mini_name: String, boss_name: String) -> void:
	main.wave = wave_mini
	main.current_world_index = main._world_index_for_wave(main.wave)
	print("wave %d resolves to %s: %s (expected %s)" % [wave_mini, world_name, main.WORLDS[main.current_world_index].name, world_name])
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await physics_frame
	main.enemies_alive = 0
	main._spawn_boss_wave()
	await physics_frame
	var mini_enemies: Array = main.get_tree().get_nodes_in_group("enemies")
	print("%s's miniboss wave spawns a %s: count=%d (expected 1), name=%s (expected %s)" % [
		world_name, mini_name, mini_enemies.size(), mini_enemies[0].get_display_name() if mini_enemies.size() == 1 else "none", mini_name
	])
	var mini_ref = mini_enemies[0] if mini_enemies.size() == 1 else null
	for e in mini_enemies:
		e.set_physics_process(false)
	if mini_ref != null:
		var squad: Array = main._gather_squad(mini_ref)
		main._setup_battle_grid(squad)
		print("...%s fights solo, big arena: squad_size=%d w=%d h=%d (expected 1, 15, 15)" % [mini_name, squad.size(), main.BATTLE_GRID_W, main.BATTLE_GRID_H])

	main.wave = wave_boss
	main.current_world_index = main._world_index_for_wave(main.wave)
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await physics_frame
	main.enemies_alive = 0
	main._spawn_boss_wave()
	await physics_frame
	var full_enemies: Array = main.get_tree().get_nodes_in_group("enemies")
	print("%s's world-ending wave spawns a %s: count=%d (expected 1), name=%s (expected %s)" % [
		world_name, boss_name, full_enemies.size(), full_enemies[0].get_display_name() if full_enemies.size() == 1 else "none", boss_name
	])
	for e in full_enemies:
		e.set_physics_process(false)

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	main.regional_world = false  # this test drives the old wave-ladder world
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	# --- Data sanity ---
	var names := ["Lava Construct", "Elder Oak", "Black Dragonlet", "White Dragon", "Voidwing"]
	var all_boss_tier := true
	var all_have_icons := true
	for n in names:
		if not main.ENEMY_TRAITS.get(n, {}).get("is_boss_tier", false):
			all_boss_tier = false
		if main.hud.ENEMY_ICONS.get(n, null) == null:
			all_have_icons = false
	print("All 5 Batch B enemies are is_boss_tier: %s (expected true)" % [all_boss_tier])
	print("All 5 Batch B enemies have HUD icons: %s (expected true)" % [all_have_icons])

	# --- Distinguishing mechanics ---
	print("Lava Construct lumbers: knockback_resist=%.2f armored=%s (expected 0.65, true)" % [
		main.ENEMY_TRAITS["Lava Construct"].knockback_resist, main.ENEMY_TRAITS["Lava Construct"].armored
	])
	print("White Dragon breathes a sweeping attack: sweeps=%s (expected true)" % [main.ENEMY_TRAITS["White Dragon"].sweeps])
	print("Voidwing is fast, evasive and ranged: move_range=%d dodge_chance=%.1f attack_range=%d (expected 3, 0.3, 2)" % [
		main.ENEMY_TRAITS["Voidwing"].move_range, main.ENEMY_TRAITS["Voidwing"].dodge_chance, main.ENEMY_TRAITS["Voidwing"].attack_range
	])

	# --- End-to-end per world ---
	await _check_world(main, 55, 60, "Caves", "Lava Construct", "Elder Oak")
	await _check_world(main, 65, 70, "Tundra", "Black Dragonlet", "White Dragon")
	await _check_world(main, 75, 80, "Mountains", "Voidwing", "White Dragon")

	quit()
