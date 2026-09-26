extends SceneTree

func _init() -> void:
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

	main.in_battle = true
	main.battle_player_tile = Vector2i(2, 2)

	# Plain knockback: pushed one tile straight back from the attacker.
	# Tested via a direct call -- going through the full _battle_player_fight
	# would immediately cascade into the enemy's own turn (_end_player_turn),
	# and a goblin's move_range of 2 would just walk it right back adjacent,
	# masking the effect being tested here.
	var goblin = goblin_script.new()
	main.add_child(goblin)
	var u1 := {
		"ref": goblin, "tile": Vector2i(3, 2), "hp": 999, "max_hp": 999,
		"move_range": 2, "damage": 1, "name": "Goblin", "winding_up": false, "stunned": false,
	}
	main.battle_terrain.clear()
	main._apply_knockback(u1, Vector2i(1, 0))
	print("plain knockback pushes back a tile: tile=%s (expected (4, 2))" % [u1.tile])

	# Knockback into a rock stuns the target instead of moving it.
	var goblin2 = goblin_script.new()
	main.add_child(goblin2)
	var u2 := {
		"ref": goblin2, "tile": Vector2i(3, 2), "hp": 999, "max_hp": 999,
		"move_range": 2, "damage": 1, "name": "Goblin", "winding_up": false, "stunned": false,
	}
	main.battle_terrain.clear()
	main.battle_terrain[Vector2i(4, 2)] = {"type": "rock"}
	main._apply_knockback(u2, Vector2i(1, 0))
	print("knockback into a rock stuns instead of moving: tile=%s (expected (3,2) unchanged), stunned=%s (expected true)" % [
		u2.tile, u2.stunned
	])

	# End-to-end: attacking an enemy pinned against a rock stuns it via
	# knockback, so it can't counter-attack that same round even though it's
	# adjacent -- the stun gets consumed harmlessly on its own turn instead.
	var goblin3 = goblin_script.new()
	main.add_child(goblin3)
	goblin3.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	main.battle_terrain.clear()
	main.battle_terrain[Vector2i(4, 2)] = {"type": "rock"}
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_target_index = 0
	main.battle_units = [{
		"ref": goblin3, "tile": Vector2i(3, 2), "hp": 999, "max_hp": 999,
		"move_range": 2, "damage": 50, "name": "Goblin", "winding_up": false, "stunned": false,
	}]
	main.battle_player_defending = false
	player.health = player.max_health
	main._battle_player_fight()
	print("pinning an enemy against a rock stuns it, skipping its counter-attack: player_health=%d (expected unchanged %d), tile=%s (expected (3,2) unchanged)" % [
		player.health, player.max_health, main.battle_units[0].tile
	])

	# Knockback off a cliff deals fall damage, and can finish off a target
	# that survived the initial hit but not the fall damage on top of it.
	player.stat_strength = 5
	player.attack_damage = 5
	var expected_fall_dmg: int = int(round(100 * main.CLIFF_FALL_DAMAGE_PCT))
	var goblin4 = goblin_script.new()
	main.add_child(goblin4)
	goblin4.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	main.battle_terrain.clear()
	main.battle_terrain[Vector2i(4, 2)] = {"type": "cliff", "dir": Vector2i(1, 0)}
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_target_index = 0
	main.battle_units = [{
		"ref": goblin4, "tile": Vector2i(3, 2), "hp": 5 + expected_fall_dmg - 1, "max_hp": 100,
		"move_range": 2, "damage": 1, "name": "Goblin", "winding_up": false, "stunned": false,
	}]
	main._battle_player_fight()
	print("fall damage on top of the hit finishes off a survivor: battle_units_left=%d (expected 0)" % [main.battle_units.size()])

	# Orcs sometimes resist knockback outright (direct call, same isolation
	# reasoning as the plain-knockback test above).
	var resisted_count := 0
	for i in 60:
		var orc = orc_script.new()
		main.add_child(orc)
		var u_orc := {
			"ref": orc, "tile": Vector2i(3, 2), "hp": 9999, "max_hp": 9999,
			"move_range": 1, "damage": 1, "name": "Orc", "winding_up": false, "stunned": false,
		}
		main.battle_terrain.clear()
		main._apply_knockback(u_orc, Vector2i(1, 0))
		if u_orc.tile == Vector2i(3, 2):
			resisted_count += 1
	print("orc resists knockback sometimes over 60 tries: resisted=%d (expected roughly ~%d, definitely >0 and <60)" % [
		resisted_count, int(60 * main.ORC_KNOCKBACK_RESIST_CHANCE)
	])

	quit()
