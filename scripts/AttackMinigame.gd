extends CanvasLayer

# The weapon attack popup: a short timing command per weapon family (commands and grading live in
# AttackTimings.gd). Usage (Main.gd):  var outcome: Dictionary = await minigame.run(command)
# -> {"result": "miss" | "hit" | "perfect", ...}.
#
# Strike input is the block key (Space), the Confirm key (Z) or a left click. Like DefenseMinigame
# it reads key/mouse events as they arrive (Time.get_ticks_usec), so timing is only as coarse as
# the game's input delivery (about one frame).

signal finished

const AttackTimingsScript := preload("res://scripts/AttackTimings.gd")

# Test hook: while this holds entries, run() skips the UI and input and answers from here
# (a result string or a result dictionary per call, consumed from the front).
static var forced_results: Array = []

const RESULT_HOLD_MS := 380.0
const ACCENT := Color(1.0, 0.5, 0.35)

var _running := false
var _cmd: Dictionary = {}
var _kind := ""
var _start_us := 0
var _events: Array = []        # [ms, pressed]
var _consumed := 0             # events already fed to the hold state machine
var _held_since := -1.0
var _result := ""
var _resolved_at_ms := -1.0
var _frozen_t := -1.0          # the clock reading the telegraph freezes on once resolved
var _hold_value := 0.0
var _panel: Panel
var _title: Label
var _hint: Label
var _canvas: Control
var _settings: Node

func _ready() -> void:
	layer = 48
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_settings = get_node_or_null("/root/Settings")
	_panel = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.93)
	style.border_color = Color(0.7, 0.62, 0.35)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.size = Vector2(440, 250)
	add_child(_panel)
	_title = Label.new()
	_title.position = Vector2(16, 8)
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", ACCENT)
	_panel.add_child(_title)
	_hint = Label.new()
	_hint.position = Vector2(16, 40)
	_hint.size = Vector2(408, 40)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_color", Color(0.78, 0.78, 0.82))
	_panel.add_child(_hint)
	_canvas = Control.new()
	_canvas.position = Vector2(16, 84)
	_canvas.size = Vector2(408, 150)
	_canvas.draw.connect(_draw_telegraph)
	_panel.add_child(_canvas)
	get_viewport().size_changed.connect(_place_panel)
	_place_panel()

func _place_panel() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	# Bottom-right, same spot as the defense popup: the battle grid sits on the left.
	_panel.position = Vector2(maxf(vs.x * 0.56, vs.x - _panel.size.x - 24.0), vs.y - _panel.size.y - 30.0).round()

# ---------------------------------------------------------------- running a popup
func run(command: Dictionary, opts: Dictionary = {}) -> Dictionary:
	if not forced_results.is_empty():
		var forced = forced_results.pop_front()
		if typeof(forced) == TYPE_STRING:
			return {"result": str(forced)}
		return (forced as Dictionary).duplicate()
	_cmd = command.duplicate(true)
	_kind = str(_cmd.get("kind", "slide"))
	var mult: float = float(opts.get("window_mult", 1.0))
	for key in ["hit_ms", "perfect_ms"]:
		if _cmd.has(key):
			_cmd[key] = float(_cmd[key]) * mult
	_events = []
	_consumed = 0
	_held_since = -1.0
	_result = ""
	_resolved_at_ms = -1.0
	_frozen_t = -1.0
	_hold_value = 0.0
	_title.text = "ATTACK  --  %s" % str(_cmd.get("name", "Strike"))
	_hint.text = "%s  [%s / %s / click]" % [_hint_text(), _key_label(_block_key()), _key_label(_confirm_key())]
	_start_us = Time.get_ticks_usec()
	_running = true
	visible = true
	_canvas.queue_redraw()
	await finished
	visible = false
	return {"result": _result, "kind": _kind}

func _hint_text() -> String:
	match _kind:
		"slide": return "Press when the marker is in the zone."
		"ring": return "Press as the ring closes on the target."
		"sweep": return "Press while the arm is inside the bright arc."
		"hold": return "HOLD to charge, RELEASE inside the zone."
		"beats": return "Tap every pulse as its ring closes."
		"cross": return "Press as the crosshair crosses the centre."
	return "Time it!"

func _now_ms() -> float:
	return float(Time.get_ticks_usec() - _start_us) / 1000.0

func _block_key() -> int:
	return _settings.get_key("block") if _settings != null else KEY_SPACE

func _confirm_key() -> int:
	return _settings.get_key("confirm") if _settings != null else KEY_Z

func _key_label(keycode: int) -> String:
	return OS.get_keycode_string(keycode).to_upper()

# ---------------------------------------------------------------- input
func _input(event: InputEvent) -> void:
	if not _running:
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

# ---------------------------------------------------------------- the timeline
func _process(_delta: float) -> void:
	if not _running:
		return
	var now := _now_ms()
	if _result == "":
		_evaluate(now)
	elif now >= _resolved_at_ms + RESULT_HOLD_MS:
		_running = false
		finished.emit()
		return
	_canvas.queue_redraw()

func _resolve(result: String, t: float, now: float) -> void:
	_result = result
	_frozen_t = t
	_resolved_at_ms = now

# Feeds the events that have arrived so far (timestamps <= now) to the active command.
func _evaluate(now: float) -> void:
	match _kind:
		"slide", "ring", "sweep", "cross":
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
		"beats":
			var beats: Array = _cmd.beats
			if now >= float(beats[beats.size() - 1]) + float(_cmd.hit_ms) + 60.0:
				var out: Dictionary = AttackTimingsScript.classify_beats(_press_times(now), beats, float(_cmd.hit_ms), float(_cmd.perfect_ms))
				_resolve(str(out.result), now, now)

func _press_times(now: float) -> Array:
	var out := []
	for e in _events:
		if bool(e[1]) and float(e[0]) <= now:
			out.append(float(e[0]))
	return out

func _grade_tap(press_ms: float) -> String:
	if _kind == "cross":
		return AttackTimingsScript.classify_cross(press_ms, _cmd.crossings, float(_cmd.hit_ms), float(_cmd.perfect_ms))
	return AttackTimingsScript.classify_tap(press_ms, float(_cmd.target_ms), float(_cmd.hit_ms), float(_cmd.perfect_ms))

# ---------------------------------------------------------------- drawing
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
		"sweep": _draw_sweep(size, t, cy)
		"hold": _draw_hold(size, now, cy)
		"beats": _draw_beats(size, now, cy)
		"cross": _draw_cross(size, t, cy)
	if _result != "" and now < _resolved_at_ms + RESULT_HOLD_MS:
		var text := "PERFECT!"
		var col := Color(0.5, 1.0, 0.6)
		if _result == AttackTimingsScript.HIT:
			text = "HIT"
			col = Color(1.0, 0.85, 0.4)
		elif _result == AttackTimingsScript.MISS:
			text = "MISTIMED"
			col = Color(1.0, 0.4, 0.35)
		_canvas.draw_string(ThemeDB.fallback_font, Vector2(0, 26), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 30, col)

func _draw_slide(size: Vector2, t: float, cy: float) -> void:
	var end_ms: float = float(_cmd.end_ms)
	var track := Rect2(10, cy - 14, size.x - 20, 28)
	var x_of := func(ms: float) -> float: return track.position.x + track.size.x * clampf(ms / end_ms, 0.0, 1.0)
	_canvas.draw_rect(track, Color(1, 1, 1, 0.08))
	var target: float = float(_cmd.target_ms)
	var hit_a: float = x_of.call(target - float(_cmd.hit_ms))
	var hit_b: float = x_of.call(target + float(_cmd.hit_ms))
	_canvas.draw_rect(Rect2(hit_a, track.position.y, hit_b - hit_a, track.size.y), Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35))
	var pa: float = x_of.call(target - float(_cmd.perfect_ms))
	var pb: float = x_of.call(target + float(_cmd.perfect_ms))
	_canvas.draw_rect(Rect2(pa, track.position.y, pb - pa, track.size.y), Color(1, 1, 1, 0.4))
	_canvas.draw_rect(track, Color(1, 1, 1, 0.5), false, 2.0)
	_canvas.draw_rect(Rect2(float(x_of.call(t)) - 3, track.position.y - 7, 6, track.size.y + 14), ACCENT)

func _draw_ring(size: Vector2, t: float, cy: float) -> void:
	var center := Vector2(size.x * 0.5, cy)
	var target: float = float(_cmd.target_ms)
	var r_target := 22.0
	var r_start := 62.0
	var r_of := func(ms: float) -> float: return maxf(3.0, r_target + (r_start - r_target) * (1.0 - ms / target))
	var hit_out: float = r_of.call(target - float(_cmd.hit_ms))
	var hit_in: float = r_of.call(target + float(_cmd.hit_ms))
	_canvas.draw_arc(center, (hit_out + hit_in) * 0.5, 0, TAU, 48, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.3), maxf(2.0, hit_out - hit_in))
	var p_out: float = r_of.call(target - float(_cmd.perfect_ms))
	var p_in: float = r_of.call(target + float(_cmd.perfect_ms))
	_canvas.draw_arc(center, (p_out + p_in) * 0.5, 0, TAU, 48, Color(1, 1, 1, 0.35), maxf(2.0, p_out - p_in))
	_canvas.draw_arc(center, r_target, 0, TAU, 48, Color(1, 1, 1, 0.6), 2.0)
	_canvas.draw_arc(center, r_of.call(t), 0, TAU, 64, ACCENT, 5.0)

func _draw_sweep(size: Vector2, t: float, cy: float) -> void:
	var center := Vector2(size.x * 0.5, cy)
	var radius := 54.0
	var target: float = float(_cmd.target_ms)
	var omega: float = (PI * 1.5) / target
	_canvas.draw_arc(center, radius, 0, TAU, 64, Color(1, 1, 1, 0.25), 2.0)
	var hit_half: float = omega * float(_cmd.hit_ms)
	var perfect_half: float = omega * float(_cmd.perfect_ms)
	_canvas.draw_arc(center, radius, -PI / 2.0 - hit_half, -PI / 2.0 + hit_half, 24, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.7), 9.0)
	_canvas.draw_arc(center, radius, -PI / 2.0 - perfect_half, -PI / 2.0 + perfect_half, 16, Color(1, 1, 1, 0.9), 9.0)
	var angle: float = -PI / 2.0 + omega * (t - target)
	_canvas.draw_line(center, center + Vector2(cos(angle), sin(angle)) * radius, ACCENT, 5.0)

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

func _draw_beats(size: Vector2, now: float, cy: float) -> void:
	var beats: Array = _cmd.beats
	var n: int = beats.size()
	var hit_ms: float = float(_cmd.hit_ms)
	var grades: Array = AttackTimingsScript.classify_beats(_press_times(now), beats, hit_ms, float(_cmd.perfect_ms)).beats
	for i in n:
		var center := Vector2(size.x * float(i + 1) / float(n + 1), cy)
		var beat: float = float(beats[i])
		_canvas.draw_arc(center, 15.0, 0, TAU, 32, Color(1, 1, 1, 0.6), 2.0)
		var over: bool = now > beat + hit_ms
		if over:
			var col := Color(0.5, 1.0, 0.6) if grades[i] == AttackTimingsScript.PERFECT else (Color(1.0, 0.85, 0.4) if grades[i] == AttackTimingsScript.HIT else Color(1.0, 0.4, 0.35))
			_canvas.draw_circle(center, 11.0, Color(col.r, col.g, col.b, 0.8))
		elif now >= beat - 600.0:
			var r: float = 15.0 + 34.0 * clampf((beat - now) / 600.0, 0.0, 1.0)
			_canvas.draw_arc(center, r, 0, TAU, 48, ACCENT, 4.0)

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
	_canvas.draw_line(Vector2(cx, cy - 28), Vector2(cx, cy + 28), Color(1, 1, 1, 0.7), 2.0)
	var x: float = cx + amp * sin(PI * (t - float(crossings[0])) / delta)
	_canvas.draw_circle(Vector2(x, cy), 9.0, ACCENT)
	_canvas.draw_arc(Vector2(x, cy), 9.0, 0, TAU, 24, Color(1, 1, 1, 0.9), 2.0)
