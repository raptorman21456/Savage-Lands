extends SceneTree

# The Sorcery wing's talismans (Clapback, Heavy Cloak, Spell Bank, Dreamcatcher, Snail Shell, Lingering Echo, Blazing Battery, Loud Whistle -- the
# design doc's list of 2026-10-27) and the Astral Sorcery passives that share their hooks (Player.meta_*): every member can wear them, they only do
# anything for whoever casts, and a Necromancer's mana is her HP.

func _make_goblin(main, tile: Vector2i, hp: int = 999, unit_name: String = "Goblin") -> Dictionary:
	var g = load("res://scripts/Enemy.gd").new()
	main.add_child(g)
	g.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	return {
		"ref": g, "tile": tile, "hp": hp, "max_hp": hp, "move_range": 2, "damage": 1,
		"name": unit_name, "winding_up": false, "stunned": false, "attack_range": 1,
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
	main.battle_fainted_members.clear()
	player.max_health = 500
	player.health = 100
	player.max_stamina = 100
	player.stamina = 100
	player.meta_release_grudge = false
	player.meta_spell_potency_pct = 0.0
	player.meta_max_mana_flat = 0
	player.meta_member_magic_per_level = 0.0

func _filler() -> Dictionary:
	return {"tile": Vector2i(0, 0), "hp": 10, "max_hp": 10, "dmg_mult": 1.0, "name": "Filler", "move_range": 1, "attack_range": 1}

func _wear(player, member, id: String) -> bool:
	player.owned_talismans[id] = true
	return player.equip_ally_talisman(member, id)

func _unit(main, player, kind: String, weapon_id: String, tile: Vector2i, talismans: Array = []) -> Dictionary:
	player.party.clear()      # one of each kind, and an item has one holder: start from nobody every time
	var member = player.recruit(kind)
	if weapon_id != "":
		player.owned_weapons[weapon_id] = true
		player.equip_ally_weapon(member, weapon_id)
	for t in talismans:
		_wear(player, member, t)
	return main._make_member_battle_unit(member, tile, 1.0)

# The position of a special in the unit's menu by (the start of) its name.
func _special(main, u: Dictionary, prefix: String) -> int:
	var list: Array = main._ally_specials(u)
	for i in list.size():
		if str(list[i].name).begins_with(prefix):
			return i
	return -1

func _cost_of(main, u: Dictionary, prefix: String) -> int:
	var i := _special(main, u, prefix)
	return int(main._ally_specials(u)[i].stamina_cost) if i >= 0 else -1

func _begin(main, u: Dictionary, foes: Array) -> void:
	main.battle_units = foes
	main.battle_allies = [u, _filler()]
	main._start_ally_turn()

func _init() -> void:
	# Magic from a Staff or Wand used to be a flat +5 / +6; the doc's per-quality-tier version (test_weapon_stat_bonuses.gd) gives a Fine one
	# (the second rung) the same figures at 2.5 / 3.0 a tier, so these checks keep the numbers they were written against.
	var _magic_weapons = load("res://scripts/Weapons.gd")
	_magic_weapons.STAFF["magic_per_tier"] = 2.5
	_magic_weapons.WAND["magic_per_tier"] = 3.0
	# These checks predate the doc's flat weapon Strength (Club +2, Spear +4 per quality tier...), which has its own test
	# (test_weapon_stat_bonuses.gd): here weapons add nothing, so every damage figure below stays as it was.
	var _stat_weapons = load("res://scripts/Weapons.gd")
	_stat_weapons.CLUB["str_bonus"] = 0
	for _stat_base in _stat_weapons.UPGRADABLE_TYPES:
		_stat_base["str_per_tier"] = 0
	seed(20261018)
	var main = load("res://Main.tscn").instantiate()
	main.regional_world = false
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	main.enforce_special_loadouts = false
	player.max_party_slots = 6
	player.level = 20
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)
	await process_frame
	await process_frame
	var tal = load("res://scripts/Talismans.gd")

	# =========================================================
	# The items
	# =========================================================
	var ids := ["clapback", "heavy_cloak", "spell_bank", "dreamcatcher", "snail_shell", "lingering_echo", "blazing_battery", "loud_whistle"]
	var present := ids.filter(func(i): return not tal.get_talisman(i).is_empty())
	print("All eight Sorcery talismans exist: %d (expected 8)" % [present.size()])
	var lore_ok := true
	for i in ids:
		if ItemLore.talisman(i).is_empty():
			lore_ok = false
	print("...each has lore: %s (expected true)" % [lore_ok])
	_reset(main, player)
	var druid_m = player.recruit("druid")
	var knight_m = player.recruit("knight")
	var all_wearable := true
	for i in ids:
		player.owned_talismans[i] = true
	for i in ids:
		if player.ally_talisman_block_reason(druid_m, i) != "" or player.ally_talisman_block_reason(knight_m, i) != "":
			all_wearable = false
	print("Every member can wear every one of them (no member-specific talismans): %s (expected true)" % [all_wearable])

	# =========================================================
	# Deep Well: max mana (a Necromancer's is her HP)
	# =========================================================
	_reset(main, player)
	var plain: Dictionary = _unit(main, player, "druid", "staff_fine_steel", Vector2i(1, 4))
	player.meta_max_mana_flat = 20
	var deep: Dictionary = _unit(main, player, "druid", "staff_fine_steel", Vector2i(1, 4))
	print("Deep Well adds a flat 20 mana: %d -> %d (expected %d)" % [plain.max_mana, deep.max_mana, plain.max_mana + 20])
	player.meta_max_mana_flat = 0
	var necro_plain: Dictionary = _unit(main, player, "necromancer", "staff_worn_bone", Vector2i(1, 4))
	player.meta_max_mana_flat = 20
	var necro_deep: Dictionary = _unit(main, player, "necromancer", "staff_worn_wood", Vector2i(1, 4))
	print("...a Necromancer's mana is her HP, so 20 mana is 4 HP for her: %d -> %d (expected %d)" % [necro_plain.max_hp, necro_deep.max_hp, necro_plain.max_hp + 4])
	player.meta_max_mana_flat = 0

	# Release Grudge: +1 Magic for every level a member has gained (not the hero)
	var trained_m = player.recruit("druid")
	trained_m.level = 5
	var before_magic: float = main._make_member_battle_unit(trained_m, Vector2i(1, 4), 1.0).magic
	player.meta_member_magic_per_level = 1.0
	var after_magic: float = main._make_member_battle_unit(trained_m, Vector2i(1, 4), 1.0).magic
	print("Release Grudge adds 1 magic per level gained (4 levels): %.1f -> %.1f (expected +4.0)" % [before_magic, after_magic])
	player.meta_member_magic_per_level = 0.0

	# =========================================================
	# Dreamcatcher: spells cost 33% less
	# =========================================================
	_reset(main, player)
	var base_cost: int = _cost_of(main, plain, "Vitalize")
	var thrifty: Dictionary = _unit(main, player, "druid", "staff_fine_steel", Vector2i(1, 4), ["dreamcatcher"])
	print("Dreamcatcher makes Vitalize cost 33%% less mana: %d -> %d (expected %d)" % [base_cost, _cost_of(main, thrifty, "Vitalize"), int(round(base_cost * 0.67))])
	var wand_plain: Dictionary = _unit(main, player, "druid", "wand_worn_wood", Vector2i(1, 4))
	var wand_thrifty: Dictionary = _unit(main, player, "druid", "wand_worn_bone", Vector2i(1, 4), ["dreamcatcher"])
	print("...and the Wand's I CAST FIREBALL too: %d -> %d (expected %d)" % [_cost_of(main, wand_plain, "I CAST FIREBALL"), _cost_of(main, wand_thrifty, "I CAST FIREBALL"), int(round(_cost_of(main, wand_plain, "I CAST FIREBALL") * 0.67))])
	var necro_cost: int = _cost_of(main, necro_plain, "Curse of Rot")
	var necro_thrifty: Dictionary = _unit(main, player, "necromancer", "staff_worn_wood", Vector2i(1, 4), ["dreamcatcher"])
	print("A Necromancer pays 33%% less HP on Curse of Rot: %d -> %d (expected %d mana-worth)" % [necro_cost, _cost_of(main, necro_thrifty, "Curse of Rot"), int(round(necro_cost * 0.67))])
	var knight_plain: Dictionary = _unit(main, player, "knight", "staff_worn_wood", Vector2i(1, 4))
	var knight_thrifty: Dictionary = _unit(main, player, "knight", "staff_worn_bone", Vector2i(1, 4), ["dreamcatcher"])
	print("A fighter pays stamina, which the Dreamcatcher leaves alone: I SUMMON THEE %d vs %d (expected equal)" % [_cost_of(main, knight_plain, "I SUMMON THEE"), _cost_of(main, knight_thrifty, "I SUMMON THEE")])

	# =========================================================
	# Snail Shell and Innate Power: potency, added together
	# =========================================================
	_reset(main, player)
	var shelled: Dictionary = _unit(main, player, "druid", "staff_fine_steel", Vector2i(1, 4), ["snail_shell"])
	print("Snail Shell: potency 1.25 (%.2f); with Innate Power's 33%% added: %.2f (expected 1.25, 1.58)" % [main._potency(shelled), (func(): player.meta_spell_potency_pct = 0.33; return main._potency(shelled)).call()])
	player.meta_spell_potency_pct = 0.0
	# Vitalize heals the hero for 25% of max HP plus a third of her magic -- both scaled by potency
	_reset(main, player)
	_begin(main, plain, [_make_goblin(main, Vector2i(6, 6))])
	main._on_battle_ally_action("special")
	main._on_battle_ally_action("special_%d" % _special(main, plain, "Vitalize"))
	main._on_battle_ally_action("pick_0")
	var healed_plain: int = player.health - 100
	_reset(main, player)
	shelled = _unit(main, player, "druid", "staff_fine_steel", Vector2i(1, 4), ["snail_shell"])
	_begin(main, shelled, [_make_goblin(main, Vector2i(6, 6))])
	main._on_battle_ally_action("special")
	main._on_battle_ally_action("special_%d" % _special(main, shelled, "Vitalize"))
	main._on_battle_ally_action("pick_0")
	var healed_shelled: int = player.health - 100
	print("Vitalize heals %d plain and %d with the Snail Shell (expected about %d, 25%% more)" % [healed_plain, healed_shelled, int(round(healed_plain * 1.25))])

	# =========================================================
	# Lingering Echo: the spell comes round again, free, and the target is chosen afresh
	# =========================================================
	_reset(main, player)
	var echoer: Dictionary = _unit(main, player, "druid", "staff_fine_steel", Vector2i(1, 4), ["lingering_echo"])
	print("Lingering Echo is worth 10%% a cast: %.2f (expected 0.10)" % [echoer.mods.get("spell_echo_chance", 0.0)])
	echoer.mods["spell_echo_chance"] = 1.0   # make the roll certain
	_begin(main, echoer, [_make_goblin(main, Vector2i(6, 6))])
	var mana_start: int = echoer.mana
	var restore_cost: int = _cost_of(main, echoer, "Vitalize")
	main._on_battle_ally_action("special")
	main._on_battle_ally_action("special_%d" % _special(main, echoer, "Vitalize"))
	main._on_battle_ally_action("pick_0")
	var after_first: int = player.health
	var left_open: bool = main.battle_commanding_ally == echoer
	var echo_list: Array = main._ally_specials(echoer)
	print("Casting Vitalize costs %d mana and the command stays open for the echo: paid=%d open=%s (expected %d, true)" % [restore_cost, mana_start - echoer.mana, left_open, restore_cost])
	print("...the menu offers just the free recast: %s (expected [Echo: Vitalize] at cost 0)" % [echo_list.map(func(s): return "%s @%d" % [s.name, s.stamina_cost])])
	main._on_battle_ally_action("special")
	main._on_battle_ally_action("special_0")
	main._on_battle_ally_action("pick_0")
	print("The recast heals again and costs nothing: hero HP %d -> %d, mana paid in total %d (expected a second heal, %d)" % [after_first, player.health, mana_start - echoer.mana, restore_cost])
	print("...and the command is over, with no echo left: commanding is the next unit=%s echo=%s (expected true, {})" % [main.battle_commanding_ally != echoer, echoer.get("echo", {})])
	# Echo with the chance at nothing never happens
	_reset(main, player)
	var plain2: Dictionary = _unit(main, player, "druid", "staff_fine_steel", Vector2i(1, 4))
	_begin(main, plain2, [_make_goblin(main, Vector2i(6, 6))])
	main._on_battle_ally_action("special")
	main._on_battle_ally_action("special_%d" % _special(main, plain2, "Vitalize"))
	main._on_battle_ally_action("pick_0")
	print("With no Echo the command simply ends: %s (expected true)" % [main.battle_commanding_ally != plain2])
	# An Echo not taken up is thrown away
	_reset(main, player)
	var church_echo: Dictionary = _unit(main, player, "druid", "staff_fine_steel", Vector2i(1, 4), ["lingering_echo"])
	church_echo.mods["spell_echo_chance"] = 1.0
	_begin(main, church_echo, [_make_goblin(main, Vector2i(6, 6))])
	main._on_battle_ally_action("special")
	main._on_battle_ally_action("special_%d" % _special(main, church_echo, "Vitalize"))
	main._on_battle_ally_action("pick_0")
	print("A fresh echo keeps the command open: %s (expected true)" % [main.battle_commanding_ally == church_echo])
	# Skipping an echo throws it away
	main._on_battle_ally_action("skip")
	print("Skipping lets the echo go: %s (expected {})" % [church_echo.get("echo", {})])

	# =========================================================
	# Spell Bank: mana back
	# =========================================================
	_reset(main, player)
	var moon: Dictionary = _unit(main, player, "druid", "staff_fine_steel", Vector2i(1, 4), ["spell_bank"])
	moon.mana = 10
	_begin(main, moon, [_make_goblin(main, Vector2i(6, 6))])
	main._on_battle_ally_action("skip")
	print("Spell Bank gives back 5%% of max mana (%d) at the end of her turn: %d -> %d (expected %d)" % [moon.max_mana, 10, moon.mana, 10 + int(round(moon.max_mana * 0.05))])
	var moon_n: Dictionary = _unit(main, player, "necromancer", "staff_worn_wood", Vector2i(1, 4), ["spell_bank"])
	moon_n.hp = 10
	_begin(main, moon_n, [_make_goblin(main, Vector2i(6, 6))])
	main._on_battle_ally_action("skip")
	print("A Necromancer heals 5%% of her max HP instead: 10 -> %d (expected %d)" % [moon_n.hp, 10 + int(round(moon_n.max_hp * 0.05))])

	# =========================================================
	# Blazing Battery: the fireball needs no charging turn
	# =========================================================
	_reset(main, player)
	var plain_f: Dictionary = _unit(main, player, "druid", "wand_fine_steel", Vector2i(1, 4))
	var goblin_a: Dictionary = _make_goblin(main, Vector2i(6, 6))
	_begin(main, plain_f, [goblin_a])
	main._on_battle_ally_action("special")
	main._on_battle_ally_action("special_%d" % _special(main, plain_f, "I CAST FIREBALL"))
	print("Without the Battery the first cast only charges: charging=%s goblin_hp=%d (expected true, 999)" % [not plain_f.charging.is_empty(), goblin_a.hp])
	_reset(main, player)
	var lens: Dictionary = _unit(main, player, "druid", "wand_fine_steel", Vector2i(1, 4), ["blazing_battery"])
	var goblin_b: Dictionary = _make_goblin(main, Vector2i(6, 6))
	_begin(main, lens, [goblin_b])
	main._on_battle_ally_action("special")
	main._on_battle_ally_action("special_%d" % _special(main, lens, "I CAST FIREBALL"))
	print("With the Blazing Battery it lands at once: charging=%s goblin_hp=%d burning=%s (expected false, below 999, true)" % [not lens.charging.is_empty(), goblin_b.hp, goblin_b.burning])

	# =========================================================
	# Loud Whistle: every summon doubled, same price
	# =========================================================
	_reset(main, player)
	var whistler: Dictionary = _unit(main, player, "druid", "staff_fine_steel", Vector2i(1, 4), ["loud_whistle"])
	var plain_whistler: Dictionary = _unit(main, player, "druid", "staff_fine_steel", Vector2i(1, 4))
	print("Both pay the same for I SUMMON THEE: %d vs %d (expected equal)" % [_cost_of(main, whistler, "I SUMMON THEE"), _cost_of(main, plain_whistler, "I SUMMON THEE")])
	_begin(main, whistler, [_make_goblin(main, Vector2i(6, 6))])
	main._on_battle_ally_action("special")
	main._on_battle_ally_action("special_%d" % _special(main, whistler, "I SUMMON THEE"))
	main._on_battle_ally_action("pick_0")
	var spectres: Array = main.battle_allies.filter(func(a): return str(a.get("kind", "")) == "spectre")
	print("One cast raises two spectres: %d (expected 2), on different tiles: %s (expected true)" % [spectres.size(), spectres.size() == 2 and spectres[0].tile != spectres[1].tile])
	_reset(main, player)
	var summoner: Dictionary = _unit(main, player, "necromancer", "staff_worn_wood", Vector2i(1, 4), ["loud_whistle"])
	main.battle_allies = [summoner]
	main.battle_units = [_make_goblin(main, Vector2i(6, 6))]
	main.battle_actor = summoner
	main._resolve_summon_dead({"summon_count": 2})
	var bones: Array = main.battle_allies.filter(func(a): return str(a.get("kind", "")) == "skeleton")
	main.battle_actor = {}
	print("Asking for 2 skeletons raises 4: %d (expected 4)" % [bones.size()])

	# =========================================================
	# Clapback
	# =========================================================
	_reset(main, player)
	var clapper: Dictionary = _unit(main, player, "druid", "staff_fine_steel", Vector2i(1, 4), ["clapback"])
	print("Clapback: 20%% chance, +30%% against mages: %s (expected 0.2 and 0.3)" % [[clapper.mods.get("spell_clapback_chance", 0.0), clapper.mods.get("spell_clapback_mage_pct", 0.0)]])
	clapper.mods["spell_clapback_chance"] = 1.0
	var plain_foe: Dictionary = _make_goblin(main, Vector2i(3, 4))
	_begin(main, clapper, [plain_foe])
	main._on_battle_ally_action("special")
	main._on_battle_ally_action("special_%d" % _special(main, clapper, "Vitalize"))
	main._on_battle_ally_action("pick_0")
	var hit_plain: int = 999 - plain_foe.hp
	_reset(main, player)
	clapper = _unit(main, player, "druid", "staff_fine_steel", Vector2i(1, 4), ["clapback"])
	clapper.mods["spell_clapback_chance"] = 1.0
	var mage_foe: Dictionary = _make_goblin(main, Vector2i(3, 4), 999, "Apprentice Mage")
	_begin(main, clapper, [mage_foe])
	main._on_battle_ally_action("special")
	main._on_battle_ally_action("special_%d" % _special(main, clapper, "Vitalize"))
	main._on_battle_ally_action("pick_0")
	var hit_mage: int = 999 - mage_foe.hp
	print("The clapback hits for %d, and %d against a mage (expected about 30%% more: %d)" % [hit_plain, hit_mage, int(round(hit_plain * 1.3))])

	# =========================================================
	# Heavy Cloak: +1 Resilience and Fortitude for every 3 Magic
	# =========================================================
	_reset(main, player)
	var bare: Dictionary = _unit(main, player, "druid", "staff_fine_steel", Vector2i(1, 4))
	var cloaked: Dictionary = _unit(main, player, "druid", "staff_fine_steel", Vector2i(1, 4), ["heavy_cloak"])
	var steps: int = int(floor(float(cloaked.magic) / 3.0))
	print("Heavy Cloak adds 1 Defense and 1 Fortitude per 3 Magic (%.1f magic = %d): defense %.1f -> %.1f, fortitude %.1f -> %.1f (expected +%d each)" % [cloaked.magic, steps, bare.defense_pct, cloaked.defense_pct, bare.fortitude, cloaked.fortitude, steps])

	# The talismans do nothing at all for a hero and for a plain (non-spell) attack
	_reset(main, player)
	var warrior: Dictionary = _unit(main, player, "knight", "staff_worn_wood", Vector2i(1, 4), ["clapback"])
	warrior.mods["spell_clapback_chance"] = 1.0
	var bystander: Dictionary = _make_goblin(main, Vector2i(2, 4))
	_begin(main, warrior, [bystander])
	var hp_before: int = bystander.hp
	main._on_battle_ally_action("attack")
	print("A plain Attack is not a spell, so no clapback rides on it: the goblin took a single hit (%d damage); command ended=%s (expected true)" % [hp_before - bystander.hp, main.battle_commanding_ally != warrior])

	main.queue_free()
	await process_frame
	quit()
