extends SceneTree

# Castle town (Main.gd:_build_town) -- a walled plaza embedded directly in
# the wilderness map (see TOWN_AREA_ORIGIN), not a separate teleported-to
# space. Walking into its bounds is just walking; only the HUD's "Town"
# label reacts (see _update_town_label). Doors are tested by calling their
# guarded handlers directly rather than driving the player physically into
# each Area2D, same convention test_debug_keys.gd already uses for F1-F5.

func _press_key(keycode: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)

func _init() -> void:
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var player = main.player
	print("starts outside the town area: %s (expected false)" % [main._in_town_area(player.global_position)])

	# Walking into the town rect (simulated by setting position directly,
	# same convention every other overworld test uses) flips the HUD label
	# on the next frame -- no teleport, no state to carry over, since it was
	# never discontinuous to begin with.
	player.global_position = main.TOWN_AREA_ORIGIN + main.TOWN_SIZE / 2
	main._process(0.016)
	print("walking into the town area updates the HUD label: in_town=%s (expected true), label=%s (expected Town)" % [
		main._in_town_area(player.global_position), main.hud.world_label.text
	])

	# The town now sits dead-center on WORLD_SIZE/2, so "outside" has to be
	# the player's own spawn point (just past the south gate) rather than
	# the map's center -- that's inside the town now.
	player.global_position = main.PLAYER_SPAWN_POSITION
	main._process(0.016)
	print("walking back out restores the normal world label: in_town=%s (expected false), label_has_world=%s (expected true)" % [
		main._in_town_area(player.global_position), main.hud.world_label.text.begins_with("World:")
	])

	# Shop door -- opens the walk-in shop panel on the Gear tab, with the
	# Enchant tab not even shown, not just unclickable.
	main._try_open_shop("gear")
	print("the shop door opens the shop panel on Gear: shop_open=%s (expected true), gear_tab_active=%s (expected true)" % [
		main.shop_open, main.hud.shop_gear_tab_button.button_pressed
	])
	print("...and the Enchant tab isn't even shown from here: gear_visible=%s enchant_visible=%s (expected true, false)" % [
		main.hud.shop_gear_tab_button.visible, main.hud.shop_enchant_tab_button.visible
	])
	main._on_shop_continue_pressed()

	# Enchanter door -- same shop panel, defaulted to the Enchant tab
	# instead, with Gear now the one hidden.
	main._try_open_shop("enchant")
	print("...and it flips the other way through the Enchanter's door: enchant_visible=%s gear_visible=%s (expected true, false)" % [
		main.hud.shop_enchant_tab_button.visible, main.hud.shop_gear_tab_button.visible
	])
	print("the enchanter door opens the same shop panel on Enchant: shop_open=%s (expected true), enchant_tab_active=%s (expected true)" % [
		main.shop_open, main.hud.shop_enchant_tab_button.button_pressed
	])
	print("...presented as the Wizard's Tower, with nothing about rerolling gear: title=%s (expected WIZARD'S TOWER), reroll_visible=%s (expected false)" % [
		main.hud.shop_title_label.text, main.hud.shop_reroll_button.visible
	])
	print("the leave button says so, not \"Continue to Next Wave\": %s (expected Leave)" % [main.hud.shop_continue_button.text])

	# The [1-9]/[R] hotkeys must not reach through to the hidden gear
	# offering from inside the tower.
	player.coins = 5000
	var coins_in_tower: int = player.coins
	_press_key(KEY_2, true)
	_press_key(KEY_R, true)
	for i in 4:
		await process_frame
	_press_key(KEY_2, false)
	_press_key(KEY_R, false)
	await process_frame
	print("number keys / R can't buy or reroll gear from inside the tower: coins_unchanged=%s (expected true)" % [player.coins == coins_in_tower])

	# Escape leaves.
	_press_key(KEY_ESCAPE, true)
	for i in 4:
		await process_frame
	_press_key(KEY_ESCAPE, false)
	await process_frame
	print("Escape leaves the tower: shop_open=%s (expected false)" % [main.shop_open])

	# ...and the plain Shop gets its own title/reroll back afterward.
	main._try_open_shop("gear")
	print("the Shop presents as the Shop again afterward: title=%s (expected SHOP), reroll_visible=%s (expected true)" % [
		main.hud.shop_title_label.text, main.hud.shop_reroll_button.visible
	])
	main._on_shop_continue_pressed()

	# Healer door -- its own panel; Rest fully restores HP/stamina for coins.
	player.health = 1
	player.stamina = 0
	player.coins = main.HealerPanelScript.REST_COST
	main._try_open_healer()
	print("the healer door opens the Inn panel: visible=%s (expected true)" % [main.healer_panel.visible])
	main.healer_panel._on_rest_pressed()
	print("resting spends the coin cost and fully restores HP/stamina: coins=%d (expected 0), health=%d/%d stamina=%d/%d (expected both full)" % [
		player.coins, player.health, player.max_health, player.stamina, player.max_stamina
	])
	main.healer_panel.close()

	# Beastiary door -- opens the same, already-working Beastiary screen
	# that used to be reachable only through the pause menu.
	main._try_open_beastiary()
	print("the beastiary door opens the Beastiary screen: visible=%s (expected true)" % [main.beastiary_panel.visible])
	main.beastiary_panel.close()

	# Tavern door -- opens on its Bounty tab by default.
	main._try_open_tavern()
	print("the tavern door opens on the Bounty tab: visible=%s (expected true), tab=%s (expected Bounty)" % [
		main.tavern_panel.visible, main.tavern_panel.active_tab
	])
	main.tavern_panel.close()

	# Quest Board door -- opens with 3 rolled slots ready to accept.
	main._try_open_quest_board()
	print("the quest board door opens with 3 quest slots: visible=%s (expected true), slot_count=%d (expected 3)" % [
		main.quest_board_panel.visible, main.quest_slots.size()
	])
	main.quest_board_panel.close()

	# The newer venues all go through the town_panels registry.
	for kind in ["butcher", "flea_market", "blacksmith", "dojo", "seer", "wishing_well", "horse_racing", "fishing"]:
		main._try_open_panel(kind)
		print("the %s door opens its panel: visible=%s (expected true)" % [kind, main.town_panels[kind].visible])
		main.town_panels[kind].close()

	# Guard: every door does nothing mid-battle (unrelated to being in town
	# -- these guards only ever cared about in_battle/shop_open/etc).
	main.in_battle = true
	main._try_open_shop("gear")
	main._try_open_healer()
	main._try_open_beastiary()
	main._try_open_tavern()
	main._try_open_quest_board()
	print("every door is a no-op mid-battle: shop=%s healer=%s beastiary=%s tavern=%s quest_board=%s (all expected false)" % [
		main.shop_open, main.healer_panel.visible, main.beastiary_panel.visible, main.tavern_panel.visible, main.quest_board_panel.visible
	])
	for kind in main.town_panels:
		main._try_open_panel(kind)
	print("...and no registry panel opens mid-battle either: any_open=%s (expected false)" % [main._any_town_panel_open()])
	main.in_battle = false

	# Decorations and enemy spawns both steer clear of the town's footprint
	# now that it shares the same space they scatter across.
	var deco_in_town := false
	for d in main.deco_nodes:
		if main._in_town_area(d.position):
			deco_in_town = true
			break
	print("no scattered decoration lands inside the town: %s (expected false)" % [deco_in_town])

	var any_enemy_spawn_in_town := false
	for i in 200:
		if main._in_town_area(main._random_enemy_spawn_position()):
			any_enemy_spawn_in_town = true
			break
	print("enemy spawn positions never land inside the town either, over 200 rolls: %s (expected false)" % [any_enemy_spawn_in_town])

	quit()
