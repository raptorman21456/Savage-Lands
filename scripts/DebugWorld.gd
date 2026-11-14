extends RefCounted

# The Debug menu's hands, part 2: moving around the world, revealing it, and putting enemies in it. Same rules as DebugActions.gd:
# the game's own functions (Main._enter_interior, Main._track_player_region, OverworldMap.update_rooms, Main._spawn...) do the
# work, every function returns {ok, msg}. Teleports close the menu so you see where you landed (the result's "close").

const WorldMapScript := preload("res://scripts/WorldMap.gd")
const RoomsScript := preload("res://scripts/Rooms.gd")
const InteriorScript := preload("res://scripts/Interior.gd")
const OverworldMapScript := preload("res://scripts/OverworldMap.gd")
const SandboxScript := preload("res://scripts/Sandbox.gd")
const SaveDataScript := preload("res://scripts/SaveData.gd")
const DebugActionsScript := preload("res://scripts/DebugActions.gd")

const TOWN_STEP_OUT := Vector2(0, 250)     # where in front of a town door you stand
const BOSS_APPROACH := Vector2(0, 1100)    # how far in front of a boss's landmark you land (its camp is 750 px)

static func ok(msg: String, extra: Dictionary = {}) -> Dictionary:
	return DebugActionsScript.ok(msg, extra)

static func fail(msg: String) -> Dictionary:
	return DebugActionsScript.fail(msg)

# Why you cannot move right now ("" = you can).
static func why_blocked(main) -> String:
	if bool(main.in_battle):
		return "Finish the battle first (Battle tab: Win now)."
	if bool(main.game_over):
		return "The run is over."
	if bool(main.in_interior):
		return "You are inside a building: leave it first (World tab: Leave the building)."
	if not bool(main.regional_world):
		return "This run uses the old arena world, which has nowhere to travel to."
	return ""

# ---------------------------------------------------------------------------------------------------------------------------
# Where can you stand?
# ---------------------------------------------------------------------------------------------------------------------------

static func _standable(p: Vector2, margin: float) -> bool:
	var size: Vector2 = WorldMapScript.SIZE
	if p.x < 200.0 or p.y < 200.0 or p.x > size.x - 200.0 or p.y > size.y - 200.0:
		return false
	if WorldMapScript.is_blocked(p):
		return false
	var room: Dictionary = RoomsScript.room_at(p)
	if str(room.kind) == "sea":
		return false
	return RoomsScript.layout(room).sample(p) > margin

# The closest standing spot to `pos` (pos itself if it will do): rings of candidates outward. Vector2.INF when there is none.
static func floor_near(pos: Vector2, margin: float = 140.0) -> Vector2:
	RoomsScript.ensure_built()
	if _standable(pos, margin):
		return pos
	for ring in range(1, 26):
		var radius: float = float(ring) * 150.0
		var steps: int = 8 + ring * 3
		for k in steps:
			var a: float = TAU * float(k) / float(steps)
			var p: Vector2 = pos + Vector2(cos(a), sin(a)) * radius
			if _standable(p, margin):
				return p
	return Vector2.INF

# Is the player's body clear of every solid thing at `pos` (trees, walls, buildings)? Needs the area around it built.
static func spot_is_clear(main, pos: Vector2) -> bool:
	var shape := CircleShape2D.new()
	shape.radius = float(main.player.BODY_RADIUS) + 6.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, pos)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [main.player.get_rid()]
	for hit in main.get_world_2d().direct_space_state.intersect_shape(query, 8):
		var body = hit.get("collider")
		# enemies and the like move out of the way; only fixed things count
		if body is StaticBody2D:
			return false
	return true

# The first clear spot at or round `pos` once the ground there is built.
static func clear_spot_near(main, pos: Vector2) -> Vector2:
	if spot_is_clear(main, pos):
		return pos
	for ring in range(1, 14):
		var radius: float = float(ring) * 90.0
		var steps: int = 8 + ring * 2
		for k in steps:
			var a: float = TAU * float(k) / float(steps)
			var p: Vector2 = pos + Vector2(cos(a), sin(a)) * radius
			if _standable(p, 100.0) and spot_is_clear(main, p):
				return p
	return pos

# Puts the player at `pos` the way the game's own travel does: the rooms round it are built, the region and room are noticed,
# the followers and camera catch up.
static func teleport_to(main, pos: Vector2, label: String) -> Dictionary:
	var blocked := why_blocked(main)
	if blocked != "":
		return fail(blocked)
	var spot: Vector2 = floor_near(pos)
	if not spot.is_finite():
		return fail("There is nowhere to stand near %s." % label)
	var p = main.player
	p.global_position = spot
	if main.overworld_map != null:
		main.overworld_map.update_rooms(spot)
	# the room may have just been built: step off anything solid in it
	var clear: Vector2 = clear_spot_near(main, spot)
	if clear != spot:
		p.global_position = clear
		spot = clear
	p.velocity = Vector2.ZERO
	main.player_trail.clear()
	main._snap_party_followers_to_player()
	if main.camera != null:
		main.camera.reset_smoothing()
	main.current_region_id = ""
	main.current_room_id = ""
	main._track_player_region()
	main._track_player_room()
	if main.hud != null:
		main._apply_world_visuals()
	return ok("Teleported to %s." % label, {"close": true})

# ---------------------------------------------------------------------------------------------------------------------------
# The destinations
# ---------------------------------------------------------------------------------------------------------------------------

const CATEGORIES := ["Places", "Regions", "Rooms", "Town", "Inside"]

# Entries: {id, name, sub (a dim line), kind: "pos" | "interior", pos, interior}. Built fresh each time (cheap).
static func destinations(main, category: String) -> Array:
	WorldMapScript.ensure_built()
	RoomsScript.ensure_built()
	var out: Array = []
	match category:
		"Places":
			for l in WorldMapScript.landmarks:
				var at: Vector2 = l.pos
				if str(l.id) == "spawn":
					at = main.PLAYER_SPAWN_POSITION
				elif str(l.kind) == "boss":
					at = l.pos + BOSS_APPROACH
				var sub: String = str(l.kind).capitalize()
				if str(l.get("boss", "")) != "":
					sub = "Boss: %s" % str(l.boss).capitalize().replace("_", " ")
				out.append({"id": "place_" + str(l.id), "name": str(l.name), "sub": sub, "kind": "pos", "pos": at})
		"Regions":
			for r in WorldMapScript.regions:
				if not bool(r.walkable):
					continue
				out.append({"id": "region_" + str(r.id), "name": str(r.name), "sub": "%s  ·  danger %d" % [str(r.id), int(r.tier)], "kind": "pos", "pos": _region_spot(r)})
		"Rooms":
			for r in RoomsScript.rooms:
				if str(r.kind) == "sea":
					continue
				var title: String = str(r.name) if str(r.name) != "" else "Room %d,%d" % [int(r.cell.x), int(r.cell.y)]
				var region_name: String = str(WorldMapScript.region(str(r.region)).get("name", ""))
				out.append({"id": "room_" + str(r.id), "name": title, "sub": "%s  ·  %s  ·  danger %d" % [region_name, str(r.kind), int(r.tier)], "kind": "pos", "pos": r.rect.get_center()})
		"Town":
			for kind in main.town_building_positions:
				var info: Dictionary = main.TOWN_LAYOUT.get(kind, {})
				out.append({"id": "town_" + str(kind), "name": str(info.get("name", str(kind).capitalize())), "sub": "Town", "kind": "pos", "pos": main.town_building_positions[kind] + TOWN_STEP_OUT})
		"Inside":
			var exits: Dictionary = interior_exits(main)
			for kind in InteriorScript.DEFS:
				out.append({"id": "inside_" + str(kind), "name": str(InteriorScript.DEFS[kind].name), "sub": str(kind), "kind": "interior", "interior": str(kind), "door": exits.get(str(kind), {}).get("door", Vector2.INF), "return": exits.get(str(kind), {}).get("return", Vector2.INF)})
	return out

# A good spot in a region: a landmark inside it if there is one, else the middle (or nearby, if the middle is outside it).
static func _region_spot(region: Dictionary) -> Vector2:
	for l in WorldMapScript.landmarks:
		if Geometry2D.is_point_in_polygon(l.pos, region.polygon) and str(WorldMapScript.region_at(l.pos).id) == str(region.id):
			return l.pos
	var centre: Vector2 = region.bounds.get_center()
	if str(WorldMapScript.region_at(centre).id) == str(region.id):
		return centre
	# a ring search for a point that really is in this region
	for ring in range(1, 40):
		var radius: float = float(ring) * 220.0
		for k in 16:
			var p: Vector2 = centre + Vector2(cos(TAU * float(k) / 16.0), sin(TAU * float(k) / 16.0)) * radius
			if region.bounds.has_point(p) and str(WorldMapScript.region_at(p).id) == str(region.id):
				return p
	return centre

# For every building with a room of its own: where its door is and where you step out to ({door, return}).
static func interior_exits(main) -> Dictionary:
	var out: Dictionary = {}
	for kind in main.town_building_positions:
		if InteriorScript.has(str(kind)):
			var at: Vector2 = main.town_building_positions[kind]
			out[str(kind)] = {"door": at + Vector2(0, 160), "return": at + TOWN_STEP_OUT}
	for house in OverworldMapScript.pesca_buildings() + OverworldMapScript.lizen_buildings() + OverworldMapScript.ranch_buildings() + OverworldMapScript.ruin_buildings() + OverworldMapScript.cave_buildings() + OverworldMapScript.gull_buildings():
		out[str(house.interior)] = {"door": house.door, "return": house.return}
	return out

static func go(main, entry: Dictionary) -> Dictionary:
	if str(entry.kind) == "interior":
		return enter_interior(main, str(entry.interior), entry.get("door", Vector2.INF), entry.get("return", Vector2.INF))
	return teleport_to(main, entry.pos, str(entry.name))

# Walks you into a building's room (the game fades out and in); with no door known, out into the town square when you leave.
static func enter_interior(main, kind: String, door: Vector2, back: Vector2) -> Dictionary:
	var blocked := why_blocked(main)
	if blocked != "":
		return fail(blocked)
	if not InteriorScript.DEFS.has(kind):
		return fail("No such room.")
	var from: Vector2 = door if door.is_finite() else main.player.global_position
	var out: Vector2 = back if back.is_finite() else main.player.global_position
	main._enter_interior(kind, from, out)
	return ok("Went inside: %s." % str(InteriorScript.DEFS[kind].name), {"close": true})

static func leave_interior(main) -> Dictionary:
	if not bool(main.in_interior):
		return fail("You are not inside a building.")
	main._leave_interior()
	return ok("Leaving the building.", {"close": true})

# Moves to the nearest clear spot (if you are wedged in a wall or a tree).
static func unstick(main) -> Dictionary:
	var blocked := why_blocked(main)
	if blocked != "":
		return fail(blocked)
	var here: Vector2 = main.player.global_position
	var spot: Vector2 = clear_spot_near(main, here)
	if spot == here:
		return ok("Nothing is in your way here.")
	main.player.global_position = spot
	return ok("Moved you %d px to open ground." % int(here.distance_to(spot)))

# ---------------------------------------------------------------------------------------------------------------------------
# The map and the danger
# ---------------------------------------------------------------------------------------------------------------------------

# The Compass without the talisman: every room counts as visited and every place as found (map, mini-map, legend).
static func reveal_map(main) -> Dictionary:
	RoomsScript.ensure_built()
	for r in RoomsScript.rooms:
		main.visited_rooms[str(r.id)] = true
	for key in main.town_building_positions:
		main.player.discovered_locations[str(key)] = true
	for kind in InteriorScript.DEFS:
		main.player.discovered_locations[str(kind)] = true
	return ok("The whole map is revealed (%d rooms)." % RoomsScript.rooms.size())

static func hide_map(main) -> Dictionary:
	main.visited_rooms.clear()
	main.player.discovered_locations.clear()
	return ok("The map is hidden again (only where you stand is known).")

const DIFFICULTIES := ["baby", "normal", "hard", "apocalyptic"]

# The difficulty enemies are scaled by in this run (the slot's own locked-in difficulty on disk is not changed).
static func set_difficulty(main, difficulty_id: String) -> Dictionary:
	if not DIFFICULTIES.has(difficulty_id):
		return fail("No such difficulty.")
	var p = main.player
	p.difficulty_id = difficulty_id
	p.difficulty_mult = SaveDataScript.get_difficulty_mult(difficulty_id)
	return ok("Enemies now use %s difficulty (x%s HP and damage) for this run." % [difficulty_id, DebugActionsScript._fmt(p.difficulty_mult)])

# The danger tiers a region can have and the HP/damage multiplier each gives.
static func tier_power(tier: int) -> float:
	return WorldMapScript.tier_power(tier)

static func current_tier(main) -> int:
	return int(WorldMapScript.region_at(main.player.global_position).tier)

# ---------------------------------------------------------------------------------------------------------------------------
# Enemies
# ---------------------------------------------------------------------------------------------------------------------------

# Every enemy the game can field: [{name, path, props, hp, dmg, xp, boss, miniboss}] (the Sandbox's catalog, boss flags added).
static func enemy_list(main) -> Array:
	var out: Array = []
	for e in SandboxScript.enemy_catalog():
		var traits: Dictionary = main.ENEMY_TRAITS.get(e.name, {})
		var row: Dictionary = e.duplicate()
		row["boss"] = bool(traits.get("is_boss_tier", false)) and not bool(traits.get("is_miniboss", false))
		row["miniboss"] = bool(traits.get("is_miniboss", false))
		out.append(row)
	return out

static func enemy_entry(main, enemy_name: String) -> Dictionary:
	for e in enemy_list(main):
		if str(e.name) == enemy_name:
			return e
	return {}

# What an enemy's HP and damage are multiplied by to be as strong as one meeting a hero of `enemy_level` (the game scales every
# enemy by the HERO's level, at the difficulty's rate; this gives the extra factor over how the game will already scale it).
# (Regular enemies' early-game HP bonus, Main._early_hp_factor, is not part of this: it keeps following the hero's real level.)
static func level_power(main, enemy_level: int, boss_tier: bool) -> float:
	if enemy_level <= 0:
		return 1.0
	var rate: float = float(main.ENEMY_LEVEL_SCALING_BY_DIFFICULTY.get(main.player.difficulty_id, main.ENEMY_LEVEL_SCALING))
	if boss_tier:
		rate *= float(main.BOSS_LEVEL_SCALING_FACTOR)
	var wanted: float = 1.0 + float(enemy_level - 1) * rate
	return wanted / maxf(0.01, float(main._enemy_level_scale(boss_tier)))

# One enemy node, wired up the way the game's own spawner does (death rewards, size), with the danger tier and strength asked for.
# enemy_level 0 = as strong as the game would make it for you; any other number = as strong as for a hero of that level.
static func make_enemy(main, entry: Dictionary, pos: Vector2, tier: int, elite: bool, power: float = 1.0, enemy_level: int = 0) -> Node:
	power *= level_power(main, enemy_level, bool(main.ENEMY_TRAITS.get(str(entry.name), {}).get("is_boss_tier", false)))
	var node = load(str(entry.path)).new()
	for key in entry.props:
		node.set(key, entry.props[key])
	node.position = pos
	node.is_elite = elite
	if elite:
		node.modulate = main.ELITE_TINT
	if str(entry.name) == "Traitor Wolf":
		node.modulate = main.TRAITOR_WOLF_TINT
		node.died.connect(main._on_wolf_died)
	main._connect_enemy_death(node)
	node.set_meta("region_tier", tier)
	node.set_meta("region_tier_power", WorldMapScript.tier_power(tier))
	if not is_equal_approx(power, 1.0):
		node.set_meta("sandbox_power_tier", power)
	main._size_overworld_enemy(node)
	main.add_child(node)
	main.enemies_alive += 1
	if main.hud != null:
		main.hud.update_enemies(main.enemies_alive)
	return node

# `count` of an enemy standing in a ring round you (just off screen-centre, not on top of you).
static func spawn_near(main, enemy_name: String, count: int, tier: int, elite: bool, power: float = 1.0, enemy_level: int = 0) -> Dictionary:
	var entry: Dictionary = enemy_entry(main, enemy_name)
	if entry.is_empty():
		return fail("No such enemy: %s." % enemy_name)
	if bool(main.in_battle) or bool(main.in_interior):
		return fail("Not now: you are in a battle or a building.")
	var here: Vector2 = main.player.global_position
	var made := 0
	for i in clampi(count, 1, 12):
		var a: float = TAU * float(i) / float(maxi(1, count)) + 0.6
		var at: Vector2 = here + Vector2(cos(a), sin(a)) * 420.0
		var spot: Vector2 = floor_near(at, 80.0) if bool(main.regional_world) else at
		if not spot.is_finite():
			spot = here + Vector2(420.0, 0.0)
		make_enemy(main, entry, spot, tier, elite, power, enemy_level)
		made += 1
	return ok("Spawned %d x %s%s near you." % [made, enemy_name, " (elite)" if elite else ""])

# Gets rid of every enemy walking the map (not the ones in a battle).
static func clear_enemies(main) -> Dictionary:
	if bool(main.in_battle):
		return fail("A battle is going: use Kill all enemies there.")
	var n := 0
	for e in main.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			e.queue_free()
			n += 1
	main.enemies_alive = 0
	if main.hud != null:
		main.hud.update_enemies(0)
	return ok("Removed %d enemies." % n)

# Tops the map up with its own wild enemies, as time would.
static func refill_enemies(main) -> Dictionary:
	if bool(main.in_battle):
		return fail("Not during a battle.")
	if not bool(main.regional_world):
		return fail("Only the regional map refills by itself.")
	var before: int = main.enemies_alive
	main._fill_ambient_population(99)
	return ok("Added %d enemies near you." % (main.enemies_alive - before))

# ---------------------------------------------------------------------------------------------------------------------------
# Buildings and events, from anywhere
# ---------------------------------------------------------------------------------------------------------------------------

const EventsScript := preload("res://scripts/Events.gd")

# The town panels the game has built (shop, church, blacksmith...), by their door's name.
static func panel_kinds(main) -> Array:
	var kinds: Array = main.town_panels.keys()
	kinds.sort()
	return kinds

# Opens a building's menu as if you had walked in (without counting the building as found on your map).
static func open_panel(main, kind: String) -> Dictionary:
	if not main.town_panels.has(kind):
		return fail("There is no '%s' menu." % kind)
	if bool(main._town_door_blocked()):
		return fail("Not now: close what is open (and leave the battle) first.")
	var panel = main.town_panels[kind]
	if kind == "beastiary":
		panel.open()
	else:
		panel.open(main.player)
	return ok("Opened the %s." % kind.replace("_", " "), {"close": true})

static func event_ids() -> Array:
	return EventsScript.EVENT_IDS.duplicate()

static func event_name(id: String) -> String:
	return str(EventsScript.EVENTS.get(id, {}).get("name", id))

# Plays a random event now: an automatic one applies at once; the others put up their question (Yes / No).
static func trigger_event(main, id: String) -> Dictionary:
	if not EventsScript.EVENTS.has(id):
		return fail("No such event: %s." % id)
	if bool(main.in_battle) or bool(main.event_choosing) or bool(main.choosing_stat) or bool(main.game_over) or bool(main.in_interior):
		return fail("Not now: finish what is on screen first (and be out in the open).")
	var def: Dictionary = EventsScript.EVENTS[id]
	if bool(def.get("auto", false)):
		main._apply_automatic_event(id)
		return ok("%s: it applies." % str(def.name), {"close": true})
	main.active_event_id = id
	main.event_choosing = true
	main.get_tree().paused = true
	main.hud.show_event_choice(def.name, main._build_event_description(id), def.yes_label, def.no_label)
	return ok("%s: it asks you." % str(def.name), {"close": true})
