extends Control
class_name InvGearView

# The grid-and-detail view the Gear and Items tabs and the gear-picker popups share: sub-tabs (unless the popup fixes one category),
# a toolbar (sort, filters, search), a scrolling grid of cards, and at the right the picked thing's detail card -- its picture on the
# top edge (with the quality's turning rays), name, lore, what it does to the unit being dressed, its specials, and the button that
# hangs off the bottom edge. Everything it shows comes from InvData; pressing the button goes back through the panel.

const SORTS := ["Best quality", "Number", "Name", "Newest"]
const EMBLEM := 112
const EMBLEM_TOP := 56.0     # where the detail card starts, so the picture sits half on its top edge
const HANG := 20.0           # how far the button hangs below the bottom edge

var panel = null             # the InventoryPanel
var player = null
var mode := "gear"           # "gear" or "items"
var member = null            # the unit being dressed (null = the hero)
var fixed := ""              # one category only (the picker popup)
var cols := 4
var left_w := 568.0
var detail_w := 504.0
var state: Dictionary = {}   # kept by the panel between rebuilds: {cat, sel: {cat: id}, sort, search, can_wield, rune, scroll}

var cards: Array = []        # the InvCards on show, in order
var shown: Array = []        # their entries
var category := ""
var _scroll: ScrollContainer = null
var _grid: GridContainer = null
var _detail_nodes: Array = []
var _search: LineEdit = null
var _subtabs: Dictionary = {}

# opts: {member, fixed, cols, left_w, detail_w, state}
func setup(p_panel, p_player, p_mode: String, opts: Dictionary = {}) -> void:
	panel = p_panel
	player = p_player
	mode = p_mode
	member = opts.get("member", null)
	fixed = str(opts.get("fixed", ""))
	cols = int(opts.get("cols", 4))
	left_w = float(opts.get("left_w", 568.0))
	detail_w = float(opts.get("detail_w", 504.0))
	state = opts.get("state", {})
	var categories: Array = InvData.GEAR_CATEGORIES if mode == "gear" else InvData.ITEM_CATEGORIES
	category = fixed if fixed != "" else str(state.get("cat", categories[0]))
	if not categories.has(category):
		category = categories[0]
	state["cat"] = category
	rebuild()

func unit_name() -> String:
	return InvData.unit_name(member)

func rebuild() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	cards.clear()
	shown.clear()
	_detail_nodes.clear()
	_subtabs.clear()
	var categories: Array = InvData.GEAR_CATEGORIES if mode == "gear" else InvData.ITEM_CATEGORIES
	var y := 0.0
	if fixed == "":
		var tabs := HBoxContainer.new()
		tabs.add_theme_constant_override("separation", 0)
		tabs.position = Vector2(0, 0)
		add_child(tabs)
		for cat in categories:
			var b := PixelButton.make(cat, InvData.CATEGORY_ICONS[cat], _on_category.bind(cat), cat == category)
			tabs.add_child(b)
			_subtabs[cat] = b
		y = 56.0
	# the toolbar: sort, the filters (weapons), then the search box that is exactly as wide as what is typed
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 0)
	toolbar.position = Vector2(0, y)
	toolbar.size = Vector2(left_w, 40)
	add_child(toolbar)
	if mode == "gear":
		toolbar.add_child(PixelButton.make("Sort: %s" % SORTS[int(state.get("sort", 0))], "", _on_sort))
		if category == "Weapons":
			toolbar.add_child(PixelButton.make("Can wield", "", _on_filter.bind("can_wield"), bool(state.get("can_wield", false))))
			toolbar.add_child(PixelButton.make("Has rune", "", _on_filter.bind("rune"), bool(state.get("rune", false))))
	elif category != "Arrows":
		toolbar.add_child(PixelKit.label("Click an item to use it.", "body", PixelKit.DIM))
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(fill)
	_search = LineEdit.new()
	_search.placeholder_text = "Search"
	_search.text = str(state.get("search", ""))
	_search.add_theme_stylebox_override("normal", PixelKit.padded("inset", 6, 0))
	_search.add_theme_stylebox_override("focus", PixelKit.padded("inset", 6, 0))
	_search.add_theme_font_override("font", PixelKit.font("body"))
	_search.add_theme_font_size_override("font_size", PixelKit.font_size("body"))
	_search.add_theme_color_override("font_color", PixelKit.CREAM)
	_search.add_theme_color_override("font_placeholder_color", PixelKit.DIM)
	_search.add_theme_color_override("caret_color", PixelKit.GOLD3)
	_search.custom_minimum_size = Vector2(0, 40)
	_search.text_changed.connect(_on_search)
	toolbar.add_child(_search)
	_fit_search()
	# the grid, in a scroll area (the pixel scroll bar only shows when there are more cards than fit)
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(0, y + 52.0)
	_scroll.size = Vector2(left_w, maxf(0.0, size.y - y - 52.0))
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	PixelKit.style_scroll(_scroll)
	add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = cols
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_scroll.add_child(_grid)
	_fill_grid()
	var saved: float = float(state.get("scroll", 0.0))
	if saved > 0.0 and is_inside_tree():
		_restore_scroll.call_deferred(saved)

func _restore_scroll(value: float) -> void:
	if _scroll != null and is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(value)

func _fit_search() -> void:
	var f: Font = PixelKit.font("body")
	var txt: String = _search.text if _search.text != "" else _search.placeholder_text
	var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, PixelKit.font_size("body")).x + 16.0 + 12.0 + 12.0
	_search.custom_minimum_size.x = clampf(w, 120.0, left_w - 20.0)
	_search.size.x = _search.custom_minimum_size.x

# --- the entries -----------------------------------------------------------------------------------------------------------------------

func all_entries() -> Array:
	return InvData.gear_entries(player, category, member) if mode == "gear" else InvData.item_entries(player, category)

func _visible_entries() -> Array:
	var out: Array = []
	var text := str(state.get("search", "")).to_lower()
	for e in all_entries():
		if text != "" and not str(e.name).to_lower().contains(text):
			continue
		if bool(state.get("can_wield", false)) and category == "Weapons" and member == null and not e.lack.is_empty():
			continue
		if bool(state.get("rune", false)) and category == "Weapons" and str(e.rune) == "":
			continue
		out.append(e)
	var sort_mode := int(state.get("sort", 0)) if mode == "gear" else 3
	match sort_mode:
		0:
			out.sort_custom(func(a, b): return a.sort_quality > b.sort_quality if a.sort_quality != b.sort_quality else str(a.name) < str(b.name))
		1:
			out.sort_custom(func(a, b): return a.sort_number > b.sort_number if a.sort_number != b.sort_number else str(a.name) < str(b.name))
		2:
			out.sort_custom(func(a, b): return str(a.name) < str(b.name))
		3:
			out.sort_custom(func(a, b): return a.sort_new > b.sort_new if mode == "gear" else a.sort_new < b.sort_new)
	return out

func selected_entry() -> Dictionary:
	var sel: Dictionary = state.get("sel", {})
	var want := str(sel.get(category, ""))
	for e in shown:
		if str(e.id) == want:
			return e
	return shown[0] if not shown.is_empty() else {}

func _fill_grid() -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	cards.clear()
	shown = _visible_entries()
	var chosen := selected_entry()
	var chosen_id := str(chosen.get("id", ""))
	for e in shown:
		var holder := ""
		for h in e.holders:
			if h != unit_name():
				holder = str(h)
				break
		var card := InvCard.new()
		card.setup({
			"name": e.name, "art": e.art, "quality": e.quality if e.quality != "Starter" else "", "key": e.key, "number": e.number, "holder": holder,
			"dim": member == null and not e.lack.is_empty(), "tint": e.tint, "mythic": e.mythic, "tooltip": e.desc,
		})
		card.worn = e.holders.has(unit_name())
		card.picked = str(e.id) == chosen_id
		card.pressed.connect(_on_card.bind(e))
		card.double_pressed.connect(_on_card_double.bind(e))
		_grid.add_child(card)
		cards.append(card)
	if shown.is_empty():
		var none := PixelKit.label("Nothing here matches." if str(state.get("search", "")) != "" or bool(state.get("can_wield", false)) or bool(state.get("rune", false)) else "None yet.", "body", PixelKit.DIM)
		_grid.add_child(none)
	_build_detail()

# --- the detail card -------------------------------------------------------------------------------------------------------------------

func _build_detail() -> void:
	for n in _detail_nodes:
		if is_instance_valid(n):
			remove_child(n)
			n.queue_free()
	_detail_nodes.clear()
	var entry := selected_entry()
	var x := left_w + 12.0
	var panel_h := size.y - EMBLEM_TOP - 30.0
	var card := PixelKit.panel("panel_steel", 8, 0)
	card.position = Vector2(x, EMBLEM_TOP)
	card.size = Vector2(detail_w, panel_h)
	card.custom_minimum_size = Vector2(detail_w, panel_h)
	add_child(card)
	_detail_nodes.append(card)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	card.add_child(outer)
	var top_gap := Control.new()
	top_gap.custom_minimum_size = Vector2(0, EMBLEM - EMBLEM_TOP - 4.0)
	outer.add_child(top_gap)
	if entry.is_empty():
		var empty := PixelKit.label("Nothing selected.", "body", PixelKit.DIM)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		outer.add_child(empty)
		return
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	PixelKit.style_scroll(scroll)
	outer.add_child(scroll)
	var act := InvData.action_for(player, member, entry)
	var has_button: bool = act.act != "none" and str(act.label) != ""
	if has_button:
		# the button hangs over the card's bottom edge: keep the scrolling text clear of it
		var under := Control.new()
		under.custom_minimum_size = Vector2(0, HANG + 6.0)
		outer.add_child(under)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	var title_kind := "myth" if bool(entry.mythic) else "head"
	var title := PixelKit.label(str(entry.name), title_kind, PixelKit.QUALITY_TEXT.Mythic if bool(entry.mythic) else PixelKit.GOLD3)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(title)
	var sub_text := str(entry.sub)
	if mode == "items":
		sub_text = "x%d" % int(entry.qty)
	if sub_text != "":
		var sub := PixelKit.label(sub_text, "body", PixelKit.QUALITY_TEXT.get(str(entry.quality), PixelKit.DIM))
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(sub)
	if str(entry.lore) != "":
		col.add_child(InvWidgets.paragraph(str(entry.lore), PixelKit.DIM, true))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	col.add_child(spacer)
	for r in InvData.rows(player, member, entry):
		InvWidgets.stat_row(col, str(r[0]), str(r[1]), str(r[2]), str(r[3]), r[4] if r.size() > 4 else [])
	# the game's own description: a sunken box, except for a weapon (its rows and specials say it) -- those get a dim line
	if str(entry.kind) == "weapon":
		if not bool(entry.mythic) and str(entry.desc) != "":
			col.add_child(InvWidgets.paragraph(str(entry.desc)))
	elif str(entry.desc) != "":
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 6)
		col.add_child(gap)
		col.add_child(InvWidgets.desc_box(str(entry.desc)))
	if mode == "items" and str(entry.kind) in ["potion", "food"]:
		col.add_child(InvWidgets.paragraph("Click it in the grid to use it.", PixelKit.DIM, true))
	if not entry.specials.is_empty():
		col.add_child(InvWidgets.caption("Specials"))
		var specials: Array = []
		for s in entry.specials:
			var item: Dictionary = {"n": s.n, "c": s.c, "d": s.d}
			if member == null and not bool(s.learned):
				item["lock"] = "Dojo"
				item["hint"] = "Not learned yet: learn it at the Dojo."
			specials.append(item)
		var box := SpecialsBox.new()
		col.add_child(box)
		box.setup(specials, 0)
	# the button that hangs off the bottom edge
	# (act was worked out above, for the room under the scroll area)
	if act.act != "none" and str(act.label) != "":
		if not bool(act.enabled) and str(act.reason) != "":
			col.add_child(InvWidgets.paragraph(str(act.reason), PixelKit.BAD, true))
		var hang := Control.new()
		hang.position = Vector2(x, EMBLEM_TOP + panel_h - HANG)
		hang.size = Vector2(detail_w, 48)
		hang.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hang.add_child(row)
		var button := PixelButton.make(str(act.label), "", _on_action.bind(entry), str(act.act) == "equip" and bool(act.enabled))
		button.disabled = not bool(act.enabled)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.set_meta("is_action", true)
		row.add_child(button)
		add_child(hang)
		_detail_nodes.append(hang)
	# and the picture on its top edge
	var tile := InvCard.tile({
		"art": entry.art, "quality": entry.quality if entry.quality != "Starter" else "", "key": entry.key, "tint": entry.tint,
	}, EMBLEM, "card_pick", 22.0)
	tile.position = Vector2(x + (detail_w - EMBLEM) / 2.0, 0)
	add_child(tile)
	_detail_nodes.append(tile)

# --- reactions -------------------------------------------------------------------------------------------------------------------------

func _on_category(cat: String) -> void:
	state["cat"] = cat
	state["scroll"] = 0.0
	category = cat
	rebuild()

func _on_sort() -> void:
	state["sort"] = (int(state.get("sort", 0)) + 1) % SORTS.size()
	rebuild()

func _on_filter(which: String) -> void:
	state[which] = not bool(state.get(which, false))
	rebuild()

func _on_search(text: String) -> void:
	state["search"] = text
	_fit_search()
	_fill_grid()

func _on_card(entry: Dictionary) -> void:
	var sel: Dictionary = state.get("sel", {})
	sel[category] = str(entry.id)
	state["sel"] = sel
	if _scroll != null:
		state["scroll"] = float(_scroll.scroll_vertical)
	if mode == "items" and str(entry.kind) in ["potion", "food"]:
		panel._on_potion_cell_pressed(str(entry.id))
		return
	var chosen_id := str(entry.id)
	for i in cards.size():
		cards[i].picked = str(shown[i].id) == chosen_id
	_build_detail()

func _on_card_double(entry: Dictionary) -> void:
	if mode == "gear":
		_on_action(entry)

func _on_action(entry: Dictionary) -> void:
	if _scroll != null:
		state["scroll"] = float(_scroll.scroll_vertical)
	panel.apply_entry_action(member, entry)
