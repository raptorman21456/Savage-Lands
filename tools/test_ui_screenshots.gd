extends SceneTree

# Not a test: takes a screenshot of every screen / menu / popup in the game into ui_screenshots/ (numbered, in the
# order a player meets them), for redesigning the UI. Needs a real window (it skips itself headless). Named test_*
# on purpose: that makes SaveData use scratch save files, so it can never touch your real saves.
#
#   Godot --path . --resolution 1280x720 --script res://tools/test_ui_screenshots.gd

const SaveDataScript := preload("res://scripts/SaveData.gd")
const SandboxScript := preload("res://scripts/Sandbox.gd")
const PartyRulesScript := preload("res://scripts/PartyRules.gd")
const WM := preload("res://scripts/WorldMap.gd")

var out_dir := ""
var count := 0
var main = null

func _shot(label: String, frames: int = 4) -> void:
	for i in frames:
		await process_frame
	count += 1
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s%02d_%s.png" % [out_dir, count, label])
	print("shot %02d %s" % [count, label])

func _init() -> void:
	if DisplayServer.get_name() == "headless":
		print("test_ui_screenshots: needs a window, skipped (run it without --headless)")
		quit()
		return
	out_dir = ProjectSettings.globalize_path("res://ui_screenshots/")
	DirAccess.make_dir_recursive_absolute(out_dir)
	for f in DirAccess.get_files_at(out_dir):
		if f.ends_with(".png"):
			DirAccess.remove_absolute(out_dir + f)
	await _title_screens()
	await _normal_run()
	await _sandbox_run()
	for n in [1, 2, 3]:
		SaveDataScript.delete_slot(n)
	print("DONE: %d screenshots in %s" % [count, out_dir])
	quit()

# ------------------------------------------------------------------------------------------ title
func _title_screens() -> void:
	for n in [1, 2, 3]:
		SaveDataScript.delete_slot(n)
	SaveDataScript.init_slot(1, "normal", "Aldric")
	SaveDataScript.init_slot(2, "hard", "Bryn the Brave")
	SaveDataScript.active_slot = 1
	var d: Dictionary = SaveDataScript.load_data()
	d["essence"] = 420
	d["best_wave"] = 17
	SaveDataScript.save_data(d)
	SaveDataScript.active_slot = 2
	d = SaveDataScript.load_data()
	d["essence"] = 95
	d["best_wave"] = 6
	SaveDataScript.save_data(d)
	SaveDataScript.active_slot = 1
	var title = load("res://TitleScreen.tscn").instantiate()
	root.add_child(title)
	await _shot("title_select_save", 55)
	title._on_slot_pressed(3)
	await _shot("title_new_save_difficulty", 55)
	title._show_select_save_screen()
	title._on_slot_options_pressed(1)
	await _shot("title_slot_options", 55)
	title._on_rename_slot_pressed(1)
	await _shot("title_slot_rename", 55)
	title._show_select_save_screen()
	title._on_slot_options_pressed(2)
	title._on_clear_slot_pressed(2)
	await _shot("title_slot_clear_confirm", 55)
	title._show_select_save_screen()
	title._on_copy_slot_pressed(1)
	await _shot("title_slot_copy_target", 55)
	title._on_copy_target_pressed(2)
	await _shot("title_slot_copy_overwrite_confirm", 55)
	title._show_select_save_screen()
	title._on_slot_pressed(1)
	await _shot("title_main_menu", 55)
	title._on_stats_pressed()
	await _shot("title_lifetime_stats", 55)
	title._on_stats_back_pressed()
	if title.beastiary_panel != null:
		title.beastiary_panel.open()
		await _shot("title_beastiary", 55)
		title.beastiary_panel.close()
	title.queue_free()
	await process_frame

# ------------------------------------------------------------------------------------------ a normal run
func _go_to(pos: Vector2) -> void:
	main.player.global_position = pos
	main.overworld_map.update_rooms(pos)
	main.overworld_map.flush()
	main.camera.reset_smoothing()
	main._track_player_region()
	main._track_player_room()
	main.hud.update_minimap(pos)

func _clear_enemies() -> void:
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.free()
	main.enemies_alive = 0

func _normal_run() -> void:
	SaveDataScript.sandbox_active = false
	SaveDataScript.active_slot = 1
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for i in 6:
		await process_frame
	var hud = main.hud
	var player = main.player
	_clear_enemies()
	await _shot("overworld_hud_start", 6)
	# a fuller HUD: coins, potions, a deep region
	player.coins = 312
	hud.update_coins(312)
	player.healing_items = 3
	hud.update_items(3)
	_go_to(WM.landmark("crater").pos + Vector2(0, 500))
	_clear_enemies()
	await _shot("overworld_hud_danger_region", 8)
	_go_to(WM.spawn_position())
	_clear_enemies()
	hud.show_message("You found a Potion!")
	await _shot("overworld_message_toast", 6)

	# pause menu and settings
	hud.show_menu()
	await _shot("pause_menu")
	hud.show_settings()
	await _shot("pause_settings")
	hud.hide_settings()
	hud.hide_menu()

	# popups
	hud.show_unlock_popup("Beastiary unlocked", "You have seen your first creature. Every enemy you meet is recorded here.")
	await _shot("popup_unlock")
	hud.hide_unlock_popup()
	hud.show_levelup_choice(5, 3, 4, 5, 6, 2, 1, 1, 1, true, true, true, 2, true)
	await _shot("levelup_choice")
	hud.hide_levelup_choice()
	hud.show_event_choice("Goblin Swarm", "A swarm of goblins pours out of the trees. Stand your ground, or slip away?", "Stand and fight", "Slip away")
	await _shot("event_choice")
	hud.hide_event_choice()
	paused = false

	# inventory, fresh character
	main.inventory_panel.open(player)
	for tab in main.inventory_panel.TABS:
		main.inventory_panel._select_tab(tab)
		await _shot("inventory_fresh_" + str(tab).to_lower())
	main.inventory_panel.close()

	# every town venue
	player.coins = 500
	var venues := {
		"healer": main.healer_panel, "tavern": main.tavern_panel, "quest_board": main.quest_board_panel,
	}
	for kind in venues:
		venues[kind].open(player)
		await _shot("town_" + kind)
		venues[kind].close()
	main.beastiary_panel.open()
	await _shot("town_beastiary")
	main.beastiary_panel.close()
	for kind in main.town_panels:
		if kind in ["sandbox", "beastiary", "healer", "tavern", "quest_board"]:
			continue
		var panel = main.town_panels[kind]
		panel.open(player)
		await _shot("town_" + kind)
		panel.close()
	paused = false
	main._open_shop("gear")
	await _shot("shop_gear", 6)
	hud.hide_shop()
	main.shop_open = false
	paused = false
	main._open_shop("enchant")
	await _shot("shop_enchant", 6)
	hud.hide_shop()
	main.shop_open = false
	paused = false

	# the first battle, with the tutorial
	_go_to(WM.spawn_position())
	_clear_enemies()
	var goblin = main._spawn_one_enemy(main.EnemyScript, player.global_position + Vector2(120, 0))
	main.trigger_battle(goblin)
	await _shot("battle_tutorial_step1_move", 8)
	main.tutorial_step = 1
	main._refresh_battle_display()
	await _shot("battle_tutorial_step2_fight")
	main.battle_menu_state = "fight"
	main._refresh_battle_display()
	await _shot("battle_tutorial_step2_fight_menu")
	main.tutorial_step = 2
	main.battle_menu_state = "main"
	main._refresh_battle_display()
	await _shot("battle_tutorial_step3_defend")
	main._on_tutorial_skip_pressed()
	main.battle_menu_state = "main"
	main._refresh_battle_display()
	await _shot("battle_menu_main")
	main._on_battle_main_action("move")
	await _shot("battle_menu_move")
	main._on_battle_move_action("cancel")
	main.battle_menu_state = "tactics"
	main._refresh_battle_display()
	await _shot("battle_menu_tactics")
	main.battle_menu_state = "main"
	main._refresh_battle_display()
	hud.show_enemy_stats("Goblin\nHP 8 / 8   Attack 2   Speed 3\nA scrappy raider. Fights in packs.")
	await _shot("battle_enemy_stats")
	hud.show_battle_confirm("Step into the water? You will drop your weapon.", "Step in", "Stay")
	await _shot("battle_confirm_prompt")
	main.battle_awaiting_water_confirm = false
	main._end_battle()
	main.in_battle = false
	paused = false
	await process_frame

	# the end screens
	var stats: Dictionary = main._run_stats_summary()
	hud.show_game_over(34, 120, stats)
	await _shot("game_over")
	main.game_over = false
	hud.show_victory(150, 270, stats)
	await _shot("victory")
	paused = false
	main.queue_free()
	await process_frame
	await process_frame

# ------------------------------------------------------------------------------------------ sandbox: rich build
func _sandbox_run() -> void:
	SaveDataScript.sandbox_active = true
	SaveDataScript.sandbox_data = {}
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	for i in 6:
		await process_frame
	var hud = main.hud
	var panel = main.sandbox_panel
	if panel != null and panel.tabs != null:
		for i in panel.tabs.get_tab_count():
			panel.tabs.current_tab = i
			await _shot("sandbox_tab_" + str(panel.tabs.get_tab_title(i)).to_lower().replace(" ", "_"))
	# build a rich character with a squad
	var cfg: Dictionary = SandboxScript.default_config()
	cfg.level = 14
	cfg.coins = 480
	var bow_base := ""
	for b in SandboxScript.weapon_bases():
		if str(b.id).contains("bow") and not str(b.id).contains("cross"):
			bow_base = str(b.id)
			break
	if bow_base != "":
		cfg.weapon = {"base": bow_base, "tier": "Fine", "material": "steel"}
	cfg.arrows = {"flame": 4, "freeze": 3, "bomb": 2}
	cfg.talismans = ["ember_charm", "wolf_fang", "berserkers_knot", "stone_amulet"]
	cfg.armor = "armor_thornmail"
	cfg.shield = "buckler"
	cfg.consumables = [{"id": "potion_health", "n": 3}]
	var kinds: Array = PartyRulesScript.KINDS.keys()
	cfg.party = []
	for k in kinds.slice(0, 3):
		cfg.party.append({"kind": str(k), "level": 6})
	cfg.enemies = [{"name": "Goblin", "elite": false, "power_tier": 1.0}, {"name": "Orc", "elite": false, "power_tier": 1.0}, {"name": "Goblin", "elite": true, "power_tier": 1.0}]
	SandboxScript.apply_build(main, cfg)
	if panel != null:
		panel.visible = false          # the sandbox panel refuses close(): hide it
	paused = false
	var player = main.player
	hud.update_health(player.health, player.max_health)
	hud.update_level(player.level)
	hud.update_coins(player.coins)
	hud.update_items(player.healing_items)
	hud.update_quiver(true, player.owned_arrows)
	await _shot("overworld_hud_rich_build", 8)

	main._open_shop("gear")
	await _shot("shop_gear_with_bow_and_arrows", 6)
	hud.hide_shop()
	main.shop_open = false
	paused = false
	main.inventory_panel.open(player)
	for tab in main.inventory_panel.TABS:
		main.inventory_panel._select_tab(tab)
		await _shot("inventory_rich_" + str(tab).to_lower())
	main.inventory_panel.close()

	# a real battle with the squad
	var squad: Array = SandboxScript.build_squad(main, cfg)
	main.start_sandbox_battle(squad, SandboxScript.world_index(main, "plains"))
	await _shot("battle_party_ally_turn_menu", 10)
	# skip the allies until it is the hero's own turn
	var guard := 0
	while main.battle_commanding_ally != null and guard < 8:
		main._on_battle_ally_action("skip")
		for i in 4:
			await process_frame
		guard += 1
	main.battle_menu_state = "main"
	main._focus_battle_main_menu()
	main._refresh_battle_display()
	await _shot("battle_party_hero_menu_main")
	main.battle_menu_state = "fight"
	main._refresh_battle_display()
	await _shot("battle_party_hero_fight_menu")
	main.battle_menu_state = "arrow"
	main._refresh_battle_display()
	await _shot("battle_party_hero_arrow_menu")
	main.battle_menu_state = "tactics"
	main._refresh_battle_display()
	await _shot("battle_party_hero_tactics_menu")
	main.battle_menu_state = "main"
	main._on_battle_main_action("move")
	await _shot("battle_party_hero_move_mode")
	main._on_battle_move_action("cancel")
	main.battle_menu_state = "ally_pick"
	main._refresh_battle_display()
	await _shot("battle_ally_pick")
	main.battle_menu_state = "ally_special"
	main._refresh_battle_display()
	await _shot("battle_ally_special")
	main.battle_menu_state = "main"
	main._refresh_battle_display()
	main.battle_awaiting_evasion = true
	main.battle_evasion_options = {"Back": Vector2i(0, 1), "Left": Vector2i(-1, 0), "Right": Vector2i(1, 0)}
	main._refresh_battle_display()
	await _shot("battle_dodge_roll_choice")
	main.battle_awaiting_evasion = false
	main.battle_evasion_options = {}
	main._refresh_battle_display()

	# the dodge / block / attack timing popups, mid-run
	var patterns = load("res://scripts/AttackPatterns.gd")
	var pattern: Dictionary = patterns.pick("Goblin", {}, "melee")
	main._get_defense_minigame().run("dodge", pattern, {})
	await create_timer(0.5, true).timeout
	await _shot("minigame_dodge", 2)
	main._get_defense_minigame()._running = false
	main._get_defense_minigame().visible = false
	main._get_defense_minigame().run("block", pattern, {})
	await create_timer(0.5, true).timeout
	await _shot("minigame_block", 2)
	main._get_defense_minigame()._running = false
	main._get_defense_minigame().visible = false
	var timings = load("res://scripts/AttackTimings.gd")
	main._get_attack_minigame().run(timings.command_for_weapon(player.current_weapon))
	await create_timer(0.5, true).timeout
	await _shot("minigame_attack_timing", 2)
	main._get_attack_minigame()._running = false
	main._get_attack_minigame().visible = false

	# a levelling-up moment inside battle, then the sandbox result screen
	hud.show_levelup_choice(15, 6, 7, 8, 9, 5, 4, 3, 2, true, true, true, 3, true)
	await _shot("battle_levelup_choice")
	hud.hide_levelup_choice()
	main.sandbox_result = "victory"
	main._end_battle()
	main.in_battle = false
	paused = false
	await process_frame
	if main.sandbox_panel != null:
		main.sandbox_panel.open(player)
		await _shot("sandbox_panel_after_battle")
	main.queue_free()
	await process_frame
	SaveDataScript.sandbox_active = false
