extends SceneTree

# Generates the 16x16 UI icons in assets/ui/ -- one per stat (stat_*.png), per inventory tab (tab_*.png) and per
# sub-tab (sub_*.png). Same idea as the weapon generator: nothing is hand-painted pixel by pixel. Each icon is a short
# list of drawing ops (an ASCII silhouette, discs, polygons, stars, lines) on a 14x14 canvas; every letter is a colour
# RAMP (five tones, dark to light), and the renderer shades it with one light from the upper left -- a part is lit where
# the pixel above or to the left is empty or lower down, shaded where the one below or to the right is -- then wraps the
# whole thing in the same near-black outline the weapons wear. To change an icon, edit its ops below and re-run:
#
#   godot --headless --path . --script res://tools/gen_ui_icons.gd [-- <where to write the review sheet>]
#   godot --headless --editor --path . --quit      (imports the new PNGs)
#
# scripts/UIIcons.gd loads them by name. A hand-made 16x16 PNG with the same name dropped into assets/ui/ simply
# replaces the generated one.

const S := 16          # final icon size
const D := 14          # drawing canvas (the outline takes the 1px border)
const OUT_DIR := "res://assets/ui"
const OUTLINE := "16100e"

# Five tones per ramp, darkest to lightest. One letter each; a second letter is a variant of the same colour so two
# neighbouring parts (clover leaves, map panels) can be told apart.
const RAMPS := {
	"r": ["4a1218", "7a1f26", "c23a3a", "f2676a", "ffb0a8"],   # red
	"b": ["14224f", "1f3a8a", "3d6fd8", "7fb0ff", "c6e0ff"],   # blue
	"g": ["10381c", "1f6030", "3fa653", "8be08f", "d4ffd0"],   # green
	"G": ["1f6030", "3fa653", "6fcf74", "b8f5b4", "e8ffe4"],   # lighter green
	"y": ["5e3f0b", "94661a", "c9931f", "efc23c", "fff3a8"],   # gold
	"Y": ["94661a", "c9931f", "efc23c", "fff3a8", "ffffff"],   # lighter gold
	"s": ["2d3038", "4c515e", "757b89", "a1a7b5", "d6dae4"],   # steel
	"w": ["2b1a0d", "4a2e17", "6a4322", "8b5c30", "ad7842"],   # wood and leather
	"p": ["24123e", "40258a", "7a4fd0", "b898ff", "e6dcff"],   # purple
	"o": ["5a2208", "9c4a14", "e8782a", "ffb05a", "ffe0b0"],   # orange
	"t": ["0e3a3a", "17686a", "2aa6a6", "8ae8e8", "d8ffff"],   # teal
	"k": ["5c3a24", "a8704c", "d9a27a", "f2c9a4", "fff0de"],   # skin
	"j": ["3a2214", "5c3a24", "8c5a3c", "b07850", "d9a27a"],   # darker skin
	"x": ["6a6458", "a39d8c", "d8d2c2", "f2eee4", "ffffff"],   # cream / bone / white
	"a": ["3a1a08", "6a3010", "a85a20", "d08a40", "f0b870"],   # roast brown
	"m": ["5c4a2a", "8c7442", "c8b078", "e6d4a0", "f8ecc8"],   # parchment
	"M": ["8c7442", "c8b078", "e6d4a0", "f8ecc8", "ffffff"],   # lighter parchment
	"d": ["0d0918", "1c1433", "30254f", "54419a", "8a6fdc"],   # near-black violet
}

var mat: Array = []                 # the ramp letter at each canvas pixel ("" = empty)
var zbuf: PackedInt32Array          # which op painted it (later = on top)
var _name := ""

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var icons := _icons()
	var written := 0
	for icon_name in icons:
		_name = icon_name
		_run(icons[icon_name])
		_render().save_png("%s/%s.png" % [OUT_DIR, icon_name])
		written += 1
	print("wrote %d icons to %s" % [written, OUT_DIR])
	var args := OS.get_cmdline_user_args()
	_contact_sheet(icons, args[0] if args.size() > 0 else "user://ui_icon_sheet.png")
	quit()

# --- The icons ---------------------------------------------------------------------

func _shield_rows(field: String) -> Array:
	var rows := [
		"ssssssssssss",
		"sFFFFFFFFFFs",
		"sFFFFFFFFFFs",
		"sFFFFFFFFFFs",
		"sFFFFFFFFFFs",
		"sFFFFFFFFFFs",
		".sFFFFFFFFs.",
		".sFFFFFFFFs.",
		"..sFFFFFFs..",
		"...sFFFFs...",
		"....sFFs....",
		".....ss.....",
	]
	return rows.map(func(r): return r.replace("F", field))

func _icons() -> Dictionary:
	var icons := {}

	# --- Stats -----------------------------------------------------------------
	var heart := ["rows", [
		"..rrrr..rrrr..",
		".rrrrrrrrrrrr.",
		"rrrrrrrrrrrrrr",
		"rrrrrrrrrrrrrr",
		"rrrrrrrrrrrrrr",
		".rrrrrrrrrrrr.",
		"..rrrrrrrrrr..",
		"...rrrrrrrr...",
		"....rrrrrr....",
		".....rrrr.....",
		"......rr......",
	]]
	icons["stat_health"] = [heart, ["px", 2, 3, "x"], ["px", 3, 2, "x"]]
	icons["stat_vigor"] = [heart, ["rect", 6, 3, 8, 8, "x"], ["rect", 4, 4, 10, 6, "x"]]
	icons["stat_mana"] = [["rows", [
		"....pp....",
		"....pp....",
		"...pppp...",
		"...pppp...",
		"..pppppp..",
		".pppppppp.",
		".pppppppp.",
		"pppppppppp",
		"pppppppppp",
		"pppppppppp",
		".pppppppp.",
		"..pppppp..",
		"...pppp...",
	]], ["px", 3, 8, "x"], ["px", 3, 9, "x"]]
	icons["stat_stamina"] = [["poly", [[9, 0], [2.5, 7.8], [6.5, 7.8], [4.5, 14], [12.5, 5.8], [8, 5.8], [11.5, 0]], "b"]]
	var sword := [
		["line", 11.8, 2.2, 5.2, 8.8, 1.25, "s"],
		["line", 2.4, 7.2, 6.8, 11.6, 0.9, "y"],
		["line", 4.2, 9.8, 2.0, 12.0, 0.8, "w"],
		["disc", 1.5, 12.5, 1.1, "y"],
	]
	icons["stat_damage"] = sword
	icons["stat_defense"] = [["rows", _shield_rows("b")], ["disc", 7, 6, 1.5, "y"]]
	icons["stat_fortitude"] = [["rows", _shield_rows("t")], ["star", 7, 6.2, 4, 4.3, 1.5, -90, "x"]]
	icons["stat_speed"] = [["rows", [
		"..xxxxxx....",
		"..wwwwww....",
		"..wwwwww....",
		"..wwwwww....",
		"..wwwwww....",
		"..wwwwwww...",
		"..wwwwwwwww.",
		".wwwwwwwwwww",
		".wwwwwwwwwww",
		".dddddddddd.",
	]]]
	icons["stat_crit"] = [["star", 7, 7, 8, 6.6, 3.0, -90, "o"], ["star", 7, 7, 8, 4.0, 1.9, -90, "y"]]
	icons["stat_luck"] = [
		["disc", 4.6, 4.6, 2.7, "g"], ["disc", 9.4, 4.6, 2.7, "G"],
		["disc", 4.6, 9.4, 2.7, "G"], ["disc", 9.4, 9.4, 2.7, "g"],
		["disc", 7, 7, 1.6, "g"],
		["line", 7.2, 9.4, 10.6, 13.4, 0.6, "w"],
	]
	icons["stat_level"] = [["star", 7, 7.4, 5, 6.9, 3.0, -90, "y"]]
	icons["stat_coin"] = [["disc", 7, 7, 6.2, "y"], ["disc", 7, 7, 3.9, "Y"]]
	icons["stat_shard"] = [
		["poly", [[7, 0], [11.5, 4], [10.5, 10], [7, 14], [3.5, 10], [2.5, 4]], "p"],
		["poly", [[7, 1.5], [10, 4.2], [7, 6.5], [4.2, 4.2]], "t"],
	]
	icons["stat_strength"] = [["rows", [
		"kk.kk.kk.kk",
		"kkjkkjkkjkk",
		"kkjkkjkkjkk",
		"kkkkkkkkkkk",
		"jjjjjjjjkkk",
		"kkkkkkkkkkk",
		"kkkkkkkkkkk",
		".kkkkkkkkk.",
		"..sssssss..",
		"..sssssss..",
	]]]
	icons["stat_agility"] = [
		["poly", [[1, 13], [2, 8], [4, 4], [9, 1], [13, 0.5], [12.5, 5], [9, 9.5], [4, 12.5]], "x"],
		["line", 1.4, 12.6, 11, 2.6, 0.5, "s"],
	]
	icons["stat_intimidation"] = [["rows", [
		"..xxxxxxxx..",
		".xxxxxxxxxx.",
		"xxxxxxxxxxxx",
		"xxxxxxxxxxxx",
		"xxx..xx..xxx",
		"xxx..xx..xxx",
		"xxxxxxxxxxxx",
		".xxxx..xxxx.",
		"..xxxxxxxx..",
		"..xx.xx.xx..",
		"..xx.xx.xx..",
	]]]
	# Might (what heavy weapons ask of you): a dumbbell.
	icons["stat_might"] = [
		["rect", 5, 6, 9, 8, "x"],
		["rect", 3, 4, 5, 10, "s"], ["rect", 9, 4, 11, 10, "s"],
		["rect", 0, 3, 3, 11, "s"], ["rect", 11, 3, 14, 11, "s"],
	]
	var breastplate := [["rows", [
		"sss......sss",
		"ssss....ssss",
		"ssssssssssss",
		".ssssssssss.",
		".ssssssssss.",
		"..ssssssss..",
		"..ssssssss..",
		"...ssssss...",
		"...ssssss...",
	]], ["rect", 4, 8, 10, 9, "w"], ["px", 6, 8, "y"], ["px", 7, 8, "y"]]
	icons["stat_resilience"] = breastplate
	icons["stat_reflexes"] = [["rows", [
		"....xxxxxx....",
		"..xxxxxxxxxx..",
		".xxxxbbbbxxxx.",
		"xxxxbbddbbxxxx",
		"xxxxbbddbbxxxx",
		".xxxxbbbbxxxx.",
		"..xxxxxxxxxx..",
		"....xxxxxx....",
	]]]
	icons["stat_dexterity"] = [
		["disc", 6.6, 7.4, 6.0, "r"], ["disc", 6.6, 7.4, 4.4, "x"],
		["disc", 6.6, 7.4, 2.9, "r"], ["disc", 6.6, 7.4, 1.2, "x"],
		["line", 7, 7, 12.6, 1.4, 0.55, "w"],
		["poly", [[13.6, 0.4], [10.8, 1.2], [12.8, 3.2]], "s"],
	]
	# Rage (berserk): a flame, red outside, orange then gold toward the heart of it.
	icons["stat_rage"] = [
		["poly", [[7.5, 0], [10.5, 4.5], [12, 8.5], [10.8, 12.2], [7, 14], [3.2, 12.2], [2, 8.5], [3.6, 5.2], [5.2, 7], [6, 3.4]], "r"],
		["poly", [[7, 5.6], [9.6, 9], [9, 12.2], [7, 13.2], [5, 12.2], [4.4, 9]], "o"],
		["poly", [[7, 8.6], [8.4, 11], [7, 12.4], [5.6, 11]], "y"],
	]
	# Magic (magic power): a wand with a bright spark at its tip.
	icons["stat_magic"] = [
		["line", 1.6, 12.4, 8.4, 5.6, 0.85, "w"],
		["star", 10, 4, 4, 4.0, 1.2, -90, "y"],
		["px", 12, 9, "x"], ["px", 3, 3, "x"], ["px", 12, 12, "p"], ["px", 1, 6, "p"],
	]

	# Intelligence (learning a weapon's specials, and what staffs ask for in place of Might): an open book, blue-bound.
	icons["stat_intelligence"] = [
		["poly", [[0, 2.4], [7, 4], [14, 2.4], [14, 12.6], [7, 14], [0, 12.6]], "b"],
		["poly", [[1.4, 3.6], [6.6, 5], [6.6, 12.2], [1.4, 11]], "x"],
		["poly", [[7.4, 5], [12.6, 3.6], [12.6, 11], [7.4, 12.2]], "x"],
		["line", 3, 6.6, 5.4, 7.2, 0.35, "s"], ["line", 3, 8.4, 5.4, 9, 0.35, "s"],
		["line", 8.6, 7.2, 11, 6.6, 0.35, "s"], ["line", 8.6, 9, 11, 8.4, 0.35, "s"],
		["rect", 6, 4, 8, 14, "p"],
	]

	# --- Inventory tabs --------------------------------------------------------------
	icons["tab_gear"] = [
		["poly", [[5.5, 3], [4.5, 0.5], [8, 0], [11, 1], [9.5, 3]], "r"],
		["rows", [
			"....ssss....",
			"..ssssssss..",
			".ssssssssss.",
			".ssssssssss.",
			"ssssssssssss",
			"ss........ss",
			"ssssssssssss",
			"ssss.ss.ssss",
			"ssss.ss.ssss",
			".ssssssssss.",
		]],
	]
	var potion := [["rows", [
		"...wwww...",
		"....xx....",
		"....xx....",
		"...xxxx...",
		"..xxxxxx..",
		".xxrrrrxx.",
		"xxrrrrrrxx",
		"xrrrrrrrrx",
		"xrrrrrrrrx",
		"xrrrrrrrrx",
		".xrrrrrrx.",
		"..xxxxxx..",
	]], ["px", 3, 8, "x"]]
	icons["tab_items"] = potion
	icons["tab_talismans"] = [
		["disc", 7, 3.2, 3.0, "y"], ["erase", 7, 3.2, 1.4],
		["poly", [[7, 5.6], [12.2, 9.6], [7, 14], [1.8, 9.6]], "y"],
		["poly", [[7, 7.2], [10.2, 9.6], [7, 12.4], [3.8, 9.6]], "p"],
	]
	icons["tab_character"] = [
		["poly", [[1.5, 14], [2.4, 10.6], [5, 9], [9, 9], [11.6, 10.6], [12.5, 14]], "b"],
		["disc", 7, 3.8, 3.3, "w"],
		["disc", 7, 5.2, 3.0, "k"],
	]
	icons["tab_party"] = [
		["poly", [[0, 14], [0.1, 11.6], [1.5, 9.6], [4, 9.6], [5, 11.6], [5, 14]], "g"],
		["disc", 2.6, 6.6, 1.7, "j"],
		["poly", [[14, 14], [13.9, 11.6], [12.5, 9.6], [10, 9.6], [9, 11.6], [9, 14]], "p"],
		["disc", 11.4, 6.6, 1.7, "k"],
		["poly", [[3, 14], [3.2, 10.6], [5.2, 8], [8.8, 8], [10.8, 10.6], [11, 14]], "b"],
		["disc", 7, 4.6, 2.3, "k"],
	]
	icons["tab_map"] = [
		["poly", [[0, 2], [5, 3], [5, 13], [0, 12]], "m"],
		["poly", [[5, 3], [9, 2], [9, 12], [5, 13]], "M"],
		["poly", [[9, 2], [14, 3], [14, 13], [9, 12]], "m"],
		["line", 10.2, 5.4, 12.6, 8.2, 0.55, "r"],
		["line", 12.6, 5.4, 10.2, 8.2, 0.55, "r"],
		["px", 2, 9, "w"], ["px", 3, 8, "w"], ["px", 5, 8, "w"], ["px", 6, 7, "w"], ["px", 7, 8, "w"],
	]
	icons["tab_settings"] = [
		["star", 7, 7, 8, 6.7, 4.6, 0, "s"],
		["disc", 7, 7, 4.9, "s"],
		["erase", 7, 7, 2.1],
	]

	# --- Sub-tabs (the gear, item and settings pages) --------------------------------
	icons["sub_weapons"] = sword
	icons["sub_armour"] = breastplate
	icons["sub_shields"] = icons["stat_defense"]
	icons["sub_potions"] = potion
	icons["sub_clothes"] = [["rows", [
		".ggg....ggg.",
		"ggggg..ggggg",
		"gggggggggggg",
		"gggggggggggg",
		"ggg.gggg.ggg",
		"ggg.gggg.ggg",
		"...gggggg...",
		"...wwwwww...",
		"...gggggg...",
		"...gggggg...",
	]], ["px", 6, 8, "y"], ["px", 7, 8, "y"]]
	icons["sub_food"] = [
		["disc", 5.6, 5.6, 4.8, "a"],
		["line", 8.6, 8.6, 11.4, 11.4, 1.0, "x"],
		["disc", 11.6, 12.8, 1.25, "x"], ["disc", 12.8, 11.6, 1.25, "x"],
	]
	icons["sub_arrows"] = [
		["line", 2.2, 11.8, 11.6, 2.4, 0.6, "w"],
		["poly", [[13.2, 0.8], [12, 4.8], [9, 2]], "s"],
		["poly", [[1.6, 12.4], [0.4, 9.4], [2.2, 9.0], [4.4, 10.6]], "r"],
		["poly", [[1.6, 12.4], [4.6, 13.6], [5.0, 11.8], [3.4, 9.6]], "r"],
	]
	icons["sub_audio"] = [
		["rect", 1, 5, 4, 9, "s"],
		["poly", [[4, 5], [8, 2], [8, 12], [4, 9]], "s"],
		["line", 10.4, 5, 10.4, 9, 0.6, "y"],
		["line", 12.6, 3.4, 12.6, 10.6, 0.6, "y"],
	]
	icons["sub_controls"] = [
		["rect", 2, 3, 12, 9, "s"],
		["disc", 3.2, 9, 2.8, "s"], ["disc", 10.8, 9, 2.8, "s"],
		["rect", 3, 4, 4, 8, "d"], ["rect", 2, 5, 5, 7, "d"],
		["disc", 9.2, 5.4, 1.0, "r"], ["disc", 11, 7, 1.0, "g"],
	]
	icons["sub_gameplay"] = [
		["rect", 1, 1, 13, 13, "x"],
		["rect", 3, 3, 5, 5, "d"], ["rect", 9, 3, 11, 5, "d"], ["rect", 6, 6, 8, 8, "d"],
		["rect", 3, 9, 5, 11, "d"], ["rect", 9, 9, 11, 11, "d"],
	]

	# --- Map pins, one per kind of place ---------------------------------------------
	icons["pin_town"] = [
		["rect", 3, 7, 11, 13, "x"],
		["poly", [[7, 1], [13, 7.4], [1, 7.4]], "r"],
		["rect", 6, 9, 8, 13, "w"], ["rect", 4, 8.6, 5, 10.4, "b"], ["rect", 9, 8.6, 10, 10.4, "b"],
	]
	icons["pin_harbour"] = [
		["line", 7, 4.2, 7, 12.6, 0.8, "t"], ["line", 4.6, 6.6, 9.4, 6.6, 0.7, "t"],
		["disc", 7, 2.8, 1.8, "t"], ["erase", 7, 2.8, 0.75],
		["line", 2.2, 9.4, 4.6, 12.4, 0.8, "t"], ["line", 4.6, 12.4, 9.4, 12.4, 0.8, "t"], ["line", 9.4, 12.4, 11.8, 9.4, 0.8, "t"],
	]
	icons["pin_chest"] = [
		["rect", 1, 6, 13, 13, "w"], ["rect", 1, 2, 13, 7, "w"],
		["rect", 6, 2, 8, 13, "y"], ["rect", 6, 6, 8, 9, "Y"],
	]
	icons["pin_boss"] = [["rows", [
		"..rrrrrrrr..",
		".rrrrrrrrrr.",
		"rrrrrrrrrrrr",
		"rrrrrrrrrrrr",
		"rrr..rr..rrr",
		"rrr..rr..rrr",
		"rrrrrrrrrrrr",
		".rrrr..rrrr.",
		"..rrrrrrrr..",
		"..rr.rr.rr..",
		"..rr.rr.rr..",
	]]]
	icons["pin_here"] = [
		["poly", [[7, 14], [2, 6.4], [2.8, 3], [7, 0.6], [11.2, 3], [12, 6.4]], "b"],
		["disc", 7, 5.6, 2.3, "x"],
	]
	# A selection cursor: the pointing arrow that marks the thing a menu is on.
	icons["ui_cursor"] = [["poly", [[3, 1.5], [12, 7], [3, 12.5]], "y"]]

	# --- Portraits: a bust each for You and the five who may join. Shown big (4x to 8x), so the chunky pixels are the look. ---
	icons["face_you"] = [
		["poly", [[1.5, 14], [2.4, 10.8], [5, 9.4], [9, 9.4], [11.6, 10.8], [12.5, 14]], "b"],
		["disc", 7, 4.4, 3.8, "w"],
		["disc", 7, 5.8, 3.0, "k"],
		["rect", 4, 3, 10, 5, "w"],
		["px", 5, 6, "d"], ["px", 8, 6, "d"], ["rect", 6, 8, 8, 9, "j"],
	]
	icons["face_knight"] = [
		["poly", [[1.2, 14], [2.2, 10.6], [5, 9.2], [9, 9.2], [11.8, 10.6], [12.8, 14]], "s"],
		["poly", [[6, 3], [5, 0.4], [8.6, 0], [10.4, 1.4], [8.4, 3.2]], "r"],
		["disc", 7, 5.8, 4.2, "s"],
		["rect", 3, 5, 11, 7, "d"], ["rect", 6.5, 7, 7.5, 10, "d"],
		["px", 5, 5, "t"], ["px", 8, 5, "t"],
	]
	icons["face_necromancer"] = [
		["poly", [[0.6, 14], [1.4, 9.8], [4.4, 7], [9.6, 7], [12.6, 9.8], [13.4, 14]], "p"],
		["poly", [[7, 0.2], [11.6, 5], [11, 10], [3, 10], [2.4, 5]], "p"],
		["poly", [[7, 2.8], [10, 6], [9.4, 9.4], [4.6, 9.4], [4, 6]], "d"],
		["px", 5, 6, "g"], ["px", 8, 6, "g"], ["px", 5, 5, "G"], ["px", 8, 5, "G"],
	]
	icons["face_druid"] = [
		["poly", [[1.5, 14], [2.4, 10.6], [5, 9.2], [9, 9.2], [11.6, 10.6], [12.5, 14]], "g"],
		["poly", [[7, 0.4], [11.4, 4.4], [11, 9], [3, 9], [2.6, 4.4]], "g"],
		["disc", 7, 6, 3.0, "k"],
		["poly", [[3, 4.4], [7, 1.4], [11, 4.4], [7, 4]], "G"],
		["px", 5, 6, "d"], ["px", 8, 6, "d"], ["rect", 5, 8, 9, 10, "x"],
	]
	icons["face_guardian"] = [
		["poly", [[0.5, 14], [1.4, 10.2], [4.8, 8.8], [9.2, 8.8], [12.6, 10.2], [13.5, 14]], "s"],
		["rect", 1, 12, 13, 13, "y"],
		["disc", 7, 5.4, 4.5, "s"],
		["rect", 4, 4.6, 10, 8, "k"],
		["rect", 6.5, 3, 7.5, 8, "s"],
		["px", 5, 6, "d"], ["px", 8, 6, "d"],
		["rect", 5, 2, 9, 3, "y"],
	]
	icons["face_marksman"] = [
		["poly", [[1.5, 14], [2.4, 10.8], [5, 9.4], [9, 9.4], [11.6, 10.8], [12.5, 14]], "g"],
		["line", 2.5, 13.5, 11.5, 9.8, 0.5, "w"],
		["poly", [[7, 0.2], [11.6, 5.6], [10.6, 9.4], [3.4, 9.4], [2.4, 5.6]], "g"],
		["rect", 4, 4.6, 10, 8.4, "k"],
		["px", 5, 6, "d"], ["px", 8, 6, "d"],
		["px", 9, 1, "r"], ["px", 10, 0, "r"],
	]
	icons["face_brawler"] = [
		["poly", [[0.6, 14], [1.6, 10], [4.6, 8.6], [9.4, 8.6], [12.4, 10], [13.4, 14]], "k"],
		["line", 4.2, 9.2, 6.6, 14, 0.7, "w"], ["line", 9.8, 9.2, 7.4, 14, 0.7, "w"],
		["disc", 7, 5, 3.6, "k"],
		["rect", 3.4, 3.2, 10.6, 5, "r"],
		["px", 5, 6, "d"], ["px", 8, 6, "d"], ["rect", 6, 8, 8, 9, "j"], ["px", 9, 4, "j"],
	]
	icons["face_shaman"] = [
		["poly", [[1.5, 14], [2.4, 10.6], [5, 9.2], [9, 9.2], [11.6, 10.6], [12.5, 14]], "w"],
		["line", 4, 3, 2, 0.5, 0.6, "r"], ["line", 7, 2.4, 7, 0, 0.6, "y"], ["line", 10, 3, 12, 0.5, 0.6, "t"],
		["disc", 7, 5.8, 3.2, "k"],
		["rect", 3.8, 3.4, 10.2, 5, "p"],
		["px", 5, 6, "d"], ["px", 8, 6, "d"], ["rect", 5, 7.6, 9, 8.4, "t"],
	]
	icons["face_wolf"] = [
		["poly", [[3, 5], [3.4, 0.8], [6.2, 3.2]], "s"], ["poly", [[11, 5], [10.6, 0.8], [7.8, 3.2]], "s"],
		["disc", 7, 7, 4.8, "s"],
		["poly", [[4.6, 8.6], [9.4, 8.6], [8.2, 12.6], [5.8, 12.6]], "x"],
		["px", 6, 12, "d"], ["px", 7, 12, "d"],
		["px", 4, 5, "y"], ["px", 9, 5, "y"],
	]
	icons["face_rogue"] = [
		["poly", [[1.5, 14], [2.4, 10.8], [5, 9.4], [9, 9.4], [11.6, 10.8], [12.5, 14]], "d"],
		["poly", [[7, 0.6], [11.4, 4.2], [11.6, 9], [2.4, 9], [2.6, 4.2]], "d"],
		["rect", 4, 4.4, 10, 7, "k"],
		["rect", 4, 7, 10, 9, "s"],
		["px", 5, 5, "y"], ["px", 8, 5, "y"],
	]
	return icons

# --- Drawing -----------------------------------------------------------------------

func _run(ops: Array) -> void:
	mat = []
	mat.resize(D * D)
	mat.fill("")
	zbuf = PackedInt32Array()
	zbuf.resize(D * D)
	zbuf.fill(0)
	var z := 0
	for op in ops:
		z += 1
		match op[0]:
			"rows": _rows(op, z)
			"disc": _capsule(Vector2(op[1], op[2]), Vector2(op[1], op[2]), op[3], op[3], op[4], z)
			"line": _capsule(Vector2(op[1], op[2]), Vector2(op[3], op[4]), op[5], op[5], op[6], z)
			"rect": _rect(op, z)
			"poly": _poly(op[1], op[2], z)
			"star": _star(op, z)
			"erase": _erase(Vector2(op[1], op[2]), op[3])
			"px": _put(int(op[1]), int(op[2]), op[3], z)
			_: push_error("%s: unknown op %s" % [_name, op[0]])

func _put(x: int, y: int, m: String, z: int) -> void:
	if x < 0 or y < 0 or x >= D or y >= D:
		return
	if not RAMPS.has(m):
		push_error("%s: unknown colour '%s'" % [_name, m])
		return
	mat[y * D + x] = m
	zbuf[y * D + x] = z

func _rows(op: Array, z: int) -> void:
	var rows: Array = op[1]
	var w: int = rows[0].length()
	var x0: int = (D - w) / 2
	var y0: int = (D - rows.size()) / 2
	for y in rows.size():
		if rows[y].length() != w:
			push_error("%s: row %d is %d wide, not %d" % [_name, y, rows[y].length(), w])
		for x in rows[y].length():
			var c: String = rows[y][x]
			if c != ".":
				_put(x0 + x, y0 + y, c, z)

func _rect(op: Array, z: int) -> void:
	for y in range(int(op[2]), int(op[4])):
		for x in range(int(op[1]), int(op[3])):
			_put(x, y, op[5], z)

# A tapered capsule from a to b (radius r0 at a, r1 at b); a disc when a == b.
func _capsule(a: Vector2, b: Vector2, r0: float, r1: float, m: String, z: int) -> void:
	var ab := b - a
	var len2: float = maxf(ab.length_squared(), 0.0001)
	for y in D:
		for x in D:
			var p := Vector2(x + 0.5, y + 0.5)
			var t: float = clampf((p - a).dot(ab) / len2, 0.0, 1.0)
			if p.distance_to(a + ab * t) <= lerpf(r0, r1, t):
				_put(x, y, m, z)

func _erase(c: Vector2, r: float) -> void:
	for y in D:
		for x in D:
			if Vector2(x + 0.5, y + 0.5).distance_to(c) <= r:
				mat[y * D + x] = ""
				zbuf[y * D + x] = 0

func _poly(points: Array, m: String, z: int) -> void:
	var pts: Array[Vector2] = []
	for pt in points:
		pts.append(Vector2(pt[0], pt[1]))
	for y in D:
		for x in D:
			var c := Vector2(x + 0.5, y + 0.5)
			var inside := false
			var j := pts.size() - 1
			for i in pts.size():
				var a := pts[i]
				var b := pts[j]
				if (a.y > c.y) != (b.y > c.y) and c.x < (b.x - a.x) * (c.y - a.y) / (b.y - a.y) + a.x:
					inside = not inside
				j = i
			if inside:
				_put(x, y, m, z)

# ["star", cx, cy, points, outer radius, inner radius, rotation in degrees (-90 = one point straight up), colour]
func _star(op: Array, z: int) -> void:
	var pts := []
	var n: int = int(op[3])
	for i in n * 2:
		var ang: float = deg_to_rad(float(op[6])) + float(i) * PI / float(n)
		var r: float = float(op[4]) if i % 2 == 0 else float(op[5])
		pts.append([float(op[1]) + cos(ang) * r, float(op[2]) + sin(ang) * r])
	_poly(pts, op[7], z)

# --- Rendering ---------------------------------------------------------------------

# Does the neighbour at (x, y) count as "not part of me" for shading: empty, or painted before me (so it sits behind)?
func _apart(x: int, y: int, z: int) -> int:
	if x < 0 or y < 0 or x >= D or y >= D:
		return 1
	var nz: int = zbuf[y * D + x]
	return 1 if nz == 0 or nz < z else 0

func _render() -> Image:
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in D:
		for x in D:
			var m: String = mat[y * D + x]
			if m == "":
				continue
			var z: int = zbuf[y * D + x]
			var score: int = _apart(x, y - 1, z) + _apart(x - 1, y, z) - _apart(x, y + 1, z) - _apart(x + 1, y, z)
			var tone := 2
			if score >= 2:
				tone = 4
			elif score == 1:
				tone = 3
			elif score <= -1:
				tone = 1
			img.set_pixel(x + 1, y + 1, Color.html(RAMPS[m][tone]))
	# Outline: any empty pixel that touches the drawing on a side.
	var outline := Color.html(OUTLINE)
	var marks: Array[Vector2i] = []
	for y in S:
		for x in S:
			if img.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < S and q.y < S and img.get_pixelv(q).a > 0.0 and img.get_pixelv(q) != outline:
					marks.append(Vector2i(x, y))
					break
	for m in marks:
		img.set_pixelv(m, outline)
	return img

# A review sheet (not shipped): every icon, ten to a row, large and then actual size on the panel colour.
func _contact_sheet(icons: Dictionary, path: String) -> void:
	var scale := 8
	var cell := (S + 3) * scale
	var names: Array = icons.keys()
	var rows := int(ceil(names.size() / 10.0))
	var strip_y := rows * cell + 8
	var sheet := Image.create(cell * 10, strip_y + 70, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.09, 0.08, 0.12))
	for i in names.size():
		var icon := Image.load_from_file(ProjectSettings.globalize_path("%s/%s.png" % [OUT_DIR, names[i]]))
		if icon == null:
			continue
		var big := icon.duplicate() as Image
		big.resize(S * scale, S * scale, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(big, Rect2i(0, 0, S * scale, S * scale), Vector2i((i % 10) * cell + scale, (i / 10) * cell + scale))
		# And again at the sizes the UI will use: actual size, then double.
		sheet.blend_rect(icon, Rect2i(0, 0, S, S), Vector2i(i * (S + 4) + 4, strip_y))
		var twice := icon.duplicate() as Image
		twice.resize(S * 2, S * 2, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(twice, Rect2i(0, 0, S * 2, S * 2), Vector2i(i * (S * 2 + 4) + 4, strip_y + 24))
	sheet.save_png(path)
	print("review sheet: %s (order: %s)" % [path, ", ".join(names)])
