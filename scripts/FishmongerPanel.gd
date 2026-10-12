extends TownPanel
class_name FishmongerPanel

# Pesca's Fishmonger (the Fishmonger's house, Interior "pesca_fish"): bait, fish and better rods for sale, and he buys
# your catch -- but this is the town that fishes, so he pays only a quarter of what the town's Butcher would
# (Foods.PESCA_SELL_MULT). The fishing itself is at the spot on Pesca's south shore (FishingPanel). All numbers are
# drafts (FishingHole.gd / Foods.gd).

const FishingHoleScript := preload("res://scripts/FishingHole.gd")
const FoodsScript := preload("res://scripts/Foods.gd")

var coins_label: Label
var stock_box: VBoxContainer

func _panel_title() -> String:
	return "THE FISHMONGER"

func _window_size() -> Vector2:
	return Vector2(660, 640)

func _build_content(outer: VBoxContainer) -> void:
	outer.add_child(_make_label("\"Everyone in Pesca fishes, so don't expect much for your catch. Sell it in the town if you want to get paid. Bait, a fish for supper, a better rod -- that I can help with.\"", 14, Color(0.8, 0.8, 0.75)))
	coins_label = _make_label("", 15, Color(1.0, 0.85, 0.3))
	outer.add_child(coins_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	stock_box = VBoxContainer.new()
	stock_box.add_theme_constant_override("separation", 8)
	stock_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(stock_box)

func _refresh() -> void:
	if _player == null or stock_box == null:
		return
	coins_label.text = "Coins: %d   Bait: %d   Rod: %s" % [_player.coins, _player.bait, _player.fishing_rod().name]
	_clear(stock_box)
	stock_box.add_child(_make_label("Bait", 15, Color(0.6, 0.9, 0.7)))
	stock_box.add_child(_make_shop_row("food_fish", "Bait", "One cast's worth.", "%d c" % FishingHoleScript.BAIT_PRICE, "Buy", _player.coins < FishingHoleScript.BAIT_PRICE, _on_buy_bait.bind(1)))
	stock_box.add_child(_make_shop_row("food_fish", "Bait x%d" % FishingHoleScript.BAIT_PACK, "A tin of five, a little cheaper.", "%d c" % FishingHoleScript.BAIT_PACK_PRICE, "Buy", _player.coins < FishingHoleScript.BAIT_PACK_PRICE, _on_buy_bait.bind(FishingHoleScript.BAIT_PACK)))
	stock_box.add_child(_make_label("Fish for supper", 15, Color(0.6, 0.9, 0.7)))
	for food in FoodsScript.for_vendor("fish"):
		var price: int = _player.get_food_price(food)
		stock_box.add_child(_make_shop_row(food.icon, food.name, food.description, "%d c" % price, "Buy", _player.coins < price, _on_buy_fish.bind(food.id)))
	stock_box.add_child(_make_label("Rods", 15, Color(0.6, 0.9, 0.7)))
	var best_id: String = _player.fishing_rod().id
	for rod in FishingHoleScript.RODS:
		if int(rod.price) <= 0:
			continue
		var owned: bool = _player.owned_rods.has(rod.id)
		stock_box.add_child(_make_shop_row("", rod.name + ("  (in use)" if rod.id == best_id else ""), rod.description, "" if owned else "%d c" % int(rod.price), "Owned" if owned else "Buy", owned or _player.coins < int(rod.price), _on_buy_rod.bind(rod.id), rod.id == best_id))
	stock_box.add_child(_make_label("Sell your catch (he pays a quarter of what the town does)", 15, Color(0.6, 0.9, 0.7)))
	var any_fish := false
	for food in FoodsScript.for_vendor("fish"):
		var held: int = _player.potion_queue.count(food.id)
		if held <= 0:
			continue
		any_fish = true
		var each: int = FoodsScript.sell_price(food.id, true)
		stock_box.add_child(_make_shop_row(food.icon, "%s  (you have %d)" % [food.name, held], "The town's Butcher would pay %d for it." % FoodsScript.sell_price(food.id, false), "+%d c" % each, "Sell", false, _on_sell.bind(food.id)))
	if not any_fish:
		stock_box.add_child(_make_label("You are not carrying any fish.", 13, Color(0.7, 0.7, 0.65)))

func buy_bait(count: int) -> bool:
	var price: int = FishingHoleScript.BAIT_PACK_PRICE if count == FishingHoleScript.BAIT_PACK else FishingHoleScript.BAIT_PRICE * count
	if _player == null or not _player.try_spend_coins(price):
		_play_sfx("error")
		return false
	_player.bait += count
	_play_sfx("purchase")
	_refresh()
	return true

func buy_fish(food_id: String) -> bool:
	var food: Dictionary = FoodsScript.get_food(food_id)
	if _player == null or food.is_empty() or food.vendor != "fish" or not _player.try_spend_coins(_player.get_food_price(food)):
		_play_sfx("error")
		return false
	_player.add_potion(food_id)
	_play_sfx("purchase")
	_refresh()
	return true

func buy_rod(rod_id: String) -> bool:
	if _player == null or not _player.try_buy_rod(rod_id):
		_play_sfx("error")
		return false
	_play_sfx("purchase")
	_refresh()
	return true

# Sells one fish at Pesca's cut-rate price. False if you carry none.
func sell(food_id: String) -> bool:
	var price: int = FoodsScript.sell_price(food_id, true)
	if _player == null or price <= 0 or not _player.try_sell_food(food_id, price):
		_play_sfx("error")
		return false
	_play_sfx("coin")
	_refresh()
	return true

func _on_buy_bait(count: int) -> void:
	buy_bait(count)

func _on_buy_fish(food_id: String) -> void:
	buy_fish(food_id)

func _on_buy_rod(rod_id: String) -> void:
	buy_rod(rod_id)

func _on_sell(food_id: String) -> void:
	sell(food_id)
