extends SceneTree

func _make_goblin(main, tile: Vector2i, hp: int = 999) -> Dictionary:
	var goblin_script = load("res://scripts/Enemy.gd")
	var g = goblin_script.new()
	main.add_child(g)
	g.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	return {
		"ref": g, "tile": tile, "hp": hp, "max_hp": hp, "move_range": 2,
		"damage": 1, "name": "Goblin", "winding_up": false, "stunned": false,
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
	var weapons_script = load("res://scripts/Weapons.gd")
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_target_index = 0
	player.stat_strength = 10
	player.attack_damage = 10

	# Regular attack builds stamina; defend builds more.
	player.stamina = 0
	main.battle_units = [_make_goblin(main, Vector2i(3, 2))]
	main._battle_player_fight()
	print("regular attack regens stamina: %d (expected %d)" % [player.stamina, main.STAMINA_REGEN_ON_ATTACK])
	main.battle_units = [_make_goblin(main, Vector2i(3, 2))]
	main._battle_player_defend()
	print("defend regens stamina: %d (expected %d)" % [player.stamina, main.STAMINA_REGEN_ON_ATTACK + main.STAMINA_REGEN_ON_DEFEND])

	# Heavy attack costs stamina and hits harder (base dmg_mult * HEAVY mult,
	# with default Club's damage_mult of 1.0).
	player.stamina = player.MAX_STAMINA
	var g_heavy = _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [g_heavy]
	main._battle_player_heavy_attack()
	var expected_heavy_dmg: int = int(round(10 * weapons_script.HEAVY_DAMAGE_MULT))
	print("heavy attack costs stamina and hits harder: dealt=%d (expected %d), stamina=%d (expected %d)" % [
		999 - g_heavy.hp, expected_heavy_dmg, player.stamina, player.MAX_STAMINA - weapons_script.HEAVY_STAMINA_COST
	])

	# Not enough stamina blocks a heavy/special attack entirely (no damage,
	# no stamina spent).
	player.stamina = 5
	var g_broke = _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [g_broke]
	main._battle_player_heavy_attack()
	print("insufficient stamina blocks heavy attack: hp_unchanged=%s stamina_unchanged=%s" % [g_broke.hp == 999, player.stamina == 5])

	# Weapon damage_mult now applies to every attack type, not just
	# nothing (it was previously ignored entirely in the tile battle).
	player.stamina = player.MAX_STAMINA
	player.current_weapon = weapons_script.GREATSWORD
	var g_gs = _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [g_gs]
	main._battle_player_fight()
	var expected_gs_dmg: int = int(round(10 * weapons_script.GREATSWORD.damage_mult))
	print("weapon damage_mult now applies in battle: dealt=%d (expected %d, greatsword mult %.1f)" % [
		999 - g_gs.hp, expected_gs_dmg, weapons_script.GREATSWORD.damage_mult
	])

	# Special: leg_blow (Club's Leg Blow) also ignores rock cover, on top of
	# its speed-reduction effect (covered in tools/test_weapon_rework.gd).
	player.current_weapon = weapons_script.CLUB
	player.stamina = player.MAX_STAMINA
	main.battle_terrain[Vector2i(4, 2)] = {"type": "rock"}
	var g_cover = _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [g_cover]
	main._battle_player_special(0)
	var expected_guard_break_dmg: int = int(round(10 * player.current_weapon.specials[0].dmg_mult))
	print("leg_blow special skips rock-cover reduction: dealt=%d (expected %d, no 25%% reduction)" % [
		999 - g_cover.hp, expected_guard_break_dmg
	])
	main.battle_terrain.clear()

	# Special: execute (Club's Heavy Swing) does bonus damage below 30% HP.
	player.stamina = player.MAX_STAMINA
	var g_execute = _make_goblin(main, Vector2i(3, 2), 20)
	g_execute.hp = 5  # 25% of 20 max_hp -- below the 30% threshold
	main.battle_units = [g_execute]
	main._battle_player_special(2)
	var base_execute_dmg: int = int(round(10 * player.current_weapon.specials[2].dmg_mult))
	var expected_execute_dmg: int = int(round(base_execute_dmg * 1.5))
	print("execute special deals bonus damage to a low-HP target: dealt=%d (expected %d)" % [
		5 - g_execute.hp, expected_execute_dmg
	])

	# Special: self_heal (Club's Second Wind) heals the player.
	player.stamina = player.MAX_STAMINA
	player.health = 1
	# damage=0 so this turn's cascaded enemy counter-attack (from
	# _end_player_turn) can't muddy the heal-amount check below.
	var g_heal := _make_goblin(main, Vector2i(3, 2))
	g_heal.damage = 0
	main.battle_units = [g_heal]
	main._battle_player_special(1)
	var expected_heal: int = int(round(player.max_health * main.SELF_HEAL_PCT))
	print("self_heal special heals the player: player_health=%d (expected 1+%d=%d)" % [
		player.health, expected_heal, 1 + expected_heal
	])

	# The cleave_all and guaranteed_knockback effect mechanics themselves --
	# no weapon's specials reference either one anymore post-rework (they
	# were retired in favor of more distinct per-weapon effects), but the
	# underlying mechanism in Main.gd is still there and still worth
	# covering, via synthetic actions/specials rather than a real weapon.
	player.current_weapon = weapons_script.GREATSWORD
	player.stamina = player.MAX_STAMINA
	var g_cleave_a = _make_goblin(main, Vector2i(3, 2))
	var g_cleave_b = _make_goblin(main, Vector2i(1, 2))
	main.battle_units = [g_cleave_a, g_cleave_b]
	main._battle_perform_attack({"name": "Test Cleave All", "stamina_cost": 0, "dmg_mult": 0.8, "effect": "cleave_all"})
	print("cleave_all effect hits every targetable enemy: a_hit=%s b_hit=%s" % [g_cleave_a.hp < 999, g_cleave_b.hp < 999])

	# guaranteed_knockback always succeeds against an Orc and pushes 2 tiles
	# instead of 1. Tested via a direct _apply_single_hit call, not the full
	# _battle_perform_attack -- that would cascade into _end_player_turn and
	# this orc's own move_range:1 turn would immediately walk it right back
	# adjacent, masking the effect (same reasoning as test_knockback.gd).
	var orc_script = load("res://scripts/Orc.gd")
	player.stamina = player.MAX_STAMINA
	main.battle_terrain.clear()
	var orc = orc_script.new()
	main.add_child(orc)
	var u_orc := {
		"ref": orc, "tile": Vector2i(3, 2), "hp": 9999, "max_hp": 9999,
		"move_range": 1, "damage": 1, "name": "Orc", "winding_up": false, "stunned": false,
	}
	main.battle_units = [u_orc]
	var crushing_blow := {"dmg_mult": 1.3, "effect": "guaranteed_knockback"}
	main._apply_single_hit(0, crushing_blow.dmg_mult, crushing_blow.effect, player.current_weapon)
	print("guaranteed_knockback always pushes an Orc 2 tiles: tile=%s (expected (5, 2))" % [u_orc.tile])

	# The double_hit effect mechanic itself (not tied to any one weapon's
	# special slot post-rework) -- a synthetic action confirms it still
	# applies the hit twice.
	player.current_weapon = weapons_script.SPEAR
	player.stamina = player.MAX_STAMINA
	var g_double = _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [g_double]
	main._battle_perform_attack({"name": "Test Double Hit", "stamina_cost": 0, "dmg_mult": 0.6, "effect": "double_hit"})
	var double_hit_dmg: int = int(round(10 * weapons_script.SPEAR.damage_mult * 0.6))
	print("double_hit effect hits twice: dealt=%d (expected ~%d, two hits of %d each)" % [
		999 - g_double.hp, double_hit_dmg * 2, double_hit_dmg
	])

	# Special: stun_bypass (Battle Axe's Oldest Trick in the Book) always
	# stuns, even with no rock involved. Tested via a direct _apply_single_hit
	# call -- through the full _battle_player_special, _end_player_turn's
	# cascade would immediately consume the stun on this same unit's own turn
	# before the test ever gets to check it (the stun-skip logic clears the
	# flag).
	player.current_weapon = weapons_script.BATTLE_AXE
	player.stamina = player.MAX_STAMINA
	main.battle_terrain.clear()
	var g_stun = _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [g_stun]
	var oldest_trick: Dictionary = player.current_weapon.specials[2]
	main._apply_single_hit(0, oldest_trick.dmg_mult, oldest_trick.effect, player.current_weapon)
	print("stun_bypass special always stuns: stunned=%s (expected true)" % [g_stun.stunned])

	# Stamina resets to full when a new battle starts. Done last since
	# _setup_battle_grid rebuilds the whole grid (player tile, terrain),
	# which would disrupt the fixed layout the tests above rely on.
	player.stamina = 3
	main._setup_battle_grid([])
	print("stamina resets to full on battle start: %d (expected %d)" % [player.stamina, player.MAX_STAMINA])

	quit()
