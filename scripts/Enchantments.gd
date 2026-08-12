extends Node
class_name Enchantments

# A fixed catalog (not randomly rolled, unlike weapon tiers/materials) -- the
# shop's Enchant tab lets the player spend Runic Shards + coins to apply one
# of these to their currently equipped weapon. Each rune bundles a passive
# (a stat change merged directly into the weapon at equip time -- see
# Player.gd:_equip_weapon) and an active (a full special dict that overwrites
# one of the weapon's 3 existing slots). Actives deliberately reuse the
# game's existing effect strings (execute/lifesteal/cleave_all/
# guaranteed_knockback) so applying one needs no new battle-code dispatch.
#
# Passive keys:
#   damage_bonus_pct         - multiplies damage_mult by (1 + pct)
#   lifesteal_pct            - adds to passive_lifesteal_pct (stacks with a
#                               Mythic weapon's own, e.g. Stormfang)
#   stamina_discount_pct     - multiplies every special's stamina_cost by
#                               (1 - pct)
#   break_chance_reduction_pct - multiplies an existing break_chance by
#                               (1 - pct); a no-op on a weapon with none
const RUNES := [
	{
		"id": "ember", "name": "Rune of Embers",
		"cost_shards": 3, "cost_coins": 40,
		"description": "+20% damage on every hit. Replaces Special 1 with Ember Burst.",
		"passive": {"damage_bonus_pct": 0.2},
		"active_slot": 0,
		"active": {
			"id": "rune_ember_burst", "name": "Ember Burst", "stamina_cost": 30,
			"dmg_mult": 1.6, "effect": "execute",
			"description": "160% damage, plus 50% more against targets below 30% HP.",
		},
	},
	{
		"id": "leech", "name": "Rune of the Leech",
		"cost_shards": 3, "cost_coins": 40,
		"description": "Heals you for 12% of all damage dealt. Replaces Special 2 with Blood Drain.",
		"passive": {"lifesteal_pct": 0.12},
		"active_slot": 1,
		"active": {
			"id": "rune_blood_drain", "name": "Blood Drain", "stamina_cost": 25,
			"dmg_mult": 1.0, "effect": "lifesteal",
			"description": "Full damage, healing you for half of what you deal.",
		},
	},
	{
		"id": "tempest", "name": "Rune of the Tempest",
		"cost_shards": 3, "cost_coins": 40,
		"description": "-30% stamina cost on all specials. Replaces Special 3 with Tempest Strike.",
		"passive": {"stamina_discount_pct": 0.3},
		"active_slot": 2,
		"active": {
			"id": "rune_tempest_strike", "name": "Tempest Strike", "stamina_cost": 20,
			"dmg_mult": 0.8, "effect": "cleave_all",
			"description": "80% damage to every enemy in range at once.",
		},
	},
	{
		"id": "warding", "name": "Rune of Warding",
		"cost_shards": 3, "cost_coins": 40,
		"description": "Halves this weapon's break chance, if it has one. Replaces Special 1 with Fortress Strike.",
		"passive": {"break_chance_reduction_pct": 0.5},
		"active_slot": 0,
		"active": {
			"id": "rune_fortress_strike", "name": "Fortress Strike", "stamina_cost": 30,
			"dmg_mult": 1.0, "effect": "guaranteed_knockback",
			"description": "Full damage that always knocks back 2 tiles, even an Orc.",
		},
	},
]

static func get_rune(id: String) -> Dictionary:
	for r in RUNES:
		if r.id == id:
			return r
	return {}
