extends SceneTree

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

	var hud = main.hud
	var goblin_script = load("res://scripts/Enemy.gd")
	var orc_script = load("res://scripts/Orc.gd")
	var brute_script = load("res://scripts/Brute.gd")
	var goblin = goblin_script.new()
	var orc = orc_script.new()
	var brute = brute_script.new()
	main.add_child(goblin)
	main.add_child(orc)
	main.add_child(brute)

	main.in_battle = true
	main.battle_terrain.clear()
	# Adjacent to the goblin specifically, so it's the one that's actually
	# targetable (and therefore highlighted) -- the orc and brute are
	# deliberately out of range so their icons stay untinted.
	main.battle_player_tile = Vector2i(1, 2)
	main.battle_target_index = 0
	main.battle_units = [
		{"ref": goblin, "tile": Vector2i(2, 2), "hp": 3, "max_hp": 3, "move_range": 2, "damage": 1, "name": "Goblin", "winding_up": false, "stunned": false, "size": 1, "attack_range": 1},
		{"ref": orc, "tile": Vector2i(4, 2), "hp": 20, "max_hp": 20, "move_range": 1, "damage": 2, "name": "Orc", "winding_up": true, "stunned": false, "size": 1, "attack_range": 1},
		{"ref": brute, "tile": Vector2i(1, 4), "hp": 35, "max_hp": 35, "move_range": 1, "damage": 3, "name": "Brute", "winding_up": false, "stunned": false, "size": 2, "attack_range": 1},
	]
	print("goblin is the only currently targetable unit: targetable=%s (expected [0])" % [main._targetable_indices()])
	main._refresh_battle_display()

	# battle_unit_icons/markers are now indexed 1:1 with battle_units (no
	# reserved slot 0 -- that was the player's own icon, now a dedicated
	# player_marker instead, see HUD.gd).
	var goblin_icon: TextureButton = hud.battle_unit_icons[0]
	var orc_icon: TextureButton = hud.battle_unit_icons[1]
	var brute_icon: TextureButton = hud.battle_unit_icons[2]
	var goblin_marker: Label = hud.battle_unit_markers[0]
	var orc_marker: Label = hud.battle_unit_markers[1]

	print("each enemy shows its real overworld sprite: goblin=%s (expected true), orc=%s (expected true), brute=%s (expected true)" % [
		goblin_icon.texture_normal == hud.ENEMY_ICONS["Goblin"],
		orc_icon.texture_normal == hud.ENEMY_ICONS["Orc"],
		brute_icon.texture_normal == hud.ENEMY_ICONS["Brute"],
	])

	print("the current target (goblin, index 0) is highlighted, others aren't: target_tint=%s (expected warm/non-white), orc_tint=%s (expected white)" % [
		goblin_icon.modulate, orc_icon.modulate
	])

	print("a winding-up unit shows the '!' badge, a calm one doesn't: orc_badge='%s' visible=%s (expected '!' true), goblin_badge='%s' visible=%s (expected '' false)" % [
		orc_marker.text, orc_marker.visible, goblin_marker.text, goblin_marker.visible
	])

	var expected_brute_icon_size := Vector2(hud.battle_tile_size * 2 - 12, hud.battle_tile_size * 2 - 12)
	print("the brute's icon is sized across its full 2x2 footprint, not just one tile: icon_size=%s (expected %s)" % [
		brute_icon.size, expected_brute_icon_size
	])

	print("icons cover every current enemy type: %s" % [
		hud.ENEMY_ICONS.keys().all(func(k): return hud.ENEMY_ICONS[k] != null)
	])

	# =========================================================
	# Battle HUD status indicators: Fae Hut spawn countdown, Gnome live pack
	# count, Druid's damage buff, and the shield status line -- all share
	# the same badge/marker mechanism the windup "!" above already uses.
	# =========================================================
	var fae_hut_script = load("res://scripts/FaeHut.gd")
	var gnome_script = load("res://scripts/Gnome.gd")
	var fae_hut = fae_hut_script.new()
	var gnome_a = gnome_script.new()
	var gnome_b = gnome_script.new()
	var gnome_c = gnome_script.new()
	main.add_child(fae_hut)
	main.add_child(gnome_a)
	main.add_child(gnome_b)
	main.add_child(gnome_c)

	main.battle_target_index = -1
	main.battle_units = [
		{"ref": fae_hut, "tile": Vector2i(0, 0), "hp": 10, "max_hp": 10, "move_range": 1, "damage": 0, "name": "Fae Hut", "winding_up": false, "stunned": false, "size": 1, "attack_range": 1, "turns_since_spawn": 1},
		{"ref": gnome_a, "tile": Vector2i(2, 0), "hp": 8, "max_hp": 8, "move_range": 2, "damage": 2, "name": "Gnome", "winding_up": false, "stunned": false, "size": 1, "attack_range": 1},
		{"ref": gnome_b, "tile": Vector2i(3, 0), "hp": 8, "max_hp": 8, "move_range": 2, "damage": 2, "name": "Gnome", "winding_up": false, "stunned": false, "size": 1, "attack_range": 1, "buffed_dmg_turns": 2},
		{"ref": gnome_c, "tile": Vector2i(4, 0), "hp": 8, "max_hp": 8, "move_range": 2, "damage": 2, "name": "Gnome", "winding_up": false, "stunned": false, "size": 1, "attack_range": 1},
	]
	main._refresh_battle_display()

	var hut_marker: Label = hud.battle_unit_markers[0]
	var gnome_a_marker: Label = hud.battle_unit_markers[1]
	var gnome_b_marker: Label = hud.battle_unit_markers[2]
	print("Fae Hut shows the turns remaining until its next spawn: badge='%s' (expected '2', FAE_HUT_SPAWN_INTERVAL(3) - turns_since_spawn(1))" % [hut_marker.text])
	print("The buffed Gnome's badge shows the buff, not the pack count, since windup/buff outrank pack size: badge='%s' (expected '^')" % [gnome_b_marker.text])
	print("An unbuffed Gnome in a 3-pack shows the live pack count instead: badge='%s' (expected 'x3')" % [gnome_a_marker.text])

	# The 6th unit slot (beyond the old 4-unit pool) actually renders --
	# regression check for the MAX_BATTLE_UNITS pool-size fix.
	var goblin_script2 = load("res://scripts/Enemy.gd")
	var pad_units := []
	for i in 6:
		var pad_g = goblin_script2.new()
		main.add_child(pad_g)
		pad_units.append({"ref": pad_g, "tile": Vector2i(i, 5), "hp": 3, "max_hp": 3, "move_range": 2, "damage": 1, "name": "Goblin", "winding_up": false, "stunned": false, "size": 1, "attack_range": 1})
	main.battle_units = pad_units
	main._refresh_battle_display()
	print("A 6-unit squad no longer indexes past the icon/marker pool: icon6_visible=%s marker6_visible=%s (expected true, false)" % [
		hud.battle_unit_icons[5].visible, hud.battle_unit_markers[5].visible
	])

	# Shield status line -- absent with nothing equipped, present (with its
	# live block chance, Shield Mastery bonus included) once one is. Lives on
	# battle_status_label2 now (see HUD.gd:update_battle_grid) -- the HP/STA
	# bars took over battle_status_label's old 2nd+ lines' vertical space.
	player.equipped_shield = {}
	player.meta_shield_block_bonus_pct = 0.0
	main._refresh_battle_display()
	print("No shield equipped: status has no Shield line: %s (expected false)" % [hud.battle_status_label2.text.contains("Shield:")])

	var shields_script = load("res://scripts/Shields.gd")
	player.current_weapon = load("res://scripts/Weapons.gd").CLUB
	player.coins = 1000
	player.try_buy_shield(shields_script.SHIELDS.shield_bulwark)
	player.meta_shield_block_bonus_pct = 0.1
	main._refresh_battle_display()
	print("An equipped shield surfaces its name and live block chance: status_has_line=%s (expected true, %s)" % [
		hud.battle_status_label2.text.contains("Iron Bulwark (18% block)"), hud.battle_status_label2.text
	])

	quit()
