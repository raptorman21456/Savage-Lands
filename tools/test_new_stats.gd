extends SceneTree

# New Stats & Status Conditions, Part 1: Might (pure level-up stat),
# Resilience/Reflexes/Dexterity (skill-tree unlock -> level-up stat),
# the Dexterity crit mechanic, the Might weapon gate, and Might's ally
# damage bonus.

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var save_data_script = load("res://scripts/SaveData.gd")
	var weapons_script = load("res://scripts/Weapons.gd")
	save_data_script.save_data({"essence": 0, "upgrades": {}, "best_wave": 0})

	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player

	# --- Might: always available, grows automatically every level-up, no
	# unlock needed. ---
	var might_before: int = player.stat_might
	player.gain_xp(1000)
	print("Might grows automatically on level-up with no unlock required: %d -> %d (expected increased)" % [might_before, player.stat_might])
	var might_after_levelup: int = player.stat_might
	player.apply_bonus_stat("might")
	print("Might can also be chosen as the level-up bonus: %d -> %d (expected +1)" % [might_after_levelup, player.stat_might])

	# --- Resilience/Reflexes/Dexterity: locked out of the level-up
	# auto-growth until their skill-tree unlock node is owned. ---
	print("Resilience/Reflexes/Dexterity all start unlocked=false on a save with nothing purchased: %s %s %s (expected false, false, false)" % [
		player.meta_resilience_unlocked, player.meta_reflexes_unlocked, player.meta_dexterity_unlocked
	])
	var resilience_before: int = player.stat_resilience
	player.gain_xp(1000)
	print("...and their stats stay at 0 through a level-up while locked: stat_resilience=%d (expected unchanged %d)" % [player.stat_resilience, resilience_before])

	# --- Now buy all 3 unlocks (and their prereq chains -- resilience_unlock
	# needs stamina:1, reflexes_unlock/dexterity_unlock need agility:1 which
	# itself needs strength:1) and confirm a fresh run picks up the flags,
	# then that the stats actually start auto-growing. ---
	var data: Dictionary = save_data_script.load_data()
	data.essence = 1000
	for id in ["stamina", "strength", "agility", "resilience_unlock", "reflexes_unlock", "dexterity_unlock"]:
		var bought: bool = save_data_script.try_buy_upgrade(data, id)
		print("bought prereq/unlock '%s': %s (expected true)" % [id, bought])
	save_data_script.save_data(data)

	var main2_scene = load("res://Main.tscn")
	var main2 = main2_scene.instantiate()
	root.add_child(main2)
	await physics_frame
	await physics_frame
	var player2 = main2.player
	print("owning all 3 unlock nodes sets the matching flags on a fresh run: %s %s %s (expected true, true, true)" % [
		player2.meta_resilience_unlocked, player2.meta_reflexes_unlocked, player2.meta_dexterity_unlocked
	])
	var stats_before: Array = [player2.stat_resilience, player2.stat_reflexes, player2.stat_dexterity]
	player2.gain_xp(1000)
	print("...and once unlocked, all 3 grow automatically on level-up: before=%s after=[%d, %d, %d] (expected all increased)" % [
		stats_before, player2.stat_resilience, player2.stat_reflexes, player2.stat_dexterity
	])

	# --- Formulas + caps (checked directly against stat values, independent
	# of however many levels it actually took to reach them). ---
	player2.stat_resilience = 10
	player2.stat_reflexes = 10
	player2.stat_dexterity = 10
	player2._recalc_stats()
	print("Resilience reduction formula at stat 10: %.4f (expected 0.10, 10*0.01)" % [player2.resilience_reduction])
	print("Reflexes dodge formula at stat 10: %.4f (expected 0.075, 10*0.0075)" % [player2.meta_dodge_chance])
	print("Dexterity crit formula at stat 10: %.4f (expected 0.075, 10*0.0075)" % [player2.meta_crit_chance])
	player2.stat_resilience = 999
	player2.stat_reflexes = 999
	player2.stat_dexterity = 999
	player2._recalc_stats()
	print("Resilience reduction caps at 20%%: %.4f (expected 0.20)" % [player2.resilience_reduction])
	print("Reflexes dodge caps at 15%%: %.4f (expected 0.15)" % [player2.meta_dodge_chance])
	print("Dexterity crit caps at 15%%: %.4f (expected 0.15)" % [player2.meta_crit_chance])

	# --- Dexterity crit mechanic: doubles damage, checked in a cover-free
	# scenario first so the doubling itself is unambiguous. A plain attack
	# always knocks its target back a tile by default (see _apply_single_hit's
	# unconditional _apply_knockback call for any effect outside a small
	# exception list) -- Goblin has no knockback_resist, so the target's tile
	# drifts after every single hit here. Rather than fight that, each check
	# re-reads the unit's CURRENT tile right before it matters instead of
	# assuming a fixed one. ---
	for e in main2.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)
	var goblin_script = load("res://scripts/Enemy.gd")
	var goblin = goblin_script.new()
	main2.add_child(goblin)
	goblin.set_physics_process(false)
	main2.in_battle = true
	main2.battle_terrain.clear()
	main2.battle_units = [{"ref": goblin, "tile": Vector2i(3, 2), "hp": 999999, "max_hp": 999999, "move_range": 1, "damage": 1, "name": "Goblin", "winding_up": false, "stunned": false, "size": 1, "attack_range": 1}]
	player2.attack_damage = 10
	player2.meta_crit_chance = 0.0
	main2._apply_single_hit(0, 1.0, "", weapons_script.CLUB)
	var normal_dmg: int = 999999 - main2.battle_units[0].hp
	main2.battle_units[0].hp = 999999
	player2.meta_crit_chance = 1.0
	main2._apply_single_hit(0, 1.0, "", weapons_script.CLUB)
	var crit_dmg: int = 999999 - main2.battle_units[0].hp
	print("Dexterity crit doubles damage with no cover involved: normal=%d crit=%d (expected crit == normal*2)" % [normal_dmg, crit_dmg])

	# --- ...and separately, crit ignores the rock-cover reduction a normal
	# hit would still take -- so against the same adjacent-rock target, crit
	# comes out to MORE than double the (cover-reduced) normal hit, not
	# exactly double it. Rock re-placed next to the unit's current (possibly
	# knocked-back) tile immediately before each hit. ---
	main2.battle_units[0].hp = 999999
	player2.meta_crit_chance = 0.0
	main2.battle_terrain.clear()
	main2.battle_terrain[main2.battle_units[0].tile + Vector2i(1, 0)] = {"type": "rock"}
	main2._apply_single_hit(0, 1.0, "", weapons_script.CLUB)
	var normal_dmg_with_cover: int = 999999 - main2.battle_units[0].hp
	main2.battle_units[0].hp = 999999
	player2.meta_crit_chance = 1.0
	main2.battle_terrain.clear()
	main2.battle_terrain[main2.battle_units[0].tile + Vector2i(1, 0)] = {"type": "rock"}
	main2._apply_single_hit(0, 1.0, "", weapons_script.CLUB)
	var crit_dmg_with_cover: int = 999999 - main2.battle_units[0].hp
	print("...against an adjacent-rock target, a normal hit is still reduced by cover: normal_with_cover=%d (expected < %d, the uncovered normal hit)" % [normal_dmg_with_cover, normal_dmg])
	print("...but crit ignores that reduction entirely: crit_with_cover=%d (expected == %d, the uncovered crit hit)" % [crit_dmg_with_cover, crit_dmg])

	main2.battle_units[0].hp = 999999
	player2.meta_crit_chance = 0.0
	main2.battle_terrain.clear()
	main2.battle_terrain[main2.battle_units[0].tile + Vector2i(1, 0)] = {"type": "rock"}
	main2._apply_single_hit(0, 1.0, "", weapons_script.CLUB, "Blade Ally")
	var ally_dmg: int = 999999 - main2.battle_units[0].hp
	print("...and never crits for an ally's own hit through the same function: ally_dmg=%d (expected == normal_with_cover, not doubled)" % [ally_dmg])
	player2.meta_crit_chance = 0.0
	main2.battle_terrain.clear()

	# --- Might weapon gate: Masterwork+ (required_might > 0) can't be
	# bought or re-equipped below the requirement, but can once met. ---
	var spear_script = weapons_script.SPEAR
	var masterwork_spear: Dictionary = {}
	for i in 200:
		var candidate: Dictionary = weapons_script.make_variant(spear_script, 3, 0.0)
		if candidate.tier_name == "Masterwork":
			masterwork_spear = candidate
			break
	print("rolled a Masterwork weapon to test the gate against: found=%s required_might=%d (expected true, 8)" % [
		not masterwork_spear.is_empty(), masterwork_spear.get("required_might", -1)
	])
	player2.stat_might = 0
	player2.coins = 100000
	var bought_below: bool = player2.try_buy_weapon(masterwork_spear)
	print("can't buy/equip a Masterwork weapon below the Might requirement: %s (expected false)" % [bought_below])
	player2.stat_might = 8
	var bought_at_threshold: bool = player2.try_buy_weapon(masterwork_spear)
	print("can buy/equip it once Might meets the requirement exactly: %s (expected true)" % [bought_at_threshold])

	# --- Might's ally damage bonus: +0.5% per point, applied to both
	# recruited party members and the wolf companion via _place_ally_units. ---
	player2.party_members = [{"name": "Blade Ally", "dmg_mult": 0.75}]
	player2.party_wolf = {"name": "Traitor Wolf", "dmg_mult": 0.6}
	player2.stat_might = 0
	main2.battle_allies = []
	main2._place_ally_units({})
	var no_might_mult: float = main2.battle_allies[0].dmg_mult
	player2.stat_might = 100
	main2.battle_allies = []
	main2._place_ally_units({})
	var with_might_mult: float = main2.battle_allies[0].dmg_mult
	print("Might boosts ally damage: no_might=%.4f with_100_might=%.4f (expected with_might == no_might * 1.5, 100*0.5%%)" % [no_might_mult, with_might_mult])
	print("...matches exactly: %s" % [is_equal_approx(with_might_mult, no_might_mult * 1.5)])

	# Reset the scratch save for whatever test runs next.
	save_data_script.save_data({"essence": 0, "upgrades": {}, "best_wave": 0})

	quit()
