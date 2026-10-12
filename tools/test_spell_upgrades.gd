extends SceneTree

# Spell upgrades (SpellUpgrades.gd): every spell upgrades twice, to + and EX, at the Wizard's Tower. Checks the table, the
# buying, the Tower's Spells tab, and that every one of the twelve spells really casts differently at each level.

const SU := preload("res://scripts/SpellUpgrades.gd")
const KITS := preload("res://scripts/PartyKits.gd")
const SD := preload("res://scripts/SaveData.gd")
const WP := preload("res://scripts/Weapons.gd")

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
	main.battle_ally_target = null
	main.battle_player_tile = Vector2i(0, 4)
	main.battle_target_index = 0
	main.battle_turn = "player"
	main.battle_menu_state = "main"
	main.battle_rally_turns = 0
	main.battle_hero_buff_turns = 0
	main.tutorial_active = false
	main.battle_first_attack_used = true
	main.battle_fainted_members.clear()
	player.shared_talisman_provider = Callable()
	player.max_health = 500
	player.health = 500
	player.max_stamina = 100
	player.stamina = 100

func _filler() -> Dictionary:
	return {"tile": Vector2i(0, 0), "hp": 10, "max_hp": 10, "dmg_mult": 1.0, "name": "Filler", "move_range": 1, "attack_range": 1}

func _special(main, u: Dictionary, special_name: String) -> Dictionary:
	for s in main._ally_specials(u):
		if s.name == special_name:
			return s
	return {}

func _cast(main, u: Dictionary, special_name: String) -> void:
	var filler := _filler()
	main.battle_commanding_ally = u
	main.battle_actor = u
	main.battle_allies = main.battle_allies.filter(func(a): return a != u and a.get("name", "") != "Filler")
	main.battle_allies.append(u)
	main.battle_allies.append(filler)
	main.battle_ally_queue = [filler]
	await main._battle_perform_attack(_special(main, u, special_name))
	main.battle_actor = {}

func _init() -> void:
	seed(20261012)
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	main.enforce_special_loadouts = false
	player.max_party_slots = 20
	player.owned_weapons["staff_fine_steel"] = true
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	# --- the table
	print("Twelve spells, three levels each: %d spells (expected 12), all with numbers and text for 3 levels: %s (expected true)" % [SU.SPELLS.size(), SU.SPELLS.all(func(s): return s.numbers.size() == 3 and s.text.size() == 3)])
	print("Names: %s / %s / %s (expected Restore / Restore+ / Restore EX)" % [SU.display_name("druid_heal", 0), SU.display_name("druid_heal", 1), SU.display_name("druid_heal", 2)])
	var all_real := true
	var kit_ids := {}
	for kind in ["druid", "shaman", "necromancer"]:
		for sp in KITS.specials_for(kind):
			kit_ids[sp.id] = true
	for sp in WP.STAFF.specials:
		kit_ids[sp.id] = true
	for s in SU.SPELLS:
		if not kit_ids.has(s.id):
			all_real = false
	print("Every spell in the table is a real special of a caster or the Staff: %s (expected true)" % [all_real])
	print("Prices: + costs %s, EX costs %s; level 0 and level 3 have none: %s %s (expected {} {})" % [SU.price(1), SU.price(2), SU.price(0), SU.price(3)])

	# --- buying: with banked Essence
	var real_slot: Dictionary = SD.load_data()
	SD.save_data({"essence": 0, "upgrades": {}, "best_wave": 0})
	print("A fresh run has no upgrades: %s (expected {})" % [player.spell_levels])
	print("With no Essence banked you cannot upgrade: %s (expected false), banked %d (expected 0)" % [player.try_upgrade_spell("druid_heal"), SD.banked_essence()])
	player.coins = 5000                                         # coins and shards do not matter any more
	player.runic_shards = 99
	print("...coins and shards do not help: %s (expected false)" % [player.try_upgrade_spell("druid_heal")])
	SD.save_data({"essence": 59, "upgrades": {}, "best_wave": 0})
	print("59 Essence is one short of the first upgrade: %s (expected false), still banked %d (expected 59)" % [player.try_upgrade_spell("druid_heal"), SD.banked_essence()])
	SD.save_data({"essence": 1000, "upgrades": {"strength": 1}, "best_wave": 0})
	var coins_before: int = player.coins
	var shards_before: int = player.runic_shards
	print("Restore -> Restore+: ok=%s (expected true), level %d (expected 1), Essence 1000 -> %d (expected 940)" % [player.try_upgrade_spell("druid_heal"), player.spell_level("druid_heal"), SD.banked_essence()])
	var second_ok: bool = player.try_upgrade_spell("druid_heal")
	print("Restore+ -> Restore EX: ok=%s (expected true), level %d (expected 2), Essence now %d (expected 780)" % [second_ok, player.spell_level("druid_heal"), SD.banked_essence()])
	print("It cost no coins or shards: %s (expected true), and the Church upgrades in the slot are untouched: %s (expected {strength: 1})" % [player.coins == coins_before and player.runic_shards == shards_before, SD.load_data().upgrades])
	print("There is nothing past EX: %s (expected false); and something that is not a spell cannot be bought: %s (expected false)" % [player.try_upgrade_spell("druid_heal"), player.try_upgrade_spell("knight_charge")])
	print("The upgrade is the run's only: a fresh Player has none: %s (expected {})" % [load("res://scripts/Player.gd").new().spell_levels])
	player.spell_levels.clear()

	# --- the Wizard's Tower's Spells tab
	SD.save_data({"essence": 100, "upgrades": {}, "best_wave": 0})
	main._open_shop("enchant")
	print("The Tower shows both tabs: enchant %s, spells %s (expected true, true)" % [main.hud.shop_enchant_tab_button.visible, main.hud.shop_spells_tab_button.visible])
	main.hud._select_shop_tab("spells")
	print("...and the Spells tab lists every spell: %d rows (expected 12), visible=%s (expected true)" % [main.hud.shop_spells_row_nodes.size(), main.hud.shop_spells_scroll.visible])
	var rows0: Array = main.spell_upgrade_rows()
	print("Prices read in Essence: '%s' (expected 60 Essence); with 100 banked every + is affordable but no EX yet: %s (expected true)" % [rows0[0].price_text, rows0.all(func(r): return r.can_buy)])
	main._on_spell_upgrade_pressed("shaman_soothing_rain")
	print("Pressing a row buys it: Soothing Rain level %d (expected 1), Essence left %d (expected 40)" % [player.spell_level("shaman_soothing_rain"), SD.banked_essence()])
	var rows: Array = main.spell_upgrade_rows()
	var rain: Dictionary = rows.filter(func(r): return r.id == "shaman_soothing_rain")[0]
	print("Its row now offers Soothing Rain+ -> Soothing Rain EX for '%s' (expected 160 Essence), which 40 Essence cannot buy: %s (expected false)" % [rain.price_text, rain.can_buy])
	main.hud.hide_shop()
	main.shop_open = false
	paused = false
	player.spell_levels.clear()
	SD.save_data(real_slot)

	# =========================================================
	# the casts, at each level
	# =========================================================
	var druid = player.recruit("druid")
	var shaman = player.recruit("shaman")
	var necro = player.recruit("necromancer")
	var guardian = player.recruit("guardian")
	var heal_ok := true
	var heal_got := []
	for level in 3:
		player.spell_levels["druid_heal"] = level
		_reset(main, player)
		var d: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 4), 1.0)
		d.mods = {}
		d.weapon = {"damage_mult": 1.0}
		d.magic = 30.0
		var hurt: Dictionary = main._make_member_battle_unit(guardian, Vector2i(2, 4), 1.0)
		hurt.max_hp = 100
		hurt.hp = 1
		hurt.mods = {}
		main.battle_allies = [d, hurt]
		main.battle_units = [_make_goblin(main, Vector2i(7, 7))]
		main.battle_ally_target = hurt
		var named: String = str(_special(main, d, SU.display_name("druid_heal", level)).get("name", ""))
		await _cast(main, d, SU.display_name("druid_heal", level))
		main.battle_ally_target = null
		heal_got.append(int(hurt.hp) - 1)
		if named != SU.display_name("druid_heal", level):
			heal_ok = false
	print("Restore heals 25%% + magic/3, then 25%% + magic/2, then 35%% + magic/1.5 (magic 30, 100 max HP): %s (expected [35, 40, 55]), named right at every level: %s (expected true)" % [heal_got, heal_ok])
	player.spell_levels.clear()

	var empower := []
	for level in 3:
		player.spell_levels["druid_buff"] = level
		_reset(main, player)
		var d2: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 4), 1.0)
		d2.mods = {}
		d2.weapon = {"damage_mult": 1.0}
		var buddy: Dictionary = main._make_member_battle_unit(guardian, Vector2i(2, 4), 1.0)
		buddy.mods = {}
		main.battle_allies = [d2, buddy]
		main.battle_units = [_make_goblin(main, Vector2i(7, 7))]
		main.battle_ally_target = buddy
		await _cast(main, d2, SU.display_name("druid_buff", level))
		main.battle_ally_target = null
		empower.append([float(buddy.get("buff_mult", 0.0)), int(buddy.get("buff_turns", 0))])
	print("Empower: x1.5 for 3 turns, x1.75 for 3, x2 for 4: %s (expected [[1.5, 3], [1.75, 3], [2.0, 4]])" % [empower])
	player.spell_levels.clear()

	var vit := []
	for level in 3:
		player.spell_levels["druid_sprint"] = level
		_reset(main, player)
		var d3: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 4), 1.0)
		d3.mods = {}
		d3.weapon = {"damage_mult": 1.0}
		d3.move_range = 4
		main.battle_allies = [d3]
		main.battle_units = [_make_goblin(main, Vector2i(7, 7))]
		main.battle_ally_moves_left = 4
		await _cast(main, d3, SU.display_name("druid_sprint", level))
		vit.append([main.battle_ally_moves_left - 4, d3.get("sprint", false), snappedf(main._sn("druid_sprint", "attack_div"), 0.01)])
	print("Vitalize doubles movement (+4 of 4), then the same, then x2.5 (+6): and her attack divisor goes 2 -> 1.33 -> 1: %s (expected [[4, true, 2.0], [4, true, 1.33], [6, true, 1.0]])" % [vit])
	player.spell_levels.clear()

	var charm := []
	for level in 3:
		player.spell_levels["shaman_how_charming"] = level
		_reset(main, player)
		var s1: Dictionary = main._make_member_battle_unit(shaman, Vector2i(3, 4), 1.0)
		s1.weapon = {"damage_mult": 1.0}
		main.battle_allies = [s1]
		main.battle_units = [_make_goblin(main, Vector2i(7, 0))]
		await _cast(main, s1, SU.display_name("shaman_how_charming", level))
		charm.append([int(s1.get("charm_radius", 0)), int(s1.get("charm_turns", 0))])
	print("How Charming reaches 4 tiles for 2 turns, 4 for 3, 5 for 4: %s (expected [[4, 2], [4, 3], [5, 4]])" % [charm])
	player.spell_levels.clear()

	var rain_got := []
	for level in 3:
		player.spell_levels["shaman_soothing_rain"] = level
		_reset(main, player)
		var s2: Dictionary = main._make_member_battle_unit(shaman, Vector2i(3, 4), 1.0)
		s2.weapon = {"damage_mult": 1.0}
		s2.mods = {}
		var near: Dictionary = main._make_member_battle_unit(guardian, Vector2i(3, 6), 1.0)
		var far: Dictionary = main._make_member_battle_unit(guardian, Vector2i(3, 7), 1.0)
		for a in [near, far]:
			a.mods = {}
			a.max_hp = 100
			a.hp = 1
		main.battle_player_tile = Vector2i(0, 0)
		main.battle_allies = [s2, near, far]
		main.battle_units = [_make_goblin(main, Vector2i(7, 0))]
		s2.mana = s2.max_mana
		await _cast(main, s2, SU.display_name("shaman_soothing_rain", level))
		rain_got.append([int(near.hp) - 1, int(far.hp) - 1])
	print("Soothing Rain heals 20%%, 30%%, 40%% (and at EX reaches the ally 3 tiles off): %s (expected [[20, 0], [30, 0], [40, 40]])" % [rain_got])
	player.spell_levels.clear()

	var chant_got := []
	for level in 3:
		player.spell_levels["shaman_cleansing_chant"] = level
		_reset(main, player)
		var s3: Dictionary = main._make_member_battle_unit(shaman, Vector2i(3, 4), 1.0)
		s3.weapon = {"damage_mult": 1.0}
		var close: Dictionary = main._make_member_battle_unit(guardian, Vector2i(3, 5), 1.0)
		var distant: Dictionary = main._make_member_battle_unit(guardian, Vector2i(3, 7), 1.0)
		for a in [close, distant]:
			a.mods = {}
			a.disarmed_tile = Vector2i(6, 6)
			a.skip_turns = 2
		main.battle_player_tile = Vector2i(0, 0)
		main.battle_allies = [s3, close, distant]
		main.battle_units = [_make_goblin(main, Vector2i(7, 0))]
		s3.mana = s3.max_mana
		main.battle_ally_target = "area"
		await _cast(main, s3, SU.display_name("shaman_cleansing_chant", level))
		main.battle_ally_target = null
		# [how many of the close ally's two afflictions went, how many of the distant (3 tiles) one's went]
		chant_got.append([int(close.disarmed_tile == Vector2i(-1, -1)) + int(close.skip_turns == 0), int(distant.disarmed_tile == Vector2i(-1, -1)) + int(distant.skip_turns == 0)])
	print("Cleansing Chant: one status each within 2 tiles; within 3 at +; every affliction from everyone at EX: %s (expected [[1, 0], [1, 1], [2, 2]])" % [chant_got])
	player.spell_levels.clear()

	var rot := []
	for level in 3:
		player.spell_levels["necromancer_curse_of_rot"] = level
		_reset(main, player)
		var n1: Dictionary = main._make_member_battle_unit(necro, Vector2i(1, 4), 1.0)
		n1.mods = {}
		n1.weapon = {"damage_mult": 1.0}
		var cursed := _make_goblin(main, Vector2i(2, 4), 100)
		main.battle_allies = [n1]
		main.battle_units = [cursed, _make_goblin(main, Vector2i(7, 7), 999)]
		await _cast(main, n1, SU.display_name("necromancer_curse_of_rot", level))
		var hp_before: int = int(cursed.hp)
		main.battle_allies = [n1, _filler()]
		await main._process_enemy_turn()
		rot.append([int(cursed.get("rot_turns", 0)) + 1, hp_before - int(cursed.hp)])
	print("Curse of Rot: 10%% a turn for 5 turns, 12%% for 5, 15%% for 6 (a goblin of 100 HP loses 10 / 12 / 15 in its first tick): %s (expected [[5, 10], [5, 12], [6, 15]])" % [rot])
	player.spell_levels.clear()

	var revive := []
	for level in 3:
		player.spell_levels["necromancer_revival_blessing"] = level
		_reset(main, player)
		var n2: Dictionary = main._make_member_battle_unit(necro, Vector2i(1, 4), 1.0)
		n2.mods = {}
		n2.weapon = {"damage_mult": 1.0}
		n2.max_hp = 40
		n2.hp = 40
		revive.append(int(_special(main, n2, SU.display_name("necromancer_revival_blessing", level)).stamina_cost) / int(main.MANA_PER_HP))
	print("Revival Blessing leaves the Necromancer 1 HP, then 25%%, then half (of 40): it costs %s HP (expected [39, 30, 20])" % [revive])
	player.spell_levels.clear()

	var skel := []
	for level in 3:
		player.spell_levels["necromancer_summon_the_dead"] = level
		_reset(main, player)
		var n3: Dictionary = main._make_member_battle_unit(necro, Vector2i(3, 4), 1.0)
		n3.mods = {}
		n3.weapon = {"damage_mult": 1.0}
		n3.max_hp = 40
		n3.hp = 40
		necro.kills_last_battle = 2
		main.battle_allies = [n3]
		main.battle_units = [_make_goblin(main, Vector2i(7, 4), 50)]
		await _cast(main, n3, SU.display_name("necromancer_summon_the_dead", level))
		var raised: Array = main.battle_allies.filter(func(a): return a.get("kind", "") == "skeleton")
		skel.append([raised.size(), int(raised[0].hp) if raised.size() > 0 else 0, int(raised[0].attack) if raised.size() > 0 else 0, 40 - int(n3.hp)])
	print("Summon the Dead (2 kills): skeletons of 1 HP / 4 damage at 5 HP each, 2 HP / 6 at 5, 3 HP / 8 at 4: %s (expected [[2, 1, 4, 10], [2, 2, 6, 10], [2, 3, 8, 8]])" % [skel])
	player.spell_levels.clear()
	necro.kills_last_battle = 0

	# the Staff
	player.equip_ally_weapon(druid, "staff_fine_steel")
	var fire := []
	for level in 3:
		player.spell_levels["staff_i_cast_fireball"] = level
		_reset(main, player)
		var d4: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 4), 1.0)
		d4.mods = {}
		d4.magic = 20.0
		var centre := _make_goblin(main, Vector2i(5, 4), 9999)
		var side := _make_goblin(main, Vector2i(6, 4), 9999)
		main.battle_allies = [d4]
		main.battle_units = [centre, side]
		d4.mana = d4.max_mana
		var charge: String = SU.display_name("staff_i_cast_fireball", level)
		await _cast(main, d4, charge)
		main.battle_target_index = 0
		await _cast(main, d4, "Release: %s" % charge)
		fire.append([9999 - int(centre.hp), (9999 - int(centre.hp)) - (9999 - int(side.hp))])
	print("I CAST FIREBALL: the centre takes more at each level (%s, expected rising) and the blast fades 5 per tile, 5, then 4: %s (expected [5, 5, 4])" % [[fire[0][0], fire[1][0], fire[2][0]], [fire[0][1], fire[1][1], fire[2][1]]])
	player.spell_levels.clear()

	var land := []
	for level in 3:
		player.spell_levels["staff_landfall"] = level
		_reset(main, player)
		var d5: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 4), 1.0)
		d5.mods = {}
		d5.attack = 10.0
		d5.magic = 20.0
		var dummy := _make_goblin(main, Vector2i(6, 4), 9999)
		main.battle_allies = [d5]
		main.battle_units = [dummy]
		d5.mana = d5.max_mana
		await _cast(main, d5, SU.display_name("staff_landfall", level))
		land.append(9999 - int(dummy.hp))
	print("Landfall: (attack x 3) + (magic x .5) = 40, then x 3.5 + .65 = 48, then x 4 + .8 = 56 (attack 10, magic 20): %s (expected [40, 48, 56])" % [land])
	player.spell_levels.clear()

	var chan := []
	for level in 3:
		player.spell_levels["staff_channel"] = level
		_reset(main, player)
		var d6: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 4), 1.0)
		d6.mods = {}
		var friend: Dictionary = main._make_member_battle_unit(shaman, Vector2i(2, 4), 1.0)
		friend.mods = {}
		friend.mana = 0
		main.battle_allies = [d6, friend]
		main.battle_units = [_make_goblin(main, Vector2i(7, 7))]
		d6.mana = d6.max_mana
		main.battle_ally_target = friend
		await _cast(main, d6, SU.display_name("staff_channel", level))
		main.battle_ally_target = null
		chan.append(int(round(100.0 * float(friend.mana) / float(friend.max_mana))))
	print("Channel restores 20%%, 30%%, 40%% of an ally's mana: %s (expected [20, 30, 40])" % [chan])
	player.spell_levels.clear()

	# the Party screen and the command menu show the upgraded names
	player.spell_levels["druid_heal"] = 2
	player.spell_levels["staff_landfall"] = 1
	var du: Dictionary = main.member_preview(druid)
	var names: Array = main._ally_special_pool(du).map(func(s): return s.name)
	print("The command menu and Party screen use the upgraded names: Restore EX in %s (expected true), Landfall+ in %s (expected true)" % [names.has("Restore EX"), names.has("Landfall+")])
	quit()
