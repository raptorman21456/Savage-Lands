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

	# Boss waves: every BOSS_WAVE_INTERVAL-th wave spawns a solo boss instead
	# of the usual goblin/orc mix.
	main.wave = main.BOSS_WAVE_INTERVAL
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await physics_frame
	main.enemies_alive = 0
	main._spawn_wave()
	await physics_frame
	var enemies: Array = main.get_tree().get_nodes_in_group("enemies")
	print("boss wave spawns exactly one Boss: count=%d (expected 1), is_boss=%s (expected true)" % [
		enemies.size(), enemies.size() == 1 and enemies[0].get_display_name() == "Boss"
	])
	for e in enemies:
		e.set_physics_process(false)

	# Boss fights are solo -- no escorts get gathered even if enemies are
	# standing right next to it.
	var boss_script = load("res://scripts/Boss.gd")
	var goblin_script = load("res://scripts/Enemy.gd")
	var boss = boss_script.new()
	main.add_child(boss)
	boss.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	var nearby_goblin = goblin_script.new()
	main.add_child(nearby_goblin)
	nearby_goblin.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	nearby_goblin.global_position = boss.global_position + Vector2(10, 0)

	var squad = main._gather_squad(boss)
	print("boss battles are solo, no escorts gathered: squad_size=%d (expected 1)" % [squad.size()])

	# Set up a deterministic boss battle for the windup/enrage/knockback
	# checks below.
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_target_index = 0
	main.battle_player_defending = false
	main.battle_units = [{
		"ref": boss, "tile": Vector2i(3, 2), "hp": 150, "max_hp": 150, "move_range": 1,
		"damage": 6, "name": "Boss", "winding_up": false, "stunned": false,
	}]
	# Boost HP well past what the boss's hits deal so the checks below
	# compare relative damage instead of everything clamping to 0 health.
	player.stat_vigor = 100
	player._recalc_stats()
	player.health = player.max_health

	# The boss telegraphs before it hits, same as an Orc.
	main._process_enemy_turn()
	print("boss telegraphs before its first hit: player_health=%d (expected unchanged %d), winding_up=%s (expected true)" % [
		player.health, player.max_health, main.battle_units[0].winding_up
	])
	main._process_enemy_turn()
	var expected_windup_dmg: int = int(round(6 * main.ORC_WINDUP_DAMAGE_MULT))
	print("boss lands the telegraphed hit: player_health=%d (expected max_health-%d = %d)" % [
		player.health, expected_windup_dmg, player.max_health - expected_windup_dmg
	])

	# The boss enrages below 30% HP, hitting harder.
	main.battle_units[0].hp = 40  # < 30% of 150
	main.battle_units[0].winding_up = false
	player.health = player.max_health
	main._process_enemy_turn()  # telegraph
	main._process_enemy_turn()  # the actual hit, enraged
	var expected_enraged_dmg: int = int(round(6 * main.ORC_WINDUP_DAMAGE_MULT * main.BOSS_ENRAGE_DAMAGE_MULT))
	print("boss enrages below 30%% HP, hitting even harder: player_health=%d (expected max_health-%d = %d)" % [
		player.health, expected_enraged_dmg, player.max_health - expected_enraged_dmg
	])

	# The boss is always immune to knockback, no resist roll needed.
	main.battle_terrain.clear()
	var u := {
		"ref": boss, "tile": Vector2i(3, 2), "hp": 9999, "max_hp": 9999,
		"move_range": 1, "damage": 1, "name": "Boss", "winding_up": false, "stunned": false,
	}
	var resisted_all := true
	for i in 10:
		u.tile = Vector2i(3, 2)
		main._apply_knockback(u, Vector2i(1, 0))
		if u.tile != Vector2i(3, 2):
			resisted_all = false
	print("boss always resists knockback: resisted_all=%s (expected true)" % [resisted_all])

	# guaranteed_knockback specials still bypass boss resistance.
	u.tile = Vector2i(3, 2)
	main._apply_knockback(u, Vector2i(1, 0), true, true)
	print("guaranteed_knockback still moves a boss: tile=%s (expected (5, 2))" % [u.tile])

	# Killing the boss grants its full loot/XP through the real death path.
	var weak_boss = boss_script.new()
	main.add_child(weak_boss)
	weak_boss.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	main.battle_units = [{
		"ref": weak_boss, "tile": Vector2i(3, 2), "hp": 1, "max_hp": 150, "move_range": 1,
		"damage": 1, "name": "Boss", "winding_up": false, "stunned": false,
	}]
	main.battle_target_index = 0
	player.stat_strength = 5
	player.attack_damage = 5
	# Set the level high enough that granting XP_REWARD (500) in one go can't
	# cross a level threshold and wrap xp around, which would make a plain
	# before/after subtraction unreliable.
	player.level = 65
	player.xp = 0
	player.xp_to_next = player.XP_BASE + player.XP_PER_LEVEL * player.level
	var xp_before: int = player.xp
	main._battle_player_fight()
	print("killing the boss grants its XP reward: xp_gained=%d (expected %d)" % [player.xp - xp_before, boss_script.XP_REWARD])

	quit()
