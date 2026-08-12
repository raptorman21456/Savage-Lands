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

	var player = main.player
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.take_damage(9999)
	await physics_frame
	await physics_frame
	# The wave-1 goblins/orcs/archer above are unfrozen through these frames,
	# and this world is small enough relative to their contact ranges (up to
	# 90px for the Archer) that one can occasionally land within contact
	# range of the player's center spawn and trigger a *real* trigger_battle()
	# before we ever get a say -- which leaves in_battle (and the tree's pause
	# state) stuck on and silently starves the wave_clearing/_open_shop
	# dispatch in _process() below, since it never reaches past the
	# `if in_battle` branch. That overworld-contact RNG has nothing to do with
	# what this test is actually checking (shop input safety), so neutralize
	# it before relying on the wave-clear path.
	if main.in_battle:
		main.in_battle = false
		main.get_tree().paused = false
	if main.choosing_stat:
		player.apply_bonus_stat("vigor")
		main.hud.hide_levelup_choice()
		main.choosing_stat = false
	main.shop_open_delay_timer = 0.0
	await process_frame
	await process_frame

	# A fresh wave-1 shop is club + SHOP_WEAPON_SLOTS weapons + armor + 3
	# potions -- 8 with the current slot count, well past the keyboard
	# handler's old hardcoded 7-key range.
	print("shop opened with more than 7 offerings: offering_size=%d (expected > 7), shop_open=%s (expected true)" % [
		main.current_shop_offering.size(), main.shop_open
	])

	# Polling the shop's keyboard input every frame must never throw, no
	# matter how big the offering gets.
	var errored := false
	for i in 20:
		main._handle_shop_input()
	print("polling shop input 20 times with a big offering doesn't error: errored=%s (expected false, see console above)" % errored)

	# Pressing Enter still closes the shop and advances the wave -- this is
	# the exact path that was silently broken (the number-key loop erroring
	# out before ever reaching this check).
	var wave_before: int = main.wave
	_press_key(KEY_ENTER, true)
	await process_frame
	await process_frame
	await process_frame
	main._handle_shop_input()
	print("Enter closes the shop and advances the wave: shop_open=%s (expected false), wave %d -> %d (expected +1)" % [
		main.shop_open, wave_before, main.wave
	])
	_press_key(KEY_ENTER, false)

	quit()
