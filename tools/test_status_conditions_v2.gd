extends SceneTree

# New Stats & Status Conditions, Part 2: the rebalanced player-side
# Concussion/Poison/Burn (POISON_TURNS/POISON_DAMAGE_PCT/BURN_DAMAGE_DIVISOR/
# BURN_DAMAGE_DEALT_REDUCTION already covered by test_reserved_terrain.gd and
# test_arrow_economy.gd via their terrain/arrow sources -- this file covers
# Concussion's own player-side tick/infliction plus Burn's damage-dealt
# reduction and water-clear, since those weren't exercised elsewhere) and the
# four brand-new status effects: Bleeding, Blindness, Exhausted, Fear.

func _make_unit(main, name: String, tile: Vector2i, hp: int = 999999, attack_range: int = 1, move_range: int = 2) -> Dictionary:
	var goblin_script = load("res://scripts/Enemy.gd")
	var g = goblin_script.new()
	main.add_child(g)
	g.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	g.set_physics_process(false)
	return {
		"ref": g, "tile": tile, "hp": hp, "max_hp": hp, "move_range": move_range,
		"damage": 0, "name": name, "winding_up": false, "stunned": false, "size": 1,
		"attack_range": attack_range, "concussed_turns": 0, "frozen_turns": 0,
		"burning": false, "armored": false, "disarmed_tile": Vector2i(-1, -1),
	}

func _init() -> void:
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player

	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_allies = []
	main.battle_player_tile = Vector2i(3, 3)
	player.stat_might = 6
	player.meta_dodge_chance = 0.0
	player.meta_crit_chance = 0.0

	# =========================================================
	# Bleeding: no natural duration -- 5%/tile moved, 10% on a successful
	# dodge, guaranteed on a landed hit from an inflicts_bleed enemy.
	# =========================================================
	player.max_health = 1000
	player.health = 1000
	main.player_bleeding = false
	main.battle_player_moves_left = 5
	main.player_bleeding = true
	main._try_battle_player_move(Vector2i(1, 0))
	var expected_move_bleed: int = int(round(1000 * main.BLEED_MOVE_DAMAGE_PCT))
	print("Bleeding costs %%-of-max-HP per tile moved: health=%d (expected %d), tile=%s (expected (4, 3))" % [
		player.health, 1000 - expected_move_bleed, main.battle_player_tile
	])

	player.health = 1000
	player.meta_dodge_chance = 1.0
	var dodge_result: Dictionary = main._enemy_apply_damage(_make_unit(main, "Goblin", Vector2i(5, 3)), main.battle_player_tile, 10, {})
	var expected_dodge_bleed: int = int(round(1000 * main.BLEED_DODGE_DAMAGE_PCT))
	print("...and a successful dodge costs even more while bleeding: dodged=%s (expected true), health=%d (expected %d)" % [
		dodge_result.get("dodged", false), player.health, 1000 - expected_dodge_bleed
	])
	player.meta_dodge_chance = 0.0
	player.health = 1000
	main.player_bleeding = false

	main._enemy_apply_damage(_make_unit(main, "Goblin", Vector2i(5, 3)), main.battle_player_tile, 5, {"inflicts_bleed": true})
	print("A landed hit from an inflicts_bleed enemy guarantees the status (no roll): player_bleeding=%s (expected true)" % [main.player_bleeding])

	main.battle_terrain.clear()
	var goblin_for_reset = load("res://scripts/Enemy.gd").new()
	main.add_child(goblin_for_reset)
	main._setup_battle_grid([goblin_for_reset])
	print("Bleeding (like every other battle-scoped player status) clears on the next battle setup: player_bleeding=%s (expected false)" % [main.player_bleeding])
	main.battle_terrain.clear()
	main.in_battle = true
	main.battle_allies = []
	main.battle_player_tile = Vector2i(3, 3)

	# =========================================================
	# Blindness: 2 turns, 75% miss chance on the player's own attacks, and
	# any hit that lands is a guaranteed crit (regardless of Dexterity).
	# =========================================================
	player.attack_damage = 10
	var weapons_script = load("res://scripts/Weapons.gd")
	var g_blind := _make_unit(main, "Goblin", Vector2i(4, 3))
	main.battle_units = [g_blind]
	main.battle_target_index = 0
	main._apply_single_hit(0, 1.0, "", weapons_script.CLUB)
	var normal_dmg: int = 999999 - g_blind.hp

	var hits := 0
	var misses := 0
	var all_hits_were_double := true
	for i in 40:
		g_blind.hp = 999999
		main.player_blind_turns = 2
		main._apply_single_hit(0, 1.0, "", weapons_script.CLUB)
		var dealt: int = 999999 - g_blind.hp
		if dealt == 0:
			misses += 1
		else:
			hits += 1
			if dealt != normal_dmg * 2:
				all_hits_were_double = false
	print("Blindness makes most attacks miss entirely but guarantees a crit on anything that lands (40 attempts): hits=%d misses=%d (expected both > 0), all_landed_hits_doubled=%s (expected true)" % [
		hits, misses, all_hits_were_double
	])
	main.player_blind_turns = 0

	main._enemy_apply_damage(_make_unit(main, "Goblin", Vector2i(5, 3)), main.battle_player_tile, 5, {"inflicts_blind": true})
	print("A landed hit from an inflicts_blind enemy guarantees Blindness: player_blind_turns=%d (expected %d)" % [main.player_blind_turns, main.BLINDNESS_TURNS])

	main.battle_units = [_make_unit(main, "Goblin", Vector2i(6, 6))]
	main._process_enemy_turn()
	print("Blindness ticks down once per player turn, same as Concussion: player_blind_turns=%d (expected %d)" % [main.player_blind_turns, main.BLINDNESS_TURNS - 1])
	main.player_blind_turns = 0

	# =========================================================
	# Exhausted: self-inflicted the instant stamina hits 0 -- halves
	# regen_stamina until stamina recovers to 50% of max, fully in Player.gd.
	# =========================================================
	player.max_stamina = player.MAX_STAMINA
	player.stamina = 5
	player.exhausted = false
	var spent_to_zero: bool = player.spend_stamina(5)
	print("Spending stamina down to exactly 0 triggers Exhausted: spent=%s (expected true), stamina=%d (expected 0), exhausted=%s (expected true)" % [
		spent_to_zero, player.stamina, player.exhausted
	])
	player.regen_stamina(20)
	print("...and regen is halved while exhausted: stamina=%d (expected %d, half of 20)" % [player.stamina, int(round(20 * player.EXHAUSTED_STAMINA_REGEN_MULT))])
	player.regen_stamina(80)
	var expected_clear_stamina: int = int(round(20 * player.EXHAUSTED_STAMINA_REGEN_MULT)) + int(round(80 * player.EXHAUSTED_STAMINA_REGEN_MULT))
	print("...until stamina reaches %d%% of max, at which point it clears and later regen is full again: stamina=%d (expected %d), exhausted=%s (expected false)" % [
		int(player.EXHAUSTED_CLEAR_STAMINA_PCT * 100), player.stamina, expected_clear_stamina, player.exhausted
	])
	var stamina_before_full_regen: int = player.stamina
	player.regen_stamina(10)
	print("...full-rate regen confirmed: stamina=%d (expected %d, a full +10 not +5)" % [player.stamina, stamina_before_full_regen + 10])

	# =========================================================
	# Concussion (player-side, rebalanced): a chance to daze the player on a
	# landed hit from an inflicts_concussion enemy; once active, a further
	# chance per turn to take Might-scaled self-damage for its duration.
	# =========================================================
	player.max_health = 1000
	player.health = 1000
	main.player_concussed_turns = 0
	var concussion_inflicted := false
	for i in 60:
		player.health = 1000
		main.player_concussed_turns = 0
		main._enemy_apply_damage(_make_unit(main, "Goblin", Vector2i(5, 3)), main.battle_player_tile, 5, {"inflicts_concussion": true})
		if main.player_concussed_turns > 0:
			concussion_inflicted = true
			break
	print("A landed hit from an inflicts_concussion enemy has a chance to inflict it (up to 60 attempts): inflicted=%s (expected true), turns=%d (expected %d when it lands)" % [
		concussion_inflicted, main.player_concussed_turns, main.PLAYER_CONCUSSION_TURNS
	])

	var concussion_damage_seen := false
	var exact_might_damage := true
	for i in 40:
		player.health = 1000
		main.player_concussed_turns = 2
		main.battle_units = [_make_unit(main, "Goblin", Vector2i(6, 6))]
		main._process_enemy_turn()
		if player.health < 1000:
			concussion_damage_seen = true
			if 1000 - player.health != player.stat_might:
				exact_might_damage = false
	print("Concussion's per-turn self-hit (up to 40 attempts) deals exactly the player's Might stat when it procs: seen=%s (expected true), exact=%s (expected true)" % [
		concussion_damage_seen, exact_might_damage
	])
	main.player_concussed_turns = 2
	main.battle_units = [_make_unit(main, "Goblin", Vector2i(6, 6))]
	main._process_enemy_turn()
	print("...and the turn counter decrements regardless of whether the roll landed: turns=%d (expected 1)" % [main.player_concussed_turns])
	main.player_concussed_turns = 0
	player.health = 1000

	# =========================================================
	# Burn rework: -25% damage DEALT while active (both sides), cleared only
	# by water (already covered structurally by test_reserved_terrain.gd/
	# test_arrow_economy.gd -- this adds the damage-dealt-reduction and the
	# water-clear itself, neither of which those files exercise).
	# =========================================================
	player.attack_damage = 10
	main.player_burning = false
	var g_burn_dmg := _make_unit(main, "Goblin", Vector2i(4, 3))
	main.battle_units = [g_burn_dmg]
	main.battle_target_index = 0
	main._apply_single_hit(0, 1.0, "", weapons_script.CLUB)
	var burn_normal_dmg: int = 999999 - g_burn_dmg.hp
	g_burn_dmg.hp = 999999
	main.player_burning = true
	main._apply_single_hit(0, 1.0, "", weapons_script.CLUB)
	var burn_reduced_dmg: int = 999999 - g_burn_dmg.hp
	print("Burn reduces the player's own damage dealt by 25%%: normal=%d burning=%d (expected burning == round(normal*0.75)=%d)" % [
		burn_normal_dmg, burn_reduced_dmg, int(round(burn_normal_dmg * (1.0 - main.BURN_DAMAGE_DEALT_REDUCTION)))
	])
	main.player_burning = false

	player.health = 1000
	var burn_enemy_result: Dictionary = main._enemy_apply_damage(_make_unit(main, "Goblin", Vector2i(5, 3)), main.battle_player_tile, 20, {})
	var g_burning_attacker := _make_unit(main, "Goblin", Vector2i(5, 3))
	g_burning_attacker.burning = true
	player.health = 1000
	var burn_enemy_reduced: Dictionary = main._enemy_apply_damage(g_burning_attacker, main.battle_player_tile, 20, {})
	print("...and a burning ENEMY's damage dealt is reduced the same way: normal=%d burning=%d (expected burning == round(normal*0.75)=%d)" % [
		burn_enemy_result.dmg, burn_enemy_reduced.dmg, int(round(burn_enemy_result.dmg * (1.0 - main.BURN_DAMAGE_DEALT_REDUCTION)))
	])

	main.player_burning = true
	main.battle_terrain = {Vector2i(3, 3): {"type": "water", "push_dir": Vector2i(0, 0)}}
	main._apply_water_push(Vector2i(3, 3))
	print("Stepping onto water clears the player's Burn: player_burning=%s (expected false)" % [main.player_burning])

	var g_water_burn := _make_unit(main, "Goblin", Vector2i(3, 3))
	g_water_burn.burning = true
	main._apply_water_push(Vector2i(3, 3), g_water_burn)
	print("...and an enemy's Burn the same way: burning=%s (expected false)" % [g_water_burn.burning])
	main.battle_terrain.clear()

	# =========================================================
	# Fear: re-derived fresh every player turn from whichever inflicts_fear
	# enemy currently has the player in ITS OWN attack range -- the entire
	# turn is forced onto a single Attack, no other action available.
	# =========================================================
	player.health = 1000
	player.max_health = 1000
	main.player_burning = false
	main.player_bleeding = false
	main.player_concussed_turns = 0
	main.player_blind_turns = 0

	# In range and reachable by the player's own (melee) weapon: the forced
	# Attack actually lands. _process_enemy_turn's own tail resolving the
	# forced attack synchronously cascades ally(skipped, empty)->enemy turn
	# again (same shape battle_player_turns_to_skip already relies on), so
	# the call can recurse a level or two before finally landing back on
	# "player" -- that's the correct terminal state here, not "ally".
	var g_shade := _make_unit(main, "Shade", Vector2i(4, 3), 999999, 1, 0)
	main.battle_units = [g_shade]
	main.battle_target_index = 99
	main._process_enemy_turn()
	print("Fear forces the whole turn onto a reachable feared enemy: battle_target_index=%d (expected 0), battle_turn=%s (expected player, the cascade always terminates back here), hp=%d (expected < 999999, the forced Attack landed)" % [
		main.battle_target_index, main.battle_turn, g_shade.hp
	])

	# In the fearing enemy's own range, but beyond the player's melee reach,
	# and unable to ever move (move_range 0): nothing about this situation
	# ever changes on its own, so without FEAR_CASCADE_LIMIT this would
	# recurse the ally/enemy-turn cascade above forever -- a real hang/crash,
	# not just a test artifact (an unreachable ranged attacker plus no
	# allies is a perfectly reachable real-game scenario). This confirms the
	# cascade is capped and still lands safely back on "player" instead.
	main.in_battle = true
	var g_mage := _make_unit(main, "Apprentice Mage", Vector2i(7, 3), 999999, main.ARCHER_ATTACK_RANGE, 0)
	main.battle_units = [g_mage]
	main.battle_target_index = 99
	main._process_enemy_turn()
	print("...and when the feared enemy is out of the player's own reach and can never close the gap, the cascade is still capped and lands safely: battle_fear_cascade_depth=%d (expected 0, reset), battle_turn=%s (expected player, not a hang), hp=%d (expected unchanged 999999)" % [
		main.battle_fear_cascade_depth, main.battle_turn, g_mage.hp
	])

	# Dynamic: re-derived fresh, not a stored duration -- once the fearing
	# enemy is gone, the very next turn is unrestricted again.
	main.in_battle = true
	main.battle_units = [_make_unit(main, "Goblin", Vector2i(6, 6))]
	main.battle_target_index = 99
	main._process_enemy_turn()
	print("...and once no inflicts_fear enemy remains, the next turn is free again: battle_feared_by_index=%d (expected -1), battle_target_index=%d (expected unchanged 99, the menu opened normally instead of forcing a target)" % [
		main.battle_feared_by_index, main.battle_target_index
	])

	# Reset the scratch save for whatever test runs next.
	var save_data_script = load("res://scripts/SaveData.gd")
	save_data_script.save_data({"essence": 0, "upgrades": {}, "best_wave": 0})

	quit()
