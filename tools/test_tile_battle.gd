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
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	var goblin_script = load("res://scripts/Enemy.gd")
	var orc_script = load("res://scripts/Orc.gd")

	# --- Goblin-initiated battle: capped at 2, orcs never join even if
	# they're standing right next to the initial goblin. ---
	var initial_goblin = goblin_script.new()
	main.add_child(initial_goblin)
	initial_goblin.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	initial_goblin.global_position = player.global_position + Vector2(500, 500)

	for i in 3:
		var o = orc_script.new()
		main.add_child(o)
		o.died.connect(main._on_enemy_died)
		main.enemies_alive += 1
		o.global_position = initial_goblin.global_position + Vector2(20 * i, 0)
	var extra_goblin = goblin_script.new()
	main.add_child(extra_goblin)
	extra_goblin.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	extra_goblin.global_position = initial_goblin.global_position + Vector2(0, 20)

	var goblin_squad = main._gather_squad(initial_goblin)
	var orc_count_in_goblin_squad = 0
	for u in goblin_squad:
		if u.get_display_name() == "Orc":
			orc_count_in_goblin_squad += 1
	print("goblin battle: squad size=%d (expected 2), orcs_in_squad=%d (expected 0)" % [goblin_squad.size(), orc_count_in_goblin_squad])

	# --- Orc-initiated battle: capped at 4, at least 1 orc guaranteed, at
	# most 2 orcs even with more nearby. ---
	var initial_orc = orc_script.new()
	main.add_child(initial_orc)
	initial_orc.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	initial_orc.global_position = player.global_position + Vector2(-500, -500)

	for i in 3:
		var o2 = orc_script.new()
		main.add_child(o2)
		o2.died.connect(main._on_enemy_died)
		main.enemies_alive += 1
		o2.global_position = initial_orc.global_position + Vector2(20 * i, 0)
	for i in 3:
		var g2 = goblin_script.new()
		main.add_child(g2)
		g2.died.connect(main._on_enemy_died)
		main.enemies_alive += 1
		g2.global_position = initial_orc.global_position + Vector2(0, 20 * i)

	var orc_squad = main._gather_squad(initial_orc)
	var orc_count_in_orc_squad = 0
	for u in orc_squad:
		if u.get_display_name() == "Orc":
			orc_count_in_orc_squad += 1
	print("orc battle: squad size=%d (expected <=4), orcs_in_squad=%d (expected 1<=x<=2)" % [orc_squad.size(), orc_count_in_orc_squad])

	# --- Deterministic grid setup for precise terrain-rule testing. Terrain
	# rules are exercised directly via _resolve_battle_step, the shared
	# step-resolution function enemy movement uses (the player no longer
	# moves in battle). ---
	main._setup_battle_grid(orc_squad)
	main.battle_terrain.clear()

	# Rock blocks movement.
	main.battle_terrain[Vector2i(3, 2)] = {"type": "rock"}
	var rock_result = main._resolve_battle_step(Vector2i(2, 2), Vector2i(1, 0))
	print("rock blocks movement: moved=%s (expected false)" % [rock_result.moved])

	# Ledge: approaching from any direction other than its own one-way dir
	# just walks onto it and stops there (no vault, no fall) -- only moving
	# WITH its direction forces the clean hop-over below.
	main.battle_terrain.clear()
	main.battle_terrain[Vector2i(2, 1)] = {"type": "ledge", "dir": Vector2i(0, 1)}
	var ledge_wrong = main._resolve_battle_step(Vector2i(2, 2), Vector2i(0, -1))
	print("ledge from the wrong direction just walks onto it: tile=%s moved=%s (expected (2,1), true)" % [ledge_wrong.tile, ledge_wrong.moved])

	var ledge_right = main._resolve_battle_step(Vector2i(2, 0), Vector2i(0, 1))
	print("ledge correct-direction hops through: tile=%s moved=%s (expected (2,2), true)" % [ledge_right.tile, ledge_right.moved])

	# Cliff: fall damage unless landing tile is water.
	main.battle_terrain.clear()
	main.battle_terrain[Vector2i(2, 1)] = {"type": "cliff", "dir": Vector2i(0, 1)}
	var cliff_result = main._resolve_battle_step(Vector2i(2, 0), Vector2i(0, 1))
	print("cliff fall (no water below): tile=%s fell=%s (expected (2,2), true)" % [cliff_result.tile, cliff_result.fell])

	main.battle_terrain[Vector2i(2, 2)] = {"type": "water", "push_dir": Vector2i(0, 0)}
	var cliff_water_result = main._resolve_battle_step(Vector2i(2, 0), Vector2i(0, 1))
	print("cliff onto water takes no fall damage: tile=%s fell=%s (expected (2,2), false)" % [cliff_water_result.tile, cliff_water_result.fell])

	# Ledge direction blocks an adjacent (range-1) attack from the wrong
	# side, but a spear bypasses that restriction entirely.
	main.battle_terrain.clear()
	main.battle_terrain[Vector2i(2, 1)] = {"type": "ledge", "dir": Vector2i(0, 1)}
	var wrong_side_no_spear = main._can_battle_attack(Vector2i(2, 2), Vector2i(2, 1), 1)
	var wrong_side_spear = main._can_battle_attack(Vector2i(2, 2), Vector2i(2, 1), 2)
	var right_side_no_spear = main._can_battle_attack(Vector2i(2, 0), Vector2i(2, 1), 1)
	print("attack from wrong side of ledge: no_spear=%s (expected false), spear=%s (expected true)" % [wrong_side_no_spear, wrong_side_spear])
	print("attack from allowed side of ledge: no_spear=%s (expected true)" % [right_side_no_spear])

	# Bug fix: attacking from either PERPENDICULAR side of a ledge/cliff
	# (never involved the drop at all) must be allowed too -- only the exact
	# opposite of the tile's own vault direction (reaching up from below the
	# drop) stays blocked.
	var left_flank_no_spear = main._can_battle_attack(Vector2i(1, 1), Vector2i(2, 1), 1)
	var right_flank_no_spear = main._can_battle_attack(Vector2i(3, 1), Vector2i(2, 1), 1)
	print("attack from either side (perpendicular) of a ledge is allowed: left=%s right=%s (expected true, true)" % [left_flank_no_spear, right_flank_no_spear])

	# Enemy stats scale with player level -- higher level should mean
	# tougher, harder-hitting enemies in the next battle.
	player.level = 11
	main._setup_battle_grid(orc_squad)
	var scaled_orc = null
	for u in main.battle_units:
		if u.name == "Orc":
			scaled_orc = u
			break
	var expected_scale: float = 1.0 + (11 - 1) * main.ENEMY_LEVEL_SCALING
	var expected_hp: int = int(round(orc_script.MAX_HEALTH * expected_scale))
	print("enemy stats scale with player level: orc hp at lvl 11=%d (expected %d, base %d)" % [
		scaled_orc.max_hp, expected_hp, orc_script.MAX_HEALTH
	])

	# Player move range: 2 tiles at baseline agility, growing with agility,
	# and available every turn regardless of which action gets chosen.
	var player_script = load("res://scripts/Player.gd")
	player.stat_agility = player_script.AGILITY_START
	print("move range at baseline agility: %d (expected 2)" % [main._battle_player_move_range()])
	player.stat_agility = player_script.AGILITY_START + main.AGILITY_PER_EXTRA_MOVE
	print("move range after +%d agility: %d (expected 3)" % [main.AGILITY_PER_EXTRA_MOVE, main._battle_player_move_range()])

	main.in_battle = true
	main._setup_battle_grid(orc_squad)
	main.battle_terrain.clear()
	print("moves_left initialized from move range: %d (expected 3)" % [main.battle_player_moves_left])

	var tile_before_move: Vector2i = main.battle_player_tile
	main._try_battle_player_move(Vector2i(1, 0))
	print("moving doesn't end the turn: tile=%s moved=%s moves_left=%d turn=%s (expected changed, 2, player)" % [
		main.battle_player_tile, main.battle_player_tile != tile_before_move, main.battle_player_moves_left, main.battle_turn
	])

	main._battle_player_defend()
	print("move budget refreshes for the next player turn: moves_left=%d (expected 3)" % [main.battle_player_moves_left])

	quit()
