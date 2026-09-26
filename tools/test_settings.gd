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
	var save_data_script = load("res://scripts/SaveData.gd")
	save_data_script.save_data({"essence": 0, "upgrades": {}, "best_wave": 0})
	# Settings now live in their own file, independent of the save-data reset
	# above -- clear it too, so a rebind from a previous run of this test
	# doesn't leak into this one via the shared scratch file.
	save_data_script.save_settings({})

	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	var settings = root.get_node("Settings")
	# Settings autoloads and loads from the (possibly stale, left over from a
	# previous run of this same test) save file at engine boot, before this
	# script's own _init() -- and therefore before the save-data reset above
	# -- ever runs. Force a fresh reload now that the scratch file is
	# actually clean, or state from a prior run leaks into this one.
	settings._load()

	# --- Defaults match the keys that used to be hardcoded. ---
	print("default move_up is KEY_UP: %s (expected true)" % [settings.get_key("move_up") == KEY_UP])
	print("default confirm is KEY_Z: %s (expected true)" % [settings.get_key("confirm") == KEY_Z])
	print("default pause is KEY_C: %s (expected true)" % [settings.get_key("pause") == KEY_C])

	# --- Rebinding changes which physical key the player responds to. ---
	# Overworld movement (unlike battle-grid movement) needs a generous
	# frame margin here -- Main.tscn's own _ready() chain (decoration
	# scatter, SFX synthesis, etc.) takes several frames' worth of real time
	# to settle before injected input is actually reflected, the same
	# reason test_tree_collision.gd waits 60 frames rather than 2-3.
	main.player.global_position = Vector2(350, 250)
	_press_key(KEY_UP, true)
	for i in 15:
		await physics_frame
	var moved_with_default_key: bool = main.player.global_position.y < 250
	_press_key(KEY_UP, false)
	await physics_frame

	settings.rebind("move_up", KEY_I)
	main.player.global_position = Vector2(350, 250)
	_press_key(KEY_UP, true)
	for i in 15:
		await physics_frame
	var old_key_still_works: bool = main.player.global_position.y < 250
	_press_key(KEY_UP, false)
	await physics_frame

	main.player.global_position = Vector2(350, 250)
	_press_key(KEY_I, true)
	for i in 15:
		await physics_frame
	var new_key_works: bool = main.player.global_position.y < 250
	_press_key(KEY_I, false)
	await physics_frame

	print("before rebind, UP moves the player: %s (expected true)" % [moved_with_default_key])
	print("after rebinding move_up to I, UP no longer moves the player: %s (expected false)" % [old_key_still_works])
	print("after rebinding move_up to I, I now moves the player: %s (expected true)" % [new_key_works])

	# --- Rebind + reload round-trips through SaveData's dedicated settings
	# file (a fresh Settings-like read should see the same override). ---
	var reloaded_settings: Dictionary = save_data_script.load_settings()
	print("rebind persisted to the settings file: %s (expected KEY_I=%d)" % [reloaded_settings.keybinds.move_up, KEY_I])

	# --- Rebinding to a key another action already owns is rejected outright
	# -- confirm and cancel sharing a key would make battle-move confirmation
	# permanently self-cancelling, since both would fire on the same press. ---
	var cancel_key_before: int = settings.get_key("cancel")
	settings.rebind("confirm", cancel_key_before)
	print("rebinding confirm onto cancel's key is rejected: confirm_unchanged=%s (expected true)" % [settings.get_key("confirm") == KEY_Z])
	print("the key collision doesn't unbind the other action either: cancel_unchanged=%s (expected true)" % [settings.get_key("cancel") == cancel_key_before])

	# A key that's genuinely free is still accepted, confirming the rejection
	# above is specifically about the collision, not rebind() breaking outright.
	settings.rebind("confirm", KEY_O)
	print("rebinding to a genuinely free key still works: %s (expected true)" % [settings.get_key("confirm") == KEY_O])
	settings.rebind("confirm", KEY_Z)

	# --- Volume setters actually move the named AudioServer bus. ---
	settings.set_master_volume(0.5)
	var master_idx: int = AudioServer.get_bus_index("Master")
	var master_db: float = AudioServer.get_bus_volume_db(master_idx)
	print("master volume at 0.5 matches linear_to_db(0.5): %s (expected true, db=%.2f)" % [is_equal_approx(master_db, linear_to_db(0.5)), master_db])

	settings.set_sfx_volume(0.0)
	var sfx_idx: int = AudioServer.get_bus_index("SFX")
	var sfx_db: float = AudioServer.get_bus_volume_db(sfx_idx)
	print("sfx volume at 0.0 is clamped to a finite floor, not -inf: %s (expected true, db=%.2f)" % [is_finite(sfx_db), sfx_db])

	settings.set_music_volume(1.0)
	var music_idx: int = AudioServer.get_bus_index("Music")
	print("Music bus exists: %s (expected true)" % [music_idx >= 0])

	# --- Screen Shake / Damage Numbers toggles: persist, and actually gate
	# Main.gd's own juice functions at the source (see _shake_camera/
	# _shake_battle/spawn_damage_number_world/_spawn_battle_damage_number). ---
	print("screen_shake_enabled defaults to true: %s (expected true)" % [settings.screen_shake_enabled])
	print("damage_numbers_enabled defaults to true: %s (expected true)" % [settings.damage_numbers_enabled])

	settings.set_screen_shake_enabled(false)
	settings.set_damage_numbers_enabled(false)
	var reloaded_toggles: Dictionary = save_data_script.load_settings()
	print("both toggles persist to the settings file: shake=%s damage_numbers=%s (expected false, false)" % [
		reloaded_toggles.get("screen_shake_enabled", true), reloaded_toggles.get("damage_numbers_enabled", true)
	])

	main.camera_shake_timer = 0.0
	main._shake_camera(4.0, 0.15)
	print("disabled Screen Shake blocks _shake_camera entirely: timer=%.2f (expected 0.0)" % [main.camera_shake_timer])
	main.battle_shake_timer = 0.0
	main._shake_battle(4.0, 0.15)
	print("...and _shake_battle too: timer=%.2f (expected 0.0)" % [main.battle_shake_timer])

	var world_children_before: int = main.get_child_count()
	main.spawn_damage_number_world(main.player.global_position, 42)
	print("disabled Damage Numbers blocks spawn_damage_number_world entirely: child_count_unchanged=%s (expected true)" % [main.get_child_count() == world_children_before])
	var battle_children_before: int = main.hud.battle_panel.get_child_count()
	main._spawn_battle_damage_number(Vector2i(0, 0), 42)
	print("...and _spawn_battle_damage_number too: child_count_unchanged=%s (expected true)" % [main.hud.battle_panel.get_child_count() == battle_children_before])

	settings.set_screen_shake_enabled(true)
	settings.set_damage_numbers_enabled(true)
	main.camera_shake_timer = 0.0
	main._shake_camera(4.0, 0.15)
	print("re-enabling Screen Shake lets _shake_camera through again: timer=%.2f (expected 0.15)" % [main.camera_shake_timer])
	main.camera_shake_timer = 0.0

	# --- Pause menu -> Settings -> Back UI flow. ---
	# The pause-key check lives in Main.gd's _process(), not
	# _physics_process() -- process_frame is the matching signal to await.
	main.player.global_position = Vector2(350, 250)
	_press_key(KEY_C, true)
	for i in 5:
		await process_frame
	_press_key(KEY_C, false)
	await process_frame
	print("pause opens the menu: menu_open=%s panel_visible=%s (expected true, true)" % [main.menu_open, main.hud.menu_panel.visible])

	main.hud.menu_settings_button.pressed.emit()
	print("Settings button opens the settings panel: settings_open=%s settings_visible=%s menu_visible=%s (expected true, true, false)" % [
		main.settings_open, main.hud.settings_panel.visible, main.hud.menu_panel.visible
	])
	print("the toggle checkboxes reflect the current settings on open: shake=%s damage_numbers=%s (expected true, true)" % [
		main.hud.settings_shake_checkbox.button_pressed, main.hud.settings_damage_numbers_checkbox.button_pressed
	])

	main.hud.settings_back_button.pressed.emit()
	print("Back returns to the pause menu: settings_open=%s settings_visible=%s menu_visible=%s (expected false, false, true)" % [
		main.settings_open, main.hud.settings_panel.visible, main.hud.menu_panel.visible
	])

	main.hud.settings_pressed.emit()
	var before_c_settings_open: bool = main.settings_open
	_press_key(KEY_C, true)
	for i in 5:
		await process_frame
	_press_key(KEY_C, false)
	await process_frame
	print("pressing pause while Settings is open does nothing: was_open=%s still_open=%s still_paused=%s (expected true, true, true)" % [
		before_c_settings_open, main.settings_open, paused
	])

	paused = false
	save_data_script.save_data({"essence": 0, "upgrades": {}, "best_wave": 0})
	save_data_script.save_settings({})
	quit()
