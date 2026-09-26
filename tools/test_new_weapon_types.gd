extends SceneTree

func _make_goblin(main, tile: Vector2i, hp: int = 999) -> Dictionary:
	var goblin_script = load("res://scripts/Enemy.gd")
	var g = goblin_script.new()
	main.add_child(g)
	g.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	return {
		"ref": g, "tile": tile, "hp": hp, "max_hp": hp, "move_range": 2,
		"damage": 1, "name": "Goblin", "winding_up": false, "stunned": false,
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
	var weapons_script = load("res://scripts/Weapons.gd")
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_target_index = 0
	player.stat_strength = 10
	player.attack_damage = 10

	print("knuckle gloves and hand picks are shop-upgradable weapon types: gloves=%s picks=%s (both expected true)" % [
		weapons_script.UPGRADABLE_TYPES.any(func(w): return w.id == "knuckle_gloves"),
		weapons_script.UPGRADABLE_TYPES.any(func(w): return w.id == "hand_picks"),
	])

	# Knuckle Gloves: innate double_strike means the plain Attack action (not
	# a special) lands twice in the tile battle.
	player.coins = 100
	var bought_gloves: bool = player.try_buy_weapon(weapons_script.KNUCKLE_GLOVES)
	# Specials have to be learned at the Dojo now -- this test is about what the
	# moves DO, not how you get them.
	player.learn_all_specials()
	player.stamina = player.MAX_STAMINA
	var g_gloves = _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [g_gloves]
	main._battle_player_fight()
	var expected_per_hit: int = int(round(10 * weapons_script.KNUCKLE_GLOVES.damage_mult))
	print("bought knuckle gloves=%s, plain attack hits twice: dealt=%d (expected 2x%d=%d)" % [
		bought_gloves, 999 - g_gloves.hp, expected_per_hit, expected_per_hit * 2
	])

	# Knuckle Gloves double_strike must NOT double a special (which already
	# has its own explicit effect) -- Haymaker (index 1) should land once.
	player.stamina = player.MAX_STAMINA
	var g_special = _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [g_special]
	main._battle_player_special(1)
	var expected_haymaker: int = int(round(10 * weapons_script.KNUCKLE_GLOVES.damage_mult * player.current_weapon.specials[1].dmg_mult))
	print("knuckle gloves specials are NOT doubled: dealt=%d (expected %d, a single hit)" % [999 - g_special.hp, expected_haymaker])

	# Knuckle Gloves double_strike also applies in the overworld swing.
	var overworld_target = load("res://scripts/Enemy.gd").new()
	main.add_child(overworld_target)
	overworld_target.died.connect(main._on_enemy_died)
	var health_before: int = overworld_target.health
	player._apply_weapon_hit(overworld_target)
	print("knuckle gloves double_strike also lands twice in the overworld: health %d -> %d (expected dropped by 2 hits or dead)" % [
		health_before, overworld_target.health if is_instance_valid(overworld_target) else -1
	])

	# Hand Picks: passive_armor_pierce_pct adds bonus damage against an
	# armored target on ANY attack (not gated to a named special, unlike
	# Maracas's identical-shaped bonus) -- and, unlike the old
	# innate_ignore_cover it replaced, rock cover still applies normally.
	player.coins = 100
	var bought_picks: bool = player.try_buy_weapon(weapons_script.HAND_PICKS)
	player.learn_all_specials()
	player.stamina = player.MAX_STAMINA
	main.battle_terrain.clear()
	main.battle_terrain[Vector2i(4, 2)] = {"type": "rock"}
	var g_picks = _make_goblin(main, Vector2i(3, 2))
	g_picks.armored = true
	main.battle_units = [g_picks]
	main._battle_player_fight()
	# Sequential rounding, same order _apply_single_hit actually applies it
	# in (armor-pierce, then cover) -- not one collapsed formula, which can
	# land a point off from compounding two separate int(round(...)) steps.
	var picks_base_dmg: int = int(round(10 * weapons_script.HAND_PICKS.damage_mult))
	var picks_after_pierce: int = int(round(picks_base_dmg * 1.3))
	var expected_picks_dmg: int = int(round(picks_after_pierce * 0.75))
	print("hand picks deals bonus damage to an armored target, on top of rock cover still applying: dealt=%d (expected %d, +30%% armor-pierce then -25%% cover)" % [999 - g_picks.hp, expected_picks_dmg])

	var g_picks_unarmored = _make_goblin(main, Vector2i(3, 2))
	main.battle_terrain.clear()
	main.battle_units = [g_picks_unarmored]
	main._battle_player_fight()
	var expected_unarmored_dmg: int = int(round(10 * weapons_script.HAND_PICKS.damage_mult))
	print("...but nothing extra against an unarmored target, and no cover to ignore here: dealt=%d (expected plain %d)" % [999 - g_picks_unarmored.hp, expected_unarmored_dmg])

	quit()
