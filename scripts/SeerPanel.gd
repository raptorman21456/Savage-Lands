extends TownPanel
class_name SeerPanel

# The town Seer: sells talismans (Talismans.gd) from a small rotating stock
# that Main re-rolls at every kill milestone (see Main.gd:seer_stock/
# _roll_seer_stock), with a paid reroll like the gear shop's. Buying puts the
# talisman in your collection and wears it if a slot is free; swapping what's
# equipped happens in the Inventory's Talismans tab.

const TalismansScript := preload("res://scripts/Talismans.gd")

var coins_label: Label
var slots_label: Label
var speech_label: Label
var stock_box: VBoxContainer
var reroll_button: Button

func _panel_title() -> String:
	return "THE SEER"

func _window_size() -> Vector2:
	return Vector2(700, 600)

func _build_content(outer: VBoxContainer) -> void:
	speech_label = _make_label("", 14, Color(0.8, 0.8, 0.75))
	outer.add_child(speech_label)
	coins_label = _make_label("", 15, Color(1.0, 0.85, 0.3))
	outer.add_child(coins_label)
	slots_label = _make_label("", 13, Color(0.7, 0.85, 1.0))
	outer.add_child(slots_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	stock_box = VBoxContainer.new()
	stock_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stock_box.add_theme_constant_override("separation", 6)
	scroll.add_child(stock_box)

	reroll_button = Button.new()
	reroll_button.custom_minimum_size = Vector2(0, 36)
	reroll_button.pressed.connect(_on_reroll_pressed)
	outer.add_child(reroll_button)

func _on_opened() -> void:
	speech_label.text = "\"The stars have set a few charms aside for you. Choose carefully -- they only work if you wear them.\""

func _refresh() -> void:
	if _player == null or stock_box == null:
		return
	var main := get_parent()
	coins_label.text = "Coins: %d" % _player.coins
	var slots: int = _player.talisman_slots()
	var next_slot_level: int = 0
	if slots < TalismansScript.SLOT_LEVELS.size() + 1:
		next_slot_level = TalismansScript.level_for_slot(slots + 1)
	slots_label.text = "Talisman slots: %d / %d worn.%s  (Equip and swap in your Inventory, I.)" % [
		_player.equipped_talismans.size(), slots,
		"" if next_slot_level == 0 else "  Next slot opens at level %d." % next_slot_level
	]
	_clear(stock_box)
	var stock: Array = main.seer_stock
	if stock.is_empty():
		stock_box.add_child(_make_label("Nothing left on the table. The stars will set out more soon.", 13, Color(0.7, 0.7, 0.65)))
	for id in stock:
		var talisman: Dictionary = TalismansScript.get_talisman(id)
		if talisman.is_empty():
			continue
		var price: int = _player.get_talisman_price(talisman)
		var owned: bool = _player.owned_talismans.has(id)
		stock_box.add_child(_make_shop_row(
			talisman.icon, "%s  (%s)" % [talisman.name, talisman.rarity.capitalize()], talisman.description,
			"%d c" % price, "Owned" if owned else "Buy", owned or _player.coins < price,
			_on_buy_pressed.bind(id), talisman.rarity != "common"
		))
	var cost: int = main.SEER_REROLL_COST
	reroll_button.text = "Reroll the stock -- %d coins" % cost
	reroll_button.disabled = _player.coins < cost

# Returns whether the purchase went through (tests drive this directly).
func buy(talisman_id: String) -> bool:
	var main := get_parent()
	if not main.seer_stock.has(talisman_id):
		_play_sfx("error")
		return false
	var ok: bool = _player.try_buy_talisman(talisman_id)
	if ok:
		main.seer_stock.erase(talisman_id)
		speech_label.text = "\"A fine choice. It will serve you well.\""
	else:
		speech_label.text = "\"You lack the coin -- or already carry that one.\""
	_play_sfx("purchase" if ok else "error")
	_refresh()
	return ok

func reroll() -> bool:
	var main := get_parent()
	var ok: bool = main.reroll_seer_stock()
	_play_sfx("purchase" if ok else "error")
	if ok:
		speech_label.text = "\"The stars turn. Look again.\""
	_refresh()
	return ok

func _on_buy_pressed(talisman_id: String) -> void:
	buy(talisman_id)

func _on_reroll_pressed() -> void:
	reroll()
