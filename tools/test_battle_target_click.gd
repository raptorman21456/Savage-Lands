extends SceneTree

func _make_unit(main, tile: Vector2i, name: String) -> Dictionary:
	var enemy_script = load("res://scripts/Enemy.gd")
	var e = enemy_script.new()
	main.add_child(e)
	e.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	return {
		"ref": e, "tile": tile, "hp": 999, "max_hp": 999, "move_range": 2,
		"damage": 0, "name": name, "winding_up": false, "stunned": false,
	}

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

	main.in_battle = true
	main.battle_turn = "player"
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_target_index = 0
	var goblin_a := _make_unit(main, Vector2i(3, 2), "Goblin")
	var goblin_b := _make_unit(main, Vector2i(1, 2), "Goblin")
	main.battle_units = [goblin_a, goblin_b]
	main._refresh_battle_display()

	# Pool slot 0 always shows battle_units[0], slot 1 always shows
	# battle_units[1] -- no reserved player slot anymore (a dedicated
	# player_marker replaced that, see HUD.gd) -- clicking each should pick
	# that squad index directly, the only way to choose a target now that
	# keyboard shortcuts are gone.
	main.hud.battle_unit_icons[1].pressed.emit()
	print("clicking the 2nd enemy's icon selects it as the target: target_index=%d (expected 1)" % [main.battle_target_index])
	main.hud.battle_unit_icons[0].pressed.emit()
	print("clicking the 1st enemy's icon selects it as the target: target_index=%d (expected 0)" % [main.battle_target_index])

	# Clicks are ignored outside the player's own turn.
	main.hud.battle_unit_icons[1].pressed.emit()
	main.battle_turn = "enemy"
	main.battle_target_index = 0
	main._on_enemy_target_selected(1)
	print("a click during the enemy's turn is ignored: target_index=%d (expected unchanged 0)" % [main.battle_target_index])
	main.battle_turn = "player"

	# An out-of-range index (e.g. a stale click after the squad shrank) is
	# ignored rather than corrupting battle_target_index.
	main._on_enemy_target_selected(5)
	print("an out-of-bounds index is ignored: target_index=%d (expected unchanged 0)" % [main.battle_target_index])

	# End-to-end: the manually clicked target is who the attack actually
	# lands on, wiring all the way through _effective_target_index.
	main.hud.battle_unit_icons[1].pressed.emit()
	player.stat_strength = 10
	player.attack_damage = 10
	main._battle_player_fight()
	print("the attack lands on the clicked target, not the default first index: goblin_b_hit=%s (expected true), goblin_a_untouched=%s (expected true)" % [
		goblin_b.hp < 999, goblin_a.hp == 999
	])

	quit()
