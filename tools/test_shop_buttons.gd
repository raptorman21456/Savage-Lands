extends SceneTree

# A lockable weapon row (any non-Club, non-owned weapon offer) is now an
# HBoxContainer wrapping [buy_button, lock_button], not a bare Button --
# this pulls out the actual buy button either way, since a Club/armor/
# potion/already-owned row is still a bare Button same as always.
func _row_button(node: Node) -> Button:
	if node is Button:
		return node
	return node.get_child(0)

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var player = main.player
	player.coins = 200
	main._open_shop()

	print("opening the shop builds a row button per offering item: rows=%d (expected %d)" % [
		main.hud.shop_row_nodes.size(), main.current_shop_offering.size()
	])

	# Clicking a row button buys that item, same as the number-key shortcut.
	var club_button: Button = _row_button(main.hud.shop_row_nodes[0])
	print("row 0 is the club: text=%s" % [club_button.text])
	var weapons_script = load("res://scripts/Weapons.gd")
	main.player.current_weapon = weapons_script.SPEAR
	club_button.pressed.emit()
	print("clicking the club row re-equips it for free: current_weapon=%s (expected club)" % [player.current_weapon.id])

	# Item stat descriptions live in the Inventory screen now, not the shop --
	# hovering a row only ever changes the Shopkeeper's own flavor line
	# (see test_shop_gear.gd's shopkeeper coverage), never this label.
	club_button.mouse_entered.emit()
	print("hovering a row no longer touches the description label: text='%s' (expected empty)" % [main.hud.shop_description_label.text])
	club_button.mouse_exited.emit()
	print("...still empty after leaving: text='%s' (expected empty)" % [main.hud.shop_description_label.text])

	# A row the player can't afford is disabled -- force it deterministically
	# by dropping to 0 coins and refreshing (the club row stays enabled,
	# since it's already owned and always free to re-equip).
	player.coins = 0
	main._refresh_shop_display()
	var unaffordable_idx := -1
	for i in main.current_shop_offering.size():
		var item: Dictionary = main.current_shop_offering[i]
		var already_owned: bool = item.category == "weapon" and player.owned_weapons.has(item.id)
		if not already_owned:
			unaffordable_idx = i
			break
	print("an unaffordable row (0 coins) is disabled: disabled=%s (expected true)" % [_row_button(main.hud.shop_row_nodes[unaffordable_idx]).disabled])
	print("the owned club row stays enabled regardless of coins: disabled=%s (expected false)" % [_row_button(main.hud.shop_row_nodes[0]).disabled])
	player.coins = 200
	main._refresh_shop_display()

	# The Reroll button costs coins and changes the offering.
	var coins_before_reroll: int = player.coins
	var expected_reroll_cost: int = main._get_shop_reroll_cost()
	var reroll_cost_shown: String = main.hud.shop_reroll_button.text
	main.hud.shop_reroll_button.pressed.emit()
	print("clicking Reroll spends coins: spent=%d (expected %d), button_showed=%s" % [
		coins_before_reroll - player.coins, expected_reroll_cost, reroll_cost_shown
	])

	# The Continue button advances the wave and closes the shop.
	var wave_before: int = main.wave
	main.hud.shop_continue_button.pressed.emit()
	print("clicking Continue advances the wave: wave %d -> %d (expected +1), shop_open=%s (expected false)" % [
		wave_before, main.wave, main.shop_open
	])

	quit()
