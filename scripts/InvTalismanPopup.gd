extends Control
class_name InvTalismanPopup

# The talisman screen, a popup from a unit's Talismans line: that unit's charm slots across the top (worn / empty / locked until a
# level), every talisman in the game in its fixed order below (the ones you have not found as pure black silhouettes, "???"), and the
# picked one at the right with its lore, a short overview of what it does, who wears it and the button to wear / take it off. A
# talisman can only be on one unit at a time: pressing Wear on one somebody else has says "Take from <them>".

const TalismansScript := preload("res://scripts/Talismans.gd")

const COLUMNS := 10
const CELL := 64
const GAP := 8

var panel = null
var player = null
var member = null            # null = the hero
var state: Dictionary = {}   # {sel: talisman id}, kept by the panel
var cells: Dictionary = {}   # id -> its Panel
var entries: Array = []

func setup(p_panel, p_player, p_member, p_state: Dictionary) -> void:
	panel = p_panel
	player = p_player
	member = p_member
	state = p_state
	rebuild()

func unit_name() -> String:
	return InvData.unit_name(member)

func rebuild() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	cells.clear()
	entries = InvData.talisman_entries(player)
	var slots := InvData.talisman_slots(player, member)
	var grid_w := COLUMNS * CELL + (COLUMNS - 1) * GAP
	var y := 0.0
	var cap1 := InvWidgets.caption("Charm slots")
	cap1.position = Vector2(0, y)
	add_child(cap1)
	y += 26.0
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", GAP)
	pips.position = Vector2(0, y)
	add_child(pips)
	for i in _max_slots():
		if i < slots.worn.size():
			var worn_entry := _entry_for(str(slots.worn[i]))
			pips.add_child(_slot_tile("worn", worn_entry, i))
		elif i < int(slots.open):
			pips.add_child(_slot_tile("open", {}, i))
		else:
			pips.add_child(_slot_tile("locked", {}, i))
	y += CELL + 12.0
	var found := 0
	for e in entries:
		if e.owned:
			found += 1
	var cap2 := InvWidgets.caption("All talismans  (%d of %d found)" % [found, entries.size()])
	cap2.position = Vector2(0, y)
	add_child(cap2)
	y += 26.0
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	grid.position = Vector2(0, y)
	add_child(grid)
	var picked := _picked()
	for e in entries:
		var cell := _cell(e, str(e.id) == str(picked.get("id", "")), slots.worn.has(e.id))
		grid.add_child(cell)
		cells[e.id] = cell
	_build_detail(picked, grid_w + 16.0)

func _max_slots() -> int:
	return TalismansScript.SLOT_LEVELS.size() + 1

func _entry_for(id: String) -> Dictionary:
	for e in entries:
		if str(e.id) == id:
			return e
	return {}

func _picked() -> Dictionary:
	var want := str(state.get("sel", ""))
	var e := _entry_for(want)
	if e.is_empty() or not e.owned:
		# default: the first one this unit wears, else the first one you own, else the first
		var slots := InvData.talisman_slots(player, member)
		if not slots.worn.is_empty():
			e = _entry_for(str(slots.worn[0]))
		if e.is_empty():
			for c in entries:
				if c.owned:
					e = c
					break
		if e.is_empty() and not entries.is_empty():
			e = entries[0]
	return e

func _slot_tile(kind: String, entry: Dictionary, index: int) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(CELL, CELL)
	p.size = Vector2(CELL, CELL)
	match kind:
		"worn":
			p.add_theme_stylebox_override("panel", PixelKit.frame("card_worn"))
			var inner := Control.new()
			inner.position = Vector2(12, 12)
			inner.size = Vector2(CELL - 24, CELL - 24)
			inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
			p.add_child(inner)
			var tint := ColorRect.new()
			tint.color = Color(PixelKit.RARITY_COLORS.get(str(entry.rarity), PixelKit.CREAM), 0.2)
			tint.set_anchors_preset(Control.PRESET_FULL_RECT)
			tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner.add_child(tint)
			var art := PixelKit.art(entry.art, 32)
			art.position = Vector2(4, 4)
			inner.add_child(art)
			p.tooltip_text = str(entry.name)
			p.mouse_filter = Control.MOUSE_FILTER_STOP
			p.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: _pick(str(entry.id)))
		"open":
			p.add_theme_stylebox_override("panel", PixelKit.frame("inset"))
			p.tooltip_text = "An empty slot."
		_:
			p.add_theme_stylebox_override("panel", PixelKit.frame("inset"))
			var need: int = TalismansScript.level_for_slot(index + 1)
			var l := PixelKit.label("Lv %d" % need, "body", PixelKit.DIM)
			l.position = Vector2(8, 18)
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			p.add_child(l)
			p.tooltip_text = "Opens at level %d." % need
	return p

func _cell(e: Dictionary, picked: bool, worn_here: bool) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(CELL, CELL)
	p.size = Vector2(CELL, CELL)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var frame_name := "card"
	if worn_here and picked:
		frame_name = "card_worn_pick"
	elif picked:
		frame_name = "card_pick"
	elif worn_here:
		frame_name = "card_worn"
	p.add_theme_stylebox_override("panel", PixelKit.frame(frame_name))
	var inner := Control.new()
	inner.position = Vector2(12, 12)
	inner.size = Vector2(CELL - 24, CELL - 24)
	inner.clip_contents = true
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(inner)
	var bg := ColorRect.new()
	bg.color = Color(PixelKit.RARITY_COLORS.get(str(e.rarity), PixelKit.CREAM), 0.2) if e.owned else Color("07060b")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(bg)
	var art := PixelKit.art(e.art, 32)
	art.position = Vector2(4, 4)
	# not found yet: a pure black silhouette, nothing revealed; worn by someone else: dimmed
	if not e.owned:
		art.modulate = Color(0, 0, 0, 1)
	elif str(e.holder) != "" and str(e.holder) != unit_name():
		art.modulate = Color(1, 1, 1, 0.45)
	inner.add_child(art)
	if e.owned and str(e.holder) != "" and str(e.holder) != unit_name():
		var chip := PixelKit.chip(str(e.holder).substr(0, 1))
		chip.position = Vector2(CELL - 36, CELL - 36)
		chip.tooltip_text = "Worn by %s" % e.holder
		p.add_child(chip)
	p.tooltip_text = str(e.name) if e.owned else "???"
	p.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.double_click and e.owned:
				panel.apply_talisman_action(member, e)
			else:
				_pick(str(e.id))
	)
	return p

func _pick(id: String) -> void:
	state["sel"] = id
	rebuild()

func _build_detail(e: Dictionary, x: float) -> void:
	var w := size.x - x
	var card := PixelKit.panel("panel_steel", 8, 4)
	card.position = Vector2(x, 0)
	card.size = Vector2(w, size.y)
	card.custom_minimum_size = Vector2(w, size.y)
	add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	card.add_child(col)
	if e.is_empty():
		return
	var tile_row := HBoxContainer.new()
	tile_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(tile_row)
	tile_row.add_child(InvCard.tile({"art": e.art, "quality": "", "tint": Color(PixelKit.RARITY_COLORS.get(str(e.rarity), PixelKit.CREAM), 0.2) if e.owned else Color("07060b"), "dim_art": false}, 96, "card_pick", 20.0))
	if not e.owned:
		_blacken(tile_row.get_child(0))
		var q := PixelKit.label("???", "head", PixelKit.DIM)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(q)
		col.add_child(InvWidgets.paragraph("You have not found this one yet.", PixelKit.DIM, true))
		return
	var name_label := PixelKit.label(str(e.name), "head", PixelKit.GOLD3)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(name_label)
	var rarity := PixelKit.label("%s · %s" % [str(e.rarity).capitalize(), e.group], "body", PixelKit.RARITY_COLORS.get(str(e.rarity), PixelKit.CREAM))
	rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(rarity)
	if str(e.lore) != "":
		col.add_child(InvWidgets.paragraph(str(e.lore), PixelKit.DIM, true))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	col.add_child(gap)
	col.add_child(InvWidgets.caption("What it does"))
	var box := InvWidgets.desc_box(str(e.overview))
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(box)
	var status := str(e.holder)
	var status_text := "Not worn"
	if status == unit_name():
		status_text = "Worn by you" if member == null else "Worn by %s" % status
	elif status != "":
		status_text = "Worn by %s" % status
	var status_label := PixelKit.label(status_text, "body", PixelKit.DIM)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(status_label)
	var act := InvData.talisman_action(player, member, e)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	var b := PixelButton.make(str(act.label), "", func(): panel.apply_talisman_action(member, e), bool(act.enabled) and str(act.label) != "Take off")
	b.disabled = not bool(act.enabled)
	if str(act.reason) != "":
		b.tooltip_text = str(act.reason)
	b.set_meta("is_action", true)
	row.add_child(b)

# Turns every picture inside a tile black (a talisman you have not found).
func _blacken(node: Node) -> void:
	for c in node.get_children():
		if c is TextureRect:
			c.modulate = Color(0, 0, 0, 1)
		_blacken(c)
