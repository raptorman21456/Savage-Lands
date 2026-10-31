extends "res://scripts/DebugViewBase.gd"

# ITEMS: give or take away any weapon (base x quality x material), armour, shield, clothing piece, talisman, potion, food, arrows and
# crafting material, and set the Blacksmith's levels. The gear categories are a searchable grid of the same cards the Inventory uses
# (the white frame = you have it) with the picked thing's details and buttons beside it; the stock categories are rows with steppers.

const WeaponsScript := preload("res://scripts/Weapons.gd")
const ArmorScript := preload("res://scripts/Armor.gd")
const ShieldsScript := preload("res://scripts/Shields.gd")
const ClothingScript := preload("res://scripts/Clothing.gd")
const TalismansScript := preload("res://scripts/Talismans.gd")
const PotionsScript := preload("res://scripts/Potions.gd")
const FoodsScript := preload("res://scripts/Foods.gd")
const MaterialsScript := preload("res://scripts/Materials.gd")
const EnchantmentsScript := preload("res://scripts/Enchantments.gd")
const BlacksmithScript := preload("res://scripts/Blacksmith.gd")
const FishingHoleScript := preload("res://scripts/FishingHole.gd")
const DebugWeaponPickScript := preload("res://scripts/DebugWeaponPick.gd")

const CATEGORIES := ["Weapons", "Armour", "Shields", "Clothes", "Talismans", "Potions", "Food", "Arrows", "Materials", "Smithing"]
const GRID_CATEGORIES := ["Weapons", "Armour", "Shields", "Clothes", "Talismans"]
const LEFT_W := 568.0
const TOP := 52.0
const GRID_TOP := 100.0

var s: Dictionary = {}                   # this tab's remembered state (kept in menu.state)
var _cards: Array = []
var _shown: Array = []
var _detail: VBoxContainer = null
var _grid: GridContainer = null

func build() -> void:
	clear()
	if not menu.state.has("items"):
		menu.state["items"] = {"cat": "Weapons", "search": "", "sel": {}, "weapon": {"base": "spear", "tier": "Fine", "material": "steel"}}
	s = menu.state.items
	var cat: String = str(s.cat)
	var tabs := DebugKitScript.flow(self)
	tabs.position = Vector2.ZERO
	tabs.size = Vector2(size.x, 44)
	for c in CATEGORIES:
		tabs.add_child(DebugKitScript.button(c, _on_category.bind(c), c == cat))
	if cat in GRID_CATEGORIES:
		_gear_page(cat)
	elif cat == "Smithing":
		_smithing_page()
	else:
		_stock_page(cat)

func _on_category(c: String) -> void:
	s["cat"] = c
	refresh()

# ---------------------------------------------------------------------------------------------------------------------------
# Gear: a grid of cards and the details of the one picked
# ---------------------------------------------------------------------------------------------------------------------------

func _gear_page(cat: String) -> void:
	var k := DebugKitScript
	var bar := k.hbox(self, 12)
	bar.position = Vector2(0, TOP)
	bar.size = Vector2(LEFT_W, 40)
	bar.add_child(k.search_field(str(s.search), _on_search))
	var held: int = _held_count(cat)
	var total: int = _entries(cat).size()
	var owned_weapons: int = player().owned_weapons.size()
	var counter := PixelKit.label(("You have %d of %d" % [held, total]) if cat != "Weapons" else ("You own %d weapon%s" % [owned_weapons, "" if owned_weapons == 1 else "s"]), "body", PixelKit.DIM)
	counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(counter)
	var scroll: ScrollContainer = k.scroll(Vector2(LEFT_W, size.y - GRID_TOP))
	scroll.position = Vector2(0, GRID_TOP)
	add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_grid)
	var detail_panel := PixelKit.panel("panel_steel", 8, 6)
	detail_panel.position = Vector2(LEFT_W + 12, TOP)
	detail_panel.size = Vector2(size.x - LEFT_W - 12, size.y - TOP)
	detail_panel.custom_minimum_size = detail_panel.size
	add_child(detail_panel)
	var detail_scroll: ScrollContainer = k.scroll(Vector2.ZERO)
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_child(detail_scroll)
	_detail = k.vbox(detail_scroll, 6)
	_fill_grid(cat)
	_fill_detail(cat)

func _on_search(text: String) -> void:
	s["search"] = text
	var cat: String = str(s.cat)
	_fill_grid(cat)
	_fill_detail(cat)

# What each grid shows: [{id, name, art, number, quality, tint, held, tooltip, ...}] -- every item of the category, not only yours.
func _entries(cat: String) -> Array:
	var p = player()
	var out: Array = []
	match cat:
		"Weapons":
			for base in DebugActionsScript.weapon_bases():
				var variant: Dictionary = DebugActionsScript.build_weapon(str(base.id), "Fine", "steel")
				var owned := 0
				for id in p.owned_weapons:
					if str(WeaponsScript.get_base_type(WeaponsScript.get_owned_variant(str(id))).get("id", "")) == str(base.id):
						owned += 1
				out.append({"id": str(base.id), "name": str(base.name), "art": WeaponIcons.texture_for(variant), "number": str(owned) if owned > 0 else "",
					"quality": "", "key": str(base.id), "tint": Color(0, 0, 0, 0), "held": owned > 0, "tooltip": str(base.get("description", "")), "data": base})
		"Armour":
			for a in ArmorScript.TIERS:
				var id := str(a.id)
				out.append({"id": id, "name": str(a.name), "art": PixelKit.texture_at(ArmorScript.icon_path(a)), "number": str(int(round(p.armor_defense_fraction(a) * 100.0))),
					"quality": "", "key": id, "tint": Color(0, 0, 0, 0), "held": p.owned_armor.has(id), "tooltip": str(a.get("description", "")), "data": a})
		"Shields":
			for id in ShieldsScript.SHIELD_IDS:
				var sh: Dictionary = ShieldsScript.SHIELDS[id]
				out.append({"id": str(id), "name": str(sh.name), "art": PixelKit.texture_at("res://assets/%s.png" % sh.get("icon", "")), "number": "%d%%" % int(round(float(sh.get("block_chance", 0.0)) * 100.0)),
					"quality": "", "key": str(id), "tint": Color(0, 0, 0, 0), "held": p.owned_shields.has(id), "tooltip": str(sh.get("description", "")), "data": sh})
		"Clothes":
			for piece in ClothingScript.PIECES:
				var id := str(piece.id)
				out.append({"id": id, "name": str(piece.name), "art": PixelKit.texture_at("res://assets/%s.png" % piece.icon), "number": "+%d" % int(round(float(piece.damage_reduction) * 100.0)),
					"quality": "", "key": id, "tint": Color(0, 0, 0, 0), "held": p.owned_clothing.has(id), "tooltip": str(piece.get("description", "")), "data": piece})
		"Talismans":
			for e in InvData.talisman_entries(p):
				var color: Color = PixelKit.RARITY_COLORS.get(str(e.rarity), Color.WHITE)
				out.append({"id": str(e.id), "name": str(e.name), "art": e.art, "number": "", "quality": "", "key": str(e.id), "tint": Color(color, 0.2),
					"held": bool(e.owned), "tooltip": str(e.overview), "data": e})
	return out

func _held_count(cat: String) -> int:
	var n := 0
	for e in _entries(cat):
		if bool(e.held):
			n += 1
	return n

func _visible(cat: String) -> Array:
	var needle := str(s.search).to_lower()
	var out: Array = []
	for e in _entries(cat):
		if needle == "" or str(e.name).to_lower().contains(needle):
			out.append(e)
	return out

func _selected_id(cat: String) -> String:
	var want := str(s.sel.get(cat, ""))
	for e in _shown:
		if str(e.id) == want:
			return want
	return str(_shown[0].id) if not _shown.is_empty() else ""

func _fill_grid(cat: String) -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	_cards.clear()
	_shown = _visible(cat)
	var chosen := _selected_id(cat)
	for e in _shown:
		var info := {"name": e.name, "art": e.art, "quality": e.quality, "key": e.key, "number": e.number, "holder": "", "tint": e.tint, "tooltip": e.tooltip}
		var card: Panel = DebugKitScript.card(info, bool(e.held), str(e.id) == chosen, _on_pick.bind(e), _on_use.bind(e))
		_grid.add_child(card)
		_cards.append(card)
	if _shown.is_empty():
		_grid.add_child(PixelKit.label("Nothing matches.", "body", PixelKit.DIM))

func _on_pick(entry: Dictionary) -> void:
	var cat: String = str(s.cat)
	if str(s.sel.get(cat, "")) == str(entry.id):
		return
	s.sel[cat] = str(entry.id)
	if cat == "Weapons":
		s.weapon["base"] = str(entry.id)
	for i in _cards.size():
		_cards[i].picked = str(_shown[i].id) == str(entry.id)
	_fill_detail(cat)

# Enter / double-click on a card: the usual "give it and put it on".
func _on_use(entry: Dictionary) -> void:
	var cat: String = str(s.cat)
	var id := str(entry.id)
	match cat:
		"Armour": act(DebugActionsScript.give_armor(main, id, true))
		"Shields": act(DebugActionsScript.give_shield(main, id, true))
		"Clothes": act(DebugActionsScript.give_clothing(main, id, true))
		"Talismans": act(DebugActionsScript.give_talisman(main, id, true))
		"Weapons":
			var variant: Dictionary = DebugWeaponPickScript.variant_of(s.weapon)
			if not variant.is_empty():
				act(DebugActionsScript.give_weapon(main, str(s.weapon.base), str(s.weapon.tier), str(s.weapon.material), true))

func _fill_detail(cat: String) -> void:
	for c in _detail.get_children():
		_detail.remove_child(c)
		c.queue_free()
	var chosen := _selected_id(cat)
	var entry: Dictionary = {}
	for e in _shown:
		if str(e.id) == chosen:
			entry = e
	if entry.is_empty():
		_detail.add_child(PixelKit.label("Nothing selected.", "body", PixelKit.DIM))
		return
	var p = player()
	var k := DebugKitScript
	var title := PixelKit.label(str(entry.name), "head", PixelKit.GOLD3)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_child(title)
	match cat:
		"Weapons":
			_weapon_detail(entry)
		"Armour":
			var a: Dictionary = entry.data
			var id := str(entry.id)
			var worn: bool = str(p.equipped_armor.get("id", "")) == id
			_state_line(bool(entry.held), worn, "worn")
			InvWidgets.icon_row(_detail, "stat_defense", "Defense", "+%s" % str(entry.number))
			InvWidgets.icon_row(_detail, "stat_fortitude", "Fortitude", str(int(a.get("fortitude", 0))))
			if str(a.get("trait", "")) != "":
				InvWidgets.icon_row(_detail, "stat_crit", "Trait", str(a.trait).capitalize())
			if ArmorScript.is_crafted(a):
				k.note(_detail, "Crafted at the Blacksmith: %s." % MaterialsScript.recipe_text(a.recipe))
			_detail.add_child(InvWidgets.desc_box(str(a.get("description", ""))))
			_gear_buttons(entry, "armor", "Give and wear", func(): return DebugActionsScript.give_armor(main, id, false), func(): return DebugActionsScript.give_armor(main, id, true), func(): return DebugActionsScript.remove_armor(main, id))
		"Shields":
			var sh: Dictionary = entry.data
			var id := str(entry.id)
			var held_now: bool = str(p.equipped_shield.get("id", "")) == id
			_state_line(bool(entry.held), held_now, "raised")
			InvWidgets.icon_row(_detail, "stat_defense", "Block chance", str(entry.number))
			InvWidgets.icon_row(_detail, "stat_fortitude", "Fortitude", str(int(sh.get("fortitude", 0))))
			_detail.add_child(InvWidgets.desc_box(str(sh.get("description", ""))))
			_gear_buttons(entry, "shield", "Give and raise", func(): return DebugActionsScript.give_shield(main, id, false), func(): return DebugActionsScript.give_shield(main, id, true), func(): return DebugActionsScript.remove_shield(main, id))
		"Clothes":
			var piece: Dictionary = entry.data
			var id := str(entry.id)
			var worn_c: bool = str(p.equipped_clothing.get(piece.slot, "")) == id
			_state_line(bool(entry.held), worn_c, "worn")
			InvWidgets.icon_row(_detail, "", "Slot", str(ClothingScript.SLOT_LABELS[piece.slot]))
			InvWidgets.icon_row(_detail, "stat_defense", "Defense", str(entry.number))
			_detail.add_child(InvWidgets.desc_box(str(piece.get("description", ""))))
			_gear_buttons(entry, "clothing", "Give and wear", func(): return DebugActionsScript.give_clothing(main, id, false), func(): return DebugActionsScript.give_clothing(main, id, true), func(): return DebugActionsScript.remove_clothing(main, id))
		"Talismans":
			var t: Dictionary = entry.data
			var id := str(entry.id)
			var worn_t: bool = p.equipped_talismans.has(id)
			_state_line(bool(entry.held), worn_t, "worn by you" if worn_t else "worn")
			if str(t.holder) != "" and str(t.holder) != "You":
				k.note(_detail, "%s is wearing it." % str(t.holder), PixelKit.GOLD3)
			var rare := PixelKit.label(str(t.rarity).capitalize(), "body", PixelKit.RARITY_COLORS.get(str(t.rarity), PixelKit.CREAM))
			_detail.add_child(rare)
			if str(t.lore) != "":
				k.note(_detail, str(t.lore))
			_detail.add_child(InvWidgets.desc_box(str(t.overview)))
			_gear_buttons(entry, "talisman", "Give and wear", func(): return DebugActionsScript.give_talisman(main, id, false), func(): return DebugActionsScript.give_talisman(main, id, true), func(): return DebugActionsScript.remove_talisman(main, id))
	# bulk actions at the foot of every gear page
	k.spacer(_detail, 6)
	var bulk := k.flow(_detail)
	var kind_of := {"Weapons": "weapon", "Armour": "armor", "Shields": "shield", "Clothes": "clothing", "Talismans": "talisman"}
	if cat != "Weapons":
		bulk.add_child(k.button("Give all", func(): act(DebugActionsScript.give_all(main, str(kind_of[cat]))), false, "", "Gives you every piece in this list."))
	bulk.add_child(k.button("Remove all", func(): menu.confirm("Take away every %s you own?" % cat.to_lower(), func(): act(DebugActionsScript.remove_all(main, str(kind_of[cat]))))))

func _state_line(held: bool, worn: bool, worn_word: String) -> void:
	var text := "You do not have it."
	var color: Color = PixelKit.DIM
	if held:
		text = "You have it, %s now." % worn_word if worn else "You have it."
		color = PixelKit.GOOD
	var l := PixelKit.label(text, "body", color)
	_detail.add_child(l)

# [Give] [Give and wear] [Remove]
func _gear_buttons(entry: Dictionary, _kind: String, wear_label: String, give: Callable, give_wear: Callable, remove: Callable) -> void:
	var k := DebugKitScript
	k.spacer(_detail, 4)
	var row := k.flow(_detail)
	row.add_child(k.button("Give", func(): act(give.call())))
	row.add_child(k.button(wear_label, func(): act(give_wear.call()), true))
	var rm: PixelButton = k.button("Remove", func(): act(remove.call()))
	k.set_enabled(rm, bool(entry.held))
	row.add_child(rm)

# The weapon page: quality and material pickers for the base picked in the grid, the result, and what you already own of it.
func _weapon_detail(entry: Dictionary) -> void:
	var p = player()
	var k := DebugKitScript
	var base: Dictionary = entry.data
	var base_id := str(base.id)
	s.weapon["base"] = base_id
	var variant: Dictionary = DebugWeaponPickScript.build(_detail, s.weapon, refresh, false)
	if variant.is_empty():
		return
	var info: Dictionary = InvData.weapon_entry(p, variant)
	var preview := k.hbox(_detail, 12)
	preview.add_child(InvCard.tile({"art": info.art, "quality": info.quality if info.quality != "Starter" else "", "key": info.key, "tint": info.tint}, 112, "card_pick", 22.0))
	var facts := k.vbox(preview, 2)
	var name_label := PixelKit.label(str(info.name), "myth" if bool(info.mythic) else "body", PixelKit.QUALITY_TEXT.Mythic if bool(info.mythic) else PixelKit.CREAM)
	facts.add_child(name_label)
	facts.add_child(PixelKit.label(str(info.sub), "body", PixelKit.QUALITY_TEXT.get(str(info.quality), PixelKit.DIM)))
	facts.add_child(PixelKit.label("Damage %s for you" % str(info.number), "body", PixelKit.GOLD3))
	for l in info.lack:
		facts.add_child(PixelKit.label("Needs %d %s (you have %d)" % [l.need, l.stat, l.have], "body", PixelKit.BAD))
	if str(info.desc) != "" and not bool(info.mythic):
		k.note(_detail, str(info.desc))
	elif bool(info.mythic):
		k.note(_detail, str(info.desc), PixelKit.QUALITY_TEXT.Mythic)
	var id := str(variant.id)
	var owned_now: bool = p.owned_weapons.has(id)
	var ally_only: bool = WeaponsScript.is_ally_only(variant)
	var row := k.flow(_detail)
	var tier: String = str(s.weapon.tier)
	var material: String = str(s.weapon.material)
	var give: PixelButton = k.button("Give", func(): act(DebugActionsScript.give_weapon(main, base_id, tier, material, false)))
	k.set_enabled(give, base_id != "club")
	row.add_child(give)
	var give_equip: PixelButton = k.button("Give and equip" if not ally_only else "Give (party only)", func(): act(DebugActionsScript.give_weapon(main, base_id, tier, material, true)), true)
	row.add_child(give_equip)
	var remove: PixelButton = k.button("Remove", func(): act(DebugActionsScript.remove_weapon(main, id)))
	k.set_enabled(remove, owned_now and base_id != "club")
	row.add_child(remove)
	_state_line(owned_now, str(p.current_weapon_base.get("id", "")) == id, "equipped")
	# what you own of this kind
	var mine: Array = []
	for v in DebugActionsScript.owned_weapon_variants(main):
		if str(WeaponsScript.get_base_type(v).get("id", "")) == base_id:
			mine.append(v)
	if not mine.is_empty():
		k.section(_detail, "You own (%d)" % mine.size())
		for v in mine:
			var vid := str(v.id)
			var line := k.hbox(_detail, 6)
			var equipped: bool = str(p.current_weapon_base.get("id", "")) == vid
			var label := PixelKit.label(DebugActionsScript._weapon_label(v) + ("   [equipped]" if equipped else ""), "body", PixelKit.GOLD3 if equipped else PixelKit.CREAM)
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			line.add_child(label)
			if not WeaponsScript.is_ally_only(v):
				line.add_child(k.button("Equip", func(): act(DebugActionsScript.equip_weapon(main, vid))))
			var rm: PixelButton = k.button("Remove", func(): act(DebugActionsScript.remove_weapon(main, vid)))
			k.set_enabled(rm, vid != "club")
			line.add_child(rm)

# ---------------------------------------------------------------------------------------------------------------------------
# Stock: potions, food, arrows, materials -- a row each with a stepper
# ---------------------------------------------------------------------------------------------------------------------------

func _stock_page(cat: String) -> void:
	var k := DebugKitScript
	var frame_and_box: Array = k.framed_scroll(Vector2(size.x, size.y - TOP))
	frame_and_box[0].position = Vector2(0, TOP)
	add_child(frame_and_box[0])
	var box: VBoxContainer = frame_and_box[1]
	var p = player()
	match cat:
		"Potions":
			for t in PotionsScript.TIERS:
				var id := str(t.id)
				_stock_row(box, PixelKit.texture_at("res://assets/%s.png" % t.get("icon", "potion")), str(t.name), str(t.get("description", "")), DebugActionsScript.potion_count(main, id),
					func(n): return DebugActionsScript.give_potion(main, id, n) if n > 0 else DebugActionsScript.remove_potion(main, id, -n))
		"Food":
			for f in FoodsScript.ITEMS:
				var id := str(f.id)
				_stock_row(box, PixelKit.texture_at("res://assets/%s.png" % f.get("icon", "food_meat")), str(f.name), str(f.get("description", "")), DebugActionsScript.potion_count(main, id),
					func(n): return DebugActionsScript.give_potion(main, id, n) if n > 0 else DebugActionsScript.remove_potion(main, id, -n))
		"Arrows":
			for kind in ["flame", "freeze", "bomb"]:
				var info: Dictionary = WeaponsScript.ARROW_TYPES[kind]
				var arrow_kind: String = kind
				_stock_row(box, PixelKit.texture_at("res://assets/arrow_%s.png" % kind), str(info.name), str(info.get("description", "")), int(p.owned_arrows.get(kind, 0)),
					func(n): return DebugActionsScript.give_arrows(main, arrow_kind, n))
		"Materials":
			for id in MaterialsScript.ITEMS:
				var material_id: String = str(id)
				var info: Dictionary = MaterialsScript.ITEMS[id]
				_stock_row(box, null, str(info.name), str(info.get("description", "")), p.material_count(material_id),
					func(n): return DebugActionsScript.give_material(main, material_id, n))
			_stock_row(box, null, "Wolf pelts", "Harvested from a wolf that falls for good; some armours are made from them.", p.pelts,
				func(n): return DebugActionsScript.set_pelts(main, p.pelts + n))

# One row: picture, name, how many you hold, and +/- buttons; `change(n)` gives n (or takes -n) and returns a result.
func _stock_row(box: VBoxContainer, art: Texture2D, item_name: String, desc: String, count: int, change: Callable) -> void:
	var k := DebugKitScript
	var row := k.hbox(box, 8)
	row.custom_minimum_size = Vector2(0, 52)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(52, 48)
	row.add_child(holder)
	if art != null:
		var pic: TextureRect = PixelKit.art(art, 48)
		pic.position = Vector2(2, 0)
		holder.add_child(pic)
	var name_label := PixelKit.label(item_name, "body", PixelKit.CREAM)
	name_label.custom_minimum_size = Vector2(190, 0)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)
	var count_label := PixelKit.label("x%d" % count, "body", PixelKit.GOLD3)
	count_label.custom_minimum_size = Vector2(70, 0)
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(count_label)
	for step in [-10, -1, 1, 10]:
		var n: int = step
		var b: PixelButton = k.button(("−%d" % absi(n)) if n < 0 else ("+%d" % n), func(): act(change.call(n)))
		k.set_enabled(b, n > 0 or count > 0)
		row.add_child(b)
	var desc_label := k.note(row, desc)
	desc_label.custom_minimum_size = Vector2(300, 0)
	desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(PixelKit.rule())

# ---------------------------------------------------------------------------------------------------------------------------
# Smithing, runes, fishing
# ---------------------------------------------------------------------------------------------------------------------------

func _smithing_page() -> void:
	var k := DebugKitScript
	var box: VBoxContainer = k.vbox(null, 4)
	var scroll: ScrollContainer = k.scroll(Vector2(size.x, size.y - TOP))
	scroll.position = Vector2(0, TOP)
	add_child(scroll)
	scroll.add_child(box)
	var p = player()
	k.section(box, "Blacksmith levels")
	var weapon_id := str(p.current_weapon_base.get("id", ""))
	num(box, "Weapon in hand (%s)" % DebugActionsScript._weapon_label(p.current_weapon_base), int(p.weapon_upgrade_levels.get(weapon_id, 0)),
		func(v): return DebugActionsScript.set_weapon_smith_level(main, v), {"min": 0, "max": BlacksmithScript.WEAPON_MAX_LEVEL, "steps": [1], "label_w": 380})
	var armor_id := str(p.equipped_armor.get("id", ""))
	if ArmorScript.is_metal(armor_id):
		num(box, "Armour worn (%s)" % str(p.equipped_armor.get("name", "")), int(p.armor_upgrade_levels.get(armor_id, 0)),
			func(v): return DebugActionsScript.set_armor_smith_level(main, v), {"min": 0, "max": BlacksmithScript.ARMOR_MAX_LEVEL, "steps": [1], "label_w": 380})
	else:
		readout(box, "Armour worn (%s)" % str(p.equipped_armor.get("name", "")), "not metal: the Blacksmith cannot upgrade it", PixelKit.DIM).get_child(0).custom_minimum_size.x = 380
	k.section(box, "Rune on the weapon in hand")
	var runes: Array = [["", "None"]]
	for r in EnchantmentsScript.RUNES:
		runes.append([str(r.id), str(r.name)])
	k.choice_row(box, runes, str(p.weapon_enchantments.get(weapon_id, "")), func(id): act(DebugActionsScript.set_rune(main, str(id))))
	k.section(box, "Fishing")
	num(box, "Bait", p.bait, func(v): return DebugActionsScript.set_bait(main, v), {"min": 0, "max": 9999, "steps": [1, 10]})
	for rod in FishingHoleScript.RODS:
		var rod_id: String = str(rod.id)
		switch_row(box, str(rod.name), p.owned_rods.has(rod_id), func(v): return DebugActionsScript.set_rod(main, rod_id, v), str(rod.get("description", "")))
	k.spacer(box, 12)
