extends SceneTree

# Nothingness boss rush (World Progression feature): 6 sequential fights
# (Demogorgon, Tiamat, Count Strahd, Duke Zalto, Acererak, then a Supreme
# Warlock rematch at power_tier 2.5), the game's first-ever win condition,
# and the Worldwalker skill-tree capstone it unlocks lifetime-wide.

func _init() -> void:
	# Explicit reset -- the lifetime file is a single shared scratch path
	# across every test run (same convention test_skill_tree.gd's save_data
	# reset already uses for the numbered slots), so a PREVIOUS test run
	# marking the game complete must not leak into this one's "before"
	# assertions.
	var save_data_script = load("res://scripts/SaveData.gd")
	save_data_script.save_lifetime_data({})
	save_data_script.save_data({"essence": 0, "upgrades": {}, "best_wave": 0})

	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	# --- Data sanity ---
	var names := ["Demogorgon", "Tiamat", "Count Strahd", "Duke Zalto", "Acererak"]
	var all_boss_tier := true
	var all_have_icons := true
	for n in names:
		if not main.ENEMY_TRAITS.get(n, {}).get("is_boss_tier", false):
			all_boss_tier = false
		if main.hud.ENEMY_ICONS.get(n, null) == null:
			all_have_icons = false
	print("All 5 new Nothingness bosses are is_boss_tier: %s (expected true)" % [all_boss_tier])
	print("All 5 new Nothingness bosses have HUD icons: %s (expected true)" % [all_have_icons])
	print("NOTHINGNESS_BOSSES has exactly 6 entries (5 new + Supreme Warlock rematch): %d (expected 6)" % [main.NOTHINGNESS_BOSSES.size()])
	print("NOTHINGNESS_POWER_TIERS climbs fight-to-fight, ending at the same 2.5x already proven for the rematch: %s (expected [1.0, 1.15, 1.3, 1.45, 1.6, 2.5])" % [main.NOTHINGNESS_POWER_TIERS])

	# --- wave 101-106 spawn the 6 fights in order, through the real
	# _spawn_wave routing (not calling _spawn_nothingness_fight directly) ---
	var expected_names := ["Demogorgon", "Tiamat", "Count Strahd", "Duke Zalto", "Acererak", "Supreme Warlock"]
	var all_correct := true
	for i in 6:
		main.wave = 101 + i
		main.current_world_index = main._world_index_for_wave(main.wave)
		for e in main.get_tree().get_nodes_in_group("enemies"):
			e.queue_free()
		await physics_frame
		main.enemies_alive = 0
		main._spawn_wave()
		await physics_frame
		var spawned: Array = main.get_tree().get_nodes_in_group("enemies")
		var got_name: String = spawned[0].get_display_name() if spawned.size() == 1 else "none(%d)" % spawned.size()
		if got_name != expected_names[i]:
			all_correct = false
			print("  MISMATCH at wave %d: got %s, expected %s" % [main.wave, got_name, expected_names[i]])
		for e in spawned:
			e.set_physics_process(false)
	print("waves 101-106 spawn all 6 rush fights in the correct order: %s (expected true)" % [all_correct])

	# --- power_tier actually reaches the enemy instance for a mid-rush
	# fight too, not just the already-tested Supreme Warlock rematch ---
	main.wave = 104  # fight_index 3 -> Duke Zalto, power_tier 1.45
	main.current_world_index = main._world_index_for_wave(main.wave)
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await physics_frame
	main.enemies_alive = 0
	main._spawn_wave()
	await physics_frame
	var zalto_nodes: Array = main.get_tree().get_nodes_in_group("enemies")
	var zalto_script = load("res://scripts/DukeZalto.gd")
	if zalto_nodes.size() == 1:
		print("Duke Zalto (fight 4) carries power_tier=1.45: %.2f (expected 1.45)" % [zalto_nodes[0].power_tier])
		main._setup_battle_grid([zalto_nodes[0]])
		print("...and _setup_battle_grid scales its HP accordingly: hp=%d (expected %d)" % [
			main.battle_units[0].hp, int(round(zalto_script.MAX_HEALTH * 1.45))
		])
	for e in zalto_nodes:
		e.set_physics_process(false)

	# --- First-ever completion: wave 107 triggers Victory, banks essence,
	# resets like a death, and sets the lifetime flag. ---
	print("game_completed_ever starts false: %s (expected false)" % [save_data_script.is_game_completed_ever()])
	main.wave = 106
	main.current_world_index = main._world_index_for_wave(main.wave)
	main.player.level = 1
	print("wave 106 is still Nothingness: %s (expected Nothingness)" % [main.WORLDS[main.current_world_index].name])

	main.wave = 107
	main.nothingness_rush_complete = false
	main.game_over = false
	main.hud.game_over_panel.visible = false
	main._spawn_wave()
	print("wave 107 (rush cleared) marks the lifetime flag: %s (expected true)" % [save_data_script.is_game_completed_ever()])
	print("...shows the Victory panel: visible=%s, text_mentions_worldwalker=%s (expected true, true)" % [
		main.hud.game_over_panel.visible, main.hud.game_over_label.text.contains("Worldwalker")
	])
	print("...ends the run like a death: game_over=%s paused=%s (expected true, true)" % [main.game_over, main.get_tree().paused])
	print("...and pins current_world_index to Voidlands for good: index=%d name=%s rush_complete=%s (expected 9, Voidlands, true)" % [
		main.current_world_index, main.WORLDS[main.current_world_index].name, main.nothingness_rush_complete
	])
	print("...the save slot was wiped, same as a death (best_wave/essence gone): %s (expected true, empty dict)" % [save_data_script.load_data().get("upgrades", {}).is_empty()])
	paused = false

	# --- Worldwalker: locked before, unlocked (and purchasable) after ---
	save_data_script.save_data({"essence": 10000, "upgrades": {}, "best_wave": 0})
	var fresh_data: Dictionary = save_data_script.load_data()
	print("Worldwalker is unlocked now that the lifetime flag is set: %s (expected true)" % [save_data_script.is_upgrade_unlocked(fresh_data, "worldwalker")])
	var bought: bool = save_data_script.try_buy_upgrade(fresh_data, "worldwalker")
	save_data_script.save_data(fresh_data)
	print("...and can actually be purchased with essence: %s (expected true)" % [bought])

	# --- Reset the lifetime flag to prove Worldwalker is genuinely gated,
	# not just always-unlocked -- confirms the "before" state was real. ---
	save_data_script.save_lifetime_data({})
	save_data_script.save_data({"essence": 10000, "upgrades": {}, "best_wave": 0})
	var locked_data: Dictionary = save_data_script.load_data()
	print("Worldwalker is locked again once the lifetime flag is cleared: %s (expected false)" % [save_data_script.is_upgrade_unlocked(locked_data, "worldwalker")])

	# --- Player.gd's meta_worldwalker: +15% max HP, +10% damage, once owned ---
	player.stat_vigor = 100
	player.stat_strength = 20
	player.meta_worldwalker = false
	player._recalc_stats()
	var base_hp: int = player.max_health
	var base_dmg: int = player.attack_damage
	player.meta_worldwalker = true
	player._recalc_stats()
	print("Worldwalker adds +15%% max HP and +10%% damage once owned: hp=%d (expected %d), dmg=%d (expected %d)" % [
		player.max_health, int(round(base_hp * 1.15)), player.attack_damage, int(round(base_dmg * 1.10))
	])

	# --- Repeat completion (lifetime flag already set): no second Victory,
	# falls through to normal Voidlands-tier spawning instead. ---
	save_data_script.mark_game_completed()
	main.game_over = false
	main.hud.game_over_panel.visible = false
	main.wave = 106
	main.nothingness_rush_complete = false
	main.current_world_index = main._world_index_for_wave(main.wave)
	main.wave = 107
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await physics_frame
	main.enemies_alive = 0
	main._spawn_wave()
	await physics_frame
	print("a REPEAT completion shows no Victory panel: %s (expected false)" % [main.hud.game_over_panel.visible])
	print("...and instead spawns a normal (Voidlands-tier) wave: enemies_spawned=%s (expected true)" % [
		not main.get_tree().get_nodes_in_group("enemies").is_empty()
	])
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	quit()
