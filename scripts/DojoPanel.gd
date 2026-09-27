extends TownPanel
class_name DojoPanel

# The town Dojo: your weapons down the left (each with how many of its three moves
# you know), and on the right the selected weapon's moves as three cards with a
# Learn button. The rules (costs, which types teach) live in Dojo.gd; what's been
# learned is Player.learned_specials. The frame, list and cards are built with the
# helpers in TownUI.gd, shared with the Blacksmith, and weapon icons and tier
# colours come from WeaponIcons, the same as the Inventory.

const DojoScript := preload("res://scripts/Dojo.gd")
const WeaponsScript := preload("res://scripts/Weapons.gd")
const WeaponIconsScript := preload("res://scripts/WeaponIcons.gd")
const PixelUIScript := preload("res://scripts/PixelUI.gd")
const TownUIScript := preload("res://scripts/TownUI.gd")

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
	return TownUIScript.picker_window_size(get_viewport().get_visible_rect().size)

func _build_content(outer: VBoxContainer) -> void:
	TownUIScript.apply_bronze_frame(self)
	var top: Dictionary = TownUIScript.add_top_row(outer)
	speech_label = top.speech
	coins_label = top.coins
	var body: Dictionary = TownUIScript.add_picker_body(outer, "YOUR WEAPONS")
	weapon_list = body.list
	detail_box = body.detail

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

func _plate(variant: Dictionary, icon_scale: int) -> PanelContainer:
	return TownUIScript.plate(WeaponIconsScript.texture_for(variant), Vector2(32, 32) * icon_scale, WeaponIconsScript.tier_color(variant))

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
		weapon_list.add_child(_make_label("None yet.", 13, TownUIScript.DIM))
	_style_entries()
	_build_detail()

# One row of the left list: icon, name, three pips (one per move, gold once learned)
# and an IN HAND tag.
func _make_weapon_entry(base: Dictionary, in_hand: bool) -> Button:
	var pips: Array = base.specials.map(func(s): return _player.knows_special(s.id))
	var entry: Button = TownUIScript.make_entry(_plate(_showcase_variant(base), 1), base.name, pips, "IN HAND" if in_hand else "", TownUIScript.GOOD)
	entry.pressed.connect(func(): select_base(base.id))
	return entry

func _style_entries() -> void:
	for id in weapon_buttons:
		TownUIScript.style_entry(weapon_buttons[id], id == selected_base_id)

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
		detail_box.add_child(_make_label("You hold no weapons with moves to teach. Buy one at the shop and come back.", 15, TownUIScript.DIM))
		return
	var learned: int = _learned_count(base)
	var in_hand: bool = base.id == WeaponsScript.get_base_type(_player.current_weapon_base).get("id", "")
	var progress := "%d of %d moves learned" % [learned, base.specials.size()]
	if in_hand:
		progress += "   |   in your hand"
	var lines: Array = [[progress, TownUIScript.GOOD if learned == base.specials.size() else TownUIScript.DIM, 14]]
	if base.get("description", "") != "":
		lines.append([base.description, Color(0.6, 0.6, 0.64), 12])
	detail_box.add_child(TownUIScript.make_header(_plate(_showcase_variant(base), 2), base.name.to_upper(), lines))

	for i in base.specials.size():
		detail_box.add_child(_make_move_card(base, i))

	if _player.talisman_bonus("weapon_whisperer") > 0.0:
		detail_box.add_child(_make_label("Weapon Whisperer: mark up to three learned moves as Whispered and they replace whatever weapon you hold.", 12, TownUIScript.STAMINA_BLUE))

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
	card.add_theme_stylebox_override("panel", TownUIScript.box(Color(0.14, 0.12, 0.08, 0.95) if learned else Color(0.11, 0.11, 0.14, 0.95), TownUIScript.GOLD if highlight else Color(0.38, 0.38, 0.44), 2, 7, 10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var step := Label.new()
	step.text = NUMERALS[clampi(index, 0, NUMERALS.size() - 1)]
	step.custom_minimum_size = Vector2(38, 0)
	step.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	step.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	step.add_theme_font_size_override("font_size", 24)
	step.add_theme_color_override("font_color", TownUIScript.GOLD if learned else Color(0.5, 0.46, 0.36))
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
	move_name.add_theme_color_override("font_color", TownUIScript.GOLD if highlight else Color(0.94, 0.93, 0.88))
	title_row.add_child(move_name)
	var sta := Label.new()
	sta.text = "%d STA" % special.stamina_cost
	sta.add_theme_font_size_override("font_size", 12)
	sta.add_theme_color_override("font_color", TownUIScript.STAMINA_BLUE)
	title_row.add_child(sta)
	# The move data writes a literal percent sign as %% (it was once run through a
	# format string), so undo that for display.
	text_col.add_child(_make_label(special.description.replace("%%", "%"), 13, Color(0.78, 0.78, 0.74)))

	var action: Dictionary
	if learned and whisperer_active:
		action = TownUIScript.make_action("", true, "Whispered" if whispered else "Whisper", false)
		action.button.pressed.connect(_on_whisper_pressed.bind(special.id))
	elif learned:
		action = TownUIScript.make_action("", true, "Learned", true)
	else:
		action = TownUIScript.make_action("%d coins" % cost, affordable, "Learn", not affordable)
		action.button.pressed.connect(_on_learn_pressed.bind(special.id))
	row.add_child(action.box)
	move_buttons.append(action.button)
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
