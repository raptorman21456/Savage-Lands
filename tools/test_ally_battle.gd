extends SceneTree

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player

	var goblin_script = load("res://scripts/Enemy.gd")
	var orc_script = load("res://scripts/Orc.gd")
	var brute_script = load("res://scripts/Brute.gd")

	# --- Tile placement: allies land on distinct, in-bounds tiles that never
	# collide with the player, an enemy squad's footprint, or each other,
	# across many trials with a maximal roster (3 party members via Pack
	# Leader + a wolf). Same overlap-checking shape as
	# test_squad_placement_overlap.gd, extended to cover battle_allies too. ---
	player.party_members = [
		{"name": "Blade Ally", "dmg_mult": 0.75},
		{"name": "Warrior", "dmg_mult": 0.75},
		{"name": "Warrior", "dmg_mult": 0.75},
	]
	player.max_party_slots = 3
	player.party_wolf = {"name": "Traitor Wolf", "dmg_mult": 0.6}

	var any_overlap := false
	var any_out_of_bounds := false
	var wrong_ally_count := false
	var trials := 100
	for i in trials:
		var squad := [orc_script.new(), brute_script.new(), goblin_script.new(), goblin_script.new()]
		for e in squad:
			main.add_child(e)
		main._setup_battle_grid(squad)

		if main.battle_allies.size() != 4:
			wrong_ally_count = true

		var claimed := {}
		claimed[main.battle_player_tile] = true
		for u in main.battle_units:
			for cell in main._footprint(u.tile, u.get("size", 1)):
				claimed[cell] = true
		for a in main.battle_allies:
			if not main._in_battle_bounds(a.tile):
				any_out_of_bounds = true
			if claimed.has(a.tile):
				any_overlap = true
			claimed[a.tile] = true

		for e in squad:
			e.queue_free()
		await physics_frame

	print("every ally in the roster gets seated: wrong_ally_count=%s (expected false, 4 allies -- 3 party + 1 wolf)" % [wrong_ally_count])
	print("no ally tile ever collides with the player, an enemy footprint, or another ally, across %d trials: any_overlap=%s (expected false)" % [trials, any_overlap])
	print("every ally tile stays within grid bounds: any_out_of_bounds=%s (expected false)" % [any_out_of_bounds])

	# --- max_hp scaling: derived fresh from the player's CURRENT max_health
	# every battle, not stored on the permanent roster. ---
	player.party_members = [{"name": "Blade Ally", "dmg_mult": 0.75}]
	player.max_party_slots = 2
	player.party_wolf = {"name": "Traitor Wolf", "dmg_mult": 0.6}
	player.max_health = 40
	player.health = 40
	main._setup_battle_grid([])
	var blade_ally: Dictionary = main.battle_allies[0]
	var wolf_ally: Dictionary = main.battle_allies[1]
	print("a party member's max_hp scales off the player's CURRENT max_health: %d (expected %d, 40*0.7)" % [
		blade_ally.max_hp, roundi(40 * main.ALLY_MAX_HP_PCT)
	])
	print("the wolf companion's max_hp uses its own, lower percentage: %d (expected %d, 40*0.55)" % [
		wolf_ally.max_hp, roundi(40 * main.WOLF_ALLY_MAX_HP_PCT)
	])
	print("both start at full HP: %s (expected true, true)" % [[blade_ally.hp == blade_ally.max_hp, wolf_ally.hp == wolf_ally.max_hp]])

	# --- Movement + attack via _process_ally_turn: an ally out of range moves
	# closer without attacking; one already in range attacks the current
	# target instead, reusing _apply_single_hit's existing hit/death handling
	# for the enemy side untouched. ---
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_target_index = 0

	var far_goblin_ref = goblin_script.new()
	main.add_child(far_goblin_ref)
	far_goblin_ref.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	var far_goblin := {"ref": far_goblin_ref, "tile": Vector2i(5, 5), "hp": 999, "max_hp": 999, "move_range": 2, "damage": 1, "name": "Goblin", "winding_up": false, "stunned": false, "attack_range": 1}
	main.battle_units = [far_goblin]
	main.battle_allies = [{"tile": Vector2i(0, 0), "hp": 20, "max_hp": 20, "dmg_mult": 0.75, "name": "Blade Ally", "move_range": 2, "attack_range": 1}]
	var ally_start_tile: Vector2i = main.battle_allies[0].tile
	main._process_ally_turn()
	print("an ally out of range moves closer without attacking: moved=%s (expected true), goblin_untouched=%s (expected true, still 999)" % [
		main.battle_allies[0].tile != ally_start_tile, far_goblin.hp == 999
	])

	var near_goblin_ref = goblin_script.new()
	main.add_child(near_goblin_ref)
	near_goblin_ref.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	var near_goblin := {"ref": near_goblin_ref, "tile": Vector2i(1, 0), "hp": 999, "max_hp": 999, "move_range": 2, "damage": 1, "name": "Goblin", "winding_up": false, "stunned": false, "attack_range": 1}
	main.battle_units = [near_goblin]
	main.battle_allies = [{"tile": Vector2i(0, 0), "hp": 20, "max_hp": 20, "dmg_mult": 1.0, "name": "Blade Ally", "move_range": 2, "attack_range": 1}]
	main.battle_target_index = 0
	main._process_ally_turn()
	print("an ally already in range attacks the current target instead of moving into it: goblin_hp=%d (expected < 999, took a hit)" % [near_goblin.hp])

	# --- Enemies can now target allies: one closer to a lone ally than to
	# the player picks the ally as its target and damages it -- this is the
	# whole point of the health bar actually moving. ---
	main.battle_target_index = 0
	main.battle_player_tile = Vector2i(5, 5)
	var attacker_ref = goblin_script.new()
	main.add_child(attacker_ref)
	attacker_ref.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	var attacker := {"ref": attacker_ref, "tile": Vector2i(0, 1), "hp": 999, "max_hp": 999, "move_range": 2, "damage": 3, "name": "Goblin", "winding_up": false, "stunned": false, "attack_range": 1}
	main.battle_units = [attacker]
	main.battle_allies = [{"tile": Vector2i(0, 0), "hp": 20, "max_hp": 20, "dmg_mult": 1.0, "name": "Blade Ally", "move_range": 2, "attack_range": 1}]
	main._process_enemy_turn()
	print("an enemy closer to an ally than the player picks the ally as its target and damages it: ally_hp=%d (expected < 20)" % [main.battle_allies[0].hp])

	# --- KO: an ally reduced to 0 HP is removed from battle_allies, but the
	# rest of the enemy turn -- and the battle itself -- keeps going. ---
	main.battle_allies = [{"tile": Vector2i(0, 0), "hp": 1, "max_hp": 20, "dmg_mult": 1.0, "name": "Blade Ally", "move_range": 2, "attack_range": 1}]
	main.battle_units = [attacker]
	attacker.hp = 999
	main._process_enemy_turn()
	print("an ally reduced to 0 HP is removed from battle_allies: %d remaining (expected 0)" % [main.battle_allies.size()])
	print("the battle keeps going -- in_battle is still true after an ally KO: %s (expected true)" % [main.in_battle])

	attacker_ref.queue_free()
	near_goblin_ref.queue_free()
	far_goblin_ref.queue_free()
	await physics_frame

	# --- Battle-scoped only: HP isn't stored on the permanent roster, so a
	# fresh _setup_battle_grid rebuilds a KO'd ally at full HP next battle,
	# regardless of how the last battle ended. ---
	player.party_members = [{"name": "Blade Ally", "dmg_mult": 0.75}]
	player.party_wolf = {}
	player.max_party_slots = 2
	main._setup_battle_grid([])
	print("a fresh battle rebuilds the party at full HP regardless of the last battle's outcome: hp=%d max_hp=%d (expected equal)" % [
		main.battle_allies[0].hp, main.battle_allies[0].max_hp
	])

	# --- Baseline: a battle with zero allies still sets up and runs its
	# ally-turn phase without crashing on an empty battle_allies. ---
	player.party_members = []
	player.party_wolf = {}
	main._setup_battle_grid([])
	print("zero allies is a valid, crash-free roster: battle_allies=%d (expected 0)" % [main.battle_allies.size()])
	main.in_battle = true
	main.battle_units = [far_goblin]
	main._process_ally_turn()
	print("_process_ally_turn with zero allies is a safe no-op: %s (expected true, still 0 allies, no crash)" % [main.battle_allies.is_empty()])

	# Reset the scratch save for whatever test runs next.
	var save_data_script = load("res://scripts/SaveData.gd")
	save_data_script.save_data({"essence": 0, "upgrades": {}, "best_wave": 0})

	quit()
