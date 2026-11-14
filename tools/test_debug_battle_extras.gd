extends SceneTree

# The Debug menu's extra control over a fight and the world (DebugBattle / DebugWorld additions): end your turn, always crit / enemies stand
# still / never miss, anyone's HP, allies down and up, enemies and allies added mid-fight, units moved, terrain placed, the counters, a status
# that was missing (fear), and opening a building's menu or playing an event from anywhere. Each is run in a real battle.

const DB := preload("res://scripts/DebugBattle.gd")
const DW := preload("res://scripts/DebugWorld.gd")
const DA := preload("res://scripts/DebugActions.gd")

var main = null
var player = null

func _frames(n: int = 2) -> void:
	for i in n:
		await process_frame

# Runs until it is the hero's turn (an enemy's turn is a chain of animated steps).
func _wait_for_hero() -> void:
	for i in 900:
		if main.in_battle and main.battle_turn == "player" and not main.battle_timeline_running:
			return
		if not main.in_battle:
			return
		await process_frame

# Answers the level-up picker or event question a win can bring.
func _clear_pending() -> void:
	for i in 6:
		if main.choosing_stat:
			main._on_levelup_choice_pressed("vigor")
		elif main.event_choosing:
			main._on_event_choice_pressed(false)
		else:
			break
	await _frames(1)

func _init() -> void:
	seed(20261109)
	await _frames(2)
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	player = main.player
	main.ambient_spawn_timer = 1.0e9
	main.settings.attack_minigame_enabled = false
	main.settings.combat_minigames_enabled = false
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)
	player.max_party_slots = 8
	player.max_health = 500
	player.health = 500

	print("--- starting a fight to meddle with")
	var r: Dictionary = DB.start_battle(main, [{"name": "Goblin", "count": 2}], 1, false, 1.0)
	print("a battle of two Goblins: ok=%s units=%d (expected true, 2)" % [r.ok, main.battle_units.size()])
	await _wait_for_hero()
	main.battle_first_attack_used = true
	main.battle_units[0]["max_hp"] = 99999
	main.battle_units[0]["hp"] = 99999
	main.battle_units[1]["max_hp"] = 99999
	main.battle_units[1]["hp"] = 99999

	print("--- moving things and building ground")
	var e0: Vector2i = main.battle_units[0].tile
	r = DB.move_unit(main, "hero", e0.x - 1, e0.y)
	print("the hero stands next to the first enemy: ok=%s tile=%s (expected true, %s)" % [r.ok, main.battle_player_tile, Vector2i(e0.x - 1, e0.y)])
	r = DB.move_unit(main, "hero", e0.x, e0.y)
	print("onto an enemy: ok=%s, hero stays at %s (expected false, %s)" % [r.ok, main.battle_player_tile, Vector2i(e0.x - 1, e0.y)])
	r = DB.move_unit(main, "hero", -1, 0)
	print("off the grid: ok=%s (expected false)" % [r.ok])
	r = DB.move_unit(main, "hero", 0, 99)
	print("far off the grid: ok=%s (expected false)" % [r.ok])
	var free_spot: Array = DB.free_tiles(main, 1, Vector2i(0, 0))
	r = DB.move_unit(main, "enemy:1", free_spot[0].x, free_spot[0].y)
	print("an enemy to a free tile: ok=%s tile=%s (expected true, %s)" % [r.ok, main.battle_units[1].tile, free_spot[0]])
	r = DB.move_unit(main, "enemy:7", 1, 1)
	print("an enemy that is not there: ok=%s (expected false)" % [r.ok])
	var terrain_tile: Vector2i = DB.free_tiles(main, 1, Vector2i(2, 2))[0]
	r = DB.set_terrain(main, terrain_tile.x, terrain_tile.y, "rock")
	print("a rock where nobody stands: ok=%s type=%s (expected true, rock)" % [r.ok, main.battle_terrain.get(terrain_tile, {}).get("type", "none")])
	r = DB.set_terrain(main, main.battle_player_tile.x, main.battle_player_tile.y, "rock")
	print("a rock under the hero: ok=%s (expected false)" % [r.ok])
	r = DB.move_unit(main, "hero", terrain_tile.x, terrain_tile.y)
	print("the hero onto the rock: ok=%s (expected false)" % [r.ok])
	r = DB.set_terrain(main, 1, 1, "lava")
	print("a kind of ground that does not exist: ok=%s (expected false)" % [r.ok])
	var water_tile: Vector2i = DB.free_tiles(main, 1, Vector2i(3, 3))[0]
	r = DB.set_terrain(main, water_tile.x, water_tile.y, "water")
	print("water gets a push direction like the game's own: %s (expected true)" % [main.battle_terrain[water_tile].has("push_dir")])
	r = DB.set_terrain(main, 40, 40, "rock")
	print("terrain off the grid: ok=%s (expected false)" % [r.ok])
	r = DB.clear_terrain(main, terrain_tile.x, terrain_tile.y)
	print("clearing it: ok=%s, gone=%s (expected true, true)" % [r.ok, not main.battle_terrain.has(terrain_tile)])
	r = DB.clear_terrain(main, terrain_tile.x, terrain_tile.y)
	print("clearing bare ground: ok=%s (expected false)" % [r.ok])
	r = DB.clear_all_terrain(main)
	print("clearing it all: terrain left=%d (expected 0)" % [main.battle_terrain.size()])
	var ice_tile: Vector2i = DB.free_tiles(main, 1, Vector2i(2, 2))[0]
	r = DB.set_terrain(main, ice_tile.x, ice_tile.y, "ice")
	print("a reserved kind (ice) too: %s, type=%s (expected true, ice)" % [r.ok, main.battle_terrain.get(ice_tile, {}).get("type", "none")])
	DB.clear_all_terrain(main)
	DB.move_unit(main, "hero", e0.x - 1, e0.y)

	print("--- the fight cheats")
	player.stamina = player.max_stamina
	main.battle_turn = "player"
	main.battle_target_index = 0
	var before: int = main.battle_units[0].hp
	main._battle_player_fight()
	var plain: int = before - main.battle_units[0].hp
	DB.set_always_crit(main, true)
	player.stamina = player.max_stamina
	main.battle_turn = "player"
	before = main.battle_units[0].hp
	main._battle_player_fight()
	var crit: int = before - main.battle_units[0].hp
	print("always crit: a plain hit did %d, with it on %d (expected the second to be more than 1.5x the first)" % [plain, crit])
	print("...the flag is %s (expected true)" % [player.debug_always_crit])
	DB.set_always_crit(main, false)
	DB.set_never_miss(main, true)
	print("never miss: %s (expected true)" % [DB.never_miss_on(main)])
	DB.set_never_miss(main, false)
	print("...and off puts the normal chances back (a script test never has misses, so the override stays 0): %s (expected true)" % [DB.never_miss_on(main)])

	print("--- anyone's HP")
	r = DB.set_unit_hp(main, "enemy:0", 5)
	print("an enemy to 5 HP: %d (expected 5)" % [main.battle_units[0].hp])
	r = DB.set_unit_hp(main, "enemy:0", 999999)
	print("above its max is held at the max: %d (expected 99999)" % [main.battle_units[0].hp])
	r = DB.set_unit_hp(main, "hero", 123)
	print("you to 123 HP: %d (expected 123)" % [player.health])
	r = DB.set_unit_hp(main, "enemy:9", 5)
	print("someone who is not there: ok=%s (expected false)" % [r.ok])
	r = DB.set_unit_hp(main, "nobody", 5)
	print("a target that is not a unit: ok=%s (expected false)" % [r.ok])
	player.health = 500

	print("--- the counters")
	DB.set_berserk_kills(main, 3)
	print("kills towards Berserk: %d (expected 3)" % [player.berserk_kills])
	DB.set_berserk_kills(main, 0)
	DB.set_momentum(main, 4)
	print("momentum: %d (expected 4)" % [main.battle_momentum_stacks])
	DB.set_momentum(main, 0)
	DB.set_moves_left(main, 7)
	print("tiles left to walk: %d (expected 7)" % [main.battle_player_moves_left])
	DB.set_moves_left(main, -3)
	print("never below zero: %d (expected 0)" % [main.battle_player_moves_left])

	print("--- a status that was missing: fear")
	print("fear is offered for enemies: %s (expected true)" % [DB.statuses_for("enemy").has("fear")])
	r = DB.set_status(main, "enemy:0", "fear", 2)
	print("fear on the first enemy: fear_turns=%d (expected 2)" % [int(main.battle_units[0].get("fear_turns", 0))])
	print("...and the game lists it: %s (expected true)" % [DB.status_list(main, "enemy:0").any(func(e): return str(e.id) == "fear")])
	DB.clear_statuses(main, "enemy:0")
	print("Clear all takes it off: fear_turns=%d (expected 0)" % [int(main.battle_units[0].get("fear_turns", 0))])

	print("--- adding to the fight")
	var enemies_before: int = main.battle_units.size()
	var alive_before: int = main.enemies_alive
	r = DB.add_enemy(main, "Orc", 2, 1, false)
	print("two Orcs join: ok=%s units %d -> %d (expected true, %d -> %d)" % [r.ok, enemies_before, main.battle_units.size(), enemies_before, enemies_before + 2])
	var orc: Dictionary = main.battle_units[main.battle_units.size() - 1]
	print("an Orc has its own stats: name=%s hp=%d max=%d damage=%d move=%d (expected Orc and real numbers)" % [orc.name, orc.hp, orc.max_hp, orc.damage, orc.move_range])
	var tiles := {}
	var clash := false
	for u in main.battle_units:
		for cell in main._footprint(u.tile, int(u.get("size", 1))):
			if tiles.has(cell) or cell == main.battle_player_tile:
				clash = true
			tiles[cell] = true
	print("nobody stands on anybody else: clash=%s (expected false)" % [clash])
	print("the game counts them: enemies_alive %d -> %d (expected +2)" % [alive_before, main.enemies_alive])
	print("they are on the turn order: %s (expected true)" % [main.battle_timeline.any(func(t): return int(t.tid) == int(orc.tid))])
	r = DB.add_enemy(main, "Brute", 1, 1, true, 1.0)
	var brute: Dictionary = main.battle_units[main.battle_units.size() - 1]
	print("a big elite Brute: ok=%s size=%d elite=%s (expected true, 2, true)" % [r.ok, brute.size, brute.is_elite])
	r = DB.add_enemy(main, "Nothing Real", 1, 1, false)
	print("an enemy that does not exist: ok=%s (expected false)" % [r.ok])
	var allies_before: int = main.battle_allies.size()
	var party_before: int = player.party.size()
	r = DB.add_ally(main, "knight")
	print("a Knight joins: ok=%s allies %d -> %d, party %d -> %d (expected true, +1, +1)" % [r.ok, allies_before, main.battle_allies.size(), party_before, player.party.size()])
	var knight_unit: Dictionary = main.battle_allies[main.battle_allies.size() - 1]
	print("his unit is real: name=%s hp=%d on the turn order=%s (expected Knight, a number, true)" % [knight_unit.name, knight_unit.hp, main.battle_timeline.any(func(t): return int(t.tid) == int(knight_unit.tid))])
	r = DB.add_ally(main, "druid")
	print("a Druid too: ok=%s (expected true)" % [r.ok])
	r = DB.set_ally_pool(main, main.battle_allies.size() - 1, "mana", 7)
	print("her mana set to 7: ok=%s mana=%d (expected true, 7)" % [r.ok, main.battle_allies[main.battle_allies.size() - 1].mana])
	r = DB.set_ally_pool(main, main.battle_allies.size() - 1, "stamina", 7)
	print("a pool she does not have: ok=%s (expected false)" % [r.ok])
	r = DB.set_unit_hp(main, "ally:%d" % (main.battle_allies.size() - 2), 4)
	print("an ally to 4 HP: %d (expected 4)" % [main.battle_allies[main.battle_allies.size() - 2].hp])
	var ai: int = main.battle_allies.size() - 2
	r = DB.down_ally(main, ai)
	print("knocking the Knight down: ok=%s allies now %d, downed %d (expected true, %d, 1)" % [r.ok, main.battle_allies.size(), main.battle_downed_allies.size(), allies_before + 1])
	r = DB.revive_ally(main, 0)
	print("standing him up: ok=%s downed %d, back on the field %s (expected true, 0, true)" % [r.ok, main.battle_downed_allies.size(), main.battle_allies.any(func(a): return str(a.name) == "Knight")])
	r = DB.revive_ally(main, 5)
	print("nobody down there: ok=%s (expected false)" % [r.ok])
	print("the party menu agrees: the Knight and the Druid are in the roster: %s (expected true)" % [player.party.size() >= party_before + 2])

	print("--- ending the turn and the enemies standing still")
	DB.set_enemies_pass(main, true)
	for u in main.battle_units:
		u["hp"] = u.max_hp
	player.health = 500
	var hp_before: int = player.health
	var tiles_before: Array = main.battle_units.map(func(u): return u.tile)
	await _wait_for_hero()
	r = DB.end_my_turn(main)
	print("end my turn: ok=%s (expected true)" % [r.ok])
	await _frames(6)
	await _wait_for_hero()
	var tiles_after: Array = main.battle_units.map(func(u): return u.tile)
	print("with enemies standing still nothing hit you: HP %d -> %d (expected equal)" % [hp_before, player.health])
	print("...and nobody moved: %s (expected true)" % [tiles_before == tiles_after])
	DB.set_enemies_pass(main, false)
	print("Turn every cheat off clears the new switches: %s (expected [false, false])" % [(func():
		DB.set_always_crit(main, true)
		DB.set_enemies_pass(main, true)
		DA.reset_cheats(main)
		return [player.debug_always_crit, player.debug_enemies_pass]).call()])
	r = DB.end_my_turn(main)
	if main.in_battle and main.battle_turn != "player":
		print("(an enemy is mid-turn: end my turn refuses: ok=%s (expected false))" % [r.ok])
	await _wait_for_hero()

	print("--- the battle still ends properly after all that")
	r = DB.win_now(main)
	print("win now: ok=%s, battle over=%s (expected true, true)" % [r.ok, not main.in_battle])
	await _frames(2)
	await _clear_pending()
	r = DB.add_enemy(main, "Goblin", 1, 1, false)
	print("add_enemy with no battle: ok=%s (expected false)" % [r.ok])
	r = DB.end_my_turn(main)
	print("end my turn with no battle: ok=%s (expected false)" % [r.ok])
	r = DB.move_unit(main, "hero", 1, 1)
	print("move with no battle: ok=%s (expected false)" % [r.ok])

	print("--- buildings and events from anywhere")
	var kinds: Array = DW.panel_kinds(main)
	print("the game's building menus are listed: %d kinds, including the shop and the church: %s (expected true)" % [kinds.size(), kinds.has("church") or kinds.has("shop")])
	var kind: String = "church" if kinds.has("church") else str(kinds[0])
	r = DW.open_panel(main, kind)
	print("opening the %s: ok=%s, it is open: %s (expected true, true)" % [kind, r.ok, main._any_town_panel_open()])
	r = DW.open_panel(main, kind)
	print("with one already open another is refused: ok=%s (expected false)" % [r.ok])
	main._close_open_town_panels()
	await _frames(1)
	r = DW.open_panel(main, "not_a_building")
	print("a building that does not exist: ok=%s (expected false)" % [r.ok])
	print("events listed: %s (expected 6 ids)" % [DW.event_ids().size()])
	var swarm_before: int = int(main.event_extra_goblins)
	r = DW.trigger_event(main, "goblin_swarm")
	print("an automatic event applies at once: ok=%s extra goblins %d -> %d (expected true, then more)" % [r.ok, swarm_before, int(main.event_extra_goblins)])
	r = DW.trigger_event(main, "ancient_shrine")
	print("a question event asks: ok=%s event_choosing=%s id=%s (expected true, true, ancient_shrine)" % [r.ok, main.event_choosing, main.active_event_id])
	r = DW.trigger_event(main, "elite_bounty")
	print("while one is on screen a second is refused: ok=%s (expected false)" % [r.ok])
	main._on_event_choice_pressed(false)
	await _clear_pending()
	r = DW.trigger_event(main, "no_such_event")
	print("an event that does not exist: ok=%s (expected false)" % [r.ok])
	quit()
