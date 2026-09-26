extends SceneTree

func _make_unit(main, name: String, tile: Vector2i, hp: int = 999, dmg: int = 0) -> Dictionary:
	var goblin_script = load("res://scripts/Enemy.gd")
	var g = goblin_script.new()
	main.add_child(g)
	g.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	return {
		"ref": g, "tile": tile, "hp": hp, "max_hp": hp, "move_range": 2,
		"damage": dmg, "name": name, "winding_up": false, "stunned": false,
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

	# min_rank=5 (the Mythic tier's own rank) forces every roll to land on
	# Mythic, the same "force the top tier" pattern test_tier_floor.gd uses.
	var mythic_rank := 5

	print("--- identity + scaling for all 8 named legendaries ---")
	for base in weapons_script.UPGRADABLE_TYPES:
		var mythic: Dictionary = weapons_script.MYTHIC_WEAPONS[base.id]
		var variant: Dictionary = weapons_script.make_variant(base, mythic_rank)
		var expected_dmg: float = base.damage_mult * 3.0
		var expected_price: int = int(round(base.price * 6.0))
		print("%s -> %s: id=%s (expected %s_mythic), tier=%s, dmg=%.3f (expected %.3f), price=%d (expected %d)" % [
			base.name, variant.name, variant.id, base.id, variant.tier_name, variant.damage_mult, expected_dmg, variant.price, expected_price
		])
		for key in mythic.passive:
			print("  passive %s present: %s (expected %s)" % [key, variant.get(key, null), mythic.passive[key]])

	print("--- battle behavior ---")

	# Stormfang: passive_lifesteal_pct heals on every hit, no lifesteal
	# special needed.
	player.current_weapon = weapons_script.make_variant(weapons_script.SPEAR, mythic_rank)
	player.stamina = player.MAX_STAMINA
	player.health = 1
	var g_storm = _make_unit(main, "Goblin", Vector2i(3, 2), 999, 0)
	main.battle_units = [g_storm]
	main._battle_player_fight()
	var storm_dmg: int = 999 - g_storm.hp
	var expected_storm_heal: int = max(1, int(round(storm_dmg * 0.25)))
	print("Stormfang lifesteal on a plain attack: dealt=%d, player_health=%d (expected 1+%d=%d)" % [
		storm_dmg, player.health, expected_storm_heal, 1 + expected_storm_heal
	])

	# Duskrender: passive_cleave_pct splashes onto a second targetable enemy.
	player.current_weapon = weapons_script.make_variant(weapons_script.GREATSWORD, mythic_rank)
	player.stamina = player.MAX_STAMINA
	main.battle_target_index = 0
	var g_dusk_primary = _make_unit(main, "Goblin", Vector2i(3, 2))
	var g_dusk_splash = _make_unit(main, "Goblin", Vector2i(2, 1))
	main.battle_units = [g_dusk_primary, g_dusk_splash]
	main._battle_player_fight()
	print("Duskrender cleave splashes a second enemy: primary_dealt=%d (expected >0), splash_dealt=%d (expected >0)" % [
		999 - g_dusk_primary.hp, 999 - g_dusk_splash.hp
	])

	# Worldbreaker: passive_guaranteed_knockback always knocks back an Orc,
	# same guarantee the existing guaranteed_knockback special has. Called
	# via _apply_single_hit directly rather than the full attack flow --
	# going through _battle_player_fight would cascade into _end_player_turn
	# and this orc's own move_range:1 turn would immediately walk it right
	# back adjacent, masking the effect (see test_combat_specials.gd's
	# identical guaranteed_knockback test for the same reasoning).
	var orc_script = load("res://scripts/Orc.gd")
	var orc = orc_script.new()
	main.add_child(orc)
	player.current_weapon = weapons_script.make_variant(weapons_script.HAMMER, mythic_rank)
	var orc_unit := {
		"ref": orc, "tile": Vector2i(3, 2), "hp": 9999, "max_hp": 9999, "move_range": 1,
		"damage": 1, "name": "Orc", "winding_up": false, "stunned": false,
	}
	main.battle_units = [orc_unit]
	main._apply_single_hit(0, 1.0, "", player.current_weapon)
	print("Worldbreaker always knocks back even an Orc: tile=%s (expected (5, 2), pushed back 2 tiles)" % [orc_unit.tile])

	# Bloodreaver: passive_execute_bonus applies +50% vs a target below 30% HP,
	# without needing the explicit execute effect. max_hp=999 keeps the
	# knockback-fall math irrelevant and hp=100 (<30% of 999) guarantees the
	# threshold is met going in.
	player.current_weapon = weapons_script.make_variant(weapons_script.BATTLE_AXE, mythic_rank)
	player.stamina = player.MAX_STAMINA
	var g_reaver := {
		"ref": load("res://scripts/Enemy.gd").new(), "tile": Vector2i(3, 2), "hp": 100, "max_hp": 999,
		"move_range": 2, "damage": 0, "name": "Goblin", "winding_up": false, "stunned": false,
	}
	main.add_child(g_reaver.ref)
	g_reaver.ref.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	main.battle_units = [g_reaver]
	main._battle_player_fight()
	var base_dmg: int = int(round(10 * player.current_weapon.damage_mult))
	var expected_reaver_dmg: int = int(round(base_dmg * 1.5))
	print("Bloodreaver executes a low-HP target without the execute effect: dealt=%d (expected %d, +50%% of %d)" % [
		100 - g_reaver.hp, expected_reaver_dmg, base_dmg
	])

	# Nightwhisper: passive_double_hit_chance is probabilistic (30%) -- over
	# many single hits, roughly 30% should land the bonus second hit.
	player.current_weapon = weapons_script.make_variant(weapons_script.DAGGER, mythic_rank)
	var extra_hits := 0
	var trials := 150
	for i in trials:
		player.stamina = player.MAX_STAMINA
		var g := _make_unit(main, "Goblin", Vector2i(3, 2), 999999)
		main.battle_units = [g]
		main._battle_player_fight()
		var hits_landed: int = 1 if (999999 - g.hp) > 0 else 0
		# A landed double-hit deals roughly 2x a single hit's damage.
		var single_hit: int = int(round(10 * player.current_weapon.damage_mult))
		if (999999 - g.hp) >= single_hit * 2 - 1:
			extra_hits += 1
		if is_instance_valid(g.ref):
			g.ref.queue_free()
	print("Nightwhisper's 30%% double-hit chance over %d trials: %d (expected roughly 30-60, ~45 mean)" % [trials, extra_hits])

	# Grunkle Gloves: passive_stun_chance is probabilistic (20%) -- called via
	# _apply_single_hit directly rather than the full attack flow, same
	# reasoning as Worldbreaker's knockback test below: going through
	# _battle_player_fight would cascade into the enemy's own turn, which
	# consumes and clears the stunned flag right after skipping its action,
	# masking the effect before we can observe it.
	player.current_weapon = weapons_script.make_variant(weapons_script.KNUCKLE_GLOVES, mythic_rank)
	var stuns := 0
	var stun_trials := 150
	for i in stun_trials:
		var g_glove := _make_unit(main, "Goblin", Vector2i(3, 2), 999999)
		main.battle_units = [g_glove]
		main._apply_single_hit(0, 1.0, "", player.current_weapon)
		if g_glove.stunned:
			stuns += 1
		if is_instance_valid(g_glove.ref):
			g_glove.ref.queue_free()
	print("Grunkle Gloves' 20%% stun chance over %d trials: %d (expected roughly 20-40, ~30 mean)" % [stun_trials, stuns])

	# Grunkle Gloves: passive_undead_boss_bonus deals 30% more against an
	# undead or boss-tier enemy (Count Strahd is both) than a plain Goblin.
	# Averaged over many landed hits, via _apply_single_hit directly -- Count
	# Strahd's own 35% dodge_chance would otherwise swing a single trial
	# either way, so whiffed (0-damage) hits are excluded from the average.
	player.current_weapon = weapons_script.make_variant(weapons_script.KNUCKLE_GLOVES, mythic_rank)
	var bonus_trials := 100
	var plain_total := 0
	var plain_hits := 0
	for i in bonus_trials:
		var g_p := _make_unit(main, "Goblin", Vector2i(3, 2), 999999)
		main.battle_units = [g_p]
		main._apply_single_hit(0, 1.0, "", player.current_weapon)
		var dealt: int = 999999 - g_p.hp
		if dealt > 0:
			plain_total += dealt
			plain_hits += 1
		if is_instance_valid(g_p.ref):
			g_p.ref.queue_free()
	var strahd_total := 0
	var strahd_hits := 0
	for i in bonus_trials:
		var g_s := _make_unit(main, "Count Strahd", Vector2i(3, 2), 999999)
		main.battle_units = [g_s]
		main._apply_single_hit(0, 1.0, "", player.current_weapon)
		var dealt: int = 999999 - g_s.hp
		if dealt > 0:
			strahd_total += dealt
			strahd_hits += 1
		if is_instance_valid(g_s.ref):
			g_s.ref.queue_free()
	var plain_avg: float = float(plain_total) / max(1, plain_hits)
	var strahd_avg: float = float(strahd_total) / max(1, strahd_hits)
	print("Grunkle Gloves deals 30%% more to undead/boss-tier: plain_avg=%.1f (n=%d landed), strahd_avg=%.1f (n=%d landed, expected ~%.1f)" % [
		plain_avg, plain_hits, strahd_avg, strahd_hits, plain_avg * 1.3
	])

	# Gravedigger: passive_free_specials means a special costs 0 stamina.
	player.current_weapon = weapons_script.make_variant(weapons_script.HAND_PICKS, mythic_rank)
	player.stamina = 0
	var g_grave = _make_unit(main, "Goblin", Vector2i(3, 2))
	main.battle_units = [g_grave]
	main._battle_player_special(0)
	print("Gravedigger's specials are free even at 0 stamina: dealt=%d (expected >0, attack still landed)" % [999 - g_grave.hp])

	quit()
