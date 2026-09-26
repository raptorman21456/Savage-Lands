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
	var weapons_script = load("res://scripts/Weapons.gd")

	# --- tab buttons exist and default to Gear ---
	print("tab buttons built: gear=%s enchant=%s (both expected true)" % [
		main.hud.shop_gear_tab_button != null, main.hud.shop_enchant_tab_button != null
	])
	print("Gear tab is visible by default: gear_visible=%s enchant_visible=%s (expected true, false)" % [
		main.hud.shop_row_scroll.visible, main.hud.shop_enchant_scroll.visible
	])

	# --- clicking the Enchant tab button swaps visibility ---
	main.hud.shop_enchant_tab_button.pressed.emit()
	print("clicking Enchant tab swaps visibility: gear_visible=%s enchant_visible=%s (expected false, true)" % [
		main.hud.shop_row_scroll.visible, main.hud.shop_enchant_scroll.visible
	])
	main.hud.shop_gear_tab_button.pressed.emit()
	print("clicking back to Gear: gear_visible=%s enchant_visible=%s (expected true, false)" % [
		main.hud.shop_row_scroll.visible, main.hud.shop_enchant_scroll.visible
	])

	# --- opening the shop populates the enchant tab with 4 rune rows for
	# whatever's currently equipped (Club by default) ---
	player.coins = 1000
	main._open_shop()
	print("enchant tab shows all 4 runes: %d (expected 4)" % main.hud.shop_enchant_row_nodes.size())
	print("Club can't be enchanted -- every rune row disabled: %s (expected true)" % [
		main.hud.shop_enchant_row_nodes.all(func(b): return b.disabled)
	])

	# --- equip a real weapon, then apply a rune via the HUD signal path ---
	var spear: Dictionary = weapons_script.SPEAR.duplicate(true)
	spear.id = "spear_enchant_ui_test"
	player.owned_weapons[spear.id] = true
	player._equip_weapon(spear)
	player.runic_shards = 10
	main._refresh_shop_display()
	print("a real equipped weapon has an affordable, enabled rune row: %s (expected true)" % [
		not main.hud.shop_enchant_row_nodes[0].disabled
	])

	main.hud.enchant_apply_pressed.emit("ember")
	print("applying via the HUD signal actually enchants: weapon_enchantments=%s (expected {%s: ember})" % [
		player.weapon_enchantments, spear.id
	])
	print("shop refreshed after applying -- shards label updated: %s (expected 7)" % [main.hud.shop_shards_label.text])
	print("enchant tab now shows 'already enchanted' state -- every row disabled again: %s (expected true)" % [
		main.hud.shop_enchant_row_nodes.all(func(b): return b.disabled)
	])

	quit()
