extends SceneTree

# 3 new enemies (Fae Hut/Fae, Gnome, Druid) + the squad-size scaling that
# now lets a battle grow past the old flat 4-unit tough-tier cap.

func _make_gnome(main, tile: Vector2i, hp: int = 999) -> Dictionary:
	var gnome_script = load("res://scripts/Gnome.gd")
	var g = gnome_script.new()
	main.add_child(g)
	g.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	return {
		"ref": g, "tile": tile, "hp": hp, "max_hp": hp, "move_range": 2,
		"damage": 2, "name": "Gnome", "winding_up": false, "stunned": false,
		"attack_range": 1, "concussed_turns": 0, "frozen_turns": 0,
		"burning": false, "armored": false,
		"disarmed_tile": Vector2i(-1, -1),
	}

func _make_goblin(main, tile: Vector2i, hp: int = 999) -> Dictionary:
	var goblin_script = load("res://scripts/Enemy.gd")
	var g = goblin_script.new()
	main.add_child(g)
	g.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	return {
		"ref": g, "tile": tile, "hp": hp, "max_hp": hp, "move_range": 2,
		"damage": 1, "name": "Goblin", "winding_up": false, "stunned": false,
		"attack_range": 1, "concussed_turns": 0, "frozen_turns": 0,
		"burning": false, "armored": false,
		"disarmed_tile": Vector2i(-1, -1),
	}

func _init() -> void:
	var weapons_script = load("res://scripts/Weapons.gd")
	var armor_script = load("res://scripts/Armor.gd")
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	# =========================================================
	# Squad-size scaling
	# =========================================================
	main.wave = 1
	player.level = 1
	player.current_weapon = weapons_script.CLUB
	player.equipped_armor = armor_script.TIERS[0]
	print("No scaling bonus at wave 1, level 1, starter gear: %d (expected 0)" % [main._squad_size_bonus()])

	main.wave = 25
	player.level = 21
	player.current_weapon = {"tier_name": "Legendary"}
	player.equipped_armor = armor_script.TIERS[3]
	print("Wave/level/gear all contribute: %d (expected 11, 5+4+2)" % [main._squad_size_bonus()])
	var scaled_max: int = clampi(main.MAX_BATTLE_ENEMIES_TOUGH + main._squad_size_bonus(), main.MAX_BATTLE_ENEMIES_TOUGH, main.MAX_BATTLE_SQUAD_SIZE_CEILING)
	print("...but the actual squad cap never exceeds the ceiling: %d (expected 6)" % [scaled_max])

	# Difficulty now also contributes: Baby/Normal round down to +0 (clamped),
	# Hard/Apocalyptic add +2/+4. Wave/level/gear zeroed out so only the
	# difficulty term shows through.
	main.wave = 1
	player.level = 1
	player.current_weapon = weapons_script.CLUB
	player.equipped_armor = armor_script.TIERS[0]
	player.difficulty_mult = 0.75
	print("Baby difficulty adds no bonus: %d (expected 0)" % [main._squad_size_bonus()])
	player.difficulty_mult = 1.0
	print("Normal difficulty adds no bonus: %d (expected 0)" % [main._squad_size_bonus()])
	player.difficulty_mult = 1.75
	print("Hard difficulty adds +2: %d (expected 2)" % [main._squad_size_bonus()])
	player.difficulty_mult = 3.0
	print("Apocalyptic difficulty adds +4: %d (expected 4)" % [main._squad_size_bonus()])
	player.difficulty_mult = 1.0

	# End-to-end: a heavily-scaled Orc-initiated battle can now seat up to 6.
	# Restore the high wave/level/gear values from the earlier scaling check
	# above (the difficulty sub-test just zeroed them back out to isolate its
	# own term). Padded with nearby GOBLINS, not more Orcs --
	# MAX_BATTLE_TOUGH_UNITS (2) is a separate, deliberately-untouched cap on
	# how many BIG units can co-occur, unrelated to this overall-size
	# scaling; stacking Orcs here would hit that cap first and never
	# exercise the ceiling this is actually testing.
	main.wave = 25
	player.level = 21
	player.current_weapon = {"tier_name": "Legendary"}
	player.equipped_armor = armor_script.TIERS[3]
	var orc_script = load("res://scripts/Orc.gd")
	var goblin_script2 = load("res://scripts/Enemy.gd")
	var initial_orc = orc_script.new()
	main.add_child(initial_orc)
	initial_orc.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	initial_orc.global_position = player.global_position + Vector2(400, 400)
	for i in 6:
		var gb = goblin_script2.new()
		main.add_child(gb)
		gb.died.connect(main._on_enemy_died)
		main.enemies_alive += 1
		gb.global_position = initial_orc.global_position + Vector2(15 * i, 0)
	var scaled_squad: Array = main._gather_squad(initial_orc)
	print("A fully-scaled tough battle can now seat up to 6: squad_size=%d (expected 6)" % [scaled_squad.size()])

	main.wave = 1
	player.level = 1
	player.current_weapon = weapons_script.CLUB
	player.equipped_armor = armor_script.TIERS[0]

	# =========================================================
	# Fae Hut / Fae
	# =========================================================
	print("Fae Hut's ENEMY_TRAITS: spawns_fae=%s (expected true)" % [main.ENEMY_TRAITS.get("Fae Hut", {}).get("spawns_fae", false)])
	print("A Fae's default move_range falls back to 2, same as any other undecorated enemy: %s" % [not main.ENEMY_TRAITS.get("Fae", {}).has("move_range")])

	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_allies = []
	main.battle_player_tile = Vector2i(0, 0)
	var fae_hut_script = load("res://scripts/FaeHut.gd")
	var hut_ref = fae_hut_script.new()
	main.add_child(hut_ref)
	hut_ref.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	var hut := {
		"ref": hut_ref, "tile": Vector2i(4, 4), "hp": 10, "max_hp": 10, "move_range": 1,
		"damage": 0, "name": "Fae Hut", "winding_up": false, "stunned": false,
		"attack_range": 1, "concussed_turns": 0, "frozen_turns": 0,
		"burning": false, "armored": false,
		"disarmed_tile": Vector2i(-1, -1),
	}
	main.battle_units = [hut]

	main._process_enemy_turn()
	print("A Fae Hut never moves: tile=%s (expected (4, 4))" % [hut.tile])
	print("...and doesn't spawn before its interval: battle_units_size=%d turns_since_spawn=%d (expected 1, 1)" % [main.battle_units.size(), hut.turns_since_spawn])
	main._process_enemy_turn()
	print("...still nothing at turn 2: battle_units_size=%d (expected 1)" % [main.battle_units.size()])
	main._process_enemy_turn()
	print("A Fae Hut summons a Fae every FAE_HUT_SPAWN_INTERVAL turns: battle_units_size=%d (expected 2), turns_since_spawn_reset=%d (expected 0)" % [
		main.battle_units.size(), hut.turns_since_spawn
	])
	var spawned_fae = null
	for u in main.battle_units:
		if u.name == "Fae":
			spawned_fae = u
	print("...and the new unit really is a Fae, with its own stats: found=%s hp=%d (expected true, %d)" % [
		spawned_fae != null, spawned_fae.hp if spawned_fae != null else -1, spawned_fae.ref.MAX_HEALTH if spawned_fae != null else -1
	])
	print("...placed adjacent to the hut, not on top of it: %s (expected true)" % [
		spawned_fae != null and (spawned_fae.tile - hut.tile).length() == 1.0
	])

	# =========================================================
	# Gnome: HP baked at setup, damage live per currently-alive packmates
	# =========================================================
	main.battle_terrain.clear()
	var gnome_script = load("res://scripts/Gnome.gd")
	var gnome_squad := []
	for i in 3:
		var g = gnome_script.new()
		main.add_child(g)
		g.died.connect(main._on_enemy_died)
		main.enemies_alive += 1
		gnome_squad.append(g)
	main._setup_battle_grid(gnome_squad)
	var expected_gnome_hp: int = gnome_script.MAX_HEALTH + (3 - 1) * main.GNOME_HP_PER_PACKMATE
	var all_hp_boosted := true
	for u in main.battle_units:
		if u.name == "Gnome" and u.max_hp != expected_gnome_hp:
			all_hp_boosted = false
	print("A 3-Gnome pack's HP is boosted at setup, baked once: expected_hp=%d all_match=%s (expected true)" % [expected_gnome_hp, all_hp_boosted])

	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_allies = []
	main.battle_player_tile = Vector2i(4, 4)
	player.max_health = 100
	player.health = 100
	player.equipped_armor = {"damage_reduction": 0.0}
	player.resilience_reduction = 0.0
	player.meta_war_chest_reduction = 0.0
	player.meta_dodge_chance = 0.0
	player.meta_block_negate_chance = 0.0
	player.equipped_shield = {}

	var g1 := _make_gnome(main, Vector2i(3, 4))
	var g2 := _make_gnome(main, Vector2i(0, 0))
	var g3 := _make_gnome(main, Vector2i(0, 1))
	main.battle_units = [g1, g2, g3]
	main._process_enemy_turn()
	var expected_3pack_dmg: int = int(round(2 * (1.0 + main.GNOME_DAMAGE_PCT_PER_PACKMATE * 2)))
	print("3 gnomes alive right now boosts damage live: player_health=%d (expected %d)" % [player.health, 100 - expected_3pack_dmg])

	player.health = 100
	var g4 := _make_gnome(main, Vector2i(3, 4))
	main.battle_units = [g4]
	main._process_enemy_turn()
	print("...but a lone gnome (rest of the pack dead) deals only base damage: player_health=%d (expected %d)" % [player.health, 100 - 2])

	# =========================================================
	# Druid: heals first, buffs second, only fights alone
	# =========================================================
	main.battle_terrain.clear()
	print("Druid's ENEMY_TRAITS: heals_allies=%s buffs_allies=%s (both expected true)" % [
		main.ENEMY_TRAITS.get("Druid", {}).get("heals_allies", false), main.ENEMY_TRAITS.get("Druid", {}).get("buffs_allies", false)
	])

	var druid_script = load("res://scripts/Druid.gd")
	var druid_ref = druid_script.new()
	main.add_child(druid_ref)
	druid_ref.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	var druid := {
		"ref": druid_ref, "tile": Vector2i(1, 1), "hp": 12, "max_hp": 12, "move_range": 2,
		"damage": 1, "name": "Druid", "winding_up": false, "stunned": false,
		"attack_range": 1, "concussed_turns": 0, "frozen_turns": 0,
		"burning": false, "armored": false,
		"disarmed_tile": Vector2i(-1, -1),
	}
	var hurt_goblin := _make_goblin(main, Vector2i(2, 2), 3)
	hurt_goblin.max_hp = 10
	var healthy_goblin := _make_goblin(main, Vector2i(2, 3), 10)
	healthy_goblin.max_hp = 10
	main.battle_units = [druid, hurt_goblin, healthy_goblin]
	main._process_enemy_turn()
	print("Druid heals the worst-hurt ally when one exists, instead of buffing: hurt_hp=%d (expected >3), healthy_buffed=%s (expected false)" % [
		hurt_goblin.hp, healthy_goblin.get("buffed_dmg_turns", 0) > 0
	])

	# Nobody's hurt now -- Druid should buff an un-buffed ally instead.
	hurt_goblin.hp = hurt_goblin.max_hp
	main._process_enemy_turn()
	var buffed_count := 0
	for u in [hurt_goblin, healthy_goblin]:
		if u.get("buffed_dmg_turns", 0) > 0:
			buffed_count += 1
	print("With nobody hurt, Druid buffs an un-buffed ally instead: exactly_one_buffed=%s (expected true)" % [buffed_count == 1])

	# Both allies already buffed -- Druid has nothing left to do but hang back.
	hurt_goblin.buffed_dmg_turns = main.DRUID_BUFF_TURNS
	hurt_goblin.buffed_dmg_pct = main.DRUID_BUFF_DMG_PCT
	healthy_goblin.buffed_dmg_turns = main.DRUID_BUFF_TURNS
	healthy_goblin.buffed_dmg_pct = main.DRUID_BUFF_DMG_PCT
	var druid_tile_before: Vector2i = druid.tile
	main._process_enemy_turn()
	print("With everyone healed and buffed, Druid just hangs back: tile_unchanged=%s (expected true)" % [druid.tile == druid_tile_before])

	# The buff itself: a buffed unit's next attack is boosted, then consumed.
	# An isolated Gnome, not a reused Goblin -- Goblin's OWN pack_bonus_mult
	# would otherwise compound with the buff and muddy this specific check;
	# a single Gnome with no packmates has no bonus of its own to interfere.
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(2, 1)
	player.health = 100
	var buffed_unit := _make_gnome(main, Vector2i(2, 2), 999)
	buffed_unit.damage = 4
	buffed_unit.buffed_dmg_turns = 1
	buffed_unit.buffed_dmg_pct = main.DRUID_BUFF_DMG_PCT
	main.battle_units = [buffed_unit]
	main._process_enemy_turn()
	var expected_buffed_dmg: int = int(round(4 * (1.0 + main.DRUID_BUFF_DMG_PCT)))
	print("A buffed attack deals bonus damage: player_health=%d (expected %d)" % [player.health, 100 - expected_buffed_dmg])
	print("...then the buff is consumed: buffed_dmg_turns=%d (expected 0)" % [buffed_unit.buffed_dmg_turns])

	quit()
