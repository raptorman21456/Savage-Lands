extends TownPanel
class_name ButcherPanel

# The town Butcher: cured and roasted meat that restores a small amount of HP
# and some stamina (see Foods.gd). Bought food goes into the player's
# potion_queue like any other consumable -- eat it from the Inventory's Items
# tab, or mid-battle through the Item button.

const FoodsScript := preload("res://scripts/Foods.gd")

var coins_label: Label
var stock_box: VBoxContainer

func _panel_title() -> String:
	return "THE BUTCHER"

func _window_size() -> Vector2:
	return Vector2(600, 520)

func _build_content(outer: VBoxContainer) -> void:
	outer.add_child(_make_label("\"Cured, smoked, or roasted -- small portions, honest prices. A little meat goes a long way out there.\"", 14, Color(0.8, 0.8, 0.75)))
	coins_label = _make_label("", 15, Color(1.0, 0.85, 0.3))
	outer.add_child(coins_label)
	stock_box = VBoxContainer.new()
	stock_box.add_theme_constant_override("separation", 8)
	outer.add_child(stock_box)

func _refresh() -> void:
	if _player == null or stock_box == null:
		return
	coins_label.text = "Coins: %d" % _player.coins
	_clear(stock_box)
	for food in FoodsScript.for_vendor("butcher"):
		var price: int = _player.get_food_price(food)
		stock_box.add_child(_make_shop_row(
			food.icon, food.name, food.description, "%d c" % price,
			"Buy", _player.coins < price, _on_buy_pressed.bind(food.id)
		))
	# He buys fish too, and pays properly (Pesca's Fishmonger pays only a quarter of this).
	var any_fish := false
	for fish in FoodsScript.for_vendor("fish"):
		var held: int = _player.potion_queue.count(fish.id)
		if held <= 0:
			continue
		if not any_fish:
			stock_box.add_child(_make_label("Sell your catch", 15, Color(0.6, 0.9, 0.7)))
			any_fish = true
		stock_box.add_child(_make_shop_row(fish.icon, "%s  (you have %d)" % [fish.name, held], "Fresh fish: he pays well for it here.", "+%d c" % FoodsScript.sell_price(fish.id, false), "Sell", false, _on_sell_pressed.bind(fish.id)))

# Returns whether the purchase went through (tests drive this directly).
func buy(food_id: String) -> bool:
	var food: Dictionary = FoodsScript.get_food(food_id)
	if _player == null or food.is_empty() or food.vendor != "butcher" or not _player.try_spend_coins(_player.get_food_price(food)):
		_play_sfx("error")
		return false
	_player.add_potion(food_id)
	_play_sfx("purchase")
	_refresh()
	return true

func _on_buy_pressed(food_id: String) -> void:
	buy(food_id)

# Sells one fish at the town's full price. False if you carry none.
func sell(food_id: String) -> bool:
	var price: int = FoodsScript.sell_price(food_id, false)
	if _player == null or price <= 0 or not _player.try_sell_food(food_id, price):
		_play_sfx("error")
		return false
	_play_sfx("coin")
	_refresh()
	return true

func _on_sell_pressed(food_id: String) -> void:
	sell(food_id)
