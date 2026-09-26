extends SceneTree

# 9 reserved terrain types (Main.gd:RESERVED_TERRAIN_TYPES): Ice, Embers,
# Poison Bog, Quicksand, Healing Spring, Crumbling Floor, Thicket, Caltrops,
# Rubble. Fully implemented but never rolled by _setup_battle_grid's real
# _place_terrain calls yet -- held back for a future per-world terrain
# system. This covers the mechanics directly, the same way other one-off
# battle mechanics get tested elsewhere in this project (manual battle_units/
# battle_terrain setup, no _setup_battle_grid call except where noted).

func _make_goblin(main, tile: Vector2i, hp: int = 999, dmg: int = 0) -> Dictionary:
	var goblin_script = load("res://scripts/Enemy.gd")
	var g = goblin_script.new()
	main.add_child(g)
	g.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	return {
		"ref": g, "tile": tile, "hp": hp, "max_hp": hp, "move_range": 2,
		"damage": dmg, "name": "Goblin", "winding_up": false, "stunned": false,
		"attack_range": 1, "concussed_turns": 0, "frozen_turns": 0,
		"burning": false, "armored": false,
		"disarmed_tile": Vector2i(-1, -1),
	}

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

	# --- None of the 9 are ever rolled by a real battle yet -- confirmed
	# across many rolls of both a normal and a boss-sized grid. ---
	var goblin_script = load("res://scripts/Enemy.gd")
	var boss_script = load("res://scripts/Boss.gd")
	var any_reserved_spawned := false
	for i in 40:
		var squad_member = goblin_script.new()
		main.add_child(squad_member)
		main._setup_battle_grid([squad_member])
		for t in main.battle_terrain:
			if main.battle_terrain[t].type in main.RESERVED_TERRAIN_TYPES:
				any_reserved_spawned = true
		squad_member.queue_free()
	var boss = boss_script.new()
	main.add_child(boss)
	main._setup_battle_grid([boss])
	for t in main.battle_terrain:
		if main.battle_terrain[t].type in main.RESERVED_TERRAIN_TYPES:
			any_reserved_spawned = true
	print("none of the 9 reserved terrain types are ever rolled by a real battle: %s (expected false)" % [any_reserved_spawned])

	main.in_battle = true
	main.battle_allies = []
	main.battle_target_index = 0
	player.equipped_armor = {"damage_reduction": 0.0}
	player.max_health = 100
	player.health = 100

	# --- Ice: landing on it slides one extra tile in the same direction. ---
	main.battle_terrain = {Vector2i(3, 2): {"type": "ice"}}
	var ice_result: Dictionary = main._resolve_battle_step(Vector2i(2, 2), Vector2i(1, 0))
	print("Ice slides you one extra tile: tile=%s moved=%s (expected (4, 2), true)" % [ice_result.tile, ice_result.moved])

	# --- Rubble: blocks movement and line-of-fire like Rock, and provides
	# the same adjacent cover bonus. ---
	main.battle_terrain = {Vector2i(3, 2): {"type": "rubble"}}
	var rubble_block: Dictionary = main._resolve_battle_step(Vector2i(2, 2), Vector2i(1, 0))
	print("Rubble blocks movement like Rock: moved=%s (expected false)" % [rubble_block.moved])
	print("Rubble blocks line-of-fire like Rock: %s (expected false)" % [main._can_battle_attack(Vector2i(1, 2), Vector2i(5, 2), 5)])
	print("Rubble provides the same adjacent cover as Rock: %s (expected true)" % [main._has_adjacent_rock(Vector2i(2, 2))])

	# --- Rubble crumbling: a knockback blocked by rubble has a chance to
	# destroy it entirely instead of stunning. Force the roll both ways by
	# checking many trials land in both buckets (RUBBLE_CRUMBLE_CHANCE=0.4,
	# neither extreme should be a fluke over 40 trials). ---
	var crumbled_count := 0
	var stunned_count := 0
	for i in 40:
		main.battle_terrain = {Vector2i(3, 2): {"type": "rubble"}}
		var g_rub := _make_goblin(main, Vector2i(2, 2))
		main._apply_knockback(g_rub, Vector2i(1, 0), true, false)
		if main.battle_terrain.has(Vector2i(3, 2)):
			stunned_count += 1
			print_verbose("stunned")
		else:
			crumbled_count += 1
	print("Rubble sometimes crumbles away from a knockback, sometimes just stuns: crumbled=%d stunned=%d (expected both > 0, out of 40)" % [crumbled_count, stunned_count])

	# --- Thicket: walkable (unlike Rock/Rubble), but still blocks
	# line-of-fire the same way. ---
	main.battle_terrain = {Vector2i(3, 2): {"type": "thicket"}}
	var thicket_step: Dictionary = main._resolve_battle_step(Vector2i(2, 2), Vector2i(1, 0))
	print("Thicket is walkable, unlike Rock/Rubble: moved=%s (expected true)" % [thicket_step.moved])
	print("...but still blocks line-of-fire: %s (expected false)" % [main._can_battle_attack(Vector2i(1, 2), Vector2i(5, 2), 5)])

	# --- Caltrops: crossing it costs an extra point of move budget, for
	# both the player and an enemy. ---
	main.battle_terrain = {Vector2i(3, 2): {"type": "caltrops"}}
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_player_moves_left = 3
	main._try_battle_player_move(Vector2i(1, 0))
	print("Caltrops cost the player an extra move point: tile=%s moves_left=%d (expected (3,2), 1)" % [main.battle_player_tile, main.battle_player_moves_left])

	main.battle_terrain = {Vector2i(3, 5): {"type": "caltrops"}}
	var g_calt := _make_goblin(main, Vector2i(2, 5))
	g_calt.move_range = 3
	main._move_enemy_unit(g_calt, 1, Vector2i(10, 5), Vector2i(10, 5))
	# 3 move budget: crossing the caltrops tile (2,5)->(3,5) spends 2, leaving
	# only 1 -- enough for one more normal step to (4,5), not the 3 tiles a
	# flat move_range would otherwise cover.
	print("Caltrops cost an enemy an extra move point too: tile=%s (expected (4, 5), only 2 tiles covered instead of 3)" % [g_calt.tile])

	# --- Embers: sets Burn (persists until water, see BURN_DAMAGE_DIVISOR)
	# instead of a one-off flat hit -- no immediate damage from the tick
	# itself, the burn ticks later on whoever's own next turn. ---
	main.battle_terrain = {Vector2i(4, 4): {"type": "embers"}}
	main.player_burning = false
	main._apply_terrain_tick(Vector2i(4, 4))
	print("Embers set the player alight instead of dealing immediate damage: health=%d (expected unchanged 100), burning=%s (expected true)" % [
		player.health, main.player_burning
	])
	main.player_burning = false
	var g_embers := _make_goblin(main, Vector2i(4, 4), 999)
	main._apply_terrain_tick(Vector2i(4, 4), g_embers)
	print("...and an enemy standing there too: burning=%s (expected true)" % [g_embers.burning])

	# --- Healing Spring: flat heal to whoever ends their turn on it. ---
	main.battle_terrain = {Vector2i(4, 4): {"type": "spring"}}
	player.health = 50
	main._apply_terrain_tick(Vector2i(4, 4))
	print("Healing Spring heals the player: health=%d (expected %d)" % [player.health, 50 + main.SPRING_HEAL_AMOUNT])
	var g_spring := _make_goblin(main, Vector2i(4, 4), 50)
	g_spring.max_hp = 100
	main._apply_terrain_tick(Vector2i(4, 4), g_spring)
	print("...and an enemy too, capped at max HP: hp=%d (expected %d)" % [g_spring.hp, 50 + main.SPRING_HEAL_AMOUNT])

	# --- Crumbling Floor: the first time anyone ends a turn on it, it
	# permanently turns into Rock. ---
	main.battle_terrain = {Vector2i(4, 4): {"type": "crumbling"}}
	main._apply_terrain_tick(Vector2i(4, 4))
	print("Crumbling Floor becomes Rock after the first turn spent on it: %s (expected rock)" % [main.battle_terrain[Vector2i(4, 4)].type])

	# --- Poison Bog: arms a lingering DOT (mirrors burning) rather than
	# dealing immediate damage -- the tick happens on a LATER turn. Damage is
	# %-of-max-HP (POISON_DAMAGE_PCT), computed at application time, not a
	# flat const. ---
	main.battle_terrain = {Vector2i(4, 4): {"type": "poison_bog"}}
	player.health = 100
	main._apply_terrain_tick(Vector2i(4, 4))
	var expected_player_poison: int = max(1, int(round(player.max_health * main.POISON_DAMAGE_PCT)))
	print("Poison Bog arms a %%-of-max-HP DOT instead of dealing immediate damage: health=%d (expected unchanged 100), poison_turns=%d poison_dmg=%d (expected %d, %d)" % [
		player.health, main.player_poison_turns, main.player_poison_dmg, main.POISON_TURNS, expected_player_poison
	])
	main.battle_units = [_make_goblin(main, Vector2i(6, 6), 999, 0)]  # harmless, far off, keeps _process_enemy_turn's tail reachable; (6,6) stays in-bounds regardless of which grid size a prior section left active
	main._process_enemy_turn()
	print("...and it actually ticks on a later turn: health=%d (expected %d), poison_turns=%d (expected %d)" % [
		player.health, 100 - expected_player_poison, main.player_poison_turns, main.POISON_TURNS - 1
	])
	player.health = 100
	main.player_poison_turns = 0

	var g_poison := _make_goblin(main, Vector2i(4, 4), 999)
	main._apply_terrain_tick(Vector2i(4, 4), g_poison)
	var expected_enemy_poison: int = max(1, int(round(999.0 * main.POISON_DAMAGE_PCT)))
	print("Poison Bog arms an enemy's DOT the same way: poison_turns=%d poison_dmg=%d (expected %d, %d)" % [
		g_poison.poison_turns, g_poison.poison_dmg, main.POISON_TURNS, expected_enemy_poison
	])
	main.battle_units = [g_poison]
	main._process_enemy_turn()
	print("...and it ticks on the enemy's own next turn: hp=%d poison_turns=%d (expected %d, %d)" % [
		g_poison.hp, g_poison.poison_turns, 999 - expected_enemy_poison, main.POISON_TURNS - 1
	])

	# --- Quicksand: immobilizes for exactly the next turn -- the player via
	# battle_player_turns_to_skip, an enemy via the existing stunned flag. ---
	main.battle_terrain = {Vector2i(4, 4): {"type": "quicksand"}}
	main.battle_player_turns_to_skip = 0
	main._apply_terrain_tick(Vector2i(4, 4))
	print("Quicksand arms a skipped next turn for the player: battle_player_turns_to_skip=%d (expected 1)" % [main.battle_player_turns_to_skip])
	main.battle_player_turns_to_skip = 0

	var g_quicksand := _make_goblin(main, Vector2i(4, 4), 999)
	main._apply_terrain_tick(Vector2i(4, 4), g_quicksand)
	print("Quicksand stuns an enemy for its next turn: stunned=%s (expected true)" % [g_quicksand.stunned])

	quit()
