extends Node
class_name Foods

# Cooked/cured food sold by the Butcher and the Flea Market's Baker (and, later,
# hauled out of the Fishing Hole). Held in the same potion_queue as potions
# (see Player.gd:add_potion) -- so the HUD's item count, the battle Item
# button, and the Inventory's Items tab all just work -- but deliberately NOT
# part of Potions.TIERS: the gear shop rolls its potion offers straight from
# that list, and food is a town-vendor good, not a shop roll.
#
# Every food restores a small amount of HP AND some stamina (stamina only
# matters in battle, where it refills to full at the start of each fight --
# which is exactly why food is worth eating mid-battle, see Main.gd:
# _battle_player_item). Amounts are deliberately small: a Health Potion heals
# 20 HP for 15 coins, and the player's max HP starts at 20.
#
# vendor: "butcher" / "baker" are sold in town; "fish" is only ever caught.
# Same shape as a Potions.TIERS entry so Player._consume_potion can treat
# either kind identically ("effect" is always "" -- food never cleanses/buffs).
static var ITEMS := [
	{
		"id": "food_jerky", "name": "Dried Jerky", "vendor": "butcher", "price": 5,
		"heal_amount": 5, "stamina_amount": 15, "effect": "",
		"description": "Heals 5 HP and restores 15 stamina.",
		"shop_description": "Tough, salty, and it keeps forever. Chew slowly.",
		"icon": "food_meat",
	},
	{
		"id": "food_sausage", "name": "Smoked Sausage", "vendor": "butcher", "price": 9,
		"heal_amount": 8, "stamina_amount": 25, "effect": "",
		"description": "Heals 8 HP and restores 25 stamina.",
		"shop_description": "Smoked over applewood. Best thing in the shop, and don't tell my wife.",
		"icon": "food_meat",
	},
	{
		"id": "food_haunch", "name": "Roast Haunch", "vendor": "butcher", "price": 14,
		"heal_amount": 12, "stamina_amount": 40, "effect": "",
		"description": "Heals 12 HP and restores 40 stamina.",
		"shop_description": "Fresh off the spit. A proper meal for someone who fights for a living.",
		"icon": "food_meat",
	},
	{
		"id": "food_bread", "name": "Fresh Bread", "vendor": "baker", "price": 4,
		"heal_amount": 5, "stamina_amount": 5, "effect": "",
		"description": "Heals 5 HP and restores 5 stamina.",
		"shop_description": "Still warm. Nothing fancy -- nothing wrong with it either.",
		"icon": "food_bread",
	},
	{
		"id": "food_pie", "name": "Meat Pie", "vendor": "baker", "price": 8,
		"heal_amount": 9, "stamina_amount": 12, "effect": "",
		"description": "Heals 9 HP and restores 12 stamina.",
		"shop_description": "Gravy, pastry, and a suspicious amount of pepper.",
		"icon": "food_bread",
	},
	{
		"id": "food_honey_cake", "name": "Honey Cake", "vendor": "baker", "price": 7,
		"heal_amount": 3, "stamina_amount": 30, "effect": "",
		"description": "Heals 3 HP and restores 30 stamina.",
		"shop_description": "Sweet enough to get your arms swinging again.",
		"icon": "food_bread",
	},
	# Only ever caught at the Fishing Hole (FishingHole.gd's loot table), never
	# bought -- "price" is unused but kept for shape-consistency with every
	# other entry.
	{
		"id": "food_minnow", "name": "Fried Minnow", "vendor": "fish", "price": 0,
		"heal_amount": 4, "stamina_amount": 10, "effect": "",
		"description": "Heals 4 HP and restores 10 stamina.",
		"shop_description": "",
		"icon": "food_fish",
	},
	{
		"id": "food_bass", "name": "Grilled Bass", "vendor": "fish", "price": 0,
		"heal_amount": 10, "stamina_amount": 28, "effect": "",
		"description": "Heals 10 HP and restores 28 stamina.",
		"shop_description": "",
		"icon": "food_fish",
	},
]

static func get_food(id: String) -> Dictionary:
	for item in ITEMS:
		if item.id == id:
			return item
	return {}

static func is_food(id: String) -> bool:
	return not get_food(id).is_empty()

# Everything a given vendor sells, in catalog order.
static func for_vendor(vendor: String) -> Array:
	var result := []
	for item in ITEMS:
		if item.vendor == vendor:
			result.append(item)
	return result
