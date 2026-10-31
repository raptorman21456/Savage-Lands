extends SceneTree

# Not a test: screenshots of Berserk and Rage -- the level-up screen with every stat unlocked (ten rows, Rage last), the Party sheet's
# stat page, and a battle with Berserk running and with the kill count building -- into ui_screenshots/rage/. Needs a real window (it
# skips itself headless). Named test_* so SaveData uses scratch saves and never touches your real ones.
#
#   Godot --path . --resolution 1152x648 --script res://tools/test_rage_shots.gd

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
		print("test_rage_shots: needs a window, skipped (run it without --headless)")
		quit()
		return
	seed(20261030)
	out_dir = ProjectSettings.globalize_path("res://ui_screenshots/rage/")
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
	var hud = main.hud
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)
	player.meta_resilience_unlocked = true
	player.meta_reflexes_unlocked = true
	player.meta_dexterity_unlocked = true
	player.meta_fortitude_unlocked = true
	player.meta_rage_unlocked = true
	player.stat_rage = 6
	hud.show_levelup_choice(7, 8, 9, 10, 205, 11, 3, 2, 2, true, true, true, 4, true, 6, true)
	await _shot("levelup_every_stat_unlocked", 10)
	hud.hide_levelup_choice()

	player.level = 12
	player.stat_might = 12
	var panel = main.inventory_panel
	panel.open(player)
	panel.party_selected_id = load("res://scripts/PartyScreen.gd").HERO_ID
	panel.party_page = "Stats"
	panel._select_tab("Party")
	await _shot("party_stats_with_rage", 10)
	panel.close()

	player.max_party_slots = 20
	for kind in ["knight", "druid"]:
		player.recruit(kind)
	var orc = load("res://scripts/Orc.gd").new()
	main.add_child(orc)
	orc.global_position = player.global_position + Vector2(30, 0)
	main.trigger_battle(orc)
	for i in 6:
		await process_frame
	main.battle_terrain.clear()
	main.battle_turn = "player"
	main.battle_menu_state = "main"
	player.berserk_kills = 3
	main._refresh_battle_display()
	await _shot("battle_rage_building_3_of_5", 10)
	main._on_unit_clicked("hero", 0)
	await _shot("battle_hero_details_rage_building", 8)
	main._on_unit_clicked("none", 0)
	player.berserk_kills = 0
	player.berserk_turns_remaining = 2
	main._refresh_battle_display()
	await _shot("battle_berserk_on", 10)
	main._on_unit_clicked("hero", 0)
	await _shot("battle_hero_details_berserk_with_rage", 8)
	print("DONE: %d screenshots in %s" % [count, out_dir])
	quit()
