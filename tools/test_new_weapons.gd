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

	print("dagger and bow are shop-upgradable weapon types: dagger=%s bow=%s (both expected true)" % [
		weapons_script.UPGRADABLE_TYPES.any(func(w): return w.id == "dagger"),
		weapons_script.UPGRADABLE_TYPES.any(func(w): return w.id == "bow"),
	])

	# Dagger: double_hit special (Quick Stab) applies the hit twice, same
	# mechanic the spear's Flurry already uses.
	player.coins = 100
	var bought_dagger: bool = player.try_buy_weapon(weapons_script.DAGGER)
	# Specials have to be learned at the Dojo now -- this test is about what the
	# moves DO, not how you get them.
	player.learn_all_specials()
	player.stamina = player.MAX_STAMINA
	var g_quick_stab = _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [g_quick_stab]
	main._battle_player_special(0)
	var quick_stab_dmg: int = int(round(10 * weapons_script.DAGGER.damage_mult * player.current_weapon.specials[0].dmg_mult))
	print("bought dagger=%s, quick stab hits twice: dealt=%d (expected ~%d, two hits of %d each)" % [
		bought_dagger, 999 - g_quick_stab.hp, quick_stab_dmg * 2, quick_stab_dmg
	])

	# Dagger: lifesteal (Bleeding Cut) heals the player for a cut of the
	# damage it just dealt. damage=0 on the target so this turn's cascaded
	# enemy counter-attack can't muddy the heal-amount check.
	player.stamina = player.MAX_STAMINA
	player.health = 1
	var g_bleed = _make_goblin(main, Vector2i(3, 2))
	g_bleed.damage = 0
	main.battle_units = [g_bleed]
	main._battle_player_special(1)
	var bleed_dmg: int = int(round(10 * weapons_script.DAGGER.damage_mult * player.current_weapon.specials[1].dmg_mult))
	var expected_lifesteal: int = max(1, int(round(bleed_dmg * main.LIFESTEAL_PCT)))
	print("lifesteal special heals the player for a cut of the damage dealt: dealt=%d, player_health=%d (expected 1+%d=%d)" % [
		999 - g_bleed.hp, player.health, expected_lifesteal, 1 + expected_lifesteal
	])

	# Bow: long_range lets it hit at range 2, same geometry a spear uses --
	# a club (no long_range) can't reach that far.
	main.battle_terrain.clear()
	player.current_weapon = weapons_script.CLUB
	main.battle_units = [_make_goblin(main, Vector2i(4, 2))]
	var club_targetable: Array = main._targetable_indices()

	player.coins = 100
	var bought_bow: bool = player.try_buy_weapon(weapons_script.BOW)
	var bow_targetable: Array = main._targetable_indices()
	print("bow attacks at range 2, club can't: bought_bow=%s club_targetable=%s (expected []) bow_targetable=%s (expected [0])" % [
		bought_bow, club_targetable, bow_targetable
	])

	# Bow: regular hits use its own damage_mult, same as every other weapon.
	player.stamina = player.MAX_STAMINA
	var g_bow = _make_goblin(main, Vector2i(4, 2))
	main.battle_units = [g_bow]
	main._battle_player_fight()
	var expected_bow_dmg: int = int(round(10 * weapons_script.BOW.damage_mult))
	print("bow deals its own damage_mult at range 2: dealt=%d (expected %d)" % [999 - g_bow.hp, expected_bow_dmg])

	quit()
