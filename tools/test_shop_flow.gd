extends SceneTree

# The shop is walk-in only now (see Main.gd:_try_open_shop/_build_town) --
# opened directly here the same way a door trigger would, rather than
# killing off wave 1 and waiting out an auto-open delay that no longer
# exists. Closing it (Enter/_on_shop_continue_pressed) no longer advances
# the wave either -- that's driven purely by kill milestones now (see
# KILLS_PER_TIER), checked separately below.

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

	main._try_open_shop("gear")
	print("shop_open=%s paused=%s wave=%d (still 1, walking in doesn't touch it)" % [
		main.shop_open, paused, main.wave
	])

	var weapons = load("res://scripts/Weapons.gd")
	player.coins = 100
	var bought: bool = player.try_buy_weapon(weapons.GREATSWORD)
	print("bought greatsword=%s current_weapon=%s coins_left=%d" % [bought, player.current_weapon.id, player.coins])

	# Simulate pressing Enter to close the shop (mirrors exactly what
	# Main._handle_shop_input does on Enter) -- purely closing the panel now,
	# nothing wave-related.
	var wave_before_close: int = main.wave
	main._on_shop_continue_pressed()
	print("closing the shop leaves the wave untouched: shop_open=%s (expected false), paused=%s (expected false), wave %d -> %d (expected unchanged)" % [
		main.shop_open, paused, wave_before_close, main.wave
	])

	# Progress now comes purely from kills -- drive one KILLS_PER_TIER
	# milestone via the real death path (side effects like XP/coins don't
	# matter here) and confirm it advances the wave on its own.
	for i in main.KILLS_PER_TIER:
		main._on_enemy_died(0)
		if main.event_choosing:
			main.event_choosing = false
			main.get_tree().paused = false

	print("a kill milestone advances the wave on its own: wave=%d (expected 2) weapon_still_equipped=%s" % [
		main.wave, player.current_weapon.id
	])

	quit()
