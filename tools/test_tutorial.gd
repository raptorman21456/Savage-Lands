extends SceneTree

# Covers the first-ever-battle interactive tutorial: device-wide gating,
# solo-squad forcing + enemy-tile pinning (so the Move->Fight sequence is
# always completable), per-step action gating, hint advancement, Skip, and
# that completion is device-wide (survives an active_slot switch) and lifts
# gating immediately within the same fight.
#
# Movement while in "move" mode is set directly on battle_player_tile
# (matching tools/test_battle_buttons.gd's convention for battle-state
# setup) rather than simulating arrow-key input -- the key-driven movement
# pipeline itself is already covered by tools/test_battle_move_keyboard.gd,
# and simulating it here on top of everything else this test drives added
# real frame-timing flakiness with nothing left to prove.

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var save_data_script = load("res://scripts/SaveData.gd")
	var lifetime_path: String = save_data_script._resolve_lifetime_path()
	if FileAccess.file_exists(lifetime_path):
		DirAccess.remove_absolute(lifetime_path)

	print("fresh lifetime data starts with the tutorial uncompleted: %s (expected true)" % [
		not save_data_script.is_tutorial_completed_ever()
	])

	# --- Scenario 1: play the tutorial through to completion naturally. ---
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	var player = main.player
	var goblin_script = load("res://scripts/Enemy.gd")
	var goblin = goblin_script.new()
	main.add_child(goblin)
	goblin.global_position = player.global_position + Vector2(30, 0)
	# A second enemy planted well within BATTLE_GATHER_RADIUS -- proves
	# squad-forcing actually overrides _gather_squad's normal proximity pull.
	var goblin2 = goblin_script.new()
	main.add_child(goblin2)
	goblin2.global_position = player.global_position + Vector2(35, 0)

	main.trigger_battle(goblin)
	await process_frame

	print("first-ever battle forces a solo squad despite a nearby second enemy: squad_size=%d (expected 1)" % [main.battle_units.size()])
	print("tutorial_active starts true at step 0 (Move): active=%s step=%d (expected true, 0)" % [main.tutorial_active, main.tutorial_step])

	var enemy_tile: Vector2i = main.battle_units[0].tile
	print("the tutorial enemy is pinned onto the player's row, within move+attack reach: same_row=%s within_reach=%s (expected true, true)" % [
		enemy_tile.y == main.battle_player_tile.y,
		enemy_tile.x <= main.battle_player_tile.x + main.PLAYER_BASE_MOVE_RANGE + 1
	])

	# --- Step 0 (Move): only Move is allowed. ---
	main.hud.battle_main_buttons["fight"].pressed.emit()
	print("step 0 blocks Fight: menu_state=%s (expected main)" % [main.battle_menu_state])
	main.hud.battle_main_buttons["defend"].pressed.emit()
	print("step 0 blocks Defend: still_defending=%s turn=%s (expected false, player)" % [main.battle_player_defending, main.battle_turn])

	main.hud.battle_main_buttons["move"].pressed.emit()
	print("step 0 allows Move: menu_state=%s (expected move)" % [main.battle_menu_state])

	# Move only 1 of the 2 available tiles -- the enemy is pinned exactly
	# PLAYER_BASE_MOVE_RANGE+1 tiles away, so this deliberately leaves it
	# still 1 tile out of melee range, with 1 move point left over, to
	# actually exercise the Fight step's Move-fallback below (rather than
	# just asserting it's allowed without ever needing it).
	main.battle_player_tile += Vector2i(1, 0)
	main.battle_player_moves_left -= 1
	main.hud.battle_move_buttons["confirm"].pressed.emit()
	print("confirming Move advances to step 1 (Fight), gap not yet closed: step=%d moves_left=%d x_distance=%d (expected 1, 1, 2)" % [
		main.tutorial_step, main.battle_player_moves_left, main.battle_units[0].tile.x - main.battle_player_tile.x
	])

	# --- Step 1 (Fight): Move stays allowed as a fallback (used here to
	# finish closing the gap), Defend blocked, Heavy Attack blocked (only a
	# regular Attack counts). ---
	main.hud.battle_main_buttons["defend"].pressed.emit()
	print("step 1 still blocks Defend: still_defending=%s (expected false)" % [main.battle_player_defending])

	main.hud.battle_main_buttons["move"].pressed.emit()
	print("step 1 still allows Move as a softlock-avoidance fallback: menu_state=%s (expected move)" % [main.battle_menu_state])
	main.battle_player_tile += Vector2i(1, 0)
	main.battle_player_moves_left -= 1
	main.hud.battle_move_buttons["confirm"].pressed.emit()
	print("the fallback Move closes the rest of the gap to melee range: x_distance=%d (expected 1)" % [
		main.battle_units[0].tile.x - main.battle_player_tile.x
	])

	main.hud.battle_main_buttons["fight"].pressed.emit()
	var stamina_before: int = player.stamina
	main.hud.battle_fight_buttons["heavy"].pressed.emit()
	print("step 1 blocks Heavy Attack: stamina_unspent=%s tutorial_step=%d (expected true, 1)" % [
		player.stamina == stamina_before, main.tutorial_step
	])

	var enemy_hp_before: int = main.battle_units[0].hp
	main.hud.battle_fight_buttons["attack"].pressed.emit()
	print("a regular Attack in step 1 lands a hit and advances to step 2 (Defend): dealt=%d step=%d (expected >0, 2)" % [
		enemy_hp_before - main.battle_units[0].hp, main.tutorial_step
	])

	# --- Step 2 (Defend): only Defend allowed; performing it completes the
	# tutorial and immediately lifts all gating. ---
	main.hud.battle_main_buttons["move"].pressed.emit()
	print("step 2 blocks Move: menu_state=%s (expected main)" % [main.battle_menu_state])

	main.hud.battle_main_buttons["defend"].pressed.emit()
	print("Defend in step 2 completes the tutorial: active=%s completed_ever=%s (expected false, true)" % [
		main.tutorial_active, save_data_script.is_tutorial_completed_ever()
	])
	print("gating is lifted immediately, mid-fight: fight_blocked_now=%s (expected false)" % [
		main.tutorial_active and not main._tutorial_action_allowed("fight")
	])

	# --- Device-wide, not per-slot: survives an active_slot switch. ---
	save_data_script.active_slot = 2
	print("completion persists across an active_slot switch (device-wide): %s (expected true)" % [
		save_data_script.is_tutorial_completed_ever()
	])
	save_data_script.active_slot = 1

	# --- A second battle no longer forces a solo squad or gates anything. ---
	main.in_battle = false
	paused = false
	var goblin3 = goblin_script.new()
	main.add_child(goblin3)
	goblin3.global_position = player.global_position + Vector2(30, 0)
	var goblin4 = goblin_script.new()
	main.add_child(goblin4)
	goblin4.global_position = player.global_position + Vector2(35, 0)
	main.trigger_battle(goblin3)
	await process_frame
	print("a later battle is no longer tutorial-gated: tutorial_active=%s squad_size=%d (expected false, 2)" % [
		main.tutorial_active, main.battle_units.size()
	])

	main.queue_free()
	await process_frame

	# --- Scenario 2: Skip completes the tutorial early, from any step. ---
	if FileAccess.file_exists(lifetime_path):
		DirAccess.remove_absolute(lifetime_path)

	var main2_scene = load("res://Main.tscn")
	var main2 = main2_scene.instantiate()
	root.add_child(main2)
	await physics_frame
	await physics_frame

	for e in main2.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	var goblin5 = goblin_script.new()
	main2.add_child(goblin5)
	goblin5.global_position = main2.player.global_position + Vector2(30, 0)
	main2.trigger_battle(goblin5)
	await process_frame

	print("scenario 2 starts a fresh tutorial: active=%s step=%d (expected true, 0)" % [main2.tutorial_active, main2.tutorial_step])
	main2._on_tutorial_skip_pressed()
	print("Skip completes the tutorial immediately, without reaching Defend: active=%s completed_ever=%s (expected false, true)" % [
		main2.tutorial_active, save_data_script.is_tutorial_completed_ever()
	])

	main2.queue_free()
	await process_frame

	quit()
