extends RefCounted
class_name RoomLayout

# The SHAPE of one room: where you can walk and where the land is solid (forest, rock, water, lava, abyss...).
#
# A room is a rectangle (Rooms.gd) but what is inside it is not: a glade, a winding path through the trees, a ring
# around a pool, a canyon, a network of islands, an open field with lakes... Each room is given one of those
# "archetypes" and builds its floor out of a few primitive shapes (discs, ellipses, boxes, tapered strokes) whose
# signed distances are combined into one FIELD sampled on a coarse grid: field > 0 is floor, field < 0 is solid, and
# its size is roughly the distance (in px) to the nearest edge of the floor. A field makes the awkward things easy:
# smooth organic outlines (marching squares for the collision walls, a shader for the picture), "is this spot clear
# by 200 px?", and a guarantee that the exits are connected to each other.
#
# Where a room meets its neighbours, the way through is fixed by the edge (Rooms.edges: open, wide or a gap), the
# same from both sides: every room's floor reaches the edge only through those openings, in the same straight
# stripe, so the two rooms line up exactly.
#
# Pure data and geometry (no scene), so it can be tested on its own. EVERY number here is a DRAFT.

const CELL := 80.0              # grid spacing (px)
const RANGE := 256.0            # the picture / image holds the field between -RANGE and +RANGE
const OUTSIDE := 200.0          # an exit's stripe reaches this far out of the room (so the edge nodes are inside it)
const EXIT_STRAIGHT := 300.0    # ...and runs straight this far into it (both rooms agree on this part)
const EXIT_TAPER := 320.0       # then narrows to a path over this much
const NOISE_BIG := 54.0         # the outline wobbles by about this much
const NOISE_SMALL := 18.0
const EDGE_CALM := 340.0        # no wobble this close to the room's own edge (neighbours must agree there)
const INSET := 320.0            # the floor stays this far from the room's edge, except through the exits

var room_id := ""
var archetype := "open"
var rect := Rect2()
var cols := 1
var rows := 1
var step := Vector2.ONE
var field := PackedFloat32Array()
var exits: Array = []            # [{pos, n, width}]: the openings on the room's edge (pos on the edge, n points inward)
var repairs := 0                 # how many paths had to be carved to keep everything connected
var floor_fraction := 0.0

var _inset := INSET
var _needs := 0.0                 # the biggest set piece the room has to hold (radius)
var room_shape: Array = []            # the hand-made floor (RoomData.gd), for an "authored" layout
var _core: Array = []
var _cuts: Array = []
var _bridges: Array = []
var _skeleton: Array = []
var _exit_shapes: Array = []
var _fixes: Array = []
var _rng := RandomNumberGenerator.new()
var _segments := PackedVector2Array()
var _segments_built := false

# discs: [[center, radius], ...] places that must be floor (the landmark structures).
static func generate(room: Dictionary, exit_list: Array, discs: Array) -> RoomLayout:
	var layout := RoomLayout.new()
	layout._make(room, exit_list, discs)
	return layout

func _make(room: Dictionary, exit_list: Array, discs: Array) -> void:
	room_id = str(room.id)
	archetype = str(room.get("layout", "open"))
	rect = room.rect
	cols = maxi(4, int(round(rect.size.x / CELL)))
	rows = maxi(4, int(round(rect.size.y / CELL)))
	step = Vector2(rect.size.x / float(cols), rect.size.y / float(rows))
	exits = exit_list
	_rng.seed = int(room.seed)
	_inset = 140.0 if not discs.is_empty() else INSET
	_needs = float(room.get("needs", 0.0))
	room_shape = room.get("shape", [])
	_build_archetype()
	for d in discs:
		_core.append(_s_disc(d[0], float(d[1])))
	_build_exits()
	_fill_field()
	_repair(discs)

# --- shapes ------------------------------------------------------------------------------------

static func _s_disc(c: Vector2, r: float) -> Dictionary:
	return {"k": "disc", "c": c, "r": r, "bb": Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0).grow(RANGE)}

static func _s_ell(c: Vector2, rx: float, ry: float) -> Dictionary:
	return {"k": "ell", "c": c, "rx": rx, "ry": ry, "bb": Rect2(c - Vector2(rx, ry), Vector2(rx, ry) * 2.0).grow(RANGE)}

# A box (half sizes hx, hy), corners rounded by rad, turned by ang radians.
static func _s_box(c: Vector2, hx: float, hy: float, rad: float = 0.0, ang: float = 0.0) -> Dictionary:
	var reach := Vector2(hx, hy).length() if ang != 0.0 else 0.0
	var bounds := Rect2(c - Vector2(hx, hy), Vector2(hx, hy) * 2.0) if ang == 0.0 else Rect2(c - Vector2(reach, reach), Vector2(reach, reach) * 2.0)
	return {"k": "box", "c": c, "hx": hx, "hy": hy, "rad": rad, "ang": ang, "bb": bounds.grow(RANGE)}

# A polygon (points in order).
static func _s_poly(points: PackedVector2Array) -> Dictionary:
	var bounds := Rect2(points[0], Vector2.ZERO)
	for p in points:
		bounds = bounds.expand(p)
	return {"k": "poly", "pts": points, "bb": bounds.grow(RANGE)}

static func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	var t := 0.0 if len2 < 0.001 else clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)

# A stroke from a to b whose width runs from wa to wb (round ends).
static func _s_seg(a: Vector2, b: Vector2, wa: float, wb: float) -> Dictionary:
	return {"k": "seg", "a": a, "b": b, "wa": wa, "wb": wb, "bb": Rect2(a, Vector2.ZERO).expand(b).grow(maxf(wa, wb) * 0.5 + RANGE)}

static func _prim(s: Dictionary, p: Vector2) -> float:
	match s.k:
		"disc":
			return float(s.r) - p.distance_to(s.c)
		"ell":
			var q := Vector2((p.x - s.c.x) / float(s.rx), (p.y - s.c.y) / float(s.ry))
			return (1.0 - q.length()) * minf(float(s.rx), float(s.ry))
		"box":
			var d: Vector2 = p - s.c
			if float(s.ang) != 0.0:
				d = d.rotated(-float(s.ang))
			var rad := float(s.rad)
			var q := Vector2(absf(d.x), absf(d.y)) - Vector2(float(s.hx) - rad, float(s.hy) - rad)
			return -(Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - rad)
		"poly":
			var pts: PackedVector2Array = s.pts
			var best := 1.0e9
			for i in pts.size():
				best = minf(best, _dist_to_segment(p, pts[i], pts[(i + 1) % pts.size()]))
			return best if Geometry2D.is_point_in_polygon(p, pts) else -best
		_:
			var ab: Vector2 = s.b - s.a
			var len2 := ab.length_squared()
			var t := 0.0 if len2 < 0.001 else clampf((p - s.a).dot(ab) / len2, 0.0, 1.0)
			var w: float = lerpf(float(s.wa), float(s.wb), t)
			return w * 0.5 - p.distance_to(s.a + ab * t)

# --- archetypes ---------------------------------------------------------------------------------

func _rand_in(r: Rect2) -> Vector2:
	return r.position + Vector2(_rng.randf(), _rng.randf()) * r.size

func _clamp_in(p: Vector2, r: Rect2) -> Vector2:
	return Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))

func _build_archetype() -> void:
	var c := rect.get_center()
	var w := rect.size.x
	var h := rect.size.y
	var inner := rect.grow(-_inset)
	match archetype:
		"glade": _a_glade(c, w, h)
		"twin_glades": _a_twin(c, w, h)
		"winding_path": _a_path(w, h, inner)
		"crossroads": _a_cross(c, w, h, inner)
		"ring": _a_ring(c, w, h, false)
		"horseshoe": _a_ring(c, w, h, true)
		"canyon": _a_canyon(c, w, h, inner)
		"l_shape": _a_l(inner)
		"branch": _a_network(w, h, inner, false)
		"islands": _a_network(w, h, inner, true)
		"lakes": _a_lakes(c, w, h, "lake")
		"groves": _a_lakes(c, w, h, "grove")
		"mesa_field": _a_lakes(c, w, h, "mesa")
		"river_lake": _a_river(c, w, h, inner)
		"authored": _a_authored(room_shape)
		_:
			_core.append(_s_box(c, w, h))
			_skeleton = [c]

func _a_glade(c: Vector2, w: float, h: float) -> void:
	var rx := maxf(_rng.randf_range(0.27, 0.40) * w, _needs + 220.0)
	var ry := maxf(_rng.randf_range(0.27, 0.40) * h, _needs + 220.0)
	var mid := c + Vector2(_rng.randf_range(-0.1, 0.1) * w, _rng.randf_range(-0.1, 0.1) * h)
	_core.append(_s_ell(mid, rx, ry))
	for i in _rng.randi_range(1, 3):
		var a := _rng.randf() * TAU
		_core.append(_s_disc(mid + Vector2(cos(a) * rx * 0.85, sin(a) * ry * 0.85), _rng.randf_range(0.28, 0.45) * minf(rx, ry) + 120.0))
	_skeleton = [mid]

func _a_twin(c: Vector2, w: float, h: float) -> void:
	var horizontal := w >= h
	var axis := Vector2.RIGHT if horizontal else Vector2.DOWN
	var cross := Vector2.DOWN if horizontal else Vector2.RIGHT
	var span := (w if horizontal else h) * _rng.randf_range(0.2, 0.28)
	var drift := cross * _rng.randf_range(-0.12, 0.12) * (h if horizontal else w)
	var c1 := c - axis * span + drift
	var c2 := c + axis * span - drift
	var r1 := maxf(_rng.randf_range(0.2, 0.3) * minf(w, h), (_needs + 220.0) / 0.9)
	var r2 := maxf(_rng.randf_range(0.2, 0.3) * minf(w, h), (_needs + 220.0) / 0.9)
	_core.append(_s_ell(c1, r1 * 1.15, r1 * 0.9))
	_core.append(_s_ell(c2, r2 * 1.15, r2 * 0.9))
	var neck := _rng.randf_range(340.0, 520.0)
	_core.append(_s_seg(c1, c2, neck, neck))
	_skeleton = [c1, c2, (c1 + c2) * 0.5]

func _a_path(w: float, h: float, inner: Rect2) -> void:
	var a: Vector2
	var b: Vector2
	if exits.size() >= 2:
		a = _clamp_in(exits[0].pos + exits[0].n * 700.0, inner)
		b = _clamp_in(exits[exits.size() - 1].pos + exits[exits.size() - 1].n * 700.0, inner)
	elif exits.size() == 1:
		a = _clamp_in(exits[0].pos + exits[0].n * 700.0, inner)
		b = _clamp_in(inner.get_center() - exits[0].n * minf(w, h) * 0.3 + Vector2(_rng.randf_range(-0.2, 0.2) * w, _rng.randf_range(-0.2, 0.2) * h), inner)
	else:
		a = _rand_in(inner)
		b = _rand_in(inner)
	if a.distance_to(b) < 900.0:
		b = _clamp_in(a + (b - a).normalized() * 1500.0 if a != b else a + Vector2(1500, 0), inner)
	var dir := b - a
	var perp := Vector2(-dir.y, dir.x).normalized()
	var swing := minf(w, h) * 0.32
	var pts: Array = [a]
	var count := _rng.randi_range(2, 4)
	for i in count:
		var t := float(i + 1) / float(count + 1)
		pts.append(_clamp_in(a + dir * t + perp * _rng.randf_range(-1.0, 1.0) * swing, inner))
	pts.append(b)
	var width := _rng.randf_range(380.0, 560.0)
	for i in pts.size() - 1:
		_core.append(_s_seg(pts[i], pts[i + 1], width * _rng.randf_range(0.85, 1.2), width * _rng.randf_range(0.85, 1.2)))
	for i in range(1, pts.size() - 1):
		if _rng.randf() < 0.6:
			_core.append(_s_disc(pts[i], width * _rng.randf_range(0.8, 1.3)))
	_skeleton = pts

func _a_cross(c: Vector2, w: float, h: float, inner: Rect2) -> void:
	var mid := c + Vector2(_rng.randf_range(-0.12, 0.12) * w, _rng.randf_range(-0.12, 0.12) * h)
	mid = _clamp_in(mid, inner.grow(-500.0))
	var wd := _rng.randf_range(380.0, 520.0)
	var left := Vector2(inner.position.x + _rng.randf_range(0.0, 0.2) * inner.size.x, mid.y)
	var right := Vector2(inner.end.x - _rng.randf_range(0.0, 0.2) * inner.size.x, mid.y)
	var top := Vector2(mid.x, inner.position.y + _rng.randf_range(0.0, 0.2) * inner.size.y)
	var bottom := Vector2(mid.x, inner.end.y - _rng.randf_range(0.0, 0.2) * inner.size.y)
	_core.append(_s_seg(left, right, wd, wd))
	_core.append(_s_seg(top, bottom, wd * _rng.randf_range(0.8, 1.1), wd * _rng.randf_range(0.8, 1.1)))
	_core.append(_s_disc(mid, _rng.randf_range(380.0, 540.0)))
	_skeleton = [mid, left, right, top, bottom]

func _a_ring(c: Vector2, w: float, h: float, horseshoe: bool) -> void:
	var rx := _rng.randf_range(0.36, 0.44) * w
	var ry := _rng.randf_range(0.34, 0.44) * h
	var band := _rng.randf_range(400.0, 540.0)
	band = minf(band, minf(rx, ry) - 180.0)
	_core.append(_s_ell(c, rx, ry))
	_cuts.append(_s_ell(c, rx - band, ry - band))
	for i in 12:
		var a := TAU * float(i) / 12.0
		_skeleton.append(c + Vector2(cos(a) * (rx - band * 0.5), sin(a) * (ry - band * 0.5)))
	if horseshoe:
		var ang := _rng.randf() * TAU
		var dirv := Vector2.from_angle(ang)
		var w_cut := _rng.randf_range(220.0, 320.0)
		_cuts.append(_s_seg(c + dirv * (minf(rx, ry) * 0.5), c + dirv * (maxf(rx, ry) + 300.0), w_cut, w_cut))

func _a_canyon(c: Vector2, w: float, h: float, inner: Rect2) -> void:
	var horizontal := w >= h
	var n := _rng.randi_range(3, 5)
	var spread := (h if horizontal else w) * 0.2
	var pts: Array = []
	for i in n + 1:
		var t := float(i) / float(n)
		var off := _rng.randf_range(-spread, spread)
		if horizontal:
			pts.append(Vector2(lerpf(inner.position.x, inner.end.x, t), c.y + off))
		else:
			pts.append(Vector2(c.x + off, lerpf(inner.position.y, inner.end.y, t)))
	var width := maxf(_rng.randf_range(560.0, 820.0), _needs * 2.0 + 260.0)
	for i in pts.size() - 1:
		_core.append(_s_seg(pts[i], pts[i + 1], width * _rng.randf_range(0.85, 1.15), width * _rng.randf_range(0.85, 1.15)))
	for i in _rng.randi_range(1, 2):
		var base: Vector2 = pts[_rng.randi_range(0, pts.size() - 1)]
		var side := Vector2(0, 1) if horizontal else Vector2(1, 0)
		_core.append(_s_disc(base + side * _rng.randf_range(-1.0, 1.0) * width * 0.9, _rng.randf_range(300.0, 480.0)))
	_skeleton = pts

func _a_l(inner: Rect2) -> void:
	var top := _rng.randf() < 0.5
	var left := _rng.randf() < 0.5
	var th := inner.size.y * _rng.randf_range(0.40, 0.52)
	var tw := inner.size.x * _rng.randf_range(0.28, 0.40)
	var bar_y := inner.position.y + th * 0.5 if top else inner.end.y - th * 0.5
	var bar_x := inner.position.x + tw * 0.5 if left else inner.end.x - tw * 0.5
	_core.append(_s_box(Vector2(inner.get_center().x, bar_y), inner.size.x * 0.5, th * 0.5))
	_core.append(_s_box(Vector2(bar_x, inner.get_center().y), tw * 0.5, inner.size.y * 0.5))
	_skeleton = [Vector2(inner.get_center().x, bar_y), Vector2(bar_x, inner.get_center().y), Vector2(bar_x, bar_y)]

# A handful of rounded places joined by paths (a thicket maze, a cave system), or -- `islands` -- bigger islands
# joined by narrow causeways across whatever fills the rest (water, bog, lava, the abyss).
func _a_network(w: float, h: float, inner: Rect2, islands: bool) -> void:
	var area := w * h
	var k := _rng.randi_range(5, 8) + (4 if area > 10.0e6 else 0)
	var min_dist := sqrt(area / (float(k) * 2.0))
	var field_rect := inner.grow(-300.0)
	var nodes: Array = []
	for attempt in 80:
		if nodes.size() >= k:
			break
		var p := _rand_in(field_rect)
		var ok := true
		for q in nodes:
			if p.distance_to(q) < min_dist:
				ok = false
		if ok:
			nodes.append(p)
	if nodes.size() < 3:
		nodes = [inner.get_center() - Vector2(500, 0), inner.get_center(), inner.get_center() + Vector2(500, 0)]
	var radius_lo := 330.0 if islands else 260.0
	var radius_hi := 560.0 if islands else 420.0
	var link_lo := 220.0 if islands else 300.0
	var link_hi := 300.0 if islands else 420.0
	for p in nodes:
		_core.append(_s_disc(p, _rng.randf_range(radius_lo, radius_hi)))
	# a minimum spanning tree (Prim), plus a few loops
	var linked: Array = [0]
	var pairs := {}
	while linked.size() < nodes.size():
		var best := 1.0e12
		var bi := -1
		var bj := -1
		for i in linked:
			for j in nodes.size():
				if j in linked:
					continue
				var d: float = nodes[i].distance_to(nodes[j])
				if d < best:
					best = d
					bi = i
					bj = j
		linked.append(bj)
		pairs[Vector2i(mini(bi, bj), maxi(bi, bj))] = true
	for i in _rng.randi_range(1, 3):
		var a := _rng.randi_range(0, nodes.size() - 1)
		var b := _rng.randi_range(0, nodes.size() - 1)
		if a != b and nodes[a].distance_to(nodes[b]) < min_dist * 2.2:
			pairs[Vector2i(mini(a, b), maxi(a, b))] = true
	for pair in pairs:
		var lw := _rng.randf_range(link_lo, link_hi)
		_core.append(_s_seg(nodes[pair.x], nodes[pair.y], lw, lw))
	_skeleton = nodes

# An open field with obstacles in it: lakes, groves of trees, or mesas. Kept clear of the room's edge so the
# openings stay open.
func _a_lakes(c: Vector2, w: float, h: float, kind: String) -> void:
	_core.append(_s_box(c, w, h))
	_skeleton = [c]
	var n := _rng.randi_range(2, 4)
	if w * h > 10.0e6:
		n += 3
	var placed: Array = []
	for attempt in n * 8:
		if placed.size() >= n:
			break
		var r := _rng.randf_range(260.0, 560.0) if kind == "lake" else _rng.randf_range(300.0, 700.0)
		var zone := rect.grow(-(520.0 + r * 0.8))
		if zone.size.x <= 0.0 or zone.size.y <= 0.0:
			continue
		var p := _rand_in(zone)
		var ok := true
		for q in placed:
			if p.distance_to(q[0]) < r + float(q[1]) + 360.0:
				ok = false
		if ok:
			placed.append([p, r])
	for q in placed:
		var p: Vector2 = q[0]
		var r: float = q[1]
		match kind:
			"lake":
				_cuts.append(_s_ell(p, r * _rng.randf_range(1.0, 1.5), r * _rng.randf_range(0.6, 1.0)))
			"grove":
				_cuts.append(_s_ell(p, r, r * _rng.randf_range(0.7, 1.0)))
				for i in _rng.randi_range(1, 3):
					var a := _rng.randf() * TAU
					_cuts.append(_s_disc(p + Vector2(cos(a), sin(a)) * r * 0.8, r * _rng.randf_range(0.4, 0.7)))
			_:
				if _rng.randf() < 0.5:
					_cuts.append(_s_box(p, r * _rng.randf_range(0.6, 1.0), r * _rng.randf_range(0.4, 0.7)))
				else:
					_cuts.append(_s_ell(p, r, r * 0.65))

# One long lake (or chasm, or lava stream) with its ends well inside the room, so there is a way round at both
# ends; sometimes a bridge across the middle.
func _a_river(c: Vector2, w: float, h: float, inner: Rect2) -> void:
	_core.append(_s_box(c, w, h))
	_skeleton = [c]
	var horizontal := w >= h
	var margin := 620.0
	var width := _rng.randf_range(260.0, 460.0)
	var jitter := (h if horizontal else w) * 0.18
	var pts: Array = []
	var n := _rng.randi_range(2, 4)
	for i in n + 1:
		var t := float(i) / float(n)
		var off := _rng.randf_range(-jitter, jitter)
		if horizontal:
			pts.append(Vector2(lerpf(rect.position.x + margin, rect.end.x - margin, t), c.y + off))
		else:
			pts.append(Vector2(c.x + off, lerpf(rect.position.y + margin, rect.end.y - margin, t)))
	for i in pts.size() - 1:
		_cuts.append(_s_seg(pts[i], pts[i + 1], width, width))
	if _rng.randf() < 0.6:
		var mid_i := pts.size() / 2
		var m: Vector2 = pts[mid_i]
		var across := Vector2(0, 1) if horizontal else Vector2(1, 0)
		_bridges.append(_s_seg(m - across * (width * 0.9), m + across * (width * 0.9), 200.0, 200.0))


# --- hand-authored shapes -----------------------------------------------------------------------

# The floor of a room drawn by hand (RoomData.gd): a list of ops in px from the room's top-left corner. A leading "-"
# cuts the shape out of the floor instead of adding it:
#   ["ell", cx, cy, rx, ry]            an ellipse
#   ["disc", cx, cy, r]                a disc
#   ["box", cx, cy, hx, hy, rad]       a box (half sizes), corners rounded by rad
#   ["rbox", cx, cy, hx, hy, deg, rad] the same, turned by deg degrees
#   ["path", width, x0, y0, x1, y1, ...] a stroke of that width through the points
#   ["poly", x0, y0, x1, y1, ...]      a polygon
func _a_authored(ops: Array) -> void:
	var o := rect.position
	for op in ops:
		var kind := str(op[0])
		var negative := kind.begins_with("-")
		var bridge := kind.begins_with("+")          # laid after the cuts: a causeway across a rift
		if negative or bridge:
			kind = kind.substr(1)
		var shapes: Array = []
		var focus: Array = []
		match kind:
			"ell":
				var c := o + Vector2(float(op[1]), float(op[2]))
				shapes.append(_s_ell(c, float(op[3]), float(op[4])))
				focus.append(c)
			"disc":
				var c2 := o + Vector2(float(op[1]), float(op[2]))
				shapes.append(_s_disc(c2, float(op[3])))
				focus.append(c2)
			"box", "rbox":
				var c3 := o + Vector2(float(op[1]), float(op[2]))
				var deg := float(op[5]) if kind == "rbox" else 0.0
				var rad := float(op[6]) if kind == "rbox" and op.size() > 6 else (float(op[5]) if kind == "box" and op.size() > 5 else 0.0)
				shapes.append(_s_box(c3, float(op[3]), float(op[4]), rad, deg_to_rad(deg)))
				focus.append(c3)
			"path":
				var width := float(op[1])
				var pts: Array = []
				for i in range(2, op.size() - 1, 2):
					pts.append(o + Vector2(float(op[i]), float(op[i + 1])))
				for i in pts.size() - 1:
					shapes.append(_s_seg(pts[i], pts[i + 1], width, width))
				focus.append_array(pts)
			"poly":
				var poly := PackedVector2Array()
				for i in range(1, op.size() - 1, 2):
					poly.append(o + Vector2(float(op[i]), float(op[i + 1])))
				shapes.append(_s_poly(poly))
				for p in poly:
					focus.append(p)
		for s in shapes:
			if negative:
				_cuts.append(s)
			elif bridge:
				_bridges.append(s)
			else:
				_core.append(s)
		if not negative and not bridge:
			_skeleton.append_array(focus)
	if _skeleton.is_empty():
		_skeleton = [rect.get_center()]

# --- exits and the field ------------------------------------------------------------------------

func _build_exits() -> void:
	var hub_default: Vector2 = rect.get_center()
	for e in exits:
		var width: float = float(e.width)
		var narrow: float = clampf(width * 0.35, 380.0, 900.0)
		narrow = minf(narrow, width)
		var p1: Vector2 = e.pos + e.n * EXIT_STRAIGHT
		var p2: Vector2 = e.pos + e.n * (EXIT_STRAIGHT + EXIT_TAPER)
		# the straight part is a box exactly as wide as the opening (no round ends to bulge into the corners)
		var half_depth := (EXIT_STRAIGHT + OUTSIDE) * 0.5
		var centre: Vector2 = e.pos + e.n * ((EXIT_STRAIGHT - OUTSIDE) * 0.5)
		var along_x: bool = absf(e.n.x) < 0.5
		_exit_shapes.append(_s_box(centre, width * 0.5 if along_x else half_depth, half_depth if along_x else width * 0.5))
		_exit_shapes.append(_s_seg(p1, p2, width, narrow))
		var hub := hub_default
		var best := 1.0e12
		for s in _skeleton:
			var d: float = p2.distance_to(s)
			if d < best:
				best = d
				hub = s
		_exit_shapes.append(_s_seg(p2, hub, narrow, narrow))

func _eval(p: Vector2, inset_box: Dictionary, noise_a: FastNoiseLite, noise_b: FastNoiseLite) -> float:
	var f := -RANGE * 2.0
	for s in _core:
		if s.bb.has_point(p):
			f = maxf(f, _prim(s, p))
	f = minf(f, _prim(inset_box, p))
	for s in _exit_shapes:
		if s.bb.has_point(p):
			f = maxf(f, _prim(s, p))
	for s in _cuts:
		if s.bb.has_point(p):
			f = minf(f, -_prim(s, p))
	for s in _bridges:
		if s.bb.has_point(p):
			f = maxf(f, _prim(s, p))
	var edge := minf(minf(p.x - rect.position.x, rect.end.x - p.x), minf(p.y - rect.position.y, rect.end.y - p.y))
	var calm := clampf((edge - EDGE_CALM) / 260.0, 0.0, 1.0)
	if calm > 0.0:
		f += calm * (noise_a.get_noise_2d(p.x, p.y) * NOISE_BIG + noise_b.get_noise_2d(p.x, p.y) * NOISE_SMALL)
	return clampf(f, -RANGE * 2.0, RANGE * 4.0)

func _fill_field() -> void:
	var noise_a := FastNoiseLite.new()
	noise_a.seed = int(_rng.seed)
	noise_a.frequency = 1.0 / 460.0
	var noise_b := FastNoiseLite.new()
	noise_b.seed = int(_rng.seed) + 17
	noise_b.frequency = 1.0 / 190.0
	var inset_box := _s_box(rect.get_center(), rect.size.x * 0.5 - _inset, rect.size.y * 0.5 - _inset)
	var stride := cols + 1
	field.resize(stride * (rows + 1))
	var floor_count := 0
	for j in rows + 1:
		for i in cols + 1:
			var p := rect.position + Vector2(float(i) * step.x, float(j) * step.y)
			var f := _eval(p, inset_box, noise_a, noise_b)
			field[j * stride + i] = f
			if f > 0.0:
				floor_count += 1
	floor_fraction = float(floor_count) / float(stride * (rows + 1))

# --- keeping it connected ----------------------------------------------------------------------

func _node_at(p: Vector2) -> int:
	var i := clampi(int(round((p.x - rect.position.x) / step.x)), 0, cols)
	var j := clampi(int(round((p.y - rect.position.y) / step.y)), 0, rows)
	return j * (cols + 1) + i

func _node_pos(index: int) -> Vector2:
	var stride := cols + 1
	return rect.position + Vector2(float(index % stride) * step.x, float(index / stride) * step.y)

# Labels every floor node with the number of the connected piece of floor it belongs to (-1 for solid ground).
func _components() -> PackedInt32Array:
	var stride := cols + 1
	var total := stride * (rows + 1)
	var labels := PackedInt32Array()
	labels.resize(total)
	labels.fill(-1)
	var next := 0
	var queue := PackedInt32Array()
	for start in total:
		if field[start] <= 0.0 or labels[start] != -1:
			continue
		labels[start] = next
		queue.clear()
		queue.append(start)
		var head := 0
		while head < queue.size():
			var n := queue[head]
			head += 1
			var x := n % stride
			var y := n / stride
			for nb in [n - 1 if x > 0 else -1, n + 1 if x < cols else -1, n - stride if y > 0 else -1, n + stride if y < rows else -1]:
				if nb >= 0 and field[nb] > 0.0 and labels[nb] == -1:
					labels[nb] = next
					queue.append(nb)
		next += 1
	return labels

func _apply_fix(shape: Dictionary) -> void:
	var stride := cols + 1
	for j in rows + 1:
		for i in cols + 1:
			var p := rect.position + Vector2(float(i) * step.x, float(j) * step.y)
			if shape.bb.has_point(p):
				field[j * stride + i] = maxf(field[j * stride + i], _prim(shape, p))
	_segments_built = false

func _repair(discs: Array) -> void:
	var required: Array = []
	for e in exits:
		required.append(e.pos + e.n * (EXIT_STRAIGHT * 0.5))
	for d in discs:
		required.append(d[0])
	if required.is_empty():
		return
	for attempt in 6:
		# every required point must itself be floor
		for q in required:
			if field[_node_at(q)] <= 0.0:
				_apply_fix(_s_disc(q, 260.0))
				repairs += 1
		var labels := _components()
		var main: int = labels[_node_at(required[0])]
		var fixed_any := false
		for q in required:
			if labels[_node_at(q)] == main:
				continue
			# carve a path from this point to the nearest piece of the main floor
			var best := 1.0e12
			var target := Vector2.ZERO
			for n in labels.size():
				if labels[n] == main:
					var d: float = _node_pos(n).distance_squared_to(q)
					if d < best:
						best = d
						target = _node_pos(n)
			_apply_fix(_s_seg(q, target, 380.0, 380.0))
			repairs += 1
			fixed_any = true
		if not fixed_any:
			break
	# whatever floor is still cut off from the exits is not reachable: make it solid
	var final_labels := _components()
	var keep: int = final_labels[_node_at(required[0])]
	for n in final_labels.size():
		if final_labels[n] != keep and final_labels[n] >= 0:
			field[n] = -8.0
	_segments_built = false

# --- queries -----------------------------------------------------------------------------------

# The field at a point (bilinear): positive = floor, about the distance in px to the nearest edge of the floor.
func sample(p: Vector2) -> float:
	var gx := (p.x - rect.position.x) / step.x
	var gy := (p.y - rect.position.y) / step.y
	if gx < 0.0 or gy < 0.0 or gx > float(cols) or gy > float(rows):
		return -RANGE
	var i := mini(int(gx), cols - 1)
	var j := mini(int(gy), rows - 1)
	var fx := gx - float(i)
	var fy := gy - float(j)
	var stride := cols + 1
	var a := field[j * stride + i]
	var b := field[j * stride + i + 1]
	var c := field[(j + 1) * stride + i]
	var d := field[(j + 1) * stride + i + 1]
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)

func is_floor(p: Vector2, margin: float = 0.0) -> bool:
	return sample(p) > margin

# A random spot at least `margin` px inside the floor ((-1,-1) if none turned up).
func floor_point(rng: RandomNumberGenerator, margin: float, area: Rect2 = Rect2()) -> Vector2:
	var zone: Rect2 = rect if area.size == Vector2.ZERO else area
	for attempt in 40:
		var p := zone.position + Vector2(rng.randf(), rng.randf()) * zone.size
		if sample(p) > margin:
			return p
	return Vector2(-1.0, -1.0)

# The outline of the floor: pairs of points (marching squares on the field), for the collision walls.
func segments() -> PackedVector2Array:
	if _segments_built:
		return _segments
	_segments = PackedVector2Array()
	var stride := cols + 1
	for j in rows:
		for i in cols:
			var f00 := field[j * stride + i]
			var f10 := field[j * stride + i + 1]
			var f01 := field[(j + 1) * stride + i]
			var f11 := field[(j + 1) * stride + i + 1]
			var code := (1 if f00 > 0.0 else 0) | (2 if f10 > 0.0 else 0) | (4 if f11 > 0.0 else 0) | (8 if f01 > 0.0 else 0)
			if code == 0 or code == 15:
				continue
			var x0 := rect.position.x + float(i) * step.x
			var y0 := rect.position.y + float(j) * step.y
			var top := Vector2(x0 + step.x * _cross(f00, f10), y0)
			var right := Vector2(x0 + step.x, y0 + step.y * _cross(f10, f11))
			var bottom := Vector2(x0 + step.x * _cross(f01, f11), y0 + step.y)
			var left := Vector2(x0, y0 + step.y * _cross(f00, f01))
			var pairs: Array = []
			match code:
				1, 14: pairs = [[left, top]]
				2, 13: pairs = [[top, right]]
				3, 12: pairs = [[left, right]]
				4, 11: pairs = [[right, bottom]]
				6, 9: pairs = [[top, bottom]]
				7, 8: pairs = [[left, bottom]]
				5:
					var inside := (f00 + f10 + f01 + f11) > 0.0
					pairs = [[top, right], [left, bottom]] if inside else [[left, top], [right, bottom]]
				10:
					var inside2 := (f00 + f10 + f01 + f11) > 0.0
					pairs = [[left, top], [right, bottom]] if inside2 else [[top, right], [left, bottom]]
			for pr in pairs:
				_segments.append(pr[0])
				_segments.append(pr[1])
	_segments_built = true
	return _segments

# The outline of the floor as chains of points (the segments above joined end to end), for lining the edge of the
# floor with something at even intervals. Chains can be closed loops (the last point equals the first).
func contours() -> Array:
	var segs := segments()
	var count := segs.size() / 2
	var adjacency := {}
	for k in count:
		for end in 2:
			var key := _key(segs[k * 2 + end])
			if not adjacency.has(key):
				adjacency[key] = []
			adjacency[key].append(k)
	var used := PackedByteArray()
	used.resize(count)
	var chains: Array = []
	for k in count:
		if used[k] == 1:
			continue
		used[k] = 1
		var forward := PackedVector2Array([segs[k * 2], segs[k * 2 + 1]])
		_extend_chain(forward, adjacency, segs, used)
		var backward := PackedVector2Array([forward[0]])
		# the start of the chain is extended the other way round
		var reversed := PackedVector2Array()
		for i in range(forward.size() - 1, -1, -1):
			reversed.append(forward[i])
		_extend_chain(reversed, adjacency, segs, used)
		chains.append(reversed)
	return chains

static func _key(p: Vector2) -> Vector2i:
	return Vector2i(int(round(p.x * 2.0)), int(round(p.y * 2.0)))

func _extend_chain(chain: PackedVector2Array, adjacency: Dictionary, segs: PackedVector2Array, used: PackedByteArray) -> void:
	while true:
		var tail_key := _key(chain[chain.size() - 1])
		var found := -1
		for k in adjacency.get(tail_key, []):
			if used[k] == 0:
				found = k
				break
		if found < 0:
			return
		used[found] = 1
		var a := segs[found * 2]
		var b := segs[found * 2 + 1]
		chain.append(b if _key(a) == tail_key else a)

# The direction toward the floor at a point (the field's gradient, normalised).
func toward_floor(p: Vector2) -> Vector2:
	var d := 8.0
	var g := Vector2(sample(p + Vector2(d, 0)) - sample(p - Vector2(d, 0)), sample(p + Vector2(0, d)) - sample(p - Vector2(0, d)))
	return g.normalized() if g.length() > 0.001 else Vector2.ZERO

# Where along an edge from value a to value b the field crosses zero (0..1).
static func _cross(a: float, b: float) -> float:
	if (a > 0.0) == (b > 0.0):
		return 0.5
	return clampf(a / (a - b), 0.0, 1.0)

# The field as an 8-bit image for the picture: 0.5 is the outline, brighter is floor, darker is deeper in the solid.
func to_image() -> Image:
	var img := Image.create(cols + 1, rows + 1, false, Image.FORMAT_R8)
	var stride := cols + 1
	for j in rows + 1:
		for i in cols + 1:
			var v := clampf(0.5 + field[j * stride + i] / (2.0 * RANGE), 0.0, 1.0)
			img.set_pixel(i, j, Color(v, 0.0, 0.0))
	return img
