extends Node

# Autoloaded as "Settings" -- readable from Player.gd/Main.gd/HUD.gd alike
# without threading a reference through all three. Registered in
# project.godot under [autoload].

const SaveDataScript := preload("res://scripts/SaveData.gd")

# Only these 11 actions are rebindable -- shop quick-buy numbers, Enter, and R
# (reroll/retry) stay hardcoded, since they're positional/mnemonic
# conventions that don't gain anything from rebinding.
const DEFAULT_KEYBINDS := {
	"move_up": KEY_UP, "move_down": KEY_DOWN, "move_left": KEY_LEFT, "move_right": KEY_RIGHT,
	"attack_up": KEY_W, "attack_down": KEY_S, "attack_left": KEY_A, "attack_right": KEY_D,
	"confirm": KEY_Z, "cancel": KEY_X, "pause": KEY_C,
}
const ACTION_ORDER := [
	"move_up", "move_down", "move_left", "move_right",
	"attack_up", "attack_down", "attack_left", "attack_right",
	"confirm", "cancel", "pause",
]
const ACTION_LABELS := {
	"move_up": "Move Up", "move_down": "Move Down", "move_left": "Move Left", "move_right": "Move Right",
	"attack_up": "Attack Up", "attack_down": "Attack Down", "attack_left": "Attack Left", "attack_right": "Attack Right",
	"confirm": "Confirm", "cancel": "Cancel / Back", "pause": "Pause Menu",
}

const MIN_VOLUME_DB := -40.0

var keybinds := {}
var master_volume := 1.0
var sfx_volume := 1.0
var music_volume := 1.0
# Accessibility/comfort toggles -- gate Main.gd's own _shake_camera/
# _shake_battle and spawn_damage_number_world/_spawn_battle_damage_number
# at the source rather than at each call site, so every existing juice
# call automatically respects them without threading a check through all of
# it.
var screen_shake_enabled := true
var damage_numbers_enabled := true

func _ready() -> void:
	_ensure_audio_buses()
	_load()

func is_action_pressed(action: String) -> bool:
	return Input.is_key_pressed(get_key(action))

func get_key(action: String) -> int:
	return keybinds.get(action, DEFAULT_KEYBINDS.get(action, KEY_NONE))

func key_name(action: String) -> String:
	return OS.get_keycode_string(get_key(action))

func rebind(action: String, keycode: int) -> void:
	if not DEFAULT_KEYBINDS.has(action):
		return
	# Two actions sharing a key isn't just confusing -- confirm and cancel
	# on the same key makes battle-move confirmation permanently self-
	# cancelling, since both fire on the very same press. Reject the
	# collision outright rather than silently letting the old owner go
	# unbound.
	for other_action in DEFAULT_KEYBINDS:
		if other_action != action and get_key(other_action) == keycode:
			return
	keybinds[action] = keycode
	_save()

func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	_apply_bus_volume("Master", master_volume)
	_save()

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_bus_volume("SFX", sfx_volume)
	_save()

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_bus_volume("Music", music_volume)
	_save()

func set_screen_shake_enabled(v: bool) -> void:
	screen_shake_enabled = v
	_save()

func set_damage_numbers_enabled(v: bool) -> void:
	damage_numbers_enabled = v
	_save()

func _apply_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	# linear_to_db(0.0) is -inf, which reads as "fully muted" rather than a
	# real dB value further down the chain -- clamp the floor instead.
	var db: float = MIN_VOLUME_DB if linear <= 0.0 else linear_to_db(linear)
	AudioServer.set_bus_volume_db(idx, db)

func _ensure_audio_buses() -> void:
	for bus_name in ["SFX", "Music"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")

func _load() -> void:
	var saved: Dictionary = SaveDataScript.load_settings()
	keybinds = DEFAULT_KEYBINDS.duplicate()
	for action in saved.get("keybinds", {}):
		if DEFAULT_KEYBINDS.has(action):
			keybinds[action] = saved.keybinds[action]
	master_volume = saved.get("master_volume", 1.0)
	sfx_volume = saved.get("sfx_volume", 1.0)
	music_volume = saved.get("music_volume", 1.0)
	screen_shake_enabled = saved.get("screen_shake_enabled", true)
	damage_numbers_enabled = saved.get("damage_numbers_enabled", true)
	_apply_bus_volume("Master", master_volume)
	_apply_bus_volume("SFX", sfx_volume)
	_apply_bus_volume("Music", music_volume)

# Settings are a device/player preference, independent of which of the 3
# save slots is active -- their own file (SaveData.gd:load_settings/
# save_settings), not nested inside a slot's progress data, so switching
# saves never resets a keybind or volume level.
func _save() -> void:
	SaveDataScript.save_settings({
		"keybinds": keybinds,
		"master_volume": master_volume,
		"sfx_volume": sfx_volume,
		"music_volume": music_volume,
		"screen_shake_enabled": screen_shake_enabled,
		"damage_numbers_enabled": damage_numbers_enabled,
	})
