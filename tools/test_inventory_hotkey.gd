extends SceneTree

# The Inventory panel (previously only reachable through the pause menu's
# own button) now also has a direct "I" shortcut from the overworld (see
# Main.gd:_process), toggled the same way "C" toggles the pause menu.

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

	print("inventory starts closed: visible=%s (expected false)" % [main.inventory_panel.visible])

	# Holding the key down across several frames must only open it once, not
	# flicker -- same edge-detected shape as every other key in this file
	# (prev_c_key, prev_debug_keys, ...).
	_press_key(KEY_I, true)
	for i in 5:
		await process_frame
	print("holding I open opens it exactly once, no flicker: visible=%s (expected true), paused=%s (expected true)" % [main.inventory_panel.visible, paused])
	_press_key(KEY_I, false)
	await process_frame

	# A second full press-release cycle toggles it closed again.
	_press_key(KEY_I, true)
	await process_frame
	await process_frame
	await process_frame
	print("pressing I again closes it: visible=%s (expected false), paused=%s (expected false)" % [main.inventory_panel.visible, paused])
	_press_key(KEY_I, false)
	await process_frame

	# It's suppressed while the pause menu is already open, to avoid
	# layering one CanvasLayer over the other.
	main.menu_open = true
	main.get_tree().paused = true
	main.hud.show_menu()
	_press_key(KEY_I, true)
	await process_frame
	await process_frame
	await process_frame
	print("I does nothing while the pause menu is already open: inventory_visible=%s (expected false)" % [main.inventory_panel.visible])
	_press_key(KEY_I, false)

	quit()
