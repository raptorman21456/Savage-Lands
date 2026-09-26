extends TownPanel
class_name HorseRacePanel

# The Horse Racing Grounds (the second gambling venue): pick one of five horses
# from the posted odds, stake a wager, and watch a short animated race. The
# race itself is simulated up front (HorseRace.simulate) and the animation just
# plays it back, so the outcome is fixed the moment you place the bet -- the
# panel is only presentation. The wager is spent when the race starts; a win
# pays wager x odds through Player.add_coins_flat (no coin-bonus inflation).
# While a race runs, Close/Escape and every button are locked.

const HorseRaceScript := preload("res://scripts/HorseRace.gd")

const WAGERS := [10, 25, 50, 100]
const LANE_HEIGHT := 36.0
const TRACK_WIDTH := 500.0
const HORSE_ICON := "res://assets/horse.png"
# How long after the winner crosses the line the field keeps running, so the
# others visibly finish before the result appears.
const FINISH_LINGER := 1.2
# Simulations run per frame while the odds are being posted.
const ODDS_SLICE := 25

var field: Array = []
var odds: Array = []
var pick := -1
var wager: int = WAGERS[0]
var racing := false
var race: Dictionary = {}
var race_elapsed := 0.0
var _stake := 0
# The field, odds and pick as they stood when the race started -- _finish_race
# resolves against these, since the panel has already lined up the NEXT field by
# the time it reports the result.
var _race_field: Array = []
var _race_odds: Array = []
var _race_pick := -1
# Coins the last finished race paid out (0 on a loss); tests read it.
var last_winnings := 0
# The incremental odds job (see _new_field / _step_odds).
var _odds_pending := false
var _odds_done := 0
var _odds_wins: Array = []
# Tests seed this; null = random.
var rng: RandomNumberGenerator = null

var coins_label: Label
var result_label: Label
var go_button: Button
var horse_buttons: Array = []
var wager_buttons := {}
var lane_horses: Array = []
var lane_names: Array = []

func _panel_title() -> String:
	return "THE RACING GROUNDS"

func _window_size() -> Vector2:
	return Vector2(720, 620)

func _build_content(outer: VBoxContainer) -> void:
	outer.add_child(_make_label("\"Five entered, one wins. Pick your horse, place your bet, and let the hooves decide.\"", 14, Color(0.8, 0.8, 0.75)))
	coins_label = _make_label("", 15, Color(1.0, 0.85, 0.3))
	outer.add_child(coins_label)

	var horse_row := HBoxContainer.new()
	horse_row.add_theme_constant_override("separation", 6)
	outer.add_child(horse_row)
	for i in HorseRaceScript.HORSE_COUNT:
		var button := Button.new()
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(128, 56)
		button.pressed.connect(_on_horse_pressed.bind(i))
		horse_row.add_child(button)
		horse_buttons.append(button)

	var wager_row := HBoxContainer.new()
	wager_row.add_theme_constant_override("separation", 8)
	outer.add_child(wager_row)
	wager_row.add_child(_make_label("Wager:", 14))
	for amount in WAGERS:
		var button := Button.new()
		button.text = "%d" % amount
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(70, 32)
		button.pressed.connect(_on_wager_pressed.bind(amount))
		wager_row.add_child(button)
		wager_buttons[amount] = button
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wager_row.add_child(spacer)
	go_button = Button.new()
	go_button.custom_minimum_size = Vector2(190, 36)
	go_button.pressed.connect(_on_go_pressed)
	wager_row.add_child(go_button)

	# One lane per horse: dirt strip, name tag, horse, and a finish line.
	var lanes := VBoxContainer.new()
	lanes.add_theme_constant_override("separation", 4)
	outer.add_child(lanes)
	for i in HorseRaceScript.HORSE_COUNT:
		var lane := Control.new()
		lane.custom_minimum_size = Vector2(TRACK_WIDTH + 120, LANE_HEIGHT)
		lanes.add_child(lane)
		var dirt := ColorRect.new()
		dirt.color = Color(0.42, 0.32, 0.2) if i % 2 == 0 else Color(0.46, 0.35, 0.22)
		dirt.set_anchors_preset(Control.PRESET_FULL_RECT)
		lane.add_child(dirt)
		var finish_line := ColorRect.new()
		finish_line.color = Color(0.95, 0.95, 0.9)
		finish_line.position = Vector2(TRACK_WIDTH + 70, 0)
		finish_line.size = Vector2(4, LANE_HEIGHT)
		lane.add_child(finish_line)
		var name_tag := Label.new()
		name_tag.add_theme_font_size_override("font_size", 11)
		name_tag.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
		name_tag.position = Vector2(4, 8)
		lane.add_child(name_tag)
		lane_names.append(name_tag)
		var horse := TextureRect.new()
		horse.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		horse.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		horse.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		horse.size = Vector2(LANE_HEIGHT, LANE_HEIGHT)
		horse.position = Vector2(_horse_x(0.0), 0)
		if ResourceLoader.exists(HORSE_ICON):
			horse.texture = load(HORSE_ICON)
		lane.add_child(horse)
		lane_horses.append(horse)

	result_label = _make_label("", 15, Color(0.95, 0.95, 0.85))
	result_label.custom_minimum_size = Vector2(0, 50)
	outer.add_child(result_label)

func _horse_x(progress: float) -> float:
	return 90.0 + progress * (TRACK_WIDTH - 20.0)

func _on_opened() -> void:
	if field.is_empty():
		_new_field()
	_show_field_in_lanes()
	result_label.text = "Pick a horse and a wager."
	_refresh()

func can_close() -> bool:
	# No walking out on a race in progress.
	return not racing

# --- Field / odds ----------------------------------------------------------------

func _new_field() -> void:
	field = HorseRaceScript.make_field(rng)
	pick = -1
	# The posted odds come from simulating the field a few hundred times -- a
	# few hundred milliseconds of work, so it runs a slice per frame (see
	# _step_odds) rather than freezing the panel as it opens or a race ends.
	odds = []
	_odds_wins = []
	for i in field.size():
		_odds_wins.append(0)
	_odds_done = 0
	_odds_pending = true

# Runs up to `sims` more simulations toward the current field's odds; when the
# last one lands, the odds are posted. True once they're ready.
func _step_odds(sims: int) -> bool:
	if not _odds_pending:
		return true
	for i in mini(sims, HorseRaceScript.ODDS_SAMPLES - _odds_done):
		_odds_wins[HorseRaceScript.simulate(field, rng, false).order[0]] += 1
		_odds_done += 1
	if _odds_done >= HorseRaceScript.ODDS_SAMPLES:
		var probs: Array = []
		for w in _odds_wins:
			probs.append(float(w) / float(HorseRaceScript.ODDS_SAMPLES))
		odds = HorseRaceScript.odds_from_probs(probs)
		_odds_pending = false
		_refresh()
	return not _odds_pending

# Finishes posting the odds right now (tests, and anything that needs them
# immediately).
func finish_odds_now() -> void:
	while _odds_pending:
		_step_odds(HorseRaceScript.ODDS_SAMPLES)

# Puts the current field's names and colours on the lanes and every horse at
# the gate. Called when the panel opens and when a race starts -- NOT when a
# race ends, so the finished race stays on screen (with the results) until the
# next one begins.
func _show_field_in_lanes() -> void:
	for i in field.size():
		lane_names[i].text = field[i].name
		lane_horses[i].modulate = field[i].color
		lane_horses[i].position.x = _horse_x(0.0)

func _refresh() -> void:
	if _player == null or coins_label == null or field.is_empty():
		return
	coins_label.text = "Coins: %d" % _player.coins
	for i in horse_buttons.size():
		var button: Button = horse_buttons[i]
		if _odds_pending:
			button.text = "%s\n(posting odds...)" % field[i].name
		else:
			button.text = "%s\nx%.1f" % [field[i].name, odds[i]]
		button.button_pressed = i == pick
		button.disabled = racing
		button.add_theme_color_override("font_color", field[i].color)
	for amount in wager_buttons:
		wager_buttons[amount].button_pressed = amount == wager
		wager_buttons[amount].disabled = racing or _player.coins < amount
	go_button.text = "Bet %d and race!" % wager
	go_button.disabled = not can_place_bet()
	close_button.disabled = racing

func set_pick(index: int) -> void:
	if racing or index < 0 or index >= field.size():
		return
	pick = index
	_refresh()

func set_wager(amount: int) -> void:
	if racing or not WAGERS.has(amount):
		return
	wager = amount
	_refresh()

func can_place_bet() -> bool:
	return not racing and not _odds_pending and pick >= 0 and _player != null and _player.coins >= wager

func _on_horse_pressed(index: int) -> void:
	set_pick(index)

func _on_wager_pressed(amount: int) -> void:
	set_wager(amount)

func _on_go_pressed() -> void:
	start_race()

# --- Racing ------------------------------------------------------------------------

# Spends the wager and starts the (precomputed) race. False if a bet can't be
# placed (no pick, can't afford it, already racing).
func start_race() -> bool:
	if not can_place_bet():
		_play_sfx("error")
		return false
	if not _player.try_spend_coins(wager):
		return false
	_stake = wager
	_race_field = field
	_race_pick = pick
	_race_odds = odds
	_show_field_in_lanes()
	race = HorseRaceScript.simulate(field, rng)
	race_elapsed = 0.0
	racing = true
	result_label.text = "And they're off!"
	_play_sfx("coin")
	_refresh()
	return true

func _process(delta: float) -> void:
	if racing:
		advance(delta)
	elif _odds_pending and visible:
		_step_odds(ODDS_SLICE)

# Plays the race forward `delta` seconds (the panel's _process calls this every
# frame; tests call it with big values to finish a race at once).
func advance(delta: float) -> void:
	if not racing:
		return
	race_elapsed += delta
	var winner_tick: int = race.winner_tick
	var tick_f: float = race_elapsed / HorseRaceScript.RACE_SECONDS * float(winner_tick)
	for i in lane_horses.size():
		var trail: PackedFloat32Array = race.positions[i]
		var idx: int = clampi(int(tick_f), 0, trail.size() - 1)
		lane_horses[i].position.x = _horse_x(trail[idx])
	if race_elapsed >= HorseRaceScript.RACE_SECONDS + FINISH_LINGER:
		_finish_race()

func _finish_race() -> void:
	racing = false
	# Everyone ends where the simulation ended.
	for i in lane_horses.size():
		var trail: PackedFloat32Array = race.positions[i]
		lane_horses[i].position.x = _horse_x(trail[trail.size() - 1])
	var order: Array = race.order
	var winner: int = order[0]
	var luck: float = _player.talisman_bonus("gambling_luck")
	var text := "1st %s   2nd %s   3rd %s\n" % [_race_field[order[0]].name, _race_field[order[1]].name, _race_field[order[2]].name]
	last_winnings = 0
	if winner == _race_pick:
		last_winnings = HorseRaceScript.payout(_stake, _race_odds[_race_pick], luck)
		_player.add_coins_flat(last_winnings)
		text += "%s wins! You collect %d coins." % [_race_field[_race_pick].name, last_winnings]
		_play_sfx("level_up")
	else:
		text += "%s finished %s. Better luck next race." % [_race_field[_race_pick].name, _ordinal(order.find(_race_pick) + 1)]
		_play_sfx("error")
	result_label.text = text
	# A fresh field (and fresh odds) for the next race.
	_new_field()
	_refresh()

func _ordinal(n: int) -> String:
	match n:
		1: return "1st"
		2: return "2nd"
		3: return "3rd"
	return "%dth" % n
