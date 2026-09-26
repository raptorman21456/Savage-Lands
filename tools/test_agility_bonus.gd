extends SceneTree

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var player = main.player

	# Choosing agility as a level-up bonus now grants +5, not +1 like a
	# stat that "does basically nothing" -- the other stats are unaffected.
	var agility_before: int = player.stat_agility
	player.apply_bonus_stat("agility")
	print("choosing agility grants +%d: %d -> %d (expected +%d)" % [
		player.AGILITY_BONUS_PER_LEVEL, agility_before, player.stat_agility, player.AGILITY_BONUS_PER_LEVEL
	])

	var strength_before: int = player.stat_strength
	player.apply_bonus_stat("strength")
	print("other stats are unaffected, still +1: %d -> %d (expected +1)" % [strength_before, player.stat_strength])

	# The faster growth shows up immediately in overworld move speed.
	print("move_speed tracks the boosted agility: %d (expected %d)" % [player.move_speed, player.stat_agility])

	# The battle move-range threshold now needs far less investment for the
	# same payoff: reaching +1 extra tile used to take 40 agility (8 picks
	# at the old +1/pick rate); it now takes AGILITY_PER_EXTRA_MOVE (20)
	# agility, or just 4 picks at +5 each.
	player.stat_agility = player.AGILITY_START
	print("move range at baseline: %d (expected %d)" % [main._battle_player_move_range(), main.PLAYER_BASE_MOVE_RANGE])
	for i in 4:
		player.apply_bonus_stat("agility")
	print("4 agility picks (+%d total) grant +1 battle move tile: agility=%d, move_range=%d (expected %d)" % [
		4 * player.AGILITY_BONUS_PER_LEVEL, player.stat_agility, main._battle_player_move_range(), main.PLAYER_BASE_MOVE_RANGE + 1
	])

	quit()
