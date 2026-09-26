extends CanvasLayer
class_name HealerPanel

# The town's Inn/Healer building (see Main.gd:_build_town) -- same shared
# overlay shape as InventoryPanel.gd/BeastiaryPanel.gd (CanvasLayer, built
# entirely in code, _was_paused snapshot/restore on open/close).

const REST_COST := 20

var _was_paused := false
var _player: Player = null
var hp_label: Label
var stamina_label: Label
var rest_button: Button

func _ready() -> void:
	layer = 30
	visible = false
	_build()

func _build() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.75)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)

	var window_size := Vector2(420, 280)
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
	title.text = "THE RESTING INN"
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
	flavor.text = "The innkeeper waves you toward a warm bed and a hot meal."
	flavor.autowrap_mode = TextServer.AUTOWRAP_WORD
	flavor.add_theme_font_size_override("font_size", 14)
	flavor.add_theme_color_override("font_color", Color(0.8, 0.8, 0.75))
	outer.add_child(flavor)

	hp_label = Label.new()
	hp_label.add_theme_font_size_override("font_size", 16)
	hp_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8))
	outer.add_child(hp_label)

	stamina_label = Label.new()
	stamina_label.add_theme_font_size_override("font_size", 16)
	stamina_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8))
	outer.add_child(stamina_label)

	rest_button = Button.new()
	rest_button.custom_minimum_size = Vector2(0, 40)
	rest_button.pressed.connect(_on_rest_pressed)
	outer.add_child(rest_button)

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
	if _player == null:
		return
	hp_label.text = "HP: %d / %d" % [_player.health, _player.max_health]
	stamina_label.text = "Stamina: %d / %d" % [_player.stamina, _player.max_stamina]
	var already_full: bool = _player.health >= _player.max_health and _player.stamina >= _player.max_stamina
	if already_full:
		rest_button.text = "Already well-rested"
		rest_button.disabled = true
	else:
		rest_button.text = "Rest -- %d coins (full HP & stamina)" % REST_COST
		rest_button.disabled = _player.coins < REST_COST

func _on_rest_pressed() -> void:
	if _player == null or not _player.try_spend_coins(REST_COST):
		_play_sfx("error")
		return
	_player.restore_health(_player.max_health)
	_player.reset_stamina()
	_play_sfx("heal")
	_refresh()

func _play_sfx(sfx_name: String) -> void:
	var parent := get_parent()
	if parent != null and parent.has_method("play_sfx"):
		parent.play_sfx(sfx_name)
