extends SceneTree

func _press_key(keycode: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)

# The keyboard shortcut layer for battle menu actions (Z/X/C/R/V/M/1/2/3/Q/E)
# was removed entirely after repeated bug reports -- menu actions are
# mouse-only now (click the buttons). Grid movement while in "move" mode is
# the one exception, since there's no button equivalent for stepping
# tile-by-tile. This test confirms the removal actually took, and that
# movement keys still work.
func _init() -> void:
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var goblin_script = load("res://scripts/Enemy.gd")
	var goblin = goblin_script.new()
	main.add_child(goblin)
	goblin.global_position = main.player.global_position + Vector2(30, 0)
	main.trigger_battle(goblin)
	await process_frame

	# Battle terrain is randomly rolled -- clear it so the hardcoded RIGHT
	# move below always has a clear path (an unlucky rock roll otherwise
	# blocks the move and makes this test intermittently fail).
	main.battle_terrain.clear()

	# None of the old shortcut keys do anything from the main menu anymore.
	for key in [KEY_Z, KEY_X, KEY_C, KEY_R, KEY_V, KEY_M, KEY_1, KEY_2, KEY_3, KEY_Q, KEY_E]:
		_press_key(key, true)
		await process_frame
		await process_frame
		await process_frame
		_press_key(key, false)
		await process_frame

	print("no keyboard shortcut changed the menu state: menu_state=%s (expected main), still_in_battle=%s (expected true), still_defending=%s (expected false)" % [
		main.battle_menu_state, main.in_battle, main.battle_player_defending
	])

	# Clicking still works, unaffected by the shortcut removal.
	main.hud.battle_main_buttons["fight"].pressed.emit()
	print("clicking Fight still opens the attack submenu: menu_state=%s (expected fight)" % [main.battle_menu_state])
	main.hud.battle_fight_buttons["back"].pressed.emit()
	print("clicking Back still returns to the main menu: menu_state=%s (expected main)" % [main.battle_menu_state])

	# Grid movement while in "move" mode is the one keyboard path kept --
	# real arrow-key presses should still move the player.
	main.hud.battle_main_buttons["move"].pressed.emit()
	print("clicking Move enters move mode: menu_state=%s (expected move)" % [main.battle_menu_state])

	var tile_before: Vector2i = main.battle_player_tile
	_press_key(KEY_RIGHT, true)
	await process_frame
	await process_frame
	await process_frame
	print("arrow key still moves the player in move mode: tile=%s (expected changed from %s)" % [main.battle_player_tile, tile_before])
	_press_key(KEY_RIGHT, false)
	await process_frame

	quit()
