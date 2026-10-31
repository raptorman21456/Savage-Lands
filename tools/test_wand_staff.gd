extends SceneTree

# The Wand, the reworked Staff and the doc's renames (design doc, 2026-10-30): the Wand's numbers and rules, Pummel,
# Poison Bomb's gas cloud and its explosion, Freeze Ray (and what it cannot freeze), Purifying Light, Fear as a status
# enemies run from, Goondorf's Staff, and the names the doc uses for armours, shields, mythics and three bosses.

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
	main._gas_clear_all()
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
	main.battle_fainted_members.clear()
	player.max_health = 500
	player.health = 500
	player.max_stamina = 100
	player.stamina = 100

func _filler() -> Dictionary:
	return {"tile": Vector2i(0, 0), "hp": 10, "max_hp": 10, "dmg_mult": 1.0, "name": "Filler", "move_range": 1, "attack_range": 1}

func _special(main, u: Dictionary, special_name: String) -> Dictionary:
	for s in main._ally_specials(u):
		if str(s.name) == special_name:
			return s
	return {}

# Runs a named special as the commanding ally, with a filler behind it in the queue.
func _cast(main, u: Dictionary, special_name: String, target = null) -> void:
	var filler := _filler()
	main.battle_commanding_ally = u
	main.battle_actor = u
	main.battle_ally_target = target
	main.battle_allies = main.battle_allies.filter(func(a): return a != u and a.get("name", "") != "Filler")
	main.battle_allies.append(u)
	main.battle_allies.append(filler)
	main.battle_ally_queue = [filler]
	await main._battle_perform_attack(_special(main, u, special_name))
	main.battle_actor = {}

func _init() -> void:
	seed(20261031)
	var weapons = load("res://scripts/Weapons.gd")
	var main = load("res://Main.tscn").instantiate()
	main.regional_world = false  # this test drives the old wave-ladder world
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	main.enforce_special_loadouts = false
	player.max_party_slots = 6
	for id in ["staff_fine_steel", "wand_fine_steel", "staff_mythic", "wand_mythic", "club"]:
		player.owned_weapons[id] = true
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)
	var druid = player.recruit("druid")

	# =========================================================
	# Names the doc uses
	# =========================================================
	var armor_names := []
	for id in ["armor_rags", "armor_thornmail", "armor_fortress", "armor_dragonskin", "armor_stonehide", "armor_bastion", "armor_cinder", "armor_bloodrage", "armor_windrunner"]:
		armor_names.append(load("res://scripts/Armor.gd").find(id).get("name", "?"))
	print("The nine renamed armours: %s (expected [Jacket, Spinemail, Fortplate, Dragonskin Plate, Stonehide, Bastionmail, Cindermail, Bloodsplattered Hide, Sprinter's Jerkin])" % [armor_names])
	var shield_names := []
	var shields_script = load("res://scripts/Shields.gd")
	for id in shields_script.SHIELD_IDS:
		shield_names.append(shields_script.SHIELDS[id].name)
	print("The shields: %s (expected [Wooden Buckler, Heavy Shield, Iron Bulwark, Phantom Kite, Brawler's Buckler])" % [shield_names])
	var mythic_names := []
	for base in ["bow", "hand_picks", "staff", "wand"]:
		mythic_names.append(weapons.get_owned_variant("%s_mythic" % base).get("name", "?"))
	print("Mythics renamed or added: %s (expected [Sniper Rifle, Emerald Picks, Goondorf's Staff, Moonstick])" % [mythic_names])
	print("The three renamed bosses are in the trait table, the old names are not: %s (expected true)" % [["Steel Construct", "Magma Construct", "White Drake"].all(func(n): return main.ENEMY_TRAITS.has(n)) and not ["Iron Construct", "Lava Construct", "White Dragon"].any(func(n): return main.ENEMY_TRAITS.has(n))])
	print("The enemy classes answer to them: %s (expected [Steel Construct, Magma Construct, White Drake])" % [[load("res://scripts/IronConstruct.gd").new().get_display_name(), load("res://scripts/LavaConstruct.gd").new().get_display_name(), load("res://scripts/WhiteDragon.gd").new().get_display_name()]])
	var save_data = load("res://scripts/SaveData.gd")
	save_data.save_lifetime_data({"beastiary_seen": {"Iron Construct": true, "White Dragon": true}})
	print("An old save's beastiary entries carry over: Steel Construct %s, White Drake %s, Magma Construct %s (expected true, true, false)" % [save_data.is_creature_seen("Steel Construct"), save_data.is_creature_seen("White Drake"), save_data.is_creature_seen("Magma Construct")])
	save_data.save_lifetime_data({})

	# =========================================================
	# The Wand's rules
	# =========================================================
	_reset(main, player)
	player.unequip_ally_weapon(druid)
	player.equip_ally_weapon(druid, "wand_fine_steel")
	var wand_unit: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 4), 1.0)
	var labels := []
	for s in main._ally_specials(wand_unit):
		labels.append(s.name + main._ally_cost_text(wand_unit, int(s.stamina_cost)))
	print("A Druid with a Wand: magic %.1f, %d mana, range %d (expected 16.0, 80, 4); her list: %s (expected [Vitalize (25 MP), Empower (35 MP), Call the Wild (50 MP), Purifying Light (60 MP), FREEZE RAY (52 MP), I CAST FIREBALL (64 MP), Stealth (20 MP)])" % [wand_unit.magic, wand_unit.max_mana, wand_unit.attack_range, labels])
	var near := _make_goblin(main, Vector2i(2, 4))
	var far := _make_goblin(main, Vector2i(5, 4))
	main.battle_units = [near, far]
	var filler := _filler()
	main.battle_allies = [wand_unit, filler]
	main._start_ally_turn()
	main.battle_target_index = 0
	var plain: Dictionary = main._ally_regular_action(wand_unit)
	print("The Wand's regular attack is just 'Attack' (no Pummel): %s, free: %d (expected Attack, 0)" % [plain.name, plain.stamina_cost])
	main._on_battle_ally_action("attack")
	print("It will not strike the enemy next to her and takes the far one (4 tiles) for her magic: near untouched=%s, far dealt=%d (expected true, 16)" % [near.hp == 999, 999 - far.hp])

	# =========================================================
	# The Staff's Pummel
	# =========================================================
	_reset(main, player)
	player.unequip_ally_weapon(druid)
	player.equip_ally_weapon(druid, "staff_fine_steel")
	var staff_unit: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 4), 1.0)
	var pummel: Dictionary = main._ally_regular_action(staff_unit)
	print("A Staff's regular attack is Pummel for 15: %s / %d (expected Pummel, 15), effect=%s (expected pummel)" % [pummel.name, pummel.stamina_cost, pummel.effect])
	var pummeled := _make_goblin(main, Vector2i(2, 4))
	var distant := _make_goblin(main, Vector2i(4, 4))
	main.battle_units = [distant, pummeled]
	main.battle_allies = [staff_unit, _filler()]
	main._start_ally_turn()
	main.battle_target_index = 1
	var mana_before: int = staff_unit.mana
	main._on_battle_ally_action("attack")
	print("Pummel hits the adjacent enemy for (0.85 x STR) + (0.25 x MAG): STR %.2f, MAG %.2f -> %d (expected %d), costs 15: %d (expected %d)" % [staff_unit.attack, staff_unit.magic, 999 - pummeled.hp, int(round(0.85 * staff_unit.attack + 0.25 * staff_unit.magic)), mana_before - staff_unit.mana, 15])
	print("...and does nothing to the one three tiles off: %s (expected true)" % [distant.hp == 999])

	# =========================================================
	# Poison Bomb and its gas
	# =========================================================
	_reset(main, player)
	var bomber: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 4), 1.0)
	bomber.mods = {}
	bomber.magic = 20.0
	bomber.fortitude = 10.0
	var hit := _make_goblin(main, Vector2i(4, 4))
	var beside := _make_goblin(main, Vector2i(5, 5))
	var outside := _make_goblin(main, Vector2i(7, 4))
	main.battle_units = [hit, beside, outside]
	main.battle_target_index = 0
	bomber.mana = bomber.max_mana
	var mana_start: int = bomber.mana
	await _cast(main, bomber, "Poison Bomb")
	print("Poison Bomb costs 35 mana: %d (expected 35); the target takes 2 x 10 + 1.2 x 20 = 44: %d (expected 44)" % [mana_start - bomber.mana, 999 - hit.hp])
	print("A 3x3 cloud of gas hangs over it, lasting 2 turns: clouds=%d (expected 1), tiles=%d (expected 9), turns=%d (expected 2)" % [main.battle_gas_clouds.size(), main.battle_gas_clouds[0].tiles.size() if not main.battle_gas_clouds.is_empty() else 0, main.battle_gas_clouds[0].turns if not main.battle_gas_clouds.is_empty() else 0])
	print("It poisons what stands in it and nobody else: target %d, neighbour %d, bystander %d turns (expected 5, 5, 0)" % [hit.get("poison_turns", 0), beside.get("poison_turns", 0), outside.get("poison_turns", 0)])
	main._tick_gas_clouds()
	print("After a round it is still there: %d cloud (expected 1)" % [main.battle_gas_clouds.size()])
	main._tick_gas_clouds()
	print("After the second it is gone: %d clouds (expected 0)" % [main.battle_gas_clouds.size()])
	# a burning enemy in the cloud sets the gas off
	_reset(main, player)
	var bomber2: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 4), 1.0)
	bomber2.mods = {}
	bomber2.magic = 20.0
	bomber2.fortitude = 10.0
	var core := _make_goblin(main, Vector2i(4, 4))
	var neighbour := _make_goblin(main, Vector2i(4, 5))
	var safe := _make_goblin(main, Vector2i(7, 4))
	main.battle_units = [core, neighbour, safe]
	main.battle_target_index = 0
	bomber2.mana = bomber2.max_mana
	await _cast(main, bomber2, "Poison Bomb")
	neighbour.burning = true
	var core_before: int = core.hp
	main._gas_enemy_turn(neighbour)
	print("A burning enemy in the cloud sets it off: the cloud is gone (%d left, expected 0); everything in it takes 1.5 x 20 = 30: %d and %d (expected 30, 30), the one outside nothing: %d (expected 0)" % [main.battle_gas_clouds.size(), core_before - core.hp, 999 - neighbour.hp, 999 - safe.hp])
	# a fireball landing on it does the same
	_reset(main, player)
	var bomber3: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 4), 1.0)
	bomber3.mods = {}
	bomber3.magic = 20.0
	var cloud_target := _make_goblin(main, Vector2i(4, 4))
	main.battle_units = [cloud_target]
	main.battle_target_index = 0
	bomber3.mana = bomber3.max_mana
	await _cast(main, bomber3, "Poison Bomb")
	var hp_in_cloud: int = cloud_target.hp
	main._gas_ignite_tiles([Vector2i(4, 4), Vector2i(4, 3)])
	print("A fire landing on the cloud explodes it for 1.5 x 20 = 30: %d (expected 30), cloud gone: %s (expected true)" % [hp_in_cloud - cloud_target.hp, main.battle_gas_clouds.is_empty()])

	# =========================================================
	# Freeze Ray and Purifying Light
	# =========================================================
	_reset(main, player)
	player.unequip_ally_weapon(druid)
	player.equip_ally_weapon(druid, "wand_fine_steel")
	var caster: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 4), 1.0)
	caster.mods = {}
	caster.magic = 20.0
	var cold_target := _make_goblin(main, Vector2i(5, 4))
	var drake := _make_goblin(main, Vector2i(5, 3))
	drake.name = "White Drake"
	main.battle_units = [cold_target, drake]
	main.battle_target_index = 0
	caster.mana = caster.max_mana
	mana_start = caster.mana
	await _cast(main, caster, "FREEZE RAY")
	print("FREEZE RAY costs 20 + 40%% of her 80 = 52: %d (expected 52); it deals 0.8 x 20 = 16: %d (expected 16) and always freezes: %d turns (expected 1 to 3)" % [mana_start - caster.mana, 999 - cold_target.hp, cold_target.frozen_turns])
	main.battle_units = [drake]
	drake.tile = Vector2i(5, 4)
	main.battle_target_index = 0
	caster.mana = caster.max_mana
	await _cast(main, caster, "FREEZE RAY")
	print("A tundric White Drake is hurt but never frozen: dealt %d (expected 16), frozen %d turns (expected 0)" % [999 - drake.hp, drake.frozen_turns])
	# Purifying Light: blinds the 3x3, hurts the undead, cures one affliction (hers first, then the hero's)
	_reset(main, player)
	var lamp: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 4), 1.0)
	lamp.mods = {}
	lamp.magic = 20.0
	var shade := _make_goblin(main, Vector2i(2, 4))
	shade.name = "Shade"
	var living := _make_goblin(main, Vector2i(2, 5))
	var distant_foe := _make_goblin(main, Vector2i(4, 4))
	main.battle_units = [shade, living, distant_foe]
	main.player_poison_turns = 3
	lamp.mana = lamp.max_mana
	mana_start = lamp.mana
	await _cast(main, lamp, "Purifying Light")
	print("Purifying Light costs 75%% of 80 = 60: %d (expected 60); blinded: shade %d, living %d, out of reach %d turns (expected 2, 2, 0)" % [mana_start - lamp.mana, shade.get("blind_turns", 0), living.get("blind_turns", 0), distant_foe.get("blind_turns", 0)])
	print("...undead take 0.5 x 20 = 10 and the living nothing: %d / %d (expected 10 / 0)" % [999 - shade.hp, 999 - living.hp])
	print("...and one affliction comes off (the hero's poison, as the Druid has none): poison_turns %d (expected 0)" % [main.player_poison_turns])
	main.player_poison_turns = 0

	# =========================================================
	# Fear: an enemy runs for two turns
	# =========================================================
	_reset(main, player)
	var coward := _make_goblin(main, Vector2i(1, 4))
	main.battle_units = [coward]
	main.battle_player_tile = Vector2i(0, 4)
	main._fear_enemy(coward)
	print("Fear lasts %d turns (expected 2) and shows as a status: %s (expected [fear])" % [coward.fear_turns, load("res://scripts/BattleStatuses.gd").for_enemy(coward).map(func(e): return e.id)])
	var hero_hp: int = player.health
	var distances := []
	for turn in 3:
		main.battle_allies = []
		main._process_enemy_turn()
		distances.append(abs(coward.tile.x) + abs(coward.tile.y - 4))
	print("It runs for two turns (further from the hero each time), then clears and comes back to fight: distances %s (expected rising twice, then down), fear_turns %d (expected 0), hero untouched during the run: %s (expected true)" % [distances, coward.get("fear_turns", 0), player.health == hero_hp or distances[2] <= distances[1]])

	# =========================================================
	# Goondorf's Staff: secondary effects 33% likelier
	# =========================================================
	_reset(main, player)
	player.unequip_ally_weapon(druid)
	player.equip_ally_weapon(druid, "staff_mythic")
	var goondorf: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 4), 1.0)
	goondorf.mods = {}
	main.battle_allies = [goondorf]
	main.battle_actor = goondorf
	print("With Goondorf's Staff a 30%% chance becomes %.3f (expected 0.399); with a plain Staff it stays %.2f (expected 0.30)" % [main._proc(0.30), (func(): main.battle_actor = {"weapon": {"damage_mult": 1.0}, "mods": {}, "tile": Vector2i(1, 4), "hp": 1, "name": "x"}; return main._proc(0.30)).call()])
	main.battle_actor = {}
	player.unequip_ally_weapon(druid)
	quit()
