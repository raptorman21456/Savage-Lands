extends SceneTree

# Dumps every piece of game data the standalone battle simulator
# (tools/battle_sim/) needs into tools/battle_sim/sim_data.json, read straight
# from the real scripts so the simulator can never drift on a number or a name.
# Run, then rebuild the HTML:
#   Godot --headless --path . --script res://tools/export_battle_sim_data.gd
#   bash tools/battle_sim/build.sh

const OUT_DIR := "res://tools/battle_sim"
const OUT_PATH := "res://tools/battle_sim/sim_data.json"

const MainScript := preload("res://scripts/Main.gd")
const PlayerScript := preload("res://scripts/Player.gd")

const ENEMY_SCRIPTS := [
	"Enemy", "Orc", "Archer", "Brute", "Shade", "Wolf", "Centaur", "FaeHut", "Fae", "Gnome",
	"BlackDragonlet", "Treant", "IronConstruct", "LavaConstruct", "Voidwing",
	"Leviathan", "LizenWarband", "ElderOak", "WhiteDragon", "RedWyrm", "Archmage",
]

func _initialize() -> void:
	var data := {}
	data["weapons"] = {
		"club": Weapons.CLUB,
		"bases": Weapons.UPGRADABLE_TYPES,
		"tiers": Weapons.TIERS,
		"materials": Weapons.MATERIALS,
		"mythics": Weapons.MYTHIC_WEAPONS,
		"arrows": Weapons.ARROW_TYPES,
		"consts": _consts(Weapons),
	}
	data["armor"] = Armor.TIERS
	data["clothing"] = Clothing.PIECES
	data["clothing_slots"] = Clothing.SLOTS
	data["shields"] = Shields.SHIELDS
	data["shield_compatible"] = Shields.COMPATIBLE_WEAPONS
	data["potions"] = Potions.TIERS
	data["foods"] = Foods.ITEMS
	data["runes"] = Enchantments.RUNES
	data["blacksmith"] = _consts(Blacksmith)
	data["talismans"] = {
		"items": Talismans.ITEMS,
		"slot_levels": Talismans.SLOT_LEVELS,
		"rarity_colors": {},
	}
	data["upgrades"] = {
		"ids": SaveData.UPGRADE_IDS,
		"defs": SaveData.UPGRADES,
		"difficulties": SaveData.DIFFICULTIES,
	}
	data["party"] = {
		"kinds": PartyRules.KINDS,
		"consts": _consts(PartyRules),
	}
	data["main_consts"] = _consts(MainScript)
	data["player_consts"] = _consts(PlayerScript)
	data["traits"] = MainScript.ENEMY_TRAITS
	data["exported"] = Time.get_datetime_string_from_system()
	data["worlds"] = _worlds()
	data["enemies"] = _enemies()

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f == null:
		push_error("export_battle_sim_data: cannot write %s" % OUT_PATH)
		quit(1)
		return
	f.store_string(JSON.stringify(_clean(data), "\t"))
	f.close()
	print("export_battle_sim_data: wrote %s" % ProjectSettings.globalize_path(OUT_PATH))
	quit()

# Every plain-value constant on a script (numbers, strings, bools, arrays,
# dictionaries) -- skips scripts, textures and colours, which the sim has no use for.
func _consts(script: Script) -> Dictionary:
	var out := {}
	var map: Dictionary = script.get_script_constant_map()
	for key in map:
		var v = map[key]
		if v is Script or v is Texture2D or v is Color or v is Callable or v is Object:
			continue
		out[str(key)] = v
	return out

func _worlds() -> Array:
	var out := []
	for w in MainScript.WORLDS:
		var entry := {"id": w.id, "name": w.name, "terrain": w.terrain}
		entry["miniboss"] = _display_name(w.miniboss_script)
		entry["boss"] = _display_name(w.boss_script)
		out.append(entry)
	return out

func _display_name(script: Script) -> String:
	var inst = script.new()
	var n: String = inst.get_display_name()
	inst.free()
	return n

func _enemies() -> Array:
	var out := []
	for script_name in ENEMY_SCRIPTS:
		var script: Script = load("res://scripts/%s.gd" % script_name)
		var map: Dictionary = script.get_script_constant_map()
		var variants := [{}]
		if script_name == "Wolf":
			variants = [{"is_traitor": false}, {"is_traitor": true}]
		elif script_name == "Centaur":
			variants = [{"has_bow": false}, {"has_bow": true}]
		for variant in variants:
			var inst = script.new()
			for key in variant:
				inst.set(key, variant[key])
			out.append({
				"script": script_name,
				"name": inst.get_display_name(),
				"max_health": int(map.get("MAX_HEALTH", 1)),
				"contact_damage": int(inst.get_contact_damage()),
				"xp_reward": int(map.get("XP_REWARD", 0)),
			})
			inst.free()
	return out

# JSON.stringify can't take Vector2i/Color/etc -- flatten them into plain
# arrays so the dump never fails halfway.
func _clean(v):
	match typeof(v):
		TYPE_VECTOR2I:
			return [v.x, v.y]
		TYPE_VECTOR2:
			return [v.x, v.y]
		TYPE_COLOR:
			return [v.r, v.g, v.b, v.a]
		TYPE_DICTIONARY:
			var d := {}
			for k in v:
				d[str(k)] = _clean(v[k])
			return d
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY:
			var a := []
			for item in v:
				a.append(_clean(item))
			return a
		TYPE_OBJECT, TYPE_CALLABLE:
			return null
	return v
