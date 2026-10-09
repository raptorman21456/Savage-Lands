extends HBoxContainer
class_name PartyScreen

# The Party screen -- the Inventory's Party tab. A roster down the left; for whoever is selected, a sheet on
# the right: portrait, description, stats (with the level-up picks to spend), the gear they wear (weapon,
# armour, shield, talismans) and the specials they bring into a fight (PartyRules.SPECIAL_SLOTS of them,
# chosen from their kit plus the equipped weapon).
#
# This only draws and reports clicks: every change goes back through InventoryPanel's _on_member_* handlers
# (which call Player / PartyMember and then rebuild), and every number shown comes from
# Main.member_preview(), the same battle unit the fight itself uses.

const PartyRulesScript := preload("res://scripts/PartyRules.gd")
const DefenseScript := preload("res://scripts/Defense.gd")
const ArmorScript := preload("res://scripts/Armor.gd")
const ShieldsScript := preload("res://scripts/Shields.gd")
const WeaponsScript := preload("res://scripts/Weapons.gd")
const TalismansScript := preload("res://scripts/Talismans.gd")

const BLADE_ALLY_ICON := preload("res://assets/blade_ally.png")
const WOLF_ICON := preload("res://assets/enemy_wolf.png")

const GOLD := Color(1, 0.9, 0.3)
const DIM := Color(0.7, 0.7, 0.65)
const TEXT := Color(0.9, 0.9, 0.86)
const GOOD := Color(0.5, 0.9, 0.55)
const LIST_WIDTH := 214.0
const STAT_LABELS := {"hp": "Max HP", "attack": "Attack", "defense": "Defense", "speed": "Speed", "magic": "Magic", "fortitude": "Fortitude"}

var panel = null        # the InventoryPanel (handlers + sfx)
var player: Player = null
var main = null         # Main (member_preview / member_special_pool)
var selected_id := -1   # the PartyMember.id on show

func setup(inventory_panel, player_ref: Player, main_ref) -> void:
	panel = inventory_panel
	player = player_ref
	main = main_ref
	selected_id = panel.party_selected_id
	add_theme_constant_override("separation", 18)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rebuild()

func rebuild() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var members: Array = player.party
	if not members.is_empty() and _member_by_id(selected_id) == null:
		selected_id = members[0].id
		panel.party_selected_id = selected_id
	_build_roster(members)
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 14)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(detail)
	var member = _member_by_id(selected_id)
	if member == null:
		detail.add_child(_label("No party members recruited yet.", 14, DIM))
		return
	_build_header(detail, member)
	_build_stats(detail, member)
	if member.can_carry_gear():
		_build_equipment(detail, member)
	else:
		detail.add_child(_heading("EQUIPMENT"))
		detail.add_child(_label("%s doesn't wear or carry anything." % member.name, 13, DIM))
	_build_specials(detail, member)

func _member_by_id(id: int):
	for m in player.party:
		if m.id == id:
			return m
	return null

# --- small builders ----------------------------------------------------------------------

func _label(text: String, size: int = 14, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _heading(text: String) -> Label:
	return _label(text, 16, GOLD)

func _wrapped(text: String, width: float, size: int = 13, color: Color = DIM) -> Label:
	var l := _label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l

func _style(bg: Color, border: Color, border_width: int = 2, radius: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(6)
	return s

# Whatever picture a member has: assets/portrait_<kind>.png once the art exists, otherwise a stand-in --
# the shared companion icon in the member's colours (the wolf wears its own).
func portrait_texture(kind: String) -> Texture2D:
	var path := "res://assets/portrait_%s.png" % kind
	if ResourceLoader.exists(path):
		return load(path)
	return WOLF_ICON if PartyRulesScript.is_wolf(kind) else BLADE_ALLY_ICON

func _portrait(member, px: float) -> Control:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _style(Color(0.1, 0.1, 0.13), Color(0.45, 0.42, 0.3), 2, 6))
	frame.custom_minimum_size = Vector2(px, px)
	var tex := TextureRect.new()
	tex.texture = portrait_texture(member.kind)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.custom_minimum_size = Vector2(px - 16, px - 16)
	if not ResourceLoader.exists("res://assets/portrait_%s.png" % member.kind) and not member.is_wolf():
		tex.modulate = member.rules().get("tint", Color(1, 1, 1))
	frame.add_child(tex)
	return frame

# --- the roster ----------------------------------------------------------------------------

func _build_roster(members: Array) -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.custom_minimum_size = Vector2(LIST_WIDTH, 0)
	add_child(col)
	col.add_child(_heading("PARTY  %d / %d" % [members.size(), player.party_capacity()]))
	for member in members:
		col.add_child(_roster_card(member))
	# The older flat companions (a recruited Warrior...) have no sheet of their own.
	for ally in player.party_members:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _style(Color(0.1, 0.1, 0.12), Color(0.3, 0.3, 0.33), 1, 6))
		var box := VBoxContainer.new()
		card.add_child(box)
		box.add_child(_label(str(ally.get("name", "Ally")), 14, TEXT))
		box.add_child(_label("%d%% damage" % int(float(ally.get("dmg_mult", 1.0)) * 100.0), 12, DIM))
		col.add_child(card)

func _roster_card(member) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = member.id == selected_id
	b.custom_minimum_size = Vector2(LIST_WIDTH, 66)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _style(Color(0.12, 0.12, 0.15), Color(0.4, 0.4, 0.45)))
	b.add_theme_stylebox_override("hover", _style(Color(0.18, 0.17, 0.12), GOLD))
	b.add_theme_stylebox_override("pressed", _style(Color(0.22, 0.18, 0.05), Color(1.0, 0.85, 0.2), 3))
	b.pressed.connect(func(): _select(member.id))
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var icon := _portrait(member, 54)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(text)
	var name_label := _label(member.name, 15, GOLD if member.id == selected_id else TEXT)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(name_label)
	var sub := "%d battles left" % member.battles_left if member.is_wolf() and member.battles_left >= 0 else ("Lv %d" % member.level if member.levels() else "")
	if member.picks > 0:
		sub += "  ·  %d pick%s" % [member.picks, "" if member.picks == 1 else "s"]
	var sub_label := _label(sub, 12, GOOD if member.picks > 0 else DIM)
	sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(sub_label)
	return b

func _select(id: int) -> void:
	selected_id = id
	panel.party_selected_id = id
	if panel != null and panel.has_method("_play_sfx"):
		panel._play_sfx("menu_move")
	rebuild()

# --- the header: portrait, name, level, picks to spend, description --------------------------

func _build_header(detail: VBoxContainer, member) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	detail.add_child(row)
	row.add_child(_portrait(member, 128))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	col.add_child(_label(member.name, 26, GOLD))
	var sub := ""
	if member.is_wolf():
		sub = "Companion  ·  never levels"
	else:
		sub = "Level %d" % member.level
	col.add_child(_label(sub, 14, DIM))
	if member.levels():
		col.add_child(_label("XP %d / %d" % [member.xp, member.xp_to_next()], 13, DIM))
	if member.picks > 0:
		col.add_child(_label("%d bonus pick%s to spend -- press + beside a stat below" % [member.picks, "" if member.picks == 1 else "s"], 13, GOOD))
	if member.is_wolf():
		var left := "no limit" if member.battles_left < 0 else "%d battles" % member.battles_left
		col.add_child(_label("Loyal for %s  ·  fainted %d of %d times" % [left, member.faints, PartyRulesScript.WOLF_MAX_FAINTS], 13, DIM))
	col.add_child(_wrapped(str(member.rules().get("description", "")), 430, 13, TEXT))

# --- the stats sheet --------------------------------------------------------------------------

func _build_stats(detail: VBoxContainer, member) -> void:
	detail.add_child(_heading("STATS"))
	var u: Dictionary = main.member_preview(member)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 3)
	detail.add_child(grid)
	var defense_cut: float = DefenseScript.reduction(float(u.defense_pct), float(u.get("defense_cap", DefenseScript.BASE_CAP)))
	var fort_cut: float = DefenseScript.reduction(float(u.fortitude), float(u.get("defense_cap", DefenseScript.BASE_CAP)))
	_stat_row(grid, member, "hp", "%d" % int(u.max_hp), "")
	_stat_row(grid, member, "attack", "%.1f" % float(u.attack), "")
	_stat_row(grid, member, "defense", "%.0f" % float(u.defense_pct), "bodily harm -%d%%" % int(round(defense_cut * 100.0)))
	_stat_row(grid, member, "fortitude", "%.0f" % float(u.fortitude), "magical harm %s%d%%" % ["-" if fort_cut >= 0.0 else "+", absi(int(round(fort_cut * 100.0)))])
	_stat_row(grid, member, "speed", "%.1f" % float(u.get("speed", 5.0)), "acts %s often" % _speed_word(float(u.get("speed", 5.0))))
	if float(u.get("magic", 0.0)) > 0.0 or member.is_caster():
		_stat_row(grid, member, "magic", "%.1f" % float(u.magic), "")
	_plain_row(grid, "Move", "%d tile%s" % [int(u.move_range), "" if int(u.move_range) == 1 else "s"], "", "How far it walks in a turn")
	_plain_row(grid, "Reach", "%d" % int(u.attack_range), "tiles away it can attack", "")
	var pool_text := ""
	if bool(u.get("hp_as_mana", false)):
		pool_text = "spells cost HP"
	elif int(u.max_mana) > 0:
		pool_text = "%d mana" % int(u.max_mana)
	elif int(u.max_stamina) > 0:
		pool_text = "%d stamina" % int(u.max_stamina)
	if pool_text != "":
		_plain_row(grid, "Pool", pool_text, "", "")
	if float(u.get("dodge_chance", 0.0)) > 0.0:
		_plain_row(grid, "Dodge", "%d%%" % int(round(float(u.dodge_chance) * 100.0)), "", "")
	if float(u.get("shield_block", 0.0)) > 0.0:
		_plain_row(grid, "Block", "%d%%" % int(round(float(u.shield_block) * 100.0)), "with its shield", "")

# Speed as the user will feel it in the turn order strip: relative to the hero's 5.
func _speed_word(speed: float) -> String:
	if speed >= 8.0:
		return "much more"
	if speed > 5.4:
		return "more"
	if speed >= 4.6:
		return "as"
	if speed > 2.9:
		return "less"
	return "far less"

func _stat_row(grid: GridContainer, member, stat: String, value: String, detail_text: String) -> void:
	var growth: float = PartyRulesScript.growth(member.kind, stat)
	var name_label := _label(STAT_LABELS[stat], 14, TEXT)
	name_label.custom_minimum_size = Vector2(96, 26)
	name_label.tooltip_text = "Levels up at x%s the usual rate." % _trim(growth)
	name_label.mouse_filter = Control.MOUSE_FILTER_STOP
	grid.add_child(name_label)
	var value_label := _label(value, 14, GOLD)
	value_label.custom_minimum_size = Vector2(60, 0)
	grid.add_child(value_label)
	var detail_label := _label(detail_text, 12, DIM)
	detail_label.custom_minimum_size = Vector2(250, 0)
	grid.add_child(detail_label)
	if member.picks > 0 and stat in member.pickable_stats():
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(30, 24)
		plus.tooltip_text = "Spend a bonus pick on %s." % STAT_LABELS[stat]
		plus.pressed.connect(func(): panel._on_member_pick_spent(member, stat))
		grid.add_child(plus)
	else:
		grid.add_child(Control.new())

func _plain_row(grid: GridContainer, name_text: String, value: String, detail_text: String, tip: String) -> void:
	var name_label := _label(name_text, 14, TEXT)
	name_label.custom_minimum_size = Vector2(0, 26)
	name_label.tooltip_text = tip
	grid.add_child(name_label)
	grid.add_child(_label(value, 14, GOLD))
	grid.add_child(_label(detail_text, 12, DIM))
	grid.add_child(Control.new())

static func _trim(x: float) -> String:
	var s := "%.2f" % x
	while s.ends_with("0") and s.contains("."):
		s = s.substr(0, s.length() - 1)
	return s.trim_suffix(".")

# --- equipment ---------------------------------------------------------------------------------

func _build_equipment(detail: VBoxContainer, member) -> void:
	detail.add_child(_heading("EQUIPMENT"))
	detail.add_child(_wrapped("From your own collection -- each item can only be with one of you at a time.", 560, 12, DIM))

	var weapon_pick := OptionButton.new()
	weapon_pick.custom_minimum_size = Vector2(330, 0)
	weapon_pick.add_item("(bare hands)")
	weapon_pick.set_item_metadata(0, "")
	var current_id: String = member.weapon_id()
	var ids: Array = player.owned_weapons.keys()
	ids.sort_custom(func(a, b): return str(WeaponsScript.get_owned_variant(a).get("name", a)) < str(WeaponsScript.get_owned_variant(b).get("name", b)))
	for id in ids:
		var variant: Dictionary = WeaponsScript.get_owned_variant(id)
		if variant.is_empty():
			continue
		var reason: String = player.ally_weapon_block_reason(member, id)
		var idx: int = weapon_pick.item_count
		weapon_pick.add_item(str(variant.get("name", id)) if reason == "" else "%s  (%s)" % [variant.get("name", id), reason])
		weapon_pick.set_item_metadata(idx, id)
		weapon_pick.set_item_disabled(idx, reason != "")
		if id == current_id:
			weapon_pick.select(idx)
	weapon_pick.item_selected.connect(func(i): panel._on_member_weapon_picked(member, str(weapon_pick.get_item_metadata(i))))
	detail.add_child(_gear_row("Weapon", weapon_pick))

	var armor_pick := OptionButton.new()
	armor_pick.custom_minimum_size = Vector2(330, 0)
	armor_pick.add_item("(none)")
	armor_pick.set_item_metadata(0, "")
	for armor in ArmorScript.TIERS:
		if armor.id == "armor_rags" or not player.owned_armor.has(armor.id):
			continue
		var armor_reason: String = player.ally_armor_block_reason(member, armor.id)
		var armor_idx: int = armor_pick.item_count
		var armor_text: String = "%s  (+%d Def, %+d Fort)" % [armor.name, int(round(player.armor_defense_fraction(armor) * 100.0)), int(armor.fortitude)]
		armor_pick.add_item(armor_text if armor_reason == "" else "%s  (%s)" % [armor.name, armor_reason])
		armor_pick.set_item_metadata(armor_idx, armor.id)
		armor_pick.set_item_disabled(armor_idx, armor_reason != "")
		if armor.id == member.armor_id():
			armor_pick.select(armor_idx)
	armor_pick.item_selected.connect(func(i): panel._on_member_armor_picked(member, str(armor_pick.get_item_metadata(i))))
	armor_pick.tooltip_text = "Defense is bent into a damage cut with diminishing returns. Fortitude does the same against magic."
	detail.add_child(_gear_row("Armour", armor_pick))

	var shield_pick := OptionButton.new()
	shield_pick.custom_minimum_size = Vector2(330, 0)
	shield_pick.add_item("(none)")
	shield_pick.set_item_metadata(0, "")
	for shield_id in ShieldsScript.SHIELD_IDS:
		var shield_reason: String = player.ally_shield_block_reason(member, shield_id)
		if shield_reason == "You don't own that shield.":
			continue
		var shield_data: Dictionary = ShieldsScript.SHIELDS[shield_id]
		var shield_idx: int = shield_pick.item_count
		shield_pick.add_item(str(shield_data.name) if shield_reason == "" else "%s  (%s)" % [shield_data.name, shield_reason])
		shield_pick.set_item_metadata(shield_idx, shield_id)
		shield_pick.set_item_disabled(shield_idx, shield_reason != "")
		if shield_id == member.shield_id():
			shield_pick.select(shield_idx)
	shield_pick.item_selected.connect(func(i): panel._on_member_shield_picked(member, str(shield_pick.get_item_metadata(i))))
	var shield_row := _gear_row("Shield", shield_pick)
	if member.shield_id() != "" and not member.shield_usable():
		shield_row.add_child(_label("(needs a free hand -- it does nothing with this weapon)", 12, Color(0.85, 0.6, 0.45)))
	detail.add_child(shield_row)

	var talisman_row := HBoxContainer.new()
	talisman_row.add_theme_constant_override("separation", 8)
	var talisman_label := _label("Talismans  %d / %d" % [member.talisman_ids().size(), member.talisman_slot_count()], 14, TEXT)
	talisman_label.custom_minimum_size = Vector2(100, 0)
	talisman_row.add_child(talisman_label)
	for id in member.talisman_ids():
		var talisman: Dictionary = TalismansScript.get_talisman(id)
		var worn_button := Button.new()
		worn_button.text = "%s  ✕" % talisman.get("name", id)
		worn_button.tooltip_text = "%s (click to take it off)" % talisman.get("description", "")
		worn_button.pressed.connect(func(): panel._on_member_talisman_removed(member, id))
		talisman_row.add_child(worn_button)
	if member.talisman_ids().size() < member.talisman_slot_count():
		var add_pick := OptionButton.new()
		add_pick.add_item("+ add a talisman")
		add_pick.set_item_metadata(0, "")
		for item in TalismansScript.ITEMS:
			if player.ally_talisman_block_reason(member, item.id) == "":
				var tidx: int = add_pick.item_count
				add_pick.add_item(item.name)
				add_pick.set_item_metadata(tidx, item.id)
		if add_pick.item_count > 1:
			add_pick.item_selected.connect(func(i): panel._on_member_talisman_added(member, str(add_pick.get_item_metadata(i))))
			talisman_row.add_child(add_pick)
	else:
		talisman_row.add_child(_label("(slots full)", 13, DIM))
	detail.add_child(talisman_row)

func _gear_row(caption: String, picker: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := _label(caption, 14, TEXT)
	l.custom_minimum_size = Vector2(100, 0)
	row.add_child(l)
	row.add_child(picker)
	return row

# --- the specials loadout ----------------------------------------------------------------------

func _build_specials(detail: VBoxContainer, member) -> void:
	var pool: Array = main.member_special_pool(member)
	var pool_ids: Array = pool.map(func(e): return str(e.special.get("id", "")))
	var slots := PartyRulesScript.SPECIAL_SLOTS
	var heading_row := HBoxContainer.new()
	heading_row.add_theme_constant_override("separation", 14)
	heading_row.add_child(_heading("SPECIALS"))
	var filled := 0
	for i in slots:
		if member.loadout_slot(i, pool_ids) != "":
			filled += 1
	heading_row.add_child(_label("%d / %d slots  ·  from %d it could bring" % [filled, slots, pool.size()], 13, DIM))
	if member.loadout_set:
		var reset := Button.new()
		reset.text = "Reset to default"
		reset.tooltip_text = "Go back to the first %d of its kit and weapon specials." % slots
		reset.pressed.connect(func(): panel._on_member_loadout_reset(member))
		heading_row.add_child(reset)
	detail.add_child(heading_row)
	detail.add_child(_wrapped("Mix and match: its own kit's specials and the equipped weapon's. Only the ones in a slot appear in its command menu.", 560, 12, DIM))
	for i in slots:
		detail.add_child(_special_slot_row(member, i, pool, pool_ids))

func _special_slot_row(member, slot: int, pool: Array, pool_ids: Array) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var cap := _label("Slot %d" % (slot + 1), 14, TEXT)
	cap.custom_minimum_size = Vector2(100, 0)
	row.add_child(cap)
	var current: String = member.loadout_slot(slot, pool_ids)
	var pick := OptionButton.new()
	pick.custom_minimum_size = Vector2(430, 0)
	pick.add_item("(empty)")
	pick.set_item_metadata(0, "")
	var selected_description := ""
	for entry in pool:
		var s: Dictionary = entry.special
		var id := str(s.get("id", ""))
		var idx: int = pick.item_count
		var source := "kit" if bool(s.get("kit", false)) else "weapon"
		var in_other := -1
		for j in PartyRulesScript.SPECIAL_SLOTS:
			if j != slot and member.loadout_slot(j, pool_ids) == id:
				in_other = j
		var text := "%s%s   [%s]" % [str(s.get("name", id)), str(entry.cost_text), source]
		if in_other >= 0:
			text += "   (in slot %d)" % (in_other + 1)
		pick.add_item(text)
		pick.set_item_metadata(idx, id)
		pick.set_item_disabled(idx, in_other >= 0)
		if id == current:
			pick.select(idx)
			selected_description = str(s.get("description", ""))
	pick.item_selected.connect(func(i): panel._on_member_special_slot(member, slot, str(pick.get_item_metadata(i))))
	row.add_child(pick)
	if selected_description != "":
		var d := _wrapped(selected_description, 470, 12, DIM)
		var indent := MarginContainer.new()
		indent.add_theme_constant_override("margin_left", 110)
		indent.add_child(d)
		box.add_child(indent)
	return box
