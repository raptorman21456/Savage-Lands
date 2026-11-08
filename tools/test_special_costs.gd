extends SceneTree

# Specials priced as "a flat part + a share of the user's whole pool" (design doc, 2026-10-30): the Club's three
# (30 + 20%, 10 + 40%, 30 + 50% of max stamina) and the Wolf's three (35 + 30%, 25 + 30%, 10 + 20%). The hero pays it
# against today's maximum, the Wolf against its 150.

func _make_goblin(main, tile: Vector2i, hp: int = 999) -> Dictionary:
	var g = load("res://scripts/Enemy.gd").new()
	main.add_child(g)
	g.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	return {
		"ref": g, "tile": tile, "hp": hp, "max_hp": hp, "move_range": 2, "damage": 1,
		"name": "Goblin", "winding_up": false, "stunned": false, "attack_range": 1,
		"concussed_turns": 0, "frozen_turns": 0, "burning": false, "armored": false,
		"disarmed_tile": Vector2i(-1, -1), "vulnerable_turns": 0, "aware_of_player": true, "size": 1,
	}

func _reset(main, player) -> void:
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_allies = []
	main.battle_downed_allies = []
	main.battle_units = []
	main.battle_actor = {}
	main.battle_commanding_ally = null
	main.battle_ally_queue = []
	main.battle_player_tile = Vector2i(0, 4)
	main.battle_target_index = 0
	main.battle_turn = "player"
	main.battle_menu_state = "main"
	main.tutorial_active = false
	player.max_health = 500
	player.health = 500

func _filler() -> Dictionary:
	return {"tile": Vector2i(0, 0), "hp": 10, "max_hp": 10, "dmg_mult": 1.0, "name": "Filler", "move_range": 1, "attack_range": 1}

func _init() -> void:
	# Magic from a Staff or Wand used to be a flat +5 / +6; the doc's per-quality-tier version (test_weapon_stat_bonuses.gd) gives a Fine one
	# (the second rung) the same figures at 2.5 / 3.0 a tier, so these checks keep the numbers they were written against.
	var _magic_weapons = load("res://scripts/Weapons.gd")
	_magic_weapons.STAFF["magic_per_tier"] = 2.5
	_magic_weapons.WAND["magic_per_tier"] = 3.0
	seed(20261107)
	var weapons = load("res://scripts/Weapons.gd")
	var kits = load("res://scripts/PartyKits.gd")
	var main = load("res://Main.tscn").instantiate()
	main.regional_world = false
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	main.settings.attack_minigame_enabled = false
	main.enforce_special_loadouts = false
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	print("--- the words and the sums")
	var club: Dictionary = weapons.CLUB
	print("Kneecaps at 100 max stamina = %d (expected 50)" % weapons.special_cost(club.specials[0], 100))
	print("Second Wind at 100 = %d (expected 50)" % weapons.special_cost(club.specials[1], 100))
	print("Heavy Swing at 100 = %d (expected 80)" % weapons.special_cost(club.specials[2], 100))
	print("Kneecaps at 130 = %d (expected 56)" % weapons.special_cost(club.specials[0], 130))
	print("text: %s | %s | %s (expected 30 + 20%% | 10 + 40%% | 30 + 50%%)" % [weapons.cost_text(club.specials[0]), weapons.cost_text(club.specials[1]), weapons.cost_text(club.specials[2])])
	print("a plain special reads %s and %d (expected 25 and 25)" % [weapons.cost_text(weapons.SPEAR.specials[0]), weapons.special_cost(weapons.SPEAR.specials[0], 100)])
	print("a share only (Landfall) reads %s (expected 40%%)" % weapons.cost_text(weapons.STAFF.specials[1]))

	print("--- the hero pays it")
	player.current_weapon = club.duplicate(true)
	for i in 3:
		_reset(main, player)
		player.max_stamina = 100
		player.stamina = 100
		main.battle_units = [_make_goblin(main, Vector2i(1, 4))]
		await main._battle_player_special(i)
		var expect: int = [50, 50, 80][i]
		print("%s took %d stamina (expected %d)" % [club.specials[i].name, 100 - player.stamina, expect])
	# A bigger pool means a bigger bill.
	_reset(main, player)
	player.max_stamina = 160
	player.stamina = 160
	main.battle_units = [_make_goblin(main, Vector2i(1, 4))]
	await main._battle_player_special(0)
	print("Kneecaps at 160 max took %d (expected 62)" % (160 - player.stamina))
	# Short of the price, it refuses.
	_reset(main, player)
	player.max_stamina = 100
	player.stamina = 49
	main.battle_units = [_make_goblin(main, Vector2i(1, 4))]
	await main._battle_player_special(0)
	print("with 49 stamina Kneecaps was refused, stamina still %d (expected 49)" % player.stamina)

	print("--- the Wolf")
	var wolf_kit: Array = kits.specials_for("wolf")
	var druid = player.recruit("druid")
	var fickle = player.recruit("wolf")
	_reset(main, player)
	var u: Dictionary = main._make_member_battle_unit(fickle, Vector2i(1, 4), 1.0)
	print("wolf max stamina %d (expected 150)" % int(u.max_stamina))
	var names := ["Drive-By", "Feed", "Nipper"]
	var costs := {}
	for kit in wolf_kit:
		var s: Dictionary = main._kit_special_for(u, kit)
		costs[str(s.name)] = int(s.stamina_cost)
	print("Drive-By %d Feed %d Nipper %d (expected 80, 70, 40)" % [costs.get("Drive-By", -1), costs.get("Feed", -1), costs.get("Nipper", -1)])
	var fed_before: int = 0
	var fed_hp: int = 0
	u.hp = 10
	u.max_hp = 60
	main.battle_actor = u
	var before: int = int(u.hp)
	main._actor_heal(kits.FEED_KILL_HEAL + int(round(60.0 * kits.FEED_KILL_HEAL_PCT)))
	print("a Feed kill heals 5 + a third of max: %d -> %d (expected 10 -> 35)" % [before, int(u.hp)])
	main.battle_actor = {}
	quit()
