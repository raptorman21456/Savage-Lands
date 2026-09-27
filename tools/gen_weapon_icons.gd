extends SceneTree

# Generates the 32x32 weapon icons in assets/weapons/ -- one per weapon type per
# material (assets/weapons/<base>_<material>.png, plus club.png), so a Golden
# Greatsword and a Bone Greatsword read differently at a glance.
#
# Each icon is drawn as flat "slots" (which part is metal, wood, leather...) from
# a few shape primitives, then shaded with one fixed light from the top-left and
# outlined, so all nine weapons share the same look and a material is only a
# different metal palette. Nothing here is hand-placed pixel by pixel: to change a
# weapon, edit its shapes below and re-run:
#
#   godot --headless --path . --script res://tools/gen_weapon_icons.gd
#   godot --headless --editor --path . --quit      (imports the new PNGs)
#
# Legendary/Mythic weapons may instead ship hand-made art, dropped in
# assets/weapons/ as legendary_<base>.png / mythic_<base>.png -- see
# scripts/WeaponIcons.gd, which prefers those when they exist.

const S := 32          # final icon size
const V := 64          # virtual drawing canvas (cropped and centred into S at the end)
const OUT_DIR := "res://assets/weapons"

# Slots
const EMPTY := 0
const METAL := 1       # the material's own palette
const METAL_DK := 2    # the same palette one step darker (guards, pommels, bands)
const WOOD := 3
const WRAP := 4        # leather grips and glove
const STRING := 5
const EDGE := 6        # a bright cutting edge (metal, always at its lightest)

# Five tones per ramp, darkest to lightest.
const RAMPS := {
	"wood_handle": ["2b1a0d", "4a2e17", "6a4322", "8b5c30", "ad7842"],
	"wrap": ["2e1512", "4d2620", "703a2e", "8f5240", "b06c54"],
	"string": ["7d6f4e", "a89a74", "cfc39c", "e8dcb8", "f8f0d4"],
	"steel": ["2d3038", "4c515e", "757b89", "a1a7b5", "d6dae4"],
	"wood": ["40291a", "624028", "88603a", "ab7e50", "cfa474"],
	"gold": ["5e3f0b", "94661a", "c9931f", "efc23c", "fff3a8"],
	"bone": ["5c503c", "8c7f64", "bfb293", "e2d8bd", "faf6ea"],
	"silver": ["4d5c78", "7f93b3", "b6c8e2", "e2eeff", "ffffff"],
	"obsidian": ["0d0918", "1c1433", "30254f", "54419a", "8a6fdc"],
}
const MATERIAL_IDS := ["wood", "steel", "gold", "bone", "silver", "obsidian"]
const OUTLINE := "16100e"

var slot: PackedInt32Array
var _current := ""
# The weapon's frame: hilt end (u = 0) and the direction it points (u) and its
# perpendicular (v, toward the lower right), in virtual-canvas pixels.
var origin := Vector2(14.0, 50.0)
var dir_u := Vector2(1, -1).normalized()
var dir_v := Vector2(1, 1).normalized()

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var bases := {
		"club": _club, "spear": _spear, "greatsword": _greatsword, "hammer": _hammer,
		"battle_axe": _battle_axe, "dagger": _dagger, "bow": _bow,
		"knuckle_gloves": _knuckle_gloves, "hand_picks": _hand_picks,
	}
	var only := OS.get_cmdline_user_args()
	var written := 0
	for base in bases:
		if only.size() > 0 and not (base in only):
			continue
		if base == "club":
			_current = base
			_new_canvas()
			bases[base].call()
			_save(_render("wood", true), "club")
			written += 1
			continue
		for material in MATERIAL_IDS:
			_current = base
			_new_canvas()
			bases[base].call()
			_save(_render(material, false), "%s_%s" % [base, material])
			written += 1
	print("wrote %d icons to %s" % [written, OUT_DIR])
	_contact_sheet(bases)
	quit()

# --- Drawing primitives --------------------------------------------------------

func _new_canvas() -> void:
	slot = PackedInt32Array()
	slot.resize(V * V)
	slot.fill(EMPTY)
	origin = Vector2(14.0, 50.0)
	dir_u = Vector2(1, -1).normalized()
	dir_v = Vector2(1, 1).normalized()

func _at(u: float, v: float) -> Vector2:
	return origin + dir_u * u + dir_v * v

func _put(x: int, y: int, s: int) -> void:
	if x >= 0 and y >= 0 and x < V and y < V:
		slot[y * V + x] = s

# A tapered capsule from a to b (radius r0 at a, r1 at b), in canvas pixels.
func _capsule_px(a: Vector2, b: Vector2, r0: float, r1: float, s: int) -> void:
	var ab := b - a
	var len2: float = maxf(ab.length_squared(), 0.0001)
	var pad := int(ceil(maxf(r0, r1))) + 1
	var lo := Vector2(minf(a.x, b.x) - pad, minf(a.y, b.y) - pad)
	var hi := Vector2(maxf(a.x, b.x) + pad, maxf(a.y, b.y) + pad)
	for y in range(int(lo.y), int(hi.y) + 1):
		for x in range(int(lo.x), int(hi.x) + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			var t: float = clampf((p - a).dot(ab) / len2, 0.0, 1.0)
			if p.distance_to(a + ab * t) <= lerpf(r0, r1, t):
				_put(x, y, s)

func _capsule(u0: float, v0: float, u1: float, v1: float, r0: float, r1: float, s: int) -> void:
	_capsule_px(_at(u0, v0), _at(u1, v1), r0, r1, s)

func _disc(u: float, v: float, r: float, s: int) -> void:
	var c := _at(u, v)
	_capsule_px(c, c, r, r, s)

func _disc_px(c: Vector2, r: float, s: int) -> void:
	_capsule_px(c, c, r, r, s)

# Fills a polygon given as (u, v) pairs.
func _poly(points: Array, s: int) -> void:
	var pts: Array[Vector2] = []
	for pt in points:
		pts.append(_at(pt[0], pt[1]))
	_poly_px(pts, s)

func _poly_px(pts: Array[Vector2], s: int) -> void:
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for p in pts:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	for y in range(int(lo.y), int(hi.y) + 1):
		for x in range(int(lo.x), int(hi.x) + 1):
			var c := Vector2(x + 0.5, y + 0.5)
			var inside := false
			var j := pts.size() - 1
			for i in pts.size():
				var a := pts[i]
				var b := pts[j]
				if (a.y > c.y) != (b.y > c.y) and c.x < (b.x - a.x) * (c.y - a.y) / (b.y - a.y) + a.x:
					inside = not inside
				j = i
			if inside:
				_put(x, y, s)

# A thin bright line through the given (u, v) points -- a blade's cutting edge.
func _edge_chain(points: Array, r: float) -> void:
	for i in range(points.size() - 1):
		_capsule(points[i][0], points[i][1], points[i + 1][0], points[i + 1][1], r, r, EDGE)

# --- The weapons -----------------------------------------------------------------
# Everything is laid out along u (hilt at 0, tip at the far end) with v across.

func _club() -> void:
	# A knotted wooden cudgel, fat at the business end, with a couple of iron studs.
	_capsule(0, 0, 27, 0, 1.5, 5.6, WOOD)
	_capsule(3, 0, 11, 0, 1.9, 2.3, WRAP)
	_disc(0.6, 0, 2.0, METAL_DK)
	for pt in [[24, -3.4], [27, 1.8], [30, -1.2], [24.5, 3.2]]:
		_disc(pt[0], pt[1], 1.0, METAL)

func _spear() -> void:
	_capsule(0, 0, 30, 0, 1.15, 1.15, WOOD)
	_capsule(8, 0, 16, 0, 1.5, 1.5, WRAP)
	_capsule(0, 0, 1.6, 0, 1.6, 1.6, METAL_DK)
	_capsule(27.5, 0, 30, 0, 1.8, 1.8, METAL_DK)
	_poly([[29, 0], [31, -2.8], [33.5, -3.8], [36.5, -2.3], [39.5, 0], [36.5, 2.3], [33.5, 3.8], [31, 2.8]], METAL)
	_capsule(31, 0, 37, 0, 0.55, 0.3, METAL_DK)

func _dagger() -> void:
	_disc(1.6, 0, 1.9, METAL_DK)
	_capsule(2, 0, 10, 0, 1.5, 1.5, WRAP)
	_capsule(11, -4.6, 11, 4.6, 1.3, 1.3, METAL_DK)
	_poly([[11.5, -2.8], [24, -2.6], [33, -1.4], [38.5, 0], [33, 1.4], [24, 2.6], [11.5, 2.8]], METAL)
	_capsule(13, 0, 31, 0, 0.55, 0.35, METAL_DK)

func _greatsword() -> void:
	_disc(1.0, 0, 2.1, METAL_DK)
	_capsule(2, 0, 10, 0, 1.6, 1.6, WRAP)
	_capsule(11, -6.2, 11, 6.2, 1.5, 1.5, METAL_DK)
	_disc(11, -6.2, 2.0, METAL_DK)
	_disc(11, 6.2, 2.0, METAL_DK)
	_poly([[12, -3.6], [28, -3.4], [34.5, -1.5], [38.5, 0], [34.5, 1.5], [28, 3.4], [12, 3.6]], METAL)
	_capsule(14, 0, 32, 0, 0.75, 0.4, METAL_DK)

func _hammer() -> void:
	_capsule(0, 0, 24, 0, 1.45, 1.45, WOOD)
	_capsule(3, 0, 11, 0, 1.8, 1.8, WRAP)
	_disc(0.6, 0, 2.1, METAL_DK)
	_poly([[20.5, -6.8], [31, -6.8], [31, 6.8], [20.5, 6.8]], METAL)
	_poly([[20.5, -6.8], [23, -6.8], [23, 6.8], [20.5, 6.8]], METAL_DK)
	_poly([[29, -6.8], [31, -6.8], [31, 6.8], [29, 6.8]], METAL_DK)

func _bow() -> void:
	# Drawn in canvas coordinates: a D-shaped bow, string on the right.
	var a := Vector2(42, 19)
	var b := Vector2(42, 45)
	var c := Vector2(15, 32)
	var prev := a
	for i in range(1, 41):
		var t := i / 40.0
		var pt := a * (1 - t) * (1 - t) + c * 2 * (1 - t) * t + b * t * t
		var thick: float = lerpf(1.0, 1.9, sin(t * PI))
		_capsule_px(prev, pt, thick, thick, METAL)
		prev = pt
	_capsule_px(Vector2(28.9, 29), Vector2(28.9, 35), 2.4, 2.4, WRAP)
	_capsule_px(a, b, 0.55, 0.55, STRING)
	_disc_px(a, 1.4, METAL_DK)
	_disc_px(b, 1.4, METAL_DK)

func _battle_axe() -> void:
	_capsule(0, 0, 25, 0, 1.4, 1.4, WOOD)
	_capsule(3, 0, 11, 0, 1.8, 1.8, WRAP)
	_disc(0.6, 0, 2.1, METAL_DK)
	# A bearded crescent blade to the upper left of the haft: the outer arc is the
	# cutting edge, the inner arc leaves a gap between blade and haft.
	_poly([[28, -1.8], [30, -6], [28.5, -10.5], [24, -13.2], [19, -13], [15.5, -9.5], [14.5, -5], [16, -1.8], [18.5, -3.2], [19.5, -6.5], [22, -8.6], [25, -7.5], [26.5, -4.5]], METAL)
	_edge_chain([[30, -6], [28.5, -10.5], [24, -13.2], [19, -13], [15.5, -9.5], [14.5, -5]], 0.9)
	_capsule(15, 0, 29, 0, 2.2, 2.2, METAL_DK)
	_capsule(25, 0, 29.5, 0, 1.3, 0.5, METAL)

func _knuckle_gloves() -> void:
	# Brass knuckles, seen from the front: a metal bar with four finger holes
	# under a row of rounded knuckles, joined by struts to a leather palm grip.
	_poly_px([Vector2(18.8, 27), Vector2(47.3, 27), Vector2(47.3, 39), Vector2(18.8, 39)], METAL)
	for i in 4:
		_disc_px(Vector2(22.7 + i * 6.9, 27.0), 3.9, METAL)
	_capsule_px(Vector2(21, 36), Vector2(21, 42), 2.3, 2.3, METAL_DK)
	_capsule_px(Vector2(45, 36), Vector2(45, 42), 2.3, 2.3, METAL_DK)
	_capsule_px(Vector2(21, 43), Vector2(45, 43), 3.2, 3.2, WRAP)
	for i in 4:
		_disc_px(Vector2(22.7 + i * 6.9, 32.6), 2.3, EMPTY)

func _hand_picks() -> void:
	# Two short picks crossed, heads splayed to the upper left and upper right.
	for side in [1, -1]:
		origin = Vector2(32.0 - side * 3.5, 52.0)
		dir_u = Vector2(side * 0.8, -1.15).normalized()
		dir_v = Vector2(1.15, side * 0.8).normalized()
		_capsule(0, 0, 23, 0, 1.25, 1.25, WOOD)
		_capsule(2, 0, 8, 0, 1.6, 1.6, WRAP)
		_disc(0.5, 0, 1.8, METAL_DK)
		_capsule(20.5, 0, 23, 0, 1.9, 1.9, METAL_DK)
		# The pick: a curved crescent swept back at both ends.
		_poly([[21.5, -7.2], [24.2, -5.0], [25.6, -1.7], [25.6, 1.7], [24.2, 5.0], [21.5, 7.2], [22.4, 3.8], [23.4, 1.3], [23.4, -1.3], [22.4, -3.8]], METAL)

# --- Rendering -----------------------------------------------------------------

func _slot_at(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= V or y >= V:
		return EMPTY
	return slot[y * V + x]

# Crops the drawing to its bounding box and centres it in an S x S icon, shades
# it with a light from the upper left, and outlines it.
func _render(material: String, is_club: bool) -> Image:
	var lo := Vector2i(V, V)
	var hi := Vector2i(-1, -1)
	for y in V:
		for x in V:
			if slot[y * V + x] != EMPTY:
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	var size := hi - lo + Vector2i.ONE
	if size.x > S - 2 or size.y > S - 2:
		push_warning("%s icon is %dx%d, larger than the %d frame" % [_current, size.x, size.y, S - 2])
	var shift := Vector2i((S - size.x) / 2, (S - size.y) / 2) - lo
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var tone_of := {}
	# Interior shading follows position within the shape: light at the upper left.
	for y in V:
		for x in V:
			var s: int = slot[y * V + x]
			if s == EMPTY:
				continue
			var lit: bool = _slot_at(x, y - 1) == EMPTY or _slot_at(x - 1, y) == EMPTY
			var shaded: bool = _slot_at(x, y + 1) == EMPTY or _slot_at(x + 1, y) == EMPTY
			var tone := 2
			if lit and not shaded:
				tone = 4 if s == METAL or s == METAL_DK else 3
			elif shaded and not lit:
				tone = 1
			elif not lit and not shaded:
				var g: float = float((x - lo.x) + (y - lo.y)) / float(maxi(1, size.x + size.y))
				tone = 3 if g < 0.4 else (2 if g < 0.62 else 1)
			if s == EDGE:
				tone = 4
			if s == METAL_DK:
				tone = maxi(0, tone - 1)
			tone_of[Vector2i(x, y)] = tone
	var metal_ramp: String = "wood" if is_club else material
	for y in V:
		for x in V:
			var s: int = slot[y * V + x]
			var px := Vector2i(x, y) + shift
			if px.x < 0 or px.y < 0 or px.x >= S or px.y >= S:
				continue
			if s == EMPTY:
				continue
			var ramp_name := ""
			match s:
				METAL, METAL_DK, EDGE:
					ramp_name = "steel" if is_club else metal_ramp
				WOOD:
					ramp_name = "wood_handle"
				WRAP:
					ramp_name = "wrap"
				STRING:
					ramp_name = "string"
			var tone: int = tone_of[Vector2i(x, y)]
			img.set_pixelv(px, Color.html(RAMPS[ramp_name][tone]))
	# Outline: any empty pixel that touches the drawing on a side.
	var outline := Color.html(OUTLINE)
	var marks: Array[Vector2i] = []
	for y in S:
		for x in S:
			if img.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < S and q.y < S and img.get_pixelv(q).a > 0.0 and img.get_pixelv(q) != outline:
					marks.append(Vector2i(x, y))
					break
	for m in marks:
		img.set_pixelv(m, outline)
	return img

func _save(img: Image, name: String) -> void:
	img.save_png("%s/%s.png" % [OUT_DIR, name])

# A review sheet (not shipped): every weapon in steel, then the materials.
func _contact_sheet(bases: Dictionary) -> void:
	var scale := 5
	var cell := (S + 4) * scale
	var names: Array = bases.keys()
	var sheet := Image.create(cell * 5, cell * 2 + cell * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.13, 0.13, 0.16))
	for i in names.size():
		var fname: String = "club" if names[i] == "club" else "%s_steel" % names[i]
		var icon := Image.load_from_file(ProjectSettings.globalize_path("%s/%s.png" % [OUT_DIR, fname]))
		if icon == null:
			continue
		icon.resize(S * scale, S * scale, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(icon, Rect2i(0, 0, S * scale, S * scale), Vector2i((i % 5) * cell + 2 * scale, (i / 5) * cell + 2 * scale))
	# Materials: the spear and the greatsword in all six.
	for r in 2:
		var b: String = ["spear", "greatsword"][r]
		for m in MATERIAL_IDS.size():
			var icon2 := Image.load_from_file(ProjectSettings.globalize_path("%s/%s_%s.png" % [OUT_DIR, b, MATERIAL_IDS[m]]))
			if icon2 == null:
				continue
			icon2.resize(S * 4, S * 4, Image.INTERPOLATE_NEAREST)
			sheet.blend_rect(icon2, Rect2i(0, 0, S * 4, S * 4), Vector2i(m * (S * 4 + 6) + 4, cell * 2 + r * (S * 4 + 8) + 4))
	sheet.save_png("user://weapon_sheet.png")
