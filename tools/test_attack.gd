extends SceneTree

# A sturdy stand-in for the Goblin: the Club now adds 2 Strength, so a swing from a fresh hero (3 damage) would kill a 3 HP enemy outright.
const TANK := 100

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	main.regional_world = false  # this test drives the old wave-ladder world
	root.add_child(main)
	await physics_frame
	await physics_frame

	var player = main.player
	var enemies = main.get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		e.set_physics_process(false)

	var enemy_a = enemies[0]
	var enemy_b = enemies[1]

	# Fresh enemy, in-direction (facing down) -- should hit.
	player.facing = Vector2(0, 1)
	enemy_a.health = TANK
	enemy_a.global_position = player.global_position + Vector2(0, 30)
	await physics_frame
	await physics_frame
	player._start_attack()
	for i in 10:
		await physics_frame
	print("in-direction (fresh enemy) -> health: %d (expected < %d)" % [enemy_a.health, TANK])

	# A DIFFERENT fresh enemy, placed behind (opposite of facing), never
	# previously near the hitbox -- should miss.
	player.facing = Vector2(0, 1)
	enemy_b.health = TANK
	enemy_b.global_position = player.global_position + Vector2(0, -30)
	await physics_frame
	await physics_frame
	player._start_attack()
	for i in 10:
		await physics_frame
	print("out-of-direction (fresh enemy) -> health: %d (expected == %d, i.e. missed)" % [enemy_b.health, TANK])

	# Regression check on enemy_a again: stationary in-direction enemy takes
	# damage on every swing, not just the first.
	player.facing = Vector2(0, 1)
	enemy_a.health = TANK
	enemy_a.global_position = player.global_position + Vector2(0, 30)
	await physics_frame
	await physics_frame
	var h0: int = enemy_a.health
	player._start_attack()
	for i in 10:
		await physics_frame
	var h1: int = enemy_a.health
	player._start_attack()
	for i in 10:
		await physics_frame
	var h2: int = enemy_a.health
	print("stationary repeated swings: %d -> %d -> %d (expect strictly decreasing)" % [h0, h1, h2])

	quit()
