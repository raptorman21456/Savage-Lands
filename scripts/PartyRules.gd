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

const TalismansScript := preload("res://scripts/Talismans.gd")

const STAT_NAMES := ["hp", "attack", "defense", "speed", "magic", "fortitude"]

# Passive gain per level and gain per bonus pick, before the kind's multiplier.
# Speed is the hero's displayed rating (starts at 5): the hero's real agility gets +1
# per level and +5 per pick out of a rating step of 5, i.e. 0.2 and 1.0 in rating.
const PASSIVE_GAIN := {"hp": 1.0, "attack": 1.0, "defense": 1.0, "speed": 0.2, "magic": 1.0, "fortitude": 1.0}
const PICK_GAIN := {"hp": 1.0, "attack": 1.0, "defense": 1.0, "speed": 1.0, "magic": 1.0, "fortitude": 1.0}

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
		"base": {"hp": 20.0, "attack": 1.0, "defense": 0.0, "speed": 5.0, "magic": 0.0, "fortitude": -5.0},
		"final_mult": {"hp": 0.9, "attack": 1.25, "defense": 0.75, "speed": 1.5, "magic": 1.0, "fortitude": 0.8},
		"stats": [],
		"stamina": 150, "caster": false,
		# Speed x1.5 is a movement multiplier: 2 tiles becomes 3.
		"move": {"tile_mult": 1.5},
		"attack_range": 1, "tint": Color(1.0, 0.85, 0.7),
	},
	"druid": {
		"name": "Druid", "levels": true,
		"base": {"hp": 10.0, "attack": 1.0, "defense": 0.0, "speed": 5.0, "magic": 10.0, "fortitude": 5.0},
		"growth": {"hp": 1.2, "attack": 0.5, "defense": 0.66, "speed": 1.0, "magic": 1.0, "fortitude": 1.2},
		"stats": ["hp", "attack", "defense", "speed", "magic", "fortitude"],
		"stamina": 0, "caster": true,
		"move": {},
		# A "favour" is a buff that only applies while a specific weapon is wielded (like the
		# Marksman's crit with bows). Keys: weapon = the weapon family id, then buff keys that
		# Main.gd:_make_member_battle_unit reads -- magic_mult (x the wielder's magic stat),
		# special_stamina_discount, crit_chance, double_hit_chance, range_bonus, damage_mult.
		# Doc: the Druid's magic stat is multiplied by 15% when she carries a staff.
		"favour": {"weapon": "staff", "magic_mult": 1.15},
		"attack_range": 1, "tint": Color(0.55, 1.0, 0.65),
	},
	"guardian": {
		"name": "Guardian", "levels": true,
		"base": {"hp": 25.0, "attack": 1.0, "defense": 5.0, "speed": 5.0, "magic": 0.0, "fortitude": 0.0},
		"growth": {"hp": 1.25, "attack": 1.0, "defense": 2.0, "speed": 1.0, "magic": 1.0, "fortitude": 1.3},
		"stats": ["hp", "attack", "defense", "fortitude"],
		"stamina": 100, "caster": false,
		# Speed is ALWAYS one tile.
		"move": {"fixed": 1},
		# The Guardian is the one member whose protection (Defense and Fortitude) can climb to 90%; everyone
		# else tops out at Defense.gd:BASE_CAP (80%).
		"defense_cap": 0.9,
		# Deals 2x damage while carrying a shield (Main.gd:_apply_single_hit).
		"shield_damage_mult": 2.0,
		"attack_range": 1, "tint": Color(0.7, 0.8, 1.0),
	},
	"marksman": {
		"name": "Marksman", "levels": true,
		"base": {"hp": 10.0, "attack": 1.0, "defense": 0.0, "speed": 5.0, "magic": 0.0, "fortitude": 0.0},
		# HP upgrades reduced by 75%.
		"growth": {"hp": 0.25, "attack": 1.0, "defense": 1.0, "speed": 1.0, "magic": 1.0, "fortitude": 1.0},
		"stats": ["hp", "attack", "speed", "fortitude"],
		"stamina": 100, "caster": false,
		# Defense is always 0, whatever armour is worn.
		"defense_fixed": 0.0,
		# Hits regardless of range or cover, and can ONLY use a bow; crit chance x1.5 with one. While a
		# Marksman is in the party arrows cost 60% less and other weapons 25% more (Player.gd prices).
		"unlimited_range": true, "ignore_cover": true, "weapon_only": "bow",
		"favour": {"weapon": "bow", "crit_chance_mult": 1.5},
		"arrow_price_mult": 0.4, "weapon_price_mult": 1.25,
		# 1 tile + 0.07 per point of speed (2026-09-29 correction -- was 4 + 0.2).
		"move": {"base": 1.0, "per_speed": 0.07},
		"attack_range": 1, "tint": Color(1.0, 0.9, 0.6),
	},
	"rogue": {
		"name": "Rogue", "levels": true,
		"base": {"hp": 20.0, "attack": 1.0, "defense": 0.0, "speed": 5.0, "magic": 0.0, "fortitude": 0.0},
		# Armour (defense) -30%, attack +30%, speed +40%, HP as normal.
		"growth": {"hp": 1.0, "attack": 1.3, "defense": 0.7, "speed": 1.4, "magic": 1.0, "fortitude": 1.0},
		"stats": ["hp", "attack", "defense", "speed", "fortitude"],
		"stamina": 100, "caster": false,
		# Its own formula, not the hero's tile-per-4-rating one: 2 + 0.12 x speed rating.
		"move": {"base": 2.0, "per_speed": 0.12},
		# 25% of its regular attacks steal 1 gold instead of striking; 1.25x damage with a knife (dagger);
		# after attacking it may move again.
		"steal_chance": 0.25, "moves_after_attack": true,
		"favour": {"weapon": "dagger", "damage_pct": 0.25},
		"attack_range": 1, "tint": Color(0.85, 0.7, 1.0),
	},
	# --- The four from the design doc (their kits live in PartyKits.gd) ---
	"knight": {
		"name": "Knight", "levels": true,
		# Starting stats the user approved: 30 HP / 3 attack / 3 defense / 4 speed / 0 magic.
		"base": {"hp": 30.0, "attack": 3.0, "defense": 3.0, "speed": 4.0, "magic": 0.0, "fortitude": 10.0},
		"growth": {"hp": 1.0, "attack": 1.3, "defense": 1.5, "speed": 0.75, "magic": 1.0, "fortitude": 0.9},
		"stats": ["hp", "attack", "defense", "speed", "magic", "fortitude"],
		"stamina": 100, "caster": false,
		# A speed of 4 would cost a tile under the hero's formula; a knight still gets the base 2.
		"move": {"min": 2},
		# Favours the greatsword: -20% stamina cost on every special while he wields one.
		"favour": {"weapon": "greatsword", "special_stamina_discount": 0.2},
		# He can hold a shield with a two-handed weapon (dormant until members can wear shields)
		# and cannot dodge.
		"shield_with_two_handed": true, "cannot_dodge": true,
		"attack_range": 1, "tint": Color(0.82, 0.86, 0.95),
	},
	"necromancer": {
		"name": "Necromancer", "levels": true,
		"base": {"hp": 15.0, "attack": 1.0, "defense": 0.0, "speed": 5.0, "magic": 10.0, "fortitude": 0.0},
		"growth": {"hp": 1.8, "attack": 0.4, "defense": 0.7, "speed": 0.9, "magic": 3.0, "fortitude": 1.4},
		"stats": ["hp", "attack", "defense", "speed", "magic", "fortitude"],
		"stamina": 0, "caster": true,
		# Spells cost HP, not mana (1 HP per 5 mana of spell).
		"hp_as_mana": true,
		"move": {},
		# +1 max HP (kept for good) for every enemy it kills, and a 2 HP heal per kill with a staff.
		"kill_max_hp": 1.0,
		"favour": {"weapon": "staff", "kill_heal": 2.0},
		"attack_range": 1, "tint": Color(0.6, 0.45, 0.75),
	},
	"brawler": {
		"name": "Brawler", "levels": true,
		"base": {"hp": 20.0, "attack": 2.0, "defense": 2.0, "speed": 4.0, "magic": 0.0, "fortitude": 5.0},
		"growth": {"hp": 1.5, "attack": 1.4, "defense": 1.3, "speed": 0.6, "magic": 1.0, "fortitude": 1.3},
		"stats": ["hp", "attack", "defense", "speed", "fortitude"],
		"stamina": 100, "caster": false,
		"move": {"min": 2},
		# Every attack: +10% to hit twice, +10% crit chance (keys in the talisman vocabulary;
		# double_hit_chance is stamped onto the weapon in Main.gd:_make_member_battle_unit).
		"perks": {"double_hit_chance": 0.10, "crit_chance": 0.10},
		# Bare fists or knuckle gloves: +1 range ("" is bare hands).
		"favour": {"weapons": ["knuckle_gloves", ""], "range_bonus": 1.0},
		"attack_range": 1, "tint": Color(1.0, 0.62, 0.5),
	},
	"shaman": {
		"name": "Shaman", "levels": true,
		"base": {"hp": 12.0, "attack": 0.0, "defense": 1.0, "speed": 5.0, "magic": 10.0, "fortitude": 10.0},
		"growth": {"hp": 1.2, "attack": 0.0, "defense": 0.7, "speed": 1.1, "magic": 1.7, "fortitude": 1.5},
		"stats": ["hp", "defense", "speed", "magic", "fortitude"],
		"stamina": 0, "caster": true,
		"move": {},
		# Four talisman slots from the start.
		"talisman_slots": 4,
		# With a staff in hand she shares her talismans' effects (50% strength) with every ally
		# within 2 tiles (4 while How Charming is up).
		"favour": {"weapon": "staff", "talisman_share": 0.5},
		"share_range": 2, "charm_range": 4,
		"attack_range": 1, "tint": Color(0.5, 0.9, 0.85),
	},
}

# Mana: a pool for magic-users only, 5 per point of Magic.
const MANA_PER_MAGIC := 5

# Gear a member can carry: weapon / armor / shield / talismans. A wolf carries nothing.
# Every member has 2 talisman slots from the start (the user, 2026-10-08), the Shaman 4 -- her own
# talisman_slots entry overrides the default. (The hero's slots still grow with level.)
const MEMBER_TALISMAN_SLOTS := 2
static func can_carry_gear(kind: String) -> bool:
	return not is_wolf(kind) and exists(kind)

static func talisman_slots(kind: String, _level: int) -> int:
	if not can_carry_gear(kind):
		return 0
	var rule: Dictionary = KINDS.get(kind, {})
	if rule.has("talisman_slots"):
		return int(rule.talisman_slots)
	return MEMBER_TALISMAN_SLOTS

# The favour buffs a kind gets from the weapon it wields ({} if the weapon is not its favourite).
static func favour_for(kind: String, weapon_base_id: String) -> Dictionary:
	var favour: Dictionary = KINDS.get(kind, {}).get("favour", {})
	if favour.is_empty():
		return {}
	# A favour names one weapon family ("weapon") or several ("weapons"; "" = bare hands).
	var liked: Array = favour.get("weapons", [favour.get("weapon", "")])
	if not liked.has(weapon_base_id):
		return {}
	return favour

# The always-on bonuses of a kind, in the talisman effect vocabulary (the Brawler's double-hit and
# crit chance). They apply whatever the member is holding.
static func perks_for(kind: String) -> Dictionary:
	return KINDS.get(kind, {}).get("perks", {})

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
