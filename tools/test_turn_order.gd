extends SceneTree

# Turn order: speed alone decides who acts next -- the hero, every ally and every enemy share one
# timeline, a fast unit can act several times in a row, and the strip in the corner shows what is coming.

func _enemy(main, name: String, tile: Vector2i, hp: int = 999) -> Dictionary:
	var g = load("res://scripts/Enemy.gd").new()
	main.add_child(g)
	g.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	g.set_physics_process(false)
	return {
		"ref": g, "tile": tile, "hp": hp, "max_hp": hp, "move_range": 1, "damage": 1,
		"name": name, "winding_up": false, "stunned": false, "attack_range": 1,
		"concussed_turns": 0, "frozen_turns": 0, "burning": false, "armored": false,
		"disarmed_tile": Vector2i(-1, -1), "vulnerable_turns": 0, "aware_of_player": false, "size": 1,
	}

func _ally(name: String, tile: Vector2i, speed: float) -> Dictionary:
	return {"tile": tile, "hp": 50, "max_hp": 50, "dmg_mult": 1.0, "name": name, "kind": "mercenary", "speed": speed, "move_range": 1, "attack_range": 1, "defense_pct": 0.0}

# The first `n` turns of the timeline as short names: "H" the hero, the ally's / enemy's name otherwise.
func _order(main, n: int) -> Array:
	var out := []
	for s in main._timeline_preview(n):
		out.append("H" if s.kind == "hero" else str(s.unit.name))
	return out

func _fresh(main, player) -> void:
	main.in_battle = true
	main.game_over = false
	main.tutorial_active = false
	main.battle_terrain.clear()
	main.battle_allies = []
	main.battle_downed_allies = []
	main.battle_units = []
	main.battle_actor = {}
	main.battle_commanding_ally = null
	main.battle_ally_queue = []
	main.battle_player_tile = Vector2i(0, 0)
	main.battle_turn = "player"
	main.battle_player_turns_to_skip = 0
	main.battle_use_timeline = true
	main.battle_timeline.clear()
	main.battle_timeline_clock = 0.0
	main.battle_tid_counter = 0
	main.battle_timeline_running = false
	main.battle_timeline_pending = false
	main.battle_hero_turns = 0
	main.battle_current_actor = {}
	player.stat_agility = load("res://scripts/Player.gd").AGILITY_START
	player.equipped_armor = load("res://scripts/Armor.gd").find("armor_rags")
	player.health = player.max_health

func _init() -> void:
	seed(20261013)
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	# =========================================================
	# Speeds
	# =========================================================
	_fresh(main, player)
	print("You start at speed 5: %.1f (expected 5.0)" % [main._hero_speed()])
	player.stat_agility += 5 * 3
	print("...and each level's +5 agility is +1 speed: %.1f after 3 levels (expected 8.0)" % [main._hero_speed()])
	player.stat_agility = load("res://scripts/Player.gd").AGILITY_START
	player.equipped_armor = load("res://scripts/Armor.gd").find("armor_windrunner")
	print("Windrunner's Jerkin adds its +2: %.1f (expected 7.0)" % [main._hero_speed()])
	player.equipped_armor = load("res://scripts/Armor.gd").find("armor_rags")
	var missing := []
	for enemy_name in main.ENEMY_TRAITS:
		if not main.ENEMY_SPEEDS.has(enemy_name):
			missing.append(enemy_name)
	print("Every enemy has a speed rating: missing %s (expected [])" % [missing])
	var strays := []
	for enemy_name in main.ENEMY_SPEEDS:
		if not main.ENEMY_TRAITS.has(enemy_name):
			strays.append(enemy_name)
	print("...and the table lists nobody who does not exist: %s (expected [])" % [strays])
	print("Speed shows in the unit: Voidwing %.1f, Brute %.1f (expected 9.0, 2.0); half after a Nipper: %.1f (expected 4.5)" % [main._unit_speed("enemy", {"name": "Voidwing"}), main._unit_speed("enemy", {"name": "Brute"}), main._unit_speed("enemy", {"name": "Voidwing", "speed_mult": 0.5})])

	# =========================================================
	# Who goes when
	# =========================================================
	_fresh(main, player)
	main.battle_allies = [_ally("Ally", Vector2i(0, 1), 5.0)]
	main.battle_units = [_enemy(main, "Gnome", Vector2i(8, 8)), _enemy(main, "Gnome", Vector2i(8, 7))]
	print("Equal speeds fall back to hero, ally, then the enemies in field order: %s (expected [H, Ally, Gnome, Gnome, H, Ally, Gnome, Gnome])" % [_order(main, 8)])

	_fresh(main, player)
	main.battle_units = [_enemy(main, "Voidwing", Vector2i(8, 8))]
	print("A speed-9 Voidwing against your 5 acts twice in a row: %s (expected [Voidwing, H, Voidwing, Voidwing, H, Voidwing, Voidwing, H])" % [_order(main, 8)])

	_fresh(main, player)
	main.battle_units = [_enemy(main, "Brute", Vector2i(8, 8))]
	print("A speed-2 Brute acts once for every two and a half of your turns: %s (expected [H, H, Brute, H, H, H, Brute, H] -- 50 against your 20 per turn)" % [_order(main, 8)])
	main.battle_timeline.clear()

	_fresh(main, player)
	var goblin: Dictionary = _enemy(main, "Goblin", Vector2i(8, 8))
	main.battle_units = [goblin]
	print("A Goblin (6) against your 5: %s (expected [Goblin, H, Goblin, H, Goblin, H, Goblin, H])" % [_order(main, 8)])
	goblin["speed_mult"] = 0.5
	main.battle_timeline.clear()
	print("Nipped (speed halved to 3): %s (expected [H, Goblin, H, H, Goblin, H, H, Goblin])" % [_order(main, 8)])

	_fresh(main, player)
	main.battle_allies = [_ally("Quick", Vector2i(0, 1), 10.0), _ally("Slow", Vector2i(0, 2), 2.5)]
	print("Party members run on their own speeds (10 and 2.5): %s (expected [Quick, H, Quick, Quick, H, Quick, Slow, Quick] -- Slow comes at 40, after you)" % [_order(main, 8)])

	# =========================================================
	# The timeline follows the field
	# =========================================================
	_fresh(main, player)
	var ga: Dictionary = _enemy(main, "Gnome", Vector2i(8, 8))
	var gb: Dictionary = _enemy(main, "Gnome", Vector2i(8, 7))
	main.battle_units = [ga, gb]
	main._timeline_sync()
	gb.hp = 0
	print("A fallen unit drops out of the order: %s (expected [H, Gnome, H, Gnome, H, Gnome, H, Gnome])" % [_order(main, 8)])
	main.battle_units = [ga]
	main.battle_timeline_clock = 40.0
	var newcomer: Dictionary = _enemy(main, "Fae", Vector2i(7, 7))
	main.battle_units.append(newcomer)
	var seen_tid_before: bool = newcomer.has("tid")
	var order_after: Array = _order(main, 3)
	print("A unit that joins mid-fight is booked one delay after 'now' (Fae speed 7 -> +14.3): has_id_before=%s, first three: %s (expected false; the Fae is not first)" % [seen_tid_before, order_after])

	# =========================================================
	# Playing it through the real loop
	# =========================================================
	_fresh(main, player)
	var chaser: Dictionary = _enemy(main, "Goblin", Vector2i(6, 0))
	chaser["aware_of_player"] = true
	main.battle_units = [chaser]
	main.battle_player_tile = Vector2i(0, 0)
	player.max_health = 500
	player.health = 500
	main.settings.combat_minigames_enabled = false
	main._timeline_begin()
	await process_frame
	var start_tile: Vector2i = chaser.tile
	print("The Goblin (6) is faster than you (5), so it acts BEFORE your first turn: goblin turns=%d (expected 1), moved=%s (expected true), hero turns so far=%d (expected 1), your menu is up: turn=%s (expected player)" % [chaser.turns_taken, chaser.tile != Vector2i(6, 0), main.battle_hero_turns, main.battle_turn])
	var hero_turns_before: int = main.battle_hero_turns
	main._end_player_turn()
	await process_frame
	await process_frame
	print("Ending your turn runs whoever is due until it is yours again: hero turns %d -> %d (expected +1), turn=%s (expected player)" % [hero_turns_before, main.battle_hero_turns, main.battle_turn])
	for round in 10:
		main._end_player_turn()
		await process_frame
		await process_frame
	print("By your 12th turn (time 240) the Goblin (a turn every 16.7) has had 14: goblin turns=%d (expected 14), your turns=%d (expected 12); it closed in: now at %s (expected next to the hero)" % [chaser.turns_taken, main.battle_hero_turns, chaser.tile])

	# =========================================================
	# The strip in the corner
	# =========================================================
	_fresh(main, player)
	main.battle_allies = [_ally("Ally", Vector2i(0, 1), 5.0)]
	main.battle_units = [_enemy(main, "Voidwing", Vector2i(8, 8)), _enemy(main, "Brute", Vector2i(8, 7))]
	main._timeline_sync()
	var current_entry: Dictionary = main._timeline_pop()
	main.battle_current_actor = current_entry
	var rows: Array = main._turn_order_rows()
	print("The strip shows 8 turns with the one in progress first and lit: rows=%d (expected 8), first=%s current=%s (expected Voidwing, true), second current=%s (expected false)" % [rows.size(), rows[0].name, rows[0].current, rows[1].current])
	print("...enemies red, allies green, you blue: %s (expected the sides in order)" % [rows.map(func(r): return r.side)])
	var hud = main.hud
	hud.set_turn_order(rows)
	await process_frame
	print("The HUD builds a title plus one row each: children=%d (expected 9), visible=%s (expected true)" % [hud.turn_order_box.get_child_count(), hud.turn_order_box.visible])
	hud.set_turn_order([])
	print("An empty order hides it: visible=%s (expected false)" % [hud.turn_order_box.visible])

	# a hero who is reeling loses the turn and play moves on
	_fresh(main, player)
	var far: Dictionary = _enemy(main, "Brute", Vector2i(9, 9))
	main.battle_units = [far]
	main._timeline_begin()
	await process_frame
	main.battle_player_turns_to_skip = 1
	var turns_then: int = main.battle_hero_turns
	main._end_player_turn()
	await process_frame
	await process_frame
	print("A reeling hero's next turn is skipped and play carries on: hero turns %d -> %d (expected +2: the skipped one and the next real one), you can act: %s (expected player)" % [turns_then, main.battle_hero_turns, main.battle_turn])

	# the tutorial fight always opens with the hero
	_fresh(main, player)
	var fast: Dictionary = _enemy(main, "Voidwing", Vector2i(9, 9))
	fast["aware_of_player"] = true
	main.battle_units = [fast]
	main.tutorial_active = true
	main._timeline_begin()
	await process_frame
	print("In the tutorial the hero always goes first even against a speed-9 foe: tile unchanged=%s (expected true), hero turns=%d (expected 1)" % [fast.tile == Vector2i(9, 9), main.battle_hero_turns])
	main.tutorial_active = false

	# without the timeline, the old phases still work exactly as before
	_fresh(main, player)
	main.battle_use_timeline = false
	main.battle_allies = [_ally("Ally", Vector2i(0, 1), 5.0)]
	var legacy_foe: Dictionary = _enemy(main, "Goblin", Vector2i(9, 9))
	main.battle_units = [legacy_foe]
	main._end_player_turn()
	await process_frame
	await process_frame
	print("With the timeline off the old phases still run: commanding the ally first: %s (expected Ally)" % [main.battle_commanding_ally.name if main.battle_commanding_ally != null else "<null>"])

	main.in_battle = false
	quit()
