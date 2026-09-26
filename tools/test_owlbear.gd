extends SceneTree

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
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var player = main.player
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	var boss_script = load("res://scripts/Boss.gd")
	var owlbear_script = load("res://scripts/Owlbear.gd")
	var goblin_script = load("res://scripts/Enemy.gd")

	# --- Wave gating: wave 5 still spawns the plain Boss, wave 10+ spawns
	# the Owlbear instead. ---
	main.wave = main.BOSS_WAVE_INTERVAL
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await physics_frame
	main.enemies_alive = 0
	main._spawn_wave()
	await physics_frame
	var wave5_enemies: Array = main.get_tree().get_nodes_in_group("enemies")
	print("wave 5 still spawns the plain Boss: count=%d (expected 1), name=%s (expected Boss)" % [
		wave5_enemies.size(), wave5_enemies[0].get_display_name() if wave5_enemies.size() == 1 else "none"
	])
	for e in wave5_enemies:
		e.set_physics_process(false)

	main.wave = main.OWLBEAR_WAVE_START
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await physics_frame
	main.enemies_alive = 0
	main._spawn_wave()
	await physics_frame
	var wave10_enemies: Array = main.get_tree().get_nodes_in_group("enemies")
	print("wave %d spawns the Owlbear instead: count=%d (expected 1), name=%s (expected Owlbear)" % [
		main.OWLBEAR_WAVE_START, wave10_enemies.size(), wave10_enemies[0].get_display_name() if wave10_enemies.size() == 1 else "none"
	])
	for e in wave10_enemies:
		e.set_physics_process(false)

	# --- Very tanky: meaningfully more HP than the Boss it replaces. ---
	print("the Owlbear is tankier than the Boss it replaces: owlbear_hp=%d boss_hp=%d (expected owlbear > boss)" % [
		owlbear_script.MAX_HEALTH, boss_script.MAX_HEALTH
	])

	# --- Owlbear fights are solo, same as the Boss -- no escorts gathered
	# even if enemies are standing right next to it. ---
	var owlbear = owlbear_script.new()
	main.add_child(owlbear)
	owlbear.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	var nearby_goblin = goblin_script.new()
	main.add_child(nearby_goblin)
	nearby_goblin.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	nearby_goblin.global_position = owlbear.global_position + Vector2(10, 0)
	var squad = main._gather_squad(owlbear)
	print("Owlbear battles are solo, no escorts gathered: squad_size=%d (expected 1)" % [squad.size()])

	# --- 2x2 footprint via the real _setup_battle_grid path. ---
	main._setup_battle_grid([owlbear])
	var owlbear_unit = main.battle_units[0]
	var footprint: Array = main._footprint(owlbear_unit.tile, owlbear_unit.size)
	print("Owlbear is placed as a real 2x2 footprint: size=%d (expected 2), footprint_cell_count=%d (expected 4), all_in_bounds=%s (expected true)" % [
		owlbear_unit.size, footprint.size(), footprint.all(func(c): return main._in_battle_bounds(c))
	])

	# --- Ignores terrain entirely, same as the Brute. ---
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(5, 5)
	main.battle_terrain[Vector2i(2, 2)] = {"type": "rock"}
	main.battle_units = [_make_unit(main, owlbear, Vector2i(1, 2), 220, "Owlbear", 6)]
	main._move_big_unit(main.battle_units[0], main.battle_player_tile, main.battle_player_tile)
	print("Owlbear walks straight through a rock in its path, ignoring terrain entirely: tile=%s (expected x=2, past the rock)" % [main.battle_units[0].tile])

	# --- Corners the player: _move_big_unit steers by movement_target, not
	# straight at attack_check_target -- same shape as the existing
	# _move_enemy_unit flanking check, now proven for a 2x2 unit. Mirrors
	# test_enemy_variety.gd's Orc flank-steering test exactly, one size up. ---
	main.battle_terrain.clear()
	main.battle_units = [_make_unit(main, owlbear, Vector2i(2, 2), 220, "Owlbear", 6)]
	main._move_big_unit(main.battle_units[0], Vector2i(0, 2), Vector2i(5, 2))
	print("_move_big_unit steers toward movement_target, not straight at the real target -- this is what wires the Owlbear's cornering in: tile=%s (expected (1, 2), moved left toward the flank tile, not right toward (5,2))" % [main.battle_units[0].tile])

	# --- Sweeping attack: a real AoE that hits the player AND an adjacent
	# ally in the same swing, now that enemies can target allies at all
	# (see tools/test_ally_battle.gd for that base mechanism). ---
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_target_index = 0
	player.stat_vigor = 100
	player._recalc_stats()
	player.health = player.max_health
	main.battle_allies = [{"tile": Vector2i(2, 3), "hp": 30, "max_hp": 30, "dmg_mult": 0.75, "name": "Blade Ally", "move_range": 2, "attack_range": 1}]
	main.battle_units = [_make_unit(main, owlbear, Vector2i(3, 2), 220, "Owlbear", 6)]
	var ally_hp_before: int = main.battle_allies[0].hp
	var player_hp_before: int = player.health
	main._process_enemy_turn()
	print("the sweep hits both the player and an adjacent ally in the same turn: player_hit=%s (expected true), ally_hit=%s (expected true)" % [
		player.health < player_hp_before, main.battle_allies[0].hp < ally_hp_before if not main.battle_allies.is_empty() else false
	])

	quit()
