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

	var orc_script = load("res://scripts/Orc.gd")
	var orc = orc_script.new()
	main.add_child(orc)

	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(2, 2)
	player.health = player.max_health

	# An Orc already sitting exactly on its own computed flank tile -- the
	# scenario that used to leave it permanently idle, since its flanking
	# movement_target was its own current tile forever, giving it zero step
	# options every turn after with no fallback to just chase the player.
	var flank_tile: Vector2i = main._flank_target_tile(main.battle_player_tile)
	var traits: Dictionary = main.ENEMY_TRAITS.get("Orc", {})
	var orc_unit := {
		"ref": orc, "tile": flank_tile, "hp": 9999, "max_hp": 9999,
		"move_range": traits.get("move_range", 1), "damage": 4, "name": "Orc",
		"winding_up": false, "stunned": false,
	}
	main.battle_units = [orc_unit]

	print("the orc starts exactly on its own flank tile, out of melee range: at_flank=%s (expected true), in_range=%s (expected false)" % [
		orc_unit.tile == flank_tile, main._can_battle_attack(orc_unit.tile, main.battle_player_tile, 1)
	])

	var reached_range := false
	var moved_at_all := false
	for turn in 3:
		main._process_enemy_turn()
		if orc_unit.tile != flank_tile:
			moved_at_all = true
		if main._can_battle_attack(orc_unit.tile, main.battle_player_tile, 1):
			reached_range = true
			break

	print("the orc falls back to chasing the player directly instead of idling forever: moved_at_all=%s (expected true), reached_melee_range=%s (expected true) within %d turns" % [
		moved_at_all, reached_range, 3
	])

	quit()
