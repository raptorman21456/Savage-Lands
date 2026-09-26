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
	return Vector2(600, 430)

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
