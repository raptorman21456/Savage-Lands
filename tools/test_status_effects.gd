extends SceneTree

# New status-effect infrastructure for the weapon specials rework: burning
# (DOT), frozen (turn-skip + damage-taken bonus), concussed (self-hit
# chance), armored (a flag some specials read/mutate), disarm (player and
# enemy), and the player's own "skip a turn" mechanic. Verified in isolation
# here, BEFORE any real weapon special is built on top of it, per the plan's
# suggested build order.

func _make_goblin(main, tile: Vector2i, hp: int = 999) -> Dictionary:
	var goblin_script = load("res://scripts/Enemy.gd")
	var g = goblin_script.new()
	main.add_child(g)
	g.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	return {
		"ref": g, "tile": tile, "hp": hp, "max_hp": hp, "move_range": 2,
		"damage": 1, "name": "Goblin", "winding_up": false, "stunned": false,
		"attack_range": 1, "concussed_turns": 0, "frozen_turns": 0,
		"burning": false, "armored": false,
		"disarmed_tile": Vector2i(-1, -1),
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

	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(0, 0)
	main.battle_allies = []

	# --- armored copies from ENEMY_TRAITS at squad setup. ---
	var orc_script = load("res://scripts/Orc.gd")
	var orc = orc_script.new()
	main.add_child(orc)
	main._setup_battle_grid([orc])
	print("armored copies true from ENEMY_TRAITS for an Orc: %s (expected true)" % [main.battle_units[0].armored])
	var goblin_ref = load("res://scripts/Enemy.gd").new()
	main.add_child(goblin_ref)
	main._setup_battle_grid([goblin_ref])
	print("armored defaults false for a Goblin: %s (expected false)" % [main.battle_units[0].armored])
	# _setup_battle_grid scatters random terrain (rocks, etc.) -- clear it so
	# it can't nondeterministically block movement/targeting in every test
	# below that assumes a clean, empty grid.
	main.battle_terrain.clear()

	# --- Burning: %-of-max-HP at the top of the unit's turn, regardless of
	# range to the player, doesn't skip the turn, and (unlike every other
	# status here) has no turn counter -- it stays set until the unit steps
	# onto water, so a second tick should fire identically. ---
	main.battle_player_tile = Vector2i(5, 5)
	var g_burn := _make_goblin(main, Vector2i(0, 0), 999)
	g_burn.burning = true
	main.battle_units = [g_burn]
	main._process_enemy_turn()
	var expected_burn: int = int(round(999.0 / main.BURN_DAMAGE_DIVISOR))
	print("burning deals %%-of-max-HP damage and does NOT clear itself: hp=%d (expected %d), burning=%s (expected true)" % [
		g_burn.hp, 999 - expected_burn, g_burn.burning
	])
	main._process_enemy_turn()
	print("...and keeps ticking every turn since nothing cleared it: hp=%d (expected %d)" % [
		g_burn.hp, 999 - expected_burn * 2
	])

	# --- Frozen: skips the whole turn (no attack even if adjacent), and
	# decrements. ---
	main.battle_player_tile = Vector2i(1, 0)
	player.health = player.max_health
	var g_frozen := _make_goblin(main, Vector2i(0, 0), 999)
	g_frozen.damage = 50
	g_frozen.frozen_turns = 2
	main.battle_units = [g_frozen]
	main._process_enemy_turn()
	print("frozen skips the turn entirely, even adjacent to the player: player_health=%d (expected unchanged %d), frozen_turns=%d (expected 1)" % [
		player.health, player.max_health, g_frozen.frozen_turns
	])

	# --- Frozen +20% damage-taken bonus, via _apply_single_hit. ---
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_target_index = 0
	player.stat_strength = 10
	player.attack_damage = 10
	player.stamina = player.MAX_STAMINA
	var g_normal := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [g_normal]
	main._battle_player_fight()
	var normal_dmg: int = 999 - g_normal.hp
	var g_frozen_dmg := _make_goblin(main, Vector2i(3, 2))
	g_frozen_dmg.frozen_turns = 1
	main.battle_units = [g_frozen_dmg]
	main._battle_player_fight()
	var frozen_dmg: int = 999 - g_frozen_dmg.hp
	print("frozen takes 20%% more damage from a hit: normal=%d frozen=%d (expected frozen == round(normal*1.2)=%d)" % [
		normal_dmg, frozen_dmg, int(round(normal_dmg * 1.2))
	])

	# --- Concussed: rolled once per turn: force the roll via a fixed
	# concussed_turns and check the decrement lands (probabilistic self-hit
	# itself isn't asserted here -- it's a 33% roll, would be flaky -- but
	# the plumbing that has to be right regardless of the roll's outcome is
	# checked: the counter decrements exactly once per turn). ---
	main.battle_player_tile = Vector2i(5, 5)
	var g_concussed := _make_goblin(main, Vector2i(0, 0), 999)
	g_concussed.concussed_turns = 3
	main.battle_units = [g_concussed]
	main._process_enemy_turn()
	print("concussed_turns decrements exactly once per turn: %d (expected 2)" % [g_concussed.concussed_turns])

	# --- Disarm, enemy side: paths toward disarmed_tile instead of
	# attacking, even while adjacent to the player; clears and resumes once
	# it arrives. ---
	main.battle_player_tile = Vector2i(1, 0)
	player.health = player.max_health
	var g_disarmed := _make_goblin(main, Vector2i(0, 0), 999)
	g_disarmed.damage = 50
	g_disarmed.disarmed_tile = Vector2i(4, 4)
	main.battle_units = [g_disarmed]
	main._process_enemy_turn()
	print("a disarmed enemy doesn't attack even while adjacent to the player: player_health=%d (expected unchanged %d), moved_toward_weapon=%s (expected true)" % [
		player.health, player.max_health, g_disarmed.tile != Vector2i(0, 0)
	])
	g_disarmed.tile = g_disarmed.disarmed_tile
	main._process_enemy_turn()
	print("a disarmed enemy clears the flag once it reaches its weapon's tile: disarmed_tile=%s (expected (-1, -1))" % [g_disarmed.disarmed_tile])

	# --- Disarm, player side: Fight is disabled while set, and reclaiming
	# the tile clears it. ---
	player.disarmed_tile = Vector2i(3, 3)
	main.battle_player_tile = Vector2i(0, 0)
	main._refresh_battle_display()
	print("Fight is disabled while the player is disarmed: %s (expected true)" % [main.hud.battle_main_buttons["fight"].disabled])
	main.battle_player_tile = Vector2i(3, 3)
	main._check_disarm_reclaimed()
	print("reaching the weapon's tile clears the player's disarm: %s (expected (-1, -1))" % [player.disarmed_tile])
	main._refresh_battle_display()
	print("Fight is re-enabled once reclaimed: %s (expected false)" % [main.hud.battle_main_buttons["fight"].disabled])

	# --- "Lose a turn" (player): the turn cycle skips the player's menu
	# entirely and lands back on it only after the skip is consumed. A live
	# enemy has to stay in battle_units, or _process_enemy_turn's own
	# "squad empty -> victory" check would return before ever reaching the
	# skip-turn logic at the very end of the function.
	main.battle_player_tile = Vector2i(5, 5)
	player.health = player.max_health
	main.battle_player_turns_to_skip = 1
	main.battle_units = [_make_goblin(main, Vector2i(0, 0), 999)]
	main._process_enemy_turn()
	print("battle_player_turns_to_skip is consumed and the cycle still lands back on the player: turns_to_skip=%d (expected 0), battle_turn=%s (expected player)" % [
		main.battle_player_turns_to_skip, main.battle_turn
	])

	# Reset the scratch save for whatever test runs next.
	var save_data_script = load("res://scripts/SaveData.gd")
	save_data_script.save_data({"essence": 0, "upgrades": {}, "best_wave": 0})

	quit()
