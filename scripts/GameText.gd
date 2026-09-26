extends Node

# Central hub for every piece of "flavor" text in the game -- weapon/item/
# rune/event/upgrade names & descriptions, world names, the shopkeeper's
# barks, and so on. res://text/strings.json is the one file to edit to
# reskin all of it; no code changes needed to retext the game.
#
# Most sellable items carry two separate lines: "description" (the plain
# mechanical text shown in the row's own hover tooltip, unchanged since
# before the shopkeeper existed) and "shop_description" (the shopkeeper's
# own pitch, shown in HUD.gd's shop_keeper_box when that row is hovered).
# Editing one never touches the other.
#
# Deliberately NOT covered here (would need real code changes first, see
# each note below before attempting):
#   - Enemy display names -- "Goblin"/"Count Strahd"/etc. double as the
#     ENEMY_TRAITS lookup key all through Main.gd and HUD.gd, so renaming one
#     would silently strip that enemy of its traits instead of just relabeling it.
#   - Weapon quality tier names ("Broken".."Mythic") -- tier_name doubles as
#     an identity check (e.g. `tier.tier_name == "Mythic"`) in Weapons.gd,
#     Main.gd, HUD.gd, Player.gd, and several tools/test_*.gd files. Needs a
#     proper id/display-name split first.
#   - The hundreds of interpolated hud.battle_log(...) combat messages in
#     Main.gd -- static flavor text only, not dynamic combat-log lines.
#
# How it works: every target below is a live reference into another script's
# const Dictionary. GDScript's `const` only locks the *variable* -- the
# Dictionary object itself stays mutable -- so applying overrides here at
# boot (before any UI ever reads these fields) reskins the game everywhere
# that data is used, with zero changes to the scripts that actually own it.

const MainScript := preload("res://scripts/Main.gd")
const HUDScript := preload("res://scripts/HUD.gd")
const STRINGS_PATH := "res://text/strings.json"

const MODE_APPLY := 0
const MODE_EXPORT := 1

var _data: Dictionary = {}

func _ready() -> void:
	_load()
	_process_all(MODE_APPLY)

# F9 re-reads strings.json and re-applies it without restarting the game --
# edit the file, alt-tab back in, hit F9, see the change immediately.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		reload()

func reload() -> void:
	_load()
	_process_all(MODE_APPLY)
	print("GameText: reloaded %d string(s) from %s" % [_data.size(), STRINGS_PATH])

func _load() -> void:
	_data.clear()
	if not FileAccess.file_exists(STRINGS_PATH):
		return
	var f := FileAccess.open(STRINGS_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		_data = parsed

# Walks every known text field, keyed the same way strings.json is -- used
# both to apply overrides (MODE_APPLY, at boot/reload) and to generate a
# fresh strings.json populated with the game's current defaults (MODE_EXPORT,
# via tools/export_game_text.gd). Keeping both directions on one code path
# means the exported file can never drift out of sync with what actually
# gets applied.
func _process_all(mode: int) -> void:
	_process_weapon(Weapons.CLUB, mode)
	for w in Weapons.UPGRADABLE_TYPES:
		_process_weapon(w, mode)
	for id in Weapons.MYTHIC_WEAPONS:
		var m: Dictionary = Weapons.MYTHIC_WEAPONS[id]
		_field(m, "weapon.mythic.%s" % id, "name", mode)
		_field(m, "weapon.mythic.%s" % id, "description", mode)
	for id in Weapons.ARROW_TYPES:
		var a: Dictionary = Weapons.ARROW_TYPES[id]
		_field(a, "arrow.%s" % id, "name", mode)
		_field(a, "arrow.%s" % id, "description", mode)
		_field(a, "arrow.%s" % id, "shop_description", mode)
	for mat in Weapons.MATERIALS:
		_field(mat, "material.%s" % mat.id, "name", mode)
	for p in Potions.TIERS:
		_field(p, "potion.%s" % p.id, "name", mode)
		_field(p, "potion.%s" % p.id, "description", mode)
		_field(p, "potion.%s" % p.id, "shop_description", mode)
	for ar in Armor.TIERS:
		_field(ar, "armor.%s" % ar.id, "name", mode)
		_field(ar, "armor.%s" % ar.id, "description", mode)
		_field(ar, "armor.%s" % ar.id, "shop_description", mode)
	for id in Shields.SHIELDS:
		var s: Dictionary = Shields.SHIELDS[id]
		_field(s, "shield.%s" % id, "name", mode)
		_field(s, "shield.%s" % id, "description", mode)
		_field(s, "shield.%s" % id, "shop_description", mode)
	for r in Enchantments.RUNES:
		_field(r, "rune.%s" % r.id, "name", mode)
		_field(r, "rune.%s" % r.id, "description", mode)
		_field(r, "rune.%s" % r.id, "shop_description", mode)
	for id in Events.EVENTS:
		var e: Dictionary = Events.EVENTS[id]
		_field(e, "event.%s" % id, "name", mode)
		_field(e, "event.%s" % id, "description", mode)
		_field(e, "event.%s" % id, "yes_label", mode)
		_field(e, "event.%s" % id, "no_label", mode)
	for id in SaveData.UPGRADES:
		var u: Dictionary = SaveData.UPGRADES[id]
		_field(u, "upgrade.%s" % id, "name", mode)
		_field(u, "upgrade.%s" % id, "description", mode)
	for d in SaveData.DIFFICULTIES:
		_field(d, "difficulty.%s" % d.id, "name", mode)
		_field(d, "difficulty.%s" % d.id, "description", mode)
	for w in MainScript.WORLDS:
		_field(w, "world.%s" % w.id, "name", mode)
	# Beastiary creature flavor lines -- name isn't editable here since it
	# doubles as the ENEMY_TRAITS/HUD.ENEMY_ICONS lookup key (see this
	# file's header note on why enemy names aren't covered at all).
	for id in Beastiary.DESCRIPTIONS:
		var key := "beastiary.%s" % id
		if mode == MODE_APPLY:
			if _data.has(key):
				Beastiary.DESCRIPTIONS[id] = _data[key]
		else:
			_data[key] = Beastiary.DESCRIPTIONS[id]
	# Every non-item hover-hint/description string (battle action
	# explanations, level-up stat blurbs, the shop's own mechanic hints) --
	# a flat Dictionary, walked directly the same way Beastiary.DESCRIPTIONS
	# is above, just with an "ui." key prefix to keep it visually distinct
	# from the per-item fields in strings.json.
	for key in HUDScript.UI_TEXT:
		var full_key := "ui.%s" % key
		if mode == MODE_APPLY:
			if _data.has(full_key):
				HUDScript.UI_TEXT[key] = _data[full_key]
		else:
			_data[full_key] = HUDScript.UI_TEXT[key]
	# Shopkeeper's generic barks (HUD.gd's shop_keeper_box) -- an Array of
	# lines per category rather than a single field, so _field's plain
	# Dictionary-key shape doesn't apply; walked directly instead.
	for category in Shopkeeper.LINES:
		var lines: Array = Shopkeeper.LINES[category]
		for i in lines.size():
			var key := "shopkeeper.%s.%d" % [category, i]
			if mode == MODE_APPLY:
				if _data.has(key):
					lines[i] = _data[key]
			else:
				_data[key] = lines[i]
	# Per-weapon-type reactions (Shopkeeper.ITEM_LINES) -- empty in code on
	# purpose (see that file's header note), but MODE_EXPORT still needs to
	# write out a starter slot per weapon_id/tier/index so there's somewhere
	# in strings.json to actually write the lines. A fixed 3-slot span per
	# tier regardless of how many (if any) already exist, so the file always
	# offers room for a full base/high_quality/familiar set instead of only
	# whatever's already been filled in.
	const ITEM_LINE_SLOTS := 3
	for weapon_id in Shopkeeper.ITEM_LINES:
		var tiers: Dictionary = Shopkeeper.ITEM_LINES[weapon_id]
		for tier in tiers:
			var lines: Array = tiers[tier]
			for i in ITEM_LINE_SLOTS:
				var key := "shopkeeper.item.%s.%s.%d" % [weapon_id, tier, i]
				if mode == MODE_APPLY:
					if _data.has(key):
						while lines.size() <= i:
							lines.append("")
						lines[i] = _data[key]
				else:
					_data[key] = lines[i] if i < lines.size() else ""

func _process_weapon(w: Dictionary, mode: int) -> void:
	_field(w, "weapon.%s" % w.id, "name", mode)
	_field(w, "weapon.%s" % w.id, "description", mode)
	_field(w, "weapon.%s" % w.id, "shop_description", mode)
	for sp in w.get("specials", []):
		_field(sp, "weapon.%s.special.%s" % [w.id, sp.id], "name", mode)
		_field(sp, "weapon.%s.special.%s" % [w.id, sp.id], "description", mode)

func _field(d: Dictionary, prefix: String, field: String, mode: int) -> void:
	if not d.has(field):
		return
	var key := "%s.%s" % [prefix, field]
	if mode == MODE_APPLY:
		if _data.has(key):
			d[field] = _data[key]
	else:
		_data[key] = d[field]

# Used only by tools/export_game_text.gd to (re)generate strings.json.
func export_defaults() -> Dictionary:
	_data.clear()
	_process_all(MODE_EXPORT)
	return _data.duplicate()
