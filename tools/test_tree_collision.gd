extends SceneTree

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

	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	var player = main.player
	# A tree directly below the player, close enough that walking down
	# should collide with its trunk almost immediately.
	player.global_position = Vector2(350, 250)
	main._add_tree_trunk_collision(Vector2(350, 280))
	await physics_frame

	var start_y: float = player.global_position.y
	_press_key(KEY_DOWN, true)
	for i in 60:
		await physics_frame
	_press_key(KEY_DOWN, false)
	var blocked_y: float = player.global_position.y
	print("player walking into a tree stops well short of its trunk: start_y=%.1f blocked_y=%.1f trunk_y=280 (expected blocked_y meaningfully < 280, e.g. < 275)" % [start_y, blocked_y])

	# A bush and a grass tuft, by contrast, have no collision at all --
	# confirm the player can walk straight through the same relative offset
	# with no obstruction (sanity check that ONLY trees got a collider).
	player.global_position = Vector2(450, 250)
	await physics_frame
	var bush_start_y: float = player.global_position.y
	_press_key(KEY_DOWN, true)
	for i in 60:
		await physics_frame
	_press_key(KEY_DOWN, false)
	var bush_end_y: float = player.global_position.y
	print("with no tree collision nearby, the player walks freely: moved=%s (expected true, end_y=%.1f > start_y=%.1f)" % [bush_end_y > bush_start_y + 20, bush_end_y, bush_start_y])

	quit()
