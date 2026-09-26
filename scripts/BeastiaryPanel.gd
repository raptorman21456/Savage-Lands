extends CanvasLayer
class_name BeastiaryPanel

# A shared, self-contained overlay -- both TitleScreen.gd and Main.gd
# instantiate their own copy of this exact script on their respective
# "Beastiary" buttons, rather than duplicating the UI-building code in two
# places. Built entirely from code in _ready(), matching how every other
# screen in this project is constructed (no .tscn). Read-only: browses
# SaveData.gd's device-wide beastiary_seen collection, never writes to it --
# Main.gd's click/defeat hooks (_on_enemy_target_selected/_on_enemy_died)
# own that.
#
# "Stats" shown here are a qualitative trait summary pulled straight from
# Main.ENEMY_TRAITS, not fixed HP/damage numbers -- those scale with wave/
# might progression, so there's no single stat block per creature to print.

const MainScript := preload("res://scripts/Main.gd")
const HUDScript := preload("res://scripts/HUD.gd")
const SaveDataScript := preload("res://scripts/SaveData.gd")
const BeastiaryScript := preload("res://scripts/Beastiary.gd")

var list_box: VBoxContainer
var detail_icon: TextureRect
var detail_name: Label
var detail_traits: Label
var detail_description: Label
var _was_paused := false

func _ready() -> void:
	layer = 30
	visible = false
	_build()

func _build() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.75)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)

	var window_size := Vector2(760, 520)
	var window := Panel.new()
	window.size = window_size
	var window_style := StyleBoxFlat.new()
	window_style.bg_color = Color(0.08, 0.08, 0.1)
	window_style.border_color = Color(0.4, 0.4, 0.45)
	window_style.set_border_width_all(3)
	window.add_theme_stylebox_override("panel", window_style)
	scrim.add_child(window)
	window.position = ((get_viewport().get_visible_rect().size - window_size) / 2).round()

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 20)
	window.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	margin.add_child(outer)

	var title_row := HBoxContainer.new()
	outer.add_child(title_row)
	var title := Label.new()
	title.text = "BEASTIARY"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	title_row.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(spacer)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(close)
	title_row.add_child(close_button)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(hbox)

	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(260, 0)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hbox.add_child(list_scroll)
	list_box = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 4)
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(list_box)

	var detail_panel := VBoxContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_constant_override("separation", 10)
	hbox.add_child(detail_panel)

	detail_icon = TextureRect.new()
	detail_icon.custom_minimum_size = Vector2(96, 96)
	detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_panel.add_child(detail_icon)

	detail_name = Label.new()
	detail_name.add_theme_font_size_override("font_size", 22)
	detail_name.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	detail_panel.add_child(detail_name)

	detail_traits = Label.new()
	detail_traits.autowrap_mode = TextServer.AUTOWRAP_WORD
	detail_traits.add_theme_font_size_override("font_size", 14)
	detail_traits.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	detail_panel.add_child(detail_traits)

	detail_description = Label.new()
	detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD
	detail_description.add_theme_font_size_override("font_size", 15)
	detail_description.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8))
	detail_panel.add_child(detail_description)

# Pauses regardless of whatever's underneath (title screen, overworld,
# battle) and remembers the PRIOR pause state so closing restores it exactly
# -- opened from an already-paused pause menu, closing this returns to that
# paused menu rather than accidentally unpausing the whole game.
func open() -> void:
	_was_paused = get_tree().paused
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_refresh_list()
	visible = true

func close() -> void:
	visible = false
	get_tree().paused = _was_paused

func _refresh_list() -> void:
	for c in list_box.get_children():
		c.queue_free()
	var first_seen := ""
	for creature_name in HUDScript.ENEMY_ICONS:
		var seen: bool = SaveDataScript.is_creature_seen(creature_name)
		if seen and first_seen == "":
			first_seen = creature_name
		var button := Button.new()
		button.text = creature_name if seen else "???"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.disabled = not seen
		if seen:
			button.pressed.connect(_select.bind(creature_name))
		list_box.add_child(button)
	if first_seen != "":
		_select(first_seen)
	else:
		detail_icon.texture = null
		detail_name.text = ""
		detail_traits.text = ""
		detail_description.text = "Nothing encountered yet -- click or defeat an enemy in battle to log it here."

func _select(creature_name: String) -> void:
	detail_icon.texture = HUDScript.ENEMY_ICONS.get(creature_name, null)
	detail_name.text = creature_name
	detail_description.text = BeastiaryScript.get_description(creature_name)
	var traits: Dictionary = MainScript.ENEMY_TRAITS.get(creature_name, {})
	var tags := []
	if traits.get("is_boss_tier", false):
		tags.append("Boss-tier")
	if traits.get("armored", false):
		tags.append("Armored")
	if traits.get("dodge_chance", 0.0) > 0.0:
		tags.append("Evasive")
	if traits.get("knockback_resist", 0.0) > 0.0:
		tags.append("Braced against knockback")
	if traits.get("big_squad", false):
		tags.append("Travels in packs")
	if traits.get("heals_allies", false):
		tags.append("Heals allies")
	if traits.get("sweeps", false):
		tags.append("Wide sweeping attack")
	detail_traits.text = ", ".join(tags) if not tags.is_empty() else "No notable traits."
