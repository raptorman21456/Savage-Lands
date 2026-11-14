extends SceneTree

# Not a test: screenshots of the Debug menu's Console tab (Console and Inspector pages) and the Battle / World tabs' new controls into
# ui_screenshots/debug_console/ (for checking the look). Needs a real window (it skips itself headless). Named test_* so SaveData uses
# scratch saves and never touches your real ones.
#
#   Godot --path . --resolution 1152x648 --script res://tools/test_debug_console_shots.gd

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
		print("test_debug_console_shots: needs a window, skipped (run it without --headless)")
		quit()
		return
	seed(20261109)
	out_dir = ProjectSettings.globalize_path("res://ui_screenshots/debug_console/")
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
	main.ambient_spawn_timer = 1.0e9
	var settings = root.get_node("Settings")
	settings.debug_menu_enabled = true
	player.level = 6
	player.max_party_slots = 6
	var menu = main.debug_menu
	menu.open()
	await process_frame
	menu._select_tab("Console")
	await process_frame
	var view = menu.view
	for line in ["player.coins = 5000", "props player coin", "units", "A.set_level(main, 12)", "player.nope = 1"]:
		view._submit(line)
	await _shot("console_page")
	menu.open_inspector("player")
	await process_frame
	menu.view.ins["search"] = "coin"
	menu.view.refresh()
	await _shot("inspector_you_search_coin")
	menu.open_inspector("main")
	await process_frame
	menu.view.ins["search"] = "battle_"
	menu.view.refresh()
	await _shot("inspector_game_search_battle")
	menu.close()

	var DB = load("res://scripts/DebugBattle.gd")
	DB.start_battle(main, [{"name": "Goblin", "count": 2}, {"name": "Orc", "count": 1}], 1, false, 1.0)
	for i in 400:
		await process_frame
		if main.battle_turn == "player" and not main.battle_timeline_running:
			break
	DB.add_ally(main, "knight")
	DB.add_ally(main, "druid")
	menu.open()
	await process_frame
	menu._select_tab("Battle")
	await _shot("battle_tab_top")
	var scroll = _first_scroll(menu.view, 1)
	if scroll != null:
		scroll.scroll_vertical = 520
	await _shot("battle_tab_middle")
	if scroll != null:
		scroll.scroll_vertical = 1100
	await _shot("battle_tab_lower")
	if scroll != null:
		scroll.scroll_vertical = 100000
	await _shot("battle_tab_bottom")
	menu.open_inspector("enemy:0")
	await _shot("inspector_enemy")
	menu.close()
	DB.win_now(main)
	for i in 30:
		await process_frame
	if main.choosing_stat:
		main._on_levelup_choice_pressed("vigor")
	menu.open()
	await process_frame
	menu._select_tab("World")
	var wscroll = _first_scroll(menu.view, 0)
	if wscroll != null:
		wscroll.scroll_vertical = 100000
	await _shot("world_buildings_and_events")
	menu.close()
	quit()

# The nth ScrollContainer (in tree order) under a node.
func _first_scroll(node: Node, nth: int):
	var found: Array = []
	_collect_scrolls(node, found)
	return found[nth] if found.size() > nth else (found[0] if not found.is_empty() else null)

func _collect_scrolls(node: Node, out: Array) -> void:
	if node is ScrollContainer:
		out.append(node)
	for c in node.get_children():
		_collect_scrolls(c, out)
