extends RefCounted
class_name RoomData

# THE HAND-MADE ROOMS of the overworld. A room listed here is designed on purpose -- its shape, the walls round it,
# its doorways, where every tree stands -- instead of being drawn by the room generator (Rooms.gd / RoomLayout.gd),
# which only fills in the rooms nobody has written yet. Everything is plain data: change a number and the room
# changes.
#
# A room is found by the cell at its top-left corner, "col,row" (the map is 11 x 11 cells; a plain cell is 3,055 x
# 2,164 px). All positions are px from the ROOM'S TOP-LEFT CORNER (x to the right, y down).
#
#   "span":     [cols, rows]            a room that covers more cells (default [1, 1])
#   "name":     what the player sees -- only rooms worth a name get one
#   "mass":     what the solid ground is made of: forest thicket pines dead_forest rock sandstone volcanic
#               crystal_rock water bog ice lava abyss
#   "shape":    the floor, as ops: ["ell", cx, cy, rx, ry] an ellipse    ["disc", cx, cy, r]
#               ["box", cx, cy, hx, hy, rad] a box (half sizes, corners rounded by rad)
#               ["rbox", cx, cy, hx, hy, degrees, rad] the same, turned    ["path", width, x0, y0, x1, y1, ...]
#               a stroke of that width through the points    ["poly", x0, y0, x1, y1, ...] a polygon
#               A leading "-" ("-disc") cuts the shape out of the floor instead of adding it.
#               The doorways (see EDGES) connect themselves to the nearest part of the shape.
#   "decor":    neat arrangements: ["orchard", cx, cy, cols, rows, spacing]  ["bed", cx, cy, cols, rows]
#               ["boulders", cx, cy, cols, rows, spacing]  ["row", item, x0, y0, x1, y1, spacing]
#               ["ring", item, cx, cy, radius, count]  ["pair", item, cx, cy, dx, dy]
#               (item = tall, small, ground or stone: what the country is dressed with). Leave "decor" out and the
#               room gets a few generated stands; put [] for none.
#   "props":    set pieces, [kind, x, y, flavour]: clearing standing_stones farm pond rock_formation camp
#               fallen_logs ruin_walls graves cliff_ridge mouth crystals
#   "enemies":  [[key, weight], ...] who lives there    "target": how many roam there
#
# EDGES: the ways through a shared side of two rooms, from the two cells either side ("4,3|5,3": the left cell
# first, or the top cell first for a vertical pair). A list of [centre, width] in px along the side (y for a left|right
# pair, x for a top|bottom pair, from the cell's own corner), "open" for the whole side, or "closed" for a wall.
# Sides not listed here are decided by the generator.

const ROOMS := {
	# ------------------------------------------------------------------ Central Lexia: the great wood
	# Where you wake: a clearing with the fire you woke by, a broad path out east to the plains, narrow trails north,
	# south and west into the woods.
	"4,3": {
		"name": "Where You Woke",
		"mass": "forest",
		"shape": [
			["ell", 900, 1082, 720, 540],
			["path", 760, 900, 1082, 2300, 1082, 3055, 1082],
			["path", 520, 1900, 1082, 1900, 0],
			["path", 520, 1900, 1082, 1900, 2164],
			["path", 440, 900, 1082, 0, 1082],
		],
		"decor": [
			["ring", "stone", 701, 1082, 230, 8],
			["bed", 700, 820, 5, 3],
			["row", "tall", 1500, 790, 2800, 790, 150],
			["row", "tall", 1500, 1374, 2800, 1374, 150],
		],
	},
	# The Fairy Ring: a round glade at the north-west corner of the map, a dead end ringed with stones.
	"0,0": {
		"name": "The Fairy Ring",
		"mass": "forest",
		"shape": [["ell", 1527, 1082, 1000, 640]],
		"props": [["standing_stones", 1527, 1082]],
		"decor": [["ring", "tall", 1527, 1082, 480, 12], ["ring", "ground", 1527, 1082, 360, 10]],
		"enemies": [["fae_hut", 3], ["gnome_pack", 2], ["wolf", 1]],
		"target": 4,
	},
	# North lane: a path winding east to west with a bulge where it meets the HeartWood's north gate.
	"1,0": {
		"mass": "forest",
		"shape": [["path", 520, 0, 1082, 700, 1000, 1500, 1100, 2300, 950, 3055, 900], ["disc", 1527, 1500, 520]],
		"decor": [["pair", "tall", 700, 1000, 0, 200], ["pair", "tall", 2300, 950, 0, 200], ["bed", 1527, 1500, 5, 2]],
	},
	# The Old Orchard: rows of trees in an oval clearing.
	"2,0": {
		"name": "The Old Orchard",
		"mass": "forest",
		"shape": [["ell", 1527, 1082, 1050, 650]],
		"decor": [["orchard", 1527, 1082, 6, 3, 130]],
		"enemies": [["goblin", 5], ["orc", 1]],
		"target": 4,
	},
	# The plaza before the ruins: a rounded square lined with trees.
	"3,0": {
		"mass": "forest",
		"shape": [["box", 1527, 1082, 1050, 640, 140]],
		"decor": [["row", "tall", 800, 620, 2300, 620, 150], ["row", "tall", 800, 1544, 2300, 1544, 150]],
	},
	# West lane: a path running north to south with a spur east to the HeartWood.
	"0,1": {
		"mass": "forest",
		"shape": [
			["path", 520, 1527, 0, 1300, 700, 1527, 1400, 1300, 2164],
			["path", 620, 1300, 1000, 3055, 1082],
			["disc", 1300, 1000, 520],
		],
		"decor": [["bed", 1300, 1000, 4, 3]],
	},
	# The HeartWood: the great round clearing round the colossal tree.
	"1,1": {
		"name": "The HeartWood",
		"span": [2, 2],
		"mass": "forest",
		"shape": [["disc", 3055, 2163, 1750]],
		"decor": [],
	},
	# East lane: a crossing of paths with a little round plaza at the heart.
	"3,1": {
		"mass": "forest",
		"shape": [
			["path", 560, 1700, 0, 1527, 1082, 1527, 2164],
			["path", 520, 0, 1082, 1527, 1082, 3055, 1000],
			["disc", 1527, 1082, 440],
		],
		"decor": [["pair", "tall", 1617, 520, 200, 0], ["pair", "tall", 1527, 1650, 230, 0]],
	},
	# The woods' edge, north: an oval clearing opening onto the plains.
	"4,1": {
		"mass": "forest",
		"shape": [["ell", 1700, 1082, 1150, 720]],
		"decor": [["orchard", 1900, 1082, 5, 3, 140]],
	},
	# Hunter's Camp: a dead-end alcove off the lane, with a camp in it.
	"0,2": {
		"name": "Hunter's Camp",
		"mass": "forest",
		"shape": [
			["path", 520, 1300, 0, 1700, 1082, 1700, 2164],
			["path", 420, 1700, 1082, 800, 1000],
			["disc", 800, 1000, 420],
		],
		"props": [["camp", 800, 1000]],
		"decor": [],
		"enemies": [["goblin", 3], ["archer", 2], ["wolf", 2]],
		"target": 4,
	},
	# Two round glades joined by a neck.
	"3,2": {
		"mass": "forest",
		"shape": [["ell", 800, 1082, 540, 540], ["ell", 2250, 1082, 540, 540], ["path", 420, 800, 1082, 2250, 1082]],
		"decor": [["ring", "small", 800, 1082, 380, 10], ["ring", "small", 2250, 1082, 380, 10]],
	},
	"4,2": {
		"mass": "forest",
		"shape": [["ell", 1700, 1082, 1100, 800]],
		"decor": [["bed", 1800, 1082, 6, 3]],
	},
	# Two rounded chambers joined by a short passage.
	"0,3": {
		"mass": "forest",
		"shape": [["box", 1000, 1082, 700, 520, 80], ["box", 2300, 1082, 520, 420, 80], ["path", 380, 1000, 1082, 1700, 1082, 2300, 1082]],
		"decor": [["bed", 1000, 1082, 5, 3], ["row", "small", 700, 760, 1300, 760, 60]],
	},
	# South lane: a path with a round bulge at the HeartWood's south gate.
	"1,3": {
		"mass": "forest",
		"shape": [["path", 560, 0, 1082, 1000, 1200, 2100, 950, 3055, 900], ["disc", 1527, 700, 560]],
		"decor": [["bed", 1527, 700, 5, 3]],
	},
	# A ring of floor round a block of boulders.
	"2,3": {
		"mass": "forest",
		"shape": [["box", 1527, 1082, 1300, 700, 100], ["-box", 1527, 1082, 450, 260, 60]],
		"decor": [["boulders", 1527, 600, 3, 1, 130]],
	},
	# A plus-shaped crossing.
	"3,3": {
		"mass": "forest",
		"shape": [["box", 1527, 1082, 1300, 420, 60], ["box", 1527, 1082, 420, 900, 60]],
		"decor": [["ring", "small", 1527, 1082, 260, 8]],
	},
	# The Wolf Den: a ring of floor round a rock-strewn mound.
	"0,4": {
		"name": "The Wolf Den",
		"mass": "forest",
		"shape": [["ell", 1527, 1082, 1100, 720], ["-ell", 1527, 1082, 520, 300]],
		"props": [["rock_formation", 1527, 1082], ["fallen_logs", 700, 1082]],
		"decor": [],
		"enemies": [["wolf", 8], ["goblin", 1]],
		"target": 6,
	},
	# A mossy hollow: a round clearing with a bed of flowers inside a ring of trees.
	"1,4": {
		"mass": "forest",
		"shape": [["ell", 1527, 1082, 900, 640]],
		"decor": [["bed", 1527, 1082, 6, 3], ["ring", "tall", 1527, 1082, 520, 14]],
	},
	# Fallen giants: a lane with a clearing where the great logs lie.
	"2,4": {
		"mass": "forest",
		"shape": [["path", 620, 0, 1100, 1000, 1000, 2000, 1200, 3055, 1000], ["disc", 1527, 1100, 520]],
		"props": [["fallen_logs", 1527, 1100]],
		"decor": [],
	},
	# Two boxes at an angle: an L-shaped room.
	"3,4": {
		"mass": "forest",
		"shape": [["box", 1000, 1082, 900, 450, 80], ["box", 2100, 1300, 500, 700, 80]],
		"decor": [["row", "small", 700, 800, 1300, 800, 60]],
	},
	# The woods' edge, south.
	"4,4": {
		"mass": "forest",
		"shape": [["ell", 1700, 1082, 1100, 760]],
		"decor": [["row", "small", 1000, 700, 2400, 700, 100]],
	},
	# ------------------------------------------------------------------ The Great Expanse: the plains round the town
	# Wide open country: nearly every plains room is full floor with its own obstacles cut out of it -- a pond, a hill, a
	# hedgerow -- and most of its sides open wide onto the next room. Dirt roads (ROADS) run out of the town's four
	# gates; avenues of trees line them.
	# The Windswept Rise: a tall meadow with a hill either side of the north road.
	"5,1": {
		"name": "The Windswept Rise",
		"span": [1, 2],
		"mass": "rock",
		"shape": [["box", 1527, 2163, 1450, 2000, 0], ["-ell", 700, 1500, 520, 700], ["-ell", 2350, 2900, 480, 620]],
		"decor": [["row", "tall", 1307, 350, 1307, 3950, 220], ["row", "tall", 1747, 350, 1747, 3950, 220]],
		"enemies": [["goblin", 5], ["orc", 2], ["archer", 1]],
		"target": 4,
	},
	# The Crossroads: the road north to the ruins meets the road from where you woke and the road down to the town; a
	# thicket fills each corner.
	"5,3": {
		"name": "The Crossroads",
		"mass": "thicket",
		"shape": [["box", 1527, 1082, 1450, 1000, 0], ["-box", 560, 420, 330, 200, 60], ["-box", 2500, 420, 330, 200, 60], ["-box", 560, 1740, 330, 200, 60], ["-box", 2500, 1740, 330, 200, 60]],
		"decor": [
			["ring", "stone", 1527, 1082, 230, 8],
			["pair", "tall", 1527, 420, 260, 0], ["pair", "tall", 1527, 1750, 260, 0],
			["pair", "tall", 420, 1082, 0, 260], ["pair", "tall", 2650, 1082, 0, 260],
		],
		"target": 3,
	},
	# The road to the town's north gate, between two ponds.
	"5,4": {
		"mass": "water",
		"shape": [["box", 1527, 1082, 1450, 1000, 0], ["-ell", 640, 1082, 330, 520], ["-ell", 2420, 1082, 330, 520]],
		"decor": [["row", "tall", 1307, 350, 1307, 1800, 220], ["row", "tall", 1747, 350, 1747, 1800, 220]],
		"target": 2,
	},
	# East of the town: fields divided by hedgerows, the east road crossing the lower one.
	"6,4": {
		"span": [1, 2],
		"mass": "thicket",
		"shape": [
			["box", 1527, 2163, 1450, 2000, 0],
			["-path", 110, 300, 1650, 1200, 1650], ["-path", 110, 1850, 1650, 2750, 1650],
			["-path", 110, 800, 2400, 800, 2950], ["-path", 110, 800, 3550, 800, 3950],
		],
		"decor": [["bed", 1500, 900, 8, 5], ["bed", 2300, 900, 8, 5], ["orchard", 2200, 2300, 5, 2, 140], ["bed", 1700, 3750, 8, 4]],
		"target": 4,
	},
	# Pastures: a hedged paddock beside the east road.
	"7,5": {
		"span": [1, 2],
		"mass": "thicket",
		"shape": [
			["box", 1527, 2163, 1450, 2000, 0],
			["-path", 110, 500, 1900, 1500, 1900], ["-path", 110, 1500, 1900, 1500, 2700], ["-path", 110, 1500, 2700, 500, 2700], ["-path", 110, 500, 2700, 500, 2100],
		],
		"decor": [["boulders", 1000, 2300, 3, 2, 150], ["row", "small", 1800, 500, 2700, 500, 70], ["row", "small", 1800, 1700, 2700, 1700, 70]],
		"enemies": [["centaur_pack", 2], ["goblin", 3], ["orc", 2]],
		"target": 4,
	},
	# The Stone Fields: two meadows with a ring of standing stones in each, between hills.
	"7,7": {
		"name": "The Stone Fields",
		"span": [1, 2],
		"mass": "rock",
		"shape": [["box", 1527, 2163, 1450, 2000, 0], ["-ell", 600, 3300, 420, 520], ["-ell", 2450, 2000, 380, 560], ["-ell", 2400, 3600, 300, 300]],
		"props": [["standing_stones", 1527, 1100], ["standing_stones", 1527, 3000]],
		"decor": [],
		"target": 4,
	},
	# Dry plain at the foot of the mountains: a crescent of rock.
	"8,4": {
		"mass": "rock",
		"shape": [["box", 1527, 1082, 1450, 1000, 0], ["-ell", 1900, 800, 520, 380]],
		"decor": [["boulders", 800, 1500, 3, 2, 150]],
		"target": 3,
	},
	# The foothills: the east road climbing between outcrops towards the caves.
	"8,5": {
		"span": [1, 2],
		"mass": "rock",
		"shape": [["box", 1527, 2163, 1450, 2000, 0], ["-ell", 1000, 2600, 520, 600], ["-ell", 2300, 1900, 420, 400], ["-ell", 2300, 3600, 420, 380]],
		"decor": [["row", "stone", 500, 740, 2500, 740, 260], ["row", "stone", 500, 1424, 2500, 1424, 260]],
		"enemies": [["brute", 3], ["orc", 3], ["centaur_pack", 1]],
		"target": 4,
	},
	"8,7": {
		"mass": "rock",
		"shape": [["box", 1527, 1082, 1450, 1000, 0], ["-disc", 1100, 1082, 330], ["-disc", 2000, 1082, 250]],
		"decor": [["boulders", 1527, 500, 4, 1, 130]],
		"enemies": [["orc", 3], ["brute", 2]],
		"target": 3,
	},
	# West of the town: fields and hedgerows, an avenue of trees along the west road.
	"4,5": {
		"span": [1, 2],
		"mass": "thicket",
		"shape": [
			["box", 1527, 2163, 1450, 2000, 0],
			["-path", 110, 300, 2400, 1400, 2400], ["-path", 110, 1900, 2400, 2750, 2400], ["-path", 110, 1000, 3000, 1000, 3900],
		],
		"decor": [["row", "tall", 300, 852, 2700, 852, 220], ["row", "tall", 300, 1312, 2700, 1312, 220], ["bed", 1800, 3100, 8, 6], ["bed", 2300, 3700, 8, 4]],
		"target": 3,
	},
	# The road to the town's south gate: a causeway between two ponds.
	"5,6": {
		"mass": "water",
		"shape": [["box", 1527, 1082, 1450, 1000, 0], ["-ell", 640, 1300, 330, 560], ["-ell", 2420, 900, 330, 560]],
		"decor": [["row", "tall", 1307, 350, 1307, 1800, 220], ["row", "tall", 1747, 350, 1747, 1800, 220]],
		"target": 2,
	},
	# The lakeshore: a long room along the west road with a lake either side of it.
	"2,5": {
		"span": [2, 1],
		"mass": "water",
		"shape": [["box", 3055, 1082, 2900, 1000, 0], ["-ell", 1800, 520, 800, 300], ["-ell", 4300, 1700, 700, 260], ["-ell", 5200, 520, 360, 200]],
		"decor": [["row", "tall", 300, 1304, 5800, 1304, 240]],
		"target": 5,
	},
	"3,6": {
		"mass": "thicket",
		"shape": [["box", 1527, 1082, 1450, 1000, 0], ["-path", 110, 500, 500, 500, 1600], ["-path", 110, 500, 1600, 1400, 1600]],
		"decor": [["bed", 1800, 800, 7, 4]],
		"target": 3,
	},
	"3,7": {
		"mass": "water",
		"shape": [["box", 1527, 1082, 1450, 1000, 0], ["-ell", 1527, 1082, 520, 330]],
		"decor": [["row", "tall", 800, 500, 2250, 500, 200], ["row", "tall", 800, 1664, 2250, 1664, 200]],
		"target": 3,
	},
	# The southern farms: farm plots divided by hedgerows, the south road through the eastern half.
	"4,7": {
		"span": [2, 1],
		"mass": "thicket",
		"shape": [
			["box", 3055, 1082, 2900, 1000, 0],
			["-path", 110, 2200, 300, 2200, 900], ["-path", 110, 2200, 1300, 2200, 1850], ["-path", 110, 800, 1500, 1800, 1500],
		],
		"props": [["farm", 1100, 800]],
		"decor": [["bed", 3300, 700, 8, 5], ["bed", 3300, 1500, 8, 5], ["bed", 5300, 700, 8, 5], ["bed", 5300, 1500, 8, 5]],
		"enemies": [["goblin", 6], ["orc", 2]],
		"target": 5,
	},
	"4,8": {
		"mass": "thicket",
		"shape": [["box", 1527, 1082, 1450, 1000, 0], ["-ell", 900, 1400, 420, 300], ["-ell", 2150, 800, 420, 300]],
		"decor": [["bed", 1500, 1082, 6, 3]],
		"target": 3,
	},
	"5,8": {
		"mass": "thicket",
		"shape": [["box", 1527, 1082, 1450, 1000, 0], ["-ell", 640, 1082, 330, 520], ["-ell", 2420, 1082, 330, 520]],
		"decor": [["row", "tall", 1307, 350, 1307, 1800, 220], ["row", "tall", 1747, 350, 1747, 1800, 220]],
		"target": 3,
	},
	# South of the ranch: fields and hedgerows.
	"6,7": {
		"span": [1, 2],
		"mass": "thicket",
		"shape": [["box", 1527, 2163, 1450, 2000, 0], ["-path", 110, 300, 1500, 1100, 1500], ["-path", 110, 1950, 1500, 2750, 1500], ["-path", 110, 1000, 2500, 1000, 3500]],
		"decor": [["bed", 1900, 900, 8, 5], ["orchard", 2100, 3100, 5, 3, 140]],
		"target": 4,
	},
}

const EDGES := {
	# --- left | right pairs: [centre y, width]
	"0,0|1,0": [[1082, 560]],
	"1,0|2,0": [[900, 520]],
	"2,0|3,0": [[1200, 520]],
	"3,0|4,0": [[1082, 720]],
	"0,1|1,1": [[1082, 900]],
	"0,2|1,2": "closed",
	"2,1|3,1": [[1082, 700]],
	"2,2|3,2": [[1100, 520]],
	"3,1|4,1": [[1000, 600]],
	"3,2|4,2": [[1100, 560]],
	"4,1|5,1": "open",
	"4,2|5,2": "open",
	"4,3|5,3": "open",
	"4,4|5,4": "open",
	"0,3|1,3": [[1082, 560]],
	"1,3|2,3": [[950, 520]],
	"2,3|3,3": [[900, 520]],
	"3,3|4,3": [[1082, 480]],
	"0,4|1,4": [[1082, 520]],
	"1,4|2,4": [[1100, 520]],
	"2,4|3,4": [[1000, 520]],
	"3,4|4,4": [[1082, 520]],
	# --- top | bottom pairs: [centre x, width]
	"0,0|0,1": [[1527, 560]],
	"1,0|1,1": [[1527, 800]],
	"2,0|2,1": [[1527, 800]],
	"3,0|3,1": [[1700, 560]],
	"4,0|4,1": [[1500, 700]],
	"5,0|5,1": "open",
	"0,1|0,2": [[1300, 520]],
	"3,1|3,2": [[1527, 520]],
	"4,1|4,2": "open",
	"0,2|0,3": [[1700, 520]],
	"1,2|1,3": [[1527, 800]],
	"2,2|2,3": [[1527, 800]],
	"3,2|3,3": [[1400, 520]],
	"4,2|4,3": [[1900, 520]],
	"0,3|0,4": [[1300, 520]],
	"1,3|1,4": [[1700, 520]],
	"2,3|2,4": [[1300, 520]],
	"3,3|3,4": [[1527, 520]],
	"4,3|4,4": [[1900, 520]],
	"0,4|0,5": [[1500, 700]],
	"1,4|1,5": "open",
	"2,4|2,5": "open",
	"3,4|3,5": "open",
	"4,4|4,5": "open",
	# --- The Great Expanse: wide open between its own rooms, narrow passes to the hills, mountains and the void
	"5,2|6,2": [[1000, 560]],
	"5,3|6,3": [[1082, 560]],
	"5,4|6,4": "open",
	"6,4|7,4": [[1082, 560]],
	"6,5|7,5": "open",
	"7,5|8,5": "open",
	"7,6|8,6": "open",
	"7,7|8,7": "open",
	"7,8|8,8": [[1082, 520]],
	"8,4|9,4": [[1082, 560]],
	"8,5|9,5": [[1082, 900]],
	"8,6|9,6": [[1082, 520]],
	"8,7|9,7": "closed",
	"6,7|7,7": "open",
	"6,8|7,8": "open",
	"5,7|6,7": "open",
	"5,8|6,8": "open",
	"3,5|4,5": "open",
	"3,6|4,6": "open",
	"3,7|4,7": "open",
	"3,8|4,8": [[1082, 520]],
	"1,5|2,5": [[1082, 900]],
	"4,6|5,6": "open",
	"4,8|5,8": "open",
	"2,6|3,6": [[1082, 520]],
	"2,7|3,7": [[1082, 520]],
	"5,2|5,3": "open",
	"5,3|5,4": "open",
	"6,3|6,4": [[1527, 520]],
	"7,4|7,5": [[1527, 520]],
	"7,6|7,7": "open",
	"7,8|7,9": "closed",
	"8,3|8,4": [[1527, 520]],
	"8,4|8,5": "open",
	"8,6|8,7": "open",
	"8,7|8,8": [[1527, 520]],
	"4,6|4,7": "open",
	"4,8|4,9": [[1527, 520]],
	"5,6|5,7": "open",
	"5,7|5,8": "open",
	"5,8|5,9": [[1527, 700]],
	"6,8|6,9": [[1527, 520]],
	"3,5|3,6": "open",
	"2,5|2,6": [[1527, 520]],
	"3,6|3,7": "open",
	"3,7|3,8": [[1527, 520]],
}

# ROADS: dirt roads drawn on the ground, from the town's four gates out across the land. Each is a stroke of `width`
# px through points given in CELL units: (5.5, 5.5) is the middle of the cell at column 5, row 5, so a road that runs
# straight across a room's middle crosses its doorways dead centre. They show only where they cross ground you can
# stand on.
const ROADS := [
	{"width": 90.0, "points": [[4.23, 3.5], [5.5, 3.5]]},                                                    # from where you woke to the crossroads
	{"width": 90.0, "points": [[5.5, 5.2], [5.5, 3.5], [5.5, 2.5], [5.5, 1.0], [5.2, 0.7], [5.0, 0.55]]},     # the north road: town, crossroads, the ruins
	{"width": 90.0, "points": [[5.8, 5.5], [6.5, 5.5], [7.5, 5.5], [8.5, 5.5], [9.2, 5.5]]},                  # the east road, up to the mountains
	{"width": 90.0, "points": [[5.5, 5.8], [5.5, 6.5], [5.5, 7.5], [5.5, 8.5], [5.5, 9.1]]},                  # the south road
	{"width": 90.0, "points": [[5.2, 5.5], [4.5, 5.5], [3.5, 5.5], [2.5, 5.5], [1.5, 5.5], [0.7, 5.5]]},      # the west road, to the Lizen
	{"width": 70.0, "points": [[6.5, 5.5], [6.5, 6.5]]},                                                     # the lane down to the ranch
]
