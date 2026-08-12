extends SceneTree

func _init() -> void:
	var save_data_script = load("res://scripts/SaveData.gd")

	# Clean slate for slots 1-3 + settings before starting. Slots 4/9 are
	# throwaway "never played" slots used below -- deleted outright (not just
	# blanked) in case a previous run of this test left them behind.
	for n in [1, 2, 3]:
		save_data_script.active_slot = n
		save_data_script.save_data({"essence": 0, "upgrades": {}, "best_wave": 0})
	for n in [4, 9]:
		DirAccess.remove_absolute(save_data_script._resolve_save_path(n))
	save_data_script.save_settings({})
	save_data_script.active_slot = 1

	# --- A never-played slot (9 -- never touched by any other test's
	# default 1/2/3 usage) reports as empty. ---
	print("a never-played slot reports as not existing: %s (expected false)" % [save_data_script.slot_exists(9)])
	print("slot_summary on an empty slot is an empty dict: %s (expected true)" % [save_data_script.slot_summary(9).is_empty()])

	# --- init_slot creates the slot file and locks in its difficulty. ---
	save_data_script.init_slot(9, "hard")
	print("init_slot creates the slot: exists=%s (expected true)" % [save_data_script.slot_exists(9)])
	var summary9: Dictionary = save_data_script.slot_summary(9)
	print("slot_summary reflects a freshly initialized slot: essence=%d best_wave=%d difficulty_id=%s difficulty_name=%s (expected 0, 0, hard, Hard Mode)" % [
		summary9.essence, summary9.best_wave, summary9.difficulty_id, summary9.difficulty_name
	])
	print("an unnamed slot falls back to 'Slot N': name=%s (expected Slot 9)" % [summary9.name])

	# --- Naming: an explicit name sticks; blank falls back to "Slot N" the
	# same as omitting it entirely. Whitespace-trimming is a UI-level concern
	# (TitleScreen.gd calls strip_edges() before handing a name down here),
	# not this layer's job -- tested separately below via the real UI flow. ---
	save_data_script.init_slot(9, "hard", "Barbarian Run")
	print("init_slot with a name stores it: name=%s (expected Barbarian Run)" % [save_data_script.slot_summary(9).name])
	save_data_script.init_slot(9, "hard", "")
	print("init_slot with a blank name falls back to 'Slot N': name=%s (expected Slot 9)" % [save_data_script.slot_summary(9).name])

	# --- rename_slot updates only the name -- everything else survives
	# untouched, and it's a no-op on a slot that's never been played. ---
	save_data_script.init_slot(9, "hard", "Original Name")
	save_data_script.active_slot = 9
	var data9: Dictionary = save_data_script.load_data()
	data9.essence = 42
	save_data_script.save_data(data9)
	save_data_script.rename_slot(9, "Renamed Save")
	var renamed_summary: Dictionary = save_data_script.slot_summary(9)
	print("rename_slot changes the name: name=%s (expected Renamed Save)" % [renamed_summary.name])
	print("...without touching the rest of the save: essence=%d difficulty_id=%s (expected 42, hard)" % [renamed_summary.essence, renamed_summary.difficulty_id])
	save_data_script.rename_slot(9, "")
	print("rename_slot with a blank name falls back to 'Slot N': name=%s (expected Slot 9)" % [save_data_script.slot_summary(9).name])
	save_data_script.active_slot = 1

	DirAccess.remove_absolute(save_data_script._resolve_save_path(9))
	save_data_script.rename_slot(9, "Ghost")
	print("rename_slot on a never-played slot is a no-op: exists=%s (expected false)" % [save_data_script.slot_exists(9)])

	# --- delete_slot (the data layer behind "Clear") wipes the slot entirely. ---
	save_data_script.init_slot(9, "hard", "About To Be Cleared")
	save_data_script.delete_slot(9)
	print("delete_slot removes the save entirely: exists=%s (expected false)" % [save_data_script.slot_exists(9)])

	# --- copy_slot (the data layer behind "Copy"): duplicates everything,
	# appends " (Copy)" to the name, and is a no-op with nothing meaningful
	# to copy in either degenerate case. ---
	save_data_script.init_slot(9, "hard", "Source Save")
	save_data_script.active_slot = 9
	var source_data: Dictionary = save_data_script.load_data()
	source_data.essence = 77
	source_data.best_wave = 5
	save_data_script.save_data(source_data)
	save_data_script.active_slot = 1

	DirAccess.remove_absolute(save_data_script._resolve_save_path(4))
	save_data_script.copy_slot(9, 4)
	var copied_summary: Dictionary = save_data_script.slot_summary(4)
	print("copy_slot duplicates essence/best_wave/difficulty: essence=%d best_wave=%d difficulty_id=%s (expected 77, 5, hard)" % [
		copied_summary.essence, copied_summary.best_wave, copied_summary.difficulty_id
	])
	print("...and appends ' (Copy)' to the name so the two saves aren't indistinguishable: name=%s (expected 'Source Save (Copy)')" % [copied_summary.name])

	DirAccess.remove_absolute(save_data_script._resolve_save_path(4))
	save_data_script.copy_slot(4, 9)
	print("copy_slot from a never-played source is a no-op: exists=%s (expected false)" % [save_data_script.slot_exists(4)])
	save_data_script.copy_slot(9, 9)
	print("copy_slot with the same source and destination is a no-op -- no ' (Copy)' suffix added to itself: name=%s (expected 'Source Save')" % [save_data_script.slot_summary(9).name])

	DirAccess.remove_absolute(save_data_script._resolve_save_path(9))

	# --- Slot independence: a purchase in slot 1 never touches slot 2. ---
	save_data_script.active_slot = 1
	var data1: Dictionary = save_data_script.load_data()
	data1.essence = 999
	save_data_script.try_buy_upgrade(data1, "strength")
	save_data_script.save_data(data1)

	save_data_script.active_slot = 2
	var data2: Dictionary = save_data_script.load_data()
	print("slot 2 is untouched by slot 1's purchase: essence=%d upgrades=%s (expected 0, {})" % [data2.essence, data2.upgrades])

	save_data_script.active_slot = 1
	var reloaded1: Dictionary = save_data_script.load_data()
	print("slot 1 kept its own purchase: essence_less_than_999=%s strength_level=%d (expected true, 1)" % [reloaded1.essence < 999, reloaded1.upgrades.get("strength", 0)])

	# --- Difficulty lock-in + enemy-scaling/essence-scaling readback, once
	# per difficulty multiplier, all on slot 1. ---
	var main_scene = load("res://Main.tscn")
	var orc_script = load("res://scripts/Orc.gd")
	for entry in save_data_script.DIFFICULTIES:
		save_data_script.init_slot(1, entry.id)
		save_data_script.active_slot = 1

		var main = main_scene.instantiate()
		root.add_child(main)
		await physics_frame
		await physics_frame
		var player = main.player
		print("%s: player.difficulty_mult=%.2f (expected %.2f)" % [entry.name, player.difficulty_mult, entry.mult])

		var orc = orc_script.new()
		main.add_child(orc)
		main._setup_battle_grid([orc])
		var expected_hp: int = max(1, int(round(orc.MAX_HEALTH * entry.mult)))
		var expected_dmg: int = max(1, int(round(orc.get_contact_damage() * entry.mult)))
		print("%s: scaled orc hp=%d (expected %d), dmg=%d (expected %d)" % [
			entry.name, main.battle_units[0].hp, expected_hp, main.battle_units[0].damage, expected_dmg
		])

		main.wave = 3
		var earned: int = save_data_script.record_run_result(main.wave - 1)
		var expected_earned: int = int(round((main.wave - 1) * save_data_script.ESSENCE_PER_WAVE_CLEARED * entry.mult))
		print("%s: essence earned for %d waves cleared = %d (expected %d)" % [entry.name, main.wave - 1, earned, expected_earned])

		main.queue_free()
		await physics_frame

	# --- Settings persist independently of active_slot. ---
	save_data_script.save_settings({"master_volume": 0.42})
	save_data_script.active_slot = 2
	print("switching active_slot doesn't touch settings: master_volume=%.2f (expected 0.42)" % [save_data_script.load_settings().get("master_volume", -1.0)])
	save_data_script.active_slot = 3
	print("...nor does switching to a third slot: master_volume=%.2f (expected 0.42)" % [save_data_script.load_settings().get("master_volume", -1.0)])

	# --- TitleScreen's Select Save screen renders each slot's real state. ---
	save_data_script.active_slot = 1
	var title_scene = load("res://TitleScreen.tscn")
	var title = title_scene.instantiate()
	root.add_child(title)
	await process_frame
	await process_frame
	print("Select Save is the first screen shown: select_save_visible=%s main_menu_visible=%s (expected true, false)" % [
		title.select_save_box.visible, title.main_menu_box.visible
	])
	print("a filled slot's button reflects its summary: %s (expected true, contains 'Apocalyptic')" % [
		title.slot_buttons[1].text.contains("Apocalyptic")
	])

	# Slot 4 has never had save_data()/init_slot() called for it anywhere in
	# this test, so it's genuinely empty -- picking it detours through the
	# difficulty picker instead of going straight to the main menu.
	print("slot 4 has never been played: %s (expected false)" % [save_data_script.slot_exists(4)])
	title._on_slot_pressed(4)
	print("picking an empty slot shows the difficulty picker: difficulty_visible=%s select_save_visible=%s (expected true, false)" % [
		title.difficulty_box.visible, title.select_save_box.visible
	])
	title._on_difficulty_pressed("baby")
	print("confirming a difficulty locks in the slot and reaches the main menu: active_slot=%d (expected 4), main_menu_visible=%s (expected true)" % [
		save_data_script.active_slot, title.main_menu_box.visible
	])
	var slot4_summary: Dictionary = save_data_script.slot_summary(4)
	print("the newly created slot 4 locked in Baby Mode: difficulty_id=%s (expected baby)" % [slot4_summary.difficulty_id])

	title._on_switch_save_pressed()
	print("Switch Save returns to Select Save: select_save_visible=%s (expected true)" % [title.select_save_box.visible])

	print("A played slot's '...' options button is visible: %s (expected true)" % [title.options_buttons[1].visible])

	# --- Overflow menu (slot 1): opens the Rename/Copy/Clear/Back screen,
	# hiding Select Save, and wires its Rename button through to the same
	# handler the row button used to call directly. ---
	title._on_slot_options_pressed(1)
	print("Opening the '...' menu shows slot_options_box and hides Select Save: options_visible=%s select_save_visible=%s target=%d (expected true, false, 1)" % [
		title.slot_options_box.visible, title.select_save_box.visible, title.slot_options_target
	])
	title.slot_options_rename_button.pressed.emit()
	print("...and its Rename button routes into the same slot_action_box rename flow: visible=%s target=%d (expected true, 1)" % [
		title.slot_action_box.visible, title.slot_action_target
	])
	title._on_slot_action_cancel_pressed()

	# --- Rename UI flow (slot 2): pre-fills the current name, Confirm strips
	# whitespace before handing off to SaveData.gd, and returns to Select Save. ---
	title._on_rename_slot_pressed(2)
	print("Rename shows the confirm screen pre-filled with the slot's current name: visible=%s prefilled=%s (expected true, Slot 2)" % [
		title.slot_action_box.visible, title.slot_action_name_edit.text
	])
	print("...with the name field shown and the delete warning hidden: name_edit=%s warning=%s (expected true, false)" % [
		title.slot_action_name_edit.visible, title.slot_action_warning.visible
	])
	title.slot_action_name_edit.text = "  My Barbarian  "
	title._on_slot_action_confirm_pressed()
	print("Confirming Rename strips whitespace and updates the save: name=%s (expected 'My Barbarian'), back on Select Save=%s (expected true)" % [
		save_data_script.slot_summary(2).name, title.select_save_box.visible
	])
	print("...and the slot button now shows the new name: button_text=%s" % [title.slot_buttons[2].text])

	# --- Clear UI flow (slot 3): Cancel changes nothing, Confirm deletes for real. ---
	title._on_clear_slot_pressed(3)
	print("Clear shows the delete warning instead of the name field: warning_visible=%s name_edit_visible=%s (expected true, false)" % [
		title.slot_action_warning.visible, title.slot_action_name_edit.visible
	])
	title._on_slot_action_cancel_pressed()
	print("Cancelling Clear leaves the save untouched: exists=%s (expected true)" % [save_data_script.slot_exists(3)])
	title._on_clear_slot_pressed(3)
	title._on_slot_action_confirm_pressed()
	print("Confirming Clear deletes the save for real: exists=%s (expected false)" % [save_data_script.slot_exists(3)])
	print("...and its '...' options button hides again now that it's empty: %s (expected false)" % [title.options_buttons[3].visible])

	# --- Copy UI flow. At this point: slot 1 = Apocalyptic Mode (unnamed, so
	# "Slot 1"), slot 2 = "My Barbarian", slot 3 = empty (just cleared above). ---
	title._on_copy_slot_pressed(1)
	print("Copy shows the destination picker naming the source: visible=%s header=%s (expected true, 'Copy Slot 1 to...')" % [
		title.copy_target_box.visible, title.copy_target_header.text
	])
	print("...listing the other 2 slots as destinations -- the occupied one named, the empty one marked [Empty]: dest0_named=%s dest1_empty=%s (expected true, true)" % [
		title.copy_target_buttons[0].text.contains("My Barbarian"), title.copy_target_buttons[1].text.contains("[Empty]")
	])

	# Destination slot 3 is empty -- copying into it needs no confirmation.
	title._on_copy_target_pressed(3)
	var copied_into_3: Dictionary = save_data_script.slot_summary(3)
	print("Copying into an empty slot happens immediately, no confirm screen: back_on_select_save=%s (expected true)" % [title.select_save_box.visible])
	print("...and duplicates the source, with ' (Copy)' appended to its (fallback) name: name=%s difficulty_id=%s (expected 'Slot 1 (Copy)', apocalyptic)" % [
		copied_into_3.name, copied_into_3.difficulty_id
	])

	# Now slot 3 is occupied -- copying slot 2 into it needs confirmation.
	title._on_copy_slot_pressed(2)
	title._on_copy_target_pressed(3)
	print("Copying into an occupied slot detours through the overwrite confirm instead: slot_action_visible=%s mode=%s (expected true, copy)" % [
		title.slot_action_box.visible, title.slot_action_mode
	])
	print("...naming both the source and the slot about to be overwritten: names_both=%s (expected true, header=%s)" % [
		title.slot_action_header.text.contains("My Barbarian") and title.slot_action_header.text.contains("Slot 1 (Copy)"), title.slot_action_header.text
	])
	print("...showing the overwrite warning, not the name field: warning=%s name_edit=%s confirm_text=%s (expected true, false, Overwrite)" % [
		title.slot_action_warning.visible, title.slot_action_name_edit.visible, title.slot_action_confirm_button.text
	])

	title._on_slot_action_cancel_pressed()
	print("Cancelling the overwrite leaves slot 3 untouched: name=%s (expected still 'Slot 1 (Copy)')" % [save_data_script.slot_summary(3).name])

	title._on_copy_slot_pressed(2)
	title._on_copy_target_pressed(3)
	title._on_slot_action_confirm_pressed()
	var final_slot3: Dictionary = save_data_script.slot_summary(3)
	print("Confirming the overwrite performs the copy for real: name=%s (expected 'My Barbarian (Copy)'), back on Select Save=%s (expected true)" % [
		final_slot3.name, title.select_save_box.visible
	])

	title.queue_free()
	await process_frame

	# Cleanup: reset slots 1-3 (used throughout the wider suite) to a blank
	# baseline, and fully DELETE the two throwaway slots (4, 9) rather than
	# just blanking them -- slot_exists(4)/slot_exists(9) need to read false
	# again the next time this test runs, or the "never-played slot" and
	# "picking an empty slot" checks above would silently stop testing what
	# they claim to.
	for n in [1, 2, 3]:
		save_data_script.active_slot = n
		save_data_script.save_data({"essence": 0, "upgrades": {}, "best_wave": 0})
	for n in [4, 9]:
		DirAccess.remove_absolute(save_data_script._resolve_save_path(n))
	save_data_script.save_settings({})
	save_data_script.active_slot = 1

	quit()
