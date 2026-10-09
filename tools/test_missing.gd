extends SceneTree

# Missing: each attack has a 5% chance to whiff entirely (no damage, no effects),
# rolled separately per hit of a multi-hit move; 2.5% once every special of the
# weapon in hand is learned; a flat 3% for allies. Shield thorns never miss.

func _make_unit(main, name: String, tile: Vector2i, hp: int = 999999) -> Dictionary:
	return {
		"ref": null, "tile": tile, "hp": hp, "max_hp": hp, "move_range": 2,
		"damage": 3, "name": name, "winding_up": false, "stunned": false,
		"attack_range": 1, "concussed_turns": 0, "frozen_turns": 0,
		"burning": false, "armored": false, "disarmed_tile": Vector2i(-1, -1),
	}

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var weapons = load("res://scripts/Weapons.gd")
	var main = load("res://Main.tscn").instantiate()
	main.regional_world = false  # this test drives the old wave-ladder world
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	print("under a test script Missing starts off so exact-damage tests stay exact: override=%.1f (expected 0.0)" % [player.miss_chance_override])
	player.miss_chance_override = -1.0  # the real rates from here on

	# --- The rates ---
	var club: Dictionary = weapons.CLUB
	var spear: Dictionary = weapons.get_owned_variant("spear_fine_steel")
	var bow: Dictionary = weapons.get_owned_variant("bow_fine_steel")
	player.learned_specials.clear()
	print("base rate with nothing learned: %.3f (expected 0.050)" % [player.miss_chance_for(club)])
	player.learned_specials[club.specials[0].id] = true
	player.learned_specials[club.specials[1].id] = true
	print("two of the Club's three moves learned is still the base rate: %.3f (expected 0.050)" % [player.miss_chance_for(club)])
	player.learned_specials[club.specials[2].id] = true
	print("all three learned halves it: %.3f (expected 0.025)" % [player.miss_chance_for(club)])
	print("...but that is per weapon: the Spear's moves are still unlearned: %.3f (expected 0.050)" % [player.miss_chance_for(spear)])
	print("the Bow has no specials to learn, so it stays at the base rate: %.3f (expected 0.050)" % [player.miss_chance_for(bow)])
	print("allies always miss at a flat rate, whatever you have learned: %.3f (expected 0.030)" % [player.ally_miss_chance()])
	player.miss_chance_override = 0.5
	print("the override replaces every rate, allies included: %.2f / %.2f (expected 0.50 / 0.50)" % [player.miss_chance_for(club), player.ally_miss_chance()])
	player.miss_chance_override = -1.0

	# --- Real hits ---
	player.attack_damage = 10
	main.in_battle = true
	main.battle_target_index = 0
	var trials := 4000
	var misses := 0
	var target := _make_unit(main, "Goblin", Vector2i(4, 3))
	main.battle_units = [target]
	player.learned_specials.clear()
	for i in trials:
		var before: int = target.hp
		main._apply_single_hit(0, 1.0, "", club)
		if target.hp == before:
			misses += 1
	print("a plain attack misses about 5%% of the time over %d hits: %d (expected roughly %d, within +/-30%%)" % [trials, misses, trials / 20])

	player.learned_specials[club.specials[0].id] = true
	player.learned_specials[club.specials[1].id] = true
	player.learned_specials[club.specials[2].id] = true
	misses = 0
	for i in trials:
		var before2: int = target.hp
		main._apply_single_hit(0, 1.0, "", club)
		if target.hp == before2:
			misses += 1
	print("...and about 2.5%% once every Club move is learned: %d (expected roughly %d, within +/-40%%)" % [misses, trials / 40])

	misses = 0
	for i in trials:
		var before3: int = target.hp
		main._apply_single_hit(0, 1.0, "", {"damage_mult": 1.0}, "Your Knight", Vector2i(3, 3))
		if target.hp == before3:
			misses += 1
	print("an ally misses about 3%% of the time: %d (expected roughly %d, within +/-40%%)" % [misses, int(trials * 0.03)])

	# A whiff applies nothing: no damage and no status effect from the hit.
	player.miss_chance_override = 1.0
	var frozen_target := _make_unit(main, "Goblin", Vector2i(4, 3), 100)
	main.battle_units = [frozen_target]
	main._apply_single_hit(0, 1.0, "arrow_freeze", club, "You", Vector2i(-1, -1), 5)
	print("a guaranteed miss deals no damage and applies no effect: hp=%d (expected 100), frozen_turns=%d (expected 0)" % [frozen_target.hp, frozen_target.frozen_turns])
	main._apply_single_hit(0, 1.0, "thorns", club, "Your shield", Vector2i(-1, -1), 5)
	print("...but a shield's thorns reflection is not an attack and never misses: hp=%d (expected 95)" % [frozen_target.hp])

	# Multi-hit: every hit rolls for itself, so a 50% rate over 8 strikes lands
	# some and misses some, instead of all-or-nothing for the whole move.
	player.miss_chance_override = 0.5
	var hits_landed := 0
	var swings := 800
	var dummy := _make_unit(main, "Goblin", Vector2i(4, 3))
	main.battle_units = [dummy]
	for i in swings:
		var before4: int = dummy.hp
		main._apply_single_hit(0, 1.0, "", club, "You", Vector2i(-1, -1), -1, true)
		if dummy.hp < before4:
			hits_landed += 1
	print("each hit of a multi-hit move rolls on its own: %d of %d landed at a 50%% rate (expected roughly %d, within +/-15%%)" % [hits_landed, swings, swings / 2])

	main.in_battle = false
	quit()
