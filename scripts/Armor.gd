extends Node
class_name Armor

# Fixed upgrade path (not randomly tiered like weapons) -- the shop always
# just offers the next rung up from whatever the player already owns.
const TIERS := [
	{
		"id": "armor_rags", "name": "Rags", "price": 0,
		"damage_reduction": 0.0, "negates_fall_damage": false,
		"description": "No damage reduction, no fall protection.",
		"icon": "armor_rags",
	},
	{
		"id": "armor_leather", "name": "Leather Vest", "price": 20,
		"damage_reduction": 0.15, "negates_fall_damage": false,
		"description": "-15% damage taken.",
		"icon": "armor_leather",
	},
	{
		"id": "armor_iron", "name": "Iron Plate", "price": 45,
		"damage_reduction": 0.3, "negates_fall_damage": true,
		"description": "-30% damage taken, and cliff falls deal no damage at all.",
		"icon": "armor_iron",
	},
	{
		"id": "armor_steel", "name": "Steel Plate", "price": 90,
		"damage_reduction": 0.45, "negates_fall_damage": true,
		"description": "-45% damage taken, and cliff falls deal no damage at all.",
		"icon": "armor_steel",
	},
	{
		"id": "armor_dragonskin", "name": "Dragonskin Plating", "price": 160,
		"damage_reduction": 0.6, "negates_fall_damage": true,
		"description": "-60% damage taken, and cliff falls deal no damage at all. Forged from the hide of something that shouldn't have died so easily.",
		"icon": "armor_dragonskin",
	},
]

# Returns the next tier up from what's owned, or an empty Dictionary if the
# player already owns the best one.
static func get_next_tier(owned_armor: Dictionary) -> Dictionary:
	for tier in TIERS:
		if not owned_armor.has(tier.id):
			return tier
	return {}
