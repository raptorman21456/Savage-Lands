extends SceneTree

func _init() -> void:
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var player = main.player
	var armor_script = load("res://scripts/Armor.gd")
	var potions_script = load("res://scripts/Potions.gd")
	var weapons_script = load("res://scripts/Weapons.gd")

	# Weapon randomization: over many rolls, not every upgradeable type shows
	# up every time (guaranteed all of them was the old behavior). Compared
	# against the full possible id count (club + every upgradeable type)
	# rather than a hardcoded number, so this doesn't go stale again the
	# next time a weapon type or SHOP_WEAPON_SLOTS changes.
	var all_possible_ids: int = weapons_script.UPGRADABLE_TYPES.size() + 1
	var saw_missing_type := false
	for i in 30:
		main._roll_shop_offering()
		var weapon_ids := {}
		for item in main.current_shop_offering:
			if item.category == "weapon":
				weapon_ids[item.id.split("_")[0]] = true
		if weapon_ids.size() < all_possible_ids:
			saw_missing_type = true
	print("shop randomization: some rolls omit a weapon type=%s (expected true)" % saw_missing_type)

	# Every roll always includes club + exactly SHOP_WEAPON_SLOTS other
	# weapons + all 3 potion tiers + (while unowned) 1 armor tier + (while
	# unowned) all 5 shields.
	main._roll_shop_offering()
	var categories := {"weapon": 0, "armor": 0, "shield": 0, "potion": 0}
	for item in main.current_shop_offering:
		categories[item.category] += 1
	print("offering shape: weapons=%d (expected %d), armor=%d (expected 1), shields=%d (expected 5), potions=%d (expected 3)" % [
		categories.weapon, main.SHOP_WEAPON_SLOTS + 1, categories.armor, categories.shield, categories.potion
	])

	# Armor: buying the offered tier equips it, reduces battle damage, and
	# the top tier negates cliff fall damage entirely.
	player.coins = 1000
	var next_armor: Dictionary = armor_script.get_next_tier(player.owned_armor)
	print("first armor offer is Leather Vest: %s (expected true)" % [next_armor.id == "armor_leather"])
	var bought_armor: bool = player.try_buy_armor(next_armor)
	print("bought leather armor=%s equipped=%s owned=%s" % [bought_armor, player.equipped_armor.id, player.owned_armor.has("armor_leather")])

	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_player_defending = false
	var goblin_script = load("res://scripts/Enemy.gd")
	var goblin = goblin_script.new()
	main.add_child(goblin)
	goblin.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	main.battle_units = [{
		"ref": goblin, "tile": Vector2i(3, 2), "hp": 999, "max_hp": 999,
		"move_range": 2, "damage": 10, "name": "Goblin", "winding_up": false,
	}]
	player.health = player.max_health
	main._process_enemy_turn()
	var expected_dmg: int = int(round(10 * (1.0 - 0.15)))
	print("leather armor reduces incoming damage: player_health=%d (expected max_health-%d = %d)" % [
		player.health, expected_dmg, player.max_health - expected_dmg
	])

	# Iron Plate negates fall damage.
	player.owned_armor["armor_iron"] = true
	player.equipped_armor = armor_script.TIERS[2]
	main.battle_terrain.clear()
	main.battle_terrain[Vector2i(2, 1)] = {"type": "cliff", "dir": Vector2i(0, 1)}
	main.battle_player_tile = Vector2i(2, 0)
	main.battle_player_moves_left = 3
	player.health = player.max_health
	main._try_battle_player_move(Vector2i(0, 1))
	print("iron plate negates cliff fall damage: player_health=%d (expected unchanged %d)" % [player.health, player.max_health])

	# Potions: buying a tier adds it to the queue with its own heal amount,
	# and using an item consumes the oldest one first (FIFO).
	player.potion_queue.clear()
	player.healing_items = 0
	var bought_potion: bool = player.try_buy_potion(potions_script.TIERS[2])
	print("bought greater potion=%s healing_items=%d (expected 1)" % [bought_potion, player.healing_items])
	player.health = 1
	player.use_healing_item()
	print("greater potion heals for its own amount: player_health=%d (expected 1+25=26, capped at max_health=%d)" % [player.health, player.max_health])

	# Reroll: costs REROLL_BASE_COST, increases each consecutive reroll,
	# resets when the shop reopens.
	player.coins = 1000
	main.shop_reroll_count = 0
	var cost1: int = main._get_shop_reroll_cost()
	main._reroll_shop()
	var cost2: int = main._get_shop_reroll_cost()
	main._reroll_shop()
	var cost3: int = main._get_shop_reroll_cost()
	print("reroll cost increases each time: %d, %d, %d (expected %d, %d, %d)" % [
		cost1, cost2, cost3, main.REROLL_BASE_COST, main.REROLL_BASE_COST + main.REROLL_COST_INCREMENT, main.REROLL_BASE_COST + main.REROLL_COST_INCREMENT * 2
	])

	var coins_before_reroll: int = player.coins
	main._reroll_shop()
	print("reroll deducts coins: spent=%d (expected %d)" % [coins_before_reroll - player.coins, main.REROLL_BASE_COST + main.REROLL_COST_INCREMENT * 2])

	player.coins = 0
	var failed_reroll: bool = main._reroll_shop()
	print("reroll fails without enough coins: %s (expected false)" % failed_reroll)

	main._open_shop()
	print("reroll count resets when the shop reopens: %d (expected 0)" % main.shop_reroll_count)

	quit()
