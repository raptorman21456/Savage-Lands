extends SceneTree

# Party members in a real battle: gear on the battle unit, mana/stamina pools, the special-move
# menu and friendly-target picker, the Staff's three specials, downed allies and revival, and
# the shared hit pipeline reading the ACTING member's own talismans instead of the hero's.

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
	main.battle_fainted_members.clear()
	player.pichaku_active = false
	player.max_health = 500
	player.health = 500
	player.max_stamina = 100
	player.stamina = 100

func _member_unit(main, player, kind: String, weapon_id: String, tile: Vector2i):
	var member = player.recruit(kind)
	if weapon_id != "":
		player.owned_weapons[weapon_id] = true
		player.equip_ally_weapon(member, weapon_id)
	var u: Dictionary = main._make_member_battle_unit(member, tile, 1.0)
	return u

# A harmless extra ally parked in the queue behind the one under test, so finishing an action hands
# control to it instead of starting the enemy phase (which would burn, counter-attack and move).
func _filler() -> Dictionary:
	return {"tile": Vector2i(0, 0), "hp": 10, "max_hp": 10, "dmg_mult": 1.0, "name": "Filler", "move_range": 1, "attack_range": 1}

func _start(main, unit: Dictionary) -> void:
	main.battle_allies = [unit]
	main._start_ally_turn()

func _init() -> void:
	seed(20261006)
	var weapons = load("res://scripts/Weapons.gd")
	var main = load("res://Main.tscn").instantiate()
	main.regional_world = false  # this test drives the old wave-ladder world
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	main.enforce_special_loadouts = false  # these tests exercise individual specials, not the loadout
	player.max_party_slots = 6
	player.owned_weapons["staff_fine_steel"] = true
	player.owned_weapons["club"] = true
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	# =========================================================
	# The battle unit carries its gear
	# =========================================================
	_reset(main, player)
	var druid = player.recruit("druid")
	var bare: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 4), 1.0)
	print("A bare-handed Druid: magic=%.1f mana=%d range=%d weapon=%s (expected 10.0, 50, 1, {damage_mult: 1.0})" % [bare.magic, bare.max_mana, bare.attack_range, bare.weapon])
	player.equip_ally_weapon(druid, "staff_fine_steel")
	var armed: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 4), 1.0)
	print("With a Staff (+6 magic, then her x1.15 favour): magic=%.2f mana=%d (expected 18.40, 92)" % [armed.magic, armed.max_mana])
	print("...range is 1 + 2 = %d (expected 3), the weapon is %s, and Landfall costs %d mana (expected Staff, 60)" % [armed.attack_range, armed.weapon.name, armed.weapon.specials[1].stamina_cost])
	druid.bonus.magic = 4.0
	var gained: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 4), 1.0)
	player.owned_weapons["staff_mythic"] = true
	player.unequip_ally_weapon(druid)
	player.equip_ally_weapon(druid, "staff_mythic")
	var moon: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 4), 1.0)
	print("Levelled-up magic (+4): %.2f; with Moonstick doubling the GAIN: %.2f (expected 23.00, 27.60)" % [gained.magic, moon.magic])
	druid.bonus.magic = 0.0
	player.unequip_ally_weapon(druid)
	player.equip_ally_weapon(druid, "staff_fine_steel")
	var guardian = player.recruit("guardian")
	var guardian_unit: Dictionary = main._make_member_battle_unit(guardian, Vector2i(1, 3), 1.0)
	print("A non-caster has no mana pool but a stamina one: mana=%d stamina=%d (expected 0, 100)" % [guardian_unit.max_mana, guardian_unit.max_stamina])
	print("The pool each pays from: druid=%s guardian=%s (expected mana, stamina)" % [main._unit_pool_name(armed), main._unit_pool_name(guardian_unit)])

	# =========================================================
	# The special-move menu
	# =========================================================
	_reset(main, player)
	var u1: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 4), 1.0)
	var g1 := _make_goblin(main, Vector2i(4, 4))
	main.battle_units = [g1]
	_start(main, u1)
	var info: Dictionary = main._ally_menu_info()
	var labels := []
	for s in info.specials:
		labels.append(s.label)
	print("Her special list shows each cost in her own currency -- her three spells, then the Staff's: %s (expected [Restore (40 MP), Empower (30 MP), Vitalize (40 MP), I CAST FIREBALL (40 MP), Landfall (60 MP), Channel (20 MP)])" % [labels])
	print("The Special button is available, Attack reads plain: has_specials=%s attack_label=%s (expected true, Attack)" % [info.has_specials, info.attack_label])
	main._on_battle_ally_action("special")
	print("Special opens the list: state=%s (expected ally_special)" % [main.battle_menu_state])
	main._on_battle_ally_action("back")
	print("Back returns to the main menu: state=%s (expected main)" % [main.battle_menu_state])

	# the Staff's own regular attack: magic damage, reaches 3 tiles
	var hp_before: int = g1.hp
	main._on_battle_ally_action("attack")
	print("A regular Staff attack hits from 3 tiles away for her MAGIC stat (18.4 -> 18): dealt=%d (expected 18)" % [hp_before - g1.hp])

	# =========================================================
	# Landfall
	# =========================================================
	_reset(main, player)
	var u2: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 4), 1.0)
	var ga := _make_goblin(main, Vector2i(4, 4))
	var gb := _make_goblin(main, Vector2i(7, 7))
	var gc := _make_goblin(main, Vector2i(2, 0))
	main.battle_units = [ga, gb, gc]
	_start(main, u2)
	u2.mana = 10
	main._on_battle_ally_action("special")
	main._on_battle_ally_action("special_4")
	print("Landfall refused without the mana: mana still %d (expected 10), nobody hurt=%s (expected true), still her turn=%s (expected true)" % [u2.mana, ga.hp == 999 and gb.hp == 999, main.battle_commanding_ally == u2])
	u2.mana = 92
	main._on_battle_ally_action("special_4")
	print("Landfall costs 60 mana: %d left (expected 32)" % [u2.mana])
	print("...and hits EVERY enemy anywhere for attack x3 + magic/2 = 3 + 9.2 = 12: dealt=%s (expected [12, 12, 12])" % [[999 - ga.hp, 999 - gb.hp, 999 - gc.hp]])

	# =========================================================
	# I CAST FIREBALL
	# =========================================================
	_reset(main, player)
	var u3: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 4), 1.0)
	var center := _make_goblin(main, Vector2i(6, 4))
	var adjacent := _make_goblin(main, Vector2i(6, 5))
	var diagonal := _make_goblin(main, Vector2i(7, 5))
	var far := _make_goblin(main, Vector2i(6, 7))
	main.battle_units = [center, adjacent, diagonal, far]
	main.battle_target_index = 0
	_start(main, u3)
	main._on_battle_ally_action("special")
	main._on_battle_ally_action("special_3")
	var filler3 := _filler()
	print("Turn 1: the fireball is only CHARGED: charging=%s, mana %d (expected true, 52), nobody hurt=%s (expected true)" % [not u3.charging.is_empty(), u3.mana, center.hp == 999 and adjacent.hp == 999])
	# the ally phase ended with a single ally; start a fresh ally phase for the release
	main.battle_turn = "player"
	main.battle_allies = [u3, filler3]
	main.battle_target_index = 0
	main.battle_units = [center, adjacent, diagonal, far]
	main._start_ally_turn()
	var charge_info: Dictionary = main._ally_menu_info()
	print("While charging she can't move or attack: move_disabled=%s attack_disabled=%s (expected true, true)" % [charge_info.move_disabled, charge_info.attack_disabled])
	print("...and her special list is just the release: %s (expected [Release: I CAST FIREBALL])" % [[charge_info.specials[0].label]])
	main._on_battle_ally_action("move")
	print("Trying to move while charging is refused: state=%s (expected main)" % [main.battle_menu_state])
	main._on_battle_ally_action("special")
	main._on_battle_ally_action("special_0")
	print("Release: the target is lit, the blast hits the 3x3 only -- centre 22, next to it 17, diagonal 12, outside untouched: %s (expected [22, 17, 12, 0])" % [[999 - center.hp, 999 - adjacent.hp, 999 - diagonal.hp, 999 - far.hp]])
	print("...the centre target is burning, the neighbours are not: %s / %s (expected true, false)" % [center.burning, adjacent.burning])
	print("...and releasing cost nothing extra: mana %d (expected 52)" % [u3.mana])
	print("...the charge is spent: %s (expected {})" % [u3.charging])

	# a downed caster loses the charge
	var u4: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 4), 1.0)
	u4.charging = {"id": "x", "name": "I CAST FIREBALL", "dmg_mult": 1.2, "effect": "fireball"}
	_reset(main, player)
	main.battle_allies = [u4]
	u4.hp = 0
	main._remove_fallen_allies()
	print("A caster knocked out mid-charge loses it: charging=%s (expected {})" % [u4.charging])

	# =========================================================
	# Channel and the friendly-target picker
	# =========================================================
	_reset(main, player)
	var caster: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 4), 1.0)
	var friend: Dictionary = main._make_member_battle_unit(guardian, Vector2i(1, 3), 1.0)
	var druid2 = player.recruit("druid")
	var other_caster: Dictionary = main._make_member_battle_unit(druid2, Vector2i(1, 2), 1.0)
	main.battle_units = [_make_goblin(main, Vector2i(6, 6))]
	main.battle_allies = [caster, friend, other_caster]
	main._start_ally_turn()
	main._on_battle_ally_action("special")
	main._on_battle_ally_action("special_5")
	var pick_labels := []
	for p in main._ally_menu_info().picks:
		pick_labels.append(p.label.split("  ")[0])
	print("Channel opens the target picker: state=%s, candidates=%s (expected ally_pick, [You, Guardian, Druid])" % [main.battle_menu_state, pick_labels])
	player.stamina = 10
	main._on_battle_ally_action("pick_0")
	print("Channelling into YOU gives 20%% of your max stamina: %d (expected 30), and costs her 20 mana: %d (expected 72)" % [player.stamina, caster.mana])
	print("...the picker is closed and her command ended: pending=%s commanding_changed=%s (expected {}, true)" % [main.battle_ally_pending_action, main.battle_commanding_ally != caster])
	# a stamina ally, then a caster ally
	_reset(main, player)
	caster.mana = 92
	friend.stamina = 0
	other_caster.mana = 20
	main.battle_units = [_make_goblin(main, Vector2i(6, 6))]
	main.battle_allies = [caster, friend, other_caster]
	main._start_ally_turn()
	main._on_battle_ally_action("special")
	main._on_battle_ally_action("special_5")
	main._on_battle_ally_action("pick_1")
	print("Channel into a stamina ally: +20%% of 100 = %d (expected 20)" % [friend.stamina])
	main.battle_allies = [caster, friend, other_caster]
	main.battle_turn = "player"
	main.battle_commanding_ally = null
	main.battle_ally_queue = []
	caster.mana = 92
	main._start_ally_turn()
	main._on_battle_ally_action("special")
	main._on_battle_ally_action("special_5")
	main._on_battle_ally_action("pick_2")
	print("Channel into a caster ally: +20%% of %d mana = %d now (expected 20 + 10 = 30)" % [other_caster.max_mana, other_caster.mana])
	main.battle_turn = "player"
	main.battle_commanding_ally = null
	main.battle_ally_queue = []
	main.battle_allies = [caster]
	main._start_ally_turn()
	main._on_battle_ally_action("special")
	main._on_battle_ally_action("special_5")
	main._on_battle_ally_action("back")
	print("Back out of the picker returns to the special list: state=%s (expected ally_special)" % [main.battle_menu_state])

	# =========================================================
	# Downed allies
	# =========================================================
	_reset(main, player)
	var fallen_member = player.recruit("rogue")
	var fallen: Dictionary = main._make_member_battle_unit(fallen_member, Vector2i(2, 4), 1.0)
	var standing: Dictionary = main._make_member_battle_unit(guardian, Vector2i(3, 4), 1.0)
	main.battle_allies = [fallen, standing]
	main.battle_units = [_make_goblin(main, Vector2i(6, 6))]
	fallen.hp = 0
	main._remove_fallen_allies()
	print("An ally at 0 HP is DOWNED, not gone: in battle_allies=%s in downed=%s (expected false, true)" % [main.battle_allies.has(fallen), main.battle_downed_allies.has(fallen)])
	print("...it has no collision any more: tile occupied=%s (expected false)" % [main._battle_tile_occupied(Vector2i(2, 4))])
	print("...enemies ignore it entirely: only the standing ally and the hero are targets (assigned=%d targets)" % [main._assign_enemy_targets().size()])
	print("...and it still counts as having fainted for the end-of-battle settlement: %s (expected true)" % [main.battle_fainted_members.has(fallen_member)])
	var picks: Array = main._ally_pick_candidates(standing, "downed")
	print("Your own side can target it: %d candidate (expected 1), labelled '%s'" % [picks.size(), picks[0].label if not picks.is_empty() else ""])
	main._revive_downed(fallen, 1.0)
	print("Revived: back on the grid=%s at full HP %d/%d (expected true, equal), no longer downed=%s, no faint counted=%s (expected true, true)" % [main.battle_allies.has(fallen), fallen.hp, fallen.max_hp, not main.battle_downed_allies.has(fallen), not main.battle_fainted_members.has(fallen_member)])
	print("It stood up on its own tile: %s (expected (2, 4))" % [fallen.tile])
	# revival blocked tile: someone is standing on it
	var fallen2: Dictionary = main._make_member_battle_unit(player.recruit("marksman"), Vector2i(4, 4), 1.0)
	main.battle_downed_allies = [fallen2]
	var blocker := _make_goblin(main, Vector2i(4, 4))
	main.battle_units.append(blocker)
	main._revive_downed(fallen2, 1.0)
	print("If its tile got taken it stands on the nearest free one: %s (expected not (4, 4))" % [fallen2.tile])
	# the revive effect itself, as an action
	_reset(main, player)
	var reviver: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 4), 1.0)
	var body: Dictionary = main._make_member_battle_unit(guardian, Vector2i(2, 4), 1.0)
	main.battle_allies = [reviver, body]
	main.battle_units = [_make_goblin(main, Vector2i(6, 6))]
	body.hp = 0
	main._remove_fallen_allies()
	main.battle_commanding_ally = reviver
	main.battle_ally_target = body
	main.battle_actor = reviver
	await main._battle_perform_attack({"stamina_cost": 0, "dmg_mult": 0.0, "effect": "revive", "name": "Revival Blessing"})
	print("The revive EFFECT stands a downed ally up: %s (expected true)" % [main.battle_allies.has(body) and body.hp == body.max_hp])

	# =========================================================
	# Paying: mana, stamina, and HP-as-mana
	# =========================================================
	var hp_caster := {"hp": 20, "max_hp": 20, "hp_as_mana": true, "max_mana": 50, "mana": 50, "stamina": 0, "max_stamina": 0}
	print("An HP-as-mana caster pays 1 HP per 5 mana: Fireball (40) costs %d HP (expected 8), pool=%s" % [main._unit_cost_amount(hp_caster, 40), main._unit_pool_name(hp_caster)])
	main.battle_actor = hp_caster
	var paid: bool = main._actor_pays(40)
	print("...it pays: %s, HP left %d (expected true, 12)" % [paid, hp_caster.hp])
	hp_caster.hp = 5
	print("...but never down to 0 HP: can_pay Fireball at 5 HP = %s (expected false), can_pay a 20-mana spell (4 HP) = %s (expected true)" % [main._unit_can_pay(hp_caster, 40), main._unit_can_pay(hp_caster, 20)])
	var sta_unit := {"hp": 20, "max_hp": 20, "max_mana": 0, "mana": 0, "stamina": 30, "max_stamina": 100}
	main.battle_actor = sta_unit
	print("A stamina ally pays stamina: %s then %d left (expected true, 5), refused at 5: %s (expected false)" % [main._actor_pays(25), sta_unit.stamina, main._actor_pays(25)])
	main._actor_refund(10)
	print("A refund goes back into the same pool: %d (expected 15)" % [sta_unit.stamina])
	main.battle_actor = {}

	# =========================================================
	# The shared hit pipeline reads the ACTING unit's own gear
	# =========================================================
	_reset(main, player)
	var striker: Dictionary = main._make_member_battle_unit(guardian, Vector2i(1, 4), 1.0)
	striker.attack = 20.0
	var target := _make_goblin(main, Vector2i(2, 4))
	main.battle_units = [target]
	var plain := {"stamina_cost": 0, "dmg_mult": 1.0, "effect": "", "name": "Attack", "is_regular_attack": true}
	var swing := func(unit: Dictionary) -> int:
		target.hp = 999
		target.burning = false
		target.vulnerable_turns = 0
		target.tile = Vector2i(2, 4)
		var filler := _filler()
		main.battle_commanding_ally = unit
		main.battle_actor = unit
		main.battle_allies = [unit, filler]
		main.battle_ally_queue = [filler]
		main.battle_units = [target]
		main.battle_downed_allies = []
		main.battle_first_attack_used = true
		await main._battle_perform_attack(plain.duplicate())
		main.battle_actor = {}
		return 999 - target.hp
	var base_dmg: int = await swing.call(striker)
	print("Baseline ally swing (attack 20, bare hands): %d (expected 20)" % [base_dmg])
	player.pichaku_active = true
	var pichaku_dmg: int = await swing.call(striker)
	print("The HERO's Pichaku no longer leaks onto an ally's hits: %d (expected 20)" % [pichaku_dmg])
	player.pichaku_active = false
	striker.mods = {"damage_pct": 0.5}
	print("Its own talisman: +50%% damage -> %d (expected 30)" % [await swing.call(striker)])
	striker.mods = {"crit_chance": 1.0}
	print("Its own crit chance (hero's stat is not used): %d (expected 40, a double-damage crit)" % [await swing.call(striker)])
	striker.mods = {"crit_chance": 1.0, "crit_damage_mult_bonus": 0.5}
	print("...a crit-damage talisman adds to the multiplier: %d (expected 50, x2.5)" % [await swing.call(striker)])
	striker.mods = {}
	player.talisman_bonus("crit_chance")
	print("With no talismans it never crits off the hero's stat: %d (expected 20)" % [await swing.call(striker)])
	striker.mods = {"lifesteal_pct": 0.5}
	striker.hp = 10
	player.health = 400
	await swing.call(striker)
	print("Vampire's Pact on an ally heals THAT ally, not the hero: ally=%d (expected 20), hero=%d (expected 400)" % [striker.hp, player.health])
	striker.mods = {"low_hp_damage_pct": 1.0}
	striker.hp = 4
	striker.max_hp = 50
	print("Low-HP damage reads the ALLY's own health: %d (expected 40)" % [await swing.call(striker)])
	striker.hp = 50
	player.health = 5
	print("...and ignores the hero's: %d (expected 20)" % [await swing.call(striker)])
	player.health = 400
	striker.mods = {"burn_chance": 1.0}
	await swing.call(striker)
	print("Ember Charm on an ally sets the target alight: burning=%s (expected true)" % [target.burning])
	striker.mods = {}
	striker.hp = 50
	# knockback goes away from the ATTACKER, not from the hero
	var knock_target := _make_goblin(main, Vector2i(6, 3))
	main.battle_units = [knock_target]
	var knocker: Dictionary = main._make_member_battle_unit(guardian, Vector2i(6, 1), 1.0)
	knocker.attack = 5.0
	main.battle_player_tile = Vector2i(0, 3)
	var knock_filler := _filler()
	main.battle_allies = [knocker, knock_filler]
	main.battle_ally_queue = [knock_filler]
	main.battle_commanding_ally = knocker
	main.battle_actor = knocker
	knocker.attack_range = 3
	await main._battle_perform_attack(plain.duplicate())
	main.battle_actor = {}
	print("An ally knocks the enemy back away from ITSELF (down the column), not away from the hero: tile=%s (expected (6, 4))" % [knock_target.tile])

	# a staggered ally loses its command
	_reset(main, player)
	var tired: Dictionary = main._make_member_battle_unit(guardian, Vector2i(1, 4), 1.0)
	var ready: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 3), 1.0)
	tired.skip_turns = 1
	main.battle_units = [_make_goblin(main, Vector2i(6, 6))]
	main.battle_allies = [tired, ready]
	main._start_ally_turn()
	print("A staggered ally is skipped, the next one commands: commanding=%s skip_turns_left=%d (expected Druid, 0)" % [main.battle_commanding_ally.name, tired.skip_turns])

	# =========================================================
	# Blindness from the Staff
	# =========================================================
	_reset(main, player)
	var archer: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 4), 1.0)
	archer.weapon = archer.weapon.duplicate(true)
	archer.weapon["passive_ranged_blind_chance"] = 1.0
	var near_target := _make_goblin(main, Vector2i(2, 4))
	var far_target := _make_goblin(main, Vector2i(4, 4))
	main.battle_units = [near_target, far_target]
	var archer_filler := _filler()
	main.battle_allies = [archer, archer_filler]
	main.battle_ally_queue = [archer_filler]
	main.battle_commanding_ally = archer
	main.battle_actor = archer
	main.battle_target_index = 0
	await main._battle_perform_attack(plain.duplicate())
	print("A point-blank Staff hit does not blind: blind_turns=%d (expected 0)" % [near_target.get("blind_turns", 0)])
	main.battle_actor = archer
	main.battle_commanding_ally = archer
	main.battle_ally_queue = [archer_filler]
	main.battle_allies = [archer, archer_filler]
	main.battle_target_index = 1
	await main._battle_perform_attack(plain.duplicate())
	print("A RANGED one blinds (chance forced to 100%%): blind_turns=%d (expected %d)" % [far_target.get("blind_turns", 0), main.BLINDNESS_TURNS])
	main.battle_actor = {}
	main.battle_units = [far_target]
	far_target.tile = Vector2i(0, 3)
	main.battle_player_tile = Vector2i(0, 4)
	main.battle_allies = []
	player.health = 500
	main._process_enemy_turn()
	print("Blindness ticks down on the enemy's turn: %d (expected 1)" % [far_target.get("blind_turns", 0)])

	quit()
