extends Node2D
class_name Interior

# The inside of a building: its own small room, parked far off the edge of the map. Walking through a building's door
# in town fades out and puts you here (Main._enter_interior); the shopkeeper stands behind the counter and walking up
# to it opens the same menu the door used to; the doorway at the bottom takes you back outside.
#
# Everything is placeholder art built from shapes (floors, walls, furniture) and the one existing NPC sprite, until the
# user's own art replaces it. Positions in DEFS are px from the room's top-left corner. EVERY number is a DRAFT.

const PickupScript := preload("res://scripts/Pickup.gd")

const WALL := 56.0                     # thickness of the walls round the room
const DOOR_WIDTH := 150.0              # the doorway in the bottom wall

# kind (the town venue it belongs to, or a room of its own with a "venue" it trades as): {name, venue, size, floor, wall, npc [x, y, tint], counter [x, y, width] (or none),
# trade [x, y, width, height] (walk in here to trade; a room with nothing to trade has none, and a "reach" [x, y] the walking
# test must be able to get to instead), things [[kind, x, y], ...], loot [[coin / meat, amount, x, y], ...] (lying about)}
const DEFS := {
	"shop": {
		"name": "General Store", "size": Vector2(1000, 720), "floor": Color(0.46, 0.33, 0.2), "wall": Color(0.27, 0.19, 0.13),
		"npc": [500, 190, Color(0.95, 0.8, 0.5)], "counter": [500, 262, 380], "trade": [500, 340, 260, 70],
		"things": [["shelf", 220, 104], ["shelf", 780, 104], ["barrel", 110, 210], ["barrel", 110, 270], ["barrel", 890, 210], ["crate", 880, 520], ["crate", 944, 520], ["crate", 944, 584], ["rug", 500, 540]],
	},
	"blacksmith": {
		"name": "The Forge", "size": Vector2(1000, 720), "floor": Color(0.38, 0.36, 0.36), "wall": Color(0.2, 0.19, 0.2),
		"npc": [690, 215, Color(0.8, 0.8, 0.85)], "counter": [430, 330, 320], "trade": [430, 405, 240, 70],
		"things": [["forge", 820, 120], ["anvil", 690, 285], ["rack", 200, 104], ["rack", 400, 104], ["barrel", 100, 220], ["barrel", 100, 280], ["barrel", 900, 520]],
	},
	"butcher": {
		"name": "The Butcher", "size": Vector2(900, 680), "floor": Color(0.7, 0.66, 0.6), "wall": Color(0.35, 0.22, 0.2),
		"npc": [450, 190, Color(1.0, 0.8, 0.8)], "counter": [450, 262, 360], "trade": [450, 340, 240, 70],
		"things": [["hang_meat", 160, 100], ["hang_meat", 280, 100], ["hang_meat", 620, 100], ["hang_meat", 740, 100], ["block", 130, 240], ["barrel", 780, 240], ["crate", 800, 540], ["crate", 100, 540]],
	},
	"healer": {
		"name": "The Resting Inn", "size": Vector2(1100, 760), "floor": Color(0.5, 0.36, 0.24), "wall": Color(0.28, 0.2, 0.15),
		"npc": [880, 230, Color(0.85, 1.0, 0.85)], "counter": [880, 300, 260], "trade": [880, 375, 240, 70],
		"things": [["bed", 150, 190], ["bed", 300, 190], ["bed", 450, 190], ["fireplace", 780, 104], ["table", 330, 540], ["table", 820, 560], ["rug", 330, 540]],
	},
	"tavern": {
		"name": "Bounty Hunter's Tavern", "size": Vector2(1100, 780), "floor": Color(0.42, 0.3, 0.19), "wall": Color(0.25, 0.17, 0.12),
		"npc": [550, 175, Color(1.0, 0.85, 0.6)], "counter": [550, 250, 520], "trade": [550, 330, 300, 70],
		"things": [["fireplace", 160, 104], ["barrel", 930, 120], ["barrel", 990, 120], ["round_table", 250, 540], ["round_table", 850, 540], ["round_table", 250, 360], ["rug", 850, 540]],
	},
	"seer": {
		"name": "The Seer's Parlour", "size": Vector2(900, 700), "floor": Color(0.26, 0.18, 0.3), "wall": Color(0.16, 0.1, 0.2),
		"npc": [450, 250, Color(0.85, 0.7, 1.0)], "counter": [450, 330, 220], "trade": [450, 410, 240, 70],
		"things": [["curtain", 110, 110], ["curtain", 790, 110], ["crystal", 450, 335], ["rug", 450, 500], ["candle", 330, 330], ["candle", 570, 330]],
	},
	"dojo": {
		"name": "The Dojo", "size": Vector2(1100, 760), "floor": Color(0.55, 0.42, 0.27), "wall": Color(0.3, 0.2, 0.14),
		"npc": [550, 210, Color(1.0, 0.7, 0.7)], "trade": [550, 300, 260, 70],
		"things": [["mat", 550, 520], ["dummy", 200, 210], ["dummy", 900, 210], ["rack", 260, 104], ["rack", 550, 104], ["rack", 840, 104]],
	},
	"church": {
		"name": "The Church", "size": Vector2(1200, 900), "floor": Color(0.55, 0.54, 0.52), "wall": Color(0.3, 0.3, 0.34),
		"npc": [600, 255, Color(1.0, 1.0, 0.95)], "trade": [600, 345, 280, 70],
		"things": [["altar", 600, 140], ["window", 200, 100], ["window", 400, 100], ["window", 800, 100], ["window", 1000, 100], ["pew", 350, 470], ["pew", 350, 560], ["pew", 350, 650], ["pew", 850, 470], ["pew", 850, 560], ["pew", 850, 650], ["candle", 480, 140], ["candle", 720, 140]],
	},
	"beastiary": {
		"name": "The Beastiary", "size": Vector2(1000, 760), "floor": Color(0.4, 0.3, 0.2), "wall": Color(0.22, 0.16, 0.12),
		"npc": [500, 250, Color(0.8, 0.9, 1.0)], "counter": [500, 330, 260], "trade": [500, 405, 240, 70],
		"things": [["bookshelf", 220, 104], ["bookshelf", 500, 104], ["bookshelf", 780, 104], ["bookshelf", 100, 300], ["bookshelf", 100, 480], ["table", 750, 540], ["rug", 500, 540]],
	},
	"enchanter": {
		"name": "The Wizard's Tower", "size": Vector2(900, 760), "floor": Color(0.3, 0.3, 0.4), "wall": Color(0.15, 0.15, 0.25),
		"npc": [450, 230, Color(0.7, 0.8, 1.0)], "trade": [450, 320, 240, 70],
		"things": [["rune_circle", 450, 500], ["cauldron", 150, 220], ["bookshelf", 300, 104], ["bookshelf", 600, 104], ["crystal", 750, 240]],
	},
	"flea_market": {
		"name": "The Flea Market", "size": Vector2(1200, 760), "floor": Color(0.5, 0.4, 0.28), "wall": Color(0.3, 0.22, 0.15),
		"npc": [600, 300, Color(1.0, 0.92, 0.72)], "trade": [600, 400, 300, 70],
		"things": [["stall", 250, 190], ["stall", 600, 160], ["stall", 950, 190], ["crate", 120, 540], ["crate", 1080, 540], ["barrel", 1060, 330], ["barrel", 140, 330]],
	},
	# --- Pesca's six houses (OverworldMap.PESCA_HOUSES). Each is a dock-town cousin of a town venue ("venue") and opens the
	# same menu; the room is its own.
	"pesca_tavern": {
		"name": "The Salty Gull", "venue": "tavern", "size": Vector2(1100, 780), "floor": Color(0.38, 0.27, 0.17), "wall": Color(0.2, 0.15, 0.11),
		"npc": [550, 175, Color(0.9, 0.85, 0.7)], "counter": [550, 250, 520], "trade": [550, 330, 300, 70],
		"things": [["ship_wheel", 550, 100], ["net", 230, 100], ["net", 870, 100], ["lantern", 400, 108], ["lantern", 700, 108], ["barrel", 90, 170], ["barrel", 90, 236], ["barrel", 1010, 170], ["round_table", 270, 540], ["round_table", 830, 540], ["round_table", 830, 380], ["rope_coil", 560, 660]],
	},
	"pesca_shop": {
		"name": "The Chandlery", "venue": "shop", "size": Vector2(1000, 720), "floor": Color(0.5, 0.4, 0.26), "wall": Color(0.25, 0.2, 0.15),
		"npc": [500, 190, Color(0.9, 0.85, 0.6)], "counter": [500, 262, 380], "trade": [500, 340, 260, 70],
		"things": [["shelf", 220, 104], ["shelf", 780, 104], ["net", 500, 100], ["barrel", 110, 210], ["barrel", 110, 270], ["rope_coil", 890, 230], ["rope_coil", 890, 310], ["sea_chest", 120, 520], ["crate", 880, 520], ["crate", 944, 520], ["rug", 500, 540]],
	},
	"pesca_fish": {
		"name": "The Fishmonger", "venue": "butcher", "size": Vector2(900, 680), "floor": Color(0.62, 0.66, 0.66), "wall": Color(0.2, 0.3, 0.35),
		"npc": [450, 190, Color(0.85, 0.95, 1.0)], "counter": [450, 262, 360], "trade": [450, 340, 240, 70],
		"things": [["fish_rack", 140, 100], ["fish_rack", 270, 100], ["fish_rack", 630, 100], ["fish_rack", 760, 100], ["crate", 130, 240], ["barrel", 780, 240], ["crate", 800, 540], ["crate", 100, 540]],
	},
	"pesca_smith": {
		"name": "The Shipwright's Forge", "venue": "blacksmith", "size": Vector2(1000, 720), "floor": Color(0.34, 0.34, 0.36), "wall": Color(0.18, 0.18, 0.2),
		"npc": [690, 215, Color(0.8, 0.82, 0.9)], "counter": [430, 330, 320], "trade": [430, 405, 240, 70],
		"things": [["forge", 820, 120], ["anvil", 690, 285], ["oars", 200, 104], ["oars", 400, 104], ["anchor", 110, 250], ["barrel", 110, 360], ["rope_coil", 790, 430], ["barrel", 900, 520]],
	},
	"pesca_healer": {
		"name": "The Tidewatch Inn", "venue": "healer", "size": Vector2(1100, 760), "floor": Color(0.45, 0.34, 0.24), "wall": Color(0.24, 0.2, 0.2),
		"npc": [880, 230, Color(0.85, 1.0, 0.9)], "counter": [880, 300, 260], "trade": [880, 375, 240, 70],
		"things": [["hammock", 150, 190], ["hammock", 300, 190], ["hammock", 450, 190], ["fireplace", 700, 104], ["lantern", 560, 108], ["table", 330, 540], ["table", 820, 560], ["rug", 330, 540]],
	},
	"pesca_chapel": {
		"name": "The Sailors' Chapel", "venue": "church", "size": Vector2(1000, 780), "floor": Color(0.5, 0.52, 0.54), "wall": Color(0.26, 0.3, 0.36),
		"npc": [500, 255, Color(0.95, 1.0, 1.0)], "trade": [500, 345, 280, 70],
		"things": [["altar", 500, 140], ["window", 180, 100], ["window", 340, 100], ["window", 660, 100], ["window", 820, 100], ["lantern", 380, 140], ["lantern", 620, 140], ["anchor", 100, 300], ["anchor", 900, 300], ["pew", 300, 470], ["pew", 300, 560], ["pew", 300, 650], ["pew", 700, 470], ["pew", 700, 560], ["pew", 700, 650]],
	},
	# --- The Lizen Encampment's six tents (OverworldMap.LIZEN_TENTS): the warband's camp, a boss's lair, so nothing here trades.
	# Each room is a place to look round with a little loot lying about ("loot": [kind, amount, x, y]); "reach" is a spot
	# the walking test has to be able to get to, in place of a counter.
	"lizen_war": {
		"name": "The War Tent", "size": Vector2(1000, 720), "floor": Color(0.36, 0.28, 0.2), "wall": Color(0.28, 0.3, 0.16),
		"reach": [500, 450],
		"things": [["throne", 500, 130], ["banner", 300, 118], ["banner", 700, 118], ["rack", 140, 104], ["rack", 860, 104], ["war_table", 500, 330], ["brazier", 110, 300], ["brazier", 890, 300], ["rug", 500, 570], ["crate", 880, 560], ["crate", 944, 560]],
		"loot": [["coin", 30, 500, 460]],
	},
	"lizen_barracks": {
		"name": "The Barracks", "size": Vector2(1100, 740), "floor": Color(0.34, 0.3, 0.22), "wall": Color(0.26, 0.3, 0.18),
		"reach": [550, 450],
		"things": [["bunk", 150, 200], ["bunk", 330, 200], ["bunk", 770, 200], ["bunk", 950, 200], ["bunk", 150, 530], ["bunk", 330, 530], ["bunk", 770, 530], ["bunk", 950, 530], ["rack", 550, 104], ["brazier", 550, 330], ["crate", 240, 370], ["crate", 860, 370]],
		"loot": [["coin", 20, 240, 430], ["coin", 20, 860, 430]],
	},
	"lizen_forge": {
		"name": "The Warband's Forge", "size": Vector2(1000, 720), "floor": Color(0.3, 0.3, 0.32), "wall": Color(0.18, 0.2, 0.18),
		"reach": [500, 450],
		"things": [["forge", 800, 120], ["anvil", 660, 285], ["rack", 200, 104], ["rack", 400, 104], ["trough", 160, 300], ["barrel", 100, 480], ["barrel", 900, 520], ["crate", 880, 420]],
		"loot": [["coin", 20, 400, 480]],
	},
	"lizen_mess": {
		"name": "The Mess", "size": Vector2(1100, 760), "floor": Color(0.4, 0.34, 0.24), "wall": Color(0.28, 0.22, 0.15),
		"reach": [250, 450],
		"things": [["cauldron", 150, 180], ["hang_meat", 320, 100], ["hang_meat", 420, 100], ["hang_meat", 680, 100], ["hang_meat", 780, 100], ["long_table", 550, 330], ["long_table", 550, 500], ["barrel", 980, 160], ["barrel", 980, 230], ["crate", 120, 600], ["crate", 990, 600]],
		"loot": [["meat", 1, 250, 470], ["coin", 15, 850, 430]],
	},
	"lizen_armoury": {
		"name": "The Armoury", "size": Vector2(1000, 720), "floor": Color(0.34, 0.34, 0.36), "wall": Color(0.2, 0.2, 0.24),
		"reach": [500, 470],
		"things": [["rack", 180, 104], ["rack", 400, 104], ["rack", 620, 104], ["rack", 840, 104], ["shield_stand", 140, 300], ["shield_stand", 140, 420], ["shield_stand", 860, 300], ["shield_stand", 860, 420], ["crate", 500, 300], ["crate", 564, 300], ["crate", 500, 364], ["rug", 500, 540]],
		"loot": [["coin", 25, 500, 470]],
	},
	"lizen_shaman": {
		"name": "The Shaman's Tent", "size": Vector2(900, 700), "floor": Color(0.26, 0.2, 0.3), "wall": Color(0.16, 0.14, 0.2),
		"reach": [450, 320],
		"things": [["curtain", 110, 110], ["curtain", 790, 110], ["totem", 450, 130], ["cauldron", 200, 260], ["candle", 330, 320], ["candle", 570, 320], ["rune_circle", 450, 490]],
		"loot": [["coin", 20, 700, 300]],
	},
	# --- The Ranch's three buildings (OverworldMap.RANCH_BUILDINGS): a barn with the town's racing horses, the farmhouse and
	# the smokehouse. Each trades as a venue ("venue"): the barn takes bets on the racing horses, the farmhouse puts you
	# up for the night, the smokehouse sells cured meat.
	"ranch_barn": {
		"name": "The Barn", "venue": "horse_racing", "size": Vector2(1100, 780), "floor": Color(0.55, 0.45, 0.28), "wall": Color(0.3, 0.2, 0.12),
		"npc": [550, 190, Color(0.85, 0.9, 0.75)], "counter": [550, 262, 360], "trade": [550, 340, 260, 70],
		"things": [["saddle_rack", 550, 104], ["horse_stall", 150, 220], ["horse_stall", 150, 400], ["horse_stall", 150, 580], ["horse_stall", 950, 220], ["horse_stall", 950, 400], ["horse_stall", 950, 580], ["hay_bale", 420, 520], ["hay_bale", 480, 520], ["hay_bale", 620, 520], ["hay_bale", 680, 520], ["hay", 550, 450]],
	},
	"ranch_house": {
		"name": "The Farmhouse", "venue": "healer", "size": Vector2(1000, 720), "floor": Color(0.5, 0.38, 0.24), "wall": Color(0.3, 0.22, 0.15),
		"npc": [700, 215, Color(1.0, 0.9, 0.8)], "counter": [700, 290, 300], "trade": [700, 365, 240, 70],
		"things": [["bed", 130, 190], ["bed", 270, 190], ["fireplace", 470, 104], ["shelf", 820, 104], ["rug", 300, 520], ["table", 300, 520], ["barrel", 900, 230], ["crate", 880, 560]],
	},
	"ranch_smoke": {
		"name": "The Smokehouse", "venue": "butcher", "size": Vector2(900, 680), "floor": Color(0.5, 0.42, 0.32), "wall": Color(0.25, 0.17, 0.13),
		"npc": [450, 190, Color(1.0, 0.85, 0.8)], "counter": [450, 262, 360], "trade": [450, 340, 240, 70],
		"things": [["hang_meat", 120, 100], ["hang_meat", 210, 100], ["hang_meat", 300, 100], ["hang_meat", 600, 100], ["hang_meat", 690, 100], ["hang_meat", 780, 100], ["block", 130, 260], ["barrel", 780, 260], ["barrel", 780, 330], ["crate", 120, 540], ["crate", 800, 540], ["crate", 800, 480]],
	},
}

# What each kind of furniture looks like: [width, height, colour, solid].
const THINGS := {
	"shelf": [220, 44, Color(0.42, 0.27, 0.14), true], "barrel": [56, 56, Color(0.5, 0.32, 0.16), true],
	"crate": [60, 60, Color(0.55, 0.4, 0.22), true], "rug": [320, 200, Color(0.55, 0.16, 0.16), false],
	"anvil": [70, 44, Color(0.25, 0.25, 0.3), true], "forge": [130, 100, Color(0.35, 0.33, 0.33), true],
	"rack": [180, 34, Color(0.4, 0.28, 0.16), true], "bed": [110, 170, Color(0.55, 0.35, 0.2), true],
	"fireplace": [160, 70, Color(0.4, 0.38, 0.36), true], "table": [130, 90, Color(0.5, 0.34, 0.18), true],
	"round_table": [120, 120, Color(0.45, 0.3, 0.18), true], "pew": [240, 38, Color(0.42, 0.27, 0.14), true],
	"altar": [260, 90, Color(0.82, 0.8, 0.72), true], "window": [100, 70, Color(0.55, 0.75, 0.9), false],
	"curtain": [70, 120, Color(0.45, 0.2, 0.55), false], "dummy": [46, 70, Color(0.7, 0.6, 0.35), true],
	"mat": [420, 260, Color(0.85, 0.82, 0.7), false], "bookshelf": [220, 44, Color(0.3, 0.2, 0.12), true],
	"cauldron": [80, 80, Color(0.15, 0.15, 0.17), true], "block": [60, 60, Color(0.5, 0.3, 0.2), true],
	"stall": [220, 80, Color(0.62, 0.32, 0.22), true], "candle": [14, 22, Color(1.0, 0.9, 0.4), false],
	"hang_meat": [40, 70, Color(0.75, 0.25, 0.25), false], "crystal": [60, 60, Color(0.6, 0.35, 0.9), true],
	"rune_circle": [320, 320, Color(0.35, 0.3, 0.7), false],
	"net": [130, 80, Color(0.62, 0.56, 0.38), false], "fish_rack": [120, 34, Color(0.4, 0.28, 0.16), true],
	"ship_wheel": [86, 86, Color(0.45, 0.3, 0.15), false], "anchor": [60, 90, Color(0.22, 0.24, 0.28), true],
	"lantern": [16, 24, Color(1.0, 0.85, 0.4), false], "rope_coil": [64, 64, Color(0.7, 0.6, 0.38), false],
	"oars": [150, 22, Color(0.5, 0.38, 0.2), true], "sea_chest": [74, 50, Color(0.5, 0.32, 0.16), true],
	"hammock": [100, 150, Color(0.72, 0.66, 0.5), true],
	"war_table": [260, 130, Color(0.42, 0.28, 0.15), true], "banner": [50, 110, Color(0.7, 0.15, 0.13), false],
	"throne": [90, 70, Color(0.35, 0.22, 0.12), true], "brazier": [50, 50, Color(0.28, 0.27, 0.3), true],
	"bunk": [100, 170, Color(0.4, 0.28, 0.16), true], "long_table": [300, 80, Color(0.45, 0.3, 0.17), true],
	"shield_stand": [60, 60, Color(0.55, 0.58, 0.62), true], "totem": [50, 100, Color(0.38, 0.26, 0.14), true],
	"trough": [150, 50, Color(0.4, 0.3, 0.2), true],
	"horse_stall": [170, 150, Color(0.4, 0.28, 0.16), true], "hay_bale": [70, 46, Color(0.85, 0.72, 0.3), true],
	"saddle_rack": [120, 34, Color(0.4, 0.28, 0.16), true], "hay": [220, 110, Color(0.78, 0.66, 0.3), false],
}

var kind := ""
var def: Dictionary = {}
var size := Vector2.ZERO
var origin := Vector2.ZERO
var _on_trade: Callable
var _on_exit: Callable

static func has(venue: String) -> bool:
	return DEFS.has(venue)

# The town venue whose menu a room's counter opens (a town room is its own venue).
static func venue_of(room_kind: String) -> String:
	return str(DEFS[room_kind].get("venue", room_kind))

# Builds the room at `origin` (world position of its top-left corner). on_trade runs when the player walks up to the
# counter, on_exit when they step into the doorway.
func setup(venue: String, at: Vector2, on_trade: Callable, on_exit: Callable) -> void:
	kind = venue
	def = DEFS[venue]
	size = def.size
	origin = at
	position = at
	z_index = -3
	_on_trade = on_trade
	_on_exit = on_exit
	_build_floor()
	_build_walls()
	for t in def.things:
		_build_thing(str(t[0]), Vector2(float(t[1]), float(t[2])))
	_build_npc()
	_build_triggers()
	_build_loot()

func rect() -> Rect2:
	return Rect2(origin, size)

# The spot in a room the walking test has to be able to reach from the doorway: its counter, or its "reach" point.
static func goal_of(room_kind: String) -> Vector2:
	var d: Dictionary = DEFS[room_kind]
	var g: Array = d.trade if d.has("trade") else d.reach
	return Vector2(float(g[0]), float(g[1]))

# Where the player appears: just inside the doorway.
func entry_point() -> Vector2:
	return origin + Vector2(size.x * 0.5, size.y - WALL - 90.0)

func _rect_node(parent: Node, center: Vector2, rect_size: Vector2, color: Color, z: int = 0) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.size = rect_size
	r.position = center - rect_size * 0.5
	r.z_index = z
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r

func _solid(center: Vector2, rect_size: Vector2, circle: bool = false) -> void:
	var body := StaticBody2D.new()
	body.position = center
	var shape := CollisionShape2D.new()
	if circle:
		var c := CircleShape2D.new()
		c.radius = minf(rect_size.x, rect_size.y) * 0.5
		shape.shape = c
	else:
		var s := RectangleShape2D.new()
		s.size = rect_size
		shape.shape = s
	body.add_child(shape)
	add_child(body)

func _disc(center: Vector2, radius: float, color: Color, z: int = 0) -> void:
	var p := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * float(i) / 20.0
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	p.polygon = pts
	p.color = color
	p.z_index = z
	add_child(p)

func _build_floor() -> void:
	var floor_color: Color = def.floor
	_rect_node(self, size * 0.5, size, floor_color, -10)
	# planks / tiles: faint lines every 44 px
	var y := 0.0
	while y < size.y:
		_rect_node(self, Vector2(size.x * 0.5, y), Vector2(size.x, 2.0), floor_color.darkened(0.25), -9)
		y += 44.0

func _build_walls() -> void:
	var wall_color: Color = def.wall
	var door_half := DOOR_WIDTH * 0.5
	# top, left, right
	_rect_node(self, Vector2(size.x * 0.5, WALL * 0.5), Vector2(size.x, WALL), wall_color, 1)
	_rect_node(self, Vector2(size.x * 0.5, WALL + 14.0), Vector2(size.x - WALL * 2.0, 28.0), wall_color.lightened(0.12), 0)
	_rect_node(self, Vector2(WALL * 0.5, size.y * 0.5), Vector2(WALL, size.y), wall_color, 1)
	_rect_node(self, Vector2(size.x - WALL * 0.5, size.y * 0.5), Vector2(WALL, size.y), wall_color, 1)
	_solid(Vector2(size.x * 0.5, WALL * 0.5), Vector2(size.x, WALL))
	_solid(Vector2(WALL * 0.5, size.y * 0.5), Vector2(WALL, size.y))
	_solid(Vector2(size.x - WALL * 0.5, size.y * 0.5), Vector2(WALL, size.y))
	# bottom wall with a doorway in the middle
	var left_len := size.x * 0.5 - door_half
	for side in [-1.0, 1.0]:
		var cx: float = size.x * 0.5 + side * (door_half + left_len * 0.5)
		_rect_node(self, Vector2(cx, size.y - WALL * 0.5), Vector2(left_len, WALL), wall_color, 1)
		_solid(Vector2(cx, size.y - WALL * 0.5), Vector2(left_len, WALL))
	_rect_node(self, Vector2(size.x * 0.5, size.y - WALL * 0.5), Vector2(DOOR_WIDTH, WALL), Color(0.2, 0.14, 0.1), 0)   # the door mat

func _build_thing(thing: String, at: Vector2) -> void:
	var spec: Array = THINGS.get(thing, [60, 60, Color(0.5, 0.5, 0.5), true])
	var thing_size := Vector2(float(spec[0]), float(spec[1]))
	var color: Color = spec[2]
	var solid: bool = bool(spec[3])
	match thing:
		"barrel", "cauldron", "round_table", "crystal":
			_disc(at, thing_size.x * 0.5, color, 0)
			_disc(at, thing_size.x * 0.32, color.lightened(0.15), 0)
			if solid:
				_solid(at, thing_size, true)
			if thing == "cauldron":
				_disc(at, thing_size.x * 0.3, Color(0.3, 0.8, 0.35), 0)
			if thing == "crystal":
				_disc(at, thing_size.x * 0.7, Color(0.7, 0.4, 1.0, 0.2), -1)
			return
		"brazier":
			_disc(at, thing_size.x * 1.1, Color(1.0, 0.6, 0.2, 0.1), -1)
			_disc(at, thing_size.x * 0.5, color, 0)
			_disc(at, thing_size.x * 0.34, Color(0.95, 0.45, 0.1), 0)
			_disc(at, thing_size.x * 0.18, Color(1.0, 0.85, 0.3), 0)
			if solid:
				_solid(at, thing_size, true)
			return
		"shield_stand":
			_disc(at, thing_size.x * 0.5, color, 0)
			_disc(at, thing_size.x * 0.34, Color(0.65, 0.18, 0.15), 0)
			_disc(at, thing_size.x * 0.12, color.lightened(0.25), 0)
			if solid:
				_solid(at, thing_size, true)
			return
		"ship_wheel":
			_disc(at, thing_size.x * 0.5, color.darkened(0.3), 0)
			_disc(at, thing_size.x * 0.4, color, 0)
			_disc(at, thing_size.x * 0.28, color.darkened(0.45), 0)
			_rect_node(self, at, Vector2(thing_size.x * 1.05, 8.0), color.lightened(0.1), 0)
			_rect_node(self, at, Vector2(8.0, thing_size.y * 1.05), color.lightened(0.1), 0)
			_disc(at, 9.0, Color(0.85, 0.7, 0.3), 0)
			return
		"lantern":
			_disc(at, 30.0, Color(1.0, 0.9, 0.5, 0.16), -1)
			_rect_node(self, at, thing_size, color, 0)
			_rect_node(self, at + Vector2(0, -15), Vector2(20, 5), Color(0.25, 0.2, 0.15), 0)
			return
		"rope_coil":
			_disc(at, thing_size.x * 0.5, color, -8)
			_disc(at, thing_size.x * 0.33, color.darkened(0.3), -8)
			_disc(at, thing_size.x * 0.17, color, -8)
			return
		"anchor":
			_rect_node(self, at, Vector2(10.0, 78.0), color, 0)
			_rect_node(self, at + Vector2(0, -26), Vector2(44.0, 9.0), color, 0)
			_rect_node(self, at + Vector2(-16, 30), Vector2(22.0, 8.0), color, 0)
			_rect_node(self, at + Vector2(16, 30), Vector2(22.0, 8.0), color, 0)
			_disc(at + Vector2(0, -42), 7.0, color.lightened(0.2), 0)
			if solid:
				_solid(at, Vector2(44.0, 84.0))
			return
		"rune_circle":
			_disc(at, thing_size.x * 0.5, color.darkened(0.3), -8)
			_disc(at, thing_size.x * 0.44, color, -8)
			_disc(at, thing_size.x * 0.3, color.darkened(0.3), -8)
			for i in 6:
				var a := TAU * float(i) / 6.0
				_disc(at + Vector2(cos(a), sin(a)) * thing_size.x * 0.37, 12.0, Color(0.8, 0.7, 1.0), -7)
			return
		"rug", "mat", "hay":
			_rect_node(self, at, thing_size, color, -8)
			_rect_node(self, at, thing_size - Vector2(24, 24), color.lightened(0.12), -8)
			return
	_rect_node(self, at, thing_size, color, 0)
	if solid:
		_solid(at, thing_size)
	match thing:
		"shelf", "bookshelf":
			for i in 5:
				var item_color := Color.from_hsv(float(i) / 5.0, 0.5 if thing == "shelf" else 0.7, 0.85)
				_rect_node(self, at + Vector2((float(i) - 2.0) * 38.0, -8.0), Vector2(26, 20), item_color, 0)
		"forge":
			_disc(at + Vector2(0, 6), 28.0, Color(1.0, 0.5, 0.1), 0)
			_disc(at + Vector2(0, 6), 14.0, Color(1.0, 0.85, 0.3), 0)
		"fireplace":
			_disc(at + Vector2(0, 6), 22.0, Color(1.0, 0.5, 0.1), 0)
		"altar":
			_rect_node(self, at + Vector2(0, -30), Vector2(220, 16), Color(0.9, 0.2, 0.25), 0)
		"rack":
			for i in 5:
				_rect_node(self, at + Vector2((float(i) - 2.0) * 32.0, -2.0), Vector2(6, 30), Color(0.75, 0.75, 0.8), 0)
		"bed":
			_rect_node(self, at + Vector2(0, 20), Vector2(96, 110), Color(0.3, 0.4, 0.75), 0)
			_rect_node(self, at + Vector2(0, -60), Vector2(70, 30), Color(0.95, 0.95, 0.9), 0)
		"dummy":
			_rect_node(self, at + Vector2(0, -6), Vector2(30, 38), Color(0.85, 0.75, 0.45), 0)
		"stall":
			_rect_node(self, at + Vector2(0, -50), Vector2(240, 22), Color(0.9, 0.85, 0.7), 0)
		"net":
			for i in 5:
				_rect_node(self, at + Vector2((float(i) - 2.0) * 26.0, 0), Vector2(3, thing_size.y), color.darkened(0.35), 0)
			for j in 4:
				_rect_node(self, at + Vector2(0, (float(j) - 1.5) * 20.0), Vector2(thing_size.x, 3), color.darkened(0.35), 0)
		"fish_rack":
			for i in 3:
				_rect_node(self, at + Vector2((float(i) - 1.0) * 34.0, 24.0), Vector2(11, 28), Color(0.62, 0.76, 0.85), 0)
		"oars":
			_rect_node(self, at + Vector2(-62, 0), Vector2(28, 18), color.lightened(0.15), 0)
			_rect_node(self, at + Vector2(62, 0), Vector2(28, 18), color.lightened(0.15), 0)
		"sea_chest":
			_rect_node(self, at + Vector2(0, -8), Vector2(74, 8), Color(0.85, 0.7, 0.3), 0)
			_rect_node(self, at + Vector2(0, -8), Vector2(10, 14), Color(0.85, 0.7, 0.3), 0)
		"hammock":
			_rect_node(self, at + Vector2(0, 14), Vector2(82, 108), color.darkened(0.15), 0)
			_rect_node(self, at + Vector2(0, -50), Vector2(58, 26), Color(0.95, 0.93, 0.85), 0)
		"banner":
			_rect_node(self, at + Vector2(0, -58), Vector2(66, 8), Color(0.3, 0.2, 0.1), 0)
			_disc(at + Vector2(0, -10), 12.0, Color(0.9, 0.8, 0.3), 0)
		"throne":
			_rect_node(self, at + Vector2(0, -28), Vector2(90, 14), Color(0.22, 0.14, 0.08), 0)
			_rect_node(self, at + Vector2(0, 6), Vector2(60, 36), Color(0.65, 0.15, 0.13), 0)
		"war_table":
			_rect_node(self, at, Vector2(220, 90), Color(0.82, 0.74, 0.55), 0)
			for i in 3:
				_rect_node(self, at + Vector2((float(i) - 1.0) * 70.0, -10.0), Vector2(14, 14), Color(0.65, 0.15, 0.13), 0)
				_rect_node(self, at + Vector2((float(i) - 1.0) * 70.0 + 30.0, 18.0), Vector2(10, 10), Color(0.25, 0.3, 0.2), 0)
		"bunk":
			_rect_node(self, at + Vector2(0, 24), Vector2(84, 110), Color(0.3, 0.42, 0.28), 0)
			_rect_node(self, at + Vector2(0, -62), Vector2(60, 26), Color(0.8, 0.78, 0.65), 0)
		"long_table":
			for i in 5:
				_rect_node(self, at + Vector2((float(i) - 2.0) * 56.0, 0), Vector2(22, 22), Color(0.85, 0.82, 0.7), 0)
		"totem":
			_rect_node(self, at + Vector2(0, -26), Vector2(34, 18), Color(0.85, 0.7, 0.3), 0)
			_rect_node(self, at + Vector2(0, 4), Vector2(34, 18), Color(0.65, 0.15, 0.13), 0)
			_rect_node(self, at + Vector2(0, 32), Vector2(34, 18), Color(0.3, 0.55, 0.3), 0)
		"trough":
			_rect_node(self, at, Vector2(132, 30), Color(0.3, 0.5, 0.7), 0)
		"horse_stall":
			_rect_node(self, at, Vector2(150, 130), Color(0.75, 0.65, 0.35), 0)
			_rect_node(self, at + Vector2(0, -68), Vector2(170, 8), color.darkened(0.3), 0)
			_rect_node(self, at + Vector2(0, 68), Vector2(170, 8), color.darkened(0.3), 0)
			_rect_node(self, at + Vector2(-82, 0), Vector2(8, 150), color.darkened(0.3), 0)
			_rect_node(self, at + Vector2(82, 0), Vector2(8, 150), color.darkened(0.3), 0)
			var horse := Sprite2D.new()
			horse.texture = preload("res://assets/horse.png")
			horse.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			horse.modulate = [Color(0.8, 0.55, 0.35), Color(0.72, 0.72, 0.74), Color(0.55, 0.35, 0.2)][int(at.x + at.y) % 3]
			horse.position = at
			horse.scale = Vector2(4.0, 4.0)
			add_child(horse)
		"hay_bale":
			for i in 3:
				_rect_node(self, at + Vector2((float(i) - 1.0) * 22.0, 0), Vector2(4, thing_size.y), Color(0.5, 0.38, 0.15), 0)
		"saddle_rack":
			_rect_node(self, at + Vector2(-28, 0), Vector2(34, 18), Color(0.45, 0.25, 0.12), 0)
			_rect_node(self, at + Vector2(28, 0), Vector2(34, 18), Color(0.45, 0.25, 0.12), 0)

func _build_npc() -> void:
	if def.has("npc"):
		var npc := Sprite2D.new()
		npc.texture = preload("res://assets/blade_ally.png")
		npc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		npc.modulate = def.npc[2]
		npc.position = Vector2(float(def.npc[0]), float(def.npc[1]))
		npc.scale = Vector2(2.0, 2.0)
		add_child(npc)
	if def.has("counter"):
		var c: Array = def.counter
		_rect_node(self, Vector2(float(c[0]), float(c[1])), Vector2(float(c[2]), 58.0), Color(0.6, 0.42, 0.22), 0)
		_rect_node(self, Vector2(float(c[0]), float(c[1]) - 22.0), Vector2(float(c[2]), 14.0), Color(0.72, 0.52, 0.3), 0)
		_solid(Vector2(float(c[0]), float(c[1])), Vector2(float(c[2]), 58.0))

func _build_triggers() -> void:
	if def.has("trade"):
		var t: Array = def.trade
		_trigger(Vector2(float(t[0]), float(t[1])), Vector2(float(t[2]), float(t[3])), _on_trade)
	_trigger(Vector2(size.x * 0.5, size.y - WALL * 0.5), Vector2(DOOR_WIDTH - 30.0, WALL), _on_exit)

# Coins and meat lying about the room. Pickups live under Main (that is where their sound is played from); they are
# gone once taken, for the run.
func _build_loot() -> void:
	var holder := get_parent()
	if holder == null:
		return
	for l in def.get("loot", []):
		var pickup = PickupScript.new()
		pickup.kind = str(l[0])
		pickup.amount = int(l[1])
		pickup.position = origin + Vector2(float(l[2]), float(l[3]))
		holder.add_child(pickup)

func _trigger(at: Vector2, trigger_size: Vector2, action: Callable) -> void:
	var area := Area2D.new()
	area.position = at
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = trigger_size
	shape.shape = rect_shape
	area.add_child(shape)
	area.body_entered.connect(func(body):
		if body.is_in_group("player"):
			action.call()
	)
	add_child(area)
