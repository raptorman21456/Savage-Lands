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

	var boss_script = load("res://scripts/Boss.gd")
	var owlbear_script = load("res://scripts/Owlbear.gd")
	var goblin_script = load("res://scripts/Enemy.gd")
	var orc_script = load("res://scripts/Orc.gd")

	# --- A plain Boss fight gets the bigger 15x15 arena. ---
	var boss = boss_script.new()
	main.add_child(boss)
	main._setup_battle_grid([boss])
	print("a Boss fight sets up on a 15x15 grid: w=%d h=%d (expected 15, 15)" % [main.BATTLE_GRID_W, main.BATTLE_GRID_H])
	print("_in_battle_bounds matches the 15x15 grid: (14,14)=%s (expected true), (15,15)=%s (expected false)" % [
		main._in_battle_bounds(Vector2i(14, 14)), main._in_battle_bounds(Vector2i(15, 15))
	])

	# --- The Owlbear that replaces it from OWLBEAR_WAVE_START on gets the
	# same bigger arena. ---
	var owlbear = owlbear_script.new()
	main.add_child(owlbear)
	main._setup_battle_grid([owlbear])
	print("an Owlbear fight also sets up on a 15x15 grid: w=%d h=%d (expected 15, 15)" % [main.BATTLE_GRID_W, main.BATTLE_GRID_H])

	# --- A normal (non-boss) wave battle still gets the standard 8x8 --
	# proves the var-instead-of-const change didn't leak a stale 15 into
	# every other fight. ---
	var goblin1 = goblin_script.new()
	var goblin2 = goblin_script.new()
	main.add_child(goblin1)
	main.add_child(goblin2)
	main._setup_battle_grid([goblin1, goblin2])
	print("a normal goblin battle stays on the standard 8x8 grid: w=%d h=%d (expected 8, 8)" % [main.BATTLE_GRID_W, main.BATTLE_GRID_H])
	print("_in_battle_bounds matches the 8x8 grid: (7,7)=%s (expected true), (8,8)=%s (expected false)" % [
		main._in_battle_bounds(Vector2i(7, 7)), main._in_battle_bounds(Vector2i(8, 8))
	])

	# A squad with an Orc (tough-tier, but not solo) never gets the boss
	# grid either -- the size check is specifically "solo Boss/Owlbear", not
	# "any dangerous unit."
	var orc = orc_script.new()
	main.add_child(orc)
	main._setup_battle_grid([orc])
	print("a solo Orc fight is NOT treated as a boss fight: w=%d h=%d (expected 8, 8)" % [main.BATTLE_GRID_W, main.BATTLE_GRID_H])

	# --- _flank_target_tile's center-based math still works sanely at the
	# larger size: the flank of a corner still lands in-bounds, on the far
	# side away from the grid's (now-bigger) center, same shape as the
	# existing 6x6 flank test in test_enemy_variety.gd. ---
	main._setup_battle_grid([boss])
	print("flank targeting stays sane on the 15x15 grid: flank_of_(2,2)=%s (expected (1,1)), flank_of_(12,12)=%s (expected (13,13))" % [
		main._flank_target_tile(Vector2i(2, 2)), main._flank_target_tile(Vector2i(12, 12))
	])

	# --- Terrain density scales with grid area instead of staying flat, so a
	# bigger battlefield doesn't feel emptier -- see _setup_battle_grid's
	# terrain_scale. A boss fight is solo, so nearly the whole 225-tile grid
	# is free; the scaled counts (rock/water ~19, ledge ~13, cliff ~6) should
	# all fit without exhausting _place_terrain's retry budget.
	var terrain_count := 0
	for t in main.battle_terrain:
		terrain_count += 1
	print("terrain scales up on the bigger 15x15 boss grid instead of staying flat: %d tiles placed (expected roughly 55-60, ~25%% of 225)" % [terrain_count])

	quit()
