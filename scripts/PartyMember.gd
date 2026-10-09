extends RefCounted
class_name PartyMember

const PartyRulesScript := preload("res://scripts/PartyRules.gd")
const DefenseScript := preload("res://scripts/Defense.gd")
const ArmorScript := preload("res://scripts/Armor.gd")
const ShieldsScript := preload("res://scripts/Shields.gd")

# One recruited party member for the length of a run: who they are, how far they
# have levelled, what they wear and (for a wolf) how many battles of loyalty are
# left. The rules and starting numbers live in PartyRulesScript.gd; this holds the state
# and turns it into the stats a battle needs.
#
# Stats are kept as floats (a Druid's attack grows 0.5 at a time) and rounded only
# where a whole number is needed.

var id := 0
var kind := ""
var name := ""
var level := 1
var xp := 0
# Bonus picks earned by levelling and not yet spent (spent in the Party screen).
var picks := 0
# Everything gained on top of the starting stats, already scaled by the kind's growth.
var bonus := {"hp": 0.0, "attack": 0.0, "defense": 0.0, "speed": 0.0, "magic": 0.0, "fortitude": 0.0}
# Wolves: times it has fainted this run (it dies for good at PartyRulesScript.WOLF_MAX_FAINTS),
# and how many battles of loyalty remain (-1 = no limit).
var faints := 0
var battles_left := -1
# What it wears: weapon / armor / shield are item ids ("" = nothing), talismans a list.
var gear := {"weapon": "", "armor": "", "shield": "", "talismans": []}
# The specials it brings into a fight, picked on the Party screen from its pool (its kit's specials plus the
# equipped weapon's): PartyRules.SPECIAL_SLOTS ids, "" = an empty slot. Until the player picks anything
# (loadout_set), the first slots' worth of the pool are used.
var special_loadout: Array = []
var loadout_set := false
# Druid spells the Wizard's Tower has upgraded ({spell_id: true}).
var upgraded_spells := {}
# Kills it has made: this battle's tally, and the last battle's (the Necromancer's Summon the Dead
# raises one skeleton per kill of the LAST battle). Main.gd:_make_member_battle_unit rolls the
# tally over at the start of each battle.
var kills_this_battle := 0
var kills_last_battle := 0

# --- Gear ---------------------------------------------------------------------------
# Item rules (who may hold what) live in Player.gd, which knows the whole collection; this just
# answers questions about what the member currently wears.

func can_carry_gear() -> bool:
	return PartyRulesScript.can_carry_gear(kind)

func weapon_id() -> String:
	return str(gear.get("weapon", ""))

func talisman_ids() -> Array:
	return gear.get("talismans", [])

# --- Special loadout -----------------------------------------------------------------
# pool_ids = every special id it could use right now, kit first (Main.gd:_ally_special_pool).

# The ids it will actually have in battle, in slot order.
func resolved_loadout(pool_ids: Array) -> Array:
	var out: Array = []
	if not loadout_set:
		for id in pool_ids:
			if out.size() < PartyRulesScript.SPECIAL_SLOTS:
				out.append(str(id))
		return out
	for id in special_loadout:
		if str(id) != "" and pool_ids.has(str(id)) and not out.has(str(id)) and out.size() < PartyRulesScript.SPECIAL_SLOTS:
			out.append(str(id))
	return out

# What slot `index` holds ("" when empty) -- the auto-filled default until the player has picked.
func loadout_slot(index: int, pool_ids: Array) -> String:
	if not loadout_set:
		var auto := resolved_loadout(pool_ids)
		return str(auto[index]) if index < auto.size() else ""
	return str(special_loadout[index]) if index < special_loadout.size() else ""

# Puts a special (or "" to empty the slot) into a slot. The first change freezes the auto-filled default
# so the other slots stay as they were. A special already in another slot moves out of it.
func set_loadout_slot(index: int, id: String, pool_ids: Array) -> void:
	if index < 0 or index >= PartyRulesScript.SPECIAL_SLOTS:
		return
	var slots: Array = []
	for i in PartyRulesScript.SPECIAL_SLOTS:
		slots.append(loadout_slot(i, pool_ids))
	if id != "":
		for i in slots.size():
			if slots[i] == id:
				slots[i] = ""
	slots[index] = id
	special_loadout = slots
	loadout_set = true

func reset_loadout() -> void:
	special_loadout = []
	loadout_set = false

func armor_id() -> String:
	return str(gear.get("armor", ""))

func shield_id() -> String:
	return str(gear.get("shield", ""))

# The armour it wears, as the full Armor.gd entry ({} = none).
func armor_dict() -> Dictionary:
	return ArmorScript.find(armor_id()) if armor_id() != "" else {}

# The shield it carries, as the full Shields.gd entry ({} = none).
func shield_dict() -> Dictionary:
	return ShieldsScript.SHIELDS.get(shield_id(), {}) if shield_id() != "" else {}

# A shield only does anything while a hand is free for it: bare hands or a one-handed weapon
# (Shields.COMPATIBLE_WEAPONS). The Knight is the exception -- it can hold a shield alongside a
# two-handed weapon.
func shield_usable() -> bool:
	if shield_dict().is_empty():
		return false
	if bool(rules().get("shield_with_two_handed", false)):
		return true
	return weapon_id() == "" or ShieldsScript.is_weapon_compatible(weapon_id())

# The shield special's power (thorns / vengeance / knockback flag), stronger with the weapon the
# shield was designed around -- the same rule the hero's shield follows.
func shield_special_pct() -> float:
	var sh: Dictionary = shield_dict()
	if sh.is_empty():
		return 0.0
	if ShieldsScript.base_weapon_id(weapon_id()) == str(sh.get("synergy_weapon", "")):
		return float(sh.get("synergy_special_pct", 0.0))
	return float(sh.get("special_pct", 0.0))

func talisman_slot_count() -> int:
	return PartyRulesScript.talisman_slots(kind, level)

# The summed effects of everything it wears (the same vocabulary as the hero's talismans).
func talisman_effects() -> Dictionary:
	return PartyRulesScript.TalismansScript.sum_effects(talisman_ids())

# Everything that modifies its combat: its talismans plus the favour buffs its kind gets from
# the weapon in hand (weapon_base_id = "staff", "greatsword"...). Favour buffs use the same key
# vocabulary as talismans (damage_pct, crit_chance, special_stamina_discount...), plus
# range_bonus; the structural keys "weapon" and "magic_mult" are read separately.
func effect_mods(weapon_base_id: String) -> Dictionary:
	var mods := talisman_effects()
	var favour: Dictionary = PartyRulesScript.favour_for(kind, weapon_base_id)
	for key in favour:
		if key == "weapon" or key == "weapons" or key == "magic_mult":
			continue
		mods[key] = float(mods.get(key, 0.0)) + float(favour[key])
	# A kind's perks apply whatever it is holding (the Brawler's double-hit and crit chance).
	var perks: Dictionary = PartyRulesScript.perks_for(kind)
	for key in perks:
		mods[key] = float(mods.get(key, 0.0)) + float(perks[key])
	return mods

static func create(member_id: int, member_kind: String) -> PartyMember:
	var m := PartyMember.new()
	m.id = member_id
	m.kind = member_kind
	m.name = PartyRulesScript.rules(member_kind).get("name", member_kind.capitalize())
	return m

func rules() -> Dictionary:
	return PartyRulesScript.rules(kind)

func is_wolf() -> bool:
	return PartyRulesScript.is_wolf(kind)

func levels() -> bool:
	return PartyRulesScript.levels(kind)

# The stats a bonus pick may go into (a Guardian's speed is fixed, a Marksman's defense is).
func pickable_stats() -> Array:
	return rules().get("stats", [])

# --- Stats --------------------------------------------------------------------------

# Starting value plus everything gained, before any final multiplier.
func raw_stat(stat_name: String) -> float:
	return float(rules().get("base", {}).get(stat_name, 0.0)) + float(bonus.get(stat_name, 0.0))

# The displayed value: a non-levelling kind (the wolf) scales its base by fixed multipliers.
func stat(stat_name: String) -> float:
	return raw_stat(stat_name) * float(rules().get("final_mult", {}).get(stat_name, 1.0))

func max_hp() -> int:
	return maxi(1, int(round(stat("hp"))))

func attack() -> float:
	return stat("attack")

# Points of Defense against bodily harm (Defense.gd bends them into a cut with diminishing returns).
func defense_pct() -> float:
	var r := rules()
	if r.has("defense_fixed"):
		return float(r.defense_fixed)
	return maxf(0.0, stat("defense"))

# The most of its bodily and magical harm this member can ever shrug off.
func defense_cap() -> float:
	return float(rules().get("defense_cap", DefenseScript.BASE_CAP))

func speed() -> float:
	return stat("speed")

func magic() -> float:
	return stat("magic")

# Protection against magical harm: a starting value and growth multiplier per kind (PartyRules), grown by
# levelling and by bonus picks like any other stat. No damage reads it until the armour rework lands.
func fortitude() -> float:
	return stat("fortitude")

func is_caster() -> bool:
	return bool(rules().get("caster", false))

func max_mana() -> int:
	return int(round(magic() * PartyRulesScript.MANA_PER_MAGIC)) if is_caster() else 0

func max_stamina() -> int:
	return int(rules().get("stamina", 0))

# Tiles it can move in a battle turn.
func move_tiles() -> int:
	var move: Dictionary = rules().get("move", {})
	if move.has("fixed"):
		return int(move.fixed)
	var rating := raw_stat("speed")
	var tiles: float
	if move.has("per_speed"):
		tiles = float(move.get("base", PartyRulesScript.BASE_MOVE_TILES)) + float(move.per_speed) * rating
	else:
		tiles = float(PartyRulesScript.BASE_MOVE_TILES) + floorf((rating - PartyRulesScript.SPEED_START) / PartyRulesScript.SPEED_PER_EXTRA_TILE)
	tiles *= float(move.get("tile_mult", 1.0))
	return maxi(int(move.get("min", 1)), int(floorf(tiles + 0.0001)))

# --- Levelling ----------------------------------------------------------------------

func xp_to_next() -> int:
	return PartyRulesScript.xp_to_next(level)

# Adds XP and levels up as many times as it earns; returns how many levels were gained.
func gain_xp(amount: int) -> int:
	if not levels() or amount <= 0:
		return 0
	var gained := 0
	xp += amount
	while level < PartyRulesScript.MAX_LEVEL and xp >= xp_to_next():
		xp -= xp_to_next()
		_level_up()
		gained += 1
	if level >= PartyRulesScript.MAX_LEVEL:
		xp = 0
	return gained

# Every level: a passive gain to each stat, and one bonus pick to spend later.
func _level_up() -> void:
	level += 1
	picks += 1
	for stat_name in PartyRulesScript.STAT_NAMES:
		bonus[stat_name] += PartyRulesScript.PASSIVE_GAIN[stat_name] * PartyRulesScript.growth(kind, stat_name)

# Spends one bonus pick on a stat. False if there is no pick left or the kind cannot
# improve that stat.
func spend_pick(stat_name: String) -> bool:
	if picks <= 0 or not (stat_name in pickable_stats()):
		return false
	bonus[stat_name] += PartyRulesScript.PICK_GAIN[stat_name] * PartyRulesScript.growth(kind, stat_name)
	picks -= 1
	return true

# --- Wolves ----------------------------------------------------------------------------

# Counts one fainting; true once it has fainted enough times to die for good.
func record_faint() -> bool:
	faints += 1
	return is_wolf() and faints >= PartyRulesScript.WOLF_MAX_FAINTS

# One battle of loyalty gone. True when there is none left (the wolf leaves).
func spend_loyalty_battle() -> bool:
	if battles_left < 0:
		return false
	battles_left -= 1
	return battles_left <= 0
