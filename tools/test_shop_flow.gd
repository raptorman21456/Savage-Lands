extends SceneTree

func _init() -> void:
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var player = main.player

	# Kill everything in wave 1 via the real death path (grants coins + XP).
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.take_damage(9999)
	await physics_frame
	await physics_frame

	# Resolve a coincidental level-up first, same as the wave test.
	if main.choosing_stat:
		player.apply_bonus_stat("vigor")
		main.hud.hide_levelup_choice()
		main.choosing_stat = false

	print("wave_clearing=%s shop_open=%s right after the kill (expected true, false -- shop opens after a delay)" % [
		main.wave_clearing, main.shop_open
	])

	# Fast-forward the shop-open delay rather than waiting 2 real seconds.
	# (Two frames, not one -- the first `await process_frame` just catches up
	# to the frame boundary the test is already inside; the actual _process()
	# tick that consumes the timer happens on the next one.)
	main.shop_open_delay_timer = 0.0
	await process_frame
	await process_frame

	print("shop_open=%s paused=%s coins=%d wave=%d (still 1)" % [
		main.shop_open, paused, player.coins, main.wave
	])

	var weapons = load("res://scripts/Weapons.gd")
	player.coins = 100
	var bought: bool = player.try_buy_weapon(weapons.GREATSWORD)
	print("bought greatsword=%s current_weapon=%s coins_left=%d" % [bought, player.current_weapon.id, player.coins])

	# Simulate pressing Enter to close the shop and advance to the next wave
	# (mirrors exactly what Main._handle_shop_input does on Enter).
	main.shop_open = false
	paused = false
	main.hud.hide_shop()
	main.wave += 1
	main._spawn_wave()
	main.hud.update_wave(main.wave)

	var expected_new_types := 0
	if main.wave >= main.ARCHER_WAVE_START:
		expected_new_types += 1
	if main.wave >= main.SHAMAN_WAVE_START:
		expected_new_types += 1
	if main.wave >= main.BRUTE_WAVE_START:
		expected_new_types += 1
	if main.wave >= main.SHADE_WAVE_START:
		expected_new_types += 1
	if main.wave >= main.WOLF_WAVE_START:
		expected_new_types += 1
	print("after continue: wave=%d (expected 2) enemies_alive=%d (expected %d) weapon_still_equipped=%s" % [
		main.wave, main.enemies_alive, main.ENEMY_COUNT + 1 + main.ORC_COUNT + expected_new_types, player.current_weapon.id
	])

	quit()
