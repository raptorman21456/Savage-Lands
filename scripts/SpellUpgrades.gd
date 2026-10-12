extends RefCounted
class_name SpellUpgrades

# Spell upgrades, bought from the Wizard's Tower (its "Spells" tab). EVERY spell can be upgraded twice -- to "+" and then to
# "EX" ("Restore" -> "Restore+" -> "Restore EX"). They are paid for in ESSENCE, the banked Essence the Church spends: the
# upgrade lasts only the run (an upgrade belongs to the SPELL, not to a member: whoever casts it, in any battle of the run,
# casts the upgraded one), but the Essence is gone for good. That is the risk and the reward -- die and you have paid
# permanent currency for something you no longer have -- and it gives Essence a use once every Church upgrade is owned.
# Level 0 is the plain spell; its numbers are the ones the design doc gives (PartyKits.gd / Main.gd).
#
# "Spells" here are the casters' own kits -- the Druid's, the Shaman's and the Necromancer's three -- and the Staff's three
# specials, twelve in all. A fighter's techniques (Rallying Cry, Haymaker...) are not spells.
#
# EVERY NUMBER BELOW IS A DRAFT: the user said only that all spells upgrade twice, to + and EX, for Essence. The prices are the
# same for every spell. The numbers each spell reads are in `numbers`, one dictionary per level (0, 1, 2); `text` is the line the
# Tower shows for what the upgrade does.

const MAX_LEVEL := 2
const SUFFIX := ["", "+", " EX"]

# What it costs, in banked Essence, to REACH level 1 and level 2 (index = the level reached). (A Church capstone is 250-600.)
const PRICES := [{}, {"essence": 60}, {"essence": 160}]

const SPELLS := [
	# --- the Druid ---
	{"id": "druid_heal", "owner": "Druid", "name": "Restore",
		"numbers": [{"pct": 0.25, "div": 3.0}, {"pct": 0.25, "div": 2.0}, {"pct": 0.35, "div": 1.5}],
		"text": ["", "Heals 25% of max HP plus HALF the Druid's magic (a third before).", "Heals 35% of max HP plus two thirds of the Druid's magic."]},
	{"id": "druid_buff", "owner": "Druid", "name": "Empower",
		"numbers": [{"mult": 1.5, "turns": 3}, {"mult": 1.75, "turns": 3}, {"mult": 2.0, "turns": 4}],
		"text": ["", "The ally deals 1.75x damage for 3 turns.", "The ally deals 2x damage for 4 turns."]},
	{"id": "druid_sprint", "owner": "Druid", "name": "Vitalize",
		"numbers": [{"attack_div": 2.0, "flat": 5.0, "move_mult": 2.0}, {"attack_div": 1.3333, "flat": 5.0, "move_mult": 2.0}, {"attack_div": 1.0, "flat": 5.0, "move_mult": 2.5}],
		"text": ["", "Her attack while it lasts is three quarters of her attack plus 5 (half before).", "2.5x movement, and her attack is her full attack plus 5."]},
	# --- the Shaman ---
	{"id": "shaman_how_charming", "owner": "Shaman", "name": "How Charming",
		"numbers": [{"radius": 4, "turns": 2}, {"radius": 4, "turns": 3}, {"radius": 5, "turns": 4}],
		"text": ["", "Her charms reach allies for 3 turns.", "Her charms reach 5 tiles, for 4 turns."]},
	{"id": "shaman_soothing_rain", "owner": "Shaman", "name": "Soothing Rain",
		"numbers": [{"pct": 0.20, "radius": 2}, {"pct": 0.30, "radius": 2}, {"pct": 0.40, "radius": 3}],
		"text": ["", "Heals 30% of max HP.", "Heals 40% of max HP, out to 3 tiles."]},
	{"id": "shaman_cleansing_chant", "owner": "Shaman", "name": "Cleansing Chant",
		"numbers": [{"radius": 2, "all": 0}, {"radius": 3, "all": 0}, {"radius": 3, "all": 1}],
		"text": ["", "Reaches allies within 3 tiles.", "Within 3 tiles, EVERY affliction comes off EVERY ally at once."]},
	# --- the Necromancer ---
	{"id": "necromancer_curse_of_rot", "owner": "Necromancer", "name": "Curse of Rot",
		"numbers": [{"pct": 0.10, "turns": 5}, {"pct": 0.12, "turns": 5}, {"pct": 0.15, "turns": 6}],
		"text": ["", "The curse eats 12% of max HP a turn.", "The curse eats 15% of max HP a turn, for 6 turns."]},
	{"id": "necromancer_revival_blessing", "owner": "Necromancer", "name": "Revival Blessing",
		"numbers": [{"keep_pct": 0.0}, {"keep_pct": 0.25}, {"keep_pct": 0.5}],
		"text": ["", "The Necromancer is left with 25% of her max HP, not 1.", "The Necromancer is left with half her max HP."]},
	{"id": "necromancer_summon_the_dead", "owner": "Necromancer", "name": "Summon the Dead",
		"numbers": [{"hp": 1, "damage": 4.0, "hp_cost": 5}, {"hp": 2, "damage": 6.0, "hp_cost": 5}, {"hp": 3, "damage": 8.0, "hp_cost": 4}],
		"text": ["", "Skeletons have 2 HP and hit for 6.", "Skeletons have 3 HP and hit for 8, and cost 4 HP each."]},
	# --- the Staff ---
	{"id": "staff_i_cast_fireball", "owner": "Staff", "name": "I CAST FIREBALL",
		"numbers": [{"mult": 1.2, "falloff": 5.0}, {"mult": 1.5, "falloff": 5.0}, {"mult": 1.8, "falloff": 4.0}],
		"text": ["", "Magic x 1.5 at the centre.", "Magic x 1.8 at the centre, and it fades only 4 per tile."]},
	{"id": "staff_landfall", "owner": "Staff", "name": "Landfall",
		"numbers": [{"attack_mult": 3.0, "magic_mult": 0.5, "stun": 0.25}, {"attack_mult": 3.5, "magic_mult": 0.65, "stun": 0.35}, {"attack_mult": 4.0, "magic_mult": 0.8, "stun": 0.5}],
		"text": ["", "(Attack x 3.5) + (magic x 0.65), 35% to stun.", "(Attack x 4) + (magic x 0.8), 50% to stun."]},
	{"id": "staff_channel", "owner": "Staff", "name": "Channel",
		"numbers": [{"pct": 0.20}, {"pct": 0.30}, {"pct": 0.40}],
		"text": ["", "Restores 30% of an ally's maximum.", "Restores 40% of an ally's maximum."]},
]

static func has(spell_id: String) -> bool:
	return not spell(spell_id).is_empty()

static func spell(spell_id: String) -> Dictionary:
	for s in SPELLS:
		if s.id == spell_id:
			return s
	return {}

# "Restore", "Restore+", "Restore EX".
static func display_name(spell_id: String, level: int) -> String:
	var s: Dictionary = spell(spell_id)
	return "%s%s" % [s.name, SUFFIX[clampi(level, 0, MAX_LEVEL)]] if not s.is_empty() else spell_id

# The numbers a spell reads at this level ({} for something that is not a spell).
static func numbers(spell_id: String, level: int) -> Dictionary:
	var s: Dictionary = spell(spell_id)
	return s.numbers[clampi(level, 0, MAX_LEVEL)] if not s.is_empty() else {}

# One number a spell reads, at this level.
static func number(spell_id: String, level: int, key: String, fallback: float = 0.0) -> float:
	return float(numbers(spell_id, level).get(key, fallback))

# What this level changes, in words ("" at level 0).
static func level_text(spell_id: String, level: int) -> String:
	var s: Dictionary = spell(spell_id)
	return str(s.text[clampi(level, 0, MAX_LEVEL)]) if not s.is_empty() else ""

# The price of reaching `level` ({} for level 0 or past the top).
static func price(level: int) -> Dictionary:
	return PRICES[level] if level >= 1 and level <= MAX_LEVEL else {}
