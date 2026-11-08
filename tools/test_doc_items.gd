extends SceneTree

# The items the design doc (2026-10-30) adds or changes that are not weapons' specials or talismans: Cliffwalker's Boots and
# Yodler's Cap (clothes with an effect), the Health / Energy / Mana potions, the unique dagger Retribution (stats, the void
# drop) and the Necromancer's Energy Transfer (once Revival Blessing).

func _make_goblin(main, tile: Vector2i, hp: int = 999, name: String = "Goblin") -> Dictionary:
	var g = load("res://scripts/Enemy.gd").new()
	main.add_child(g)
	g.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	return {
		"ref": g, "tile": tile, "hp": hp, "max_hp": hp, "move_range": 2, "damage": 1,
		"name": name, "winding_up": false, "stunned": false, "attack_range": 1,
		"concussed_turns": 0, "frozen_turns": 0, "burning": false, "armored": false,
		"disarmed_tile": Vector2i(-1, -1), "vulnerable_turns": 0, "aware_of_player": true, "size": 1,
	}

func _battle(main, player) -> void:
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_allies = []
	main.battle_downed_allies = []
	main.battle_actor = {}
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_turn = "player"
	main.battle_first_attack_used = true
	main.tutorial_active = false
	player.max_health = 100
	player.health = 100

func _init() -> void:
	# These checks predate the doc's flat weapon Strength (Club +2, Spear +4 per quality tier...), which has its own test
	# (test_weapon_stat_bonuses.gd): here weapons add nothing, so every damage figure below stays as it was.
	var _stat_weapons = load("res://scripts/Weapons.gd")
	_stat_weapons.CLUB["str_bonus"] = 0
	for _stat_base in _stat_weapons.UPGRADABLE_TYPES:
		_stat_base["str_per_tier"] = 0
	seed(20261107)
	var weapons = load("res://scripts/Weapons.gd")
	var clothing = load("res://scripts/Clothing.gd")
	var potions = load("res://scripts/Potions.gd")
	var main = load("res://Main.tscn").instantiate()
	main.regional_world = false
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	main.settings.attack_minigame_enabled = false
	main.settings.combat_minigames_enabled = false
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)
	player.meta_favour_chance = 0.0
	player.max_party_slots = 6

	print("--- clothes with an effect")
	var boots: Dictionary = clothing.get_piece("cloth_cliffwalker_boots")
	var cap: Dictionary = clothing.get_piece("cloth_yodler_cap")
	print("the doc's two pieces exist, boots on the feet and the cap on the head: %s / %s (expected feet / head)" % [boots.get("slot", "?"), cap.get("slot", "?")])
	player.equipped_clothing = {"head": "", "body": "", "feet": ""}
	player.owned_clothing = {}
	player._rebuild_talisman_cache()
	print("bare-footed, a fall still hurts: fall factor %.1f (expected 1.0), ledge attack %.0f (expected 0)" % [player.fall_damage_factor(), player.talisman_bonus("ignore_ledge_attack")])
	player.coins = 500
	var bought: bool = player.try_buy_clothing("cloth_cliffwalker_boots")
	print("Cliffwalker's Boots bought and worn: %s / %s (expected true / cloth_cliffwalker_boots)" % [bought, player.equipped_clothing.feet])
	print("...no damage from a fall: factor %.1f (expected 0.0); swing up a ledge with any weapon: %.0f (expected 1)" % [player.fall_damage_factor(), player.talisman_bonus("ignore_ledge_attack")])
	player.try_buy_clothing("cloth_yodler_cap")
	print("Yodler's Cap worn: taunt_confusion %.0f (expected 1)" % [player.talisman_bonus("taunt_confusion")])
	player.equip_clothing("cloth_sandals") if player.owned_clothing.has("cloth_sandals") else player.try_buy_clothing("cloth_sandals")
	player.equip_clothing("cloth_sandals")
	print("swapping the boots out for sandals takes the effect away: factor %.1f (expected 1.0)" % [player.fall_damage_factor()])
	player.equipped_clothing = {"head": "", "body": "", "feet": ""}
	player._rebuild_talisman_cache()

	print("--- potions")
	player.max_health = 90
	player.health = 1
	player.meta_healing_bonus_pct = 0.0
	player.equipped_talismans.clear()
	player._rebuild_talisman_cache()
	player.potion_queue = ["potion_health"]
	var drunk: Dictionary = player.use_healing_item()
	print("Health Potion heals 20 + a third of max HP (90): %d (expected 50)" % [drunk.get("healed", -1)])
	print("the shop's Health Potion price is still %d (expected 15)" % [potions.get_tier("potion_health").price])
	print("Energy Potion gives %d extra tiles (expected 2)" % [main.ENERGY_POTION_MOVE_BONUS])
	var mana: Dictionary = potions.get_tier("potion_mana")
	print("a Mana Potion exists: %s, costs %d (expected Mana Potion, 12), effect %s (expected restore_mana)" % [mana.get("name", "?"), mana.get("price", -1), mana.get("effect", "?")])
	_battle(main, player)
	var druid = player.recruit("druid")
	var du: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 2), 1.0)
	du.mana = 3
	main.battle_allies = [du]
	main.battle_units = [_make_goblin(main, Vector2i(5, 5))]
	player.potion_queue = ["potion_mana"]
	player.healing_items = 1
	main._battle_player_item()
	print("drinking it refills the Druid's mana: %d of %d (expected full)" % [du.mana, du.max_mana])

	print("--- Retribution")
	var ret: Dictionary = weapons.get_owned_variant("dagger_retribution")
	print("the id rebuilds the dagger: name=%s tier=%s base=%s (expected Retribution, Legendary, dagger)" % [ret.get("name", "?"), ret.get("tier_name", "?"), weapons.get_base_type(ret).get("id", "?")])
	print("its numbers: +15%% crit %.2f, crit x%.2f, mages x%.1f, others x%.1f, taken from mages x%.2f, from others x%.2f (expected 0.15, 1.33, 1.5, 0.7, 0.95, 1.10)" % [
		ret.passive_crit_chance_bonus, ret.passive_crit_damage_mult, ret.passive_damage_vs_mage_mult, ret.passive_damage_vs_nonmage_mult,
		ret.passive_taken_from_mage_mult, ret.passive_taken_from_nonmage_mult])
	player.owned_weapons.erase("dagger_retribution")
	print("a Shade is a void creature: %s, a Goblin is not: %s (expected true, false)" % [main.ENEMY_TRAITS["Shade"].get("is_void", false), main.ENEMY_TRAITS["Goblin"].get("is_void", false)])
	print("a roll under 0.5%% drops it: %s (expected true)" % [main._roll_unique_drop("Shade", 0.004)])
	print("...and you own it now: %s (expected true); it never drops twice: %s (expected false)" % [player.owned_weapons.has("dagger_retribution"), main._roll_unique_drop("Shade", 0.0)])
	player.owned_weapons.erase("dagger_retribution")
	print("a roll over 0.5%% does not: %s (expected false)" % [main._roll_unique_drop("Shade", 0.006)])
	# Damage: a mage takes more, anything else less; the wielder takes less from mages.
	_battle(main, player)
	player.current_weapon = ret
	player.stat_strength = 100
	player.attack_damage = 100
	player.stamina = player.max_stamina
	player._talisman_cache["crit_chance"] = 0.0
	player.temp_damage_bonus_pct = 0.0
	var base_dmg: int = 0
	var plain := _make_goblin(main, Vector2i(3, 2), 99999, "Goblin")
	main.battle_units = [plain]
	main._apply_single_hit(0, 1.0, "", {"damage_mult": 1.0}, "You", Vector2i(-1, -1))
	base_dmg = 99999 - plain.hp
	var mage := _make_goblin(main, Vector2i(3, 2), 99999, "Apprentice Mage")
	main.battle_units = [mage]
	main._apply_single_hit(0, 1.0, "", ret, "You", Vector2i(-1, -1))
	var vs_mage: int = 99999 - mage.hp
	var non := _make_goblin(main, Vector2i(3, 2), 99999, "Goblin")
	main.battle_units = [non]
	main._apply_single_hit(0, 1.0, "", ret, "You", Vector2i(-1, -1))
	var vs_non: int = 99999 - non.hp
	print("against a mage it hits harder than against a goblin: %s (expected true) [%d vs %d; a plain weapon does %d]" % [vs_mage > vs_non, vs_mage, vs_non, base_dmg])
	player.equipped_armor = load("res://scripts/Armor.gd").TIERS[0]
	player.equipped_clothing = {"head": "", "body": "", "feet": ""}
	player.equipped_shield = {}
	player.resilience_reduction = 0.0
	player.meta_war_chest_reduction = 0.0
	player.meta_last_stand_pct_per_10 = 0.0
	player.potion_resilience_turns = 0
	player.coins = 0
	main.battle_player_defending = false
	print("a 100 blow from a mage lands for %d, from a goblin for %d (expected 95 and 110)" % [main._apply_incoming_reductions(100, {"mage": true}), main._apply_incoming_reductions(100, {})])

	print("--- Energy Transfer")
	var kit: Array = load("res://scripts/PartyKits.gd").specials_for("necromancer")
	var names := []
	for s in kit:
		names.append(str(s.name))
	print("the Necromancer's kit reads %s (expected [Curse of Rot, Energy Transfer, Summon the Dead])" % [names])
	main.in_battle = false
	quit()
