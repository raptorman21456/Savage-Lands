extends SceneTree

# Beach (world 1) proof-of-concept: Aboleth (miniboss) and Water Elemental
# (world-ending boss) -- the first world beyond Plains to get real content,
# validating the WORLDS-driven boss lookup end to end before the remaining
# 7 worlds are batched in.

func _init() -> void:
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	var aboleth_script = load("res://scripts/Aboleth.gd")
	var water_elemental_script = load("res://scripts/WaterElemental.gd")

	# --- Data sanity ---
	print("Aboleth's ENEMY_TRAITS: is_boss_tier=%s ignore_line=%s attack_range=%d (expected true, true, 2)" % [
		main.ENEMY_TRAITS.get("Aboleth", {}).get("is_boss_tier", false),
		main.ENEMY_TRAITS.get("Aboleth", {}).get("ignore_line", false),
		main.ENEMY_TRAITS.get("Aboleth", {}).get("attack_range", 1),
	])
	print("Water Elemental's ENEMY_TRAITS: is_boss_tier=%s sweeps=%s knockback_resist=%.1f (expected true, true, 0.9)" % [
		main.ENEMY_TRAITS.get("Water Elemental", {}).get("is_boss_tier", false),
		main.ENEMY_TRAITS.get("Water Elemental", {}).get("sweeps", false),
		main.ENEMY_TRAITS.get("Water Elemental", {}).get("knockback_resist", 0.0),
	])
	print("Water Elemental is tankier than Aboleth, matching boss > miniboss: elemental_hp=%d aboleth_hp=%d (expected elemental > aboleth)" % [
		water_elemental_script.MAX_HEALTH, aboleth_script.MAX_HEALTH
	])
	print("HUD icons cover both new enemies: aboleth=%s (expected true), water_elemental=%s (expected true)" % [
		main.hud.ENEMY_ICONS.get("Aboleth", null) != null, main.hud.ENEMY_ICONS.get("Water Elemental", null) != null
	])

	# --- Beach's wave-gated boss spawn end-to-end (through the real
	# _spawn_boss_wave, not a hand-built dict) ---
	main.wave = 15  # Beach, world-relative wave 5 -> miniboss
	main.current_world_index = main._world_index_for_wave(main.wave)
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await physics_frame
	main.enemies_alive = 0
	main._spawn_boss_wave()
	await physics_frame
	var mini_enemies: Array = main.get_tree().get_nodes_in_group("enemies")
	print("Beach's miniboss wave spawns an Aboleth: count=%d (expected 1), name=%s (expected Aboleth)" % [
		mini_enemies.size(), mini_enemies[0].get_display_name() if mini_enemies.size() == 1 else "none"
	])
	var aboleth_ref = mini_enemies[0] if mini_enemies.size() == 1 else null
	for e in mini_enemies:
		e.set_physics_process(false)

	# --- Solo fight, big arena (is_boss_tier flows through _gather_squad /
	# _setup_battle_grid exactly like Boss/Owlbear did) -- checked here,
	# before the next wave's cleanup queue_frees this reference. ---
	if aboleth_ref != null:
		var mini_squad: Array = main._gather_squad(aboleth_ref)
		print("Aboleth fights are solo, no escorts gathered: squad_size=%d (expected 1)" % [mini_squad.size()])
		main._setup_battle_grid(mini_squad)
		print("Aboleth fight sets up on the bigger 15x15 arena: w=%d h=%d (expected 15, 15)" % [main.BATTLE_GRID_W, main.BATTLE_GRID_H])

	main.wave = 20  # Beach, world-relative wave 10 -> full boss
	main.current_world_index = main._world_index_for_wave(main.wave)
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await physics_frame
	main.enemies_alive = 0
	main._spawn_boss_wave()
	await physics_frame
	var full_enemies: Array = main.get_tree().get_nodes_in_group("enemies")
	print("Beach's world-ending wave spawns a Water Elemental: count=%d (expected 1), name=%s (expected Water Elemental)" % [
		full_enemies.size(), full_enemies[0].get_display_name() if full_enemies.size() == 1 else "none"
	])
	var elemental_ref = full_enemies[0] if full_enemies.size() == 1 else null
	for e in full_enemies:
		e.set_physics_process(false)

	if elemental_ref != null:
		var squad2: Array = main._gather_squad(elemental_ref)
		print("Water Elemental fights are solo too: squad_size=%d (expected 1)" % [squad2.size()])
		main._setup_battle_grid(squad2)
		print("Water Elemental fight also gets the 15x15 arena: w=%d h=%d (expected 15, 15)" % [main.BATTLE_GRID_W, main.BATTLE_GRID_H])

		# --- Water Elemental's sweep hits the player and an adjacent ally ---
		main.battle_player_tile = Vector2i(5, 5)
		main.battle_allies = [{"ref": null, "tile": Vector2i(6, 6), "hp": 50, "max_hp": 50, "name": "Blade Ally"}]
		var elemental_unit := {
			"ref": elemental_ref, "tile": Vector2i(5, 6), "hp": 999, "max_hp": 999, "move_range": 1,
			"damage": 10, "name": "Water Elemental", "winding_up": false, "stunned": false, "size": 1,
			"attack_range": 1, "concussed_turns": 0, "frozen_turns": 0, "burning": false,
			"armored": true, "disarmed_tile": Vector2i(-1, -1),
		}
		var swept: Array = main._sweep_targets(elemental_unit)
		print("Water Elemental's sweep catches both the player and the adjacent ally: %s (expected true)" % [
			Vector2i(5, 5) in swept and Vector2i(6, 6) in swept
		])

	quit()
