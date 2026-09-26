extends SceneTree

func _init() -> void:
	var save_data_script = load("res://scripts/SaveData.gd")
	var weapons_script = load("res://scripts/Weapons.gd")

	# Start from a clean slate -- shared scratch save file (see
	# SaveData._resolve_save_path).
	save_data_script.save_data({"essence": 0, "upgrades": {}, "best_wave": 0})

	for id in ["stamina", "luck", "resilience_unlock", "potions"]:
		print("SaveData tracks the new upgrade '%s': present=%s (expected true)" % [
			id, save_data_script.UPGRADE_IDS.has(id)
		])

	# Buy one level of each new upgrade and confirm the bonuses compute
	# correctly before touching a real Player. resilience_unlock is a pure
	# ownership flag now (see SaveData.gd) -- it unlocks Resilience as a
	# level-up stat rather than granting a %/level reduction directly, so
	# owning it just needs to read as > 0, not a specific percentage.
	var data: Dictionary = save_data_script.load_data()
	data.essence = 1000
	for id in ["stamina", "luck", "resilience_unlock", "potions"]:
		save_data_script.try_buy_upgrade(data, id)
	save_data_script.save_data(data)
	var bonuses: Dictionary = save_data_script.get_applied_bonuses()
	print("applied bonuses after buying one level of each: stamina=%d (expected 15), luck=%.2f (expected 0.15), resilience_unlock=%s (expected true), potions=%d (expected 1)" % [
		bonuses.stamina, bonuses.luck, bonuses.resilience_unlock > 0, bonuses.potions
	])

	# --- A fresh run's player picks all of this up automatically. ---
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	print("player picks up stamina/luck/potions on a new run: max_stamina=%d (expected %d), stamina=%d (expected same), luck_bonus=%.2f (expected 0.15), healing_items=%d (expected >=1)" % [
		player.max_stamina, player.MAX_STAMINA + 15, player.stamina, player.luck_bonus, player.healing_items
	])
	print("...and Resilience is unlocked as a level-up choice, though its stat starts at 0 until leveled: meta_resilience_unlocked=%s (expected true), stat_resilience=%d (expected 0), resilience_reduction=%.2f (expected 0.0)" % [
		player.meta_resilience_unlocked, player.stat_resilience, player.resilience_reduction
	])

	# --- Resilience stacks with armor to reduce incoming battle damage. ---
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)
	var orc_script = load("res://scripts/Orc.gd")
	var orc = orc_script.new()
	main.add_child(orc)
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_player_defending = false
	# Boost vigor well past what the orc's hit deals so the check below
	# compares relative damage instead of clamping to 0 health. A few points
	# of Resilience (only reachable via level-ups once unlocked, simulated
	# directly here) gives a real reduction to actually test the stacking.
	player.stat_vigor = 100
	player.stat_resilience = 3
	player._recalc_stats()
	player.health = player.max_health
	main.battle_units = [{
		"ref": orc, "tile": Vector2i(3, 2), "hp": 20, "max_hp": 20, "move_range": 1,
		"damage": 10, "name": "Orc", "winding_up": true, "stunned": false,
	}]
	main._process_enemy_turn()
	var expected_reduction: float = clampf(player.equipped_armor.get("damage_reduction", 0.0) + player.resilience_reduction, 0.0, 0.9)
	var expected_dmg: int = int(round(10 * main.ORC_WINDUP_DAMAGE_MULT * (1.0 - expected_reduction)))
	print("resilience stacks with armor to reduce the telegraphed hit: player_health=%d (expected max_health-%d=%d)" % [
		player.health, expected_dmg, player.max_health - expected_dmg
	])

	# --- Fortune (luck) shifts shop weapon-tier odds toward Fine/Masterwork. ---
	var master_count_no_luck := 0
	var master_count_with_luck := 0
	for i in 1000:
		if weapons_script._pick_tier(0, 0.0).tier_name == "Masterwork":
			master_count_no_luck += 1
		if weapons_script._pick_tier(0, 0.6).tier_name == "Masterwork":
			master_count_with_luck += 1
	print("luck shifts weapon-tier odds toward Masterwork: no_luck=%d/1000 (~18%%), with_luck=%d/1000 (expected clearly higher)" % [
		master_count_no_luck, master_count_with_luck
	])

	# --- The weapon roster itself has room for the newer types (dagger/bow)
	# alongside the originals -- the shop's own offering size is a flat
	# SHOP_TOTAL_SLOTS lootpool now (see Main.gd:_roll_shop_offering),
	# not a per-category weapon-slot count tied to the roster size. ---
	print("weapon roster includes the newer types: %d upgradable types (expected >= 8)" % [weapons_script.UPGRADABLE_TYPES.size()])

	# Reset the scratch save for whatever test runs next.
	save_data_script.save_data({"essence": 0, "upgrades": {}, "best_wave": 0})

	quit()
