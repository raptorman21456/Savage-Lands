extends Control
class_name TitleScreen

# The title screen, in the pixel kit, as a short walk through screens:
#   splash        the living backdrop, the logo and "Press anything to continue"
#   files         Select a File: three big cards, each a save slot (Hollow Knight's way, not a list of buttons); an empty one starts a
#                 new game after choosing its difficulty
#   menu          the chosen file's options: Play, Stats, Beastiary, Sandbox, Switch File, Quit
#   difficulty / slot_options / slot_action / copy_target / stats    the smaller screens, each in a framed panel of FIXED size, so
#                 changing the words under a hover can never resize or move the panel
# A TitleEntry (a Button underneath) is every choice: the arrow keys and the mouse move the choice, Enter / Space / Z take it, Esc goes back.
# Coming back to this scene after a run skips the splash (it was already seen this session).

const SaveDataScript := preload("res://scripts/SaveData.gd")
const BeastiaryPanelScript := preload("res://scripts/BeastiaryPanel.gd")
const TitleBackdropScript := preload("res://scripts/TitleBackdrop.gd")
const PixelLogoScript := preload("res://scripts/PixelLogo.gd")
const UIIconsScript := preload("res://scripts/UIIcons.gd")

const GAME_TITLE := "SAVAGE LANDS"
const GAME_SUBTITLE := "A tiny pixel-art action RPG"
# The logo's width as a fraction of the window on the splash / the small one kept at the top of every other screen.
const LOGO_WIDTH_FRACTION := 0.56
const LOGO_COMPACT_WIDTH_FRACTION := 0.26

const CARD_SIZE := Vector2(720, 112)
const PANEL_WIDTH := 600.0
const ROW_HEIGHT := 46.0
# How dark the backdrop goes behind each screen.
const DIMS := {"splash": 0.0, "files": 0.3, "menu": 0.3, "difficulty": 0.5, "slot_options": 0.5, "slot_action": 0.5, "copy_target": 0.5, "stats": 0.6}
const DIFFICULTY_COLORS := {"baby": Color("8be08f"), "normal": Color("f2eee4"), "hard": Color("efc23c"), "apocalyptic": Color("f2676a")}
const KEYS_CHOOSE := "Up / Down  Choose      Z / Enter  Select      Esc  Back"
const HINTS := {
	"splash": "",
	"files": "Up / Down  Choose      Z / Enter  Select      X  File options      Esc  Back",
	"menu": "Up / Down  Choose      Z / Enter  Select      Esc  Switch File",
	"difficulty": KEYS_CHOOSE, "slot_options": KEYS_CHOOSE, "slot_action": KEYS_CHOOSE, "copy_target": KEYS_CHOOSE,
	"stats": "Esc  Back",
}

# True once the splash has been passed in this session (a static, so it survives the scene changing to the game and back).
static var seen_splash := false

var screen := "splash"
var _age := 0.0

var play_button: TitleEntry
var quit_button: TitleEntry
var stats_button: TitleEntry
var sandbox_button: TitleEntry
var map_editor_button: TitleEntry
var switch_save_button: TitleEntry
var beastiary_button: TitleEntry
var description_label: Label     # the words under the screen being looked at (the main menu's and the difficulty screen's each have one)
var main_menu_box: Control
var beastiary_panel: BeastiaryPanelScript

var backdrop: TitleBackdropScript
var logo: PixelLogoScript
var subtitle_label: Label
var logo_block: VBoxContainer
var menu_margin: MarginContainer
var logo_compact := false
var splash_box: Control
var splash_prompt: Label
var hint_label: Label
var _desc_labels := {}           # screen name -> its fixed description label

var stats_box: Control
var stats_rows := {}             # lifetime stat id -> its value label
var stats_back_button: TitleEntry

# Select a File: three cards, each with a "..." gear that opens that file's own options.
var select_save_box: Control
var slot_buttons := {}           # slot number -> its card (a TitleEntry; its text summarises the file)
var options_buttons := {}
var select_save_quit_button: TitleEntry
var _card_parts := {}
var difficulty_box: Control
var difficulty_buttons := {}
var new_save_name_edit: LineEdit
var pending_slot := 0

var slot_options_box: Control
var slot_options_header: Label
var slot_options_rename_button: TitleEntry
var slot_options_copy_button: TitleEntry
var slot_options_clear_button: TitleEntry
var slot_options_target := 0

var slot_action_box: Control
var slot_action_header: Label
var slot_action_warning: Label
var slot_action_name_edit: LineEdit
var slot_action_confirm_button: TitleEntry
var slot_action_mode := ""       # "rename", "clear" or "copy": what Confirm does
var slot_action_target := 0

var copy_target_box: Control
var copy_target_header: Label
var copy_target_buttons := {}
var copy_source_slot := 0

var save_data: Dictionary

func _ready() -> void:
	# Coming back from the sandbox (or anywhere else): the real save is live again.
	SaveDataScript.sandbox_active = false
	SaveDataScript.sandbox_data = {}
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_bind_extra_select_key()
	save_data = SaveDataScript.load_data()

	# The scene behind everything: banded sunset, parallax ridges, the barbarian's campfire and its drifting embers (TitleBackdrop.gd).
	backdrop = TitleBackdropScript.new()
	add_child(backdrop)

	# Every screen but the splash sits centred in what the logo leaves free below it.
	menu_margin = MarginContainer.new()
	menu_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_margin.add_theme_constant_override("margin_bottom", 44)
	add_child(menu_margin)
	var center := CenterContainer.new()
	menu_margin.add_child(center)

	_build_files(center)
	_build_menu(center)
	_build_difficulty(center)
	_build_slot_options(center)
	_build_slot_action(center)
	_build_copy_target(center)
	_build_stats(center)

	beastiary_panel = BeastiaryPanelScript.new()
	add_child(beastiary_panel)

	# The logo block is added after the screens so it draws over them; it is pinned to the top and never takes part in centring.
	logo_block = VBoxContainer.new()
	logo_block.set_anchors_preset(Control.PRESET_TOP_WIDE)
	logo_block.offset_top = 26
	logo_block.add_theme_constant_override("separation", 8)
	logo_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo_block)
	logo = PixelLogoScript.new()
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	logo_block.add_child(logo)
	subtitle_label = PixelKit.label(GAME_SUBTITLE, "body", Color(0.95, 0.82, 0.62))
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo_block.add_child(subtitle_label)

	# The splash: only the prompt, low in the window, breathing.
	splash_box = Control.new()
	splash_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	splash_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(splash_box)
	splash_prompt = PixelKit.label("Press anything to continue", "head", PixelKit.CREAM)
	splash_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	splash_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	splash_prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	splash_prompt.offset_bottom = -76
	splash_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	splash_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	splash_box.add_child(splash_prompt)

	hint_label = PixelKit.label("", "body", PixelKit.DIM)
	hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint_label.offset_bottom = -14
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint_label)

	resized.connect(_update_logo_layout)
	_refresh_select_save_display()

	if seen_splash:
		_show_select_save_screen()
		return
	_show("splash")
	# Entrance: the logo fades up, then the prompt, which then breathes.
	logo_block.modulate.a = 0.0
	splash_prompt.modulate.a = 0.0
	var intro := create_tween()
	intro.tween_property(logo_block, "modulate:a", 1.0, 1.0)
	intro.tween_property(splash_prompt, "modulate:a", 1.0, 0.8).set_delay(0.3)
	intro.tween_callback(_breathe_prompt)

var _breathing := false

func _breathe_prompt() -> void:
	if _breathing:
		return
	_breathing = true
	var loop := splash_prompt.create_tween().set_loops()
	loop.tween_property(splash_prompt, "modulate:a", 0.35, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	loop.tween_property(splash_prompt, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# --- building the screens ---------------------------------------------------------------------------------------------------------------

# A framed panel of a fixed width holding a column; returns [panel, column]. Panels never shrink-wrap their words: every word box inside
# is a fixed width that wraps, so no text can change the panel's size.
func _panel_screen(width: float) -> Array:
	var box := PixelKit.panel("panel", 14, 10)
	box.custom_minimum_size = Vector2(width, 0)
	box.visible = false
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	box.add_child(col)
	return [box, col]

func _header(text_in: String) -> Label:
	var l := PixelKit.label(text_in, "head", PixelKit.GOLD3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(PANEL_WIDTH - 60.0, 0)
	return l

func _note(text_in: String, color: Color = PixelKit.DIM) -> Label:
	var l := PixelKit.label(text_in, "body", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(PANEL_WIDTH - 60.0, 0)
	return l

func _row(text_in: String, on_pressed: Callable, desc: String = "") -> TitleEntry:
	var e := TitleEntry.make(text_in, "row", on_pressed, desc, Vector2(0, ROW_HEIGHT))
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_describe(e)
	return e

# A hovered or chosen entry shows its description in the screen's fixed description box (if the screen has one).
func _describe(e: TitleEntry) -> void:
	e.focus_entered.connect(func(): _set_description(e.description))

func _set_description(text_in: String) -> void:
	if description_label != null:
		description_label.text = text_in

func _fixed_description(for_screen: String, lines: int) -> Control:
	var box := InvWidgets.desc_box("", PixelKit.CREAM, 24.0 * lines + 24.0)
	_desc_labels[for_screen] = box.get_meta("label")
	return box

func _style_edit(edit: LineEdit, placeholder: String) -> void:
	edit.placeholder_text = placeholder
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.max_length = 24
	edit.custom_minimum_size = Vector2(0, 44)
	edit.add_theme_stylebox_override("normal", PixelKit.padded("inset", 8, 0))
	edit.add_theme_stylebox_override("focus", PixelKit.padded("inset", 8, 0))
	edit.add_theme_font_override("font", PixelKit.font("body"))
	edit.add_theme_font_size_override("font_size", PixelKit.font_size("body"))
	edit.add_theme_color_override("font_color", PixelKit.CREAM)
	edit.add_theme_color_override("font_placeholder_color", PixelKit.DIM)
	edit.add_theme_color_override("caret_color", PixelKit.GOLD3)
	edit.add_theme_color_override("selection_color", Color(PixelKit.GOLD3, 0.4))

func _build_files(parent: Control) -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(CARD_SIZE.x, 0)
	col.visible = false
	parent.add_child(col)
	select_save_box = col
	var header := PixelKit.label("Select a File", "head", PixelKit.GOLD3)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(header)
	for n in [1, 2, 3]:
		var card := _build_card(n)
		col.add_child(card)
		slot_buttons[n] = card
	select_save_quit_button = TitleEntry.make("Quit", "text", _on_quit_pressed, "Exit the game.", Vector2(260, 54))
	col.add_child(select_save_quit_button)

# One file's card: a portrait tile, the file's name, its difficulty and what it has banked, and a gear for its options.
func _build_card(n: int) -> TitleEntry:
	var card := TitleEntry.make("", "card", _on_slot_pressed.bind(n), "", CARD_SIZE)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 16
	row.offset_top = 14
	row.offset_right = -16
	row.offset_bottom = -14
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var tile := PixelKit.panel_box("inset")
	tile.custom_minimum_size = Vector2(84, 84)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tile)
	var face := PixelKit.icon("face_you", 64)
	face.position = Vector2(10, 10)
	tile.add_child(face)
	var plus := PixelKit.label("+", "big", PixelKit.DIM)
	plus.position = Vector2(30, 14)
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(plus)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	var name_label := PixelKit.label("", "head", PixelKit.CREAM)
	var diff_label := PixelKit.label("", "body", PixelKit.CREAM)
	var stats_label := PixelKit.label("", "body", PixelKit.DIM)
	for l in [name_label, diff_label, stats_label]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.add_child(l)
	var gear := PixelButton.make("", "tab_settings", func(): _on_slot_options_pressed(n))
	gear.tooltip_text = "Rename, copy or clear this file."
	gear.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(gear)
	options_buttons[n] = gear
	_card_parts[n] = {"face": face, "plus": plus, "name": name_label, "diff": diff_label, "stats": stats_label}
	card.chosen_changed.connect(func(on: bool): _recolor_card(n, on))
	return card

func _recolor_card(n: int, chosen: bool) -> void:
	var parts: Dictionary = _card_parts[n]
	var filled: bool = SaveDataScript.slot_exists(n)
	var base: Color = PixelKit.CREAM if filled else PixelKit.DIM
	parts.name.add_theme_color_override("font_color", PixelKit.GOLD4 if chosen else base)

func _build_menu(parent: Control) -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.visible = false
	parent.add_child(col)
	main_menu_box = col
	_menu_file_label = PixelKit.label("", "body", PixelKit.DIM)
	_menu_file_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_menu_file_label)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	col.add_child(gap)
	play_button = _menu_entry(col, "Play", _on_play_pressed, "Begin your adventure.")
	stats_button = _menu_entry(col, "Stats", _on_stats_pressed, "View your lifetime stats across every file.")
	beastiary_button = _menu_entry(col, "Beastiary", func(): beastiary_panel.open(), "Browse every creature you've encountered or defeated, across every file.")
	sandbox_button = _menu_entry(col, "Sandbox", _on_sandbox_pressed, "Debug sandbox: build any character, pick the enemies, and fight a real battle. Nothing in it is saved.")
	map_editor_button = _menu_entry(col, "Map Editor", _on_map_editor_pressed, "Edit the world map: rooms, doorways, roads and places. Your save files are never touched.")
	switch_save_button = _menu_entry(col, "Switch File", _on_switch_save_pressed, "Return to the file select to play a different file.")
	quit_button = _menu_entry(col, "Quit", _on_quit_pressed, "Exit the game.")
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 10)
	col.add_child(gap2)
	var box := _fixed_description("menu", 2)
	box.custom_minimum_size.x = 620.0
	col.add_child(box)

var _menu_file_label: Label

func _menu_entry(col: Control, text_in: String, on_pressed: Callable, desc: String) -> TitleEntry:
	var e := TitleEntry.make(text_in, "text", on_pressed, desc, Vector2(420, 56))
	_describe(e)
	col.add_child(e)
	return e

func _build_difficulty(parent: Control) -> void:
	var made := _panel_screen(PANEL_WIDTH)
	difficulty_box = made[0]
	var col: VBoxContainer = made[1]
	parent.add_child(difficulty_box)
	col.add_child(_header("Choose a Difficulty"))
	col.add_child(_note("Locked in for this file -- it can't be changed later."))
	new_save_name_edit = LineEdit.new()
	_style_edit(new_save_name_edit, "File name (optional)")
	col.add_child(new_save_name_edit)
	for d in SaveDataScript.DIFFICULTIES:
		var e := _row(d.name, _on_difficulty_pressed.bind(d.id), d.description)
		col.add_child(e)
		difficulty_buttons[d.id] = e
	col.add_child(_fixed_description("difficulty", 3))
	col.add_child(_row("Back", _on_difficulty_back_pressed, ""))

func _build_slot_options(parent: Control) -> void:
	var made := _panel_screen(PANEL_WIDTH)
	slot_options_box = made[0]
	var col: VBoxContainer = made[1]
	parent.add_child(slot_options_box)
	slot_options_header = _header("")
	col.add_child(slot_options_header)
	slot_options_rename_button = _row("Rename", func(): _on_rename_slot_pressed(slot_options_target), "Rename this file.")
	col.add_child(slot_options_rename_button)
	slot_options_copy_button = _row("Copy", func(): _on_copy_slot_pressed(slot_options_target), "Copy this file to another slot.")
	col.add_child(slot_options_copy_button)
	slot_options_clear_button = _row("Clear", func(): _on_clear_slot_pressed(slot_options_target), "Permanently delete this file.")
	col.add_child(slot_options_clear_button)
	col.add_child(_row("Back", _show_select_save_screen, ""))

func _build_slot_action(parent: Control) -> void:
	var made := _panel_screen(PANEL_WIDTH)
	slot_action_box = made[0]
	var col: VBoxContainer = made[1]
	parent.add_child(slot_action_box)
	slot_action_header = _header("")
	col.add_child(slot_action_header)
	slot_action_warning = _note("This permanently deletes all progress on this file. This can't be undone.", PixelKit.BAD)
	col.add_child(slot_action_warning)
	slot_action_name_edit = LineEdit.new()
	_style_edit(slot_action_name_edit, "File name")
	col.add_child(slot_action_name_edit)
	slot_action_confirm_button = _row("Confirm", _on_slot_action_confirm_pressed, "")
	col.add_child(slot_action_confirm_button)
	col.add_child(_row("Cancel", _on_slot_action_cancel_pressed, ""))

func _build_copy_target(parent: Control) -> void:
	var made := _panel_screen(PANEL_WIDTH)
	copy_target_box = made[0]
	var col: VBoxContainer = made[1]
	parent.add_child(copy_target_box)
	copy_target_header = _header("")
	col.add_child(copy_target_header)
	# Exactly 2 rows: with 3 files in all, "every file but the source" is always the other 2 (relabelled fresh in _on_copy_slot_pressed).
	for i in [0, 1]:
		var e := _row("", Callable(), "")
		col.add_child(e)
		copy_target_buttons[i] = e
	col.add_child(_row("Back", _show_select_save_screen, ""))

func _build_stats(parent: Control) -> void:
	var made := _panel_screen(PANEL_WIDTH)
	stats_box = made[0]
	var col: VBoxContainer = made[1]
	parent.add_child(stats_box)
	col.add_child(_header("Lifetime Stats"))
	var rows := [["runs", "stat_speed", "Runs played"], ["kills", "stat_intimidation", "Lifetime kills"], ["world", "tab_map", "Deepest world reached"],
			["bosses", "stat_crit", "Bosses and minibosses defeated"], ["nothing", "stat_level", "The Nothingness conquered"]]
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 0)
	col.add_child(holder)
	for r in rows:
		var line := InvWidgets.icon_row(holder, str(r[1]), str(r[2]), "")
		var value: Label = line.get_child(0).get_child(line.get_child(0).get_child_count() - 1)
		stats_rows[str(r[0])] = value
	stats_back_button = _row("Back", _on_stats_back_pressed, "")
	col.add_child(stats_back_button)

# --- which screen is up ------------------------------------------------------------------------------------------------------------------

func _screen_node(name_in: String) -> Control:
	match name_in:
		"splash":
			return splash_box
		"files":
			return select_save_box
		"menu":
			return main_menu_box
		"difficulty":
			return difficulty_box
		"slot_options":
			return slot_options_box
		"slot_action":
			return slot_action_box
		"copy_target":
			return copy_target_box
		"stats":
			return stats_box
	return null

# Shows exactly one screen (instantly: the fade is only the look), leaves the logo big on the splash and small everywhere else, and
# puts the cursor on the screen's first choice.
func _show(name_in: String) -> void:
	screen = name_in
	for s in DIMS:
		var node := _screen_node(s)
		node.visible = s == name_in
	description_label = _desc_labels.get(name_in, null)
	_set_description("")
	hint_label.text = HINTS.get(name_in, "")
	logo_compact = name_in != "splash"
	_update_logo_layout()
	var shown := _screen_node(name_in)
	if name_in != "splash":
		shown.modulate.a = 0.0
		create_tween().tween_property(shown, "modulate:a", 1.0, 0.22)

# Sizes the pixel logo to the window (bigger pixels on a bigger window, capped so it never dominates) and reserves exactly its height
# above the screens. The small form (no subtitle) is the one every screen after the splash keeps at the top.
func _update_logo_layout() -> void:
	if logo == null or size.x < 32.0:
		return
	var fraction: float = LOGO_COMPACT_WIDTH_FRACTION if logo_compact else LOGO_WIDTH_FRACTION
	var cols_estimate := 69.0
	var pixel: int = clampi(int(size.x * fraction / cols_estimate), 2, 10)
	logo.set_logo(GAME_TITLE, pixel)
	subtitle_label.visible = not logo_compact
	var block_height: float = logo.custom_minimum_size.y + (0.0 if logo_compact else 32.0)
	menu_margin.add_theme_constant_override("margin_top", int(26.0 + block_height + 8.0))

# The scene dims behind each screen so it never fights the words on top of it.
func _process(delta: float) -> void:
	_age += delta
	if backdrop == null:
		return
	backdrop.dim_target = maxf(float(DIMS.get(screen, 0.0)), 0.35 if beastiary_panel.visible else 0.0)

# --- keys -----------------------------------------------------------------------------------------------------------------------------------

# On the splash anything at all moves on: a key, a mouse button, a controller button (not in the first half second, so a held key from the
# last scene can't skip it).
func _input(event: InputEvent) -> void:
	if screen != "splash" or _age < 0.5:
		return
	var any_press: bool = (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed) or (event is InputEventJoypadButton and event.pressed)
	if any_press:
		get_viewport().set_input_as_handled()
		_leave_splash()

# Esc (or X) goes back a screen; X on a file's card opens that file's options.
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo or beastiary_panel.visible:
		return
	if screen == "files" and event.keycode == KEY_X:
		# on the file select X is not "back": it opens the options of the file the cursor is on
		var focused := get_viewport().gui_get_focus_owner()
		for n in slot_buttons:
			if slot_buttons[n] == focused and SaveDataScript.slot_exists(n):
				_on_slot_options_pressed(n)
				get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_ESCAPE or event.keycode == KEY_X:
		get_viewport().set_input_as_handled()
		go_back()

# One step back from wherever you are.
func go_back() -> void:
	match screen:
		"files":
			_show("splash")
		"menu":
			_show_select_save_screen()
		"difficulty", "slot_options", "slot_action", "copy_target":
			_show_select_save_screen()
		"stats":
			_on_stats_back_pressed()

func _leave_splash() -> void:
	seen_splash = true
	_show_select_save_screen()

# Registers Z as an extra key for Godot's built-in "ui_accept" action -- once bound, it activates whatever Control has keyboard focus
# everywhere in the game (this screen, shop, level-up, battle menus), the exact same way Enter/Space already do natively. This runs once
# here since the title screen is always the very first scene loaded, and InputMap changes are global and persist across every later
# scene change for the rest of the process.
func _bind_extra_select_key() -> void:
	for event in InputMap.action_get_events("ui_accept"):
		if event is InputEventKey and event.keycode == KEY_Z:
			return
	var z_event := InputEventKey.new()
	z_event.keycode = KEY_Z
	InputMap.action_add_event("ui_accept", z_event)

# --- the file select ------------------------------------------------------------------------------------------------------------------------

func _commas(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return ("-" if n < 0 else "") + out

# A file never played reads as "New Game"; otherwise its name, its difficulty and what it has banked, read straight off disk
# (SaveData.gd:slot_summary) without touching active_slot, so browsing the file select can never affect the file you play.
func _refresh_select_save_display() -> void:
	for n in [1, 2, 3]:
		var summary: Dictionary = SaveDataScript.slot_summary(n)
		var card: TitleEntry = slot_buttons[n]
		var parts: Dictionary = _card_parts[n]
		var exists: bool = not summary.is_empty()
		parts.face.visible = exists
		parts.plus.visible = not exists
		if not exists:
			card.text = "Slot %d\nNew Game" % n
			card.description = "Start a new file in slot %d." % n
			parts.name.text = "New Game"
			parts.diff.text = "Slot %d" % n
			parts.diff.add_theme_color_override("font_color", PixelKit.DIM)
			parts.stats.text = "Choose a difficulty to begin."
		else:
			var banked := "%s Essence  ·  %d upgrade%s" % [_commas(int(summary.essence)), int(summary.upgrades), "" if int(summary.upgrades) == 1 else "s"]
			card.text = "%s\n%s\n%s" % [summary.name, summary.difficulty_name, banked]
			card.description = "Continue this file (%s)." % summary.difficulty_name
			parts.name.text = str(summary.name)
			parts.diff.text = str(summary.difficulty_name)
			parts.diff.add_theme_color_override("font_color", DIFFICULTY_COLORS.get(str(summary.difficulty_id), PixelKit.CREAM))
			parts.stats.text = banked
		_recolor_card(n, card.has_focus())
		# Nothing to rename, copy, or clear on a file that's never been played.
		options_buttons[n].visible = exists

func _show_select_save_screen() -> void:
	_refresh_select_save_display()
	_show("files")
	slot_buttons[1].grab_focus()

func _show_main_menu() -> void:
	var summary: Dictionary = SaveDataScript.slot_summary(SaveDataScript.active_slot)
	_menu_file_label.text = "%s  ·  %s" % [summary.get("name", "Slot %d" % SaveDataScript.active_slot), summary.get("difficulty_name", "")] if not summary.is_empty() else ""
	_show("menu")
	play_button.grab_focus()

# An already-played file just becomes active; an empty one detours through the difficulty screen first (see _on_difficulty_pressed) --
# either way ends at the main menu with save_data freshly reloaded for whichever slot is now active.
func _on_slot_pressed(n: int) -> void:
	if SaveDataScript.slot_exists(n):
		SaveDataScript.active_slot = n
		save_data = SaveDataScript.load_data()
		_show_main_menu()
	else:
		pending_slot = n
		# Cleared here (not just after creating a file) so a name typed for a slot the player backed out of never leaks into another.
		new_save_name_edit.text = ""
		_show("difficulty")
		difficulty_buttons[SaveDataScript.DIFFICULTIES[0].id].grab_focus()

# Locks in pending_slot's difficulty for good (SaveData.gd:init_slot) -- there's no path back to this screen for an already-initialized
# slot, so "you can't change the difficulty once you start a file" holds structurally, not just by convention.
func _on_difficulty_pressed(difficulty_id: String) -> void:
	SaveDataScript.init_slot(pending_slot, difficulty_id, new_save_name_edit.text.strip_edges())
	SaveDataScript.active_slot = pending_slot
	save_data = SaveDataScript.load_data()
	_show_main_menu()

func _on_difficulty_back_pressed() -> void:
	_show_select_save_screen()

func _on_switch_save_pressed() -> void:
	_show_select_save_screen()

# Opens the small Rename / Copy / Clear / Back screen for slot n (the gear on its card).
func _on_slot_options_pressed(n: int) -> void:
	slot_options_target = n
	slot_options_header.text = str(SaveDataScript.slot_summary(n).get("name", "Slot %d" % n))
	_show("slot_options")
	slot_options_rename_button.grab_focus()

# Shared entry point for the Rename / Clear / Copy-overwrite confirmation screen -- mode is "rename" (pre-fills the name field with the
# slot's current name), "clear" (shows the delete warning instead), or "copy" (shows an overwrite warning naming both the source and
# destination). See _on_slot_action_confirm_pressed for what Confirm actually does with slot_action_mode / target (and copy_source_slot).
func _show_slot_action_screen(mode: String, n: int) -> void:
	slot_action_mode = mode
	slot_action_target = n
	var is_rename: bool = mode == "rename"
	var current_name: String = SaveDataScript.slot_summary(n).get("name", "Slot %d" % n)
	match mode:
		"rename":
			slot_action_header.text = "Rename %s" % current_name
			slot_action_confirm_button.set_face_text("Confirm")
		"clear":
			slot_action_header.text = "Clear %s?" % current_name
			slot_action_confirm_button.set_face_text("Delete")
		"copy":
			var source_name: String = SaveDataScript.slot_summary(copy_source_slot).get("name", "Slot %d" % copy_source_slot)
			slot_action_header.text = "Overwrite %s with a copy of %s?" % [current_name, source_name]
			slot_action_confirm_button.set_face_text("Overwrite")
	slot_action_name_edit.visible = is_rename
	slot_action_warning.visible = not is_rename
	if mode == "copy":
		slot_action_warning.text = "The file being overwritten is lost for good. This can't be undone."
	elif mode == "clear":
		slot_action_warning.text = "This permanently deletes all progress on this file. This can't be undone."
	if is_rename:
		slot_action_name_edit.text = current_name
	_show("slot_action")
	if is_rename:
		slot_action_name_edit.grab_focus()
	else:
		slot_action_confirm_button.grab_focus()

func _on_rename_slot_pressed(n: int) -> void:
	_show_slot_action_screen("rename", n)

func _on_clear_slot_pressed(n: int) -> void:
	_show_slot_action_screen("clear", n)

# "Copy Slot N to..." -- lists the other 2 slots as destinations, relabelled fresh each time since which slots those are depends on the source.
func _on_copy_slot_pressed(n: int) -> void:
	copy_source_slot = n
	var source_name: String = SaveDataScript.slot_summary(n).get("name", "Slot %d" % n)
	copy_target_header.text = "Copy %s to..." % source_name
	var other_slots: Array = [1, 2, 3].filter(func(s): return s != n)
	for i in other_slots.size():
		var target_n: int = other_slots[i]
		var button: TitleEntry = copy_target_buttons[i]
		var summary: Dictionary = SaveDataScript.slot_summary(target_n)
		if summary.is_empty():
			button.set_face_text("Slot %d  ·  Empty" % target_n)
			button.description = "Copy into empty slot %d." % target_n
		else:
			button.set_face_text("%s  ·  %s Essence" % [summary.name, _commas(int(summary.essence))])
			button.description = "Overwrite this file with a copy of %s." % source_name
		# Rebind rather than bind-once at construction, since which real slot button index i maps to changes with the source.
		for existing_connection in button.pressed.get_connections():
			button.pressed.disconnect(existing_connection.callable)
		button.pressed.connect(_on_copy_target_pressed.bind(target_n))
	_show("copy_target")
	copy_target_buttons[0].grab_focus()

# An empty destination copies immediately (nothing to lose); an occupied one detours through slot_action_box first to confirm the overwrite.
func _on_copy_target_pressed(n: int) -> void:
	if SaveDataScript.slot_exists(n):
		_show_slot_action_screen("copy", n)
	else:
		SaveDataScript.copy_slot(copy_source_slot, n)
		_show_select_save_screen()

func _on_slot_action_confirm_pressed() -> void:
	if slot_action_mode == "rename":
		SaveDataScript.rename_slot(slot_action_target, slot_action_name_edit.text.strip_edges())
	elif slot_action_mode == "clear":
		SaveDataScript.delete_slot(slot_action_target)
	elif slot_action_mode == "copy":
		SaveDataScript.copy_slot(copy_source_slot, slot_action_target)
	_show_select_save_screen()

func _on_slot_action_cancel_pressed() -> void:
	_show_select_save_screen()

# --- the main menu --------------------------------------------------------------------------------------------------------------------------

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://Main.tscn")

# Debug sandbox: a throwaway run whose every save read/write stays in memory (SaveData.sandbox_active) -- see Sandbox.gd / SandboxPanel.gd.
func _on_sandbox_pressed() -> void:
	SaveDataScript.sandbox_active = true
	SaveDataScript.sandbox_data = {}
	get_tree().change_scene_to_file("res://Main.tscn")

# The Map Editor shows the real overworld with nothing running in it; the same switch as the sandbox keeps any save read/write in memory.
func _on_map_editor_pressed() -> void:
	SaveDataScript.sandbox_active = true
	SaveDataScript.sandbox_data = {}
	get_tree().change_scene_to_file("res://MapEditor.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_stats_pressed() -> void:
	_refresh_stats_display()
	_show("stats")
	stats_back_button.grab_focus()

func _on_stats_back_pressed() -> void:
	_show_main_menu()

# Lifetime aggregates (SaveData.gd:record_lifetime_run_stats) -- device-wide, independent of which file is active. Never written by this
# screen, only read.
func _refresh_stats_display() -> void:
	var data: Dictionary = SaveDataScript.load_lifetime_data()
	stats_rows.runs.text = _commas(int(data.get("total_runs", 0)))
	stats_rows.kills.text = _commas(int(data.get("lifetime_kills", 0)))
	stats_rows.world.text = str(data.get("deepest_world_ever", "None yet"))
	stats_rows.bosses.text = _commas(int(data.get("total_bosses_defeated", 0)))
	stats_rows.nothing.text = "Yes" if data.get("game_completed_ever", false) else "Not yet"
