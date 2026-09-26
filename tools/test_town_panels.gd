extends SceneTree

# Main.gd's town_panels registry: one guard for every walk-in panel, Escape
# closes whichever is open, and while one is up neither C (pause menu) nor I
# (Inventory) may act -- C used to unpause the world under a still-showing
# panel and I stacked the Inventory on top of it.

func _press_key(keycode: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)

func _tap(keycode: int) -> void:
	_press_key(keycode, true)
	for i in 4:
		await process_frame
	_press_key(keycode, false)
	await process_frame

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var player = main.player
	print("the older four panels are registered: %s (expected true)" % [
		["beastiary", "healer", "tavern", "quest_board"].all(func(k): return main.town_panels.has(k))
	])
	print("nothing is open at the start: %s (expected false)" % [main._any_town_panel_open()])

	# Escape closes an open panel and restores the un-paused state.
	main._try_open_healer()
	print("opening a panel pauses the game: open=%s (expected true), paused=%s (expected true)" % [main._any_town_panel_open(), paused])
	await _tap(KEY_ESCAPE)
	print("Escape closes it and unpauses: open=%s (expected false), paused=%s (expected false)" % [main._any_town_panel_open(), paused])

	# C must not toggle the pause menu (and so must not unpause) under a panel.
	main._try_open_tavern()
	await _tap(KEY_C)
	print("C does nothing under an open panel: menu_open=%s (expected false), paused=%s (expected true), still_open=%s (expected true)" % [
		main.menu_open, paused, main.tavern_panel.visible
	])
	# ...and I doesn't stack the Inventory on top of it.
	await _tap(KEY_I)
	print("I doesn't open the Inventory over a panel: inventory_visible=%s (expected false)" % [main.inventory_panel.visible])
	main.tavern_panel.close()
	print("closing restores the world: paused=%s (expected false)" % [paused])
	await process_frame

	# ...but both work again once the panel is gone.
	await _tap(KEY_I)
	print("I opens the Inventory again with no panel up: %s (expected true)" % [main.inventory_panel.visible])
	await _tap(KEY_I)

	# A second walk-in while a panel is already up (two door triggers
	# overlapping) must not re-snapshot the paused state -- which would leave
	# the game stuck paused after close() -- nor stack a second panel.
	main._try_open_quest_board()
	main._try_open_quest_board()
	main._try_open_tavern()
	print("a second door can't stack on an open panel: quest_board=%s tavern=%s (expected true false)" % [main.quest_board_panel.visible, main.tavern_panel.visible])
	main.quest_board_panel.close()
	print("closing after a double walk-in still restores the un-paused state: paused=%s (expected false)" % [paused])

	# The Beastiary works through the same registry (it takes no player arg).
	main._try_open_panel("beastiary")
	print("the registry opens the Beastiary too: %s (expected true)" % [main.beastiary_panel.visible])
	await _tap(KEY_ESCAPE)
	print("...and Escape closes it: %s (expected false)" % [main.beastiary_panel.visible])

	# The shared guard: nothing opens mid-battle, and an unregistered kind is a
	# harmless no-op rather than a crash.
	main.in_battle = true
	main._try_open_panel("healer")
	print("a registry door is a no-op mid-battle: %s (expected false)" % [main.healer_panel.visible])
	main.in_battle = false
	main._try_open_panel("no_such_venue")
	print("an unregistered kind is a harmless no-op: open=%s (expected false)" % [main._any_town_panel_open()])

	quit()
