extends SceneTree

# The older kits from the design doc -- Wolf, Druid, Guardian, Marksman, Rogue -- played through the
# real command menu and attack dispatcher, plus ally Fortitude levelling and the flat talisman slots.

func _make_goblin(main, tile: Vector2i, hp: int = 999) -> Dictionary:
	var g = load("res://scripts/Enemy.gd").new()
	main.add_child(g)
	g.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	return {
		"ref": g, "tile": tile, "hp": hp, "max_hp": hp, "move_range": 4, "damage": 1,
		"name": "Goblin", "winding_up": false, "stunned": false, "attack_range": 1,
		"concussed_turns": 0, "frozen_turns": 0, "burning": false, "armored": false,
		"disarmed_tile": Vector2i(-1, -1), "vulnerable_turns": 0, "aware_of_player": true, "size": 1,
	}

func _reset(main, player) -> void:
	main.in_battle = true
	main.game_over = false
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
	main.battle_player_defending = false
	main.tutorial_active = false
	main.battle_first_attack_used = true
	main.battle_fainted_members.clear()
	player.shared_talisman_provider = Callable()
	player.miss_chance_override = 0.0
	player.max_health = 500
	player.health = 500
	player.max_stamina = 100
	player.stamina = 100

func _filler() -> Dictionary:
	return {"tile": Vector2i(0, 0), "hp": 10, "max_hp": 10, "dmg_mult": 1.0, "name": "Filler", "move_range": 1, "attack_range": 1}

# A unit with no random procs and exact numbers.
func _plain(main, member, tile: Vector2i, attack: float = 10.0) -> Dictionary:
	var u: Dictionary = main._make_member_battle_unit(member, tile, 1.0)
	u.mods = {}
	u.weapon = {"damage_mult": 1.0}
	u.attack = attack
	return u

func _special(main, u: Dictionary, special_name: String) -> Dictionary:
	for s in main._ally_specials(u):
		if s.name == special_name:
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

func _attack(main, u: Dictionary) -> void:
	var filler := _filler()
	main.battle_commanding_ally = u
	main.battle_actor = u
	main.battle_allies = main.battle_allies.filter(func(a): return a != u and a.get("name", "") != "Filler")
	main.battle_allies.append(u)
	main.battle_allies.append(filler)
	main.battle_ally_queue = [filler]
	await main._battle_perform_attack(main._ally_regular_action(u))
	main.battle_actor = {}

func _init() -> void:
	seed(20261009)
	var rules = load("res://scripts/PartyRules.gd")
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	player.max_party_slots = 30
	for id in ["bow_fine_steel", "dagger_fine_steel", "club", "staff_fine_steel"]:
		player.owned_weapons[id] = true
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	# =========================================================
	# Fortitude levels like any other stat; members have 2 talisman slots (Shaman 4)
	# =========================================================
	var knight = player.recruit("knight")
	for i in 2:
		knight.gain_xp(knight.xp_to_next())
	knight.spend_pick("fortitude")
	print("Fortitude levels: Knight 10 + (2 passive + 1 chosen) x 0.9 = %.1f (expected 12.7), two level-ups gave %d picks (expected 2, one spent)" % [knight.fortitude(), knight.picks + 1])
	var guardian_probe = player.recruit("guardian")
	print("Every levelling kind can pick it, the wolf cannot: guardian=%s wolf=%s (expected true, false)" % [guardian_probe.pickable_stats().has("fortitude"), player.recruit("wolf").pickable_stats().has("fortitude")])
	print("Talisman slots at level 1: druid=%d shaman=%d rogue=%d wolf=%d (expected 2, 4, 2, 0)" % [player.recruit("druid").talisman_slot_count(), player.recruit("shaman").talisman_slot_count(), player.recruit("rogue").talisman_slot_count(), 0 if not player.party.filter(func(m): return m.is_wolf()).is_empty() and player.party.filter(func(m): return m.is_wolf())[0].talisman_slot_count() == 0 else -1])
	var late = rules.talisman_slots("druid", 12)
	print("...and they don't grow with level: a level-12 Druid still has %d (expected 2)" % [late])

	# =========================================================
	# Wolf
	# =========================================================
	_reset(main, player)
	var wolf = player.recruit("wolf")
	var w1 := _plain(main, wolf, Vector2i(2, 4), 10.0)
	var prey := _make_goblin(main, Vector2i(3, 4), 100)
	var spare := _make_goblin(main, Vector2i(3, 6), 100)
	main.battle_units = [prey, spare]
	var wl := []
	for s in main._ally_specials(w1):
		wl.append(s.name + main._ally_cost_text(w1, int(s.stamina_cost)))
	print("Wolf's specials: %s (expected [Drive-By (35 STA), Feed (25 STA), Nipper (10 STA)])" % [wl])
	await _cast(main, w1, "Drive-By")
	print("Drive-By hits at 1.4x: %d (expected 14), dashes past to %s (expected (4, 4)), and the command stays open: %s (expected true)" % [100 - prey.hp, w1.tile, main.battle_commanding_ally == w1])
	main.battle_commanding_ally = w1
	main.battle_allies = [w1, _filler()]
	var wolf_info: Dictionary = main._ally_menu_info()
	print("...afterwards only a plain Attack is offered: specials=%s attack_disabled=%s (expected false, false)" % [wolf_info.has_specials, wolf_info.attack_disabled])
	prey.tile = Vector2i(5, 4)
	main.battle_target_index = 0
	await _attack(main, w1)
	print("...that Attack ends the turn: bonus spent=%s, ally phase moved on to %s (expected true, Filler)" % [not w1.bonus_attack, main.battle_commanding_ally.name if main.battle_commanding_ally != null else "none"])
	# blocked behind
	_reset(main, player)
	var w2 := _plain(main, wolf, Vector2i(2, 4), 10.0)
	var front := _make_goblin(main, Vector2i(3, 4), 100)
	var back := _make_goblin(main, Vector2i(4, 4), 100)
	main.battle_units = [front, back]
	await _cast(main, w2, "Drive-By")
	print("If the tile behind the target is taken the Wolf stays where it was: %s (expected (2, 4))" % [w2.tile])

	# Feed
	_reset(main, player)
	var w3 := _plain(main, wolf, Vector2i(2, 4), 10.0)
	w3.stamina = 100
	w3.hp = 5
	w3.max_hp = 20
	var healthy := _make_goblin(main, Vector2i(3, 4), 100)
	main.battle_units = [healthy]
	await _cast(main, w3, "Feed")
	print("Feed on a healthy enemy is a plain hit: %d (expected 10), stamina %d (expected 75)" % [100 - healthy.hp, w3.stamina])
	var weak := _make_goblin(main, Vector2i(3, 4), 100)
	weak.hp = 15
	main.battle_units = [weak]
	w3.stamina = 100
	await _cast(main, w3, "Feed")
	print("...under 20%% HP it bites 1.5x: %d (expected 15), and as that was the kill: HP 5 -> %d (expected 10), stamina %d (expected 95: 25 spent, 20 back)" % [15 - weak.hp, w3.hp, w3.stamina])
	# Nipper
	var slowed := 0
	var untouched := 0
	for i in 40:
		_reset(main, player)
		var w4 := _plain(main, wolf, Vector2i(2, 4), 1.0)
		var biter := _make_goblin(main, Vector2i(3, 4), 999)
		main.battle_units = [biter]
		await _cast(main, w4, "Nipper")
		if biter.move_range < 4:
			slowed += 1
		else:
			untouched += 1
	print("Nipper halves an enemy's speed about half the time (40 tries): slowed=%s untouched=%s (expected both > 0)" % [slowed > 0, untouched > 0])

	# =========================================================
	# Druid
	# =========================================================
	_reset(main, player)
	var druid = player.recruit("druid")
	var d1 := _plain(main, druid, Vector2i(1, 4), 4.0)
	d1.magic = 12.0
	d1.mana = d1.max_mana
	var tank = player.recruit("guardian")
	var t1: Dictionary = main._make_member_battle_unit(tank, Vector2i(1, 3), 1.0)
	t1.mods = {}
	t1.hp = 5
	t1.max_hp = 40
	var dl := []
	for s in main._ally_specials(d1):
		dl.append(s.name + main._ally_cost_text(d1, int(s.stamina_cost)))
	print("Druid's spells: %s (expected the three spells, then no weapon specials when bare-handed)" % [dl])
	main.battle_units = [_make_goblin(main, Vector2i(6, 6), 999)]
	await _cast(main, d1, "Heal", t1)
	print("Heal = 25%% of 40 max HP + magic 12 / 3 = 14: HP 5 -> %d (expected 19); costs 30 mana: %d left (expected %d)" % [t1.hp, d1.mana, d1.max_mana - 30])
	player.health = 100
	d1.mana = d1.max_mana
	await _cast(main, d1, "Heal", "hero")
	print("...on the hero: 25%% of 500 + 4 = 129: %d (expected 229)" % [player.health])
	d1.upgraded_flag_probe = true
	druid.upgraded_spells["druid_heal"] = true
	var d1b: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 4), 1.0)
	d1b.magic = 12.0
	t1.hp = 5
	main.battle_allies = [d1b, t1]
	main.battle_actor = d1b
	main.battle_commanding_ally = d1b
	main.battle_ally_target = t1
	main._resolve_druid_heal()
	main.battle_actor = {}
	print("Upgraded at the Wizard's Tower it adds a half of magic (6) instead of a third: HP 5 -> %d (expected 21)" % [t1.hp])

	# Empower
	_reset(main, player)
	var d2 := _plain(main, druid, Vector2i(1, 4), 4.0)
	d2.mana = d2.max_mana
	var fighter := _plain(main, tank, Vector2i(2, 4), 10.0)
	var dummy := _make_goblin(main, Vector2i(3, 4), 999)
	main.battle_units = [dummy]
	main.battle_allies = [d2, fighter]
	await _cast(main, d2, "Empower", fighter)
	print("Empower on an ally: buff_turns=%d (expected 3), mana %d (expected %d)" % [fighter.buff_turns, d2.mana, d2.max_mana - 30])
	dummy.hp = 999
	await _attack(main, fighter)
	print("...the buffed ally hits for x1.5: %d (expected 15)" % [999 - dummy.hp])
	d2.mana = d2.max_mana
	await _cast(main, d2, "Empower", "hero")
	print("Empower on the hero: %d turns (expected 3)" % [main.battle_hero_buff_turns])
	dummy.hp = 999
	dummy.tile = Vector2i(1, 4)
	main.battle_target_index = 0
	var hero_plain: int = player.attack_damage
	main._apply_single_hit(0, 1.0, "", player.current_weapon)
	var buffed_hit: int = 999 - dummy.hp
	main.battle_hero_buff_turns = 0
	dummy.hp = 999
	main._apply_single_hit(0, 1.0, "", player.current_weapon)
	print("...and the hero's own hit is x1.5: %d vs %d unbuffed (expected buffed ~= 1.5x)" % [buffed_hit, 999 - dummy.hp])

	# Sprint
	_reset(main, player)
	var d3 := _plain(main, druid, Vector2i(1, 4), 8.0)
	d3.mana = d3.max_mana
	d3.move_range = 2
	var target3 := _make_goblin(main, Vector2i(2, 4), 999)
	main.battle_units = [target3]
	var sprint_filler := _filler()
	main.battle_allies = [d3, sprint_filler]
	main.battle_ally_queue = [sprint_filler]
	main._start_ally_turn()
	var moves_before: int = main.battle_ally_moves_left
	main._on_battle_ally_action("special")
	main._on_battle_ally_action("special_2")
	print("The movement spell doesn't end her turn: still commanding=%s (expected true), moves %d -> %d (expected 2 -> 4), mana %d (expected %d)" % [main.battle_commanding_ally == d3, moves_before, main.battle_ally_moves_left, d3.mana, d3.max_mana - 40])
	main.battle_menu_state = "main"
	main._on_battle_ally_action("attack")
	print("...but her attack is a flat (8 / 2) + 5 = 9: %d (expected 9)" % [999 - target3.hp])

	# =========================================================
	# Guardian
	# =========================================================
	_reset(main, player)
	var g1: Dictionary = main._make_member_battle_unit(tank, Vector2i(2, 4), 1.0)
	g1.mods = {}
	g1.weapon = {"damage_mult": 1.0}
	g1.defense_pct = 10.0
	g1.attack = 2.0
	var gt := _make_goblin(main, Vector2i(3, 4), 999)
	var gl := []
	for s in main._ally_specials(g1):
		gl.append(s.name + main._ally_cost_text(g1, int(s.stamina_cost)))
	print("Guardian's specials: %s (expected [Taunt, Body Slam (35 STA), Haymaker (50 STA), Earbursting Bellow (60 STA)])" % [gl])
	main.battle_units = [gt]
	var g_filler := _filler()
	main.battle_allies = [g1, g_filler]
	main.battle_ally_queue = [g_filler]
	await _cast(main, g1, "Taunt")
	print("Taunt doesn't end the turn: command stays=%s (expected true), braced=%s taunting=%s (expected true, true)" % [main.battle_commanding_ally == g1, g1.defending, g1.taunting])
	print("...and every enemy now goes for the Guardian: taunting ally tile=%s (expected (2, 4))" % [main._taunting_ally().tile])
	main.battle_allies = [g1]
	main.battle_ally_queue = [g1]
	main._advance_ally_queue()
	print("It wears off when the Guardian next commands: taunting=%s (expected false)" % [g1.taunting])
	await _cast(main, g1, "Body Slam")
	print("Body Slam uses DEFENSE (10) x 1.3 instead of attack (2): %d (expected 13)" % [999 - gt.hp])
	var stunned := 0
	for i in 40:
		gt.stunned = false
		gt.tile = Vector2i(3, 4)
		g1.stamina = 100
		await _cast(main, g1, "Body Slam")
		if gt.stunned:
			stunned += 1
	print("...with about a 15%% chance to stun (40 tries): stunned %d times (expected 1-15)" % [stunned])
	gt.stunned = false
	gt.hp = 999
	gt.tile = Vector2i(3, 4)
	g1.stamina = 100
	await _cast(main, g1, "Haymaker")
	print("Haymaker deals 1.5x of ATTACK (2 -> 3) and always stuns: %d, stunned=%s (expected 3, true)" % [999 - gt.hp, gt.stunned])
	# Bellow
	_reset(main, player)
	var g2: Dictionary = main._make_member_battle_unit(tank, Vector2i(2, 4), 1.0)
	g2.mods = {}
	var b1 := _make_goblin(main, Vector2i(5, 4), 999)
	var b2 := _make_goblin(main, Vector2i(7, 7), 999)
	main.battle_units = [b1, b2]
	main.battle_allies = [g2, _filler()]
	player.health = 500
	await _cast(main, g2, "Earbursting Bellow")
	var bellow: int = 20 + int(round(0.67 * g2.max_hp))
	print("Earbursting Bellow hits EVERY enemy for 20 + 0.67 x %d max HP = %d: %s (expected [%d, %d])" % [g2.max_hp, bellow, [999 - b1.hp, 999 - b2.hp], bellow, bellow])
	print("...and the hero takes the same unless they avoid it (no popups, no defences here): %d (expected %d)" % [500 - player.health, bellow])
	_reset(main, player)
	g2.stamina = 100
	main.battle_units = [_make_goblin(main, Vector2i(5, 4), 999)]
	main.battle_allies = [g2, _filler()]
	main.battle_player_defending = true
	player.health = 500
	await _cast(main, g2, "Earbursting Bellow")
	print("A braced hero takes only half (the usual Defend rules): %d (expected at most %d)" % [500 - player.health, bellow])

	# =========================================================
	# Marksman
	# =========================================================
	_reset(main, player)
	var marksman = player.recruit("marksman")
	print("The Marksman can only use a bow: club -> '%s'; bow -> '%s' (expected a refusal, then empty)" % [player.ally_weapon_block_reason(marksman, "club"), player.ally_weapon_block_reason(marksman, "bow_fine_steel")])
	player.equip_ally_weapon(marksman, "bow_fine_steel")
	var m1: Dictionary = main._make_member_battle_unit(marksman, Vector2i(1, 4), 1.0)
	print("It hits regardless of range and cover: unlimited=%s ignore_cover=%s (expected true, true); crit chance x%.1f with the bow (expected 1.5)" % [m1.unlimited_range, m1.ignore_cover, m1.mods.get("crit_chance_mult", 0.0)])
	var far := _make_goblin(main, Vector2i(7, 7), 999)
	main.battle_units = [far]
	print("...so an enemy on the far side of the grid is targetable: %s (expected [0])" % [main._ally_targetable_indices(m1)])
	var ml := []
	for s in main._ally_specials(m1):
		ml.append(s.name)
	print("Its specials are the bow's arrows: %s (expected [Flame Arrow, Freeze Arrow, Bomb Arrow, then the bow's own])" % [ml.slice(0, 3)])
	player.owned_arrows = {"flame": 2, "freeze": 0, "bomb": 1}
	var disabled := []
	for s in main._ally_specials(m1):
		if s.has("disabled_reason"):
			disabled.append(s.name)
	print("...an empty quiver disables one: %s (expected [Freeze Arrow])" % [disabled])
	m1.attack = 10.0
	await _cast(main, m1, "Flame Arrow")
	print("Flame Arrow spends one of YOUR arrows (%d left, expected 1), deals 2 + half the attack = %d (expected 7), and sets the target alight: %s (expected true)" % [player.owned_arrows.flame, 999 - far.hp, far.burning])
	main.battle_units = [far]
	await _cast(main, m1, "Bomb Arrow")
	print("Bomb Arrow uses the last bomb: %d (expected 0), 20 more damage: %d (expected 27 in all)" % [player.owned_arrows.bomb, 999 - far.hp])
	# prices
	var spear_price: int = player.get_weapon_price(load("res://scripts/Weapons.gd").get_owned_variant("spear_fine_steel"))
	var bow_price: int = player.get_weapon_price(load("res://scripts/Weapons.gd").get_owned_variant("bow_fine_steel"))
	var arrow_price: int = player.get_arrow_price("flame")
	player.dismiss_party_member(marksman.id)
	var spear_base: int = player.get_weapon_price(load("res://scripts/Weapons.gd").get_owned_variant("spear_fine_steel"))
	var bow_base: int = player.get_weapon_price(load("res://scripts/Weapons.gd").get_owned_variant("bow_fine_steel"))
	var arrow_base: int = player.get_arrow_price("flame")
	print("With a Marksman: other weapons x1.25 (%d vs %d), the bow itself unchanged (%d vs %d), arrows 60%% cheaper (%d vs %d) (expected the first 25%% up, bow equal, arrows ~0.4x)" % [spear_price, spear_base, bow_price, bow_base, arrow_price, arrow_base])

	# =========================================================
	# Rogue
	# =========================================================
	_reset(main, player)
	var rogue = player.recruit("rogue")
	player.equip_ally_weapon(rogue, "dagger_fine_steel")
	var r0: Dictionary = main._make_member_battle_unit(rogue, Vector2i(2, 4), 1.0)
	print("With a knife the Rogue deals x1.25: damage_pct=%.2f (expected 0.25); steal chance %.2f (expected 0.25)" % [r0.mods.get("damage_pct", 0.0), r0.steal_chance])
	player.unequip_ally_weapon(rogue)
	var r1 := _plain(main, rogue, Vector2i(2, 4), 10.0)
	r1.steal_chance = 1.0
	r1.moves_after_attack = true
	var rt := _make_goblin(main, Vector2i(3, 4), 999)
	main.battle_units = [rt]
	var coins_before: int = player.coins
	await _attack(main, r1)
	print("A regular attack can steal 1 gold INSTEAD of striking (forced here): coins +%d (expected 1), damage %d (expected 0)" % [player.coins - coins_before, 999 - rt.hp])
	r1.steal_chance = 0.0
	r1.attacked = false
	var r_filler := _filler()
	main.battle_allies = [r1, r_filler]
	main.battle_ally_queue = [r_filler]
	main.battle_commanding_ally = r1
	main.battle_ally_moves_left = 0
	await _attack(main, r1)
	var rinfo: Dictionary = main._ally_menu_info()
	print("Attacking lets it move again: command stays=%s (expected true), moves refilled to %d (expected %d), Attack now disabled=%s, specials hidden=%s (expected true, true)" % [main.battle_commanding_ally == r1, main.battle_ally_moves_left, r1.move_range, rinfo.attack_disabled, not rinfo.has_specials])
	# Pickpocket
	_reset(main, player)
	var r2 := _plain(main, rogue, Vector2i(2, 4), 10.0)
	var pt := _make_goblin(main, Vector2i(3, 4), 999)
	main.battle_units = [pt]
	coins_before = player.coins
	await _cast(main, r2, "Pickpocket")
	print("Pickpocket steals 3 coins (%d), deals no damage (%d), costs no stamina (%d, expected 100) and ends the turn (%s)" % [player.coins - coins_before, 999 - pt.hp, r2.stamina, main.battle_commanding_ally != r2])
	main.battle_ally_queue = [r2]
	main.battle_allies = [r2]
	main._advance_ally_queue()
	print("...next turn it has an extra tile: %d (expected %d)" % [main.battle_ally_moves_left, r2.move_range + 1])
	# Jugular
	_reset(main, player)
	var r3 := _plain(main, rogue, Vector2i(2, 4), 10.0)
	var jt := _make_goblin(main, Vector2i(3, 4), 999)
	main.battle_units = [jt]
	await _cast(main, r3, "Aim for the Jugular!")
	print("Aim for the Jugular! is always a crit (x2 = 20: %d) and leaves it bleeding (%d turns, expected 2); stamina %d (expected 60)" % [999 - jt.hp, jt.get("bleed_turns", 0), r3.stamina])
	# London's Welcome
	_reset(main, player)
	var r4 := _plain(main, rogue, Vector2i(2, 4), 10.0)
	var lt := _make_goblin(main, Vector2i(3, 4), 9999)
	main.battle_units = [lt]
	var landed := []
	for i in 12:
		lt.hp = 9999
		lt.tile = Vector2i(3, 4)
		r4.stamina = 100
		r4.attacked = false
		await _cast(main, r4, "London's Welcome")
		landed.append((9999 - lt.hp) / 6)
	var fine := true
	for n in landed:
		if n < 3 or n > 7:
			fine = false
	print("London's Welcome lands 3-7 slashes of 6 (10 x 60%%) each (12 tries): counts=%s all in range=%s (expected true)" % [landed, fine])
	player.miss_chance_override = 1.0
	lt.hp = 9999
	r4.stamina = 100
	await _cast(main, r4, "London's Welcome")
	print("If the roll misses the whole flurry misses: damage %d (expected 0)" % [9999 - lt.hp])
	player.miss_chance_override = 0.0

	quit()
