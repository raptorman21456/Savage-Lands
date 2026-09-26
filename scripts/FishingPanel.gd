extends TownPanel
class_name FishingPanel

# The Fishing Hole: pay bait, cast, wait for a bite, hook it in time, then reel
# without running out of progress or snapping the line. The rules (sizes,
# timing, reel numbers, loot) live in FishingHole.gd; this panel is the state
# machine plus a simple top-down Control view of the pond.
#
# States: "idle" -> "waiting" (line's in, waiting for a bite) -> "biting" (a
# fish is nibbling, hook it now) -> "reeling" (hold to reel, tension bar) ->
# back to "idle" with a result message. Space/Z is the one action button,
# meaning changes with the state (Cast / Hook! / hold to Reel).

const FishingHoleScript := preload("res://scripts/FishingHole.gd")
const FoodsScript := preload("res://scripts/Foods.gd")
const PotionsScript := preload("res://scripts/Potions.gd")
const TalismansScript := preload("res://scripts/Talismans.gd")

# Real-world seconds per simulation tick -- ties FishingHole's tick-based
# numbers to actual time without hardcoding seconds into the rules module.
const TICK_SECONDS := 1.0 / 12.0

var state := "idle"
var current_size := ""
var wait_ticks_left := 0
var bite_ticks_left := 0
var progress := 0.0
var tension := 0.0
var holding_reel := false
var _tick_accum := 0.0
# Tests seed this; null = random.
var rng: RandomNumberGenerator = null

# Meters are ColorRect bg/fill pairs, not a stock ProgressBar -- matching the
# HUD's own HP/stamina bars (HUD.gd:health_bar_bg/fill), and avoiding a stock
# Control whose default theme can render at an unreadable sliver of a height.
# A fixed width rather than one read back from the container's own layout,
# since that layout isn't guaranteed settled the instant _refresh() first runs.
const BAR_WIDTH := 500.0
const BAR_HEIGHT := 16.0

var coins_label: Label
var speech_label: Label
var pond_view: Control
var action_button: Button
var progress_bg: ColorRect
var progress_fill: ColorRect
var tension_bg: ColorRect
var tension_fill: ColorRect
var bar_box: VBoxContainer

func _panel_title() -> String:
	return "THE FISHING HOLE"

func _window_size() -> Vector2:
	return Vector2(560, 520)

func _build_content(outer: VBoxContainer) -> void:
	speech_label = _make_label("\"Bait's cheap, patience isn't. Cast a line and see what bites.\"", 14, Color(0.8, 0.8, 0.75))
	outer.add_child(speech_label)
	coins_label = _make_label("", 15, Color(1.0, 0.85, 0.3))
	outer.add_child(coins_label)

	pond_view = Control.new()
	pond_view.custom_minimum_size = Vector2(0, 220)
	pond_view.draw.connect(_on_pond_draw)
	outer.add_child(pond_view)

	bar_box = VBoxContainer.new()
	bar_box.add_theme_constant_override("separation", 4)
	bar_box.visible = false
	outer.add_child(bar_box)
	bar_box.add_child(_make_label("Progress", 11, Color(0.6, 0.9, 0.6)))
	progress_bg = _make_bar_bg()
	bar_box.add_child(progress_bg)
	progress_fill = _make_bar_fill(Color(0.35, 0.85, 0.4))
	progress_bg.add_child(progress_fill)
	bar_box.add_child(_make_label("Line tension", 11, Color(0.9, 0.6, 0.5)))
	tension_bg = _make_bar_bg()
	bar_box.add_child(tension_bg)
	tension_fill = _make_bar_fill(Color(0.85, 0.35, 0.3))
	tension_bg.add_child(tension_fill)

	action_button = Button.new()
	action_button.custom_minimum_size = Vector2(0, 44)
	action_button.button_down.connect(_on_action_down)
	action_button.button_up.connect(_on_action_up)
	outer.add_child(action_button)

func _make_bar_bg() -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0.15, 0.15, 0.16)
	bg.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	return bg

func _make_bar_fill(color: Color) -> ColorRect:
	var fill := ColorRect.new()
	fill.color = color
	fill.size = Vector2(0, BAR_HEIGHT)
	return fill

func _on_opened() -> void:
	_reset("idle")
	speech_label.text = "\"Bait's cheap, patience isn't. Cast a line and see what bites.\""

func can_close() -> bool:
	# Walking away mid-bite or mid-reel just loses the fish, same as any other
	# panel's Close -- nothing here is worth locking the door over.
	return true

func _on_closing() -> void:
	if state != "idle":
		_reset("idle")

func _reset(new_state: String) -> void:
	state = new_state
	current_size = ""
	wait_ticks_left = 0
	bite_ticks_left = 0
	progress = 0.0
	tension = 0.0
	holding_reel = false
	_tick_accum = 0.0

func _refresh() -> void:
	if _player == null or coins_label == null:
		return
	coins_label.text = "Coins: %d" % _player.coins
	bar_box.visible = state == "reeling"
	if state == "reeling":
		progress_fill.size = Vector2(BAR_WIDTH * progress, BAR_HEIGHT)
		tension_fill.size = Vector2(BAR_WIDTH * tension, BAR_HEIGHT)
	match state:
		"idle":
			action_button.text = "Cast (%d coins)" % FishingHoleScript.BAIT_COST
			action_button.disabled = _player.coins < FishingHoleScript.BAIT_COST
		"waiting":
			action_button.text = "Waiting..."
			action_button.disabled = true
		"biting":
			action_button.text = "HOOK IT!"
			action_button.disabled = false
		"reeling":
			action_button.text = "Hold to reel in"
			action_button.disabled = false
	pond_view.queue_redraw()

func _on_action_down() -> void:
	match state:
		"idle":
			cast()
		"biting":
			hook()
		"reeling":
			holding_reel = true

func _on_action_up() -> void:
	if state == "reeling":
		holding_reel = false

# --- The loop, as pure-ish state transitions (each also callable directly by
# tests, without going through the button). ---------------------------------

# Spends bait and starts the wait for a bite. False if it can't be afforded or
# a cast is already in progress.
func cast() -> bool:
	if state != "idle" or _player == null or not _player.try_spend_coins(FishingHoleScript.BAIT_COST):
		_play_sfx("error")
		return false
	var luck: float = _player.talisman_bonus("fishing_luck")
	current_size = FishingHoleScript.roll_size(luck, rng)
	wait_ticks_left = FishingHoleScript.bite_wait_ticks(current_size)
	state = "waiting"
	_play_sfx("coin")
	speech_label.text = "Line's in. Wait for a bite..."
	_refresh()
	return true

# Called by _process (and directly by tests) once per tick while waiting;
# starts the bite window once the wait runs out.
func _tick_waiting() -> void:
	wait_ticks_left -= 1
	if wait_ticks_left <= 0:
		state = "biting"
		bite_ticks_left = FishingHoleScript.bite_window_ticks(_player.talisman_bonus("fishing_luck"))
		speech_label.text = "Something's biting! Hook it!"
		_play_sfx("buff")
		_refresh()

# Ticks the open bite window down; the fish gets away if it closes unhooked.
func _tick_biting() -> void:
	bite_ticks_left -= 1
	if bite_ticks_left <= 0:
		speech_label.text = "It got away."
		_play_sfx("error")
		_reset("idle")
		_refresh()

# Attempts to set the hook while a bite is open. False if there's no bite to hook.
func hook() -> bool:
	if state != "biting":
		return false
	state = "reeling"
	progress = 0.0
	tension = 0.0
	speech_label.text = "Hooked! Hold to reel it in -- don't let the line snap."
	_play_sfx("hit")
	_refresh()
	return true

# One reel tick, driven by whatever holding_reel currently is. Resolves the
# catch or the snap when a threshold is crossed.
func _tick_reeling() -> void:
	var result: Dictionary = FishingHoleScript.step_reel(progress, tension, current_size, holding_reel, rng)
	progress = result.progress
	tension = result.tension
	if tension >= 1.0:
		speech_label.text = "The line snaps! It's gone."
		_play_sfx("error")
		_reset("idle")
	elif progress >= 1.0:
		_land_catch()
	_refresh()

func _land_catch() -> void:
	var loot: Dictionary = FishingHoleScript.loot_for_size(current_size, _player.owned_talismans, rng)
	match loot.kind:
		"coins":
			_player.add_coins_flat(loot.amount)
			speech_label.text = "Caught it! %s: +%d coins." % [loot.label, loot.amount]
		"food":
			_player.add_potion(loot.id)
			var food: Dictionary = FoodsScript.get_food(loot.id)
			speech_label.text = "Caught it! %s: a %s." % [loot.label, food.get("name", "fish")]
		"potion":
			_player.add_potion(loot.id)
			var potion: Dictionary = PotionsScript.get_tier(loot.id)
			speech_label.text = "Caught it! %s: a %s." % [loot.label, potion.get("name", "potion")]
		"talisman":
			_player.owned_talismans[loot.id] = true
			var worn := false
			if _player.equipped_talismans.size() < _player.talisman_slots():
				worn = _player.equip_talisman(loot.id)
			var talisman: Dictionary = TalismansScript.get_talisman(loot.id)
			speech_label.text = "Caught it! %s: the %s.%s" % [loot.label, talisman.name, " You put it on." if worn else " (Wear it from your Inventory.)"]
	_play_sfx("level_up" if current_size in ["large", "golden"] else "item")
	_reset("idle")

func _process(delta: float) -> void:
	if state == "idle":
		return
	_tick_accum += delta
	while _tick_accum >= TICK_SECONDS:
		_tick_accum -= TICK_SECONDS
		match state:
			"waiting":
				_tick_waiting()
			"biting":
				_tick_biting()
			"reeling":
				_tick_reeling()
		if state == "idle":
			break

# Advances the loop by `seconds` of simulated time in one go -- what tests use
# instead of many tiny _process(delta) calls.
func advance(seconds: float) -> void:
	_process(seconds)

# --- The pond view -----------------------------------------------------------

func _on_pond_draw() -> void:
	var size: Vector2 = pond_view.size
	pond_view.draw_rect(Rect2(Vector2.ZERO, size), Color(0.16, 0.32, 0.44))
	pond_view.draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.2, 0.3), false, 3.0)
	var center: Vector2 = size / 2.0
	match state:
		"idle":
			pond_view.draw_string(ThemeDB.fallback_font, center - Vector2(70, 0), "Cast a line to begin.", HORIZONTAL_ALIGNMENT_LEFT, 200, 14, Color(0.8, 0.9, 0.95))
		"waiting":
			pond_view.draw_line(center, center + Vector2(0, 60), Color(0.9, 0.9, 0.85), 2.0)
			pond_view.draw_circle(center + Vector2(0, 60), 5, Color(0.9, 0.3, 0.2))
		"biting":
			pond_view.draw_line(center, center + Vector2(0, 60), Color(0.9, 0.9, 0.85), 2.0)
			pond_view.draw_circle(center + Vector2(0, 60), 5, Color(0.9, 0.3, 0.2))
			pond_view.draw_string(ThemeDB.fallback_font, center + Vector2(-6, -20), "!", HORIZONTAL_ALIGNMENT_CENTER, 20, 32, Color(1.0, 0.9, 0.2))
		"reeling":
			pond_view.draw_string(ThemeDB.fallback_font, center - Vector2(80, 0), "It's fighting the line!", HORIZONTAL_ALIGNMENT_LEFT, 220, 16, Color(0.95, 0.85, 0.4))
