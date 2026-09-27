extends TownPanel
class_name BlacksmithPanel

# The town Blacksmith: pay coins to upgrade any owned weapon (up to +5) or your
# metal armour (up to +3). The rules and numbers live in Blacksmith.gd; the
# levels themselves are Player state (weapon_upgrade_levels /
# armor_upgrade_levels), applied whenever a weapon is equipped or damage is
# reduced -- so an upgrade takes effect everywhere at once.
#
# Laid out like the Dojo (see TownUI.gd): your gear down the left, and on the right
# the selected piece's header, a "next upgrade" card showing what you get for the
# price, and a row of chips for every level.

const BlacksmithScript := preload("res://scripts/Blacksmith.gd")
const ArmorScript := preload("res://scripts/Armor.gd")
const WeaponsScript := preload("res://scripts/Weapons.gd")
const WeaponIconsScript := preload("res://scripts/WeaponIcons.gd")
const TownUIScript := preload("res://scripts/TownUI.gd")

const METAL_TINT := Color(0.62, 0.68, 0.82)
const SOFT_TINT := Color(0.5, 0.46, 0.4)

var coins_label: Label
var speech_label: Label
var gear_list: VBoxContainer
var detail_box: VBoxContainer
# What the right side is showing: "weapon" or "armor", and that piece's id.
var selected_kind := ""
var selected_id := ""
# "weapon:<id>" / "armor:<id>" -> its entry in the left list; and the Upgrade
# button of the detail side (null when there is nothing to buy). Rebuilt by _refresh.
var entry_buttons := {}
var upgrade_button: Button = null

func _panel_title() -> String:
	return "THE BLACKSMITH"

func _window_size() -> Vector2:
	return TownUIScript.picker_window_size(get_viewport().get_visible_rect().size)

func _build_content(outer: VBoxContainer) -> void:
	TownUIScript.apply_bronze_frame(self)
	var top: Dictionary = TownUIScript.add_top_row(outer)
	speech_label = top.speech
	coins_label = top.coins
	var body: Dictionary = TownUIScript.add_picker_body(outer, "YOUR GEAR")
	gear_list = body.list
	detail_box = body.detail

func _on_opened() -> void:
	speech_label.text = "\"Bring me steel and coin and I'll make it bite harder. Metal armour too -- I don't work leather.\""
	var key := _key(selected_kind, selected_id)
	if entry_buttons.has(key):
		entry_buttons[key].grab_focus()

# --- Data helpers ------------------------------------------------------------

func _key(kind: String, id: String) -> String:
	return "%s:%s" % [kind, id]

# Owned weapons: the one in hand first, then best tier first, then by name.
func _ordered_weapons() -> Array:
	var current_id: String = _player.current_weapon_base.get("id", "")
	var variants: Array = []
	for id in _player.owned_weapons:
		var variant: Dictionary = WeaponsScript.get_owned_variant(id)
		if not variant.is_empty():
			variants.append(variant)
	variants.sort_custom(func(a, b):
		var a_current: bool = a.get("id", "") == current_id
		var b_current: bool = b.get("id", "") == current_id
		if a_current != b_current:
			return a_current
		var rank_a: int = _tier_rank(a)
		var rank_b: int = _tier_rank(b)
		if rank_a != rank_b:
			return rank_a > rank_b
		return WeaponIconsScript.display_name(a) < WeaponIconsScript.display_name(b))
	return variants

func _tier_rank(variant: Dictionary) -> int:
	for tier in WeaponsScript.TIERS:
		if tier.tier_name == variant.get("tier_name", ""):
			return tier.rank
	return -1

# Owned armour worth listing (not the free Rags), in tier order.
func _owned_armor() -> Array:
	var result: Array = []
	for armor in ArmorScript.TIERS:
		if _player.owned_armor.has(armor.id) and armor.id != "armor_rags":
			result.append(armor)
	return result

func _weapon_by_id(id: String) -> Dictionary:
	return WeaponsScript.get_owned_variant(id) if _player.owned_weapons.has(id) else {}

func _armor_by_id(id: String) -> Dictionary:
	for armor in _owned_armor():
		if armor.id == id:
			return armor
	return {}

func _pips(level: int, max_level: int) -> Array:
	var pips: Array = []
	for i in max_level:
		pips.append(i < level)
	return pips

func _armor_texture(armor: Dictionary) -> Texture2D:
	return load("res://assets/%s.png" % armor.get("icon", "armor_rags"))

# The 16x16 armour art on a plate, drawn at a whole multiple so it stays crisp.
func _armor_plate(armor: Dictionary, icon_scale: int) -> PanelContainer:
	return TownUIScript.plate(_armor_texture(armor), Vector2(16, 16) * icon_scale, METAL_TINT if armor.get("metal", false) else SOFT_TINT)

func _weapon_plate(variant: Dictionary, icon_scale: int) -> PanelContainer:
	return TownUIScript.plate(WeaponIconsScript.texture_for(variant), Vector2(32, 32) * icon_scale, WeaponIconsScript.tier_color(variant))

func _title_with_level(title: String, level: int) -> String:
	return title if level == 0 else "%s +%d" % [title, level]

# --- Refresh -----------------------------------------------------------------

func _refresh() -> void:
	if _player == null or gear_list == null:
		return
	coins_label.text = "%d" % _player.coins
	var weapons: Array = _ordered_weapons()
	var armors: Array = _owned_armor()
	# Keep the selection if it still exists, else the weapon in hand, else the first thing.
	var still_valid: bool = (selected_kind == "weapon" and _player.owned_weapons.has(selected_id)) or (selected_kind == "armor" and not _armor_by_id(selected_id).is_empty())
	if not still_valid:
		if not weapons.is_empty():
			selected_kind = "weapon"
			selected_id = weapons[0].id
		elif not armors.is_empty():
			selected_kind = "armor"
			selected_id = armors[0].id
		else:
			selected_kind = ""
			selected_id = ""

	_clear(gear_list)
	entry_buttons.clear()
	var current_id: String = _player.current_weapon_base.get("id", "")
	gear_list.add_child(_make_label("WEAPONS", 11, TownUIScript.GOLD))
	for variant in weapons:
		var id: String = variant.id
		var level: int = _player.get_weapon_upgrade_level(id)
		var entry: Button = TownUIScript.make_entry(_weapon_plate(variant, 1), _title_with_level(WeaponIconsScript.display_name(variant), level), _pips(level, BlacksmithScript.WEAPON_MAX_LEVEL), "IN HAND" if id == current_id else "", TownUIScript.GOOD)
		entry.pressed.connect(func(): select("weapon", id))
		gear_list.add_child(entry)
		entry_buttons[_key("weapon", id)] = entry
	gear_list.add_child(_make_label("ARMOUR", 11, TownUIScript.GOLD))
	var worn_id: String = _player.equipped_armor.get("id", "")
	for armor in armors:
		var id: String = armor.id
		var metal: bool = armor.get("metal", false)
		var level: int = _player.get_armor_upgrade_level(id)
		var pips: Array = _pips(level, BlacksmithScript.ARMOR_MAX_LEVEL) if metal else []
		var tag := "WORN" if id == worn_id else ("NOT METAL" if not metal else "")
		var entry: Button = TownUIScript.make_entry(_armor_plate(armor, 2), _title_with_level(armor.name, level), pips, tag, TownUIScript.GOOD if id == worn_id else TownUIScript.BAD)
		entry.pressed.connect(func(): select("armor", id))
		gear_list.add_child(entry)
		entry_buttons[_key("armor", id)] = entry
	if armors.is_empty():
		gear_list.add_child(_make_label("You own no armour worth working yet.", 13, TownUIScript.DIM))
	_style_entries()
	_build_detail()

func _style_entries() -> void:
	var selected_key := _key(selected_kind, selected_id)
	for key in entry_buttons:
		TownUIScript.style_entry(entry_buttons[key], key == selected_key)

func select(kind: String, id: String) -> void:
	if kind == selected_kind and id == selected_id:
		return
	selected_kind = kind
	selected_id = id
	_style_entries()
	_build_detail()

# --- The selected piece ------------------------------------------------------

func _build_detail() -> void:
	_clear(detail_box)
	upgrade_button = null
	if selected_kind == "weapon" and not _weapon_by_id(selected_id).is_empty():
		_build_weapon_detail(_weapon_by_id(selected_id))
	elif selected_kind == "armor" and not _armor_by_id(selected_id).is_empty():
		_build_armor_detail(_armor_by_id(selected_id))
	else:
		detail_box.add_child(_make_label("You have nothing for the smith to work on yet.", 15, TownUIScript.DIM))

func _build_weapon_detail(variant: Dictionary) -> void:
	var id: String = variant.id
	var level: int = _player.get_weapon_upgrade_level(id)
	var max_level: int = BlacksmithScript.WEAPON_MAX_LEVEL
	var in_hand: bool = id == _player.current_weapon_base.get("id", "")
	var tier_line: String = WeaponIconsScript.tier_label(variant) + ("   |   in your hand" if in_hand else "")
	var forged_line := "Not yet upgraded" if level == 0 else ("Fully forged  (+%d)" % level if level >= max_level else "Forged +%d of +%d" % [level, max_level])
	var lines: Array = [
		[tier_line, WeaponIconsScript.tier_color(variant).lightened(0.25), 14],
		[forged_line, TownUIScript.GOLD if level >= max_level else TownUIScript.DIM, 13],
	]
	if variant.get("description", "") != "":
		lines.append([variant.description, Color(0.6, 0.6, 0.64), 12])
	detail_box.add_child(TownUIScript.make_header(_weapon_plate(variant, 2), variant.name.to_upper(), lines))

	var cost: int = BlacksmithScript.weapon_cost(level)
	var now_damage: float = _player.weapon_damage_exact(variant)
	var bonus_now: int = int(round(BlacksmithScript.WEAPON_DAMAGE_PCT_PER_LEVEL * 100.0 * level))
	var stats: Array = []
	if cost >= 0:
		var next_damage: float = _player.weapon_damage_exact(variant, level + 1)
		stats.append(["Damage per hit", "%.1f" % now_damage, "%.1f" % next_damage, "at your Strength"])
		stats.append(["Smith's bonus", "+%d%%" % bonus_now, "+%d%%" % (bonus_now + int(round(BlacksmithScript.WEAPON_DAMAGE_PCT_PER_LEVEL * 100.0))), "damage"])
		var break_now: float = variant.get("break_chance", 0.0) * BlacksmithScript.weapon_break_factor(level)
		if break_now > 0.0:
			var break_next: float = variant.get("break_chance", 0.0) * BlacksmithScript.weapon_break_factor(level + 1)
			stats.append(["Break chance", "%.1f%%" % (break_now * 100.0), "%.1f%%" % (break_next * 100.0), "lower is better"])
	else:
		stats.append(["Damage per hit", "%.1f" % now_damage, "", "at your Strength"])
		stats.append(["Smith's bonus", "+%d%%" % bonus_now, "", "damage"])
	_add_next_card(level, max_level, cost, stats, "upgrade_weapon", id)

	var chips: Array = []
	for i in max_level:
		chips.append({"cost": BlacksmithScript.weapon_cost(i), "effect": "+%d%% dmg" % int(BlacksmithScript.WEAPON_DAMAGE_PCT_PER_LEVEL * 100 * (i + 1))})
	_add_level_row(level, chips)

func _build_armor_detail(armor: Dictionary) -> void:
	var id: String = armor.id
	var metal: bool = armor.get("metal", false)
	var level: int = _player.get_armor_upgrade_level(id)
	var max_level: int = BlacksmithScript.ARMOR_MAX_LEVEL
	var worn: bool = id == _player.equipped_armor.get("id", "")
	var lines: Array = [
		[("Metal armour" if metal else "Not metal") + ("   |   worn" if worn else ""), TownUIScript.GOOD if worn else TownUIScript.DIM, 14],
	]
	if metal:
		lines.append(["Not yet upgraded" if level == 0 else ("Fully forged  (+%d)" % level if level >= max_level else "Forged +%d of +%d" % [level, max_level]), TownUIScript.GOLD if level >= max_level else TownUIScript.DIM, 13])
	if armor.get("description", "") != "":
		lines.append([armor.description, Color(0.6, 0.6, 0.64), 12])
	detail_box.add_child(TownUIScript.make_header(_armor_plate(armor, 4), armor.name.to_upper(), lines))

	if not metal:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", TownUIScript.box(Color(0.11, 0.11, 0.14, 0.95), Color(0.38, 0.38, 0.44), 2, 7, 12))
		card.add_child(_make_label("Not metal -- the smith won't touch it. He works iron and steel, and nothing softer.", 14, TownUIScript.DIM))
		detail_box.add_child(card)
		return

	var cost: int = BlacksmithScript.armor_cost(level)
	var dr_now: float = armor.get("damage_reduction", 0.0) + BlacksmithScript.armor_bonus(level)
	var stats: Array = []
	if cost >= 0:
		var dr_next: float = armor.get("damage_reduction", 0.0) + BlacksmithScript.armor_bonus(level + 1)
		stats.append(["Damage reduction", "%.1f%%" % (dr_now * 100.0), "%.1f%%" % (dr_next * 100.0), "before clothing"])
		stats.append(["Smith's bonus", "+%.1f%%" % (BlacksmithScript.armor_bonus(level) * 100.0), "+%.1f%%" % (BlacksmithScript.armor_bonus(level + 1) * 100.0), "reduction"])
	else:
		stats.append(["Damage reduction", "%.1f%%" % (dr_now * 100.0), "", "before clothing"])
		stats.append(["Smith's bonus", "+%.1f%%" % (BlacksmithScript.armor_bonus(level) * 100.0), "", "reduction"])
	_add_next_card(level, max_level, cost, stats, "upgrade_armor", id)

	var chips: Array = []
	for i in max_level:
		chips.append({"cost": BlacksmithScript.armor_cost(i), "effect": "+%.1f%% DR" % (BlacksmithScript.ARMOR_DR_PER_LEVEL * 100.0 * (i + 1))})
	_add_level_row(level, chips)

# The "next upgrade" card: what it changes (rows of [label, now, after, note]), the
# price, and the Upgrade button -- or, once maxed, a plain "fully forged" note.
func _add_next_card(level: int, max_level: int, cost: int, stats: Array, method: String, id: String) -> void:
	detail_box.add_child(_make_label("NEXT UPGRADE", 12, TownUIScript.DIM))
	var maxed: bool = cost < 0
	var card := PanelContainer.new()

	card.add_theme_stylebox_override("panel", TownUIScript.box(Color(0.14, 0.12, 0.08, 0.95) if maxed else Color(0.11, 0.11, 0.14, 0.95), TownUIScript.GOLD if maxed else Color(0.38, 0.38, 0.44), 2, 7, 12))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.alignment = BoxContainer.ALIGNMENT_CENTER
	text_col.add_theme_constant_override("separation", 6)
	row.add_child(text_col)
	var title := Label.new()
	title.text = "Fully forged" if maxed else "Upgrade to +%d" % (level + 1)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", TownUIScript.GOLD if maxed else Color(0.94, 0.93, 0.88))
	text_col.add_child(title)
	if maxed:
		text_col.add_child(_make_label("This is as good as I can make it.", 13, Color(0.78, 0.78, 0.74)))
	for stat in stats:
		text_col.add_child(_make_stat_row(stat[0], stat[1], stat[2], stat[3]))

	var affordable: bool = not maxed and _player.coins >= cost
	var action: Dictionary = TownUIScript.make_action("" if maxed else "%d coins" % cost, affordable, "Maxed" if maxed else "Upgrade", maxed or not affordable)
	if not maxed:
		action.button.pressed.connect(Callable(self, method).bind(id))
		upgrade_button = action.button
	row.add_child(action.box)
	detail_box.add_child(card)

# "Damage   12 -> 13   +8% per level": the label dim, the current value white, the
# result green, and a small note.
func _make_stat_row(label_text: String, now: String, after: String, note: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var name_label := Label.new()
	name_label.text = label_text
	name_label.custom_minimum_size = Vector2(130, 0)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", TownUIScript.DIM)
	row.add_child(name_label)
	var now_label := Label.new()
	now_label.text = now
	now_label.add_theme_font_size_override("font_size", 16)
	now_label.add_theme_color_override("font_color", Color(0.94, 0.93, 0.88))
	row.add_child(now_label)
	if after != "":
		var arrow := Label.new()
		arrow.text = "->"
		arrow.add_theme_font_size_override("font_size", 14)
		arrow.add_theme_color_override("font_color", TownUIScript.DIM)
		row.add_child(arrow)
		var after_label := Label.new()
		after_label.text = after
		after_label.add_theme_font_size_override("font_size", 16)
		after_label.add_theme_color_override("font_color", TownUIScript.GOOD)
		row.add_child(after_label)
	var note_label := Label.new()
	note_label.text = note
	note_label.add_theme_font_size_override("font_size", 11)
	note_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
	row.add_child(note_label)
	return row

# One chip per level: +N, what it costs, and the total bonus at that level. Reached
# levels are gold, the next one is bright, later ones are dim.
func _add_level_row(level: int, chips: Array) -> void:
	detail_box.add_child(_make_label("UPGRADE LEVELS", 12, TownUIScript.DIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	detail_box.add_child(row)
	for i in chips.size():
		var reached: bool = i < level
		var is_next: bool = i == level
		var chip := PanelContainer.new()
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var border: Color = TownUIScript.GOLD if reached else (Color(0.85, 0.85, 0.9) if is_next else Color(0.3, 0.3, 0.36))
		chip.add_theme_stylebox_override("panel", TownUIScript.box(Color(0.16, 0.13, 0.07, 0.95) if reached else Color(0.1, 0.1, 0.13, 0.95), border, 2, 6, 8))
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 2)
		chip.add_child(col)
		var name_label := Label.new()
		name_label.text = "+%d" % (i + 1)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 20)
		name_label.add_theme_color_override("font_color", TownUIScript.GOLD if reached else (Color(0.94, 0.93, 0.88) if is_next else Color(0.5, 0.5, 0.55)))
		col.add_child(name_label)
		var effect := Label.new()
		effect.text = chips[i].effect
		effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		effect.add_theme_font_size_override("font_size", 11)
		effect.add_theme_color_override("font_color", TownUIScript.DIM if not reached else Color(0.85, 0.75, 0.45))
		col.add_child(effect)
		var price := Label.new()
		price.text = "done" if reached else "%d c" % chips[i].cost
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price.add_theme_font_size_override("font_size", 12)
		price.add_theme_color_override("font_color", TownUIScript.GOLD if reached else Color(0.7, 0.62, 0.36))
		col.add_child(price)
		row.add_child(chip)

# --- Upgrading ---------------------------------------------------------------

# Both return whether the upgrade went through (tests drive these directly).
func upgrade_weapon(weapon_id: String) -> bool:
	var ok: bool = _player.try_upgrade_weapon(weapon_id)
	_play_sfx("purchase" if ok else "error")
	speech_label.text = "\"There. Sharper than the day it was forged.\"" if ok else "\"Can't do that one -- not enough coin, or it's already as good as I can make it.\""
	_refresh()
	if visible:
		_restore_focus()
	return ok

func upgrade_armor(armor_id: String) -> bool:
	var ok: bool = _player.try_upgrade_armor(armor_id)
	_play_sfx("purchase" if ok else "error")
	speech_label.text = "\"Reinforced. That'll turn a blade.\"" if ok else "\"No. Not enough coin, not metal, or already maxed.\""
	_refresh()
	if visible:
		_restore_focus()
	return ok

# The rebuilt buttons have lost keyboard focus: put it back on the Upgrade button if
# there is one you can press, else on the piece you're looking at.
func _restore_focus() -> void:
	if upgrade_button != null and not upgrade_button.disabled:
		upgrade_button.grab_focus()
		return
	var key := _key(selected_kind, selected_id)
	if entry_buttons.has(key):
		entry_buttons[key].grab_focus()
