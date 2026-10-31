extends RefCounted

# The Map Editor's geometry: a room's shape ops, decoration arrangements and set pieces turned into little editable MODELS (a
# dictionary with a centre, sizes, points...) and back into the exact list format of rooms.json. Everything here is in px from the
# ROOM'S TOP-LEFT CORNER, like the data. No scene, no UI: the editor, the overlay and the tests all use it.
#
# Shape model:   {mode: "floor" | "cut" | "bridge", kind: "ell" | "disc" | "box" | "path" | "poly", ...}
#   ell   c, rx, ry            disc  c, r            box  c, hx, hy, rad, deg (turned when deg != 0: "rbox")
#   path  width, pts           poly  pts
# Decor model:   {kind, item, c, cols, rows, spacing, a, b, count, radius, d}   (only the fields a kind uses)
# Prop model:    {kind, c, flavour}

const MapDataScript := preload("res://scripts/MapData.gd")

const MODE_PREFIX := {"floor": "", "cut": "-", "bridge": "+"}
const MODE_NAMES := {"floor": "Floor", "cut": "Cut", "bridge": "Bridge"}
const KIND_NAMES := {"ell": "Oval", "disc": "Circle", "box": "Box", "path": "Path", "poly": "Polygon"}
const DECOR_NAMES := {"orchard": "Orchard", "bed": "Flower bed", "boulders": "Boulders", "row": "Row", "ring": "Ring", "pair": "Pair"}
const ITEM_NAMES := {"tall": "Tall: trees, cacti", "small": "Small: bushes, rocks", "ground": "Ground cover", "stone": "Stones"}
const PROP_NAMES := {
	"clearing": "Clearing", "standing_stones": "Standing stones", "farm": "Farm", "pond": "Pond", "rock_formation": "Rock formation",
	"camp": "Camp", "fallen_logs": "Fallen logs", "ruin_walls": "Ruin walls", "graves": "Graves", "cliff_ridge": "Cliff ridge",
	"mouth": "Cave mouth", "crystals": "Crystals", "lighthouse": "Lighthouse", "wreck": "Shipwreck",
}
const FLAVOURS := ["water", "lava", "bog", "ice", "void"]
# How big each set piece is (the same table Rooms.gd uses to keep floor round them).
const PROP_RADIUS := {
	"clearing": 300.0, "standing_stones": 260.0, "farm": 420.0, "pond": 250.0, "rock_formation": 260.0, "camp": 330.0,
	"fallen_logs": 260.0, "ruin_walls": 340.0, "graves": 300.0, "cliff_ridge": 520.0, "mouth": 260.0, "crystals": 280.0,
	"lighthouse": 200.0, "wreck": 300.0,
}
const MASS_NAMES := {
	"": "None (blank)", "forest": "Forest (trees)", "thicket": "Thicket (bushes)", "pines": "Pines", "dead_forest": "Dead forest",
	"rock": "Rock", "sandstone": "Sandstone", "volcanic": "Volcanic rock", "crystal_rock": "Crystal rock", "water": "Water",
	"bog": "Bog", "ice": "Ice", "lava": "Lava", "abyss": "Abyss",
}

# --- numbers ---------------------------------------------------------------------------------------------------------------

# A number the way the data files write it: whole numbers as ints, at most two decimals.
static func n(v: float):
	var s := snappedf(v, 0.01)
	return int(s) if s == roundf(s) else s

static func snap(v: float, step: float) -> float:
	return snappedf(v, step) if step > 0.0 else v

static func snap_v(p: Vector2, step: float) -> Vector2:
	return Vector2(snap(p.x, step), snap(p.y, step))

# --- shape ops -----------------------------------------------------------------------------------------------------------------

# A data op -> its model.
static func parse_op(op: Array) -> Dictionary:
	var kind := str(op[0])
	var mode := "floor"
	if kind.begins_with("-"):
		mode = "cut"
		kind = kind.substr(1)
	elif kind.begins_with("+"):
		mode = "bridge"
		kind = kind.substr(1)
	var m := {"mode": mode, "kind": kind}
	match kind:
		"ell":
			m.c = Vector2(float(op[1]), float(op[2]))
			m.rx = float(op[3])
			m.ry = float(op[4])
		"disc":
			m.c = Vector2(float(op[1]), float(op[2]))
			m.r = float(op[3])
		"box", "rbox":
			m.kind = "box"
			m.c = Vector2(float(op[1]), float(op[2]))
			m.hx = float(op[3])
			m.hy = float(op[4])
			if kind == "rbox":
				m.deg = float(op[5])
				m.rad = float(op[6]) if op.size() > 6 else 0.0
			else:
				m.deg = 0.0
				m.rad = float(op[5]) if op.size() > 5 else 0.0
		"path":
			m.width = float(op[1])
			m.pts = _points(op, 2)
		"poly":
			m.pts = _points(op, 1)
	return m

static func _points(op: Array, from: int) -> Array:
	var pts: Array = []
	var i := from
	while i + 1 < op.size():
		pts.append(Vector2(float(op[i]), float(op[i + 1])))
		i += 2
	return pts

# A model -> the data op.
static func build_op(m: Dictionary) -> Array:
	var kind: String = m.kind
	var prefix: String = MODE_PREFIX.get(m.get("mode", "floor"), "")
	match kind:
		"ell":
			return [prefix + "ell", n(m.c.x), n(m.c.y), n(m.rx), n(m.ry)]
		"disc":
			return [prefix + "disc", n(m.c.x), n(m.c.y), n(m.r)]
		"box":
			if float(m.get("deg", 0.0)) != 0.0:
				return [prefix + "rbox", n(m.c.x), n(m.c.y), n(m.hx), n(m.hy), n(m.deg), n(m.rad)]
			return [prefix + "box", n(m.c.x), n(m.c.y), n(m.hx), n(m.hy), n(m.rad)]
		"path":
			var op: Array = [prefix + "path", n(m.width)]
			for p in m.pts:
				op.append(n(p.x))
				op.append(n(p.y))
			return op
		"poly":
			var op2: Array = [prefix + "poly"]
			for p in m.pts:
				op2.append(n(p.x))
				op2.append(n(p.y))
			return op2
	return []

static func default_op(kind: String, mode: String, centre: Vector2) -> Dictionary:
	var m := {"mode": mode, "kind": kind}
	match kind:
		"ell":
			m.c = centre
			m.rx = 500.0
			m.ry = 350.0
		"disc":
			m.c = centre
			m.r = 350.0
		"box":
			m.c = centre
			m.hx = 450.0
			m.hy = 300.0
			m.rad = 60.0
			m.deg = 0.0
		"path":
			m.width = 400.0
			m.pts = [centre - Vector2(500, 0), centre + Vector2(500, 0)]
		"poly":
			m.pts = [centre + Vector2(-400, 300), centre + Vector2(0, -400), centre + Vector2(400, 300)]
	return m

static func op_center(m: Dictionary) -> Vector2:
	if m.has("c"):
		return m.c
	var sum := Vector2.ZERO
	for p in m.pts:
		sum += p
	return sum / maxf(float(m.pts.size()), 1.0)

static func op_move(m: Dictionary, delta: Vector2) -> void:
	if m.has("c"):
		m.c += delta
	if m.has("pts"):
		for i in m.pts.size():
			m.pts[i] += delta

static func op_area(m: Dictionary) -> float:
	match m.kind:
		"ell":
			return PI * float(m.rx) * float(m.ry)
		"disc":
			return PI * float(m.r) * float(m.r)
		"box":
			return 4.0 * float(m.hx) * float(m.hy)
		"path":
			var length := 0.0
			for i in m.pts.size() - 1:
				length += m.pts[i].distance_to(m.pts[i + 1])
			return maxf(length, 1.0) * float(m.width)
		"poly":
			var a := 0.0
			for i in m.pts.size():
				var p: Vector2 = m.pts[i]
				var q: Vector2 = m.pts[(i + 1) % m.pts.size()]
				a += p.x * q.y - q.x * p.y
			return absf(a) * 0.5
	return 1.0

static func op_contains(m: Dictionary, p: Vector2) -> bool:
	match m.kind:
		"ell":
			var q := Vector2((p.x - m.c.x) / maxf(float(m.rx), 1.0), (p.y - m.c.y) / maxf(float(m.ry), 1.0))
			return q.length_squared() <= 1.0
		"disc":
			return p.distance_to(m.c) <= float(m.r)
		"box":
			var d: Vector2 = p - m.c
			if float(m.deg) != 0.0:
				d = d.rotated(-deg_to_rad(float(m.deg)))
			return absf(d.x) <= float(m.hx) and absf(d.y) <= float(m.hy)
		"path":
			for i in m.pts.size() - 1:
				if dist_to_segment(p, m.pts[i], m.pts[i + 1]) <= float(m.width) * 0.5:
					return true
			return false
		"poly":
			return m.pts.size() >= 3 and Geometry2D.is_point_in_polygon(p, PackedVector2Array(m.pts))
	return false

static func dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	var t := 0.0 if len2 < 0.001 else clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)

# The outline of the shape as a closed polygon (room-local px), for drawing.
static func op_outline(m: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	match m.kind:
		"ell":
			for i in 48:
				var a := TAU * float(i) / 48.0
				out.append(m.c + Vector2(cos(a) * float(m.rx), sin(a) * float(m.ry)))
		"disc":
			for i in 40:
				var a2 := TAU * float(i) / 40.0
				out.append(m.c + Vector2(cos(a2), sin(a2)) * float(m.r))
		"box":
			var hx: float = m.hx
			var hy: float = m.hy
			var rad: float = clampf(float(m.get("rad", 0.0)), 0.0, minf(hx, hy))
			var rot := deg_to_rad(float(m.get("deg", 0.0)))
			var corners := [Vector2(hx, hy), Vector2(-hx, hy), Vector2(-hx, -hy), Vector2(hx, -hy)]
			var starts := [0.0, PI * 0.5, PI, PI * 1.5]
			for ci in 4:
				var cc: Vector2 = corners[ci]
				var inner := Vector2(signf(cc.x) * (absf(cc.x) - rad), signf(cc.y) * (absf(cc.y) - rad))
				if rad <= 0.5:
					out.append((cc).rotated(rot) + m.c)
				else:
					for k in 7:
						var ang: float = float(starts[ci]) + PI * 0.5 * float(k) / 6.0
						out.append((inner + Vector2(cos(ang), sin(ang)) * rad).rotated(rot) + m.c)
		"path":
			var polys := Geometry2D.offset_polyline(PackedVector2Array(m.pts), maxf(float(m.width) * 0.5, 1.0), Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)
			if not polys.is_empty():
				return polys[0]
		"poly":
			return PackedVector2Array(m.pts)
	return out

# The squares to grab: [{id, pos}]. "c" moves, "e/w/n/s" stretch, "p<i>" is a point, "m<i>" a midpoint that adds a point when pulled,
# "r" the corner radius is only in the inspector.
static func op_handles(m: Dictionary) -> Array:
	var h: Array = []
	match m.kind:
		"ell":
			h = [{"id": "c", "pos": m.c}, {"id": "e", "pos": m.c + Vector2(m.rx, 0)}, {"id": "w", "pos": m.c - Vector2(m.rx, 0)},
				{"id": "n", "pos": m.c - Vector2(0, m.ry)}, {"id": "s", "pos": m.c + Vector2(0, m.ry)}]
		"disc":
			h = [{"id": "c", "pos": m.c}, {"id": "e", "pos": m.c + Vector2(m.r, 0)}]
		"box":
			var rot := deg_to_rad(float(m.get("deg", 0.0)))
			h = [{"id": "c", "pos": m.c}, {"id": "e", "pos": m.c + Vector2(m.hx, 0).rotated(rot)}, {"id": "w", "pos": m.c - Vector2(m.hx, 0).rotated(rot)},
				{"id": "n", "pos": m.c - Vector2(0, m.hy).rotated(rot)}, {"id": "s", "pos": m.c + Vector2(0, m.hy).rotated(rot)}]
		"path", "poly":
			for i in m.pts.size():
				h.append({"id": "p%d" % i, "pos": m.pts[i]})
			var last: int = m.pts.size() - (1 if m.kind == "path" else 0)
			for i in last:
				h.append({"id": "m%d" % i, "pos": (m.pts[i] as Vector2).lerp(m.pts[(i + 1) % m.pts.size()], 0.5)})
	return h

# Pulls handle `id` to room-local point `p` (already snapped by the caller if it should be). A midpoint handle turns into a real point
# first and returns the new handle's id ("p<i+1>") so the drag carries on with it.
static func op_drag(m: Dictionary, id: String, p: Vector2, step: float = 0.0) -> String:
	if id.begins_with("m"):
		var i := int(id.substr(1))
		var mid: Vector2 = (m.pts[i] as Vector2).lerp(m.pts[(i + 1) % m.pts.size()], 0.5)
		m.pts.insert(i + 1, mid)
		return op_drag(m, "p%d" % (i + 1), p, step)
	if id.begins_with("p"):
		m.pts[int(id.substr(1))] = p
		return id
	match id:
		"c":
			m.c = p
		"e", "w", "n", "s":
			var local: Vector2 = p - m.c
			if m.kind == "box" and float(m.get("deg", 0.0)) != 0.0:
				local = local.rotated(-deg_to_rad(float(m.deg)))
			match m.kind:
				"ell":
					if id == "e" or id == "w":
						m.rx = maxf(snap(absf(local.x), step), 20.0)
					else:
						m.ry = maxf(snap(absf(local.y), step), 20.0)
				"disc":
					m.r = maxf(snap(local.length(), step), 20.0)
				"box":
					if id == "e" or id == "w":
						m.hx = maxf(snap(absf(local.x), step), 20.0)
					else:
						m.hy = maxf(snap(absf(local.y), step), 20.0)
	return id

# --- decoration --------------------------------------------------------------------------------------------------------------------

# Hidden defaults (the same as OverworldMap uses when a list leaves them out).
const ORCHARD_SPACING := 112.0
const BOULDER_SPACING := 130.0
const BED_SPACING := 52.0

static func parse_decor(op: Array) -> Dictionary:
	var kind := str(op[0])
	var m := {"kind": kind}
	match kind:
		"orchard", "boulders", "bed":
			m.c = Vector2(float(op[1]), float(op[2]))
			m.cols = int(op[3])
			m.rows = int(op[4])
			m.spacing = float(op[5]) if op.size() > 5 else (BED_SPACING if kind == "bed" else (ORCHARD_SPACING if kind == "orchard" else BOULDER_SPACING))
			m.item = "tall" if kind == "orchard" else ("ground" if kind == "bed" else "stone")
		"row":
			m.item = str(op[1])
			m.a = Vector2(float(op[2]), float(op[3]))
			m.b = Vector2(float(op[4]), float(op[5]))
			m.spacing = float(op[6])
		"ring":
			m.item = str(op[1])
			m.c = Vector2(float(op[2]), float(op[3]))
			m.radius = float(op[4])
			m.count = int(op[5])
		"pair":
			m.item = str(op[1])
			m.c = Vector2(float(op[2]), float(op[3]))
			m.d = Vector2(float(op[4]), float(op[5]))
	return m

static func build_decor(m: Dictionary) -> Array:
	match m.kind:
		"orchard", "boulders":
			return [m.kind, n(m.c.x), n(m.c.y), int(m.cols), int(m.rows), n(m.spacing)]
		"bed":
			return ["bed", n(m.c.x), n(m.c.y), int(m.cols), int(m.rows)]
		"row":
			return ["row", m.item, n(m.a.x), n(m.a.y), n(m.b.x), n(m.b.y), n(m.spacing)]
		"ring":
			return ["ring", m.item, n(m.c.x), n(m.c.y), n(m.radius), int(m.count)]
		"pair":
			return ["pair", m.item, n(m.c.x), n(m.c.y), n(m.d.x), n(m.d.y)]
	return []

static func default_decor(kind: String, at: Vector2) -> Dictionary:
	match kind:
		"orchard":
			return {"kind": kind, "item": "tall", "c": at, "cols": 5, "rows": 3, "spacing": ORCHARD_SPACING}
		"bed":
			return {"kind": kind, "item": "ground", "c": at, "cols": 5, "rows": 3, "spacing": BED_SPACING}
		"boulders":
			return {"kind": kind, "item": "stone", "c": at, "cols": 3, "rows": 2, "spacing": BOULDER_SPACING}
		"row":
			return {"kind": kind, "item": "tall", "a": at - Vector2(450, 0), "b": at + Vector2(450, 0), "spacing": 150.0}
		"ring":
			return {"kind": kind, "item": "tall", "c": at, "radius": 300.0, "count": 10}
		"pair":
			return {"kind": kind, "item": "tall", "c": at, "d": Vector2(0, 200)}
	return {}

# Where each thing of an arrangement stands (room-local px), the same way OverworldMap._arrange_authored places them.
static func decor_points(m: Dictionary) -> Array:
	var out: Array = []
	match m.kind:
		"orchard", "boulders", "bed":
			var cols: int = maxi(int(m.cols), 1)
			var rows: int = maxi(int(m.rows), 1)
			var sp: float = float(m.spacing)
			var size := Vector2(float(cols - 1) * sp, float(rows - 1) * sp)
			for ix in cols:
				for iy in rows:
					out.append(m.c - size * 0.5 + Vector2(float(ix) * sp, float(iy) * sp))
		"row":
			var gap := maxf(float(m.spacing), 20.0)
			var cnt := int(m.a.distance_to(m.b) / gap)
			for i in cnt + 1:
				out.append((m.a as Vector2).lerp(m.b, float(i) / float(maxi(cnt, 1))))
		"ring":
			var count: int = maxi(int(m.count), 1)
			for i in count:
				var ang := TAU * float(i) / float(count)
				out.append(m.c + Vector2(cos(ang), sin(ang)) * float(m.radius))
		"pair":
			out.append(m.c - m.d)
			out.append(m.c + m.d)
	return out

static func decor_center(m: Dictionary) -> Vector2:
	if m.has("c"):
		return m.c
	return ((m.a as Vector2) + (m.b as Vector2)) * 0.5

static func decor_move(m: Dictionary, delta: Vector2) -> void:
	for k in ["c", "a", "b"]:
		if m.has(k):
			m[k] += delta

static func decor_handles(m: Dictionary) -> Array:
	match m.kind:
		"orchard", "boulders", "bed":
			var half := Vector2(float(maxi(int(m.cols), 1) - 1), float(maxi(int(m.rows), 1) - 1)) * float(m.spacing) * 0.5
			return [{"id": "c", "pos": m.c}, {"id": "br", "pos": m.c + half}]
		"row":
			return [{"id": "a", "pos": m.a}, {"id": "b", "pos": m.b}]
		"ring":
			return [{"id": "c", "pos": m.c}, {"id": "r", "pos": m.c + Vector2(float(m.radius), 0)}]
		"pair":
			return [{"id": "c", "pos": m.c}, {"id": "d", "pos": m.c + m.d}]
	return []

static func decor_drag(m: Dictionary, id: String, p: Vector2, step: float = 0.0) -> void:
	match id:
		"c":
			m.c = p
		"a":
			m.a = p
		"b":
			m.b = p
		"br":
			var sp: float = maxf(float(m.spacing), 1.0)
			var off: Vector2 = p - m.c
			m.cols = clampi(int(roundf(absf(off.x) * 2.0 / sp)) + 1, 1, 40)
			m.rows = clampi(int(roundf(absf(off.y) * 2.0 / sp)) + 1, 1, 40)
		"r":
			m.radius = maxf(snap(p.distance_to(m.c), step), 40.0)
		"d":
			m.d = Vector2(snap(p.x - m.c.x, step), snap(p.y - m.c.y, step))

static func decor_label(m: Dictionary) -> String:
	match m.kind:
		"orchard", "boulders", "bed":
			return "%s  %d x %d" % [DECOR_NAMES[m.kind], int(m.cols), int(m.rows)]
		"row":
			return "Row of %s  %d" % [str(m.item), decor_points(m).size()]
		"ring":
			return "Ring of %s  %d" % [str(m.item), int(m.count)]
		"pair":
			return "Pair of %s" % str(m.item)
	return str(m.kind)

# --- set pieces ---------------------------------------------------------------------------------------------------------------------

static func parse_prop(p: Array) -> Dictionary:
	return {"kind": str(p[0]), "c": Vector2(float(p[1]), float(p[2])), "flavour": str(p[3]) if p.size() > 3 else ""}

static func build_prop(m: Dictionary) -> Array:
	var out: Array = [m.kind, n(m.c.x), n(m.c.y)]
	if str(m.get("flavour", "")) != "":
		out.append(m.flavour)
	return out

static func prop_radius(kind: String) -> float:
	return float(PROP_RADIUS.get(kind, 260.0))

# --- labels -----------------------------------------------------------------------------------------------------------------------

static func op_label(m: Dictionary) -> String:
	var head: String = "%s %s" % [MODE_NAMES.get(m.get("mode", "floor"), "Floor"), KIND_NAMES.get(m.kind, m.kind)]
	match m.kind:
		"ell":
			return "%s  %d x %d" % [head, int(m.rx), int(m.ry)]
		"disc":
			return "%s  r %d" % [head, int(m.r)]
		"box":
			return "%s  %d x %d%s" % [head, int(m.hx) * 2, int(m.hy) * 2, ("  turned %s" % str(n(m.deg))) if float(m.deg) != 0.0 else ""]
		"path":
			return "%s  %d wide, %d points" % [head, int(m.width), m.pts.size()]
		"poly":
			return "%s  %d points" % [head, m.pts.size()]
	return head

# The whole room as models, from its data (ops that cannot be read are skipped).
static func shape_models(room: Dictionary) -> Array:
	var out: Array = []
	for op in room.get("shape", []):
		if MapDataScript.check_shape_op(op) == "":
			out.append(parse_op(op))
	return out
