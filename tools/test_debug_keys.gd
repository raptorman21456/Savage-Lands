extends SceneTree

# Dev-only cheat keys (Main.gd:_handle_debug_input) -- F1/F2 jump worlds
# forward/backward with a matching wave and a freshly-spawned squad, F3
# grants+equips a random weapon, F4/F5 top off coins/HP-stamina. Not reached
# by any player input path, so tested by calling the underlying functions
# directly rather than simulating keypresses. Compared against each world's
# stable "id" field, not its user-editable display "name" (text/
# strings.json can rename any of them).

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	print("starts on Plains, wave 1: id=%s (expected plains), wave=%d (expected 1)" % [main.WORLDS[main.current_world_index].id, main.wave])

	main._debug_jump_world(1)
	await physics_frame
	print("F1 jumps forward one world: id=%s (expected beach), wave=%d (expected %d, first wave of that world)" % [
		main.WORLDS[main.current_world_index].id, main.wave, main.WAVES_PER_WORLD + 1
	])
	var enemies_after_jump: int = main.get_tree().get_nodes_in_group("enemies").size()
	print("a fresh squad actually spawned for the new world: enemies_alive=%d (expected > 0), live enemy nodes match=%s (expected true)" % [
		main.enemies_alive, enemies_after_jump == main.enemies_alive
	])

	main._debug_jump_world(-1)
	await physics_frame
	print("F2 jumps back: id=%s (expected plains), wave=%d (expected 1)" % [main.WORLDS[main.current_world_index].id, main.wave])

	main._debug_jump_world(-1)
	print("jumping past world 0 clamps rather than wrapping negative: index=%d (expected 0)" % main.current_world_index)

	for i in main.WORLDS.size() + 2:
		main._debug_jump_world(1)
	print("jumping past the last world clamps at the top instead of erroring: index=%d (expected %d)" % [main.current_world_index, main.WORLDS.size() - 1])

	# Reset back to a known-good state before the weapon grant check.
	main._debug_jump_world(-99)
	await physics_frame

	var owned_before: int = main.player.owned_weapons.size()
	main._debug_grant_random_weapon()
	var granted_base: Dictionary = main.WeaponsScript.get_base_type(main.player.current_weapon_base)
	print("F3 grants and equips a random weapon: owned_weapons grew=%s (expected true), it's a real UPGRADABLE_TYPES base=%s (expected true)" % [
		main.player.owned_weapons.size() > owned_before, not granted_base.is_empty()
	])

	# F4: +500 coins, checked as "a real increase happened" rather than an
	# exact +500 since add_coins' own bonus-coin-pct scaling could inflate
	# it further depending on the player's meta upgrades.
	var coins_before: int = main.player.coins
	main.player.add_coins(500)
	print("F4 grants coins: %d -> %d (expected an increase of at least 500)" % [coins_before, main.player.coins])

	main.player.health = 1
	main.player.stamina = 0
	main.player.restore_health(main.player.max_health)
	main.player.reset_stamina()
	print("F5 tops off HP/stamina: health=%d/%d stamina=%d/%d (expected both full)" % [
		main.player.health, main.player.max_health, main.player.stamina, main.player.max_stamina
	])

	quit()
