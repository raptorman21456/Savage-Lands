extends SceneTree

# Not a test: takes a screenshot of every tab (and a few states) of the Debug menu into ui_screenshots/debug/, for checking the look.
# Needs a real window (it skips itself headless). Named test_* so SaveData uses scratch saves and never touches your real ones.
#
#   Godot --path . --resolution 1152x648 --script res://tools/test_debug_shots.gd

const DA := preload("res://scripts/DebugActions.gd")
const DW := preload("res://scripts/DebugWorld.gd")
const DB := preload("res://scripts/DebugBattle.gd")
const DP := preload("res://scripts/DebugProgress.gd")
const DK := preload("res://scripts/DebugKit.gd")

var out_dir := ""
var count := 0
var main = null
var menu = null

func _shot(label: String, frames: int = 8) -> void:
	for i in frames:
		await process_frame
	count += 1
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s%02d_%s.png" % [out_dir, count, label])
	print("shot %02d %s" % [count, label])

func _scroll_to(pixels: int, index: int = 0) -> void:
	var areas: Array = DK.scrolls(menu.view)
	if index < areas.size():
		areas[index].scroll_vertical = pixels
	await process_frame
	await process_frame

func _find_button(node: Node, wanted: String):
	if node is PixelButton and node.text == wanted and node.is_visible_in_tree():
		return node
	for child in node.get_children():
		var found = _find_button(child, wanted)
		if found != null:
			return found
	return null

func _init() -> void:
	if DisplayServer.get_name() == "headless":
		print("test_debug_shots: needs a window, skipped (run it without --headless)")
		quit()
		return
	seed(20261018)
	out_dir = ProjectSettings.globalize_path("res://ui_screenshots/debug/")
	DirAccess.make_dir_recursive_absolute(out_dir)
	for f in DirAccess.get_files_at(out_dir):
		if f.ends_with(".png"):
			DirAccess.remove_absolute(out_dir + f)
	await process_frame
	await process_frame
	var settings = root.get_node("Settings")
	var setting_before: bool = settings.debug_menu_enabled
	settings.debug_menu_enabled = true
	var save := FileAccess.get_file_as_string("user://test_save_data_slot_1.json") if FileAccess.file_exists("user://test_save_data_slot_1.json") else ""
	load("res://scripts/SaveData.gd").save_data({"essence": 420, "upgrades": {}, "best_wave": 3, "difficulty": "hard", "name": "Shots"})
	load("res://scripts/SaveData.gd").mark_tutorial_completed()
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	main.ambient_spawn_timer = 1.0e9
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)
	menu = main.debug_menu
	var player = main.player

	# the Settings toggle
	main.inventory_panel.open(player)
	main.inventory_panel.settings_page = "Gameplay"
	main.inventory_panel._select_tab("Settings")
	await _shot("settings_gameplay_toggle")
	main.inventory_panel.close()

	# a lived-in hero
	DA.set_level(main, 12)
	DA.set_coins(main, 840)
	DA.set_shards(main, 14)
	DA.give_weapon(main, "spear", "Masterwork", "gold", true)
	DA.give_weapon(main, "dagger", "Fine", "silver", false)
	DA.give_weapon(main, "hammer", "Legendary", "obsidian", false)
	DA.give_armor(main, "armor_gambeson", true)
	DA.give_shield(main, "shield_heavy", true)
	DA.give_talisman(main, "moss_charm", true)
	DA.give_talisman(main, "wolf_fang", false)
	DA.give_potion(main, "potion_health", 4)
	DA.give_potion(main, "food_jerky", 3)
	DA.give_arrows(main, "flame", 6)
	DA.set_god_mode(main, true)
	DA.recruit(main, "knight", true)
	DA.recruit(main, "druid", true)
	DA.recruit(main, "wolf", true)
	for m in player.party:
		if m.kind == "knight":
			DA.set_member_level(main, m.id, 6)
			DA.equip_member(main, m.id, "weapon", "greatsword_fine_steel")
			DA.equip_member(main, m.id, "armor", "armor_gambeson" if false else "armor_fortress")
			DA.equip_member(main, m.id, "talisman", "guardian_knot")

	menu.open()
	for tab in ["Player"]:
		menu._select_tab(tab)
		await _shot("player_top")
	await _scroll_to(380)
	await _shot("player_stats")
	await _scroll_to(900)
	await _shot("player_cheats")

	menu._select_tab("Items")
	menu.state.items = {"cat": "Weapons", "search": "", "sel": {"Weapons": "greatsword"}, "weapon": {"base": "greatsword", "tier": "Legendary", "material": "obsidian"}}
	menu.view.build()
	await _shot("items_weapons_builder")
	menu.state.items = {"cat": "Weapons", "search": "", "sel": {"Weapons": "spear"}, "weapon": {"base": "spear", "tier": "Mythic", "material": "steel"}}
	menu.view.build()
	await _shot("items_weapons_mythic")
	for cat in ["Armour", "Shields", "Clothes", "Talismans", "Potions", "Food", "Arrows", "Materials", "Smithing"]:
		menu.view._on_category(cat)
		await _shot("items_%s" % cat.to_lower())

	menu._select_tab("Party")
	await _shot("party_sheet")
	menu.state.party.pick = "weapon"
	menu.view.build()
	await _shot("party_weapon_picker")
	menu.state.party.pick = "talisman"
	menu.view.build()
	await _shot("party_talisman_picker")
	menu.state.party.pick = ""
	menu.view.build()

	menu._select_tab("World")
	await _shot("world_places")
	menu.state.world.cat = "Rooms"
	menu.view.build()
	await _shot("world_rooms")
	menu.state.world.cat = "Inside"
	menu.view.build()
	await _shot("world_inside")
	await _scroll_to(400, 1)
	await _shot("world_enemies")

	menu._select_tab("Battle")
	await _shot("battle_idle")
	menu.close()
	DB.start_battle(main, [{"name": "Orc", "count": 2}, {"name": "Goblin", "count": 1}], 3, false)
	for i in 900:
		if main.battle_turn == "player" and not main.battle_timeline_running:
			break
		await process_frame
	DB.set_status(main, "hero", "poison", 3)
	DB.set_status(main, "enemy:0", "burn", 2)
	DB.set_status(main, "enemy:1", "frozen", 2)
	main.battle_allies[0]["hp"] = 3 if not main.battle_allies.is_empty() else 0
	menu.open()
	menu._select_tab("Battle")
	await _shot("battle_in_progress")
	menu.confirm("End the run? You fall at once and the game-over screen follows.", func(): pass)
	await _shot("confirm_dialog")
	menu._close_confirm()
	menu.close()
	await _shot("battle_screen_behind")
	DB.win_now(main)
	await process_frame
	await process_frame

	menu.open()
	menu._select_tab("Progress")
	await _shot("progress_church")
	DP.max_all_upgrades(main)
	menu.view.build()
	await _shot("progress_church_maxed")
	await _scroll_to(2300)
	await _shot("progress_flags")
	await _scroll_to(3300)
	await _shot("progress_spells")
	DP.reset_upgrades(main)

	menu._select_tab("Game")
	await _shot("game_top")
	await _scroll_to(330)
	await _shot("game_slot")
	menu.set_overlay(true)
	DA.set_speed_mult(main, 2.0)
	menu.close()
	await _shot("overlay_in_the_corner")
	menu.set_overlay(false)

	# the keyboard ring
	menu.open()
	menu._select_tab("Player")
	await process_frame
	var heal = _find_button(menu.view, "Heal fully")
	if heal != null:
		heal.grab_focus()
	await _shot("keyboard_focus_ring")
	menu.close()

	settings.debug_menu_enabled = setting_before
	if save != "":
		var f := FileAccess.open("user://test_save_data_slot_1.json", FileAccess.WRITE)
		f.store_string(save)
		f.close()
	quit()
