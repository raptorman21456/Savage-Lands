extends SceneTree

# Berserk and Rage, as the design doc has them. Berserk: every 5th enemy to fall in a battle starts it (the count carries from battle
# to battle), or a Club's Heavy Swing that kills; it lasts 2 turns, stops when the battle does, and gives +25% damage dealt, 25% less
# damage taken and +1 tile of movement -- no drawbacks. Rage is the hero's own stat (unlocked by the Church's Painful Memories, +1 per
# level-up, also a level-up pick) and every point makes all three stronger, plus the hero's turn speed.

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
	main.regional_world = false  # this test drives the old wave-ladder world
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	var weapons_script = load("res://scripts/Weapons.gd")
	var shields_script = load("res://scripts/Shields.gd")
	var statuses_script = load("res://scripts/BattleStatuses.gd")

	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_allies = []
	main.battle_player_tile = Vector2i(3, 3)
	player.current_weapon = weapons_script.CLUB
	player.berserk_turns_remaining = 0
	player.berserk_kills = 0
	player.meta_rage_bonus_pct = 0.0
	player.stat_rage = 0

	# --- The numbers are the doc's ---
	print("the doc's Berserk: %d turns, +%d%% damage, %d%% less damage taken, +%d tile, every %dth kill (expected 2, 25, 25, 1, 5)" % [
		main.BERSERK_TURNS, int(main.BERSERK_DAMAGE_BONUS_PCT * 100), int(main.BERSERK_DAMAGE_TAKEN_CUT * 100), main.BERSERK_MOVE_BONUS, main.BERSERK_KILLS_NEEDED])

	# --- Trigger: the 5th kill, and the count is spent when it fires ---
	var counts: Array = []
	var turns_after: Array = []
	for i in 4:
		main._on_enemy_died(0, "Goblin")
		counts.append(player.berserk_kills)
		turns_after.append(player.berserk_turns_remaining)
	print("four kills do not start Berserk, the count climbs: counts=%s (expected [1, 2, 3, 4]) turns=%s (expected all 0)" % [counts, turns_after])
	main._on_enemy_died(0, "Goblin")
	print("the 5th kill starts it and spends the count: turns=%d (expected %d), kills=%d (expected 0)" % [player.berserk_turns_remaining, main.BERSERK_TURNS, player.berserk_kills])

	# The count carries from one battle to the next, and Berserk itself stops with the battle.
	player.berserk_turns_remaining = 0
	player.berserk_kills = 3
	main._end_battle()
	main.in_battle = true
	print("the battle ending keeps the count: kills=%d (expected 3)" % [player.berserk_kills])
	var goblin_for_reset = load("res://scripts/Enemy.gd").new()
	main.add_child(goblin_for_reset)
	main._setup_battle_grid([goblin_for_reset])
	print("...and a new battle does not wipe it either: kills=%d (expected 3)" % [player.berserk_kills])
	main.in_battle = true
	main._on_enemy_died(0, "Goblin")
	main._on_enemy_died(0, "Goblin")
	print("...so two more kills in the next battle make the 5th: turns=%d (expected %d), kills=%d (expected 0)" % [player.berserk_turns_remaining, main.BERSERK_TURNS, player.berserk_kills])
	player.berserk_turns_remaining = 1
	player.berserk_kills = 4
	main._on_enemy_died(0, "Goblin")
	print("a 5th kill while it is already on refreshes it to full instead of stacking: %d (expected %d)" % [player.berserk_turns_remaining, main.BERSERK_TURNS])
	main._end_battle()
	print("Berserk stops when the battle ends: turns=%d (expected 0)" % [player.berserk_turns_remaining])
	main.in_battle = false
	player.berserk_kills = 0
	main._on_enemy_died(0, "Goblin")
	print("a kill outside a battle does not count: kills=%d (expected 0)" % [player.berserk_kills])
	main.in_battle = true
	main.battle_allies = []
	player.berserk_turns_remaining = 0

	# --- Club's Heavy Swing: a kill with it starts Berserk at once ---
	player.current_weapon = weapons_script.CLUB
	player.stamina = player.MAX_STAMINA
	player.stat_strength = 50
	player.attack_damage = 50
	main.battle_player_tile = Vector2i(2, 2)
	# (A second enemy stays on the field: killing the last one ends the battle, and Berserk stops with it.)
	var victim := _make_unit(main, "Goblin", Vector2i(3, 2), 5)
	var bystander := _make_unit(main, "Goblin", Vector2i(7, 7), 99999)
	main.battle_units = [victim, bystander]
	main.battle_target_index = 0
	player.berserk_kills = 0
	main._battle_player_special(2)
	print("Heavy Swing that kills starts Berserk without the count: turns=%d (expected %d: it started at 2 and the swing ending the turn ticked it once), the kill still counts: kills=%d (expected 1)" % [player.berserk_turns_remaining, main.BERSERK_TURNS - 1, player.berserk_kills])
	player.berserk_turns_remaining = 0
	player.stamina = player.MAX_STAMINA
	var survivor := _make_unit(main, "Goblin", Vector2i(3, 2), 99999)
	main.battle_units = [survivor, bystander]
	main.battle_target_index = 0
	main._battle_player_special(2)
	print("...but a Heavy Swing that does not kill does not: turns=%d (expected 0)" % [player.berserk_turns_remaining])
	player.berserk_turns_remaining = 0
	player.berserk_kills = 0

	# --- Damage dealt: +25%, + 1% per Rage, + the Church's RAGE node; an ally's own hit never gets it ---
	player.attack_damage = 10
	player.stat_strength = 10
	var g_dmg := _make_unit(main, "Goblin", Vector2i(4, 3))
	main.battle_units = [g_dmg]
	main.battle_target_index = 0
	main._apply_single_hit(0, 1.0, "", weapons_script.CLUB)
	var normal_dmg: int = 999999 - g_dmg.hp
	player.berserk_turns_remaining = 2
	g_dmg.hp = 999999
	main._apply_single_hit(0, 1.0, "", weapons_script.CLUB)
	var berserk_dmg: int = 999999 - g_dmg.hp
	print("Berserk boosts damage dealt by +25%%: normal=%d berserk=%d (expected round(normal*1.25)=%d)" % [normal_dmg, berserk_dmg, int(round(normal_dmg * 1.25))])
	player.stat_rage = 10
	g_dmg.hp = 999999
	main._apply_single_hit(0, 1.0, "", weapons_script.CLUB)
	print("...Rage 10 adds +10%%: %d (expected round(normal*1.35)=%d)" % [999999 - g_dmg.hp, int(round(normal_dmg * 1.35))])
	player.meta_rage_bonus_pct = 0.3
	g_dmg.hp = 999999
	main._apply_single_hit(0, 1.0, "", weapons_script.CLUB)
	print("...and the Church's RAGE node stacks on top of both: %d (expected round(normal*1.65)=%d)" % [999999 - g_dmg.hp, int(round(normal_dmg * 1.65))])
	g_dmg.hp = 999999
	main._apply_single_hit(0, 1.0, "", weapons_script.CLUB, "Knight")
	print("...but an ally's own hit through the same function is not boosted: ally=%d (expected %d)" % [999999 - g_dmg.hp, normal_dmg])
	player.meta_rage_bonus_pct = 0.0
	player.stat_rage = 0
	player.berserk_turns_remaining = 0

	# --- Damage taken: 25% less after every other reduction, + 0.5% per Rage, capped ---
	var taken_normal: int = main._apply_incoming_reductions(100, {})
	player.berserk_turns_remaining = 2
	var taken_berserk: int = main._apply_incoming_reductions(100, {})
	print("Berserk takes 25%% off a hit: normal=%d berserk=%d (expected %d)" % [taken_normal, taken_berserk, int(round(taken_normal * 0.75))])
	player.stat_rage = 20
	print("...Rage 20 takes 10%% more off: %d (expected %d)" % [main._apply_incoming_reductions(100, {}), int(round(taken_normal * 0.65))])
	player.stat_rage = 1000
	print("...and it never takes more than 60%% off, however much Rage: %d (expected %d)" % [main._apply_incoming_reductions(100, {}), int(round(taken_normal * 0.4))])
	print("a magical hit is cut too: %d (expected 40, the same 60%% off)" % [main._apply_incoming_reductions(100, {"harm": "magical"})])
	player.stat_rage = 0
	player.berserk_turns_remaining = 0

	# --- No drawbacks: shields, Block Master and dodge all work as normal ---
	var buckler: Dictionary = shields_script.SHIELDS.shield_buckler
	player.equipped_shield = buckler
	var block_before: float = player.shield_block_chance()
	var usable_before: bool = player.shield_usable()
	player.berserk_turns_remaining = 2
	print("a shield works during Berserk: block %.2f -> %.2f (expected equal and > 0), usable %s -> %s (expected true, true)" % [block_before, player.shield_block_chance(), usable_before, player.shield_usable()])
	player.equipped_shield = {}
	player.berserk_turns_remaining = 0

	player.meta_block_negate_chance = 0.4
	main.battle_player_defending = true
	var negates_normal := 0
	for i in 500:
		if main._apply_incoming_reductions(100, {}) == 0:
			negates_normal += 1
	player.berserk_turns_remaining = 2
	var negates_berserk := 0
	for i in 500:
		if main._apply_incoming_reductions(100, {}) == 0:
			negates_berserk += 1
	print("Block Master negates as often in Berserk as out of it: normal=%d berserk=%d over 500 rolls (expected both about 200, 40%%)" % [negates_normal, negates_berserk])
	main.battle_player_defending = false
	player.meta_block_negate_chance = 0.0
	player.berserk_turns_remaining = 0

	player.meta_dodge_chance = 0.4
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
	print("Reflexes dodge as often in Berserk: normal=%d berserk=%d over 500 rolls (expected both about 200, 40%%)" % [dodges_normal, dodges_berserk])
	player.meta_dodge_chance = 0.0
	player.berserk_turns_remaining = 0
	player.health = player.max_health
	# (Some of those 1000 real hits can kill the hero: the death path sets game_over and ends the battle, so put both back.)
	main.game_over = false
	main.in_battle = true

	# --- +1 tile of movement, and Rage quickens the hero's turns ---
	var move_normal: int = main._battle_player_move_range()
	var speed_normal: float = main._hero_speed()
	player.berserk_turns_remaining = 2
	print("Berserk is one tile more movement: %d -> %d (expected +%d)" % [move_normal, main._battle_player_move_range(), main.BERSERK_MOVE_BONUS])
	print("...and no faster a turn without Rage: speed %.2f -> %.2f (expected equal)" % [speed_normal, main._hero_speed()])
	player.stat_rage = 8
	print("...Rage 8 adds %.2f to the hero's speed: %.2f -> %.2f (expected +2.00)" % [main._berserk_speed_bonus(), speed_normal, main._hero_speed()])
	player.berserk_turns_remaining = 0
	print("...and none of it outside Berserk: move %d, speed %.2f (expected %d, %.2f)" % [main._battle_player_move_range(), main._hero_speed(), move_normal, speed_normal])
	player.stat_rage = 0

	# --- Ticks down once per player turn ---
	player.berserk_turns_remaining = 2
	main.battle_units = [_make_unit(main, "Goblin", Vector2i(6, 6))]
	main._process_enemy_turn()
	print("Berserk ticks down once per player turn: berserk_turns_remaining=%d (expected 1)" % [player.berserk_turns_remaining])

	# --- Per-battle reset ---
	player.berserk_turns_remaining = 2
	main._setup_battle_grid([load("res://scripts/Enemy.gd").new()])
	print("a new battle starts with no Berserk running: berserk_turns_remaining=%d (expected 0)" % [player.berserk_turns_remaining])

	# --- What the screen says ---
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_allies = []
	main.battle_units = [_make_unit(main, "Goblin", Vector2i(6, 6))]
	player.berserk_turns_remaining = 2
	player.stat_rage = 4
	main._refresh_battle_display()
	print("the HUD shows a BERSERK indicator while active: %s (expected true)" % [main.hud.battle_status_label2.text.contains("BERSERK")])
	var entries: Array = statuses_script.for_hero(main._hero_status_state())
	var berserk_entry: Dictionary = {}
	for e in entries:
		if e.id == "berserk":
			berserk_entry = e
	print("the status says what it is worth with Rage 4: '%s' (expected +29%% damage, 27%% less damage taken, 1 tile, Rage mentioned)" % [berserk_entry.get("desc", "")])
	player.berserk_turns_remaining = 0
	player.berserk_kills = 3
	main._refresh_battle_display()
	entries = statuses_script.for_hero(main._hero_status_state())
	var building: Dictionary = {}
	for e in entries:
		if e.id == "rage_building":
			building = e
	print("between Berserks the count shows as a status: '%s %s' (expected Rage building 3 / 5)" % [building.get("name", ""), building.get("detail", "")])
	print("...and the BERSERK indicator is gone: %s (expected false)" % [main.hud.battle_status_label2.text.contains("BERSERK")])
	player.berserk_kills = 0
	player.stat_rage = 0

	# --- Rage is a real stat: locked until Painful Memories, +1 per level-up, a level-up pick ---
	player.meta_rage_unlocked = false
	var rage_before: int = player.stat_rage
	player._level_up()
	print("Rage does not grow before Painful Memories: %d -> %d (expected 0 -> 0)" % [rage_before, player.stat_rage])
	print("...and is not offered on the level-up screen: %s (expected false)" % [main._levelup_choice_order().has("rage")])
	player.apply_bonus_stat("strength")
	player.meta_rage_unlocked = true
	player._level_up()
	print("with Painful Memories every level-up gives +1 Rage: %d (expected 1)" % [player.stat_rage])
	player._level_up()
	print("...each time: %d (expected 2)" % [player.stat_rage])
	var order: Array = main._levelup_choice_order()
	print("Rage is the last choice on the level-up screen: %s (expected rage)" % [order[order.size() - 1]])
	main.hud.show_levelup_choice(5, 1, 1, 1, 180, 1, 0, 0, 0, false, false, false, 0, false, 7, true)
	print("the level-up screen lists it with its number: %s (expected true), Rage button text '%s'" % [main.hud.levelup_buttons.has("rage"), main.hud.levelup_buttons["rage"].text if main.hud.levelup_buttons.has("rage") else ""])
	main.hud.hide_levelup_choice()
	main.hud.show_levelup_choice(5, 1, 1, 1, 180, 1, 0, 0, 0, false, false, false, 0, false, 0, false)
	print("...and does not list it while locked: %s (expected false)" % [main.hud.levelup_buttons.has("rage")])
	main.hud.hide_levelup_choice()
	var picked_before: int = player.stat_rage
	player.apply_bonus_stat("rage")
	print("picking Rage as the bonus gives +1: %d -> %d (expected +1)" % [picked_before, player.stat_rage])
	player.meta_bonus_levelup_stat = true
	picked_before = player.stat_rage
	player.apply_bonus_stat("rage")
	print("...and Prodigy doubles the pick: %d -> %d (expected +2)" % [picked_before, player.stat_rage])
	player.meta_bonus_levelup_stat = false
	player.stat_rage = 0
	player.meta_rage_unlocked = false

	# Reset the scratch save for whatever test runs next.
	var save_data_script = load("res://scripts/SaveData.gd")
	save_data_script.save_data({"essence": 0, "upgrades": {}, "best_wave": 0})

	quit()
