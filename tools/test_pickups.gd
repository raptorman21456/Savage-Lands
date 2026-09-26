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

	# Directly spawn a coin pickup and a meat pickup on top of the player and
	# confirm collection applies the right effect.
	var pickup_script = load("res://scripts/Pickup.gd")

	var coin = pickup_script.new()
	coin.kind = "coin"
	coin.amount = 5
	coin.position = player.global_position
	main.add_child(coin)

	await physics_frame
	await physics_frame
	print("coin collected: player.coins=%d (expected 5)" % [player.coins])

	# Meat is a stockpiled healing item usable in battle, not an instant heal.
	player.healing_items = 0
	var meat = pickup_script.new()
	meat.kind = "meat"
	meat.amount = 1
	meat.position = player.global_position
	main.add_child(meat)

	await physics_frame
	await physics_frame
	print("meat collected: player.healing_items=%d (expected 1)" % [player.healing_items])

	# Now confirm real enemy deaths drop loot (statistically, since drops
	# have a chance component -- kill several and check at least some loot
	# appeared as child nodes of Main).
	var enemy_script = load("res://scripts/Enemy.gd")
	var dropped_any_meat := false
	var total_coins_seen := 0
	for i in 20:
		var e = enemy_script.new()
		main.add_child(e)
		e.global_position = Vector2(-500, -500)  # off in a corner, away from player
		e.take_damage(999)
		await physics_frame

	for p in main.get_tree().get_nodes_in_group("pickups"):
		if p.kind == "meat":
			dropped_any_meat = true
		else:
			total_coins_seen += p.amount

	print("after killing 20 goblins off-screen: coin_pickups_total_amount=%d (expected > 0), any_meat_dropped=%s" % [
		total_coins_seen, dropped_any_meat
	])

	quit()
