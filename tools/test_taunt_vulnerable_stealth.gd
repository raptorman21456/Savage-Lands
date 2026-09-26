extends SceneTree

# Taunt, Vulnerable, Stealth (+ always-on LOS detection, wander AI, Dagger
# sneak bonus). See C:\Users\maxjm\.claude\plans\recursive-squishing-stream.md
# for the full design. Detection is ALWAYS on: every non-boss unit starts a
# battle with aware_of_player == false and must actually spot the player
# (ENEMY_SIGHT_RANGE + line of sight, latched via _update_enemy_awareness)
# before it'll target them -- Stealth only shrinks that range further
# (STEALTH_SIGHT_RANGE) while active, it isn't the trigger for the system
# existing at all. Once latched, aware_of_player is sticky for the rest of
# the battle. Boss-tier enemies are always aware; Taunt and landing any hit
# both mark a unit aware immediately.

func _make_unit(main, name: String, tile: Vector2i, hp: int = 999999, move_range: int = 2, size: int = 1) -> Dictionary:
	var enemy_script = load("res://scripts/Enemy.gd")
	var e = enemy_script.new()
	main.add_child(e)
	e.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	e.set_physics_process(false)
	return {
		"ref": e, "tile": tile, "hp": hp, "max_hp": hp, "move_range": move_range,
		"damage": 0, "name": name, "winding_up": false, "stunned": false, "size": size,
		"attack_range": 1, "concussed_turns": 0, "frozen_turns": 0,
		"burning": false, "vulnerable_turns": 0, "aware_of_player": false,
		"armored": false, "disarmed_tile": Vector2i(-1, -1),
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
	main.BATTLE_GRID_W = 15
	main.BATTLE_GRID_H = 15
	main.battle_terrain.clear()
	main.battle_allies = []
	main.battle_player_tile = Vector2i(7, 7)
	player.current_weapon = weapons_script.CLUB
	player.stamina = player.max_stamina
	player.stealth_turns_remaining = 0
	player.berserk_turns_remaining = 0
	player.meta_crit_chance = 0.0
	player.temp_damage_bonus_pct = 0.0
	player.meta_low_hp_damage_bonus_pct = 0.0
	main.battle_momentum_stacks = 0
	main.battle_player_defending = false
	main.battle_player_taunting = false

	# --- Taunt: same flag-shape as Defend, plus forced targeting, plus
	# permanently revealing the player to the whole squad. ---
	# _battle_player_taunt() ends with _end_player_turn(), which (since
	# battle_units is empty here) cascades straight to _battle_victory()
	# rather than a real enemy turn -- so the flags are checked in their
	# immediate post-call state, before anything downstream could touch them.
	main.battle_units = []
	main._battle_player_taunt()
	print("Taunt sets both battle_player_taunting and battle_player_defending (Defend's own reduction gate): taunting=%s defending=%s (expected both true)" % [main.battle_player_taunting, main.battle_player_defending])
	main.battle_player_defending = false
	main.battle_player_taunting = false
	main.in_battle = true

	# With a real unit present this time, the same call's cascade runs a full
	# enemy turn (which legitimately resets taunting/defending afterward --
	# tested separately below) -- aware_of_player isn't touched by that
	# reset, so it's the one flag still meaningful to check post-call here.
	var g_taunt_reveal := _make_unit(main, "Goblin", Vector2i(0, 0))
	main.battle_units = [g_taunt_reveal]
	main._battle_player_taunt()
	print("...and immediately reveals the player to every current unit, permanently: aware_of_player=%s (expected true)" % [g_taunt_reveal.aware_of_player])
	main.battle_player_defending = false
	main.battle_player_taunting = false

	# Forced targeting: an ally sits within attack range, the player doesn't.
	# Without Taunt the enemy (unaware of the player by default) attacks the
	# closer ally; with Taunt active it's forced onto the player instead and
	# (being out of range this single turn) doesn't land a hit on anyone.
	main.battle_allies = [{"tile": Vector2i(8, 8), "hp": 20, "max_hp": 20, "dmg_mult": 1.0, "name": "Wolf", "move_range": 2, "attack_range": 1}]
	var g_untaunted := _make_unit(main, "Goblin", Vector2i(8, 9))
	main.battle_units = [g_untaunted]
	main._process_enemy_turn()
	var ally_hp_after_untaunted: int = main.battle_allies[0].hp
	print("Without Taunt, an enemy already in range attacks the closer ally: ally_hp=%d (expected < 20)" % [ally_hp_after_untaunted])

	main.battle_allies = [{"tile": Vector2i(8, 8), "hp": 20, "max_hp": 20, "dmg_mult": 1.0, "name": "Wolf", "move_range": 2, "attack_range": 1}]
	var g_taunted := _make_unit(main, "Goblin", Vector2i(8, 9))
	main.battle_units = [g_taunted]
	main.battle_player_taunting = true
	main._process_enemy_turn()
	var ally_hp_after_taunted: int = main.battle_allies[0].hp
	print("With Taunt active, the same enemy is forced onto the player instead and doesn't land a hit on the ally: ally_hp=%d (expected 20, unchanged)" % [ally_hp_after_taunted])
	main.battle_player_taunting = false
	main.battle_allies = []

	# --- Vulnerable: crit-triggered, ticks on the unit's own turn, +25%
	# damage taken from ANY attacker (player or ally) through _apply_single_hit. ---
	player.attack_damage = 40
	var g_vuln := _make_unit(main, "Goblin", Vector2i(9, 9))
	main.battle_units = [g_vuln]
	main.battle_target_index = 0
	player.meta_crit_chance = 1.0
	main._apply_single_hit(0, 1.0, "", weapons_script.CLUB)
	print("A landed player crit sets the target's vulnerable_turns: vulnerable_turns=%d (expected %d)" % [g_vuln.vulnerable_turns, main.VULNERABLE_TURNS])
	player.meta_crit_chance = 0.0

	var g_novuln_ctrl := _make_unit(main, "Goblin", Vector2i(9, 9))
	main.battle_units = [g_novuln_ctrl]
	main._apply_single_hit(0, 1.0, "", weapons_script.CLUB)
	var dmg_normal: int = 999999 - g_novuln_ctrl.hp

	var g_vuln_applied := _make_unit(main, "Goblin", Vector2i(9, 9))
	g_vuln_applied.vulnerable_turns = 1
	main.battle_units = [g_vuln_applied]
	main._apply_single_hit(0, 1.0, "", weapons_script.CLUB)
	var dmg_vulnerable: int = 999999 - g_vuln_applied.hp
	print("Vulnerable adds +25%% damage taken from the player: normal=%d vulnerable=%d (expected vulnerable == round(normal*1.25)=%d)" % [dmg_normal, dmg_vulnerable, int(round(dmg_normal * 1.25))])

	var g_vuln_ally := _make_unit(main, "Goblin", Vector2i(9, 9))
	g_vuln_ally.vulnerable_turns = 1
	main.battle_units = [g_vuln_ally]
	main._apply_single_hit(0, 1.0, "", weapons_script.CLUB, "Wolf")
	var dmg_vulnerable_ally: int = 999999 - g_vuln_ally.hp
	print("...and the same multiplier applies to an ALLY's hit through the same function: dmg=%d (expected == round(normal*1.25)=%d)" % [dmg_vulnerable_ally, int(round(dmg_normal * 1.25))])

	var g_vuln_tick := _make_unit(main, "Goblin", Vector2i(10, 10))
	g_vuln_tick.vulnerable_turns = 2
	g_vuln_tick.aware_of_player = true
	main.battle_units = [g_vuln_tick]
	main._process_enemy_turn()
	print("Vulnerable ticks down once per the unit's own turn: vulnerable_turns=%d (expected 1)" % [g_vuln_tick.vulnerable_turns])

	# --- Always-on detection: a fresh unit starts every battle unaware, and
	# only becomes (permanently) aware once _update_enemy_awareness actually
	# latches it -- close enough (ENEMY_SIGHT_RANGE, or STEALTH_SIGHT_RANGE
	# while stealthed) with clear line of sight. ---
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(7, 7)
	player.stealth_turns_remaining = 0

	var u_far := _make_unit(main, "Goblin", Vector2i(0, 0))
	print("A fresh unit starts every battle unaware by default (no live re-check, no auto-true outside Stealth): sees=%s (expected false)" % [main._enemy_currently_sees_player(u_far)])

	var u_close := _make_unit(main, "Goblin", Vector2i(9, 7))
	main.battle_units = [u_close]
	main._update_enemy_awareness()
	print("_update_enemy_awareness latches a unit within ENEMY_SIGHT_RANGE(%d) with clear LOS: aware_of_player=%s (expected true)" % [main.ENEMY_SIGHT_RANGE, u_close.aware_of_player])

	var u_far2 := _make_unit(main, "Goblin", Vector2i(0, 0))
	main.battle_units = [u_far2]
	main._update_enemy_awareness()
	print("...but not a unit beyond ENEMY_SIGHT_RANGE: aware_of_player=%s (expected false)" % [u_far2.aware_of_player])

	var u_blocked := _make_unit(main, "Goblin", Vector2i(11, 7))
	main.battle_terrain[Vector2i(9, 7)] = {"type": "rock"}
	main.battle_units = [u_blocked]
	main._update_enemy_awareness()
	print("...nor a unit within range but blocked by a rock strictly between it and the player: aware_of_player=%s (expected false)" % [u_blocked.aware_of_player])
	main.battle_terrain.clear()
	main._update_enemy_awareness()
	print("...but latches on the very next check once the rock is cleared: aware_of_player=%s (expected true)" % [u_blocked.aware_of_player])

	print("Once latched, awareness is sticky -- moving back out of range doesn't un-spot a unit: (using u_close from above)")
	u_close.tile = Vector2i(0, 0)
	main.battle_units = [u_close]
	main._update_enemy_awareness()
	print("  aware_of_player=%s (expected still true)" % [u_close.aware_of_player])

	var u_mid_normal := _make_unit(main, "Goblin", Vector2i(10, 7))
	main.battle_units = [u_mid_normal]
	player.stealth_turns_remaining = 0
	main._update_enemy_awareness()
	print("A unit at distance 3 (between STEALTH_SIGHT_RANGE(%d) and ENEMY_SIGHT_RANGE(%d)) is spotted while NOT stealthed: aware_of_player=%s (expected true)" % [main.STEALTH_SIGHT_RANGE, main.ENEMY_SIGHT_RANGE, u_mid_normal.aware_of_player])

	var u_mid_stealthed := _make_unit(main, "Goblin", Vector2i(10, 7))
	main.battle_units = [u_mid_stealthed]
	player.stealth_turns_remaining = main.STEALTH_TURNS
	main._update_enemy_awareness()
	print("...but NOT spotted at the same distance while Stealth shrinks the range: aware_of_player=%s (expected false)" % [u_mid_stealthed.aware_of_player])
	player.stealth_turns_remaining = 0

	var u_boss := _make_unit(main, "Owlbear", Vector2i(0, 0), 999999, 2, 2)
	print("Boss-tier enemies are always aware regardless of distance or their own stored flag: sees=%s (expected true, aware_of_player itself stays %s)" % [main._enemy_currently_sees_player(u_boss), u_boss.aware_of_player])

	var g_reveal := _make_unit(main, "Goblin", Vector2i(0, 0))
	main.battle_units = [g_reveal]
	main._apply_single_hit(0, 1.0, "", weapons_script.CLUB)
	print("Landing any hit immediately reveals its target, regardless of distance: aware_of_player=%s (expected true)" % [g_reveal.aware_of_player])

	# --- Wander: unaware + no ally target -> sentinel from
	# _pick_enemy_target_tile, consumed by _process_enemy_turn's wander branch. ---
	main.battle_allies = []
	var u_sentinel := _make_unit(main, "Goblin", Vector2i(0, 0))
	var picked: Vector2i = main._pick_enemy_target_tile(u_sentinel)
	print("A fresh (default-unaware) unit with no ally alive returns the wander sentinel: picked=%s (expected (-1, -1))" % [picked])

	main.battle_allies = [{"tile": Vector2i(1, 1), "hp": 20, "max_hp": 20, "dmg_mult": 1.0, "name": "Wolf", "move_range": 2, "attack_range": 1}]
	var picked_with_ally: Vector2i = main._pick_enemy_target_tile(u_sentinel)
	print("...but falls back to a living ally instead of wandering when one exists: picked=%s (expected (1, 1))" % [picked_with_ally])
	main.battle_allies = []

	main.battle_terrain.clear()
	main.battle_units = []
	var max_wander_dist := 0
	for i in 30:
		var u_wander := {"tile": Vector2i(3, 3), "move_range": 5, "max_hp": 999999, "hp": 999999, "name": "Goblin", "ref": null}
		main._move_enemy_wander(u_wander)
		var dist: int = abs(u_wander.tile.x - 3) + abs(u_wander.tile.y - 3)
		max_wander_dist = max(max_wander_dist, dist)
	print("_move_enemy_wander throttles a fast (move_range=5) unit to WANDER_MOVE_RANGE_CAP over 30 trials: max_dist_seen=%d (expected <= %d)" % [max_wander_dist, main.WANDER_MOVE_RANGE_CAP])

	# --- Dagger sneak-crit bonus: is_crit + attacker_label=="You" +
	# was_unaware + Dagger equipped -> +KNIFE_STEALTH_CRIT_BONUS flat. Works
	# off the same default-unaware state as everything else above -- no
	# Stealth required for the bonus itself, only for Stealth's OWN
	# guaranteed-crit mechanism (tested separately below). ---
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(7, 7)
	player.attack_damage = 40
	player.current_weapon = weapons_script.DAGGER
	player.meta_crit_chance = 1.0
	var dagger_mult: float = weapons_script.DAGGER.get("damage_mult", 1.0)
	var base_dagger_dmg: int = int(round(40.0 * dagger_mult))

	var g_sneak := _make_unit(main, "Goblin", Vector2i(0, 0))
	main.battle_units = [g_sneak]
	main._apply_single_hit(0, 1.0, "", weapons_script.DAGGER)
	var sneak_dmg: int = 999999 - g_sneak.hp
	var expected_sneak_dmg: int = base_dagger_dmg * 2 + main.KNIFE_STEALTH_CRIT_BONUS
	print("A crit landed on a default-unaware enemy with a Dagger equipped adds the flat sneak bonus (no Stealth needed): dmg=%d (expected %d, base*2 + %d)" % [sneak_dmg, expected_sneak_dmg, main.KNIFE_STEALTH_CRIT_BONUS])

	var g_sneak_club := _make_unit(main, "Goblin", Vector2i(0, 0))
	main.battle_units = [g_sneak_club]
	player.current_weapon = weapons_script.CLUB
	main._apply_single_hit(0, 1.0, "", weapons_script.CLUB)
	var club_sneak_dmg: int = 999999 - g_sneak_club.hp
	var base_club_dmg: int = int(round(40.0 * weapons_script.CLUB.get("damage_mult", 1.0)))
	print("...but the bonus is Dagger-specific -- the same crit with a Club gets no +%d: dmg=%d (expected == base*2 = %d, no bonus)" % [main.KNIFE_STEALTH_CRIT_BONUS, club_sneak_dmg, base_club_dmg * 2])
	player.current_weapon = weapons_script.DAGGER

	var g_sneak_aware := _make_unit(main, "Goblin", Vector2i(0, 0))
	g_sneak_aware.aware_of_player = true
	main.battle_units = [g_sneak_aware]
	main._apply_single_hit(0, 1.0, "", weapons_script.DAGGER)
	var aware_sneak_dmg: int = 999999 - g_sneak_aware.hp
	print("...and requires the target to actually be unaware -- a crit on an already-aware enemy gets no bonus: dmg=%d (expected == base*2 = %d)" % [aware_sneak_dmg, base_dagger_dmg * 2])
	player.meta_crit_chance = 0.0

	# Stealth's OWN guaranteed-crit mechanism: consumed by the FIRST hit
	# inside _apply_single_hit itself, so a second hit immediately after
	# (same call sequence a multi-hit special would make) isn't also forced.
	player.stealth_turns_remaining = main.STEALTH_TURNS
	var g_multi_a := _make_unit(main, "Goblin", Vector2i(0, 0))
	var g_multi_b := _make_unit(main, "Goblin", Vector2i(0, 0))
	main.battle_units = [g_multi_a, g_multi_b]
	main._apply_single_hit(0, 1.0, "", weapons_script.DAGGER)
	var first_hit_dmg: int = 999999 - g_multi_a.hp
	main._apply_single_hit(1, 1.0, "", weapons_script.DAGGER)
	var second_hit_dmg: int = 999999 - g_multi_b.hp
	print("Stealth's forced crit lands on the first hit (dmg=%d, expected %d) and breaks stealth: stealth_consumed=%s (expected true)" % [first_hit_dmg, expected_sneak_dmg, player.stealth_turns_remaining == 0])
	print("...so a second hit right after isn't also forced/bonused: second_hit_dmg=%d (expected == base_dagger_dmg = %d, no crit, no bonus)" % [second_hit_dmg, base_dagger_dmg])
	player.stealth_turns_remaining = 0

	# Reset the scratch save for whatever test runs next.
	var save_data_script = load("res://scripts/SaveData.gd")
	save_data_script.save_data({"essence": 0, "upgrades": {}, "best_wave": 0})

	quit()
