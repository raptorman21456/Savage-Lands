extends CanvasLayer

# The Debug menu: F1 in a run (or in the Sandbox) opens a floating window, built in the pixel kit like the Inventory, that can change
# almost anything: your stats and gear, the party, where you are, the battle in front of you, the Church's upgrades, the game's speed.
# It is OFF for normal play: it answers F1 only when Settings > Gameplay > "Debug menu (F1)" is On, or in the Sandbox.
#
#   Tabs      Player / Items / Party / World / Battle / Progress / Game   (Q and E step through them)
#   Keys      F1 or Esc close it. Arrows move between buttons, Enter / Space / Z press one, Tab also moves on.
#   Pause     it pauses the game while it is open and puts the pause back as it found it (re-worked if an action ended a battle).
#   Log       every action says what it did in the strip at the bottom.
#
# This file is the window and the rules of being open; what each tab shows is in Debug*View.gd, and what they do to the game is in
# DebugActions.gd / DebugWorld.gd / DebugBattle.gd / DebugProgress.gd (so a test can drive them with no screen).
# New scripts avoid class_name (they are preloaded by path).

const SaveDataScript := preload("res://scripts/SaveData.gd")
const DebugKitScript := preload("res://scripts/DebugKit.gd")
const DebugActionsScript := preload("res://scripts/DebugActions.gd")
const DebugWorldScript := preload("res://scripts/DebugWorld.gd")
const DebugProgressScript := preload("res://scripts/DebugProgress.gd")

const WINDOW_SIZE := Vector2(1120, 624)
const BODY_POS := Vector2(6, 62)
const BODY_H := 444.0
const TABS := [
	["Player", "tab_character"], ["Items", "tab_items"], ["Party", "tab_party"], ["World", "tab_map"],
	["Battle", "stat_damage"], ["Progress", "stat_level"], ["Game", "tab_settings"],
]
const VIEW_SCRIPTS := {
	"Player": "res://scripts/DebugPlayerView.gd", "Items": "res://scripts/DebugItemsView.gd", "Party": "res://scripts/DebugPartyView.gd",
	"World": "res://scripts/DebugWorldView.gd", "Battle": "res://scripts/DebugBattleView.gd", "Progress": "res://scripts/DebugProgressView.gd",
	"Game": "res://scripts/DebugGameView.gd",
}

var main = null
var active_tab := "Player"
var state: Dictionary = {}          # what the tabs share and keep between visits (the enemy picked, counts, searches...)
var history: Array = []             # every log line: {msg, ok}
var show_overlay := false           # the FPS / position read-out in the corner of the screen

var window: Panel = null
var content: Control = null
var body: Control = null
var view: Control = null
var scrim: ColorRect = null
var tab_buttons: Dictionary = {}
var log_new: Label = null
var log_old: Label = null
var focus_ring: Panel = null
var overlay_layer: CanvasLayer = null
var overlay_panel: PanelContainer = null
var overlay_label: Label = null
var confirm_box: Control = null
var _confirm_buttons: Array = []

var _built := false
var _was_paused := false
var _flags: Array = []
var _held_inputs: Array = []        # nodes whose _input was switched off while the menu is up
var _prev_focus: Control = null

# --- whether it answers at all ------------------------------------------------------------------------------------------------

# On when Settings > Gameplay says so, or in the Sandbox (which is a testing tool anyway).
static func is_enabled() -> bool:
	if SaveDataScript.sandbox_active:
		return true
	var loop = Engine.get_main_loop()
	if loop is SceneTree:
		var settings = (loop as SceneTree).root.get_node_or_null("Settings")
		return settings != null and bool(settings.debug_menu_enabled)
	return false

# --- life cycle ---------------------------------------------------------------------------------------------------------------

func _ready() -> void:
	layer = 80
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func setup(main_ref) -> void:
	main = main_ref

func _exit_tree() -> void:
	# never leave the game slowed down or the collision view on behind us (only what we moved)
	DebugProgressScript.restore_engine(get_tree() if is_inside_tree() else null)

func is_open() -> bool:
	return visible

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func open() -> void:
	if main == null or main.player == null or visible:
		return
	_build_ui()
	_was_paused = get_tree().paused
	get_tree().paused = true
	_flags = _game_flags()
	_prev_focus = get_viewport().gui_get_focus_owner()
	_hold_other_inputs(true)
	window.position = ((get_viewport().get_visible_rect().size - WINDOW_SIZE) / 2.0).round()
	visible = true
	_select_tab(active_tab)
	_show_log()
	_focus_first.call_deferred()

func close() -> void:
	if not visible:
		return
	_close_confirm()
	_resync_pause()
	visible = false
	_hold_other_inputs(false)
	get_tree().paused = _was_paused
	if _prev_focus != null and is_instance_valid(_prev_focus) and _prev_focus.is_inside_tree():
		_prev_focus.grab_focus()
	else:
		var owner := get_viewport().gui_get_focus_owner()
		if owner != null:
			owner.release_focus()
	_prev_focus = null

# Only the Debug menu hears the keyboard while it is up: the HUD's H and Tab, the Inventory's Q and E and the rest are switched off
# for the duration (and back on after).
func _hold_other_inputs(hold: bool) -> void:
	if hold:
		_held_inputs.clear()
		for c in main.get_children():
			if c != self and c.is_processing_input():
				c.set_process_input(false)
				_held_inputs.append(c)
	else:
		for c in _held_inputs:
			if is_instance_valid(c):
				c.set_process_input(true)
		_held_inputs.clear()

# The facts that decide whether the game is paused, so a change in them (a battle that ended, a game over) can be noticed.
func _game_flags() -> Array:
	return [main.in_battle, main.game_over, main.choosing_stat, main.shop_open, main.menu_open, main.event_choosing, _panel_open()]

func _panel_open() -> bool:
	return main._any_town_panel_open() or (main.inventory_panel != null and main.inventory_panel.visible)

func _game_wants_paused() -> bool:
	return bool(main.in_battle) or bool(main.game_over) or bool(main.choosing_stat) or bool(main.shop_open) or bool(main.menu_open) or bool(main.event_choosing) or _panel_open()

# After an action: if it changed what the pause depends on (a battle started or ended...), the pause to give back changes with it.
func _resync_pause() -> void:
	var now := _game_flags()
	if now != _flags:
		_flags = now
		_was_paused = _game_wants_paused()

# --- keys -----------------------------------------------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if main == null or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F1:
		if not is_enabled():
			return           # does nothing at all: the key is left for anyone else
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	if confirm_box != null:
		_confirm_key(event)
		return
	var typing: bool = get_viewport().gui_get_focus_owner() is LineEdit
	if event.keycode == KEY_ESCAPE:
		if typing:
			get_viewport().gui_get_focus_owner().release_focus()
			_focus_first_after_edit()
		else:
			close()
		get_viewport().set_input_as_handled()
		return
	if not typing and (event.keycode == KEY_Q or event.keycode == KEY_E):
		var i := _tab_index(active_tab)
		i = posmod(i + (1 if event.keycode == KEY_E else -1), TABS.size())
		_select_tab(TABS[i][0])
		_focus_first.call_deferred()
		get_viewport().set_input_as_handled()

func _tab_index(tab_name: String) -> int:
	for i in TABS.size():
		if TABS[i][0] == tab_name:
			return i
	return 0

# --- building the window ----------------------------------------------------------------------------------------------------------

func _build_ui() -> void:
	if _built:
		return
	_built = true
	scrim = ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.75)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)
	window = Panel.new()
	window.size = WINDOW_SIZE
	window.add_theme_stylebox_override("panel", PixelKit.frame("panel"))
	scrim.add_child(window)
	content = Control.new()
	content.position = Vector2(14, 14)
	content.size = WINDOW_SIZE - Vector2(28, 28)
	window.add_child(content)
	var title := PixelKit.label("Debug", "head", PixelKit.GOLD3)
	title.position = Vector2(8, 10)
	content.add_child(title)
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 0)
	tab_row.position = Vector2(104, 4)
	content.add_child(tab_row)
	for t in TABS:
		var tab_name: String = t[0]
		var b := DebugKitScript.button(tab_name, _on_tab_pressed.bind(tab_name), tab_name == active_tab, t[1])
		tab_row.add_child(b)
		tab_buttons[tab_name] = b
	var close_button := DebugKitScript.button("×", close)
	close_button.tooltip_text = "Close (F1 or Esc)"
	close_button.position = Vector2(content.size.x - 56, 4)
	close_button.custom_minimum_size = Vector2(52, 48)
	content.add_child(close_button)
	body = Control.new()
	body.position = BODY_POS
	body.size = Vector2(content.size.x - 12, BODY_H)
	content.add_child(body)
	var log_panel := PixelKit.panel("inset", 8, 2)
	log_panel.position = Vector2(6, BODY_POS.y + BODY_H + 6)
	log_panel.size = Vector2(content.size.x - 12, 56)
	log_panel.custom_minimum_size = log_panel.size
	content.add_child(log_panel)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 0)
	log_panel.add_child(lines)
	log_old = PixelKit.label("", "body", PixelKit.DIM)
	log_old.clip_text = true
	lines.add_child(log_old)
	log_new = PixelKit.label("Ready.", "body", PixelKit.CREAM)
	log_new.clip_text = true
	lines.add_child(log_new)
	var hint := PixelKit.label("F1 / Esc  Close      Q / E  Tabs      Arrows  Move      Enter  Use", "body", PixelKit.DIM)
	hint.position = Vector2(8, content.size.y - 24)
	content.add_child(hint)
	# one gold outline that follows whatever has the keyboard (buttons, cards, boxes alike)
	focus_ring = Panel.new()
	var outline := StyleBoxFlat.new()
	outline.draw_center = false
	outline.border_color = PixelKit.GOLD4
	outline.set_border_width_all(2)
	focus_ring.add_theme_stylebox_override("panel", outline)
	focus_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_ring.visible = false
	scrim.add_child(focus_ring)
	# the read-out in the corner, shown on request (Game tab)
	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 85
	overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay_layer)
	overlay_panel = PixelKit.panel("chip", 6, 2)
	overlay_panel.position = Vector2(8, 8)
	overlay_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_layer.add_child(overlay_panel)
	overlay_label = PixelKit.label("", "body", PixelKit.GOLD4)
	overlay_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_panel.add_child(overlay_label)
	overlay_layer.visible = false

func _on_tab_pressed(tab_name: String) -> void:
	_select_tab(tab_name)
	_focus_first.call_deferred()

func _select_tab(tab_name: String) -> void:
	if not _built:
		return
	active_tab = tab_name
	for n in tab_buttons:
		tab_buttons[n].on = n == tab_name
	if view != null:
		body.remove_child(view)
		view.queue_free()
		view = null
	var script: Script = load(str(VIEW_SCRIPTS[tab_name]))
	view = script.new()
	view.size = body.size
	body.add_child(view)
	view.setup(self, main)

# Keyboard focus: the first control in the tab, or the tab's own button when the tab has none.
func _focus_first() -> void:
	if not visible or view == null:
		return
	var items: Array = DebugKitScript.focusables(view)
	if not items.is_empty():
		items[0].grab_focus()
	elif tab_buttons.has(active_tab):
		tab_buttons[active_tab].grab_focus()

func _focus_first_after_edit() -> void:
	# leaving a text box with Esc: keep the keyboard in the tab (on the first control) so the arrows still work
	_focus_first.call_deferred()

# --- the log --------------------------------------------------------------------------------------------------------------------

# Every action ends here: the result's message goes on the strip and in the console, a sound plays, and a result that asks to
# (a teleport, a battle starting) closes the menu so you can see what happened.
func report(result: Dictionary) -> void:
	var msg := str(result.get("msg", ""))
	var success: bool = bool(result.get("ok", true))
	if msg != "":
		history.append({"msg": msg, "ok": success})
		if history.size() > 300:
			history.pop_front()
		_show_log()
		print("[Debug] %s%s" % ["" if success else "(no) ", msg])
		if main != null and main.has_method("play_sfx"):
			main.play_sfx("purchase" if success else "error")
	_resync_pause()
	if success and bool(result.get("close", false)):
		if main != null and main.hud != null and msg != "":
			main.hud.show_message("[DEBUG] " + msg)
		close()

# Posts a plain line (not the result of an action).
func say(msg: String, success: bool = true) -> void:
	report({"ok": success, "msg": msg})

func _show_log() -> void:
	if log_new == null:
		return
	var n := history.size()
	if n == 0:
		return
	log_new.text = str(history[n - 1].msg)
	log_new.add_theme_color_override("font_color", PixelKit.GOOD if history[n - 1].ok else PixelKit.BAD)
	log_old.text = str(history[n - 2].msg) if n > 1 else ""

# --- asking "are you sure" -----------------------------------------------------------------------------------------------------

# A small box over the window: the message, [Cancel] and [yes_label]. Cancel has the keyboard; Esc cancels.
func confirm(message: String, on_yes: Callable, yes_label: String = "Yes, do it") -> void:
	if not visible:
		return
	_close_confirm()
	confirm_box = Control.new()
	confirm_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirm_box.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.add_child(confirm_box)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.05, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirm_box.add_child(dim)
	var panel := PixelKit.panel("panel", 20, 16)
	confirm_box.add_child(panel)
	var col := DebugKitScript.vbox(panel, 12)
	var msg_label := PixelKit.wrapped(message, 520.0, "body", PixelKit.CREAM)
	col.add_child(msg_label)
	var buttons := DebugKitScript.hbox(col, 12)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	var cancel := DebugKitScript.button("Cancel", _close_confirm)
	var yes := DebugKitScript.button(yes_label, func():
		_close_confirm()
		on_yes.call()
	, true)
	buttons.add_child(cancel)
	buttons.add_child(yes)
	_confirm_buttons = [cancel, yes]
	# centre it (it takes the size its contents want)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	cancel.grab_focus.call_deferred()

func _close_confirm() -> void:
	if confirm_box != null and is_instance_valid(confirm_box):
		confirm_box.get_parent().remove_child(confirm_box)
		confirm_box.queue_free()
	confirm_box = null
	_confirm_buttons = []
	if visible:
		_focus_first.call_deferred()

# While a question is up the arrows hop between its two buttons only (the window under it is out of reach); Esc is "no".
func _confirm_key(event: InputEventKey) -> void:
	if event.keycode == KEY_ESCAPE:
		_close_confirm()
		get_viewport().set_input_as_handled()
		return
	if event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_TAB] and _confirm_buttons.size() == 2:
		var current: Control = get_viewport().gui_get_focus_owner()
		var other: Control = _confirm_buttons[1] if current == _confirm_buttons[0] else _confirm_buttons[0]
		other.grab_focus()
		get_viewport().set_input_as_handled()

# --- every frame: cheats that must be held up, the read-out, the pause ---------------------------------------------------------------

func _process(_delta: float) -> void:
	if main == null or main.player == null:
		return
	if not is_enabled():
		# turned off (or never on): no cheat may outlive the switch
		if visible:
			close()
		if _cheats_active():
			DebugActionsScript.reset_cheats(main)
		if overlay_layer != null:
			overlay_layer.visible = false
		return
	var p = main.player
	if p.debug_infinite_stamina and p.stamina < p.max_stamina:
		p.stamina = p.max_stamina
		p.exhausted = false
		p.stamina_changed.emit(p.stamina, p.max_stamina)
	if bool(p.get_meta("debug_ohko", false)) and p.temp_damage_bonus_pct != DebugActionsScript.ONE_HIT_BONUS:
		p.temp_damage_bonus_pct = DebugActionsScript.ONE_HIT_BONUS
	# an action that ended a battle unpauses the game under the open window: hold it (and note what the pause should go back to)
	if visible:
		_resync_pause()
		if not get_tree().paused:
			get_tree().paused = true
	if visible:
		_follow_focus()
	if overlay_layer != null:
		overlay_layer.visible = show_overlay
		if show_overlay:
			overlay_label.text = overlay_text()
			# top centre: the corners belong to the HUD
			overlay_panel.position.x = roundf((get_viewport().get_visible_rect().size.x - overlay_panel.size.x) / 2.0)

# The gold outline sits round the control that has the keyboard (and above everything in the window, a question box included).
func _follow_focus() -> void:
	if focus_ring == null:
		return
	var owner: Control = get_viewport().gui_get_focus_owner()
	if owner == null or not scrim.is_ancestor_of(owner) or not owner.is_visible_in_tree():
		focus_ring.visible = false
		return
	var r: Rect2 = owner.get_global_rect()
	focus_ring.visible = true
	focus_ring.global_position = r.position - Vector2(3, 3)
	focus_ring.size = r.size + Vector2(6, 6)
	if scrim.get_child(scrim.get_child_count() - 1) != focus_ring:
		scrim.move_child(focus_ring, scrim.get_child_count() - 1)

func _cheats_active() -> bool:
	var p = main.player
	return p.debug_god_mode or p.debug_infinite_stamina or p.debug_speed_mult != 1.0 or bool(p.get_meta("debug_ohko", false)) or DebugProgressScript.time_scale_touched or DebugProgressScript.collision_view_touched

func set_overlay(on: bool) -> void:
	show_overlay = on
	if overlay_layer != null:
		overlay_layer.visible = on

# One line of facts for the corner.
func overlay_text() -> String:
	var p = main.player
	var region: String = str(load("res://scripts/WorldMap.gd").region(str(main.current_region_id)).get("name", main.current_region_id))
	var room_info: Dictionary = load("res://scripts/Rooms.gd").by_id(str(main.current_room_id))
	var room: String = str(room_info.get("name", "")) if not room_info.is_empty() and str(room_info.get("name", "")) != "" else str(main.current_room_id)
	return "FPS %d   x %d  y %d   %s / %s   enemies %d   %s%s" % [
		Engine.get_frames_per_second(), int(p.global_position.x), int(p.global_position.y), region, room, int(main.enemies_alive),
		"BATTLE  " if main.in_battle else "", "speed x%s" % DebugActionsScript._fmt(Engine.time_scale) if Engine.time_scale != 1.0 else ""]
