extends SceneTree

# Enemies no longer force-clear to advance the wave, and the shop no longer
# auto-opens (see Main.gd:_on_enemy_died/_advance_wave_tier and KILLS_PER_
# TIER) -- this used to guard against the pause key getting eaten by the old
# wave-clear/shop-open-delay window. That window doesn't exist anymore, so
# this now checks the replacement: a kill milestone advances the wave on its
# own, the shop stays closed the whole time, and the pause key keeps working
# normally before, during, and after.

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

	# Pause key works normally before any of this starts.
	_press_key(KEY_C, true)
	await process_frame
	await process_frame
	await process_frame
	_press_key(KEY_C, false)
	await process_frame
	print("pause works normally before any kills: menu_open=%s (expected true), paused=%s (expected true)" % [main.menu_open, paused])
	main.menu_open = false
	paused = false

	var wave_before: int = main.wave
	# Drive the kill counter straight to one tier milestone via the real
	# death path, same as every other kill in the game -- side effects
	# (coins/XP/loot) don't matter here, only that shop_open never flips.
	for i in main.KILLS_PER_TIER:
		main._on_enemy_died(0)
		if main.event_choosing:
			# A random event can fire as part of _advance_wave_tier's own
			# _maybe_trigger_event -- auto-resolve it (or dismiss it) so it
			# can't block the wave-advance this test is actually checking.
			main.event_choosing = false
			main.get_tree().paused = false

	print("a kill milestone advances the wave with no shop involved: wave %d -> %d (expected +1), shop_open=%s (expected false)" % [
		wave_before, main.wave, main.shop_open
	])

	# Pause key still works normally right after -- nothing about the
	# milestone/tier-advance path leaves a stuck pause or overlay behind.
	_press_key(KEY_C, true)
	await process_frame
	await process_frame
	await process_frame
	_press_key(KEY_C, false)
	await process_frame
	print("pause still works normally right after the milestone: menu_open=%s (expected true), paused=%s (expected true)" % [main.menu_open, paused])

	quit()
