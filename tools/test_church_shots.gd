extends SceneTree

# Not a test: screenshots of the Church (the Astral tree) into ui_screenshots/church/, with a sample save in the scratch slot (named test_*
# so SaveData uses scratch files and never touches your real saves). Needs a real window (it skips itself headless).
#
#   Godot --path . --resolution 1152x648 --script res://tools/test_church_shots.gd

var out_dir := ""
var count := 0

func _shot(label: String, frames: int = 40) -> void:
	for i in frames:
		await process_frame
	count += 1
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s%02d_%s.png" % [out_dir, count, label])
	print("shot %02d %s" % [count, label])

func _init() -> void:
	if DisplayServer.get_name() == "headless":
		print("test_church_shots: needs a window, skipped (run it without --headless)")
		quit()
		return
	out_dir = ProjectSettings.globalize_path("res://ui_screenshots/church/")
	DirAccess.make_dir_recursive_absolute(out_dir)
	for f in DirAccess.get_files_at(out_dir):
		if f.ends_with(".png"):
			DirAccess.remove_absolute(out_dir + f)
	var sd = load("res://scripts/SaveData.gd")
	sd.save_lifetime_data({})
	sd.save_data({"essence": 140, "best_wave": 0, "upgrades": {
		"legacy": 1, "strength": 1, "agility": 1, "vigor": 1, "reflexes_unlock": 1, "berserker_edge": 3, "adrenaline": 1,
		"coins": 1, "intimidation": 1, "luck": 1, "haggling": 2, "stamina": 3, "resilience_unlock": 1, "release_grudge": 1, "deep_well": 1,
	}})
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame
	await physics_frame
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)
	main._try_open_panel("church")
	await _shot("opens_on_the_hub")
	var panel = main.town_panels["church"]
	panel.view.center_on("rage")
	await _shot("physical_wing", 60)
	panel._on_node_hover_changed("battle_hardened")
	await _shot("a_locked_node_says_what_it_wants", 20)
	panel._on_node_hover_changed("")
	panel.view.center_on("deep_well")
	await _shot("sorcery_wing", 60)
	panel._on_node_hover_changed("innate_power")
	await _shot("innate_power_tooltip", 20)
	panel._on_node_hover_changed("")
	panel.view.center_on("aegis_transcendence")
	await _shot("cross_branch", 60)
	panel.view.center_on("otherworldly_power")
	await _shot("otherworldly_power", 60)
	sd.save_data({"essence": 0, "upgrades": {}, "best_wave": 0})
	quit()
