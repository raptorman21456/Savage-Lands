extends SceneTree

# Not a test: screenshots of the Party tab's Dismiss, Bench and Add member controls into ui_screenshots/party_bench/ (for checking the look).
# Needs a real window (it skips itself headless). Named test_* so SaveData uses scratch saves and never touches your real ones.
#
#   Godot --path . --resolution 1152x648 --script res://tools/test_party_bench_shots.gd

var out_dir := ""
var count := 0

func _shot(label: String, frames: int = 8) -> void:
	for i in frames:
		await process_frame
	count += 1
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s%02d_%s.png" % [out_dir, count, label])
	print("shot %02d %s" % [count, label])

func _init() -> void:
	if DisplayServer.get_name() == "headless":
		print("test_party_bench_shots: needs a window, skipped (run it without --headless)")
		quit()
		return
	seed(20261108)
	out_dir = ProjectSettings.globalize_path("res://ui_screenshots/party_bench/")
	DirAccess.make_dir_recursive_absolute(out_dir)
	for f in DirAccess.get_files_at(out_dir):
		if f.ends_with(".png"):
			DirAccess.remove_absolute(out_dir + f)
	load("res://scripts/SaveData.gd").mark_tutorial_completed()
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)
	player.level = 6
	player.max_party_slots = 5
	player.meta_battle_hardened = true
	main.settings.debug_menu_enabled = true
	var knight = player.recruit("knight")
	player.recruit("druid")
	player.recruit("wolf")
	var guardian = player.recruit("guardian")
	knight.level = 4
	var panel = main.inventory_panel
	panel.party_selected_id = knight.id
	panel.open(player)
	panel._select_tab("Party")
	await _shot("member_page")

	player.send_to_bench(guardian.id)
	panel._refresh()
	await _shot("one_on_the_bench")
	panel.party_screen._open_bench()
	await _shot("bench_popup")
	panel.close_popup()
	panel.party_screen._open_add()
	await _shot("add_member_popup")
	panel.close_popup()
	panel.party_selected_id = knight.id
	player.meta_battle_hardened = false
	panel._refresh()
	await _shot("locked_before_friends_in_high_places")
	panel.close()
	quit()
