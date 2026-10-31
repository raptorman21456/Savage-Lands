extends SceneTree

# Walking into an enemy starts the fight. The plain enemies (Goblin, Brute, Wolf...) always did, the moment you touched them; the
# telegraphed ones (Orc and every miniboss and boss) only fought when their own wind-up strike landed, so walking into them did
# nothing. They all have a touch trigger now. Also: the quest board no longer pays in shards.

const TELEGRAPHED := ["Orc", "BlackDragonlet", "Treant", "IronConstruct", "LavaConstruct", "Voidwing", "WhiteDragon", "RedWyrm", "ElderOak", "Leviathan", "LizenWarband", "Archmage"]

func _init() -> void:
	seed(20261018)
	await process_frame
	await process_frame
	var started: Array = []
	var cooled_ok: Array = []
	var far_ok: Array = []
	for name in TELEGRAPHED:
		var main = load("res://Main.tscn").instantiate()
		root.add_child(main)
		await physics_frame
		await physics_frame
		for e in main.get_tree().get_nodes_in_group("enemies"):
			e.queue_free()
		await process_frame
		var player = main.player
		var enemy = load("res://scripts/%s.gd" % name).new()
		main.add_child(enemy)
		enemy.global_position = player.global_position + Vector2(300, 0)
		# far away: nothing happens
		enemy._physics_process(0.016)
		far_ok.append(not main.in_battle)
		# touching, but still on cooldown (it has only just fought): nothing happens
		enemy.global_position = player.global_position + Vector2(20, 0)
		enemy.attack_cooldown = 1.0
		enemy._physics_process(0.016)
		cooled_ok.append(not main.in_battle)
		# touching with nothing holding it back: the fight starts at once, without waiting for any wind-up
		enemy.attack_cooldown = 0.0
		enemy.is_winding_up = false
		enemy._physics_process(0.016)
		started.append(main.in_battle)
		get_root().get_tree().paused = false
		main.queue_free()
		await process_frame
	print("each telegraphed enemy ignores you from far away: %s (expected all true)" % [far_ok.all(func(b): return b)])
	print("...and while still cooling down from its last fight: %s (expected all true)" % [cooled_ok.all(func(b): return b)])
	print("walking into each one starts the fight at once: %s (expected all true for %s)" % [started, ", ".join(TELEGRAPHED)])

	# the quest board pays coins, never shards
	var main2 = load("res://Main.tscn").instantiate()
	root.add_child(main2)
	await physics_frame
	await physics_frame
	var rewards_ok := true
	for template in ["cull_the_herd", "treasure_hunter", "monster_slayer"]:
		var slot: Dictionary = main2._build_quest(template)
		if int(slot.reward_shards) != 0 or int(slot.reward_coins) <= 0:
			rewards_ok = false
	print("every quest pays coins and no shards: %s (expected true)" % [rewards_ok])
	main2.queue_free()
	await process_frame
	quit()
