extends Node
class_name SaveData

# Persistent meta-progression: Essence earned on death (based on waves
# cleared that run) banks permanently and buys permanent starting-stat
# upgrades from the title screen, applied to every future run. This is what
# makes death matter instead of just resetting everything to zero.
const ESSENCE_PER_WAVE_CLEARED := 8

# A real tree: 3 wings (Warrior/Merchant/Survivor), each splitting into two
# sub-paths partway down that reconverge at that wing's capstone, plus
# cross-wing convergence nodes that need investment from TWO different
# wings, plus deep/capstone-tier nodes past that carrying the most
# impactful abilities -- the most powerful things sit furthest from the
# roots. `prereqs` (an Array of {id, min_level}, AND logic -- every entry
# must be satisfied) gates a node; an empty array is a root. `max_level`
# caps a node's purchases -- everything without one is unlimited (checked
# via .get() with a huge default).
#
# Note on strength/agility/vigor/intimidation: these no longer add straight
# to your STARTING stat. Player.gd:_apply_meta_upgrades stores them as
# meta_levelup_bonus_* instead, and Player.gd:apply_bonus_stat adds them on
# top of whatever a level-up's stat CHOICE already grants -- e.g. owning
# Might at level 2 turns a level-up's "+1 Strength" choice into "+3
# Strength" (1 base + 2 from the skill). The stat_bonus numbers themselves
# are unchanged from before; only WHEN they apply changed.
const UPGRADE_IDS := [
	"strength", "agility", "vigor", "reflexes_unlock", "berserker_edge", "adrenaline",
	"dexterity_unlock",
	"battle_hardened", "pack_leader", "prodigy", "warlord", "beastmaster", "pack_bond",
	"riposte", "momentum", "rage", "hardened",
	"coins", "intimidation", "luck", "haggling", "silver_tongue", "appraisal",
	"golden_touch", "investor",
	"fletcher", "field_surgeon", "windfall", "black_market",
	"stamina", "resilience_unlock", "potions", "herbalism", "vampiric_grit", "vigilant_defense",
	"undying", "second_wind", "block_master", "second_breath",
	"favour", "last_stand", "shield_mastery", "unbreakable_guard", "worldwalker",
	"warband", "battle_medic", "war_chest", "war_profiteer",
]
static var UPGRADES := {
	# --- Warrior wing: combat stats, splitting into a raw-power path
	# (Vitality -> Berserker's Edge) and a finesse path (Precision ->
	# Adrenaline) that reconverge at the Blade Ally capstone, which then
	# splits three ways into the wing's deepest, most powerful nodes. ---
	# Renamed from "Might" -- that name now belongs to the new core Might
	# stat (see the "dexterity_unlock"/"resilience_unlock"/"reflexes_unlock"
	# nodes below and Player.gd:stat_might), a wholly separate mechanic.
	"strength": {"name": "Brawn", "stat_bonus": 1, "base_cost": 15, "cost_step": 8, "description": "Choosing Strength on level-up grants +1 more per level owned, instead of a flat starting bonus."},
	"agility": {"name": "Swiftness", "stat_bonus": 10, "base_cost": 15, "cost_step": 8, "description": "Choosing Agility on level-up grants +10 more per level owned, instead of a flat starting bonus.", "prereqs": [{"id": "strength", "min_level": 1}]},
	"vigor": {"name": "Vitality", "stat_bonus": 2, "base_cost": 15, "cost_step": 8, "description": "Choosing Vigor on level-up grants +2 more per level owned, instead of a flat starting bonus.", "prereqs": [{"id": "agility", "min_level": 1}]},
	# Renamed from "Precision" -- no longer a %/level dodge node itself, just
	# the unlock gate for the new Reflexes level-up stat (Player.gd:
	# stat_reflexes / meta_dodge_chance). A single purchase, not a scaling one.
	"reflexes_unlock": {"name": "Reflexes", "stat_bonus": 1, "base_cost": 20, "cost_step": 12, "max_level": 1, "description": "Unlocks Reflexes as a level-up choice -- 0.75% chance per point owned to fully dodge an incoming hit, capped at 15%.", "prereqs": [{"id": "agility", "min_level": 1}]},
	"berserker_edge": {"name": "Berserker's Edge", "stat_bonus": 0.08, "base_cost": 30, "cost_step": 18, "description": "+8% chance per level for ANY attack, with any weapon, to strike twice -- stacks with a weapon's own double-hit passive.", "prereqs": [{"id": "vigor", "min_level": 1}]},
	"adrenaline": {"name": "Adrenaline", "stat_bonus": 0.08, "base_cost": 30, "cost_step": 18, "max_level": 3, "description": "+8% extra damage DEALT per level while below 30% HP -- a berserker's edge when the fight turns desperate.", "prereqs": [{"id": "reflexes_unlock", "min_level": 1}]},
	# New branch off Reflexes' old root (Agility, via Berserker's Edge/
	# Vigor's neighborhood) -- unlocks the new Dexterity level-up stat
	# (Player.gd:stat_dexterity / meta_crit_chance), a crit mechanic that
	# doubles damage and ignores the rock-cover reduction.
	"dexterity_unlock": {"name": "Dexterity", "stat_bonus": 1, "base_cost": 25, "cost_step": 15, "max_level": 1, "description": "Unlocks Dexterity as a level-up choice -- 0.75% chance per point owned for an attack to critically strike (double damage, ignores cover), capped at 15%.", "prereqs": [{"id": "agility", "min_level": 1}]},
	# stat_bonus is now just an ownership flag (get_applied_bonuses() needs a
	# nonzero value to report this as owned) -- the real effect is the Blade
	# Ally companion, applied via Player.has_blade_ally, not a stat delta.
	# Both the power path (Berserker's Edge) and the finesse path
	# (Adrenaline) feed into it -- the wing's two branches reconverging.
	"battle_hardened": {"name": "Blade Ally", "stat_bonus": 1, "base_cost": 350, "cost_step": 0, "max_level": 1, "description": "Warrior capstone -- a combat companion joins every battle and auto-attacks once per turn, scaling with your own Strength.", "prereqs": [{"id": "berserker_edge", "min_level": 3}, {"id": "adrenaline", "min_level": 2}]},
	# A further Warrior-wing unlock past the capstone itself -- stat_bonus
	# is again just an ownership flag, the real effect is +1 max party slot
	# (Player.max_party_slots), applied in Player.gd:_apply_meta_upgrades.
	"pack_leader": {"name": "Pack Leader", "stat_bonus": 1, "base_cost": 500, "cost_step": 0, "max_level": 1, "description": "+1 max party slot (3 total) -- a second recruited ally can now fight alongside your Blade Ally.", "prereqs": [{"id": "battle_hardened", "min_level": 1}]},
	# Three deep nodes split off Pack Leader -- the wing's most powerful,
	# furthest-from-the-root abilities.
	"prodigy": {"name": "Prodigy", "stat_bonus": 1, "base_cost": 450, "cost_step": 0, "max_level": 1, "description": "The level-up bonus-stat choice now grants +2 instead of +1.", "prereqs": [{"id": "pack_leader", "min_level": 1}]},
	"warlord": {"name": "Warlord", "stat_bonus": 1, "base_cost": 600, "cost_step": 0, "max_level": 1, "description": "+1 more max party slot (4 total).", "prereqs": [{"id": "pack_leader", "min_level": 1}]},
	"beastmaster": {"name": "Beastmaster", "stat_bonus": 1, "base_cost": 300, "cost_step": 0, "max_level": 1, "description": "Every run starts with a Traitor Wolf already in your pack -- no need to find and defeat one.", "prereqs": [{"id": "pack_leader", "min_level": 1}]},
	"pack_bond": {"name": "Pack Bond", "stat_bonus": 3, "base_cost": 200, "cost_step": 100, "max_level": 3, "description": "Your Traitor Wolf's loyalty lasts 3 waves longer per level before it leaves your pack.", "prereqs": [{"id": "beastmaster", "min_level": 1}]},
	"riposte": {"name": "Riposte", "stat_bonus": 0.1, "base_cost": 35, "cost_step": 20, "max_level": 4, "description": "+10% chance per level, when Reflexes fully dodges a hit, to immediately counter-attack whoever swung at you for 50% damage.", "prereqs": [{"id": "reflexes_unlock", "min_level": 1}]},
	"momentum": {"name": "Momentum", "stat_bonus": 0.03, "base_cost": 40, "cost_step": 25, "max_level": 5, "description": "+3% damage per level for the rest of the battle, per enemy you defeat this battle -- stacks, resets each fight.", "prereqs": [{"id": "berserker_edge", "min_level": 1}]},
	# Powers the Berserk state (Main.gd:_on_enemy_died triggers it, +50%
	# base damage while active) -- Rage adds on top of that base bonus.
	"rage": {"name": "Rage", "stat_bonus": 0.1, "base_cost": 45, "cost_step": 25, "max_level": 5, "description": "+10% bonus damage per level while Berserk is active (triggered by killing an enemy mid-battle).", "prereqs": [{"id": "momentum", "min_level": 1}]},
	"hardened": {"name": "Hardened", "stat_bonus": 2, "base_cost": 150, "cost_step": 80, "max_level": 3, "description": "+2 max HP per level for every wave you clear this run, permanently stacking for the rest of that run.", "prereqs": [{"id": "pack_leader", "min_level": 1}]},

	# --- Merchant wing: economy stats, splitting into a shop-quality path
	# (Fortune -> Silver Tongue) and an income path (Haggling -> Appraisal)
	# that reconverge at the Merchant Prince capstone. ---
	"coins": {"name": "Nest Egg", "stat_bonus": 15, "base_cost": 10, "cost_step": 6, "description": "+15 starting coins per level."},
	"intimidation": {"name": "Presence", "stat_bonus": 1, "base_cost": 15, "cost_step": 8, "description": "Choosing Intimidation on level-up grants +1 more per level owned (cheaper shops sooner), instead of a flat starting bonus.", "prereqs": [{"id": "coins", "min_level": 1}]},
	"luck": {"name": "Fortune", "stat_bonus": 0.15, "base_cost": 20, "cost_step": 12, "description": "Improves shop weapon-tier odds toward Fine, Masterwork, and Legendary.", "prereqs": [{"id": "intimidation", "min_level": 1}]},
	"haggling": {"name": "Haggling", "stat_bonus": 0.1, "base_cost": 20, "cost_step": 12, "max_level": 5, "description": "+10% bonus coins per level from every source.", "prereqs": [{"id": "intimidation", "min_level": 1}]},
	"silver_tongue": {"name": "Silver Tongue", "stat_bonus": 1, "base_cost": 120, "cost_step": 0, "max_level": 1, "description": "Every weapon special costs 0 stamina, permanently, with any weapon you ever equip.", "prereqs": [{"id": "luck", "min_level": 1}]},
	"appraisal": {"name": "Appraisal", "stat_bonus": 20, "base_cost": 25, "cost_step": 15, "description": "+20 starting coins per level, stacking with Nest Egg.", "prereqs": [{"id": "haggling", "min_level": 1}]},
	# stat_bonus is now just an ownership flag -- the real effect is the
	# guaranteed bonus shop item, applied via Player.has_merchant_prince.
	# Both the shop-quality path (Silver Tongue) and the income path
	# (Appraisal) feed into it.
	"golden_touch": {"name": "Merchant Prince", "stat_bonus": 1, "base_cost": 350, "cost_step": 0, "max_level": 1, "description": "Merchant capstone -- every shop visit offers one extra weapon, guaranteed Masterwork quality or better.", "prereqs": [{"id": "silver_tongue", "min_level": 1}, {"id": "appraisal", "min_level": 1}]},
	"investor": {"name": "Investor", "stat_bonus": 3, "base_cost": 200, "cost_step": 0, "max_level": 1, "description": "The shop rolls 3 more weapon options every visit.", "prereqs": [{"id": "golden_touch", "min_level": 1}]},
	"fletcher": {"name": "Fletcher", "stat_bonus": 0.15, "base_cost": 60, "cost_step": 30, "max_level": 3, "description": "Special arrows cost 15% less per level, and you can hold 5 more of each per level.", "prereqs": [{"id": "haggling", "min_level": 1}]},
	"field_surgeon": {"name": "Field Surgeon", "stat_bonus": 0.15, "base_cost": 90, "cost_step": 45, "max_level": 2, "description": "Merchant + Survivor convergence -- healing potions in the shop cost 15% less per level.", "prereqs": [{"id": "appraisal", "min_level": 1}, {"id": "potions", "min_level": 1}]},
	"windfall": {"name": "Windfall", "stat_bonus": 0.2, "base_cost": 50, "cost_step": 25, "max_level": 3, "description": "+20% chance per level for a defeated enemy to drop a bonus 5-15 gold windfall.", "prereqs": [{"id": "haggling", "min_level": 1}]},
	"black_market": {"name": "Black Market", "stat_bonus": 0.2, "base_cost": 80, "cost_step": 40, "max_level": 3, "description": "Shop rerolls cost 20% less per level.", "prereqs": [{"id": "silver_tongue", "min_level": 1}]},

	# --- Survivor wing: sustain stats, splitting into a lifesteal path
	# (Provisions -> Vampiric Grit) and a recovery path (Herbalism ->
	# Resilience) that reconverge at the Guardian's Ultimatum capstone. ---
	"stamina": {"name": "Endurance", "stat_bonus": 15, "base_cost": 15, "cost_step": 8, "description": "+15 max Stamina per level (more room for Heavy Attacks and specials)."},
	# Renamed from "Fortitude" -- no longer a %/level damage-reduction node
	# itself, just the unlock gate for the new Resilience level-up stat
	# (Player.gd:stat_resilience / resilience_reduction). A single purchase.
	"resilience_unlock": {"name": "Resilience", "stat_bonus": 1, "base_cost": 18, "cost_step": 10, "max_level": 1, "description": "Unlocks Resilience as a level-up choice -- 1% damage reduction per point owned, capped at 20%, stacking with armor.", "prereqs": [{"id": "stamina", "min_level": 1}]},
	"potions": {"name": "Provisions", "stat_bonus": 1, "base_cost": 25, "cost_step": 15, "description": "+1 healing item at the start of every run.", "prereqs": [{"id": "resilience_unlock", "min_level": 1}]},
	"herbalism": {"name": "Herbalism", "stat_bonus": 0.15, "base_cost": 20, "cost_step": 12, "max_level": 5, "description": "+15% bonus healing per level from every healing item.", "prereqs": [{"id": "resilience_unlock", "min_level": 1}]},
	"vampiric_grit": {"name": "Vampiric Grit", "stat_bonus": 0.05, "base_cost": 30, "cost_step": 18, "description": "+5% lifesteal per level on every hit, with any weapon.", "prereqs": [{"id": "potions", "min_level": 1}]},
	# Renamed from "Resilience" -- that name now belongs to the new core
	# Resilience stat above; this node's own effect is unchanged.
	"vigilant_defense": {"name": "Vigilant Defense", "stat_bonus": 3, "base_cost": 30, "cost_step": 18, "description": "Heal 3 HP per level every time you Defend.", "prereqs": [{"id": "herbalism", "min_level": 1}]},
	# stat_bonus is now just an ownership flag -- the real effect is the
	# Guardian's Ultimatum battle skill, applied via Player.has_guardian_skill.
	# Both the lifesteal path (Vampiric Grit) and the recovery path
	# (Vigilant Defense) feed into it.
	"undying": {"name": "Guardian's Ultimatum", "stat_bonus": 1, "base_cost": 350, "cost_step": 0, "max_level": 1, "description": "Survivor capstone -- unlocks a battle Skill: instantly heal 40% of max HP, once every 4 turns.", "prereqs": [{"id": "vampiric_grit", "min_level": 3}, {"id": "vigilant_defense", "min_level": 2}]},
	"second_wind": {"name": "Second Wind", "stat_bonus": 1, "base_cost": 60, "cost_step": 30, "max_level": 2, "description": "+1 healing item at the start of every run, stacking with Provisions.", "prereqs": [{"id": "undying", "min_level": 1}]},
	"block_master": {"name": "Block Master", "stat_bonus": 0.15, "base_cost": 35, "cost_step": 20, "max_level": 3, "description": "+15% chance per level to completely negate all incoming damage while Defending.", "prereqs": [{"id": "resilience_unlock", "min_level": 1}]},
	"second_breath": {"name": "Second Breath", "stat_bonus": 5, "base_cost": 25, "cost_step": 15, "max_level": 4, "description": "+5 Stamina automatically at the start of every one of your turns, stacking with everything else.", "prereqs": [{"id": "stamina", "min_level": 1}]},
	# Renamed from "Second Chance" -- was a guaranteed once-per-battle save;
	# now a %/level chance (Player.gd:meta_favour_chance) on ANY hit that
	# would drop you to 0 HP, still only ever once per battle.
	"favour": {"name": "Favour", "stat_bonus": 0.01, "base_cost": 250, "cost_step": 100, "max_level": 5, "description": "1% chance per level, on any hit that would drop you to 0 HP, to survive with 1 HP instead (once per battle), capped at 5%.", "prereqs": [{"id": "undying", "min_level": 1}]},
	"last_stand": {"name": "Last Stand", "stat_bonus": 0.01, "base_cost": 50, "cost_step": 30, "max_level": 5, "description": "+1% damage reduction per level for every 10% HP you're missing -- the more hurt you are, the tankier you get.", "prereqs": [{"id": "resilience_unlock", "min_level": 1}]},
	"shield_mastery": {"name": "Shield Mastery", "stat_bonus": 0.08, "base_cost": 35, "cost_step": 20, "max_level": 3, "description": "+8% shield block chance per level, on any shield you carry.", "prereqs": [{"id": "resilience_unlock", "min_level": 1}]},
	"unbreakable_guard": {"name": "Unbreakable Guard", "stat_bonus": 1, "base_cost": 250, "cost_step": 0, "max_level": 1, "description": "Your equipped shield stays active even with a two-handed weapon equipped.", "prereqs": [{"id": "shield_mastery", "min_level": 3}]},
	# Gated on a LIFETIME flag (survives permadeath, see
	# load_lifetime_data/mark_game_completed above), not a normal prereq --
	# invisible/unbuyable until the Nothingness boss rush has been cleared
	# once, ever, on any slot; purchasable with essence like any other node
	# from that point on. See Player.gd:meta_worldwalker for the effect.
	"worldwalker": {"name": "Worldwalker", "stat_bonus": 1, "base_cost": 400, "cost_step": 0, "max_level": 1, "description": "The strength you earned conquering the Nothingness -- always-on +15% max HP and +10% damage. Unlocked only after beating the game once.", "requires_lifetime_flag": "game_completed_ever"},

	# --- Cross-wing convergence: each requires investment from TWO
	# different wings, not just one -- the tree's real "converging paths."
	# (field_surgeon above is also cross-wing -- Merchant + Survivor -- kept
	# in the Merchant block since that's where it visually branches off.) ---
	"warband": {"name": "Warband", "stat_bonus": 0.15, "base_cost": 400, "cost_step": 0, "max_level": 1, "description": "Warrior + Merchant convergence -- your recruited party members hit noticeably harder (better-equipped mercenaries).", "prereqs": [{"id": "battle_hardened", "min_level": 1}, {"id": "golden_touch", "min_level": 1}]},
	"battle_medic": {"name": "Battle Medic", "stat_bonus": 1, "base_cost": 250, "cost_step": 0, "max_level": 1, "description": "Survivor + Warrior convergence -- healing items also restore stamina.", "prereqs": [{"id": "potions", "min_level": 1}, {"id": "vigor", "min_level": 1}]},
	"war_chest": {"name": "War Chest", "stat_bonus": 0.05, "base_cost": 250, "cost_step": 0, "max_level": 1, "description": "Merchant + Survivor convergence -- your equipped armor's damage reduction is permanently boosted.", "prereqs": [{"id": "luck", "min_level": 1}, {"id": "resilience_unlock", "min_level": 1}]},
	"war_profiteer": {"name": "War Profiteer", "stat_bonus": 2, "base_cost": 200, "cost_step": 0, "max_level": 3, "description": "Warrior + Merchant convergence -- +2 coins per level for every enemy you defeat.", "prereqs": [{"id": "battle_hardened", "min_level": 1}, {"id": "golden_touch", "min_level": 1}]},
}

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
	var data := {"essence": 0, "upgrades": {}, "best_wave": 0}
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
		for key in parsed:
			data[key] = parsed[key]
	return data

static func save_data(data: Dictionary) -> void:
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
	return {
		"name": parsed.get("name", "Slot %d" % n),
		"essence": parsed.get("essence", 0),
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
	f.store_string(JSON.stringify({"essence": 0, "upgrades": {}, "best_wave": 0, "difficulty": difficulty_id, "name": save_name}))
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

# Permadeath: dying wipes the slot's file entirely -- essence, upgrades,
# best_wave, difficulty, all of it. slot_exists(n) reads false again
# afterward, so the title screen offers it as [New Game] once more.
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
# settings.json, deliberately never touched by delete_slot. Permadeath wipes
# a slot's essence/upgrades/best_wave every time, but "have you ever beaten
# the game" needs to survive that -- see Main.gd's Nothingness completion
# handling and the Worldwalker skill node below, which is gated on
# game_completed_ever rather than a normal prereq.
static func _resolve_lifetime_path() -> String:
	for arg in OS.get_cmdline_args():
		if arg.contains("res://tools/test_"):
			return "user://test_lifetime_progress.json"
	return "user://lifetime_progress.json"

static func load_lifetime_data() -> Dictionary:
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

static func get_upgrade_cost(id: String, owned_level: int) -> int:
	var def: Dictionary = UPGRADES[id]
	return def.base_cost + def.cost_step * owned_level

# True if every one of `id`'s prereqs (it may have zero, one, or several --
# a converging node has more than one) is satisfied by what's currently
# owned -- checked separately from try_buy_upgrade so the title screen can
# render a locked node's state without attempting a purchase.
static func is_upgrade_unlocked(data: Dictionary, id: String) -> bool:
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

# Banks essence for a finished run and returns the amount earned, for
# display on the game-over screen. Scaled by the active slot's locked-in
# difficulty -- harder modes pay out more Essence, same multiplier that
# makes their enemies tougher (Main.gd:_setup_battle_grid).
static func record_run_result(waves_cleared: int) -> int:
	var data := load_data()
	var mult: float = get_difficulty_mult(data.get("difficulty", ""))
	var earned: int = int(round(max(0, waves_cleared) * ESSENCE_PER_WAVE_CLEARED * mult))
	data.essence = data.get("essence", 0) + earned
	data.best_wave = max(data.get("best_wave", 0), waves_cleared)
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
