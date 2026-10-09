extends SceneTree

# The party roster on Player (recruit / capacity / the Wolf Fang slot) and how it plays
# out in a battle: allies fight on their own stats, take damage through their own
# defense, earn XP, and a wolf counts faints and loyalty per battle and is harvested when
# it dies for good.

func _make_unit(main, name: String, tile: Vector2i, hp: int = 999, damage: int = 3) -> Dictionary:
	var g = load("res://scripts/Enemy.gd").new()
	main.add_child(g)
	return {
		"ref": g, "tile": tile, "hp": hp, "max_hp": hp, "move_range": 2, "damage": damage, "name": name,
		"winding_up": false, "stunned": false, "attack_range": 1, "concussed_turns": 0, "frozen_turns": 0,
		"burning": false, "armored": false, "disarmed_tile": Vector2i(-1, -1),
	}

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	# --- Capacity: every member counts, wolves included ---
	player.party = []
	player.party_members = []
	player.max_party_slots = 2
	print("a fresh party has room: wolf=%s druid=%s (expected true, true)" % [player.can_recruit("wolf"), player.can_recruit("druid")])
	var w1 = player.recruit("wolf")
	var d1 = player.recruit("druid")
	print("two members fill two slots: size=%d wolf=%s druid=%s (expected 2, true, true)" % [player.party.size(), w1.kind, d1.kind])
	print("...and the party is now full for anyone: wolf=%s druid=%s (expected false, false)" % [player.can_recruit("wolf"), player.can_recruit("druid")])
	print("recruit() into a full party returns nothing: %s (expected true)" % [player.recruit("rogue") == null])
	print("an unknown kind is refused: %s (expected true)" % [player.recruit("dragon") == null])
	print("the older mercenaries take a slot too: %s (expected false)" % [player.can_recruit("mercenary")])
	player.party_members = [{"name": "Knight", "dmg_mult": 0.75}]
	player.party = []
	print("a Knight and one more fit in two slots: %s / then full: %s (expected true / false)" % [player.can_recruit("guardian"), (player.recruit("guardian") != null) and not player.can_recruit("druid")])

	# --- The Wolf Fang slot: only wolves may use it ---
	player.party_members = []
	player.party = []
	player.max_party_slots = 2
	player.recruit("druid")
	player.recruit("guardian")
	print("two ordinary members, no Wolf Fang: a wolf has no room: %s (expected false)" % [player.can_recruit("wolf")])
	player.owned_talismans["wolf_fang"] = true
	print("Wolf Fang is worn: %s (expected true)" % [player.equip_talisman("wolf_fang")])
	print("...it adds a slot, capacity 3: %d (expected 3)" % [player.party_capacity()])
	print("...that a wolf can take: %s (expected true)" % [player.can_recruit("wolf")])
	print("...but no other kind can, since the ordinary slots are full: rogue=%s druid=%s (expected false, false)" % [player.can_recruit("rogue"), player.can_recruit("druid")])
	player.recruit("wolf")
	print("with the wolf in, the party is full again: %s (expected false)" % [player.can_recruit("wolf")])
	player.party = []
	player.recruit("wolf")
	player.recruit("wolf")
	print("wolves fill ordinary slots first and can then use the extra one, so three wolves fit: %s (expected true)" % [player.recruit("wolf") != null])
	print("...and a fourth does not: %s (expected false)" % [player.can_recruit("wolf")])

	# --- Loyalty: 10 battles, 15 with Wolf Fang, plus Pack Bond ---
	player.party = []
	var stay_with_fang = player.recruit("wolf")
	print("a wolf recruited with Wolf Fang worn stays 15 battles: %d (expected 15)" % [stay_with_fang.battles_left])
	player.unequip_talisman("wolf_fang")
	player.party = []
	var stay_plain = player.recruit("wolf")
	print("...10 without it: %d (expected 10)" % [stay_plain.battles_left])
	player.meta_wolf_bonus_waves = 6
	player.party = []
	print("...and Pack Bond stacks on top: %d (expected 16)" % [player.recruit("wolf").battles_left])
	player.meta_wolf_bonus_waves = 0
	player.party = []
	print("only wolves have a loyalty limit: druid=%d (expected -1, none)" % [player.recruit("druid").battles_left])

	# --- Fielded party ---
	player.party = []
	player.party_members = []
	player.max_party_slots = 2
	player.recruit("druid")
	player.recruit("guardian")
	print("everyone fits, so everyone takes the field: %d (expected 2)" % [player.fielded_party().size()])
	player.owned_talismans["wolf_fang"] = true
	player.equip_talisman("wolf_fang")
	player.recruit("wolf")
	print("the wolf in the extra slot fields too: %d (expected 3)" % [player.fielded_party().size()])
	player.unequip_talisman("wolf_fang")
	print("take Wolf Fang off and the newest member waits behind: fielded=%s (expected the druid and guardian)" % [player.fielded_party().map(func(m): return m.kind)])
	player.dismiss_party_member(player.party[0].id)
	print("dismissing a member frees the slot: size=%d (expected 2)" % [player.party.size()])

	# --- Battle units: their own stats ---
	player.party = []
	player.party_members = []
	player.max_party_slots = 4
	var guardian = player.recruit("guardian")
	var marksman = player.recruit("marksman")
	var wolf = player.recruit("wolf")
	player.max_health = 100
	player.health = 100
	player.attack_damage = 50
	main._setup_battle_grid([])
	var by_kind := {}
	for a in main.battle_allies:
		by_kind[a.kind] = a
	print("each roster member is seated as a unit: %s (expected guardian, marksman, wolf)" % [main.battle_allies.map(func(a): return a.kind)])
	print("HP is the member's own, not a share of the hero's 100: guardian=%d marksman=%d wolf=%d (expected 25, 10, 18)" % [by_kind.guardian.max_hp, by_kind.marksman.max_hp, by_kind.wolf.max_hp])
	print("defense and movement come from the member: guardian=%.1f%%/%d tiles marksman=%.1f%%/%d tiles wolf=%.1f%%/%d tiles (expected 5.0/1, 0.0/1, 0.0/3)" % [
		by_kind.guardian.defense_pct, by_kind.guardian.move_range, by_kind.marksman.defense_pct, by_kind.marksman.move_range, by_kind.wolf.defense_pct, by_kind.wolf.move_range
	])
	print("pools: wolf stamina=%d (expected 150), guardian=%d (expected 100), no mana anywhere: %d/%d/%d (expected 0/0/0)" % [
		by_kind.wolf.stamina, by_kind.guardian.stamina, by_kind.guardian.mana, by_kind.marksman.mana, by_kind.wolf.mana
	])
	print("each unit keeps its link back to the member: %s (expected true)" % [by_kind.wolf.member == wolf and by_kind.guardian.member == guardian])

	# An ally swings on its OWN attack stat, not the hero's 50.
	main.in_battle = true
	main.battle_player_tile = Vector2i(5, 5)
	main.battle_terrain.clear()
	var target := _make_unit(main, "Goblin", Vector2i(1, 0), 999)
	main.battle_units = [target]
	main.battle_target_index = 0
	var g_unit: Dictionary = by_kind.guardian
	g_unit.tile = Vector2i(0, 0)
	main.battle_allies = [g_unit]
	main.battle_commanding_ally = g_unit
	main._battle_ally_attack()
	print("commanded to Attack, an ally hits for its own attack (Guardian attack 1) and not the hero's 50: %d (expected 1)" % [999 - target.hp])
	var w_unit: Dictionary = by_kind.wolf
	w_unit.tile = Vector2i(0, 0)
	main.battle_allies = [w_unit]
	main.battle_commanding_ally = w_unit
	target.hp = 999
	main._battle_ally_attack()
	print("the wolf's 1.25 attack rounds to 1, and a connecting hit is never below 1: %d (expected 1)" % [999 - target.hp])
	main.battle_commanding_ally = null
	player.stat_might = 100
	main.battle_allies = []
	main._setup_battle_grid([])
	print("Might boosts every kind of ally's damage multiplier: %.2f (expected 1.50)" % [main.battle_allies[0].dmg_mult])
	player.stat_might = 0

	# --- Damage taken goes through defense ---
	main.in_battle = true
	main.battle_terrain.clear()
	var attacker := _make_unit(main, "Orc", Vector2i(0, 1), 999, 100)
	var soft_ally := {"tile": Vector2i(0, 0), "hp": 1000, "max_hp": 1000, "dmg_mult": 1.0, "name": "Knight", "kind": "mercenary", "defense_pct": 0.0, "move_range": 2, "attack_range": 1}
	main.battle_allies = [soft_ally]
	main.battle_units = [attacker]
	main._enemy_apply_damage(attacker, Vector2i(0, 0), 100, {})
	print("with no defense an ally takes the full hit: %d (expected 100)" % [1000 - soft_ally.hp])
	var tough_ally := {"tile": Vector2i(0, 0), "hp": 1000, "max_hp": 1000, "dmg_mult": 1.0, "name": "Guardian", "kind": "guardian", "defense_pct": 20.0, "move_range": 1, "attack_range": 1}
	main.battle_allies = [tough_ally]
	main._enemy_apply_damage(attacker, Vector2i(0, 0), 100, {})
	print("20%% defense cuts a 100 hit to: %d (expected 80)" % [1000 - tough_ally.hp])
	tough_ally.defense_pct = 100000.0
	tough_ally.hp = 1000
	main._enemy_apply_damage(attacker, Vector2i(0, 0), 100, {})
	print("defense never reaches the 80%% ceiling, so even absurd defense takes: %d (expected 20)" % [1000 - tough_ally.hp])
	tough_ally["defense_cap"] = 0.9
	tough_ally.hp = 1000
	main._enemy_apply_damage(attacker, Vector2i(0, 0), 100, {})
	print("...and a unit with a 90%% cap (the Guardian's) takes: %d (expected 10)" % [1000 - tough_ally.hp])
	tough_ally.erase("defense_cap")
	tough_ally.defense_pct = 5.0
	tough_ally.hp = 1000
	main._enemy_apply_damage(attacker, Vector2i(0, 0), 1, {})
	print("a hit never drops below 1 damage: %d (expected 1)" % [1000 - tough_ally.hp])

	# --- XP ---
	player.party = []
	var druid = player.recruit("druid")
	var xp_wolf = player.recruit("wolf")
	main._award_party_xp(28)
	print("every levelling member earns the kill's XP and levels at 28: druid level=%d picks=%d (expected 2, 1)" % [druid.level, druid.picks])
	print("...but a wolf never levels: level=%d xp=%d (expected 1, 0)" % [xp_wolf.level, xp_wolf.xp])

	# --- Faints, loyalty and death for good ---
	player.party = []
	player.pelts = 0
	var potions_before: int = player.potion_queue.size()
	var mortal = player.recruit("wolf")
	var steady = player.recruit("guardian")
	mortal.battles_left = 10
	for round_number in 3:
		main.battle_fainted_members = [mortal]
		main._settle_party_after_battle()
	print("a wolf fainting three times dies for good: alive=%s faints=%d (expected false, 3)" % [player.party_wolves().size() == 1, mortal.faints])
	print("...its body is harvested for %d Roast Haunch and %d pelts: %d / %d (expected 2 / 2)" % [main.WOLF_HARVEST_MEAT, main.WOLF_HARVEST_PELTS, player.potion_queue.size() - potions_before, player.pelts])
	print("...and it leaves the party, the guardian stays: %s (expected [guardian])" % [player.party.map(func(m): return m.kind)])
	var survivor = player.recruit("wolf")
	survivor.battles_left = 10
	main.battle_fainted_members = [survivor]
	main._settle_party_after_battle()
	print("one faint is survivable, and it still spends its battle: faints=%d battles_left=%d (expected 1, 9)" % [survivor.faints, survivor.battles_left])
	survivor.battles_left = 1
	main.battle_fainted_members = []
	main._settle_party_after_battle()
	print("a wolf whose loyalty runs out leaves: wolves=%d (expected 0)" % [player.party_wolves().size()])
	print("...with no harvest (it walked away): pelts=%d (expected 2 from the earlier death only)" % [player.pelts])
	print("non-wolf members never leave from loyalty: guardian still here = %s (expected true)" % [player.party.has(steady)])

	main.in_battle = false
	quit()
