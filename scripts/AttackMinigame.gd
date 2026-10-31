extends CanvasLayer

# The weapon attack popup: a short action command per weapon family (commands, dice and grading live in
# AttackTimings.gd). Usage (Main.gd):  var outcome: Dictionary = await minigame.run(command, {"spell_id": ...})
# -> {"result": "miss" | "hit" | "perfect", "kind": ..., plus whatever the style adds: "hits" for the dagger, "shape" and
# "power" for the wand ...}.
#
# The styles (see AttackTimings.COMMANDS):
#   club        slide    an Undertale-style marker slides across a bar; press while it is in the zone in the middle
#   spear       ring     a ring closes on a bullseye
#   greatsword  arc      the Club's bar, bent into an arc
#   hammer      hold     hold to fill a meter, release inside the zone
#   battle axe  mash     spam to push a constantly falling gauge into a random band
#   dagger      markers  a random number of markers in a random rhythm: every one you hit is another strike
#   gloves      twin     two circles with closing rings somewhere on screen: one is for Z, one for X
#   hand picks  orbit    the Hammer, round, with a zone that keeps drifting
#   bow         cross    a crosshair swings back and forth; press as it crosses the centre
#   wand        trace    trace a random shape with the mouse (harder shape = more power)
#   staff       arrows   press 4-7 random arrow keys in order
#
# Strike input is the block key (Space), the Confirm key (Z) or a left click. Like DefenseMinigame
# it reads key/mouse events as they arrive (Time.get_ticks_usec), so timing is only as coarse as
# the game's input delivery (about one frame).

signal finished

const AttackTimingsScript := preload("res://scripts/AttackTimings.gd")
const BattleStyleScript := preload("res://scripts/BattleStyle.gd")
const PixelFxScript := preload("res://scripts/PixelFx.gd")
# The popup's circles, rings and lines are built from squares this many pixels across (PixelFx), not smooth curves.
const PIXEL_CELL := 2.0

# Test hook: while this holds entries, run() skips the UI and input and answers from here
# (a result string or a result dictionary per call, consumed from the front).
static var forced_results: Array = []

const RESULT_HOLD_MS := 380.0
const STAGE_RESULT_HOLD_MS := 700.0
const ACCENT := Color(1.0, 0.5, 0.35)
const GOOD := Color(0.5, 1.0, 0.6)
const OKAY := Color(1.0, 0.85, 0.4)
const BAD := Color(1.0, 0.4, 0.35)
const ARROW_KEYS := {KEY_UP: "up", KEY_DOWN: "down", KEY_LEFT: "left", KEY_RIGHT: "right"}
# An arrow glyph, as cells (7 x 7, pointing up); the other directions turn it.
const ARROW_UP := ["...#...", "..###..", ".#####.", "#######", "...#...", "...#...", "...#..."]

var _running := false
var _cmd: Dictionary = {}
var _kind := ""
var _start_us := 0
var _events: Array = []        # [ms, pressed, tag] -- tag is "z" / "x" for the gloves, "up" / "down" / ... for the staff
var _consumed := 0             # events already fed to the hold state machine
var _held_since := -1.0
var _result := ""
var _extra: Dictionary = {}    # what a style adds to its answer (the dagger's hits, the wand's shape ...)
var _resolved_at_ms := -1.0
var _frozen_t := -1.0          # the clock reading the telegraph freezes on once resolved
var _hold_value := 0.0
var _panel: Panel
var _title: Label
var _hint: Label
var _canvas: Control
var _stage: Control            # the whole screen, for the styles that want room (the gloves' circles, the wand's shape)
var _settings: Node
var _verb := "ATTACK"
# The wand: the stroke so far, in stage coordinates, and the shape it is meant to follow.
var _trace_points := PackedVector2Array()
var _trace_active := false
var _trace_released := false
var _trace_shape := PackedVector2Array()
var _trace_center := Vector2.ZERO
var _trace_radius := 120.0

func _ready() -> void:
	layer = 48
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_settings = get_node_or_null("/root/Settings")
	_stage = Control.new()
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.draw.connect(_draw_stage)
	add_child(_stage)
	# The battle screen's dark-fantasy frame (BattleStyle), with its inner trim line -- the same as the defense popup.
	_panel = Panel.new()
	_panel.add_theme_stylebox_override("panel", BattleStyleScript.panel_style())
	_panel.size = BattleStyleScript.POPUP_SIZE
	add_child(_panel)
	var trim := Panel.new()
	trim.position = Vector2(4, 4)
	trim.size = _panel.size - Vector2(8, 8)
	trim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var trim_style := StyleBoxFlat.new()
	trim_style.bg_color = Color(0, 0, 0, 0)
	trim_style.border_color = BattleStyleScript.PANEL_TRIM
	trim_style.set_border_width_all(1)
	BattleStyleScript.chamfer(trim_style, BattleStyleScript.CORNER - 2)
	trim.add_theme_stylebox_override("panel", trim_style)
	_panel.add_child(trim)
	_title = Label.new()
	_title.position = Vector2(14, 8)
	PixelKit.fit(_title, 18)
	_title.add_theme_color_override("font_color", ACCENT)
	_panel.add_child(_title)
	_hint = Label.new()
	_hint.position = Vector2(14, 34)
	_hint.size = Vector2(292, 40)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	PixelKit.fit(_hint, 12)
	_hint.add_theme_color_override("font_color", BattleStyleScript.DIM)
	_panel.add_child(_hint)
	_canvas = Control.new()
	_canvas.position = BattleStyleScript.POPUP_CANVAS_POS
	_canvas.size = BattleStyleScript.POPUP_CANVAS_SIZE
	_canvas.draw.connect(_draw_telegraph)
	_panel.add_child(_canvas)
	get_viewport().size_changed.connect(_place_panel)
	_place_panel()

func _place_panel() -> void:
	# The right-hand column, clear of the grid and above the bottom bar -- the same spot as the defense popup.
	_panel.position = BattleStyleScript.popup_position(get_viewport().get_visible_rect().size, _panel.size)

# ---------------------------------------------------------------- running a popup
func run(command: Dictionary, opts: Dictionary = {}) -> Dictionary:
	if not forced_results.is_empty():
		var forced = forced_results.pop_front()
		if typeof(forced) == TYPE_STRING:
			return {"result": str(forced)}
		return (forced as Dictionary).duplicate()
	_cmd = AttackTimingsScript.roll(command, opts)
	_kind = str(_cmd.get("kind", "slide"))
	var mult: float = float(opts.get("window_mult", 1.0))
	for key in ["hit_ms", "perfect_ms", "hit_deg", "perfect_deg", "tolerance"]:
		if _cmd.has(key):
			_cmd[key] = float(_cmd[key]) * mult
	_verb = str(opts.get("verb", "ATTACK"))
	_events = []
	_consumed = 0
	_held_since = -1.0
	_result = ""
	_extra = {}
	_resolved_at_ms = -1.0
	_frozen_t = -1.0
	_hold_value = 0.0
	_trace_points = PackedVector2Array()
	_trace_active = false
	_trace_released = false
	if _kind == "trace":
		_setup_trace()
	_title.text = "%s  --  %s" % [_verb, str(_cmd.get("name", "Strike"))]
	_hint.text = _hint_text()
	_start_us = Time.get_ticks_usec()
	_running = true
	visible = true
	_stage.visible = _uses_stage()
	_canvas.queue_redraw()
	_stage.queue_redraw()
	await finished
	visible = false
	var out: Dictionary = {"result": _result, "kind": _kind}
	out.merge(_extra)
	return out

func _uses_stage() -> bool:
	return _kind == "twin" or _kind == "trace"

func _hint_text() -> String:
	var strike := "[%s / %s / click]" % [_key_label(_block_key()), _key_label(_confirm_key())]
	match _kind:
		"slide": return "Press when the marker is in the zone.  %s" % strike
		"ring": return "Press as the ring closes on the bullseye.  %s" % strike
		"arc": return "Press when the marker is at the top of the arc.  %s" % strike
		"hold": return "HOLD to charge, RELEASE inside the zone.  %s" % strike
		"mash": return "MASH to lift the gauge into the band and keep it there.  %s" % strike
		"markers": return "Press as each marker crosses the zone: every hit is a strike.  %s" % strike
		"twin": return "Press %s for the circle marked Z, %s for the one marked X, as its ring closes." % [_key_label(_confirm_key()), _key_label(_cancel_key())]
		"orbit": return "HOLD to sweep the arm round, RELEASE inside the drifting zone.  %s" % strike
		"cross": return "Press as the crosshair crosses the centre.  %s" % strike
		"trace":
			var shape: Dictionary = AttackTimingsScript.SHAPES.get(str(_cmd.get("shape", "circle")), {})
			return "Hold the mouse button and trace the %s as closely as you can. Harder shapes cast harder." % str(shape.get("name", "shape")).to_lower()
		"arrows": return "Press the arrow keys in this order."
	return "Time it!"

func _now_ms() -> float:
	return float(Time.get_ticks_usec() - _start_us) / 1000.0

func _block_key() -> int:
	return _settings.get_key("block") if _settings != null else KEY_SPACE

func _confirm_key() -> int:
	return _settings.get_key("confirm") if _settings != null else KEY_Z

func _cancel_key() -> int:
	return _settings.get_key("cancel") if _settings != null else KEY_X

func _key_label(keycode: int) -> String:
	return OS.get_keycode_string(keycode).to_upper()

# ---------------------------------------------------------------- input
func _input(event: InputEvent) -> void:
	if not _running:
		return
	match _kind:
		"trace":
			_input_trace(event)
			return
		"arrows":
			_input_arrows(event)
			return
		"twin":
			_input_twin(event)
			return
	var strike := false
	var pressed := false
	if event is InputEventKey:
		if event.keycode == _block_key() or event.keycode == _confirm_key():
			strike = true
			pressed = event.pressed
			if event.echo:
				# Key-repeat of a held strike key is swallowed but never counted.
				get_viewport().set_input_as_handled()
				return
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		strike = true
		pressed = event.pressed
	if not strike:
		return
	if _result == "":
		_events.append([_now_ms(), pressed])
	get_viewport().set_input_as_handled()

# The gloves: the Confirm key answers the circle marked Z, the Cancel key the one marked X.
func _input_twin(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var tag := ""
	if event.keycode == _confirm_key():
		tag = "z"
	elif event.keycode == _cancel_key():
		tag = "x"
	if tag == "":
		return
	get_viewport().set_input_as_handled()
	if event.echo or not event.pressed:
		return
	if _result == "":
		_events.append([_now_ms(), true, tag])

# The staff: the four arrow keys.
func _input_arrows(event: InputEvent) -> void:
	if not (event is InputEventKey) or not ARROW_KEYS.has(event.keycode):
		return
	get_viewport().set_input_as_handled()
	if event.echo or not event.pressed:
		return
	if _result == "":
		_events.append([_now_ms(), true, str(ARROW_KEYS[event.keycode])])

# The wand: hold the left button and draw; letting go ends the stroke.
func _input_trace(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		if _result != "":
			return
		if event.pressed and not _trace_released:
			_trace_active = true
			_trace_points.append(_stage.get_local_mouse_position())
		elif not event.pressed and _trace_active:
			_trace_active = false
			_trace_released = true
	elif event is InputEventMouseMotion and _trace_active and _result == "":
		var p: Vector2 = _stage.get_local_mouse_position()
		if _trace_points.is_empty() or p.distance_to(_trace_points[_trace_points.size() - 1]) >= 3.0:
			_trace_points.append(p)

# Test hook: hands the wand a finished stroke (stage coordinates), as if the mouse had drawn it.
func inject_trace(points: PackedVector2Array) -> void:
	_trace_points = points
	_trace_released = true

# ---------------------------------------------------------------- the timeline
func _process(_delta: float) -> void:
	if not _running:
		return
	var now := _now_ms()
	if _result == "":
		_evaluate(now)
	elif now >= _resolved_at_ms + (STAGE_RESULT_HOLD_MS if _uses_stage() else RESULT_HOLD_MS):
		_running = false
		finished.emit()
		return
	_canvas.queue_redraw()
	if _uses_stage():
		_stage.queue_redraw()

func _resolve(result: String, t: float, now: float) -> void:
	_result = result
	_frozen_t = t
	_resolved_at_ms = now

# Feeds the events that have arrived so far (timestamps <= now) to the active command.
func _evaluate(now: float) -> void:
	match _kind:
		"slide", "ring", "arc", "cross":
			for e in _events:
				if bool(e[1]) and float(e[0]) <= now:
					_resolve(_grade_tap(float(e[0])), float(e[0]), now)
					return
			if now > float(_cmd.get("end_ms", 1200)):
				_resolve(AttackTimingsScript.MISS, now, now)
		"hold":
			var fill: float = float(_cmd.fill_ms)
			while _consumed < _events.size() and float(_events[_consumed][0]) <= now:
				var e: Array = _events[_consumed]
				_consumed += 1
				if bool(e[1]) and _held_since < 0.0:
					_held_since = float(e[0])
				elif not bool(e[1]) and _held_since >= 0.0:
					var held: float = float(e[0]) - _held_since
					_hold_value = held / fill
					_resolve(AttackTimingsScript.classify_hold(held, fill, _cmd.zone, _cmd.perfect), float(e[0]), now)
					return
			if _held_since >= 0.0 and now - _held_since > fill:
				_hold_value = (now - _held_since) / fill
				_resolve(AttackTimingsScript.MISS, now, now)
			elif _held_since < 0.0 and now > float(_cmd.get("wait_ms", 1500)):
				_resolve(AttackTimingsScript.MISS, now, now)
		"orbit":
			var orbit_fill: float = float(_cmd.fill_ms)
			while _consumed < _events.size() and float(_events[_consumed][0]) <= now:
				var oe: Array = _events[_consumed]
				_consumed += 1
				if bool(oe[1]) and _held_since < 0.0:
					_held_since = float(oe[0])
				elif not bool(oe[1]) and _held_since >= 0.0:
					var orbit_held: float = float(oe[0]) - _held_since
					_hold_value = orbit_held / orbit_fill
					var zone_deg: float = AttackTimingsScript.orbit_zone_deg(_cmd, float(oe[0]))
					_resolve(AttackTimingsScript.classify_orbit(orbit_held, orbit_fill, zone_deg, float(_cmd.hit_deg), float(_cmd.perfect_deg)), float(oe[0]), now)
					return
			if _held_since >= 0.0 and now - _held_since > orbit_fill:
				_hold_value = (now - _held_since) / orbit_fill
				_resolve(AttackTimingsScript.MISS, now, now)
			elif _held_since < 0.0 and now > float(_cmd.get("wait_ms", 1600)):
				_resolve(AttackTimingsScript.MISS, now, now)
		"mash":
			var m: Dictionary = AttackTimingsScript.mash_replay(_press_times(now), _cmd, now)
			if m.result != "":
				_extra = {"in_zone_ms": m.in_zone_ms}
				_resolve(str(m.result), float(m.done_ms), now)
		"markers":
			var beats: Array = _cmd.beats
			if now >= float(beats[beats.size() - 1]) + float(_cmd.hit_ms) + 60.0:
				var out: Dictionary = AttackTimingsScript.classify_beats(_press_times(now), beats, float(_cmd.hit_ms), float(_cmd.perfect_ms))
				_extra = {"hits": int(out.hits), "perfects": int(out.perfects), "markers": beats.size()}
				_resolve(str(out.result), now, now)
		"twin":
			if now >= float(_cmd.end_ms):
				var twin: Dictionary = AttackTimingsScript.classify_twin(_tagged_presses(now), _cmd.targets, float(_cmd.hit_ms), float(_cmd.perfect_ms))
				_extra = {"grades": twin.grades}
				_resolve(str(twin.result), now, now)
		"arrows":
			var a: Dictionary = AttackTimingsScript.classify_arrows(_tagged_presses(now), _cmd.sequence, float(_cmd.limit_ms), float(_cmd.fast_ms), now)
			if a.result != "":
				_extra = {"progress": int(a.progress), "keys": _cmd.sequence.size()}
				_resolve(str(a.result), now, now)
		"trace":
			if _trace_released or now > float(_cmd.limit_ms):
				var shape_score: Dictionary = AttackTimingsScript.trace_score(_trace_points, _trace_shape, float(_cmd.tolerance))
				var shape_id: String = str(_cmd.shape)
				_extra = {"shape": shape_id, "power": AttackTimingsScript.shape_power(shape_id), "coverage": shape_score.coverage, "precision": shape_score.precision}
				_resolve(str(shape_score.result), now, now)

func _press_times(now: float) -> Array:
	var out := []
	for e in _events:
		if bool(e[1]) and float(e[0]) <= now:
			out.append(float(e[0]))
	return out

func _tagged_presses(now: float) -> Array:
	var out := []
	for e in _events:
		if bool(e[1]) and float(e[0]) <= now:
			out.append([float(e[0]), str(e[2]) if e.size() > 2 else ""])
	return out

func _grade_tap(press_ms: float) -> String:
	if _kind == "cross":
		return AttackTimingsScript.classify_cross(press_ms, _cmd.crossings, float(_cmd.hit_ms), float(_cmd.perfect_ms))
	return AttackTimingsScript.classify_tap(press_ms, float(_cmd.target_ms), float(_cmd.hit_ms), float(_cmd.perfect_ms))

# The wand's shape, placed in the middle of the screen at a size that fits.
func _setup_trace() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	_trace_radius = clampf(minf(view.x, view.y) * 0.26, 70.0, 150.0)
	_trace_center = Vector2(view.x * 0.5, view.y * 0.46)
	var unit: PackedVector2Array = AttackTimingsScript.shape_points(str(_cmd.shape), float(_cmd.get("spin", 0.0)))
	_trace_shape = PackedVector2Array()
	for p in unit:
		_trace_shape.append(_trace_center + p * _trace_radius)

# ---------------------------------------------------------------- drawing: the popup
func _draw_telegraph() -> void:
	if _cmd.is_empty():
		return
	var size: Vector2 = _canvas.size
	var now := _now_ms()
	var t: float = _frozen_t if _result != "" else now
	var cy: float = size.y * 0.5
	match _kind:
		"slide": _draw_slide(size, t, cy)
		"ring": _draw_ring(size, t, cy)
		"arc": _draw_arc(size, t)
		"hold": _draw_hold(size, now, cy)
		"mash": _draw_mash(size, now)
		"markers": _draw_markers(size, now, cy)
		"twin": _draw_twin_popup(size, now)
		"orbit": _draw_orbit(size, now)
		"cross": _draw_cross(size, t, cy)
		"trace": _draw_trace_popup(size, now)
		"arrows": _draw_arrows(size, now)
	if _result != "" and now < _resolved_at_ms + (STAGE_RESULT_HOLD_MS if _uses_stage() else RESULT_HOLD_MS):
		var text := "PERFECT!"
		var col := GOOD
		if _result == AttackTimingsScript.HIT:
			text = "HIT"
			col = OKAY
		elif _result == AttackTimingsScript.MISS:
			text = "MISTIMED"
			col = BAD
		if _kind == "markers" and _extra.has("hits"):
			text = "%d / %d HITS" % [int(_extra.hits), int(_extra.markers)]
		elif _kind == "trace" and _result != AttackTimingsScript.MISS:
			text += "  x%.2f" % float(_extra.get("power", 1.0))
		elif _kind == "arrows" and _result == AttackTimingsScript.MISS:
			text = "WRONG KEY" if int(_extra.get("progress", 0)) < int(_extra.get("keys", 1)) and _was_wrong_key() else "TOO SLOW"
		_canvas.draw_string(PixelKit.font("body"), Vector2(0, 26), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 30, col)

func _was_wrong_key() -> bool:
	var a: Dictionary = AttackTimingsScript.classify_arrows(_tagged_presses(INF), _cmd.sequence, float(_cmd.limit_ms), float(_cmd.fast_ms), 0.0)
	return bool(a.wrong)

# Club: a bar, the zone dead centre, a marker sliding left to right.
func _draw_slide(size: Vector2, t: float, cy: float) -> void:
	var end_ms: float = float(_cmd.end_ms)
	var track := Rect2(10, cy - 14, size.x - 20, 28)
	var x_of := func(ms: float) -> float: return track.position.x + track.size.x * clampf(ms / end_ms, 0.0, 1.0)
	_draw_bar_zone(track, x_of, float(_cmd.target_ms), float(_cmd.hit_ms), float(_cmd.perfect_ms))
	_canvas.draw_rect(Rect2(float(x_of.call(t)) - 3, track.position.y - 7, 6, track.size.y + 14), ACCENT)

func _draw_bar_zone(track: Rect2, x_of: Callable, target: float, hit_ms: float, perfect_ms: float) -> void:
	_canvas.draw_rect(track, Color(1, 1, 1, 0.08))
	var hit_a: float = x_of.call(target - hit_ms)
	var hit_b: float = x_of.call(target + hit_ms)
	_canvas.draw_rect(Rect2(hit_a, track.position.y, hit_b - hit_a, track.size.y), Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35))
	var pa: float = x_of.call(target - perfect_ms)
	var pb: float = x_of.call(target + perfect_ms)
	_canvas.draw_rect(Rect2(pa, track.position.y, pb - pa, track.size.y), Color(1, 1, 1, 0.4))
	_canvas.draw_rect(track, Color(1, 1, 1, 0.5), false, 2.0)

# Spear: a bullseye, with a ring closing on it.
func _draw_ring(size: Vector2, t: float, cy: float) -> void:
	var center := Vector2(size.x * 0.5, cy)
	var target: float = float(_cmd.target_ms)
	var r_target := 22.0
	var r_start := 62.0
	var r_of := func(ms: float) -> float: return maxf(3.0, r_target + (r_start - r_target) * (1.0 - ms / target))
	# the bullseye: alternating discs, outermost first
	PixelFxScript.draw_disc(_canvas, center, r_target, Color(0.78, 0.2, 0.2), PIXEL_CELL)
	PixelFxScript.draw_disc(_canvas, center, r_target * 0.72, Color(0.95, 0.93, 0.88), PIXEL_CELL)
	PixelFxScript.draw_disc(_canvas, center, r_target * 0.46, Color(0.78, 0.2, 0.2), PIXEL_CELL)
	PixelFxScript.draw_disc(_canvas, center, r_target * 0.2, Color(0.95, 0.93, 0.88), PIXEL_CELL)
	var hit_out: float = r_of.call(target - float(_cmd.hit_ms))
	var hit_in: float = r_of.call(target + float(_cmd.hit_ms))
	PixelFxScript.draw_ring(_canvas, center, (hit_out + hit_in) * 0.5, maxf(2.0, hit_out - hit_in), Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.3), PIXEL_CELL)
	var p_out: float = r_of.call(target - float(_cmd.perfect_ms))
	var p_in: float = r_of.call(target + float(_cmd.perfect_ms))
	PixelFxScript.draw_ring(_canvas, center, (p_out + p_in) * 0.5, maxf(2.0, p_out - p_in), Color(1, 1, 1, 0.35), PIXEL_CELL)
	PixelFxScript.draw_ring(_canvas, center, r_target, 2.0, Color(1, 1, 1, 0.6), PIXEL_CELL)
	PixelFxScript.draw_ring(_canvas, center, r_of.call(t), 5.0, ACCENT, PIXEL_CELL)

# Greatsword: the Club's bar bent into an arc; the marker rides it from the left end to the right, the zone sits at the top.
func _draw_arc(size: Vector2, t: float) -> void:
	var end_ms: float = float(_cmd.end_ms)
	var radius := 112.0
	var center := Vector2(size.x * 0.5, size.y - 4.0 + radius * 0.34)
	var half_span := deg_to_rad(62.0)
	var angle_of := func(ms: float) -> float: return -PI / 2.0 - half_span + 2.0 * half_span * clampf(ms / end_ms, 0.0, 1.0)
	var target: float = float(_cmd.target_ms)
	PixelFxScript.draw_ring(_canvas, center, radius, 24.0, Color(1, 1, 1, 0.08), PIXEL_CELL, angle_of.call(0.0), angle_of.call(end_ms))
	PixelFxScript.draw_ring(_canvas, center, radius, 24.0, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35), PIXEL_CELL, angle_of.call(target - float(_cmd.hit_ms)), angle_of.call(target + float(_cmd.hit_ms)))
	PixelFxScript.draw_ring(_canvas, center, radius, 24.0, Color(1, 1, 1, 0.4), PIXEL_CELL, angle_of.call(target - float(_cmd.perfect_ms)), angle_of.call(target + float(_cmd.perfect_ms)))
	var a: float = angle_of.call(t)
	var p: Vector2 = center + Vector2(cos(a), sin(a)) * radius
	PixelFxScript.draw_disc(_canvas, p, 9.0, ACCENT, PIXEL_CELL)
	PixelFxScript.draw_ring(_canvas, p, 9.0, 2.0, Color(1, 1, 1, 0.9), PIXEL_CELL)

# Hammer: a horizontal meter that fills while held.
func _draw_hold(size: Vector2, now: float, cy: float) -> void:
	var meter := Rect2(10, cy - 14, size.x - 20, 28)
	_canvas.draw_rect(meter, Color(1, 1, 1, 0.08))
	var zone: Array = _cmd.zone
	var perfect: Array = _cmd.perfect
	_canvas.draw_rect(Rect2(meter.position.x + meter.size.x * float(zone[0]), meter.position.y, meter.size.x * (float(zone[1]) - float(zone[0])), meter.size.y), Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35))
	_canvas.draw_rect(Rect2(meter.position.x + meter.size.x * float(perfect[0]), meter.position.y, meter.size.x * (float(perfect[1]) - float(perfect[0])), meter.size.y), Color(1, 1, 1, 0.4))
	var v := 0.0
	if _result != "":
		v = _hold_value
	elif _held_since >= 0.0:
		v = (now - _held_since) / float(_cmd.fill_ms)
	v = clampf(v, 0.0, 1.0)
	_canvas.draw_rect(Rect2(meter.position.x, meter.position.y + 6, meter.size.x * v, meter.size.y - 12), ACCENT)
	_canvas.draw_rect(meter, Color(1, 1, 1, 0.5), false, 2.0)

# Battle axe: an upright gauge that never stops draining; the band to reach is lit.
func _draw_mash(size: Vector2, now: float) -> void:
	var gauge := Rect2(size.x * 0.5 - 22.0, 6.0, 44.0, size.y - 12.0)
	var zone: Array = _cmd.zone
	var y_of := func(v: float) -> float: return gauge.position.y + gauge.size.y * (1.0 - clampf(v, 0.0, 1.0))
	_canvas.draw_rect(gauge, Color(1, 1, 1, 0.08))
	var zt: float = y_of.call(float(zone[1]))
	var zb: float = y_of.call(float(zone[0]))
	_canvas.draw_rect(Rect2(gauge.position.x, zt, gauge.size.x, zb - zt), Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35))
	var third: float = (float(zone[1]) - float(zone[0])) / 3.0
	var ct: float = y_of.call(float(zone[1]) - third)
	var cb: float = y_of.call(float(zone[0]) + third)
	_canvas.draw_rect(Rect2(gauge.position.x, ct, gauge.size.x, cb - ct), Color(1, 1, 1, 0.3))
	var replay: Dictionary = AttackTimingsScript.mash_replay(_press_times(INF), _cmd, _frozen_t if _result != "" else now)
	var level: float = float(replay.value)
	var fy: float = y_of.call(level)
	_canvas.draw_rect(Rect2(gauge.position.x + 6.0, fy, gauge.size.x - 12.0, gauge.position.y + gauge.size.y - fy), ACCENT)
	_canvas.draw_rect(Rect2(gauge.position.x - 4.0, fy - 2.0, gauge.size.x + 8.0, 4.0), Color(1, 1, 1, 0.9))
	_canvas.draw_rect(gauge, Color(1, 1, 1, 0.5), false, 2.0)
	# how long it has held in the band, as a bar along the bottom
	var need: float = float(_cmd.need_ms)
	var held_share: float = clampf(float(replay.in_zone_ms) / need, 0.0, 1.0)
	_canvas.draw_rect(Rect2(10.0, size.y - 8.0, (size.x - 20.0) * held_share, 4.0), GOOD)
	_canvas.draw_rect(Rect2(10.0, size.y - 8.0, size.x - 20.0, 4.0), Color(1, 1, 1, 0.3), false, 1.0)

# Dagger: the Club's bar with the zone in the middle and a handful of markers sliding through it in their own rhythm.
func _draw_markers(size: Vector2, now: float, cy: float) -> void:
	var beats: Array = _cmd.beats
	var travel: float = float(_cmd.travel_ms)
	var track := Rect2(10, cy - 14, size.x - 20, 28)
	var center_x: float = track.position.x + track.size.x * 0.5
	var px_per_ms: float = track.size.x / travel
	var hit_ms: float = float(_cmd.hit_ms)
	var perfect_ms: float = float(_cmd.perfect_ms)
	_canvas.draw_rect(track, Color(1, 1, 1, 0.08))
	_canvas.draw_rect(Rect2(center_x - hit_ms * px_per_ms, track.position.y, hit_ms * 2.0 * px_per_ms, track.size.y), Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35))
	_canvas.draw_rect(Rect2(center_x - perfect_ms * px_per_ms, track.position.y, perfect_ms * 2.0 * px_per_ms, track.size.y), Color(1, 1, 1, 0.4))
	_canvas.draw_rect(track, Color(1, 1, 1, 0.5), false, 2.0)
	var t: float = _frozen_t if _result != "" else now
	var grades: Array = AttackTimingsScript.classify_beats(_press_times(t), beats, hit_ms, perfect_ms).beats
	for i in beats.size():
		var x: float = center_x + (t - float(beats[i])) * px_per_ms
		if x < track.position.x - 6.0 or x > track.position.x + track.size.x + 6.0:
			continue
		var col := ACCENT
		if t > float(beats[i]) + hit_ms:
			col = GOOD if grades[i] == AttackTimingsScript.PERFECT else (OKAY if grades[i] == AttackTimingsScript.HIT else BAD)
		_canvas.draw_rect(Rect2(x - 3.0, track.position.y - 6.0, 6.0, track.size.y + 12.0), col)

# Gloves: the popup only says which key is which; the circles themselves are on the stage.
func _draw_twin_popup(size: Vector2, now: float) -> void:
	var targets: Array = _cmd.targets
	for i in targets.size():
		var key_text: String = _key_label(_confirm_key() if str(targets[i].key) == "z" else _cancel_key())
		var x: float = size.x * (0.3 + 0.4 * float(i))
		var col := ACCENT
		if _result != "":
			col = _grade_color(str(_extra.get("grades", ["", ""])[i])) if _extra.has("grades") else ACCENT
		PixelFxScript.draw_disc(_canvas, Vector2(x, size.y * 0.5), 26.0, Color(col.r, col.g, col.b, 0.25), PIXEL_CELL)
		PixelFxScript.draw_ring(_canvas, Vector2(x, size.y * 0.5), 26.0, 3.0, col, PIXEL_CELL)
		_canvas.draw_string(PixelKit.font("body"), Vector2(x - 30.0, size.y * 0.5 + 9.0), key_text, HORIZONTAL_ALIGNMENT_CENTER, 60.0, 30, Color(1, 1, 1, 0.95))
	_canvas.draw_string(PixelKit.font("body"), Vector2(0, size.y - 6.0), "the circles are on the screen", HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, Color(1, 1, 1, 0.4))

func _grade_color(grade: String) -> Color:
	match grade:
		AttackTimingsScript.PERFECT: return GOOD
		AttackTimingsScript.HIT: return OKAY
	return BAD

# Hand picks: a round dial. The arm sweeps clockwise from the top while you hold; the lit zone keeps drifting round it.
func _draw_orbit(size: Vector2, now: float) -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.5)
	var radius := 58.0
	var t: float = _frozen_t if _result != "" else now
	PixelFxScript.draw_ring(_canvas, center, radius, 14.0, Color(1, 1, 1, 0.08), PIXEL_CELL)
	var zone_deg: float = AttackTimingsScript.orbit_zone_deg(_cmd, t)
	var a_of := func(deg: float) -> float: return deg_to_rad(deg) - PI / 2.0
	var hit_deg: float = float(_cmd.hit_deg)
	var perfect_deg: float = float(_cmd.perfect_deg)
	PixelFxScript.draw_ring(_canvas, center, radius, 14.0, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.4), PIXEL_CELL, a_of.call(zone_deg - hit_deg), a_of.call(zone_deg + hit_deg))
	PixelFxScript.draw_ring(_canvas, center, radius, 14.0, Color(1, 1, 1, 0.45), PIXEL_CELL, a_of.call(zone_deg - perfect_deg), a_of.call(zone_deg + perfect_deg))
	PixelFxScript.draw_ring(_canvas, center, radius + 8.0, 2.0, Color(1, 1, 1, 0.5), PIXEL_CELL)
	var v := 0.0
	if _result != "":
		v = _hold_value
	elif _held_since >= 0.0:
		v = (now - _held_since) / float(_cmd.fill_ms)
	v = clampf(v, 0.0, 1.0)
	var arm: float = a_of.call(360.0 * v)
	PixelFxScript.draw_line_px(_canvas, center, center + Vector2(cos(arm), sin(arm)) * (radius + 4.0), 5.0, ACCENT, PIXEL_CELL)
	PixelFxScript.draw_disc(_canvas, center, 7.0, ACCENT, PIXEL_CELL)

# Bow: the crosshair swinging back and forth.
func _draw_cross(size: Vector2, t: float, cy: float) -> void:
	var crossings: Array = _cmd.crossings
	var delta: float = float(crossings[1]) - float(crossings[0])
	var amp: float = size.x * 0.44
	var cx: float = size.x * 0.5
	var zone_half: float = amp * sin(PI * float(_cmd.hit_ms) / delta)
	var perfect_half: float = amp * sin(PI * float(_cmd.perfect_ms) / delta)
	_canvas.draw_rect(Rect2(cx - amp, cy - 2, amp * 2.0, 4), Color(1, 1, 1, 0.1))
	_canvas.draw_rect(Rect2(cx - zone_half, cy - 22, zone_half * 2.0, 44), Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.3))
	_canvas.draw_rect(Rect2(cx - perfect_half, cy - 22, perfect_half * 2.0, 44), Color(1, 1, 1, 0.35))
	PixelFxScript.draw_line_px(_canvas, Vector2(cx, cy - 28), Vector2(cx, cy + 28), 2.0, Color(1, 1, 1, 0.7), PIXEL_CELL)
	var x: float = cx + amp * sin(PI * (t - float(crossings[0])) / delta)
	PixelFxScript.draw_disc(_canvas, Vector2(x, cy), 9.0, ACCENT, PIXEL_CELL)
	PixelFxScript.draw_ring(_canvas, Vector2(x, cy), 9.0, 2.0, Color(1, 1, 1, 0.9), PIXEL_CELL)

# Wand: the popup shows the shape's name and what it is worth, and a bar of the time left.
func _draw_trace_popup(size: Vector2, now: float) -> void:
	var shape_id: String = str(_cmd.shape)
	var info: Dictionary = AttackTimingsScript.SHAPES.get(shape_id, {})
	_canvas.draw_string(PixelKit.font("body"), Vector2(0, 58.0), str(info.get("name", shape_id)).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 30, Color(1, 1, 1, 0.9))
	_canvas.draw_string(PixelKit.font("body"), Vector2(0, 88.0), "power x%.2f" % AttackTimingsScript.shape_power(shape_id), HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, OKAY)
	var left: float = clampf(1.0 - (_frozen_t if _result != "" else now) / float(_cmd.limit_ms), 0.0, 1.0)
	_canvas.draw_rect(Rect2(10.0, size.y - 14.0, (size.x - 20.0) * left, 6.0), ACCENT)
	_canvas.draw_rect(Rect2(10.0, size.y - 14.0, size.x - 20.0, 6.0), Color(1, 1, 1, 0.3), false, 1.0)

# Staff: the arrows to press, the ones already right lit, and a bar of the time left.
func _draw_arrows(size: Vector2, now: float) -> void:
	var seq: Array = _cmd.sequence
	var n: int = seq.size()
	var t: float = _frozen_t if _result != "" else now
	var progress: int = int(AttackTimingsScript.classify_arrows(_tagged_presses(t), seq, float(_cmd.limit_ms), float(_cmd.fast_ms), t).progress)
	var gap := 8.0
	var cell: float = floorf(minf(5.0, (size.x - 20.0 - float(n - 1) * gap) / (float(n) * 7.0)))
	var glyph: float = 7.0 * cell
	var total: float = n * glyph + (n - 1) * gap
	var x0: float = (size.x - total) * 0.5
	for i in n:
		var col := Color(1, 1, 1, 0.35)
		if i < progress:
			col = GOOD
		elif i == progress and _result == "":
			col = ACCENT
		elif _result != "" and i == progress:
			col = BAD
		_draw_arrow(Vector2(x0 + i * (glyph + gap), size.y * 0.42 - glyph * 0.5), str(seq[i]), cell, col)
	var left: float = clampf(1.0 - t / float(_cmd.limit_ms), 0.0, 1.0)
	_canvas.draw_rect(Rect2(10.0, size.y - 16.0, (size.x - 20.0) * left, 6.0), ACCENT)
	_canvas.draw_rect(Rect2(10.0, size.y - 16.0, size.x - 20.0, 6.0), Color(1, 1, 1, 0.3), false, 1.0)

# An arrow glyph from squares: ARROW_UP, turned to point the right way.
func _draw_arrow(top_left: Vector2, dir: String, cell: float, col: Color) -> void:
	for y in 7:
		for x in 7:
			if ARROW_UP[y][x] != "#":
				continue
			var gx := x
			var gy := y
			match dir:
				"down":
					gy = 6 - y
				"left":
					gx = y
					gy = x
				"right":
					gx = 6 - y
					gy = x
			_canvas.draw_rect(Rect2(top_left + Vector2(gx, gy) * cell, Vector2(cell, cell)), col)

# ---------------------------------------------------------------- drawing: the stage
func _draw_stage() -> void:
	if _cmd.is_empty() or not _running or not _uses_stage():
		return
	var size: Vector2 = _stage.size
	_stage.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.01, 0.05, 0.45))
	var now := _now_ms()
	if _kind == "twin":
		_draw_twin_stage(size, now)
	elif _kind == "trace":
		_draw_trace_stage(size, now)

# Gloves: the two circles, each with a ring closing in on it and its key's letter inside.
func _draw_twin_stage(size: Vector2, now: float) -> void:
	var targets: Array = _cmd.targets
	var close_ms: float = float(_cmd.close_ms)
	var hit_ms: float = float(_cmd.hit_ms)
	var margin := Vector2(120.0, 90.0)
	var area := Rect2(margin, size - margin * 2.0)
	var t: float = _frozen_t if _result != "" else now
	var grades: Array = _extra.get("grades", [])
	for i in targets.size():
		var tgt: Dictionary = targets[i]
		var c: Vector2 = area.position + area.size * Vector2(tgt.pos)
		var key_text: String = _key_label(_confirm_key() if str(tgt.key) == "z" else _cancel_key())
		var col := ACCENT
		if _result != "" and i < grades.size():
			col = _grade_color(str(grades[i]))
		elif t > float(tgt.ms) + hit_ms:
			col = BAD
		PixelFxScript.draw_disc(_stage, c, 26.0, Color(col.r, col.g, col.b, 0.28), PIXEL_CELL)
		PixelFxScript.draw_ring(_stage, c, 26.0, 3.0, Color(1, 1, 1, 0.8), PIXEL_CELL)
		_stage.draw_string(PixelKit.font("body"), Vector2(c.x - 30.0, c.y + 9.0), key_text, HORIZONTAL_ALIGNMENT_CENTER, 60.0, 30, Color(1, 1, 1, 0.95))
		var to_go: float = float(tgt.ms) - t
		if to_go > -hit_ms and to_go < close_ms:
			var r: float = 26.0 + 60.0 * clampf(to_go / close_ms, 0.0, 1.0)
			PixelFxScript.draw_ring(_stage, c, r, 4.0, col, PIXEL_CELL)

# Wand: the shape as a dotted outline, and the line drawn so far.
func _draw_trace_stage(size: Vector2, now: float) -> void:
	var dotted: PackedVector2Array = AttackTimingsScript.resample(_trace_shape, 72)
	for i in dotted.size():
		if i % 2 == 0:
			_stage.draw_rect(Rect2(dotted[i] - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), Color(1, 1, 1, 0.75))
	if not _trace_shape.is_empty():
		_stage.draw_rect(Rect2(_trace_shape[0] - Vector2(5.0, 5.0), Vector2(10.0, 10.0)), GOOD)
	var col := ACCENT
	if _result != "":
		col = _grade_color(_result)
	for i in range(1, _trace_points.size()):
		PixelFxScript.draw_line_px(_stage, _trace_points[i - 1], _trace_points[i], 4.0, col, PIXEL_CELL)
	if _result != "" and _extra.has("coverage"):
		_stage.draw_string(PixelKit.font("body"), Vector2(0, _trace_center.y + _trace_radius + 40.0), "followed %d%%   on target %d%%" % [int(round(float(_extra.coverage) * 100.0)), int(round(float(_extra.precision) * 100.0))], HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, Color(1, 1, 1, 0.7))
