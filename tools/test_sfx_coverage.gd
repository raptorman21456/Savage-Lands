extends SceneTree

# 5 previously-silent mechanics (Mine, shield block, shield knockback, Fae
# Hut spawn, Druid heal/buff) now each play a distinct cue. play_sfx() has no
# return value or "last played" record, so each check snapshots
# sfx_next_player beforehand and confirms THAT pool slot's stream ended up
# matching the expected clip -- the same round-robin play_sfx() itself uses.

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
	var shields_script = load("res://scripts/Shields.gd")
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player

	# --- Data sanity: every new cue actually registered a real clip. ---
	var new_keys := ["mine", "shield_block", "shield_knockback", "fae_spawn", "heal", "buff"]
	var all_present := true
	for k in new_keys:
		if not (main.sfx_streams.has(k) and main.sfx_streams[k] is AudioStreamWAV):
			all_present = false
	print("All 6 new SFX cues are registered as real clips: %s (expected true)" % [all_present])

	# =========================================================
	# Mine (Hand Picks breaking a rock)
	# =========================================================
	main.in_battle = true
	main.battle_turn = "player"
	main.battle_player_tile = Vector2i(4, 4)
	main.battle_terrain = {Vector2i(5, 4): {"type": "rock"}}
	main.battle_rock_target = Vector2i(5, 4)
	var idx: int = main.sfx_next_player
	main._resolve_mine_rock()
	print("Mining a rock plays the 'mine' cue: %s (expected true)" % [main.sfx_players[idx].stream == main.sfx_streams["mine"]])

	# =========================================================
	# Shield block / shield knockback
	# =========================================================
	main.battle_terrain.clear()
	main.battle_allies = []
	main.battle_target_index = 0
	player.equipped_armor = {"damage_reduction": 0.0}
	player.resilience_reduction = 0.0
	player.meta_war_chest_reduction = 0.0
	player.meta_dodge_chance = 0.0
	player.meta_riposte_chance = 0.0
	player.meta_block_negate_chance = 0.0
	player.meta_last_stand_pct_per_10 = 0.0
	player.meta_shield_block_bonus_pct = 0.0
	player.meta_shield_universal = false
	player.max_health = 100
	player.health = 100

	# Iron Bulwark's block is guaranteed by cranking Shield Mastery's bonus
	# past 100% -- simpler than fighting RNG for a deterministic test.
	player.current_weapon = weapons_script.CLUB
	player.coins = 1000
	player.try_buy_shield(shields_script.SHIELDS.shield_bulwark)
	player.meta_shield_block_bonus_pct = 1.0
	var goblin := _make_goblin(main, Vector2i(4, 5))
	main.battle_units = [goblin]
	idx = main.sfx_next_player
	await main._enemy_apply_damage(goblin, main.battle_player_tile, 10, {})
	print("A non-knockback shield block plays 'shield_block' only: block=%s knockback=%s (expected true, false)" % [
		main.sfx_players[idx].stream == main.sfx_streams["shield_block"],
		main.sfx_players[(idx + 1) % main.SFX_POOL_SIZE].stream == main.sfx_streams["shield_knockback"],
	])

	player.health = 100
	player.try_buy_shield(shields_script.SHIELDS.shield_heavy)
	idx = main.sfx_next_player
	await main._enemy_apply_damage(goblin, main.battle_player_tile, 10, {})
	print("A knockback shield block plays both 'shield_block' then 'shield_knockback': %s (expected true, true)" % [
		main.sfx_players[idx].stream == main.sfx_streams["shield_block"]
		and main.sfx_players[(idx + 1) % main.SFX_POOL_SIZE].stream == main.sfx_streams["shield_knockback"]
	])
	player.equipped_shield = {}
	player.meta_shield_block_bonus_pct = 0.0

	# =========================================================
	# Fae Hut spawn
	# =========================================================
	main.battle_terrain.clear()
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
		"disarmed_tile": Vector2i(-1, -1), "turns_since_spawn": main.FAE_HUT_SPAWN_INTERVAL - 1,
	}
	main.battle_units = [hut]
	idx = main.sfx_next_player
	main._process_enemy_turn()
	print("A Fae Hut spawning a Fae plays the 'fae_spawn' cue: %s (expected true)" % [main.sfx_players[idx].stream == main.sfx_streams["fae_spawn"]])

	# =========================================================
	# Druid heal / buff
	# =========================================================
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
	main.battle_units = [druid, hurt_goblin]
	idx = main.sfx_next_player
	main._process_enemy_turn()
	print("Druid healing an ally plays the 'heal' cue: %s (expected true)" % [main.sfx_players[idx].stream == main.sfx_streams["heal"]])

	hurt_goblin.hp = hurt_goblin.max_hp  # nobody hurt now -> Druid buffs instead
	idx = main.sfx_next_player
	main._process_enemy_turn()
	print("Druid buffing an ally plays the 'buff' cue: %s (expected true)" % [main.sfx_players[idx].stream == main.sfx_streams["buff"]])

	quit()
