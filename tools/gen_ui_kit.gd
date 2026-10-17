extends SceneTree

# Generates the 9-slice frames the inventory (and later every menu) is built from, in assets/ui/kit/. They are drawn the
# way the icons are: the same near-black outline, the same palette ramps, a light from the upper left (a ring is lit
# along its top and left, shaded along its bottom and right) and chamfered corners that read as a stepped pixel curve.
# Draw each at 1 pixel = 1 art pixel and show it at a whole-number scale (the mockup uses 2x) with no smoothing; in Godot
# that is a NinePatchRect / StyleBoxTexture with the patch margins below and nearest filtering.
#
#   godot --headless --path . --script res://tools/gen_ui_kit.gd [-- <where to write the review sheet>]
#
# name: [size, patch margin, corner chamfer, rings (outside in, each [lit, shade]), fill colour or ""]. The patch margin is
# the border width to give the 9-slice (in art pixels); a frame with no fill leaves its middle transparent so a card can
# show its own picture plate inside it.

const OUT_DIR := "res://assets/ui/kit"
const OUTLINE := "16100e"

# the colours, all lifted from the icon ramps in gen_ui_icons.gd
const VIOLET := ["0d0918", "1c1433", "30254f", "54419a", "8a6fdc"]
const GOLD := ["5e3f0b", "94661a", "c9931f", "efc23c", "fff3a8"]
const STEEL := ["2d3038", "4c515e", "757b89", "a1a7b5", "d6dae4"]

func _frames() -> Dictionary:
	var o := OUTLINE
	return {
		# the window: outline, a two-pixel gold bevel, a dark edge with a faint violet lip, violet-black body
		"panel": {"size": 20, "margin": 7, "chamfer": 4, "fill": VIOLET[1],
			"rings": [[o, o], [GOLD[4], GOLD[2]], [GOLD[3], GOLD[1]], [VIOLET[0], VIOLET[0]], [VIOLET[2], VIOLET[0]]]},
		# a panel inside the window: steel trim instead of gold
		"panel_steel": {"size": 16, "margin": 4, "chamfer": 3, "fill": VIOLET[1],
			"rings": [[o, o], [STEEL[3], STEEL[1]], [VIOLET[0], VIOLET[0]]]},
		# a sunken box (descriptions, fields, slots): lit along its bottom and right instead
		"inset": {"size": 14, "margin": 4, "chamfer": 2, "fill": "120c20",
			"rings": [[o, o], [VIOLET[0], VIOLET[3]], [VIOLET[0], VIOLET[2]]], "invert": true},
		# a small flat badge (the number on a card, who wears it): outline, a thin raised lip, nothing else
		"chip": {"size": 10, "margin": 3, "chamfer": 1, "fill": VIOLET[1],
			"rings": [[o, o], [VIOLET[3], VIOLET[0]]]},
		# buttons and tabs: a raised violet plaque, then the same in gold when it is the one chosen
		"button": {"size": 14, "margin": 4, "chamfer": 2, "fill": VIOLET[2],
			"rings": [[o, o], [VIOLET[4], VIOLET[0]], [VIOLET[3], VIOLET[1]]]},
		"button_hover": {"size": 14, "margin": 4, "chamfer": 2, "fill": "3d3068",
			"rings": [[o, o], ["c4b0ff", VIOLET[0]], [VIOLET[4], VIOLET[1]]]},
		"button_on": {"size": 14, "margin": 4, "chamfer": 2, "fill": "7a5516",
			"rings": [[o, o], [GOLD[4], GOLD[0]], [GOLD[3], GOLD[1]]]},
		"button_press": {"size": 14, "margin": 4, "chamfer": 2, "fill": "241a3f",
			"rings": [[o, o], [VIOLET[0], VIOLET[4]], [VIOLET[1], VIOLET[3]]]},
		# item slots: steel while at rest, brighter on hover, white for worn, gold for the one picked
		"card": {"size": 20, "margin": 6, "chamfer": 3, "fill": "",
			"rings": [[o, o], [STEEL[3], STEEL[0]], [STEEL[2], STEEL[1]], [VIOLET[0], VIOLET[0]]]},
		"card_hover": {"size": 20, "margin": 6, "chamfer": 3, "fill": "",
			"rings": [[o, o], [STEEL[4], STEEL[1]], [STEEL[3], STEEL[2]], [VIOLET[0], VIOLET[0]]]},
		"card_worn": {"size": 20, "margin": 6, "chamfer": 3, "fill": "",
			"rings": [[o, o], ["ffffff", STEEL[3]], ["ffffff", STEEL[4]], [STEEL[2], STEEL[1]]]},
		"card_pick": {"size": 20, "margin": 6, "chamfer": 3, "fill": "",
			"rings": [[o, o], [GOLD[4], GOLD[2]], [GOLD[3], GOLD[1]], [VIOLET[0], VIOLET[0]]]},
		# worn AND picked: gold outside, white inside
		"card_worn_pick": {"size": 20, "margin": 6, "chamfer": 3, "fill": "",
			"rings": [[o, o], [GOLD[4], GOLD[2]], [GOLD[3], GOLD[1]], ["ffffff", STEEL[3]]]},
	}

var S := 16

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var frames := _frames()
	for frame_name in frames:
		var f: Dictionary = frames[frame_name]
		_make(f).save_png("%s/%s.png" % [OUT_DIR, frame_name])
	print("wrote %d frames to %s (patch margins: %s)" % [frames.size(), OUT_DIR, ", ".join(frames.keys().map(func(n): return "%s=%d" % [n, frames[n].margin]))])
	var args := OS.get_cmdline_user_args()
	_sheet(frames, args[0] if args.size() > 0 else "user://ui_kit_sheet.png")
	quit()

# is (x, y) inside the frame shrunk by `inset` pixels, with its corners chamfered (the chamfer shrinks as the ring goes in)?
func _inside(x: int, y: int, inset: int, chamfer: int, size: int) -> bool:
	var lo := inset
	var hi := size - 1 - inset
	if x < lo or y < lo or x > hi or y > hi:
		return false
	var k := maxi(chamfer - inset, 0)
	if (x - lo) + (y - lo) < k: return false
	if (hi - x) + (y - lo) < k: return false
	if (x - lo) + (hi - y) < k: return false
	if (hi - x) + (hi - y) < k: return false
	return true

func _make(f: Dictionary) -> Image:
	var size: int = f.size
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rings: Array = f.rings
	var invert: bool = f.get("invert", false)
	for y in size:
		for x in size:
			var r := -1
			for i in range(size / 2):
				if _inside(x, y, i, f.chamfer, size):
					r = i
				else:
					break
			if r < 0:
				continue
			if r >= rings.size():
				if f.fill != "":
					img.set_pixel(x, y, Color.html(f.fill))
				continue
			# lit along the top and left of a ring, shaded along its bottom and right (the other way round for a sunken box)
			var dl := x - r
			var dt := y - r
			var dr := size - 1 - r - x
			var db := size - 1 - r - y
			var lit := mini(dl, dt) <= mini(dr, db)
			if invert:
				lit = not lit
			img.set_pixel(x, y, Color.html(rings[r][0] if lit else rings[r][1]))
	return img

# A review sheet (not shipped): each frame as a small button-sized and a panel-sized 9-slice at 4x, on a dark ground.
func _sheet(frames: Dictionary, path: String) -> void:
	var scale := 4
	var names: Array = frames.keys()
	var sheet := Image.create(1500, 260 * ((names.size() + 3) / 4), false, Image.FORMAT_RGBA8)
	sheet.fill(Color.html("2a2236"))
	for i in names.size():
		var f: Dictionary = frames[names[i]]
		var src := Image.load_from_file(ProjectSettings.globalize_path("%s/%s.png" % [OUT_DIR, names[i]]))
		var m: int = f.margin
		var size: int = f.size
		var w := 56 if f.size <= 14 else 80
		var h := 22 if f.size <= 14 else 56
		var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
		out.fill(Color(0, 0, 0, 0))
		# 9-slice by hand: corners 1:1, edges and middle stretched
		var xs := [0, m, size - m, size]
		var ys := [0, m, size - m, size]
		var ox := [0, m, w - m, w]
		var oy := [0, m, h - m, h]
		for a in 3:
			for b in 3:
				var rect := Rect2i(xs[a], ys[b], xs[a + 1] - xs[a], ys[b + 1] - ys[b])
				var piece := src.get_region(rect)
				piece.resize(ox[a + 1] - ox[a], oy[b + 1] - oy[b], Image.INTERPOLATE_NEAREST)
				out.blend_rect(piece, Rect2i(0, 0, piece.get_width(), piece.get_height()), Vector2i(ox[a], oy[b]))
		out.resize(w * scale, h * scale, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(out, Rect2i(0, 0, out.get_width(), out.get_height()), Vector2i((i % 4) * 370 + 20, (i / 4) * 260 + 20))
	sheet.save_png(path)
	print("review sheet: %s (order: %s)" % [path, ", ".join(names)])
