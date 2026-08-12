extends SceneTree

func _init() -> void:
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var player = main.player
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_player_moves_left = 3
	main.battle_menu_state = "main"
	main.battle_units = []

	# Selecting Move enters move mode and snapshots the undo state.
	main._on_battle_main_action("move")
	print("selecting Move enters move mode: state=%s (expected move), undo_tile=%s (expected (2,2)), undo_moves=%d (expected 3)" % [
		main.battle_menu_state, main.battle_move_undo_tile, main.battle_move_undo_moves_left
	])

	# Moving records a trail entry and updates position/moves_left.
	main._try_battle_player_move(Vector2i(1, 0))
	print("moving once: tile=%s (expected (3,2)), moves_left=%d (expected 2), trail_size=%d (expected 1)" % [
		main.battle_player_tile, main.battle_player_moves_left, main.battle_move_trail.size()
	])
	main._try_battle_player_move(Vector2i(0, 1))
	print("moving twice: tile=%s (expected (3,3)), trail_size=%d (expected 2), trail=%s" % [
		main.battle_player_tile, main.battle_move_trail.size(), main.battle_move_trail
	])

	# Cancel fully reverts to the pre-move snapshot and clears the trail.
	main._on_battle_move_action("cancel")
	print("cancel reverts position and moves: tile=%s (expected (2,2)), moves_left=%d (expected 3), trail_size=%d (expected 0), state=%s (expected main)" % [
		main.battle_player_tile, main.battle_player_moves_left, main.battle_move_trail.size(), main.battle_menu_state
	])

	# Cancel also undoes cliff-fall damage taken during the pending move.
	# The cliff's own dir must match the movement direction (up, (0,-1)) or
	# the one-way rule blocks the step entirely -- landing on (2,0), which
	# isn't water, so it triggers a fall.
	main.battle_terrain[Vector2i(2, 1)] = {"type": "cliff", "dir": Vector2i(0, -1)}
	player.health = player.max_health
	main._on_battle_main_action("move")
	main._try_battle_player_move(Vector2i(0, -1))
	var health_after_fall: int = player.health
	main._on_battle_move_action("cancel")
	print("cancel undoes cliff-fall damage: health_after_fall=%d (expected < %d), health_after_cancel=%d (expected %d)" % [
		health_after_fall, player.max_health, player.health, player.max_health
	])
	main.battle_terrain.clear()

	# Confirm keeps the new position and clears the trail.
	main._on_battle_main_action("move")
	main._try_battle_player_move(Vector2i(1, 0))
	main._on_battle_move_action("confirm")
	print("confirm keeps the new position: tile=%s (expected (3,2)), trail_size=%d (expected 0), state=%s (expected main)" % [
		main.battle_player_tile, main.battle_move_trail.size(), main.battle_menu_state
	])

	# Selecting Move with no moves left refuses and stays in the main menu.
	main.battle_player_moves_left = 0
	main._on_battle_main_action("move")
	print("move refuses with no moves left: state=%s (expected main)" % [main.battle_menu_state])

	# The HUD "Move" button and Confirm/Cancel buttons drive the same path.
	main.battle_player_moves_left = 2
	main.battle_player_tile = Vector2i(2, 2)
	main._refresh_battle_display()
	main.hud.battle_main_buttons["move"].pressed.emit()
	print("HUD Move button opens move mode: state=%s (expected move), main_visible=%s (expected false), move_visible=%s (expected true)" % [
		main.battle_menu_state, main.hud.battle_main_menu_box.visible, main.hud.battle_move_submenu_box.visible
	])
	main._try_battle_player_move(Vector2i(1, 0))
	main.hud.battle_move_buttons["cancel"].pressed.emit()
	print("HUD Cancel button reverts the move: tile=%s (expected (2,2)), state=%s (expected main)" % [
		main.battle_player_tile, main.battle_menu_state
	])

	# Move button disables once moves are exhausted.
	main.battle_player_moves_left = 0
	main._refresh_battle_display()
	print("Move button disables with no moves left: disabled=%s (expected true)" % [main.hud.battle_main_buttons["move"].disabled])

	quit()
