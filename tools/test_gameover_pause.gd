extends SceneTree

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
	var enemy = main.get_tree().get_first_node_in_group("enemies")
	var enemy_start_pos: Vector2 = enemy.global_position

	player.take_damage(player.max_health + 100)
	await process_frame
	await process_frame

	print("after lethal damage: game_over=%s tree_paused=%s" % [main.game_over, paused])

	for i in 30:
		await process_frame
	print("30 frames after death: enemy moved=%s" % [enemy.global_position != enemy_start_pos])

	quit()
