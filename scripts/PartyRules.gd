extends RefCounted
class_name PartyRules

# The rules and numbers for party members (see PartyMember.gd for one member's
# state). Every kind of member is one entry in KINDS below: its starting stats, how
# fast each stat grows when it levels, its movement rule, its resource pools and
# the gear it is restricted to. Nothing here touches the game -- it is all data and
# pure formulas, so it can be tested on its own (tools/test_party_members.gd).
#
# The model mirrors the hero's (Player.gd:_level_up / apply_bonus_stat): every level
# grants a small passive gain to each stat AND one bonus pick to spend on a stat of
# your choice, and a kind's growth multiplier scales BOTH. A Druid (HP x1.2) at
# level 1 with 10 HP, levelled five times with every pick into HP, has
# 10 + (5 passive + 5 chosen) x 1.2 = 22 HP.

const STAT_NAMES := ["hp", "attack", "defense", "speed", "magic"]

# Passive gain per level and gain per bonus pick, before the kind's multiplier.
# Speed is the hero's displayed rating (starts at 5): the hero's real agility gets +1
# per level and +5 per pick out of a rating step of 5, i.e. 0.2 and 1.0 in rating.
const PASSIVE_GAIN := {"hp": 1.0, "attack": 1.0, "defense": 1.0, "speed": 0.2, "magic": 1.0}
const PICK_GAIN := {"hp": 1.0, "attack": 1.0, "defense": 1.0, "speed": 1.0, "magic": 1.0}

# Mirrors Player.gd (XP_BASE / XP_PER_LEVEL / MAX_LEVEL / the tile rule below); the
# test checks they still agree, so a members' level curve is the hero's.
const XP_BASE := 20
const XP_PER_LEVEL := 8
const MAX_LEVEL := 99
# Battle move tiles: the hero gets 2, plus one more per 4 speed rating over 5.
const BASE_MOVE_TILES := 2
const SPEED_START := 5.0
const SPEED_PER_EXTRA_TILE := 4.0

# Loyalty: how many battles a Fickle Wolf stays, before Wolf Fang / Pack Bond.
const WOLF_BASE_STAY_BATTLES := 10
# A wolf that faints this many times over the run dies for good.
const WOLF_MAX_FAINTS := 3

# base: starting stats (level 1). growth: multiplier on every gain (passive and
# picks). stats: the stats a pick can go into. levels: false = never levels.
# final_mult (non-levelling kinds): multipliers applied straight onto the base.
const KINDS := {
	"wolf": {
		"name": "Fickle Wolf", "wolf": true, "levels": false,
		"base": {"hp": 20.0, "attack": 1.0, "defense": 0.0, "speed": 5.0, "magic": 0.0},
		"final_mult": {"hp": 0.9, "attack": 1.25, "defense": 0.75, "speed": 1.5, "magic": 1.0},
		"stats": [],
		"stamina": 150, "caster": false,
		# Speed x1.5 is a movement multiplier: 2 tiles becomes 3.
		"move": {"tile_mult": 1.5},
		"attack_range": 1, "tint": Color(1.0, 0.85, 0.7),
	},
	"druid": {
		"name": "Druid", "levels": true,
		"base": {"hp": 10.0, "attack": 1.0, "defense": 0.0, "speed": 5.0, "magic": 10.0},
		"growth": {"hp": 1.2, "attack": 0.5, "defense": 0.66, "speed": 1.0, "magic": 1.0},
		"stats": ["hp", "attack", "defense", "speed", "magic"],
		"stamina": 0, "caster": true,
		"move": {},
		"attack_range": 1, "tint": Color(0.55, 1.0, 0.65),
	},
	"guardian": {
		"name": "Guardian", "levels": true,
		"base": {"hp": 25.0, "attack": 1.0, "defense": 5.0, "speed": 5.0, "magic": 0.0},
		"growth": {"hp": 1.25, "attack": 1.0, "defense": 1.5, "speed": 1.0, "magic": 1.0},
		"stats": ["hp", "attack", "defense"],
		"stamina": 100, "caster": false,
		# Speed is ALWAYS one tile.
		"move": {"fixed": 1},
		"attack_range": 1, "tint": Color(0.7, 0.8, 1.0),
	},
	"marksman": {
		"name": "Marksman", "levels": true,
		"base": {"hp": 10.0, "attack": 1.0, "defense": 0.0, "speed": 5.0, "magic": 0.0},
		# HP upgrades reduced by 75%.
		"growth": {"hp": 0.25, "attack": 1.0, "defense": 1.0, "speed": 1.0, "magic": 1.0},
		"stats": ["hp", "attack", "speed"],
		"stamina": 100, "caster": false,
		# Defense is always 0, whatever armour is worn.
		"defense_fixed": 0.0,
		# 1 tile + 0.07 per point of speed (2026-09-29 correction -- was 4 + 0.2).
		"move": {"base": 1.0, "per_speed": 0.07},
		"attack_range": 1, "tint": Color(1.0, 0.9, 0.6),
	},
	"rogue": {
		"name": "Rogue", "levels": true,
		"base": {"hp": 20.0, "attack": 1.0, "defense": 0.0, "speed": 5.0, "magic": 0.0},
		# Armour (defense) -30%, attack +30%, speed +40%, HP as normal.
		"growth": {"hp": 1.0, "attack": 1.3, "defense": 0.7, "speed": 1.4, "magic": 1.0},
		"stats": ["hp", "attack", "defense", "speed"],
		"stamina": 100, "caster": false,
		# Its own formula, not the hero's tile-per-4-rating one: 2 + 0.12 x speed rating.
		"move": {"base": 2.0, "per_speed": 0.12},
		"attack_range": 1, "tint": Color(0.85, 0.7, 1.0),
	},
}

# Mana: a pool for magic-users only, 5 per point of Magic.
const MANA_PER_MAGIC := 5

static func exists(kind: String) -> bool:
	return KINDS.has(kind)

static func rules(kind: String) -> Dictionary:
	return KINDS.get(kind, {})

static func is_wolf(kind: String) -> bool:
	return KINDS.get(kind, {}).get("wolf", false)

static func levels(kind: String) -> bool:
	return KINDS.get(kind, {}).get("levels", true)

static func growth(kind: String, stat: String) -> float:
	return float(KINDS.get(kind, {}).get("growth", {}).get(stat, 1.0))

static func xp_to_next(level: int) -> int:
	return XP_BASE + XP_PER_LEVEL * level

# How many battles a newly recruited wolf stays: the base, plus whatever Wolf Fang
# (talisman) and Pack Bond (skill) add.
static func wolf_stay_battles(talisman_bonus: int, pack_bond_bonus: int) -> int:
	return WOLF_BASE_STAY_BATTLES + talisman_bonus + pack_bond_bonus
