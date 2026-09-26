extends Node
class_name Enchantments

# A fixed catalog (not randomly rolled, unlike weapon tiers/materials) -- the
# shop's Enchant tab lets the player spend Runic Shards + coins to apply one
# of these to their currently equipped weapon, permanently, one per weapon.
#
# Pact runes: each one is a single, build-defining tradeoff -- a genuinely
# big passive upside paired with a real, always-on downside -- rather than a
# small flat buff plus a bonus special hidden behind a button press (the old
# shape). All merged directly into the weapon at equip time (see
# Player.gd:_apply_enchantment_to_weapon); no dedicated battle-code dispatch
# needed beyond the couple of passive_* checks already used for weapon
# passives elsewhere (Main.gd).
#
# Passive keys (mirroring existing weapon-passive naming -- "passive_"
# prefix added on merge, matching the flag actually read in Main.gd):
#   damage_bonus_pct        - multiplies damage_mult by (1 + pct); a
#                              negative value works the same way, just down
#   lifesteal_pct           - adds to passive_lifesteal_pct (stacks with a
#                              Mythic weapon's own, e.g. the Great Toothpicke)
#   self_damage_pct         - a cut of the damage just dealt comes back at
#                              the wielder as recoil (passive_self_damage_pct)
#   stamina_discount_pct    - multiplies every special's stamina_cost by
#                              (1 - pct)
#   stamina_cost_bonus_pct  - the inverse: multiplies by (1 + pct)
#   break_chance_bonus_pct  - adds flat to break_chance, even on a weapon
#                              that normally has none
#   guaranteed_knockback    - sets passive_guaranteed_knockback
#   ignore_cover            - sets passive_ignore_cover
static var RUNES := [
	{
		"id": "ember", "name": "Rune of Bloodlust",
		"cost_shards": 3, "cost_coins": 40,
		"description": "Deal 50% more damage with every hit -- but violence like this always draws blood both ways. You take 15% of the damage you deal as recoil.",
		"shop_description": "Power always costs something. This one just makes you pay it yourself.",
		"passive": {"damage_bonus_pct": 0.5, "self_damage_pct": 0.15},
	},
	{
		"id": "leech", "name": "Rune of the Leech",
		"cost_shards": 3, "cost_coins": 40,
		"description": "Heals you for 25% of all damage dealt -- but the ritual saps your strength. -20% damage dealt.",
		"shop_description": "Trade a little bite for a lot of staying power. Fair deal, if you ask me.",
		"passive": {"lifesteal_pct": 0.25, "damage_bonus_pct": -0.2},
	},
	{
		"id": "tempest", "name": "Rune of the Tempest",
		"cost_shards": 3, "cost_coins": 40,
		"description": "Specials cost 50% less stamina -- but channeling a storm through your weapon strains it badly. +15% chance to shatter with every swing.",
		"shop_description": "Swing all you like -- just don't come crying to me when it shatters.",
		"passive": {"stamina_discount_pct": 0.5, "break_chance_bonus_pct": 0.15},
	},
	{
		"id": "warding", "name": "Rune of Warding",
		"cost_shards": 3, "cost_coins": 40,
		"description": "Every hit knocks the target back and ignores cover entirely -- but wielding this much force so precisely jars you just as hard. You take 10% of the damage you deal as recoil.",
		"shop_description": "Precision like that doesn't come free. Your own bones will remind you of that.",
		"passive": {"guaranteed_knockback": true, "ignore_cover": true, "self_damage_pct": 0.1},
	},
]

static func get_rune(id: String) -> Dictionary:
	for r in RUNES:
		if r.id == id:
			return r
	return {}
