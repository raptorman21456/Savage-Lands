extends SceneTree

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var save_data_script = load("res://scripts/SaveData.gd")

	# Start from a clean slate -- every test_*.gd run shares the same
	# test-only scratch save file (see SaveData._resolve_save_path).
	save_data_script.save_data({"essence": 0, "upgrades": {}, "best_wave": 0})

	var data: Dictionary = save_data_script.load_data()
	print("fresh save starts empty: essence=%d (expected 0), upgrades=%s (expected {})" % [data.essence, data.upgrades])

	# Legacy (the hub every wing grows from) costs 1; Deep Lungs (stamina) is the cheapest multi-level node behind it, 1, 1, 2 Essence for
	# its three levels.
	var legacy_cost: int = save_data_script.get_upgrade_cost("legacy", 0)
	var cost_lvl0: int = save_data_script.get_upgrade_cost("stamina", 0)
	var cost_lvl2: int = save_data_script.get_upgrade_cost("stamina", 2)
	print("each level has its own price: lvl0=%d lvl2=%d (expected %d, %d from the node's price list)" % [
		cost_lvl0, cost_lvl2, save_data_script.UPGRADES.stamina.costs[0], save_data_script.UPGRADES.stamina.costs[2]
	])

	data.essence = 0
	var bought_too_poor: bool = save_data_script.try_buy_upgrade(data, "legacy")
	print("can't buy an upgrade without enough essence: bought=%s essence_unchanged=%s (expected false, true)" % [
		bought_too_poor, data.essence == 0
	])
	data.essence = 100
	var bought_locked: bool = save_data_script.try_buy_upgrade(data, "stamina")
	print("...nor one whose requirement is missing (Deep Lungs needs Legacy): bought=%s (expected false)" % [bought_locked])
	save_data_script.try_buy_upgrade(data, "legacy")
	var bought: bool = save_data_script.try_buy_upgrade(data, "stamina")
	print("buying an upgrade spends essence and levels it up: bought=%s essence_left=%d (expected %d) level=%d (expected 1)" % [
		bought, data.essence, 100 - legacy_cost - cost_lvl0, data.upgrades.stamina
	])

	save_data_script.save_data(data)
	var reloaded: Dictionary = save_data_script.load_data()
	print("save/load round-trips correctly: essence=%d (expected %d) stamina_level=%d (expected 1)" % [
		reloaded.essence, 100 - legacy_cost - cost_lvl0, reloaded.upgrades.get("stamina", 0)
	])

	var bonuses: Dictionary = save_data_script.get_applied_bonuses()
	print("applied bonuses reflect owned upgrade levels: stamina_bonus=%d (expected %d), coins_bonus=%d (expected 0)" % [
		bonuses.stamina, save_data_script.UPGRADES.stamina.stat_bonus, bonuses.coins
	])

	# --- A fresh run's Player picks up the permanent bonus. ---
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	print("a new run's player starts with the permanent stamina bonus applied: max_stamina=%d (expected %d)" % [
		player.max_stamina, player.MAX_STAMINA + bonuses.stamina
	])

	# --- Death: computes essence for the kills made, banks it into the slot
	# (see below) and shows the game-over panel instead of the old bare
	# "press R" message. ---
	main.wave = 4
	# Essence is earned per enemy: 5 ordinary kills and one boss.
	for i in 5:
		main._on_enemy_died(0, "Goblin")
	main._on_enemy_died(0, "Archmage")
	var expected_earned: int = 5 * save_data_script.ESSENCE_PER_KILL + save_data_script.ESSENCE_PER_BOSS_KILL
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
	# Dying ends the run, not the save: the essence is banked and the upgrades
	# bought with it stay (a run's own weapons/armour/allies/gold are never
	# serialized, so they're gone regardless).
	var after_death: Dictionary = save_data_script.load_data()
	print("dying keeps the slot and banks the essence: slot_exists=%s (expected true), essence=%d (expected %d)" % [
		save_data_script.slot_exists(save_data_script.active_slot), after_death.essence, (100 - legacy_cost - cost_lvl0) + expected_earned
	])
	print("...and the upgrades bought with it survive: stamina_level=%d (expected 1)" % [after_death.upgrades.get("stamina", 0)])

	# Reset the scratch save so later tests in a full-suite run always see a
	# clean slate, regardless of run order.
	save_data_script.save_data({"essence": 0, "upgrades": {}, "best_wave": 0})

	quit()
