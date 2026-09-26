extends SceneTree

func _init() -> void:
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var player = main.player
	var weapons = load("res://scripts/Weapons.gd")

	print("baseline: weapon=%s reach=%.0f width=%.0f cooldown_after_attack=?" % [
		player.current_weapon.id, player.attack_collision.shape.size.x, player.attack_collision.shape.size.y
	])

	# Buy the spear (give free coins for the test) and check geometry/cooldown.
	player.coins = 100
	var bought: bool = player.try_buy_weapon(weapons.SPEAR)
	print("bought spear=%s coins_left=%d current=%s" % [bought, player.coins, player.current_weapon.id])
	print("spear shape size=%s (expected reach=75,width=18)" % [player.attack_collision.shape.size])

	player.facing = Vector2(0, 1)
	player._start_attack()
	print("spear cooldown_timer=%.4f (base 0.35 * mult 0.45 = 0.1575)" % [player.cooldown_timer])

	# Switch to the hammer (circle shape).
	var bought2: bool = player.try_buy_weapon(weapons.HAMMER)
	print("bought hammer=%s current=%s shape_type=%s radius=%.0f" % [
		bought2, player.current_weapon.id, player.attack_collision.shape.get_class(), player.attack_collision.shape.radius
	])

	# Battle axe + OHKO statistics: hit a fresh high-HP enemy many times and
	# count how often a single hit kills it outright (normal damage alone
	# would never one-shot a 500 HP target).
	player.try_buy_weapon(weapons.BATTLE_AXE)
	var enemy_script = load("res://scripts/Enemy.gd")
	var enemy = enemy_script.new()
	main.add_child(enemy)
	enemy.set_physics_process(false)
	await physics_frame

	var ohko_count := 0
	var trials := 300
	for i in trials:
		enemy.health = 500
		player.hit_this_swing.clear()
		player._apply_weapon_hit(enemy)
		if enemy.health <= 0:
			ohko_count += 1

	print("OHKO triggered %d/%d times (~%.1f%%, expected ~20%%)" % [ohko_count, trials, 100.0 * ohko_count / trials])

	quit()
