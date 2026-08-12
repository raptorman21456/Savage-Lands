extends Control
class_name TitleScreen

const SaveDataScript := preload("res://scripts/SaveData.gd")

# A real tree: hand-placed (col, row) positions for every node (see
# SaveData.gd:UPGRADES) so branch/converge/split connector lines read
# cleanly. Each wing (Warrior/Merchant/Survivor) gets 3 sub-columns (branch
# A / trunk / branch B) with a blank gap column between wings, so a wing's
# own connectors never cross a neighboring wing's nodes. The 3 cross-wing
# convergence nodes sit below the main rows, pulled toward whichever
# position keeps both of their connector lines clear of a third wing's
# nodes -- the part most likely to need a visual tweak after a look.
const SKILL_TREE_LAYOUT := {
	# Warrior wing (cols 0-2)
	"strength": Vector2i(1, 0),
	"agility": Vector2i(1, 1),
	"vigor": Vector2i(0, 2),
	"reflexes_unlock": Vector2i(2, 2),
	"dexterity_unlock": Vector2i(2, 1),
	"berserker_edge": Vector2i(0, 3),
	"adrenaline": Vector2i(2, 3),
	"battle_hardened": Vector2i(1, 4),
	"pack_leader": Vector2i(1, 5),
	"prodigy": Vector2i(0, 6),
	"warlord": Vector2i(1, 6),
	"beastmaster": Vector2i(2, 6),
	# Warrior wing, deeper still (row 7+)
	"pack_bond": Vector2i(2, 7),
	"riposte": Vector2i(0, 7),
	"momentum": Vector2i(1, 7),
	"hardened": Vector2i(1, 8),
	"rage": Vector2i(2, 8),
	# Merchant wing (cols 4-6)
	"coins": Vector2i(5, 0),
	"intimidation": Vector2i(5, 1),
	"luck": Vector2i(4, 2),
	"haggling": Vector2i(6, 2),
	"silver_tongue": Vector2i(4, 3),
	"appraisal": Vector2i(6, 3),
	"golden_touch": Vector2i(5, 4),
	"investor": Vector2i(5, 5),
	# Merchant wing, new col 7 (mirrors the col-3 gap on the Warrior side)
	"fletcher": Vector2i(7, 1),
	"field_surgeon": Vector2i(7, 2),
	"windfall": Vector2i(7, 3),
	"black_market": Vector2i(4, 4),
	# Survivor wing (cols 8-10)
	"stamina": Vector2i(9, 0),
	"resilience_unlock": Vector2i(9, 1),
	"potions": Vector2i(8, 2),
	"herbalism": Vector2i(10, 2),
	"vampiric_grit": Vector2i(8, 3),
	"vigilant_defense": Vector2i(10, 3),
	"undying": Vector2i(9, 4),
	"second_wind": Vector2i(9, 5),
	# Survivor wing, new col 11
	"second_breath": Vector2i(11, 0),
	"block_master": Vector2i(11, 1),
	"last_stand": Vector2i(11, 2),
	"shield_mastery": Vector2i(10, 1),
	"unbreakable_guard": Vector2i(9, 2),
	"favour": Vector2i(9, 7),
	# Cross-wing convergence
	"warband": Vector2i(3, 4),
	"war_chest": Vector2i(7, 6),
	"battle_medic": Vector2i(4, 7),
	"war_profiteer": Vector2i(3, 5),
	# Deliberately isolated below the whole tree, no prereqs/connector lines
	# -- a post-game reward rather than part of any one wing's progression.
	"worldwalker": Vector2i(5, 9),
}
const SKILL_NODE_W := 120.0
const SKILL_NODE_H := 56.0
const SKILL_COL_W := 140.0
const SKILL_ROW_H := 80.0

var play_button: Button
var quit_button: Button
var upgrades_button: Button
var stats_button: Button
var description_label: Label
var main_menu_box: VBoxContainer

var upgrades_box: VBoxContainer
var upgrades_header_label: Label
var upgrade_buttons := {}
var barbarian_deco: TextureRect

# Lifetime stats (SaveData.gd:record_lifetime_run_stats) -- a simple
# read-only recap, not tied to any one save slot. One multi-line label,
# rebuilt each time the screen opens (_refresh_stats_display), rather than a
# row per stat -- the set is small and fixed, unlike the save-slot list.
var stats_box: VBoxContainer
var stats_label: Label

# Shown first, before Play/Upgrades/Quit: 3 independent save slots, each
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

	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.1, 0.06, 0.18, 1.0))
	gradient.set_color(1, Color(0.02, 0.02, 0.04, 1.0))
	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.fill_from = Vector2(0, 0)
	gradient_texture.fill_to = Vector2(0, 1)

	var background := TextureRect.new()
	background.texture = gradient_texture
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	barbarian_deco = TextureRect.new()
	barbarian_deco.texture = load("res://assets/barbarian.png")
	barbarian_deco.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	barbarian_deco.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	barbarian_deco.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	barbarian_deco.position = Vector2(-260, -220)
	barbarian_deco.size = Vector2(160, 160)
	barbarian_deco.modulate = Color(1, 1, 1, 0.9)
	add_child(barbarian_deco)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(column)

	var title_label := Label.new()
	title_label.text = "PIXEL QUEST"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 56)
	title_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	column.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.text = "A tiny pixel-art action RPG"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 16)
	subtitle_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	column.add_child(subtitle_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	column.add_child(spacer)

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

	upgrades_button = Button.new()
	upgrades_button.text = "Upgrades"
	upgrades_button.custom_minimum_size = Vector2(180, 44)
	upgrades_button.pressed.connect(_on_upgrades_pressed)
	_setup_hover_button(upgrades_button, "Spend Essence earned from past runs on permanent bonuses.")
	_style_skill_node_button(upgrades_button)
	main_menu_box.add_child(upgrades_button)

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

	upgrades_box = VBoxContainer.new()
	upgrades_box.add_theme_constant_override("separation", 10)
	upgrades_box.alignment = BoxContainer.ALIGNMENT_CENTER
	upgrades_box.visible = false
	column.add_child(upgrades_box)

	upgrades_header_label = Label.new()
	upgrades_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrades_header_label.add_theme_font_size_override("font_size", 18)
	upgrades_header_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	upgrades_box.add_child(upgrades_header_label)

	# A real tree: nodes positioned absolutely from SKILL_TREE_LAYOUT (a
	# Container can't express branching/converging lines), with thin rotated
	# ColorRects as connectors -- the same absolute-position-plus-drawn-line
	# technique HUD.gd's battle grid already uses for arbitrary node layout.
	# Both scroll directions are needed now (11 columns wide, 8 rows tall).
	var upgrades_scroll := ScrollContainer.new()
	upgrades_scroll.custom_minimum_size = Vector2(900, 480)
	upgrades_box.add_child(upgrades_scroll)

	var max_col := 0
	var max_row := 0
	for coord in SKILL_TREE_LAYOUT.values():
		max_col = max(max_col, coord.x)
		max_row = max(max_row, coord.y)

	var tree_area := Control.new()
	tree_area.custom_minimum_size = Vector2((max_col + 1) * SKILL_COL_W, (max_row + 1) * SKILL_ROW_H)
	upgrades_scroll.add_child(tree_area)

	# Connectors are added before the node buttons, so each button visually
	# draws over (and clips) the line ends beneath it -- reads as edge-to-
	# edge rather than center-to-center.
	for id in SaveDataScript.UPGRADE_IDS:
		for prereq in SaveDataScript.UPGRADES[id].get("prereqs", []):
			_draw_connector(tree_area, _skill_node_center(prereq.id), _skill_node_center(id))

	for id in SaveDataScript.UPGRADE_IDS:
		var def: Dictionary = SaveDataScript.UPGRADES[id]
		var button := Button.new()
		var node_center: Vector2 = _skill_node_center(id)
		button.position = node_center - Vector2(SKILL_NODE_W, SKILL_NODE_H) / 2.0
		button.size = Vector2(SKILL_NODE_W, SKILL_NODE_H)
		button.pressed.connect(_on_buy_upgrade_pressed.bind(id))
		_setup_hover_button(button, def.description)
		_style_skill_node_button(button)
		tree_area.add_child(button)
		upgrade_buttons[id] = button

	var upgrades_back_button := Button.new()
	upgrades_back_button.text = "Back"
	upgrades_back_button.custom_minimum_size = Vector2(180, 40)
	upgrades_back_button.pressed.connect(_on_upgrades_back_pressed)
	_setup_hover_button(upgrades_back_button, "Return to the main menu.")
	_style_skill_node_button(upgrades_back_button)
	upgrades_box.add_child(upgrades_back_button)

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

	# barbarian_deco overlaps select_save_box/difficulty_box the same way it
	# overlaps the upgrades tree -- hidden whenever the main menu isn't the
	# visible screen.
	barbarian_deco.visible = false
	_refresh_select_save_display()
	slot_buttons[1].grab_focus()

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

func _skill_node_center(id: String) -> Vector2:
	var coord: Vector2i = SKILL_TREE_LAYOUT[id]
	return Vector2(coord.x * SKILL_COL_W, coord.y * SKILL_ROW_H) + Vector2(SKILL_NODE_W, SKILL_NODE_H) / 2.0

# A thin rotated ColorRect between two node centers -- branch, converge, and
# split edges all render the same way, just a line segment between two
# points. Added as a child of `parent` before any node buttons are (see the
# call site in _ready()), so buttons drawn afterward clip the line ends
# beneath them.
func _draw_connector(parent: Control, from: Vector2, to: Vector2) -> void:
	var connector := ColorRect.new()
	connector.color = Color(0.55, 0.42, 0.18, 0.9)
	var diff := to - from
	connector.position = from
	connector.size = Vector2(diff.length(), 3)
	connector.rotation = diff.angle()
	connector.pivot_offset = Vector2(0, 1.5)
	parent.add_child(connector)

func _style_skill_node_button(button: Button) -> void:
	# Same bronze (0.62, 0.48, 0.2) HUD.gd's PANEL_BORDER/_style_standard_
	# button use, so the title screen and every in-game menu share one
	# border color instead of two near-but-not-quite-matching bronzes.
	button.add_theme_stylebox_override("normal", _make_node_stylebox(Color(0.13, 0.12, 0.16, 0.92), Color(0.62, 0.48, 0.2, 1.0)))
	button.add_theme_stylebox_override("hover", _make_node_stylebox(Color(0.22, 0.19, 0.1, 0.96), Color(1.0, 0.9, 0.2, 1.0)))
	button.add_theme_stylebox_override("pressed", _make_node_stylebox(Color(0.18, 0.15, 0.06, 0.96), Color(1.0, 0.9, 0.2, 1.0)))
	button.add_theme_stylebox_override("disabled", _make_node_stylebox(Color(0.08, 0.08, 0.09, 0.6), Color(0.25, 0.25, 0.25, 0.6)))
	button.add_theme_stylebox_override("focus", _make_node_stylebox(Color(0, 0, 0, 0), Color(1.0, 0.9, 0.2, 1.0)))

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
func _setup_hover_button(button: Button, description: String) -> void:
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.2))
	button.add_theme_color_override("font_focus_color", Color(1.0, 0.9, 0.2))
	button.set_meta("description", description)
	button.mouse_entered.connect(func(): description_label.text = button.get_meta("description", ""))
	button.mouse_exited.connect(func(): description_label.text = "")
	button.focus_entered.connect(func(): description_label.text = button.get_meta("description", ""))
	button.focus_exited.connect(func(): description_label.text = "")

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

func _on_upgrades_pressed() -> void:
	select_save_box.visible = false
	difficulty_box.visible = false
	main_menu_box.visible = false
	upgrades_box.visible = true
	stats_box.visible = false
	slot_action_box.visible = false
	copy_target_box.visible = false
	slot_options_box.visible = false
	# The tree is now much wider than the old 3-column layout and scrolls
	# into the corner where this decoration sits -- hidden while it's open
	# so it doesn't overlap real nodes/text.
	barbarian_deco.visible = false
	_refresh_upgrades_display()
	upgrade_buttons[SaveDataScript.UPGRADE_IDS[0]].grab_focus()

func _on_upgrades_back_pressed() -> void:
	upgrades_box.visible = false
	main_menu_box.visible = true
	barbarian_deco.visible = true
	play_button.grab_focus()

func _on_stats_pressed() -> void:
	select_save_box.visible = false
	difficulty_box.visible = false
	main_menu_box.visible = false
	upgrades_box.visible = false
	stats_box.visible = true
	slot_action_box.visible = false
	copy_target_box.visible = false
	slot_options_box.visible = false
	barbarian_deco.visible = false
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
	upgrades_box.visible = false
	stats_box.visible = false
	slot_action_box.visible = false
	copy_target_box.visible = false
	slot_options_box.visible = false
	barbarian_deco.visible = false
	_refresh_select_save_display()
	slot_buttons[1].grab_focus()

func _show_main_menu() -> void:
	select_save_box.visible = false
	difficulty_box.visible = false
	main_menu_box.visible = true
	upgrades_box.visible = false
	stats_box.visible = false
	slot_action_box.visible = false
	copy_target_box.visible = false
	slot_options_box.visible = false
	barbarian_deco.visible = true
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

func _on_buy_upgrade_pressed(id: String) -> void:
	if SaveDataScript.try_buy_upgrade(save_data, id):
		SaveDataScript.save_data(save_data)
		_refresh_upgrades_display()

func _refresh_upgrades_display() -> void:
	var essence: int = save_data.get("essence", 0)
	upgrades_header_label.text = "Essence: %d" % essence
	var owned: Dictionary = save_data.get("upgrades", {})
	for id in SaveDataScript.UPGRADE_IDS:
		var def: Dictionary = SaveDataScript.UPGRADES[id]
		var level: int = owned.get(id, 0)
		var max_level: int = def.get("max_level", 999999)
		var button: Button = upgrade_buttons[id]
		if level >= max_level:
			button.text = "%s\n[Mastered]" % def.name
			button.disabled = true
		elif not SaveDataScript.is_upgrade_unlocked(save_data, id):
			button.text = "%s\n[Locked]" % def.name
			button.disabled = true
		else:
			var cost: int = SaveDataScript.get_upgrade_cost(id, level)
			button.text = "%s Lv.%d\n%d Essence" % [def.name, level, cost]
			button.disabled = essence < cost
