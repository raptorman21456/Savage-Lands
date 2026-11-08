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
	# A caster's mana is 20 + 5 per point of Intelligence now. These checks were written against the pools a Staff (86) and a
	# Wand (80) used to give, so the caster gets the Intelligence that makes it so; what they test is what the spells do with the pool.
	var rules = load("res://scripts/PartyRules.gd")
	if member.is_caster() and weapon_id.begins_with("staff"):
		member.extra["intelligence"] = 13.2 - rules.extra_base(kind, "intelligence")
	elif member.is_caster() and weapon_id.begins_with("wand"):
		member.extra["intelligence"] = 12.0 - rules.extra_base(kind, "intelligence")
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
	# Magic from a Staff or Wand used to be a flat +5 / +6; the doc's per-quality-tier version (test_weapon_stat_bonuses.gd) gives a Fine one
	# (the second rung) the same figures at 2.5 / 3.0 a tier, so these checks keep the numbers they were written against.
	var _magic_weapons = load("res://scripts/Weapons.gd")
	_magic_weapons.STAFF["magic_per_tier"] = 2.5
	_magic_weapons.WAND["magic_per_tier"] = 3.0
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
	player.owned_weapons["wand_fine_steel"] = true
	player.owned_weapons["wand_mythic"] = true
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
	# Mana is 20 + 5 per point of Intelligence now; these checks were written against the 86 a Staff-wielding Druid used to have.
	druid.extra["intelligence"] = 7.2
	var armed: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 4), 1.0)
	print("With a Staff (+5 magic, then her x1.15 favour): magic=%.2f mana=%d (expected 17.25, 86)" % [armed.magic, armed.max_mana])
	print("...range is 1 + 2 = %d (expected 3), the weapon is %s, and Landfall costs %d%% of her mana (expected Staff, 40)" % [armed.attack_range, armed.weapon.name, int(round(float(armed.weapon.specials[1].cost_pct_max) * 100.0))])
	# The Wand: +6 magic and +3 range (the Druid has no favour for it); a Moonstick doubles what levelling GAINED.
	player.unequip_ally_weapon(druid)
	player.equip_ally_weapon(druid, "wand_fine_steel")
	druid.extra["intelligence"] = 6.0   # ...and the 80 of a Wand-wielding one
	var wand_unit: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 4), 1.0)
	print("With a Wand (+6 magic, no favour): magic=%.2f mana=%d range=%d (expected 16.00, 80, 4)" % [wand_unit.magic, wand_unit.max_mana, wand_unit.attack_range])
	druid.bonus.magic = 4.0
	var gained: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 4), 1.0)
	player.unequip_ally_weapon(druid)
	player.equip_ally_weapon(druid, "wand_mythic")
	var moon: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 4), 1.0)
	print("Levelled-up magic (+4): %.2f; with Moonstick doubling the GAIN: %.2f (expected 20.00, 33.00: 10 + 8 gained + 15 from a Mythic wand at 3.0 a tier)" % [gained.magic, moon.magic])
	druid.bonus.magic = 0.0
	player.unequip_ally_weapon(druid)
	player.equip_ally_weapon(druid, "staff_fine_steel")
	druid.extra["intelligence"] = 7.2   # back to the Staff-wielder's 86
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
	print("Her special list shows each cost in her own currency -- her three spells, then the Staff's: %s (expected [Vitalize (25 MP), Empower (35 MP), Call the Wild (50 MP), Poison Bomb (35 MP), Landfall (34 MP), I SUMMON THEE (43 MP), Stealth (20 MP) -- every member has Stealth])" % [labels])
	print("The Special button is available, and the Staff turns Attack into Pummel: has_specials=%s attack_label=%s (expected true, Pummel (15 MP))" % [info.has_specials, info.attack_label])
	main._on_battle_ally_action("special")
	print("Special opens the list: state=%s (expected ally_special)" % [main.battle_menu_state])
	main._on_battle_ally_action("back")
	print("Back returns to the main menu: state=%s (expected main)" % [main.battle_menu_state])

	# the Staff's regular attack is Pummel: it only reaches an enemy within one tile
	var hp_before: int = g1.hp
	var mana_before_pummel: int = u1.mana
	main._on_battle_ally_action("attack")
	print("Pummel refuses an enemy 3 tiles away: dealt=%d (expected 0), mana still %d (expected %d)" % [hp_before - g1.hp, u1.mana, mana_before_pummel])
	var close_goblin := _make_goblin(main, Vector2i(2, 4))
	main.battle_units = [g1, close_goblin]
	main.battle_target_index = 1
	main._on_battle_ally_action("attack")
	print("...next to an enemy it hits for (0.85 x STR) + (0.25 x MAG) = 0.85 + 4.31 = 5: dealt=%d (expected 5), costs 15 mana: %d left (expected %d)" % [999 - close_goblin.hp, u1.mana, mana_before_pummel - 15])

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
	u2.mana = u2.max_mana
	main._on_battle_ally_action("special_4")
	print("Landfall costs 40%% of her 86 mana = 34: %d left (expected 52)" % [u2.mana])
	print("...and hits EVERY enemy anywhere for attack x3 + magic/2 = 3 + 8.6 = 12: dealt=%s (expected [12, 12, 12])" % [[999 - ga.hp, 999 - gb.hp, 999 - gc.hp]])

	# =========================================================
	# I CAST FIREBALL (the Wand's: a 5x5 blast)
	# =========================================================
	_reset(main, player)
	player.unequip_ally_weapon(druid)
	player.equip_ally_weapon(druid, "wand_fine_steel")
	druid.extra["intelligence"] = 6.0   # a Wand-wielder's 80
	var u3: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 4), 1.0)
	var center := _make_goblin(main, Vector2i(6, 4))
	var adjacent := _make_goblin(main, Vector2i(6, 5))
	var diagonal := _make_goblin(main, Vector2i(7, 5))
	var two_away := _make_goblin(main, Vector2i(6, 6))
	var corner := _make_goblin(main, Vector2i(8, 6))
	var far := _make_goblin(main, Vector2i(6, 7))
	var foes := [center, adjacent, diagonal, two_away, corner, far]
	main.battle_units = foes.duplicate()
	main.battle_target_index = 0
	_start(main, u3)
	main._on_battle_ally_action("special")
	main._on_battle_ally_action("special_5")
	var filler3 := _filler()
	print("Turn 1: the fireball is only CHARGED (80%% of her 80 mana = 64): charging=%s, mana %d (expected true, 16), nobody hurt=%s (expected true)" % [not u3.charging.is_empty(), u3.mana, center.hp == 999 and adjacent.hp == 999])
	# the ally phase ended with a single ally; start a fresh ally phase for the release
	main.battle_turn = "player"
	main.battle_allies = [u3, filler3]
	main.battle_target_index = 0
	main.battle_units = foes.duplicate()
	main._start_ally_turn()
	var charge_info: Dictionary = main._ally_menu_info()
	print("While charging she can't move or attack: move_disabled=%s attack_disabled=%s (expected true, true)" % [charge_info.move_disabled, charge_info.attack_disabled])
	print("...and her special list is just the release: %s (expected [Release: I CAST FIREBALL])" % [[charge_info.specials[0].label]])
	main._on_battle_ally_action("move")
	print("Trying to move while charging is refused: state=%s (expected main)" % [main.battle_menu_state])
	main._on_battle_ally_action("special")
	main._on_battle_ally_action("special_0")
	print("Release: the blast hits the 5x5 -- magic 16 x 2.5 = 40 at the centre, 5 less per tile: centre 40, next to it 35, diagonal 30, two away 30, the far corner 20, outside untouched: %s (expected [40, 35, 30, 30, 20, 0])" % [[999 - center.hp, 999 - adjacent.hp, 999 - diagonal.hp, 999 - two_away.hp, 999 - corner.hp, 999 - far.hp]])
	print("...everything left alive in the blast is set on fire, what is outside is not: %s / %s (expected true / false)" % [[center.burning, adjacent.burning, corner.burning].all(func(b): return b), far.burning])
	print("...and releasing cost nothing extra: mana %d (expected 16)" % [u3.mana])
	print("...the charge is spent: %s (expected {})" % [u3.charging])
	player.unequip_ally_weapon(druid)
	player.equip_ally_weapon(druid, "staff_fine_steel")
	druid.extra["intelligence"] = 7.2   # a Staff-wielder's 86

	# a downed caster loses the charge
	var u4: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 4), 1.0)
	u4.charging = {"id": "x", "name": "I CAST FIREBALL", "dmg_mult": 1.2, "effect": "fireball"}
	_reset(main, player)
	main.battle_allies = [u4]
	u4.hp = 0
	main._remove_fallen_allies()
	print("A caster knocked out mid-charge loses it: charging=%s (expected {})" % [u4.charging])

	# =========================================================
	# I SUMMON THEE (it replaced Channel) and the tile picker
	# =========================================================
	_reset(main, player)
	var caster: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 4), 1.0)
	main.battle_units = [_make_goblin(main, Vector2i(6, 6))]
	main.battle_allies = [caster, _filler()]
	main._start_ally_turn()
	var summon_label: String = ""
	for s in main._ally_menu_info().specials:
		if s.label.begins_with("I SUMMON THEE"):
			summon_label = s.label
	print("Her Staff has I SUMMON THEE, costing HALF her mana: '%s' (expected I SUMMON THEE (%d MP), half of %d)" % [summon_label, int(round(caster.max_mana * 0.5)), caster.max_mana])
	main._on_battle_ally_action("special")
	main._on_battle_ally_action("special_5")
	var pick_labels := []
	for p in main._ally_menu_info().picks:
		pick_labels.append(p.label)
	print("It opens a tile picker offering two spots: state=%s, candidates=%s (expected ally_pick, [Beside <her name>, Beside the nearest enemy])" % [main.battle_menu_state, pick_labels])
	var mana_before: int = caster.mana
	main._on_battle_ally_action("pick_0")
	var spectre: Dictionary = {}
	for a in main.battle_allies:
		if str(a.get("kind", "")) == "spectre":
			spectre = a
	print("Choosing a spot raises a spectre ally: %s (expected true), its mana cost %d (expected %d)" % [not spectre.is_empty(), mana_before - caster.mana, int(round(caster.max_mana * 0.5))])
	print("...the picker is closed and her command ended: pending=%s commanding_changed=%s (expected {}, true)" % [main.battle_ally_pending_action, main.battle_commanding_ally != caster])
	print("Its stats are shares of hers: attack=%.2f (expected %.2f = 80%% of her attack + 80%% of her magic), max_hp=%d (expected %d, half of hers), speed=%.2f (expected %.2f, 120%%)" % [
		spectre.attack, 0.8 * float(caster.attack) + 0.8 * float(caster.magic), spectre.max_hp, int(round(caster.max_hp * 0.5)), spectre.speed, float(caster.speed) * 1.2
	])
	print("...it dodges half of all attacks, ignores terrain, has no armour and acts on its own: dodge=%.2f (expected 0.50), ignores_terrain=%s auto=%s summoned=%s (expected true x3), defense=%.1f fortitude=%.1f (expected 0, 0)" % [
		spectre.dodge_chance, spectre.ignores_terrain, spectre.auto, spectre.summoned, spectre.defense_pct, spectre.fortitude
	])

	# Clicking ANY empty tile on the grid places it there -- even one with rock on it -- and an occupied tile is refused.
	_reset(main, player)
	main.battle_units = [_make_goblin(main, Vector2i(6, 6))]
	main.battle_allies = [caster, _filler()]
	caster.mana = caster.max_mana
	main._start_ally_turn()
	main.battle_terrain[Vector2i(4, 2)] = {"type": "rock"}
	main._on_battle_ally_action("special")
	main._on_battle_ally_action("special_5")
	main._on_rock_target_selected(Vector2i(6, 6))
	print("Clicking an occupied tile is refused and the picker stays open: state=%s (expected ally_pick), no spectre yet=%s (expected true)" % [main.battle_menu_state, not main.battle_allies.any(func(a): return str(a.get("kind", "")) == "spectre")])
	main._on_rock_target_selected(Vector2i(4, 2))
	var placed: Dictionary = {}
	for a in main.battle_allies:
		if str(a.get("kind", "")) == "spectre":
			placed = a
	print("Clicking a rock tile raises it right there (it ignores terrain): tile=%s (expected (4, 2))" % [placed.get("tile", "none")])

	# It walks through rock and strikes the nearest enemy on its own turn.
	_reset(main, player)
	var foe := _make_goblin(main, Vector2i(2, 7))
	main.battle_units = [foe]
	var ghost: Dictionary = main._make_spectre(Vector2i(2, 2), caster)
	for y in [3, 4, 5]:
		main.battle_terrain[Vector2i(2, y)] = {"type": "rock"}
	main.battle_allies = [ghost]
	main._auto_ally_act(ghost)
	print("On its own turn it walks THROUGH a wall of rock toward the enemy: it moved from y=2 to y=%d (expected %d, its full move of %d)" % [ghost.tile.y, 2 + int(ghost.move_range), ghost.move_range])
	ghost.tile = Vector2i(2, 6)
	main._auto_ally_act(ghost)
	print("...and hits the enemy when it reaches it: goblin HP %d (expected below 999)" % [foe.hp])

	# Its price follows the caster's own currency: HP for the Necromancer, stamina for anyone without mana.
	_reset(main, player)
	var necro: Dictionary = _member_unit(main, player, "necromancer", "staff_worn_wood", Vector2i(1, 4))
	var necro_cost_text := ""
	for e in main.member_special_pool(necro.member):
		if str(e.special.name) == "I SUMMON THEE":
			necro_cost_text = e.cost_text
	print("A Necromancer pays in HP, half her max (%d): '%s' (expected ' (%d HP)')" % [necro.max_hp, necro_cost_text, int(round(necro.max_hp * 0.5))])
	var knight_u: Dictionary = _member_unit(main, player, "knight", "staff_worn_bone", Vector2i(1, 4))
	var knight_cost := ""
	for e in main.member_special_pool(knight_u.member):
		if str(e.special.name) == "I SUMMON THEE":
			knight_cost = e.cost_text
	print("Someone with no mana pool pays stamina, half of %d: '%s' (expected ' (%d STA)')" % [knight_u.max_stamina, knight_cost, int(round(knight_u.max_stamina * 0.5))])
	main.battle_allies = [caster]
	player.set_spell_level_of(druid, "staff_i_summon_thee", 2)
	var ex_unit: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 4), 1.0)
	var ex_spectre: Dictionary = main._make_spectre(Vector2i(3, 3), ex_unit)
	print("At EX the spectre is much stronger (attack %.2f vs %.2f), dodges 60%% (%.2f), and the cast costs 40%% of her mana (%d of %d): (expected true, 0.60, %d)" % [
		ex_spectre.attack, spectre.attack, ex_spectre.dodge_chance, int(round(ex_unit.max_mana * 0.4)), ex_unit.max_mana, int(round(ex_unit.max_mana * 0.4))
	])
	player.spell_levels.clear()

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
	await main._battle_perform_attack({"stamina_cost": 0, "dmg_mult": 0.0, "effect": "revive", "name": "Energy Transfer"})
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
	print("Its own crit chance (hero's stat is not used): %d (expected 50, a x2.5 crit: 250%%)" % [await swing.call(striker)])
	striker.mods = {"crit_chance": 1.0, "crit_damage_mult_bonus": 0.5}
	print("...a crit-damage talisman adds to the multiplier: %d (expected 60, x3.0: 250%% plus the talisman's 50%%)" % [await swing.call(striker)])
	striker.mods = {}
	player.talisman_bonus("crit_chance")
	print("With no talismans it never crits off the hero's stat: %d (expected 20)" % [await swing.call(striker)])
	striker.mods = {"lifesteal_pct": 0.5}
	striker.hp = 10
	player.health = 400
	await swing.call(striker)
	print("Bat Fang on an ally heals THAT ally, not the hero: ally=%d (expected 20), hero=%d (expected 400)" % [striker.hp, player.health])
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
	print("Pyrogenesis Organ on an ally sets the target alight: burning=%s (expected true)" % [target.burning])
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
	# Fear from the Staff, blindness from the Wand
	# =========================================================
	_reset(main, player)
	var archer: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 4), 1.0)
	archer.weapon = archer.weapon.duplicate(true)
	archer.weapon["passive_ranged_fear_chance"] = 1.0
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
	print("A point-blank Staff hit does not frighten: fear_turns=%d (expected 0)" % [near_target.get("fear_turns", 0)])
	main.battle_actor = archer
	main.battle_commanding_ally = archer
	main.battle_ally_queue = [archer_filler]
	main.battle_allies = [archer, archer_filler]
	main.battle_target_index = 1
	await main._battle_perform_attack(plain.duplicate())
	print("A RANGED one frightens (chance forced to 100%%): fear_turns=%d (expected %d)" % [far_target.get("fear_turns", 0), main.FEAR_TURNS])
	main.battle_actor = {}
	main.battle_units = [far_target]
	far_target.tile = Vector2i(0, 3)
	main.battle_player_tile = Vector2i(0, 4)
	main.battle_allies = []
	player.health = 500
	main._process_enemy_turn()
	print("A frightened enemy runs from the hero instead of attacking: fear_turns now %d (expected 1), hero untouched=%s (expected true), distance %d (expected 3 or more, it was 1)" % [far_target.get("fear_turns", 0), player.health == 500, abs(far_target.tile.x - 0) + abs(far_target.tile.y - 4)])
	# The Wand: blinds on ANY landed hit, and has no close-quarters attack
	_reset(main, player)
	player.unequip_ally_weapon(druid)
	player.equip_ally_weapon(druid, "wand_fine_steel")
	druid.extra["intelligence"] = 6.0
	var wander: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 4), 1.0)
	wander.weapon = wander.weapon.duplicate(true)
	wander.weapon["passive_blind_chance"] = 1.0
	var wand_near := _make_goblin(main, Vector2i(2, 4))
	var wand_far := _make_goblin(main, Vector2i(4, 4))
	var wand_filler := _filler()
	main.battle_units = [wand_near, wand_far]
	main.battle_allies = [wander, wand_filler]
	main.battle_ally_queue = [wand_filler]
	main.battle_commanding_ally = wander
	main.battle_actor = wander
	main.battle_target_index = 0
	await main._battle_perform_attack(plain.duplicate())
	print("The Wand will not strike the enemy next to it, and picks the far one instead: near untouched=%s, far hit=%s (expected true, true)" % [wand_near.hp == 999, wand_far.hp < 999])
	print("...every hit it lands can blind (chance forced to 100%%): blind_turns=%d (expected %d)" % [wand_far.get("blind_turns", 0), main.BLINDNESS_TURNS])
	main.battle_units = [wand_near]
	main.battle_actor = wander
	var near_hp: int = wand_near.hp
	await main._battle_perform_attack(plain.duplicate())
	print("With only an adjacent enemy the Wand has no attack: dealt=%d (expected 0)" % [near_hp - wand_near.hp])
	main.battle_actor = {}
	player.unequip_ally_weapon(druid)
	player.equip_ally_weapon(druid, "staff_fine_steel")
	druid.extra["intelligence"] = 7.2

	quit()
