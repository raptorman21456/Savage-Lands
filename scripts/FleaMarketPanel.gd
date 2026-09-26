extends TownPanel
class_name FleaMarketPanel

# The Flea Market: three vendors under one panel, one tab each.
#   Baker        -- healing food (Foods.gd, vendor "baker")
#   Tailor       -- clothes: light extra armour pieces (Clothing.gd)
#   Curio Dealer -- arrows and a couple of odd potions, via the exact same
#                   Player.try_buy_arrow / try_buy_potion the gear shop uses
#                   (so prices, the arrow cap, and shop-discount bonuses all
#                   behave identically here)
# Layout follows TavernPanel's tab idiom: buttons across the top, one
# container per tab, everything rebuilt by _refresh().

const FoodsScript := preload("res://scripts/Foods.gd")
const ClothingScript := preload("res://scripts/Clothing.gd")
const PotionsScript := preload("res://scripts/Potions.gd")
const WeaponsScript := preload("res://scripts/Weapons.gd")

const TABS := ["Baker", "Tailor", "Curio Dealer"]
# The Curio Dealer's potions -- both already exist in the gear shop's pool.
const CURIO_POTION_IDS := ["potion_regular", "potion_stamina"]
const ARROW_KINDS := ["flame", "freeze", "bomb"]

var active_tab := "Baker"
var tab_buttons := {}
var tab_containers := {}
var coins_label: Label
var flavor_label: Label

func _panel_title() -> String:
	return "FLEA MARKET"

func _window_size() -> Vector2:
	return Vector2(660, 560)

func _build_content(outer: VBoxContainer) -> void:
	flavor_label = _make_label("", 14, Color(0.8, 0.8, 0.75))
	outer.add_child(flavor_label)
	coins_label = _make_label("", 15, Color(1.0, 0.85, 0.3))
	outer.add_child(coins_label)

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	outer.add_child(tab_row)
	for tab_name in TABS:
		var button := Button.new()
		button.text = tab_name
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(140, 32)
		button.button_pressed = tab_name == active_tab
		button.pressed.connect(_on_tab_pressed.bind(tab_name))
		tab_row.add_child(button)
		tab_buttons[tab_name] = button

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(stack)
	for tab_name in TABS:
		var container := VBoxContainer.new()
		container.add_theme_constant_override("separation", 8)
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.visible = tab_name == active_tab
		stack.add_child(container)
		tab_containers[tab_name] = container

func _on_tab_pressed(tab_name: String) -> void:
	active_tab = tab_name
	for name in tab_buttons:
		tab_buttons[name].button_pressed = name == tab_name
	for name in tab_containers:
		tab_containers[name].visible = name == tab_name
	_refresh()

func _refresh() -> void:
	if _player == null or coins_label == null:
		return
	coins_label.text = "Coins: %d" % _player.coins
	match active_tab:
		"Baker":
			flavor_label.text = "\"Warm bread, meat pies, honey cakes -- three coins buys you a better mood.\""
		"Tailor":
			flavor_label.text = "\"Nothing fancy, but a good cloak turns a blade better than you'd think.\""
		"Curio Dealer":
			flavor_label.text = "\"Arrows, tonics, odds and ends. Don't ask where they came from.\""
	for name in tab_containers:
		_clear(tab_containers[name])
	_build_baker(tab_containers["Baker"])
	_build_tailor(tab_containers["Tailor"])
	_build_curios(tab_containers["Curio Dealer"])

# --- Baker ------------------------------------------------------------------

func _build_baker(container: VBoxContainer) -> void:
	for food in FoodsScript.for_vendor("baker"):
		var price: int = _player.get_food_price(food)
		container.add_child(_make_shop_row(
			food.icon, food.name, food.description, "%d c" % price,
			"Buy", _player.coins < price, _on_buy_food_pressed.bind(food.id)
		))

# Returns whether the purchase went through (tests drive this directly).
func buy_food(food_id: String) -> bool:
	var food: Dictionary = FoodsScript.get_food(food_id)
	if food.is_empty() or food.vendor != "baker" or not _player.try_spend_coins(_player.get_food_price(food)):
		_play_sfx("error")
		return false
	_player.add_potion(food_id)
	_play_sfx("purchase")
	_refresh()
	return true

func _on_buy_food_pressed(food_id: String) -> void:
	buy_food(food_id)

# --- Tailor -----------------------------------------------------------------

func _build_tailor(container: VBoxContainer) -> void:
	for slot in ClothingScript.SLOTS:
		container.add_child(_make_label(ClothingScript.SLOT_LABELS[slot].to_upper(), 13, Color(1.0, 0.9, 0.3)))
		var worn_id: String = _player.equipped_clothing.get(slot, "")
		for piece in ClothingScript.for_slot(slot):
			var owned: bool = _player.owned_clothing.has(piece.id)
			var worn: bool = piece.id == worn_id
			var price: int = _player.get_clothing_price(piece)
			var button_text := "Buy"
			var price_text := "%d c" % price
			var disabled: bool = _player.coins < price
			if worn:
				button_text = "Worn"
				price_text = ""
				disabled = true
			elif owned:
				button_text = "Wear"
				price_text = ""
				disabled = false
			container.add_child(_make_shop_row(
				piece.icon, piece.name, piece.description, price_text,
				button_text, disabled, _on_clothing_pressed.bind(piece.id), worn
			))

# Buying equips the piece when it beats what's already in that slot (an
# empty slot counts as beaten); a cheaper, weaker piece bought later is just
# owned, so a stray purchase never downgrades you. Owned pieces are simply
# worn on click. Returns whether anything happened.
func use_clothing(piece_id: String) -> bool:
	var piece: Dictionary = ClothingScript.get_piece(piece_id)
	if piece.is_empty():
		return false
	if _player.owned_clothing.has(piece_id):
		_player.equip_clothing(piece_id)
		_play_sfx("purchase")
		_refresh()
		return true
	if not _player.try_buy_clothing(piece_id):
		_play_sfx("error")
		return false
	_play_sfx("purchase")
	_refresh()
	return true

func _on_clothing_pressed(piece_id: String) -> void:
	use_clothing(piece_id)

# --- Curio Dealer -----------------------------------------------------------

func _build_curios(container: VBoxContainer) -> void:
	container.add_child(_make_label("ARROWS", 13, Color(1.0, 0.9, 0.3)))
	var unlimited: bool = _player.has_unlimited_arrows()
	var cap: int = WeaponsScript.ARROW_MAX_HELD + _player.arrow_cap_bonus()
	for kind in ARROW_KINDS:
		var info: Dictionary = WeaponsScript.ARROW_TYPES[kind]
		var held: int = _player.owned_arrows.get(kind, 0)
		var price: int = _player.get_arrow_price(kind)
		var at_cap: bool = not unlimited and held >= cap
		var count_text: String = "%s (%d)" % [info.name, held] if unlimited else "%s (%d/%d)" % [info.name, held, cap]
		container.add_child(_make_shop_row(
			"quiver", count_text, info.get("description", ""),
			"%d c" % price, "Full" if at_cap else "Buy", at_cap or _player.coins < price,
			_on_buy_arrow_pressed.bind(kind)
		))
	container.add_child(_make_label("TONICS", 13, Color(1.0, 0.9, 0.3)))
	for id in CURIO_POTION_IDS:
		var potion: Dictionary = PotionsScript.get_tier(id)
		var price: int = _player.get_potion_price(potion)
		container.add_child(_make_shop_row(
			potion.get("icon", "potion"), potion.name, potion.get("description", ""),
			"%d c" % price, "Buy", _player.coins < price, _on_buy_potion_pressed.bind(id)
		))

func buy_arrow(kind: String) -> bool:
	var ok: bool = _player.try_buy_arrow(kind)
	_play_sfx("purchase" if ok else "error")
	_refresh()
	return ok

func buy_potion(potion_id: String) -> bool:
	var potion: Dictionary = PotionsScript.get_tier(potion_id)
	var ok: bool = not potion.is_empty() and _player.try_buy_potion(potion)
	_play_sfx("purchase" if ok else "error")
	_refresh()
	return ok

func _on_buy_arrow_pressed(kind: String) -> void:
	buy_arrow(kind)

func _on_buy_potion_pressed(potion_id: String) -> void:
	buy_potion(potion_id)
