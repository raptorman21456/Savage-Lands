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
# damage_penalty_pct is the tradeoff for fighting one-handed -- every shield
# except the free Wooden Buckler cuts into your own damage output while
# active (Player.gd:shield_damage_penalty_pct, read in Main.gd's
# _apply_single_hit). The Buckler stays a no-tradeoff baseline, same as how
# Club has no downside of its own either.
#
# damage_reduction_pct is a flat cut off every hit that actually lands --
# independent of, and stacking with, the block_chance dice roll above (see
# Player.gd:shield_damage_reduction_pct, folded into Main.gd's
# _apply_incoming_reductions alongside Armor's own damage_reduction).
#
# defend_threshold_bonus raises the flat-negate threshold on the Defend
# action itself (Main.gd:DEFEND_FULL_NEGATE_THRESHOLD) -- a sturdier shield
# lets bracing behind it shrug off a bigger hit before Defend falls back to
# just halving it (see Player.gd:shield_defend_threshold_bonus). Buckler and
# Phantom Guard carry none -- Buckler for its usual "no trick" simplicity,
# Phantom Guard because it's built around dodging a hit, not bracing for one.
#
# special: "" (Buckler has none), "knockback" (shoves the attacker back),
# "thorns" (reflect damage), "evasive" (dodge-roll one tile on a dodge), or
# "vengeance" (bonus damage on your next attack). All except "evasive" are
# resolved in Main.gd's _resolve_shield_block(), firing only when the passive
# block_chance roll (see _enemy_apply_damage) actually succeeds. "evasive" is
# the one exception -- it triggers off a successful DODGE instead (Precision
# or otherwise): Main.gd offers back/left/right relative to the attacker,
# whichever of those are actually free tiles (see _evasion_directions), and
# the player picks exactly one. "knockback"'s special_pct is a flag (0 =
# single-tile shove, >0 = an extra-distance double shove) rather than a
# percentage.
#
# synergy_weapon is the one COMPATIBLE_WEAPONS id each shield was designed
# around -- equipping that exact weapon bumps special_pct up to
# synergy_special_pct (see Player.gd's shield_special_pct()), on top of the
# shield already working fully with any of the 5. Phantom Guard has no
# special_pct at all -- its dodge-roll is always exactly one tile, so there's
# no magnitude for a synergy weapon to scale.
static var SHIELDS := {
	"shield_buckler": {
		"id": "shield_buckler", "name": "Wooden Buckler", "price": 0,
		"synergy_weapon": "club",
		"block_chance": 0.33,
		"special": "", "special_pct": 0.0, "synergy_special_pct": 0.0,
		"description": "A simple wooden shield -- steady, reliable, free. No special trick, just a full third of incoming hits bouncing right off. Pairs naturally with a Club: neither needs finesse.",
		"shop_description": "Every adventurer's first shield. Simple, honest, doesn't cost you a thing.",
		"icon": "shield_buckler",
	},
	"shield_heavy": {
		"id": "shield_heavy", "name": "Heavy Shield", "price": 40,
		"synergy_weapon": "spear",
		"block_chance": 0.15,
		"push_immune": true,
		"damage_penalty_pct": 0.10,
		"damage_reduction_pct": 0.10,
		"defend_threshold_bonus": 4,
		"special": "knockback", "special_pct": 0.0, "synergy_special_pct": 1.0,
		"description": "A slab too solid to move -- you can't be pushed while it's raised, water current included. A successful block shoves the attacker back a tile (two, with a Spear to brace against). Passively soaks 10% off every hit that lands, and Defend alone shrugs off a bigger blow before falling back to halving it. Bracing this much steel behind you costs 10% of your own damage.",
		"shop_description": "Plant your feet behind this and nothing's moving you. Nothing at all.",
		"icon": "shield_round",
	},
	"shield_bulwark": {
		"id": "shield_bulwark", "name": "Iron Bulwark", "price": 60,
		"synergy_weapon": "hammer",
		"block_chance": 0.18,
		"damage_penalty_pct": 0.15,
		"damage_reduction_pct": 0.15,
		"defend_threshold_bonus": 8,
		"special": "thorns", "special_pct": 0.25, "synergy_special_pct": 0.4,
		"description": "A slab of iron built to eat a blow head-on and throw it right back -- a Hammer-wielder's whole philosophy, in shield form. Thorns: a successful block reflects 25% of the blocked hit back at the attacker (40% with a Hammer). Passively soaks 15% off every hit that lands, and the best Defend threshold in the game on top. This much dead weight costs 15% of your own damage.",
		"shop_description": "Heaviest one I stock. Hit it and you'll wish you hadn't.",
		"icon": "shield_bulwark",
	},
	"shield_phantom": {
		"id": "shield_phantom", "name": "Phantom Guard", "price": 50,
		"synergy_weapon": "dagger",
		"block_chance": 0.18,
		"damage_penalty_pct": 0.08,
		"damage_reduction_pct": 0.05,
		"special": "evasive",
		"description": "Barely more than a bracer -- less about blocking a blow than never being where it lands. A dodge earns you a single dodge-roll: back, left, or right, whichever way isn't blocked. Passively soaks a light 5% off every hit that lands. Even this light a shield costs 8% of your own damage.",
		"shop_description": "Barely there, and that's the point. You won't even feel it -- until you need it.",
		"icon": "shield_phantom",
	},
	"shield_brawler": {
		"id": "shield_brawler", "name": "Brawler's Buckler", "price": 55,
		"synergy_weapon": "knuckle_gloves",
		"block_chance": 0.10,
		"damage_penalty_pct": 0.10,
		"damage_reduction_pct": 0.08,
		"defend_threshold_bonus": 2,
		"special": "vengeance", "special_pct": 0.5, "synergy_special_pct": 0.75,
		"description": "Strapped to the forearm, built to punish -- a blocked hit only feeds the fire behind your next punch. Vengeance: a successful block empowers your very next attack for +50% damage (+75% with Knuckle Gloves). Passively soaks 8% off every hit that lands. Fighting one-handed costs 10% of your own damage.",
		"shop_description": "Block with this and I'd pity whatever you hit next.",
		"icon": "shield_brawler",
	},
}

const SHIELD_IDS := ["shield_buckler", "shield_heavy", "shield_bulwark", "shield_phantom", "shield_brawler"]

static func is_weapon_compatible(weapon_id: String) -> bool:
	return weapon_id in COMPATIBLE_WEAPONS
