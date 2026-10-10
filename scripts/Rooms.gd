extends RefCounted
class_name Rooms

# The continent as ROOMS, Zelda-style. WorldMap.gd says what the land is (regions, landmarks); this says how it is
# cut up: an 11 x 11 grid of big rooms (about 3,050 x 2,160 px -- four screens wide), many of them merged into long,
# tall and great ones. Only the room you are in and the ones near it are built, and each room has its own
# personality: a VARIANT (a mossy hollow, a wolf den, standing stones, a bog...) that decides its set pieces, who
# lives there and how many, and a SHAPE (RoomLayout.gd: a glade, a winding path, a ring, a canyon, a lake field...)
# that decides where you can walk and where the land is solid.
#
# Crossing from one room to the next is seamless -- no loading screen -- because the neighbours are already built
# by the time you reach the edge. Where two rooms meet the way through is fixed by the edge itself (see _openings):
# wide open, a wide opening, or one or two narrow gaps -- the same from both sides.
#
# Pure data and geometry, like WorldMap.gd. EVERY number and name here is a DRAFT for the user to tune.

const WorldMapScript := preload("res://scripts/WorldMap.gd")
const RoomLayoutScript := preload("res://scripts/RoomLayout.gd")
const RoomDataScript := preload("res://scripts/RoomData.gd")

const COLS := WorldMapScript.ROOM_COLS
const ROWS := WorldMapScript.ROOM_ROWS
const EDGE_MARGIN := 400.0           # roaming enemies spawn at least this far inside a room
const TARGET_SCALE := 0.4            # the variants' "target" is a feel; this turns it into enemies kept in a room
const SEA_LAND_FRACTION := 0.12      # a room with less land than this is open sea
# Chances that a free cell is merged with its neighbour(s) of the same country into one bigger room.
const MERGE_BIG := 0.05              # 2 x 2
const MERGE_WIDE := 0.22             # 2 x 1
const MERGE_TALL := 0.16             # 1 x 2

# The shapes (RoomLayout.gd archetypes) each kind of country picks from, by weight. A room whose variant has set
# pieces (a pond, a camp...) only takes the roomy ones.
const LAYOUTS := {
	"woods": [["glade", 3], ["twin_glades", 2], ["winding_path", 4], ["crossroads", 1], ["ring", 2], ["horseshoe", 1], ["branch", 2], ["l_shape", 1]],
	"woods_edge": [["glade", 2], ["winding_path", 2], ["groves", 3], ["l_shape", 1], ["open", 1], ["lakes", 1]],
	"plains": [["open", 2], ["lakes", 3], ["groves", 3], ["river_lake", 2], ["mesa_field", 1], ["l_shape", 1]],
	"ruins": [["groves", 2], ["open", 2], ["ring", 1], ["l_shape", 1], ["glade", 1]],
	"desert": [["canyon", 3], ["mesa_field", 3], ["glade", 1], ["winding_path", 1], ["l_shape", 1], ["twin_glades", 1]],
	"hills": [["glade", 2], ["canyon", 2], ["winding_path", 2], ["mesa_field", 2], ["twin_glades", 1], ["l_shape", 1]],
	"mountains": [["canyon", 3], ["winding_path", 3], ["crossroads", 1], ["branch", 2], ["horseshoe", 1], ["twin_glades", 1], ["ring", 1]],
	"volcano": [["river_lake", 3], ["islands", 2], ["canyon", 2], ["glade", 1], ["winding_path", 1]],
	"frozen": [["lakes", 3], ["islands", 2], ["glade", 2], ["groves", 2], ["winding_path", 1], ["ring", 1]],
	"swamp": [["islands", 4], ["branch", 2], ["lakes", 2], ["winding_path", 2], ["groves", 1]],
	"void": [["islands", 4], ["ring", 2], ["crossroads", 1], ["glade", 1], ["river_lake", 2]],
	"beach": [["open", 3], ["lakes", 2], ["groves", 1], ["l_shape", 1], ["glade", 1]],
	"lizen": [["open", 2], ["groves", 2], ["l_shape", 1]],
}
const ROOMY := ["glade", "twin_glades", "open", "lakes", "groves", "river_lake", "mesa_field", "l_shape", "canyon"]
# What fills the solid part of a room, by what the archetype does with it: "wall" layouts are enclosed by it,
# "pool" ones have lakes (or chasms, or lava) in a field, "obstacle" ones have groves and mesas.
const ARCHETYPE_ROLE := {
	"glade": "wall", "twin_glades": "wall", "winding_path": "wall", "crossroads": "wall", "ring": "wall", "horseshoe": "wall",
	"canyon": "wall", "l_shape": "wall", "branch": "wall", "lakes": "pool", "river_lake": "pool", "islands": "pool",
	"groves": "obstacle", "mesa_field": "obstacle", "open": "", "authored": "wall",
}
const MASS := {
	"wall": {"woods": "forest", "woods_edge": "forest", "mountains": "rock", "hills": "rock", "desert": "sandstone", "volcano": "volcanic", "frozen": "pines", "swamp": "dead_forest", "void": "crystal_rock", "plains": "thicket", "ruins": "thicket", "lizen": "thicket", "beach": "rock"},
	"pool": {"plains": "water", "woods": "water", "woods_edge": "water", "ruins": "water", "lizen": "water", "beach": "water", "desert": "water", "hills": "water", "mountains": "water", "volcano": "lava", "frozen": "ice", "swamp": "bog", "void": "abyss"},
	"obstacle": {"plains": "thicket", "woods": "forest", "woods_edge": "forest", "ruins": "rock", "lizen": "rock", "beach": "rock", "desert": "sandstone", "hills": "rock", "mountains": "rock", "volcano": "volcanic", "frozen": "pines", "swamp": "dead_forest", "void": "crystal_rock"},
}
# How much room each kind of set piece needs (a layout is made big enough for the biggest one its room has).
const FEATURE_RADIUS := {
	"clearing": 300.0, "standing_stones": 260.0, "farm": 420.0, "pond": 250.0, "rock_formation": 260.0, "camp": 330.0,
	"fallen_logs": 260.0, "ruin_walls": 340.0, "graves": 300.0, "cliff_ridge": 520.0, "mouth": 260.0, "crystals": 280.0,
	"lighthouse": 200.0, "wreck": 300.0,
}
# How far from a landmark's centre its structure reaches (the room keeps that much floor around it).
const STRUCTURE_RADIUS := {
	"heartwood": 1550.0, "ruins": 1000.0, "lizen_encampment": 800.0, "leviathan_shore": 560.0, "frozen_spire": 560.0,
	"crater": 1150.0, "void_throne": 800.0, "caves": 1000.0,
}

# Rooms that are bigger than one cell: id -> [first col, first row, last col, last row].
const MERGED := {
	"heartwood": [1, 1, 2, 2],
	"ruins": [4, 0, 5, 0],
	"crater": [7, 1, 7, 2],
	"pesca": [2, 8, 3, 9],
}

# A room is picked from its country's variants by weight. features: placeholder set pieces OverworldMap builds
# ([kind, count] or [kind, count, flavour]); decor: multipliers on the region's scenery chances by thing; enemies:
# replaces the region's table when present; target: how many roam there (see TARGET_SCALE).
const VARIANTS := {
	"plains": [
		{"id": "open_fields", "name": "Open Fields", "weight": 5, "features": [], "target": 7},
		{"id": "wildflower_meadow", "name": "Wildflower Meadow", "weight": 3, "decor": {"tuft": 2.0, "bush": 1.6}, "features": [], "target": 6},
		{"id": "standing_stones", "named": true, "name": "Standing Stones", "weight": 2, "features": [["standing_stones", 1]], "target": 6},
		{"id": "abandoned_farmstead", "named": true, "name": "Abandoned Farmstead", "weight": 2, "features": [["farm", 1]], "enemies": [["goblin", 6], ["orc", 2]], "target": 8},
		{"id": "reed_pond", "name": "Reed Pond", "weight": 2, "features": [["pond", 1, "water"]], "target": 6},
		{"id": "windswept_rise", "name": "Windswept Rise", "weight": 2, "features": [["rock_formation", 2]], "target": 7},
		{"id": "bandit_camp", "named": true, "name": "Bandit Camp", "weight": 1, "features": [["camp", 1]], "enemies": [["goblin", 5], ["orc", 3], ["archer", 1]], "target": 9},
	],
	"woods_edge": [
		{"id": "forest_edge", "name": "Forest Edge", "weight": 4, "features": [], "target": 7},
		{"id": "wayside_glade", "name": "Wayside Glade", "weight": 2, "features": [["clearing", 1]], "target": 6},
		{"id": "woodcutters_yard", "named": true, "name": "Woodcutter's Yard", "weight": 1, "features": [["camp", 1], ["fallen_logs", 1]], "enemies": [["goblin", 5], ["orc", 2]], "target": 8},
	],
	"woods": [
		{"id": "tangled_thicket", "name": "Tangled Thicket", "weight": 5, "decor": {"tree": 1.25}, "features": [], "target": 7},
		{"id": "mossy_hollow", "name": "Mossy Hollow", "weight": 3, "features": [["clearing", 1]], "target": 6},
		{"id": "whispering_glade", "name": "Whispering Glade", "weight": 2, "features": [["clearing", 2]], "target": 5},
		{"id": "wolf_den", "named": true, "name": "Wolf Den", "weight": 2, "features": [["rock_formation", 1], ["fallen_logs", 1]], "enemies": [["wolf", 8], ["goblin", 1]], "target": 10},
		{"id": "fallen_giants", "name": "Fallen Giants", "weight": 2, "features": [["fallen_logs", 2]], "target": 7},
		{"id": "fae_ring", "named": true, "name": "Fae Ring", "weight": 2, "features": [["standing_stones", 1]], "enemies": [["fae_hut", 3], ["gnome_pack", 2], ["wolf", 1]], "target": 7},
		{"id": "hunters_camp", "named": true, "name": "Hunter's Camp", "weight": 1, "features": [["camp", 1]], "enemies": [["goblin", 3], ["archer", 2], ["wolf", 2]], "target": 8},
		{"id": "fern_stream", "name": "Fern Stream", "weight": 2, "features": [["pond", 2, "water"]], "target": 6},
	],
	"ruins": [
		{"id": "ruined_houses", "name": "Ruined Houses", "weight": 3, "features": [["ruin_walls", 2]], "target": 8},
		{"id": "collapsed_chapel", "named": true, "name": "Collapsed Chapel", "weight": 2, "features": [["ruin_walls", 1], ["graves", 1]], "target": 8},
		{"id": "graveyard", "named": true, "name": "The Graveyard", "weight": 2, "features": [["graves", 2]], "enemies": [["shade", 6], ["orc", 1]], "target": 9},
	],
	"desert": [
		{"id": "dunes", "name": "Rolling Dunes", "weight": 4, "features": [], "target": 7},
		{"id": "oasis", "named": true, "name": "The Oasis", "weight": 1, "features": [["pond", 1, "water"]], "target": 5},
		{"id": "bone_field", "named": true, "name": "Bone Field", "weight": 2, "features": [["rock_formation", 1]], "target": 8},
		{"id": "sandstone_arches", "name": "Sandstone Arches", "weight": 2, "features": [["rock_formation", 3]], "target": 7},
	],
	"hills": [
		{"id": "scree_slope", "name": "Scree Slope", "weight": 4, "features": [], "target": 7},
		{"id": "stone_circle", "named": true, "name": "Stone Circle", "weight": 1, "features": [["standing_stones", 1]], "target": 6},
		{"id": "old_quarry", "named": true, "name": "Old Quarry", "weight": 2, "features": [["rock_formation", 2], ["camp", 1]], "target": 8},
	],
	"volcano": [
		{"id": "ash_flats", "name": "Ash Flats", "weight": 3, "features": [], "target": 7},
		{"id": "lava_field", "name": "Lava Field", "weight": 2, "features": [["pond", 2, "lava"]], "target": 7},
		{"id": "obsidian_ridge", "name": "Obsidian Ridge", "weight": 2, "features": [["cliff_ridge", 1]], "target": 8},
	],
	"mountains": [
		{"id": "cliff_pass", "name": "Cliff Pass", "weight": 3, "features": [["cliff_ridge", 1]], "target": 7},
		{"id": "high_meadow", "name": "High Meadow", "weight": 2, "features": [["clearing", 1]], "target": 6},
		{"id": "cave_mouth", "named": true, "name": "Cave Mouth", "weight": 2, "features": [["rock_formation", 1], ["mouth", 1]], "target": 8},
		{"id": "rockfall", "name": "Rockfall", "weight": 3, "features": [["rock_formation", 3]], "target": 7},
	],
	"lizen": [
		{"id": "lizen_fields", "name": "Lizen Fields", "weight": 1, "features": [["camp", 1]], "target": 8},
	],
	"swamp": [
		{"id": "bog", "name": "The Bog", "weight": 4, "features": [["pond", 2, "bog"]], "target": 7},
		{"id": "dead_wood", "name": "Dead Wood", "weight": 3, "decor": {"dead_tree": 1.6}, "features": [], "target": 7},
		{"id": "rotting_boardwalk", "name": "Rotting Boardwalk", "weight": 1, "features": [["pond", 1, "bog"], ["fallen_logs", 1]], "target": 6},
		{"id": "hags_hut", "named": true, "name": "Hag's Hut", "weight": 1, "features": [["camp", 1]], "enemies": [["fae_hut", 3], ["shade", 3]], "target": 8},
	],
	"beach": [
		{"id": "driftwood_shore", "name": "Driftwood Shore", "weight": 3, "features": [["fallen_logs", 1]], "target": 6},
		{"id": "tidal_pools", "name": "Tidal Pools", "weight": 2, "features": [["pond", 2, "water"]], "target": 6},
		{"id": "sandy_dunes", "name": "Sandy Dunes", "weight": 3, "features": [], "target": 6},
	],
	"frozen": [
		{"id": "snowfield", "name": "Snowfield", "weight": 4, "features": [], "target": 7},
		{"id": "ice_floes", "name": "Ice Floes", "weight": 2, "features": [["pond", 2, "ice"]], "target": 7},
		{"id": "frozen_pines", "name": "Frozen Pines", "weight": 3, "decor": {"pine": 2.0}, "features": [], "target": 7},
		{"id": "ice_cave", "named": true, "name": "Ice Cave", "weight": 1, "features": [["rock_formation", 1], ["mouth", 1]], "target": 8},
	],
	"void": [
		{"id": "crystal_field", "name": "Crystal Field", "weight": 4, "features": [["crystals", 2]], "target": 8},
		{"id": "rift", "name": "The Rift", "weight": 2, "features": [["pond", 2, "void"]], "target": 9},
		{"id": "broken_ground", "name": "Broken Ground", "weight": 3, "features": [], "target": 8},
	],
}

# Rooms that are a place of their own, found by the landmark inside them (first match in this order wins):
# name, kind ("safe" = no wild enemies; "boss" = its boss waits on the landmark; "wild"), set pieces and enemies.
const LANDMARK_ROOMS := [
	["town", {"id": "castle_town", "name": "The Castle Town", "kind": "safe", "features": [], "target": 0}],
	["pesca", {"id": "pesca", "name": "Pesca", "kind": "safe", "features": [], "target": 0}],
	["ranch", {"id": "ranch", "name": "The Ranch", "kind": "safe", "features": [], "target": 0}],
	["heartwood", {"id": "heartwood", "name": "The HeartWood", "kind": "boss", "features": [], "target": 8}],
	["lizen_encampment", {"id": "lizen_encampment", "name": "The Lizen Encampment", "kind": "boss", "features": [], "target": 7}],
	["leviathan_shore", {"id": "leviathan_shore", "name": "Leviathan's Shore", "kind": "boss", "features": [], "target": 5}],
	["frozen_spire", {"id": "frozen_spire", "name": "The White Spire", "kind": "boss", "features": [], "target": 6}],
	["crater", {"id": "crater", "name": "The Crater", "kind": "boss", "features": [], "target": 6}],
	["void_throne", {"id": "void_throne", "name": "The Void Throne", "kind": "boss", "features": [], "target": 7}],
	["ruins", {"id": "ruined_settlement", "name": "The Ruined Settlement", "kind": "wild", "features": [], "enemies": [["shade", 3], ["orc", 2], ["goblin", 2]], "target": 9}],
	["caves", {"id": "caves", "name": "The Caves", "kind": "wild", "features": [], "target": 8}],
	["spawn", {"id": "spawn_glade", "name": "Where You Woke", "kind": "wild", "features": [], "target": 5}],
]

static var rooms: Array = []
static var _by_id: Dictionary = {}
static var _cell_room: Array = []     # COLS * ROWS -> room id
static var _layouts: Dictionary = {}   # room id -> RoomLayout, built on demand
static var _built := false

static func ensure_built() -> void:
	if _built:
		return
	_built = true
	WorldMapScript.ensure_built()
	_cell_room = []
	_cell_room.resize(COLS * ROWS)
	rooms = []
	_by_id = {}
	_layouts = {}
	# The authored merged rooms first, then random merges of ordinary country into long, tall and big rooms, then a
	# room for every cell still free.
	for id in MERGED:
		var span: Array = MERGED[id]
		_register(_make_room(id, Vector2i(span[0], span[1]), Vector2i(span[2] - span[0] + 1, span[3] - span[1] + 1)))
	_register_authored_rooms()
	_merge_ordinary_rooms()
	for row in ROWS:
		for col in COLS:
			if _cell_room[row * COLS + col] == null:
				_register(_make_room("r%d_%d" % [col, row], Vector2i(col, row), Vector2i(1, 1)))
	_assign_content()

# Some neighbouring cells of the same country become one room: a long hall, a tall valley, a great hollow. Never
# coasts, never a cell with a landmark in it. Seeded, so the world is the same every time.
static func _merge_ordinary_rooms() -> void:
	var locked := {}
	for l in WorldMapScript.landmarks:
		locked[cell_at(l.pos)] = true
	var info := {}
	for row in ROWS:
		for col in COLS:
			var probe := _make_room("probe", Vector2i(col, row), Vector2i(1, 1))
			var s: Dictionary = _survey(probe)
			info[Vector2i(col, row)] = {"group": _group_for(s.region), "land": float(s.land)}
	var rng := RandomNumberGenerator.new()
	rng.seed = WorldMapScript.MAP_SEED + 5
	for row in ROWS:
		for col in COLS:
			var here := Vector2i(col, row)
			if not _can_merge(here, locked, info, null):
				continue
			var group: String = info[here].group
			var roll: float = rng.randf()
			if roll < MERGE_BIG and _free_block(here, Vector2i(2, 2), locked, info, group):
				_register(_make_room("m%d_%d" % [col, row], here, Vector2i(2, 2)))
			elif roll < MERGE_BIG + MERGE_WIDE and _free_block(here, Vector2i(2, 1), locked, info, group):
				_register(_make_room("m%d_%d" % [col, row], here, Vector2i(2, 1)))
			elif roll < MERGE_BIG + MERGE_WIDE + MERGE_TALL and _free_block(here, Vector2i(1, 2), locked, info, group):
				_register(_make_room("m%d_%d" % [col, row], here, Vector2i(1, 2)))

static func _can_merge(cell: Vector2i, locked: Dictionary, info: Dictionary, group) -> bool:
	if cell.x >= COLS or cell.y >= ROWS or _cell_room[cell.y * COLS + cell.x] != null or locked.has(cell):
		return false
	var i: Dictionary = info[cell]
	if float(i.land) < 0.9 or i.group == "beach":
		return false
	return group == null or i.group == group

static func _free_block(cell: Vector2i, span: Vector2i, locked: Dictionary, info: Dictionary, group: String) -> bool:
	for dy in span.y:
		for dx in span.x:
			if not _can_merge(Vector2i(cell.x + dx, cell.y + dy), locked, info, group):
				return false
	return true

# The hand-made rooms (RoomData.gd) claim their cells first. A cell already taken by one of the landmark rooms above
# (the HeartWood...) keeps that room and its id.
static func _register_authored_rooms() -> void:
	for key in RoomDataScript.ROOMS:
		var parts: PackedStringArray = str(key).split(",")
		var col := int(parts[0])
		var row := int(parts[1])
		if _cell_room[row * COLS + col] != null:
			continue
		var span_data: Array = RoomDataScript.ROOMS[key].get("span", [1, 1])
		var span := Vector2i(int(span_data[0]), int(span_data[1]))
		var id := "r%d_%d" % [col, row] if span == Vector2i(1, 1) else "m%d_%d" % [col, row]
		_register(_make_room(id, Vector2i(col, row), span))

# What a hand-made room overrides on the generated one: its name, shape, solid ground, set pieces, decoration and who
# lives there.
static func _apply_authored(r: Dictionary) -> void:
	var data: Dictionary = RoomDataScript.ROOMS.get("%d,%d" % [r.cell.x, r.cell.y], {})
	if data.is_empty():
		return
	r.authored = true
	r.name = str(data.get("name", ""))                  # a hand-made room is named only if it says so
	if data.has("shape"):
		r.layout = "authored"
		r.shape = data.shape
	if data.has("mass"):
		r.mass = str(data.mass)
	elif data.has("shape"):
		r.mass = _mass_for(r)
	r.props = data.get("props", [])                      # a hand-made room has only the set pieces it lists
	r.features = []
	r.needs = 0.0
	if data.has("decor"):
		r.stands = data.decor
	if data.has("enemies"):
		r.enemies = data.enemies
	elif r.landmarks.is_empty():
		r.enemies = []                                   # no generated residents: the country's own
	if data.has("target") and r.kind not in ["safe", "sea"]:
		r.target = int(data.target)
	elif r.landmarks.is_empty() and r.kind not in ["safe", "sea"]:
		r.target = 3

static func _register(r: Dictionary) -> void:
	rooms.append(r)
	_by_id[r.id] = r
	for dy in r.span.y:
		for dx in r.span.x:
			_cell_room[(r.cell.y + dy) * COLS + r.cell.x + dx] = r.id

static func _make_room(id: String, cell: Vector2i, span: Vector2i) -> Dictionary:
	var x0: int = WorldMapScript.col_x(cell.x)
	var y0: int = WorldMapScript.row_y(cell.y)
	var rect := Rect2(Vector2(x0, y0), Vector2(WorldMapScript.col_x(cell.x + span.x) - x0, WorldMapScript.row_y(cell.y + span.y) - y0))
	return {
		"id": id, "cell": cell, "span": span, "rect": rect, "name": "", "variant": "", "kind": "wild",
		"region": "", "group": "", "tier": 1, "land": 1.0, "target": 0, "enemies": [], "features": [], "decor": {},
		"landmarks": [], "layout": "open", "mass": "", "needs": 0.0, "shape": [], "stands": null, "props": null, "authored": false, "seed": hash(id) ^ WorldMapScript.MAP_SEED,
	}

# Names, variants and kinds: from the country under each room and the landmark in it (if any).
static func _assign_content() -> void:
	for l in WorldMapScript.landmarks:
		var home: Dictionary = room_at(l.pos)
		home.landmarks.append(l.id)
	for r in rooms:
		var survey: Dictionary = _survey(r)
		var region: Dictionary = survey.region
		r.region = region.id
		r.tier = int(region.tier)
		r.land = float(survey.land)
		r.group = _group_for(region)
		var fixed: Dictionary = {}
		for entry in LANDMARK_ROOMS:
			if entry[0] in r.landmarks:
				fixed = entry[1]
				break
		var variant: Dictionary
		if not fixed.is_empty():
			variant = fixed
			r.kind = fixed.kind
		elif r.land < SEA_LAND_FRACTION:
			r.kind = "sea"
			variant = {"id": "open_sea", "name": "The Open Sea", "features": [], "target": 0}
		else:
			var rng := RandomNumberGenerator.new()
			rng.seed = r.seed
			variant = _pick_variant(r.group, rng, _variants_nearby(r))
		# only places worth a name get one (the town, the ruins, a bandit camp...); ordinary country stays nameless
		r.name = str(variant.name) if (not fixed.is_empty() or bool(variant.get("named", false))) else ""
		r.variant = str(variant.id)
		r.features = variant.get("features", [])
		r.needs = 0.0
		for f in r.features:
			r.needs = maxf(r.needs, float(FEATURE_RADIUS.get(str(f[0]), 260.0)))
		r.decor = variant.get("decor", {})
		r.enemies = variant.get("enemies", [])
		var base_target: float = float(variant.get("target", 0))
		r.target = 0 if r.kind in ["safe", "sea"] else maxi(1, int(round(base_target * TARGET_SCALE * maxf(r.land, 0.35))))
		r.layout = _choose_layout(r, fixed)
		r.mass = _mass_for(r)
		_apply_authored(r)

# Which shape a room takes: the places you start and trade in are open; coasts are open; a boss's arena is a glade;
# the rest pick from their country's shapes (only the roomy ones if the room has set pieces to fit in).
static func _choose_layout(r: Dictionary, fixed: Dictionary) -> String:
	if r.kind in ["safe", "sea"] or "spawn" in r.landmarks or float(r.land) < 0.85:
		return "open"
	if not fixed.is_empty():
		return "canyon" if "caves" in r.landmarks else "glade"
	var options: Array = LAYOUTS.get(r.group, LAYOUTS["plains"])
	var pool: Array = []
	var total := 0.0
	for o in options:
		if r.features.is_empty() or o[0] in ROOMY:
			pool.append(o)
			total += float(o[1])
	if pool.is_empty():
		return "glade"
	var roll: float = _hash01(str(r.id) + "layout") * total
	for o in pool:
		roll -= float(o[1])
		if roll <= 0.0:
			return str(o[0])
	return str(pool[0][0])

# What the solid ground in a room is made of (see OverworldMap.MASS_STYLES); "" when it has none.
static func _mass_for(r: Dictionary) -> String:
	var role: String = str(ARCHETYPE_ROLE.get(r.layout, ""))
	if role == "":
		return ""
	return str(MASS[role].get(r.group, MASS[role]["plains"]))

static func _group_for(region: Dictionary) -> String:
	match region.id:
		"great_expanse", "ranch": return "plains"
		"woods_edge": return "woods_edge"
		"woods", "heartwood_grove": return "woods"
		"ruins": return "ruins"
		"desert": return "desert"
		"volcano_hills": return "hills"
		"volcano_slopes", "crater": return "volcano"
		"mountains": return "mountains"
		"lizen": return "lizen"
		"swamp": return "swamp"
		"beach", "pesca", "ocean", "long_pier", "gull_rock": return "beach"
		"frozen_wastes": return "frozen"
		"voidlands": return "void"
	return "plains"

# Variants already given to the rooms to the west and north (decided before this one), so a row of rooms does not
# repeat itself.
static func _variants_nearby(r: Dictionary) -> Array:
	var out: Array = []
	for offset in [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
		var cx: int = r.cell.x + offset.x
		var cy: int = r.cell.y + offset.y
		if cx < 0 or cy < 0:
			continue
		var other_id = _cell_room[cy * COLS + cx]
		if other_id != null and other_id != r.id and str(_by_id[other_id].variant) != "":
			out.append(str(_by_id[other_id].variant))
	return out

const REPEAT_WEIGHT := 0.25          # a variant a neighbour already has is only this likely, relative

static func _pick_variant(group: String, rng: RandomNumberGenerator, avoid: Array = []) -> Dictionary:
	var options: Array = VARIANTS.get(group, VARIANTS["plains"])
	var total := 0.0
	for v in options:
		total += _variant_weight(v, avoid)
	var roll: float = rng.randf() * total
	for v in options:
		roll -= _variant_weight(v, avoid)
		if roll <= 0.0:
			return v
	return options[0]

static func _variant_weight(v: Dictionary, avoid: Array) -> float:
	return float(v.weight) * (REPEAT_WEIGHT if str(v.id) in avoid else 1.0)

# What a room is mostly made of: the walkable region covering most of a 6 x 6 lattice of sample points, and the
# fraction of the samples that are walkable at all.
static func _survey(r: Dictionary) -> Dictionary:
	var counts := {}
	var land := 0
	var total := 0
	var rect: Rect2 = r.rect
	for ix in 6:
		for iy in 6:
			var p: Vector2 = rect.position + Vector2((float(ix) + 0.5) / 6.0, (float(iy) + 0.5) / 6.0) * rect.size
			var found: Dictionary = WorldMapScript.region_at(p)
			total += 1
			if found.walkable:
				land += 1
				counts[found.id] = int(counts.get(found.id, 0)) + 1
	var best := ""
	var best_n := -1
	for id in counts:
		if int(counts[id]) > best_n:
			best_n = int(counts[id])
			best = id
	if best == "":
		best = "ocean"
	return {"region": WorldMapScript.region(best), "land": float(land) / float(total)}

# --- queries -----------------------------------------------------------------------------------

static func by_id(id: String) -> Dictionary:
	ensure_built()
	return _by_id.get(id, {})

static func cell_at(pos: Vector2) -> Vector2i:
	ensure_built()
	var col := COLS - 1
	for i in COLS:
		if pos.x < WorldMapScript.col_x(i + 1):
			col = i
			break
	var row := ROWS - 1
	for j in ROWS:
		if pos.y < WorldMapScript.row_y(j + 1):
			row = j
			break
	return Vector2i(col, row)

static func room_at(pos: Vector2) -> Dictionary:
	ensure_built()
	var cell := cell_at(pos)
	return _by_id[_cell_room[cell.y * COLS + cell.x]]

# Rooms touching this one by an edge or a corner (the 3 x 3 neighbourhood, itself excluded).
static func neighbours(r: Dictionary) -> Array:
	ensure_built()
	var out: Array = []
	var seen := {}
	for dy in range(-1, r.span.y + 1):
		for dx in range(-1, r.span.x + 1):
			var cx: int = r.cell.x + dx
			var cy: int = r.cell.y + dy
			if cx < 0 or cy < 0 or cx >= COLS or cy >= ROWS:
				continue
			var id: String = _cell_room[cy * COLS + cx]
			if id == r.id or seen.has(id):
				continue
			seen[id] = true
			out.append(_by_id[id])
	return out

# The room you are in plus its neighbours: what is kept built.
static func loaded_set(r: Dictionary) -> Array:
	var out: Array = [r]
	out.append_array(neighbours(r))
	return out

# Every room whose rectangle is within `margin` of a point (a room becomes "active" as you approach it).
static func rooms_near(pos: Vector2, margin: float) -> Array:
	ensure_built()
	var out: Array = []
	for r in rooms:
		if r.rect.grow(margin).has_point(pos):
			out.append(r)
	return out

# The sides of a room that border another room, one entry per cell side: {side: "n"|"e"|"s"|"w", from, to (the
# segment, the same direction seen from both rooms), length, other (the neighbouring room), key, inward (the
# direction into this room), openings: [[t0, t1], ...] (the stretches of the side, as fractions along from -> to,
# where you can pass through: the same from both sides)}.
static func edges(r: Dictionary) -> Array:
	ensure_built()
	var out: Array = []
	for dy in r.span.y:
		for dx in r.span.x:
			var cx: int = r.cell.x + dx
			var cy: int = r.cell.y + dy
			for side in ["n", "e", "s", "w"]:
				var nx := cx
				var ny := cy
				var inward := Vector2.ZERO
				match side:
					"n": ny -= 1; inward = Vector2(0, 1)
					"s": ny += 1; inward = Vector2(0, -1)
					"e": nx += 1; inward = Vector2(-1, 0)
					"w": nx -= 1; inward = Vector2(1, 0)
				if nx < 0 or ny < 0 or nx >= COLS or ny >= ROWS:
					continue
				var other_id: String = _cell_room[ny * COLS + nx]
				if other_id == r.id:
					continue
				var other: Dictionary = _by_id[other_id]
				var x0: float = WorldMapScript.col_x(cx)
				var x1: float = WorldMapScript.col_x(cx + 1)
				var y0: float = WorldMapScript.row_y(cy)
				var y1: float = WorldMapScript.row_y(cy + 1)
				var a := Vector2.ZERO
				var b := Vector2.ZERO
				match side:
					"n": a = Vector2(x0, y0); b = Vector2(x1, y0)
					"s": a = Vector2(x0, y1); b = Vector2(x1, y1)
					"w": a = Vector2(x0, y0); b = Vector2(x0, y1)
					"e": a = Vector2(x1, y0); b = Vector2(x1, y1)
				var key := _edge_key("%d,%d" % [cx, cy], "%d,%d" % [nx, ny])
				# the hand-made name of this side: the two cells, the left (or top) one first
				var first_is_here: bool = cy < ny or (cy == ny and cx < nx)
				var edge_name := "%d,%d|%d,%d" % ([cx, cy, nx, ny] if first_is_here else [nx, ny, cx, cy])
				out.append({
					"side": side, "from": a, "to": b, "length": a.distance_to(b), "other": other, "key": key, "inward": inward,
					"openings": _openings(r, other, key, a.distance_to(b), edge_name),
				})
	return out

static func _edge_key(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a

static func _hash01(s: String) -> float:
	return float(hash(s) & 0xFFFF) / 65535.0

# How likely each kind of country is to close its edges to a few narrow gaps (a treeline, a cliff line) instead of
# leaving them wide open.
const ENCLOSURE := {
	"woods": 0.9, "mountains": 0.9, "hills": 0.7, "volcano": 0.7, "swamp": 0.7, "frozen": 0.6, "void": 0.6,
	"desert": 0.5, "woods_edge": 0.5, "plains": 0.12, "ruins": 0.2, "lizen": 0.2, "beach": 0.0,
}
const GAP_WIDTH_MIN := 460.0
const GAP_WIDTH_MAX := 940.0
const CORNER_POST := 160.0             # solid ground kept at every room corner

# The ways through a shared side, decided from the edge alone so both rooms agree: wide open, a wide opening, or one
# or two narrow gaps. Edges at the sea, at safe rooms and at the room you wake in are always wide open.
static func _openings(a: Dictionary, b: Dictionary, key: String, length: float, edge_name: String = "") -> Array:
	if RoomDataScript.EDGES.has(edge_name):
		return _authored_openings(RoomDataScript.EDGES[edge_name], length)
	for r in [a, b]:
		if r.kind in ["sea", "safe"] or "spawn" in r.landmarks or float(r.land) < 0.85:
			return [[0.0, 1.0]]
	var enclose: float = minf(float(ENCLOSURE.get(a.group, 0.3)), float(ENCLOSURE.get(b.group, 0.3)))
	var roll: float = _hash01(key + "m")
	if roll < enclose:
		var gaps := 2 if (length > 2000.0 and _hash01(key + "n") < 0.3) else 1
		var out: Array = []
		for i in gaps:
			var width: float = lerpf(GAP_WIDTH_MIN, GAP_WIDTH_MAX, _hash01(key + "w%d" % i)) / length
			var centre: float
			if gaps == 1:
				centre = 0.22 + 0.56 * _hash01(key + "c")
			else:
				centre = (0.24 + 0.14 * _hash01(key + "c0")) if i == 0 else (0.62 + 0.14 * _hash01(key + "c1"))
			out.append([maxf(centre - width * 0.5, 0.05), minf(centre + width * 0.5, 0.95)])
		return out
	if roll < enclose + (1.0 - enclose) * 0.5:
		var span: float = 0.5 + 0.35 * _hash01(key + "s")
		var start: float = (1.0 - span) * _hash01(key + "t")
		return [[start, start + span]]
	return [[0.0, 1.0]]

# A hand-made side (RoomData.EDGES) as openings: "open", "closed", or [[centre, width], ...] in px along the side.
static func _authored_openings(spec, length: float) -> Array:
	if typeof(spec) == TYPE_STRING:
		return [[0.0, 1.0]] if spec == "open" else []
	var out: Array = []
	for o in spec:
		var half: float = float(o[1]) * 0.5
		out.append([maxf((float(o[0]) - half) / length, 0.0), minf((float(o[0]) + half) / length, 1.0)])
	return out

# The openings of a room as exits for its layout: {pos (on the edge), n (pointing into the room), width, key}.
static func exits(r: Dictionary) -> Array:
	var out: Array = []
	for e in edges(r):
		for o in e.openings:
			# an opening never reaches the corner itself: the corner belongs to four rooms, who each decide their own
			# edges, so it is always a post of solid ground
			var lo: float = maxf(float(o[0]) * float(e.length), CORNER_POST)
			var hi: float = minf(float(o[1]) * float(e.length), float(e.length) - CORNER_POST)
			if hi - lo < 120.0:
				continue
			out.append({"pos": Vector2(e.from).lerp(e.to, (lo + hi) * 0.5 / float(e.length)), "n": e.inward, "width": hi - lo, "key": e.key, "side": e.side})
	return out

# The places a room's layout has to keep as floor: the landmark structures standing in it.
static func structure_discs(r: Dictionary) -> Array:
	var out: Array = []
	if r.kind == "safe":
		return out
	for id in r.landmarks:
		var radius: float = float(STRUCTURE_RADIUS.get(id, 0.0))
		if radius > 0.0:
			out.append([WorldMapScript.landmark(id).pos, radius])
	return out

# The shape of a room (RoomLayout.gd), built the first time it is asked for and kept.
static func layout(r: Dictionary):
	ensure_built()
	if not _layouts.has(r.id):
		_layouts[r.id] = RoomLayoutScript.generate(r, exits(r), structure_discs(r))
	return _layouts[r.id]

# Where roaming enemies may stand: the room, pulled in from its edges.
static func spawn_rect(r: Dictionary) -> Rect2:
	return r.rect.grow(-EDGE_MARGIN)

# The enemy table a room uses: its own variant's, else the country under that point.
static func enemy_table(r: Dictionary, pos: Vector2) -> Array:
	if not r.enemies.is_empty():
		return r.enemies
	return WorldMapScript.region_at(pos).enemies
