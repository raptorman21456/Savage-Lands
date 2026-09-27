extends TownPanel
class_name DojoPanel

# The town Dojo: your weapons down the left (each with how many of its three moves
# you know), and on the right the selected weapon's moves as three cards with a
# Learn button. The rules (costs, which types teach) live in Dojo.gd; what's been
# learned is Player.learned_specials. Weapon icons and tier colours come from
# WeaponIcons, the same as the Inventory.

const DojoScript := preload("res://scripts/Dojo.gd")
const WeaponsScript := preload("res://scripts/Weapons.gd")
const WeaponIconsScript := preload("res://scripts/WeaponIcons.gd")
const PixelUIScript := preload("res://scripts/PixelUI.gd")

const GOLD := Color(1.0, 0.86, 0.36)
const DIM := Color(0.68, 0.68, 0.72)
const GOOD := Color(0.55, 0.95, 0.55)
const BAD := Color(1.0, 0.5, 0.45)
const STAMINA_BLUE := Color(0.55, 0.78, 1.0)
const LIST_WIDTH := 262.0
const NUMERALS := ["I", "II", "III"]

var coins_label: Label
var speech_label: Label
var weapon_list: VBoxContainer
var detail_box: VBoxContainer
# The weapon type whose moves are showing on the right.
var selected_base_id := ""
# base id -> the entry button in the left list, and the three Learn/Whisper
# buttons of the selected weapon in move order (both rebuilt by _refresh).
var weapon_buttons := {}
var move_buttons: Array = []

func _panel_title() -> String:
	return "THE DOJO"

func _window_size() -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	return Vector2(minf(viewport_size.x - 60.0, 900.0), minf(viewport_size.y - 30.0, 610.0))

func _build_content(outer: VBoxContainer) -> void:
	window.add_theme_stylebox_override("panel", PixelUIScript.panel_style(true))
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	title_label.add_theme_color_override("font_outline_color", PixelUIScript.OUTLINE)
	title_label.add_theme_constant_override("outline_size", 6)
	PixelUIScript.skin_button(close_button)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	outer.add_child(top)
	speech_label = _make_label("", 13, DIM)
	speech_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(speech_label)
	var coin_icon := TextureRect.new()
	coin_icon.texture = load("res://assets/coin.png")
	coin_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	coin_icon.custom_minimum_size = Vector2(26, 26)
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(coin_icon)
	coins_label = Label.new()
	coins_label.add_theme_font_size_override("font_size", 22)
	coins_label.add_theme_color_override("font_color", GOLD)
	coins_label.add_theme_color_override("font_outline_color", PixelUIScript.OUTLINE)
	coins_label.add_theme_constant_override("outline_size", 5)
	top.add_child(coins_label)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	outer.add_child(body)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(LIST_WIDTH, 0)
	left.add_theme_constant_override("separation", 6)
	body.add_child(left)
	left.add_child(_make_label("YOUR WEAPONS", 12, DIM))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	weapon_list = VBoxContainer.new()
	weapon_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_list.add_theme_constant_override("separation", 6)
	scroll.add_child(weapon_list)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(2, 0)
	divider.color = Color(0.36, 0.27, 0.12)
	body.add_child(divider)

	detail_box = VBoxContainer.new()
	detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_box.add_theme_constant_override("separation", 8)
	body.add_child(detail_box)

func _on_opened() -> void:
	speech_label.text = "\"A weapon is only as good as the moves you've drilled into it. Pay the fee, put in the hours, and it's yours for good.\""
	if weapon_buttons.has(selected_base_id):
		weapon_buttons[selected_base_id].grab_focus()

# --- Data helpers ------------------------------------------------------------

# The weapon types you hold that have moves to teach, the one in your hand first
# and the rest in teaching order.
func _ordered_bases() -> Array:
	var in_hand: String = WeaponsScript.get_base_type(_player.current_weapon_base).get("id", "")
	var first := []
	var rest := []
	for base in DojoScript.owned_bases(_player.owned_weapons):
		if base.id == in_hand:
			first.append(base)
		else:
			rest.append(base)
	return first + rest

func _learned_count(base: Dictionary) -> int:
	var count := 0
	for special in base.specials:
		if _player.knows_special(special.id):
			count += 1
	return count

# The variant of this type to show: the one in your hand, else the best tier you own.
func _showcase_variant(base: Dictionary) -> Dictionary:
	var best := {}
	var best_rank := -2
	for id in _player.owned_weapons:
		var variant: Dictionary = WeaponsScript.get_owned_variant(id)
		if variant.is_empty() or WeaponsScript.get_base_type(variant).get("id", "") != base.id:
			continue
		if variant.get("id", "") == _player.current_weapon_base.get("id", ""):
			return variant
		var rank := -1
		for tier in WeaponsScript.TIERS:
			if tier.tier_name == variant.get("tier_name", ""):
				rank = tier.rank
		if rank > best_rank:
			best = variant
			best_rank = rank
	return best if not best.is_empty() else {"icon": base.get("icon", "")}

func _icon_plate(variant: Dictionary, icon_scale: int) -> PanelContainer:
	var tier_color: Color = WeaponIconsScript.tier_color(variant)
	var plate := PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override("panel", _box(tier_color.darkened(0.82), tier_color.darkened(0.35), 2, 6, 3))
	var icon := TextureRect.new()
	icon.texture = WeaponIconsScript.texture_for(variant)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size = Vector2(32 * icon_scale, 32 * icon_scale)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(icon)
	return plate

func _box(bg: Color, border: Color, border_width: int, radius: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style

# --- Refresh -----------------------------------------------------------------

func _refresh() -> void:
	if _player == null or weapon_list == null:
		return
	coins_label.text = "%d" % _player.coins
	var bases: Array = _ordered_bases()
	var has_selected := false
	for base in bases:
		if base.id == selected_base_id:
			has_selected = true
	if not has_selected:
		selected_base_id = bases[0].id if not bases.is_empty() else ""
	_clear(weapon_list)
	weapon_buttons.clear()
	var in_hand: String = WeaponsScript.get_base_type(_player.current_weapon_base).get("id", "")
	for base in bases:
		var entry := _make_weapon_entry(base, base.id == in_hand)
		weapon_list.add_child(entry)
		weapon_buttons[base.id] = entry
	if bases.is_empty():
		weapon_list.add_child(_make_label("None yet.", 13, DIM))
	_style_entries()
	_build_detail()

# One row of the left list: icon, name, three pips (one per move, gold once learned)
# and an IN HAND tag.
func _make_weapon_entry(base: Dictionary, in_hand: bool) -> Button:
	var entry := Button.new()
	entry.custom_minimum_size = Vector2(0, 62)
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.pressed.connect(func(): select_base(base.id))
	var pad := MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_%s" % side, 7)
	entry.add_child(pad)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	pad.add_child(row)
	row.add_child(_icon_plate(_showcase_variant(base), 1))

	var text_col := VBoxContainer.new()
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.alignment = BoxContainer.ALIGNMENT_CENTER
	text_col.add_theme_constant_override("separation", 4)
	row.add_child(text_col)
	var name_label := Label.new()
	name_label.text = base.name
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(0.94, 0.93, 0.88))
	text_col.add_child(name_label)
	var meta := HBoxContainer.new()
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta.add_theme_constant_override("separation", 4)
	text_col.add_child(meta)
	for i in base.specials.size():
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(11, 11)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.color = GOLD if _player.knows_special(base.specials[i].id) else Color(0.2, 0.19, 0.24)
		meta.add_child(pip)
	var meta_spacer := Control.new()
	meta_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta.add_child(meta_spacer)
	if in_hand:
		var tag := Label.new()
		tag.text = "IN HAND"
		tag.add_theme_font_size_override("font_size", 10)
		tag.add_theme_color_override("font_color", GOOD)
		meta.add_child(tag)
	return entry

func _style_entries() -> void:
	for id in weapon_buttons:
		_style_entry(weapon_buttons[id], id == selected_base_id)

func _style_entry(button: Button, selected: bool) -> void:
	var bg: Color = Color(0.19, 0.16, 0.08, 0.98) if selected else Color(0.11, 0.11, 0.14, 0.95)
	var border: Color = GOLD if selected else Color(0.38, 0.38, 0.44)
	var normal: StyleBoxFlat = _box(bg, border, 3 if selected else 2, 6, 0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("pressed", _box(bg.darkened(0.12), border, 3 if selected else 2, 6, 0))
	button.add_theme_stylebox_override("hover", _box(bg.lightened(0.08), border.lightened(0.3), 3 if selected else 2, 6, 0))
	var focus: StyleBoxFlat = _box(Color(0, 0, 0, 0), Color(1, 1, 1, 0.9), 2, 6, 0)
	focus.set_expand_margin_all(2)
	button.add_theme_stylebox_override("focus", focus)

func select_base(base_id: String) -> void:
	if base_id == selected_base_id:
		return
	selected_base_id = base_id
	_style_entries()
	_build_detail()

# --- The selected weapon's moves ---------------------------------------------

func _selected_base() -> Dictionary:
	for base in DojoScript.owned_bases(_player.owned_weapons):
		if base.id == selected_base_id:
			return base
	return {}

func _build_detail() -> void:
	_clear(detail_box)
	move_buttons.clear()
	var base: Dictionary = _selected_base()
	if base.is_empty():
		detail_box.add_child(_make_label("You hold no weapons with moves to teach. Buy one at the shop and come back.", 15, DIM))
		return
	var variant: Dictionary = _showcase_variant(base)
	var learned: int = _learned_count(base)
	var in_hand: bool = base.id == WeaponsScript.get_base_type(_player.current_weapon_base).get("id", "")

	# Header: a big icon, the name, and how far along you are.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	detail_box.add_child(header)
	header.add_child(_icon_plate(variant, 2))
	var titles := VBoxContainer.new()
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 3)
	header.add_child(titles)
	var name_label := Label.new()
	name_label.text = base.name.to_upper()
	name_label.add_theme_font_size_override("font_size", 26)
	name_label.add_theme_color_override("font_color", GOLD)
	name_label.add_theme_color_override("font_outline_color", PixelUIScript.OUTLINE)
	name_label.add_theme_constant_override("outline_size", 6)
	titles.add_child(name_label)
	var progress := "%d of %d moves learned" % [learned, base.specials.size()]
	if in_hand:
		progress += "   |   in your hand"
	titles.add_child(_make_label(progress, 14, GOOD if learned == base.specials.size() else DIM))
	var flavor: String = base.get("description", "")
	if flavor != "":
		var flavor_label := _make_label(flavor, 12, Color(0.6, 0.6, 0.64))
		flavor_label.max_lines_visible = 2
		titles.add_child(flavor_label)

	for i in base.specials.size():
		detail_box.add_child(_make_move_card(base, i))

	if _player.talisman_bonus("weapon_whisperer") > 0.0:
		detail_box.add_child(_make_label("Weapon Whisperer: mark up to three learned moves as Whispered and they replace whatever weapon you hold.", 12, STAMINA_BLUE))

# A move as a card: its step (I-III, which sets the price), name, stamina cost,
# description, and on the right the price and the Learn button.
func _make_move_card(base: Dictionary, index: int) -> PanelContainer:
	var special: Dictionary = base.specials[index]
	var learned: bool = _player.knows_special(special.id)
	var cost: int = DojoScript.lesson_cost(index)
	var affordable: bool = _player.coins >= cost
	var whisperer_active: bool = _player.talisman_bonus("weapon_whisperer") > 0.0
	var whispered: bool = _player.weapon_whisperer_specials.has(special.id)
	var highlight: bool = learned and (not whisperer_active or whispered)

	var card := PanelContainer.new()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _box(Color(0.14, 0.12, 0.08, 0.95) if learned else Color(0.11, 0.11, 0.14, 0.95), GOLD if highlight else Color(0.38, 0.38, 0.44), 2, 7, 10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var step := Label.new()
	step.text = NUMERALS[clampi(index, 0, NUMERALS.size() - 1)]
	step.custom_minimum_size = Vector2(38, 0)
	step.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	step.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	step.add_theme_font_size_override("font_size", 24)
	step.add_theme_color_override("font_color", GOLD if learned else Color(0.5, 0.46, 0.36))
	step.add_theme_color_override("font_outline_color", PixelUIScript.OUTLINE)
	step.add_theme_constant_override("outline_size", 5)
	row.add_child(step)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.alignment = BoxContainer.ALIGNMENT_CENTER
	text_col.add_theme_constant_override("separation", 4)
	row.add_child(text_col)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	text_col.add_child(title_row)
	var move_name := Label.new()
	move_name.text = special.name
	move_name.add_theme_font_size_override("font_size", 17)
	move_name.add_theme_color_override("font_color", GOLD if highlight else Color(0.94, 0.93, 0.88))
	title_row.add_child(move_name)
	var sta := Label.new()
	sta.text = "%d STA" % special.stamina_cost
	sta.add_theme_font_size_override("font_size", 12)
	sta.add_theme_color_override("font_color", STAMINA_BLUE)
	title_row.add_child(sta)
	# The move data writes a literal percent sign as %% (it was once run through a
	# format string), so undo that for display.
	text_col.add_child(_make_label(special.description.replace("%%", "%"), 13, Color(0.78, 0.78, 0.74)))

	var action := VBoxContainer.new()
	action.custom_minimum_size = Vector2(122, 0)
	action.alignment = BoxContainer.ALIGNMENT_CENTER
	action.add_theme_constant_override("separation", 4)
	row.add_child(action)
	var button := Button.new()
	button.custom_minimum_size = Vector2(122, 40)
	PixelUIScript.skin_button(button)
	if learned:
		if whisperer_active:
			button.text = "Whispered" if whispered else "Whisper"
			button.pressed.connect(_on_whisper_pressed.bind(special.id))
		else:
			button.text = "Learned"
			button.disabled = true
	else:
		var price := Label.new()
		price.text = "%d coins" % cost
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price.add_theme_font_size_override("font_size", 14)
		price.add_theme_color_override("font_color", GOOD if affordable else BAD)
		action.add_child(price)
		button.text = "Learn"
		button.disabled = not affordable
		button.pressed.connect(_on_learn_pressed.bind(special.id))
	action.add_child(button)
	move_buttons.append(button)
	return card

func _on_whisper_pressed(special_id: String) -> void:
	_player.toggle_whisperer_special(special_id)
	_refresh()
	_restore_focus()

# Returns whether the lesson went through (tests drive this directly).
func learn(special_id: String) -> bool:
	var ok: bool = _player.try_learn_special(special_id)
	_play_sfx("purchase" if ok else "error")
	if ok:
		speech_label.text = "\"Good. Again -- until you stop thinking about it.\""
		_announce_learned(special_id)
	else:
		speech_label.text = "\"Not enough coin, or you already know it. Come back when you've earned more.\""
	_refresh()
	if visible:
		_restore_focus()
	return ok

func _announce_learned(special_id: String) -> void:
	var main := get_parent()
	var found: Dictionary = DojoScript.locate_special(special_id)
	if not found.is_empty() and main != null and main.hud != null:
		main.hud.show_message("You learned %s!" % found.special.name)

func _on_learn_pressed(special_id: String) -> void:
	learn(special_id)

# After a lesson or a Whisper toggle the rebuilt buttons have lost keyboard focus:
# put it on the next thing you could do (an enabled move button), else the weapon.
func _restore_focus() -> void:
	for button in move_buttons:
		if not button.disabled:
			button.grab_focus()
			return
	if weapon_buttons.has(selected_base_id):
		weapon_buttons[selected_base_id].grab_focus()
