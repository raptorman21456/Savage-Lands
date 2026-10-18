extends SceneTree

# Not a test: screenshots of every screen of the title flow into ui_screenshots/title/, with three sample saves in the scratch slots (named
# test_* so SaveData uses scratch files and never touches your real saves). Needs a real window (it skips itself headless).
#
#   Godot --path . --resolution 1152x648 --script res://tools/test_title_shots.gd

var out_dir := ""
var count := 0

func _shot(label: String, frames: int = 30) -> void:
	for i in frames:
		await process_frame
	count += 1
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s%02d_%s.png" % [out_dir, count, label])
	print("shot %02d %s" % [count, label])

func _init() -> void:
	if DisplayServer.get_name() == "headless":
		print("test_title_shots: needs a window, skipped (run it without --headless)")
		quit()
		return
	out_dir = ProjectSettings.globalize_path("res://ui_screenshots/title/")
	DirAccess.make_dir_recursive_absolute(out_dir)
	for f in DirAccess.get_files_at(out_dir):
		if f.ends_with(".png"):
			DirAccess.remove_absolute(out_dir + f)
	var sd = load("res://scripts/SaveData.gd")
	for n in [1, 2, 3]:
		sd.delete_slot(n)
	# slot 1: a long-running Hard file, slot 2: a fresh Normal one, slot 3 stays empty
	sd.init_slot(1, "hard", "The Barbarian")
	sd.active_slot = 1
	var data: Dictionary = sd.load_data()
	data.essence = 1438
	data.best_wave = 23
	data.upgrades = {"hardened": 3, "nest_egg": 2, "brawn": 4}
	sd.save_data(data)
	sd.init_slot(2, "apocalyptic", "")
	sd.active_slot = 2
	data = sd.load_data()
	data.essence = 120
	sd.save_data(data)
	sd.active_slot = 1

	await process_frame
	await process_frame
	var title = load("res://TitleScreen.tscn").instantiate()
	root.add_child(title)
	await _shot("splash", 170)
	title._leave_splash()
	await _shot("files")
	title.slot_buttons[2].grab_focus()
	await _shot("files_second_chosen")
	title.slot_buttons[3].grab_focus()
	await _shot("files_empty_chosen")
	title._on_slot_pressed(1)
	await _shot("menu")
	title.sandbox_button.grab_focus()
	await _shot("menu_sandbox_chosen")
	title._on_stats_pressed()
	await _shot("stats")
	title._on_stats_back_pressed()
	title._on_switch_save_pressed()
	title._on_slot_pressed(3)
	await _shot("difficulty")
	title.difficulty_buttons["apocalyptic"].grab_focus()
	await _shot("difficulty_apocalyptic_chosen")
	title.new_save_name_edit.text = "Conan"
	title._on_difficulty_back_pressed()
	title._on_slot_options_pressed(1)
	await _shot("file_options")
	title._on_rename_slot_pressed(1)
	await _shot("rename")
	title._on_slot_action_cancel_pressed()
	title._on_clear_slot_pressed(2)
	await _shot("clear")
	title._on_slot_action_cancel_pressed()
	title._on_copy_slot_pressed(1)
	await _shot("copy_to")
	print("DONE: %d screenshots in %s" % [count, out_dir])
	quit()
