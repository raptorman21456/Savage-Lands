extends CanvasLayer

# The dodge / block popup shown while an enemy attack lands on you.
#
#   DODGE: press a direction key as the cue lands -- that's also the way you roll.
#   BLOCK: hold the block key (Space) to raise the shield; a raise OR a lower within
#          PARRY_MS of the impact is a parry (the whole hit is blocked).
#
# Usage (Main.gd):  var results: Array = await minigame.run("dodge", pattern, {...})
# -> one result per impact: {"outcome": "perfect"|"good"|"miss" (dodge) or "parry"|"block"|"fail"
# (block), "dir": Vector2i (dodge roll direction), "mult": the impact's damage share}.
# Timing is read from key events as they arrive (Time.get_ticks_usec), not from per-frame
# polling, so it is only as coarse as the game's input delivery (about one frame).

signal finished

const AttackPatternsScript := preload("res://scripts/AttackPatterns.gd")

# Test hook: while this holds entries, run() skips the UI and input entirely and answers from
# here (a string outcome or a result dictionary per impact, consumed from the front).
static var forced_results: Array = []

const END_PADDING_MS := 520.0
const DODGE_COLOR := Color(0.45, 0.85, 1.0)
const BLOCK_COLOR := Color(1.0, 0.72, 0.28)
const DIR_KEYS := {"move_up": Vector2i(0, -1), "move_down": Vector2i(0, 1), "move_left": Vector2i(-1, 0), "move_right": Vector2i(1, 0)}

var _running := false
var _mode := "dodge"
var _pattern: Dictionary = {}
var _impacts: Array = []
var _window_ms := 160.0
var _parry_ms := 45.0
var _start_us := 0
var _events: Array = []          # block: [ms, pressed]
var _presses: Array = []         # dodge: [ms, Vector2i]
var _held_at_start := false
var _resolved: Array = []        # per impact: result Dictionary or null
var _flash_text := ""
var _flash_color := Color.WHITE
var _flash_until_ms := 0.0
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
	# Bottom-right: the battle grid sits on the left and the action menu under it, both hidden or idle on an enemy turn.
	_panel.position = Vector2(maxf(vs.x * 0.56, vs.x - _panel.size.x - 24.0), vs.y - _panel.size.y - 30.0).round()

# ---------------------------------------------------------------- running a popup
func run(mode: String, pattern: Dictionary, opts: Dictionary = {}) -> Array:
	if not forced_results.is_empty():
		return _forced(pattern)
	_mode = mode
	_pattern = pattern
	_impacts = pattern.impacts.duplicate(true)
	_window_ms = float(pattern.get("dodge_ms", 160)) * float(opts.get("window_mult", 1.0))
	_parry_ms = float(opts.get("parry_ms", AttackPatternsScript.PARRY_MS))
	_events = []
	_presses = []
	_resolved = []
	for i in _impacts.size():
		_resolved.append(null)
	_flash_text = ""
	_flash_until_ms = 0.0
	_held_at_start = _key_down(_block_key())
	var accent: Color = DODGE_COLOR if mode == "dodge" else BLOCK_COLOR
	_title.text = "%s  --  %s" % ["DODGE" if mode == "dodge" else "BLOCK", str(pattern.get("name", "Attack"))]
	_title.add_theme_color_override("font_color", accent)
	_hint.text = ("Press a DIRECTION key as the cue lands -- you roll that way." if mode == "dodge"
		else "Hold %s to raise your shield. Raise or lower it right at the impact to PARRY." % _key_label(_block_key()))
	_start_us = Time.get_ticks_usec()
	_running = true
	visible = true
	_canvas.queue_redraw()
	await finished
	visible = false
	return _resolved.duplicate(true)

func _forced(pattern: Dictionary) -> Array:
	var out := []
	for hit in pattern.impacts:
		var entry = forced_results.pop_front() if not forced_results.is_empty() else ("miss" if _mode == "dodge" else "fail")
		var res: Dictionary = {"outcome": entry} if typeof(entry) == TYPE_STRING else (entry as Dictionary).duplicate()
		res["mult"] = float(hit.mult)
		if not res.has("dir"):
			res["dir"] = Vector2i.ZERO
		out.append(res)
	return out

func _now_ms() -> float:
	return float(Time.get_ticks_usec() - _start_us) / 1000.0

func _block_key() -> int:
	return _settings.get_key("block") if _settings != null else KEY_SPACE

func _key_down(keycode: int) -> bool:
	return Input.is_key_pressed(keycode)

func _key_label(keycode: int) -> String:
	return OS.get_keycode_string(keycode).to_upper()

# ---------------------------------------------------------------- input
func _input(event: InputEvent) -> void:
	if not _running or not (event is InputEventKey):
		return
	var key: int = event.keycode
	var now := _now_ms()
	if key == _block_key():
		# Key-repeat echoes of a held Space are swallowed too, so a focused battle button never fires from them.
		if not event.echo:
			_events.append([now, event.pressed])
		get_viewport().set_input_as_handled()
		return
	if event.echo:
		return
	if event.pressed and _settings != null:
		for action in DIR_KEYS:
			if key == _settings.get_key(action):
				_presses.append([now, DIR_KEYS[action]])
				get_viewport().set_input_as_handled()
				return

# ---------------------------------------------------------------- the timeline
func _process(_delta: float) -> void:
	if not _running:
		return
	var now := _now_ms()
	for i in _impacts.size():
		if _resolved[i] != null:
			continue
		var impact: float = float(_impacts[i].ms)
		var reach: float = _window_ms if _mode == "dodge" else _parry_ms
		if now > impact + reach:
			_resolve(i, impact)
	var all_done := true
	for r in _resolved:
		if r == null:
			all_done = false
	if all_done:
		var last: float = float(_impacts[_impacts.size() - 1].ms)
		if now >= last + (_window_ms if _mode == "dodge" else _parry_ms) + END_PADDING_MS:
			_running = false
			finished.emit()
			return
	_canvas.queue_redraw()

func _resolve(i: int, impact: float) -> void:
	var res := {"mult": float(_impacts[i].mult), "dir": Vector2i.ZERO}
	if _mode == "dodge":
		var best := -1
		var best_off := 1.0e9
		for j in _presses.size():
			var used: bool = bool(_presses[j].size() > 2 and _presses[j][2])
			if used:
				continue
			var off: float = absf(float(_presses[j][0]) - impact)
			if off < best_off:
				best_off = off
				best = j
		if best >= 0 and best_off <= _window_ms:
			_presses[best].append(true)
			res["outcome"] = AttackPatternsScript.classify_dodge(float(_presses[best][0]), impact, _window_ms)
			res["dir"] = _presses[best][1]
		else:
			res["outcome"] = "miss"
	else:
		res["outcome"] = AttackPatternsScript.classify_block(_events, _held_at_start, impact, _parry_ms)
	_resolved[i] = res
	_flash(str(res.outcome))

func _flash(outcome: String) -> void:
	match outcome:
		"perfect": _flash_text = "PERFECT DODGE!"; _flash_color = Color(0.5, 1.0, 0.6)
		"good": _flash_text = "DODGED"; _flash_color = Color(0.6, 0.9, 1.0)
		"parry": _flash_text = "PARRY!"; _flash_color = Color(1.0, 0.95, 0.4)
		"block": _flash_text = "BLOCKED"; _flash_color = Color(1.0, 0.75, 0.3)
		_: _flash_text = "HIT!"; _flash_color = Color(1.0, 0.4, 0.35)
	_flash_until_ms = _now_ms() + 450.0

# ---------------------------------------------------------------- drawing
func _next_unresolved() -> int:
	for i in _resolved.size():
		if _resolved[i] == null:
			return i
	return -1

func _draw_telegraph() -> void:
	if _impacts.is_empty():
		return
	var accent: Color = DODGE_COLOR if _mode == "dodge" else BLOCK_COLOR
	var size: Vector2 = _canvas.size
	var now := _now_ms()
	var next := _next_unresolved()
	var seg_start := 0.0
	var seg_end: float = float(_impacts[_impacts.size() - 1].ms)
	if next >= 0:
		seg_end = float(_impacts[next].ms)
		if next > 0:
			seg_start = float(_impacts[next - 1].ms)
	var p: float = clampf((now - seg_start) / maxf(1.0, seg_end - seg_start), 0.0, 1.0)
	var style: String = str(_pattern.get("style", "bar"))
	var area := Rect2(0, 0, size.x, size.y - 34.0)
	var center := area.get_center()
	var active: bool = next >= 0
	var window_frac: float = _window_ms / maxf(1.0, seg_end - seg_start)
	match style:
		"ring":
			var target_r := 30.0
			var r: float = lerpf(target_r + 78.0, target_r, p)
			_canvas.draw_arc(center, target_r, 0, TAU, 48, Color(1, 1, 1, 0.55), 3.0)
			if active:
				_canvas.draw_arc(center, r, 0, TAU, 64, accent, 5.0)
		"sweep":
			var radius := minf(area.size.x, area.size.y) * 0.46
			_canvas.draw_arc(center, radius, 0, TAU, 64, Color(1, 1, 1, 0.25), 2.0)
			_canvas.draw_arc(center, radius, -PI / 2.0 - 0.28, -PI / 2.0 + 0.28, 16, Color(1, 1, 1, 0.9), 6.0)
			var angle: float = lerpf(-PI / 2.0 - PI * 1.5, -PI / 2.0, p)
			if active:
				_canvas.draw_line(center, center + Vector2(cos(angle), sin(angle)) * radius, accent, 5.0)
		"flash":
			var pulse: float = pow(p, 3.0)
			var fill := Color(accent.r, accent.g, accent.b, 0.08 + pulse * 0.30)
			if active and p >= 1.0:
				fill = Color(1, 1, 1, 0.95)
			_canvas.draw_circle(center, 44.0, fill)
			_canvas.draw_arc(center, 44.0, 0, TAU, 48, Color(1, 1, 1, 0.5), 3.0)
		_:
			var track := Rect2(10, center.y - 14, size.x - 20, 28)
			_canvas.draw_rect(track, Color(1, 1, 1, 0.08))
			var zone_w: float = clampf(track.size.x * window_frac, 16.0, track.size.x * 0.4)
			var zone := Rect2(track.end.x - zone_w, track.position.y, zone_w, track.size.y)
			_canvas.draw_rect(zone, Color(accent.r, accent.g, accent.b, 0.35))
			_canvas.draw_rect(zone, Color(1, 1, 1, 0.7), false, 2.0)
			if active:
				_canvas.draw_rect(Rect2(lerpf(track.position.x, zone.position.x + zone.size.x * 0.5, p) - 3, track.position.y - 6, 6, track.size.y + 12), accent)
	# the shield (block mode) -- lit while the key is down
	if _mode == "block":
		var held: bool = _key_down(_block_key())
		_canvas.draw_rect(Rect2(8, 8, 40, 44), Color(1.0, 0.72, 0.28, 0.9 if held else 0.15))
		_canvas.draw_rect(Rect2(8, 8, 40, 44), Color(1, 1, 1, 0.8), false, 2.0)
	# thin timeline of every impact
	var bar := Rect2(10, size.y - 22, size.x - 20, 8)
	var total: float = float(_impacts[_impacts.size() - 1].ms) + 250.0
	_canvas.draw_rect(bar, Color(1, 1, 1, 0.12))
	for i in _impacts.size():
		var x: float = bar.position.x + bar.size.x * float(_impacts[i].ms) / total
		var done: bool = _resolved[i] != null
		_canvas.draw_rect(Rect2(x - 2, bar.position.y - 5, 4, bar.size.y + 10), Color(0.5, 1.0, 0.6) if done else Color.WHITE)
	_canvas.draw_rect(Rect2(bar.position.x + bar.size.x * clampf(now / total, 0.0, 1.0) - 1, bar.position.y - 2, 3, bar.size.y + 4), accent)
	if now < _flash_until_ms and _flash_text != "":
		var font := ThemeDB.fallback_font
		_canvas.draw_string(font, Vector2(0, center.y - 54.0), _flash_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 30, _flash_color)
