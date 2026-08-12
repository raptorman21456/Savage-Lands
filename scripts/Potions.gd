extends Node
class_name Potions

# Consumable, stackable -- buying one just adds it to the stockpile, no
# equip/owned concept. heal_amount for the minor tier matches Player's
# ITEM_HEAL_AMOUNT so meat drops and the cheapest shop potion feel the same.
const TIERS := [
	{
		"id": "potion_minor", "name": "Minor Potion", "price": 8, "heal_amount": 5,
		"description": "Heals 5 HP.", "icon": "potion",
	},
	{
		"id": "potion_regular", "name": "Potion", "price": 18, "heal_amount": 12,
		"description": "Heals 12 HP.", "icon": "potion",
	},
	{
		"id": "potion_greater", "name": "Greater Potion", "price": 35, "heal_amount": 25,
		"description": "Heals 25 HP.", "icon": "potion",
	},
]
