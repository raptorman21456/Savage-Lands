extends SceneTree

func _init() -> void:
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	print("Apprentice Mage's traits: attack_range=%d (expected 4), ignore_line=%s (expected true)" % [
		main.ENEMY_TRAITS.get("Apprentice Mage", {}).get("attack_range", 0),
		main.ENEMY_TRAITS.get("Apprentice Mage", {}).get("ignore_line", false),
	])
	print("HUD.ENEMY_ICONS resolves for the new name: %s (expected true)" % [main.hud.ENEMY_ICONS.has("Apprentice Mage")])

	# --- Non-straight-line range: an L-shaped offset (3 tiles over, 1 tile
	# down -- neither axis-aligned) at exactly Manhattan distance 4, which
	# the old straight-line-only Archer logic would have refused outright. ---
	var attacker := Vector2i(0, 0)
	var offset_target := Vector2i(3, 1)
	print("with ignore_line, an off-angle target 4 tiles away is a valid hit: %s (expected true)" % [
		main._can_battle_attack(attacker, offset_target, 4, true)
	])
	print("the same shot without ignore_line is refused -- this is exactly what the old Archer would have done: %s (expected false)" % [
		main._can_battle_attack(attacker, offset_target, 4, false)
	])

	# --- Still respects the range-4 cutoff -- one tile farther, still
	# off-angle, is out of range regardless of ignore_line. ---
	var too_far_target := Vector2i(4, 1)
	print("a target 5 tiles away is still out of range even with ignore_line: %s (expected false)" % [
		main._can_battle_attack(attacker, too_far_target, 4, true)
	])

	# --- 6 HP, via the real _setup_battle_grid path (not the hardcoded
	# const alone), and the display name that's actually rendered. ---
	var mage_script = load("res://scripts/Archer.gd")
	var mage = mage_script.new()
	main.add_child(mage)
	mage.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	main._setup_battle_grid([mage])
	print("Apprentice Mage has 6 HP via the real battle-setup path: name=%s (expected Apprentice Mage), max_hp=%d (expected 6)" % [
		main.battle_units[0].name, main.battle_units[0].max_hp
	])

	quit()
