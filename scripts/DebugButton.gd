extends PixelButton

# A PixelButton the keyboard can reach. The arrow keys move between these through Godot's own focus navigation (the menu draws a gold
# outline round whatever has focus), and Enter / Space / Z presses the focused one (a click does as ever). Built through DebugKit.button().

func _init() -> void:
	focus_mode = Control.FOCUS_ALL

func _gui_input(event: InputEvent) -> void:
	if not disabled and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE or event.keycode == KEY_Z:
			pressed.emit()
			accept_event()
			return
	super._gui_input(event)
