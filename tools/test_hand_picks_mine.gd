extends SceneTree

# Hand Picks' "Mine" action: target and break a rock/rubble tile next to the
# player. Mirrors the enemy-targeting shape (battle_target_index /
# _effective_target_index) with battle_rock_target / _effective_rock_target,
# driven by a click reported through HUD.gd's per-tile gui_input.

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var weapons_script = load("res://scripts/Weapons.gd")
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player

	main.in_battle = true
	main.battle_turn = "player"
	main.battle_player_tile = Vector2i(4, 4)
	main.battle_rock_target = Vector2i(-1, -1)

	# --- Weapon gating: only Hand Picks can ever target a rock. ---
	player.current_weapon = weapons_script.CLUB
	print("Club can't target rocks: %s (expected false)" % [main._player_has_hand_picks()])
	player.current_weapon = weapons_script.HAND_PICKS
	print("Hand Picks can: %s (expected true)" % [main._player_has_hand_picks()])

	# --- Targetable rocks: only cardinal-adjacent rock/rubble, nothing
	# diagonal and nothing farther out. ---
	main.battle_terrain = {
		Vector2i(5, 4): {"type": "rock"},
		Vector2i(3, 4): {"type": "rubble"},
		Vector2i(5, 5): {"type": "rock"},  # diagonal -- not adjacent
		Vector2i(6, 4): {"type": "rock"},  # 2 tiles away -- out of reach
		Vector2i(4, 3): {"type": "water", "push_dir": Vector2i(0, 1)},  # adjacent, but not minable
	}
	var targetable: Array = main._targetable_rock_tiles()
	print("Only the 2 real cardinal-adjacent rock/rubble tiles are targetable: %d (expected 2)" % [targetable.size()])
	print("...specifically the rock and the rubble, not the diagonal/far/water ones: %s (expected true)" % [
		Vector2i(5, 4) in targetable and Vector2i(3, 4) in targetable and targetable.size() == 2
	])

	# --- _effective_rock_target falls back to the first targetable rock
	# when nothing (or something stale) is explicitly selected. ---
	main.battle_rock_target = Vector2i(-1, -1)
	print("No explicit selection falls back to a targetable rock: %s (expected true)" % [main._effective_rock_target() in targetable])
	main.battle_rock_target = Vector2i(9, 9)  # stale/never-valid selection
	print("A stale selection also falls back rather than sticking: %s (expected true)" % [main._effective_rock_target() in targetable])
	main.battle_rock_target = Vector2i(3, 4)
	print("A still-valid explicit selection is kept, not overridden: %s (expected (3, 4))" % [main._effective_rock_target()])

	# --- Clicking (via _on_rock_target_selected) only does anything on the
	# player's own turn, and only for an actually-targetable tile. ---
	main.battle_rock_target = Vector2i(-1, -1)
	main.battle_turn = "enemy"
	main._on_rock_target_selected(Vector2i(5, 4))
	print("A click during the enemy's turn is ignored: battle_rock_target=%s (expected (-1, -1))" % [main.battle_rock_target])
	main.battle_turn = "player"
	main._on_rock_target_selected(Vector2i(4, 4))  # the player's own tile -- not a rock
	print("A click on a non-targetable tile is ignored: battle_rock_target=%s (expected (-1, -1))" % [main.battle_rock_target])
	main._on_rock_target_selected(Vector2i(5, 4))
	print("A click on a real targetable rock selects it: battle_rock_target=%s (expected (5, 4))" % [main.battle_rock_target])

	# --- Mining breaks the tile, ends the turn, and clears the selection.
	# battle_turn flips to "ally" via _end_player_turn -- confirms the action
	# actually consumed the turn, same as any other Fight option. ---
	main._resolve_mine_rock()
	print("Mining removes the rock from battle_terrain: %s (expected false, tile gone)" % [main.battle_terrain.has(Vector2i(5, 4))])
	print("...clears the selection: battle_rock_target=%s (expected (-1, -1))" % [main.battle_rock_target])
	print("...and consumes the turn: battle_turn=%s (expected ally)" % [main.battle_turn])

	# --- Rubble breaks the same way. ---
	main.battle_turn = "player"
	main._on_rock_target_selected(Vector2i(3, 4))
	main._resolve_mine_rock()
	print("Mining also works on Rubble: %s (expected false, tile gone)" % [main.battle_terrain.has(Vector2i(3, 4))])

	# --- With nothing left in reach, mining is a harmless no-op -- doesn't
	# end the turn or touch battle_terrain. ---
	main.battle_turn = "player"
	var terrain_size_before: int = main.battle_terrain.size()
	main._resolve_mine_rock()
	print("Mining with nothing in reach is a no-op: terrain_unchanged=%s battle_turn_unchanged=%s (expected true, true)" % [
		main.battle_terrain.size() == terrain_size_before, main.battle_turn == "player"
	])

	# --- battle_rock_target resets with the rest of the battle-scoped state. ---
	main.battle_rock_target = Vector2i(2, 2)
	main._setup_battle_grid([])
	print("battle_rock_target resets at the start of a new battle: %s (expected (-1, -1))" % [main.battle_rock_target])

	quit()
