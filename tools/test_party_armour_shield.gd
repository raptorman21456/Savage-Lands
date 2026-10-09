extends SceneTree

# Armour and shield slots on party members: who may hold what (one holder per item), what they add to
# the battle unit (Defense, Fortitude, move, stamina, dodge), how every armour trait and shield special
# plays out on a member, and the Inventory / Sandbox pickers.

const SandboxScript := preload("res://scripts/Sandbox.gd")

func _find_all(node: Node, type_name: String, out: Array) -> void:
	for c in node.get_children():
		if c.get_class() == type_name:
			out.append(c)
		_find_all(c, type_name, out)

func _texts(node: Node) -> Array:
	var out := []
	for kind in ["Button", "Label", "OptionButton"]:
		var found := []
		_find_all(node, kind, found)
		for n in found:
			if kind == "OptionButton":
				for i in n.item_count:
					out.append(n.get_item_text(i))
			else:
				out.append(n.text)
	return out

func _foe(main, tile: Vector2i, range_: int = 1, hp: int = 999) -> Dictionary:
	var g = load("res://scripts/Enemy.gd").new()
	main.add_child(g)
	g.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	return {
		"ref": g, "tile": tile, "hp": hp, "max_hp": hp, "move_range": 2, "damage": 1,
		"name": "Goblin", "winding_up": false, "stunned": false, "attack_range": range_,
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
	main.battle_player_tile = Vector2i(9, 9)
	main.battle_turn = "enemy"
	main.battle_player_defending = false
	main.tutorial_active = false
	main.battle_first_attack_used = true
	player.miss_chance_override = 0.0
	player.shared_talisman_provider = Callable()
	player.meta_last_stand_pct_per_10 = 0.0
	player.equipped_armor = load("res://scripts/Armor.gd").find("armor_rags")
	player.equipped_shield = {}
	player.max_health = 500
	player.health = 500

# A member's battle unit with no random procs (the numbers below are exact), standing on `tile`.
func _unit(main, member, tile: Vector2i) -> Dictionary:
	var u: Dictionary = main._make_member_battle_unit(member, tile, 1.0)
	u.mods = {}
	u.weapon = {"damage_mult": 1.0}
	u["dodge_chance"] = 0.0
	u["shield_block"] = 0.0
	u["attack"] = 100.0
	return u

func _hit_for(main, u: Dictionary, foe: Dictionary) -> int:
	foe.hp = 999
	foe["vulnerable_turns"] = 0
	main.battle_units = [foe]
	main.battle_actor = u
	main._hit(0, 1.0, "", u.weapon)
	main.battle_actor = {}
	return 999 - foe.hp

func _taken(main, u: Dictionary, foe: Dictionary, dmg: int, traits: Dictionary = {}) -> int:
	foe["burning"] = false
	u.hp = 1000
	u.max_hp = 1000
	main.battle_allies = [u]
	await main._enemy_apply_damage(foe, u.tile, dmg, traits)
	return 1000 - int(u.hp)

func _init() -> void:
	seed(20261012)
	var armor_script = load("res://scripts/Armor.gd")
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	player.party.clear()
	player.max_party_slots = 20
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	var knight = player.recruit("knight")
	var brawler = player.recruit("brawler")
	var guardian = player.recruit("guardian")
	var marksman = player.recruit("marksman")
	var wolf = player.recruit("wolf")
	var druid = player.recruit("druid")

	# =========================================================
	# Who may hold what
	# =========================================================
	for id in ["armor_gambeson", "armor_thornmail", "armor_stonehide", "armor_fortress"]:
		player.owned_armor[id] = true
	print("A wolf wears nothing: %s (expected false)" % [player.equip_ally_armor(wolf, "armor_gambeson")])
	print("An armour you don't own is refused: %s -- %s (expected false, You don't own that armour.)" % [player.equip_ally_armor(knight, "armor_bastion"), player.ally_armor_block_reason(knight, "armor_bastion")])
	print("Rags are 'no armour', never held: %s (expected false)" % [player.equip_ally_armor(knight, "armor_rags")])
	print("The Knight takes the Gambeson: %s, wearing %s (expected true, armor_gambeson)" % [player.equip_ally_armor(knight, "armor_gambeson"), knight.armor_id()])
	print("The Brawler can't have it too: %s -- %s (expected false, Knight is wearing it.)" % [player.equip_ally_armor(brawler, "armor_gambeson"), player.ally_armor_block_reason(brawler, "armor_gambeson")])
	print("...the holder lookup agrees: %s (expected Knight)" % [player.armor_holder("armor_gambeson").name])
	player.try_buy_armor(armor_script.find("armor_gambeson"))
	print("You put the Gambeson on -- you have the final say, it leaves the Knight: knight='%s' you=%s (expected '', armor_gambeson)" % [knight.armor_id(), player.equipped_armor.id])
	print("...and you can't give it away while you wear it: %s (expected You are wearing it.)" % [player.ally_armor_block_reason(knight, "armor_gambeson")])
	player.try_buy_armor(armor_script.find("armor_rags"))
	player.equip_ally_armor(knight, "armor_gambeson")
	player.unequip_ally_armor(knight)
	print("Taking it off frees it: knight='%s' holder=%s (expected '', <null>)" % [knight.armor_id(), player.armor_holder("armor_gambeson")])

	print("A shield you don't own is refused: %s -- %s (expected false, You don't own that shield.)" % [player.equip_ally_shield(knight, "shield_heavy"), player.ally_shield_block_reason(knight, "shield_heavy")])
	player.owned_shields["shield_heavy"] = true
	player.owned_shields["shield_bulwark"] = true
	player.owned_shields["shield_phantom"] = true
	player.owned_shields["shield_brawler"] = true
	print("Once owned the Knight takes it (%s, expected true); the free Buckler needs no owning (%s, expected true)" % [player.equip_ally_shield(knight, "shield_heavy"), player.equip_ally_shield(brawler, "shield_buckler")])
	print("The Heavy Shield is on the Knight only: brawler refused=%s (%s) (expected false, Knight is using it.)" % [player.equip_ally_shield(brawler, "shield_heavy"), player.ally_shield_block_reason(brawler, "shield_heavy")])
	player.equip_ally_shield(guardian, "shield_buckler")
	print("The free Buckler can be carried by several at once: brawler=%s guardian=%s (expected shield_buckler, shield_buckler)" % [brawler.shield_id(), guardian.shield_id()])
	player.equip_shield(load("res://scripts/Shields.gd").SHIELDS["shield_heavy"])
	print("You take the Heavy Shield: it leaves the Knight: knight='%s' you=%s (expected '', shield_heavy)" % [knight.shield_id(), player.equipped_shield.id])
	player.equip_shield(load("res://scripts/Shields.gd").SHIELDS["shield_buckler"])
	print("...and taking the free Buckler yourself does not strip it from the others: you=%s guardian=%s (expected shield_buckler, shield_buckler)" % [player.equipped_shield.id, guardian.shield_id()])
	player.equipped_shield = {}
	print("A wolf carries no shield: %s (expected false)" % [player.equip_ally_shield(wolf, "shield_buckler")])
	for m in [knight, brawler, guardian]:
		player.unequip_ally_shield(m)

	# =========================================================
	# When a shield works: a free hand
	# =========================================================
	player.owned_weapons["greatsword_fine_steel"] = true
	player.owned_weapons["spear_fine_steel"] = true
	player.owned_weapons["bow_fine_steel"] = true
	player.equip_ally_shield(brawler, "shield_heavy")
	print("Bare hands leave a hand free: usable=%s (expected true)" % [brawler.shield_usable()])
	player.equip_ally_weapon(brawler, "spear_fine_steel")
	print("...so does a one-handed Spear: %s (expected true)" % [brawler.shield_usable()])
	player.equip_ally_weapon(brawler, "greatsword_fine_steel")
	print("...but a two-handed Greatsword does not: %s (expected false)" % [brawler.shield_usable()])
	player.unequip_ally_shield(brawler)
	player.equip_ally_shield(knight, "shield_heavy")
	player.equip_ally_weapon(knight, "greatsword_fine_steel")
	print("The Knight alone can hold a shield with a two-handed weapon: %s (expected true)" % [knight.shield_usable()])
	player.unequip_ally_shield(knight)
	player.unequip_ally_weapon(knight)
	player.unequip_ally_weapon(brawler)

	# =========================================================
	# What they add to the battle unit
	# =========================================================
	_reset(main, player)
	var bare: Dictionary = main._make_member_battle_unit(knight, Vector2i(1, 1), 1.0)
	player.equip_ally_armor(knight, "armor_gambeson")
	var geared: Dictionary = main._make_member_battle_unit(knight, Vector2i(1, 1), 1.0)
	print("Knight in a Gambeson (+15 Defense, +5 Fortitude): defense %.0f -> %.0f (expected 3 -> 18), fortitude %.0f -> %.0f (expected 10 -> 15)" % [bare.defense_pct, geared.defense_pct, bare.fortitude, geared.fortitude])
	player.unequip_ally_armor(knight)
	player.equip_ally_armor(marksman, "armor_gambeson")
	var sharp: Dictionary = main._make_member_battle_unit(marksman, Vector2i(1, 1), 1.0)
	print("A Marksman's Defense stays 0 whatever it wears, but the Fortitude still counts: defense %.0f fortitude %.0f (expected 0, 5)" % [sharp.defense_pct, sharp.fortitude])
	player.unequip_ally_armor(marksman)
	var plain_move: int = main._make_member_battle_unit(brawler, Vector2i(1, 1), 1.0).move_range
	player.owned_armor["armor_windrunner"] = true
	player.equip_ally_armor(brawler, "armor_windrunner")
	var runner: Dictionary = main._make_member_battle_unit(brawler, Vector2i(1, 1), 1.0)
	print("Windrunner's Jerkin: +1 move tile (%d -> %d, expected %d) and +2 speed for turn order (%d, expected 2)" % [plain_move, runner.move_range, plain_move + 1, runner.speed_bonus])
	player.equip_ally_armor(brawler, "armor_fortress")
	print("Fortress Plate: one tile less (%d, expected %d), never below 1" % [main._make_member_battle_unit(brawler, Vector2i(1, 1), 1.0).move_range, plain_move - 1])
	player.unequip_ally_armor(brawler)
	player.equip_ally_armor(guardian, "armor_windrunner")
	print("The Guardian's one-tile move is fixed -- no armour changes it: %d (expected 1)" % [main._make_member_battle_unit(guardian, Vector2i(1, 1), 1.0).move_range])
	player.unequip_ally_armor(guardian)
	player.owned_armor["armor_cinder"] = true
	var stamina_bare: int = main._make_member_battle_unit(knight, Vector2i(1, 1), 1.0).max_stamina
	player.equip_ally_armor(knight, "armor_cinder")
	print("Cinder Mail's heat costs 10 stamina: %d -> %d (expected %d)" % [stamina_bare, main._make_member_battle_unit(knight, Vector2i(1, 1), 1.0).max_stamina, stamina_bare - 10])
	player.unequip_ally_armor(knight)
	player.owned_armor["armor_shadowweave"] = true
	player.equip_ally_armor(brawler, "armor_shadowweave")
	player.equip_ally_armor(knight, "armor_shadowweave")
	print("Shadowweave gives a member a 10%% dodge (Brawler %.2f, expected 0.10) but never the Knight, who cannot dodge (%.2f, expected 0.00)" % [main._make_member_battle_unit(brawler, Vector2i(1, 1), 1.0).dodge_chance, main._make_member_battle_unit(knight, Vector2i(1, 1), 1.0).dodge_chance])
	player.unequip_ally_armor(brawler)
	player.unequip_ally_armor(knight)
	player.equip_ally_shield(brawler, "shield_phantom")
	var phantom: Dictionary = main._make_member_battle_unit(brawler, Vector2i(1, 1), 1.0)
	var no_shield: Dictionary = main._make_member_battle_unit(marksman, Vector2i(1, 1), 1.0)
	print("A Phantom Guard (+5 Defense, +12 Fortitude, 18%% block) on a bare-handed Brawler: defense %.0f (expected 7), fortitude %.0f (expected 17), block %.2f (expected 0.18)" % [phantom.defense_pct, phantom.fortitude, phantom.shield_block])
	print("...no shield, no block: %.2f (expected 0.00)" % [no_shield.shield_block])
	player.equip_ally_weapon(brawler, "greatsword_fine_steel")
	var inert: Dictionary = main._make_member_battle_unit(brawler, Vector2i(1, 1), 1.0)
	print("...and with a two-handed weapon the shield does nothing at all: block %.2f defense %.0f fortitude %.0f (expected 0.00, 2, 5)" % [inert.shield_block, inert.defense_pct, inert.fortitude])
	player.unequip_ally_weapon(brawler)
	player.unequip_ally_shield(brawler)

	# =========================================================
	# Armour traits on a member that is hit
	# =========================================================
	_reset(main, player)
	var foe := _foe(main, Vector2i(5, 4))
	var tile := Vector2i(4, 4)
	player.equip_ally_armor(knight, "armor_gambeson")
	var k: Dictionary = _unit(main, knight, tile)
	print("Knight in a Gambeson takes bodily 100 -> %d (expected 82, 18 points), magical 100 -> %d (expected 84, 15 Fortitude)" % [await _taken(main, k, foe, 100), await _taken(main, k, foe, 100, {"harm": "magical"})])
	player.unequip_ally_armor(knight)

	player.owned_armor["armor_stonehide"] = true
	player.equip_ally_armor(knight, "armor_stonehide")
	k = _unit(main, knight, tile)
	print("Stonehide Mail on a member: 13 points then -3 flat -> %d (expected 83); a hit of 3 -> %d (expected 1); magical 100 -> %d (expected 84)" % [await _taken(main, k, foe, 100), await _taken(main, k, foe, 3), await _taken(main, k, foe, 100, {"harm": "magical"})])
	player.unequip_ally_armor(knight)

	player.owned_armor["armor_martyr"] = true
	player.equip_ally_armor(knight, "armor_martyr")
	k = _unit(main, knight, tile)
	var martyr_full: int = await _taken(main, k, foe, 100)
	k.hp = 500
	k.max_hp = 1000
	main.battle_allies = [k]
	var before_half: int = k.hp
	await main._enemy_apply_damage(foe, k.tile, 100, {})
	print("Martyr's Mantle on a member: full health -> %d (expected 91); at half health (+15 points) -> %d (expected 78)" % [martyr_full, before_half - k.hp])
	player.unequip_ally_armor(knight)

	player.equip_ally_armor(knight, "armor_thornmail")
	k = _unit(main, knight, tile)
	foe.hp = 999
	await _taken(main, k, foe, 100)
	print("Thornmail on a member: a 72 hit throws back 30%% -> foe 999 -> %d (expected 977)" % [foe.hp])
	var archer := _foe(main, Vector2i(8, 4), 3)
	await _taken(main, k, archer, 100)
	print("...but not an archer's arrow: %d (expected 999)" % [archer.hp])
	player.unequip_ally_armor(knight)

	player.equip_ally_armor(knight, "armor_cinder")
	k = _unit(main, knight, tile)
	foe.burning = false
	await _taken(main, k, foe, 50)
	print("Cinder Mail on a member sets a melee attacker alight: %s (expected true)" % [foe.burning])
	player.unequip_ally_armor(knight)

	player.owned_armor["armor_bloodrage"] = true
	player.equip_ally_armor(knight, "armor_bloodrage")
	k = _unit(main, knight, tile)
	await _taken(main, k, foe, 50)
	await _taken(main, k, foe, 50)
	print("Bloodrage Hide: two blows = %d stacks (expected 2) lasting %d turns (expected 2)" % [k.bloodrage_stacks, k.bloodrage_turns])
	var raged: int = _hit_for(main, k, foe)
	k.bloodrage_stacks = 0
	var calm: int = _hit_for(main, k, foe)
	print("...its next swing hits for +20%%: %d vs %d (expected 120 vs 100)" % [raged, calm])
	k.bloodrage_stacks = 2
	k.bloodrage_turns = 2
	main._ally_start_of_turn(k)
	main._ally_start_of_turn(k)
	print("...and the rage fades after two of its own turns: stacks %d (expected 0)" % [k.bloodrage_stacks])
	player.unequip_ally_armor(knight)

	player.owned_armor["armor_spellward"] = true
	player.equip_ally_armor(knight, "armor_spellward")
	k = _unit(main, knight, tile)
	k.stamina = 50
	var first: int = await _taken(main, k, foe, 100, {"harm": "magical"})
	var second: int = await _taken(main, k, foe, 100, {"harm": "magical"})
	print("Spellward Robes on a member swallow the first magical hit (%d, expected 0), then 35 Fortitude cuts the next (%d, expected 71); each gave 10 stamina: %d (expected 70)" % [first, second, k.stamina])
	print("...and a sword is not a spell: %d (expected 91, 8 points)" % [await _taken(main, k, foe, 100)])
	player.unequip_ally_armor(knight)

	# Warden's Aegis: the wearer's friends (and you) take less
	player.owned_armor["armor_warden"] = true
	player.equip_ally_armor(brawler, "armor_warden")
	var warden: Dictionary = _unit(main, brawler, Vector2i(4, 3))
	var near: Dictionary = _unit(main, knight, Vector2i(4, 4))
	var far: Dictionary = _unit(main, knight, Vector2i(0, 0))
	near.hp = 1000
	near.max_hp = 1000
	far.hp = 1000
	far.max_hp = 1000
	main.battle_allies = [warden, near, far]
	await main._enemy_apply_damage(foe, near.tile, 100, {})
	await main._enemy_apply_damage(foe, far.tile, 100, {})
	print("Warden's Aegis on a member: a friend next to them takes %d (expected 82), one far away %d (expected 96)" % [1000 - near.hp, 1000 - far.hp])
	warden.hp = 1000
	warden.max_hp = 1000
	await main._enemy_apply_damage(foe, warden.tile, 100, {})
	print("...the wearer is covered by Defense only, not their own aura: %d (expected 79, 22 points)" % [1000 - warden.hp])
	main.battle_player_tile = Vector2i(4, 5)
	main.battle_allies = [warden]
	print("...and the hero standing nearby takes 15%% less too: %d (expected 85)" % [main._apply_incoming_reductions(100, {})])
	main.battle_player_tile = Vector2i(9, 9)
	player.unequip_ally_armor(brawler)

	# Shadowweave dodge
	player.equip_ally_armor(brawler, "armor_shadowweave")
	var slip: Dictionary = _unit(main, brawler, tile)
	slip["dodge_chance"] = 1.0
	var slipped: int = await _taken(main, slip, foe, 100)
	print("A dodged blow does nothing (%d, expected 0) and sets up a crit: %s (expected true)" % [slipped, slip.shadow_crit])
	var crit: int = _hit_for(main, slip, foe)
	var after: int = _hit_for(main, slip, foe)
	print("...the next swing crits once: %d then %d (expected 200 then 100)" % [crit, after])
	player.unequip_ally_armor(brawler)

	# Bastion: bracing steadies the stamina
	player.owned_armor["armor_bastion"] = true
	player.equip_ally_armor(knight, "armor_bastion")
	k = _unit(main, knight, tile)
	k.stamina = 10
	main.battle_turn = "player"
	main.battle_menu_state = "main"
	main.battle_commanding_ally = k
	main.battle_ally_queue = [{"tile": Vector2i(0, 0), "hp": 10, "max_hp": 10, "dmg_mult": 1.0, "name": "Filler", "move_range": 1, "attack_range": 1}]
	main.battle_allies = [k] + main.battle_ally_queue
	main._on_battle_ally_action("guard")
	print("Bastion Mail on a member: Guard gives back 15 + 10 stamina: %d (expected 35)" % [k.stamina])
	main.battle_commanding_ally = null
	main.battle_ally_queue = []
	player.unequip_ally_armor(knight)

	# =========================================================
	# Shields on a member that is hit
	# =========================================================
	_reset(main, player)
	foe = _foe(main, Vector2i(5, 4))
	player.equip_ally_shield(knight, "shield_heavy")
	k = _unit(main, knight, tile)
	print("Heavy Shield passively adds 10 Defense (13 points): bodily 100 -> %d (expected 86)" % [await _taken(main, k, foe, 100)])
	k["shield_block"] = 1.0
	print("A block negates the hit entirely: %d (expected 0)" % [await _taken(main, k, foe, 100)])
	print("...and Heavy's block shoves the attacker back a tile: x=%d (expected 6)" % [foe.tile.x])
	player.unequip_ally_shield(knight)

	foe = _foe(main, Vector2i(5, 4))
	player.equip_ally_shield(knight, "shield_bulwark")
	k = _unit(main, knight, tile)
	k["shield_block"] = 1.0
	await _taken(main, k, foe, 100)
	print("Iron Bulwark's thorns reflect 25%% of a blocked hit: foe 999 -> %d (expected 974)" % [foe.hp])
	player.unequip_ally_shield(knight)

	player.equip_ally_shield(brawler, "shield_brawler")
	var b: Dictionary = _unit(main, brawler, tile)
	b["shield_block"] = 1.0
	await _taken(main, b, foe, 100)
	print("Brawler's Buckler: a block sets up vengeance: %s (expected true)" % [b.vengeance])
	var vengeful: int = _hit_for(main, b, foe)
	var spent: int = _hit_for(main, b, foe)
	print("...the next regular swing hits +50%% harder, once: %d then %d (expected 135 then 90; the shield docks every swing 10%%)" % [vengeful, spent])
	player.unequip_ally_shield(brawler)

	# damage dealt: the shield's penalty and the Guardian's double
	player.equip_ally_shield(guardian, "shield_heavy")
	var g: Dictionary = _unit(main, guardian, tile)
	var plain_guardian: Dictionary = _unit(main, guardian, tile)
	plain_guardian["shield_penalty"] = 0.0
	plain_guardian["shield_damage_mult"] = 1.0
	print("A Guardian hits twice as hard with a shield: %d (expected 180: 100 -10%% shield penalty, then x2) vs %d (expected 100) without" % [_hit_for(main, g, foe), _hit_for(main, plain_guardian, foe)])
	player.unequip_ally_shield(guardian)
	player.equip_ally_shield(knight, "shield_heavy")
	var sk: Dictionary = _unit(main, knight, tile)
	print("Any other member is docked the shield's penalty: Knight hits for %d (expected 90)" % [_hit_for(main, sk, foe)])
	player.unequip_ally_shield(knight)

	# =========================================================
	# The Inventory's Party tab and the Sandbox
	# =========================================================
	player.owned_armor["armor_gambeson"] = true
	player.owned_shields["shield_heavy"] = true
	var panel = main.inventory_panel
	main.in_battle = false
	panel.open(player)
	await process_frame
	var party_texts: Array = _texts(panel.tab_containers.Party)
	print("The Party tab has Armour and Shield rows for every member: %s, %s (expected true, true)" % [party_texts.has("Armour"), party_texts.has("Shield")])
	print("...the armour picker lists your Gambeson with its numbers: %s (expected true)" % [party_texts.any(func(t): return str(t).begins_with("Gambeson") and str(t).contains("+15 Def"))])
	panel._on_member_armor_picked(knight, "armor_gambeson")
	panel._on_member_shield_picked(knight, "shield_heavy")
	print("Picking them dresses the Knight: armour=%s shield=%s (expected armor_gambeson, shield_heavy)" % [knight.armor_id(), knight.shield_id()])
	panel._on_member_armor_picked(druid, "armor_gambeson")
	print("A second member can't take the same armour: druid='%s' (expected '')" % [druid.armor_id()])
	panel._on_member_armor_picked(knight, "")
	panel._on_member_shield_picked(knight, "")
	print("Choosing (none) takes them off: armour='%s' shield='%s' (expected '' and '')" % [knight.armor_id(), knight.shield_id()])
	panel.close()

	var cfg: Dictionary = SandboxScript.default_config()
	cfg.party = [{"kind": "knight", "level": 1, "picks": {}, "armor": "armor_thornmail", "shield": "shield_bulwark"}, {"kind": "brawler", "level": 1, "picks": {}, "armor": "armor_thornmail", "shield": "shield_buckler"}]
	SandboxScript.apply_build(main, cfg)
	var s_knight = player.party[0]
	var s_brawler = player.party[1]
	print("A sandbox member is dressed on request: knight armour=%s shield=%s (expected armor_thornmail, shield_bulwark)" % [s_knight.armor_id(), s_knight.shield_id()])
	print("...one holder per item still: brawler armour='%s' (expected ''), but the free Buckler is fine: %s (expected shield_buckler)" % [s_brawler.armor_id(), s_brawler.shield_id()])

	quit()
