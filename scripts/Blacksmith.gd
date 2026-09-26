extends Node
class_name Blacksmith

# The town Blacksmith's upgrade rules -- pure numbers, no state (the levels
# themselves live on Player as weapon_upgrade_levels / armor_upgrade_levels,
# keyed by weapon/armor id, because a weapon variant is rebuilt from its id
# every time and can't carry per-instance state itself -- see Weapons.gd:
# get_owned_variant).
#
# Weapons: any owned weapon can be upgraded up to WEAPON_MAX_LEVEL times; each
# level adds WEAPON_DAMAGE_PCT_PER_LEVEL to its damage and trims its break
# chance (Gold/Bone/Obsidian-forged weapons can shatter) by a tenth. Level 0
# is an exact identity -- an unupgraded weapon is untouched.
#
# Armour: only METAL armour (Armor.TIERS entries tagged "metal") -- the smith
# doesn't work leather, rags, or dragonhide. Each level adds a flat
# ARMOR_DR_PER_LEVEL of damage reduction on top of the tier's own.

const WEAPON_MAX_LEVEL := 5
const ARMOR_MAX_LEVEL := 3
const WEAPON_DAMAGE_PCT_PER_LEVEL := 0.08
# Relative, not flat: a Gold weapon's 5% break chance goes 5% -> 4.5% -> ...
const WEAPON_BREAK_REDUCTION_PER_LEVEL := 0.10
const ARMOR_DR_PER_LEVEL := 0.025

# Cost of the NEXT level, indexed by the level the item is at now (so
# WEAPON_COSTS[0] buys +1). The economy is small (weapons are 12-40 coins,
# ~1-2 coins per kill), so the first level costs about a new weapon and the
# last a real investment.
const WEAPON_COSTS := [25, 50, 90, 140, 200]
const ARMOR_COSTS := [40, 80, 140]

# Cost to raise a weapon from `level` to level+1, or -1 if already maxed.
static func weapon_cost(level: int) -> int:
	if level < 0 or level >= WEAPON_MAX_LEVEL:
		return -1
	return WEAPON_COSTS[level]

static func armor_cost(level: int) -> int:
	if level < 0 or level >= ARMOR_MAX_LEVEL:
		return -1
	return ARMOR_COSTS[level]

# The damage multiplier an upgrade level adds to a weapon (1.0 at level 0).
static func weapon_damage_factor(level: int) -> float:
	return 1.0 + WEAPON_DAMAGE_PCT_PER_LEVEL * maxi(level, 0)

static func weapon_break_factor(level: int) -> float:
	return maxf(0.0, 1.0 - WEAPON_BREAK_REDUCTION_PER_LEVEL * maxi(level, 0))

static func armor_bonus(level: int) -> float:
	return ARMOR_DR_PER_LEVEL * maxi(level, 0)
