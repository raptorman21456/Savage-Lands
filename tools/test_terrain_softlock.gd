extends SceneTree

func _all_neighbors_are_rock(main, t: Vector2i) -> bool:
	for dir in main.CARDINAL_DIRS:
		var n: Vector2i = t + dir
		if not main._in_battle_bounds(n):
			continue
		var terrain = main.battle_terrain.get(n, null)
		if terrain == null or terrain.type != "rock":
			return false
	return true

# Mirrors _resolve_battle_step's actual blocking rule: Rock/Rubble are the
# only tiles that ever fully block a step. A ledge/cliff is walkable from
# any direction now (only moving WITH its own dir triggers the one-way
# vault instead of just stopping on it), so it's never a dead end by itself.
func _all_neighbors_effectively_blocked(main, t: Vector2i) -> bool:
	for dir in main.CARDINAL_DIRS:
		var n: Vector2i = t + dir
		if not main._in_battle_bounds(n):
			continue
		var terrain = main.battle_terrain.get(n, null)
		if terrain == null or not (terrain.type in ["rock", "rubble"]):
			return false
	return true

func _init() -> void:
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var player = main.player
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	# --- The player, boxed in on all 3 sides at a grid edge, always keeps
	# at least one way out after the repair pass. ---
	main.battle_units = []
	main.battle_player_tile = Vector2i(0, 2)
	main.battle_terrain = {
		Vector2i(0, 1): {"type": "rock"},
		Vector2i(0, 3): {"type": "rock"},
		Vector2i(1, 2): {"type": "rock"},
	}
	print("player edge tile starts fully boxed in by rocks: %s (expected true)" % [_all_neighbors_are_rock(main, main.battle_player_tile)])
	main._prevent_boxed_in_units()
	print("repair pass frees at least one side: %s (expected false, no longer fully boxed)" % [_all_neighbors_are_rock(main, main.battle_player_tile)])

	# --- Same thing for a corner tile (only 2 neighbors, both rocks). ---
	main.battle_player_tile = Vector2i(0, 0)
	main.battle_terrain = {
		Vector2i(1, 0): {"type": "rock"},
		Vector2i(0, 1): {"type": "rock"},
	}
	print("player corner tile starts fully boxed in: %s (expected true)" % [_all_neighbors_are_rock(main, main.battle_player_tile)])
	main._prevent_boxed_in_units()
	print("repair pass frees the corner too: %s (expected false)" % [_all_neighbors_are_rock(main, main.battle_player_tile)])

	# --- An edge-positioned enemy gets the same protection. Tile x=7 is the
	# actual last column of the current 8x8 default grid (BATTLE_GRID_W) --
	# x=5 stopped being the edge once the grid grew past its old 6x6 size. ---
	var goblin_script = load("res://scripts/Enemy.gd")
	var goblin = goblin_script.new()
	main.add_child(goblin)
	main.battle_player_tile = Vector2i(3, 3)
	main.battle_units = [{
		"ref": goblin, "tile": Vector2i(7, 2), "hp": 3, "max_hp": 3, "move_range": 2,
		"damage": 1, "name": "Goblin", "winding_up": false, "stunned": false, "size": 1, "attack_range": 1,
	}]
	main.battle_terrain = {
		Vector2i(6, 2): {"type": "rock"},
		Vector2i(7, 1): {"type": "rock"},
		Vector2i(7, 3): {"type": "rock"},
	}
	print("an edge-positioned enemy starts fully boxed in: %s (expected true)" % [_all_neighbors_are_rock(main, main.battle_units[0].tile)])
	main._prevent_boxed_in_units()
	print("repair pass frees the enemy too: %s (expected false)" % [_all_neighbors_are_rock(main, main.battle_units[0].tile)])

	# --- A terrain-ignoring 2x2 Brute is deliberately NOT covered -- it
	# can't be boxed in by rocks in the first place, so the repair pass
	# should leave its surrounding rocks alone. ---
	var brute_script = load("res://scripts/Brute.gd")
	var brute = brute_script.new()
	main.add_child(brute)
	main.battle_player_tile = Vector2i(0, 0)
	main.battle_units = [{
		"ref": brute, "tile": Vector2i(2, 2), "hp": 35, "max_hp": 35, "move_range": 1,
		"damage": 3, "name": "Brute", "winding_up": false, "stunned": false, "size": 2, "attack_range": 1,
	}]
	main.battle_terrain = {
		Vector2i(1, 2): {"type": "rock"}, Vector2i(1, 3): {"type": "rock"},
		Vector2i(2, 1): {"type": "rock"}, Vector2i(3, 1): {"type": "rock"},
		Vector2i(4, 2): {"type": "rock"}, Vector2i(4, 3): {"type": "rock"},
		Vector2i(2, 4): {"type": "rock"}, Vector2i(3, 4): {"type": "rock"},
	}
	var rocks_before: int = main.battle_terrain.size()
	main._prevent_boxed_in_units()
	print("a fully-surrounded brute is left alone (it ignores terrain anyway): rocks_unchanged=%s (expected true)" % [main.battle_terrain.size() == rocks_before])

	# --- The real _setup_battle_grid path never produces a boxed-in player,
	# across many random rolls. ---
	var goblin_script2 = load("res://scripts/Enemy.gd")
	var any_boxed := false
	for i in 200:
		var squad_member = goblin_script2.new()
		main.add_child(squad_member)
		main._setup_battle_grid([squad_member])
		if _all_neighbors_are_rock(main, main.battle_player_tile):
			any_boxed = true
		squad_member.queue_free()
	print("the real battle setup never boxes the player in, over 200 rolls: any_boxed=%s (expected false)" % [any_boxed])

	# --- A wrong-direction cliff is no longer a dead end -- you can now walk
	# onto it from any side (just without the vault/fall), so 3 rocks plus a
	# cliff facing away from the player is a real escape, not a box-in. The
	# repair pass must leave it untouched. ---
	main.battle_units = []
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_terrain = {
		Vector2i(1, 2): {"type": "rock"},
		Vector2i(2, 1): {"type": "rock"},
		Vector2i(2, 3): {"type": "rock"},
		Vector2i(3, 2): {"type": "cliff", "dir": Vector2i(-1, 0)},
	}
	print("a wrong-direction cliff is NOT a box-in anymore -- it's walkable from any side: truly_boxed=%s (expected false)" % [
		_all_neighbors_effectively_blocked(main, main.battle_player_tile)
	])
	main._prevent_boxed_in_units()
	print("repair pass leaves a wrong-direction cliff exit untouched too: cliff_still_there=%s (expected true)" % [main.battle_terrain.has(Vector2i(3, 2))])

	# --- A correctly-facing cliff is also a real way out, same as before. ---
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_terrain = {
		Vector2i(1, 2): {"type": "rock"},
		Vector2i(2, 1): {"type": "rock"},
		Vector2i(2, 3): {"type": "rock"},
		Vector2i(3, 2): {"type": "cliff", "dir": Vector2i(1, 0)},
	}
	print("a correctly-facing cliff is a real escape, not a box-in: truly_boxed=%s (expected false)" % [_all_neighbors_effectively_blocked(main, main.battle_player_tile)])
	main._prevent_boxed_in_units()
	print("repair pass leaves a valid cliff exit untouched: cliff_still_there=%s (expected true)" % [main.battle_terrain.has(Vector2i(3, 2))])

	# --- Only Rock/Rubble still count as real dead ends -- 3 rocks plus a
	# rubble on the last side IS a genuine box-in, and the repair pass must
	# open one of them back up. ---
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_terrain = {
		Vector2i(1, 2): {"type": "rock"},
		Vector2i(2, 1): {"type": "rock"},
		Vector2i(2, 3): {"type": "rock"},
		Vector2i(3, 2): {"type": "rubble"},
	}
	print("rock+rubble on all 4 sides is a genuine box-in: truly_boxed=%s (expected true)" % [_all_neighbors_effectively_blocked(main, main.battle_player_tile)])
	main._prevent_boxed_in_units()
	print("repair pass frees a rock+rubble box-in too: %s (expected false)" % [_all_neighbors_effectively_blocked(main, main.battle_player_tile)])

	# --- The actual reported softlock: a tile NOBODY starts on (not the
	# player's or any unit's spawn tile) can still be boxed in by rock on
	# every in-bounds side -- e.g. a grid-corner tile a player later walks
	# or vaults (one-way ledge/cliff) into mid-battle. The old version of
	# this function only ever checked occupied tiles at setup time and would
	# have left this one alone; the full-grid sweep must catch it too. ---
	main.battle_units = []
	main.battle_player_tile = Vector2i(4, 4)
	var corner_tile := Vector2i(0, 4)
	main.battle_terrain = {
		Vector2i(0, 3): {"type": "rock"},
		Vector2i(0, 5): {"type": "rock"},
		Vector2i(1, 4): {"type": "rock"},
	}
	print("an unoccupied grid-edge tile nobody starts on is still boxed in by rock: %s (expected true)" % [_all_neighbors_are_rock(main, corner_tile)])
	main._prevent_boxed_in_units()
	print("the full-grid sweep frees it too, even though nothing was standing there: %s (expected false)" % [_all_neighbors_are_rock(main, corner_tile)])

	quit()
