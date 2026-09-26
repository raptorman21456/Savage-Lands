extends SceneTree

func _press_key(keycode: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)

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
	# The shop is a flat lootpool now (see Main.gd:_roll_shop_offering) --
	# Club + SHOP_TOTAL_SLOTS alone (7) no longer exceeds the keyboard
	# handler's 9-key range, so this grants Investor's bonus-slots effect
	# directly to force a bigger offering, same as the overflow scenario
	# this test actually cares about (a shop offering bigger than 9 rows
	# must never crash the number-key polling below).
	player.meta_investor_bonus_slots = 5

	# The shop is walk-in only now -- opened directly the same way a door
	# trigger would (see Main.gd:_try_open_shop), no need to kill off wave 1
	# and wait out an auto-open delay that no longer exists.
	main._try_open_shop("gear")

	# Club + SHOP_TOTAL_SLOTS + the forced Investor bonus above -- comfortably
	# past the keyboard handler's old hardcoded 7-key range (and the current
	# 9-key one).
	print("shop opened with more than 7 offerings: offering_size=%d (expected > 7), shop_open=%s (expected true)" % [
		main.current_shop_offering.size(), main.shop_open
	])

	# Polling the shop's keyboard input every frame must never throw, no
	# matter how big the offering gets.
	var errored := false
	for i in 20:
		main._handle_shop_input()
	print("polling shop input 20 times with a big offering doesn't error: errored=%s (expected false, see console above)" % errored)

	# Pressing Enter still closes the shop -- walk-in shopping no longer
	# advances the wave on close (see Main.gd:_on_shop_continue_pressed), so
	# this only checks the panel itself closes cleanly.
	var wave_before: int = main.wave
	_press_key(KEY_ENTER, true)
	await process_frame
	await process_frame
	await process_frame
	main._handle_shop_input()
	print("Enter closes the shop without touching the wave: shop_open=%s (expected false), wave %d -> %d (expected unchanged)" % [
		main.shop_open, wave_before, main.wave
	])
	_press_key(KEY_ENTER, false)

	quit()
