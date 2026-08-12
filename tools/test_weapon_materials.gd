extends SceneTree

func _init() -> void:
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var player = main.player
	var weapons_script = load("res://scripts/Weapons.gd")
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	# --- distribution over many rolls (min_rank=1 excludes Mythic entirely
	# via the tier floor, isolating pure material distribution) ---
	var material_counts := {}
	for m in weapons_script.MATERIALS:
		material_counts[m.id] = 0
	# min_rank=1 only excludes Broken (rank 0) -- Mythic (rank 5) is still
	# eligible and, unlike every other tier, never rolls a material at all.
	# Skip those (rare, ~0.5%) rather than crash on the missing key.
	var trials := 3000
	for i in trials:
		var variant: Dictionary = weapons_script.make_variant(weapons_script.SPEAR, 1)
		if not variant.has("material_name"):
			continue
		for m in weapons_script.MATERIALS:
			if variant.material_name == m.name:
				material_counts[m.id] += 1
	print("material distribution over %d rolls: %s (expected roughly wood 25%%, steel 35%%, gold 15%%, bone 10%%, silver 10%%, obsidian 5%%)" % [trials, material_counts])

	# --- composition math, forcing a specific tier+material combo by
	# re-rolling until both land (cheap given trial budget above). ---
	var found_fine_wood := false
	var found_masterwork_gold := false
	for i in 500:
		var v: Dictionary = weapons_script.make_variant(weapons_script.SPEAR, 0)
		if v.tier_name == "Fine" and v.material_name == "Wooden" and not found_fine_wood:
			found_fine_wood = true
			var expected_dmg: float = weapons_script.SPEAR.damage_mult * 1.0 * 0.65
			var expected_price: int = int(round(weapons_script.SPEAR.price * 1.0 * 0.5))
			var expected_stamina: int = int(round(weapons_script.SPEAR.specials[0].stamina_cost * 0.5))
			print("Fine Wooden Spear composes correctly: name=%s (expected 'Wooden Spear'), dmg=%.3f (expected %.3f), price=%d (expected %d), special0_stamina=%d (expected %d), break_chance=%.2f (expected 0.00)" % [
				v.name, v.damage_mult, expected_dmg, v.price, expected_price, v.specials[0].stamina_cost, expected_stamina, v.break_chance
			])
		if v.tier_name == "Masterwork" and v.material_name == "Golden" and not found_masterwork_gold:
			found_masterwork_gold = true
			var expected_dmg2: float = weapons_script.SPEAR.damage_mult * 1.3 * 1.25
			var expected_price2: int = int(round(weapons_script.SPEAR.price * 1.7 * 1.3))
			print("Masterwork Golden Spear composes correctly: name=%s (expected 'Masterwork Golden Spear'), dmg=%.3f (expected %.3f), price=%d (expected %d), break_chance=%.2f (expected 0.05)" % [
				v.name, v.damage_mult, expected_dmg2, v.price, expected_price2, v.break_chance
			])

	# --- base const is never mutated by material stamina scaling (the
	# deep-duplicate fix) ---
	var base_stamina_before: int = weapons_script.SPEAR.specials[0].stamina_cost
	for i in 200:
		weapons_script.make_variant(weapons_script.SPEAR, 0)
	print("base SPEAR const specials untouched after 200 rolls: stamina=%d (expected unchanged %d)" % [
		weapons_script.SPEAR.specials[0].stamina_cost, base_stamina_before
	])

	# --- get_owned_tier_rank works across material suffixes ---
	player.owned_weapons["spear_masterwork_gold"] = true
	print("owned rank for a Masterwork Gold spear: %d (expected 3, Masterwork's rank)" % [player.get_owned_tier_rank("spear")])
	player.owned_weapons.clear()
	player.owned_weapons["club"] = true
	player.owned_weapons["greatsword_mythic"] = true
	# Mythic must NOT raise the floor -- otherwise owning one greatsword
	# Mythic (a ~0.5% jackpot) would lock every future greatsword shop roll
	# to Mythic forever, since it's the single highest rank there is.
	print("owning only a Mythic greatsword doesn't floor future rolls: %d (expected -1, not 5)" % [player.get_owned_tier_rank("greatsword")])
	player.owned_weapons["greatsword_fine_steel"] = true
	print("a lower tier owned alongside a Mythic still sets its own floor: %d (expected 2, Fine's rank, not Mythic's 5)" % [player.get_owned_tier_rank("greatsword")])
	print("owned rank for a never-bought type: %d (expected -1)" % [player.get_owned_tier_rank("hammer")])

	# --- breaking: a weapon with break_chance=1.0 always shatters on its
	# next landed hit, reverting the player to Club. ---
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_target_index = 0
	player.stat_strength = 10
	player.attack_damage = 10
	var risky_weapon: Dictionary = weapons_script.SPEAR.duplicate(true)
	risky_weapon.id = "spear_risky_test"
	risky_weapon.break_chance = 1.0
	player.owned_weapons[risky_weapon.id] = true
	player.current_weapon = risky_weapon
	player.stamina = player.MAX_STAMINA
	var goblin_script = load("res://scripts/Enemy.gd")
	var g = goblin_script.new()
	main.add_child(g)
	g.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	main.battle_units = [{
		"ref": g, "tile": Vector2i(3, 2), "hp": 999, "max_hp": 999, "move_range": 2,
		"damage": 0, "name": "Goblin", "winding_up": false, "stunned": false,
	}]
	main._battle_player_fight()
	print("a 100%% break_chance weapon shatters on its first landed hit: current_weapon=%s (expected club), still_owned=%s (expected false)" % [
		player.current_weapon.id, player.owned_weapons.has(risky_weapon.id)
	])

	quit()
