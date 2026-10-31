extends RefCounted

# The map's EDITABLE DATA FILES (res://data/*.json): reading them, checking them, writing them back readably, and keeping a
# timestamped backup of whatever a save replaces. Nothing in here knows about the game -- RoomData.gd decides what to do when a
# file is missing or broken (it falls back to the built-in values and says so), and the map editor (MapEditor.gd) is what writes.
#
#   rooms.json      the hand-made rooms: shape, ground, decoration, set pieces, who lives there   (RoomData.ROOMS)
#   edges.json      the doorways between neighbouring rooms                                       (RoomData.EDGES)
#   roads.json      the roads drawn across the land                                               (RoomData.ROADS)
#   landmarks.json  the named places (town, HeartWood, caves...): name, position, size
#   regions.json    per-region tweaks: name, danger tier, who lives there, the miniboss
#
# Every reader here is TOLERANT: a file that cannot be opened or parsed gives {"status": "broken"} with a plain sentence saying why;
# an entry that does not make sense is dropped (with a warning) and the rest is kept, so one typo costs you one room, not the map.

const DIR := "res://data"
const FORMAT := 1
const FILE_NAMES := {
	"rooms": "rooms.json", "edges": "edges.json", "roads": "roads.json", "landmarks": "landmarks.json", "regions": "regions.json",
}
const KINDS := ["rooms", "edges", "roads", "landmarks", "regions"]
const ABOUT := {
	"rooms": "The hand-made rooms of the overworld. Key = the room's top-left cell \"col,row\" (the map is 11 x 11 cells). Positions are px from the room's top-left corner. Edit it in the game (title > Map Editor) or by hand; the format is described at the top of scripts/RoomData.gd.",
	"edges": "The doorways between neighbouring rooms. Key = the two cells either side (\"4,3|5,3\": the left cell first, or the top cell first for a vertical pair). Value = \"open\", \"closed\", or a list of [centre, width] in px along the side.",
	"roads": "Roads drawn across the land. points are in CELL units (5.5, 5.5 is the middle of the cell at column 5, row 5); width is in px; style is optional (boards, ash, snow, sand, crystal).",
	"landmarks": "The named places of the world: id (do not change), name, pos = [x, y] in world px, radius in px. Only these fields are read; the game's code still decides what stands there.",
	"regions": "Per-region tweaks keyed by region id: name, tier (danger 1-8), enemies = [[enemy, weight], ...], miniboss. The outlines of the regions are still drawn in scripts/WorldMap.gd.",
}

# What shape ops, decoration arrangements and set pieces look like (the numbers each needs). Kept here so the checks, the editor and
# the converter agree.
const SHAPE_KINDS := ["ell", "disc", "box", "rbox", "path", "poly"]
const DECOR_KINDS := ["orchard", "bed", "boulders", "row", "ring", "pair"]
const DECOR_ITEMS := ["tall", "small", "ground", "stone"]
const PROP_KINDS := ["clearing", "standing_stones", "farm", "pond", "rock_formation", "camp", "fallen_logs", "ruin_walls", "graves", "cliff_ridge", "mouth", "crystals", "lighthouse", "wreck"]
const MASSES := ["", "forest", "thicket", "pines", "dead_forest", "rock", "sandstone", "volcanic", "crystal_rock", "water", "bog", "ice", "lava", "abyss"]
const COLS := 11
const ROWS := 11

# --- files --------------------------------------------------------------------------------------------------------------------

static func file_path(kind: String, dir: String = DIR) -> String:
	return "%s/%s" % [dir, FILE_NAMES[kind]]

# Reads and checks one data file. {status: "ok" | "missing" | "broken", data: the cleaned data (null unless ok), warnings: [sentences],
# path}. "ok" can still carry warnings (entries that were dropped).
static func read(kind: String, dir: String = DIR) -> Dictionary:
	var path := file_path(kind, dir)
	var out := {"status": "missing", "data": null, "warnings": [], "path": path}
	if not FileAccess.file_exists(path):
		out.warnings.append("%s is missing" % path)
		return out
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		out.status = "broken"
		out.warnings.append("%s could not be opened (error %d)" % [path, FileAccess.get_open_error()])
		return out
	var text := f.get_as_text()
	f.close()
	return read_text(kind, text, path)

static func read_text(kind: String, text: String, path: String = "") -> Dictionary:
	var out := {"status": "broken", "data": null, "warnings": [], "path": path}
	var json := JSON.new()
	if json.parse(text) != OK:
		out.warnings.append("%s is not valid JSON (line %d: %s)" % [path, json.get_error_line() + 1, json.get_error_message()])
		return out
	if typeof(json.data) != TYPE_DICTIONARY or not json.data.has(kind):
		out.warnings.append("%s has no \"%s\" section" % [path, kind])
		return out
	var cleaned: Dictionary = clean(kind, tidy(json.data[kind]))
	out.warnings = cleaned.warnings
	if cleaned.has("data"):
		out.status = "ok"
		out.data = cleaned.data
	return out

# The data wrapped in its file (what write() puts on disk).
static func serialize(kind: String, data) -> String:
	var wrapper := {"_about": ABOUT[kind], "format": FORMAT, kind: data}
	return dump(wrapper) + "\n"

# Writes one data file. The file it replaces is first copied to <dir>/backups/<name>_<yyyymmdd_hhmmss>.json (nothing is ever
# deleted). Returns {ok, path, backup ("" when there was nothing to back up), unchanged, error}.
static func write(kind: String, data, dir: String = DIR) -> Dictionary:
	var path := file_path(kind, dir)
	var out := {"ok": false, "path": path, "backup": "", "unchanged": false, "error": ""}
	var text := serialize(kind, data)
	var make_err := DirAccess.make_dir_recursive_absolute(dir)
	if make_err != OK and not DirAccess.dir_exists_absolute(dir):
		out.error = "could not create the folder %s (error %d)" % [dir, make_err]
		return out
	if FileAccess.file_exists(path):
		var old := FileAccess.get_file_as_string(path)
		if old == text:
			out.ok = true
			out.unchanged = true
			return out
		var backup := _backup(path, dir, kind)
		if backup == "":
			out.error = "could not keep a backup of %s, so it was not overwritten" % path
			return out
		out.backup = backup
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		out.error = "could not write %s (error %d)" % [path, FileAccess.get_open_error()]
		return out
	f.store_string(text)
	f.close()
	if FileAccess.get_file_as_string(path) != text:
		out.error = "%s was written but reads back differently" % path
		return out
	out.ok = true
	return out

static func _backup(path: String, dir: String, kind: String) -> String:
	var backups := dir + "/backups"
	DirAccess.make_dir_recursive_absolute(backups)
	var t := Time.get_datetime_dict_from_system()
	var stamp := "%04d%02d%02d_%02d%02d%02d" % [t.year, t.month, t.day, t.hour, t.minute, t.second]
	var target := "%s/%s_%s.json" % [backups, kind, stamp]
	var n := 2
	while FileAccess.file_exists(target):
		target = "%s/%s_%s_%d.json" % [backups, kind, stamp, n]
		n += 1
	var err := DirAccess.copy_absolute(path, target)
	return target if err == OK else ""

# --- numbers and comparing ------------------------------------------------------------------------------------------------------

# JSON numbers all arrive as floats; whole ones become ints again, so data read from a file looks exactly like the hand-written
# constants (900, not 900.0). Recursive.
static func tidy(v):
	match typeof(v):
		TYPE_FLOAT:
			if absf(v) < 1.0e9 and v == roundf(v):
				return int(v)
			return v
		TYPE_ARRAY:
			var out: Array = []
			for e in v:
				out.append(tidy(e))
			return out
		TYPE_DICTIONARY:
			var d := {}
			for k in v:
				d[k] = tidy(v[k])
			return d
	return v

# Deep equality where 900 == 900.0 and numbers within `eps` are the same.
static func same(a, b, eps: float = 0.0005) -> bool:
	var ta := typeof(a)
	var tb := typeof(b)
	var a_num: bool = ta == TYPE_INT or ta == TYPE_FLOAT
	var b_num: bool = tb == TYPE_INT or tb == TYPE_FLOAT
	if a_num and b_num:
		return absf(float(a) - float(b)) <= eps
	if ta != tb:
		return false
	match ta:
		TYPE_ARRAY:
			if a.size() != b.size():
				return false
			for i in a.size():
				if not same(a[i], b[i], eps):
					return false
			return true
		TYPE_DICTIONARY:
			if a.size() != b.size():
				return false
			for k in a:
				if not b.has(k) or not same(a[k], b[k], eps):
					return false
			return true
	return a == b

# --- checking ---------------------------------------------------------------------------------------------------------------------

static func _is_num(v) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT

static func _all_nums(a: Array, from: int = 0) -> bool:
	for i in range(from, a.size()):
		if not _is_num(a[i]):
			return false
	return true

static func cell_key(col: int, row: int) -> String:
	return "%d,%d" % [col, row]

# "4,3" -> Vector2i(4, 3), or Vector2i(-1, -1) when it is not a cell of the 11 x 11 grid.
static func parse_cell(s: String) -> Vector2i:
	var parts := s.split(",")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return Vector2i(-1, -1)
	var c := Vector2i(int(parts[0]), int(parts[1]))
	if c.x < 0 or c.y < 0 or c.x >= COLS or c.y >= ROWS:
		return Vector2i(-1, -1)
	return c

# "" when the shape op is usable, else what is wrong with it.
static func check_shape_op(op) -> String:
	if typeof(op) != TYPE_ARRAY or op.is_empty() or typeof(op[0]) != TYPE_STRING:
		return "a shape op must be a list starting with its kind"
	var kind: String = str(op[0])
	if kind.begins_with("-") or kind.begins_with("+"):
		kind = kind.substr(1)
	if not (kind in SHAPE_KINDS):
		return "unknown shape kind \"%s\"" % str(op[0])
	if not _all_nums(op, 1):
		return "\"%s\" has something that is not a number" % str(op[0])
	var n: int = op.size()
	match kind:
		"ell":
			if n < 5: return "\"ell\" needs cx, cy, rx, ry"
		"disc":
			if n < 4: return "\"disc\" needs cx, cy, r"
		"box":
			if n < 5: return "\"box\" needs cx, cy, hx, hy (and a corner radius)"
		"rbox":
			if n < 6: return "\"rbox\" needs cx, cy, hx, hy, degrees (and a corner radius)"
		"path":
			if n < 6 or n % 2 != 0: return "\"path\" needs a width and at least two x, y points"
		"poly":
			if n < 7 or n % 2 != 1: return "\"poly\" needs at least three x, y points"
	return ""

static func check_decor_op(op) -> String:
	if typeof(op) != TYPE_ARRAY or op.is_empty() or typeof(op[0]) != TYPE_STRING:
		return "a decoration must be a list starting with its kind"
	var kind: String = str(op[0])
	if not (kind in DECOR_KINDS):
		return "unknown decoration \"%s\"" % kind
	var n: int = op.size()
	match kind:
		"orchard", "boulders":
			if n < 5 or n > 6 or not _all_nums(op, 1): return "\"%s\" needs cx, cy, cols, rows (and spacing)" % kind
		"bed":
			if n < 5 or not _all_nums(op, 1): return "\"bed\" needs cx, cy, cols, rows"
		"row":
			if n < 7 or typeof(op[1]) != TYPE_STRING or not _all_nums(op, 2): return "\"row\" needs item, x0, y0, x1, y1, spacing"
		"ring", "pair":
			if n < 6 or typeof(op[1]) != TYPE_STRING or not _all_nums(op, 2): return "\"%s\" needs item, then four numbers" % kind
	return ""

static func check_prop(p) -> String:
	if typeof(p) != TYPE_ARRAY or p.size() < 3 or typeof(p[0]) != TYPE_STRING or not _is_num(p[1]) or not _is_num(p[2]):
		return "a set piece must be [kind, x, y] (and a flavour)"
	if p.size() > 3 and typeof(p[3]) != TYPE_STRING:
		return "a set piece's flavour must be a word"
	return ""

static func check_enemies(list) -> String:
	if typeof(list) != TYPE_ARRAY:
		return "enemies must be a list of [enemy, weight]"
	for e in list:
		if typeof(e) != TYPE_ARRAY or e.size() < 2 or typeof(e[0]) != TYPE_STRING or not _is_num(e[1]):
			return "enemies must be a list of [enemy, weight]"
	return ""

# "" when the room is usable, else what is wrong with it.
static func check_room(key: String, room) -> String:
	if parse_cell(key) == Vector2i(-1, -1):
		return "\"%s\" is not a cell of the 11 x 11 map" % key
	if typeof(room) != TYPE_DICTIONARY:
		return "it is not a room (a list of settings)"
	if room.has("name") and typeof(room.name) != TYPE_STRING:
		return "name must be text"
	if room.has("mass") and typeof(room.mass) != TYPE_STRING:
		return "mass must be text"
	if room.has("target") and not _is_num(room.target):
		return "target must be a number"
	if room.has("span"):
		var s = room.span
		if typeof(s) != TYPE_ARRAY or s.size() != 2 or not _all_nums(s) or int(s[0]) < 1 or int(s[1]) < 1:
			return "span must be [columns, rows]"
		var c := parse_cell(key)
		if c.x + int(s[0]) > COLS or c.y + int(s[1]) > ROWS:
			return "span reaches off the map"
	if room.has("shape"):
		if typeof(room.shape) != TYPE_ARRAY:
			return "shape must be a list"
		for i in room.shape.size():
			var bad := check_shape_op(room.shape[i])
			if bad != "":
				return "shape #%d: %s" % [i + 1, bad]
	if room.has("decor"):
		if typeof(room.decor) != TYPE_ARRAY:
			return "decor must be a list"
		for i in room.decor.size():
			var bad2 := check_decor_op(room.decor[i])
			if bad2 != "":
				return "decor #%d: %s" % [i + 1, bad2]
	if room.has("props"):
		if typeof(room.props) != TYPE_ARRAY:
			return "props must be a list"
		for i in room.props.size():
			var bad3 := check_prop(room.props[i])
			if bad3 != "":
				return "prop #%d: %s" % [i + 1, bad3]
	if room.has("enemies"):
		var bad4 := check_enemies(room.enemies)
		if bad4 != "":
			return bad4
	return ""

# Which cells two sides name, or [] when "a,b|c,d" is not a pair of neighbouring cells of the map.
static func parse_edge(key: String) -> Array:
	var halves := key.split("|")
	if halves.size() != 2:
		return []
	var a := parse_cell(halves[0])
	var b := parse_cell(halves[1])
	if a == Vector2i(-1, -1) or b == Vector2i(-1, -1):
		return []
	var d := b - a
	if (d == Vector2i(1, 0)) or (d == Vector2i(0, 1)):
		return [a, b]
	return []

static func check_edge(key: String, spec) -> String:
	if parse_edge(key).is_empty():
		return "\"%s\" is not two neighbouring cells (left or top one first)" % key
	if typeof(spec) == TYPE_STRING:
		return "" if spec in ["open", "closed"] else "\"%s\" is not open or closed" % str(spec)
	if typeof(spec) != TYPE_ARRAY:
		return "it must be \"open\", \"closed\" or a list of [centre, width]"
	for o in spec:
		if typeof(o) != TYPE_ARRAY or o.size() < 2 or not _is_num(o[0]) or not _is_num(o[1]):
			return "each doorway must be [centre, width]"
		if float(o[1]) <= 0.0:
			return "a doorway's width must be more than 0"
	return ""

static func check_road(road) -> String:
	if typeof(road) != TYPE_DICTIONARY or not road.has("points") or typeof(road.points) != TYPE_ARRAY:
		return "a road needs a width and a list of points"
	if not road.has("width") or not _is_num(road.width) or float(road.width) <= 0.0:
		return "a road needs a width above 0"
	if road.points.size() < 2:
		return "a road needs at least two points"
	for p in road.points:
		if typeof(p) != TYPE_ARRAY or p.size() < 2 or not _is_num(p[0]) or not _is_num(p[1]):
			return "each road point must be [x, y] in cells"
	if road.has("style") and typeof(road.style) != TYPE_STRING:
		return "a road's style must be a word"
	return ""

# Checks one file's section. {data (only when usable), warnings}.
static func clean(kind: String, raw) -> Dictionary:
	var warnings: Array = []
	match kind:
		"rooms":
			if typeof(raw) != TYPE_DICTIONARY:
				return {"warnings": ["rooms.json: \"rooms\" must be a list of rooms keyed by cell"]}
			var rooms := {}
			var taken := {}
			var overlaps := 0
			for key in raw:
				var bad := check_room(str(key), raw[key])
				if bad != "":
					warnings.append("room %s was left out (the generator fills it): %s" % [key, bad])
					continue
				var room: Dictionary = raw[key]
				var c := parse_cell(str(key))
				var span: Array = room.get("span", [1, 1])
				var clash := ""
				for dy in int(span[1]):
					for dx in int(span[0]):
						var cell := cell_key(c.x + dx, c.y + dy)
						if taken.has(cell) and clash == "":
							clash = str(taken[cell])
				if clash != "":
					overlaps += 1
					if overlaps <= 5:
						warnings.append("room %s was left out: it overlaps the hand-made room %s that comes before it" % [key, clash])
					continue
				for dy in int(span[1]):
					for dx in int(span[0]):
						taken[cell_key(c.x + dx, c.y + dy)] = str(key)
				rooms[str(key)] = room
			if overlaps > 5:
				warnings.append("...and %d more rooms overlapped an earlier one and were left out" % (overlaps - 5))
			return {"data": rooms, "warnings": warnings}
		"edges":
			if typeof(raw) != TYPE_DICTIONARY:
				return {"warnings": ["edges.json: \"edges\" must be a list keyed by pairs of cells"]}
			var edges := {}
			for key in raw:
				var bad := check_edge(str(key), raw[key])
				if bad != "":
					warnings.append("doorway %s was left out (the generator decides it): %s" % [key, bad])
					continue
				edges[str(key)] = raw[key]
			return {"data": edges, "warnings": warnings}
		"roads":
			if typeof(raw) != TYPE_ARRAY:
				return {"warnings": ["roads.json: \"roads\" must be a list"]}
			var roads: Array = []
			for i in raw.size():
				var bad := check_road(raw[i])
				if bad != "":
					warnings.append("road #%d was left out: %s" % [i + 1, bad])
					continue
				roads.append(raw[i])
			return {"data": roads, "warnings": warnings}
		"landmarks":
			if typeof(raw) != TYPE_ARRAY:
				return {"warnings": ["landmarks.json: \"landmarks\" must be a list"]}
			var lms: Array = []
			for i in raw.size():
				var l = raw[i]
				var ok: bool = typeof(l) == TYPE_DICTIONARY and typeof(l.get("id", null)) == TYPE_STRING
				if ok and l.has("pos"):
					ok = typeof(l.pos) == TYPE_ARRAY and l.pos.size() == 2 and _all_nums(l.pos)
				if ok and l.has("radius"):
					ok = _is_num(l.radius) and float(l.radius) > 0.0
				if ok and l.has("name"):
					ok = typeof(l.name) == TYPE_STRING
				if not ok:
					warnings.append("landmark #%d was left out: it needs an id, a name, pos [x, y] and a radius" % (i + 1))
					continue
				lms.append(l)
			return {"data": lms, "warnings": warnings}
		"regions":
			if typeof(raw) != TYPE_DICTIONARY:
				return {"warnings": ["regions.json: \"regions\" must be a list keyed by region id"]}
			var regs := {}
			for id in raw:
				var r = raw[id]
				var ok2: bool = typeof(r) == TYPE_DICTIONARY
				if ok2 and r.has("name"):
					ok2 = typeof(r.name) == TYPE_STRING
				if ok2 and r.has("tier"):
					ok2 = _is_num(r.tier)
				if ok2 and r.has("enemies"):
					ok2 = check_enemies(r.enemies) == ""
				if ok2 and r.has("miniboss"):
					ok2 = typeof(r.miniboss) == TYPE_STRING
				if not ok2:
					warnings.append("region %s was left out: name is text, tier a number, enemies [[enemy, weight]], miniboss text" % id)
					continue
				regs[str(id)] = r
			return {"data": regs, "warnings": warnings}
	return {"warnings": ["unknown kind %s" % kind]}

# --- writing it out readably ---------------------------------------------------------------------------------------------

static func _num(v: float) -> String:
	if v == roundf(v) and absf(v) < 1.0e9:
		return str(int(v))
	return str(snappedf(v, 0.000001))

static func _scalar(v) -> String:
	match typeof(v):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if v else "false"
		TYPE_INT:
			return str(v)
		TYPE_FLOAT:
			return _num(v)
	return JSON.stringify(str(v))

static func _is_scalar(v) -> bool:
	return typeof(v) != TYPE_ARRAY and typeof(v) != TYPE_DICTIONARY

# True for a list of scalars and lists of scalars (a shape op, a list of ops...): what is written one entry to a line.
static func _is_simple(v: Array) -> bool:
	for e in v:
		if typeof(e) == TYPE_DICTIONARY:
			return false
		if typeof(e) == TYPE_ARRAY:
			for q in e:
				if not _is_scalar(q):
					return false
	return true

static func _flat(v) -> String:
	if typeof(v) == TYPE_ARRAY:
		var parts: Array = []
		for e in v:
			parts.append(_flat(e))
		return "[" + ", ".join(parts) + "]"
	return _scalar(v)

# Readable JSON: objects one key to a line, a list of lists one list to a line (a shape op, a doorway), short lists on one line.
static func dump(v, depth: int = 0) -> String:
	var pad := "\t".repeat(depth)
	var inner := "\t".repeat(depth + 1)
	match typeof(v):
		TYPE_ARRAY:
			if v.is_empty():
				return "[]"
			var flat := _flat(v)
			if _is_simple(v) and flat.length() + depth * 4 <= 110:
				return flat
			var scalar_only := true
			for e in v:
				if not _is_scalar(e):
					scalar_only = false
			if scalar_only:
				# a long list of numbers: wrap it
				var lines: Array = []
				var cur := ""
				for e in v:
					var piece := _scalar(e)
					if cur != "" and cur.length() + piece.length() > 100:
						lines.append(cur)
						cur = ""
					cur += (", " if cur != "" else "") + piece
				lines.append(cur)
				return "[\n" + ",\n".join(lines.map(func(l): return inner + l)) + "\n" + pad + "]"
			var rows: Array = []
			for e in v:
				rows.append(inner + dump(e, depth + 1))
			return "[\n" + ",\n".join(rows) + "\n" + pad + "]"
		TYPE_DICTIONARY:
			if v.is_empty():
				return "{}"
			var rows2: Array = []
			for k in v:
				rows2.append("%s%s: %s" % [inner, JSON.stringify(str(k)), dump(v[k], depth + 1)])
			return "{\n" + ",\n".join(rows2) + "\n" + pad + "}"
	return _scalar(v)

# --- editing helpers shared by the editor, the converter and the tests ----------------------------------------------------

# A deep copy that can be changed without touching the original.
static func copy(v):
	if typeof(v) == TYPE_ARRAY or typeof(v) == TYPE_DICTIONARY:
		return v.duplicate(true)
	return v

# 12919.200195 -> 12919.2: a Vector2 holds 32-bit numbers, so the clean decimal turns back into exactly the same position.
static func clean_number(v: float) -> float:
	var rounded := snappedf(v, 0.001)
	return rounded if Vector2(rounded, 0.0).x == v else v

# WorldMap's landmarks (dictionaries with a Vector2 pos) as the entries landmarks.json lists.
static func landmark_entries(landmarks: Array) -> Array:
	var out: Array = []
	for l in landmarks:
		out.append({
			"id": l.id, "name": l.name, "kind": l.kind,
			"pos": [clean_number(l.pos.x), clean_number(l.pos.y)], "radius": clean_number(l.radius), "boss": l.boss,
		})
	return tidy(out)

# WorldMap's regions as the entries regions.json lists (only what can be tweaked).
static func region_entries(regions: Array) -> Dictionary:
	var out := {}
	for r in regions:
		out[r.id] = {"name": r.name, "tier": r.tier, "enemies": r.enemies.duplicate(true), "miniboss": r.miniboss}
	return tidy(out)
