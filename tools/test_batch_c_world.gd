extends SceneTree

# Batch C world (World Progression feature): Volcano (Lava Golem / Red
# Wyrm) -- same end-to-end shape as test_batch_a_worlds.gd /
# test_batch_b_worlds.gd, run for the single remaining "normal enemy
# archetype" world before Voidlands (which needs the extra power_tier
# scaling hook).

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
	var names := ["Lava Golem", "Red Wyrm"]
	var all_boss_tier := true
	var all_have_icons := true
	for n in names:
		if not main.ENEMY_TRAITS.get(n, {}).get("is_boss_tier", false):
			all_boss_tier = false
		if main.hud.ENEMY_ICONS.get(n, null) == null:
			all_have_icons = false
	print("Both Volcano enemies are is_boss_tier: %s (expected true)" % [all_boss_tier])
	print("Both Volcano enemies have HUD icons: %s (expected true)" % [all_have_icons])
	print("Red Wyrm is tankier than Lava Golem (elder dragon > golem): wyrm_hp=%d > golem_hp=%d (expected true)" % [
		main.RedWyrmScript.MAX_HEALTH, main.LavaGolemScript.MAX_HEALTH
	])
	print("Red Wyrm's breath reaches as wide as Beholder/Blue Dragon's: attack_range=%d sweeps=%s (expected 2, true)" % [
		main.ENEMY_TRAITS["Red Wyrm"].attack_range, main.ENEMY_TRAITS["Red Wyrm"].sweeps
	])
	print("Red Wyrm is the tankiest dragon across all 4 worlds: wyrm=%d >= black=%d, white=%d, blue=%d (expected true)" % [
		main.RedWyrmScript.MAX_HEALTH, main.BlackDragonletScript.MAX_HEALTH, main.WhiteDragonScript.MAX_HEALTH, main.BlueDragonScript.MAX_HEALTH
	])

	# --- End-to-end ---
	main.wave = 85
	main.current_world_index = main._world_index_for_wave(main.wave)
	print("wave 85 resolves to Volcano: %s (expected Volcano)" % [main.WORLDS[main.current_world_index].name])
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await physics_frame
	main.enemies_alive = 0
	main._spawn_boss_wave()
	await physics_frame
	var mini_enemies: Array = main.get_tree().get_nodes_in_group("enemies")
	print("Volcano's miniboss wave spawns a Lava Golem: count=%d (expected 1), name=%s (expected Lava Golem)" % [
		mini_enemies.size(), mini_enemies[0].get_display_name() if mini_enemies.size() == 1 else "none"
	])
	var mini_ref = mini_enemies[0] if mini_enemies.size() == 1 else null
	for e in mini_enemies:
		e.set_physics_process(false)
	if mini_ref != null:
		var squad: Array = main._gather_squad(mini_ref)
		main._setup_battle_grid(squad)
		print("...Lava Golem fights solo, big arena: squad_size=%d w=%d h=%d (expected 1, 15, 15)" % [squad.size(), main.BATTLE_GRID_W, main.BATTLE_GRID_H])

	main.wave = 90
	main.current_world_index = main._world_index_for_wave(main.wave)
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await physics_frame
	main.enemies_alive = 0
	main._spawn_boss_wave()
	await physics_frame
	var full_enemies: Array = main.get_tree().get_nodes_in_group("enemies")
	print("Volcano's world-ending wave spawns a Red Wyrm: count=%d (expected 1), name=%s (expected Red Wyrm)" % [
		full_enemies.size(), full_enemies[0].get_display_name() if full_enemies.size() == 1 else "none"
	])
	for e in full_enemies:
		e.set_physics_process(false)

	quit()
