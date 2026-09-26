extends CanvasLayer
class_name InventoryPanel

# The player's full in-run menu -- opened from the pause menu's "Inventory"
# button or the overworld's direct "I" key (see Main.gd:_process). Tabbed,
# grid-based: Weapons (weapons/armor/shields), Items (potions/arrows),
# Party (recruited followers), Map (a schematic of wherever you are), and
# Settings (a passthrough to HUD's existing settings screen, not rebuilt
# here -- see _on_tab_pressed).
#
# Weapons and Shields are real, browsable collections (owned_weapons/
# owned_shields track every one ever acquired) so their grids are fully
# interactive -- click any owned one to equip it. Armor has no such
# ownership model (buying a piece immediately replaces whatever you had --
# see Player.gd:try_buy_armor): only ever one exists at a time, so its
# section is a single info card, not a clickable grid.

const EnchantmentsScript := preload("res://scripts/Enchantments.gd")
const PotionsScript := preload("res://scripts/Potions.gd")
const WeaponsScript := preload("res://scripts/Weapons.gd")
const ShieldsScript := preload("res://scripts/Shields.gd")
const ClothingScript := preload("res://scripts/Clothing.gd")
const TalismansScript := preload("res://scripts/Talismans.gd")

const TABS := ["Weapons", "Items", "Talismans", "Party", "Map", "Settings"]
const GRID_COLUMNS := 4
const CELL_SIZE := Vector2(112, 122)
const EQUIPPED_COLOR := Color(1.0, 0.85, 0.2)
const BORDER_COLOR := Color(0.4, 0.4, 0.45)

var _was_paused := false
var _player: Player = null
var active_tab: String = "Weapons"
var tab_buttons := {}
var tab_containers := {}
var map_canvas: Control

func _ready() -> void:
	layer = 30
	visible = false
	_build()

func _build() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.75)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)

	var window_size := Vector2(880, 640)
	var window := Panel.new()
	window.size = window_size
	var window_style := StyleBoxFlat.new()
	window_style.bg_color = Color(0.08, 0.08, 0.1)
	window_style.border_color = Color(0.4, 0.4, 0.45)
	window_style.set_border_width_all(3)
	window_style.set_corner_radius_all(10)
	window.add_theme_stylebox_override("panel", window_style)
	scrim.add_child(window)
	window.position = ((get_viewport().get_visible_rect().size - window_size) / 2).round()

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 20)
	window.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	margin.add_child(outer)

	var title_row := HBoxContainer.new()
	outer.add_child(title_row)
	var title := Label.new()
	title.text = "INVENTORY"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	title_row.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(spacer)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(close)
	title_row.add_child(close_button)

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	outer.add_child(tab_row)
	for tab_name in TABS:
		var button := Button.new()
		button.text = tab_name
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(130, 34)
		button.button_pressed = tab_name == active_tab
		button.pressed.connect(_on_tab_pressed.bind(tab_name))
		_style_tab_button(button)
		tab_row.add_child(button)
		tab_buttons[tab_name] = button

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var content_stack := VBoxContainer.new()
	content_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content_stack)
	for tab_name in TABS:
		if tab_name == "Settings":
			continue
		var container := VBoxContainer.new()
		container.add_theme_constant_override("separation", 18)
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.visible = tab_name == active_tab
		content_stack.add_child(container)
		tab_containers[tab_name] = container

func _style_tab_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _make_stylebox(Color(0.13, 0.12, 0.15, 0.92), BORDER_COLOR, 2, 8))
	button.add_theme_stylebox_override("hover", _make_stylebox(Color(0.2, 0.19, 0.13, 0.96), Color(1.0, 0.9, 0.2), 2, 8))
	button.add_theme_stylebox_override("pressed", _make_stylebox(Color(0.22, 0.18, 0.05, 0.95), Color(1.0, 0.85, 0.2), 2, 8))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _make_stylebox(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style

func open(player_ref: Player) -> void:
	_player = player_ref
	_was_paused = get_tree().paused
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_refresh()
	visible = true

func close() -> void:
	visible = false
	get_tree().paused = _was_paused

# Settings is a passthrough to HUD's own already-built settings screen
# rather than a real tab of its own -- rebuilding every slider/checkbox a
# second time here would just be duplicated, divergence-prone UI for a
# screen that already works. Also opens the pause menu underneath (same as
# reaching Settings from the pause menu's own button) rather than calling
# close(), specifically so Settings' existing Back button has something
# sane to return to -- neither it nor its Back button touch get_tree().
# paused themselves (they rely on already being reached from an already-
# paused pause menu), so landing here with nothing paused-and-visible
# underneath would strand the game paused with no UI at all once Back is
# pressed.
func _on_tab_pressed(tab_name: String) -> void:
	if tab_name == "Settings":
		var main := get_parent()
		visible = false
		main.menu_open = true
		main.hud.show_menu()
		main.settings_open = true
		main.hud.show_settings()
		tab_buttons[tab_name].button_pressed = false
		tab_buttons[active_tab].button_pressed = true
		return
	_select_tab(tab_name)

func _select_tab(tab_name: String) -> void:
	active_tab = tab_name
	for name in tab_buttons:
		tab_buttons[name].button_pressed = name == tab_name
	for name in tab_containers:
		tab_containers[name].visible = name == tab_name
	if tab_name == "Map" and map_canvas != null:
		map_canvas.queue_redraw()

func _refresh() -> void:
	if _player == null:
		return
	for name in tab_containers:
		for c in tab_containers[name].get_children():
			c.queue_free()
	_build_weapons_tab(tab_containers.Weapons)
	_build_items_tab(tab_containers.Items)
	_build_talismans_tab(tab_containers.Talismans)
	_build_party_tab(tab_containers.Party)
	_build_map_tab(tab_containers.Map)
	_select_tab(active_tab)

# --- Weapons tab: Weapons (grid, click to equip) + Armor (single info card,
# see class comment for why it isn't a grid) + Shields (grid, click to
# equip). ---------------------------------------------------------------

func _build_weapons_tab(container: VBoxContainer) -> void:
	_add_section_heading(container, "WEAPONS")
	var weapon_grid := GridContainer.new()
	weapon_grid.columns = GRID_COLUMNS
	weapon_grid.add_theme_constant_override("h_separation", 10)
	weapon_grid.add_theme_constant_override("v_separation", 10)
	container.add_child(weapon_grid)
	var current_weapon_id: String = _player.current_weapon_base.get("id", "")
	for id in _player.owned_weapons:
		var variant: Dictionary = WeaponsScript.get_owned_variant(id)
		if variant.is_empty():
			continue
		var equipped: bool = id == current_weapon_id
		var subtitle: String = variant.get("tier_name", "")
		var rune_id: String = _player.weapon_enchantments.get(id, "")
		if rune_id != "":
			subtitle += " (%s)" % EnchantmentsScript.get_rune(rune_id).name
		var upgrade_level: int = _player.get_weapon_upgrade_level(id)
		if upgrade_level > 0:
			subtitle += " +%d" % upgrade_level
		var cell := _make_grid_cell(
			"res://assets/weapon_%s.png" % variant.get("icon", ""), variant.name, subtitle, equipped,
			variant.get("description", ""), func(): _on_weapon_cell_pressed(variant)
		)
		weapon_grid.add_child(cell)

	_add_section_heading(container, "ARMOR")
	var armor_row := HBoxContainer.new()
	container.add_child(armor_row)
	var armor: Dictionary = _player.equipped_armor
	var armor_level: int = _player.get_armor_upgrade_level(armor.get("id", ""))
	var armor_title: String = armor.get("name", "Rags")
	if armor_level > 0:
		armor_title += " +%d" % armor_level
	armor_row.add_child(_make_grid_cell(
		"res://assets/%s.png" % armor.get("icon", ""), armor_title,
		"-%d%% damage" % int(round(_player.armor_tier_damage_reduction() * 100)), true,
		armor.get("description", ""), Callable()
	))
	if _player.clothing_damage_reduction() > 0.0:
		_add_plain_label(container, "With your clothes: -%d%% damage taken in total." % int(round(_player.armor_damage_reduction() * 100)))

	# Clothes: light extra armour pieces from the Flea Market tailor, one
	# worn per slot -- click any owned piece to wear it (see Player.equip_clothing).
	_add_section_heading(container, "CLOTHES")
	if _player.owned_clothing.is_empty():
		_add_plain_label(container, "None owned. The Flea Market's tailor sells some.")
	else:
		var clothes_grid := GridContainer.new()
		clothes_grid.columns = GRID_COLUMNS
		clothes_grid.add_theme_constant_override("h_separation", 10)
		clothes_grid.add_theme_constant_override("v_separation", 10)
		container.add_child(clothes_grid)
		for piece in ClothingScript.PIECES:
			if not _player.owned_clothing.has(piece.id):
				continue
			var worn: bool = _player.equipped_clothing.get(piece.slot, "") == piece.id
			clothes_grid.add_child(_make_grid_cell(
				"res://assets/%s.png" % piece.icon, piece.name,
				"%s  -%d%%" % [ClothingScript.SLOT_LABELS[piece.slot], int(round(piece.damage_reduction * 100))], worn,
				piece.description, func(): _on_clothing_cell_pressed(piece.id)
			))

	_add_section_heading(container, "SHIELDS")
	if _player.owned_shields.is_empty():
		_add_plain_label(container, "None owned.")
	else:
		var shield_grid := GridContainer.new()
		shield_grid.columns = GRID_COLUMNS
		shield_grid.add_theme_constant_override("h_separation", 10)
		shield_grid.add_theme_constant_override("v_separation", 10)
		container.add_child(shield_grid)
		var current_shield_id: String = _player.equipped_shield.get("id", "")
		for id in _player.owned_shields:
			var shield: Dictionary = ShieldsScript.SHIELDS.get(id, {})
			if shield.is_empty():
				continue
			var equipped: bool = id == current_shield_id
			var cell := _make_grid_cell(
				"res://assets/%s.png" % shield.get("icon", ""), shield.name,
				"%d%% block" % int(shield.get("block_chance", 0.0) * 100), equipped,
				shield.get("description", ""), func(): _on_shield_cell_pressed(shield)
			)
			shield_grid.add_child(cell)

func _on_weapon_cell_pressed(variant: Dictionary) -> void:
	if variant.get("id", "") == _player.current_weapon_base.get("id", ""):
		return
	_player._equip_weapon(variant)
	_play_sfx("purchase")
	_refresh()

func _on_clothing_cell_pressed(piece_id: String) -> void:
	var piece: Dictionary = ClothingScript.get_piece(piece_id)
	if piece.is_empty() or _player.equipped_clothing.get(piece.slot, "") == piece_id:
		return
	if _player.equip_clothing(piece_id):
		_play_sfx("purchase")
		_refresh()

func _on_shield_cell_pressed(shield: Dictionary) -> void:
	if shield.get("id", "") == _player.equipped_shield.get("id", ""):
		return
	_player.equipped_shield = shield
	_play_sfx("purchase")
	_refresh()

# --- Items tab: Potions (grid, click to drink) + Arrows (grid, read-only --
# which type is nocked is only ever chosen live in battle). ---------------

func _build_items_tab(container: VBoxContainer) -> void:
	_add_section_heading(container, "POTIONS & FOOD")
	var counts := {}
	var order := []
	for id in _player.potion_queue:
		if not counts.has(id):
			counts[id] = 0
			order.append(id)
		counts[id] += 1
	if order.is_empty():
		_add_plain_label(container, "None held.")
	else:
		var potion_grid := GridContainer.new()
		potion_grid.columns = GRID_COLUMNS
		potion_grid.add_theme_constant_override("h_separation", 10)
		potion_grid.add_theme_constant_override("v_separation", 10)
		container.add_child(potion_grid)
		for id in order:
			# Potions and food share the queue (see Foods.gd), so one merged lookup.
			var tier: Dictionary = _player.get_consumable(id)
			var cell := _make_grid_cell(
				"res://assets/%s.png" % tier.get("icon", "potion"), "%s x%d" % [tier.get("name", id), counts[id]],
				"Eat" if tier.has("stamina_amount") else "Use", false, tier.get("description", ""), func(): _on_potion_cell_pressed(id)
			)
			potion_grid.add_child(cell)

	_add_section_heading(container, "ARROWS")
	var arrow_lines_empty := true
	var arrow_grid := GridContainer.new()
	arrow_grid.columns = GRID_COLUMNS
	arrow_grid.add_theme_constant_override("h_separation", 10)
	arrow_grid.add_theme_constant_override("v_separation", 10)
	for kind in ["flame", "freeze", "bomb"]:
		var held: int = _player.owned_arrows.get(kind, 0)
		if held <= 0:
			continue
		arrow_lines_empty = false
		var info: Dictionary = WeaponsScript.ARROW_TYPES[kind]
		# No per-type arrow art exists -- every kind shares the one quiver icon.
		arrow_grid.add_child(_make_grid_cell(
			"res://assets/quiver.png", "%s x%d" % [info.name, held], "",
			false, info.get("description", ""), Callable()
		))
	if arrow_lines_empty:
		_add_plain_label(container, "None held.")
	else:
		container.add_child(arrow_grid)

# --- Talismans tab: everything bought from the Seer, click to wear / take off.
# Only talisman_slots() can be worn at once (more open as you level up). ------

func _build_talismans_tab(container: VBoxContainer) -> void:
	var slots: int = _player.talisman_slots()
	_add_section_heading(container, "TALISMANS  (%d / %d worn)" % [_player.equipped_talismans.size(), slots])
	if slots < TalismansScript.SLOT_LEVELS.size() + 1:
		_add_plain_label(container, "Your next slot opens at level %d." % TalismansScript.level_for_slot(slots + 1))
	if _player.owned_talismans.is_empty():
		_add_plain_label(container, "None owned. The Seer in town sells them.")
		return
	var grid := GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	container.add_child(grid)
	# Worn ones first, then the rest in catalog order.
	var ids: Array = []
	for id in _player.equipped_talismans:
		ids.append(id)
	for item in TalismansScript.ITEMS:
		if _player.owned_talismans.has(item.id) and not ids.has(item.id):
			ids.append(item.id)
	for id in ids:
		var talisman: Dictionary = TalismansScript.get_talisman(id)
		if talisman.is_empty():
			continue
		var worn: bool = _player.equipped_talismans.has(id)
		grid.add_child(_make_grid_cell(
			"res://assets/%s.png" % talisman.icon, talisman.name,
			"Worn" if worn else talisman.rarity.capitalize(), worn,
			talisman.description, func(): _on_talisman_cell_pressed(id)
		))

func _on_talisman_cell_pressed(talisman_id: String) -> void:
	var ok := false
	if _player.equipped_talismans.has(talisman_id):
		ok = _player.unequip_talisman(talisman_id)
	else:
		ok = _player.equip_talisman(talisman_id)
	_play_sfx("purchase" if ok else "error")
	_refresh()

func _on_potion_cell_pressed(potion_id: String) -> void:
	var result: Dictionary = _player.use_specific_potion(potion_id)
	if result.is_empty():
		return
	_play_sfx("heal")
	_refresh()

# --- Party tab: read-only roster cards -- the same followers now visible
# trailing the player in the overworld (see Main.gd:_update_party_followers).
# ---------------------------------------------------------------------

func _build_party_tab(container: VBoxContainer) -> void:
	_add_section_heading(container, "PARTY")
	if _player.party_wolf.is_empty() and _player.party_members.is_empty():
		_add_plain_label(container, "No party members recruited yet.")
		return
	var grid := GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	container.add_child(grid)
	if not _player.party_wolf.is_empty():
		grid.add_child(_make_grid_cell(
			"res://assets/enemy_wolf.png", _player.party_wolf.get("name", "Traitor Wolf"),
			"%d%% dmg" % int(_player.party_wolf.get("dmg_mult", 1.0) * 100), false,
			"A defected enemy, fighting at your side. Follows you in the field.", Callable()
		))
	for member in _player.party_members:
		grid.add_child(_make_grid_cell(
			"res://assets/blade_ally.png", member.get("name", "Ally"),
			"%d%% dmg" % int(member.get("dmg_mult", 1.0) * 100), false,
			"A recruited companion, fighting at your side. Follows you in the field.", Callable()
		))

# --- Map tab: a schematic (not a live camera capture) of wherever you
# currently are, scaled to fit -- see _on_map_draw. --------------------

func _build_map_tab(container: VBoxContainer) -> void:
	_add_section_heading(container, "MAP")
	map_canvas = Control.new()
	map_canvas.custom_minimum_size = Vector2(780, 420)
	map_canvas.draw.connect(_on_map_draw)
	container.add_child(map_canvas)
	var legend := Label.new()
	legend.text = "Green: you. Numbered gold dots: shops and services you've found so far. Tan box: the town."
	legend.add_theme_font_size_override("font_size", 12)
	legend.add_theme_color_override("font_color", Color(0.7, 0.7, 0.65))
	container.add_child(legend)

# One unified wilderness map -- the town is embedded in the same space (see
# Main.gd:TOWN_AREA_ORIGIN), not a separate view to switch to, so it's just
# drawn as a labeled region within the whole map rather than its own screen.
func _on_map_draw() -> void:
	var main := get_parent()
	var area_size: Vector2 = main.WORLD_SIZE
	var canvas_size: Vector2 = map_canvas.size
	if canvas_size.x <= 0 or canvas_size.y <= 0:
		return
	# The map hugs the left edge so the right-hand column stays free for the
	# numbered legend -- a dozen-plus building labels can't fit inside the
	# town's own ~220px-wide box on the map.
	var legend_width := 170.0
	var scale_factor: float = minf((canvas_size.x - legend_width) / area_size.x, canvas_size.y / area_size.y)
	var draw_size: Vector2 = area_size * scale_factor
	var draw_offset: Vector2 = Vector2(0, (canvas_size.y - draw_size.y) / 2.0)
	var font := ThemeDB.fallback_font

	var to_map := func(world_pos: Vector2) -> Vector2:
		return draw_offset + world_pos * scale_factor

	map_canvas.draw_rect(Rect2(draw_offset, draw_size), Color(0.16, 0.22, 0.14), true)
	map_canvas.draw_rect(Rect2(draw_offset, draw_size), Color(0.55, 0.55, 0.5), false, 2.0)

	var town_top_left: Vector2 = to_map.call(main.TOWN_AREA_ORIGIN)
	var town_draw_size: Vector2 = main.TOWN_SIZE * scale_factor
	map_canvas.draw_rect(Rect2(town_top_left, town_draw_size), Color(0.32, 0.3, 0.27), true)
	map_canvas.draw_rect(Rect2(town_top_left, town_draw_size), Color(0.7, 0.6, 0.3), false, 2.0)
	map_canvas.draw_string(font, town_top_left + Vector2(4, -4), "TOWN", HORIZONTAL_ALIGNMENT_LEFT, town_draw_size.x, 12, Color(0.9, 0.8, 0.5))

	# Numbered dots on the map, names in a legend column to its right --
	# skipped for anywhere the player hasn't actually reached yet, unless
	# Pathfinder's Compass (talisman) reveals everything up front.
	var legend_x: float = draw_offset.x + draw_size.x + 16.0
	var legend_y := 14.0
	var number := 1
	var reveal_all: bool = _player.talisman_bonus("reveal_all_locations") > 0.0
	for key in main.town_building_positions:
		if not reveal_all and not _player.discovered_locations.get(key, false):
			continue
		var p: Vector2 = to_map.call(main.town_building_positions[key])
		var venue_name: String = main.TOWN_LAYOUT.get(key, {}).get("name", key.capitalize())
		map_canvas.draw_circle(p, 7, Color(0.9, 0.7, 0.3))
		map_canvas.draw_string(font, p + Vector2(-8, 4), str(number), HORIZONTAL_ALIGNMENT_CENTER, 16, 11, Color(0.1, 0.08, 0.02))
		map_canvas.draw_circle(Vector2(legend_x + 8, legend_y - 4), 7, Color(0.9, 0.7, 0.3))
		map_canvas.draw_string(font, Vector2(legend_x, legend_y), str(number), HORIZONTAL_ALIGNMENT_CENTER, 16, 11, Color(0.1, 0.08, 0.02))
		map_canvas.draw_string(font, Vector2(legend_x + 22, legend_y), venue_name, HORIZONTAL_ALIGNMENT_LEFT, legend_width - 24, 13, Color(0.92, 0.92, 0.88))
		legend_y += 24.0
		number += 1

	var player_p: Vector2 = to_map.call(_player.global_position)
	map_canvas.draw_circle(player_p, 6, Color(0.3, 0.95, 0.3))
	map_canvas.draw_circle(player_p, 6, Color(1, 1, 1), false, 1.5)

# --- Shared grid-cell builder --------------------------------------------

# icon_path may point at a nonexistent file (blank icon, no crash). An empty
# on_click Callable makes the cell purely informational (Armor's single
# card, Arrows) -- still styled like a grid cell for a consistent look, just
# not clickable.
func _make_grid_cell(icon_path: String, title: String, subtitle: String, equipped: bool, tooltip: String, on_click: Callable) -> Button:
	var cell := Button.new()
	cell.custom_minimum_size = CELL_SIZE
	cell.tooltip_text = tooltip
	cell.disabled = not on_click.is_valid()
	if on_click.is_valid():
		cell.pressed.connect(on_click)
	_style_grid_cell(cell, equipped)

	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 2)
	cell.add_child(content)

	var top_pad := Control.new()
	top_pad.custom_minimum_size = Vector2(0, 6)
	content.add_child(top_pad)

	if icon_path != "" and ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.texture = load(icon_path)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.custom_minimum_size = Vector2(44, 44)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		content.add_child(icon)

	var title_label := Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	title_label.custom_minimum_size = Vector2(CELL_SIZE.x - 12, 0)
	title_label.add_theme_font_size_override("font_size", 13)
	title_label.add_theme_color_override("font_color", EQUIPPED_COLOR if equipped else Color(0.9, 0.9, 0.85))
	content.add_child(title_label)

	if subtitle != "":
		var subtitle_label := Label.new()
		subtitle_label.text = subtitle
		subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle_label.add_theme_font_size_override("font_size", 11)
		subtitle_label.add_theme_color_override("font_color", Color(0.6, 0.85, 0.6) if equipped else Color(0.65, 0.65, 0.6))
		content.add_child(subtitle_label)

	return cell

func _style_grid_cell(button: Button, equipped: bool) -> void:
	var border: Color = EQUIPPED_COLOR if equipped else BORDER_COLOR
	var bg: Color = Color(0.16, 0.15, 0.08, 0.95) if equipped else Color(0.12, 0.12, 0.14, 0.9)
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg
	normal.border_color = border
	normal.set_border_width_all(3 if equipped else 2)
	normal.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("disabled", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.border_color = Color(1.0, 0.9, 0.3)
	hover.bg_color = bg.lightened(0.08)
	button.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = bg.darkened(0.1)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _add_section_heading(container: VBoxContainer, text: String) -> void:
	var heading := Label.new()
	heading.text = text
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	container.add_child(heading)

func _add_plain_label(container: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.65))
	container.add_child(label)

func _play_sfx(sfx_name: String) -> void:
	var parent := get_parent()
	if parent != null and parent.has_method("play_sfx"):
		parent.play_sfx(sfx_name)
