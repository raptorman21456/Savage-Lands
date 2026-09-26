extends Node
class_name Clothing

# The Flea Market tailor's wares: light "extra armour pieces" that stack a
# little damage reduction on top of whichever Armor tier is worn (see
# Player.gd:armor_damage_reduction). Three slots -- head, body, feet -- with
# three pieces each, cheapest/weakest first. Buying a piece equips it if it
# beats what's in that slot; every piece bought stays in owned_clothing so the
# Inventory's Clothes section can swap between them.
#
# Deliberately damage reduction only (no new stat types) -- the whole point is
# a cheap, modest top-up, not a second armour system. The best piece in every
# slot is +18% in total; the combined cap Main.gd already enforces (0.9) still
# applies on top of armour and everything else.
const SLOTS := ["head", "body", "feet"]
const SLOT_LABELS := {"head": "Head", "body": "Body", "feet": "Feet"}

static var PIECES := [
	{
		"id": "cloth_cap", "name": "Cloth Cap", "slot": "head", "price": 10,
		"damage_reduction": 0.02, "icon": "cloth_head",
		"description": "-2% damage taken.",
	},
	{
		"id": "cloth_hood", "name": "Leather Hood", "slot": "head", "price": 22,
		"damage_reduction": 0.04, "icon": "cloth_head",
		"description": "-4% damage taken.",
	},
	{
		"id": "cloth_pelt_hood", "name": "Wolf-Pelt Hood", "slot": "head", "price": 40,
		"damage_reduction": 0.06, "icon": "cloth_head",
		"description": "-6% damage taken.",
	},
	{
		"id": "cloth_tunic", "name": "Traveler's Tunic", "slot": "body", "price": 12,
		"damage_reduction": 0.03, "icon": "cloth_body",
		"description": "-3% damage taken.",
	},
	{
		"id": "cloth_jerkin", "name": "Padded Jerkin", "slot": "body", "price": 28,
		"damage_reduction": 0.05, "icon": "cloth_body",
		"description": "-5% damage taken.",
	},
	{
		"id": "cloth_cloak", "name": "Fur Cloak", "slot": "body", "price": 50,
		"damage_reduction": 0.07, "icon": "cloth_body",
		"description": "-7% damage taken.",
	},
	{
		"id": "cloth_sandals", "name": "Sturdy Sandals", "slot": "feet", "price": 8,
		"damage_reduction": 0.02, "icon": "cloth_feet",
		"description": "-2% damage taken.",
	},
	{
		"id": "cloth_boots", "name": "Leather Boots", "slot": "feet", "price": 20,
		"damage_reduction": 0.03, "icon": "cloth_feet",
		"description": "-3% damage taken.",
	},
	{
		"id": "cloth_trail_boots", "name": "Trail Boots", "slot": "feet", "price": 36,
		"damage_reduction": 0.05, "icon": "cloth_feet",
		"description": "-5% damage taken.",
	},
]

static func get_piece(id: String) -> Dictionary:
	for piece in PIECES:
		if piece.id == id:
			return piece
	return {}

static func for_slot(slot: String) -> Array:
	var result := []
	for piece in PIECES:
		if piece.slot == slot:
			result.append(piece)
	return result
