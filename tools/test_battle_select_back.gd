extends SceneTree

func _press_key(keycode: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)

# Z = Select, X = Back. Z's "select whatever's focused" behavior comes from
# registering Z as an extra key on Godot's built-in "ui_accept" action (see
# TitleScreen._bind_extra_select_key) -- the same native mechanism that
# already makes Enter/Space activate a focused Button, so it isn't
# re-implemented here; simulating a raw injected key through that whole
# native GUI dispatch pipeline proved flaky in a headless SceneTree (workable
# interactively, but not reliably reproducible via parse_input_event + a
# fixed frame count), so this test instead confirms the registration itself
# plus every explicitly-coded path: X-back in the Fight submenu, and Z/X in
# Move mode (whose buttons deliberately can't hold focus, so they need
# explicit key handling rather than the native ui_accept route).
func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var title_scene = load("res://TitleScreen.tscn")
	var title = title_scene.instantiate()
	root.add_child(title)
	await process_frame

	var z_bound_to_accept := false
	for event in InputMap.action_get_events("ui_accept"):
		if event is InputEventKey and event.keycode == KEY_Z:
			z_bound_to_accept = true
	print("Z is registered as an extra ui_accept key: %s (expected true)" % [z_bound_to_accept])
	title.queue_free()
	await process_frame

	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var goblin_script = load("res://scripts/Enemy.gd")
	var goblin = goblin_script.new()
	main.add_child(goblin)
	goblin.global_position = main.player.global_position + Vector2(30, 0)
	# This test isn't about the first-ever-battle tutorial -- mark it
	# completed first so trigger_battle doesn't force a solo squad/pinned
	# tile/gated menu on top of what's actually being tested here.
	load("res://scripts/SaveData.gd").mark_tutorial_completed()
	main.trigger_battle(goblin)
	await process_frame

	print("main menu starts with Move focused: %s (native ui_accept then activates it on Z, same as Enter/Space)" % [
		main.hud.battle_main_buttons["move"].has_focus()
	])

	# X backs out of the Fight submenu to the main menu.
	main.hud.battle_main_buttons["fight"].pressed.emit()
	print("entered fight submenu: menu_state=%s (expected fight)" % [main.battle_menu_state])
	_press_key(KEY_X, true)
	await process_frame
	await process_frame
	await process_frame
	print("X backs out of the fight submenu: menu_state=%s (expected main)" % [main.battle_menu_state])
	_press_key(KEY_X, false)
	await process_frame

	# Entering move mode releases focus, so a stale focused button (e.g. the
	# Move button itself) can't be silently re-triggered by the Z-is-
	# ui_accept binding while Z is being used for Confirm instead.
	main.hud.battle_main_buttons["move"].pressed.emit()
	print("focus is released on entering move mode: focus_owner=%s (expected null)" % [root.gui_get_focus_owner()])

	# Z confirms and X cancels in move mode, via explicit key handling.
	var tile_before: Vector2i = main.battle_player_tile
	_press_key(KEY_RIGHT, true)
	await process_frame
	await process_frame
	await process_frame
	_press_key(KEY_RIGHT, false)
	await process_frame
	_press_key(KEY_Z, true)
	await process_frame
	await process_frame
	await process_frame
	print("Z confirms the move without re-entering move mode: menu_state=%s (expected main), tile=%s (expected changed from %s)" % [
		main.battle_menu_state, main.battle_player_tile, tile_before
	])
	_press_key(KEY_Z, false)
	await process_frame
	await process_frame

	main.hud.battle_main_buttons["move"].pressed.emit()
	var tile_before_cancel: Vector2i = main.battle_player_tile
	_press_key(KEY_LEFT, true)
	await process_frame
	await process_frame
	await process_frame
	_press_key(KEY_LEFT, false)
	await process_frame
	_press_key(KEY_X, true)
	await process_frame
	await process_frame
	await process_frame
	print("X cancels the move: menu_state=%s (expected main), tile=%s (expected reverted to %s)" % [
		main.battle_menu_state, main.battle_player_tile, tile_before_cancel
	])
	_press_key(KEY_X, false)
	await process_frame

	quit()
