extends SceneTree

# Foods (Foods.gd) and the Butcher (ButcherPanel.gd): meat that restores a
# small amount of HP AND stamina, held in the same potion_queue as potions.
# Also the Flea Market's Baker, which sells the other half of the catalog.

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var player = main.player
	var foods_script = load("res://scripts/Foods.gd")
	var potions_script = load("res://scripts/Potions.gd")

	# --- Catalog shape --------------------------------------------------------
	var butcher_items: Array = foods_script.for_vendor("butcher")
	var baker_items: Array = foods_script.for_vendor("baker")
	print("the Butcher sells 3 meats and the Baker 3 baked goods: %d / %d (expected 3 / 3)" % [butcher_items.size(), baker_items.size()])
	var all_restore_both := true
	for item in foods_script.ITEMS:
		if item.heal_amount <= 0 or item.stamina_amount <= 0:
			all_restore_both = false
		# "Small": never as strong as the 20-HP Health Potion.
		if item.heal_amount >= 20:
			all_restore_both = false
	print("every food restores some HP and some stamina, none rivals a Health Potion: %s (expected true)" % [all_restore_both])
	var leaked_into_potions := false
	for t in potions_script.TIERS:
		if foods_script.is_food(t.id):
			leaked_into_potions = true
	print("food ids never collide with Potions.TIERS (the gear shop's roll pool): %s (expected false); tiers still %d (expected 6)" % [
		leaked_into_potions, potions_script.TIERS.size()
	])

	# --- Eating: HP + stamina, through the same paths potions use -------------
	player.health = 5
	player.stamina = 10
	player.exhausted = false
	player.add_potion("food_haunch")
	var result: Dictionary = player.use_healing_item()
	print("eating a Roast Haunch (12 HP / 40 stamina) via the battle Item path: health=%d (expected 17), stamina=%d (expected 50), healed=%d (expected 12)" % [
		player.health, player.stamina, result.get("healed", -1)
	])
	print("...the result reports the stamina restored too: %d (expected 40)" % [result.get("stamina_restored", -1)])

	# Directly from the Inventory's Items tab (use_specific_potion).
	player.health = 3
	player.stamina = 0
	player.add_potion("food_jerky")
	player.add_potion("potion_health")
	var specific: Dictionary = player.use_specific_potion("food_jerky")
	print("use_specific_potion works on food and leaves other items alone: health=%d (expected 8), stamina=%d (expected 15), left=%s (expected [potion_health])" % [
		player.health, player.stamina, player.potion_queue
	])
	player.potion_queue.clear()
	player.healing_items = 0

	# Healing bonuses (Herbalism-style) scale food's HP just like a potion's.
	player.meta_healing_bonus_pct = 0.5
	player.health = 1
	player.add_potion("food_sausage")
	var boosted: Dictionary = player.use_healing_item()
	print("the healing bonus applies to food: healed=%d (expected 12 = 8 x 1.5)" % [boosted.get("healed", -1)])
	player.meta_healing_bonus_pct = 0.0

	# Stamina is clamped to the max and clears exhaustion like any regen.
	player.stamina = player.max_stamina - 5
	player.add_potion("food_haunch")
	player.use_healing_item()
	print("stamina never overshoots the max: %d (expected %d)" % [player.stamina, player.max_stamina])

	# --- In battle: the Item button eats it and logs both effects ------------
	player.health = 4
	player.stamina = 20
	player.add_potion("food_pie")
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_allies = []
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_target_index = 0
	main.battle_turn = "player"
	main._battle_player_item()
	main.in_battle = false
	print("the battle Item button eats food too: health=%d (expected 13), stamina=%d (expected 32)" % [player.health, player.stamina])

	# --- Butcher panel --------------------------------------------------------
	var panel = main.town_panels.get("butcher")
	print("the Butcher panel is registered: %s (expected true)" % [panel != null])
	if panel == null:
		quit()
		return
	player.potion_queue.clear()
	player.healing_items = 0
	player.coins = 20
	main._try_open_panel("butcher")
	print("the Butcher's door opens its panel: visible=%s (expected true), title=%s (expected THE BUTCHER)" % [panel.visible, panel.title_label.text])
	var bought: bool = panel.buy("food_jerky")
	print("buying jerky spends 5 coins and adds it to the queue: ok=%s (expected true), coins=%d (expected 15), queue=%s (expected [food_jerky])" % [
		bought, player.coins, player.potion_queue
	])
	player.coins = 2
	var refused: bool = panel.buy("food_haunch")
	print("can't afford it: ok=%s (expected false), coins=%d (expected 2), queue_size=%d (expected 1)" % [refused, player.coins, player.potion_queue.size()])
	print("a made-up food id is refused: %s (expected false)" % [panel.buy("food_unicorn")])
	panel.close()

	# --- Baker (Flea Market tab) --------------------------------------------
	var market = main.town_panels.get("flea_market")
	print("the Flea Market panel is registered: %s (expected true)" % [market != null])
	if market != null:
		player.potion_queue.clear()
		player.healing_items = 0
		player.coins = 10
		main._try_open_panel("flea_market")
		var bread_ok: bool = market.buy_food("food_bread")
		print("the Baker sells bread: ok=%s (expected true), coins=%d (expected 6), queue=%s (expected [food_bread])" % [bread_ok, player.coins, player.potion_queue])
		market.close()

	quit()
