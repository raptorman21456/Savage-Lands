extends SceneTree

func _press_key(keycode: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)

func _init() -> void:
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	# Kill everything in wave 1 via the real death path, same setup as
	# test_shop_flow.gd, to enter the wave_clearing auto-shop-delay window.
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.take_damage(9999)
	await physics_frame
	await physics_frame
	if main.choosing_stat:
		main.player.apply_bonus_stat("vigor")
		main.hud.hide_levelup_choice()
		main.choosing_stat = false
		# Mirrors _on_levelup_choice_pressed's own cleanup -- it would
		# normally un-pause here (shop isn't open yet, we're not in battle),
		# so bypassing the real handler must still leave that in place or
		# every "paused" check below would be polluted by the level-up's
		# own get_tree().paused = true, not by anything this test cares about.
		paused = false

	print("wave_clearing is active with time left on the shop-open delay: wave_clearing=%s (expected true), timer>0=%s (expected true)" % [
		main.wave_clearing, main.shop_open_delay_timer > 0.0
	])

	# Pressing the pause key during this window must be a no-op -- the timer
	# is still ticking in the background even while "paused" (Main runs at
	# PROCESS_MODE_ALWAYS so the same key can un-pause), so opening the menu
	# here previously let the shop force itself open on top of it.
	_press_key(KEY_C, true)
	await process_frame
	await process_frame
	await process_frame
	_press_key(KEY_C, false)
	await process_frame
	print("the pause key does nothing during the wave-clear delay: menu_open=%s (expected false), paused=%s (expected false)" % [
		main.menu_open, paused
	])

	# Let the delay expire -- the shop should open on its own, with no pause
	# menu ever having been shown underneath it.
	main.shop_open_delay_timer = 0.0
	await process_frame
	await process_frame
	print("the shop auto-opens cleanly with no pause menu stuck behind it: shop_open=%s (expected true), wave_clearing=%s (expected false), menu_open=%s (expected false)" % [
		main.shop_open, main.wave_clearing, main.menu_open
	])

	# Close the shop the normal way (Enter) and confirm gameplay resumes
	# fully unpaused, with no leftover pause overlay.
	_press_key(KEY_ENTER, true)
	await process_frame
	await process_frame
	await process_frame
	_press_key(KEY_ENTER, false)
	await process_frame
	print("closing the shop leaves gameplay fully unpaused, no stuck overlay: shop_open=%s (expected false), menu_open=%s (expected false), paused=%s (expected false)" % [
		main.shop_open, main.menu_open, paused
	])

	# Sanity check: the pause key still works normally once we're back to
	# plain gameplay, confirming the fix didn't break real pausing.
	_press_key(KEY_C, true)
	await process_frame
	await process_frame
	await process_frame
	_press_key(KEY_C, false)
	await process_frame
	print("the pause key still works normally outside the wave-clear delay: menu_open=%s (expected true), paused=%s (expected true)" % [
		main.menu_open, paused
	])

	quit()
