extends SceneTree

func _make_enemy(main, tile: Vector2i, hp: int = 999) -> Dictionary:
	var g = load("res://scripts/Enemy.gd").new()
	main.add_child(g)
	g.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	return {
		"ref": g, "tile": tile, "hp": hp, "max_hp": hp, "move_range": 2,
		"damage": 0, "name": "Goblin", "winding_up": false, "stunned": false,
	}

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	main.regional_world = false  # this test drives the old wave-ladder world
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
			var expected_dmg: float = weapons_script.SPEAR.damage_mult * 1.0 * 0.75
			var expected_price: int = int(round(weapons_script.SPEAR.price * 1.0 * 0.5))
			var expected_stamina: int = int(round(weapons_script.SPEAR.specials[0].stamina_cost * 0.5))
			print("Fine Wooden Spear composes correctly: name=%s (expected 'Wooden Spear'), dmg=%.3f (expected %.3f), price=%d (expected %d), special0_stamina=%d (expected %d), break_chance=%.2f (expected 0.00)" % [
				v.name, v.damage_mult, expected_dmg, v.price, expected_price, v.specials[0].stamina_cost, expected_stamina, v.break_chance
			])
		if v.tier_name == "Masterwork" and v.material_name == "Golden" and not found_masterwork_gold:
			found_masterwork_gold = true
			var expected_dmg2: float = weapons_script.SPEAR.damage_mult * 1.3 * 1.25
			var expected_price2: int = int(round(weapons_script.SPEAR.price * 1.7 * 1.4))
			print("Masterwork Golden Spear composes correctly: name=%s (expected 'Masterwork Golden Spear'), dmg=%.3f (expected %.3f), price=%d (expected %d), break_chance=%.2f (expected 0.00)" % [
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

	# --- Weapon material passives (Weapons.gd:MATERIALS) --------------------
	# Steel (the baseline) carries none; Wood/Gold/Bone/Silver/Obsidian each
	# get one always-on combat trait, gated on weapon.material_id at each
	# read site in Main.gd. Stone Amulet's amplification of these gets its
	# simplest, fully-deterministic case (Gold's flat coin bonus) covered in
	# test_talismans.gd instead -- this just covers each material's own base
	# behavior, plus a couple of representative Stone Amulet checks here too.
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_allies = []
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_turn = "player"
	main.battle_target_index = 0
	player.equipped_talismans.clear()
	player._talisman_cache.clear()
	player.stat_strength = 10
	player.attack_damage = 10
	player.temp_damage_bonus_pct = 0.0
	player.meta_crit_chance = 0.0
	player.stealth_turns_remaining = 0
	main.player_burning = false
	main.player_blind_turns = 0
	main.player_poison_turns = 0
	main.player_concussed_turns = 0

	var known_material_ids: Array = weapons_script.MATERIALS.map(func(m): return m.id)
	# min_rank=1 still leaves the ~0.5% Mythic jackpot eligible (see the
	# material-distribution test above), and a Mythic variant carries no
	# material_id at all -- re-roll past it rather than risk a flaky failure.
	var rolled_variant: Dictionary = weapons_script.make_variant(weapons_script.SPEAR, 1)
	while rolled_variant.get("tier_name", "") == "Mythic":
		rolled_variant = weapons_script.make_variant(weapons_script.SPEAR, 1)
	print("a rolled variant carries a real material_id: %s (expected true, one of %s)" % [
		known_material_ids.has(rolled_variant.get("material_id", "")), known_material_ids
	])

	# Wood's Quick Strikes (renamed 2026-09-29 from Quick Hands -- a free first
	# use): a flat 10% chance for a landed hit to strike again, same shape as
	# a weapon's own passive_double_hit_chance. A hit landing for MORE than
	# a single hit's damage is the double-hit firing.
	var wood_weapon: Dictionary = weapons_script.SPEAR.duplicate(true)
	wood_weapon.material_id = "wood"
	player.current_weapon = wood_weapon
	var wood_target := _make_enemy(main, Vector2i(3, 2), 999999)
	main.battle_units = [wood_target]
	var wood_trials := 300
	var wood_doubles := 0
	var single_hit_dmg: int = int(round(10 * wood_weapon.damage_mult))
	for i in wood_trials:
		player.stamina = player.MAX_STAMINA
		var hp_before: int = wood_target.hp
		main._battle_player_fight()
		if (hp_before - wood_target.hp) >= single_hit_dmg * 2 - 1:
			wood_doubles += 1
	print("Wood's Quick Strikes: a flat 10%% chance to hit again over %d trials: %d (expected roughly 15-55, ~30 mean)" % [wood_trials, wood_doubles])
	player._talisman_cache["material_passive_boost"] = 1.0
	var wood_doubles_boosted := 0
	for i in wood_trials:
		player.stamina = player.MAX_STAMINA
		var hp_before2: int = wood_target.hp
		main._battle_player_fight()
		if (hp_before2 - wood_target.hp) >= single_hit_dmg * 2 - 1:
			wood_doubles_boosted += 1
	print("Stone Amulet raises Quick Strikes to roughly 15%%: %d (expected roughly 25-70, clearly more than a 10%% baseline)" % [wood_doubles_boosted])
	player._talisman_cache.erase("material_passive_boost")
	player.stamina = player.MAX_STAMINA

	# Gold's Gilded Strike: a coin for landing the killing blow yourself --
	# not from an ally's kill with the same weapon. A "ref": null synthetic
	# target (not a real Enemy node) on purpose -- a real node's .died signal
	# would refresh Rage/Berserk and grant XP (see _on_enemy_died), polluting
	# the deterministic damage-magnitude checks later in this file.
	var gold_weapon: Dictionary = weapons_script.SPEAR.duplicate(true)
	gold_weapon.material_id = "gold"
	player.coins = 0
	player.meta_bonus_coin_pct = 0.0
	main.battle_units = [{"ref": null, "tile": Vector2i(3, 2), "hp": 1, "max_hp": 1, "move_range": 2, "damage": 0, "name": "Goblin"}]
	main._apply_single_hit(0, 1.0, "", gold_weapon, "You", Vector2i(-1, -1), 999, false)
	print("Gold's Gilded Strike: +1 coin for the killing blow: coins=%d (expected 1)" % [player.coins])
	player.coins = 0
	main.battle_units = [{"ref": null, "tile": Vector2i(3, 2), "hp": 1, "max_hp": 1, "move_range": 2, "damage": 0, "name": "Goblin"}]
	main._apply_single_hit(0, 1.0, "", gold_weapon, "Your Wolf", Vector2i(2, 2), 999, false)
	print("...but not from an ally's kill: coins=%d (expected 0)" % [player.coins])

	# Steel (the baseline) carries no material passive at all.
	var steel_weapon: Dictionary = weapons_script.SPEAR.duplicate(true)
	steel_weapon.material_id = "steel"
	player.coins = 0
	main.battle_units = [{"ref": null, "tile": Vector2i(3, 2), "hp": 1, "max_hp": 1, "move_range": 2, "damage": 0, "name": "Goblin"}]
	main._apply_single_hit(0, 1.0, "", steel_weapon, "You", Vector2i(-1, -1), 999, false)
	print("Steel carries no material passive: coins unchanged=%d (expected 0)" % [player.coins])
	player.berserk_turns_remaining = 0

	# Bone's Dreadful Strike: a flat 7.5% chance regardless of weapon type
	# (2026-09-29 -- was scaled by weapon cooldown_mult), amplified by Stone
	# Amulet.
	var bone_spear: Dictionary = weapons_script.SPEAR.duplicate(true)
	bone_spear.material_id = "bone"
	var dread_target := {"ref": null, "tile": Vector2i(3, 2), "hp": 999999, "max_hp": 999999, "move_range": 2, "damage": 0, "name": "Goblin"}
	main.battle_units = [dread_target]
	var dread_procs := 0
	var dread_trials := 1000
	for i in dread_trials:
		dread_target.feared = false
		main._apply_single_hit(0, 1.0, "", bone_spear, "You", Vector2i(-1, -1), 1, false)
		if dread_target.feared:
			dread_procs += 1
	print("Bone's Dreadful Strike procs roughly 7.5%% over %d trials: %d (expected roughly 75, within +/-40%%)" % [dread_trials, dread_procs])
	player._talisman_cache["material_passive_boost"] = 1.0
	var dread_boosted := 0
	for i in dread_trials:
		dread_target.feared = false
		main._apply_single_hit(0, 1.0, "", bone_spear, "You", Vector2i(-1, -1), 1, false)
		if dread_target.feared:
			dread_boosted += 1
	print("Stone Amulet raises Dreadful Strike's chance to roughly 11.25%%: %d (expected roughly 112, clearly more than %d)" % [dread_boosted, dread_procs])
	player._talisman_cache.erase("material_passive_boost")
	dread_target.feared = false

	# The feared flag itself skips the whole enemy turn once, then clears --
	# same shape as Frozen/Stunned (see _process_enemy_turn).
	main.battle_player_tile = Vector2i(1, 0)
	player.health = player.max_health
	var feared_enemy := _make_enemy(main, Vector2i(0, 0), 999)
	feared_enemy.damage = 50
	feared_enemy["feared"] = true
	main.battle_units = [feared_enemy]
	main._process_enemy_turn()
	print("a feared enemy skips its turn entirely, even adjacent to the player: player_health=%d (expected unchanged %d), feared=%s (expected false)" % [
		player.health, player.max_health, feared_enemy.feared
	])

	# Silver's Cleansing Strike: the helper picks one active affliction (not
	# all of them) and clears it; the on-hit roll actually calls it.
	main.player_poison_turns = 5
	main.player_blind_turns = 3
	main._try_cleanse_one_player_status()
	var poison_cleared: bool = main.player_poison_turns == 0
	var blind_cleared: bool = main.player_blind_turns == 0
	print("cleansing with two afflictions active clears exactly one, not both: %s (expected true)" % [poison_cleared != blind_cleared])
	main.player_poison_turns = 0
	main.player_blind_turns = 0

	main.battle_player_tile = Vector2i(2, 2)
	var silver_weapon: Dictionary = weapons_script.SPEAR.duplicate(true)
	silver_weapon.material_id = "silver"
	var silver_target := {"ref": null, "tile": Vector2i(3, 2), "hp": 999999, "max_hp": 999999, "move_range": 2, "damage": 0, "name": "Goblin"}
	main.battle_units = [silver_target]
	var silver_cleanses := 0
	var silver_trials := 500
	for i in silver_trials:
		main.player_poison_turns = 5
		main._apply_single_hit(0, 1.0, "", silver_weapon, "You", Vector2i(-1, -1), 1, false)
		if main.player_poison_turns == 0:
			silver_cleanses += 1
	print("Silver's Cleansing Strike procs roughly 15%% of hits over %d trials: %d (expected roughly 75, within +/-40%%)" % [silver_trials, silver_cleanses])
	main.player_poison_turns = 0

	# Obsidian's Splinter Strike (renamed 2026-09-29 from Volatile Shard): a
	# 5% chance for a landed hit to cause Bleeding instead of extra damage,
	# amplified by Stone Amulet. Never re-triggers while already bleeding
	# (see the bleed_turns <= 0 guard in _apply_single_hit).
	var obsidian_weapon: Dictionary = weapons_script.SPEAR.duplicate(true)
	obsidian_weapon.material_id = "obsidian"
	var obsidian_trials := 500
	var obsidian_procs := 0
	for i in obsidian_trials:
		var obsidian_target := {"ref": null, "tile": Vector2i(3, 2), "hp": 100000000, "max_hp": 100000000, "move_range": 2, "damage": 0, "name": "Goblin", "bleed_turns": 0}
		main.battle_units = [obsidian_target]
		main._apply_single_hit(0, 1.0, "", obsidian_weapon, "You", Vector2i(-1, -1), 10, false)
		if obsidian_target.bleed_turns > 0:
			obsidian_procs += 1
	print("Obsidian's Splinter Strike causes Bleeding on roughly 5%% of hits over %d trials: %d (expected roughly 25, within +/-60%%)" % [obsidian_trials, obsidian_procs])
	player._talisman_cache["material_passive_boost"] = 1.0
	var obsidian_procs_boosted := 0
	for i in obsidian_trials:
		var obsidian_target2 := {"ref": null, "tile": Vector2i(3, 2), "hp": 100000000, "max_hp": 100000000, "move_range": 2, "damage": 0, "name": "Goblin", "bleed_turns": 0}
		main.battle_units = [obsidian_target2]
		main._apply_single_hit(0, 1.0, "", obsidian_weapon, "You", Vector2i(-1, -1), 10, false)
		if obsidian_target2.bleed_turns > 0:
			obsidian_procs_boosted += 1
	print("Stone Amulet raises Splinter Strike's chance to roughly 7.5%%: %d (expected roughly 38, clearly more than %d)" % [obsidian_procs_boosted, obsidian_procs])
	player._talisman_cache.erase("material_passive_boost")

	main.in_battle = false
	player.current_weapon = weapons_script.CLUB

	quit()
