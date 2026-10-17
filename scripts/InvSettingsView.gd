extends Control
class_name InvSettingsView

# The Settings tab, a real page of the inventory now (it used to hand you over to the pause menu's own screen): Audio (the three
# volumes), Controls (press a key's button, then the new key; Esc cancels) and Gameplay (the four comfort toggles). It reads and writes
# the same Settings autoload the pause menu's screen does, so the two always agree.

var panel = null
var settings: Node = null
var page := "Audio"
var rebinding := ""
var _rebind_buttons: Dictionary = {}
var _body: VBoxContainer = null

func setup(p_panel) -> void:
	panel = p_panel
	settings = get_node_or_null("/root/Settings")
	page = panel.settings_page
	rebuild()

func rebuild() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_rebind_buttons.clear()
	if settings == null:
		add_child(PixelKit.label("Settings aren't available here.", "body", PixelKit.DIM))
		return
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 0)
	add_child(tabs)
	var icons := {"Audio": "sub_audio", "Controls": "sub_controls", "Gameplay": "sub_gameplay"}
	for p in ["Audio", "Controls", "Gameplay"]:
		tabs.add_child(PixelButton.make(p, icons[p], _on_page.bind(p), p == page))
	var frame := PixelKit.panel("panel_steel", 8, 4)
	frame.position = Vector2(0, 56)
	frame.size = Vector2(minf(size.x, 900.0), size.y - 56.0)
	frame.custom_minimum_size = frame.size
	add_child(frame)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	PixelKit.style_scroll(scroll)
	frame.add_child(scroll)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 0)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)
	match page:
		"Audio":
			_audio()
		"Controls":
			_controls()
		"Gameplay":
			_gameplay()

func _on_page(p: String) -> void:
	_cancel_rebind()
	page = p
	panel.settings_page = p
	rebuild()

func _row(label: String) -> HBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.custom_minimum_size = Vector2(0, 56)
	box.add_child(row)
	var l := PixelKit.label(label)
	l.custom_minimum_size = Vector2(250, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	box.add_child(PixelKit.rule())
	_body.add_child(box)
	return row

func _audio() -> void:
	for spec in [["Master volume", "master_volume", "set_master_volume"], ["Effects", "sfx_volume", "set_sfx_volume"], ["Music", "music_volume", "set_music_volume"]]:
		var row := _row(str(spec[0]))
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = float(settings.get(str(spec[1])))
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		PixelKit.style_slider(slider)
		row.add_child(slider)
		var value := PixelKit.label("%d%%" % roundi(slider.value * 100.0), "body", PixelKit.GOLD3)
		value.custom_minimum_size = Vector2(70, 0)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
		var setter := str(spec[2])
		slider.value_changed.connect(func(v):
			settings.call(setter, v)
			value.text = "%d%%" % roundi(v * 100.0)
		)

func _gameplay() -> void:
	for spec in [["Screen shake", "screen_shake_enabled", "set_screen_shake_enabled"], ["Damage numbers", "damage_numbers_enabled", "set_damage_numbers_enabled"],
			["Dodge and block popups", "combat_minigames_enabled", "set_combat_minigames_enabled"], ["Attack timing popup", "attack_minigame_enabled", "set_attack_minigame_enabled"]]:
		var row := _row(str(spec[0]))
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)
		var on: bool = bool(settings.get(str(spec[1])))
		var setter := str(spec[2])
		var toggle := PixelButton.make("On" if on else "Off", "", Callable(), on)
		toggle.custom_minimum_size = Vector2(96, 0)
		toggle.pressed.connect(func():
			var now: bool = not bool(settings.get(str(spec[1])))
			settings.call(setter, now)
			toggle.text = "On" if now else "Off"
			toggle.on = now
		)
		row.add_child(toggle)

func _controls() -> void:
	for action in settings.ACTION_ORDER:
		var row := _row(str(settings.ACTION_LABELS.get(action, action)))
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)
		var key_button := PixelButton.make(str(settings.key_name(action)), "", Callable(), false)
		key_button.custom_minimum_size = Vector2(190, 0)
		key_button.pressed.connect(func():
			_cancel_rebind()
			rebinding = action
			key_button.text = "Press a key..."
			key_button.on = true
		)
		row.add_child(key_button)
		_rebind_buttons[action] = key_button
	_body.add_child(InvWidgets.paragraph("Press a key's button, then the new key. Esc cancels."))

func _cancel_rebind() -> void:
	if rebinding != "" and _rebind_buttons.has(rebinding):
		var b: PixelButton = _rebind_buttons[rebinding]
		b.text = str(settings.key_name(rebinding))
		b.on = false
	rebinding = ""

# The panel hands every key press here while a rebind is waiting; true if it took it.
func handle_key(event: InputEventKey) -> bool:
	if rebinding == "":
		return false
	if event.keycode == KEY_ESCAPE:
		_cancel_rebind()
		return true
	settings.rebind(rebinding, event.keycode)
	rebinding = ""
	rebuild()
	return true
