extends SceneTree

func _init() -> void:
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var player = main.player
	var enemy = main.get_tree().get_first_node_in_group("enemies")

	player.invincible_timer = 5.0
	var enemy_start_pos: Vector2 = enemy.global_position

	paused = true
	for i in 30:
		await process_frame
	print("while paused: player.invincible_timer=%.2f (expected ~5.0, unchanged), enemy moved=%s" % [
		player.invincible_timer, enemy.global_position != enemy_start_pos
	])

	paused = false
	for i in 30:
		await process_frame
	print("after unpause: player.invincible_timer=%.2f (expected < 5.0, ticked down)" % [player.invincible_timer])

	quit()
