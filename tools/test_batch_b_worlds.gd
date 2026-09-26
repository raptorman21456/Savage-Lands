extends SceneTree

# Batch B worlds (World Progression feature): Caves (Stone Giant / Beholder),
# Tundra (Frost Giant / White Dragon), Mountains (Roc / Blue Dragon) -- same
# end-to-end shape as test_batch_a_worlds.gd.

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
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	# --- Data sanity ---
	var names := ["Stone Giant", "Beholder", "Frost Giant", "White Dragon", "Roc", "Blue Dragon"]
	var all_boss_tier := true
	var all_have_icons := true
	for n in names:
		if not main.ENEMY_TRAITS.get(n, {}).get("is_boss_tier", false):
			all_boss_tier = false
		if main.hud.ENEMY_ICONS.get(n, null) == null:
			all_have_icons = false
	print("All 6 Batch B enemies are is_boss_tier: %s (expected true)" % [all_boss_tier])
	print("All 6 Batch B enemies have HUD icons: %s (expected true)" % [all_have_icons])

	# --- Distinguishing mechanics ---
	print("Stone Giant is a literal 2x2 giant: size=%d (expected 2)" % [main.ENEMY_TRAITS["Stone Giant"].size])
	print("Beholder's sweep reaches further than a melee dragon's: attack_range=%d sweeps=%s (expected 2, true)" % [
		main.ENEMY_TRAITS["Beholder"].attack_range, main.ENEMY_TRAITS["Beholder"].sweeps
	])
	print("Frost Giant jabs frequently on top of its armor: quick_jab_chance=%.1f armored=%s (expected 0.3, true)" % [
		main.ENEMY_TRAITS["Frost Giant"].quick_jab_chance, main.ENEMY_TRAITS["Frost Giant"].armored
	])
	print("White Dragon breathes a sweeping attack: sweeps=%s (expected true)" % [main.ENEMY_TRAITS["White Dragon"].sweeps])
	print("Roc is fast and evasive: move_range=%d dodge_chance=%.1f (expected 3, 0.2)" % [
		main.ENEMY_TRAITS["Roc"].move_range, main.ENEMY_TRAITS["Roc"].dodge_chance
	])
	print("Blue Dragon's breath reaches as far as Beholder's eye rays: attack_range=%d sweeps=%s (expected 2, true)" % [
		main.ENEMY_TRAITS["Blue Dragon"].attack_range, main.ENEMY_TRAITS["Blue Dragon"].sweeps
	])

	# --- End-to-end per world ---
	await _check_world(main, 55, 60, "Caves", "Stone Giant", "Beholder")
	await _check_world(main, 65, 70, "Tundra", "Frost Giant", "White Dragon")
	await _check_world(main, 75, 80, "Mountains", "Roc", "Blue Dragon")

	# --- Stone Giant seats as a real 2x2 footprint (mirrors test_owlbear.gd's
	# footprint check, confirming "size" flows through _setup_battle_grid the
	# same way for a NEW boss as it already does for Owlbear/Brute). ---
	main.wave = 55
	main.current_world_index = main._world_index_for_wave(main.wave)
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await physics_frame
	main.enemies_alive = 0
	main._spawn_boss_wave()
	await physics_frame
	var giants: Array = main.get_tree().get_nodes_in_group("enemies")
	if giants.size() == 1:
		main._setup_battle_grid([giants[0]])
		var u: Dictionary = main.battle_units[0]
		var footprint: Array = main._footprint(u.tile, u.size)
		print("Stone Giant is placed as a real 2x2 footprint: size=%d (expected 2), footprint_cell_count=%d (expected 4)" % [u.size, footprint.size()])
	for e in giants:
		e.set_physics_process(false)

	quit()
