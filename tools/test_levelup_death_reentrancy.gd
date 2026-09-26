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
	main.in_battle = true
	player.health = player.max_health

	# Simulate the exact same-call-stack cascade the bug depends on: a kill
	# that levels the player up, immediately followed (still mid attack-
	# resolution/enemy-turn cascade, no frame boundary in between) by a
	# separate hit that kills the player. _on_player_leveled_up and
	# take_battle_damage are the real signal handler/method this goes
	# through in actual gameplay -- called directly for a deterministic
	# repro instead of depending on real combat RNG lining both up.
	main._on_player_leveled_up(2)
	print("a level-up mid-battle opens its choice panel and pauses: choosing_stat=%s (expected true), paused=%s (expected true)" % [
		main.choosing_stat, paused
	])

	player.take_battle_damage(9999)
	print("dying in the same cascade correctly sets game_over: game_over=%s (expected true), in_battle=%s (expected false)" % [
		main.game_over, main.in_battle
	])
	print("the dangling level-up choice is cleared, not left behind the game-over screen: choosing_stat=%s (expected false), levelup_panel_visible=%s (expected false)" % [
		main.choosing_stat, main.hud.levelup_panel.visible
	])
	print("the game stays paused for the game-over screen: paused=%s (expected true)" % [paused])

	# Defense in depth: even if a level-up choice press somehow still lands
	# after this (e.g. a queued input event), it must not resume live
	# gameplay behind the game-over screen just because in_battle is false
	# -- that's a side effect of death, not proof the battle really ended.
	main._on_levelup_choice_pressed("vigor")
	print("a stray level-up choice press after death doesn't unpause behind game over: paused=%s (expected true), game_over=%s (expected true)" % [
		paused, main.game_over
	])

	quit()
