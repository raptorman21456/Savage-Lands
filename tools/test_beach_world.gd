extends SceneTree

# Beach (world 1): Leviathan is its full boss (wave 10); its wave-5 miniboss is a
# PLACEHOLDER (Lava Construct) until Beach gets one of its own. Validates the
# WORLDS-driven boss lookup end to end through the real _spawn_boss_wave.

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

	var leviathan_script = load("res://scripts/Leviathan.gd")

	# --- Data sanity ---
	print("Leviathan's ENEMY_TRAITS: is_boss_tier=%s is_miniboss=%s ignore_line=%s attack_range=%d (expected true, false, true, 2)" % [
		main.ENEMY_TRAITS.get("Leviathan", {}).get("is_boss_tier", false),
		main.ENEMY_TRAITS.get("Leviathan", {}).get("is_miniboss", false),
		main.ENEMY_TRAITS.get("Leviathan", {}).get("ignore_line", false),
		main.ENEMY_TRAITS.get("Leviathan", {}).get("attack_range", 1),
	])
	print("Leviathan carries a power_tier for the Nothingness rush: %s (expected 1.0)" % [leviathan_script.new().power_tier])
	print("HUD has an icon for Leviathan: %s (expected true)" % [main.hud.ENEMY_ICONS.get("Leviathan", null) != null])

	# --- Beach's wave-gated boss spawn end-to-end (through the real
	# _spawn_boss_wave, not a hand-built dict) ---
	main.wave = 15  # Beach, world-relative wave 5 -> miniboss slot
	main.current_world_index = main._world_index_for_wave(main.wave)
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await physics_frame
	main.enemies_alive = 0
	main._spawn_boss_wave()
	await physics_frame
	var mini_enemies: Array = main.get_tree().get_nodes_in_group("enemies")
	print("Beach's miniboss wave spawns a Lava Construct (placeholder): count=%d (expected 1), name=%s (expected Lava Construct)" % [
		mini_enemies.size(), mini_enemies[0].get_display_name() if mini_enemies.size() == 1 else "none"
	])
	var mini_ref = mini_enemies[0] if mini_enemies.size() == 1 else null
	for e in mini_enemies:
		e.set_physics_process(false)

	# --- Solo fight, big arena (is_boss_tier flows through _gather_squad /
	# _setup_battle_grid) -- checked here, before the next wave's cleanup
	# queue_frees this reference. ---
	if mini_ref != null:
		var mini_squad: Array = main._gather_squad(mini_ref)
		print("Miniboss fights are solo, no escorts gathered: squad_size=%d (expected 1)" % [mini_squad.size()])
		main._setup_battle_grid(mini_squad)
		print("Miniboss fight sets up on the bigger 15x15 arena: w=%d h=%d (expected 15, 15)" % [main.BATTLE_GRID_W, main.BATTLE_GRID_H])

	main.wave = 20  # Beach, world-relative wave 10 -> full boss
	main.current_world_index = main._world_index_for_wave(main.wave)
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await physics_frame
	main.enemies_alive = 0
	main._spawn_boss_wave()
	await physics_frame
	var full_enemies: Array = main.get_tree().get_nodes_in_group("enemies")
	print("Beach's world-ending wave spawns a Leviathan: count=%d (expected 1), name=%s (expected Leviathan)" % [
		full_enemies.size(), full_enemies[0].get_display_name() if full_enemies.size() == 1 else "none"
	])
	var boss_ref = full_enemies[0] if full_enemies.size() == 1 else null
	for e in full_enemies:
		e.set_physics_process(false)

	if boss_ref != null:
		var squad2: Array = main._gather_squad(boss_ref)
		print("Leviathan fights are solo: squad_size=%d (expected 1)" % [squad2.size()])
		main._setup_battle_grid(squad2)
		print("Leviathan fight gets the 15x15 arena: w=%d h=%d (expected 15, 15)" % [main.BATTLE_GRID_W, main.BATTLE_GRID_H])

	# --- A sweeping boss's attack hits the player and an adjacent ally (Elder Oak here,
	# since the Leviathan itself reaches rather than sweeps) ---
	main.battle_player_tile = Vector2i(5, 5)
	main.battle_allies = [{"ref": null, "tile": Vector2i(6, 6), "hp": 50, "max_hp": 50, "name": "Knight"}]
	var sweeper := {
		"ref": null, "tile": Vector2i(5, 6), "hp": 999, "max_hp": 999, "move_range": 1,
		"damage": 10, "name": "Elder Oak", "winding_up": false, "stunned": false, "size": 1,
		"attack_range": 1, "concussed_turns": 0, "frozen_turns": 0, "burning": false,
		"armored": true, "disarmed_tile": Vector2i(-1, -1),
	}
	var swept: Array = main._sweep_targets(sweeper)
	print("A sweep catches both the player and the adjacent ally: %s (expected true)" % [
		Vector2i(5, 5) in swept and Vector2i(6, 6) in swept
	])

	quit()
