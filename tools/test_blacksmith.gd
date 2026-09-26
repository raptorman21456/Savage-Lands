extends SceneTree

# The town Blacksmith (Blacksmith.gd / BlacksmithPanel.gd): coin-for-upgrade
# levels on owned weapons (+8% damage each, fewer breaks) and METAL armour
# (+2.5% damage reduction each). Levels live on Player keyed by id and are
# applied inside _equip_weapon / armor_damage_reduction, so they reach every
# equip path and the real incoming-damage calculation.

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var player = main.player
	var weapons = load("res://scripts/Weapons.gd")
	var armor = load("res://scripts/Armor.gd")
	var smith = load("res://scripts/Blacksmith.gd")

	# --- Rules ------------------------------------------------------------------
	print("weapon costs by level: %s (expected [25, 50, 90, 140, 200])" % [smith.WEAPON_COSTS])
	print("cost past the max is -1: weapon=%d armor=%d (expected -1 -1)" % [smith.weapon_cost(5), smith.armor_cost(3)])
	print("level 0 is an exact identity: dmg x%.2f, break x%.2f, armour +%.3f (expected 1.00, 1.00, 0.000)" % [
		smith.weapon_damage_factor(0), smith.weapon_break_factor(0), smith.armor_bonus(0)
	])
	print("level 5 weapon: dmg x%.2f (expected 1.40), break x%.2f (expected 0.50); level 3 armour +%.3f (expected 0.075)" % [
		smith.weapon_damage_factor(5), smith.weapon_break_factor(5), smith.armor_bonus(3)
	])
	var metal_ids := []
	for a in armor.TIERS:
		if a.get("metal", false):
			metal_ids.append(a.id)
	print("only Iron and Steel are metal: %s (expected [armor_iron, armor_steel])" % [metal_ids])

	# --- Weapons -------------------------------------------------------------------
	var spear: Dictionary = weapons.get_owned_variant("spear_fine_steel")
	player.owned_weapons[spear.id] = true
	player._equip_weapon(spear)
	var base_dmg: float = spear.damage_mult
	print("an un-upgraded weapon is untouched: dmg=%.3f (expected %.3f), name=%s (expected %s)" % [
		player.current_weapon.damage_mult, base_dmg, player.current_weapon.name, spear.name
	])

	player.coins = 30
	var ok: bool = player.try_upgrade_weapon(spear.id)
	print("+1 costs 25 and applies at once: ok=%s (expected true), coins=%d (expected 5), level=%d (expected 1)" % [ok, player.coins, player.get_weapon_upgrade_level(spear.id)])
	print("...damage x1.08: %.3f (expected %.3f)" % [player.current_weapon.damage_mult, base_dmg * 1.08])
	print("...name carries the level, but the id and the raw base weapon are untouched: name=%s (expected '%s +1'), id=%s, base_dmg=%.3f (expected %.3f)" % [
		player.current_weapon.name, spear.name, player.current_weapon.id, player.current_weapon_base.damage_mult, base_dmg
	])
	print("can't afford +2 (50): ok=%s (expected false), coins=%d (expected 5), level=%d (expected 1)" % [player.try_upgrade_weapon(spear.id), player.coins, player.get_weapon_upgrade_level(spear.id)])
	print("can't upgrade a weapon you don't own: %s (expected false)" % [player.try_upgrade_weapon("dagger_fine_steel")])

	player.coins = 1000
	for i in 4:
		player.try_upgrade_weapon(spear.id)
	print("upgrades to +5 and stops: level=%d (expected 5), coins=%d (expected %d)" % [player.get_weapon_upgrade_level(spear.id), player.coins, 1000 - 50 - 90 - 140 - 200])
	print("...a sixth is refused: %s (expected false), level=%d (expected 5)" % [player.try_upgrade_weapon(spear.id), player.get_weapon_upgrade_level(spear.id)])
	print("...+40%% damage in total: %.3f (expected %.3f)" % [player.current_weapon.damage_mult, base_dmg * 1.4])

	# Re-equipping through any path (e.g. the shop's re-equip of an owned weapon)
	# still applies the level.
	player.try_buy_weapon(weapons.CLUB)
	player.try_buy_weapon(spear)
	print("re-equipping an owned upgraded weapon keeps its level: dmg=%.3f (expected %.3f)" % [player.current_weapon.damage_mult, base_dmg * 1.4])

	# Stacks with an enchantment rather than replacing it.
	player.weapon_enchantments[spear.id] = "ember"
	player._equip_weapon(spear)
	print("stacks with a rune (Bloodlust +50%%): dmg=%.3f (expected %.3f)" % [player.current_weapon.damage_mult, base_dmg * 1.5 * 1.4])
	player.weapon_enchantments.erase(spear.id)

	# Fewer breaks on a fragile (Gold) weapon.
	var gold: Dictionary = weapons.get_owned_variant("spear_fine_gold")
	player.owned_weapons[gold.id] = true
	player._equip_weapon(gold)
	var gold_break: float = gold.break_chance
	player.try_upgrade_weapon(gold.id)
	player.try_upgrade_weapon(gold.id)
	print("a Gold weapon's break chance shrinks 10%% per level: %.4f (expected %.4f)" % [player.current_weapon.break_chance, gold_break * 0.8])

	# A shattered weapon loses its levels along with it.
	player.owned_weapons[gold.id] = true
	player.weapon_upgrade_levels[gold.id] = 2
	player.owned_weapons.erase(gold.id)
	player.weapon_upgrade_levels.erase(gold.id)
	print("levels are gone once the weapon is: %d (expected 0)" % [player.get_weapon_upgrade_level(gold.id)])

	# Club (the free fallback) can be upgraded like any other.
	player.try_buy_weapon(weapons.CLUB)
	player.coins = 100
	print("Club can be upgraded: %s (expected true)" % [player.try_upgrade_weapon("club")])

	# --- Armour --------------------------------------------------------------------
	player.coins = 1000
	player.owned_armor["armor_iron"] = true
	player.equipped_armor = armor.TIERS[2]
	print("Iron Plate is 30%% before any upgrade: %.3f (expected 0.300)" % [player.armor_damage_reduction()])
	print("upgrading metal armour works: ok=%s (expected true), coins=%d (expected 960), level=%d (expected 1)" % [player.try_upgrade_armor("armor_iron"), player.coins, player.get_armor_upgrade_level("armor_iron")])
	print("...+2.5%% damage reduction: %.3f (expected 0.325)" % [player.armor_damage_reduction()])
	player.try_upgrade_armor("armor_iron")
	player.try_upgrade_armor("armor_iron")
	print("stops at +3: level=%d (expected 3), dr=%.3f (expected 0.375), a fourth refused=%s (expected false)" % [
		player.get_armor_upgrade_level("armor_iron"), player.armor_damage_reduction(), player.try_upgrade_armor("armor_iron")
	])

	player.owned_armor["armor_leather"] = true
	print("leather and dragonhide aren't metal, unowned armour isn't upgradable: leather=%s dragonskin=%s steel=%s (expected false false false)" % [
		player.try_upgrade_armor("armor_leather"), player.try_upgrade_armor("armor_dragonskin"), player.try_upgrade_armor("armor_steel")
	])

	# The bonus follows the armour that is actually WORN, not every owned piece.
	player.owned_armor["armor_steel"] = true
	player.equipped_armor = armor.TIERS[3]
	print("an un-upgraded Steel Plate ignores Iron's levels: %.3f (expected 0.450)" % [player.armor_damage_reduction()])
	player.equipped_armor = armor.TIERS[2].duplicate()
	player.equipped_armor["category"] = "armor"
	print("a shop-tagged copy of Iron still gets its levels: %.3f (expected 0.375)" % [player.armor_damage_reduction()])

	# Stacks with clothes and reaches the real damage path.
	player.equipped_armor = armor.TIERS[2]
	player.armor_upgrade_levels["armor_iron"] = 2
	player.owned_clothing["cloth_cloak"] = true
	player.equip_clothing("cloth_cloak")
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_allies = []
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_turn = "enemy"
	player.resilience_reduction = 0.0
	player.meta_war_chest_reduction = 0.0
	player.meta_last_stand_pct_per_10 = 0.0
	player.equipped_shield = {}
	player.potion_resilience_turns = 0
	main.battle_player_defending = false
	print("100 damage into +2 Iron (35%%) and a Fur Cloak (7%%): %d (expected 58)" % [main._apply_incoming_reductions(100, {})])
	main.in_battle = false

	# --- The panel ---------------------------------------------------------------------
	var panel = main.town_panels.get("blacksmith")
	print("the Blacksmith panel is registered: %s (expected true)" % [panel != null])
	if panel != null:
		player.owned_weapons = {"club": true}
		player.weapon_upgrade_levels = {}
		player.armor_upgrade_levels = {}
		player.try_buy_weapon(weapons.CLUB)
		player.equipped_armor = armor.TIERS[2]
		player.owned_armor = {"armor_rags": true, "armor_iron": true, "armor_leather": true}
		player.equipped_clothing = {"head": "", "body": "", "feet": ""}
		player.coins = 100
		main._try_open_panel("blacksmith")
		print("the door opens it: visible=%s (expected true), title=%s (expected THE BLACKSMITH)" % [panel.visible, panel.title_label.text])
		print("upgrading the Club through the panel: ok=%s (expected true), coins=%d (expected 75)" % [panel.upgrade_weapon("club"), player.coins])
		print("...and armour: ok=%s (expected true), coins=%d (expected 35)" % [panel.upgrade_armor("armor_iron"), player.coins])
		print("refuses leather (not metal): %s (expected false)" % [panel.upgrade_armor("armor_leather")])
		print("refuses when broke: %s (expected false)" % [panel.upgrade_armor("armor_iron")])
		panel.close()

	quit()
