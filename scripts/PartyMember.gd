extends RefCounted
class_name PartyMember

const PartyRulesScript := preload("res://scripts/PartyRules.gd")

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
var bonus := {"hp": 0.0, "attack": 0.0, "defense": 0.0, "speed": 0.0, "magic": 0.0}
# Wolves: times it has fainted this run (it dies for good at PartyRulesScript.WOLF_MAX_FAINTS),
# and how many battles of loyalty remain (-1 = no limit).
var faints := 0
var battles_left := -1
# What it wears: weapon / armor / shield are item ids ("" = nothing), talismans a list.
var gear := {"weapon": "", "armor": "", "shield": "", "talismans": []}
# Druid spells the Wizard's Tower has upgraded ({spell_id: true}).
var upgraded_spells := {}

# --- Gear ---------------------------------------------------------------------------
# Item rules (who may hold what) live in Player.gd, which knows the whole collection; this just
# answers questions about what the member currently wears.

func can_carry_gear() -> bool:
	return PartyRulesScript.can_carry_gear(kind)

func weapon_id() -> String:
	return str(gear.get("weapon", ""))

func talisman_ids() -> Array:
	return gear.get("talismans", [])

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
		if key == "weapon" or key == "magic_mult":
			continue
		mods[key] = float(mods.get(key, 0.0)) + float(favour[key])
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

# Defense is a percentage cut to incoming damage: one point is one percent.
func defense_pct() -> float:
	var r := rules()
	if r.has("defense_fixed"):
		return float(r.defense_fixed)
	return maxf(0.0, stat("defense"))

func speed() -> float:
	return stat("speed")

func magic() -> float:
	return stat("magic")

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
	return maxi(1, int(floorf(tiles + 0.0001)))

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
