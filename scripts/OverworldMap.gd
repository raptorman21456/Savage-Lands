extends Node2D
class_name OverworldMap

# Draws WorldMap.gd's geography as the overworld: every region painted as a textured polygon (soft-edged where it
# meets its neighbours) and deep water that actually blocks you. Everything ELSE -- the scenery, the set pieces
# (ponds, camps, standing stones...), the barriers along room edges and the landmark structures -- belongs to a ROOM
# (Rooms.gd) and exists only while that room is near you: the room you stand in is built at once, the ones around
# it a little at a time as you approach, and each is freed again once you have left it far behind. A room's contents
# come from its own seed, so leaving and coming back always shows the same trees.
#
# The landmark structures (the HeartWood, the Lizen palisade, Pesca's docks...) and the set pieces are PLACEHOLDERS
# built from simple shapes and the existing sprites, until the user's own art replaces them.

const WorldMapScript := preload("res://scripts/WorldMap.gd")
const RoomsScript := preload("res://scripts/Rooms.gd")
const RoomDataScript := preload("res://scripts/RoomData.gd")

const ROOM_LOAD_MARGIN := 1600.0      # a room starts to be built when you come within this of it...
const ROOM_UNLOAD_MARGIN := 2600.0    # ...and is freed once you are further than this
const SCATTER_PER_FRAME := 400        # tree-wall lattice points handled per frame for a room that is loading in the background
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

var protected_check: Callable = Callable()   # Main: pos -> bool, true where scenery must stay out (the town, the pond...)
var _rooms: Dictionary = {}                  # room id -> state (see _start_room)
var _pending: Array = []                     # ids of rooms waiting to be built, nearest first
var _work: Array = []                        # ids of rooms whose scenery is still being scattered
var _wanted: Dictionary = {}                 # ids of the rooms that should be built right now
var _current_id := ""
var _last_center := Vector2(-1.0e9, -1.0e9)
var _ground_nodes: Array = []                # [{node, key}] so the animated textures can be swapped in later
var _landmark_clearings: Array = []          # [pos, radius]

func build() -> void:
	WorldMapScript.ensure_built()
	RoomsScript.ensure_built()
	_paint_regions()
	_add_water_collision()
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

# --- rooms: loading, shape, scenery -----------------------------------------------------------

# Keeps the room around `center` built, queues the ones within reach and lets go of the far ones. Cheap when you have
# not gone anywhere (Main calls it every frame).
func update_rooms(center: Vector2) -> void:
	RoomsScript.ensure_built()
	var here: Dictionary = RoomsScript.room_at(center)
	if here.id == _current_id and center.distance_squared_to(_last_center) < 2500.0:
		return
	_last_center = center
	_current_id = here.id
	_wanted = {here.id: true}
	for r in RoomsScript.rooms_near(center, ROOM_LOAD_MARGIN):
		_wanted[r.id] = true
	var keep := {here.id: true}
	for r in RoomsScript.rooms_near(center, ROOM_UNLOAD_MARGIN):
		keep[r.id] = true
	# the room you stand in is finished before you can see an unfinished one
	if not _rooms.has(here.id):
		_start_room(here, true)
	elif not _rooms[here.id].done:
		_finish(_rooms[here.id])
	var queue: Array = []
	for id in _wanted:
		if not _rooms.has(id) and not (id in _pending):
			queue.append(RoomsScript.by_id(id))
	queue.sort_custom(func(a, b): return _rect_distance(a.rect, center) < _rect_distance(b.rect, center))
	for r in queue:
		_pending.append(r.id)
	for id in _rooms.keys():
		if not keep.has(id):
			_unload_room(id)
	_pending = _pending.filter(func(id): return _wanted.has(id))

static func _rect_distance(rect: Rect2, p: Vector2) -> float:
	var dx := maxf(maxf(rect.position.x - p.x, 0.0), p.x - rect.end.x)
	var dy := maxf(maxf(rect.position.y - p.y, 0.0), p.y - rect.end.y)
	return sqrt(dx * dx + dy * dy)

func _process(_delta: float) -> void:
	_pump()

# One slice of background loading: the next stage of the room in progress, else the start of the next queued room.
# False when there is nothing left to do.
func _pump() -> bool:
	if not _work.is_empty():
		var id: String = _work[0]
		if not _rooms.has(id):
			_work.pop_front()
			return true
		var state: Dictionary = _rooms[id]
		_advance(state, SCATTER_PER_FRAME)
		if state.done:
			_work.pop_front()
		return true
	while not _pending.is_empty():
		var next_id: String = _pending.pop_front()
		if _rooms.has(next_id) or not _wanted.has(next_id):
			continue
		_start_room(RoomsScript.by_id(next_id), false)
		return true
	return false

# Finishes every room that is queued or half-built (used at the start of a run and by the tests).
func flush() -> void:
	while _pump():
		pass

func loaded_room_count() -> int:
	return _rooms.size()

func loaded_room_ids() -> Array:
	return _rooms.keys()

func is_room_loaded(id: String) -> bool:
	return _rooms.has(id)

func is_room_complete(id: String) -> bool:
	return _rooms.has(id) and bool(_rooms[id].done)

func pending_room_count() -> int:
	return _pending.size() + _work.size()

# How many scenery sprites a loaded room holds on its floor (tests compare a room before and after being unloaded).
func scenery_count(id: String) -> int:
	return _rooms[id].scenery.get_child_count() if _rooms.has(id) else 0

# How many sprites make up the room's solid ground (the trees of a forest wall...).
func mass_sprite_count(id: String) -> int:
	return _rooms[id].mass_sprites.get_child_count() if _rooms.has(id) else 0

# How many of the room's set pieces found a place to stand (a room's features can fail to fit).
func features_placed(id: String) -> int:
	return int(_rooms[id].placed) if _rooms.has(id) else 0

# Is this spot inside a set piece of a loaded room? (Enemies are not dropped there.)
func in_feature(pos: Vector2, margin: float = 0.0) -> bool:
	for id in _rooms:
		for c in _rooms[id].clearings:
			if pos.distance_to(c[0]) < float(c[1]) + margin:
				return true
	return false

func _start_room(r: Dictionary, immediate: bool) -> void:
	var root := Node2D.new()
	root.name = "Room_%s" % r.id
	add_child(root)
	var mass_sprites := Node2D.new()
	mass_sprites.name = "MassSprites"
	mass_sprites.z_index = -8
	mass_sprites.y_sort_enabled = true
	root.add_child(mass_sprites)
	var scenery := Node2D.new()
	scenery.name = "Scenery"
	scenery.z_index = -5
	scenery.y_sort_enabled = true
	root.add_child(scenery)
	var structures := Node2D.new()
	structures.name = "Structures"
	structures.z_index = -4
	root.add_child(structures)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(r.seed)
	var style: Dictionary = MASS_STYLES.get(str(r.mass), {})
	var spacing: float = float(style.get("spacing", 64.0))
	# the lattice the solid ground's sprites sit on: world-anchored rows, every other row shifted half a step
	var mass_state := {"mi0": 0, "mj0": 0, "mcols": 1, "mn": 0}
	if not style.is_empty() and not style.sprites.is_empty():
		var row_step := spacing * 0.82
		mass_state.mi0 = floori(r.rect.position.x / spacing) - 1
		mass_state.mj0 = floori(r.rect.position.y / row_step) - 1
		mass_state.mcols = ceili(r.rect.size.x / spacing) + 3
		mass_state.mn = mass_state.mcols * (ceili(r.rect.size.y / row_step) + 3)
	var state := {
		"room": r, "root": root, "scenery": scenery, "structures": structures, "mass_sprites": mass_sprites,
		"rng": rng, "stage": 0, "layout": null, "style": style, "done": false, "clearings": [], "placed": 0,
		"mi": 0, "mn": 0, "mi0": 0, "mj0": 0, "mcols": 1,
	}
	state.merge(mass_state, true)
	_rooms[r.id] = state
	if immediate:
		_finish(state)
	else:
		_work.append(r.id)

func _finish(state: Dictionary) -> void:
	while not state.done:
		_advance(state, 1 << 30)

# The stages of building a room, one per call (so a room loading in the background costs a little each frame):
# its shape, its solid ground and set pieces, the sprites of the solid ground, the scenery on the floor.
func _advance(state: Dictionary, budget: int) -> void:
	match int(state.stage):
		0:
			state.layout = RoomsScript.layout(state.room)
			state.stage = 1
		1:
			_build_roads(state)
			_build_mass(state)
			# the doorways stay clear of scenery
			for ex in RoomsScript.exits(state.room):
				state.clearings.append([Vector2(ex.pos) + Vector2(ex.n) * 150.0, minf(float(ex.width) * 0.5, 320.0)])
			_place_features(state)
			_build_room_landmarks(state)
			state.stage = 2
		2:
			_scatter_mass(state, budget)
			if int(state.mi) >= int(state.mn):
				state.stage = 3
		_:
			_arrange(state)

func _unload_room(id: String) -> void:
	if not _rooms.has(id):
		return
	_rooms[id].root.queue_free()
	_rooms.erase(id)
	_work.erase(id)

# --- roads --------------------------------------------------------------------------------------

const ROAD_TEXTURE := preload("res://assets/ground_track.png")
const ROAD_EDGE := Color(0.32, 0.25, 0.17)
# Roads drawn flat instead of with the dirt texture: wooden boards over a bog, packed ash on the mountain.
const FLAT_ROADS := {
	"boards": {"fill": Color(0.5, 0.37, 0.22), "edge": Color(0.26, 0.18, 0.1)},
	"ash": {"fill": Color(0.34, 0.28, 0.27), "edge": Color(0.14, 0.1, 0.1)},
	"snow": {"fill": Color(0.84, 0.9, 0.94), "edge": Color(0.52, 0.62, 0.74)},
	"sand": {"fill": Color(0.85, 0.74, 0.5), "edge": Color(0.55, 0.43, 0.25)},
	"crystal": {"fill": Color(0.3, 0.16, 0.48), "edge": Color(0.1, 0.04, 0.2)},
}

static func _cell_to_px(p: Array) -> Vector2:
	var cx := float(p[0])
	var cy := float(p[1])
	var ic := clampi(floori(cx), 0, WorldMapScript.ROOM_COLS - 1)
	var ir := clampi(floori(cy), 0, WorldMapScript.ROOM_ROWS - 1)
	var x0 := float(WorldMapScript.col_x(ic))
	var x1 := float(WorldMapScript.col_x(ic + 1))
	var y0 := float(WorldMapScript.row_y(ir))
	var y1 := float(WorldMapScript.row_y(ir + 1))
	return Vector2(x0 + (cx - float(ic)) * (x1 - x0), y0 + (cy - float(ir)) * (y1 - y0))

# The dirt roads (RoomData.ROADS) that cross this room, drawn on the ground, edged darker.
func _build_roads(state: Dictionary) -> void:
	var rect: Rect2 = state.room.rect
	var rect_poly := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	for road in RoomDataScript.ROADS:
		var pts := PackedVector2Array()
		for p in road.points:
			pts.append(_cell_to_px(p))
		var half: float = float(road.width) * 0.5
		var flat: Dictionary = FLAT_ROADS.get(str(road.get("style", "dirt")), {})
		for layer in 2:
			var radius: float = half + (11.0 if layer == 0 else 0.0)
			for stroke in Geometry2D.offset_polyline(pts, radius, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
				for piece in Geometry2D.intersect_polygons(stroke, rect_poly):
					var poly := Polygon2D.new()
					poly.polygon = piece
					poly.z_index = -9
					if layer == 0:
						poly.color = flat.edge if not flat.is_empty() else ROAD_EDGE
					elif not flat.is_empty():
						poly.color = flat.fill
					else:
						poly.texture = ROAD_TEXTURE
						poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
						poly.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
						var uv := PackedVector2Array()
						for v in piece:
							uv.append(v / 3.0)
						poly.uv = uv
					state.root.add_child(poly)

# --- the solid ground of a room ---------------------------------------------------------------

# What a room's solid ground looks like: its colours (the picture is drawn by a shader from the layout's field), and
# the sprites scattered over it near the floor (trees of a forest wall, boulders of a cliff...): [texture, scale,
# weight, tint]. depth = how far from the floor the sprites go (further in it is plain colour).
const MASS_STYLES := {
	"forest": {"fill": Color(0.07, 0.2, 0.08), "deep": Color(0.03, 0.1, 0.04), "rim": Color(0.12, 0.3, 0.1), "spacing": 56.0, "depth": 420.0,
		"sprites": [[TREE, 3.4, 1.0, Color(0.62, 0.86, 0.62)], [BUSH, 3.2, 0.25, Color(0.6, 0.85, 0.55)]]},
	"thicket": {"fill": Color(0.13, 0.3, 0.11), "deep": Color(0.07, 0.18, 0.07), "rim": Color(0.22, 0.4, 0.15), "spacing": 60.0, "depth": 340.0,
		"sprites": [[BUSH, 4.0, 1.0, Color(0.72, 0.95, 0.62)], [TREE, 2.6, 0.3, Color(0.72, 0.95, 0.66)]]},
	"pines": {"fill": Color(0.1, 0.22, 0.2), "deep": Color(0.05, 0.12, 0.12), "rim": Color(0.55, 0.72, 0.75), "spacing": 58.0, "depth": 420.0,
		"sprites": [[PINE, 3.3, 1.0, Color(0.85, 0.95, 1.1)]]},
	"dead_forest": {"fill": Color(0.15, 0.17, 0.1), "deep": Color(0.08, 0.1, 0.06), "rim": Color(0.25, 0.3, 0.16), "spacing": 64.0, "depth": 380.0,
		"sprites": [[DEAD_TREE, 3.2, 1.0, Color(0.7, 0.8, 0.6)], [BUSH, 2.6, 0.2, Color(0.55, 0.65, 0.4)]]},
	"rock": {"fill": Color(0.33, 0.31, 0.33), "deep": Color(0.2, 0.19, 0.21), "rim": Color(0.55, 0.53, 0.55), "spacing": 84.0, "depth": 380.0,
		"sprites": [[ROCK, 6.5, 1.0, Color(0.75, 0.72, 0.7)]]},
	"sandstone": {"fill": Color(0.62, 0.46, 0.28), "deep": Color(0.45, 0.32, 0.18), "rim": Color(0.8, 0.64, 0.4), "spacing": 84.0, "depth": 380.0,
		"sprites": [[ROCK, 6.5, 1.0, Color(1.1, 0.9, 0.65)]]},
	"volcanic": {"fill": Color(0.16, 0.09, 0.08), "deep": Color(0.08, 0.04, 0.04), "rim": Color(0.4, 0.2, 0.14), "spacing": 84.0, "depth": 380.0,
		"sprites": [[ROCK, 6.5, 1.0, Color(0.55, 0.4, 0.36)]]},
	"crystal_rock": {"fill": Color(0.12, 0.06, 0.2), "deep": Color(0.06, 0.03, 0.12), "rim": Color(0.4, 0.2, 0.6), "spacing": 90.0, "depth": 340.0,
		"sprites": [[CRYSTAL, 5.0, 1.0, Color(0.75, 0.5, 1.2)], [ROCK, 5.0, 0.5, Color(0.5, 0.4, 0.6)]]},
	"water": {"fill": Color(0.17, 0.4, 0.7), "deep": Color(0.1, 0.25, 0.52), "rim": Color(0.62, 0.84, 0.94), "spacing": 64.0, "depth": 0.0, "sprites": []},
	"bog": {"fill": Color(0.2, 0.27, 0.14), "deep": Color(0.1, 0.15, 0.08), "rim": Color(0.35, 0.42, 0.2), "spacing": 64.0, "depth": 0.0, "sprites": []},
	"ice": {"fill": Color(0.6, 0.82, 0.95), "deep": Color(0.4, 0.65, 0.85), "rim": Color(0.92, 0.97, 1.0), "spacing": 64.0, "depth": 0.0, "sprites": []},
	"lava": {"fill": Color(0.95, 0.4, 0.08), "deep": Color(0.75, 0.2, 0.05), "rim": Color(0.25, 0.08, 0.05), "spacing": 64.0, "depth": 0.0, "sprites": []},
	"abyss": {"fill": Color(0.05, 0.02, 0.1), "deep": Color(0.01, 0.0, 0.03), "rim": Color(0.45, 0.2, 0.7), "spacing": 64.0, "depth": 0.0, "sprites": []},
}
const MASS_SHADER_CODE := """
shader_type canvas_item;
uniform vec4 fill_color : source_color;
uniform vec4 deep_color : source_color;
uniform vec4 rim_color : source_color;
uniform vec2 texel;
void fragment() {
	vec2 lo = 0.5 * texel;
	if (UV.x < lo.x || UV.y < lo.y || UV.x > 1.0 - lo.x || UV.y > 1.0 - lo.y) {
		discard;
	}
	float v = texture(TEXTURE, UV).r;
	float inside = 1.0 - smoothstep(0.494, 0.506, v);
	float depth = clamp((0.5 - v) * 2.0, 0.0, 1.0);
	vec3 c = mix(rim_color.rgb, fill_color.rgb, smoothstep(0.0, 0.1, depth));
	c = mix(c, deep_color.rgb, smoothstep(0.25, 0.9, depth));
	COLOR = vec4(c, inside);
}
"""
static var _mass_shader: Shader = null

# The picture of the solid ground (a shader over the layout's field, so the outline is smooth) and its collision (the
# outline of the floor, as line segments).
func _build_mass(state: Dictionary) -> void:
	var r: Dictionary = state.room
	var layout = state.layout
	var style: Dictionary = state.style
	if style.is_empty():
		return
	var sprite := Sprite2D.new()
	sprite.name = "MassFill"
	sprite.centered = false
	var image: Image = layout.to_image()
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = r.rect.position - layout.step * 0.5
	sprite.scale = layout.step
	sprite.z_index = -9
	if _mass_shader == null:
		_mass_shader = Shader.new()
		_mass_shader.code = MASS_SHADER_CODE
	var material := ShaderMaterial.new()
	material.shader = _mass_shader
	material.set_shader_parameter("fill_color", style.fill)
	material.set_shader_parameter("deep_color", style.deep)
	material.set_shader_parameter("rim_color", style.rim)
	material.set_shader_parameter("texel", Vector2(1.0 / float(image.get_width()), 1.0 / float(image.get_height())))
	sprite.material = material
	state.root.add_child(sprite)
	var segments: PackedVector2Array = layout.segments()
	if segments.size() >= 2:
		var body := StaticBody2D.new()
		body.name = "MassWalls"
		var shape := ConcavePolygonShape2D.new()
		shape.segments = segments
		var collision := CollisionShape2D.new()
		collision.shape = shape
		body.add_child(collision)
		state.root.add_child(body)

# The sprites of the solid ground within reach of the floor, on a regular lattice anchored to the world (so a forest
# wall lines up from one room to the next): rows of trees, every other one in the deeper rows, all the same size.
func _scatter_mass(state: Dictionary, budget: int) -> void:
	var style: Dictionary = state.style
	if style.is_empty() or int(state.mn) == 0:
		return
	var layout = state.layout
	var rect: Rect2 = state.room.rect
	var spacing: float = float(style.get("spacing", 64.0))
	var row_step: float = spacing * 0.82
	var depth_max: float = float(style.get("depth", 0.0))
	var sprites: Array = style.sprites
	var cols: int = state.mcols
	var end: int = mini(int(state.mi) + budget, int(state.mn))
	while int(state.mi) < end:
		var index: int = state.mi
		state.mi += 1
		var gj: int = int(state.mj0) + index / cols
		var gi: int = int(state.mi0) + index % cols
		var pos := Vector2((float(gi) + 0.5 * float(gj & 1)) * spacing, float(gj) * row_step)
		if not rect.has_point(pos):
			continue
		var depth: float = -layout.sample(pos)
		if depth < 4.0 or depth > depth_max:
			continue
		if depth > depth_max * 0.85 and not (gi % 2 == 0 and gj % 2 == 0):
			continue
		if depth > depth_max * 0.6 and (gi + gj) % 2 != 0:
			continue
		var chosen: Array = sprites[0]
		if sprites.size() > 1 and gi % 5 == 2 and gj % 3 == 1:
			chosen = sprites[1]
		var s: float = float(chosen[1])
		var sprite := Sprite2D.new()
		sprite.texture = chosen[0]
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = pos
		sprite.scale = Vector2(s, s)
		sprite.modulate = Color(chosen[3]).darkened(clampf(depth / maxf(depth_max, 1.0), 0.0, 1.0) * 0.3)
		state.mass_sprites.add_child(sprite)

# --- the decoration of the floor: arranged, never sprinkled ----------------------------------------

# What each country is dressed with: a tall thing (a tree...), a small one (a bush...), ground cover and a stone.
const PALETTES := {
	"plains": {"tall": TREE, "small": BUSH, "ground": TUFT, "stone": ROCK},
	"woods_edge": {"tall": TREE, "small": BUSH, "ground": TUFT, "stone": ROCK},
	"woods": {"tall": TREE, "small": BUSH, "ground": TUFT, "stone": ROCK},
	"heartwood": {"tall": TREE, "small": BUSH, "ground": TUFT, "stone": ROCK},
	"ruins": {"tall": DEAD_TREE, "small": ROCK, "ground": TUFT, "stone": ROCK},
	"desert": {"tall": CACTUS, "small": ROCK, "stone": ROCK},
	"hills": {"tall": DEAD_TREE, "small": ROCK, "ground": TUFT, "stone": ROCK},
	"volcano": {"tall": DEAD_TREE, "small": ROCK, "stone": ROCK},
	"crater": {"tall": CRYSTAL, "small": ROCK, "stone": ROCK},
	"mountains": {"tall": PINE, "small": ROCK, "stone": ROCK},
	"lizen": {"tall": DEAD_TREE, "small": ROCK, "ground": TUFT},
	"swamp": {"tall": DEAD_TREE, "small": BUSH, "ground": TUFT},
	"beach": {"small": ROCK, "ground": TUFT, "stone": ROCK},
	"frozen": {"tall": PINE, "small": ROCK, "stone": ROCK},
	"void": {"tall": CRYSTAL, "small": ROCK, "stone": ROCK},
	"ranch": {"small": BUSH, "ground": TUFT},
}
# Neat blocks of decoration set down on the floor: an orchard of trees in rows, a flower bed, a boulder garden, a
# hedge, a ring of trees. cols / rows are in items, spacing in px. A room's own "decor" multipliers (a meadow has
# more flower beds...) scale how often each is chosen.
const STANDS := {
	"orchard": {"item": "tall", "cols": [3, 6], "rows": [2, 4], "spacing": 112.0, "scale": 2.6, "solid": true, "weight": 3.0, "decor": ["tree", "pine", "dead_tree", "cactus"]},
	"flowerbed": {"item": "ground", "cols": [4, 7], "rows": [3, 4], "spacing": 52.0, "scale": 2.2, "solid": false, "weight": 2.0, "decor": ["tuft"]},
	"boulders": {"item": "stone", "cols": [2, 4], "rows": [2, 3], "spacing": 130.0, "scale": 3.2, "solid": true, "weight": 2.0, "decor": ["rock"]},
	"hedge": {"item": "small", "cols": [6, 12], "rows": [1, 1], "spacing": 60.0, "scale": 3.0, "solid": false, "weight": 2.0, "decor": ["bush"]},
	"ring": {"item": "tall", "ring": 8, "radius": 170.0, "scale": 2.6, "solid": true, "weight": 1.0, "decor": ["tree", "pine", "dead_tree"]},
}
# What lines the foot of each kind of solid ground, at even intervals: [palette item, ...] alternating.
const FRINGES := {
	"forest": {"every": 96.0, "inset": 70.0, "items": ["small", "ground"]},
	"thicket": {"every": 96.0, "inset": 62.0, "items": ["ground", "ground"]},
	"pines": {"every": 110.0, "inset": 66.0, "items": ["stone", "ground"]},
	"dead_forest": {"every": 104.0, "inset": 66.0, "items": ["small", "ground"]},
	"rock": {"every": 120.0, "inset": 56.0, "items": ["stone", "ground"]},
	"sandstone": {"every": 120.0, "inset": 56.0, "items": ["stone"]},
	"volcanic": {"every": 120.0, "inset": 56.0, "items": ["stone"]},
	"crystal_rock": {"every": 130.0, "inset": 56.0, "items": ["stone"]},
	"water": {"every": 76.0, "inset": 30.0, "items": ["ground"]},
	"bog": {"every": 76.0, "inset": 30.0, "items": ["ground"]},
}
const GRID := 64.0                    # stands sit on a grid of this size

# One decoration, if the spot is ordinary walkable ground that nothing else claims.
func _decor_item(state: Dictionary, tex: Texture2D, pos: Vector2, scale: float, solid: bool) -> bool:
	var region: Dictionary = WorldMapScript.region_at(pos)
	if not region.walkable or (protected_check.is_valid() and protected_check.call(pos)):
		return false
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = pos
	sprite.scale = Vector2(scale, scale)
	sprite.modulate = Color.WHITE.lerp(region.tint, 0.55)
	state.scenery.add_child(sprite)
	if solid:
		var body := StaticBody2D.new()
		var collision := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		if tex == ROCK:
			body.position = pos
			shape.radius = 6.0 * scale
		else:
			body.position = pos + Vector2(0, 10) * scale
			shape.radius = 8.0 * scale
		collision.shape = shape
		body.add_child(collision)
		state.scenery.add_child(body)
	return true

# The floor of a room is dressed once its shape and set pieces are in: posts either side of each doorway, a row of
# small things along the foot of the walls, and a few neat stands.
func _arrange(state: Dictionary) -> void:
	var r: Dictionary = state.room
	var layout = state.layout
	var palette: Dictionary = PALETTES.get(str(WorldMapScript.region(r.region).decor), PALETTES["plains"])
	_gate_posts(state, palette)
	_fringe(state, palette)
	if r.stands != null:                                 # hand-made: exactly the arrangements the room lists
		_arrange_authored(state, palette)
		state.done = true
		return
	var floor_area: float = r.rect.get_area() * layout.floor_fraction
	for i in clampi(int(round(floor_area / 2.2e6)), 1, 7):
		_place_stand(state, palette)
	state.done = true

# The arrangements a hand-made room lists (RoomData.gd "decor"), placed exactly where it says.
func _arrange_authored(state: Dictionary, palette: Dictionary) -> void:
	var o: Vector2 = state.room.rect.position
	for op in state.room.stands:
		var kind := str(op[0])
		match kind:
			"orchard":
				_authored_block(state, palette, "tall", o + Vector2(float(op[1]), float(op[2])), int(op[3]), int(op[4]), float(op[5]) if op.size() > 5 else 112.0)
			"bed":
				_authored_block(state, palette, "ground", o + Vector2(float(op[1]), float(op[2])), int(op[3]), int(op[4]), 52.0)
			"boulders":
				_authored_block(state, palette, "stone", o + Vector2(float(op[1]), float(op[2])), int(op[3]), int(op[4]), float(op[5]) if op.size() > 5 else 130.0)
			"row":
				var a := o + Vector2(float(op[2]), float(op[3]))
				var b := o + Vector2(float(op[4]), float(op[5]))
				var gap := maxf(float(op[6]), 20.0)
				var n := int(a.distance_to(b) / gap)
				for i in n + 1:
					_authored_item(state, palette, str(op[1]), a.lerp(b, float(i) / float(maxi(n, 1))))
			"ring":
				var c := o + Vector2(float(op[2]), float(op[3]))
				var count := int(op[5])
				for i in count:
					var ang := TAU * float(i) / float(count)
					_authored_item(state, palette, str(op[1]), c + Vector2(cos(ang), sin(ang)) * float(op[4]))
			"pair":
				var m := o + Vector2(float(op[2]), float(op[3]))
				var d := Vector2(float(op[4]), float(op[5]))
				_authored_item(state, palette, str(op[1]), m - d)
				_authored_item(state, palette, str(op[1]), m + d)

func _authored_block(state: Dictionary, palette: Dictionary, item: String, centre: Vector2, cols: int, rows: int, spacing: float) -> void:
	var size := Vector2(float(cols - 1) * spacing, float(rows - 1) * spacing)
	for ix in cols:
		for iy in rows:
			_authored_item(state, palette, item, centre - size * 0.5 + Vector2(float(ix) * spacing, float(iy) * spacing))

# One decoration by what it is (tall, small, ground, stone), sized and made solid as a stand would.
func _authored_item(state: Dictionary, palette: Dictionary, item: String, pos: Vector2) -> void:
	if not palette.has(item):
		return
	var item_scale := 2.6
	var solid := false
	match item:
		"tall": item_scale = 2.6; solid = true
		"small": item_scale = 3.0
		"ground": item_scale = 2.2
		"stone": item_scale = 3.2; solid = true
	_decor_item(state, palette[item], pos, item_scale, solid)

# Two tall things framing each narrow doorway.
func _gate_posts(state: Dictionary, palette: Dictionary) -> void:
	if not palette.has("tall"):
		return
	for ex in RoomsScript.exits(state.room):
		var width: float = float(ex.width)
		if width > 1300.0:
			continue
		var n: Vector2 = ex.n
		var across := Vector2(-n.y, n.x)
		for side in [-1.0, 1.0]:
			_decor_item(state, palette.tall, Vector2(ex.pos) + n * 80.0 + across * side * (width * 0.5 - 60.0), 3.0, true)

# Small things at even intervals along the foot of the walls (bushes under a forest wall, reeds along a shore...).
func _fringe(state: Dictionary, palette: Dictionary) -> void:
	var spec: Dictionary = FRINGES.get(str(state.room.mass), {})
	if spec.is_empty():
		return
	var layout = state.layout
	var every: float = float(spec.every)
	var inset: float = float(spec.inset)
	var keys: Array = spec["items"]
	var index := 0
	for chain in layout.contours():
		var carry := every * 0.5
		for i in chain.size() - 1:
			var a: Vector2 = chain[i]
			var b: Vector2 = chain[i + 1]
			var seg_len: float = a.distance_to(b)
			var d := carry
			while d <= seg_len:
				var p: Vector2 = a.lerp(b, d / seg_len)
				var pos: Vector2 = p + layout.toward_floor(p) * inset
				var key: String = keys[index % keys.size()]
				index += 1
				if palette.has(key) and layout.sample(pos) > 20.0 and not _in_clearing(pos, state):
					_decor_item(state, palette[key], pos, 2.4, false)
				d += every
			carry = d - seg_len

# One stand (see STANDS) on a spot of the floor that fits it whole.
func _place_stand(state: Dictionary, palette: Dictionary) -> void:
	var r: Dictionary = state.room
	var layout = state.layout
	var rng: RandomNumberGenerator = state.rng
	var kinds: Array = []
	var total := 0.0
	for k in STANDS:
		var spec: Dictionary = STANDS[k]
		if not palette.has(spec.item):
			continue
		var boost := 1.0
		for dk in spec.decor:
			boost = maxf(boost, float(r.decor.get(dk, 1.0)))
		kinds.append([k, float(spec.weight) * boost])
		total += float(spec.weight) * boost
	if kinds.is_empty():
		return
	var roll: float = rng.randf() * total
	var kind: String = kinds[0][0]
	for k in kinds:
		roll -= float(k[1])
		if roll <= 0.0:
			kind = k[0]
			break
	var spec: Dictionary = STANDS[kind]
	var spacing: float = float(spec.get("spacing", 100.0))
	var cols := 1
	var rows := 1
	if spec.has("ring"):
		cols = 3
		rows = 3
	else:
		cols = rng.randi_range(int(spec.cols[0]), int(spec.cols[1]))
		rows = rng.randi_range(int(spec.rows[0]), int(spec.rows[1]))
		if kind == "hedge" and rng.randf() < 0.5:
			rows = cols
			cols = 1
	var size := Vector2(float(cols - 1) * spacing, float(rows - 1) * spacing)
	if spec.has("ring"):
		size = Vector2(float(spec.radius), float(spec.radius)) * 2.0
	var half := size * 0.5 + Vector2(70.0, 70.0)
	var radius := half.length()
	var rect: Rect2 = r.rect.grow(-300.0)
	var spawn: Vector2 = WorldMapScript.spawn_position()
	for attempt in 40:
		var c := Vector2(snappedf(rect.position.x + rng.randf() * rect.size.x, GRID), snappedf(rect.position.y + rng.randf() * rect.size.y, GRID))
		# the whole footprint on the floor: corners, edge middles and centre
		var fits := true
		for off in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0), Vector2.ZERO]:
			var q: Vector2 = c + Vector2(half.x * off.x, half.y * off.y)
			if layout.sample(q) < 70.0 or not WorldMapScript.region_at(q).walkable or (protected_check.is_valid() and protected_check.call(q)):
				fits = false
				break
		if not fits:
			continue
		for cl in _landmark_clearings:
			if c.distance_to(cl[0]) < float(cl[1]) + radius:
				fits = false
		for cl in state.clearings:
			if c.distance_to(cl[0]) < float(cl[1]) + radius:
				fits = false
		if c.distance_to(spawn) < radius + PLAYER_CLEARANCE:
			fits = false
		if not fits:
			continue
		var tex: Texture2D = palette[spec.item]
		var s: float = float(spec.scale)
		if spec.has("ring"):
			for k in int(spec.ring):
				var a := TAU * float(k) / float(spec.ring)
				_decor_item(state, tex, c + Vector2(cos(a), sin(a)) * float(spec.radius), s, bool(spec.solid))
		else:
			for ix in cols:
				for iy in rows:
					_decor_item(state, tex, c - size * 0.5 + Vector2(float(ix) * spacing, float(iy) * spacing), s, bool(spec.solid))
		state.clearings.append([c, radius + 30.0])
		return

func _in_clearing(pos: Vector2, state: Dictionary) -> bool:
	for c in _landmark_clearings:
		if pos.distance_to(c[0]) < float(c[1]):
			return true
	for c in state.clearings:
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

# --- set pieces -------------------------------------------------------------------------------

# How much room each kind of set piece needs (also how far apart pieces are kept).
const POOL_COLORS := {
	"water": {"rim": Color(0.3, 0.5, 0.45), "fill": Color(0.2, 0.45, 0.75), "solid": true},
	"lava": {"rim": Color(0.25, 0.08, 0.05), "fill": Color(1.0, 0.45, 0.1), "solid": true},
	"bog": {"rim": Color(0.2, 0.25, 0.12), "fill": Color(0.28, 0.36, 0.16), "solid": false},
	"ice": {"rim": Color(0.75, 0.9, 1.0), "fill": Color(0.55, 0.8, 0.95), "solid": false},
	"void": {"rim": Color(0.1, 0.03, 0.2), "fill": Color(0.35, 0.1, 0.6), "solid": true},
}

func _place_features(state: Dictionary) -> void:
	var r: Dictionary = state.room
	var rng := RandomNumberGenerator.new()
	rng.seed = int(r.seed) + 11
	if r.props != null:                                  # a hand-made room says exactly where each piece stands
		for p in r.props:
			var kind := str(p[0])
			var radius: float = float(RoomsScript.FEATURE_RADIUS.get(kind, 260.0))
			var at: Vector2 = r.rect.position + Vector2(float(p[1]), float(p[2]))
			state.clearings.append([at, radius + 40.0])
			state.placed += 1
			_build_feature(state.structures, kind, str(p[3]) if p.size() > 3 else "water", at, radius, rng)
		return
	for entry in r.features:
		var kind := str(entry[0])
		var flavour := str(entry[2]) if entry.size() > 2 else "water"
		for i in int(entry[1]):
			var radius: float = float(RoomsScript.FEATURE_RADIUS.get(kind, 260.0))
			var at: Vector2 = _feature_spot(state, rng, radius)
			if at.x < 0.0:
				continue                                  # nowhere to put it (all water, the town...)
			state.clearings.append([at, radius + 40.0])
			state.placed += 1
			_build_feature(state.structures, kind, flavour, at, radius, rng)

func _feature_spot(state: Dictionary, rng: RandomNumberGenerator, radius: float) -> Vector2:
	var rect: Rect2 = state.room.rect
	var inner: Rect2 = rect.grow(-(radius + 100.0))
	var layout = state.layout
	for attempt in 150:
		var p: Vector2 = inner.position + Vector2(rng.randf(), rng.randf()) * inner.size
		var ok: bool = layout.sample(p) >= radius + 60.0   # the whole set piece stands on the floor
		if not ok:
			continue
		for off in [Vector2.ZERO, Vector2(radius * 0.8, 0), Vector2(-radius * 0.8, 0), Vector2(0, radius * 0.8), Vector2(0, -radius * 0.8)]:
			var q: Vector2 = p + off
			if not WorldMapScript.region_at(q).walkable or (protected_check.is_valid() and protected_check.call(q)):
				ok = false
				break
		if not ok:
			continue
		for c in _landmark_clearings:
			if p.distance_to(c[0]) < float(c[1]) + radius:
				ok = false
		for c in state.clearings:
			if p.distance_to(c[0]) < radius + float(c[1]):
				ok = false
		if p.distance_to(WorldMapScript.spawn_position()) < radius + PLAYER_CLEARANCE:
			ok = false
		if ok:
			return p
	return Vector2(-1.0, -1.0)

func _build_feature(parent: Node, kind: String, flavour: String, at: Vector2, radius: float, rng: RandomNumberGenerator) -> void:
	match kind:
		"clearing": _f_clearing(parent, at, radius, rng)
		"standing_stones": _f_standing_stones(parent, at, radius, rng)
		"farm": _f_farm(parent, at, rng)
		"pond": _f_pond(parent, at, radius, flavour, rng)
		"rock_formation": _f_rocks(parent, at, radius, rng)
		"camp": _f_camp(parent, at, radius, rng)
		"fallen_logs": _f_logs(parent, at, radius, rng)
		"ruin_walls": _f_ruin_walls(parent, at, radius, rng)
		"graves": _f_graves(parent, at, rng)
		"cliff_ridge": _f_ridge(parent, at, radius, rng)
		"mouth": _f_mouth(parent, at)
		"crystals": _f_crystals(parent, at, radius, rng)
		"lighthouse": _f_lighthouse(parent, at, radius, rng)
		"wreck": _wreck(parent, at, rng, false)

func _f_clearing(parent: Node, at: Vector2, radius: float, _rng: RandomNumberGenerator) -> void:
	_disc(parent, at, radius, Color(1.0, 0.98, 0.7, 0.10), -2, 28)
	for i in 8:                                       # a ring of flowers round one in the middle
		var a := TAU * float(i) / 8.0
		_sprite(parent, TUFT, at + Vector2(cos(a), sin(a)) * radius * 0.7, 2.5, Color(1.0, 0.95, 0.6))
	_sprite(parent, TUFT, at, 3.2, Color(1.0, 0.9, 0.5))

func _f_standing_stones(parent: Node, at: Vector2, radius: float, _rng: RandomNumberGenerator) -> void:
	_disc(parent, at, radius * 0.7, Color(0.1, 0.12, 0.1, 0.18), -2, 24)
	for i in 8:
		var a := TAU * float(i) / 8.0
		_box(parent, at + Vector2(cos(a), sin(a)) * radius * 0.62, Vector2(24, 76), Color(0.5, 0.5, 0.52), 0.0, true, 1)
	_box(parent, at, Vector2(70, 46), Color(0.42, 0.42, 0.45), 0.0, true, 1)

# A fenced yard gone to ruin: a square of fence with a gate on the south side, the walls of the old house, haystacks in
# a row.
func _f_farm(parent: Node, at: Vector2, _rng: RandomNumberGenerator) -> void:
	var half := 300.0
	var step := 78.0
	for side in 4:
		for i in int(2.0 * half / step):
			var t: float = -half + step * float(i) + step / 2.0
			var p := Vector2.ZERO
			match side:
				0: p = Vector2(t, -half)
				1: p = Vector2(half, t)
				2: p = Vector2(-t, half)
				3: p = Vector2(-half, -t)
			if side == 2 and absf(t) < step:
				continue                                  # the gate
			_box(parent, at + p, Vector2(10, 26), Color(0.4, 0.28, 0.15), 0.0, true, 1)
			_box(parent, at + p, Vector2(step, 6), Color(0.52, 0.38, 0.2), 0.0 if side % 2 == 0 else PI / 2.0, false, 0)
	var wall := Color(0.45, 0.4, 0.34)
	_box(parent, at + Vector2(-130, -150), Vector2(150, 16), wall, 0.0, true, 1)
	_box(parent, at + Vector2(-205, -100), Vector2(16, 100), wall, 0.0, true, 1)
	_box(parent, at + Vector2(-55, -100), Vector2(16, 100), wall, 0.0, true, 1)
	for i in 3:
		_disc(parent, at + Vector2(60 + 70 * i, 120), 22.0, Color(0.85, 0.72, 0.3), 0, 12)

func _blob(radius: float, rng: RandomNumberGenerator, count: int = 22, low: float = 0.7) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in count:
		var a := TAU * float(i) / float(count)
		pts.append(Vector2(cos(a), sin(a)) * radius * (low + rng.randf() * (1.0 - low)))
	return pts

func _scaled(pts: PackedVector2Array, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p * k)
	return out

# A pool of water / lava / bog / ice / void. The deep kinds (water, lava, void) block the way.
func _f_pond(parent: Node, at: Vector2, radius: float, flavour: String, rng: RandomNumberGenerator) -> void:
	var look: Dictionary = POOL_COLORS.get(flavour, POOL_COLORS["water"])
	var blob := _blob(radius, rng, 22, 0.82)
	var holder := Node2D.new()
	holder.position = at
	parent.add_child(holder)
	_poly(holder, _scaled(blob, 1.18), look.rim, -1)
	_poly(holder, blob, look.fill, 0)
	_poly(holder, _scaled(blob, 0.6), Color(look.fill).lightened(0.18), 0)
	if bool(look.solid):
		var body := StaticBody2D.new()
		var shape := CollisionPolygon2D.new()
		shape.polygon = _scaled(blob, 0.92)
		body.add_child(shape)
		holder.add_child(body)
	if flavour == "water" or flavour == "bog":
		for i in 10:                                      # reeds at even spacing round the edge
			var a := TAU * float(i) / 10.0
			_sprite(parent, TUFT, at + Vector2(cos(a), sin(a)) * radius * 1.12, 2.5, Color(0.6, 0.9, 0.5))

# Boulders in a neat cluster: a big one with two smaller either side and two more behind it.
func _f_rocks(parent: Node, at: Vector2, _radius: float, _rng: RandomNumberGenerator) -> void:
	for entry in [[Vector2(0, 0), 7.0], [Vector2(-150, 50), 5.0], [Vector2(150, 50), 5.0], [Vector2(-70, -110), 4.0], [Vector2(70, -110), 4.0]]:
		_sprite(parent, ROCK, at + entry[0], entry[1], Color(0.72, 0.7, 0.68), 7.0 * float(entry[1]), 0)

# Three tents at even angles round a fire, a log beside each.
func _f_camp(parent: Node, at: Vector2, radius: float, _rng: RandomNumberGenerator) -> void:
	_disc(parent, at + Vector2(0, 30), radius * 0.6, Color(0.25, 0.2, 0.1, 0.25), -2, 20)
	_disc(parent, at, 44.0, Color(0.1, 0.07, 0.04, 0.5), 0, 14)
	_disc(parent, at, 22.0, Color(0.95, 0.5, 0.12), 1, 12)
	for i in 3:
		var a := -PI / 2.0 + TAU * float(i) / 3.0
		var c := at + Vector2(cos(a), sin(a)) * radius * 0.62
		_poly(parent, PackedVector2Array([c + Vector2(0, -52), c + Vector2(48, 30), c + Vector2(-48, 30)]), Color(0.45, 0.4, 0.28), 1)
		_poly(parent, PackedVector2Array([c + Vector2(0, -10), c + Vector2(14, 30), c + Vector2(-14, 30)]), Color(0.12, 0.1, 0.08), 2)
		_box(parent, at + Vector2(cos(a + PI / 3.0), sin(a + PI / 3.0)) * 80.0, Vector2(54, 14), Color(0.32, 0.22, 0.12), a + PI / 3.0 + PI / 2.0, false, 0)

# A stack of logs, side by side.
func _f_logs(parent: Node, at: Vector2, _radius: float, _rng: RandomNumberGenerator) -> void:
	for i in 4:
		_box(parent, at + Vector2(0, (float(i) - 1.5) * 38.0), Vector2(220, 28), Color(0.3, 0.2, 0.1), 0.0, true, 0)

# Two ruined buildings: four broken walls each, with a doorway on the south side, and rubble at the corners.
func _f_ruin_walls(parent: Node, at: Vector2, _radius: float, _rng: RandomNumberGenerator) -> void:
	var wall := Color(0.42, 0.4, 0.37)
	for building in [[Vector2(-130, 0), Vector2(230, 170)], [Vector2(150, 40), Vector2(150, 120)]]:
		var c: Vector2 = at + building[0]
		var hx: float = float(building[1].x) * 0.5
		var hy: float = float(building[1].y) * 0.5
		_box(parent, c + Vector2(0, -hy), Vector2(hx * 2.0, 16), wall, 0.0, true, 0)
		_box(parent, c + Vector2(-hx, 0), Vector2(16, hy * 2.0), wall, 0.0, true, 0)
		_box(parent, c + Vector2(hx, 0), Vector2(16, hy * 1.2), wall, 0.0, true, 0)
		_box(parent, c + Vector2(-hx * 0.55, hy), Vector2(hx * 0.9, 16), wall, 0.0, true, 0)
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			_sprite(parent, ROCK, c + Vector2(hx * corner.x, hy * corner.y) * 1.15, 2.4, Color(0.7, 0.68, 0.64))

func _f_graves(parent: Node, at: Vector2, _rng: RandomNumberGenerator) -> void:
	for ix in 5:
		for iy in 3:
			_box(parent, at + Vector2((ix - 2) * 70.0, (iy - 1) * 70.0), Vector2(14, 30), Color(0.34, 0.34, 0.38), 0.0, false, 0)
	_sprite(parent, DEAD_TREE, at + Vector2(0, -150), 2.6, Color(0.75, 0.72, 0.68), 8.0 * 2.6)

# A straight line of boulders across part of the room, with a gap in the middle to walk through.
func _f_ridge(parent: Node, at: Vector2, radius: float, rng: RandomNumberGenerator) -> void:
	var dir := Vector2.RIGHT if rng.randf() < 0.5 else Vector2.DOWN
	var length := radius * 2.0
	var t := 0.0
	while t <= length:
		if absf(t - length * 0.5) > 150.0:
			_sprite(parent, ROCK, at - dir * radius + dir * t, 6.5, Color(0.6, 0.58, 0.56), 7.0 * 6.5, 0)
		t += 78.0

func _f_mouth(parent: Node, at: Vector2) -> void:
	_sprite(parent, ROCK, at, 12.0, Color(0.7, 0.68, 0.66), 7.0 * 12.0, 0)
	_poly(parent, PackedVector2Array([at + Vector2(-46, 84), at + Vector2(-30, 20), at + Vector2(0, 0), at + Vector2(30, 20), at + Vector2(46, 84)]), Color(0.03, 0.03, 0.04), 1)

# Gull Rock's lighthouse: a white tower with two red bands, a gallery, a lamp and a roof, on a base nothing can walk through.
func _f_lighthouse(parent: Node, at: Vector2, _radius: float, _rng: RandomNumberGenerator) -> void:
	var k := 0.8
	var white := Color(0.92, 0.9, 0.84)
	var red := Color(0.7, 0.15, 0.13)
	var bottom := 10.0
	var top := -330.0
	var half := func(y: float) -> float: return lerpf(70.0, 44.0, (bottom - y) / (bottom - top)) * k
	var bands := [[10.0, -70.0, white], [-70.0, -140.0, red], [-140.0, -210.0, white], [-210.0, -280.0, red], [-280.0, -330.0, white]]
	for b in bands:
		var y0: float = b[0]
		var y1: float = b[1]
		_poly(parent, PackedVector2Array([at + Vector2(-half.call(y0), y0 * k), at + Vector2(half.call(y0), y0 * k), at + Vector2(half.call(y1), y1 * k), at + Vector2(-half.call(y1), y1 * k)]), b[2], 1)
	_box(parent, at + Vector2(0, -338.0 * k), Vector2(140.0 * k, 14.0 * k), Color(0.25, 0.22, 0.2), 0.0, false, 1)
	_box(parent, at + Vector2(0, -368.0 * k), Vector2(60.0 * k, 46.0 * k), Color(1.0, 0.93, 0.6), 0.0, false, 1)
	_poly(parent, PackedVector2Array([at + Vector2(-48.0 * k, -391.0 * k), at + Vector2(48.0 * k, -391.0 * k), at + Vector2(0, -440.0 * k)]), red, 1)
	_disc(parent, at + Vector2(0, -368.0 * k), 130.0 * k, Color(1.0, 0.95, 0.6, 0.22), 2, 20)
	_box(parent, at + Vector2(0, 0), Vector2(120.0 * k, 40.0 * k), Color(0, 0, 0, 0), 0.0, true, 0)

# Crystals in an even row, alternately tall and short.
func _f_crystals(parent: Node, at: Vector2, _radius: float, _rng: RandomNumberGenerator) -> void:
	for i in 5:
		var s := 5.0 if i % 2 == 0 else 4.0
		_sprite(parent, CRYSTAL, at + Vector2((float(i) - 2.0) * 110.0, 0), s, Color(0.8, 0.5, 1.3), 4.0 * s, 1)

func _build_room_landmarks(state: Dictionary) -> void:
	var r: Dictionary = state.room
	for lid in r.landmarks:
		var l: Dictionary = WorldMapScript.landmark(lid)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(lid) ^ WorldMapScript.MAP_SEED
		var parent: Node2D = state.structures
		match lid:
			"heartwood": _heartwood(parent, l.pos, rng)
			"ruins": _ruins(parent, l.pos, rng)
			"lizen_encampment": _lizen(parent, l.pos, rng)
			"pesca": _pesca(parent, l.pos, rng)
			"ranch": _ranch(parent, l.pos, rng)
			"leviathan_shore": _wreck(parent, l.pos, rng)
			"frozen_spire": _spire(parent, l.pos, rng)
			"crater": _crater(parent, l.pos, rng)
			"void_throne": _throne(parent, l.pos, rng)
			"caves": _caves(parent, l.pos, rng)

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
func _heartwood(parent: Node, pos: Vector2, _rng: RandomNumberGenerator) -> void:
	_disc(parent, pos, 1050.0, Color(0.05, 0.12, 0.06, 0.45), -2, 36)
	_disc(parent, pos, 620.0, Color(0.08, 0.2, 0.1, 0.4), -2, 30)
	# eight roots spreading evenly from the trunk
	for i in 8:
		var a := TAU * float(i) / 8.0
		_box(parent, pos + Vector2(cos(a), sin(a)) * 330.0 + Vector2(0, 260), Vector2(380, 46), Color(0.22, 0.14, 0.08), a, false, -1)
	_sprite(parent, TREE, pos, 32.0, Color(0.7, 0.95, 0.7), 8.0 * 32.0 * 0.62, 2)
	# two rings of guardian trees, evenly spaced
	for i in 16:
		var a := TAU * float(i) / 16.0
		_sprite(parent, TREE, pos + Vector2(cos(a), sin(a)) * 1300.0, 7.5, Color(0.6, 0.9, 0.62), 8.0 * 7.5, 1)
	for i in 8:
		var a := TAU * (float(i) + 0.5) / 8.0
		_sprite(parent, TREE, pos + Vector2(cos(a), sin(a)) * 900.0, 5.0, Color(0.65, 0.92, 0.66), 8.0 * 5.0, 1)

# A settlement where everyone is dead: broken walls, rubble, bare trees and a few grave markers. Sized for a
# 32 px player: a ruined house is ~150 px across.
func _ruins(parent: Node, pos: Vector2, _rng: RandomNumberGenerator) -> void:
	_disc(parent, pos, 1100.0, Color(0.2, 0.2, 0.18, 0.3), -2, 32)
	var wall := Color(0.42, 0.4, 0.37)
	# four ruined houses round a well: three standing walls each and a doorway facing the well
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var c: Vector2 = pos + Vector2(corner.x * 480.0, corner.y * 300.0)
		var hx := 150.0
		var hy := 105.0
		_box(parent, c + Vector2(0, corner.y * hy), Vector2(hx * 2.0, 16), wall, 0.0, true, 0)           # the far wall
		_box(parent, c + Vector2(-hx, 0), Vector2(16, hy * 2.0), wall, 0.0, true, 0)
		_box(parent, c + Vector2(hx, 0), Vector2(16, hy * 2.0), wall, 0.0, true, 0)
		_box(parent, c + Vector2(-corner.x * hx * 0.6, -corner.y * hy), Vector2(hx * 0.8, 16), wall, 0.0, true, 0)   # the wall facing the well, with a doorway beside it
		for k in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			_sprite(parent, ROCK, c + Vector2(hx * k.x, hy * k.y) * 1.1, 2.4, Color(0.7, 0.68, 0.64))
	# the well
	_disc(parent, pos, 54.0, Color(0.3, 0.3, 0.33), 0, 18)
	_disc(parent, pos, 34.0, Color(0.1, 0.12, 0.2), 1, 14)
	# graves in two neat rows north of the well, a bare tree at each end
	for ix in 6:
		for iy in 2:
			_box(parent, pos + Vector2((float(ix) - 2.5) * 80.0, -560.0 - float(iy) * 80.0), Vector2(14, 30), Color(0.3, 0.3, 0.32), 0.0, false, 0)
	for side in [-1.0, 1.0]:
		_sprite(parent, DEAD_TREE, pos + Vector2(side * 380.0, -600.0), 2.6, Color(0.75, 0.72, 0.68), 8.0 * 2.6)
		_sprite(parent, DEAD_TREE, pos + Vector2(side * 800.0, 0.0), 2.6, Color(0.75, 0.72, 0.68), 8.0 * 2.6)

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
func _wreck(parent: Node, pos: Vector2, _rng: RandomNumberGenerator, on_beach: bool = true) -> void:
	_poly(parent, PackedVector2Array([pos + Vector2(-240, 0), pos + Vector2(240, -40), pos + Vector2(190, 76), pos + Vector2(-190, 96)]), Color(0.3, 0.2, 0.12), 0)
	_box(parent, pos + Vector2(26, -110), Vector2(12, 170), Color(0.4, 0.3, 0.2), 0.15, false, 1)
	_box(parent, pos + Vector2(70, -96), Vector2(96, 76), Color(0.8, 0.78, 0.7, 0.8), 0.15, false, 1)
	if on_beach:                                         # a neat row of rocks along the keel (a wreck standing in the sea has none)
		for i in 5:
			_sprite(parent, ROCK, pos + Vector2(-100.0 + 200.0 * float(i), 240), 2.6, Color(0.8, 0.85, 0.9))

# The White Spire: shards of ice.
func _spire(parent: Node, pos: Vector2, rng: RandomNumberGenerator) -> void:
	for i in 7:
		var a := TAU * float(i) / 7.0
		var c := pos + Vector2(cos(a), sin(a)) * (240.0 + rng.randf() * 110.0)
		_poly(parent, PackedVector2Array([c + Vector2(-40, 40), c + Vector2(0, -170 - rng.randf() * 80.0), c + Vector2(40, 40)]), Color(0.75, 0.9, 1.0, 0.9), 1)
	_sprite(parent, CRYSTAL, pos, 6.5, Color(0.7, 0.9, 1.3), 8.0 * 6.5 * 0.5, 1)

# The Crater: pools of lava around the Red Wyrm's nest.
func _crater(parent: Node, pos: Vector2, _rng: RandomNumberGenerator) -> void:
	_disc(parent, pos, 1050.0, Color(0.15, 0.04, 0.03, 0.45), -2, 30)
	# eight pools of lava evenly round the nest, each too hot to walk through
	for i in 8:
		var a := TAU * float(i) / 8.0 + PI / 8.0
		var c := pos + Vector2(cos(a), sin(a)) * 640.0
		_disc(parent, c, 130.0, Color(1.0, 0.5, 0.08, 0.95), -1, 16)
		_disc(parent, c, 85.0, Color(1.0, 0.8, 0.3, 0.9), -1, 14)
		var body := StaticBody2D.new()
		body.position = c
		var collision := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 115.0
		collision.shape = shape
		body.add_child(collision)
		parent.add_child(body)
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
