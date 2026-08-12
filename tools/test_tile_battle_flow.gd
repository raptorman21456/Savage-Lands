extends SceneTree

func _init() -> void:
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var player = main.player
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	var goblin_script = load("res://scripts/Enemy.gd")
	var goblin = goblin_script.new()
	main.add_child(goblin)
	goblin.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	goblin.global_position = player.global_position + Vector2(300, 300)

	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_target_index = 0
	main.battle_units = [{
		"ref": goblin, "tile": Vector2i(4, 2), "hp": 5, "max_hp": 5,
		"move_range": 2, "damage": 2, "name": "Goblin",
	}]

	# Water pushes whoever's standing on it -- enemies at the end of the enemy
	# turn, and the player too now, at the end of the player's turn (see the
	# dedicated test_water_push_player.gd for that half, kept out of this
	# file since _end_player_turn's enemy-turn cascade has side effects that
	# don't play well with this test's later shared-state assumptions).
	main.battle_terrain[Vector2i(4, 2)] = {"type": "water", "push_dir": Vector2i(-1, 0)}
	var pushed_tile = main._apply_water_push(Vector2i(4, 2))
	print("water pushes a unit standing on it: pushed_tile=%s (expected (3, 2))" % [pushed_tile])
	main.battle_terrain.clear()

	# Rock cover reduces damage. Bump strength so the 25% reduction is
	# actually visible (base attack_damage of 1 would round right back to 1).
	player.stat_strength = 20
	player.attack_damage = 20
	main.battle_terrain[Vector2i(4, 3)] = {"type": "rock"}
	main.battle_units[0].tile = Vector2i(4, 2)
	main.battle_units[0].hp = 999
	main.battle_player_tile = Vector2i(3, 2)
	var normal_dmg: int = player.attack_damage
	var hp_before: int = main.battle_units[0].hp
	main._battle_player_fight()
	var dmg_dealt: int = hp_before - main.battle_units[0].hp
	print("rock-adjacent cover reduces damage: dealt=%d (expected ~%d, 25%% less than %d)" % [
		dmg_dealt, int(round(normal_dmg * 0.75)), normal_dmg
	])

	# Fight to kill: confirm real death path (loot/xp) fires and battle ends
	# in victory when the squad is empty.
	main.battle_units[0].hp = 1
	var enemies_alive_before: int = main.enemies_alive
	var xp_before: int = player.xp
	main._battle_player_fight()
	print("killing the last unit -> in_battle=%s (expected false) enemies_alive %d -> %d xp %d -> %d" % [
		main.in_battle, enemies_alive_before, main.enemies_alive, xp_before, player.xp
	])

	# Item usage.
	player.add_healing_item(2)
	player.health = 1
	main.in_battle = true
	main.battle_turn = "player"
	main.battle_units = []
	main._battle_player_item()
	print("item heals: player_health=%d (expected 1+%d=%d), items_left=%d (expected 1)" % [
		player.health, player.ITEM_HEAL_AMOUNT, 1 + player.ITEM_HEAL_AMOUNT, player.healing_items
	])

	# Defend reduces incoming damage during the enemy phase.
	var goblin2 = goblin_script.new()
	main.add_child(goblin2)
	goblin2.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	main.battle_units = [{
		"ref": goblin2, "tile": Vector2i(3, 2), "hp": 5, "max_hp": 5,
		"move_range": 2, "damage": 4, "name": "Goblin",
	}]
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_terrain.clear()
	player.health = player.max_health
	main.battle_player_defending = true
	main._process_enemy_turn()
	var expected_defend_dmg: int = int(round(4 * 0.7))
	print("defend halves-ish incoming damage: player_health=%d (expected max_health-%d = %d)" % [
		player.health, expected_defend_dmg, player.max_health - expected_defend_dmg
	])

	# Targeting: two enemies both in range -- confirm cycling switches which
	# one an attack lands on, and that a dead/out-of-range target falls back
	# automatically rather than swinging at nothing.
	var goblin3 = goblin_script.new()
	main.add_child(goblin3)
	goblin3.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	var goblin4 = goblin_script.new()
	main.add_child(goblin4)
	goblin4.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_units = [
		{"ref": goblin3, "tile": Vector2i(3, 2), "hp": 999, "max_hp": 999, "move_range": 2, "damage": 2, "name": "Goblin"},
		{"ref": goblin4, "tile": Vector2i(1, 2), "hp": 999, "max_hp": 999, "move_range": 2, "damage": 2, "name": "Goblin"},
	]
	main.battle_target_index = 0
	print("both enemies targetable: indices=%s (expected [0, 1])" % [main._targetable_indices()])
	main._cycle_battle_target(1)
	print("cycle target once: battle_target_index=%d (expected 1)" % [main.battle_target_index])
	main._cycle_battle_target(1)
	print("cycle target wraps around: battle_target_index=%d (expected 0)" % [main.battle_target_index])

	main.battle_target_index = 1
	main.battle_units[1].hp = 1
	main._battle_player_fight()
	print("attack lands on the cycled-to target: goblin4_dead=%s goblin3_hp=%d (expected true, 999)" % [
		not is_instance_valid(goblin4) or main.battle_units.size() == 1, main.battle_units[0].hp if main.battle_units.size() > 0 else -1
	])

	# Orc telegraph: first adjacent turn winds up (no damage), second lands a
	# heavier hit. Goblins have no telegraph and hit every turn in range.
	var orc_script = load("res://scripts/Orc.gd")
	var orc = orc_script.new()
	main.add_child(orc)
	orc.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_player_defending = false
	main.battle_units = [{
		"ref": orc, "tile": Vector2i(3, 2), "hp": 999, "max_hp": 999,
		"move_range": 1, "damage": 4, "name": "Orc", "winding_up": false,
	}]
	player.health = player.max_health
	main._process_enemy_turn()
	print("orc telegraphs before its first hit: player_health=%d (expected unchanged %d), winding_up=%s (expected true)" % [
		player.health, player.max_health, main.battle_units[0].winding_up
	])

	main._process_enemy_turn()
	var expected_windup_dmg: int = int(round(4 * main.ORC_WINDUP_DAMAGE_MULT))
	print("orc lands the telegraphed hit: player_health=%d (expected max_health-%d = %d), winding_up=%s (expected false)" % [
		player.health, expected_windup_dmg, player.max_health - expected_windup_dmg, main.battle_units[0].winding_up
	])

	quit()
