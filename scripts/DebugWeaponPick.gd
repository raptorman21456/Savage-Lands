extends RefCounted

# The weapon builder the Items and Party tabs share: pick a base (Spear...), a quality tier and a material and see the result, the
# way the game builds weapons (Weapons.gd: base x tier x material, with a Mythic being a fixed named artifact that takes no material).

const DebugKitScript := preload("res://scripts/DebugKit.gd")
const DebugActionsScript := preload("res://scripts/DebugActions.gd")
const WeaponsScript := preload("res://scripts/Weapons.gd")

# Tier and material names, best last, as the game has them.
static func tiers() -> Array:
	var out: Array = []
	for t in WeaponsScript.TIERS:
		out.append(str(t.tier_name))
	return out

static func materials() -> Array:
	var out: Array = []
	for m in WeaponsScript.MATERIALS:
		out.append([str(m.id), str(m.name)])
	return out

# Fixes a selection that does not make sense (a Mythic Club, a material on a Mythic...) and fills in defaults.
static func normalise(st: Dictionary) -> void:
	var bases: Array = DebugActionsScript.weapon_bases()
	var ids: Array = bases.map(func(b): return str(b.id))
	if not st.has("base") or not ids.has(str(st.base)):
		st["base"] = "spear"
	if not st.has("tier") or not tiers().has(str(st.tier)):
		st["tier"] = "Fine"
	if not st.has("material") or WeaponsScript.find_material(str(st.material)).is_empty():
		st["material"] = "steel"
	if str(st.base) == "club":
		return
	if str(st.tier) == "Mythic" and not WeaponsScript.MYTHIC_WEAPONS.has(str(st.base)):
		st["tier"] = "Fine"

# The weapon the selection makes ({} if it makes none).
static func variant_of(st: Dictionary) -> Dictionary:
	normalise(st)
	return DebugActionsScript.build_weapon(str(st.base), str(st.tier), str(st.material))

# Adds the three pickers to `parent` (the selection lives in `st`; on_change() is called after each pick so the view can rebuild) and
# returns the weapon it currently describes.
static func build(parent: Node, st: Dictionary, on_change: Callable, show_base: bool = true) -> Dictionary:
	normalise(st)
	var base_id := str(st.base)
	var is_club: bool = base_id == "club"
	var is_mythic: bool = str(st.tier) == "Mythic" and not is_club
	var pick := func(key: String, value) -> void:
		st[key] = value
		on_change.call()
	# base (the Items tab picks it in its grid instead)
	if show_base:
		var bases: Array = []
		for b in DebugActionsScript.weapon_bases():
			bases.append([str(b.id), str(b.name) + (" (party)" if WeaponsScript.is_ally_only(b) else "")])
		var base_row: HBoxContainer = DebugKitScript.row(parent, "Weapon", 110.0)
		DebugKitScript.choice_row(base_row, bases, base_id, func(id): pick.call("base", id))
	if not is_club:
		var tier_opts: Array = []
		for t in tiers():
			if t == "Mythic" and not WeaponsScript.MYTHIC_WEAPONS.has(base_id):
				continue
			tier_opts.append([t, t])
		var tier_row: HBoxContainer = DebugKitScript.row(parent, "Quality", 110.0)
		DebugKitScript.choice_row(tier_row, tier_opts, str(st.tier), func(id): pick.call("tier", id))
		var material_row: HBoxContainer = DebugKitScript.row(parent, "Material", 110.0)
		if is_mythic:
			material_row.add_child(PixelKit.label("A Mythic is a fixed artifact: it takes no material.", "body", PixelKit.DIM))
		else:
			DebugKitScript.choice_row(material_row, materials(), str(st.material), func(id): pick.call("material", id))
	return variant_of(st)
