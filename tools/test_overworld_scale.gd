extends SceneTree

# Overworld enemies and party followers were drawn small next to the (much
# bigger) world -- see Main.gd:OVERWORLD_ENEMY_SCALE/_size_overworld_enemy.
# Enemies are scaled on the root node so the collision body grows with the
# sprite; followers get the scale their counterpart already uses.

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var enemies: Array = main.get_tree().get_nodes_in_group("enemies")
	var all_scaled := enemies.size() > 0
	for e in enemies:
		if not e.scale.is_equal_approx(Vector2(main.OVERWORLD_ENEMY_SCALE, main.OVERWORLD_ENEMY_SCALE)):
			all_scaled = false
	print("every wave-spawned enemy carries the overworld scale: %s (expected true), count=%d" % [all_scaled, enemies.size()])

	for e in enemies:
		e.set_physics_process(false)
		e.queue_free()
	await physics_frame
	main.enemies_alive = 0
	main._spawn_boss_wave()
	var boss = main.get_tree().get_nodes_in_group("enemies")[0]
	print("a boss spawned by _spawn_boss_wave is scaled too: %s (expected true)" % [
		boss.scale.is_equal_approx(Vector2(main.OVERWORLD_ENEMY_SCALE, main.OVERWORLD_ENEMY_SCALE))
	])
	boss.set_physics_process(false)
	boss.queue_free()
	await physics_frame

	# The scaled body's collision shape must grow with it: a goblin shoved
	# into the map's left boundary wall should stop a scaled radius away
	# (~14 * 1.5 = 21), not the unscaled 14.
	var goblin = main.EnemyScript.new()
	goblin.position = Vector2(80, 500)
	main._size_overworld_enemy(goblin)
	main.add_child(goblin)
	goblin.wander_dir = Vector2(-1, 0)
	goblin.wander_timer = 1000.0
	for i in 90:
		await physics_frame
	var stopped_x: float = goblin.global_position.x
	print("a scaled enemy's hitbox scales with it -- stops a scaled radius off the wall: x=%.1f (expected ~21, well past the unscaled ~14)" % [stopped_x])
	print("...clearly further than an unscaled body would: %s (expected true)" % [stopped_x > 17.5])
	goblin.queue_free()

	# Followers: wolf matches an overworld Wolf enemy's on-screen size, the
	# Blade Ally matches the player's own scale.
	var player = main.player
	player.party_wolf = {"name": "Traitor Wolf", "dmg_mult": 0.6}
	player.party_members.append({"name": "Blade Ally", "dmg_mult": 0.75})
	main._process(0.016)
	var wolf_expected: Vector2 = Vector2(1.75, 1.75) * main.OVERWORLD_ENEMY_SCALE
	print("the wolf follower matches an overworld Wolf enemy's size: %s (expected true)" % [
		main.party_follower_nodes[0].scale.is_equal_approx(wolf_expected)
	])
	print("the Blade Ally follower matches the player's own scale: %s (expected true)" % [
		main.party_follower_nodes[1].scale.is_equal_approx(main.PlayerScript.BASE_SPRITE_SCALE)
	])

	quit()
