extends SceneTree

func _init() -> void:
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var player = main.player
	var goblin_script = load("res://scripts/Enemy.gd")
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_target_index = 0
	main.battle_menu_state = "main"
	player.stamina = player.MAX_STAMINA

	var goblin = goblin_script.new()
	main.add_child(goblin)
	goblin.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	main.battle_units = [{
		"ref": goblin, "tile": Vector2i(3, 2), "hp": 999, "max_hp": 999, "move_range": 2,
		"damage": 1, "name": "Goblin", "winding_up": false, "stunned": false,
	}]
	main._refresh_battle_display()

	# Clicking "Fight" opens the attack submenu without spending a turn.
	main.hud.battle_main_buttons["fight"].pressed.emit()
	print("clicking Fight opens the submenu: state=%s (expected fight), main_visible=%s (expected false), submenu_visible=%s (expected true)" % [
		main.battle_menu_state, main.hud.battle_main_menu_box.visible, main.hud.battle_fight_submenu_box.visible
	])

	# Clicking "Back" returns to the main menu, still without spending a turn.
	main.hud.battle_fight_buttons["back"].pressed.emit()
	print("clicking Back returns to the main menu: state=%s (expected main)" % [main.battle_menu_state])

	# Clicking "Fight" then "Attack" actually lands a hit and ends the turn.
	main.hud.battle_main_buttons["fight"].pressed.emit()
	var hp_before: int = main.battle_units[0].hp
	main.hud.battle_fight_buttons["attack"].pressed.emit()
	print("clicking Attack in the submenu lands a hit: dealt=%d (expected >0), menu_state_after=%s (expected main, reset for the next turn)" % [
		hp_before - main.battle_units[0].hp, main.battle_menu_state
	])

	# Item/Defend/Flee still work directly from the main menu (no submenu).
	# damage=0 so this turn's cascaded enemy counter-attack (from
	# _end_player_turn) can't muddy the heal-amount check below.
	main.battle_units[0].damage = 0
	player.add_potion(5)
	player.health = 1
	main.hud.battle_main_buttons["item"].pressed.emit()
	print("clicking Item heals directly from the main menu: player_health=%d (expected 6)" % [player.health])

	# Heavy Attack button is disabled when stamina is too low.
	player.stamina = 5
	main._refresh_battle_display()
	print("heavy attack button disables with low stamina: disabled=%s (expected true)" % [main.hud.battle_fight_buttons["heavy"].disabled])
	player.stamina = player.MAX_STAMINA
	main._refresh_battle_display()
	print("heavy attack button re-enables with full stamina: disabled=%s (expected false)" % [main.hud.battle_fight_buttons["heavy"].disabled])

	# Item button is disabled with no potions held.
	player.potion_queue.clear()
	player.healing_items = 0
	main._refresh_battle_display()
	print("item button disables with no potions: disabled=%s (expected true)" % [main.hud.battle_main_buttons["item"].disabled])

	# Special buttons show the equipped weapon's actual special names.
	var weapons_script = load("res://scripts/Weapons.gd")
	player.current_weapon = weapons_script.HAMMER
	main._refresh_battle_display()
	print("special buttons reflect the equipped weapon: special_1_text=%s (expected to mention %s)" % [
		main.hud.battle_fight_buttons["special_0"].text, weapons_script.HAMMER.specials[0].name
	])

	quit()
