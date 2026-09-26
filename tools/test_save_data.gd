extends SceneTree

func _init() -> void:
	var save_data_script = load("res://scripts/SaveData.gd")

	# Start from a clean slate -- every test_*.gd run shares the same
	# test-only scratch save file (see SaveData._resolve_save_path).
	save_data_script.save_data({"essence": 0, "upgrades": {}, "best_wave": 0})

	var data: Dictionary = save_data_script.load_data()
	print("fresh save starts empty: essence=%d (expected 0), upgrades=%s (expected {})" % [data.essence, data.upgrades])

	# "strength" (a branch-root node with no prereq) stands in for the old
	# blanket "any upgrade" test target -- "vigor" now sits behind strength
	# -> agility in the Warrior branch (see SaveData.gd:SKILL_TREE_BRANCHES),
	# so buying it directly here would be silently rejected by the new
	# prereq check in try_buy_upgrade.
	var cost_lvl0: int = save_data_script.get_upgrade_cost("strength", 0)
	var cost_lvl1: int = save_data_script.get_upgrade_cost("strength", 1)
	print("upgrade cost rises with level owned: lvl0=%d lvl1=%d (expected %d, %d)" % [
		cost_lvl0, cost_lvl1, save_data_script.UPGRADES.strength.base_cost, save_data_script.UPGRADES.strength.base_cost + save_data_script.UPGRADES.strength.cost_step
	])

	data.essence = 10
	var bought_too_poor: bool = save_data_script.try_buy_upgrade(data, "strength")
	print("can't buy an upgrade without enough essence: bought=%s essence_unchanged=%s (expected false, true)" % [
		bought_too_poor, data.essence == 10
	])

	data.essence = 100
	var bought: bool = save_data_script.try_buy_upgrade(data, "strength")
	print("buying an upgrade spends essence and levels it up: bought=%s essence_left=%d (expected %d) level=%d (expected 1)" % [
		bought, data.essence, 100 - cost_lvl0, data.upgrades.strength
	])

	save_data_script.save_data(data)
	var reloaded: Dictionary = save_data_script.load_data()
	print("save/load round-trips correctly: essence=%d (expected %d) strength_level=%d (expected 1)" % [
		reloaded.essence, 100 - cost_lvl0, reloaded.upgrades.get("strength", 0)
	])

	var bonuses: Dictionary = save_data_script.get_applied_bonuses()
	print("applied bonuses reflect owned upgrade levels: strength_bonus=%d (expected %d), coins_bonus=%d (expected 0)" % [
		bonuses.strength, save_data_script.UPGRADES.strength.stat_bonus, bonuses.coins
	])

	# --- A fresh run's Player picks up the permanent bonus. ---
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	print("a new run's player starts with the permanent strength bonus applied: stat_strength=%d (expected 1+%d=%d), attack_damage=%d (expected same)" % [
		player.stat_strength, bonuses.strength, 1 + bonuses.strength, player.attack_damage
	])

	# --- Permadeath: dying computes essence for the waves cleared (shown on
	# the game-over screen for the player's benefit) but then wipes the
	# whole slot instead of banking it -- there is no save left to bank it
	# to. Shows the game-over panel instead of the old bare "press R"
	# message. ---
	main.wave = 4
	var expected_earned: int = (main.wave - 1) * save_data_script.ESSENCE_PER_WAVE_CLEARED
	player.health = 1
	player.take_battle_damage(1)
	print("dying shows the game-over panel: game_over=%s panel_visible=%s (expected true, true)" % [
		main.game_over, main.hud.game_over_panel.visible
	])
	# The essence-earned line now lives in the stats recap box (Run-end stats
	# screen feature) rather than game_over_label itself -- see HUD.gd:
	# _populate_game_over_stats.
	var reports_earned := false
	for row in main.hud.game_over_stats_box.get_children():
		if row.text.contains("earned %d Essence" % expected_earned):
			reports_earned = true
	print("the game-over screen reports what this run would have earned: %s (expected true, contains 'earned %d Essence')" % [
		reports_earned, expected_earned
	])
	print("permadeath wipes the whole slot -- essence, upgrades, everything: slot_exists=%s (expected false)" % [
		save_data_script.slot_exists(save_data_script.active_slot)
	])

	# --- The title screen's Upgrades panel buys and persists an upgrade. ---
	save_data_script.save_data({"essence": 50, "upgrades": {}, "best_wave": 0})
	var title_scene = load("res://TitleScreen.tscn")
	var title = title_scene.instantiate()
	root.add_child(title)
	await process_frame
	await process_frame
	title._on_upgrades_pressed()
	var cost: int = save_data_script.get_upgrade_cost("strength", 0)
	title._on_buy_upgrade_pressed("strength")
	print("title screen upgrades panel buys an upgrade: essence_left=%d (expected %d), button_text=%s" % [
		title.save_data.essence, 50 - cost, title.upgrade_buttons["strength"].text
	])
	var reloaded2: Dictionary = save_data_script.load_data()
	print("the purchase persists to disk: strength_level=%d (expected 1)" % [reloaded2.upgrades.get("strength", 0)])

	# Reset the scratch save so later tests in a full-suite run always see a
	# clean slate, regardless of run order.
	save_data_script.save_data({"essence": 0, "upgrades": {}, "best_wave": 0})

	quit()
