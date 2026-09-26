extends SceneTree

func _init() -> void:
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var player = main.player
	var goblin_script = load("res://scripts/Enemy.gd")
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	# --- spawn roll distribution ---
	var elite_count := 0
	var trials := 2000
	for i in trials:
		main._spawn_enemies(goblin_script, 1)
	# Disable physics immediately -- 2000+ active wander/chase nodes would
	# otherwise all tick on the next awaited frame for no reason this test
	# cares about.
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)
		if e.is_elite:
			elite_count += 1
	print("elite spawn rate over %d goblins: %d (expected roughly %d, ~%.0f%%)" % [
		trials, elite_count, int(trials * main.ELITE_CHANCE), main.ELITE_CHANCE * 100.0
	])

	# --- elite tint applied on the root node, not the child sprite ---
	var tinted := 0
	var untinted := 0
	for e in main.get_tree().get_nodes_in_group("enemies"):
		if e.is_elite and e.modulate == main.ELITE_TINT:
			tinted += 1
		elif not e.is_elite and e.modulate == Color(1, 1, 1, 1):
			untinted += 1
	print("elite root-node tint applied correctly: elites_tinted=%d/%d, non-elites_untinted=%d (expected both to roughly match elite_count/non-elite count)" % [
		tinted, elite_count, untinted
	])

	# --- boss never rolls elite, even spawned many times ---
	var boss_script = load("res://scripts/Boss.gd")
	var boss_elite_count := 0
	for i in 50:
		main._spawn_boss_wave()
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)
		if e.get_script() == boss_script and e.is_elite:
			boss_elite_count += 1
	print("Boss never rolls elite over 50 spawns: %d (expected 0)" % boss_elite_count)

	# --- elite stat boost reaches the tile battle via _setup_battle_grid ---
	var elite_goblin = goblin_script.new()
	main.add_child(elite_goblin)
	elite_goblin.is_elite = true
	main._setup_battle_grid([elite_goblin])
	var elite_unit: Dictionary = main.battle_units[0]
	var expected_hp: int = int(round(goblin_script.MAX_HEALTH * main.ELITE_HP_MULT))
	var expected_dmg: int = int(round(goblin_script.CONTACT_DAMAGE * main.ELITE_DAMAGE_MULT))
	print("elite stat boost reaches the battle grid: hp=%d (expected %d), damage=%d (expected %d), is_elite flag=%s (expected true)" % [
		elite_unit.hp, expected_hp, elite_unit.damage, expected_dmg, elite_unit.is_elite
	])

	var normal_goblin = goblin_script.new()
	main.add_child(normal_goblin)
	main._setup_battle_grid([normal_goblin])
	var normal_unit: Dictionary = main.battle_units[0]
	print("a non-elite goblin gets no boost: hp=%d (expected %d), damage=%d (expected %d)" % [
		normal_unit.hp, goblin_script.MAX_HEALTH, normal_unit.damage, goblin_script.CONTACT_DAMAGE
	])

	# --- killing an elite guarantees a shard drop ---
	player.runic_shards = 0
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_target_index = 0
	player.stat_strength = 999
	player.attack_damage = 999
	player.current_weapon = load("res://scripts/Weapons.gd").CLUB
	player.stamina = player.MAX_STAMINA
	var dying_elite = goblin_script.new()
	main.add_child(dying_elite)
	dying_elite.is_elite = true
	dying_elite.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	main.battle_units = [{
		"ref": dying_elite, "tile": Vector2i(3, 2), "hp": 1, "max_hp": 1, "move_range": 2,
		"damage": 0, "name": "Goblin", "winding_up": false, "stunned": false, "is_elite": true,
	}]
	main._battle_player_fight()
	await process_frame
	var shard_pickups: Array = main.get_tree().get_nodes_in_group("pickups").filter(func(p): return p.kind == "shard")
	print("killing an elite spawns a shard pickup: found=%s (expected true)" % [shard_pickups.size() > 0])
	if shard_pickups.size() > 0:
		player.add_runic_shards(shard_pickups[0].amount)
	print("player.runic_shards after collecting: %d (expected 1)" % player.runic_shards)

	# --- runic shard currency mutators mirror the coins pattern ---
	player.runic_shards = 5
	var spent: bool = player.try_spend_runic_shards(3)
	print("try_spend_runic_shards(3) from 5: succeeded=%s remaining=%d (expected true, 2)" % [spent, player.runic_shards])
	var failed: bool = player.try_spend_runic_shards(10)
	print("try_spend_runic_shards(10) from 2: succeeded=%s remaining=%d (expected false, 2)" % [failed, player.runic_shards])

	quit()
