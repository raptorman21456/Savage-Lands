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

	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_units = []
	main.battle_target_index = 0

	# Water pushes the player at the end of their turn, the same way it
	# already pushed enemies at the end of theirs (see _apply_water_push's
	# other call sites in _process_enemy_turn). No units in battle_units, so
	# _end_player_turn's cascade into a real enemy turn is a safe no-op here.
	main.battle_terrain[Vector2i(2, 2)] = {"type": "water", "push_dir": Vector2i(0, 1)}
	main.battle_player_tile = Vector2i(2, 2)
	main._end_player_turn()
	print("water pushes the player at the end of their turn: tile=%s (expected (2, 3))" % [main.battle_player_tile])

	# Standing off water is a no-op, same as for any other unit.
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(3, 3)
	main._end_player_turn()
	print("no water, no push: tile=%s (expected unchanged (3, 3))" % [main.battle_player_tile])

	# A rock beyond the water blocks the push, same as it does for enemies.
	main.battle_terrain.clear()
	main.battle_terrain[Vector2i(1, 1)] = {"type": "water", "push_dir": Vector2i(0, 1)}
	main.battle_terrain[Vector2i(1, 2)] = {"type": "rock"}
	main.battle_player_tile = Vector2i(1, 1)
	main._end_player_turn()
	print("a rock beyond the water blocks the player's push: tile=%s (expected unchanged (1, 1))" % [main.battle_player_tile])

	quit()
