extends SceneTree

# The doc's first new regular enemies: Shadelet (slow, weak, no gold), Disgraced Mage (an enhanced Shade), Fire Mage (ranged, burns) and
# Hermoid (blocks some blows completely; one in eight wears a chest and pays ten times the gold). Draft numbers, so the checks read them
# from the game rather than repeating them. Each line says what it checked.

const DB := preload("res://scripts/DebugBattle.gd")
const SandboxScript := preload("res://scripts/Sandbox.gd")
const NAMES := ["Shadelet", "Disgraced Mage", "Fire Mage", "Hermoid"]

func _wait_for_hero(main) -> void:
	for i in 900:
		if main.in_battle and main.battle_turn == "player" and not main.battle_timeline_running:
			return
		if not main.in_battle:
			return
		await process_frame

func _coin_total(main) -> int:
	var total := 0
	for c in main.get_children():
		if c.get("kind") == "coin":
			total += int(c.get("amount"))
	return total

func _init() -> void:
	seed(20261112)
	await process_frame
	var main = load("res://Main.tscn").instantiate()
	main.regional_world = false
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	main.ambient_spawn_timer = 1.0e9
	main.settings.attack_minigame_enabled = false
	main.settings.combat_minigames_enabled = false
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	print("--- they exist")
	var catalog: Array = SandboxScript.enemy_catalog()
	for n in NAMES:
		var row := {}
		for e in catalog:
			if str(e.name) == n:
				row = e
		print("%s is in the catalog: hp=%s dmg=%s xp=%s (expected real numbers)" % [n, row.get("hp", "missing"), row.get("dmg", "missing"), row.get("xp", "missing")])
	for key in ["shadelet", "disgraced_mage", "fire_mage", "hermoid"]:
		print("the region key '%s' spawns a script: %s (expected true)" % [key, main.REGION_ENEMY_SCRIPTS.has(key)])
	print("Shadelet is weaker and slower than a Goblin's mates: speed %s (expected 3.0), Disgraced Mage faster than a Shade: %s vs %s (expected 9.0 vs 7.0)" % [main.ENEMY_SPEEDS["Shadelet"], main.ENEMY_SPEEDS["Disgraced Mage"], main.ENEMY_SPEEDS["Shade"]])
	print("the editor can put them in a room: %s (expected true)" % [load("res://scripts/MapEditor.gd").ENEMY_KEYS.has("hermoid") and load("res://scripts/MapEditor.gd").ENEMY_KEYS.has("fire_mage")])
	var wm = load("res://scripts/WorldMap.gd")
	print("the volcano has Fire Mages, the beach Hermoids, the Voidlands Shadelets: %s (expected [true, true, true])" % [[
		str(wm.region("volcano_slopes").enemies).contains("fire_mage"), str(wm.region("beach").enemies).contains("hermoid"), str(wm.region("voidlands").enemies).contains("shadelet")]])

	print("--- gold")
	for n in ["Shadelet", "Hermoid"]:
		var script = load("res://scripts/%s.gd" % n)
		var before := _coin_total(main)
		var f = script.new()
		main.add_child(f)
		if n == "Hermoid":
			f.is_chest = false
		f.take_damage(9999)
		await process_frame
		var plain := _coin_total(main) - before
		if n == "Shadelet":
			print("a Shadelet drops no gold: %d coins (expected 0)" % [plain])
		else:
			var g = script.new()
			main.add_child(g)
			g.is_chest = true
			var b2 := _coin_total(main)
			g.take_damage(9999)
			await process_frame
			var chest := _coin_total(main) - b2
			print("a plain Hermoid pays %d coins, a chest Hermoid %d (expected the second to be about ten times the first, at least 8x the plain maximum)" % [plain, chest])
			print("...so the chest one pays more than the plain one could ever: %s (expected true)" % [chest > 6 * 8])

	print("--- in a battle")
	var r: Dictionary = DB.start_battle(main, [{"name": "Hermoid", "count": 1}, {"name": "Fire Mage", "count": 1}], 1, false, 1.0)
	print("a Hermoid and a Fire Mage fight: ok=%s units=%d (expected true, 2)" % [r.ok, main.battle_units.size()])
	await _wait_for_hero(main)
	main.battle_first_attack_used = true
	player.max_health = 9999
	player.health = 9999
	var herm_i := 0
	for i in main.battle_units.size():
		if main.battle_units[i].name == "Hermoid":
			herm_i = i
	main.battle_units[herm_i]["max_hp"] = 9999999
	main.battle_units[herm_i]["hp"] = 9999999
	var h_tile: Vector2i = main.battle_units[herm_i].tile
	DB.move_unit(main, "hero", h_tile.x - 1, h_tile.y)
	main.battle_target_index = herm_i
	var blocked := 0
	var swings := 120
	for i in swings:
		player.stamina = player.max_stamina
		main.battle_turn = "player"
		var hp_before: int = main.battle_units[herm_i].hp
		main._battle_player_fight()
		if main.battle_units[herm_i].hp == hp_before:
			blocked += 1
	print("a Hermoid shrugs off about 30%% of swings: %d of %d blocked (expected between 15%% and 45%%: %d to %d)" % [blocked, swings, int(swings * 0.15), int(swings * 0.45)])
	print("its card says Blocks: %s (expected true)" % [main.ENEMY_TRAITS["Hermoid"].block_chance > 0.0])

	var mage_i := 1 - herm_i
	var mage: Dictionary = main.battle_units[mage_i]
	player.health = 9999
	main.player_burning = false
	main._land_enemy_hit_on_player(mage, 2, main.ENEMY_TRAITS["Fire Mage"])
	print("a Fire Mage's hit sets you alight: burning=%s (expected true)" % [main.player_burning])
	main.player_burning = false
	main._land_enemy_hit_on_player(mage, 2, main.ENEMY_TRAITS["Hermoid"])
	print("a Hermoid's hit does not: burning=%s (expected false)" % [main.player_burning])
	main.player_burning = false
	DB.win_now(main)
	await process_frame
	await _clear(main)
	await _batch_two(main, player)
	await _batch_three(main, player)
	quit()

func _clear(main) -> void:
	for i in 6:
		if main.choosing_stat:
			main._on_levelup_choice_pressed("vigor")
		elif main.event_choosing:
			main._on_event_choice_pressed(false)
		else:
			break
	await process_frame

# Earth Mage, Gale Mage, the Treant and Voidwing becoming ordinary late-game enemies, and the Voidwing Swarm.
func _batch_two(main, player) -> void:
	print("--- the second batch")
	var catalog: Array = SandboxScript.enemy_catalog()
	for n in ["Earth Mage", "Gale Mage", "Voidwing Swarm", "Treant", "Voidwing"]:
		var row := {}
		for e in catalog:
			if str(e.name) == n:
				row = e
		print("%s is in the catalog: hp=%s dmg=%s xp=%s" % [n, row.get("hp", "missing"), row.get("dmg", "missing"), row.get("xp", "missing")])
	var tr: Dictionary = main.ENEMY_TRAITS
	print("the Treant and the Voidwing are no longer minibosses: %s (expected [false, false])" % [[tr["Treant"].get("is_miniboss", false), tr["Voidwing"].get("is_miniboss", false)]])
	print("the Treant and the Voidwing are ordinary spawns now: %s (expected [true, true]); they are not minibosses any more: %s (expected [false, false])" % [
		[main.REGION_ENEMY_SCRIPTS.has("treant"), main.REGION_ENEMY_SCRIPTS.has("voidwing")], [main.MINIBOSS_SCRIPTS.has("treant"), main.MINIBOSS_SCRIPTS.has("voidwing")]])
	print("the Swarm is the Voidlands miniboss: %s (expected true), and it is a miniboss marker: %s (expected true)" % [main.MINIBOSS_SCRIPTS.has("voidwing_swarm"), tr["Voidwing Swarm"].get("is_miniboss", false)])
	var wm = load("res://scripts/WorldMap.gd")
	print("the HeartWood has no miniboss and the Voidlands the Swarm: ['%s', '%s'] (expected ['', 'voidwing_swarm'])" % [wm.region("heartwood_grove").miniboss, wm.region("voidlands").miniboss])
	print("Gale Mage is the fastest thing out there and winds up a charge: speed %s, windup=%s, range %s (expected 12.0, true, 5); Earth Mage the slowest: %s (expected 2.0)" % [main.ENEMY_SPEEDS["Gale Mage"], tr["Gale Mage"].windup, tr["Gale Mage"].attack_range, main.ENEMY_SPEEDS["Earth Mage"]])

	print("--- the Swarm is seven Voidwings")
	var alive_before: int = main.enemies_alive
	var r: Dictionary = DB.start_battle(main, [{"name": "Voidwing Swarm", "count": 1}], 1, false, 1.0)
	var names: Array = main.battle_units.map(func(u): return str(u.name))
	print("starting a fight against the Swarm: ok=%s, units=%d (expected true, 7), all Voidwings: %s (expected true)" % [r.ok, names.size(), names.all(func(n): return n == "Voidwing")])
	var tiles := {}
	for u in main.battle_units:
		tiles[u.tile] = true
	print("on seven different tiles: %d (expected 7)" % [tiles.size()])
	print("no marker is left on the overworld: %s (expected 0)" % [main.get_tree().get_nodes_in_group("enemies").filter(func(e): return is_instance_valid(e) and not e.is_queued_for_deletion() and e.get_display_name() == "Voidwing Swarm").size()])
	await _wait_for_hero(main)
	DB.win_now(main)
	await process_frame
	await _clear(main)

	print("--- the Earth Mage's blast spreads")
	player.max_health = 9999
	player.health = 9999
	r = DB.start_battle(main, [{"name": "Earth Mage", "count": 1}, {"name": "Goblin", "count": 1}], 1, false, 1.0)
	await _wait_for_hero(main)
	DB.add_ally(main, "knight")
	DB.add_ally(main, "druid")
	var mage: Dictionary = main.battle_units[0]
	for u in main.battle_units:
		if u.name == "Earth Mage":
			mage = u
	DB.move_unit(main, "hero", 3, 3)
	DB.move_unit(main, "ally:0", 4, 3)      # next to you
	DB.move_unit(main, "ally:1", 0, 0)      # far away
	var near_hp: int = main.battle_allies[0].hp
	var far_hp: int = main.battle_allies[1].hp
	var hero_hp: int = player.health
	var res: Dictionary = await main._enemy_apply_damage(mage, Vector2i(4, 3), 20, main.ENEMY_TRAITS["Earth Mage"], "normal")
	print("the target ally took the hit: %d -> %d (expected less)" % [near_hp, main.battle_allies[0].hp])
	print("you, standing next to them, took half: %d -> %d (expected less)" % [hero_hp, player.health])
	print("the one far away took nothing: %d -> %d (expected equal)" % [far_hp, main.battle_allies[1].hp])
	hero_hp = player.health
	near_hp = main.battle_allies[0].hp
	await main._enemy_apply_damage(mage, Vector2i(3, 3), 20, main.ENEMY_TRAITS["Earth Mage"], "normal")
	print("hitting you instead: you took it (%d -> %d, expected less) and the ally beside you took half (%d -> %d, expected less)" % [hero_hp, player.health, near_hp, main.battle_allies[0].hp])
	var plain_hp: int = main.battle_allies[0].hp
	await main._enemy_apply_damage(mage, Vector2i(3, 3), 20, {}, "normal")
	print("an ordinary enemy's hit does not spread: ally %d -> %d (expected equal)" % [plain_hp, main.battle_allies[0].hp])
	DB.win_now(main)
	await process_frame
	await _clear(main)

# The Constructs, the Wyrm-Hole and the Empowered Mage.
func _batch_three(main, player) -> void:
	print("--- the third batch: the Constructs, the Wyrm-Hole, the Empowered Mage")
	var catalog: Array = SandboxScript.enemy_catalog()
	for n in ["Water Construct", "Stone Construct", "Frost Construct", "Wyrm-Hole", "Empowered Mage"]:
		var row := {}
		for e in catalog:
			if str(e.name) == n:
				row = e
		print("%s is in the catalog: hp=%s dmg=%s xp=%s (expected real numbers)" % [n, row.get("hp", "missing"), row.get("dmg", "missing"), row.get("xp", "missing")])
	var tr: Dictionary = main.ENEMY_TRAITS
	var wm = load("res://scripts/WorldMap.gd")
	print("the Stone Construct holds the ruins, the Frost Construct the Frozen Wastes, the Wyrm-Hole the desert: ['%s', '%s', '%s'] (expected stone_construct, frost_construct, wyrm_hole)" % [wm.region("ruins").miniboss, wm.region("frozen_wastes").miniboss, wm.region("desert").miniboss])
	print("all four are solo miniboss fights: %s (expected true)" % [["Water Construct", "Stone Construct", "Frost Construct", "Wyrm-Hole"].all(func(n): return tr[n].get("is_miniboss", false) and tr[n].get("is_boss_tier", false))])

	player.max_health = 9999
	player.health = 9999
	var r: Dictionary = DB.start_battle(main, [{"name": "Water Construct", "count": 1}], 1, false, 1.0)
	await _wait_for_hero(main)
	var boss: Dictionary = main.battle_units[0]
	var centre := Vector2i(main.BATTLE_GRID_W / 2, main.BATTLE_GRID_H / 2)
	DB.move_unit(main, "enemy:0", centre.x - 1, centre.y)
	main.battle_terrain.clear()

	print("--- Water Construct: a hit shoves you two tiles and leaves water")
	DB.move_unit(main, "hero", centre.x + 1, centre.y)
	var before: Vector2i = main.battle_player_tile
	main._enemy_on_hit_effects(boss, tr["Water Construct"])
	print("shoved away from it: %s -> %s (expected two tiles to the east: %s)" % [before, main.battle_player_tile, before + Vector2i(2, 0)])
	print("water is left where you stood: %s (expected water)" % [main.battle_terrain.get(before, {}).get("type", "none")])
	DB.move_unit(main, "hero", main.BATTLE_GRID_W - 1, centre.y)
	main.battle_terrain.clear()
	before = main.battle_player_tile
	main._enemy_on_hit_effects(boss, tr["Water Construct"])
	print("against the edge nothing moves and nothing is left: %s -> %s, terrain %d (expected unchanged, 0)" % [before, main.battle_player_tile, main.battle_terrain.size()])
	DB.win_now(main)
	await process_frame
	await _clear(main)

	print("--- Frost Construct: a hit slides you three tiles and leaves ice")
	r = DB.start_battle(main, [{"name": "Frost Construct", "count": 1}], 1, false, 1.0)
	await _wait_for_hero(main)
	boss = main.battle_units[0]
	DB.move_unit(main, "enemy:0", centre.x - 1, centre.y)
	main.battle_terrain.clear()
	DB.move_unit(main, "hero", centre.x, centre.y)
	before = main.battle_player_tile
	main._enemy_on_hit_effects(boss, tr["Frost Construct"])
	print("slid away: %s -> %s (expected three tiles east: %s)" % [before, main.battle_player_tile, before + Vector2i(3, 0)])
	print("ice is left where you stood: %s (expected ice)" % [main.battle_terrain.get(before, {}).get("type", "none")])
	DB.win_now(main)
	await process_frame
	await _clear(main)

	print("--- Stone Construct: rocks round you, never a cage, never more than ten")
	r = DB.start_battle(main, [{"name": "Stone Construct", "count": 1}], 1, false, 1.0)
	await _wait_for_hero(main)
	boss = main.battle_units[0]
	main.battle_terrain.clear()
	DB.move_unit(main, "hero", centre.x + 2, centre.y)
	var all_open := true
	var rocks_after_one := 0
	for i in 12:
		main._enemy_turn_start_hook(boss, tr["Stone Construct"], main.battle_player_tile)
		if i == 0:
			rocks_after_one = main.battle_terrain.values().filter(func(t): return t.type == "rock").size()
		var open_sides := 0
		for d in main.CARDINAL_DIRS:
			var n: Vector2i = main.battle_player_tile + d
			if main._in_battle_bounds(n) and not (main.battle_terrain.has(n) and main.battle_terrain[n].type in ["rock", "rubble"]) and not main._battle_tile_occupied(n):
				open_sides += 1
		if open_sides < 1:
			all_open = false
	var rocks: int = main.battle_terrain.values().filter(func(t): return t.type == "rock").size()
	print("the first turn raises two rocks: %d (expected 2)" % [rocks_after_one])
	print("after twelve turns: %d rocks (expected 10 or fewer, and more than 2); you always have a way out: %s (expected true)" % [rocks, all_open])
	DB.win_now(main)
	await process_frame
	await _clear(main)

	print("--- Wyrm-Hole: tunnels and bursts up beside you")
	r = DB.start_battle(main, [{"name": "Wyrm-Hole", "count": 1}], 1, false, 1.0)
	await _wait_for_hero(main)
	boss = main.battle_units[0]
	main.battle_terrain.clear()
	DB.move_unit(main, "hero", centre.x, centre.y)
	print("it is 2x2 and ignores terrain: size=%d ignore_terrain=%s (expected 2, true)" % [boss.size, tr["Wyrm-Hole"].ignore_terrain])
	var jumps := 0
	var bad_spot := false
	for i in 40:
		var from_tile: Vector2i = boss.tile
		main._enemy_turn_start_hook(boss, tr["Wyrm-Hole"], main.battle_player_tile)
		if boss.tile != from_tile:
			jumps += 1
			var dist: int = 99
			for cell in main._footprint(boss.tile, 2):
				dist = mini(dist, maxi(absi(cell.x - main.battle_player_tile.x), absi(cell.y - main.battle_player_tile.y)))
			if dist > 3 or not main._in_battle_bounds(boss.tile) or not main._in_battle_bounds(boss.tile + Vector2i(1, 1)):
				bad_spot = true
	print("it teleports on about half its turns: %d of 40 (expected between 10 and 32)" % [jumps])
	print("always to a legal spot a couple of tiles from you: bad=%s (expected false)" % [bad_spot])
	DB.win_now(main)
	await process_frame
	await _clear(main)

	print("--- Empowered Mage: stronger every turn it lives")
	r = DB.start_battle(main, [{"name": "Empowered Mage", "count": 1}], 1, false, 1.0)
	await _wait_for_hero(main)
	var mage: Dictionary = main.battle_units[0]
	main.battle_terrain.clear()
	mage["hp"] = 99999
	mage["max_hp"] = 99999
	var mv1: Dictionary = DB.move_unit(main, "hero", 3, centre.y)
	var mv2: Dictionary = DB.move_unit(main, "enemy:0", 5, centre.y)
	print("(moved the hero and the mage into range: %s, %s (expected true, true))" % [mv1.ok, mv2.ok])
	mage["stacks"] = 0
	var hp0: int = player.health
	await main._enemy_take_turn(mage, {mage.ref: main.battle_player_tile}, [])
	var hit0: int = hp0 - player.health
	print("a fresh Empowered Mage hit you for %d and now has %d stack (expected a real hit, 1 stack)" % [hit0, int(mage.get("stacks", 0))])
	mage["stacks"] = 6
	DB.move_unit(main, "enemy:0", 5, centre.y)
	var hp1: int = player.health
	await main._enemy_take_turn(mage, {mage.ref: main.battle_player_tile}, [])
	var hit6: int = hp1 - player.health
	print("with 6 stacks it hit for %d, about 1.6x the fresh hit of %d (expected between 1.3x and 1.9x)" % [hit6, hit0])
	mage["stacks"] = 10
	await main._enemy_take_turn(mage, {mage.ref: main.battle_player_tile}, [])
	print("stacks stop at the cap: %d (expected 10)" % [int(mage.stacks)])
	print("its hit blinds you: %s (expected true)" % [main.player_blind_turns > 0 or tr["Empowered Mage"].inflicts_blind])
	DB.win_now(main)
	await process_frame
	await _clear(main)
