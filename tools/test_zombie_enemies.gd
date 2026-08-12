extends SceneTree

# Builds a battle_units entry the same way _setup_battle_grid does --
# move_range/attack_range/size pulled from the real ENEMY_TRAITS table
# instead of hand-typed, so a future trait change can't silently desync
# this test the way a hardcoded "attack_range" once did.
func _make_unit(main, ref, tile: Vector2i, hp: int, max_hp: int, name: String, damage: int) -> Dictionary:
	var traits: Dictionary = main.ENEMY_TRAITS.get(name, {})
	return {
		"ref": ref, "tile": tile, "hp": hp, "max_hp": max_hp,
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
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	var centaur_script = load("res://scripts/Centaur.gd")
	var goblin_script = load("res://scripts/Enemy.gd")
	var fall_dmg: int = int(round(100 * main.CLIFF_FALL_DAMAGE_PCT))

	# --- A Centaur Archer that dies mid-retreat (kiting off a cliff) must
	# not keep acting -- no attack this turn, removed from battle_units, and
	# the now-empty squad ends the battle. "kites" now lives on Centaur
	# Archer (ENEMY_TRAITS in Main.gd) -- the plain Archer/Apprentice Mage
	# doesn't kite anymore, so this needs an actual bow roll, not just a
	# renamed Archer. ---
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(4, 2)
	main.battle_player_defending = false
	player.health = player.max_health
	var archer = centaur_script.new()
	while not archer.has_bow:
		archer.free()
		archer = centaur_script.new()
	main.add_child(archer)
	archer.died.connect(main._on_enemy_died)
	main.enemies_alive = 1
	# Archer stands at (3,2), adjacent to the player at (4,2) -- cornered, so
	# it retreats left. The retreat step lands ON the cliff at (2,2) (the
	# tile it steps onto, not the tile it starts from), hopping to (1,2).
	main.battle_terrain[Vector2i(2, 2)] = {"type": "cliff", "dir": Vector2i(-1, 0)}
	main.battle_units = [_make_unit(main, archer, Vector2i(3, 2), fall_dmg - 1, 100, archer.get_display_name(), 1)]
	main._process_enemy_turn()
	print("archer that dies retreating off a cliff is removed, not left acting: battle_units_left=%d (expected 0), player_health=%d (expected unchanged %d), enemies_alive=%d (expected 0), battle_ended=%s (expected true)" % [
		main.battle_units.size(), player.health, player.max_health, main.enemies_alive, not main.in_battle
	])

	# --- A Goblin chasing the player across a cliff dies from the fall
	# before ever reaching attack range -- same requirements: removed, no
	# attack landed. A second, untouched Goblin confirms the squad-sweep
	# doesn't disturb survivors or end the battle early. ---
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(0, 2)
	main.battle_player_defending = false
	player.health = player.max_health
	var goblin_chaser = goblin_script.new()
	main.add_child(goblin_chaser)
	goblin_chaser.died.connect(main._on_enemy_died)
	var goblin_survivor = goblin_script.new()
	main.add_child(goblin_survivor)
	goblin_survivor.died.connect(main._on_enemy_died)
	main.enemies_alive = 2
	main.battle_terrain[Vector2i(2, 2)] = {"type": "cliff", "dir": Vector2i(-1, 0)}
	var chaser := _make_unit(main, goblin_chaser, Vector2i(3, 2), fall_dmg - 1, 100, "Goblin", 1)
	var survivor := _make_unit(main, goblin_survivor, Vector2i(3, 5), 999, 999, "Goblin", 1)
	main.battle_units = [chaser, survivor]
	main._process_enemy_turn()
	var chaser_gone: bool = true
	var survivor_left = null
	for u in main.battle_units:
		if u.ref == goblin_chaser:
			chaser_gone = false
		if u.ref == goblin_survivor:
			survivor_left = u
	print("goblin that dies chasing across a cliff is removed without attacking: chaser_gone=%s (expected true), player_health=%d (expected unchanged %d)" % [
		chaser_gone, player.health, player.max_health
	])
	print("a surviving squadmate is untouched by the dead unit's sweep: survivor_still_present=%s (expected true), battle_still_active=%s (expected true)" % [
		survivor_left != null, main.in_battle
	])

	quit()
