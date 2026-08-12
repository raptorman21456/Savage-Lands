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
	var orc_script = load("res://scripts/Orc.gd")
	var orc = orc_script.new()
	main.add_child(orc)
	orc.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	orc.global_position = player.global_position + Vector2(50, 0)
	await physics_frame
	await physics_frame

	for i in 100:
		await physics_frame

	print("after orc closes in and winds up: in_battle=%s (expected true) paused=%s" % [main.in_battle, paused])

	quit()
