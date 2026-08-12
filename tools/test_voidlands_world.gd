extends SceneTree

# Voidlands world (World Progression feature): Voidwing (miniboss) /
# Supreme Warlock (world-ending boss) -- the last "normal" world before
# Nothingness. Supreme Warlock's power_tier field is the hook the
# Nothingness rematch will use later (Phase 6) to re-fight the same boss at
# higher stats -- tested here directly since this is where it's introduced.

func _init() -> void:
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	# --- Data sanity ---
	var names := ["Voidwing", "Supreme Warlock"]
	var all_boss_tier := true
	var all_have_icons := true
	for n in names:
		if not main.ENEMY_TRAITS.get(n, {}).get("is_boss_tier", false):
			all_boss_tier = false
		if main.hud.ENEMY_ICONS.get(n, null) == null:
			all_have_icons = false
	print("Both Voidlands enemies are is_boss_tier: %s (expected true)" % [all_boss_tier])
	print("Both Voidlands enemies have HUD icons: %s (expected true)" % [all_have_icons])
	print("Voidwing is fast, evasive, AND genuinely ranged (unlike the melee Roc): move_range=%d dodge_chance=%.1f ignore_line=%s attack_range=%d (expected 3, 0.3, true, 2)" % [
		main.ENEMY_TRAITS["Voidwing"].move_range, main.ENEMY_TRAITS["Voidwing"].dodge_chance,
		main.ENEMY_TRAITS["Voidwing"].ignore_line, main.ENEMY_TRAITS["Voidwing"].attack_range
	])
	print("Supreme Warlock is an unarmored glass-cannon caster with a wide obstacle-ignoring spell: armored=%s sweeps=%s ignore_line=%s attack_range=%d (expected false, true, true, 2)" % [
		main.ENEMY_TRAITS["Supreme Warlock"].get("armored", false), main.ENEMY_TRAITS["Supreme Warlock"].sweeps,
		main.ENEMY_TRAITS["Supreme Warlock"].ignore_line, main.ENEMY_TRAITS["Supreme Warlock"].attack_range
	])

	# --- End-to-end wave-gated spawn ---
	main.wave = 95
	main.current_world_index = main._world_index_for_wave(main.wave)
	print("wave 95 resolves to Voidlands: %s (expected Voidlands)" % [main.WORLDS[main.current_world_index].name])
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await physics_frame
	main.enemies_alive = 0
	main._spawn_boss_wave()
	await physics_frame
	var mini_enemies: Array = main.get_tree().get_nodes_in_group("enemies")
	print("Voidlands' miniboss wave spawns a Voidwing: count=%d (expected 1), name=%s (expected Voidwing)" % [
		mini_enemies.size(), mini_enemies[0].get_display_name() if mini_enemies.size() == 1 else "none"
	])
	for e in mini_enemies:
		e.set_physics_process(false)

	main.wave = 100
	main.current_world_index = main._world_index_for_wave(main.wave)
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await physics_frame
	main.enemies_alive = 0
	main._spawn_boss_wave()
	await physics_frame
	var full_enemies: Array = main.get_tree().get_nodes_in_group("enemies")
	print("Voidlands' world-ending wave (wave 100) spawns a Supreme Warlock: count=%d (expected 1), name=%s (expected Supreme Warlock)" % [
		full_enemies.size(), full_enemies[0].get_display_name() if full_enemies.size() == 1 else "none"
	])
	for e in full_enemies:
		e.set_physics_process(false)

	# --- power_tier scaling hook: a rematch instance with power_tier=2.5
	# should come out of _setup_battle_grid with proportionally higher HP
	# and damage than a normal power_tier=1.0 instance, all else equal. ---
	player.level = 1
	player.difficulty_mult = 1.0
	var warlock_script = load("res://scripts/SupremeWarlock.gd")

	var normal_warlock = warlock_script.new()
	normal_warlock.power_tier = 1.0
	main.add_child(normal_warlock)
	main._setup_battle_grid([normal_warlock])
	var normal_hp: int = main.battle_units[0].hp
	var normal_dmg: int = main.battle_units[0].damage
	normal_warlock.set_physics_process(false)

	var rematch_warlock = warlock_script.new()
	rematch_warlock.power_tier = 2.5
	main.add_child(rematch_warlock)
	main._setup_battle_grid([rematch_warlock])
	var rematch_hp: int = main.battle_units[0].hp
	var rematch_dmg: int = main.battle_units[0].damage
	rematch_warlock.set_physics_process(false)

	print("power_tier=1.0 Supreme Warlock has its base stats: hp=%d (expected %d), dmg=%d (expected %d)" % [
		normal_hp, warlock_script.MAX_HEALTH, normal_dmg, warlock_script.ATTACK_DAMAGE
	])
	print("power_tier=2.5 rematch scales both HP and damage by 2.5x: hp=%d (expected %d), dmg=%d (expected %d)" % [
		rematch_hp, int(round(warlock_script.MAX_HEALTH * 2.5)), rematch_dmg, int(round(warlock_script.ATTACK_DAMAGE * 2.5))
	])
	print("...the rematch is meaningfully tougher than the normal fight: hp_ratio=%.2f dmg_ratio=%.2f (both expected ~2.5)" % [
		float(rematch_hp) / float(normal_hp), float(rematch_dmg) / float(normal_dmg)
	])

	# --- power_tier doesn't leak onto enemies that don't define it ---
	var goblin_script = load("res://scripts/Enemy.gd")
	var goblin = goblin_script.new()
	main.add_child(goblin)
	main._setup_battle_grid([goblin])
	print("A Goblin (no power_tier field) is unaffected -- defaults to 1.0 cleanly: hp=%d (expected %d)" % [
		main.battle_units[0].hp, int(round(goblin_script.MAX_HEALTH))
	])
	goblin.set_physics_process(false)

	quit()
