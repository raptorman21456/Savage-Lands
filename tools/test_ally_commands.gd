extends SceneTree

# The commanded ally-turn state machine (Main.gd:battle_commanding_ally): "you
# control allies, they get their own turns during your turn" -- after the hero's
# own turn, every living fielded ally gets its own Move/Attack/Guard/Skip phase,
# one at a time, in order, before the enemy turn begins. Mirrors
# test_battle_move_undo.gd's shape for the Move/Confirm/Cancel half of this.

func _make_goblin(main, tile: Vector2i, hp: int = 999) -> Dictionary:
	var goblin_script = load("res://scripts/Enemy.gd")
	var g = goblin_script.new()
	main.add_child(g)
	g.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	return {
		"ref": g, "tile": tile, "hp": hp, "max_hp": hp, "move_range": 2, "damage": 1,
		"name": "Goblin", "winding_up": false, "stunned": false, "attack_range": 1,
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
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(2, 2)

	# --- Starting the ally phase queues every living ally, then hands
	# control to the first one. ---
	var ally_a := {"tile": Vector2i(0, 0), "hp": 20, "max_hp": 20, "dmg_mult": 1.0, "name": "Ally A", "move_range": 2, "attack_range": 1}
	var ally_b := {"tile": Vector2i(0, 1), "hp": 20, "max_hp": 20, "dmg_mult": 1.0, "name": "Ally B", "move_range": 2, "attack_range": 1}
	var fainted := {"tile": Vector2i(0, 2), "hp": 0, "max_hp": 20, "dmg_mult": 1.0, "name": "Fainted", "move_range": 2, "attack_range": 1}
	main.battle_allies = [ally_a, ally_b, fainted]
	main.battle_units = [_make_goblin(main, Vector2i(5, 5))]
	main._start_ally_turn()
	print("the first living ally is handed control: commanding=%s (expected Ally A), moves_left=%d (expected 2)" % [
		main.battle_commanding_ally.name, main.battle_ally_moves_left
	])
	print("a fainted ally is skipped, never queued a turn: queue_size=%d (expected 1, just Ally B)" % [main.battle_ally_queue.size()])

	# --- Move: selecting it snapshots undo state; moving steps the tile and
	# spends from THIS ally's own budget, not the hero's. ---
	main._on_battle_ally_action("move")
	print("selecting Move enters move mode: state=%s (expected move), undo_tile=%s (expected (0,0))" % [
		main.battle_menu_state, main.battle_ally_move_undo_tile
	])
	main._try_battle_ally_move(Vector2i(1, 0))
	print("moving steps the ally's own tile and spends its own budget: tile=%s (expected (1,0)), moves_left=%d (expected 1), hero_moves_untouched=%d" % [
		ally_a.tile, main.battle_ally_moves_left, main.battle_player_moves_left
	])

	# --- Cancel fully reverts, same shape as the hero's own Move. ---
	main._on_battle_move_action("cancel")
	print("cancel reverts the ally's tile and budget: tile=%s (expected (0,0)), moves_left=%d (expected 2), state=%s (expected main)" % [
		ally_a.tile, main.battle_ally_moves_left, main.battle_menu_state
	])

	# --- Confirm keeps the new position without ending the ally's turn --
	# it can still Attack/Guard/Skip afterward, same as the hero's own Move. ---
	main._on_battle_ally_action("move")
	main._try_battle_ally_move(Vector2i(1, 0))
	main._on_battle_move_action("confirm")
	print("confirm keeps the position and returns to the ally's own main menu: tile=%s (expected (1,0)), state=%s (expected main), still_commanding=%s (expected Ally A)" % [
		ally_a.tile, main.battle_menu_state, main.battle_commanding_ally.name
	])

	# --- Attack out of range logs it but doesn't advance the queue --
	# nothing else to do here but try again after moving or just Skip. ---
	main._on_battle_ally_action("attack")
	print("attacking out of range does nothing and doesn't end the turn: hp_untouched=%s (expected true, still 999), still_commanding=%s (expected Ally A)" % [
		main.battle_units[0].hp == 999, main.battle_commanding_ally.name
	])

	# --- Guard: sets the flag, ends this ally's turn (hands off to Ally B), and
	# actually reduces damage taken until its next turn. ---
	main._on_battle_ally_action("guard")
	print("Guard ends the turn and hands off to the next ally: guarding=%s (expected true), commanding=%s (expected Ally B)" % [
		ally_a.defending, main.battle_commanding_ally.name
	])
	ally_a.hp = 1000
	var attacker := {"ref": null, "tile": Vector2i(2, 0)}
	main._enemy_apply_damage(attacker, ally_a.tile, 100, {})
	print("Guard actually halves the damage taken: hp=%d (expected %d, 1000 - 50)" % [ally_a.hp, 1000 - 50])

	# --- Skip ends the turn with no action, and Guard doesn't carry over. ---
	print("Ally B starts fresh, not guarding: guarding=%s (expected false)" % [ally_b.defending])
	main._on_battle_ally_action("skip")
	# The lone goblin's own turn runs synchronously right here too (nothing
	# in this scenario awaits a prompt) and hands control straight back to
	# the hero for a new round -- battle_turn reads "player" again, not
	# "enemy", by the time this call returns.
	print("Skip advances past the last ally, straight through the enemy's own turn and back to a new player turn: commanding=%s (expected null, queue empty), turn=%s (expected player)" % [
		main.battle_commanding_ally, main.battle_turn
	])

	# --- No moves left refuses Move, same guard the hero's own Move has. ---
	main.in_battle = true
	main.battle_units = [_make_goblin(main, Vector2i(5, 5))]
	main.battle_allies = [ally_a]
	ally_a.hp = 20
	main._start_ally_turn()
	main.battle_ally_moves_left = 0
	main._on_battle_ally_action("move")
	print("no moves left refuses Move: state=%s (expected main, not move)" % [main.battle_menu_state])

	# --- A commanded Attack that kills the last enemy resolves as an instant
	# victory rather than waiting on any allies still queued behind it. ---
	main.in_battle = true
	var lone_goblin := _make_goblin(main, Vector2i(1, 0), 1)
	main.battle_units = [lone_goblin]
	var killer := {"tile": Vector2i(0, 0), "hp": 20, "max_hp": 20, "dmg_mult": 1.0, "name": "Killer", "move_range": 2, "attack_range": 1}
	var bystander := {"tile": Vector2i(0, 1), "hp": 20, "max_hp": 20, "dmg_mult": 1.0, "name": "Bystander", "move_range": 2, "attack_range": 1}
	main.battle_allies = [killer, bystander]
	main.battle_target_index = 0
	main._start_ally_turn()
	main._on_battle_ally_action("attack")
	print("a commanded kill on the last enemy resolves as an instant victory: in_battle=%s (expected false), commanding=%s (expected null)" % [
		main.in_battle, main.battle_commanding_ally
	])

	quit()
