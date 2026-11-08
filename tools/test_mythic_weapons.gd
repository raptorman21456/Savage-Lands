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
	# These checks predate the doc's flat weapon Strength (Club +2, Spear +4 per quality tier...), which has its own test
	# (test_weapon_stat_bonuses.gd): here weapons add nothing, so every damage figure below stays as it was.
	var _stat_weapons = load("res://scripts/Weapons.gd")
	_stat_weapons.CLUB["str_bonus"] = 0
	for _stat_base in _stat_weapons.UPGRADABLE_TYPES:
		_stat_base["str_per_tier"] = 0
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	main.regional_world = false  # this test drives the old wave-ladder world
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
		var expected_dmg: float = base.damage_mult * 2.25
		var expected_price: int = int(round(base.price * 6.0))
		print("%s -> %s: id=%s (expected %s_mythic), tier=%s, dmg=%.3f (expected %.3f), price=%d (expected %d)" % [
			base.name, variant.name, variant.id, base.id, variant.tier_name, variant.damage_mult, expected_dmg, variant.price, expected_price
		])
		for key in mythic.passive:
			print("  passive %s present: %s (expected %s)" % [key, variant.get(key, null), mythic.passive[key]])

	print("--- battle behavior ---")

	# The Great Toothpicke: passive_heal_chance/passive_heal_flat is a flat,
	# probabilistic sip of HP on a landed hit -- 25% chance, always exactly 5
	# HP, not a %-of-damage lifesteal. Health is reset to 1 before every
	# trial so a heal (health goes above 1) is unambiguous, and any heal that
	# ISN'T exactly to 6 would mean the flat amount drifted.
	player.current_weapon = weapons_script.make_variant(weapons_script.SPEAR, mythic_rank)
	var heal_trials := 150
	var heals := 0
	var wrong_heal_amount := false
	for i in heal_trials:
		player.stamina = player.MAX_STAMINA
		player.health = 1
		var g_tooth := _make_unit(main, "Goblin", Vector2i(3, 2), 999999)
		main.battle_units = [g_tooth]
		main.battle_target_index = 0
		main._battle_player_fight()
		if player.health > 1:
			heals += 1
			if player.health != 1 + 5 + int(round(player.max_health * 0.05)):
				wrong_heal_amount = true
		if is_instance_valid(g_tooth.ref):
			g_tooth.ref.queue_free()
	print("The Great Toothpicke's 25%% heal-chance over %d trials: %d (expected roughly 20-55, ~37 mean), always exactly 5 HP plus 5%% of max HP: wrong_amount=%s (expected false)" % [heal_trials, heals, wrong_heal_amount])

	# The Great Toothpicke's other half: a 25% chance on a landed hit to poison the target.
	var poisoned := 0
	for i in heal_trials:
		var g_venom := _make_unit(main, "Goblin", Vector2i(3, 2), 999999)
		main.battle_units = [g_venom]
		main._apply_single_hit(0, 1.0, "", player.current_weapon)
		if int(g_venom.get("poison_turns", 0)) > 0:
			poisoned += 1
		if is_instance_valid(g_venom.ref):
			g_venom.ref.queue_free()
	print("The Great Toothpicke's 25%% poison chance over %d trials: %d (expected roughly 20-55, about 37 mean)" % [heal_trials, poisoned])

	# The Looongblade: passive_extra_range adds a flat tile of reach on top of
	# whatever the weapon normally gets -- turns Greatsword's usual melee-only
	# range (1) into 2, same as a long_range weapon, but not further than that.
	player.current_weapon = weapons_script.make_variant(weapons_script.GREATSWORD, mythic_rank)
	player.stamina = player.MAX_STAMINA
	var g_long = _make_unit(main, "Goblin", Vector2i(4, 2), 999) # 2 tiles from (2,2) -- out of Greatsword's normal range
	main.battle_units = [g_long]
	main.battle_target_index = 0
	main._battle_player_fight()
	print("The Looongblade reaches 2 tiles instead of Greatsword's usual 1: dealt=%d (expected >0)" % [999 - g_long.hp])
	player.stamina = player.MAX_STAMINA
	var g_too_far = _make_unit(main, "Goblin", Vector2i(5, 2), 999) # 3 tiles -- the flat +1 doesn't reach this far
	main.battle_units = [g_too_far]
	main.battle_target_index = 0
	main._battle_player_fight()
	print("...but not 3 tiles: dealt=%d (expected 0, no target in range)" % [999 - g_too_far.hp])

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

	# The Executioner's Axe: passive_oneshot_chance is an independent 5%
	# per-hit chance to kill a regular enemy outright, same "bosses are
	# immune" carve-out as the Last Stand Idol talisman's guaranteed version.
	player.current_weapon = weapons_script.make_variant(weapons_script.BATTLE_AXE, mythic_rank)
	var oneshot_trials := 200
	var oneshots := 0
	for i in oneshot_trials:
		player.stamina = player.MAX_STAMINA
		var g_axe := _make_unit(main, "Goblin", Vector2i(3, 2), 999999)
		main.battle_units = [g_axe]
		main.battle_target_index = 0
		main._battle_player_fight()
		if g_axe.hp <= 0:
			oneshots += 1
		if is_instance_valid(g_axe.ref):
			g_axe.ref.queue_free()
	print("The Executioner's Axe's 35%% oneshot-chance over %d trials: %d (expected roughly 55-115, ~70 mean)" % [oneshot_trials, oneshots])
	# A boss-tier target is immune, same as Last Stand Idol. Elder Oak's own
	# 35% dodge_chance means not every trial actually lands, so only landed
	# hits (dealt > 0) count toward the "never a full kill" check.
	var boss_trials := 60
	var boss_landed := 0
	var boss_oneshot := false
	for i in boss_trials:
		player.stamina = player.MAX_STAMINA
		var g_boss := _make_unit(main, "Elder Oak", Vector2i(3, 2), 999999)
		main.battle_units = [g_boss]
		main.battle_target_index = 0
		main._battle_player_fight()
		var boss_dealt: int = 999999 - g_boss.hp
		if boss_dealt > 0:
			boss_landed += 1
			if g_boss.hp <= 0:
				boss_oneshot = true
		if is_instance_valid(g_boss.ref):
			g_boss.ref.queue_free()
	print("...but never a boss-tier enemy, across %d landed hits: oneshot=%s (expected false)" % [boss_landed, boss_oneshot])

	# The Implement: passive_lifesteal_pct heals back 20% of the damage just
	# dealt, on every landed hit -- guaranteed, not a chance roll.
	player.current_weapon = weapons_script.make_variant(weapons_script.DAGGER, mythic_rank)
	player.stamina = player.MAX_STAMINA
	player.health = 1
	var g_implement = _make_unit(main, "Goblin", Vector2i(3, 2), 999999)
	main.battle_units = [g_implement]
	main.battle_target_index = 0
	main._battle_player_fight()
	var implement_dmg: int = 999999 - g_implement.hp
	var expected_implement_heal: int = max(1, int(round(implement_dmg * 0.20)))
	print("The Implement's 20%% lifesteal on a plain attack: dealt=%d, player_health=%d (expected 1+%d=%d)" % [
		implement_dmg, player.health, expected_implement_heal, 1 + expected_implement_heal
	])

	# Grunkle Gloves: 1.2x crit damage. A stealth strike is a guaranteed crit, so the same weapon with the multiplier at 1.0 and at
	# 1.2 shows the difference exactly (the ratio is the multiplier, up to rounding).
	player.current_weapon = weapons_script.make_variant(weapons_script.KNUCKLE_GLOVES, mythic_rank)
	var crit_totals := {}
	for mult in [1.0, 1.2]:
		var crit_weapon: Dictionary = player.current_weapon.duplicate(true)
		crit_weapon["passive_crit_damage_mult"] = mult
		var total := 0
		for i in 40:
			var g_crit := _make_unit(main, "Goblin", Vector2i(3, 2), 999999)
			main.battle_units = [g_crit]
			player.stealth_turns_remaining = 3
			main._apply_single_hit(0, 1.0, "", crit_weapon)
			total += 999999 - g_crit.hp
			if is_instance_valid(g_crit.ref):
				g_crit.ref.queue_free()
		crit_totals[mult] = total
	print("Grunkle Gloves' 1.2x crit damage: forced crits total %d at x1.0 and %d at x1.2 (ratio %.2f, expected about 1.20)" % [crit_totals[1.0], crit_totals[1.2], float(crit_totals[1.2]) / maxf(1.0, float(crit_totals[1.0]))])
	print("Grunkle Gloves' crit chance multiplier is on the weapon: %s (expected 1.3)" % [player.current_weapon.get("passive_crit_chance_mult", 1.0)])

	# Grunkle Gloves: passive_undead_boss_bonus deals 30% more against an
	# undead or boss-tier enemy (Elder Oak is both) than a plain Goblin.
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
		var g_s := _make_unit(main, "Elder Oak", Vector2i(3, 2), 999999)
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

	# Emerald Picks: passive_free_special_chance is a probabilistic 10% chance
	# per use, not Gravedigger's guaranteed free ride -- pichaku (0 stamina
	# regardless) is a clean special to repeat since it never actually needs
	# the free roll to succeed, so stamina is drained back to 0 every trial
	# and only the free-roll's own log line proves whether it fired.
	player.current_weapon = weapons_script.make_variant(weapons_script.HAND_PICKS, mythic_rank)
	var free_trials := 200
	var frees := 0
	for i in free_trials:
		player.stamina = 0
		var special_idx := -1
		for s in player.current_weapon.specials.size():
			if player.current_weapon.specials[s].effect == "diamonds":
				special_idx = s
				break
		var g_pan = _make_unit(main, "Goblin", Vector2i(3, 2))
		main.battle_units = [g_pan]
		main.battle_target_index = 0
		main._battle_player_special(special_idx)
		if 999 - g_pan.hp > 0:
			frees += 1
		if is_instance_valid(g_pan.ref):
			g_pan.ref.queue_free()
	print("Emerald Picks' 20%% free-special-chance over %d trials at 0 stamina: %d (expected roughly 25-60, about 40 mean)" % [free_trials, frees])

	# Second Best: a 20% chance on every landed hit to concuss the target (BONK's three turns), instead of a stun.
	player.current_weapon = weapons_script.make_variant(weapons_script.HAMMER, mythic_rank)
	var concussed := 0
	var stunned_instead := 0
	for i in 150:
		var g_hammer := _make_unit(main, "Goblin", Vector2i(3, 2), 999999)
		main.battle_units = [g_hammer]
		main._apply_single_hit(0, 1.0, "", player.current_weapon)
		if int(g_hammer.get("concussed_turns", 0)) > 0:
			concussed += 1
		if g_hammer.stunned:
			stunned_instead += 1
		if is_instance_valid(g_hammer.ref):
			g_hammer.ref.queue_free()
	print("Second Best's 20%% concussion chance over 150 trials: %d (expected roughly 15-50, about 30 mean), turns %d (expected %d), and it no longer stuns: %d (expected 0)" % [concussed, main.BONK_CONCUSSED_TURNS, 3, stunned_instead])

	quit()
