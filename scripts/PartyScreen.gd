extends Control
class_name PartyScreen

# The Party tab, with YOU and your recruits on one page: a roster of portraits across the top ("You" first), a sheet down the left
# (portrait, name, level, vitals) and, at the right, small pages -- Equipment (a tile for each thing worn; press one to pick what goes
# there, the Talismans line opens the talisman screen), Specials, Stats, and for you also Defense and Run. A recruit's specials are the
# three loadout slots it brings into a fight, chosen from its own kit and its weapon.
#
# This only draws and reports clicks: every change goes back through InventoryPanel's handlers (which call Player / PartyMember and
# then rebuild), and every number shown for a recruit comes from Main.member_preview(), the same battle unit the fight itself uses.

const PartyRulesScript := preload("res://scripts/PartyRules.gd")
const DefenseScript := preload("res://scripts/Defense.gd")
const TalismansScript := preload("res://scripts/Talismans.gd")
const UIIconsScript := preload("res://scripts/UIIcons.gd")

const HERO_ID := -2
const BLADE_ALLY_ICON := preload("res://assets/blade_ally.png")
const WOLF_ICON := preload("res://assets/enemy_wolf.png")

# The stat pages: member stat -> its icon and label (the members' own stat names, not the hero's level-up stats).
const MEMBER_STAT_ICONS := {"hp": "stat_health", "attack": "stat_damage", "defense": "stat_defense", "fortitude": "stat_fortitude", "speed": "stat_speed", "magic": "stat_magic"}
const MEMBER_STAT_LABELS := {"hp": "Max HP", "attack": "Attack", "defense": "Defense", "fortitude": "FTD", "speed": "Speed", "magic": "Magic"}

var panel = null          # the InventoryPanel (handlers, popups, sfx)
var player: Player = null
var main = null           # Main (member_preview / member_special_pool / the run's stats)
var selected_id := HERO_ID
var page := "Equipment"
var roster_tiles: Dictionary = {}   # id -> its tile
var content_root: VBoxContainer = null
var left_panel: Control = null

func setup(inventory_panel, player_ref: Player, main_ref) -> void:
	panel = inventory_panel
	player = player_ref
	main = main_ref
	selected_id = panel.party_selected_id
	page = panel.party_page
	rebuild()

func unit_member():
	return _member_by_id(selected_id)

func _member_by_id(id: int):
	if id == HERO_ID:
		return null
	for m in player.party:
		if m.id == id:
			return m
	return null

func is_hero() -> bool:
	return selected_id == HERO_ID or _member_by_id(selected_id) == null

func pages_for(member) -> Array:
	if member == null:
		return ["Equipment", "Specials", "Stats", "Defense", "Run"]
	return ["Equipment", "Specials", "Stats"]

# A portrait for a kind: its face if one is drawn, else a stand-in (the shared companion icon, the wolf's own).
func portrait_texture(kind: String) -> Texture2D:
	var tex: Texture2D = UIIconsScript.texture("face_%s" % kind)
	if tex != null:
		return tex
	return WOLF_ICON if PartyRulesScript.is_wolf(kind) else BLADE_ALLY_ICON

func rebuild() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	roster_tiles.clear()
	var member = _member_by_id(selected_id)
	if selected_id != HERO_ID and member == null:
		selected_id = HERO_ID
		panel.party_selected_id = HERO_ID
	var pages := pages_for(member)
	if not pages.has(page):
		page = "Equipment"
	panel.party_page = page
	_build_roster()
	_build_left(member)
	_build_right(member, pages)

# --- the roster ------------------------------------------------------------------------------------------------------------------------

func _build_roster() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	row.add_child(_roster_tile(HERO_ID, "You", "face_you", "Level %d" % player.level))
	for m in player.party:
		var sub := "Level %d" % m.level if m.levels() else ""
		if m.picks > 0:
			sub = "%d pick%s" % [m.picks, "" if m.picks == 1 else "s"]
		row.add_child(_roster_tile(m.id, str(m.name), "face_%s" % m.kind, sub))
	var cap := PixelKit.label("Party  %d / %d" % [player.party.size(), player.party_capacity()], "body", PixelKit.DIM)
	cap.position = Vector2(size.x - 190.0, 4)
	add_child(cap)
	# The older flat companions have no sheet of their own: one dim line.
	if not player.party_members.is_empty():
		var names: Array = []
		for ally in player.party_members:
			names.append("%s (%d%% damage)" % [str(ally.get("name", "Ally")), int(float(ally.get("dmg_mult", 1.0)) * 100.0)])
		var also := PixelKit.label("Also with you: " + ", ".join(names), "body", PixelKit.DIM)
		also.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		also.custom_minimum_size = Vector2(180, 0)
		also.position = Vector2(size.x - 190.0, 30)
		also.size = Vector2(180, 0)
		add_child(also)

func _roster_tile(id: int, unit_name: String, face: String, sub: String) -> Control:
	var on: bool = id == selected_id
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.custom_minimum_size = Vector2(96, 0)
	col.mouse_filter = Control.MOUSE_FILTER_STOP
	col.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	col.modulate = Color(1, 1, 1, 1) if on else Color(1, 1, 1, 0.62)
	var tile := Panel.new()
	tile.custom_minimum_size = Vector2(80, 80)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tile.add_theme_stylebox_override("panel", PixelKit.frame("card_worn" if on else "card"))
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner := ColorRect.new()
	inner.color = PixelKit.V0
	inner.position = Vector2(12, 12)
	inner.size = Vector2(56, 56)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(inner)
	var face_tex: Texture2D = UIIconsScript.texture(face)
	if face_tex == null:
		face_tex = portrait_texture(face.trim_prefix("face_"))
	var face_rect := PixelKit.art(face_tex, 32)
	face_rect.position = Vector2(12, 12)
	inner.add_child(face_rect)
	col.add_child(tile)
	var name_label := PixelKit.label(unit_name, "body", PixelKit.GOLD3 if on else PixelKit.DIM)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_label)
	col.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: _select(id))
	col.tooltip_text = sub
	roster_tiles[id] = col
	return col

func _select(id: int) -> void:
	selected_id = id
	panel.party_selected_id = id
	panel._play_sfx("menu_move")
	rebuild()

# --- the sheet on the left -------------------------------------------------------------------------------------------------------------

func _build_left(member) -> void:
	var box := PixelKit.panel("panel_steel", 8, 4)
	box.position = Vector2(0, 104)
	box.size = Vector2(288, size.y - 104.0)
	box.custom_minimum_size = box.size
	add_child(box)
	left_panel = box
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	box.add_child(col)
	var portrait := PixelKit.panel("inset")
	portrait.custom_minimum_size = Vector2(144, 144)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var face_name := "face_you" if member == null else "face_%s" % member.kind
	var face_tex: Texture2D = UIIconsScript.texture(face_name)
	if face_tex == null and member != null:
		face_tex = portrait_texture(member.kind)
	var face := PixelKit.art(face_tex, 128)
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.add_child(face)
	col.add_child(portrait)
	var title := PixelKit.label("You" if member == null else str(member.name), "head", PixelKit.GOLD3)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var level_text := ""
	var xp_ratio := -1.0
	var xp_text := ""
	if member == null:
		level_text = "Level %d" % player.level
		xp_ratio = float(player.xp) / maxf(1.0, float(player.xp_to_next))
		xp_text = "XP %d / %d" % [player.xp, player.xp_to_next]
	elif member.is_wolf():
		level_text = "Companion · never levels"
	else:
		level_text = "Level %d" % member.level
		xp_ratio = float(member.xp) / maxf(1.0, float(member.xp_to_next()))
		xp_text = "XP %d / %d" % [member.xp, member.xp_to_next()]
	var lv := HBoxContainer.new()
	lv.alignment = BoxContainer.ALIGNMENT_CENTER
	lv.add_theme_constant_override("separation", 8)
	if member == null or not member.is_wolf():
		lv.add_child(PixelKit.icon("stat_level", 32))
	lv.add_child(PixelKit.label(level_text, "body", PixelKit.DIM))
	col.add_child(lv)
	if xp_ratio >= 0.0:
		var bar_row := HBoxContainer.new()
		bar_row.alignment = BoxContainer.ALIGNMENT_CENTER
		bar_row.add_child(PixelKit.bar(200, xp_ratio))
		col.add_child(bar_row)
		var xp := PixelKit.label(xp_text, "body", PixelKit.DIM)
		xp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(xp)
	var vitals := VBoxContainer.new()
	vitals.add_theme_constant_override("separation", 0)
	col.add_child(vitals)
	if member == null:
		InvWidgets.icon_row(vitals, "stat_health", "HP", "%d/%d" % [player.health, player.max_health])
		InvWidgets.icon_row(vitals, "stat_stamina", "Stamina", "%d/%d" % [player.stamina, player.max_stamina])
	else:
		var u: Dictionary = main.member_preview(member)
		InvWidgets.icon_row(vitals, "stat_health", "HP", "%d" % int(u.max_hp))
		if bool(u.get("hp_as_mana", false)):
			vitals.add_child(PixelKit.label("Her mana is her HP.", "body", PixelKit.DIM))
		elif int(u.max_mana) > 0:
			InvWidgets.icon_row(vitals, "stat_mana", "Mana", "%d" % int(u.max_mana))
		elif int(u.max_stamina) > 0:
			InvWidgets.icon_row(vitals, "stat_stamina", "Stamina", "%d" % int(u.max_stamina))
		if member.is_wolf():
			# a wolf stays only so many battles, and is lost for good if it faints too often
			var stays := "no limit" if member.battles_left < 0 else "%d battle%s" % [member.battles_left, "" if member.battles_left == 1 else "s"]
			InvWidgets.icon_row(vitals, "", "Loyal for", stays, "Battles left before the wolf leaves your pack.")
			InvWidgets.icon_row(vitals, "", "Fainted", "%d of %d" % [member.faints, PartyRulesScript.WOLF_MAX_FAINTS], "A wolf that faints this many times is gone for good.")
		if member.picks > 0:
			var picks := HBoxContainer.new()
			picks.alignment = BoxContainer.ALIGNMENT_CENTER
			picks.add_child(PixelKit.label("%d bonus pick%s to spend" % [member.picks, "" if member.picks == 1 else "s"], "body", PixelKit.GOOD))
			col.add_child(picks)

# --- the pages on the right -----------------------------------------------------------------------------------------------------------

func _build_right(member, pages: Array) -> void:
	var box := PixelKit.panel("panel_steel", 8, 4)
	box.position = Vector2(304, 104)
	box.size = Vector2(size.x - 304.0, size.y - 104.0)
	box.custom_minimum_size = box.size
	add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	box.add_child(col)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 0)
	col.add_child(tabs)
	var icons := {"Equipment": "tab_gear", "Specials": "stat_crit", "Stats": "stat_strength", "Defense": "stat_defense", "Run": "stat_speed"}
	for p in pages:
		tabs.add_child(PixelButton.make(p, icons[p], _on_page.bind(p), p == page))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	PixelKit.style_scroll(scroll)
	col.add_child(scroll)
	content_root = VBoxContainer.new()
	content_root.add_theme_constant_override("separation", 6)
	content_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content_root)
	match page:
		"Equipment":
			_page_equipment(member)
		"Specials":
			_page_specials(member)
		"Stats":
			_page_stats(member)
		"Defense":
			_page_defense()
		"Run":
			_page_run()

func _on_page(p: String) -> void:
	page = p
	panel.party_page = p
	panel._play_sfx("menu_move")
	rebuild()

# --- Equipment: a tile for everything worn ---------------------------------------------------------------------------------------------

func _page_equipment(member) -> void:
	if member != null and not member.can_carry_gear():
		content_root.add_child(InvWidgets.paragraph("%s doesn't wear or carry anything." % member.name))
		return
	var who := InvData.unit_name(member)
	var cell_w := (size.x - 304.0 - 16.0 - 16.0 - 12.0) / 2.0
	var cells: Array = []
	cells.append(["sub_weapons", "Weapon", "Weapons"])
	cells.append(["sub_armour", "Armour", "Armour"])
	if member == null:
		cells.append(["sub_clothes", "Clothes", "Clothes"])
	cells.append(["sub_shields", "Shield", "Shields"])
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 4)
	content_root.add_child(grid)
	for c in cells:
		var worn: Array = InvData.gear_entries(player, c[2], member).filter(func(e): return e.holders.has(who))
		grid.add_child(_slot_cell(c[0], c[1], c[2], worn, member, cell_w))
	content_root.add_child(_talisman_line(member))
	content_root.add_child(InvWidgets.paragraph("Press a tile to change what %s. Talisman slots open at levels %s." % ["you wear" if member == null else "%s wears" % member.name, ", ".join(["1"] + TalismansScript.SLOT_LEVELS.map(func(l): return str(l)))]))

func _slot_cell(icon_name: String, label: String, category: String, worn: Array, member, width: float) -> Control:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(width, 0)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cell.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(row)
	var shown: Dictionary = worn[0] if not worn.is_empty() else {}
	var tile_info := {"art": shown.get("art", null), "quality": str(shown.get("quality", "")) if str(shown.get("quality", "")) != "Starter" else "", "key": str(shown.get("key", category))}
	var tile := InvCard.tile(tile_info, 104, "card", 22.0)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tile)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(PixelKit.icon(icon_name, 32))
	head.add_child(PixelKit.label(label, "body", PixelKit.DIM))
	col.add_child(head)
	if worn.is_empty():
		col.add_child(PixelKit.label("—", "body", PixelKit.DIM))
	else:
		for e in worn:
			var n := PixelKit.label(str(e.name), "myth" if bool(e.mythic) else "body", PixelKit.QUALITY_TEXT.Mythic if bool(e.mythic) else PixelKit.CREAM)
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE
			n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			col.add_child(n)
		if worn.size() == 1 and str(shown.get("sub", "")) != "":   # (two pieces of clothing: the first one's slot would say nothing about the second)
			col.add_child(PixelKit.label(str(shown.sub), "body", PixelKit.QUALITY_TEXT.get(str(shown.quality), PixelKit.DIM)))
	var arrow := PixelKit.label("›", "head", PixelKit.GOLD3)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(arrow)
	cell.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: panel.open_gear_popup(member, category))
	cell.set_meta("category", category)
	return cell

func _talisman_line(member) -> Control:
	var slots := InvData.talisman_slots(player, member)
	var line := PanelContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_STOP
	line.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	line.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(row)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.custom_minimum_size = Vector2(190, 0)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(PixelKit.icon("tab_talismans", 32))
	head.add_child(PixelKit.label("Talismans", "body", PixelKit.DIM))
	row.add_child(head)
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 8)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pips)
	var all := InvData.talisman_entries(player)
	for i in TalismansScript.SLOT_LEVELS.size() + 1:
		var tile := Panel.new()
		tile.custom_minimum_size = Vector2(64, 64)
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i < slots.worn.size():
			tile.add_theme_stylebox_override("panel", PixelKit.frame("card_worn"))
			var worn_entry: Dictionary = {}
			for e in all:
				if str(e.id) == str(slots.worn[i]):
					worn_entry = e
			var inner := ColorRect.new()
			inner.color = Color(PixelKit.RARITY_COLORS.get(str(worn_entry.get("rarity", "common")), PixelKit.CREAM), 0.2)
			inner.position = Vector2(12, 12)
			inner.size = Vector2(40, 40)
			inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.add_child(inner)
			var art := PixelKit.art(worn_entry.get("art", null), 32)
			art.position = Vector2(4, 4)
			inner.add_child(art)
		elif i < int(slots.open):
			tile.add_theme_stylebox_override("panel", PixelKit.frame("inset"))
		else:
			tile.add_theme_stylebox_override("panel", PixelKit.frame("inset"))
			var l := PixelKit.label("Lv %d" % TalismansScript.level_for_slot(i + 1), "body", PixelKit.DIM)
			l.position = Vector2(8, 18)
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.add_child(l)
		pips.add_child(tile)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	row.add_child(PixelKit.label("%d / %d slots" % [slots.worn.size(), int(slots.open)], "body", PixelKit.DIM))
	var arrow := PixelKit.label("›", "head", PixelKit.GOLD3)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(arrow)
	line.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: panel.open_talisman_popup(member))
	line.set_meta("category", "Talismans")
	return line

# --- Specials -------------------------------------------------------------------------------------------------------------------------

func _page_specials(member) -> void:
	if member == null:
		_hero_specials()
	else:
		_member_specials(member)

# Yours: the equipped weapon's three, greyed where you have not learned them at the Dojo.
func _hero_specials() -> void:
	var weapon: Dictionary = player.current_weapon_base
	if weapon.is_empty():
		content_root.add_child(InvWidgets.paragraph("You are bare-handed: no specials."))
		return
	var entry := InvData.weapon_entry(player, weapon, null)
	content_root.add_child(InvWidgets.caption("From your %s" % str(entry.name)))
	if entry.specials.is_empty():
		var bow: bool = str(weapon.get("id", "")) == "bow"
		content_root.add_child(InvWidgets.paragraph("The Bow has no specials of its own: you fire the special arrows you carry." if bow else "No specials."))
		return
	var list: Array = []
	for s in entry.specials:
		var item: Dictionary = {"n": s.n, "c": s.c, "d": s.d}
		if not bool(s.learned):
			item["lock"] = "Dojo"
			item["hint"] = "Not learned yet: learn it at the Dojo."
		list.append(item)
	var box := SpecialsBox.new()
	content_root.add_child(box)
	box.setup(list, 0)

# A recruit's: PartyRules.SPECIAL_SLOTS slots, each filled from its kit and weapon; press a slot to change it.
func _member_specials(member) -> void:
	var pool: Array = main.member_special_pool(member)
	var pool_ids: Array = pool.map(func(e): return str(e.special.get("id", "")))
	var slots := PartyRulesScript.SPECIAL_SLOTS
	var filled := 0
	for i in slots:
		if member.loadout_slot(i, pool_ids) != "":
			filled += 1
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	content_root.add_child(head)
	head.add_child(PixelKit.label("%d / %d slots  ·  from %d it could bring" % [filled, slots, pool.size()], "body", PixelKit.DIM))
	if member.loadout_set:
		head.add_child(PixelButton.make("Reset to default", "", func(): panel._on_member_loadout_reset(member)))
	content_root.add_child(InvWidgets.paragraph("Mix its own kit's specials and the equipped weapon's. Only the ones in a slot appear in its command menu."))
	for i in slots:
		content_root.add_child(_special_slot(member, i, pool, pool_ids))

func _special_slot(member, slot: int, pool: Array, pool_ids: Array) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var cap := PixelKit.label("Slot %d" % (slot + 1), "body", PixelKit.DIM)
	cap.custom_minimum_size = Vector2(90, 0)
	row.add_child(cap)
	var current: String = member.loadout_slot(slot, pool_ids)
	var current_entry: Dictionary = {}
	for e in pool:
		if str(e.special.get("id", "")) == current:
			current_entry = e
	var text := "(empty)" if current_entry.is_empty() else "%s%s" % [str(current_entry.special.get("name", current)), str(current_entry.cost_text)]
	var button := PixelButton.make(text, "", func(): _pick_special(member, slot, pool, pool_ids), not current_entry.is_empty())
	button.set_meta("slot", slot)
	row.add_child(button)
	if not current_entry.is_empty():
		var source := "kit" if bool(current_entry.special.get("kit", false)) else "weapon"
		row.add_child(PixelKit.label("[%s]" % source, "body", PixelKit.DIM))
		var d := InvWidgets.paragraph(str(current_entry.special.get("description", "")).replace("%%", "%"))
		var indent := MarginContainer.new()
		indent.add_theme_constant_override("margin_left", 102)
		indent.add_child(d)
		box.add_child(indent)
	return box

func _pick_special(member, slot: int, pool: Array, pool_ids: Array) -> void:
	var rows: Array = [{"label": "(empty)", "right": "", "disabled": false, "pick": func(): panel._on_member_special_slot(member, slot, "")}]
	for e in pool:
		var s: Dictionary = e.special
		var id := str(s.get("id", ""))
		var in_other := -1
		for j in PartyRulesScript.SPECIAL_SLOTS:
			if j != slot and member.loadout_slot(j, pool_ids) == id:
				in_other = j
		rows.append({
			"label": "%s%s" % [str(s.get("name", id)), str(e.cost_text)],
			"right": ("in slot %d" % (in_other + 1)) if in_other >= 0 else ("kit" if bool(s.get("kit", false)) else "weapon"),
			"disabled": in_other >= 0, "pick": func(): panel._on_member_special_slot(member, slot, id),
		})
	panel.open_pick_popup("Slot %d" % (slot + 1), "%s's specials" % member.name, rows)

# --- Stats ----------------------------------------------------------------------------------------------------------------------------

func _page_stats(member) -> void:
	if member == null:
		_hero_stats()
	else:
		_member_stats(member)

# Your level-up stats: the always-there five, then Resilience / Reflexes / Dexterity / Fortitude once their unlocks are owned
# (the same set the level-up screen offers). Rage, Magic and Intelligence have no stat in the game yet, so they are not listed.
func _hero_stats() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 0)
	content_root.add_child(grid)
	for id in hero_stat_ids():
		var row := _stat_line(UIIconsScript.stat_icon(id), UIIconsScript.stat_abbr(id), str(UIIconsScript.STAT_INFO[id].does), str(player.get("stat_%s" % id)), UIIconsScript.stat_tooltip(id))
		row.custom_minimum_size = Vector2((size.x - 304.0 - 16.0 - 16.0 - 24.0) / 2.0, 36)
		grid.add_child(row)
	content_root.add_child(InvWidgets.paragraph("Hover a stat for more."))

func hero_stat_ids() -> Array:
	var ids: Array = ["might", "strength", "vigor", "agility", "intimidation"]
	if player.meta_dexterity_unlocked:
		ids.append("dexterity")
	if player.meta_resilience_unlocked:
		ids.append("resilience")
	if player.meta_reflexes_unlocked:
		ids.append("reflexes")
	if player.meta_fortitude_unlocked:
		ids.append("fortitude")
	return ids

func _stat_line(icon_name: String, abbr: String, does: String, value: String, tip: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.tooltip_text = tip
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, 36)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	row.add_child(PixelKit.icon(icon_name, 32))
	var ab := PixelKit.label(abbr)
	ab.custom_minimum_size = Vector2(64, 0)
	row.add_child(ab)
	var d := PixelKit.label(does, "body", PixelKit.DIM)
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(d)
	row.add_child(PixelKit.label(value, "body", PixelKit.GOLD3))
	box.add_child(PixelKit.rule())
	return box

func _member_stats(member) -> void:
	var u: Dictionary = main.member_preview(member)
	var defense_cut: float = DefenseScript.reduction(float(u.defense_pct), float(u.get("defense_cap", DefenseScript.BASE_CAP)))
	var fort_cut: float = DefenseScript.reduction(float(u.fortitude), float(u.get("defense_cap", DefenseScript.BASE_CAP)))
	var rows: Array = [
		["hp", "%d" % int(u.max_hp), ""],
		["attack", "%.1f" % float(u.attack), ""],
		["defense", "%.0f" % float(u.defense_pct), "bodily harm −%d%%" % int(round(defense_cut * 100.0))],
		["fortitude", "%.0f" % float(u.fortitude), "magical harm %s%d%%" % ["−" if fort_cut >= 0.0 else "+", absi(int(round(fort_cut * 100.0)))]],
		["speed", "%.1f" % float(u.get("speed", 5.0)), "acts %s often" % _speed_word(float(u.get("speed", 5.0)))],
	]
	if float(u.get("magic", 0.0)) > 0.0 or member.is_caster():
		rows.append(["magic", "%.1f" % float(u.magic), ""])
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	content_root.add_child(col)
	for r in rows:
		col.add_child(_member_stat_row(member, str(r[0]), str(r[1]), str(r[2])))
	var extras: Array = [["Move", "%d tile%s" % [int(u.move_range), "" if int(u.move_range) == 1 else "s"], "how far it walks in a turn"], ["Reach", "%d" % int(u.attack_range), "tiles away it can attack"]]
	if bool(u.get("hp_as_mana", false)):
		extras.append(["Pool", "spells cost HP", ""])
	elif int(u.max_mana) > 0:
		extras.append(["Pool", "%d mana" % int(u.max_mana), ""])
	elif int(u.max_stamina) > 0:
		extras.append(["Pool", "%d stamina" % int(u.max_stamina), ""])
	if float(u.get("dodge_chance", 0.0)) > 0.0:
		extras.append(["Dodge", "%d%%" % int(round(float(u.dodge_chance) * 100.0)), ""])
	if float(u.get("shield_block", 0.0)) > 0.0:
		extras.append(["Block", "%d%%" % int(round(float(u.shield_block) * 100.0)), "with its shield"])
	# the smaller facts sit two to a line (their explanation in a tooltip) so the member's description still fits under them
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 0)
	content_root.add_child(grid)
	for x in extras:
		var line := _stat_line("", str(x[0]), "", str(x[1]), str(x[2]).substr(0, 1).to_upper() + str(x[2]).substr(1))
		line.custom_minimum_size = Vector2((size.x - 304.0 - 16.0 - 16.0 - 24.0 - 20.0) / 2.0, 36)
		grid.add_child(line)
	var desc := str(member.rules().get("description", ""))
	if desc != "":
		content_root.add_child(InvWidgets.paragraph(desc))

func _member_stat_row(member, stat: String, value: String, detail: String) -> Control:
	var growth: float = PartyRulesScript.growth(member.kind, stat)
	var line := _stat_line(MEMBER_STAT_ICONS[stat], MEMBER_STAT_LABELS[stat], detail, value, "Levels up at x%s the usual rate." % _trim(growth))
	if member.picks > 0 and stat in member.pickable_stats():
		var row: HBoxContainer = line.get_child(0)
		var plus := PixelButton.make("+", "", func(): panel._on_member_pick_spent(member, stat))
		plus.tooltip_text = "Spend a bonus pick on %s." % MEMBER_STAT_LABELS[stat]
		row.add_child(plus)
	return line

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

static func _trim(x: float) -> String:
	var s := "%.2f" % x
	while s.ends_with("0") and s.contains("."):
		s = s.substr(0, s.length() - 1)
	return s.trim_suffix(".")

# --- Defense (yours) and Run (yours) -----------------------------------------------------------------------------------------------------

func _page_defense() -> void:
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	content_root.add_child(cols)
	var bodily := VBoxContainer.new()
	bodily.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bodily.add_theme_constant_override("separation", 0)
	cols.add_child(bodily)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(PixelKit.icon("stat_defense", 32))
	head.add_child(PixelKit.label("Bodily harm  −%d%%" % int(round(player.bodily_reduction() * 100.0)), "head", PixelKit.GOLD3))
	bodily.add_child(head)
	var armor_name := str(player.equipped_armor.get("name", "none"))
	InvWidgets.icon_row(bodily, "sub_armour", "Armour (%s)" % armor_name, "+%d" % int(round(player.armor_tier_damage_reduction() * 100.0)))
	InvWidgets.icon_row(bodily, "sub_clothes", "Clothes", "+%d" % int(round(player.clothing_damage_reduction() * 100.0)))
	InvWidgets.icon_row(bodily, "sub_shields", "Shield", "+%d" % int(round(player.shield_damage_reduction_pct() * 100.0)))
	InvWidgets.icon_row(bodily, "stat_resilience", "RES", "+%d" % int(round(player.resilience_reduction * 100.0)))
	bodily.add_child(InvWidgets.paragraph("%d points of Defense, with diminishing returns, never past 80%%." % int(round(player.bodily_defense_points()))))
	var magical := VBoxContainer.new()
	magical.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	magical.add_theme_constant_override("separation", 0)
	cols.add_child(magical)
	var head2 := HBoxContainer.new()
	head2.add_theme_constant_override("separation", 8)
	head2.add_child(PixelKit.icon("stat_fortitude", 32))
	head2.add_child(PixelKit.label("Magical harm  −%d%%" % int(round(player.fortitude_reduction() * 100.0)), "head", PixelKit.BLUE))
	magical.add_child(head2)
	InvWidgets.icon_row(magical, "sub_armour", "Armour", "%+d" % int(player.equipped_armor.get("fortitude", 0)))
	InvWidgets.icon_row(magical, "sub_shields", "Shield", "%+d" % int(round(player.shield_fortitude())))
	InvWidgets.icon_row(magical, "stat_fortitude", "FTD", "%+d" % int(player.stat_fortitude))
	magical.add_child(InvWidgets.paragraph("%d points of Fortitude." % int(round(player.fortitude_total()))))

func _page_run() -> void:
	var kills := 0
	for n in main.run_kills_by_name:
		kills += int(main.run_kills_by_name[n])
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.custom_minimum_size = Vector2(520, 0)
	content_root.add_child(col)
	col.add_child(InvWidgets.caption("This run"))
	InvWidgets.icon_row(col, "stat_intimidation", "Foes defeated", str(kills))
	InvWidgets.icon_row(col, "stat_level", "Bosses beaten", str(int(main.run_bosses_defeated)))
	InvWidgets.icon_row(col, "stat_damage", "Waves cleared", str(maxi(0, int(main.wave) - 1)))
	InvWidgets.icon_row(col, "stat_coin", "Coins", str(int(player.coins)))
	InvWidgets.icon_row(col, "stat_shard", "Runic shards", str(int(player.runic_shards)))
