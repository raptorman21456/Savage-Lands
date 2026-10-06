extends SceneTree

# Boss waves and big-unit behaviour. Replaces the old Owlbear test: wave 5 of a world is its
# miniboss and wave 10 its full boss (Plains uses PLACEHOLDER pair Treant / Lizen Warband),
# boss-tier fights are solo, a sweeping boss (Elder Oak) hits the player AND an adjacent ally,
# and the 2x2 Brute (the remaining big unit) still ignores terrain and steers by its flank tile.

func _make_unit(main, ref, tile: Vector2i, hp: int, name: String, damage: int) -> Dictionary:
	var traits: Dictionary = main.ENEMY_TRAITS.get(name, {})
	return {
		"ref": ref, "tile": tile, "hp": hp, "max_hp": hp,
		"move_range": traits.get("move_range", 2),
		"attack_range": traits.get("attack_range", 1),
		"size": traits.get("size", 1),
		"damage": damage, "name": name, "winding_up": false, "stunned": false,
	}

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

	var oak_script = load("res://scripts/ElderOak.gd")
	var treant_script = load("res://scripts/Treant.gd")
	var brute_script = load("res://scripts/Brute.gd")
	var goblin_script = load("res://scripts/Enemy.gd")

	# --- Wave gating: wave 5 spawns the world's miniboss, wave 10 its full boss. ---
	main.wave = main.BOSS_WAVE_INTERVAL
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await physics_frame
	main.enemies_alive = 0
	main._spawn_wave()
	await physics_frame
	var wave5_enemies: Array = main.get_tree().get_nodes_in_group("enemies")
	print("wave 5 spawns Plains' miniboss: count=%d (expected 1), name=%s (expected Treant)" % [
		wave5_enemies.size(), wave5_enemies[0].get_display_name() if wave5_enemies.size() == 1 else "none"
	])
	for e in wave5_enemies:
		e.set_physics_process(false)

	main.wave = main.WORLD_BOSS_WAVE
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await physics_frame
	main.enemies_alive = 0
	main._spawn_wave()
	await physics_frame
	var wave10_enemies: Array = main.get_tree().get_nodes_in_group("enemies")
	print("wave %d spawns Plains' full boss: count=%d (expected 1), name=%s (expected Lizen Warband)" % [
		main.WORLD_BOSS_WAVE, wave10_enemies.size(), wave10_enemies[0].get_display_name() if wave10_enemies.size() == 1 else "none"
	])
	for e in wave10_enemies:
		e.set_physics_process(false)

	# --- A full boss out-tanks the miniboss of its own world (Forest: Elder Oak vs Treant). ---
	print("Elder Oak is tankier than the Treant: oak_hp=%d treant_hp=%d (expected oak > treant)" % [oak_script.MAX_HEALTH, treant_script.MAX_HEALTH])

	# --- Boss fights are solo -- no escorts even if enemies stand right next to it. ---
	var oak = oak_script.new()
	main.add_child(oak)
	oak.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	var nearby_goblin = goblin_script.new()
	main.add_child(nearby_goblin)
	nearby_goblin.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	nearby_goblin.global_position = oak.global_position + Vector2(10, 0)
	var squad = main._gather_squad(oak)
	print("Elder Oak battles are solo, no escorts gathered: squad_size=%d (expected 1)" % [squad.size()])

	# --- The Brute is the one 2x2 unit left: a real footprint via _setup_battle_grid. ---
	var brute = brute_script.new()
	main.add_child(brute)
	main._setup_battle_grid([brute])
	var brute_unit = main.battle_units[0]
	var footprint: Array = main._footprint(brute_unit.tile, brute_unit.size)
	print("Brute is placed as a real 2x2 footprint: size=%d (expected 2), footprint_cell_count=%d (expected 4), all_in_bounds=%s (expected true)" % [
		brute_unit.size, footprint.size(), footprint.all(func(c): return main._in_battle_bounds(c))
	])

	# --- Ignores terrain entirely. ---
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(5, 5)
	main.battle_terrain[Vector2i(2, 2)] = {"type": "rock"}
	main.battle_units = [_make_unit(main, brute, Vector2i(1, 2), 35, "Brute", 3)]
	main._move_big_unit(main.battle_units[0], main.battle_player_tile, main.battle_player_tile)
	print("Brute walks straight through a rock in its path, ignoring terrain entirely: tile=%s (expected x=2, past the rock)" % [main.battle_units[0].tile])

	# --- _move_big_unit steers by movement_target, not straight at attack_check_target. ---
	main.battle_terrain.clear()
	main.battle_units = [_make_unit(main, brute, Vector2i(2, 2), 35, "Brute", 3)]
	main._move_big_unit(main.battle_units[0], Vector2i(0, 2), Vector2i(5, 2))
	print("_move_big_unit steers toward movement_target, not straight at the real target: tile=%s (expected (1, 2), moved left toward the flank tile)" % [main.battle_units[0].tile])

	# --- Sweeping attack: a real AoE that hits the player AND an adjacent ally in the same swing. ---
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_target_index = 0
	player.stat_vigor = 100
	player._recalc_stats()
	player.health = player.max_health
	main.battle_allies = [{"tile": Vector2i(3, 3), "hp": 30, "max_hp": 30, "dmg_mult": 0.75, "name": "Knight", "move_range": 2, "attack_range": 1}]
	main.battle_units = [_make_unit(main, oak, Vector2i(3, 2), 245, "Elder Oak", 7)]
	var ally_hp_before: int = main.battle_allies[0].hp
	var player_hp_before: int = player.health
	# Elder Oak telegraphs first (windup), then lands the sweep.
	main._process_enemy_turn()
	main._process_enemy_turn()
	print("the sweep hits both the player and an adjacent ally in the same turn: player_hit=%s (expected true), ally_hit=%s (expected true)" % [
		player.health < player_hp_before, main.battle_allies[0].hp < ally_hp_before if not main.battle_allies.is_empty() else false
	])

	quit()
