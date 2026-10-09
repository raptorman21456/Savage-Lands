extends RefCounted
class_name WorldMap

# The overworld's geography: one big continent of regions you can walk between, instead of one arena whose
# biome was swapped every ten waves. Pure data and geometry (nothing here touches the scene), so it can be
# tested on its own -- Main.gd draws it, spawns enemies from it and asks it where you are.
#
# THE LAYOUT (the user's description, 2026-10-09; the desert/mountain swap is theirs too):
#   * The Great Expanse -- wide plains filling the middle. The castle town sits dead centre, a ranch on its outskirts.
#   * Top left: Central Lexia, a massive wood. You spawn on its inner edge; the HeartWood, a massive tree, stands
#     at its heart. East of the woods, top-centre: a ruined settlement where everyone is dead.
#   * Below the woods, far left: the fortified Lizen Encampment; below that the Toxic Mire (swamp); below THAT,
#     covering the bottom-left corner, an ocean ringed with beaches and the dock town of Pesca on a headland.
#   * Along the very bottom: the Frozen Wastes (tundra). Bottom right corner: the Voidlands.
#   * Top right: a massive volcano ringed by rocky hills. East of it, Arahas Desert. Down the east side below the
#     desert: the mountains with their caves and outcroppings -- their southern half swallowed by the Voidlands.
#
# EVERYTHING numeric here -- sizes, danger tiers, which enemies live where -- is a DRAFT for the user to tune.
#
# Regions are listed in PAINT ORDER (first = bottom layer); where two overlap, the later one wins, both on screen
# and in region_at(). That is how the Voidlands swallow the mountains and the volcano's rings nest.

# 7x the old 4800x3400 map in each direction.
const SIZE := Vector2(33600, 23800)
const MAP_SEED := 20261009
# Region borders are wobbled so coasts and treelines look natural rather than ruled: the edge is cut into
# EDGE_STEP pieces and each corner is pushed up to EDGE_JITTER sideways.
const EDGE_JITTER := 420.0
const EDGE_STEP := 560.0

# Where the player wakes: the inner edge of the woods, toward the middle of the map.
const SPAWN_N := Vector2(0.372, 0.352)

# How hard each danger tier hits. Multiplies enemy HP and damage on top of the usual level scaling
# (Main.gd:_setup_battle_grid). Index = tier (0 unused). A DRAFT.
const TIER_POWER := [1.0, 1.0, 1.25, 1.55, 1.9, 2.35, 2.9, 3.5, 4.2]

# Cached build (see ensure_built).
static var regions: Array = []
static var landmarks: Array = []
static var _by_id: Dictionary = {}
static var _landmark_by_id: Dictionary = {}
static var _blocked_cache: Array = []
static var _built := false

# --- building the map ----------------------------------------------------------------------

static func ensure_built() -> void:
	if _built:
		return
	_built = true
	var noise := FastNoiseLite.new()
	noise.seed = MAP_SEED
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.00045

	# The woods first: the edge band around it is the woods grown outward.
	var woods_poly: PackedVector2Array = _wobble(_poly_n([
		Vector2(0, 0), Vector2(0.37, 0), Vector2(0.385, 0.10), Vector2(0.365, 0.22), Vector2(0.345, 0.31),
		Vector2(0.30, 0.385), Vector2(0.21, 0.42), Vector2(0.10, 0.415), Vector2(0, 0.40)]), noise, 1.0)
	var woods_edge_poly: PackedVector2Array = _largest(Geometry2D.offset_polygon(woods_poly, 1800.0, Geometry2D.JOIN_ROUND))
	woods_edge_poly = _clamp_to_map(woods_edge_poly)

	var list: Array = []
	list.append(_region("great_expanse", "The Great Expanse", _rect_n(0, 0, 1, 1), "grass", Color(1, 1, 1), 1, "plains", true, "plains",
		[["goblin", 6], ["orc", 2], ["archer", 1], ["centaur_pack", 1]], false))
	list.append(_region("woods_edge", "Central Lexia", woods_edge_poly, "grass", Color(0.8, 0.95, 0.78), 1, "forest", true, "woods_edge",
		[["goblin", 5], ["wolf", 2], ["gnome_pack", 1], ["orc", 1]], false))
	list.append(_region("woods", "Central Lexia", woods_poly, "grass", Color(0.62, 0.85, 0.62), 2, "forest", true, "woods",
		[["wolf", 4], ["goblin", 3], ["fae_hut", 1], ["gnome_pack", 2], ["archer", 1]], false))
	list.append(_region("heartwood_grove", "The HeartWood", _wobble(_circle_n(Vector2(0.17, 0.18), 3300.0), noise, 0.7), "grass", Color(0.5, 0.78, 0.55), 3, "forest", true, "heartwood",
		[["wolf", 4], ["fae_hut", 2], ["gnome_pack", 2], ["brute", 1]], false, "treant"))
	list.append(_region("ruins", "The Ruined Settlement", _wobble(_circle_n(Vector2(0.45, 0.085), 2300.0), noise, 0.8), "grass", Color(0.72, 0.74, 0.66), 2, "plains", true, "ruins",
		[["shade", 3], ["orc", 2], ["goblin", 2]], false))
	list.append(_region("desert", "Arahas Desert", _wobble(_poly_n([
		Vector2(0.835, 0.05), Vector2(1, 0), Vector2(1, 0.395), Vector2(0.90, 0.375), Vector2(0.835, 0.34), Vector2(0.81, 0.20)]), noise, 1.0),
		"sand", Color(1.3, 1.05, 0.7), 4, "desert", true, "desert",
		[["centaur_pack", 2], ["orc", 3], ["brute", 2], ["archer", 1]], false, "iron_construct"))
	list.append(_region("volcano_hills", "Death Mountain", _wobble(_circle_n(Vector2(0.69, 0.17), 5500.0), noise, 1.0), "rock", Color(0.85, 0.8, 0.78), 5, "mountains", true, "hills",
		[["brute", 3], ["orc", 3], ["centaur_pack", 1], ["shade", 1]], false))
	list.append(_region("volcano_slopes", "Death Mountain", _wobble(_circle_n(Vector2(0.69, 0.17), 3600.0), noise, 1.0), "ash", Color(1.15, 0.8, 0.7), 6, "volcano", true, "volcano",
		[["brute", 3], ["shade", 3], ["archer", 1]], false, "lava_construct"))
	list.append(_region("crater", "The Crater", _wobble(_circle_n(Vector2(0.69, 0.17), 1600.0), noise, 0.8), "ash", Color(1.35, 0.55, 0.4), 7, "volcano", true, "crater",
		[["shade", 3], ["brute", 2]], false))
	list.append(_region("mountains", "Lexian Peaks", _wobble(_poly_n([
		Vector2(0.835, 0.40), Vector2(0.90, 0.37), Vector2(1, 0.38), Vector2(1, 0.78), Vector2(0.90, 0.72), Vector2(0.84, 0.62), Vector2(0.80, 0.50)]), noise, 1.0),
		"rock", Color(0.8, 0.78, 0.75), 5, "mountains", true, "mountains",
		[["brute", 3], ["orc", 3], ["centaur_pack", 1], ["archer", 1]], false, "iron_construct"))
	list.append(_region("lizen", "The Lizen Encampment", _wobble(_poly_n([
		Vector2(0, 0.455), Vector2(0.115, 0.45), Vector2(0.125, 0.52), Vector2(0.11, 0.565), Vector2(0, 0.57)]), noise, 0.8),
		"rock", Color(0.78, 0.7, 0.58), 3, "plains", true, "lizen",
		[["orc", 4], ["brute", 2], ["archer", 2], ["goblin", 2]], false))
	list.append(_region("swamp", "The Toxic Mire", _wobble(_poly_n([
		Vector2(0, 0.575), Vector2(0.12, 0.57), Vector2(0.21, 0.555), Vector2(0.255, 0.60), Vector2(0.265, 0.68), Vector2(0.235, 0.735),
		Vector2(0.10, 0.745), Vector2(0, 0.74)]), noise, 1.0),
		"swamp", Color(0.75, 0.85, 0.65), 3, "swamp", true, "swamp",
		[["fae_hut", 2], ["shade", 3], ["gnome_pack", 2], ["wolf", 2]], false, "black_dragonlet"))
	list.append(_region("beach", "Sandy Shores", _wobble(_poly_n([
		Vector2(0, 0.725), Vector2(0.12, 0.735), Vector2(0.235, 0.715), Vector2(0.285, 0.74), Vector2(0.36, 0.79), Vector2(0.435, 0.88),
		Vector2(0.465, 0.97), Vector2(0.47, 1.0), Vector2(0, 1.0)]), noise, 1.0),
		"sand", Color(1.15, 1.1, 0.85), 2, "beach", true, "beach",
		[["goblin", 4], ["orc", 2], ["archer", 2], ["gnome_pack", 1]], false))
	list.append(_region("ocean", "The Ocean", _wobble(_poly_n([
		Vector2(0, 0.775), Vector2(0.12, 0.78), Vector2(0.225, 0.76), Vector2(0.27, 0.785), Vector2(0.335, 0.83), Vector2(0.395, 0.90),
		Vector2(0.425, 0.97), Vector2(0.43, 1.0), Vector2(0, 1.0)]), noise, 1.0),
		"water", Color(0.8, 0.9, 1.0), 3, "beach", false, "ocean", [], false))
	list.append(_region("pesca", "Pesca", _wobble(_poly_n([
		Vector2(0.245, 0.735), Vector2(0.29, 0.75), Vector2(0.305, 0.80), Vector2(0.29, 0.84), Vector2(0.245, 0.885), Vector2(0.20, 0.90),
		Vector2(0.185, 0.875), Vector2(0.215, 0.835), Vector2(0.232, 0.79)]), noise, 0.35),
		"sand", Color(1.1, 1.05, 0.9), 1, "beach", true, "pesca", [], false))
	list.append(_region("frozen_wastes", "The Frozen Wastes", _wobble(_poly_n([
		Vector2(0.43, 1.0), Vector2(0.44, 0.90), Vector2(0.47, 0.845), Vector2(0.55, 0.815), Vector2(0.64, 0.83), Vector2(0.69, 0.88), Vector2(0.67, 1.0)]), noise, 1.0),
		"snow", Color(0.85, 0.95, 1.2), 5, "tundra", true, "frozen",
		[["wolf", 4], ["brute", 3], ["shade", 2], ["archer", 1]], false, "black_dragonlet"))
	list.append(_region("voidlands", "The Voidlands", _wobble(_poly_n([
		Vector2(0.665, 1.0), Vector2(0.67, 0.92), Vector2(0.675, 0.83), Vector2(0.72, 0.755), Vector2(0.80, 0.69), Vector2(0.90, 0.665), Vector2(1, 0.66), Vector2(1, 1.0)]), noise, 1.0),
		"void", Color(0.6, 0.55, 0.85), 8, "voidlands", true, "void",
		[["shade", 4], ["archer", 2], ["brute", 2], ["centaur_pack", 1]], false, "voidwing"))
	list.append(_region("ranch", "The Ranch", _wobble(_circle_n(Vector2(0.585, 0.585), 1500.0), noise, 0.4), "grass", Color(0.95, 1.05, 0.85), 1, "plains", true, "ranch", [], false))
	regions = list

	_by_id.clear()
	for r in regions:
		_by_id[r.id] = r

	landmarks = [
		_landmark("spawn", "Where you woke", "spawn", SPAWN_N, 220.0),
		_landmark("town", "The Castle Town", "town", Vector2(0.5, 0.5), 900.0),
		_landmark("ranch", "The Ranch", "ranch", Vector2(0.585, 0.585), 900.0),
		_landmark("heartwood", "The HeartWood", "boss", Vector2(0.17, 0.18), 700.0, "elder_oak"),
		_landmark("ruins", "The Ruined Settlement", "ruins", Vector2(0.45, 0.085), 700.0),
		_landmark("lizen_encampment", "The Lizen Encampment", "boss", Vector2(0.055, 0.51), 700.0, "lizen_warband"),
		_landmark("pesca", "Pesca", "town", Vector2(0.222, 0.86), 600.0),
		_landmark("leviathan_shore", "Leviathan's Shore", "boss", Vector2(0.395, 0.915), 700.0, "leviathan"),
		_landmark("frozen_spire", "The White Spire", "boss", Vector2(0.55, 0.935), 700.0, "white_dragon"),
		_landmark("crater", "The Crater", "boss", Vector2(0.69, 0.17), 700.0, "red_wyrm"),
		_landmark("void_throne", "The Void Throne", "boss", Vector2(0.86, 0.84), 700.0, "archmage"),
		_landmark("caves", "The Caves", "cave", Vector2(0.93, 0.55), 500.0),
	]
	_landmark_by_id.clear()
	for l in landmarks:
		_landmark_by_id[l.id] = l

	# The blocked ground (deep water): its outline with any later walkable region (the Pesca headland) cut out, so
	# the dock town stands on solid ground in the middle of the sea.
	_blocked_cache = []
	for i in regions.size():
		var r: Dictionary = regions[i]
		if r.walkable:
			continue
		var pieces: Array = [r.polygon]
		for j in range(i + 1, regions.size()):
			var later: Dictionary = regions[j]
			if not later.walkable or not later.bounds.intersects(r.bounds):
				continue
			var next_pieces: Array = []
			for piece in pieces:
				var cut: Array = Geometry2D.clip_polygons(piece, later.polygon)
				for c in cut:
					if not Geometry2D.is_polygon_clockwise(c):
						next_pieces.append(c)
			pieces = next_pieces
		for piece in pieces:
			_blocked_cache.append(piece)

# --- queries -----------------------------------------------------------------------------------

static func region(id: String) -> Dictionary:
	ensure_built()
	return _by_id.get(id, {})

# The topmost region under a point (the Great Expanse underlies everything).
static func region_at(pos: Vector2) -> Dictionary:
	ensure_built()
	for i in range(regions.size() - 1, -1, -1):
		var r: Dictionary = regions[i]
		if r.bounds.has_point(pos) and Geometry2D.is_point_in_polygon(pos, r.polygon):
			return r
	return regions[0]

static func is_blocked(pos: Vector2) -> bool:
	return not region_at(pos).walkable

static func landmark(id: String) -> Dictionary:
	ensure_built()
	return _landmark_by_id.get(id, {})

static func landmarks_of_kind(kind: String) -> Array:
	ensure_built()
	return landmarks.filter(func(l): return l.kind == kind)

static func spawn_position() -> Vector2:
	return SPAWN_N * SIZE

# Polygons the player and enemies cannot cross (deep water).
static func blocked_polygons() -> Array:
	ensure_built()
	return _blocked_cache

static func tier_power(tier: int) -> float:
	return float(TIER_POWER[clampi(tier, 1, TIER_POWER.size() - 1)])

# --- authoring helpers -------------------------------------------------------------------------

static func _region(id: String, region_name: String, polygon: PackedVector2Array, ground: String, tint: Color, tier: int, world: String, walkable: bool, decor: String, enemies: Array, feather: bool, miniboss: String = "") -> Dictionary:
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for p in polygon:
		bounds = bounds.expand(p)
	return {
		"id": id, "name": region_name, "polygon": polygon, "bounds": bounds, "ground": ground, "tint": tint,
		"tier": tier, "world": world, "walkable": walkable, "decor": decor, "enemies": enemies,
		"feather": feather, "miniboss": miniboss,
	}

static func _landmark(id: String, landmark_name: String, kind: String, pos_n: Vector2, radius: float, boss: String = "") -> Dictionary:
	return {"id": id, "name": landmark_name, "kind": kind, "pos": pos_n * SIZE, "radius": radius, "boss": boss}

static func _poly_n(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(Vector2(p.x * SIZE.x, p.y * SIZE.y))
	return out

static func _rect_n(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return _poly_n([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])

static func _circle_n(center_n: Vector2, radius_px: float, count: int = 24) -> PackedVector2Array:
	var out := PackedVector2Array()
	var center := center_n * SIZE
	for i in count:
		var a := TAU * float(i) / float(count)
		out.append(center + Vector2(cos(a), sin(a)) * radius_px)
	return out

static func _largest(polys: Array) -> PackedVector2Array:
	var best := PackedVector2Array()
	var best_area := -1.0
	for p in polys:
		var a := absf(_area(p))
		if a > best_area:
			best_area = a
			best = p
	return best

static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var p: Vector2 = poly[i]
		var q: Vector2 = poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5

static func _clamp_to_map(poly: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly:
		out.append(Vector2(clampf(p.x, 0.0, SIZE.x), clampf(p.y, 0.0, SIZE.y)))
	return out

# Cuts every edge into EDGE_STEP pieces and pushes each corner sideways by noise (up to EDGE_JITTER x `amount`)
# so borders wander like real coasts and treelines. Corners on the map's own edge stay put.
static func _wobble(poly: PackedVector2Array, noise: FastNoiseLite, amount: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := poly.size()
	for i in n:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		var steps := maxi(1, int(ceil(a.distance_to(b) / EDGE_STEP)))
		var edge: Vector2 = (b - a)
		var normal := Vector2(-edge.y, edge.x).normalized()
		var rim := _on_map_border(a, b)
		for s in steps:
			var p := a.lerp(b, float(s) / float(steps))
			if not rim:
				p += normal * noise.get_noise_2d(p.x, p.y) * EDGE_JITTER * amount
			out.append(Vector2(clampf(p.x, 0.0, SIZE.x), clampf(p.y, 0.0, SIZE.y)))
	return out

# An edge lying along the rim of the map (both ends on the same border).
static func _on_map_border(a: Vector2, b: Vector2) -> bool:
	return (is_zero_approx(a.x) and is_zero_approx(b.x)) or (is_equal_approx(a.x, SIZE.x) and is_equal_approx(b.x, SIZE.x)) \
		or (is_zero_approx(a.y) and is_zero_approx(b.y)) or (is_equal_approx(a.y, SIZE.y) and is_equal_approx(b.y, SIZE.y))
