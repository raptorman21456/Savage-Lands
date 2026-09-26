extends Control

# The title-screen logo: text drawn from a hand-built 5x7 bitmap font as chunky
# pixels -- vertical gold-to-ember gradient fill, a beveled edge, a dark
# outline, a hard extruded shadow, a light sweep that glints across it every few
# seconds, and the odd twinkling sparkle. No font asset needed, so it stays
# crisp at any size and matches the game's pixel-art look.

const GLYPH_W := 5
const GLYPH_H := 7
const LETTER_GAP := 1
const SPACE_W := 3
const EXTRUDE_STEPS := 3
const GLINT_PERIOD := 4.5

const GLYPHS := {
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
	"C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
	"D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
	"E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
	"F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
	"G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###."],
	"H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"I": [".###.", "..#..", "..#..", "..#..", "..#..", "..#..", ".###."],
	"J": ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
	"K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
	"L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
	"M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
	"N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
	"O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
	"Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
	"R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
	"S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
	"T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
	"U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
	"W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
	"X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
	"Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
	"Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
	"-": [".....", ".....", ".....", "#####", ".....", ".....", "....."],
	"'": ["..#..", "..#..", ".#...", ".....", ".....", ".....", "....."],
	"!": ["..#..", "..#..", "..#..", "..#..", "..#..", ".....", "..#.."],
	".": [".....", ".....", ".....", ".....", ".....", ".##..", ".##.."],
}

var text := "SAVAGE LANDS"
var pixel_size := 8
var glint_enabled := true

var _cells: Array[Vector2i] = []
var _cell_set := {}
var _cols := 0
var _outline := 2
var _extrude := 2
var _time := 0.0
var _sparkles: Array = []
var _next_sparkle := 0.5

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rebuild()

func set_logo(new_text: String, new_pixel_size: int) -> void:
	text = new_text.to_upper()
	pixel_size = maxi(1, new_pixel_size)
	_rebuild()

func _rebuild() -> void:
	_cells.clear()
	_cell_set.clear()
	var cursor := 0
	for ch in text.to_upper():
		if not GLYPHS.has(ch):
			cursor += SPACE_W + LETTER_GAP
			continue
		var rows: Array = GLYPHS[ch]
		for y in GLYPH_H:
			var row: String = rows[y]
			for x in GLYPH_W:
				if row[x] == "#":
					var cell := Vector2i(cursor + x, y)
					_cells.append(cell)
					_cell_set[cell] = true
		cursor += GLYPH_W + LETTER_GAP
	_cols = maxi(0, cursor - LETTER_GAP)
	_outline = maxi(1, pixel_size / 3)
	_extrude = maxi(1, pixel_size / 3)
	custom_minimum_size = Vector2(
		_cols * pixel_size + 2 * _outline + EXTRUDE_STEPS * _extrude,
		GLYPH_H * pixel_size + 2 * _outline + EXTRUDE_STEPS * _extrude
	)
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	_next_sparkle -= delta
	if _next_sparkle <= 0.0 and not _cells.is_empty():
		_next_sparkle = randf_range(0.25, 0.6)
		var cell: Vector2i = _cells[randi() % _cells.size()]
		# Only on top-facing edges, so a sparkle reads as a glint off the metal.
		if not _cell_set.has(cell + Vector2i(0, -1)):
			_sparkles.append({"cell": cell, "age": 0.0, "life": randf_range(0.45, 0.8)})
	for i in range(_sparkles.size() - 1, -1, -1):
		_sparkles[i].age += delta
		if _sparkles[i].age >= _sparkles[i].life:
			_sparkles.remove_at(i)
	queue_redraw()

func _fill_color(cell: Vector2i) -> Color:
	var t: float = float(cell.y) / float(GLYPH_H - 1)
	var top := Color(1.0, 0.96, 0.62)
	var mid := Color(1.0, 0.76, 0.2)
	var bottom := Color(0.86, 0.36, 0.1)
	var c: Color = top.lerp(mid, t * 2.0) if t < 0.5 else mid.lerp(bottom, (t - 0.5) * 2.0)
	if glint_enabled and _cols > 0:
		# A soft diagonal band sweeping left-to-right, then a long rest.
		var span: float = float(_cols) + float(GLYPH_H) * 0.6
		var d: float = (float(cell.x) + float(cell.y) * 0.6) / span
		var sweep: float = -0.25 + fmod(_time, GLINT_PERIOD) / GLINT_PERIOD * 1.9
		var band: float = clampf(1.0 - absf(d - sweep) / 0.09, 0.0, 1.0)
		c = c.lerp(Color(1, 1, 1), band * 0.85)
	return c

func _draw() -> void:
	var p := pixel_size
	var o := _outline
	var origin := Vector2(o, o)
	var pad := Vector2(2 * o, 2 * o)
	# Hard extruded shadow, deepest layer first so nearer ones draw over it.
	for k in range(EXTRUDE_STEPS, 0, -1):
		var shade := 0.55 + 0.15 * float(EXTRUDE_STEPS - k)
		var extrude_color := Color(0.42 * shade, 0.06 * shade, 0.08 * shade)
		var shift := Vector2(k * _extrude, k * _extrude)
		for cell in _cells:
			draw_rect(Rect2(origin + Vector2(cell.x * p, cell.y * p) + shift - Vector2(o, o), Vector2(p, p) + pad), extrude_color)
	var outline_color := Color(0.06, 0.02, 0.09)
	for cell in _cells:
		draw_rect(Rect2(origin + Vector2(cell.x * p, cell.y * p) - Vector2(o, o), Vector2(p, p) + pad), outline_color)
	var bevel := maxi(1, p / 4)
	for cell in _cells:
		var pos := origin + Vector2(cell.x * p, cell.y * p)
		var color := _fill_color(cell)
		draw_rect(Rect2(pos, Vector2(p, p)), color)
		if not _cell_set.has(cell + Vector2i(0, -1)):
			draw_rect(Rect2(pos, Vector2(p, bevel)), color.lightened(0.4))
		if not _cell_set.has(cell + Vector2i(0, 1)):
			draw_rect(Rect2(pos + Vector2(0, p - bevel), Vector2(p, bevel)), color.darkened(0.4))
	for sparkle in _sparkles:
		var u: float = sparkle.age / sparkle.life
		var intensity: float = sin(u * PI)
		var center: Vector2 = origin + Vector2(sparkle.cell.x * p + p * 0.5, sparkle.cell.y * p)
		var arm: float = p * (0.8 + 1.4 * intensity)
		var thick: float = maxf(2.0, p * 0.28)
		var spark_color := Color(1, 1, 0.9, intensity)
		draw_rect(Rect2(center - Vector2(arm, thick * 0.5), Vector2(arm * 2.0, thick)), spark_color)
		draw_rect(Rect2(center - Vector2(thick * 0.5, arm), Vector2(thick, arm * 2.0)), spark_color)
