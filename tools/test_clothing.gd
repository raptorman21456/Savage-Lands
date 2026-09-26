extends SceneTree

# Clothes (Clothing.gd): light extra armour pieces from the Flea Market tailor,
# one worn per slot, stacking a little damage reduction on top of armour (see
# Player.gd:armor_damage_reduction). Covers the Player rules, the tailor tab,
# the real incoming-damage path, and the Inventory's Clothes section.

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var player = main.player
	var clothing = load("res://scripts/Clothing.gd")
	var armor = load("res://scripts/Armor.gd")

	print("3 slots x 3 pieces: slots=%d (expected 3), pieces=%d (expected 9)" % [clothing.SLOTS.size(), clothing.PIECES.size()])
	var each_slot_three := true
	for slot in clothing.SLOTS:
		if clothing.for_slot(slot).size() != 3:
			each_slot_three = false
	print("...three per slot: %s (expected true)" % [each_slot_three])
	print("nothing is worn to start: dr=%.2f (expected 0.00)" % [player.clothing_damage_reduction()])

	# --- Buying: auto-wears if it beats the slot's current piece. ---
	player.coins = 100
	print("buying a Cloth Cap spends its price and wears it: ok=%s (expected true), coins=%d (expected 90), head=%s (expected cloth_cap)" % [
		player.try_buy_clothing("cloth_cap"), player.coins, player.equipped_clothing.head
	])
	print("clothing DR stacks: %.2f (expected 0.02)" % [player.clothing_damage_reduction()])
	player.try_buy_clothing("cloth_pelt_hood")
	print("a better hood replaces it: head=%s (expected cloth_pelt_hood), dr=%.2f (expected 0.06)" % [player.equipped_clothing.head, player.clothing_damage_reduction()])

	# A weaker piece bought afterwards is only owned, never a silent downgrade.
	player.try_buy_clothing("cloth_hood")
	print("a weaker hood bought later is owned but not worn: owned=%s (expected true), head=%s (expected cloth_pelt_hood)" % [
		player.owned_clothing.has("cloth_hood"), player.equipped_clothing.head
	])
	# ...but choosing it explicitly does swap.
	print("wearing an owned piece explicitly works (even a downgrade): ok=%s (expected true), head=%s (expected cloth_hood)" % [
		player.equip_clothing("cloth_hood"), player.equipped_clothing.head
	])
	print("an unowned piece can't be worn: %s (expected false), unknown id: %s (expected false)" % [
		player.equip_clothing("cloth_cloak"), player.equip_clothing("cloth_nothing")
	])

	# Can't-afford and unknown ids.
	player.coins = 3
	print("can't afford Fur Cloak: ok=%s (expected false), coins=%d (expected 3), body=%s (expected empty)" % [
		player.try_buy_clothing("cloth_cloak"), player.coins, player.equipped_clothing.body
	])
	print("an unknown piece id is refused: %s (expected false)" % [player.try_buy_clothing("cloth_nothing")])

	# All three slots worn add up.
	player.coins = 500
	player.owned_clothing.clear()
	player.equipped_clothing = {"head": "", "body": "", "feet": ""}
	player.try_buy_clothing("cloth_pelt_hood")
	player.try_buy_clothing("cloth_cloak")
	player.try_buy_clothing("cloth_trail_boots")
	print("best in every slot: dr=%.2f (expected 0.18)" % [player.clothing_damage_reduction()])

	# --- Stacks with the armour tier, in the number every system reads. ---
	player.equipped_armor = armor.TIERS[2]
	print("armour (30%%) + clothes (18%%) = armor_damage_reduction: %.2f (expected 0.48)" % [player.armor_damage_reduction()])

	# --- ...and in the real incoming-damage path. ---
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
	print("100 damage into 30%% armour + 18%% clothes lands as: %d (expected 52)" % [main._apply_incoming_reductions(100, {})])
	player.equipped_clothing = {"head": "", "body": "", "feet": ""}
	print("...and as 70 with the clothes off: %d (expected 70)" % [main._apply_incoming_reductions(100, {})])
	# The combined cap (0.9) still holds.
	player.equipped_armor = armor.TIERS[4]
	player.equip_clothing("cloth_pelt_hood")
	player.equip_clothing("cloth_cloak")
	player.equip_clothing("cloth_trail_boots")
	player.resilience_reduction = 0.5
	print("the 90%% cap still holds however much is stacked: %d (expected 10)" % [main._apply_incoming_reductions(100, {})])
	player.resilience_reduction = 0.0
	main.in_battle = false

	# --- Tailor tab at the Flea Market. ---
	var market = main.town_panels.get("flea_market")
	player.equipped_armor = armor.TIERS[0]
	player.owned_clothing.clear()
	player.equipped_clothing = {"head": "", "body": "", "feet": ""}
	player.coins = 40
	main._try_open_panel("flea_market")
	market._on_tab_pressed("Tailor")
	print("the Flea Market opens with 3 tabs, Tailor now active: tab=%s (expected Tailor), tabs=%d (expected 3)" % [market.active_tab, market.tab_buttons.size()])
	var bought: bool = market.use_clothing("cloth_boots")
	print("buying Leather Boots at the tailor: ok=%s (expected true), coins=%d (expected 20), feet=%s (expected cloth_boots)" % [
		bought, player.coins, player.equipped_clothing.feet
	])
	var again: bool = market.use_clothing("cloth_boots")
	print("clicking an owned piece just wears it, free: ok=%s (expected true), coins=%d (expected 20)" % [again, player.coins])
	print("can't afford the Fur Cloak (50): ok=%s (expected false)" % [market.use_clothing("cloth_cloak")])
	market.close()

	# --- Inventory's Clothes section. ---
	var panel = main.inventory_panel
	panel.open(player)
	var weapons_tab = panel.tab_containers.Weapons
	var found_heading := false
	for c in weapons_tab.get_children():
		if c is Label and c.text == "CLOTHES":
			found_heading = true
	print("the Weapons tab has a CLOTHES section: %s (expected true)" % [found_heading])
	player.equip_clothing("cloth_boots")
	panel._on_clothing_cell_pressed("cloth_boots")
	print("clicking the worn piece is a harmless no-op: %s (expected cloth_boots)" % [player.equipped_clothing.feet])
	player.try_buy_clothing("cloth_sandals")
	player.equip_clothing("cloth_boots")
	panel._on_clothing_cell_pressed("cloth_sandals")
	print("clicking another owned piece swaps to it: feet=%s (expected cloth_sandals)" % [player.equipped_clothing.feet])
	panel.close()

	quit()
