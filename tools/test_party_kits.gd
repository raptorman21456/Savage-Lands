extends SceneTree

# The four members from the design doc -- Knight, Necromancer, Brawler, Shaman: their stats and
# growth, how their favours/perks reach the battle unit, and every special in their kits
# (PartyKits.gd) played through the real command menu and attack dispatcher.

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
	main.tutorial_active = false
	main.battle_first_attack_used = true
	main.battle_fainted_members.clear()
	player.shared_talisman_provider = Callable()
	player.max_health = 500
	player.health = 500
	player.max_stamina = 100
	player.stamina = 100

# A harmless extra ally parked in the queue behind the one under test, so finishing an action hands
# control to it instead of starting the enemy phase.
func _filler() -> Dictionary:
	return {"tile": Vector2i(0, 0), "hp": 10, "max_hp": 10, "dmg_mult": 1.0, "name": "Filler", "move_range": 1, "attack_range": 1}

func _plain_unit(main, member, tile: Vector2i) -> Dictionary:
	var u: Dictionary = main._make_member_battle_unit(member, tile, 1.0)
	# No random procs: the numbers below are exact.
	u.mods = {}
	u.weapon = {"damage_mult": 1.0}
	return u

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
	seed(20261008)
	var weapons = load("res://scripts/Weapons.gd")
	var rules = load("res://scripts/PartyRules.gd")
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	main.enforce_special_loadouts = false  # these tests exercise individual specials, not the loadout
	player.max_party_slots = 20
	for id in ["staff_fine_steel", "greatsword_fine_steel", "knuckle_gloves_fine_steel", "club"]:
		player.owned_weapons[id] = true
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	# =========================================================
	# Stats and growth (the doc's multipliers, the approved starting stats)
	# =========================================================
	var knight = player.recruit("knight")
	var necro = player.recruit("necromancer")
	var brawler = player.recruit("brawler")
	var shaman = player.recruit("shaman")
	print("Knight starts 30 HP / 3 atk / 3 def / 4 speed / 0 magic / 10 fortitude: %d / %.0f / %.0f / %.0f / %.0f / %.0f (expected 30 / 3 / 3 / 4 / 0 / 10)" % [knight.max_hp(), knight.attack(), knight.defense_pct(), knight.speed(), knight.magic(), knight.fortitude()])
	print("Necromancer 15 / 1 / 0 / 5 / 10 / fortitude 0: %d / %.0f / %.0f / %.0f / %.0f / %.0f (expected 15 / 1 / 0 / 5 / 10 / 0)" % [necro.max_hp(), necro.attack(), necro.defense_pct(), necro.speed(), necro.magic(), necro.fortitude()])
	print("Brawler 20 / 2 / 2 / 4 / 0 / fortitude 5: %d / %.0f / %.0f / %.0f / %.0f / %.0f (expected 20 / 2 / 2 / 4 / 0 / 5)" % [brawler.max_hp(), brawler.attack(), brawler.defense_pct(), brawler.speed(), brawler.magic(), brawler.fortitude()])
	print("Shaman 12 / 0 / 1 / 5 / 10 / fortitude 10: %d / %.0f / %.0f / %.0f / %.0f / %.0f (expected 12 / 0 / 1 / 5 / 10 / 10)" % [shaman.max_hp(), shaman.attack(), shaman.defense_pct(), shaman.speed(), shaman.magic(), shaman.fortitude()])
	var wolf = player.recruit("wolf")
	print("A wolf's fortitude is -5 scaled by its x0.8 (it never levels): %.1f (expected -4.0)" % [wolf.fortitude()])
	print("Fortitude data for every kind (start / multiplier): %s (expected the user's list)" % [[
		[rules.rules("druid").base.fortitude, rules.growth("druid", "fortitude")],
		[rules.rules("guardian").base.fortitude, rules.growth("guardian", "fortitude")],
		[rules.rules("marksman").base.fortitude, rules.growth("marksman", "fortitude")],
		[rules.rules("rogue").base.fortitude, rules.growth("rogue", "fortitude")],
		[rules.rules("knight").base.fortitude, rules.growth("knight", "fortitude")],
		[rules.rules("necromancer").base.fortitude, rules.growth("necromancer", "fortitude")],
		[rules.rules("brawler").base.fortitude, rules.growth("brawler", "fortitude")],
		[rules.rules("shaman").base.fortitude, rules.growth("shaman", "fortitude")],
	]])
	print("Casters and fighters: necromancer caster=%s hp_as_mana=%s mana=%d, shaman caster=%s mana=%d, knight caster=%s stamina=%d (expected true, true, 50, true, 50, false, 100)" % [necro.is_caster(), necro.rules().get("hp_as_mana", false), necro.max_mana(), shaman.is_caster(), shaman.max_mana(), knight.is_caster(), knight.max_stamina()])
	print("A speed of 4 would cost a tile -- Knight and Brawler still move 2: %d / %d (expected 2 / 2)" % [knight.move_tiles(), brawler.move_tiles()])
	print("The Shaman has all four talisman slots at level 1: %d (expected 4); others follow the level curve: knight=%d (expected 1)" % [shaman.talisman_slot_count(), knight.talisman_slot_count()])
	print("The Shaman's attack never grows (x0): %.1f after three levels (expected 0.0); pickable=%s (expected no attack)" % [_levelled(rules, "shaman", 3).attack(), shaman.pickable_stats()])
	var lv = _levelled(rules, "necromancer", 2)
	for i in 2:
		lv.spend_pick("magic")
	print("Necromancer magic x3.0: 10 + (2 + 2) x 3 = %.1f (expected 22.0)" % [lv.magic()])
	var lk = _levelled(rules, "knight", 2)
	for i in 2:
		lk.spend_pick("defense")
	print("Knight defense x1.5: 3 + (2 + 2) x 1.5 = %.1f (expected 9.0)" % [lk.defense_pct()])
	var lb = _levelled(rules, "brawler", 2)
	for i in 2:
		lb.spend_pick("speed")
	print("Brawler speed x0.6: 4 + (2 x 0.2 + 2 x 1) x 0.6 = %.2f (expected 5.44)" % [lb.speed()])

	# =========================================================
	# What reaches the battle unit
	# =========================================================
	_reset(main, player)
	var knight_unit: Dictionary = main._make_member_battle_unit(knight, Vector2i(1, 4), 1.0)
	print("Knight, bare-handed: kit costs %s (expected [25, 50, 10]); cannot dodge flag=%s (expected true)" % [_costs(main, knight_unit), knight_unit.cannot_dodge])
	player.equip_ally_weapon(knight, "greatsword_fine_steel")
	var sword_unit: Dictionary = main._make_member_battle_unit(knight, Vector2i(1, 4), 1.0)
	print("...with a greatsword every special is 20%% cheaper: kit costs %s (expected [20, 40, 8])" % [_costs(main, sword_unit)])
	var sword_names := []
	for s in main._ally_specials(sword_unit):
		sword_names.append(s.name)
	print("...kit first, then the weapon's own specials: %s (expected 3 kit names, then 3 greatsword ones, then Stealth, which every member has)" % [sword_names])
	player.unequip_ally_weapon(knight)
	var brawler_unit: Dictionary = main._make_member_battle_unit(brawler, Vector2i(1, 4), 1.0)
	print("Brawler perks: crit chance +%.2f (expected 0.10), double-hit chance +%.2f (expected 0.10), bare fists range %d (expected 2)" % [brawler_unit.mods.get("crit_chance", 0.0), brawler_unit.weapon.get("passive_double_hit_chance", 0.0), brawler_unit.attack_range])
	player.equip_ally_weapon(brawler, "knuckle_gloves_fine_steel")
	var gloves_unit: Dictionary = main._make_member_battle_unit(brawler, Vector2i(1, 4), 1.0)
	var gloves_plain: int = int(rules.rules("brawler").attack_range) + int(gloves_unit.weapon.get("range_bonus", 0)) + int(gloves_unit.weapon.get("passive_extra_range", 0))
	print("...knuckle gloves keep the +1 range: %d (expected %d)" % [gloves_unit.attack_range, gloves_plain + 1])
	player.unequip_ally_weapon(brawler)
	player.equip_ally_weapon(brawler, "club")
	var club_unit: Dictionary = main._make_member_battle_unit(brawler, Vector2i(1, 4), 1.0)
	print("...a club gets no range bonus (%d, expected 1) but the perks still apply: crit +%.2f, double-hit +%.2f (expected 0.10, 0.10)" % [club_unit.attack_range, club_unit.mods.get("crit_chance", 0.0), club_unit.weapon.get("passive_double_hit_chance", 0.0)])
	player.unequip_ally_weapon(brawler)
	var necro_unit: Dictionary = main._make_member_battle_unit(necro, Vector2i(1, 4), 1.0)
	print("Necromancer pays in HP: pool=%s hp=%d (expected HP, 15); no staff -> kill heal %.0f (expected 0)" % [main._unit_pool_name(necro_unit), necro_unit.hp, necro_unit.mods.get("kill_heal", 0.0)])
	player.equip_ally_weapon(necro, "staff_fine_steel")
	var staff_necro: Dictionary = main._make_member_battle_unit(necro, Vector2i(1, 4), 1.0)
	print("...with a staff: kill heal %.0f (expected 2) and range %d (expected 3)" % [staff_necro.mods.get("kill_heal", 0.0), staff_necro.attack_range])
	player.unequip_ally_weapon(necro)
	var bare_shaman: Dictionary = main._make_member_battle_unit(shaman, Vector2i(1, 4), 1.0)
	player.equip_ally_weapon(shaman, "staff_fine_steel")
	var staff_shaman: Dictionary = main._make_member_battle_unit(shaman, Vector2i(1, 4), 1.0)
	print("Talisman sharing needs the staff: bare share=%.1f (expected 0.0), staff share=%.1f (expected 0.5)" % [bare_shaman.mods.get("talisman_share", 0.0), staff_shaman.mods.get("talisman_share", 0.0)])
	player.unequip_ally_weapon(shaman)

	# =========================================================
	# The menus
	# =========================================================
	_reset(main, player)
	var menu_knight: Dictionary = main._make_member_battle_unit(knight, Vector2i(1, 4), 1.0)
	var menu_goblin := _make_goblin(main, Vector2i(6, 6))
	main.battle_units = [menu_goblin]
	main.battle_allies = [menu_knight]
	main._start_ally_turn()
	var labels := []
	for s in main._ally_menu_info().specials:
		labels.append(s.label)
	print("Knight's Special menu: %s (expected [Rallying Cry (25 STA), CHARGE!! (50 STA), Stalwart (10 STA), Stealth (20 STA)])" % [labels])
	var nlabels := []
	var necro_menu: Dictionary = main._make_member_battle_unit(necro, Vector2i(1, 3), 1.0)
	for s in main._ally_specials(necro_menu):
		nlabels.append(s.name + main._ally_cost_text(necro_menu, int(s.stamina_cost)))
	print("Necromancer's, in HP: %s (expected [Curse of Rot (12 HP), Revival Blessing (14 HP), Summon the Dead (5 HP), Stealth (4 HP)])" % [nlabels])
	var slabels := []
	var shaman_menu: Dictionary = main._make_member_battle_unit(shaman, Vector2i(1, 3), 1.0)
	for s in main._ally_specials(shaman_menu):
		slabels.append(s.name + main._ally_cost_text(shaman_menu, int(s.stamina_cost)))
	print("Shaman's, in mana: %s (expected [How Charming (40 MP), Soothing Rain (50 MP), Cleansing Chant (30 MP), Stealth (20 MP)])" % [slabels])
	var blabels := []
	for s in main._ally_specials(brawler_unit):
		blabels.append(s.name + main._ally_cost_text(brawler_unit, int(s.stamina_cost)))
	print("Brawler's: %s (expected [Sucker Punch (30 STA), Dodge and Weave (45 STA), Drain Punch (40 STA), Stealth (20 STA)])" % [blabels])

	# =========================================================
	# Knight: Rallying Cry
	# =========================================================
	_reset(main, player)
	var k1 := _plain_unit(main, knight, Vector2i(1, 4))
	var g1 := _make_goblin(main, Vector2i(2, 4))
	main.battle_units = [g1]
	var swing := func(unit: Dictionary) -> int:
		g1.hp = 999
		g1.tile = Vector2i(2, 4)
		g1.vulnerable_turns = 0
		var filler := _filler()
		main.battle_commanding_ally = unit
		main.battle_actor = unit
		main.battle_allies = [unit, filler]
		main.battle_ally_queue = [filler]
		main.battle_units = [g1]
		await main._battle_perform_attack({"stamina_cost": 0, "dmg_mult": 1.0, "effect": "", "name": "Attack", "is_regular_attack": true})
		main.battle_actor = {}
		return 999 - g1.hp
	var before_cry: int = await swing.call(k1)
	await _cast(main, k1, "Rallying Cry")
	print("Rallying Cry costs 25 stamina (%d left, expected 75) and lasts %d rounds (expected 3)" % [k1.stamina, main.battle_rally_turns])
	var after_cry: int = await swing.call(k1)
	print("Enemies now take +25%% from everyone: the Knight's 3 damage becomes %d (was %d; expected 4 vs 3)" % [after_cry, before_cry])
	main.battle_rally_turns = 0
	print("...and it wears off: %d (expected 3)" % [await swing.call(k1)])

	# =========================================================
	# Knight: CHARGE!!
	# =========================================================
	_reset(main, player)
	var k2 := _plain_unit(main, knight, Vector2i(1, 4))
	k2.attack = 6.0
	k2.defense_pct = 9.0
	var c1 := _make_goblin(main, Vector2i(2, 4))
	var c2 := _make_goblin(main, Vector2i(3, 4))
	var c3 := _make_goblin(main, Vector2i(5, 4))
	main.battle_units = [c1, c2, c3]
	var charge_filler := _filler()
	main.battle_allies = [k2, charge_filler]
	main.battle_ally_queue = [charge_filler]
	main._start_ally_turn()
	main._on_battle_ally_action("special")
	main._on_battle_ally_action("special_1")
	var dir_labels := []
	for p in main._ally_menu_info().picks:
		dir_labels.append(p.label)
	print("CHARGE!! asks for a direction: state=%s options=%s (expected ally_pick, [Charge up, Charge down, Charge left, Charge right])" % [main.battle_menu_state, dir_labels])
	main._on_battle_ally_action("pick_3")
	print("Running right hits the two in the way for 2 x 9 defense + 2/3 x 6 attack = 22 each, not the one 4 tiles off: %s (expected [22, 22, 0])" % [[999 - c1.hp, 999 - c2.hp, 999 - c3.hp]])
	print("...stamina 40 spent: %d (expected 60); the Knight ended up further along the row: x=%d (expected >= 2), y=%d (expected 4)" % [k2.stamina, k2.tile.x, k2.tile.y])
	# over rock: terrain is ignored
	_reset(main, player)
	var k3 := _plain_unit(main, knight, Vector2i(1, 4))
	main.battle_terrain[Vector2i(2, 4)] = {"type": "rock"}
	main.battle_units = [_make_goblin(main, Vector2i(6, 6))]
	var rock_filler := _filler()
	main.battle_allies = [k3, rock_filler]
	main.battle_ally_queue = [rock_filler]
	main.battle_commanding_ally = k3
	main.battle_actor = k3
	main.battle_ally_target = Vector2i(1, 0)
	await main._battle_perform_attack(_special(main, k3, "CHARGE!!"))
	main.battle_actor = {}
	print("A rock in the path doesn't stop it, and it never ends on the rock: x=%d (expected 4)" % [k3.tile.x])

	# =========================================================
	# Knight: Stalwart
	# =========================================================
	_reset(main, player)
	var k4 := _plain_unit(main, knight, Vector2i(2, 4))
	k4.defense_pct = 0.0
	k4.stamina = 50
	var attacker := _make_goblin(main, Vector2i(6, 4))
	main.battle_units = [attacker]
	await _cast(main, k4, "Stalwart")
	print("Stalwart costs 10: stamina %d (expected 40), braced=%s (expected true)" % [k4.stamina, k4.stalwart])
	var hp_before: int = k4.hp
	var taken: Dictionary = await main._enemy_apply_damage(attacker, k4.tile, 10, {})
	print("A 10-damage hit is halved: dealt %d (expected 5), HP lost %d (expected 5)" % [taken.dmg, hp_before - k4.hp])
	print("...and the hit fed its stamina by 20%% of max: %d (expected 60)" % [k4.stamina])
	main.battle_ally_queue = [k4]
	main.battle_allies = [k4]
	main._advance_ally_queue()
	print("It lasts only until its next turn: braced=%s (expected false)" % [k4.stalwart])

	# =========================================================
	# Brawler: Sucker Punch, Dodge and Weave, Drain Punch
	# =========================================================
	_reset(main, player)
	var b1 := _plain_unit(main, brawler, Vector2i(1, 4))
	b1.attack = 5.0
	var bt := _make_goblin(main, Vector2i(2, 4), 100)
	main.battle_units = [bt]
	await _cast(main, b1, "Sucker Punch")
	print("Sucker Punch on a full-health enemy is a guaranteed crit: %d (expected 10)" % [100 - bt.hp])
	bt.hp = 60
	bt.tile = Vector2i(2, 4)
	bt.vulnerable_turns = 0
	await _cast(main, b1, "Sucker Punch")
	print("...on a wounded one it is a plain hit: %d (expected 5)" % [60 - bt.hp])

	_reset(main, player)
	var b2 := _plain_unit(main, brawler, Vector2i(1, 4))
	b2.attack = 10.0
	var bw := _make_goblin(main, Vector2i(2, 4), 100)
	main.battle_units = [bw]
	var weave_filler := _filler()
	main.battle_allies = [b2, weave_filler]
	main.battle_ally_queue = [weave_filler]
	main._start_ally_turn()
	main._on_battle_ally_action("special")
	main._on_battle_ally_action("special_1")
	var weave_labels := []
	for p in main._ally_menu_info().picks:
		weave_labels.append(p.label)
	print("Dodge and Weave offers only the rolls with room (the hero stands left of it) plus staying put: %s (expected [Roll up, Roll down, Stay put]: left is the hero, right is the enemy)" % [weave_labels])
	var up_index := weave_labels.find("Roll up")
	main._on_battle_ally_action("pick_%d" % up_index)
	print("Two hits at 80%% of attack 10 = 8 each: dealt %d (expected 16); then it rolled 2 tiles up: tile %s (expected (1, 2))" % [100 - bw.hp, b2.tile])
	print("...paying 45 stamina: %d (expected 55)" % [b2.stamina])

	_reset(main, player)
	var b3 := _plain_unit(main, brawler, Vector2i(1, 4))
	b3.attack = 10.0
	b3.hp = 10
	b3.max_hp = 20
	var bd := _make_goblin(main, Vector2i(2, 4), 100)
	main.battle_units = [bd]
	await _cast(main, b3, "Drain Punch")
	print("Drain Punch heals half the damage dealt: dealt %d (expected 10), HP 10 -> %d (expected 15)" % [100 - bd.hp, b3.hp])

	# =========================================================
	# Necromancer: Curse of Rot, kills, Revival Blessing, Summon the Dead
	# =========================================================
	_reset(main, player)
	var n1: Dictionary = main._make_member_battle_unit(necro, Vector2i(1, 4), 1.0)
	n1.mods = {}
	n1.weapon = {"damage_mult": 1.0}
	var cursed := _make_goblin(main, Vector2i(2, 4), 100)
	var far_goblin := _make_goblin(main, Vector2i(7, 7), 999)
	main.battle_units = [cursed, far_goblin]
	await _cast(main, n1, "Curse of Rot")
	print("Curse of Rot costs 10 HP + 15%% of max HP (2) = 12: %d -> %d HP (expected 15 -> 3), enemy cursed for %d turns (expected 5)" % [15, n1.hp, cursed.get("rot_turns", 0)])
	var nhp_before: int = int(n1.max_hp)
	cursed.hp = 1
	cursed.max_hp = 100
	main.battle_allies = [n1, _filler()]
	await main._process_enemy_turn()
	print("The rot ticks 10%% of max HP (10) at the enemy's turn and the kill is the Necromancer's: goblin gone=%s (expected true), max HP %d -> %d (expected +1), kills=%d (expected 1)" % [not main.battle_units.has(cursed), nhp_before, n1.max_hp, necro.kills_this_battle])
	print("...the +1 max HP is for good: member bonus hp=%.1f (expected 1.0), max_hp() now %d (expected 16)" % [necro.bonus.hp, necro.max_hp()])
	# a direct kill
	_reset(main, player)
	var necro_b = player.recruit("necromancer")
	var n2: Dictionary = main._make_member_battle_unit(necro_b, Vector2i(1, 4), 1.0)
	n2.mods = {"kill_heal": 0.0}
	n2.weapon = {"damage_mult": 1.0}
	n2.attack = 50.0
	n2.hp = 5
	var prey := _make_goblin(main, Vector2i(2, 4), 3)
	main.battle_units = [prey, _make_goblin(main, Vector2i(7, 7), 999)]
	var n2_filler := _filler()
	main.battle_allies = [n2, n2_filler]
	main.battle_ally_queue = [n2_filler]
	main.battle_commanding_ally = n2
	main.battle_actor = n2
	await main._battle_perform_attack(main._ally_regular_action(n2))
	main.battle_actor = {}
	print("Its own kill: +1 max HP and +1 HP (no staff, no extra heal): max %d (expected 16), HP %d (expected 6)" % [n2.max_hp, n2.hp])
	n2.mods = {"kill_heal": 2.0}
	n2.hp = 5
	var prey2 := _make_goblin(main, Vector2i(2, 4), 3)
	main.battle_units = [prey2, _make_goblin(main, Vector2i(7, 7), 999)]
	main.battle_allies = [n2, n2_filler]
	main.battle_ally_queue = [n2_filler]
	main.battle_commanding_ally = n2
	main.battle_actor = n2
	await main._battle_perform_attack(main._ally_regular_action(n2))
	main.battle_actor = {}
	print("With a staff each kill also heals 2: HP %d (expected 5 + 1 + 2 = 8), max %d (expected 17)" % [n2.hp, n2.max_hp])
	# somebody else's kill does not count
	var other_before: int = int(n2.max_hp)
	main._note_enemy_death({"name": "Goblin"}, {"kind": "guardian", "max_hp": 30, "hp": 20})
	main._note_enemy_death({"name": "Goblin"}, {})
	print("A kill by anyone else counts for nobody: necromancer max HP still %d (expected %d)" % [n2.max_hp, other_before])

	# Revival Blessing
	_reset(main, player)
	var guardian = player.recruit("guardian")
	var necro_c = player.recruit("necromancer")
	var n3: Dictionary = main._make_member_battle_unit(necro_c, Vector2i(1, 4), 1.0)
	n3.mods = {}
	n3.weapon = {"damage_mult": 1.0}
	var corpse: Dictionary = main._make_member_battle_unit(guardian, Vector2i(2, 4), 1.0)
	main.battle_allies = [n3, corpse]
	main.battle_units = [_make_goblin(main, Vector2i(7, 7))]
	corpse.hp = 0
	main._remove_fallen_allies()
	var revive_cost: int = int(_special(main, n3, "Revival Blessing").stamina_cost)
	print("Revival Blessing takes the whole bar: every HP but one (%d HP) -> cost shows %s (expected 14 HP)" % [n3.hp - 1, main._ally_cost_text(n3, revive_cost)])
	var n3_filler := _filler()
	main.battle_allies = [n3, n3_filler]
	main.battle_ally_queue = [n3_filler]
	main._start_ally_turn()
	main._on_battle_ally_action("special")
	main._on_battle_ally_action("special_1")
	print("It asks which fallen ally: state=%s, candidates=%d (expected ally_pick, 1)" % [main.battle_menu_state, main._ally_menu_info().picks.size()])
	main._on_battle_ally_action("pick_0")
	print("The Guardian is back at full HP %d/%d (expected equal) and the Necromancer is at %d HP (expected 1)" % [corpse.hp, corpse.max_hp, n3.hp])
	var low: Dictionary = main._make_member_battle_unit(necro_c, Vector2i(1, 4), 1.0)
	low.hp = 1
	print("At 1 HP it cannot pay for Revival at all: disabled=%s (expected true)" % [not main._unit_can_pay(low, int(_special(main, low, "Revival Blessing").stamina_cost))])

	# Summon the Dead
	_reset(main, player)
	var necro_d = player.recruit("necromancer")
	var n4: Dictionary = main._make_member_battle_unit(necro_d, Vector2i(3, 4), 1.0)
	n4.mods = {}
	n4.weapon = {"damage_mult": 1.0}
	var disabled_special: Dictionary = _special(main, n4, "Summon the Dead")
	print("With no kills last battle Summon is unavailable: reason='%s' (expected a reason)" % [disabled_special.get("disabled_reason", "")])
	necro_d.kills_last_battle = 3
	var summon_special: Dictionary = _special(main, n4, "Summon the Dead")
	print("After 3 kills it could raise %d skeletons (expected 2: HP 15 pays for 14/5 = 2), costing %s (expected 10 HP)" % [summon_special.summon_count, main._ally_cost_text(n4, int(summon_special.stamina_cost)).strip_edges()])
	var sk_target := _make_goblin(main, Vector2i(7, 4), 50)
	main.battle_units = [sk_target]
	await _cast(main, n4, "Summon the Dead")
	var skeletons: Array = main.battle_allies.filter(func(a): return a.get("kind", "") == "skeleton")
	print("Two skeletons are raised: %d (expected 2), the Necromancer paid 10 HP: %d (expected 5)" % [skeletons.size(), n4.hp])
	print("Each is a 1 HP, 4 damage, 1-tile unit: hp=%d attack=%.0f move=%d (expected 1, 4, 1)" % [skeletons[0].hp, skeletons[0].attack, skeletons[0].move_range])
	# a skeleton acts by itself when its turn comes
	var skel: Dictionary = skeletons[0]
	skel.tile = Vector2i(5, 4)
	for other in skeletons.slice(1):
		main.battle_allies.erase(other)
	main.battle_allies = [skel, _filler()]
	main.battle_ally_queue = []
	main.battle_turn = "player"
	main._start_ally_turn()
	print("In the ally phase the skeleton walks at the nearest enemy and (in reach) hits it: tile=%s hp %d (expected (6, 4) and 46)" % [skel.tile, sk_target.hp])
	print("...and the next ally (the filler) is then the one being commanded: %s (expected Filler)" % [main.battle_commanding_ally.name if main.battle_commanding_ally != null else "none"])
	skel.hp = 0
	main.battle_allies = [skel]
	main._remove_fallen_allies()
	print("A fallen skeleton just crumbles -- no body to revive: downed=%d (expected 0), faints=%d (expected 0)" % [main.battle_downed_allies.size(), main.battle_fainted_members.size()])
	# the tally rolls over at the end of a battle
	necro_d.kills_this_battle = 4
	main._settle_party_after_battle()
	print("At battle end this battle's kills become the last battle's: last=%d (expected 4), this=%d (expected 0)" % [necro_d.kills_last_battle, necro_d.kills_this_battle])

	# Guard for an HP caster
	_reset(main, player)
	var necro_e = player.recruit("necromancer")
	var n5: Dictionary = main._make_member_battle_unit(necro_e, Vector2i(1, 4), 1.0)
	n5.hp = 10
	n5.max_hp = 22
	main.battle_units = [_make_goblin(main, Vector2i(7, 7))]
	var n5_filler := _filler()
	main.battle_allies = [n5, n5_filler]
	main.battle_ally_queue = [n5_filler]
	main.battle_commanding_ally = n5
	main._on_battle_ally_action("guard")
	print("An HP caster's Guard steadies it with HP instead of mana (15 mana = 3 HP): %d (expected 13)" % [n5.hp])

	# =========================================================
	# Shaman: sharing, How Charming, Soothing Rain, Cleansing Chant
	# =========================================================
	_reset(main, player)
	player.equip_ally_weapon(shaman, "staff_fine_steel")
	var s1: Dictionary = main._make_member_battle_unit(shaman, Vector2i(3, 4), 1.0)
	s1.mods["damage_pct"] = 0.20
	s1.mods["coin_pct"] = 0.10
	var near_ally: Dictionary = main._make_member_battle_unit(guardian, Vector2i(3, 6), 1.0)
	var mid_ally: Dictionary = main._make_member_battle_unit(brawler, Vector2i(3, 7), 1.0)
	near_ally.mods = {}
	mid_ally.mods = {}
	main.battle_allies = [s1, near_ally, mid_ally]
	main.battle_units = [_make_goblin(main, Vector2i(7, 0))]
	player.shared_talisman_provider = Callable(main, "_hero_shared_effect")
	print("A Shaman with a staff shares half her damage talisman with an ally 2 tiles away: %.2f (expected 0.10); 3 tiles away: %.2f (expected 0.00)" % [main._unit_effect(near_ally, "damage_pct"), main._unit_effect(mid_ally, "damage_pct")])
	print("...but not economy effects (coin_pct): %.2f (expected 0.00), and not to herself twice: %.2f (expected 0.20)" % [main._unit_effect(near_ally, "coin_pct"), main._unit_effect(s1, "damage_pct")])
	print("The hero is an ally too -- at (0, 4) the Shaman at (3, 4) is 3 tiles off: %.2f (expected 0.00)" % [player.talisman_bonus("damage_pct")])
	main.battle_player_tile = Vector2i(2, 4)
	print("...one step closer (1 tile away) the hero gains it: %.2f (expected 0.10)" % [player.talisman_bonus("damage_pct")])
	main.battle_player_tile = Vector2i(0, 4)
	await _cast(main, s1, "How Charming")
	print("How Charming costs 40 mana (%d left, expected %d) and stretches her reach to 4 tiles for %d turns" % [s1.mana, s1.max_mana - 40, s1.charm_turns])
	print("...the ally 3 tiles off now gets it: %.2f (expected 0.10), and the hero 3 tiles away too: %.2f (expected 0.10)" % [main._unit_effect(mid_ally, "damage_pct"), player.talisman_bonus("damage_pct")])
	s1.charm_turns = 0
	s1.mods.erase("talisman_share")
	print("Without the staff's share nothing is passed on: %.2f (expected 0.00)" % [main._unit_effect(near_ally, "damage_pct")])
	s1.mods["talisman_share"] = 0.5
	s1.hp = 0
	print("A downed Shaman shares nothing: %.2f (expected 0.00)" % [main._unit_effect(near_ally, "damage_pct")])
	s1.hp = s1.max_hp

	# Soothing Rain
	player.health = 100
	near_ally.hp = 5
	near_ally.max_hp = 50
	mid_ally.hp = 5
	mid_ally.max_hp = 50
	s1.hp = 6
	s1.max_hp = 30
	main.battle_player_tile = Vector2i(2, 4)
	near_ally.tile = Vector2i(3, 6)
	s1.mana = s1.max_mana
	var mana_before_rain: int = s1.mana
	await _cast(main, s1, "Soothing Rain")
	print("Soothing Rain heals everyone within 2 tiles for 20%% of their max HP: hero %d (expected 200), 2 tiles away ally %d (expected 15), the Shaman %d (expected 12), 3 tiles away ally %d (expected 5, untouched)" % [player.health, near_ally.hp, s1.hp, mid_ally.hp])
	print("...costing 50 mana: %d (expected %d)" % [s1.mana, mana_before_rain - 50])

	# Cleansing Chant
	_reset(main, player)
	main.battle_allies = [s1, near_ally, mid_ally]
	main.battle_player_tile = Vector2i(2, 4)
	s1.tile = Vector2i(3, 4)
	s1.mana = s1.max_mana
	main.player_burning = true
	main.player_poison_turns = 3
	near_ally.disarmed_tile = Vector2i(6, 6)
	mid_ally.disarmed_tile = Vector2i(6, 6)
	main.battle_units = [_make_goblin(main, Vector2i(7, 0))]
	await _cast(main, s1, "Cleansing Chant")
	print("Cleansing Chant removes ONE status from the hero (burning first): burning=%s (expected false), poison turns=%d (expected 3 -- still there)" % [main.player_burning, main.player_poison_turns])
	print("...and the dropped weapon of an ally in range comes back (%s, expected (-1, -1)); the one 3 tiles off keeps its problem (%s)" % [near_ally.disarmed_tile, mid_ally.disarmed_tile])
	main.player_poison_turns = 0

	# the single-target mode: every affliction off one ally
	main.player_burning = true
	main.player_poison_turns = 3
	main.player_blind_turns = 2
	s1.mana = s1.max_mana
	var chant_options: Array = main._ally_pick_candidates(s1, "chant")
	var chant_labels := []
	for c in chant_options:
		chant_labels.append(str(c.label).split(":")[0])
	print("Cleansing Chant offers the whole circle plus each ally one by one: %s (expected the circle, You, then every living ally)" % [chant_labels])
	main.battle_ally_target = "hero"
	await _cast(main, s1, "Cleansing Chant")
	main.battle_ally_target = null
	print("...purging YOU clears everything at once: burning=%s poison=%d blind=%d (expected false, 0, 0)" % [main.player_burning, main.player_poison_turns, main.player_blind_turns])
	near_ally.disarmed_tile = Vector2i(6, 6)
	near_ally.skip_turns = 1
	s1.mana = s1.max_mana
	main.battle_ally_target = mid_ally
	mid_ally.disarmed_tile = Vector2i(6, 6)
	mid_ally.skip_turns = 2
	await _cast(main, s1, "Cleansing Chant")
	main.battle_ally_target = null
	print("...and a chosen ally is purged even from beyond the circle (3 tiles): disarmed=%s staggered=%d (expected (-1, -1), 0), the one not chosen keeps theirs: %s (expected (6, 6))" % [mid_ally.disarmed_tile, mid_ally.skip_turns, near_ally.disarmed_tile])

	# the round tick
	_reset(main, player)
	s1.tile = Vector2i(3, 4)
	s1.charm_turns = 2
	main.battle_rally_turns = 3
	main.battle_allies = [s1]
	main.battle_units = [_make_goblin(main, Vector2i(7, 7))]
	await main._process_enemy_turn()
	print("The party kits' timers tick once per round: rally %d (expected 2), charm %d (expected 1)" % [main.battle_rally_turns, s1.charm_turns])

	quit()

func _levelled(rules, kind: String, levels: int):
	var m = load("res://scripts/PartyMember.gd").create(99, kind)
	for i in levels:
		m.gain_xp(m.xp_to_next())
	return m

func _costs(main, u: Dictionary) -> Array:
	var out := []
	for kit in load("res://scripts/PartyKits.gd").specials_for(str(u.kind)):
		out.append(int(main._kit_special_for(u, kit).stamina_cost))
	return out
