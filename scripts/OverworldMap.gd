extends Node2D
class_name OverworldMap

# Draws WorldMap.gd's geography as the overworld: every region painted as a textured polygon (soft-edged where it
# meets its neighbours), deep water that actually blocks you, the landmark structures, and the scenery -- trees,
# rocks, cacti and so on -- streamed in chunk by chunk around the player so a 33,600 x 23,800 map never has to
# hold all of it at once. Scenery is generated from the chunk's coordinates, so leaving and coming back always
# shows the same trees.
#
# The landmark structures (the HeartWood, the Lizen palisade, Pesca's docks...) are PLACEHOLDERS built from
# simple shapes and the existing sprites, until the user's own art replaces them.

const WorldMapScript := preload("res://scripts/WorldMap.gd")

const CHUNK := 1024.0
const CHUNK_RADIUS := 2               # chunks kept alive on each side of the player's chunk
const CANDIDATES_PER_CHUNK := 90
const MIN_SPACING := 70.0
const DECO_SCALE := 2.5
const PLAYER_CLEARANCE := 260.0       # nothing is dropped right on the spawn
# A feathered edge: the region's own ground is painted a few times, each a little larger and fainter, so it
# fades into its neighbour instead of ending on a hard line.
const FEATHER := [[260.0, 0.22], [150.0, 0.4], [60.0, 0.65]]

const GROUND := {
	"grass": preload("res://Sprites/GrassTile.png"),
	"sand": preload("res://assets/ground_sand.png"),
	"swamp": preload("res://assets/ground_swamp.png"),
	"rock": preload("res://assets/ground_rock.png"),
	"snow": preload("res://assets/ground_snow.png"),
	"ash": preload("res://assets/ground_ash.png"),
	"void": preload("res://assets/ground_void.png"),
	"water": preload("res://Sprites/Water_0.png"),
}

const TREE := preload("res://assets/deco_tree.png")
const BUSH := preload("res://assets/deco_bush.png")
const TUFT := preload("res://assets/deco_grass_tuft.png")
const ROCK := preload("res://assets/deco_rock.png")
const CACTUS := preload("res://assets/deco_cactus.png")
const DEAD_TREE := preload("res://assets/deco_dead_tree.png")
const PINE := preload("res://assets/deco_pine_tree.png")
const CRYSTAL := preload("res://assets/deco_crystal.png")

# Scenery per region ("decor" in WorldMap.gd): each entry gets `chance` of being the thing dropped at a candidate
# spot (the chances of one region add up to under 1). `solid` = a trunk-sized body that blocks movement.
# `scale` is a multiple of DECO_SCALE.
const DECOR := {
	"plains": [
		{"tex": TREE, "chance": 0.035, "solid": true}, {"tex": BUSH, "chance": 0.06}, {"tex": TUFT, "chance": 0.2}, {"tex": ROCK, "chance": 0.012},
	],
	"woods_edge": [
		{"tex": TREE, "chance": 0.2, "solid": true}, {"tex": BUSH, "chance": 0.1}, {"tex": TUFT, "chance": 0.12},
	],
	"woods": [
		{"tex": TREE, "chance": 0.46, "solid": true}, {"tex": BUSH, "chance": 0.12}, {"tex": TUFT, "chance": 0.09},
	],
	"heartwood": [
		{"tex": TREE, "chance": 0.5, "solid": true}, {"tex": TREE, "chance": 0.04, "solid": true, "scale": 1.7}, {"tex": BUSH, "chance": 0.1},
	],
	"ruins": [
		{"tex": DEAD_TREE, "chance": 0.07, "solid": true}, {"tex": ROCK, "chance": 0.13}, {"tex": TUFT, "chance": 0.06}, {"tex": BUSH, "chance": 0.03},
	],
	"desert": [
		{"tex": CACTUS, "chance": 0.07, "solid": true}, {"tex": ROCK, "chance": 0.06}, {"tex": ROCK, "chance": 0.008, "solid": true, "scale": 3.0},
	],
	"hills": [
		{"tex": ROCK, "chance": 0.15}, {"tex": ROCK, "chance": 0.02, "solid": true, "scale": 2.4}, {"tex": DEAD_TREE, "chance": 0.02, "solid": true},
	],
	"volcano": [
		{"tex": ROCK, "chance": 0.14}, {"tex": DEAD_TREE, "chance": 0.05, "solid": true},
	],
	"crater": [
		{"tex": ROCK, "chance": 0.1}, {"tex": CRYSTAL, "chance": 0.03},
	],
	"mountains": [
		{"tex": ROCK, "chance": 0.16}, {"tex": ROCK, "chance": 0.03, "solid": true, "scale": 3.0}, {"tex": PINE, "chance": 0.03, "solid": true},
	],
	"lizen": [
		{"tex": ROCK, "chance": 0.05}, {"tex": TUFT, "chance": 0.05}, {"tex": DEAD_TREE, "chance": 0.02, "solid": true},
	],
	"swamp": [
		{"tex": DEAD_TREE, "chance": 0.14, "solid": true}, {"tex": ROCK, "chance": 0.04}, {"tex": BUSH, "chance": 0.06}, {"tex": TUFT, "chance": 0.04},
	],
	"beach": [
		{"tex": ROCK, "chance": 0.03}, {"tex": TUFT, "chance": 0.025}, {"tex": BUSH, "chance": 0.01},
	],
	"frozen": [
		{"tex": PINE, "chance": 0.1, "solid": true}, {"tex": ROCK, "chance": 0.06},
	],
	"void": [
		{"tex": CRYSTAL, "chance": 0.12}, {"tex": ROCK, "chance": 0.04},
	],
	"ranch": [
		{"tex": TUFT, "chance": 0.05}, {"tex": BUSH, "chance": 0.015},
	],
}

var protected_check: Callable = Callable()   # Main: pos -> bool, true where scenery must stay out (the town, the pond...)
var _chunks: Dictionary = {}                 # Vector2i -> Node2D holding that chunk's scenery
var _last_chunk := Vector2i(-99999, -99999)
var _ground_nodes: Array = []                # [{node, key}] so the animated textures can be swapped in later
var _landmark_clearings: Array = []          # [pos, radius]

func build() -> void:
	WorldMapScript.ensure_built()
	_paint_regions()
	_add_water_collision()
	_build_landmarks()
	for l in WorldMapScript.landmarks:
		if l.kind in ["boss", "ruins", "ranch", "town", "cave"]:
			_landmark_clearings.append([l.pos, float(l.radius) + 650.0])
	_landmark_clearings.append([WorldMapScript.landmark("pesca").pos, 1500.0])

# The HUD owns the animated grass and water textures; Main hands them over once it exists.
func apply_animated_textures(grass: Texture2D, water: Texture2D) -> void:
	for entry in _ground_nodes:
		if entry.key == "grass" and grass != null:
			entry.node.texture = grass
		elif entry.key == "water" and water != null:
			entry.node.texture = water

# --- the ground ------------------------------------------------------------------------------

func _paint_regions() -> void:
	var holder := Node2D.new()
	holder.name = "Ground"
	holder.z_index = -10
	add_child(holder)
	for r in WorldMapScript.regions:
		var base: bool = r.id == "great_expanse"
		var feathered: bool = not base and r.walkable and r.ground != "water"
		if feathered:
			for ring in FEATHER:
				for poly in Geometry2D.offset_polygon(r.polygon, float(ring[0]), Geometry2D.JOIN_ROUND):
					holder.add_child(_ground_polygon(poly, r, float(ring[1])))
		holder.add_child(_ground_polygon(r.polygon, r, 1.0))

func _ground_polygon(poly: PackedVector2Array, r: Dictionary, alpha: float) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = poly
	p.uv = poly
	p.texture = GROUND.get(r.ground, GROUND["grass"])
	p.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.color = Color(r.tint.r, r.tint.g, r.tint.b, alpha)
	if r.ground == "grass" or r.ground == "water":
		_ground_nodes.append({"node": p, "key": r.ground})
	return p

func _add_water_collision() -> void:
	var body := StaticBody2D.new()
	body.name = "DeepWater"
	for poly in WorldMapScript.blocked_polygons():
		var shape := CollisionPolygon2D.new()
		shape.polygon = poly
		body.add_child(shape)
	add_child(body)

# --- scenery chunks --------------------------------------------------------------------------

# Keeps the chunks around `center` loaded and frees the far ones. Cheap when the player has not changed chunk.
func update_chunks(center: Vector2) -> void:
	var here := Vector2i(floori(center.x / CHUNK), floori(center.y / CHUNK))
	if here == _last_chunk:
		return
	_last_chunk = here
	var wanted := {}
	var max_x: int = int(ceil(WorldMapScript.SIZE.x / CHUNK))
	var max_y: int = int(ceil(WorldMapScript.SIZE.y / CHUNK))
	for dx in range(-CHUNK_RADIUS, CHUNK_RADIUS + 1):
		for dy in range(-CHUNK_RADIUS, CHUNK_RADIUS + 1):
			var c := Vector2i(here.x + dx, here.y + dy)
			if c.x < 0 or c.y < 0 or c.x >= max_x or c.y >= max_y:
				continue
			wanted[c] = true
			if not _chunks.has(c):
				_load_chunk(c)
	for c in _chunks.keys():
		if not wanted.has(c):
			_chunks[c].queue_free()
			_chunks.erase(c)

func loaded_chunk_count() -> int:
	return _chunks.size()

func _load_chunk(coord: Vector2i) -> void:
	var container := Node2D.new()
	container.name = "Chunk_%d_%d" % [coord.x, coord.y]
	container.z_index = -5
	add_child(container)
	_chunks[coord] = container
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(coord.x, coord.y, WorldMapScript.MAP_SEED))
	var placed: Array = []
	var spawn: Vector2 = WorldMapScript.spawn_position()
	for i in CANDIDATES_PER_CHUNK:
		var pos := Vector2(coord.x * CHUNK + rng.randf() * CHUNK, coord.y * CHUNK + rng.randf() * CHUNK)
		var roll: float = rng.randf()          # always drawn, so what lands where never depends on what was skipped
		var scale_roll: float = rng.randf()
		if pos.x < 40.0 or pos.y < 40.0 or pos.x > WorldMapScript.SIZE.x - 40.0 or pos.y > WorldMapScript.SIZE.y - 40.0:
			continue
		if pos.distance_to(spawn) < PLAYER_CLEARANCE:
			continue
		var region: Dictionary = WorldMapScript.region_at(pos)
		if not region.walkable:
			continue
		var specs: Array = DECOR.get(region.decor, [])
		if specs.is_empty():
			continue
		if protected_check.is_valid() and protected_check.call(pos):
			continue
		if _in_clearing(pos):
			continue
		var chosen: Dictionary = {}
		var acc := 0.0
		for spec in specs:
			acc += float(spec.chance)
			if roll < acc:
				chosen = spec
				break
		if chosen.is_empty():
			continue
		var too_close := false
		for q in placed:
			if pos.distance_to(q) < MIN_SPACING:
				too_close = true
				break
		if too_close:
			continue
		placed.append(pos)
		var s: float = DECO_SCALE * float(chosen.get("scale", 1.0)) * (0.85 + scale_roll * 0.3)
		var sprite := Sprite2D.new()
		sprite.texture = chosen.tex
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = pos
		sprite.scale = Vector2(s, s)
		sprite.modulate = Color.WHITE.lerp(region.tint, 0.55)
		container.add_child(sprite)
		if bool(chosen.get("solid", false)):
			container.add_child(_trunk_body(pos, s))

func _in_clearing(pos: Vector2) -> bool:
	for c in _landmark_clearings:
		if pos.distance_to(c[0]) < float(c[1]):
			return true
	return false

# A small collision circle near the trunk (not the wide canopy): the trunk sits in the lower third of the sprite.
func _trunk_body(pos: Vector2, s: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = pos + Vector2(0, 10) * s
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 8.0 * s
	collision.shape = shape
	body.add_child(collision)
	return body

# --- landmark structures (placeholders) ------------------------------------------------------

func _build_landmarks() -> void:
	var holder := Node2D.new()
	holder.name = "Landmarks"
	holder.z_index = -4
	add_child(holder)
	var rng := RandomNumberGenerator.new()
	rng.seed = WorldMapScript.MAP_SEED + 7
	_heartwood(holder, WorldMapScript.landmark("heartwood").pos, rng)
	_ruins(holder, WorldMapScript.landmark("ruins").pos, rng)
	_lizen(holder, WorldMapScript.landmark("lizen_encampment").pos, rng)
	_pesca(holder, WorldMapScript.landmark("pesca").pos, rng)
	_ranch(holder, WorldMapScript.landmark("ranch").pos, rng)
	_wreck(holder, WorldMapScript.landmark("leviathan_shore").pos, rng)
	_spire(holder, WorldMapScript.landmark("frozen_spire").pos, rng)
	_crater(holder, WorldMapScript.landmark("crater").pos, rng)
	_throne(holder, WorldMapScript.landmark("void_throne").pos, rng)
	_caves(holder, WorldMapScript.landmark("caves").pos, rng)

func _poly(parent: Node, points: PackedVector2Array, color: Color, z: int = 0) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = color
	p.z_index = z
	parent.add_child(p)
	return p

func _disc(parent: Node, center: Vector2, radius: float, color: Color, z: int = 0, count: int = 22) -> Polygon2D:
	var pts := PackedVector2Array()
	for i in count:
		var a := TAU * float(i) / float(count)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return _poly(parent, pts, color, z)

func _box(parent: Node, center: Vector2, size: Vector2, color: Color, rotation_rad: float = 0.0, solid: bool = false, z: int = 0) -> Node2D:
	var node: Node2D = StaticBody2D.new() if solid else Node2D.new()
	node.position = center
	node.rotation = rotation_rad
	node.z_index = z
	var half := size / 2.0
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)])
	p.color = color
	node.add_child(p)
	if solid:
		var c := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = size
		c.shape = shape
		node.add_child(c)
	parent.add_child(node)
	return node

func _sprite(parent: Node, tex: Texture2D, pos: Vector2, s: float, tint: Color = Color.WHITE, solid_radius: float = 0.0, z: int = 0) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.position = pos
	sp.scale = Vector2(s, s)
	sp.modulate = tint
	sp.z_index = z
	parent.add_child(sp)
	if solid_radius > 0.0:
		var body := StaticBody2D.new()
		body.position = pos + Vector2(0, 10) * s
		var c := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = solid_radius
		c.shape = shape
		body.add_child(c)
		parent.add_child(body)
	return sp

# The HeartWood: one colossal tree the whole wood grows around, in a dark clearing.
func _heartwood(parent: Node, pos: Vector2, rng: RandomNumberGenerator) -> void:
	_disc(parent, pos, 1050.0, Color(0.05, 0.12, 0.06, 0.45), -2, 36)
	_disc(parent, pos, 620.0, Color(0.08, 0.2, 0.1, 0.4), -2, 30)
	# roots
	for i in 8:
		var a := TAU * float(i) / 8.0 + rng.randf() * 0.3
		_box(parent, pos + Vector2(cos(a), sin(a)) * 330.0 + Vector2(0, 260), Vector2(380, 46), Color(0.22, 0.14, 0.08), a, false, -1)
	_sprite(parent, TREE, pos, 32.0, Color(0.7, 0.95, 0.7), 8.0 * 32.0 * 0.62, 2)
	for i in 14:
		var a := TAU * float(i) / 14.0 + rng.randf() * 0.2
		_sprite(parent, TREE, pos + Vector2(cos(a), sin(a)) * (1250.0 + rng.randf() * 200.0), 7.0 + rng.randf() * 3.0, Color(0.6, 0.9, 0.62), 8.0 * 7.0, 1)

# A settlement where everyone is dead: broken walls, rubble, bare trees and a few grave markers. Sized for a
# 32 px player: a ruined house is ~150 px across.
func _ruins(parent: Node, pos: Vector2, rng: RandomNumberGenerator) -> void:
	_disc(parent, pos, 1100.0, Color(0.2, 0.2, 0.18, 0.3), -2, 32)
	for i in 34:
		var a := rng.randf() * TAU
		var d := 60.0 + rng.randf() * 900.0
		var wall := Vector2(50.0 + rng.randf() * 110.0, 16.0 + rng.randf() * 12.0)
		_box(parent, pos + Vector2(cos(a), sin(a)) * d, wall, Color(0.42 + rng.randf() * 0.1, 0.4, 0.37), rng.randf() * PI, true, 0)
	for i in 14:
		var a := rng.randf() * TAU
		_sprite(parent, ROCK, pos + Vector2(cos(a), sin(a)) * (120.0 + rng.randf() * 950.0), 2.4, Color(0.7, 0.68, 0.64))
	for i in 8:
		var a := rng.randf() * TAU
		_sprite(parent, DEAD_TREE, pos + Vector2(cos(a), sin(a)) * (250.0 + rng.randf() * 800.0), 2.6, Color(0.75, 0.72, 0.68), 8.0 * 2.6)
	for i in 10:
		var a := rng.randf() * TAU
		_box(parent, pos + Vector2(cos(a), sin(a)) * (150.0 + rng.randf() * 600.0), Vector2(12, 28), Color(0.3, 0.3, 0.32), 0.0, false, 0)

# The Lizen Encampment: a palisade ring with a gate north and south, tents, towers and a fire.
func _lizen(parent: Node, pos: Vector2, rng: RandomNumberGenerator) -> void:
	var radius := 520.0
	_disc(parent, pos, radius + 140.0, Color(0.3, 0.22, 0.12, 0.35), -2, 36)
	var posts := 60
	for i in posts:
		var a := TAU * float(i) / float(posts)
		if absf(sin(a)) > 0.95:
			continue                                   # the two gates (north and south)
		var p := pos + Vector2(cos(a), sin(a)) * radius
		_box(parent, p, Vector2(58, 18), Color(0.4, 0.27, 0.14), a + PI / 2.0, true, 1)
	for i in 4:
		var a := PI / 4.0 + PI / 2.0 * float(i)
		_box(parent, pos + Vector2(cos(a), sin(a)) * radius, Vector2(54, 54), Color(0.3, 0.2, 0.1), 0.0, true, 2)
	for i in 6:
		var a := TAU * float(i) / 6.0 + 0.4
		var c := pos + Vector2(cos(a), sin(a)) * 270.0
		_poly(parent, PackedVector2Array([c + Vector2(0, -62), c + Vector2(58, 38), c + Vector2(-58, 38)]), Color(0.38, 0.45, 0.25), 1)
	_disc(parent, pos, 26.0, Color(0.9, 0.45, 0.12), 1, 12)
	_disc(parent, pos, 54.0, Color(0.1, 0.07, 0.04, 0.5), 0, 14)
	for i in 4:
		_box(parent, pos + Vector2(-110 + 75 * i, 190), Vector2(8, 56), Color(0.7, 0.15, 0.12), 0.0, false, 2)

# Pesca: a dock town on a headland -- boardwalk, houses (the town's building art, for now) and a few boats.
func _pesca(parent: Node, pos: Vector2, rng: RandomNumberGenerator) -> void:
	var poly: PackedVector2Array = WorldMapScript.region("pesca").polygon
	var base := Vector2.ZERO
	for p in poly:
		base += p
	base /= float(poly.size())
	var axis: Vector2 = (pos - base).normalized()
	var length: float = base.distance_to(pos)
	for i in int(length / 70.0):
		_box(parent, base + axis * (70.0 * float(i)), Vector2(70, 22), Color(0.5, 0.35, 0.2), axis.angle() + PI / 2.0, false, 1)
	var houses := [
		preload("res://assets/building_shop.png"), preload("res://assets/building_tavern.png"), preload("res://assets/building_healer.png"),
		preload("res://assets/building_blacksmith.png"), preload("res://assets/building_church.png"), preload("res://assets/building_butcher.png"),
	]
	var side := Vector2(-axis.y, axis.x)
	for i in houses.size():
		var along: float = 120.0 + 150.0 * float(i / 2)
		var off: float = (150.0 if i % 2 == 0 else -150.0)
		var at: Vector2 = base + axis * along + side * off
		_sprite(parent, houses[i], at, 3.4, Color.WHITE, 0.0, 2)
		_box(parent, at + Vector2(0, 52), Vector2(150, 90), Color(0, 0, 0, 0), 0.0, true, 0)
	for i in 4:
		var bp := pos + side * (260.0 + 80.0 * float(i)) + axis * (rng.randf() * 200.0)
		_poly(parent, PackedVector2Array([bp + Vector2(-44, 0), bp + Vector2(44, 0), bp + Vector2(30, 24), bp + Vector2(-30, 24)]), Color(0.35, 0.22, 0.12), 1)
		_box(parent, bp + Vector2(0, -26), Vector2(5, 52), Color(0.8, 0.78, 0.7), 0.0, false, 1)

# The ranch: a fenced paddock with a barn and haystacks on the town's outskirts.
func _ranch(parent: Node, pos: Vector2, rng: RandomNumberGenerator) -> void:
	var radius := 620.0
	var posts := 64
	for i in posts:
		var a := TAU * float(i) / float(posts)
		if cos(a) > 0.95:
			continue                                   # the gate faces the town... east
		var p := pos + Vector2(cos(a), sin(a)) * radius
		_box(parent, p, Vector2(60, 7), Color(0.55, 0.4, 0.22), a + PI / 2.0, false, 0)
		_box(parent, p, Vector2(9, 22), Color(0.4, 0.28, 0.15), 0.0, true, 1)
	_sprite(parent, preload("res://assets/building_shop.png"), pos + Vector2(-210, -170), 5.0, Color(0.9, 0.7, 0.6), 0.0, 2)
	_box(parent, pos + Vector2(-210, -100), Vector2(220, 150), Color(0, 0, 0, 0), 0.0, true, 0)
	for i in 5:
		var a := rng.randf() * TAU
		_disc(parent, pos + Vector2(cos(a), sin(a)) * (150.0 + rng.randf() * 280.0), 26.0, Color(0.85, 0.72, 0.3), 0, 12)

# Leviathan's Shore: a wrecked hull on the beach.
func _wreck(parent: Node, pos: Vector2, rng: RandomNumberGenerator) -> void:
	_poly(parent, PackedVector2Array([pos + Vector2(-240, 0), pos + Vector2(240, -40), pos + Vector2(190, 76), pos + Vector2(-190, 96)]), Color(0.3, 0.2, 0.12), 0)
	_box(parent, pos + Vector2(26, -110), Vector2(12, 170), Color(0.4, 0.3, 0.2), 0.15, false, 1)
	_box(parent, pos + Vector2(70, -96), Vector2(96, 76), Color(0.8, 0.78, 0.7, 0.8), 0.15, false, 1)
	for i in 6:
		_sprite(parent, ROCK, pos + Vector2(-420 + rng.randf() * 840.0, 170 + rng.randf() * 200.0), 2.6, Color(0.8, 0.85, 0.9))

# The White Spire: shards of ice.
func _spire(parent: Node, pos: Vector2, rng: RandomNumberGenerator) -> void:
	for i in 7:
		var a := TAU * float(i) / 7.0
		var c := pos + Vector2(cos(a), sin(a)) * (240.0 + rng.randf() * 110.0)
		_poly(parent, PackedVector2Array([c + Vector2(-40, 40), c + Vector2(0, -170 - rng.randf() * 80.0), c + Vector2(40, 40)]), Color(0.75, 0.9, 1.0, 0.9), 1)
	_sprite(parent, CRYSTAL, pos, 6.5, Color(0.7, 0.9, 1.3), 8.0 * 6.5 * 0.5, 1)

# The Crater: pools of lava around the Red Wyrm's nest.
func _crater(parent: Node, pos: Vector2, rng: RandomNumberGenerator) -> void:
	_disc(parent, pos, 1050.0, Color(0.15, 0.04, 0.03, 0.45), -2, 30)
	for i in 8:
		var a := TAU * float(i) / 8.0 + rng.randf() * 0.5
		_disc(parent, pos + Vector2(cos(a), sin(a)) * (520.0 + rng.randf() * 300.0), 90.0 + rng.randf() * 120.0, Color(1.0, 0.4 + rng.randf() * 0.2, 0.08, 0.9), -1, 14)
	_disc(parent, pos, 230.0, Color(0.12, 0.08, 0.08), 0, 20)

# The Void Throne: a ring of dark crystals around a black disc.
func _throne(parent: Node, pos: Vector2, rng: RandomNumberGenerator) -> void:
	_disc(parent, pos, 700.0, Color(0.03, 0.01, 0.08, 0.5), -2, 30)
	_disc(parent, pos, 200.0, Color(0.02, 0.0, 0.05), -1, 20)
	for i in 8:
		var a := TAU * float(i) / 8.0
		_sprite(parent, CRYSTAL, pos + Vector2(cos(a), sin(a)) * 520.0, 6.0, Color(0.8, 0.5, 1.3), 8.0 * 6.0 * 0.5, 1)

# The mountain's caves: dark mouths in big outcrops of rock.
func _caves(parent: Node, pos: Vector2, rng: RandomNumberGenerator) -> void:
	for i in 3:
		var c := pos + Vector2(-700 + 700.0 * float(i), -320 + 340.0 * float(i % 2))
		_sprite(parent, ROCK, c, 16.0, Color(0.7, 0.68, 0.66), 8.0 * 16.0 * 0.6, 0)
		_poly(parent, PackedVector2Array([c + Vector2(-70, 190), c + Vector2(-44, 60), c + Vector2(0, 24), c + Vector2(44, 60), c + Vector2(70, 190)]), Color(0.03, 0.03, 0.04), 1)
