extends SceneTree

# Squad coordination AI: cross-unit target deconfliction (_assign_enemy_targets)
# and formation holding (a ranged/ignore_line attacker not pushing forward
# past a melee ally that's already screening its target).

func _init() -> void:
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var goblin_script = load("res://scripts/Enemy.gd")
	var mage_script = load("res://scripts/Archer.gd")

	main.in_battle = true
	main.battle_terrain.clear()

	# --- No living ally: only one valid target exists, so there's nothing to
	# split -- _assign_enemy_targets returns an empty map and every unit
	# falls back to _pick_enemy_target_tile's plain nearest-target behavior
	# (handled by _process_enemy_turn's own .get(u.ref, _pick_enemy_target_tile(u))
	# fallback, not tested again here). ---
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_allies = []
	var solo_goblin_ref = goblin_script.new()
	main.add_child(solo_goblin_ref)
	main.battle_units = [{"ref": solo_goblin_ref, "tile": Vector2i(3, 2), "hp": 10, "max_hp": 10, "move_range": 2, "damage": 1, "name": "Goblin", "winding_up": false, "stunned": false, "attack_range": 1}]
	print("with no living ally, there's nothing to split -- assign map is empty: %s (expected true)" % [main._assign_enemy_targets().is_empty()])
	solo_goblin_ref.queue_free()
	await physics_frame

	# --- A clear, unambiguous nearest target (no tie) -- every unit's
	# assignment matches exactly what _pick_enemy_target_tile alone would
	# already give it. ---
	main.battle_allies = [{"tile": Vector2i(7, 7), "hp": 20, "max_hp": 20, "dmg_mult": 1.0, "name": "Blade Ally", "move_range": 2, "attack_range": 1}]
	var clear_goblin_ref = goblin_script.new()
	main.add_child(clear_goblin_ref)
	var clear_goblin := {"ref": clear_goblin_ref, "tile": Vector2i(3, 2), "hp": 10, "max_hp": 10, "move_range": 2, "damage": 1, "name": "Goblin", "winding_up": false, "stunned": false, "attack_range": 1}
	main.battle_units = [clear_goblin]
	var clear_assigned: Dictionary = main._assign_enemy_targets()
	print("with an unambiguous nearest target, the assignment matches _pick_enemy_target_tile exactly: %s (expected true)" % [
		clear_assigned.get(clear_goblin_ref, Vector2i(-1, -1)) == main._pick_enemy_target_tile(clear_goblin)
	])
	clear_goblin_ref.queue_free()
	await physics_frame

	# --- A genuine tie: two goblins, each equidistant (within tolerance)
	# between the player and a living ally, end up split across both targets
	# instead of both converging on the same one. ---
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_allies = [{"tile": Vector2i(4, 2), "hp": 20, "max_hp": 20, "dmg_mult": 1.0, "name": "Blade Ally", "move_range": 2, "attack_range": 1}]
	var ally_tile: Vector2i = main.battle_allies[0].tile

	var goblin_a_ref = goblin_script.new()
	main.add_child(goblin_a_ref)
	var goblin_b_ref = goblin_script.new()
	main.add_child(goblin_b_ref)
	# (3,2): dist 1 to the player, dist 1 to the ally -- an exact tie.
	# (3,1): dist 2 to the player, dist 2 to the ally -- also an exact tie.
	main.battle_units = [
		{"ref": goblin_a_ref, "tile": Vector2i(3, 2), "hp": 10, "max_hp": 10, "move_range": 2, "damage": 1, "name": "Goblin", "winding_up": false, "stunned": false, "attack_range": 1},
		{"ref": goblin_b_ref, "tile": Vector2i(3, 1), "hp": 10, "max_hp": 10, "move_range": 2, "damage": 1, "name": "Goblin", "winding_up": false, "stunned": false, "attack_range": 1},
	]
	var tied_assigned: Dictionary = main._assign_enemy_targets()
	var target_a: Vector2i = tied_assigned.get(goblin_a_ref, Vector2i(-1, -1))
	var target_b: Vector2i = tied_assigned.get(goblin_b_ref, Vector2i(-1, -1))
	var both_valid: bool = target_a in [main.battle_player_tile, ally_tile] and target_b in [main.battle_player_tile, ally_tile]
	print("a genuine tie splits the two enemies across both valid targets instead of both picking the same one: both_valid=%s (expected true), split=%s (expected true)" % [
		both_valid, target_a != target_b
	])
	goblin_a_ref.queue_free()
	goblin_b_ref.queue_free()
	await physics_frame

	# --- Formation holding: a ranged (ignore_line) attacker out of its own
	# attack_range doesn't push forward past a melee ally that's already
	# closer to the shared target -- it holds its tile this turn instead of
	# advancing past the screen. ---
	main.battle_player_tile = Vector2i(0, 0)
	main.battle_allies = []
	var mage_ref = mage_script.new()
	main.add_child(mage_ref)
	var screen_ref = goblin_script.new()
	main.add_child(screen_ref)
	var mage_start_tile := Vector2i(6, 0)
	main.battle_units = [
		{"ref": mage_ref, "tile": mage_start_tile, "hp": 6, "max_hp": 6, "move_range": 2, "damage": 1, "name": "Apprentice Mage", "winding_up": false, "stunned": false, "attack_range": 4},
		{"ref": screen_ref, "tile": Vector2i(3, 0), "hp": 10, "max_hp": 10, "move_range": 2, "damage": 1, "name": "Goblin", "winding_up": false, "stunned": false, "attack_range": 1},
	]
	main._process_enemy_turn()
	print("a screened ranged attacker holds its tile instead of advancing past its melee ally: tile=%s (expected unchanged %s)" % [
		main.battle_units[0].tile, mage_start_tile
	])

	# --- Contrast: the exact same ranged attacker, alone (no melee ally to
	# screen it), advances toward its target normally -- formation holding
	# only ever kicks in when there's actually something to hold behind. ---
	var mage2_ref = mage_script.new()
	main.add_child(mage2_ref)
	main.battle_units = [
		{"ref": mage2_ref, "tile": mage_start_tile, "hp": 6, "max_hp": 6, "move_range": 2, "damage": 1, "name": "Apprentice Mage", "winding_up": false, "stunned": false, "attack_range": 4},
	]
	main._process_enemy_turn()
	print("with no ally to screen it, the same ranged attacker advances as normal: moved=%s (expected true)" % [
		main.battle_units[0].tile != mage_start_tile
	])

	mage_ref.queue_free()
	screen_ref.queue_free()
	mage2_ref.queue_free()
	await physics_frame

	main.queue_free()
	await process_frame
	quit()
