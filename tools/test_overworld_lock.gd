extends SceneTree

func _press_key(keycode: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)

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
	var enemies = main.get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		e.set_physics_process(false)

	var enemy = enemies[0]
	player.facing = Vector2(0, 1)
	enemy.health = enemy.MAX_HEALTH
	enemy.global_position = player.global_position + Vector2(0, 30)

	print("locked by default: %s (expected true)" % player.overworld_attack_locked)

	# Holding the real WASD attack key should do nothing while locked.
	_press_key(KEY_S, true)
	await physics_frame
	await physics_frame
	print("WASD attack blocked while locked: attack_timer=%.2f enemy_health=%d (expected 0.00, %d unchanged)" % [
		player.attack_timer, enemy.health, enemy.MAX_HEALTH
	])
	_press_key(KEY_S, false)
	await physics_frame

	# Unlocking restores the real WASD-driven swing.
	player.overworld_attack_locked = false
	_press_key(KEY_S, true)
	await physics_frame
	for i in 10:
		await physics_frame
	print("WASD attack works once unlocked: enemy_health=%d (expected < %d)" % [enemy.health, enemy.MAX_HEALTH])
	_press_key(KEY_S, false)
	await physics_frame

	quit()
