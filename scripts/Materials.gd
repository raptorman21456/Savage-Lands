extends RefCounted
class_name Materials

# Crafting materials dropped by enemies. The pelt armours (Armor.gd entries with a "recipe") are made
# from them at the Blacksmith. Player.materials holds the counts for the run.
#
# DROPS is keyed by the enemy's display name -> a list of {id, chance, min, max}. Only enemies that
# exist today are listed; Bear Pelts, Spider Silk and Feathers come from enemies that have yet to be
# added -- when they are, add their rows here and they start dropping (the Sandbox can hand out any
# material meanwhile). Every chance and amount is a DRAFT.

const ITEMS := {
	"dragon_scale": {"name": "Dragon Scale", "description": "A hard, warm scale prised from a dragon's hide. Dragonskin Plating is made of these."},
	"mage_hair": {"name": "Mage Hair", "description": "A lock of wiry hair, still crackling faintly. Needed for Bloodrage Hide."},
	"bear_pelt": {"name": "Bear Pelt", "description": "A thick, heavy bear pelt. Needed for Bloodrage Hide."},
	"spider_silk": {"name": "Spider Silk", "description": "Fine, strong, nearly invisible thread. Shadowweave is spun from it."},
	"feather": {"name": "Feather", "description": "A long, light feather. Windrunner's Jerkin is stitched with them."},
}

const DROPS := {
	"Black Dragonlet": [{"id": "dragon_scale", "chance": 1.0, "min": 2, "max": 4}],
	"White Dragon": [{"id": "dragon_scale", "chance": 1.0, "min": 3, "max": 5}],
	"Red Wyrm": [{"id": "dragon_scale", "chance": 1.0, "min": 3, "max": 5}],
	"Apprentice Mage": [{"id": "mage_hair", "chance": 0.35, "min": 1, "max": 1}],
}

static func name_of(id: String) -> String:
	return str(ITEMS.get(id, {}).get("name", id))

# What one defeated enemy drops this time: {material_id: count}. Rolled with the given RNG
# so tests can be exact.
static func roll_drops(enemy_name: String, rng: RandomNumberGenerator = null) -> Dictionary:
	var out := {}
	for row in DROPS.get(enemy_name, []):
		var roll: float = rng.randf() if rng != null else randf()
		if roll >= float(row.chance):
			continue
		var lo: int = int(row.min)
		var hi: int = int(row.max)
		var n: int = (rng.randi_range(lo, hi) if rng != null else randi_range(lo, hi))
		out[row.id] = int(out.get(row.id, 0)) + n
	return out

# "8 Dragon Scale + 120 coins"-style text for a recipe.
static func recipe_text(recipe: Dictionary) -> String:
	var parts: Array = []
	for id in recipe.get("materials", {}):
		parts.append("%d %s" % [int(recipe.materials[id]), name_of(str(id))])
	if int(recipe.get("coins", 0)) > 0:
		parts.append("%d coins" % int(recipe.coins))
	return " + ".join(parts)
