extends Control

# A Cookie-Clicker-Ascension-style constellation: a starfield canvas you drag
# around, a glowing hub at the centre, and round icon nodes fanned out in rings
# by prerequisite depth, joined by thin lines. Names, costs and descriptions
# live in the caller's tooltip (see ChurchPanel.gd), so the canvas itself stays
# uncluttered -- just icons, rings and a level badge.
#
# The caller hands over plain node definitions and per-node states; this file
# owns the layout, drawing, panning and focus, and reports clicks/hover back.
#
# Node definition: {id, parents: Array of ids, wing: String, icon: Texture2D,
#                   isolated (optional): true for a node with no prerequisites
#                   that should sit apart from every wing (post-game unlocks)}
# States: "locked", "unaffordable", "available", "owned", "upgradable" (owned and
# the next level is affordable), "mastered".

signal node_pressed(id: String)
signal node_hover_changed(id: String)

const NODE_RADIUS := 28.0
const HUB_RADIUS := 46.0
const RING_START := 158.0
const RING_STEP := 108.0
const MIN_GAP := 96.0
const PAN_MARGIN := 260.0
const ISOLATED_RADIUS := 1150.0

# Wing roots fan out at 120 degrees apart (screen coordinates: y grows down).
const WING_ANGLES := {
	"warrior": 3.665191,   # 210 degrees: up and to the left
	"merchant": 5.759587,  # 330 degrees: up and to the right
	"survivor": 1.570796,  # 90 degrees: straight down
}
const WING_TINTS := {
	"warrior": Color(1.0, 0.46, 0.27),
	"merchant": Color(1.0, 0.82, 0.3),
	"survivor": Color(0.36, 0.9, 0.62),
	"convergence": Color(0.74, 0.52, 1.0),
	"isolated": Color(0.7, 0.95, 1.0),
}
const GOLD := Color(1.0, 0.86, 0.36)

var world: Control
var hub_texture: Texture2D

var _defs := {}
var _buttons := {}
var _icons := {}
var _badges := {}
var _positions := {}
var _states := {}
var _stars: Array = []
var _time := 0.0
var _dragging := false
var _offset := Vector2.ZERO
var _extent := 1000.0
var _hover_id := ""
var _pan_tween: Tween
var _vignette := GradientTexture2D.new()

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world = Control.new()
	world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(world)
	world.draw.connect(_draw_world)
	resized.connect(_apply_offset)

	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	for i in 170:
		_stars.append({
			"pos": Vector2(rng.randf() * 1500.0, rng.randf() * 1000.0),
			"depth": rng.randf_range(0.15, 0.9),
			"size": 3.0 if rng.randf() < 0.14 else 2.0,
			"phase": rng.randf() * TAU,
			"speed": rng.randf_range(0.5, 2.0),
		})
	var vignette_gradient := Gradient.new()
	vignette_gradient.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	vignette_gradient.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.1), Color(0, 0, 0, 0.75)])
	_vignette.gradient = vignette_gradient
	_vignette.fill = GradientTexture2D.FILL_RADIAL
	_vignette.fill_from = Vector2(0.5, 0.5)
	_vignette.fill_to = Vector2(1.0, 0.5)
	_vignette.width = 256
	_vignette.height = 256
	_apply_offset()

# --- Layout -----------------------------------------------------------------

# Radial layout from the prerequisite graph alone: depth (longest chain from a
# root) sets the ring, a node sits at its parents' mean angle (siblings fanned
# apart), roots start at their wing's angle, and a few relaxation passes push
# apart anything that still crowds. Deterministic, so the map never reshuffles.
static func compute_layout(defs: Array) -> Dictionary:
	var by_id := {}
	var order := {}
	for i in defs.size():
		by_id[defs[i].id] = defs[i]
		order[defs[i].id] = i
	var depth := {}
	for d in defs:
		_depth_of(d.id, by_id, depth)

	var children := {}
	for d in defs:
		for parent_id in d.parents:
			if not children.has(parent_id):
				children[parent_id] = []
			children[parent_id].append(d.id)

	var ids: Array = by_id.keys()
	ids.sort_custom(func(a, b):
		if depth[a] != depth[b]:
			return depth[a] < depth[b]
		return order[a] < order[b])

	var angle := {}
	var radius := {}
	var pos := {}
	for id in ids:
		var d: Dictionary = by_id[id]
		var r: float = RING_START + float(depth[id]) * RING_STEP
		var a: float = 0.0
		if d.get("isolated", false):
			a = 4.712389
			r = ISOLATED_RADIUS
		elif d.parents.is_empty():
			a = WING_ANGLES.get(d.wing, 0.0)
		elif d.parents.size() == 1:
			var parent_id: String = d.parents[0]
			var siblings: Array = children[parent_id]
			siblings.sort_custom(func(x, y): return order[x] < order[y])
			var idx: int = siblings.find(id)
			var step: float = maxf(MIN_GAP / r, 0.13)
			a = angle[parent_id] + (float(idx) - float(siblings.size() - 1) * 0.5) * step
		else:
			var sum := Vector2.ZERO
			for parent_id in d.parents:
				sum += Vector2.from_angle(angle[parent_id])
			a = sum.angle()
		angle[id] = a
		radius[id] = r
		pos[id] = Vector2.from_angle(a) * r

	for pass_index in 60:
		var moved := false
		for i in ids.size():
			for j in range(i + 1, ids.size()):
				var pa: Vector2 = pos[ids[i]]
				var pb: Vector2 = pos[ids[j]]
				var gap: float = pa.distance_to(pb)
				if gap >= MIN_GAP:
					continue
				moved = true
				var push: Vector2 = (pb - pa).normalized() if gap > 0.01 else Vector2.RIGHT.rotated(float(i))
				var half: float = (MIN_GAP - gap) * 0.5
				if not by_id[ids[i]].get("isolated", false):
					pos[ids[i]] = pa - push * half
				if not by_id[ids[j]].get("isolated", false):
					pos[ids[j]] = pb + push * half
		if not moved:
			break
	return pos

static func _depth_of(id: String, by_id: Dictionary, depth: Dictionary) -> int:
	if depth.has(id):
		return depth[id]
	var best := 0
	for parent_id in by_id[id].parents:
		if by_id.has(parent_id):
			best = maxi(best, _depth_of(parent_id, by_id, depth) + 1)
	depth[id] = best
	return best

# --- Building ---------------------------------------------------------------

func build(defs: Array, hub_icon: Texture2D) -> void:
	for button in _buttons.values():
		button.queue_free()
	_buttons.clear()
	_icons.clear()
	_badges.clear()
	_defs.clear()
	_states.clear()
	hub_texture = hub_icon
	for d in defs:
		_defs[d.id] = d
	_positions = compute_layout(defs)
	_extent = 400.0
	for p in _positions.values():
		_extent = maxf(_extent, p.length() + NODE_RADIUS + 60.0)
	for d in defs:
		_make_node(d)
		_states[d.id] = "locked"
		_apply_state(d.id)
	_apply_offset()

func _make_node(d: Dictionary) -> void:
	var id: String = d.id
	var button := Button.new()
	var diameter: float = NODE_RADIUS * 2.0
	button.size = Vector2(diameter, diameter)
	button.custom_minimum_size = button.size
	button.position = _positions[id] - button.size * 0.5
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(func(): node_pressed.emit(id))
	button.mouse_entered.connect(func(): _set_hover(id))
	button.mouse_exited.connect(func():
		if _hover_id == id:
			_set_hover(""))
	button.focus_entered.connect(func():
		_set_hover(id)
		_ensure_visible(id))
	button.focus_exited.connect(func():
		if _hover_id == id:
			_set_hover(""))
	world.add_child(button)

	var icon := TextureRect.new()
	icon.texture = d.get("icon")
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.size = Vector2(34, 34)
	icon.position = (button.size - icon.size) * 0.5
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)

	var badge := Label.new()
	badge.add_theme_font_size_override("font_size", 13)
	badge.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	badge.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.08))
	badge.add_theme_constant_override("outline_size", 5)
	badge.position = Vector2(button.size.x - 18.0, button.size.y - 20.0)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(badge)

	_buttons[id] = button
	_icons[id] = icon
	_badges[id] = badge

# --- State ------------------------------------------------------------------

func set_state(id: String, state: String, badge_text: String = "") -> void:
	if not _buttons.has(id):
		return
	_states[id] = state
	_badges[id].text = badge_text
	_apply_state(id)

func button_for(id: String) -> Button:
	return _buttons.get(id)

func node_ids() -> Array:
	return _buttons.keys()

func position_of(id: String) -> Vector2:
	return _positions.get(id, Vector2.ZERO)

func tint_of(id: String) -> Color:
	return WING_TINTS.get(_defs[id].wing, WING_TINTS["convergence"])

func _circle_style(fill: Color, border: Color, border_width: int = 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(int(NODE_RADIUS))
	sb.anti_aliasing = false
	return sb

func _apply_state(id: String) -> void:
	var button: Button = _buttons[id]
	var tint: Color = tint_of(id)
	var state: String = _states.get(id, "locked")
	var fill := Color(0.06, 0.06, 0.1)
	var ring := Color(0.26, 0.26, 0.32)
	var icon_color := Color(0.4, 0.4, 0.46, 0.75)
	match state:
		"unaffordable":
			fill = tint.darkened(0.78)
			ring = tint.darkened(0.35)
			icon_color = Color(0.85, 0.85, 0.85)
		"available":
			fill = tint.darkened(0.6)
			ring = tint
			icon_color = Color(1, 1, 1)
		"owned", "upgradable":
			fill = tint.darkened(0.55)
			ring = GOLD
			icon_color = Color(1, 1, 1)
		"mastered":
			fill = GOLD.darkened(0.45)
			ring = Color(1.0, 0.97, 0.75)
			icon_color = Color(1, 1, 1)
	button.add_theme_stylebox_override("normal", _circle_style(fill, ring))
	button.add_theme_stylebox_override("hover", _circle_style(fill.lightened(0.18), ring.lightened(0.35)))
	button.add_theme_stylebox_override("pressed", _circle_style(fill.darkened(0.3), ring))
	button.add_theme_stylebox_override("disabled", _circle_style(fill, ring))
	var focus := _circle_style(Color(0, 0, 0, 0), Color(1, 1, 1, 0.95), 3)
	focus.expand_margin_left = 5
	focus.expand_margin_right = 5
	focus.expand_margin_top = 5
	focus.expand_margin_bottom = 5
	button.add_theme_stylebox_override("focus", focus)
	_icons[id].modulate = icon_color

# --- Hover / focus / panning ---------------------------------------------------

func _set_hover(id: String) -> void:
	if id == _hover_id:
		return
	_hover_id = id
	node_hover_changed.emit(id)

# Rect of a node in this view's own coordinates (for tooltip placement).
func node_rect_in_view(id: String) -> Rect2:
	var button: Button = _buttons[id]
	return Rect2(world.position + button.position, button.size)

func _ensure_visible(id: String) -> void:
	var rect := node_rect_in_view(id)
	if size.x < 200.0 or size.y < 200.0:
		return  # not laid out yet (a panel focusing a node the instant it opens)
	var inner := Rect2(Vector2(90, 90), size - Vector2(180, 180))
	if inner.encloses(rect):
		return
	center_on(id)

func center_on(id: String) -> void:
	if not _positions.has(id):
		return
	_animate_offset(-_positions[id])

func center_on_hub() -> void:
	_animate_offset(Vector2.ZERO)

# Snaps back to the hub with no animation (used when the panel first opens).
func reset_view() -> void:
	if _pan_tween != null and _pan_tween.is_valid():
		_pan_tween.kill()
	_set_offset(Vector2.ZERO)

func _animate_offset(target: Vector2) -> void:
	target = _clamped(target)
	if _pan_tween != null and _pan_tween.is_valid():
		_pan_tween.kill()
	_pan_tween = create_tween()
	_pan_tween.tween_method(func(v: Vector2): _set_offset(v), _offset, target, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _clamped(v: Vector2) -> Vector2:
	return v.limit_length(_extent + PAN_MARGIN)

func _set_offset(v: Vector2) -> void:
	_offset = _clamped(v)
	_apply_offset()

func _apply_offset() -> void:
	if world != null:
		world.position = (size * 0.5 + _offset).round()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_MIDDLE):
		_dragging = event.pressed
		if _dragging and _pan_tween != null and _pan_tween.is_valid():
			_pan_tween.kill()
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_set_offset(_offset + event.relative)
		accept_event()

# A drag that ends with the cursor outside the view would otherwise never see
# its button release.
func _input(event: InputEvent) -> void:
	if _dragging and event is InputEventMouseButton and not event.pressed:
		_dragging = false

# --- Drawing ------------------------------------------------------------------

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	queue_redraw()
	world.queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.012, 0.012, 0.045))
	# Slow nebula clouds, drifting a little as you pan.
	var nebulae := [
		[Vector2(0.28, 0.3), 0.55, Color(0.42, 0.14, 0.62, 0.075)],
		[Vector2(0.74, 0.62), 0.5, Color(0.1, 0.42, 0.55, 0.07)],
		[Vector2(0.5, 0.86), 0.42, Color(0.6, 0.2, 0.3, 0.06)],
	]
	for n in nebulae:
		var c: Vector2 = Vector2(size.x * n[0].x, size.y * n[0].y) + _offset * 0.12
		draw_circle(c, size.y * n[1], n[2])
		draw_circle(c, size.y * n[1] * 0.6, Color(n[2].r, n[2].g, n[2].b, n[2].a * 0.9))
	var tile := Vector2(1500.0, 1000.0)
	for star in _stars:
		var p := Vector2(
			fposmod(star.pos.x + _offset.x * star.depth * 0.5, tile.x),
			fposmod(star.pos.y + _offset.y * star.depth * 0.5, tile.y)
		)
		if p.x > size.x or p.y > size.y:
			continue
		var twinkle: float = 0.5 + 0.5 * sin(_time * star.speed + star.phase)
		var s: float = star.size
		draw_rect(Rect2(p.floor(), Vector2(s, s)), Color(0.85, 0.9, 1.0, 0.25 + 0.65 * twinkle * star.depth))
	draw_texture_rect(_vignette, Rect2(Vector2.ZERO, size), false)

static func _is_owned_state(state: String) -> bool:
	return state == "owned" or state == "upgradable" or state == "mastered"

func _edge_color(parent_id: String, child_id: String) -> Color:
	var child_state: String = _states.get(child_id, "locked")
	var parent_state: String = _states.get(parent_id, "locked")
	var tint: Color = tint_of(child_id)
	var parent_owned: bool = _is_owned_state(parent_state)
	if _is_owned_state(child_state):
		return Color(GOLD.r, GOLD.g, GOLD.b, 0.95) if parent_owned else Color(tint.r, tint.g, tint.b, 0.6)
	if child_state == "locked":
		return Color(0.22, 0.22, 0.3, 0.85)
	return Color(tint.r, tint.g, tint.b, 0.6)

func _draw_world() -> void:
	for k in range(0, 10):
		world.draw_arc(Vector2.ZERO, RING_START + float(k) * RING_STEP, 0.0, TAU, 128, Color(0.6, 0.65, 1.0, 0.035), 2.0)
	# The hub: a soft halo, a ring, and the Essence shard at its heart.
	var breathe: float = 0.5 + 0.5 * sin(_time * 1.3)
	world.draw_circle(Vector2.ZERO, HUB_RADIUS * (2.6 + 0.2 * breathe), Color(1.0, 0.8, 0.4, 0.04))
	world.draw_circle(Vector2.ZERO, HUB_RADIUS * 1.7, Color(1.0, 0.8, 0.4, 0.07))
	world.draw_circle(Vector2.ZERO, HUB_RADIUS, Color(0.07, 0.05, 0.12))
	world.draw_arc(Vector2.ZERO, HUB_RADIUS, 0.0, TAU, 48, GOLD, 4.0)
	if hub_texture != null:
		world.draw_texture_rect(hub_texture, Rect2(-24.0, -24.0, 48.0, 48.0), false)

	for id in _defs:
		var d: Dictionary = _defs[id]
		var to: Vector2 = _positions[id]
		var roots: bool = d.parents.is_empty() and not d.get("isolated", false)
		if roots:
			var c: Color = tint_of(id)
			world.draw_line(Vector2.ZERO, to, Color(c.r, c.g, c.b, 0.3), 3.0)
		for parent_id in d.parents:
			if _positions.has(parent_id):
				world.draw_line(_positions[parent_id], to, _edge_color(parent_id, id), 4.0)
	# A slow pulse around every node you can buy right now.
	var pulse: float = fmod(_time * 0.9, 1.0)
	for id in _states:
		if _states[id] == "available" or _states[id] == "upgradable":
			var c: Color = GOLD if _states[id] == "upgradable" else tint_of(id)
			world.draw_arc(_positions[id], NODE_RADIUS + 5.0 + pulse * 9.0, 0.0, TAU, 40, Color(c.r, c.g, c.b, (1.0 - pulse) * 0.7), 3.0)
