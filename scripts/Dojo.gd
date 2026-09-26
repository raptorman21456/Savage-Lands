extends Node
class_name Dojo

# The town Dojo: weapons no longer start with their special moves -- each of a
# weapon type's three specials has to be learned here, per run, for coins (see
# Player.gd:learned_specials/try_learn_special, and the two gates that refuse
# an unlearned special: HUD.gd's Fight submenu and Main.gd:_battle_player_special).
#
# Specials belong to the weapon's BASE type (Spear, Hammer, ...), not to any
# one variant: learning "Piercing Thrust" teaches it for every Spear you'll
# ever hold -- Worn, Masterwork, Golden -- exactly because special ids are
# stable across variants.

const WeaponsScript := preload("res://scripts/Weapons.gd")

# Price of a weapon type's 1st / 2nd / 3rd move, in that order. The economy is
# small (a kill is ~1-2 coins), so the first lesson is a handful of fights
# away and the third is a real goal.
const LESSON_COSTS := [15, 35, 60]

# Cost of the special at this index in its weapon's `specials` array.
static func lesson_cost(slot_index: int) -> int:
	return LESSON_COSTS[clampi(slot_index, 0, LESSON_COSTS.size() - 1)]

# Every weapon base type that has moves to learn, Club first. Bow uses arrows
# instead of specials, so it never appears.
static func teachable_bases() -> Array:
	var result := [WeaponsScript.CLUB]
	for base in WeaponsScript.UPGRADABLE_TYPES:
		if not base.get("specials", []).is_empty():
			result.append(base)
	return result

# Where a special id lives: {"base": <weapon base dict>, "index": <slot in that
# base's specials array>, "special": <the special dict>}, or {} if no weapon
# has it. The slot decides the lesson's price.
static func locate_special(special_id: String) -> Dictionary:
	for base in teachable_bases():
		var specials: Array = base.specials
		for i in specials.size():
			if specials[i].id == special_id:
				return {"base": base, "index": i, "special": specials[i]}
	return {}

# The base types the player currently owns at least one variant of, in
# teaching order -- the Dojo only offers lessons for weapons you actually hold.
static func owned_bases(owned_weapons: Dictionary) -> Array:
	var owned_base_ids := {}
	for id in owned_weapons:
		var base: Dictionary = WeaponsScript.get_base_type({"id": id})
		if not base.is_empty():
			owned_base_ids[base.id] = true
	var result := []
	for base in teachable_bases():
		if owned_base_ids.has(base.id):
			result.append(base)
	return result
