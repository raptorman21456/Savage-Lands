extends SceneTree

# Builds a battle_units entry the same way _setup_battle_grid does --
# move_range/attack_range/size all pulled from the real ENEMY_TRAITS table
# instead of hand-typed, so a future trait change can't silently desync
# these tests the way a hardcoded "attack_range" once did.
func _make_unit(main, ref, tile: Vector2i, hp: int, name: String, damage: int) -> Dictionary:
	var traits: Dictionary = main.ENEMY_TRAITS.get(name, {})
	return {
		"ref": ref, "tile": tile, "hp": hp, "max_hp": hp,
		"move_range": traits.get("move_range", 2),
		"attack_range": traits.get("attack_range", 1),
		"size": traits.get("size", 1),
		"damage": damage, "name": name, "winding_up": false, "stunned": false,
	}

func _init() -> void:
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var player = main.player

	# --- Wave gating: new types phase in one per wave rather than all at
	# once. ---
	main.wave = main.ARCHER_WAVE_START
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await physics_frame
	main.enemies_alive = 0
	main._spawn_wave()
	# Same stray-contact-battle risk as above -- freeze immediately, before
	# the await below gives these fresh spawns a live tick.
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)
	await physics_frame
	var wave1_counts := {}
	for e in main.get_tree().get_nodes_in_group("enemies"):
		var n: String = e.get_display_name()
		wave1_counts[n] = wave1_counts.get(n, 0) + 1
	print("wave 1 introduces only the Apprentice Mage among new types: archer=%d (expected 1), shaman=%d (expected 0), brute=%d (expected 0), shade=%d (expected 0)" % [
		wave1_counts.get("Apprentice Mage", 0), wave1_counts.get("Shaman", 0), wave1_counts.get("Brute", 0), wave1_counts.get("Shade", 0)
	])

	main.wave = main.SHADE_WAVE_START
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await physics_frame
	main.enemies_alive = 0
	main._spawn_wave()
	# Same stray-contact-battle risk as above -- freeze immediately, before
	# the await below gives these fresh spawns (which by this wave include
	# an Archer, Brute, Shade and Shaman) a live tick.
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)
	await physics_frame
	var wave4_counts := {}
	for e in main.get_tree().get_nodes_in_group("enemies"):
		var n: String = e.get_display_name()
		wave4_counts[n] = wave4_counts.get(n, 0) + 1
	print("by wave 4 all four new types are present: archer=%d shaman=%d brute=%d shade=%d (all expected >=1)" % [
		wave4_counts.get("Apprentice Mage", 0), wave4_counts.get("Shaman", 0), wave4_counts.get("Brute", 0), wave4_counts.get("Shade", 0)
	])

	# --- Goblin: very aggressive and persistent -- once it spots the
	# player, it never reverts to wandering, even if the player then moves
	# far outside its detect range. This is an overworld (Enemy.gd) chase
	# behavior, tested directly on the node rather than through a battle. ---
	var goblin_script = load("res://scripts/Enemy.gd")
	var aggro_goblin = goblin_script.new()
	main.add_child(aggro_goblin)
	aggro_goblin.global_position = Vector2(100, 100)
	player.global_position = Vector2(150, 100)
	aggro_goblin._physics_process(0.016)
	var aggro_after_first_sight: bool = aggro_goblin.has_aggro
	player.global_position = Vector2(100000, 100000)
	aggro_goblin._physics_process(0.016)
	print("goblin gains aggro on sight and never loses it, even far out of detect range: aggro_after_sight=%s (expected true), aggro_still_after_leaving=%s (expected true)" % [
		aggro_after_first_sight, aggro_goblin.has_aggro
	])
	aggro_goblin.set_physics_process(false)

	# --- Deterministic tile-battle setup shared by the checks below. ---
	main.in_battle = true
	main.battle_target_index = 0
	# The wave 1/4 respawns above are unfrozen for one live tick each before
	# being frozen, and this world is small enough relative to enemy contact
	# ranges (up to 90px for the Archer, spawned in both waves) that one can
	# occasionally land within contact range of the player's still-centered
	# spawn and trigger a *real* trigger_battle(), which populates
	# battle_terrain with random rocks via the genuine _setup_battle_grid
	# path. The very next line's line-of-sight check assumes an empty board
	# (nothing here has placed terrain on purpose yet) -- clear it explicitly
	# so that assumption holds regardless of any incidental overworld contact.
	main.battle_terrain.clear()
	player.stat_vigor = 100
	player._recalc_stats()

	var archer_script = load("res://scripts/Archer.gd")
	var shaman_script = load("res://scripts/Shaman.gd")
	var brute_script = load("res://scripts/Brute.gd")
	var shade_script = load("res://scripts/Shade.gd")
	var orc_script = load("res://scripts/Orc.gd")

	# --- Apprentice Mage: attacks from up to 4 tiles away (a melee-range
	# check on the same geometry can't reach that far). The non-straight-line
	# part of its rework has its own dedicated coverage in
	# tools/test_apprentice_mage.gd. ---
	print("Apprentice Mage's 4-tile range reaches across most of the grid: at_range=%s (expected true), melee_cant=%s (expected false)" % [
		main._can_battle_attack(Vector2i(4, 2), Vector2i(0, 2), main.ARCHER_ATTACK_RANGE),
		main._can_battle_attack(Vector2i(4, 2), Vector2i(0, 2), 1)
	])

	# Apprentice Mage: unlike the Archer it replaced, it doesn't kite or
	# strafe -- already in range, it just fires and holds its tile.
	var archer = archer_script.new()
	main.add_child(archer)
	archer.died.connect(main._on_enemy_died)
	main.enemies_alive += 1

	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(0, 2)
	main.battle_player_defending = false
	player.health = player.max_health
	main.battle_units = [_make_unit(main, archer, Vector2i(3, 2), 6, "Apprentice Mage", 1)]
	main._process_enemy_turn()
	print("Apprentice Mage holds its tile and fires instead of strafing/kiting away: tile=%s (expected unchanged (3, 2)), player_hit=%s (expected true, health dropped from %d)" % [
		main.battle_units[0].tile, player.health < player.max_health, player.max_health
	])

	# --- Shade: a total glass cannon -- 1 HP (any landed hit kills it),
	# but a real chance to dodge entirely, over enough trials to be sure
	# both a dodge and a landed (lethal) hit occur. ---
	var shade = shade_script.new()
	main.add_child(shade)
	shade.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	main._setup_battle_grid([shade])
	print("shade's data-driven fields via the real _setup_battle_grid path: move_range=%d (expected 3), max_hp=%d (expected 1)" % [
		main.battle_units[0].move_range, main.battle_units[0].max_hp
	])

	player.stat_strength = 5
	player.attack_damage = 5
	main.battle_target_index = 0
	var saw_dodge := false
	var saw_kill := false
	for i in 100:
		var shade_unit = _make_unit(main, shade, Vector2i(3, 2), 1, "Shade", 10)
		main.battle_units = [shade_unit]
		main._apply_single_hit(0, 1.0, "", player.current_weapon)
		if main.battle_units.size() == 1 and main.battle_units[0].hp == 1:
			saw_dodge = true
		elif main.battle_units.is_empty():
			saw_kill = true
		if saw_dodge and saw_kill:
			break
	print("shade sometimes dodges an attack entirely, but any landed hit is lethal at 1 HP: saw_dodge=%s saw_kill=%s (both expected true)" % [saw_dodge, saw_kill])

	# That loop's kills grant real XP through the real death path, which can
	# level the player up mid-test -- reset back to a known baseline so
	# every later print's "max_health - N" stays easy to sanity-check.
	player.level = 1
	player.xp = 0
	player.xp_to_next = player.XP_BASE + player.XP_PER_LEVEL * player.level
	player.stat_vigor = 100
	player._recalc_stats()
	main.choosing_stat = false
	main.get_tree().paused = false

	# Shade deals its new, much heavier damage when it lands a hit.
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_player_defending = false
	player.health = player.max_health
	main.battle_units = [_make_unit(main, shade, Vector2i(3, 2), 1, "Shade", 10)]
	main._process_enemy_turn()
	print("shade deals 10 damage when it lands a hit: player_health=%d (expected max_health-10=%d)" % [
		player.health, player.max_health - 10
	])

	# --- Brute: a real 2x2 footprint (not just a bigger number), assigned
	# via the real _setup_battle_grid path, and fully ignores terrain. ---
	var brute = brute_script.new()
	main.add_child(brute)
	brute.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	main._setup_battle_grid([brute])
	var brute_unit = main.battle_units[0]
	var brute_footprint: Array = main._footprint(brute_unit.tile, brute_unit.size)
	print("brute is placed as a real 2x2 footprint: size=%d (expected 2), footprint_cell_count=%d (expected 4), all_in_bounds=%s (expected true)" % [
		brute_unit.size, brute_footprint.size(), brute_footprint.all(func(c): return main._in_battle_bounds(c))
	])

	# A rock placed directly in its path doesn't block it at all.
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(5, 5)
	main.battle_terrain[Vector2i(2, 2)] = {"type": "rock"}
	main.battle_units = [_make_unit(main, brute, Vector2i(1, 2), 35, "Brute", 3)]
	main._move_big_unit(main.battle_units[0], main.battle_player_tile, main.battle_player_tile)
	print("brute walks straight through a rock in its path, ignoring terrain entirely: tile=%s (expected x=2, past the rock)" % [main.battle_units[0].tile])

	# It can still be targeted from any of its 4 cells, not just one.
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(0, 0)
	main.battle_units = [_make_unit(main, brute, Vector2i(2, 2), 35, "Brute", 3)]
	# Adjacent to the footprint's far corner (3,3), not its anchor (2,2).
	main.battle_player_tile = Vector2i(4, 3)
	print("brute can be targeted from any of its 4 cells, not just its anchor: targetable=%s (expected [0])" % [main._targetable_indices()])

	# It still shrugs off rock cover, same as before.
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_terrain[Vector2i(2, 3)] = {"type": "rock"}
	main.battle_player_defending = false
	player.health = player.max_health
	main.battle_units = [_make_unit(main, brute, Vector2i(3, 2), 35, "Brute", 3)]
	main._process_enemy_turn()
	print("brute still ignores rock cover for its own damage output: player_health=%d (expected max_health-3=%d, full damage despite adjacent rock)" % [
		player.health, player.max_health - 3
	])

	# --- Orc: tries to flank toward the far side of the player (away from
	# the grid center) instead of charging straight in. ---
	print("orc's flank target aims past the player, away from the grid center: flank_of_(1,1)=%s (expected (0,0)), flank_of_(4,4)=%s (expected (5,5))" % [
		main._flank_target_tile(Vector2i(1, 1)), main._flank_target_tile(Vector2i(4, 4))
	])

	var orc = orc_script.new()
	main.add_child(orc)
	orc.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	# Deliberately point movement_target the opposite way from the real
	# player tile -- if _move_enemy_unit actually steers by movement_target
	# (how "corners" wires in _flank_target_tile) rather than always
	# chasing battle_player_tile directly, the orc moves left, not right.
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(5, 2)
	main.battle_units = [_make_unit(main, orc, Vector2i(2, 2), 20, "Orc", 2)]
	main._move_enemy_unit(main.battle_units[0], main.battle_units[0].attack_range, Vector2i(0, 2), main.battle_player_tile)
	print("_move_enemy_unit steers toward movement_target, not straight at the player -- this is what wires the orc's flanking in: tile=%s (expected (1, 2), moved left toward the target, not right toward the player)" % [main.battle_units[0].tile])

	# Orc: sometimes skips the telegraph for an immediate quick jab (2
	# damage) instead of winding up (which still leads to the same old
	# 4-damage hit) -- over enough trials to see both.
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_player_defending = false
	var saw_quick_jab := false
	var saw_windup_start := false
	for i in 100:
		player.health = player.max_health
		main.battle_units = [_make_unit(main, orc, Vector2i(3, 2), 20, "Orc", 2)]
		main._process_enemy_turn()
		var dmg_taken: int = player.max_health - player.health
		if dmg_taken == 2:
			saw_quick_jab = true
		elif dmg_taken == 0 and main.battle_units[0].winding_up:
			saw_windup_start = true
		if saw_quick_jab and saw_windup_start:
			break
	print("orc sometimes quick-jabs for 2 instead of winding up: saw_quick_jab=%s (expected true), saw_windup_start=%s (expected true)" % [saw_quick_jab, saw_windup_start])

	# The orc's full telegraphed hit is unchanged at 4 damage.
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_player_defending = false
	player.health = player.max_health
	main.battle_units = [_make_unit(main, orc, Vector2i(3, 2), 20, "Orc", 2)]
	main.battle_units[0].winding_up = true
	main._process_enemy_turn()
	print("orc's full windup hit still deals 4 damage: player_health=%d (expected max_health-4=%d)" % [
		player.health, player.max_health - 4
	])

	# --- Shaman: refuses to engage at all while any other ally is alive
	# (heals if it can, otherwise just watches), only fighting once it's
	# truly the last one standing. ---
	var shaman = shaman_script.new()
	main.add_child(shaman)
	shaman.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	var goblin_for_shaman = goblin_script.new()
	main.add_child(goblin_for_shaman)
	goblin_for_shaman.died.connect(main._on_enemy_died)
	main.enemies_alive += 1

	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_player_defending = false
	player.health = player.max_health
	var player_health_before: int = player.health
	main.battle_units = [
		_make_unit(main, shaman, Vector2i(5, 5), 12, "Shaman", 1),
		_make_unit(main, goblin_for_shaman, Vector2i(5, 4), 1, "Goblin", 1),
	]
	main.battle_units[1].max_hp = 3
	main._process_enemy_turn()
	var expected_heal: int = max(1, int(round(3 * main.SHAMAN_HEAL_PCT)))
	print("shaman heals its worst-hurt ally instead of attacking: goblin_hp=%d (expected %d), player_health=%d (expected unchanged %d)" % [
		main.battle_units[1].hp, min(3, 1 + expected_heal), player.health, player_health_before
	])

	# Even with nobody left to heal, it still refuses to engage while an
	# ally is alive -- it just watches and waits.
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_player_defending = false
	player.health = player.max_health
	main.battle_units = [
		_make_unit(main, shaman, Vector2i(3, 2), 12, "Shaman", 1),
		_make_unit(main, goblin_for_shaman, Vector2i(5, 5), 3, "Goblin", 1),
	]
	main._process_enemy_turn()
	print("shaman refuses to engage while any ally is alive, even at full HP: player_health=%d (expected unchanged %d)" % [
		player.health, player.max_health
	])

	# Shaman: falls back to attacking directly once it's the last one
	# standing (nothing left to heal, no one left to wait for).
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_player_defending = false
	player.health = player.max_health
	main.battle_units = [_make_unit(main, shaman, Vector2i(3, 2), 12, "Shaman", 1)]
	main._process_enemy_turn()
	print("shaman attacks directly once it's the last unit standing: player_health=%d (expected max_health-1=%d)" % [
		player.health, player.max_health - 1
	])

	# --- Squad gathering: Brute (and Shade) generalize the old Orc-only
	# "tough" escort logic instead of being treated as goblin-tier fodder. ---
	var initial_orc = orc_script.new()
	main.add_child(initial_orc)
	initial_orc.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	initial_orc.position = Vector2(2000, 2000)

	var nearby_brute = brute_script.new()
	main.add_child(nearby_brute)
	nearby_brute.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	nearby_brute.position = Vector2(2020, 2000)

	var squad = main._gather_squad(initial_orc)
	var brute_joined := false
	for u in squad:
		if u.get_display_name() == "Brute":
			brute_joined = true
	print("a brute can join an orc-led tough squad: squad_size=%d (expected 2<=x<=4), brute_joined=%s (expected true)" % [squad.size(), brute_joined])

	# --- Goblin: fights harder while another goblin is still alive in the
	# fight (unchanged mechanically from before). ---
	var goblin_a = goblin_script.new()
	main.add_child(goblin_a)
	goblin_a.died.connect(main._on_enemy_died)
	main.enemies_alive += 1

	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_player_defending = false
	player.health = player.max_health
	main.battle_units = [_make_unit(main, goblin_a, Vector2i(3, 2), 3, "Goblin", 2)]
	main._process_enemy_turn()
	print("solo goblin deals base damage, no pack bonus: player_health=%d (expected max_health-2=%d)" % [
		player.health, player.max_health - 2
	])

	var goblin_b = goblin_script.new()
	main.add_child(goblin_b)
	goblin_b.died.connect(main._on_enemy_died)
	main.enemies_alive += 1

	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_player_defending = false
	player.health = player.max_health
	main.battle_units = [
		_make_unit(main, goblin_a, Vector2i(3, 2), 3, "Goblin", 2),
		_make_unit(main, goblin_b, Vector2i(5, 5), 3, "Goblin", 2),
	]
	main._process_enemy_turn()
	var expected_pack_dmg: int = int(round(2 * main.GOBLIN_PACK_DAMAGE_MULT))
	print("goblin with a packmate alive elsewhere fights fiercely, dealing bonus damage: player_health=%d (expected max_health-%d=%d)" % [
		player.health, expected_pack_dmg, player.max_health - expected_pack_dmg
	])

	# Trait data sanity checks -- pins the exact numbers each type's identity
	# depends on.
	print("shade trait data: dodge_chance=%.2f (expected 0.40), move_range=%d (expected 3)" % [
		main.ENEMY_TRAITS["Shade"].dodge_chance, main.ENEMY_TRAITS["Shade"].move_range
	])
	print("brute trait data: knockback_resist=%.2f (expected 0.60), ignore_cover=%s (expected true), ignore_terrain=%s (expected true), size=%d (expected 2)" % [
		main.ENEMY_TRAITS["Brute"].knockback_resist, main.ENEMY_TRAITS["Brute"].ignore_cover, main.ENEMY_TRAITS["Brute"].ignore_terrain, main.ENEMY_TRAITS["Brute"].size
	])
	print("Apprentice Mage trait data: attack_range=%d (expected 4), ignore_line=%s (expected true), kites=%s strafes=%s (both expected false -- that identity moved to the Centaur Archer)" % [
		main.ENEMY_TRAITS["Apprentice Mage"].attack_range, main.ENEMY_TRAITS["Apprentice Mage"].ignore_line,
		main.ENEMY_TRAITS["Apprentice Mage"].get("kites", false), main.ENEMY_TRAITS["Apprentice Mage"].get("strafes", false)
	])
	print("shaman trait data: heals_allies=%s (expected true)" % [main.ENEMY_TRAITS["Shaman"].heals_allies])
	print("goblin trait data: pack_bonus_mult=%.2f (expected 1.50)" % [main.ENEMY_TRAITS["Goblin"].pack_bonus_mult])
	print("orc trait data: corners=%s (expected true), quick_jab_chance=%.2f (expected 0.40)" % [
		main.ENEMY_TRAITS["Orc"].corners, main.ENEMY_TRAITS["Orc"].quick_jab_chance
	])

	quit()
