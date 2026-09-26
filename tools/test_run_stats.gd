extends SceneTree

# Run-end stats recap: per-run kill/damage/boss counters (Main.gd), the HUD's
# shared game-over/victory recap panel, SaveData.gd's lifetime aggregates,
# and the TitleScreen Stats screen that displays them.

func _init() -> void:
	var save_data_script = load("res://scripts/SaveData.gd")
	# Shared scratch path across every test run (same convention
	# test_nothingness_boss_rush.gd already uses for the lifetime file) -- a
	# previous test run's aggregates must not leak into this one's "before"
	# assertions.
	save_data_script.save_lifetime_data({})

	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	# --- Kill tracking + boss tally ---
	# Kept positive so _on_enemy_died's wave-clear branch never fires and
	# opens the shop mid-test -- irrelevant to what's being tested here.
	main.enemies_alive = 10
	main._on_enemy_died(5, "Goblin")
	main._on_enemy_died(5, "Goblin")
	main._on_enemy_died(50, "Owlbear")
	main._on_enemy_died(3, "")
	print("kills_by_name tracks named kills: %s (expected {\"Goblin\": 2, \"Owlbear\": 1})" % [main.run_kills_by_name])
	print("bosses_defeated only counts is_boss_tier kills: %d (expected 1)" % [main.run_bosses_defeated])

	# --- Damage dealt (_apply_single_hit) ---
	var goblin_script = load("res://scripts/Enemy.gd")
	var goblin = goblin_script.new()
	main.add_child(goblin)
	main._setup_battle_grid([goblin])
	var hp_before: int = main.battle_units[0].hp
	var dealt_before: int = main.run_damage_dealt
	main._apply_single_hit(0, 1.0, "", player.current_weapon)
	var actual_dealt: int = hp_before - main.battle_units[0].hp
	print("_apply_single_hit adds to run_damage_dealt: delta=%d actual_dmg=%d (expected equal, both > 0)" % [main.run_damage_dealt - dealt_before, actual_dealt])

	# --- Damage taken (_enemy_apply_damage, player branch) ---
	# Checked against the function's own returned "dmg" (the post-reduction
	# hit it actually logged), not player.health's delta -- health can be
	# clamped at 0 if the hit would overkill, which would make the two
	# diverge without indicating any tracking bug.
	var taken_before: int = main.run_damage_taken
	var result: Dictionary = main._enemy_apply_damage({"tile": Vector2i(4, 5), "name": "Goblin"}, main.battle_player_tile, 15, {})
	print("_enemy_apply_damage adds to run_damage_taken: delta=%d reported_dmg=%d (expected equal, both > 0)" % [main.run_damage_taken - taken_before, result.dmg])

	# --- _run_stats_summary() shape ---
	main.wave = 23
	main.current_world_index = main._world_index_for_wave(main.wave)
	var summary: Dictionary = main._run_stats_summary()
	print("run_stats_summary reflects live counters: waves_cleared=%d (expected 22), world_reached=%s, bosses_defeated=%d (expected 1)" % [
		summary.waves_cleared, summary.world_reached, summary.bosses_defeated
	])
	print("...and damage counters carry through too: damage_dealt_positive=%s damage_taken_positive=%s (expected true, true)" % [
		summary.damage_dealt > 0, summary.damage_taken > 0
	])

	# --- HUD show_game_over populates the shared stats recap ---
	main.hud.show_game_over(123, 456, summary)
	var row_texts := []
	for c in main.hud.game_over_stats_box.get_children():
		row_texts.append(c.text)
	var found_waves := false
	var found_kills_header := false
	var found_goblin_kill := false
	for t in row_texts:
		if t.contains("Waves cleared: 22"):
			found_waves = true
		if t == "Kills:":
			found_kills_header = true
		if t.contains("Goblin x2"):
			found_goblin_kill = true
	print("show_game_over populates a waves-cleared row: %s (expected true)" % [found_waves])
	print("...a Kills header and per-enemy rows: header=%s goblin_row=%s (expected true, true)" % [found_kills_header, found_goblin_kill])
	print("show_game_over panel becomes visible: %s (expected true)" % [main.hud.game_over_panel.visible])

	main.hud.game_over_panel.visible = false
	main.hud.show_victory(123, 456, summary)
	print("show_victory reuses the same recap helper: row_count_positive=%s (expected true)" % [main.hud.game_over_stats_box.get_children().size() > 0])
	print("...and its header still calls out the Worldwalker unlock: %s (expected true)" % [main.hud.game_over_label.text.contains("Worldwalker")])

	# Defensive default (stats: Dictionary = {}) -- an omitted stats arg
	# renders cleanly instead of crashing on a missing key.
	main.hud.show_game_over(0, 0)
	print("show_game_over with no stats arg still renders: panel_visible=%s (expected true)" % [main.hud.game_over_panel.visible])

	main.queue_free()
	await process_frame

	# --- SaveData.gd lifetime aggregate persistence ---
	save_data_script.save_lifetime_data({})
	save_data_script.record_lifetime_run_stats({"Goblin": 3, "Orc": 1}, "Swamp", 2, 1)
	var after_first: Dictionary = save_data_script.load_lifetime_data()
	print("first run: total_runs=%d (expected 1), lifetime_kills=%d (expected 4), deepest_world_ever=%s (expected Swamp), total_bosses_defeated=%d (expected 1)" % [
		after_first.total_runs, after_first.lifetime_kills, after_first.deepest_world_ever, after_first.total_bosses_defeated
	])

	# A second, SHALLOWER run still accumulates kills/bosses/runs but must
	# not regress deepest_world_ever back to an earlier world.
	save_data_script.record_lifetime_run_stats({"Goblin": 2}, "Beach", 1, 0)
	var after_second: Dictionary = save_data_script.load_lifetime_data()
	print("a shallower second run still accumulates: total_runs=%d (expected 2), lifetime_kills=%d (expected 6), total_bosses_defeated=%d (expected 1)" % [
		after_second.total_runs, after_second.lifetime_kills, after_second.total_bosses_defeated
	])
	print("...but deepest_world_ever does not regress: %s (expected Swamp)" % [after_second.deepest_world_ever])

	# A third, DEEPER run does advance deepest_world_ever.
	save_data_script.record_lifetime_run_stats({}, "Nothingness", 10, 2)
	var after_third: Dictionary = save_data_script.load_lifetime_data()
	print("a deeper third run advances deepest_world_ever: %s (expected Nothingness), total_bosses_defeated=%d (expected 3)" % [
		after_third.deepest_world_ever, after_third.total_bosses_defeated
	])

	# --- TitleScreen Stats screen reads the same lifetime file ---
	var title_scene = load("res://TitleScreen.tscn")
	var title = title_scene.instantiate()
	root.add_child(title)
	await process_frame
	await process_frame
	print("Stats screen starts hidden: %s (expected false)" % [title.stats_box.visible])
	title._on_stats_pressed()
	print("Stats button shows the stats screen and hides the main menu: stats_visible=%s main_menu_visible=%s (expected true, false)" % [
		title.stats_box.visible, title.main_menu_box.visible
	])
	print("stats_label reflects the lifetime file: has_3=%s has_6=%s has_nothingness=%s (expected true, true, true)" % [
		title.stats_label.text.contains("3"), title.stats_label.text.contains("6"), title.stats_label.text.contains("Nothingness")
	])
	title._on_stats_back_pressed()
	print("Back returns to the main menu: main_menu_visible=%s stats_visible=%s (expected true, false)" % [
		title.main_menu_box.visible, title.stats_box.visible
	])
	title.queue_free()
	await process_frame

	# Cleanup -- shared scratch path, don't leak into other tests.
	save_data_script.save_lifetime_data({})

	quit()
