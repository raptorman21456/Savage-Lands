extends SceneTree

# Enemy HP/damage scale with the player's level (Main._enemy_level_scale): the per-level rate
# depends on the save's difficulty, and bosses/minibosses (is_boss_tier) scale at
# BOSS_LEVEL_SCALING_FACTOR of it. The rates are DRAFT numbers (see the Main.gd constants); this
# test pins the mechanism, with hand-computed expectations for a few cases.

func _stats_for(main, player, level: int, difficulty_id: String, script_path: String) -> Array:
	player.level = level
	player.difficulty_id = difficulty_id
	player.difficulty_mult = main.SaveDataScript.get_difficulty_mult(difficulty_id)
	var e = load(script_path).new()
	main.add_child(e)
	main._setup_battle_grid([e])
	var u: Dictionary = main.battle_units[0]
	e.set_physics_process(false)
	return [u.hp, u.damage]

func _init() -> void:
	seed(20261005)
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player

	print("the Normal rate stays ENEMY_LEVEL_SCALING (5%%): %s (expected 0.05)" % [main.ENEMY_LEVEL_SCALING_BY_DIFFICULTY["normal"]])
	print("every difficulty has a rate: %s (expected true)" % [
		main.ENEMY_LEVEL_SCALING_BY_DIFFICULTY.has("baby") and main.ENEMY_LEVEL_SCALING_BY_DIFFICULTY.has("hard") and main.ENEMY_LEVEL_SCALING_BY_DIFFICULTY.has("apocalyptic")
	])
	print("harder difficulties scale faster per level: %s (expected true)" % [
		main.ENEMY_LEVEL_SCALING_BY_DIFFICULTY["baby"] < main.ENEMY_LEVEL_SCALING_BY_DIFFICULTY["normal"]
		and main.ENEMY_LEVEL_SCALING_BY_DIFFICULTY["normal"] < main.ENEMY_LEVEL_SCALING_BY_DIFFICULTY["hard"]
		and main.ENEMY_LEVEL_SCALING_BY_DIFFICULTY["hard"] < main.ENEMY_LEVEL_SCALING_BY_DIFFICULTY["apocalyptic"]
	])

	# --- the multiplier function ---
	player.difficulty_id = "normal"
	player.level = 1
	print("level 1 never scales: regular=%.2f boss=%.2f (expected 1.00, 1.00)" % [main._enemy_level_scale(false), main._enemy_level_scale(true)])
	player.level = 11
	print("Normal level 11: regular x%.3f (expected 1.500), boss x%.3f (expected 1.250, half the rate)" % [main._enemy_level_scale(false), main._enemy_level_scale(true)])
	player.difficulty_id = "hard"
	print("Hard level 11: regular x%.2f (expected 1.80), boss x%.2f (expected 1.40)" % [main._enemy_level_scale(false), main._enemy_level_scale(true)])
	player.difficulty_id = "not_a_difficulty"
	print("an unknown difficulty id falls back to the Normal rate: x%.2f (expected 1.50)" % [main._enemy_level_scale(false)])

	# --- through the real _setup_battle_grid (HP and damage) ---
	var goblin_hard: Array = _stats_for(main, player, 10, "hard", "res://scripts/Enemy.gd")
	print("Hard, level 10 Goblin (base 3 HP / 1 dmg, x1.72 level x1.75 difficulty): hp=%d dmg=%d (expected 9, 3)" % [goblin_hard[0], goblin_hard[1]])
	var treant_normal: Array = _stats_for(main, player, 10, "normal", "res://scripts/Treant.gd")
	print("Normal, level 10 Treant (miniboss, base 175 HP / 6 dmg, x1.225): hp=%d dmg=%d (expected 214, 7)" % [treant_normal[0], treant_normal[1]])
	var goblin_baby: Array = _stats_for(main, player, 20, "baby", "res://scripts/Enemy.gd")
	print("Baby, level 20 Goblin (x1.57 level x0.75 difficulty): hp=%d dmg=%d (expected 4, 1)" % [goblin_baby[0], goblin_baby[1]])
	var oak_normal: Array = _stats_for(main, player, 10, "normal", "res://scripts/ElderOak.gd")
	print("a full boss scales at the same gentle rate as a miniboss (Elder Oak, base 245 HP, x1.225): hp=%d (expected 300)" % [oak_normal[0]])

	quit()
