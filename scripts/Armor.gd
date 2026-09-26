extends Node
class_name Armor

# Fixed upgrade path (not randomly tiered like weapons) -- the shop always
# just offers the next rung up from whatever the player already owns.
#
# fall_damage_mult scales the usual cliff-fall damage (Main.gd's
# CLIFF_FALL_DAMAGE_PCT): 1.0 is normal, 0.0 fully negates it, anything else
# scales it up or down. Not monotonic with the armor's own tier -- Steel's
# rigid, heavy plate makes a fall worse despite blocking hits better than
# Iron, so this is a real tradeoff between tiers, not just "bigger number
# further down the list."
static var TIERS := [
	{
		"id": "armor_rags", "name": "Rags", "price": 0,
		"damage_reduction": 0.0, "fall_damage_mult": 1.0,
		"description": "No damage reduction, no fall protection.",
		"shop_description": "Technically clothing. I wouldn't call it armor, but it's free.",
		"icon": "armor_rags",
	},
	{
		"id": "armor_leather", "name": "Leather Vest", "price": 20,
		"damage_reduction": 0.15, "fall_damage_mult": 1.0,
		"description": "-15% damage taken.",
		"shop_description": "A step up from bare skin. Modest, but modest beats dead.",
		"icon": "armor_leather",
	},
	{
		"id": "armor_iron", "name": "Iron Plate", "price": 45, "metal": true,
		"damage_reduction": 0.3, "fall_damage_mult": 0.5,
		"description": "-30% damage taken, and cliff falls deal half damage.",
		"shop_description": "Solid stuff. Even softens a bad landing, for what that's worth.",
		"icon": "armor_iron",
	},
	{
		"id": "armor_steel", "name": "Steel Plate", "price": 90, "metal": true,
		"damage_reduction": 0.45, "fall_damage_mult": 1.5,
		"description": "-45% damage taken, but the rigid plate makes falls worse -- cliff falls deal 50% more damage.",
		"shop_description": "Stops almost anything short. Just don't trip near a cliff wearing it.",
		"icon": "armor_steel",
	},
	{
		"id": "armor_dragonskin", "name": "Dragonskin Plating", "price": 160,
		"damage_reduction": 0.6, "fall_damage_mult": 0.0,
		"description": "-60% damage taken, and cliff falls deal no damage at all. Forged from the hide of something that shouldn't have died so easily.",
		"shop_description": "Don't ask where I got this. Just know it used to be attached to something much bigger than you.",
		"icon": "armor_dragonskin",
	},
]

# "metal" tags the plate armours the town Blacksmith will upgrade (Blacksmith.
# gd) -- he won't work leather, rags, or dragonhide.
static func is_metal(id: String) -> bool:
	for tier in TIERS:
		if tier.id == id:
			return tier.get("metal", false)
	return false

# Returns the next tier up from what's owned, or an empty Dictionary if the
# player already owns the best one.
static func get_next_tier(owned_armor: Dictionary) -> Dictionary:
	for tier in TIERS:
		if not owned_armor.has(tier.id):
			return tier
	return {}

# Position of an armor in TIERS (worst to best), found by id -- the shop hands
# out tagged COPIES of these entries (Main._tagged adds a "category" key), which
# never compare equal to the original dictionaries, so TIERS.find(armor) would
# always come back -1 for anything bought. -1 for an unknown id.
static func tier_rank(armor: Dictionary) -> int:
	var id: String = armor.get("id", "")
	for i in TIERS.size():
		if TIERS[i].id == id:
			return i
	return -1
