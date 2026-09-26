extends Control

# The title screen's living backdrop, all drawn in code: a banded blood-red
# sunset, twinkling stars, a setting sun cut by ridge lines, three parallax
# mountain layers that lean with the mouse, great birds gliding across the sky, a
# barbarian on a cliff beside a campfire throwing embers, swaying foreground
# pines, drifting clouds, the odd shooting star, and a vignette. Nothing here
# takes input; TitleScreen just drops it behind the menu.

const BARBARIAN_TEXTURE := preload("res://assets/barbarian.png")
const PINE_TEXTURE := preload("res://assets/deco_pine_tree.png")
const DEAD_TREE_TEXTURE := preload("res://assets/deco_dead_tree.png")

const SKY_BANDS := 36
const STAR_COUNT := 90
const CLOUD_COUNT := 6
const MAX_EMBERS := 110
const RIDGE_STEP_QUANT := 6.0

# Extra darkening for busy screens (the upgrade tree, stats) so the scene never
# fights the text on top of it. TitleScreen drives dim_target.
var dim_target := 0.0
var dim := 0.0

var _time := 0.0
var _mouse := Vector2(0.5, 0.5)
var _stars: Array = []
var _clouds: Array = []
var _embers: Array = []
var _layers: Array = []
var _built_for := Vector2.ZERO
var _sky := Gradient.new()
var _sun_colors := Gradient.new()
var _vignette := GradientTexture2D.new()
var _shooting_star: Dictionary = {}
var _next_shooting_star := 4.0
var _ember_budget := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rng.seed = 90210

	_sky.offsets = PackedFloat32Array([0.0, 0.34, 0.62, 0.86, 1.0])
	_sky.colors = PackedColorArray([
		Color(0.02, 0.01, 0.09), Color(0.12, 0.05, 0.23), Color(0.43, 0.09, 0.27),
		Color(0.84, 0.28, 0.21), Color(1.0, 0.55, 0.25),
	])
	_sun_colors.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	_sun_colors.colors = PackedColorArray([Color(1.0, 0.86, 0.36), Color(1.0, 0.46, 0.2), Color(0.82, 0.1, 0.22)])

	var vignette_gradient := Gradient.new()
	vignette_gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	vignette_gradient.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.05), Color(0, 0, 0, 0.7)])
	_vignette.gradient = vignette_gradient
	_vignette.fill = GradientTexture2D.FILL_RADIAL
	_vignette.fill_from = Vector2(0.5, 0.5)
	_vignette.fill_to = Vector2(1.0, 0.5)
	_vignette.width = 256
	_vignette.height = 256

	for i in STAR_COUNT:
		_stars.append({
			"pos": Vector2(_rng.randf(), _rng.randf() * 0.5),
			"size": 3.0 if _rng.randf() < 0.18 else 2.0,
			"phase": _rng.randf() * TAU,
			"speed": _rng.randf_range(0.6, 2.2),
		})
	for i in CLOUD_COUNT:
		_clouds.append({
			"x": _rng.randf(),
			"y": _rng.randf_range(0.12, 0.42),
			"w": _rng.randf_range(0.16, 0.3),
			"speed": _rng.randf_range(0.004, 0.012),
			"alpha": _rng.randf_range(0.14, 0.26),
		})
	resized.connect(_build_layers)
	_build_layers()

# One ridge line per parallax layer: blocky (quantized) heights, seeded so the
# skyline is the same every launch, rebuilt whenever the window resizes.
func _build_layers() -> void:
	_layers.clear()
	if size.x < 16.0 or size.y < 16.0:
		return
	_built_for = size
	var specs := [
		{"base": 0.57, "amp": 0.11, "color": Color(0.24, 0.09, 0.31), "parallax": 10.0, "seed": 11.0, "step": 26.0, "freq": 0.13},
		{"base": 0.67, "amp": 0.09, "color": Color(0.14, 0.06, 0.22), "parallax": 22.0, "seed": 29.0, "step": 20.0, "freq": 0.17},
		{"base": 0.77, "amp": 0.075, "color": Color(0.065, 0.03, 0.12), "parallax": 40.0, "seed": 47.0, "step": 16.0, "freq": 0.21},
	]
	for spec in specs:
		var margin: float = spec.parallax * 2.5
		var step: float = spec.step
		var count: int = int(ceil((size.x + margin * 2.0) / step)) + 2
		var heights := PackedFloat32Array()
		for i in count:
			var peak: float = pow(1.0 - absf(sin(float(i) * spec.freq + spec.seed)), 1.7)
			var swell: float = 0.5 + 0.5 * sin(float(i) * spec.freq * 0.37 + spec.seed * 1.9)
			var jitter: float = _rng.randf() * 0.18
			var lift: float = clampf(peak * 0.65 + swell * 0.3 + jitter, 0.0, 1.0)
			var h: float = size.y * spec.base - size.y * spec.amp * lift
			heights.append(roundf(h / RIDGE_STEP_QUANT) * RIDGE_STEP_QUANT)
		_layers.append({
			"heights": heights, "color": spec.color, "parallax": spec.parallax,
			"step": step, "margin": margin,
		})

func _process(delta: float) -> void:
	_time += delta
	dim = lerpf(dim, dim_target, minf(1.0, delta * 4.0))
	var target := Vector2(0.5, 0.5)
	if size.x > 1.0 and size.y > 1.0:
		var local := get_local_mouse_position()
		target = Vector2(clampf(local.x / size.x, 0.0, 1.0), clampf(local.y / size.y, 0.0, 1.0))
	_mouse = _mouse.lerp(target, minf(1.0, delta * 2.5))

	for cloud in _clouds:
		cloud.x += cloud.speed * delta
		if cloud.x > 1.0 + cloud.w:
			cloud.x = -cloud.w

	_update_embers(delta)

	_next_shooting_star -= delta
	if _shooting_star.is_empty() and _next_shooting_star <= 0.0:
		_shooting_star = {
			"pos": Vector2(randf_range(0.15, 0.85), randf_range(0.05, 0.22)),
			"age": 0.0, "life": 0.7,
		}
		_next_shooting_star = randf_range(7.0, 16.0)
	elif not _shooting_star.is_empty():
		_shooting_star.age += delta
		if _shooting_star.age >= _shooting_star.life:
			_shooting_star = {}
	queue_redraw()

# The campfire on the cliff throws most of the embers; a thin ambient drift
# rises from the whole ground line so the far side of the screen isn't dead.
func _update_embers(delta: float) -> void:
	for i in range(_embers.size() - 1, -1, -1):
		var e: Dictionary = _embers[i]
		e.age += delta
		if e.age >= e.life:
			_embers.remove_at(i)
			continue
		e.pos = e.pos + e.vel * delta
		e.vel = e.vel + Vector2(sin(_time * 1.7 + e.phase) * 22.0 * delta, 0.0)
	_ember_budget += delta * 16.0
	while _ember_budget >= 1.0 and _embers.size() < MAX_EMBERS:
		_ember_budget -= 1.0
		var from_fire: bool = randf() < 0.7
		var origin: Vector2
		var vel: Vector2
		if from_fire:
			origin = _campfire_pos() + Vector2(randf_range(-10.0, 10.0), -8.0)
			vel = Vector2(randf_range(-14.0, 26.0), randf_range(-95.0, -45.0))
		else:
			origin = Vector2(randf() * size.x, size.y + 6.0)
			vel = Vector2(randf_range(-6.0, 24.0), randf_range(-55.0, -22.0))
		_embers.append({
			"pos": origin, "vel": vel, "age": 0.0, "life": randf_range(3.5, 8.0),
			"size": 4.0 if randf() < 0.3 else 3.0, "phase": randf() * TAU,
		})
	_ember_budget = minf(_ember_budget, 2.0)

func _cliff_top() -> float:
	return size.y * 0.8

func _hero_x() -> float:
	return size.x * 0.15

func _campfire_pos() -> Vector2:
	return Vector2(_hero_x() + _hero_scale() * 12.0, _cliff_top())

func _hero_scale() -> float:
	return clampf(roundf(size.y / 72.0), 5.0, 12.0)

func _draw() -> void:
	if size.x < 16.0 or size.y < 16.0:
		return
	if size != _built_for:
		_build_layers()
	_draw_sky()
	_draw_stars()
	_draw_sun()
	_draw_clouds()
	_draw_bird(0.62, 3.0, 70.0, 0.34)
	_draw_layer(0)
	_draw_fog(0.62, 0.16)
	_draw_bird(1.0, 6.0, 45.0, 0.27)
	_draw_layer(1)
	_draw_fog(0.72, 0.2)
	_draw_layer(2)
	_draw_shooting_star()
	_draw_cliff_scene()
	_draw_pines()
	_draw_embers()
	draw_texture_rect(_vignette, Rect2(Vector2.ZERO, size), false)
	if dim > 0.001:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, dim * 0.6))

func _draw_sky() -> void:
	var sky_height: float = size.y * 0.8
	var band_h: float = ceil(sky_height / float(SKY_BANDS))
	for i in SKY_BANDS:
		var color: Color = _sky.sample(float(i) / float(SKY_BANDS - 1))
		draw_rect(Rect2(0.0, float(i) * band_h, size.x, band_h + 1.0), color)
	draw_rect(Rect2(0.0, sky_height, size.x, size.y - sky_height + 1.0), _sky.sample(1.0))

func _draw_stars() -> void:
	for star in _stars:
		var fade: float = clampf(1.0 - star.pos.y / 0.5, 0.0, 1.0)
		var twinkle: float = 0.5 + 0.5 * sin(_time * star.speed + star.phase)
		var alpha: float = (0.25 + 0.75 * twinkle) * fade
		var pos := Vector2(star.pos.x * size.x, star.pos.y * size.y).floor()
		var s: float = star.size
		draw_rect(Rect2(pos, Vector2(s, s)), Color(1, 0.95, 0.85, alpha))
		if s > 2.5 and twinkle > 0.6:
			draw_rect(Rect2(pos + Vector2(-s, 0), Vector2(s * 3.0, s * 0.5)), Color(1, 0.95, 0.85, alpha * 0.55))
			draw_rect(Rect2(pos + Vector2(0, -s), Vector2(s * 0.5, s * 3.0)), Color(1, 0.95, 0.85, alpha * 0.55))

func _draw_sun() -> void:
	var radius: float = minf(size.x, size.y) * 0.19
	var center := Vector2(size.x * 0.7, size.y * 0.5 + sin(_time * 0.25) * 4.0)
	draw_circle(center, radius * 1.9, Color(1.0, 0.35, 0.18, 0.05))
	draw_circle(center, radius * 1.5, Color(1.0, 0.4, 0.2, 0.07))
	draw_circle(center, radius * 1.22, Color(1.0, 0.5, 0.22, 0.1))
	var row_h: float = maxf(3.0, roundf(radius / 14.0))
	var rows: int = int(ceil(radius * 2.0 / row_h))
	for i in rows:
		var y: float = center.y - radius + float(i) * row_h
		var dy: float = y + row_h * 0.5 - center.y
		var half_sq: float = radius * radius - dy * dy
		if half_sq <= 0.0:
			continue
		var lower: int = i - rows / 2
		# The synthwave-sun cut lines: from the equator down, every third row
		# is left out, so it reads as banded rather than a flat disc.
		if lower > 2 and lower % 3 == 0:
			continue
		var half: float = roundf(sqrt(half_sq))
		draw_rect(Rect2(roundf(center.x - half), roundf(y), half * 2.0, row_h), _sun_colors.sample(float(i) / float(rows - 1)))

func _draw_clouds() -> void:
	for cloud in _clouds:
		var w: float = cloud.w * size.x
		var x: float = cloud.x * size.x
		var y: float = cloud.y * size.y
		var color := Color(0.62, 0.22, 0.36, cloud.alpha)
		draw_rect(Rect2(roundf(x), roundf(y), w, 10.0), color)
		draw_rect(Rect2(roundf(x + w * 0.14), roundf(y - 8.0), w * 0.6, 8.0), color)
		draw_rect(Rect2(roundf(x + w * 0.34), roundf(y - 14.0), w * 0.28, 6.0), color)
		draw_rect(Rect2(roundf(x + w * 0.5), roundf(y + 10.0), w * 0.36, 5.0), Color(color.r, color.g, color.b, color.a * 0.7))

# A great bird gliding across the sky, dead black against the sunset -- the
# classic wings-out silhouette, built column by column so it stays blocky and
# its wingbeat is real animation rather than a squashed sprite. Two passes at
# different depths (size, speed, height) so the sky feels lived in.
func _draw_bird(depth: float, unit: float, period: float, height_frac: float) -> void:
	var travel: float = fmod(_time / period + depth * 0.37, 1.0)
	var span: float = size.x + 300.0
	var x: float = size.x + 150.0 - travel * span
	var y: float = size.y * height_frac + sin(_time * 0.7 + depth * 3.0) * 12.0
	var flap: float = sin(_time * 3.4 + depth * 2.0)
	var color := Color(0.04, 0.015, 0.06, 0.55 + 0.45 * depth)
	var cx: float = roundf(x)
	var cy: float = roundf(y)
	draw_rect(Rect2(cx - unit * 0.7, cy - unit * 0.5, unit * 1.4, unit * 1.5), color)
	for side in [-1.0, 1.0]:
		for col in range(1, 10):
			var t: float = float(col)
			# Tips swing up on the upstroke and droop on the downstroke; the
			# thin sine bump gives the wing its bent-elbow "M" shape in glide.
			var lift: float = t * (0.14 + 0.3 * flap) + sin(t / 9.0 * PI) * 0.9
			var thick: float = maxf(0.7, 2.4 - t * 0.2)
			var wx: float = cx + side * t * unit * 0.9 - unit * 0.5
			var wy: float = cy - lift * unit - thick * unit * 0.5
			draw_rect(Rect2(roundf(wx), roundf(wy), unit, thick * unit), color)

func _draw_layer(index: int) -> void:
	if index >= _layers.size():
		return
	var layer: Dictionary = _layers[index]
	var heights: PackedFloat32Array = layer.heights
	var step: float = layer.step
	var lean: float = (_mouse.x - 0.5) * -layer.parallax * 2.0
	var sway: float = sin(_time * 0.11 + float(index)) * layer.parallax * 0.25
	var x0: float = -layer.margin + lean + sway
	# One rectangle per run of equal-height columns, each running down to the
	# bottom of the screen. (Rectangles rather than a polygon: a stepped
	# outline is degenerate whenever neighbouring heights match, and the
	# triangulator rejects it at some window sizes.)
	var bottom: float = size.y + 4.0
	var run_start: int = 0
	for i in range(1, heights.size() + 1):
		if i == heights.size() or heights[i] != heights[run_start]:
			var left: float = x0 + float(run_start) * step
			var right: float = x0 + float(i) * step
			draw_rect(Rect2(left, heights[run_start], right - left, bottom - heights[run_start]), layer.color)
			run_start = i

# A low band of mist between ridge layers, warmest at its top edge where the
# sunset catches it.
func _draw_fog(top_frac: float, thickness_frac: float) -> void:
	var top: float = size.y * top_frac
	var height: float = size.y * thickness_frac
	var bands := 6
	for i in bands:
		var t: float = float(i) / float(bands)
		var a: float = 0.16 * (1.0 - t)
		draw_rect(Rect2(0.0, top + t * height, size.x, height / float(bands) + 1.0), Color(0.75, 0.32, 0.32, a))

func _draw_shooting_star() -> void:
	if _shooting_star.is_empty():
		return
	var u: float = _shooting_star.age / _shooting_star.life
	var head: Vector2 = Vector2(_shooting_star.pos.x * size.x, _shooting_star.pos.y * size.y) + Vector2(1.0, 0.45) * (u * 260.0)
	var alpha: float = sin(u * PI)
	for i in 8:
		var back: float = float(i) * 9.0
		var pos: Vector2 = (head - Vector2(1.0, 0.45) * back).floor()
		var s: float = maxf(1.0, 4.0 - float(i) * 0.4)
		draw_rect(Rect2(pos, Vector2(s, s)), Color(1, 0.95, 0.85, alpha * (1.0 - float(i) / 8.0)))

# The barbarian on his cliff with a campfire and one dead tree, all near-black
# so they read as a silhouette against the sunset.
func _draw_cliff_scene() -> void:
	var top: float = _cliff_top()
	var ink := Color(0.02, 0.012, 0.04)
	# A stepped cliff: a few overlapping columns, each dropping to the bottom.
	var floor_y: float = size.y + 4.0
	var steps := [
		[-20.0, size.x * 0.05, top + 30.0], [size.x * 0.05, size.x * 0.09, top + 12.0],
		[size.x * 0.09, size.x * 0.3, top], [size.x * 0.3, size.x * 0.34, top + 24.0],
		[size.x * 0.34, size.x * 0.4, top + 60.0],
	]
	for step in steps:
		draw_rect(Rect2(step[0], step[2], step[1] - step[0], maxf(0.0, floor_y - step[2])), ink)

	var s: float = _hero_scale()
	# Campfire glow first, so it lights the hero from behind rather than over him.
	var fire: Vector2 = _campfire_pos()
	var flicker: float = 0.8 + 0.2 * sin(_time * 11.0) + 0.1 * sin(_time * 23.0)
	draw_circle(fire + Vector2(0, -10), s * 11.0 * flicker, Color(1.0, 0.45, 0.15, 0.07))
	draw_circle(fire + Vector2(0, -10), s * 6.5 * flicker, Color(1.0, 0.55, 0.18, 0.1))

	var hero_x: float = _hero_x()
	var breathe: float = 1.0 + 0.022 * sin(_time * 1.9)
	draw_set_transform(Vector2(roundf(hero_x), top + 2.0), 0.0, Vector2(1.0, breathe))
	# Warm rim of firelight on the side facing the flames, then the figure
	# itself graded dark so it sits in the scene.
	draw_texture_rect(BARBARIAN_TEXTURE, Rect2(-8.0 * s + 3.0, -16.0 * s, 16.0 * s, 16.0 * s), false, Color(1.0, 0.5, 0.2, 0.55 * flicker))
	draw_texture_rect(BARBARIAN_TEXTURE, Rect2(-8.0 * s, -16.0 * s, 16.0 * s, 16.0 * s), false, Color(0.78, 0.58, 0.55))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# The fire itself: three flickering pixel tongues.
	var unit: float = maxf(3.0, s * 0.9)
	var base := Vector2(roundf(fire.x), roundf(top))
	for tongue in 3:
		var offset: float = (float(tongue) - 1.0) * unit * 1.1
		var h: float = unit * (2.2 + 1.2 * (0.5 + 0.5 * sin(_time * (9.0 + float(tongue) * 3.0) + float(tongue))))
		draw_rect(Rect2(base.x + offset - unit * 0.5, base.y - h, unit, h), Color(1.0, 0.42, 0.1))
		draw_rect(Rect2(base.x + offset - unit * 0.3, base.y - h * 0.62, unit * 0.6, h * 0.62), Color(1.0, 0.82, 0.3))
	draw_rect(Rect2(base.x - unit * 2.0, base.y - unit * 0.5, unit * 4.0, unit * 0.5), Color(0.25, 0.1, 0.05))

	var tree_h: float = size.y * 0.3
	var tree_w: float = tree_h * (DEAD_TREE_TEXTURE.get_width() / float(DEAD_TREE_TEXTURE.get_height()))
	var sway: float = sin(_time * 0.5) * 0.012
	draw_set_transform(Vector2(size.x * 0.27, top + 4.0), sway, Vector2.ONE)
	draw_texture_rect(DEAD_TREE_TEXTURE, Rect2(-tree_w * 0.5, -tree_h, tree_w, tree_h), false, Color(0.03, 0.02, 0.06))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_pines() -> void:
	var specs := [[0.83, 0.36, 0.0], [0.915, 0.46, 1.7], [0.985, 0.32, 3.1], [0.7, 0.24, 4.4]]
	for spec in specs:
		var h: float = size.y * spec[1]
		var w: float = h * (PINE_TEXTURE.get_width() / float(PINE_TEXTURE.get_height()))
		var sway: float = sin(_time * 0.6 + spec[2]) * 0.014
		draw_set_transform(Vector2(size.x * spec[0], size.y + 8.0), sway, Vector2.ONE)
		draw_texture_rect(PINE_TEXTURE, Rect2(-w * 0.5, -h, w, h), false, Color(0.025, 0.015, 0.05))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_embers() -> void:
	for e in _embers:
		var u: float = e.age / e.life
		var fade_in: float = clampf(u / 0.08, 0.0, 1.0)
		var alpha: float = fade_in * (1.0 - u)
		var color := Color(1.0, lerpf(0.85, 0.22, u), lerpf(0.35, 0.06, u), alpha)
		var pos: Vector2 = e.pos.floor()
		var s: float = e.size * (1.0 - u * 0.4)
		draw_rect(Rect2(pos - Vector2(s, s) * 0.5 - Vector2(2, 2), Vector2(s + 4.0, s + 4.0)), Color(color.r, color.g, color.b, alpha * 0.16))
		draw_rect(Rect2(pos - Vector2(s, s) * 0.5, Vector2(s, s)), color)
