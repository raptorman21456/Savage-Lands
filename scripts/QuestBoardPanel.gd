extends CanvasLayer
class_name QuestBoardPanel

# Town's Quest Board (see Main.gd:_build_town/_place_quest_board) -- same
# shared overlay shape as HealerPanel.gd/InventoryPanel.gd (CanvasLayer,
# built in code, _was_paused snapshot/restore on open/close). The 3 quest
# slots themselves live on Main.gd (quest_slots) since they're per-run town
# state, not player state -- this panel is a thin view that reads/mutates
# them via get_parent() (Main), the same convention HealerPanel already
# uses for play_sfx().

var _was_paused := false
var _player: Player = null
var slot_container: VBoxContainer

func _ready() -> void:
	layer = 30
	visible = false
	_build()

func _build() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.75)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)

	var window_size := Vector2(620, 520)
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
	outer.add_theme_constant_override("separation", 14)
	margin.add_child(outer)

	var title_row := HBoxContainer.new()
	outer.add_child(title_row)
	var title := Label.new()
	title.text = "QUEST BOARD"
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

	var flavor := Label.new()
	flavor.text = "A handful of jobs pinned up for anyone willing."
	flavor.add_theme_font_size_override("font_size", 14)
	flavor.add_theme_color_override("font_color", Color(0.8, 0.8, 0.75))
	outer.add_child(flavor)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	slot_container = VBoxContainer.new()
	slot_container.add_theme_constant_override("separation", 12)
	slot_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(slot_container)

func open(player_ref: Player) -> void:
	_player = player_ref
	_was_paused = get_tree().paused
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_refresh()
	visible = true

func close() -> void:
	visible = false
	get_tree().paused = _was_paused

func _refresh() -> void:
	for c in slot_container.get_children():
		c.queue_free()
	var main := get_parent()
	for i in main.quest_slots.size():
		slot_container.add_child(_build_quest_card(main, i))

func _build_quest_card(main: Node, index: int) -> Control:
	var slot: Dictionary = main.quest_slots[index]
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.12, 0.15, 0.92)
	style.border_color = Color(0.4, 0.4, 0.45)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_col)

	var title_label := Label.new()
	title_label.text = slot.title
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	text_col.add_child(title_label)

	var flavor_label := Label.new()
	flavor_label.text = slot.flavor
	flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	flavor_label.add_theme_font_size_override("font_size", 13)
	flavor_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8))
	text_col.add_child(flavor_label)

	var reward_bits := []
	if slot.reward_coins > 0:
		reward_bits.append("%d coins" % slot.reward_coins)
	if slot.reward_shards > 0:
		reward_bits.append("%d shards" % slot.reward_shards)
	var reward_label := Label.new()
	reward_label.text = "Reward: %s" % " + ".join(reward_bits)
	reward_label.add_theme_font_size_override("font_size", 12)
	reward_label.add_theme_color_override("font_color", Color(0.6, 0.85, 0.6))
	text_col.add_child(reward_label)

	if slot.accepted:
		var progress: int = main._quest_progress(slot)
		var progress_label := Label.new()
		progress_label.text = "Progress: %d / %d" % [mini(progress, slot.target_amount), slot.target_amount]
		progress_label.add_theme_font_size_override("font_size", 13)
		progress_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
		text_col.add_child(progress_label)

	var action_button := Button.new()
	action_button.custom_minimum_size = Vector2(110, 36)
	if not slot.accepted:
		action_button.text = "Accept"
		action_button.pressed.connect(func():
			main.accept_quest(index)
			_refresh()
		)
	elif main.is_quest_complete(index):
		action_button.text = "Claim"
		action_button.pressed.connect(func():
			main.claim_quest(index)
			_refresh()
		)
	else:
		action_button.text = "In Progress"
		action_button.disabled = true
	row.add_child(action_button)

	return card
