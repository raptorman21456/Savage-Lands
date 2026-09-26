extends SceneTree

# World infrastructure: wave->world index math, per-world terrain rolled
# into real battles (RESERVED_TERRAIN_TYPES finally in use), ground tint /
# battle backdrop swapping with the current world.

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var goblin_script = load("res://scripts/Enemy.gd")

	# --- wave -> world index boundaries ---
	print("wave 1 is world 0 (Plains): %d (expected 0)" % [main._world_index_for_wave(1)])
	print("wave 10 (Plains' last wave) is still world 0: %d (expected 0)" % [main._world_index_for_wave(10)])
	print("wave 11 crosses into world 1 (Beach): %d (expected 1)" % [main._world_index_for_wave(11)])
	print("wave 100 (Voidlands' last wave) is world 9: %d (expected 9)" % [main._world_index_for_wave(100)])
	print("wave 101 crosses into world 10 (Nothingness): %d (expected 10)" % [main._world_index_for_wave(101)])
	print("wave 500 stays clamped at world 10, never runs off the table: %d (expected 10)" % [main._world_index_for_wave(500)])
	print("WORLDS has exactly 11 entries (10 campaign worlds + Nothingness): %d (expected 11)" % [main.WORLDS.size()])

	# --- Plains rolls no reserved terrain -- only the base 4 types ---
	main.wave = 1
	main.current_world_index = main._world_index_for_wave(main.wave)
	var g1 = goblin_script.new()
	var g2 = goblin_script.new()
	main.add_child(g1)
	main.add_child(g2)
	main._setup_battle_grid([g1, g2])
	var plains_has_reserved := false
	for t in main.battle_terrain.values():
		if t.type in main.RESERVED_TERRAIN_TYPES:
			plains_has_reserved = true
	print("Plains (world 0) never rolls a reserved terrain type: %s (expected false)" % [plains_has_reserved])

	# --- Swamp (world 2, wave 25) rolls poison_bog ---
	main.wave = 25
	main.current_world_index = main._world_index_for_wave(main.wave)
	print("wave 25 resolves to Swamp: %s (expected Swamp)" % [main.WORLDS[main.current_world_index].name])
	var g3 = goblin_script.new()
	var g4 = goblin_script.new()
	main.add_child(g3)
	main.add_child(g4)
	# Retried a few times -- _place_terrain rolls random tiles, so a single
	# unlucky pass (2 tiles requested, 60 attempts, tiny chance of a total
	# miss on an 8x8 grid already crowded with rock/water/ledge/cliff) could
	# in principle place zero. Matches the pattern other terrain tests use.
	var swamp_has_poison_bog := false
	for attempt in 5:
		main._setup_battle_grid([g3, g4])
		for t in main.battle_terrain.values():
			if t.type == "poison_bog":
				swamp_has_poison_bog = true
		if swamp_has_poison_bog:
			break
	print("Swamp (world 2) rolls poison_bog into its battles: %s (expected true)" % [swamp_has_poison_bog])

	# --- Voidlands rolls both of its 2 reserved types (caltrops + spring) ---
	main.wave = 95
	main.current_world_index = main._world_index_for_wave(main.wave)
	print("wave 95 resolves to Voidlands: %s (expected Voidlands)" % [main.WORLDS[main.current_world_index].name])
	print("Voidlands carries exactly 2 terrain types: %s (expected [caltrops, spring])" % [main.WORLDS[main.current_world_index].terrain])

	# --- Nothingness (world 10) also rolls no reserved terrain ---
	main.wave = 101
	main.current_world_index = main._world_index_for_wave(main.wave)
	print("Nothingness carries no terrain flavor of its own: %s (expected [])" % [main.WORLDS[main.current_world_index].terrain])

	# --- Ground tint / battle backdrop follow the current world ---
	main.wave = 1
	main.current_world_index = main._world_index_for_wave(main.wave)
	main._apply_world_visuals()
	print("Plains' ground tint is neutral white: %s (expected (1, 1, 1, 1))" % [main.ground.modulate])
	main.wave = 81
	main.current_world_index = main._world_index_for_wave(main.wave)
	main._apply_world_visuals()
	print("wave 81 resolves to Volcano: %s (expected Volcano)" % [main.WORLDS[main.current_world_index].name])
	print("...and its ground tint is the warm reddish Volcano tint, not Plains' neutral: %s (expected != (1, 1, 1, 1))" % [main.ground.modulate != Color(1, 1, 1, 1)])
	print("Volcano's battle backdrop differs from Plains': %s (expected != (0.05, 0.05, 0.05))" % [main.WORLDS[main.current_world_index].battle_bg != Color(0.05, 0.05, 0.05)])

	# --- HUD world label text ---
	main.wave = 43
	main.current_world_index = main._world_index_for_wave(main.wave)
	print("world label for a mid-world wave shows name + progress: '%s' (expected 'World: Desert (3/10)')" % [main._world_label_text()])
	main.wave = 150
	main.current_world_index = main._world_index_for_wave(main.wave)
	print("world label for Nothingness omits the wave-in-world fraction: '%s' (expected 'World: Nothingness')" % [main._world_label_text()])

	# =========================================================
	# Boss-tier generalization: is_boss_tier trait (not a hardcoded name
	# list) drives solo-fight/big-arena detection, and _spawn_boss_wave picks
	# world-relative miniboss (wave 5-of-10) vs. boss (wave 10-of-10)
	# generically off WORLDS -- Beach still resolves to Boss/Owlbear today
	# (placeholder scripts, see WORLDS) but through the NEW mechanism.
	# =========================================================
	print("is_boss_tier drives solo-squad detection, not a name list: Boss=%s (expected true), Goblin=%s (expected false)" % [
		main.ENEMY_TRAITS.get("Boss", {}).get("is_boss_tier", false), main.ENEMY_TRAITS.get("Goblin", {}).get("is_boss_tier", false)
	])

	main.wave = 15  # Beach, wave-in-world 5 -> miniboss
	main.current_world_index = main._world_index_for_wave(main.wave)
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await physics_frame
	main.enemies_alive = 0
	main._spawn_boss_wave()
	await physics_frame
	var mini_enemies: Array = main.get_tree().get_nodes_in_group("enemies")
	print("wave 15 (Beach, world-relative wave 5) spawns that world's miniboss: count=%d (expected 1), name=%s (expected Boss)" % [
		mini_enemies.size(), mini_enemies[0].get_display_name() if mini_enemies.size() == 1 else "none"
	])
	for e in mini_enemies:
		e.set_physics_process(false)

	main.wave = 20  # Beach, wave-in-world 10 -> full boss
	main.current_world_index = main._world_index_for_wave(main.wave)
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await physics_frame
	main.enemies_alive = 0
	main._spawn_boss_wave()
	await physics_frame
	var full_enemies: Array = main.get_tree().get_nodes_in_group("enemies")
	print("wave 20 (Beach, world-relative wave 10) spawns that world's full boss: count=%d (expected 1), name=%s (expected Owlbear)" % [
		full_enemies.size(), full_enemies[0].get_display_name() if full_enemies.size() == 1 else "none"
	])
	for e in full_enemies:
		e.set_physics_process(false)

	quit()
