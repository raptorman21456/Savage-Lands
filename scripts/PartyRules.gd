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
# Battle move tiles (the design doc): 1, plus 0.05 for every point of speed rating, rounded down -- the hero's rule too.
const BASE_MOVE_TILES := 1
const MOVE_TILES_PER_SPEED := 0.05

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
		"description": "A traitor wolf that turned on its pack. The old magic that made wolves so savage still runs through it, so it fights harder than any hound should. It cannot level, wear gear or carry a weapon, and three faints will be its last.",
		"base": {"hp": 20.0, "attack": 1.0, "defense": 0.0, "speed": 5.0, "magic": 0.0, "fortitude": -5.0},
		"final_mult": {"hp": 0.9, "attack": 1.4, "defense": 0.7, "speed": 1.5, "magic": 0.5, "fortitude": 0.7},
		"stats": [],
		"stamina": 150, "caster": false,
		# Speed x1.5 is a movement multiplier: 2 tiles becomes 3.
		"move": {"tile_mult": 1.5, "round": "up"},
		"attack_range": 1, "tint": Color(1.0, 0.85, 0.7),
	},
	"druid": {
		"name": "Druid", "levels": true,
		"description": "A wild-woods healer who would rather mend than maim. Her spells restore and embolden her friends, and when she must move, she moves twice as far. Fragile, and worth protecting.",
		"base": {"hp": 10.0, "attack": 1.0, "defense": 0.0, "speed": 5.0, "magic": 10.0, "fortitude": 5.0},
		"growth": {"hp": 1.4, "attack": 0.5, "defense": 0.7, "speed": 1.0, "magic": 1.5, "fortitude": 1.7},
		"extra_growth": {"dexterity": 1.2, "might": 0.9, "intelligence": 1.5, "charisma": 0.8, "reflexes": 1.2},
		"extra_base": {"intelligence": 6.0},
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
		"description": "A wall that walks. It only ever takes one step, hits twice as hard with a shield in hand, knocks foes a tile further with a hammer, and shouts loud enough to rattle every enemy on the field.",
		"base": {"hp": 25.0, "attack": 1.0, "defense": 5.0, "speed": 5.0, "magic": 0.0, "fortitude": 0.0},
		"growth": {"hp": 1.5, "attack": 1.3, "defense": 2.5, "speed": 0.1, "magic": 0.8, "fortitude": 1.8},
		"extra_growth": {"dexterity": 0.9, "might": 1.4, "intelligence": 1.1, "charisma": 1.5, "reflexes": 0.5},
		"stats": ["hp", "attack", "defense", "fortitude"],
		"stamina": 100, "caster": false,
		# Speed is ALWAYS one tile.
		"move": {"fixed": 1},
		# The Guardian is the one member whose protection (Defense and Fortitude) can climb to 90%; everyone
		# else tops out at Defense.gd:BASE_CAP (80%).
		"defense_cap": 0.9,
		# Taunting does not end its turn, and it knocks a foe back one tile further with a hammer (the doc).
		"favour": {"weapon": "hammer", "knockback_bonus": 1.0},
		# Deals 2x damage while carrying a shield (Main.gd:_apply_single_hit).
		"shield_damage_mult": 2.0,
		"attack_range": 1, "tint": Color(0.7, 0.8, 1.0),
	},
	"marksman": {
		"name": "Marksman", "levels": true,
		"description": "A sharpshooter who ignores range and cover, but will only ever fight with a bow. Arrows are cheap while the Marksman is around, and every other weapon costs more.",
		"base": {"hp": 10.0, "attack": 1.0, "defense": 0.0, "speed": 5.0, "magic": 0.0, "fortitude": 0.0},
		# HP upgrades reduced by 75%.
		"growth": {"hp": 0.7, "attack": 2.0, "defense": 0.1, "speed": 1.6, "magic": 1.0, "fortitude": 0.2},
		"extra_growth": {"dexterity": 1.5, "might": 1.1, "intelligence": 1.2, "charisma": 2.0, "reflexes": 2.0},
		"stats": ["hp", "attack", "speed", "fortitude"],
		"stamina": 100, "caster": false,
		# Armour protects it 60% less (the doc).
		"armor_defense_mult": 0.4,
		# Hits regardless of range or cover, and can ONLY use a bow; crit chance x1.5 with one. While a
		# Marksman is in the party arrows cost 50% less and other weapons 25% more (Player.gd prices).
		"unlimited_range": true, "ignore_cover": true, "weapon_only": "bow",
		"favour": {"weapon": "bow", "crit_chance_mult": 1.5},
		"arrow_price_mult": 0.5, "weapon_price_mult": 1.25,
		# 1 tile + 0.07 per point of speed (2026-09-29 correction -- was 4 + 0.2).
		"move": {"base": 1.0, "per_speed": 0.075, "round": "up"},
		"attack_range": 1, "tint": Color(1.0, 0.9, 0.6),
	},
	"rogue": {
		"name": "Rogue", "levels": true,
		"description": "Quick hands, quicker feet. Would rather lift an enemy's coin purse than its life, right up until the moment it decides otherwise. Always half in shadow: foes only notice the Rogue from close by, and its Stealth lasts longer, costs less and bites harder.",
		"base": {"hp": 20.0, "attack": 1.0, "defense": 0.0, "speed": 5.0, "magic": 0.0, "fortitude": 0.0},
		# Armour (defense) -30%, attack +30%, speed +40%, HP as normal.
		"growth": {"hp": 0.7, "attack": 1.5, "defense": 0.7, "speed": 1.9, "magic": 1.0, "fortitude": 0.9},
		"extra_growth": {"dexterity": 1.6, "might": 1.4, "intelligence": 1.0, "charisma": 1.3, "reflexes": 1.6},
		"stats": ["hp", "attack", "defense", "speed", "fortitude"],
		"stamina": 100, "caster": false,
		# Its own formula, not the hero's tile-per-4-rating one: 2 + 0.12 x speed rating.
		"move": {"base": 2.0, "per_speed": 0.12},
		# 25% of its regular attacks steal 1 gold instead of striking; 1.25x damage with a knife (dagger);
		# after attacking it may move again.
		"steal_chance": 0.25, "moves_after_attack": true,
		"favour": {"weapon": "dagger", "damage_pct": 0.25},
		# Every member can use Stealth (Main.gd:_ally_stealth_special); the Rogue's is better, and it is never fully visible.
		# DRAFT numbers (the user asked only for "always partially on" and "buffed"): plain Stealth is 3 turns / 20 / foes spot a
		# hiding member from 2 tiles; the Rogue's lasts 5 turns, costs 10, its stealthed crit does +1.0x on top of a normal crit's
		# 2x, and even when not hiding foes only spot it from 3 tiles (passive_sight).
		"stealth": {"turns": 5, "cost": 10, "crit_bonus": 0.5, "passive_sight": 3},
		"attack_range": 1, "tint": Color(0.85, 0.7, 1.0),
	},
	# --- The four from the design doc (their kits live in PartyKits.gd) ---
	"knight": {
		"name": "Knight", "levels": true,
		"description": "A veteran who holds the line. Strongest with a greatsword, able to keep a shield up even behind a two-handed weapon, and far too proud to dodge.",
		# Starting stats the user approved: 30 HP / 3 attack / 3 defense / 4 speed / 0 magic.
		"base": {"hp": 30.0, "attack": 3.0, "defense": 3.0, "speed": 4.0, "magic": 0.0, "fortitude": 10.0},
		"growth": {"hp": 1.2, "attack": 1.6, "defense": 1.3, "speed": 1.4, "magic": 0.6, "fortitude": 1.2},
		"extra_growth": {"dexterity": 1.0, "might": 1.1, "intelligence": 0.9, "charisma": 1.4, "reflexes": 0.7},
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
		"description": "Pays for every spell in blood and grows a little stronger with each kill. Rots enemies from within and raises the fallen to fight again.",
		"base": {"hp": 15.0, "attack": 1.0, "defense": 0.0, "speed": 5.0, "magic": 10.0, "fortitude": 0.0},
		"growth": {"hp": 2.4, "attack": 0.4, "defense": 0.7, "speed": 0.9, "magic": 1.8, "fortitude": 1.4},
		"extra_growth": {"dexterity": 0.7, "might": 0.7, "intelligence": 1.2, "charisma": 1.4, "reflexes": 0.8},
		"extra_base": {"intelligence": 6.0},
		"stats": ["hp", "attack", "defense", "speed", "magic", "fortitude"],
		"stamina": 0, "caster": true,
		# Spells cost HP, not mana (1 HP per 5 mana of spell).
		"hp_as_mana": true,
		"move": {},
		# +1 max HP (kept for good) for every enemy it kills, and a 2 HP heal per kill with a wand (the doc, 2026-10-30).
		"kill_max_hp": 1.0,
		"favour": {"weapon": "wand", "kill_heal": 2.0},
		"attack_range": 1, "tint": Color(0.6, 0.45, 0.75),
	},
	"brawler": {
		"name": "Brawler", "levels": true,
		"description": "A bare-knuckle fighter whose crits land 50% harder. Fists and knuckle gloves reach one tile further in these hands.",
		"base": {"hp": 20.0, "attack": 2.0, "defense": 2.0, "speed": 4.0, "magic": 0.0, "fortitude": 5.0},
		"growth": {"hp": 1.5, "attack": 1.8, "defense": 1.6, "speed": 0.6, "magic": 0.5, "fortitude": 0.9},
		"extra_growth": {"dexterity": 1.8, "might": 1.6, "intelligence": 0.5, "charisma": 1.3, "reflexes": 1.4},
		"stats": ["hp", "attack", "defense", "speed", "fortitude"],
		"stamina": 100, "caster": false,
		"move": {"min": 2},
		# Every attack: +10% to hit twice, +10% crit chance (keys in the talisman vocabulary;
		# double_hit_chance is stamped onto the weapon in Main.gd:_make_member_battle_unit).
		"perks": {"crit_damage_pct": 0.5},
		# Bare fists or knuckle gloves: +1 range ("" is bare hands).
		"favour": {"weapons": ["knuckle_gloves", ""], "range_bonus": 1.0},
		"attack_range": 1, "tint": Color(1.0, 0.62, 0.5),
	},
	"shaman": {
		"name": "Shaman", "levels": true,
		"description": "Carries five talismans and shares their power with everyone nearby. Heals, cleanses, and keeps the whole party in tune.",
		"base": {"hp": 12.0, "attack": 0.0, "defense": 1.0, "speed": 5.0, "magic": 10.0, "fortitude": 10.0},
		"growth": {"hp": 1.4, "attack": 0.4, "defense": 1.2, "speed": 1.1, "magic": 2.1, "fortitude": 1.6},
		"extra_growth": {"dexterity": 1.0, "might": 1.0, "intelligence": 1.7, "charisma": 1.2, "reflexes": 0.7},
		"extra_base": {"intelligence": 6.0},
		"stats": ["hp", "defense", "speed", "magic", "fortitude"],
		"stamina": 0, "caster": true,
		"move": {},
		# Five talisman slots from the start (the doc).
		"talisman_slots": 5,
		# With a staff in hand she shares her talismans' effects (50% strength) with every ally
		# within 2 tiles (4 while How Charming is up).
		"favour": {"weapon": "staff", "talisman_share": 0.5},
		"share_range": 2, "charm_range": 4,
		"attack_range": 1, "tint": Color(0.5, 0.9, 0.85),
	},
}

# Mana: a pool for magic-users only -- 20 + 5 per point of Intelligence (the design doc, 2026-10-30; it was 5 per point of Magic).
const MANA_BASE := 20
const MANA_PER_INTELLIGENCE := 5
# Kept for the code that still prices a spell in Magic.
const MANA_PER_MAGIC := 5

# The five stats beyond the original six (the doc's DXT, MGT, ITL, INM (charisma) and RFL). A member starts with its kind's
# extra_base (0 unless listed), gains EXTRA_GAIN x its kind's extra_growth every level, and they are not pickable. Their uses:
#   dexterity    crit chance, 0.5% a point, up to 10%         (the hero's Deft Fingers rule)
#   might        max stamina, +3 a point
#   intelligence max mana, 20 + 5 a point
#   charisma     every shop price drops by the party's average charisma, in coins, before the Intimidation discount
#   reflexes     dodge chance, 0.5% a point, up to 15%        (the hero's Sharp Mind rule; the Knight cannot dodge)
const EXTRA_STATS := ["dexterity", "might", "intelligence", "charisma", "reflexes"]
const EXTRA_GAIN := 1.0
const STAMINA_PER_MIGHT := 3
const CRIT_PER_DEXTERITY := 0.005
const CRIT_FROM_DEXTERITY_CAP := 0.10
const DODGE_PER_REFLEXES := 0.005
const DODGE_FROM_REFLEXES_CAP := 0.15

# How many specials a member brings into a fight: chosen on the Party screen from its pool (its kit's
# specials plus the equipped weapon's). The user's ruling, 2026-10-09.
const SPECIAL_SLOTS := 3

# Descriptions edited in strings.json (GameText applies them here: KINDS is a const, which cannot be written to).
static var description_overrides := {}

static func description_for(kind: String) -> String:
	if description_overrides.has(kind):
		return str(description_overrides[kind])
	return str(rules(kind).get("description", ""))

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

static func extra_growth(kind: String, stat: String) -> float:
	return float(KINDS.get(kind, {}).get("extra_growth", {}).get(stat, 1.0))

static func extra_base(kind: String, stat: String) -> float:
	return float(KINDS.get(kind, {}).get("extra_base", {}).get(stat, 0.0))

static func growth(kind: String, stat: String) -> float:
	return float(KINDS.get(kind, {}).get("growth", {}).get(stat, 1.0))

static func xp_to_next(level: int) -> int:
	return XP_BASE + XP_PER_LEVEL * level

# How many battles a newly recruited wolf stays: the base, plus whatever Wolf Fang
# (talisman) and Pack Bond (skill) add.
static func wolf_stay_battles(talisman_bonus: int, pack_bond_bonus: int) -> int:
	return WOLF_BASE_STAY_BATTLES + talisman_bonus + pack_bond_bonus
