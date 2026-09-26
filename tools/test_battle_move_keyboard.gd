extends SceneTree

func _press_key(keycode: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)

# Move mode is the one place keyboard shortcuts still exist alongside
# arrow-key movement: Z confirms the pending move, X cancels/backs out of it.
func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
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

	# Battle terrain is randomly rolled -- clear it so the hardcoded
	# RIGHT/LEFT moves below always have a clear path (an unlucky rock roll
	# otherwise silently blocks a move and makes this test intermittently
	# fail, even though the input-handling logic itself is working fine).
	main.battle_terrain.clear()

	main.hud.battle_main_buttons["move"].pressed.emit()
	print("entered move mode: menu_state=%s (expected move)" % [main.battle_menu_state])

	# Move a tile via real arrow-key input, then confirm via real Z input.
	_press_key(KEY_RIGHT, true)
	await process_frame
	await process_frame
	await process_frame
	_press_key(KEY_RIGHT, false)
	await process_frame
	var tile_after_move: Vector2i = main.battle_player_tile

	_press_key(KEY_Z, true)
	await process_frame
	await process_frame
	await process_frame
	print("pressing Z confirms the move: menu_state=%s (expected main), tile=%s (expected unchanged from %s)" % [
		main.battle_menu_state, main.battle_player_tile, tile_after_move
	])
	_press_key(KEY_Z, false)
	await process_frame
	await process_frame

	# Re-enter move mode, move again, then cancel via real X input --
	# should fully revert to where this move session started.
	main.hud.battle_main_buttons["move"].pressed.emit()
	var tile_before_second_move: Vector2i = main.battle_player_tile
	_press_key(KEY_LEFT, true)
	await process_frame
	await process_frame
	await process_frame
	_press_key(KEY_LEFT, false)
	await process_frame
	print("moved again: tile=%s (expected different from %s)" % [main.battle_player_tile, tile_before_second_move])

	_press_key(KEY_X, true)
	await process_frame
	await process_frame
	await process_frame
	print("pressing X cancels the move: menu_state=%s (expected main), tile=%s (expected reverted to %s)" % [
		main.battle_menu_state, main.battle_player_tile, tile_before_second_move
	])
	_press_key(KEY_X, false)
	await process_frame

	quit()
