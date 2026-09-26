extends SceneTree

# New Stats & Status Conditions, Part 3: Rage/Berserk. Killing an enemy
# mid-battle triggers/refreshes a 2-turn Berserk state (Player.gd:
# berserk_turns_remaining) -- +50%+Rage's own meta_rage_bonus_pct damage
# dealt, shields forced off entirely, Block Master/Reflexes dodge both cut
# to a quarter of their normal rate.

func _make_unit(main, name: String, tile: Vector2i, hp: int = 999999) -> Dictionary:
	var goblin_script = load("res://scripts/Enemy.gd")
	var g = goblin_script.new()
	main.add_child(g)
	g.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	g.set_physics_process(false)
	return {
		"ref": g, "tile": tile, "hp": hp, "max_hp": hp, "move_range": 2,
		"damage": 0, "name": name, "winding_up": false, "stunned": false, "size": 1,
		"attack_range": 1, "concussed_turns": 0, "frozen_turns": 0,
		"burning": false, "armored": false, "disarmed_tile": Vector2i(-1, -1),
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
	var shields_script = load("res://scripts/Shields.gd")

	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_allies = []
	main.battle_player_tile = Vector2i(3, 3)
	player.current_weapon = weapons_script.CLUB
	player.berserk_turns_remaining = 0
	player.meta_rage_bonus_pct = 0.0

	# --- Trigger: any kill mid-battle sets it to the full duration. ---
	main._on_enemy_died(0, "Goblin")
	print("A kill mid-battle triggers Berserk: berserk_turns_remaining=%d (expected %d)" % [player.berserk_turns_remaining, main.BERSERK_TURNS])

	player.berserk_turns_remaining = 1
	main._on_enemy_died(0, "Goblin")
	print("...and refreshes back to full duration even if already active (doesn't stack): berserk_turns_remaining=%d (expected %d)" % [player.berserk_turns_remaining, main.BERSERK_TURNS])

	main.in_battle = false
	player.berserk_turns_remaining = 0
	main._on_enemy_died(0, "Goblin")
	print("...but only while actually in a battle: berserk_turns_remaining=%d (expected 0, an overworld kill doesn't trigger it)" % [player.berserk_turns_remaining])
	main.in_battle = true

	# --- Damage bonus: +50%+meta_rage_bonus_pct, gated on attacker_label so
	# an ally's own hit through the same function is unaffected. ---
	player.attack_damage = 10
	var g_dmg := _make_unit(main, "Goblin", Vector2i(4, 3))
	main.battle_units = [g_dmg]
	main.battle_target_index = 0
	player.berserk_turns_remaining = 0
	main._apply_single_hit(0, 1.0, "", weapons_script.CLUB)
	var normal_dmg: int = 999999 - g_dmg.hp

	g_dmg.hp = 999999
	player.berserk_turns_remaining = 2
	main._apply_single_hit(0, 1.0, "", weapons_script.CLUB)
	var berserk_dmg: int = 999999 - g_dmg.hp
	print("Berserk boosts damage dealt by +50%%: normal=%d berserk=%d (expected berserk == round(normal*1.5)=%d)" % [
		normal_dmg, berserk_dmg, int(round(normal_dmg * 1.5))
	])

	g_dmg.hp = 999999
	player.meta_rage_bonus_pct = 0.3
	main._apply_single_hit(0, 1.0, "", weapons_script.CLUB)
	var berserk_with_rage_dmg: int = 999999 - g_dmg.hp
	print("...and Rage's own bonus stacks on top: berserk_with_rage=%d (expected round(normal*1.8)=%d, +50%% base +30%% Rage)" % [
		berserk_with_rage_dmg, int(round(normal_dmg * 1.8))
	])

	g_dmg.hp = 999999
	main._apply_single_hit(0, 1.0, "", weapons_script.CLUB, "Blade Ally")
	var ally_dmg: int = 999999 - g_dmg.hp
	print("...but never applies to an ally's own hit through the same function: ally_dmg=%d (expected == normal_dmg=%d, not boosted)" % [ally_dmg, normal_dmg])
	player.meta_rage_bonus_pct = 0.0

	# --- Shields forced off entirely while berserk. ---
	var buckler: Dictionary = shields_script.SHIELDS.shield_buckler
	player.equipped_shield = buckler
	player.berserk_turns_remaining = 0
	var block_before: float = player.shield_block_chance()
	player.berserk_turns_remaining = 2
	var block_during: float = player.shield_block_chance()
	print("Berserk forces shield_block_chance to 0: before=%.2f (expected > 0) during=%.2f (expected 0.0)" % [block_before, block_during])
	player.equipped_shield = {}

	# --- Block Master (Defend) cut to a quarter of its normal rate: 40% base
	# -> 10% while berserk, proven via a large sample rather than a single
	# roll (Godot's clean 0%/100% edge cases don't distinguish "scaled down"
	# from "always/never triggers" the way an intermediate rate does).
	player.meta_block_negate_chance = 0.4
	main.battle_player_defending = true
	player.berserk_turns_remaining = 0
	var negates_normal := 0
	for i in 500:
		if main._apply_incoming_reductions(100, {}) == 0:
			negates_normal += 1
	player.berserk_turns_remaining = 2
	var negates_berserk := 0
	for i in 500:
		if main._apply_incoming_reductions(100, {}) == 0:
			negates_berserk += 1
	print("Block Master negate-rate over 500 rolls: normal=%d (expected ~200, 40%%) berserk=%d (expected ~50, 10%% -- a quarter of 40%%)" % [negates_normal, negates_berserk])
	main.battle_player_defending = false
	player.meta_block_negate_chance = 0.0
	player.berserk_turns_remaining = 0

	# --- Reflexes dodge cut to a quarter of its normal rate the same way.
	# The 60% of rolls that DON'T dodge land a real hit via take_battle_damage
	# -- health is topped up before/after so 500 real hits don't actually
	# kill the player and end the battle out from under the rest of this test. ---
	player.meta_dodge_chance = 0.4
	player.berserk_turns_remaining = 0
	var dodges_normal := 0
	for i in 500:
		player.health = player.max_health
		var r: Dictionary = main._enemy_apply_damage(_make_unit(main, "Goblin", Vector2i(5, 3)), main.battle_player_tile, 10, {})
		if r.get("dodged", false):
			dodges_normal += 1
	player.berserk_turns_remaining = 2
	var dodges_berserk := 0
	for i in 500:
		player.health = player.max_health
		var r2: Dictionary = main._enemy_apply_damage(_make_unit(main, "Goblin", Vector2i(5, 3)), main.battle_player_tile, 10, {})
		if r2.get("dodged", false):
			dodges_berserk += 1
	print("Reflexes dodge-rate over 500 rolls: normal=%d (expected ~200, 40%%) berserk=%d (expected ~50, 10%% -- a quarter of 40%%)" % [dodges_normal, dodges_berserk])
	player.meta_dodge_chance = 0.0
	player.berserk_turns_remaining = 0
	player.health = player.max_health
	# One of those 1000 real hits inevitably drops health to 0 on some
	# iteration despite the top-of-loop reset (the reset happens BEFORE that
	# iteration's hit, not after) -- take_battle_damage's death path sets
	# game_over=true and in_battle=false right then, and nothing later in
	# the loop undoes either, so both need restoring here too, not just health.
	main.game_over = false
	main.in_battle = true

	# --- Ticks down once per player turn, same shape as Concussion/Blindness. ---
	player.berserk_turns_remaining = 2
	main.battle_units = [_make_unit(main, "Goblin", Vector2i(6, 6))]
	main._process_enemy_turn()
	print("Berserk ticks down once per player turn: berserk_turns_remaining=%d (expected 1)" % [player.berserk_turns_remaining])

	# --- Per-battle reset. ---
	player.berserk_turns_remaining = 2
	var goblin_for_reset = load("res://scripts/Enemy.gd").new()
	main.add_child(goblin_for_reset)
	main._setup_battle_grid([goblin_for_reset])
	print("Berserk (like every other battle-scoped player status) clears on the next battle setup: berserk_turns_remaining=%d (expected 0)" % [player.berserk_turns_remaining])

	# --- HUD status text (battle_status_label2 -- see HUD.gd:update_battle_grid,
	# the HP/STA bars took over battle_status_label's old 2nd+ lines). ---
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_allies = []
	main.battle_units = [_make_unit(main, "Goblin", Vector2i(6, 6))]
	player.berserk_turns_remaining = 2
	main._refresh_battle_display()
	print("HUD shows a BERSERK indicator while active: %s (expected true)" % [main.hud.battle_status_label2.text.contains("BERSERK")])
	player.berserk_turns_remaining = 0
	main._refresh_battle_display()
	print("...and hides it once Berserk ends: %s (expected false)" % [main.hud.battle_status_label2.text.contains("BERSERK")])

	# Reset the scratch save for whatever test runs next.
	var save_data_script = load("res://scripts/SaveData.gd")
	save_data_script.save_data({"essence": 0, "upgrades": {}, "best_wave": 0})

	quit()
