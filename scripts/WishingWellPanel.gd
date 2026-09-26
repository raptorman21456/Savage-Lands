extends TownPanel
class_name WishingWellPanel

# The town Wishing Well (one of the two gambling venues): toss coins in and
# something happens -- see WishingWell.gd for the odds. The wager is spent up
# front; whatever comes up is applied at once. Winnings paid in coins bypass
# the coin-bonus percentage (Player.add_coins_flat) so the odds are what they
# look like.

const WishingWellScript := preload("res://scripts/WishingWell.gd")
const TalismansScript := preload("res://scripts/Talismans.gd")

# What "A Gift" can be.
const GIFT_POTIONS := ["potion_health", "potion_attack", "potion_resilience", "potion_energy", "potion_stamina"]
const SURGE_STATS := ["strength", "vigor", "agility"]

var wager: int = WishingWellScript.WAGERS[0]
var wager_buttons := {}
var coins_label: Label
var result_label: Label
var throw_button: Button
var last_outcome := ""
# Tests seed this to make the draw deterministic; null = a fresh random draw.
var rng: RandomNumberGenerator = null

func _panel_title() -> String:
	return "THE WISHING WELL"

func _window_size() -> Vector2:
	return Vector2(580, 440)

func _build_content(outer: VBoxContainer) -> void:
	outer.add_child(_make_label("\"Toss in a coin and make a wish. The well is old, and not always kind.\"", 14, Color(0.8, 0.8, 0.75)))
	coins_label = _make_label("", 15, Color(1.0, 0.85, 0.3))
	outer.add_child(coins_label)
	outer.add_child(_make_label("A bigger offering tilts the odds a little in your favour -- and makes the good things bigger.", 12, Color(0.65, 0.75, 0.9)))

	var wager_row := HBoxContainer.new()
	wager_row.add_theme_constant_override("separation", 8)
	outer.add_child(wager_row)
	for amount in WishingWellScript.WAGERS:
		var button := Button.new()
		button.text = "%d coins" % amount
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(110, 34)
		button.pressed.connect(_on_wager_pressed.bind(amount))
		wager_row.add_child(button)
		wager_buttons[amount] = button

	throw_button = Button.new()
	throw_button.text = "Toss the coins in"
	throw_button.custom_minimum_size = Vector2(0, 42)
	throw_button.pressed.connect(_on_throw_pressed)
	outer.add_child(throw_button)

	result_label = _make_label("", 16, Color(0.95, 0.95, 0.85))
	result_label.custom_minimum_size = Vector2(0, 90)
	outer.add_child(result_label)

func _on_opened() -> void:
	result_label.text = ""
	last_outcome = ""

func _refresh() -> void:
	if _player == null or coins_label == null:
		return
	coins_label.text = "Coins: %d" % _player.coins
	for amount in wager_buttons:
		wager_buttons[amount].button_pressed = amount == wager
		wager_buttons[amount].disabled = _player.coins < amount
	throw_button.disabled = _player.coins < wager
	throw_button.text = "Toss in %d coins" % wager

func set_wager(amount: int) -> void:
	if WishingWellScript.WAGERS.has(amount):
		wager = amount
	_refresh()

func _on_wager_pressed(amount: int) -> void:
	set_wager(amount)

func _on_throw_pressed() -> void:
	throw()

# Spends the wager and applies one outcome. Returns the outcome id, or "" if
# the wager couldn't be paid. `forced` skips the draw (tests only).
func throw(forced: String = "") -> String:
	if _player == null or not _player.try_spend_coins(wager):
		_play_sfx("error")
		return ""
	_play_sfx("coin")
	var luck: float = _player.talisman_bonus("gambling_luck")
	var id: String = forced if forced != "" else WishingWellScript.roll(wager, luck, rng)
	last_outcome = id
	var text: String = _apply_outcome(id)
	var label: String = WishingWellScript.OUTCOMES[id].label
	result_label.text = "%s\n%s" % [label.to_upper(), text]
	_refresh()
	return id

func _apply_outcome(id: String) -> String:
	var main := get_parent()
	match id:
		"blessing":
			var pct: float = WishingWellScript.blessing_pct(wager)
			_player.temp_damage_bonus_pct = pct
			main.shrine_effect_waves_remaining = WishingWellScript.EFFECT_WAVES
			_play_sfx("buff")
			return "Warmth floods your arms. +%d%% damage for %d waves." % [int(round(pct * 100)), WishingWellScript.EFFECT_WAVES]
		"curse":
			var pct: float = WishingWellScript.curse_pct()
			_player.temp_damage_bonus_pct = -pct
			main.shrine_effect_waves_remaining = WishingWellScript.EFFECT_WAVES
			_play_sfx("error")
			return "A cold hand closes over yours. -%d%% damage for %d waves." % [int(round(pct * 100)), WishingWellScript.EFFECT_WAVES]
		"refund":
			var amount: int = WishingWellScript.refund_amount(wager)
			_player.add_coins_flat(amount)
			_play_sfx("coin")
			return "The well spits your coins back -- doubled. +%d coins." % amount
		"jackpot":
			var amount: int = WishingWellScript.jackpot_amount(wager)
			_player.add_coins_flat(amount)
			_play_sfx("level_up")
			return "A geyser of gold! +%d coins." % amount
		"healing":
			_player.heal(_player.max_health)
			_player.reset_stamina()
			_play_sfx("heal")
			return "The water glows. You are fully restored."
		"potion":
			var potion_id: String = GIFT_POTIONS[randi() % GIFT_POTIONS.size()]
			_player.add_potion(potion_id)
			_play_sfx("item")
			var potion: Dictionary = _player.get_consumable(potion_id)
			return "Something bobs to the surface: a %s." % potion.get("name", "potion")
		"stat":
			var stat_name: String = SURGE_STATS[randi() % SURGE_STATS.size()]
			_player.apply_bonus_stat(stat_name)
			_play_sfx("level_up")
			return "Power surges through you. +%s for the rest of the run." % stat_name.capitalize()
		"wish":
			return _grant_wish()
		"purse":
			var taken: int = mini(_player.coins, wager)
			_player.try_spend_coins(taken)
			_play_sfx("error")
			return "A tug at your belt -- the well takes %d more." % taken
	_play_sfx("error")
	return "The coins sink into the dark. Nothing happens."

# A talisman you don't own yet, worn if a slot is free; if you somehow own the
# whole catalog, coins instead.
func _grant_wish() -> String:
	var pick: Array = TalismansScript.roll_stock(1, _player.owned_talismans, rng)
	if pick.is_empty():
		var amount: int = WishingWellScript.jackpot_amount(wager) / 2
		_player.add_coins_flat(amount)
		return "You wish for a charm -- but you own them all. +%d coins instead." % amount
	var talisman: Dictionary = TalismansScript.get_talisman(pick[0])
	_player.owned_talismans[pick[0]] = true
	var worn := false
	if _player.equipped_talismans.size() < _player.talisman_slots():
		worn = _player.equip_talisman(pick[0])
	_play_sfx("level_up")
	return "Your wish is granted: the %s.%s" % [talisman.name, " You put it on." if worn else " (Wear it from your Inventory.)"]
