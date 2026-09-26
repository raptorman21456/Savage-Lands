extends SceneTree

# Batch A worlds (World Progression feature): Swamp (Lizard Soldier Swarm /
# Black Dragonlet), Forest (Treant / Elder Oak), Desert (Gibbering Mouther /
# Iron Golem) -- same end-to-end shape as test_beach_world.gd, run for all 3
# worlds in one file since the pattern is now fully proven.

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
		print("...%s fights solo, big arena: squad_size=%d w=%d h=%d (expected 1, 15, 15)" % [mini_name, squad.size(), main.BATTLE_GRID_W, main.BATTLE_GRID_H])
		main._setup_battle_grid(squad)
		print("...arena confirmed: w=%d h=%d (expected 15, 15)" % [main.BATTLE_GRID_W, main.BATTLE_GRID_H])

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
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	# --- Data sanity: ENEMY_TRAITS + HUD icons for all 6 new enemies ---
	var names := ["Lizard Soldier Swarm", "Black Dragonlet", "Treant", "Elder Oak", "Gibbering Mouther", "Iron Golem"]
	var all_boss_tier := true
	var all_have_icons := true
	for n in names:
		if not main.ENEMY_TRAITS.get(n, {}).get("is_boss_tier", false):
			all_boss_tier = false
		if main.hud.ENEMY_ICONS.get(n, null) == null:
			all_have_icons = false
	print("All 6 Batch A enemies are is_boss_tier: %s (expected true)" % [all_boss_tier])
	print("All 6 Batch A enemies have HUD icons: %s (expected true)" % [all_have_icons])

	# --- Distinguishing mechanics ---
	print("Lizard Soldier Swarm is fast with frequent quick jabs: move_range=%d quick_jab_chance=%.1f (expected 2, 0.5)" % [
		main.ENEMY_TRAITS["Lizard Soldier Swarm"].move_range, main.ENEMY_TRAITS["Lizard Soldier Swarm"].quick_jab_chance
	])
	print("Black Dragonlet breathes a sweeping attack: sweeps=%s (expected true)" % [main.ENEMY_TRAITS["Black Dragonlet"].sweeps])
	print("Treant resists being shoved: knockback_resist=%.2f (expected 0.85)" % [main.ENEMY_TRAITS["Treant"].knockback_resist])
	print("Elder Oak sweeps too, tankier than Treant: sweeps=%s hp=%d>%d (expected true, true)" % [
		main.ENEMY_TRAITS["Elder Oak"].sweeps, main.ElderOakScript.MAX_HEALTH, main.TreantScript.MAX_HEALTH
	])
	print("Gibbering Mouther is erratic: dodge_chance=%.2f ignore_line=%s (expected 0.25, true)" % [
		main.ENEMY_TRAITS["Gibbering Mouther"].dodge_chance, main.ENEMY_TRAITS["Gibbering Mouther"].ignore_line
	])
	print("Iron Golem is immovable: knockback_resist=%.1f (expected 1.0)" % [main.ENEMY_TRAITS["Iron Golem"].knockback_resist])

	# --- End-to-end per world ---
	await _check_world(main, 25, 30, "Swamp", "Lizard Soldier Swarm", "Black Dragonlet")
	await _check_world(main, 35, 40, "Forest", "Treant", "Elder Oak")
	await _check_world(main, 45, 50, "Desert", "Gibbering Mouther", "Iron Golem")

	quit()
