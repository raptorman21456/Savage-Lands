extends InvCard

# An inventory card the keyboard can use in the Debug menu's grids: arrow keys move between cards (focusing one chooses it, so the
# detail beside the grid follows), Enter / Space / Z uses it (a double-click does the same).
# Focus the menu itself puts back after a rebuild (DebugKit.restore) is "quiet": it must not change what is chosen.

func _init() -> void:
	focus_mode = Control.FOCUS_ALL

func _ready() -> void:
	focus_entered.connect(func():
		if bool(get_meta("quiet_focus", false)):
			set_meta("quiet_focus", false)
			return
		pressed.emit())

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE or event.keycode == KEY_Z:
			double_pressed.emit()
			accept_event()
			return
	super._gui_input(event)
