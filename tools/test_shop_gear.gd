extends SceneTree

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var player = main.player
	var armor_script = load("res://scripts/Armor.gd")
	var potions_script = load("res://scripts/Potions.gd")

	# The shop is one flat lootpool now (see Main.gd:_roll_shop_offering) --
	# exactly SHOP_TOTAL_SLOTS independently-rolled items (category, then a
	# specific item within it) plus the always-free Club, no more "one
	# guaranteed slot per category" shape. Every category should show up at
	# least once across enough rolls, and every roll's total size should
	# match Club + SHOP_TOTAL_SLOTS exactly.
	var saw_category := {"weapon": false, "armor": false, "shield": false, "potion": false}
	var all_correct_size := true
	for i in 60:
		main._roll_shop_offering()
		if main.current_shop_offering.size() != main.SHOP_TOTAL_SLOTS + 1:
			all_correct_size = false
		for item in main.current_shop_offering:
			saw_category[item.category] = true
	print("shop lootpool: every roll is Club + SHOP_TOTAL_SLOTS items=%s (expected true), every category turns up over 60 rolls: weapon=%s armor=%s shield=%s potion=%s (expected all true)" % [
		all_correct_size, saw_category.weapon, saw_category.armor, saw_category.shield, saw_category.potion
	])

	# Weapon quality isn't gated by what's already owned anymore -- a fresh
	# level-1 character (owns nothing above Broken) can still roll a
	# Masterwork+ weapon; rare (Weapons.gd's TIERS weights), but not walled
	# off entirely the way the old min_rank floor made impossible early on.
	var saw_high_tier := false
	for i in 200:
		main._roll_shop_offering()
		for item in main.current_shop_offering:
			if item.category == "weapon" and item.get("tier_name", "") in ["Masterwork", "Legendary", "Mythic"]:
				saw_high_tier = true
	print("a high-quality weapon can still turn up despite owning nothing above the base tier: %s (expected true)" % saw_high_tier)

	# Armor: buying the offered tier equips it, reduces battle damage; fall
	# damage response differs per tier instead of just getting better as you
	# upgrade -- Iron halves it, Steel actually makes falls worse, Dragonskin
	# negates it entirely.
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

	# Iron Plate halves fall damage.
	player.owned_armor["armor_iron"] = true
	player.equipped_armor = armor_script.TIERS[2]
	main.battle_terrain.clear()
	main.battle_terrain[Vector2i(2, 1)] = {"type": "cliff", "dir": Vector2i(0, 1)}
	main.battle_player_tile = Vector2i(2, 0)
	main.battle_player_moves_left = 3
	player.health = player.max_health
	main._try_battle_player_move(Vector2i(0, 1))
	var expected_iron_fall: int = int(round(player.max_health * main.CLIFF_FALL_DAMAGE_PCT * 0.5))
	print("iron plate halves cliff fall damage: player_health=%d (expected max_health-%d = %d)" % [
		player.health, expected_iron_fall, player.max_health - expected_iron_fall
	])

	# Steel Plate increases fall damage instead of reducing it.
	player.owned_armor["armor_steel"] = true
	player.equipped_armor = armor_script.TIERS[3]
	main.battle_terrain.clear()
	main.battle_terrain[Vector2i(2, 1)] = {"type": "cliff", "dir": Vector2i(0, 1)}
	main.battle_player_tile = Vector2i(2, 0)
	main.battle_player_moves_left = 3
	player.health = player.max_health
	main._try_battle_player_move(Vector2i(0, 1))
	var expected_steel_fall: int = int(round(player.max_health * main.CLIFF_FALL_DAMAGE_PCT * 1.5))
	print("steel plate increases cliff fall damage: player_health=%d (expected max_health-%d = %d)" % [
		player.health, expected_steel_fall, player.max_health - expected_steel_fall
	])

	# Dragonskin Plating still negates cliff fall damage entirely.
	player.owned_armor["armor_dragonskin"] = true
	player.equipped_armor = armor_script.TIERS[4]
	main.battle_terrain.clear()
	main.battle_terrain[Vector2i(2, 1)] = {"type": "cliff", "dir": Vector2i(0, 1)}
	main.battle_player_tile = Vector2i(2, 0)
	main.battle_player_moves_left = 3
	player.health = player.max_health
	main._try_battle_player_move(Vector2i(0, 1))
	print("dragonskin plating still negates cliff fall damage: player_health=%d (expected unchanged %d)" % [player.health, player.max_health])

	# Potions: buying a tier adds it to the queue with its own id, and using
	# an item consumes the oldest one first (FIFO).
	player.potion_queue.clear()
	player.healing_items = 0
	var health_potion: Dictionary = potions_script.get_tier("potion_health")
	var bought_potion: bool = player.try_buy_potion(health_potion)
	print("bought health potion=%s healing_items=%d (expected 1)" % [bought_potion, player.healing_items])
	player.health = 1
	player.use_healing_item()
	print("health potion heals for its own amount: player_health=%d (expected 1+%d=%d, capped at max_health=%d)" % [
		player.health, health_potion.heal_amount, 1 + health_potion.heal_amount, player.max_health
	])

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
