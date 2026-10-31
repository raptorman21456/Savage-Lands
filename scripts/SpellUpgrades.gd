extends RefCounted
class_name SpellUpgrades

# Spell upgrades, bought from the Wizard's Tower (its "Spells" tab). EVERY spell can be upgraded twice -- to "+" and then to
# "EX" ("Vitalize" -> "Vitalize+" -> "Vitalize EX"). They are paid for in ESSENCE, the banked Essence the Church spends: the
# upgrade lasts only the run (an upgrade belongs to the CASTER -- the party member it was bought for -- and goes with them from battle to battle of the run, whatever
# they hold), but the Essence is gone for good. That is the risk and the reward -- die and you have paid
# permanent currency for something you no longer have -- and it gives Essence a use once every Church upgrade is owned.
# Level 0 is the plain spell; its numbers are the ones the design doc gives (PartyKits.gd / Main.gd).
#
# "Spells" here are the casters' own kits -- the Druid's, the Shaman's and the Necromancer's three -- and the Staff's and the Wand's three
# specials, twelve in all. A fighter's techniques (Rallying Cry, Haymaker...) are not spells.
#
# EVERY NUMBER BELOW IS A DRAFT: the user said only that all spells upgrade twice, to + and EX, for Essence. The prices are the
# same for every spell. The numbers each spell reads are in `numbers`, one dictionary per level (0, 1, 2); `text` is the line the
# Tower shows for what the upgrade does.

const MAX_LEVEL := 2
const SUFFIX := ["", "+", " EX"]

# What it costs, in banked Essence, to REACH level 1 and level 2 (index = the level reached): the design doc (2026-10-27) says + costs 10 and EX
# 40 more (50 in all).
const PRICES := [{}, {"essence": 10}, {"essence": 40}]

const SPELLS := [
	# --- the Druid ---
	{"id": "druid_heal", "owner": "Druid", "name": "Vitalize",
		"numbers": [{"pct": 0.25, "div": 3.0}, {"pct": 0.25, "div": 2.0}, {"pct": 0.35, "div": 1.5}],
		"text": ["", "Heals 25% of max HP plus HALF the Druid's magic (a third before).", "Heals 35% of max HP plus two thirds of the Druid's magic."]},
	{"id": "druid_buff", "owner": "Druid", "name": "Empower",
		"numbers": [{"mult": 1.5, "turns": 3}, {"mult": 1.75, "turns": 3}, {"mult": 2.0, "turns": 4}],
		"text": ["", "The ally deals 1.75x damage for 3 turns.", "The ally deals 2x damage for 4 turns."]},
	# Call the Wild: a traitor wolf at the Druid's own level for the rest of the battle (the wolf's stats are its kind's, scaled by `stat_mult`).
	{"id": "druid_call_the_wild", "owner": "Druid", "name": "Call the Wild",
		"numbers": [{"stat_mult": 1.0, "wolves": 1}, {"stat_mult": 1.25, "wolves": 1}, {"stat_mult": 1.25, "wolves": 2}],
		"text": ["", "The wolf is 25% stronger and tougher.", "The wolf is 25% stronger and tougher, and TWO answer the call."]},
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
		"numbers": [{"pct": 0.10, "kills": 1}, {"pct": 0.12, "kills": 1}, {"pct": 0.15, "kills": 2}],
		"text": ["", "The curse eats 12% of max HP a turn.", "The curse eats 15% of max HP a turn, and a kill it claims counts as 2 kills."]},
	{"id": "necromancer_revival_blessing", "owner": "Necromancer", "name": "Revival Blessing",
		"numbers": [{"keep_pct": 0.0}, {"keep_pct": 0.25}, {"keep_pct": 0.5}],
		"text": ["", "The Necromancer is left with 25% of her max HP, not 1.", "The Necromancer is left with half her max HP."]},
	{"id": "necromancer_summon_the_dead", "owner": "Necromancer", "name": "Summon the Dead",
		"numbers": [{"hp": 1, "damage": 4.0, "hp_cost": 5}, {"hp": 2, "damage": 6.0, "hp_cost": 5}, {"hp": 3, "damage": 8.0, "hp_cost": 4}],
		"text": ["", "Skeletons have 2 HP and hit for 6.", "Skeletons have 3 HP and hit for 8, and cost 4 HP each."]},
	# --- the Staff ---
	# Poison Bomb: the target takes (ftd x fortitude) + (mag x magic); the cloud lingers `turns` turns; a flame in it sets it off for (boom x magic).
	{"id": "staff_poison_bomb", "owner": "Staff", "name": "Poison Bomb",
		"numbers": [{"ftd": 2.0, "mag": 1.2, "boom": 1.5, "turns": 2}, {"ftd": 2.5, "mag": 1.5, "boom": 1.8, "turns": 2}, {"ftd": 3.0, "mag": 1.8, "boom": 2.2, "turns": 3}],
		"text": ["", "Hits for (fortitude x 2.5) + (magic x 1.5), and the explosion is magic x 1.8.", "Hits for (fortitude x 3) + (magic x 1.8), the cloud lingers 3 turns, and the explosion is magic x 2.2."]},
	{"id": "staff_landfall", "owner": "Staff", "name": "Landfall",
		"numbers": [{"attack_mult": 3.0, "magic_mult": 0.5, "stun": 0.25}, {"attack_mult": 3.5, "magic_mult": 0.65, "stun": 0.35}, {"attack_mult": 4.0, "magic_mult": 0.8, "stun": 0.5}],
		"text": ["", "(Attack x 3.5) + (magic x 0.65), 35% to stun.", "(Attack x 4) + (magic x 0.8), 50% to stun."]},
	# I SUMMON THEE (it replaced Channel): one spectre ally whose stats are shares of the caster's. `cost_pct` is the share of the caster's
	# maximum mana (stamina, or HP for the Necromancer) the cast takes; `dodge` is the spectre's flat chance to dodge an attack (RFL).
	{"id": "staff_i_summon_thee", "owner": "Staff", "name": "I SUMMON THEE",
		"numbers": [{"str": 0.8, "mag": 0.8, "vgr": 0.5, "agi": 1.2, "dxt": 0.7, "dodge": 0.5, "cost_pct": 0.5},
			{"str": 1.0, "mag": 1.0, "vgr": 0.65, "agi": 1.3, "dxt": 0.85, "dodge": 0.5, "cost_pct": 0.5},
			{"str": 1.2, "mag": 1.2, "vgr": 0.8, "agi": 1.4, "dxt": 1.0, "dodge": 0.6, "cost_pct": 0.4}],
		"text": ["", "The spectre is stronger: STR and MAG 100% of yours, VGR 65%, AGI 130%, DXT 85%.",
			"STR and MAG 120%, VGR 80%, AGI 140%, DXT 100%, it dodges 60% of attacks, and the cast costs only 40% of your maximum."]},
	# --- the Wand ---
	# Purifying Light: every enemy in the 3x3 is blinded for `blind` turns, `cures` afflictions come off the caster, and undead take (undead x magic).
	{"id": "wand_purifying_light", "owner": "Wand", "name": "Purifying Light",
		"numbers": [{"undead": 0.5, "cures": 1, "blind": 2}, {"undead": 0.8, "cures": 1, "blind": 3}, {"undead": 1.2, "cures": 2, "blind": 3}],
		"text": ["", "Undead take magic x 0.8, and the blindness lasts 3 turns.", "Undead take magic x 1.2, two afflictions come off you, and the blindness lasts 3 turns."]},
	# Freeze Ray: (mag x magic) damage and a freeze of min..max turns (tundric creatures cannot be frozen).
	{"id": "wand_freeze_ray", "owner": "Wand", "name": "FREEZE RAY",
		"numbers": [{"mag": 0.8, "min": 1, "max": 3}, {"mag": 1.0, "min": 2, "max": 3}, {"mag": 1.3, "min": 2, "max": 4}],
		"text": ["", "Magic x 1.0, frozen for 2-3 turns.", "Magic x 1.3, frozen for 2-4 turns."]},
	# The fireball moved from the Staff to the Wand (the doc): a 5x5 blast, magic x `mult` at the centre.
	{"id": "wand_i_cast_fireball", "owner": "Wand", "name": "I CAST FIREBALL",
		"numbers": [{"mult": 2.5, "falloff": 5.0}, {"mult": 3.0, "falloff": 5.0}, {"mult": 3.6, "falloff": 4.0}],
		"text": ["", "Magic x 3 at the centre.", "Magic x 3.6 at the centre, and it fades only 4 per tile."]},
]

static func has(spell_id: String) -> bool:
	return not spell(spell_id).is_empty()

static func spell(spell_id: String) -> Dictionary:
	for s in SPELLS:
		if s.id == spell_id:
			return s
	return {}

# "Vitalize", "Vitalize+", "Vitalize EX".
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
