extends SceneTree

# The weapon specials rework: new coverage per weapon, added alongside each
# one as it's built (see the plan). Existing mechanics reused from before
# the rework (execute, cleave_all, lifesteal, etc.) already have coverage in
# tools/test_combat_specials.gd -- this file is for what's actually new.

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
	main.battle_allies = []
	player.stat_strength = 10
	player.attack_damage = 10

	# =========================================================
	# Spear: diagonal targeting, Piercing Thrust, Wombo Combo,
	# Target Practice.
	# =========================================================
	player.current_weapon = weapons_script.SPEAR
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_target_index = 0

	# --- Diagonal targeting: the Spear (and only the Spear) can target a
	# diagonally-adjacent enemy, which _can_battle_attack refuses by default. ---
	var g_diag := _make_goblin(main, Vector2i(3, 3))
	main.battle_units = [g_diag]
	print("Spear can target a diagonally-adjacent enemy: %s (expected true)" % [0 in main._targetable_indices()])
	player.current_weapon = weapons_script.CLUB
	print("...but Club (or anything else) still can't: %s (expected false)" % [0 in main._targetable_indices()])
	player.current_weapon = weapons_script.SPEAR

	# --- Piercing Thrust: ignores cover, and also hits a second enemy one
	# tile beyond the primary, in the same line. ---
	player.stamina = player.MAX_STAMINA
	var g_pierce_a := _make_goblin(main, Vector2i(3, 2))
	var g_pierce_b := _make_goblin(main, Vector2i(4, 2))
	main.battle_units = [g_pierce_a, g_pierce_b]
	main.battle_target_index = 0
	main._battle_player_special(0)
	var expected_pierce_dmg: int = int(round(10 * weapons_script.SPEAR.damage_mult * 1.25))
	print("Piercing Thrust hits the primary target: dealt=%d (expected %d)" % [999 - g_pierce_a.hp, expected_pierce_dmg])
	print("...and pierces through to the enemy one tile beyond it: dealt=%d (expected %d)" % [999 - g_pierce_b.hp, expected_pierce_dmg])

	# --- Wombo Combo: hits a single target 5-10 times at 17% each (no luck
	# bonus here, so no scaling beyond the base range). ---
	player.stamina = player.MAX_STAMINA
	player.luck_bonus = 0.0
	var g_wombo := _make_goblin(main, Vector2i(3, 2), 999999)
	main.battle_units = [g_wombo]
	main.battle_target_index = 0
	main._battle_player_special(1)
	var per_hit: int = int(round(10 * weapons_script.SPEAR.damage_mult * 0.17))
	var total_wombo_dmg: int = 999999 - g_wombo.hp
	var min_expected: int = per_hit * 5
	var max_expected: int = per_hit * 10
	print("Wombo Combo lands between 5 and 10 hits: total=%d (expected between %d and %d)" % [total_wombo_dmg, min_expected, max_expected])

	# --- Target Practice: over many attempts, every single one resolves as
	# EITHER a kill OR a disarm, never both, never neither. ---
	var saw_kill := false
	var saw_disarm := false
	var any_invalid_outcome := false
	for i in 60:
		player.stamina = player.MAX_STAMINA
		player.disarmed_tile = Vector2i(-1, -1)
		var g_tp := _make_goblin(main, Vector2i(3, 2))
		main.battle_units = [g_tp]
		main.battle_target_index = 0
		main._battle_player_special(2)
		var killed: bool = main.battle_units.is_empty()
		var disarmed: bool = player.disarmed_tile != Vector2i(-1, -1)
		if killed:
			saw_kill = true
		if disarmed:
			saw_disarm = true
		if killed == disarmed:
			any_invalid_outcome = true
	print("Target Practice always resolves as exactly one of kill/disarm: %s (expected true)" % [not any_invalid_outcome])
	print("...and both outcomes are actually reachable over 60 tries: saw_kill=%s saw_disarm=%s (expected true, true)" % [saw_kill, saw_disarm])

	# =========================================================
	# Greatsword: Whirlwind Strike, Low Sweep, Wide Cleave.
	# =========================================================
	# Re-pinned: Target Practice's kills above granted XP, which can level
	# the player up and change attack_damage -- reset before relying on a
	# fixed damage baseline again.
	player.stat_strength = 10
	player.attack_damage = 10
	player.current_weapon = weapons_script.GREATSWORD
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_target_index = 0

	# --- Whirlwind Strike: 2-5 full-cleave passes, each hitting every
	# targetable enemy at 40% damage. ---
	player.stamina = player.MAX_STAMINA
	var g_ww_a := _make_goblin(main, Vector2i(3, 2), 999999)
	var g_ww_b := _make_goblin(main, Vector2i(1, 2), 999999)
	main.battle_units = [g_ww_a, g_ww_b]
	main._battle_player_special(0)
	var ww_per_pass: int = int(round(10 * weapons_script.GREATSWORD.damage_mult * 0.4))
	var ww_dealt_a: int = 999999 - g_ww_a.hp
	var ww_dealt_b: int = 999999 - g_ww_b.hp
	print("Whirlwind Strike hits every targetable enemy 2-5 times each: a=%d b=%d (expected both between %d and %d)" % [
		ww_dealt_a, ww_dealt_b, ww_per_pass * 2, ww_per_pass * 5
	])

	# --- Low Sweep: 80% chance to halve move_range -- run enough trials
	# that a healthy majority land, without pinning the exact count (a real
	# RNG roll, not worth being flaky over). ---
	var halved_count := 0
	var trials := 50
	for i in trials:
		player.stamina = player.MAX_STAMINA
		var g_sweep := _make_goblin(main, Vector2i(3, 2))
		g_sweep.move_range = 4
		main.battle_units = [g_sweep]
		main.battle_target_index = 0
		main._battle_player_special(1)
		if g_sweep.move_range == 2:
			halved_count += 1
	print("Low Sweep halves move_range in a healthy majority of %d trials: halved=%d (expected >= 30, ~80%%)" % [trials, halved_count])

	# --- Wide Cleave: hits everyone in the 3 tiles toward the current
	# target, and refuses outright (refunding stamina) if cover blocks it. ---
	player.stamina = player.MAX_STAMINA
	main.battle_terrain.clear()
	var g_wc_1 := _make_goblin(main, Vector2i(3, 2))
	var g_wc_2 := _make_goblin(main, Vector2i(4, 2))
	var g_wc_3 := _make_goblin(main, Vector2i(5, 2))
	main.battle_units = [g_wc_1, g_wc_2, g_wc_3]
	main.battle_target_index = 0
	main._battle_player_special(2)
	print("Wide Cleave hits all 3 tiles in the line toward the target: %s (expected true, true, true)" % [[g_wc_1.hp < 999, g_wc_2.hp < 999, g_wc_3.hp < 999]])

	player.stamina = player.MAX_STAMINA
	var stamina_before_blocked: int = player.stamina
	main.battle_terrain[Vector2i(4, 2)] = {"type": "rock"}
	var g_wc_blocked := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [g_wc_blocked]
	main.battle_target_index = 0
	main._battle_player_special(2)
	print("Wide Cleave is refused outright when cover blocks the line, and refunds its stamina: hp_unchanged=%s stamina=%d (expected true, %d)" % [
		g_wc_blocked.hp == 999, player.stamina, stamina_before_blocked
	])
	main.battle_terrain.clear()

	# =========================================================
	# Battle Axe: Devastating Slash, Execution, Oldest Trick in the Book.
	# =========================================================
	player.stat_strength = 10
	player.attack_damage = 10
	player.current_weapon = weapons_script.BATTLE_AXE
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_target_index = 0

	# --- Devastating Slash: 180% damage, then the player's own next turn
	# is skipped entirely by the turn cycle. _battle_perform_attack's tail
	# calls _end_player_turn(), which would otherwise cascade all the way
	# through the ally/enemy phases and consume the skip before we could
	# observe it -- in_battle=false halts that cascade at the very first
	# "if not in_battle: return" check in _process_enemy_turn, after the
	# skip counter is set but before anything decrements it again.
	player.stamina = player.MAX_STAMINA
	main.battle_player_turns_to_skip = 0
	var g_slash := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [g_slash]
	main.in_battle = false
	main._battle_player_special(0)
	main.in_battle = true
	var expected_slash_dmg: int = int(round(10 * weapons_script.BATTLE_AXE.damage_mult * 1.8))
	print("Devastating Slash deals 180%% damage: dealt=%d (expected %d)" % [999 - g_slash.hp, expected_slash_dmg])
	print("...and queues exactly one skipped player turn: %d (expected 1)" % [main.battle_player_turns_to_skip])
	main.battle_player_turns_to_skip = 0

	# --- Execution: instakill vs. armorless, zero damage vs. armored. ---
	player.stamina = player.MAX_STAMINA
	var g_unarmored := _make_goblin(main, Vector2i(3, 2))
	g_unarmored.armored = false
	main.battle_units = [g_unarmored]
	main.battle_target_index = 0
	main._battle_player_special(1)
	print("Execution instantly kills an armorless enemy: %s (expected true)" % [main.battle_units.is_empty()])

	player.stamina = player.MAX_STAMINA
	var g_armored := _make_goblin(main, Vector2i(3, 2))
	g_armored.armored = true
	main.battle_units = [g_armored]
	main.battle_target_index = 0
	main._battle_player_special(1)
	print("Execution deals zero damage against an armored enemy: hp_unchanged=%s (expected true)" % [g_armored.hp == 999])

	# --- Oldest Trick in the Book: 40% damage, and stuns via the existing
	# stunned mechanic (reused directly, not a new status). Called via a
	# direct _apply_single_hit, not _battle_player_special -- the latter's
	# _end_player_turn() tail would cascade straight into this same goblin's
	# own (skipped) turn and consume the stun before we ever got to check
	# it, same reasoning as test_combat_specials.gd's own stun_bypass check.
	player.stamina = player.MAX_STAMINA
	var g_trick := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [g_trick]
	var oldest_trick: Dictionary = weapons_script.BATTLE_AXE.specials[2]
	main._apply_single_hit(0, oldest_trick.dmg_mult, oldest_trick.effect, weapons_script.BATTLE_AXE)
	var expected_trick_dmg: int = int(round(10 * weapons_script.BATTLE_AXE.damage_mult * 0.4))
	print("Oldest Trick in the Book deals 40%% damage and stuns: dealt=%d (expected %d), stunned=%s (expected true)" % [
		999 - g_trick.hp, expected_trick_dmg, g_trick.stunned
	])

	# =========================================================
	# War Hammer: Crushing Collision, Maracas, BONK.
	# =========================================================
	player.stat_strength = 10
	player.attack_damage = 10
	player.current_weapon = weapons_script.HAMMER
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_target_index = 0

	# --- Crushing Collision: 80% damage, strips armor (only if armored). ---
	player.stamina = player.MAX_STAMINA
	var g_strip := _make_goblin(main, Vector2i(3, 2))
	g_strip.armored = true
	main.battle_units = [g_strip]
	main._battle_player_special(0)
	var expected_collision_dmg: int = int(round(10 * weapons_script.HAMMER.damage_mult * 0.8))
	print("Crushing Collision deals 80%% damage and strips armor: dealt=%d (expected %d), armored=%s (expected false)" % [
		999 - g_strip.hp, expected_collision_dmg, g_strip.armored
	])

	# --- Maracas: 130% damage, 195% (1.5x) if the target is armored. ---
	player.stamina = player.MAX_STAMINA
	var g_maracas_plain := _make_goblin(main, Vector2i(3, 2))
	g_maracas_plain.armored = false
	main.battle_units = [g_maracas_plain]
	main.battle_target_index = 0
	main._battle_player_special(1)
	var expected_maracas_plain: int = int(round(10 * weapons_script.HAMMER.damage_mult * 1.3))
	print("Maracas deals 130%% damage against an unarmored target: dealt=%d (expected %d)" % [999 - g_maracas_plain.hp, expected_maracas_plain])

	player.stamina = player.MAX_STAMINA
	var g_maracas_armored := _make_goblin(main, Vector2i(3, 2))
	g_maracas_armored.armored = true
	main.battle_units = [g_maracas_armored]
	main.battle_target_index = 0
	main._battle_player_special(1)
	var expected_maracas_armored: int = int(round(expected_maracas_plain * 1.5))
	print("...and 195%% (1.5x bonus) against an armored one: dealt=%d (expected %d)" % [999 - g_maracas_armored.hp, expected_maracas_armored])

	# --- BONK: 110% damage, inflicts Concussed for 3 turns. Direct
	# _apply_single_hit, same reasoning as Oldest Trick in the Book above --
	# the cascaded enemy turn would otherwise start consuming the counter
	# before we could observe its starting value. ---
	player.stamina = player.MAX_STAMINA
	var g_bonk := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [g_bonk]
	var bonk: Dictionary = weapons_script.HAMMER.specials[2]
	main._apply_single_hit(0, bonk.dmg_mult, bonk.effect, weapons_script.HAMMER)
	var expected_bonk_dmg: int = int(round(10 * weapons_script.HAMMER.damage_mult * 1.1))
	print("BONK deals 110%% damage and inflicts Concussed for 3 turns: dealt=%d (expected %d), concussed_turns=%d (expected 3)" % [
		999 - g_bonk.hp, expected_bonk_dmg, g_bonk.concussed_turns
	])

	# =========================================================
	# Dagger: Flurry Slice, Knife Throw (Bleeding Cut is unchanged, already
	# covered by test_combat_specials.gd's generic lifesteal check).
	# =========================================================
	# Dagger's damage_mult (0.45) is low enough that a 10-attack_damage
	# baseline rounds Flurry Slice's already-small 10% per-hit down to 0 --
	# bump the baseline for this section so the per-hit amount is
	# meaningful to assert on.
	player.stat_strength = 50
	player.attack_damage = 50
	player.current_weapon = weapons_script.DAGGER
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_target_index = 0

	# --- Flurry Slice: 8-13 hits at 10% damage each. ---
	player.stamina = player.MAX_STAMINA
	var g_flurry := _make_goblin(main, Vector2i(3, 2), 999999)
	main.battle_units = [g_flurry]
	main._battle_player_special(0)
	var flurry_per_hit: int = int(round(50 * weapons_script.DAGGER.damage_mult * 0.1))
	var flurry_total: int = 999999 - g_flurry.hp
	print("Flurry Slice lands between 8 and 13 hits: total=%d (expected between %d and %d)" % [
		flurry_total, flurry_per_hit * 8, flurry_per_hit * 13
	])

	# --- Knife Throw: 200% damage, always disarms afterward regardless of
	# outcome. ---
	player.stamina = player.MAX_STAMINA
	player.disarmed_tile = Vector2i(-1, -1)
	var g_throw := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [g_throw]
	main.battle_target_index = 0
	main._battle_player_special(2)
	var expected_throw_dmg: int = int(round(50 * weapons_script.DAGGER.damage_mult * 2.0))
	print("Knife Throw deals 200%% damage and always disarms you: dealt=%d (expected %d), disarmed=%s (expected true)" % [
		999 - g_throw.hp, expected_throw_dmg, player.disarmed_tile != Vector2i(-1, -1)
	])
	player.disarmed_tile = Vector2i(-1, -1)

	# =========================================================
	# Knuckle Gloves: The 'Ol One-Two, Wrist Strike, Clothesliner.
	# =========================================================
	player.stat_strength = 10
	player.attack_damage = 10
	player.current_weapon = weapons_script.KNUCKLE_GLOVES
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_target_index = 0

	# --- The 'Ol One-Two: with only one enemy in range, hits it twice at
	# 75% each. ---
	player.stamina = player.MAX_STAMINA
	var g_onetwo_solo := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [g_onetwo_solo]
	main._battle_player_special(0)
	var onetwo_solo_hit: int = int(round(10 * weapons_script.KNUCKLE_GLOVES.damage_mult * 0.75))
	print("The 'Ol One-Two hits a lone target twice at 75%% each: dealt=%d (expected ~%d, two hits of %d each)" % [
		999 - g_onetwo_solo.hp, onetwo_solo_hit * 2, onetwo_solo_hit
	])

	# --- With a second enemy in range, splits between both at 70% each
	# instead of double-hitting the one. ---
	player.stamina = player.MAX_STAMINA
	var g_onetwo_a := _make_goblin(main, Vector2i(3, 2))
	var g_onetwo_b := _make_goblin(main, Vector2i(1, 2))
	main.battle_units = [g_onetwo_a, g_onetwo_b]
	main.battle_target_index = 0
	main._battle_player_special(0)
	var onetwo_split_hit: int = int(round(10 * weapons_script.KNUCKLE_GLOVES.damage_mult * 0.7))
	print("...but splits 70%% across both targets when a second is in range: a=%d b=%d (expected both %d)" % [
		999 - g_onetwo_a.hp, 999 - g_onetwo_b.hp, onetwo_split_hit
	])

	# --- Wrist Strike: 65% damage, disarms the enemy (weapon flies to a
	# random tile, it can't attack until it reaches it). ---
	player.stamina = player.MAX_STAMINA
	var g_wrist := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [g_wrist]
	main.battle_target_index = 0
	main._battle_player_special(1)
	var expected_wrist_dmg: int = int(round(10 * weapons_script.KNUCKLE_GLOVES.damage_mult * 0.65))
	print("Wrist Strike deals 65%% damage and disarms the enemy: dealt=%d (expected %d), disarmed=%s (expected true)" % [
		999 - g_wrist.hp, expected_wrist_dmg, g_wrist.disarmed_tile != Vector2i(-1, -1)
	])

	# --- Clothesliner: 150% damage, pulls the target to the tile directly
	# behind the player instead of the usual push-away knockback. ---
	player.stamina = player.MAX_STAMINA
	var g_clothesline := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [g_clothesline]
	main.battle_target_index = 0
	main._battle_player_special(2)
	var expected_clothesline_dmg: int = int(round(10 * weapons_script.KNUCKLE_GLOVES.damage_mult * 1.5))
	print("Clothesliner deals 150%% damage and pulls the target behind you: dealt=%d (expected %d), tile=%s (expected (1, 2), behind the player at (2,2) toward (3,2))" % [
		999 - g_clothesline.hp, expected_clothesline_dmg, g_clothesline.tile
	])

	# =========================================================
	# Hand Picks: Pichaku, DIAMONDS, Minernado.
	# =========================================================
	player.stat_strength = 10
	player.attack_damage = 10
	player.current_weapon = weapons_script.HAND_PICKS
	player.pichaku_active = false
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_target_index = 0

	# --- Pichaku: a pure self-buff, no damage dealt, but still requires (and
	# spends) a target/turn like any other special. ---
	player.stamina = player.MAX_STAMINA
	var g_pichaku_activate := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [g_pichaku_activate]
	main._battle_player_special(0)
	print("Pichaku deals no damage and activates the stance: hp_unchanged=%s pichaku_active=%s (expected true, true)" % [
		g_pichaku_activate.hp == 999, player.pichaku_active
	])

	# --- Pichaku's damage multiplier: while active, a regular/heavy hit
	# (effect == "") deals 80% of its normal damage. Checked via a direct
	# _apply_single_hit call so the double-hit roll below can't muddy the
	# exact-damage assertion. ---
	var g_pichaku_dmg := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [g_pichaku_dmg]
	main._apply_single_hit(0, 1.0, "", weapons_script.HAND_PICKS)
	var expected_pichaku_dmg: int = int(round(10 * weapons_script.HAND_PICKS.damage_mult * main.PICHAKU_DAMAGE_MULT))
	print("Pichaku reduces a regular/heavy attack's damage to 80%%: dealt=%d (expected %d)" % [999 - g_pichaku_dmg.hp, expected_pichaku_dmg])

	# --- Pichaku's double-hit chance: 20% of regular/heavy attacks land a
	# second hit. Run enough trials that a healthy minority land, without
	# pinning the exact count (a real RNG roll, not worth being flaky over). ---
	var double_count := 0
	var dh_trials := 200
	var per_hit_dmg: int = int(round(10 * weapons_script.HAND_PICKS.damage_mult * main.PICHAKU_DAMAGE_MULT))
	for i in dh_trials:
		player.stamina = player.MAX_STAMINA
		var g_dh := _make_goblin(main, Vector2i(3, 2), 999999)
		main.battle_units = [g_dh]
		main.battle_target_index = 0
		main._battle_player_fight()
		if 999999 - g_dh.hp >= per_hit_dmg * 2:
			double_count += 1
	print("Pichaku's double-hit chance triggers in a healthy minority of %d trials: double_count=%d (expected roughly 20%%, i.e. between 10 and 70)" % [dh_trials, double_count])
	player.pichaku_active = false

	# --- DIAMONDS: can strike an enemy far outside normal melee range,
	# teleporting the player onto its (pre-hit) tile and knocking it back --
	# the range-limited targetable list is checked first to confirm this
	# really is otherwise unreachable. ---
	player.stamina = player.MAX_STAMINA
	main.battle_player_tile = Vector2i(0, 2)
	var g_diamonds := _make_goblin(main, Vector2i(4, 2))
	main.battle_units = [g_diamonds]
	main.battle_target_index = 0
	print("DIAMONDS' target is otherwise out of normal range: %s (expected true, targetable is empty)" % [main._targetable_indices().is_empty()])
	main._battle_player_special(1)
	var expected_diamonds_dmg: int = int(round(10 * weapons_script.HAND_PICKS.damage_mult * 2.0))
	print("DIAMONDS deals 200%% damage to a far-off target: dealt=%d (expected %d)" % [999 - g_diamonds.hp, expected_diamonds_dmg])
	print("...teleports the player onto its original tile: player_tile=%s (expected (4, 2))" % [main.battle_player_tile])
	print("...and knocks the target back a tile away from the player: target_tile=%s (expected (5, 2))" % [g_diamonds.tile])

	# --- Minernado: 4-7 hits at 20% damage each. ---
	player.stamina = player.MAX_STAMINA
	main.battle_player_tile = Vector2i(2, 2)
	var g_minernado := _make_goblin(main, Vector2i(3, 2), 999999)
	main.battle_units = [g_minernado]
	main.battle_target_index = 0
	main._battle_player_special(2)
	var minernado_per_hit: int = int(round(10 * weapons_script.HAND_PICKS.damage_mult * 0.2))
	var minernado_total: int = 999999 - g_minernado.hp
	print("Minernado lands between 4 and 7 hits: total=%d (expected between %d and %d)" % [
		minernado_total, minernado_per_hit * 4, minernado_per_hit * 7
	])

	# Reset the scratch save for whatever test runs next.
	var save_data_script = load("res://scripts/SaveData.gd")
	save_data_script.save_data({"essence": 0, "upgrades": {}, "best_wave": 0})

	quit()
