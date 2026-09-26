extends Control
class_name TitleScreen

const SaveDataScript := preload("res://scripts/SaveData.gd")
const BeastiaryPanelScript := preload("res://scripts/BeastiaryPanel.gd")
const TitleBackdropScript := preload("res://scripts/TitleBackdrop.gd")
const PixelLogoScript := preload("res://scripts/PixelLogo.gd")
const PixelUIScript := preload("res://scripts/PixelUI.gd")

const GAME_TITLE := "SAVAGE LANDS"
const GAME_SUBTITLE := "A tiny pixel-art action RPG"
# The logo's width as a fraction of the window in the full title layout / the
# compact one used while the wider stats screen is open.
const LOGO_WIDTH_FRACTION := 0.56
const LOGO_COMPACT_WIDTH_FRACTION := 0.26

var play_button: Button
var quit_button: Button
var stats_button: Button
var description_label: Label
var main_menu_box: VBoxContainer
var beastiary_panel: BeastiaryPanelScript

# The living scene behind everything (sunset, ridges, the barbarian's campfire),
# the pixel-font logo pinned above the menu, and the framed panel the menu
# screens sit in. logo_compact shrinks the logo and dims the scene while a
# screen too big to share the window with a full logo (the stats screen) is up.
var backdrop: TitleBackdropScript
var logo: PixelLogoScript
var subtitle_label: Label
var logo_block: VBoxContainer
var menu_margin: MarginContainer
var menu_panel: PanelContainer
var logo_compact := false

# Lifetime stats (SaveData.gd:record_lifetime_run_stats) -- a simple
# read-only recap, not tied to any one save slot. One multi-line label,
# rebuilt each time the screen opens (_refresh_stats_display), rather than a
# row per stat -- the set is small and fixed, unlike the save-slot list.
var stats_box: VBoxContainer
var stats_label: Label

# Shown first, before Play/Quit: 3 independent save slots, each
# locking in a difficulty (SaveData.gd:DIFFICULTIES) the moment it's created.
# Picking an empty slot detours through difficulty_box; picking a filled one
# goes straight to the main menu.
var select_save_box: VBoxContainer
var slot_buttons := {}
# Per-slot "..." overflow button -- opens slot_options_box for that slot
# rather than exposing Rename/Copy/Clear as 3 separate buttons on every row.
var options_buttons := {}
var difficulty_box: VBoxContainer
var difficulty_buttons := {}
# Optional name for the save about to be created -- read once, when a
# difficulty is chosen (see _on_difficulty_pressed).
var new_save_name_edit: LineEdit
var switch_save_button: Button
# Which empty slot difficulty_box is currently choosing a difficulty for.
var pending_slot := 0

# Small per-slot menu (Rename/Copy/Clear/Back) opened by a slot row's "..."
# button -- keeps the Select Save rows to 2 buttons wide instead of 4.
var slot_options_box: VBoxContainer
var slot_options_header: Label
var slot_options_rename_button: Button
var slot_options_copy_button: Button
var slot_options_clear_button: Button
var slot_options_target := 0

# Shared Rename/Clear/Copy confirmation screen for an already-played slot
# (see _on_rename_slot_pressed/_on_clear_slot_pressed/_on_copy_target_
# pressed) -- one box reused for all three rather than near-identical ones,
# since they differ only in which controls are visible and what Confirm does.
var slot_action_box: VBoxContainer
var slot_action_header: Label
var slot_action_warning: Label
var slot_action_name_edit: LineEdit
var slot_action_confirm_button: Button
# "rename", "clear", or "copy" -- which action Confirm performs.
var slot_action_mode := ""
var slot_action_target := 0

# "Copy Slot N to..." destination picker (see _on_copy_slot_pressed) -- the
# other 2 slots besides the source, whichever it is. Picking an empty one
# copies immediately; picking a filled one routes through slot_action_box
# (mode "copy") to confirm the overwrite first.
var copy_target_box: VBoxContainer
var copy_target_header: Label
var copy_target_buttons := {}
var copy_source_slot := 0

var save_data: Dictionary

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_bind_extra_select_key()
	save_data = SaveDataScript.load_data()

	# The scene behind everything: banded sunset, parallax ridges, the
	# barbarian's campfire and its drifting embers (TitleBackdrop.gd).
	backdrop = TitleBackdropScript.new()
	add_child(backdrop)

	# The menu sits in a framed panel centered in whatever room the logo
	# leaves below it (menu_margin's top margin tracks the logo's height).
	menu_margin = MarginContainer.new()
	menu_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(menu_margin)

	var center := CenterContainer.new()
	menu_margin.add_child(center)

	menu_panel = PanelContainer.new()
	menu_panel.add_theme_stylebox_override("panel", PixelUIScript.panel_style())
	center.add_child(menu_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_panel.add_child(column)

	# The logo block is added after the menu so it draws over it; it's pinned
	# to the top and never takes part in the menu's centering.
	logo_block = VBoxContainer.new()
	logo_block.set_anchors_preset(Control.PRESET_TOP_WIDE)
	logo_block.offset_top = 26
	logo_block.add_theme_constant_override("separation", 8)
	logo_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo_block)

	logo = PixelLogoScript.new()
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	logo_block.add_child(logo)

	subtitle_label = Label.new()
	subtitle_label.text = GAME_SUBTITLE
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 16)
	subtitle_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.62))
	subtitle_label.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.08, 0.95))
	subtitle_label.add_theme_constant_override("outline_size", 5)
	subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo_block.add_child(subtitle_label)

	resized.connect(_update_logo_layout)
	_update_logo_layout()

	main_menu_box = VBoxContainer.new()
	main_menu_box.add_theme_constant_override("separation", 18)
	main_menu_box.alignment = BoxContainer.ALIGNMENT_CENTER
	# Hidden until a save slot is chosen via select_save_box below --
	# Select Save is the first thing shown, not the main menu.
	main_menu_box.visible = false
	column.add_child(main_menu_box)

	play_button = Button.new()
	play_button.text = "Play"
	play_button.custom_minimum_size = Vector2(180, 44)
	play_button.pressed.connect(_on_play_pressed)
	_setup_hover_button(play_button, "Begin your adventure.")
	_style_skill_node_button(play_button)
	main_menu_box.add_child(play_button)

	switch_save_button = Button.new()
	switch_save_button.text = "Switch Save"
	switch_save_button.custom_minimum_size = Vector2(180, 44)
	switch_save_button.pressed.connect(_on_switch_save_pressed)
	_setup_hover_button(switch_save_button, "Return to Select Save to play a different slot.")
	_style_skill_node_button(switch_save_button)
	main_menu_box.add_child(switch_save_button)

	stats_button = Button.new()
	stats_button.text = "Stats"
	stats_button.custom_minimum_size = Vector2(180, 44)
	stats_button.pressed.connect(_on_stats_pressed)
	_setup_hover_button(stats_button, "View your lifetime stats across every save.")
	_style_skill_node_button(stats_button)
	main_menu_box.add_child(stats_button)

	var beastiary_button := Button.new()
	beastiary_button.text = "Beastiary"
	beastiary_button.custom_minimum_size = Vector2(180, 44)
	beastiary_button.pressed.connect(func(): beastiary_panel.open())
	_setup_hover_button(beastiary_button, "Browse every creature you've encountered or defeated, across every save.")
	_style_skill_node_button(beastiary_button)
	main_menu_box.add_child(beastiary_button)

	beastiary_panel = BeastiaryPanelScript.new()
	add_child(beastiary_panel)

	quit_button = Button.new()
	quit_button.text = "Quit"
	quit_button.custom_minimum_size = Vector2(180, 44)
	quit_button.pressed.connect(_on_quit_pressed)
	_setup_hover_button(quit_button, "Exit the game.")
	_style_skill_node_button(quit_button)
	main_menu_box.add_child(quit_button)

	select_save_box = VBoxContainer.new()
	select_save_box.add_theme_constant_override("separation", 14)
	select_save_box.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(select_save_box)

	var select_save_header := Label.new()
	select_save_header.text = "Select a Save"
	select_save_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	select_save_header.add_theme_font_size_override("font_size", 22)
	select_save_header.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	select_save_box.add_child(select_save_header)

	for n in [1, 2, 3]:
		var slot_row := HBoxContainer.new()
		slot_row.add_theme_constant_override("separation", 8)
		select_save_box.add_child(slot_row)

		var slot_button := Button.new()
		slot_button.custom_minimum_size = Vector2(190, 56)
		slot_button.pressed.connect(_on_slot_pressed.bind(n))
		_setup_hover_button(slot_button, "")
		_style_skill_node_button(slot_button)
		slot_row.add_child(slot_button)
		slot_buttons[n] = slot_button

		var options_button := Button.new()
		options_button.text = "..."
		options_button.custom_minimum_size = Vector2(44, 56)
		options_button.pressed.connect(_on_slot_options_pressed.bind(n))
		_setup_hover_button(options_button, "Rename, copy, or clear this save.")
		_style_skill_node_button(options_button)
		slot_row.add_child(options_button)
		options_buttons[n] = options_button

	var select_save_quit_button := Button.new()
	select_save_quit_button.text = "Quit"
	select_save_quit_button.custom_minimum_size = Vector2(180, 44)
	select_save_quit_button.pressed.connect(_on_quit_pressed)
	_setup_hover_button(select_save_quit_button, "Exit the game.")
	_style_skill_node_button(select_save_quit_button)
	select_save_box.add_child(select_save_quit_button)

	slot_options_box = VBoxContainer.new()
	slot_options_box.add_theme_constant_override("separation", 14)
	slot_options_box.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_options_box.visible = false
	column.add_child(slot_options_box)

	slot_options_header = Label.new()
	slot_options_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_options_header.add_theme_font_size_override("font_size", 22)
	slot_options_header.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	slot_options_box.add_child(slot_options_header)

	slot_options_rename_button = Button.new()
	slot_options_rename_button.text = "Rename"
	slot_options_rename_button.custom_minimum_size = Vector2(220, 44)
	slot_options_rename_button.pressed.connect(func(): _on_rename_slot_pressed(slot_options_target))
	_setup_hover_button(slot_options_rename_button, "Rename this save.")
	_style_skill_node_button(slot_options_rename_button)
	slot_options_box.add_child(slot_options_rename_button)

	slot_options_copy_button = Button.new()
	slot_options_copy_button.text = "Copy"
	slot_options_copy_button.custom_minimum_size = Vector2(220, 44)
	slot_options_copy_button.pressed.connect(func(): _on_copy_slot_pressed(slot_options_target))
	_setup_hover_button(slot_options_copy_button, "Copy this save to another slot.")
	_style_skill_node_button(slot_options_copy_button)
	slot_options_box.add_child(slot_options_copy_button)

	slot_options_clear_button = Button.new()
	slot_options_clear_button.text = "Clear"
	slot_options_clear_button.custom_minimum_size = Vector2(220, 44)
	slot_options_clear_button.pressed.connect(func(): _on_clear_slot_pressed(slot_options_target))
	_setup_hover_button(slot_options_clear_button, "Permanently delete this save.")
	_style_skill_node_button(slot_options_clear_button)
	slot_options_box.add_child(slot_options_clear_button)

	var slot_options_back_button := Button.new()
	slot_options_back_button.text = "Back"
	slot_options_back_button.custom_minimum_size = Vector2(180, 40)
	slot_options_back_button.pressed.connect(_show_select_save_screen)
	_setup_hover_button(slot_options_back_button, "Return to Select Save.")
	_style_skill_node_button(slot_options_back_button)
	slot_options_box.add_child(slot_options_back_button)

	difficulty_box = VBoxContainer.new()
	difficulty_box.add_theme_constant_override("separation", 14)
	difficulty_box.alignment = BoxContainer.ALIGNMENT_CENTER
	difficulty_box.visible = false
	column.add_child(difficulty_box)

	var difficulty_header := Label.new()
	difficulty_header.text = "Choose a Difficulty"
	difficulty_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	difficulty_header.add_theme_font_size_override("font_size", 22)
	difficulty_header.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	difficulty_box.add_child(difficulty_header)

	var difficulty_note := Label.new()
	difficulty_note.text = "Locked in for this save -- it can't be changed later."
	difficulty_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	difficulty_note.add_theme_font_size_override("font_size", 13)
	difficulty_note.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	difficulty_box.add_child(difficulty_note)

	new_save_name_edit = LineEdit.new()
	new_save_name_edit.placeholder_text = "Save name (optional)"
	new_save_name_edit.custom_minimum_size = Vector2(220, 36)
	new_save_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	new_save_name_edit.max_length = 24
	_style_name_edit(new_save_name_edit)
	difficulty_box.add_child(new_save_name_edit)

	for d in SaveDataScript.DIFFICULTIES:
		var diff_button := Button.new()
		diff_button.text = d.name
		diff_button.custom_minimum_size = Vector2(220, 44)
		diff_button.pressed.connect(_on_difficulty_pressed.bind(d.id))
		_setup_hover_button(diff_button, d.description)
		_style_skill_node_button(diff_button)
		difficulty_box.add_child(diff_button)
		difficulty_buttons[d.id] = diff_button

	var difficulty_back_button := Button.new()
	difficulty_back_button.text = "Back"
	difficulty_back_button.custom_minimum_size = Vector2(180, 40)
	difficulty_back_button.pressed.connect(_on_difficulty_back_pressed)
	_setup_hover_button(difficulty_back_button, "Return to Select Save.")
	_style_skill_node_button(difficulty_back_button)
	difficulty_box.add_child(difficulty_back_button)

	slot_action_box = VBoxContainer.new()
	slot_action_box.add_theme_constant_override("separation", 14)
	slot_action_box.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_action_box.visible = false
	column.add_child(slot_action_box)

	slot_action_header = Label.new()
	slot_action_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_action_header.add_theme_font_size_override("font_size", 22)
	slot_action_header.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	slot_action_box.add_child(slot_action_header)

	slot_action_warning = Label.new()
	slot_action_warning.text = "This permanently deletes all progress on this save. This can't be undone."
	slot_action_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_action_warning.custom_minimum_size = Vector2(320, 0)
	slot_action_warning.autowrap_mode = TextServer.AUTOWRAP_WORD
	slot_action_warning.add_theme_font_size_override("font_size", 13)
	slot_action_warning.add_theme_color_override("font_color", Color(0.95, 0.4, 0.4))
	slot_action_box.add_child(slot_action_warning)

	slot_action_name_edit = LineEdit.new()
	slot_action_name_edit.placeholder_text = "Save name"
	slot_action_name_edit.custom_minimum_size = Vector2(220, 36)
	slot_action_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_action_name_edit.max_length = 24
	_style_name_edit(slot_action_name_edit)
	slot_action_box.add_child(slot_action_name_edit)

	var slot_action_buttons_row := HBoxContainer.new()
	slot_action_buttons_row.add_theme_constant_override("separation", 12)
	slot_action_buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_action_box.add_child(slot_action_buttons_row)

	slot_action_confirm_button = Button.new()
	slot_action_confirm_button.text = "Confirm"
	slot_action_confirm_button.custom_minimum_size = Vector2(120, 40)
	slot_action_confirm_button.pressed.connect(_on_slot_action_confirm_pressed)
	_setup_hover_button(slot_action_confirm_button, "")
	_style_skill_node_button(slot_action_confirm_button)
	slot_action_buttons_row.add_child(slot_action_confirm_button)

	var slot_action_cancel_button := Button.new()
	slot_action_cancel_button.text = "Cancel"
	slot_action_cancel_button.custom_minimum_size = Vector2(120, 40)
	slot_action_cancel_button.pressed.connect(_on_slot_action_cancel_pressed)
	_setup_hover_button(slot_action_cancel_button, "Return to Select Save without changing anything.")
	_style_skill_node_button(slot_action_cancel_button)
	slot_action_buttons_row.add_child(slot_action_cancel_button)

	copy_target_box = VBoxContainer.new()
	copy_target_box.add_theme_constant_override("separation", 14)
	copy_target_box.alignment = BoxContainer.ALIGNMENT_CENTER
	copy_target_box.visible = false
	column.add_child(copy_target_box)

	copy_target_header = Label.new()
	copy_target_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy_target_header.add_theme_font_size_override("font_size", 22)
	copy_target_header.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	copy_target_box.add_child(copy_target_header)

	# Exactly 2 buttons -- with only 3 slots total, "every slot but the
	# source" is always the other 2, whichever those turn out to be (see
	# _on_copy_slot_pressed, which relabels these fresh every time).
	for i in [0, 1]:
		var copy_target_button := Button.new()
		copy_target_button.custom_minimum_size = Vector2(260, 56)
		_setup_hover_button(copy_target_button, "")
		_style_skill_node_button(copy_target_button)
		copy_target_box.add_child(copy_target_button)
		copy_target_buttons[i] = copy_target_button

	var copy_target_back_button := Button.new()
	copy_target_back_button.text = "Back"
	copy_target_back_button.custom_minimum_size = Vector2(180, 40)
	copy_target_back_button.pressed.connect(_show_select_save_screen)
	_setup_hover_button(copy_target_back_button, "Return to Select Save without copying anything.")
	_style_skill_node_button(copy_target_back_button)
	copy_target_box.add_child(copy_target_back_button)

	description_label = Label.new()
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.custom_minimum_size = Vector2(400, 24)
	description_label.add_theme_font_size_override("font_size", 13)
	description_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.6))
	column.add_child(description_label)

	stats_box = VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 10)
	stats_box.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_box.visible = false
	column.add_child(stats_box)

	var stats_header := Label.new()
	stats_header.text = "Lifetime Stats"
	stats_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_header.add_theme_font_size_override("font_size", 22)
	stats_header.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	stats_box.add_child(stats_header)

	stats_label = Label.new()
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 16)
	stats_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	stats_box.add_child(stats_label)

	var stats_back_button := Button.new()
	stats_back_button.text = "Back"
	stats_back_button.custom_minimum_size = Vector2(180, 40)
	stats_back_button.pressed.connect(_on_stats_back_pressed)
	_setup_hover_button(stats_back_button, "Return to the main menu.")
	_style_skill_node_button(stats_back_button)
	stats_box.add_child(stats_back_button)

	_refresh_select_save_display()
	slot_buttons[1].grab_focus()

	# Re-run now that every screen exists (the first call, above, ran before
	# the stats screen was built).
	_update_logo_layout()

	# Entrance: the logo fades up first, then the menu panel behind it.
	logo_block.modulate.a = 0.0
	menu_margin.modulate.a = 0.0
	var intro := create_tween().set_parallel(true)
	intro.tween_property(logo_block, "modulate:a", 1.0, 1.0)
	intro.tween_property(menu_margin, "modulate:a", 1.0, 0.7).set_delay(0.45)

# Sizes the pixel logo to the window (bigger pixels on a bigger window, capped
# so it never dominates) and reserves exactly its height above the menu. The
# compact form (smaller logo, no subtitle) is for screens too big to share the
# window with a full logo -- the stats screen.
func _update_logo_layout() -> void:
	if logo == null or size.x < 32.0:
		return
	var fraction: float = LOGO_COMPACT_WIDTH_FRACTION if logo_compact else LOGO_WIDTH_FRACTION
	var cols_estimate := 69.0
	var pixel: int = clampi(int(size.x * fraction / cols_estimate), 2, 10)
	logo.set_logo(GAME_TITLE, pixel)
	subtitle_label.visible = not logo_compact
	var block_height: float = logo.custom_minimum_size.y + (0.0 if logo_compact else 32.0)
	var top_margin: float = 26.0 + block_height + 8.0
	menu_margin.add_theme_constant_override("margin_top", int(top_margin))

func _set_logo_compact(compact: bool) -> void:
	if compact == logo_compact:
		return
	logo_compact = compact
	_update_logo_layout()

# The scene dims behind the wide screens so it never fights the text on top of
# it, and the logo shrinks to make room for them.
func _process(_delta: float) -> void:
	if backdrop == null:
		return
	var heavy: bool = stats_box.visible
	_set_logo_compact(heavy)
	backdrop.dim_target = 0.6 if heavy else (0.35 if beastiary_panel.visible else 0.0)

# Flat rectangular panel, no rounded corners or anti-aliasing -- matches the
# crisp-edged StyleBoxFlat card look established for the shop (HUD.gd).
func _make_node_stylebox(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.anti_aliasing = false
	sb.set_content_margin_all(8)
	return sb

func _style_skill_node_button(button: Button) -> void:
	# The shared pixel-art skin (PixelUI.gd): beveled bronze frame, rivets and a
	# banded fill, with gold hover/focus states -- the same bronze the in-game
	# menus use, so the title screen and the rest of the game still match.
	PixelUIScript.skin_button(button)

# Bronze/yellow-accent chrome for the save-name text fields, matching every
# other bordered control on this screen instead of Godot's stock LineEdit box.
func _style_name_edit(line_edit: LineEdit) -> void:
	line_edit.add_theme_stylebox_override("normal", _make_node_stylebox(Color(0.09, 0.08, 0.12, 0.97), Color(0.62, 0.48, 0.2, 1.0)))
	line_edit.add_theme_stylebox_override("focus", _make_node_stylebox(Color(0.09, 0.08, 0.12, 0.97), Color(1.0, 0.9, 0.2, 1.0)))
	line_edit.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	line_edit.add_theme_color_override("font_placeholder_color", Color(0.55, 0.55, 0.58, 0.8))
	line_edit.add_theme_color_override("font_selected_color", Color(0.09, 0.08, 0.12))
	line_edit.add_theme_color_override("selection_color", Color(1.0, 0.9, 0.2, 0.55))
	line_edit.add_theme_color_override("caret_color", Color(1.0, 0.9, 0.2))

# Same yellow-highlight-plus-description hover/focus pattern used everywhere
# else in the game's UI (shop, level-up, battle menus).
func _setup_hover_button(button: Button, description: String, animate: bool = true) -> void:
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.2))
	button.add_theme_color_override("font_focus_color", Color(1.0, 0.9, 0.2))
	button.set_meta("description", description)
	button.mouse_entered.connect(func(): description_label.text = button.get_meta("description", ""))
	button.mouse_exited.connect(func(): description_label.text = "")
	button.focus_entered.connect(func(): description_label.text = button.get_meta("description", ""))
	button.focus_exited.connect(func(): description_label.text = "")
	if animate:
		# A quick swell on hover/focus, so the menu feels alive under the
		# cursor instead of just changing color. Scaling doesn't disturb the
		# container layout, only how the button draws.
		button.resized.connect(func(): button.pivot_offset = button.size / 2.0)
		button.mouse_entered.connect(_swell_button.bind(button, 1.06))
		button.focus_entered.connect(_swell_button.bind(button, 1.06))
		button.mouse_exited.connect(_swell_button.bind(button, 1.0))
		button.focus_exited.connect(_swell_button.bind(button, 1.0))

func _swell_button(button: Button, target_scale: float) -> void:
	if button.has_meta("swell_tween"):
		var old: Tween = button.get_meta("swell_tween")
		if old != null and old.is_valid():
			old.kill()
	var tween := button.create_tween()
	tween.tween_property(button, "scale", Vector2(target_scale, target_scale), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	button.set_meta("swell_tween", tween)

# Registers Z as an extra key for Godot's built-in "ui_accept" action --
# once bound, it activates whatever Control has keyboard focus everywhere
# in the game (this screen, shop, level-up, battle menus), the exact same
# way Enter/Space already do natively. This runs once here since the title
# screen is always the very first scene loaded, and InputMap changes are
# global and persist across every later scene change for the rest of the
# process.
func _bind_extra_select_key() -> void:
	for event in InputMap.action_get_events("ui_accept"):
		if event is InputEventKey and event.keycode == KEY_Z:
			return
	var z_event := InputEventKey.new()
	z_event.keycode = KEY_Z
	InputMap.action_add_event("ui_accept", z_event)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://Main.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_stats_pressed() -> void:
	select_save_box.visible = false
	difficulty_box.visible = false
	main_menu_box.visible = false
	stats_box.visible = true
	slot_action_box.visible = false
	copy_target_box.visible = false
	slot_options_box.visible = false
	_refresh_stats_display()

func _on_stats_back_pressed() -> void:
	stats_box.visible = false
	_show_main_menu()

# Lifetime aggregates (SaveData.gd:record_lifetime_run_stats) -- device-wide,
# independent of which save slot is active. Never written by this screen,
# only read.
func _refresh_stats_display() -> void:
	var data: Dictionary = SaveDataScript.load_lifetime_data()
	stats_label.text = "Runs played: %d\nLifetime kills: %d\nDeepest world reached: %s\nBosses/minibosses defeated: %d\nThe Nothingness conquered: %s" % [
		data.get("total_runs", 0),
		data.get("lifetime_kills", 0),
		data.get("deepest_world_ever", "None yet"),
		data.get("total_bosses_defeated", 0),
		"Yes" if data.get("game_completed_ever", false) else "Not yet",
	]

# Empty for a slot never played -- otherwise essence/best_wave/difficulty
# read straight off disk without touching active_slot (SaveData.gd:
# slot_summary), so browsing Select Save can never affect the slot you're
# actually about to play.
func _refresh_select_save_display() -> void:
	for n in [1, 2, 3]:
		var summary: Dictionary = SaveDataScript.slot_summary(n)
		var button: Button = slot_buttons[n]
		var exists: bool = not summary.is_empty()
		if not exists:
			button.text = "Slot %d\n[New Game]" % n
			button.set_meta("description", "Start a new save in slot %d." % n)
		else:
			button.text = "%s\nWave %d -- %d Essence\n%s" % [summary.name, summary.best_wave, summary.essence, summary.difficulty_name]
			button.set_meta("description", "Continue this save (%s)." % summary.difficulty_name)
		# Nothing to rename, copy, or clear on a slot that's never been played.
		options_buttons[n].visible = exists

func _show_select_save_screen() -> void:
	select_save_box.visible = true
	difficulty_box.visible = false
	main_menu_box.visible = false
	stats_box.visible = false
	slot_action_box.visible = false
	copy_target_box.visible = false
	slot_options_box.visible = false
	_refresh_select_save_display()
	slot_buttons[1].grab_focus()

func _show_main_menu() -> void:
	select_save_box.visible = false
	difficulty_box.visible = false
	main_menu_box.visible = true
	stats_box.visible = false
	slot_action_box.visible = false
	copy_target_box.visible = false
	slot_options_box.visible = false
	play_button.grab_focus()

# Opens the small Rename/Copy/Clear/Back menu for slot n (the "..." button
# on its Select Save row) instead of exposing all 3 actions as separate
# buttons on every row.
func _on_slot_options_pressed(n: int) -> void:
	slot_options_target = n
	var current_name: String = SaveDataScript.slot_summary(n).get("name", "Slot %d" % n)
	slot_options_header.text = current_name
	select_save_box.visible = false
	slot_options_box.visible = true
	slot_options_rename_button.grab_focus()

# An already-played slot just becomes active; an empty one detours through
# difficulty_box first (see _on_difficulty_pressed) -- either way ends at
# the main menu with save_data freshly reloaded for whichever slot is now
# active.
func _on_slot_pressed(n: int) -> void:
	if SaveDataScript.slot_exists(n):
		SaveDataScript.active_slot = n
		save_data = SaveDataScript.load_data()
		_show_main_menu()
	else:
		pending_slot = n
		# Cleared here (not just after creating a save) so a name typed for
		# a slot the player backed out of never leaks into a different one.
		new_save_name_edit.text = ""
		select_save_box.visible = false
		difficulty_box.visible = true
		difficulty_buttons[SaveDataScript.DIFFICULTIES[0].id].grab_focus()

# Locks in pending_slot's difficulty for good (SaveData.gd:init_slot) --
# there's no path back to this screen for an already-initialized slot, so
# "you can't change the difficulty once you start a save" holds structurally,
# not just by convention.
func _on_difficulty_pressed(difficulty_id: String) -> void:
	SaveDataScript.init_slot(pending_slot, difficulty_id, new_save_name_edit.text.strip_edges())
	SaveDataScript.active_slot = pending_slot
	save_data = SaveDataScript.load_data()
	_show_main_menu()

func _on_difficulty_back_pressed() -> void:
	_show_select_save_screen()

func _on_switch_save_pressed() -> void:
	_show_select_save_screen()

# Shared entry point for the Rename/Clear/Copy-overwrite confirmation
# screen -- mode is "rename" (pre-fills the name field with the slot's
# current name), "clear" (shows the delete warning instead), or "copy"
# (shows an overwrite warning naming both the source and destination). See
# _on_slot_action_confirm_pressed for what Confirm actually does with
# slot_action_mode/target (and copy_source_slot, for "copy").
func _show_slot_action_screen(mode: String, n: int) -> void:
	slot_action_mode = mode
	slot_action_target = n
	var is_rename: bool = mode == "rename"
	var current_name: String = SaveDataScript.slot_summary(n).get("name", "Slot %d" % n)
	match mode:
		"rename":
			slot_action_header.text = "Rename %s" % current_name
			slot_action_confirm_button.text = "Confirm"
		"clear":
			slot_action_header.text = "Clear %s?" % current_name
			slot_action_confirm_button.text = "Delete"
		"copy":
			var source_name: String = SaveDataScript.slot_summary(copy_source_slot).get("name", "Slot %d" % copy_source_slot)
			slot_action_header.text = "Overwrite %s with a copy of %s?" % [current_name, source_name]
			slot_action_confirm_button.text = "Overwrite"
	slot_action_name_edit.visible = is_rename
	slot_action_warning.visible = not is_rename
	if is_rename:
		slot_action_name_edit.text = current_name
	select_save_box.visible = false
	copy_target_box.visible = false
	slot_options_box.visible = false
	slot_action_box.visible = true
	if is_rename:
		slot_action_name_edit.grab_focus()
	else:
		slot_action_confirm_button.grab_focus()

func _on_rename_slot_pressed(n: int) -> void:
	_show_slot_action_screen("rename", n)

func _on_clear_slot_pressed(n: int) -> void:
	_show_slot_action_screen("clear", n)

# "Copy Slot N to..." -- lists the other 2 slots as destinations, relabeled
# fresh each time since which slots those are depends on the source.
func _on_copy_slot_pressed(n: int) -> void:
	copy_source_slot = n
	var source_name: String = SaveDataScript.slot_summary(n).get("name", "Slot %d" % n)
	copy_target_header.text = "Copy %s to..." % source_name
	var other_slots: Array = [1, 2, 3].filter(func(s): return s != n)
	for i in other_slots.size():
		var target_n: int = other_slots[i]
		var button: Button = copy_target_buttons[i]
		var summary: Dictionary = SaveDataScript.slot_summary(target_n)
		if summary.is_empty():
			button.text = "Slot %d\n[Empty]" % target_n
			button.set_meta("description", "Copy into empty slot %d." % target_n)
		else:
			button.text = "%s\nWave %d -- %d Essence" % [summary.name, summary.best_wave, summary.essence]
			button.set_meta("description", "Overwrite this save with a copy of %s." % source_name)
		# Rebind rather than bind-once at construction, since which real slot
		# button index i maps to changes with the source.
		for existing_connection in button.pressed.get_connections():
			button.pressed.disconnect(existing_connection.callable)
		button.pressed.connect(_on_copy_target_pressed.bind(target_n))
	select_save_box.visible = false
	slot_options_box.visible = false
	copy_target_box.visible = true
	copy_target_buttons[0].grab_focus()

# An empty destination copies immediately (nothing to lose); an occupied one
# detours through slot_action_box first to confirm the overwrite.
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
