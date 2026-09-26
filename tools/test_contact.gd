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
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	var enemy_script = load("res://scripts/Enemy.gd")
	var enemy = enemy_script.new()
	main.add_child(enemy)
	enemy.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	enemy.global_position = player.global_position + Vector2(30, 0)

	print("before contact: in_battle=%s" % [main.in_battle])

	for i in 10:
		await physics_frame

	print("after real contact (enemy's own _physics_process still running): in_battle=%s (expected true) paused=%s" % [
		main.in_battle, paused
	])

	quit()
