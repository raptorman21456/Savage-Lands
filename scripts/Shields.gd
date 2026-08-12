extends Node
class_name Shields

# Off-hand equipment slot, separate from both weapon and armor -- the player
# can carry one of each simultaneously. Unlike Armor's fixed upgrade path,
# these are 5 permanently distinct items (not a linear tier), so the shop
# offers whichever ones aren't owned yet rather than "the next rung up."
#
# A shield's passive block_chance and special ability are only ACTIVE while
# the currently equipped weapon is one of COMPATIBLE_WEAPONS below -- you can
# own and carry a shield regardless of weapon, but a Greatsword or Bow needs
# both hands, so it goes inert until you switch to something one-handed.
# Checked in Player.gd's shield_block_chance()/shield_push_immune() helpers.
const COMPATIBLE_WEAPONS := ["club", "spear", "hammer", "dagger", "knuckle_gloves"]

# block_chance is flat -- identical with ANY compatible weapon equipped, not
# just the shield's own synergy_weapon (a shield is fully usable off its
# synergy pick, just without the special's extra kick). Only special_pct
# scales with synergy, rewarding the "designed for" pairing without gating
# the shield's core protection behind it.
#
# special: "" (Buckler has none), "knockback" (shoves the attacker back),
# "thorns" (reflect damage), "evasive" (relocate on a dodge), or "vengeance"
# (bonus damage on your next attack). All except "evasive" are resolved in
# Main.gd's _resolve_shield_block(), firing only when the passive
# block_chance roll (see _enemy_apply_damage) actually succeeds. "evasive" is
# the one exception -- it triggers off a successful DODGE instead (Precision
# or otherwise), pausing the attacker's turn so the player can pick a nearby
# tile to relocate to; special_pct there means bonus reposition tiles, not a
# percentage. "knockback"'s special_pct is a flag (0 = single-tile shove, >0
# = an extra-distance double shove) rather than a percentage too.
#
# synergy_weapon is the one COMPATIBLE_WEAPONS id each shield was designed
# around -- equipping that exact weapon bumps special_pct up to
# synergy_special_pct (see Player.gd's shield_special_pct()), on top of the
# shield already working fully with any of the 5.
const SHIELDS := {
	"shield_buckler": {
		"id": "shield_buckler", "name": "Wooden Buckler", "price": 0,
		"synergy_weapon": "club",
		"block_chance": 0.33,
		"special": "", "special_pct": 0.0, "synergy_special_pct": 0.0,
		"description": "A simple wooden shield -- steady, reliable, free. No special trick, just a full third of incoming hits bouncing right off. Pairs naturally with a Club: neither needs finesse.",
		"icon": "shield_buckler",
	},
	"shield_heavy": {
		"id": "shield_heavy", "name": "Heavy Shield", "price": 40,
		"synergy_weapon": "spear",
		"block_chance": 0.15,
		"push_immune": true,
		"special": "knockback", "special_pct": 0.0, "synergy_special_pct": 1.0,
		"description": "A slab too solid to move -- you can't be pushed while it's raised, water current included. A successful block shoves the attacker back a tile (two, with a Spear to brace against).",
		"icon": "shield_round",
	},
	"shield_bulwark": {
		"id": "shield_bulwark", "name": "Iron Bulwark", "price": 60,
		"synergy_weapon": "hammer",
		"block_chance": 0.08,
		"special": "thorns", "special_pct": 0.25, "synergy_special_pct": 0.4,
		"description": "A slab of iron built to eat a blow head-on and throw it right back -- a Hammer-wielder's whole philosophy, in shield form. Thorns: a successful block reflects 25%% of the blocked hit back at the attacker (40%% with a Hammer).",
		"icon": "shield_bulwark",
	},
	"shield_phantom": {
		"id": "shield_phantom", "name": "Phantom Guard", "price": 50,
		"synergy_weapon": "dagger",
		"block_chance": 0.08,
		"special": "evasive", "special_pct": 2, "synergy_special_pct": 3,
		"description": "Barely more than a bracer -- less about blocking a blow than never being where it lands. A dodge lets you slip up to 2 tiles away, your pick (3 with a Dagger), before the attacker even realizes they missed.",
		"icon": "shield_phantom",
	},
	"shield_brawler": {
		"id": "shield_brawler", "name": "Brawler's Buckler", "price": 55,
		"synergy_weapon": "knuckle_gloves",
		"block_chance": 0.10,
		"special": "vengeance", "special_pct": 0.5, "synergy_special_pct": 0.75,
		"description": "Strapped to the forearm, built to punish -- a blocked hit only feeds the fire behind your next punch. Vengeance: a successful block empowers your very next attack for +50%% damage (+75%% with Knuckle Gloves).",
		"icon": "shield_brawler",
	},
}

const SHIELD_IDS := ["shield_buckler", "shield_heavy", "shield_bulwark", "shield_phantom", "shield_brawler"]

static func is_weapon_compatible(weapon_id: String) -> bool:
	return weapon_id in COMPATIBLE_WEAPONS
