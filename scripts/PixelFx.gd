extends RefCounted

# The few screen effects that would otherwise be smooth -- a vignette, a gradient, a circle -- made in the same chunky pixel language
# as the art. A vignette or gradient is a tiny image with a handful of colour steps, stretched over the screen with nearest filtering so
# every step is a hard band; a disc or ring is drawn as a grid of little squares. Nothing here blends smoothly between pixels.

# 2x2 ordered-dither thresholds: the classic checkerboard that makes a step edge look like an old console instead of a gradient.
const BAYER2 := [[0.125, 0.625], [0.875, 0.375]]

# A darkening / tint around the edges of the screen, in stepped bands. `cols` x `rows` is the number of fat pixels across the screen,
# `steps` how many different strengths there are between clear (the middle) and `max_alpha` (the corners), `start` how far out from the
# centre (0 = the middle, 1 = the corners) it begins, and `dither` puts the checkerboard between neighbouring steps.
static func vignette(color: Color, max_alpha: float, cols: int = 64, rows: int = 36, steps: int = 4, start: float = 0.5, dither: bool = true) -> ImageTexture:
	var img := Image.create(cols, rows, false, Image.FORMAT_RGBA8)
	for y in rows:
		for x in cols:
			var nx: float = (x + 0.5) / cols * 2.0 - 1.0
			var ny: float = (y + 0.5) / rows * 2.0 - 1.0
			var r: float = sqrt(nx * nx + ny * ny) / sqrt(2.0)
			var t: float = clampf((r - start) / maxf(0.001, 1.0 - start), 0.0, 1.0)
			var level: float = t * steps
			var step: int = int(floor(level))
			if dither:
				if level - float(step) > BAYER2[y % 2][x % 2]:
					step += 1
			else:
				step = int(round(level))
			step = clampi(step, 0, steps)
			img.set_pixel(x, y, Color(color.r, color.g, color.b, max_alpha * float(step) / float(steps)))
	return ImageTexture.create_from_image(img)

# A top-to-bottom gradient as `count` flat bands (a 1 x count image: stretch it over a rect with nearest filtering).
static func bands(top: Color, bottom: Color, count: int) -> ImageTexture:
	var img := Image.create(1, count, false, Image.FORMAT_RGBA8)
	for i in count:
		img.set_pixel(0, i, top.lerp(bottom, float(i) / float(maxi(1, count - 1))))
	return ImageTexture.create_from_image(img)

# Big shapes get squares twice as wide, so a big glow stays chunky next to a small ring instead of turning into fine detail.
const BIG_RADIUS := 120.0

# A filled circle from rows of squares, `cell` screen pixels each. Draws on `ci` (a CanvasItem in its _draw / draw signal).
static func draw_disc(ci: CanvasItem, center: Vector2, radius: float, color: Color, cell: float = 2.0) -> void:
	if radius >= BIG_RADIUS:
		cell *= 2.0
	var rows: int = int(ceil(radius / cell))
	for j in range(-rows, rows):
		var y: float = (float(j) + 0.5) * cell
		var half: float = sqrt(maxf(0.0, radius * radius - y * y))
		var span: float = floor(half / cell) * cell
		if span <= 0.0:
			continue
		ci.draw_rect(Rect2(center.x - span, center.y + float(j) * cell, span * 2.0, cell), color)

# A ring (or an arc, from angle `from` to `to` in radians) from squares on a `cell` grid -- the pixel version of draw_arc. A cell is
# drawn once however many samples land in it, so a translucent colour does not pile up.
static func draw_ring(ci: CanvasItem, center: Vector2, radius: float, thickness: float, color: Color, cell: float = 2.0, from: float = 0.0, to: float = TAU) -> void:
	if radius >= BIG_RADIUS:
		cell *= 2.0
	var cells := {}
	var span: float = to - from
	var steps: int = maxi(8, int(ceil(absf(span) * (radius + thickness) / (cell * 0.5))))
	var layers: int = maxi(1, int(ceil(thickness / cell)))
	for i in steps + 1:
		var a: float = from + span * float(i) / float(steps)
		var dir := Vector2(cos(a), sin(a))
		for k in layers:
			var r: float = radius - thickness * 0.5 + (float(k) + 0.5) * thickness / float(layers)
			var p: Vector2 = center + dir * r
			cells[Vector2i(int(floor(p.x / cell)), int(floor(p.y / cell)))] = true
	for c in cells:
		ci.draw_rect(Rect2(Vector2(c) * cell, Vector2(cell, cell)), color)

# A straight line from squares on a `cell` grid (the pixel version of draw_line).
static func draw_line_px(ci: CanvasItem, from: Vector2, to: Vector2, thickness: float, color: Color, cell: float = 2.0) -> void:
	var cells := {}
	var length: float = from.distance_to(to)
	var steps: int = maxi(1, int(ceil(length / (cell * 0.5))))
	var half: int = maxi(0, int(round(thickness / cell / 2.0)))
	for i in steps + 1:
		var p: Vector2 = from.lerp(to, float(i) / float(steps))
		var gx: int = int(floor(p.x / cell))
		var gy: int = int(floor(p.y / cell))
		for dx in range(-half, half + 1):
			for dy in range(-half, half + 1):
				cells[Vector2i(gx + dx, gy + dy)] = true
	for c in cells:
		ci.draw_rect(Rect2(Vector2(c) * cell, Vector2(cell, cell)), color)
