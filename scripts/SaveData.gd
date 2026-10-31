extends Node
class_name SaveData

# Persistent meta-progression: Essence earned during a run (1 per enemy
# defeated, ESSENCE_PER_BOSS_KILL per boss or miniboss) banks permanently when
# the run ends and buys permanent upgrades at the Church in town, applied to
# every future run. This is what makes death matter instead of just resetting
# everything to zero.
const ESSENCE_PER_KILL := 1
const ESSENCE_PER_BOSS_KILL := 10

# What one defeated enemy is worth before the difficulty multiplier.
static func essence_for_kill(is_boss: bool) -> int:
	return ESSENCE_PER_BOSS_KILL if is_boss else ESSENCE_PER_KILL

# The Church's tree: the design doc's Astral Upgrades tab (read again 2026-10-27) -- its names, maxima and requirements -- priced with the
# per-level prices of the team's Astral tree visualizer from the doc's earlier revision (which came to exactly 1,536 Essence for its 44
# upgrades; the visualizer is gone from the doc now and the tree has changed since, so every price of a node that is NEW is my draft). A hub,
# LEGACY (from that visualizer; the doc's list does not mention it), opens four wings -- Physical, Economy, Sustain and Sorcery -- with three
# cross-branch capstones, the post-game Worldwalker, and Otherworldly Power at the very end, which wants every other upgrade. `prereqs` (an
# Array of {id, min_level}, AND logic -- every entry must be satisfied) gates a node; as in the visualizer a plain requirement means the node
# FULLY BOUGHT (so min_level is its max_level unless the doc says "lvl 2"); an empty array is a root. `costs` is the price of each level in
# turn, and its length is the node's max level.
#
# What is in the doc and not built: Continual Learning (Intelligence, +1 every level) is in the tree but Intelligence is not a stat in the game
# yet, so it only records that it was bought. (Painful Memories unlocks the Rage stat, which is built.) The third cross-branch capstone
# ("something else") is the visualizer's Aegis & Transcendence.
#
# Note on strength/agility/vigor/might/intimidation: these do not add to your STARTING stat. Player.gd:_refresh_meta_passives stores them as
# meta_levelup_bonus_* and Player.gd:apply_bonus_stat adds them on top of whatever a level-up's stat CHOICE already grants.
#
# Ids kept from the old tree even where the name changed: "herbalism" is the doc's Field Surgeon (+% healing) and "field_surgeon" the doc's
# Herbalist (cheaper potions in the shop) -- the doc swapped those two names -- and so on (strength = Physical Training, coins = Inheritance...).
const UPGRADE_IDS := [
	# --- hub ---
	"legacy",
	# --- physical ---
	"strength", "agility", "continual_growth", "painful_memories", "reflexes_unlock", "berserker_edge", "adrenaline", "dexterity_unlock", 
	"battle_hardened", "pack_leader", "prodigy", "beastmaster", "pack_bond", "heroic_destiny", "riposte", "momentum", "rage",
	# --- economy ---
	"coins", "intimidation", "luck", "haggling", "silver_muscles", "golden_touch", "fletcher", "field_surgeon", "windfall", "light_metal", 
	"black_market",
	# --- sustain ---
	"stamina", "vigor", "resilience_unlock", "take_a_breather", "second_breath", "potions", "herbalism", "vampiric_grit", "block_master", "last_stand", 
	"unbreakable_guard", "worldwalker",
	# --- sorcery ---
	"release_grudge", "deep_well", "innate_power", "smart_savage", "continual_learning",
	# --- cross ---
	"war_profiteer", "battle_medic", "aegis_transcendence", "otherworldly_power",
]
static var UPGRADES := {

	# ================= HUB =================
	"legacy": {"name": "Legacy", "stat_bonus": 1, "costs": [1], "max_level": 1, "description": "The foundation of all mortal power. Unlocks the first upgrade of every branch.", "hub": true},

	# ================= PHYSICAL =================
	"strength": {"name": "Physical Training", "stat_bonus": 1, "costs": [1], "max_level": 1, "description": "Putting a level-up into Strength grants +1 more.", "prereqs": [{"id": "legacy", "min_level": 1}]},
	"agility": {"name": "Endurance Training", "stat_bonus": 10, "costs": [1], "max_level": 1, "description": "Putting a level-up into Agility grants +10 more.", "prereqs": [{"id": "legacy", "min_level": 1}]},
	"continual_growth": {"name": "Continual Growth", "stat_bonus": 1, "costs": [2], "max_level": 1, "description": "Putting a level-up into Might grants +1 more.", "prereqs": [{"id": "legacy", "min_level": 1}]},
	"painful_memories": {"name": "Painful Memories", "stat_bonus": 1, "costs": [2], "max_level": 1, "description": "Unlocks the Rage stat: it grows by +1 every level-up and joins the level-up choices. Every point of Rage makes Berserk hit harder, shrug off more damage and act sooner.", "prereqs": [{"id": "legacy", "min_level": 1}]},
	"reflexes_unlock": {"name": "Sharp Mind", "stat_bonus": 1, "costs": [2], "max_level": 1, "description": "Unlocks Reflexes as a level-up choice -- 0.5% chance per point owned to fully dodge an incoming hit, capped at 15%.", "prereqs": [{"id": "strength", "min_level": 1}, {"id": "agility", "min_level": 1}, {"id": "vigor", "min_level": 1}]},
	"berserker_edge": {"name": "Pure Spite", "stat_bonus": 0.01, "costs": [2, 3, 4, 6, 10], "max_level": 5, "description": "+1% chance per level for ANY attack, with any weapon, to strike twice -- stacks with a weapon's own double-hit passive.", "prereqs": [{"id": "strength", "min_level": 1}]},
	"adrenaline": {"name": "Adrenaline", "stat_bonus": 0.08, "costs": [4, 6, 9], "max_level": 3, "description": "+8% extra damage DEALT per level while below 30% HP.", "prereqs": [{"id": "reflexes_unlock", "min_level": 1}, {"id": "agility", "min_level": 1}]},
	"dexterity_unlock": {"name": "Deft Fingers", "stat_bonus": 1, "costs": [1], "max_level": 1, "description": "Unlocks Dexterity as a level-up choice -- 0.5% chance per point owned for an attack to critically strike (double damage, ignores cover), capped at 10%.", "prereqs": [{"id": "vigor", "min_level": 1}, {"id": "strength", "min_level": 1}]},
	"battle_hardened": {"name": "Friends in High Places", "stat_bonus": 1, "costs": [1], "max_level": 1, "description": "Puts the Knight within reach: find him in the Ruined Settlement and he joins your party. Unlocks the party system, and dismissing party members for a while.", "prereqs": [{"id": "berserker_edge", "min_level": 5}, {"id": "adrenaline", "min_level": 3}]},
	"pack_leader": {"name": "Leader's Instincts", "stat_bonus": 1, "costs": [15, 22], "max_level": 2, "description": "+1 max party slot per level.", "prereqs": [{"id": "vigor", "min_level": 1}, {"id": "battle_hardened", "min_level": 1}]},
	"prodigy": {"name": "Scholar", "stat_bonus": 1, "costs": [1], "max_level": 1, "description": "The level-up bonus-stat choice grants +2 instead of +1.", "prereqs": [{"id": "pack_leader", "min_level": 2}]},
	"beastmaster": {"name": "Man's Best Friend", "stat_bonus": 1, "costs": [1], "max_level": 1, "description": "Every run starts with a Traitor Wolf already in your pack, loyal for 25 battles.", "prereqs": [{"id": "pack_leader", "min_level": 2}]},
	"pack_bond": {"name": "Pack Bond", "stat_bonus": 4, "costs": [40, 60, 90], "max_level": 3, "description": "Your wolves stay 4 battles longer per level before they leave your pack.", "prereqs": [{"id": "beastmaster", "min_level": 1}]},
	"heroic_destiny": {"name": "Heroic Destiny", "stat_bonus": 1, "costs": [1], "max_level": 1, "description": "You start every run with a wooden club and a wooden shield.", "prereqs": [{"id": "battle_hardened", "min_level": 1}]},
	"riposte": {"name": "Riposte", "stat_bonus": 0.02, "costs": [8, 12, 18, 27], "max_level": 4, "description": "+2% chance per level, when Reflexes fully dodges a hit, to immediately counter-attack whoever swung at you for 50% damage.", "prereqs": [{"id": "adrenaline", "min_level": 3}, {"id": "dexterity_unlock", "min_level": 1}]},
	"momentum": {"name": "Momentum", "stat_bonus": 0.08, "costs": [4, 6, 9, 13, 20], "max_level": 5, "description": "+8% damage per level for the rest of the battle, per enemy you defeat this battle -- stacks, resets each fight.", "prereqs": [{"id": "berserker_edge", "min_level": 5}]},
	"rage": {"name": "RAGE", "stat_bonus": 0.1, "costs": [8, 12, 18, 27, 40], "max_level": 5, "description": "+10% bonus damage per level while Berserk is active (every 5th enemy to fall sends you into Berserk).", "prereqs": [{"id": "momentum", "min_level": 5}, {"id": "adrenaline", "min_level": 3}]},

	# ================= ECONOMY =================
	"coins": {"name": "Inheritance", "stat_bonus": 15, "costs": [1, 2, 3, 5, 8], "max_level": 5, "description": "+15 starting coins per level.", "prereqs": [{"id": "legacy", "min_level": 1}]},
	"intimidation": {"name": "Presence", "stat_bonus": 1, "costs": [2], "max_level": 1, "description": "Putting a level-up into Intimidation grants +1 more (cheaper shops sooner).", "prereqs": [{"id": "coins", "min_level": 5}]},
	"luck": {"name": "Good Fortune", "stat_bonus": 0.15, "costs": [2], "max_level": 1, "description": "Improves shop weapon-tier odds toward Fine, Masterwork, and Legendary.", "prereqs": [{"id": "coins", "min_level": 5}]},
	"haggling": {"name": "Magpie", "stat_bonus": 0.05, "costs": [4, 6, 9, 13, 20], "max_level": 5, "description": "+5% bonus coins per level from every source.", "prereqs": [{"id": "intimidation", "min_level": 1}]},
	"silver_muscles": {"name": "Silver Muscles", "stat_bonus": 5, "costs": [8], "max_level": 1, "description": "Every weapon special costs 5 less stamina, with any weapon you equip.", "prereqs": [{"id": "luck", "min_level": 1}, {"id": "haggling", "min_level": 5}]},
	"golden_touch": {"name": "Merchant's Favour", "stat_bonus": 1, "costs": [15], "max_level": 1, "description": "Every shop visit offers one extra weapon, guaranteed Fine quality or better.", "prereqs": [{"id": "silver_muscles", "min_level": 1}]},
	"fletcher": {"name": "Fletcher", "stat_bonus": 0.05, "costs": [4, 6, 9], "max_level": 3, "description": "Special arrows cost 5% less per level, and you can hold 3 more of each per level.", "prereqs": [{"id": "luck", "min_level": 1}]},
	"field_surgeon": {"name": "Herbalist", "stat_bonus": 0.01, "costs": [8, 12, 18, 27, 40], "max_level": 5, "description": "Healing potions in the shop cost 1% less per level.", "prereqs": [{"id": "potions", "min_level": 2}]},
	"windfall": {"name": "Keen Eye", "stat_bonus": 0.1, "costs": [8, 12, 18], "max_level": 3, "description": "+10% chance per level for a defeated enemy to drop a bonus 1-3 gold.", "prereqs": [{"id": "haggling", "min_level": 5}, {"id": "intimidation", "min_level": 1}]},
	"light_metal": {"name": "Light Metal", "stat_bonus": 1, "costs": [25], "max_level": 1, "description": "Weapons ask for half the Might to wield (rounded up).", "prereqs": [{"id": "rage", "min_level": 5}, {"id": "golden_touch", "min_level": 1}]},
	"black_market": {"name": "Black Market", "stat_bonus": 0.2, "costs": [40, 60, 90], "max_level": 3, "description": "Shop rerolls cost 20% less per level.", "prereqs": [{"id": "silver_muscles", "min_level": 1}, {"id": "light_metal", "min_level": 1}]},

	# ================= SUSTAIN =================
	"stamina": {"name": "Deep Lungs", "stat_bonus": 20, "costs": [1, 1, 2], "max_level": 3, "description": "+20 max Stamina per level.", "prereqs": [{"id": "legacy", "min_level": 1}]},
	"vigor": {"name": "Dense Muscles", "stat_bonus": 2, "costs": [1], "max_level": 1, "description": "Putting a level-up into Vigor grants +2 more.", "prereqs": [{"id": "legacy", "min_level": 1}]},
	"resilience_unlock": {"name": "Leather Skin", "stat_bonus": 1, "costs": [2], "max_level": 1, "description": "Unlocks Resilience as a level-up choice -- +1 Defense per point owned, pooled with your armour. Defense has diminishing returns and never passes 80% reduction.", "prereqs": [{"id": "stamina", "min_level": 3}]},
	"take_a_breather": {"name": "Take a Breather", "stat_bonus": 1, "costs": [2], "max_level": 1, "description": "Defending (the way you skip a turn) heals you for 1/16 of your max HP.", "prereqs": [{"id": "stamina", "min_level": 3}]},
	"second_breath": {"name": "Full Breath", "stat_bonus": 5, "costs": [2, 3], "max_level": 2, "description": "+5 Stamina automatically at the start of every one of your turns, per level.", "prereqs": [{"id": "stamina", "min_level": 3}]},
	"potions": {"name": "Preparations", "stat_bonus": 1, "costs": [4, 6], "max_level": 2, "description": "+1 healing item at the start of every run, per level.", "prereqs": [{"id": "resilience_unlock", "min_level": 1}]},
	"herbalism": {"name": "Field Surgeon", "stat_bonus": 0.05, "costs": [8, 12, 18, 27, 40], "max_level": 5, "description": "+5% bonus healing per level from every healing item.", "prereqs": [{"id": "potions", "min_level": 2}]},
	"vampiric_grit": {"name": "Bloodlust", "stat_bonus": 0.05, "costs": [8], "max_level": 1, "description": "+5% lifesteal on every hit, with any weapon.", "prereqs": [{"id": "potions", "min_level": 2}]},
	"block_master": {"name": "Parry Master", "stat_bonus": 0.1, "costs": [4, 6, 9], "max_level": 3, "description": "+10% chance per level to completely negate a hit while Defending.", "prereqs": [{"id": "resilience_unlock", "min_level": 1}]},
	"last_stand": {"name": "Last Stand", "stat_bonus": 0.01, "costs": [8, 12, 18, 27, 40], "max_level": 5, "description": "+1% damage reduction per level for every 10% of your HP you're missing.", "prereqs": [{"id": "adrenaline", "min_level": 3}, {"id": "block_master", "min_level": 3}]},
	"unbreakable_guard": {"name": "Unbreakable Guard", "stat_bonus": 1, "costs": [25], "max_level": 1, "description": "Your equipped shield stays active even with a two-handed weapon equipped. Needs every other Sustain upgrade, fully bought.", "prereqs": [{"id": "stamina", "min_level": 3}, {"id": "resilience_unlock", "min_level": 1}, {"id": "take_a_breather", "min_level": 1}, {"id": "second_breath", "min_level": 2}, {"id": "potions", "min_level": 2}, {"id": "herbalism", "min_level": 5}, {"id": "vampiric_grit", "min_level": 1}, {"id": "block_master", "min_level": 3}, {"id": "last_stand", "min_level": 5}]},
	"worldwalker": {"name": "Worldwalker", "stat_bonus": 1, "costs": [1], "max_level": 1, "description": "The strength you earned conquering the Nothingness -- always-on +15% max HP and +10% damage. Unlocked only after beating the game once.", "requires_lifetime_flag": "game_completed_ever"},

	# ================= SORCERY =================
	"release_grudge": {"name": "Release Grudge", "stat_bonus": 1, "costs": [2], "max_level": 1, "description": "Allows the recruitment of magical party members (the Druid, the Necromancer, the Shaman) and unlocks the Magic stat for every party member (not you), who also gain +1 Magic every level-up.", "prereqs": [{"id": "legacy", "min_level": 1}]},
	"deep_well": {"name": "Deep Well", "stat_bonus": 20, "costs": [8], "max_level": 1, "description": "+20 max mana for every caster in your party (a Necromancer's mana is her HP: 5 mana is 1 HP).", "prereqs": [{"id": "release_grudge", "min_level": 1}]},
	"innate_power": {"name": "Innate Power", "stat_bonus": 0.33, "costs": [15], "max_level": 1, "description": "+33% potency on every spell.", "prereqs": [{"id": "deep_well", "min_level": 1}]},
	"smart_savage": {"name": "Smart Savage", "stat_bonus": 1, "costs": [10], "max_level": 1, "description": "Unlocks Fortitude as a level-up choice, and it grows by +1 every level-up. Fortitude has diminishing returns and never passes 80% reduction of MAGICAL harm.", "prereqs": [{"id": "legacy", "min_level": 1}]},
	"continual_learning": {"name": "Continual Learning", "stat_bonus": 1, "costs": [10], "max_level": 1, "description": "Unlocks Intelligence, which grows by +1 every level-up. (Intelligence is not a stat in the game yet, so this does nothing until it is.)", "prereqs": [{"id": "legacy", "min_level": 1}]},

	# ================= CROSS =================
	"war_profiteer": {"name": "War Profiteer", "stat_bonus": 0.002, "costs": [25], "max_level": 1, "description": "Every enemy you defeat in a run makes the shops 0.2% cheaper, for the rest of that run.", "prereqs": [{"id": "battle_hardened", "min_level": 1}, {"id": "golden_touch", "min_level": 1}]},
	"battle_medic": {"name": "Battle Medic", "stat_bonus": 5, "costs": [25], "max_level": 1, "description": "Using a healing item in battle deals 5 damage to every enemy.", "prereqs": [{"id": "potions", "min_level": 2}, {"id": "pack_leader", "min_level": 2}]},
	"aegis_transcendence": {"name": "Aegis & Transcendence", "stat_bonus": 0.1, "costs": [40], "max_level": 1, "description": "Walk into a shop with a full stamina bar and it is 10% cheaper, for every full 100 Stamina you carry.", "prereqs": [{"id": "golden_touch", "min_level": 1}, {"id": "unbreakable_guard", "min_level": 1}]},
	"otherworldly_power": {"name": "Otherworldly Power", "stat_bonus": 1, "costs": [184], "max_level": 1, "description": "Allows the wizards to breach the veil. Unlocks the true ending. Needs every other upgrade, fully bought.", "requires_all": true},
}

# Version of the tree above. A save from before the rebuild (no `church_version`, or an older one) has its Church upgrades refunded -- at the
# prices it paid for them, from LEGACY_COSTS (version 1) or V2_COSTS (version 2, the short-lived first rebuild) -- the first time it loads, and
# starts the new tree empty.
const CHURCH_VERSION := 3
# What the OLD tree charged: id -> [base_cost, cost_step] (a level cost base + step * levels already owned).
const LEGACY_COSTS := {
	"strength": [15, 8], "agility": [15, 8], "vigor": [15, 8], "reflexes_unlock": [20, 12], "berserker_edge": [30, 18], "adrenaline": [30, 18],
	"dexterity_unlock": [25, 15], "battle_hardened": [350, 0], "pack_leader": [500, 0], "prodigy": [450, 0], "warlord": [600, 0],
	"beastmaster": [300, 0], "pack_bond": [200, 100], "riposte": [35, 20], "momentum": [40, 25], "rage": [45, 25], "hardened": [150, 80],
	"coins": [10, 6], "intimidation": [15, 8], "luck": [20, 12], "haggling": [20, 12], "silver_tongue": [120, 0], "appraisal": [25, 15],
	"golden_touch": [350, 0], "investor": [200, 0], "fletcher": [60, 30], "field_surgeon": [90, 45], "windfall": [50, 25], "black_market": [80, 40],
	"stamina": [15, 8], "resilience_unlock": [18, 10], "warded_mind": [20, 12], "mental_mush": [30, 18], "smort_savage": [40, 0],
	"potions": [25, 15], "herbalism": [20, 12], "vampiric_grit": [30, 18], "vigilant_defense": [30, 18], "undying": [350, 0], "second_wind": [60, 30],
	"block_master": [35, 20], "second_breath": [25, 15], "favour": [250, 100], "last_stand": [50, 30], "shield_mastery": [35, 20],
	"unbreakable_guard": [250, 0], "worldwalker": [400, 0], "warband": [400, 0], "battle_medic": [250, 0], "war_chest": [250, 0], "war_profiteer": [200, 0],
}

# What buying every level of every upgrade costs in all.
static func total_tree_cost() -> int:
	var total := 0
	for id in UPGRADE_IDS:
		for level in int(UPGRADES[id].get("max_level", 1)):
			total += get_upgrade_cost(id, level)
	return total

# The Essence a save paid for the upgrades it owns under the OLD tree (version 1).
static func legacy_refund(owned: Dictionary) -> int:
	var refund := 0
	for id in owned:
		var prices: Array = LEGACY_COSTS.get(id, [0, 0])
		for level in int(owned[id]):
			refund += int(prices[0]) + int(prices[1]) * level
	return refund

# What the first rebuild (version 2) charged: id -> the price of each level in turn.
const V2_COSTS := {
	"legacy": [1],
	"strength": [1],
	"agility": [1],
	"vigor": [1],
	"reflexes_unlock": [2],
	"berserker_edge": [2,3,4,6,10],
	"adrenaline": [4,6,9],
	"dexterity_unlock": [1],
	"battle_hardened": [1],
	"pack_leader": [15,22],
	"prodigy": [1],
	"beastmaster": [1],
	"pack_bond": [40,60,90],
	"heroic_destiny": [1],
	"riposte": [8,12,18,27],
	"momentum": [4,6,9,13,20],
	"rage": [8,12,18,27,40],
	"coins": [1],
	"intimidation": [2],
	"luck": [2],
	"haggling": [4,6,9,13,20],
	"silver_muscles": [8],
	"golden_touch": [15],
	"fletcher": [4,6,9],
	"field_surgeon": [8,12,18,27,40],
	"windfall": [8,12,18],
	"light_metal": [25],
	"black_market": [40,60,90],
	"stamina": [1,1,2],
	"resilience_unlock": [2],
	"take_a_breather": [2],
	"second_breath": [2,3],
	"potions": [4,6],
	"herbalism": [8,12,18,27,40],
	"vampiric_grit": [8],
	"block_master": [4,6,9],
	"last_stand": [8,12,18,27,40],
	"unbreakable_guard": [25],
	"worldwalker": [1],
	"release_grudge": [2],
	"deep_well": [4,6,9],
	"steady_flow": [8,12],
	"thrifty_casting": [4,6,9],
	"arcane_training": [8],
	"spell_echo": [2,3,4,6,10],
	"intellect": [4],
	"innate_power": [15],
	"essence_tithe": [8,12,18],
	"warded_mind": [2],
	"mental_mush": [4,6,9],
	"smort_savage": [8],
	"war_profiteer": [25],
	"battle_medic": [25],
	"aegis_transcendence": [40],
	"otherworldly_power": [184],
}

# The Essence a save paid under the first rebuild (version 2).
static func v2_refund(owned: Dictionary) -> int:
	var refund := 0
	for id in owned:
		var prices: Array = V2_COSTS.get(id, [])
		for level in mini(int(owned[id]), prices.size()):
			refund += int(prices[level])
	return refund

# A save from the old tree, brought up to date: upgrades emptied, their cost back in Essence, the version stamped.
static func migrate_church(data: Dictionary) -> Dictionary:
	var owned: Dictionary = data.get("upgrades", {}) if typeof(data.get("upgrades", {})) == TYPE_DICTIONARY else {}
	data["essence"] = int(data.get("essence", 0)) + (legacy_refund(owned) if int(data.get("church_version", 1)) < 2 else v2_refund(owned))
	data["upgrades"] = {}
	data["church_version"] = CHURCH_VERSION
	return data

# 3 independent save slots, each locking in a difficulty the moment it's
# created (see init_slot) -- mult scales both enemy HP/damage (Main.gd:
# _setup_battle_grid, via Player.difficulty_mult) and essence earned
# (record_run_result) by the same number. An Array, not a Dict, so the title
# screen's difficulty picker can render it in a fixed, meaningful order.
static var DIFFICULTIES := [
	{"id": "baby", "name": "Baby Mode", "mult": 0.75, "description": "Enemies have 75% HP and deal 75% damage. Gentler runs, less Essence earned."},
	{"id": "normal", "name": "Normal Mode", "mult": 1.0, "description": "Enemies at standard HP and damage. The intended experience."},
	{"id": "hard", "name": "Hard Mode", "mult": 1.75, "description": "Enemies have 175% HP and deal 175% damage. A real fight, more Essence earned."},
	{"id": "apocalyptic", "name": "Apocalyptic", "mult": 3.0, "description": "Enemies have 300% HP and deal 300% damage. Brutal -- but Essence earned triples too."},
]

# Which of the 3 slots the rest of the game reads/writes. Set once by
# TitleScreen.gd before changing to Main.tscn; a static var persists for the
# whole process, the same mechanism the Z-keybind InputMap change already
# relies on surviving a scene change.
static var active_slot := 1

# Sandbox mode (Sandbox.gd / SandboxPanel.gd, the title screen's Sandbox button):
# while sandbox_active is set, every load/save below reads and writes an
# in-memory copy instead of the real slot / lifetime files, so a sandbox session
# can never change Essence, Church upgrades, the Beastiary or lifetime stats.
# The tutorial and the Worldwalker lock are treated as already cleared.
static var sandbox_active := false
static var sandbox_data: Dictionary = {}
static var sandbox_lifetime: Dictionary = {"tutorial_completed_ever": true, "game_completed_ever": true}

static func get_difficulty_mult(difficulty_id: String) -> float:
	for d in DIFFICULTIES:
		if d.id == difficulty_id:
			return d.mult
	return 1.0

# Any script invoked via `--script res://tools/test_*.gd` (every headless
# test in this project) is redirected to a scratch save file instead of the
# real one, so running the test suite can never read or clobber the actual
# player's persisted Essence/upgrades. `slot` defaults to whichever slot is
# currently active -- callers that need a SPECIFIC slot regardless of
# active_slot (slot_exists/slot_summary/init_slot, so the title screen can
# inspect a slot before switching to it) pass one explicitly.
static func _resolve_save_path(slot: int = -1) -> String:
	var s: int = slot if slot > 0 else active_slot
	for arg in OS.get_cmdline_args():
		if arg.contains("res://tools/test_"):
			return "user://test_save_data_slot_%d.json" % s
	return "user://save_slot_%d.json" % s

static func load_data() -> Dictionary:
	var data := {"essence": 0, "upgrades": {}, "best_wave": 0, "church_version": CHURCH_VERSION}
	if sandbox_active:
		for key in sandbox_data:
			data[key] = sandbox_data[key].duplicate(true) if typeof(sandbox_data[key]) in [TYPE_DICTIONARY, TYPE_ARRAY] else sandbox_data[key]
		return data
	var path := _resolve_save_path()
	if not FileAccess.file_exists(path):
		return data
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return data
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		# A save from before the Church was rebuilt gets its upgrades refunded, once, and starts the new tree empty.
		if int(parsed.get("church_version", 1)) < CHURCH_VERSION:
			parsed = migrate_church(parsed)
			var fw := FileAccess.open(path, FileAccess.WRITE)
			if fw != null:
				fw.store_string(JSON.stringify(parsed))
				fw.close()
		for key in parsed:
			data[key] = parsed[key]
	return data

static func save_data(data: Dictionary) -> void:
	if sandbox_active:
		sandbox_data = data.duplicate(true)
		return
	# Anything saved from here is in the current tree's format (a legacy file is migrated by load_data before it is ever saved).
	if not data.has("church_version"):
		data["church_version"] = CHURCH_VERSION
	var f := FileAccess.open(_resolve_save_path(), FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()

# True if slot `n` has ever been played (has a file on disk) -- false means
# the title screen should offer the difficulty picker instead of loading it.
static func slot_exists(n: int) -> bool:
	return FileAccess.file_exists(_resolve_save_path(n))

# Read-only glance at a slot's progress for the title screen's Select Save
# buttons, without making it the active slot. Empty Dictionary for a slot
# that's never been played.
static func slot_summary(n: int) -> Dictionary:
	if not slot_exists(n):
		return {}
	var f := FileAccess.open(_resolve_save_path(n), FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var difficulty_id: String = parsed.get("difficulty", "")
	var difficulty_name := "Hard Mode"
	for d in DIFFICULTIES:
		if d.id == difficulty_id:
			difficulty_name = d.name
			break
	# (a save from before the Church was rebuilt is shown as it will be once loaded: refunded, owning nothing yet)
	if int(parsed.get("church_version", 1)) < CHURCH_VERSION:
		parsed = migrate_church(parsed.duplicate(true))
	# How many Church upgrade levels the file owns in all (what the file select shows beside its Essence).
	var upgrade_levels := 0
	var owned: Dictionary = parsed.get("upgrades", {}) if typeof(parsed.get("upgrades", {})) == TYPE_DICTIONARY else {}
	for id in owned:
		upgrade_levels += int(owned[id])
	return {
		"name": parsed.get("name", "Slot %d" % n),
		"essence": parsed.get("essence", 0),
		"upgrades": upgrade_levels,
		"best_wave": parsed.get("best_wave", 0),
		"difficulty_id": difficulty_id,
		"difficulty_name": difficulty_name,
	}

# Creates a fresh slot `n`, locking in `difficulty_id` for the lifetime of
# that save -- there is no way to change it later short of starting over on
# that slot, matching "you can't change the difficulty once you start a
# save." Writes directly to slot `n`'s path regardless of active_slot; the
# caller (TitleScreen.gd) sets active_slot = n afterward. An empty/blank
# `name` falls back to "Slot N" -- naming a save is optional, not required.
static func init_slot(n: int, difficulty_id: String, name: String = "") -> void:
	var f := FileAccess.open(_resolve_save_path(n), FileAccess.WRITE)
	if f == null:
		return
	var save_name: String = name if name != "" else "Slot %d" % n
	f.store_string(JSON.stringify({"essence": 0, "upgrades": {}, "best_wave": 0, "church_version": CHURCH_VERSION, "difficulty": difficulty_id, "name": save_name}))
	f.close()

# Renames an already-played slot in place -- everything else (essence,
# upgrades, best_wave, difficulty) is read back off disk and rewritten
# untouched. A no-op if the slot's never been played (nothing to rename).
# Writes directly to slot `n`'s path regardless of active_slot, same as
# init_slot -- renaming a save from the picker never touches the save you're
# actually about to play.
static func rename_slot(n: int, new_name: String) -> void:
	if not slot_exists(n):
		return
	var path := _resolve_save_path(n)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	parsed["name"] = new_name if new_name != "" else "Slot %d" % n
	var fw := FileAccess.open(path, FileAccess.WRITE)
	if fw == null:
		return
	fw.store_string(JSON.stringify(parsed))
	fw.close()

# Duplicates slot `from`'s entire save (essence, upgrades, best_wave,
# difficulty, name) into slot `to`, overwriting whatever `to` already had.
# The copy's name gets " (Copy)" appended so two slots never show the exact
# same name and get mixed up in the picker. A no-op if `from` doesn't exist
# or the two slots are the same -- there's nothing to copy in either case.
# Writes directly to both slots' paths regardless of active_slot, same as
# every other slot-management function here.
static func copy_slot(from: int, to: int) -> void:
	if not slot_exists(from) or from == to:
		return
	var f := FileAccess.open(_resolve_save_path(from), FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		parsed["name"] = "%s (Copy)" % parsed.get("name", "Slot %d" % from)
		text = JSON.stringify(parsed)
	var fw := FileAccess.open(_resolve_save_path(to), FileAccess.WRITE)
	if fw == null:
		return
	fw.store_string(text)
	fw.close()

# Removes the slot's file entirely -- essence, upgrades, best_wave, difficulty,
# all of it -- so slot_exists(n) reads false and the title screen offers it as
# [New Game] again. Dying no longer does this (a death only ends the run, the
# slot's Essence and upgrades persist); it's now just the player's own "Clear"
# choice on the Select Save screen.
static func delete_slot(n: int) -> void:
	var path := _resolve_save_path(n)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

# Settings (keybinds/volume) are a device/player preference, not tied to
# which save is active -- their own file, independent of active_slot, so
# switching slots never resets a keybind or volume level.
static func _resolve_settings_path() -> String:
	for arg in OS.get_cmdline_args():
		if arg.contains("res://tools/test_"):
			return "user://test_settings.json"
	return "user://settings.json"

static func load_settings() -> Dictionary:
	var path := _resolve_settings_path()
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}

static func save_settings(data: Dictionary) -> void:
	var f := FileAccess.open(_resolve_settings_path(), FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()

# Lifetime progress (World Progression feature's Nothingness boss rush) --
# a third, device-level file alongside the 3 numbered save slots and
# settings.json, deliberately never touched by delete_slot. A slot can be
# cleared or copied over, but "have you ever beaten the game" needs to survive
# that on any slot -- see Main.gd's Nothingness completion
# handling and the Worldwalker skill node below, which is gated on
# game_completed_ever rather than a normal prereq.
static func _resolve_lifetime_path() -> String:
	for arg in OS.get_cmdline_args():
		if arg.contains("res://tools/test_"):
			return "user://test_lifetime_progress.json"
	return "user://lifetime_progress.json"

static func load_lifetime_data() -> Dictionary:
	if sandbox_active:
		return sandbox_lifetime.duplicate(true)
	var path := _resolve_lifetime_path()
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}

static func save_lifetime_data(data: Dictionary) -> void:
	if sandbox_active:
		sandbox_lifetime = data.duplicate(true)
		return
	var f := FileAccess.open(_resolve_lifetime_path(), FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()

static func is_game_completed_ever() -> bool:
	return load_lifetime_data().get("game_completed_ever", false)

static func mark_game_completed() -> void:
	var data := load_lifetime_data()
	data.game_completed_ever = true
	save_lifetime_data(data)

# The Druid is freed for good the first time the Lizen Encampment is cleared out: from then on she waits in the HeartWood
# at the start of every run (see Main.gd's druid section).
static func is_druid_unlocked() -> bool:
	return load_lifetime_data().get("druid_unlocked_ever", false)

static func mark_druid_unlocked() -> void:
	var data := load_lifetime_data()
	data.druid_unlocked_ever = true
	save_lifetime_data(data)

static func is_tutorial_completed_ever() -> bool:
	return load_lifetime_data().get("tutorial_completed_ever", false)

static func mark_tutorial_completed() -> void:
	var data := load_lifetime_data()
	data.tutorial_completed_ever = true
	save_lifetime_data(data)

static func is_unlock_seen(key: String) -> bool:
	return load_lifetime_data().get("seen_unlocks", {}).get(key, false)

static func mark_unlock_seen(key: String) -> void:
	var data := load_lifetime_data()
	if not data.has("seen_unlocks"):
		data.seen_unlocks = {}
	data.seen_unlocks[key] = true
	save_lifetime_data(data)

# Atomic check-and-mark -- true only the first time `key` is ever seen,
# false on every later call (any run, any slot, forever). Callers use this
# directly instead of pairing the two functions above themselves.
static func try_mark_unlock_seen(key: String) -> bool:
	if is_unlock_seen(key):
		return false
	mark_unlock_seen(key)
	return true

# Beastiary: which creatures (ENEMY_TRAITS/HUD.ENEMY_ICONS display names)
# the player has ever clicked as a battle target or defeated, on ANY save
# slot -- device-wide and permanent, same shape as seen_unlocks above, just
# its own key so the two collections never mix. Main.gd calls
# mark_creature_seen from _on_enemy_target_selected (click) and
# _on_enemy_died (defeat); the Beastiary screen itself only ever reads.
static func is_creature_seen(name: String) -> bool:
	return load_lifetime_data().get("beastiary_seen", {}).get(name, false)

static func mark_creature_seen(name: String) -> void:
	if name == "" or is_creature_seen(name):
		return
	var data := load_lifetime_data()
	if not data.has("beastiary_seen"):
		data.beastiary_seen = {}
	data.beastiary_seen[name] = true
	save_lifetime_data(data)

# Run-end aggregates, updated on EVERY run-end (death or victory alike) --
# unlike game_completed_ever, these don't gate anything, they're purely for
# the title screen's Stats display. world_reached_index is only used here to
# decide whether this run set a new deepest-world record; the name string is
# what's actually persisted for display, so this file never needs to know
# WORLDS' own contents.
static func record_lifetime_run_stats(kills_by_name: Dictionary, world_reached_name: String, world_reached_index: int, bosses_defeated: int) -> void:
	var data := load_lifetime_data()
	data.total_runs = data.get("total_runs", 0) + 1
	var kills_total := 0
	for enemy_name in kills_by_name:
		kills_total += int(kills_by_name[enemy_name])
	data.lifetime_kills = data.get("lifetime_kills", 0) + kills_total
	data.total_bosses_defeated = data.get("total_bosses_defeated", 0) + bosses_defeated
	if world_reached_index >= data.get("deepest_world_index", -1):
		data.deepest_world_index = world_reached_index
		data.deepest_world_ever = world_reached_name
	save_lifetime_data(data)

# What the next level of a node costs, with `owned_level` levels already bought (a level past the top costs the last price).
static func get_upgrade_cost(id: String, owned_level: int) -> int:
	var costs: Array = UPGRADES[id].costs
	return int(costs[clampi(owned_level, 0, costs.size() - 1)])

# True if every one of `id`'s prereqs (it may have zero, one, or several --
# a converging node has more than one) is satisfied by what's currently
# owned -- checked separately from try_buy_upgrade so the title screen can
# render a locked node's state without attempting a purchase.
static func is_upgrade_unlocked(data: Dictionary, id: String) -> bool:
	# Otherworldly Power wants EVERY other upgrade, each at its top level.
	if UPGRADES[id].get("requires_all", false):
		var held: Dictionary = data.get("upgrades", {})
		for other in UPGRADE_IDS:
			if other != id and int(held.get(other, 0)) < int(UPGRADES[other].get("max_level", 1)):
				return false
		return true
	# Worldwalker's gate: a lifetime (cross-slot, survives permadeath) flag
	# instead of a normal prereq -- see load_lifetime_data above. Checked
	# first since a node can have this AND (in principle) real prereqs too.
	var lifetime_flag: String = UPGRADES[id].get("requires_lifetime_flag", "")
	if lifetime_flag != "" and not load_lifetime_data().get(lifetime_flag, false):
		return false
	var prereqs: Array = UPGRADES[id].get("prereqs", [])
	if prereqs.is_empty():
		return true
	var owned_upgrades: Dictionary = data.get("upgrades", {})
	for prereq in prereqs:
		if owned_upgrades.get(prereq.id, 0) < prereq.min_level:
			return false
	return true

# True if at least one skill can be bought right now: not at its max level, its
# prerequisites (and any lifetime gate) met, and enough Essence for its next
# level. The Church door's marker (Main.gd:refresh_church_marker) uses this.
static func can_buy_any_upgrade(data: Dictionary) -> bool:
	var owned_upgrades: Dictionary = data.get("upgrades", {})
	var essence: int = data.get("essence", 0)
	for id in UPGRADE_IDS:
		var owned: int = owned_upgrades.get(id, 0)
		if owned >= UPGRADES[id].get("max_level", 999999):
			continue
		if essence < get_upgrade_cost(id, owned):
			continue
		if is_upgrade_unlocked(data, id):
			return true
	return false

# The Essence banked in the active slot (what the Church and the Wizard's Tower's spell upgrades spend).
static func banked_essence() -> int:
	return int(load_data().get("essence", 0))

# Spends banked Essence outside the Church (the Wizard's Tower's spell upgrades); false if there is not enough.
static func try_spend_essence(cost: int) -> bool:
	var data := load_data()
	if int(data.get("essence", 0)) < cost:
		return false
	data.essence = int(data.get("essence", 0)) - cost
	save_data(data)
	return true

# Mutates `data` in place (caller is expected to have gotten it from
# load_data() and to persist it afterward with save_data()).
static func try_buy_upgrade(data: Dictionary, id: String) -> bool:
	var owned_upgrades: Dictionary = data.get("upgrades", {})
	var owned: int = owned_upgrades.get(id, 0)
	if owned >= UPGRADES[id].get("max_level", 999999):
		return false
	if not is_upgrade_unlocked(data, id):
		return false
	var cost := get_upgrade_cost(id, owned)
	if data.get("essence", 0) < cost:
		return false
	data.essence = data.get("essence", 0) - cost
	if not data.has("upgrades"):
		data.upgrades = {}
	data.upgrades[id] = owned + 1
	return true

# Banks the essence a finished run earned and returns the amount, for display
# on the game-over screen. raw_essence is what the run tallied up (see
# Main.gd:run_essence); it is scaled here by the active slot's locked-in
# difficulty -- harder modes pay out more Essence, same multiplier that makes
# their enemies tougher (Main.gd:_setup_battle_grid). waves_reached only feeds
# the slot's best_wave record.
static func record_run_result(raw_essence: int, waves_reached: int = 0) -> int:
	if sandbox_active:
		return 0
	var data := load_data()
	var mult: float = get_difficulty_mult(data.get("difficulty", ""))
	var earned: int = int(round(max(0, raw_essence) * mult))
	data.essence = data.get("essence", 0) + earned
	data.best_wave = max(data.get("best_wave", 0), waves_reached)
	save_data(data)
	return earned

# Every owned permanent upgrade's total stat bonus, applied once when a new
# run's Player is created.
static func get_applied_bonuses() -> Dictionary:
	var data := load_data()
	var owned: Dictionary = data.get("upgrades", {})
	var bonuses := {}
	for id in UPGRADE_IDS:
		bonuses[id] = UPGRADES[id].stat_bonus * int(owned.get(id, 0))
	return bonuses
