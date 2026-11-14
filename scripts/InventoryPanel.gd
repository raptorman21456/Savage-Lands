extends CanvasLayer
class_name InventoryPanel

# The player's in-run menu -- opened from the pause menu's "Inventory" button or the overworld's "I" key (see Main.gd:_process) -- as a
# floating window in the pixel kit (PixelKit.gd): five tabs, icon-only except the one you are on.
#   Gear      weapons / armour / clothes / shields as a grid of cards with a detail card beside it (InvGearView)
#   Items     potions, food and arrows (click a potion or food to use it)
#   Party     you and your recruits on one page (PartyScreen): equipment tiles, specials, stats; press a tile and a picker popup opens
#   Map       the continent with pins and zoom (InvMapView)
#   Settings  audio, controls, gameplay (InvSettingsView)
# Talismans have no tab: they are a popup (InvTalismanPopup) from a unit's Talismans line on the Party page.
# Weapons carry their quality as slowly turning pixel rays (PixelRays.gd), never in the name.
#
# What a button does is decided in InvData (the same equip functions on Player as ever); this file builds the window, owns the popups,
# plays the sounds and rebuilds. The `_on_*_pressed` handlers below are kept as plain "do this to the player" entry points.

const WeaponsScript := preload("res://scripts/Weapons.gd")
const ShieldsScript := preload("res://scripts/Shields.gd")
const ClothingScript := preload("res://scripts/Clothing.gd")
const ArmorScript := preload("res://scripts/Armor.gd")

const TABS := ["Gear", "Items", "Party", "Map", "Settings"]
const TAB_ICONS := {"Gear": "tab_gear", "Items": "tab_items", "Party": "tab_party", "Map": "tab_map", "Settings": "tab_settings"}
const WINDOW_SIZE := Vector2(1120, 624)
const POPUP_SIZE := Vector2(1076, 604)

var _was_paused := false
var _player: Player = null
var active_tab: String = "Gear"
var tab_buttons := {}
var tab_containers := {}
# Whose sheet the Party tab shows (PartyMember.id, or PartyScreen.HERO_ID for you) and which of its pages; kept here because the tab is rebuilt.
var party_selected_id := -2
var party_page := "Equipment"
var settings_page := "Audio"
var view_states := {}          # each view's remembered category / selection / sort / search, by name
var window: Panel = null
var content: Control = null
var body: Control = null
var scrim: ColorRect = null
var popup_layer: Control = null
var popup_view: Control = null  # the view inside the open popup, if any
var popup_kind := ""            # "gear", "talisman" or "pick"
var popup_member = null
var popup_category := ""
var gear_view: InvGearView = null
var items_view: InvGearView = null
var party_screen: PartyScreen = null
var map_view: InvMapView = null
var settings_view: InvSettingsView = null

func _ready() -> void:
	layer = 30
	visible = false
	_build()

func _build() -> void:
	scrim = ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.75)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)
	window = Panel.new()
	window.size = WINDOW_SIZE
	window.add_theme_stylebox_override("panel", PixelKit.frame("panel"))
	scrim.add_child(window)
	content = Control.new()
	content.position = Vector2(14, 14)
	content.size = WINDOW_SIZE - Vector2(28, 28)
	window.add_child(content)
	var title := PixelKit.label("Inventory", "head", PixelKit.GOLD3)
	title.position = Vector2(8, 10)
	content.add_child(title)
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 0)
	tab_row.position = Vector2(230, 4)
	content.add_child(tab_row)
	for tab_name in TABS:
		var b := PixelButton.make("", TAB_ICONS[tab_name], _on_tab_pressed.bind(tab_name), tab_name == active_tab)
		b.tooltip_text = tab_name
		tab_row.add_child(b)
		tab_buttons[tab_name] = b
	var close_button := PixelButton.make("×", "", close)
	close_button.tooltip_text = "Close"
	close_button.position = Vector2(content.size.x - 56, 4)
	close_button.custom_minimum_size = Vector2(52, 48)
	content.add_child(close_button)
	body = Control.new()
	body.position = Vector2(6, 62)
	body.size = Vector2(content.size.x - 12, 500)
	content.add_child(body)
	var hint := PixelKit.label("Q / E  Tabs      Esc  Back      I  Close", "body", PixelKit.DIM)
	hint.position = Vector2(8, content.size.y - 26)
	content.add_child(hint)
	for tab_name in TABS:
		var container := Control.new()
		container.size = body.size
		container.visible = tab_name == active_tab
		body.add_child(container)
		tab_containers[tab_name] = container
	popup_layer = Control.new()
	popup_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.add_child(popup_layer)
	_style_tab_buttons()

func _center_window() -> void:
	window.position = ((get_viewport().get_visible_rect().size - WINDOW_SIZE) / 2.0).round()

func open(player_ref: Player) -> void:
	_player = player_ref
	_was_paused = get_tree().paused
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_center_window()
	close_popup()
	_refresh()
	visible = true

func close() -> void:
	close_popup()
	visible = false
	get_tree().paused = _was_paused

func _on_tab_pressed(tab_name: String) -> void:
	close_popup()
	_select_tab(tab_name)

func _select_tab(tab_name: String) -> void:
	active_tab = tab_name
	for name in tab_containers:
		tab_containers[name].visible = name == tab_name
	_style_tab_buttons()
	_build_tab(tab_name)

# Only the tab you are on shows its name; the rest are just their icon.
func _style_tab_buttons() -> void:
	for name in tab_buttons:
		var b: PixelButton = tab_buttons[name]
		b.on = name == active_tab
		b.text = name if name == active_tab else ""

func _refresh() -> void:
	if _player == null:
		return
	_build_tab(active_tab)
	_refresh_popup()

func _state(key: String) -> Dictionary:
	if not view_states.has(key):
		view_states[key] = {}
	return view_states[key]

func _clear(container: Control) -> void:
	for c in container.get_children():
		container.remove_child(c)
		c.queue_free()

func _build_tab(tab_name: String) -> void:
	if _player == null or not tab_containers.has(tab_name):
		return
	var container: Control = tab_containers[tab_name]
	_clear(container)
	match tab_name:
		"Gear":
			gear_view = InvGearView.new()
			gear_view.size = body.size
			container.add_child(gear_view)
			gear_view.setup(self, _player, "gear", {"state": _state("gear"), "cols": 4, "left_w": 568.0, "detail_w": body.size.x - 568.0 - 12.0})
		"Items":
			items_view = InvGearView.new()
			items_view.size = body.size
			container.add_child(items_view)
			items_view.setup(self, _player, "items", {"state": _state("items"), "cols": 4, "left_w": 568.0, "detail_w": body.size.x - 568.0 - 12.0})
		"Party":
			party_screen = PartyScreen.new()
			party_screen.size = body.size
			container.add_child(party_screen)
			party_screen.setup(self, _player, get_parent())
		"Map":
			map_view = InvMapView.new()
			var frame := PixelKit.panel_box("panel_steel")
			frame.size = body.size
			container.add_child(frame)
			map_view.position = Vector2(8, 8)
			map_view.size = body.size - Vector2(16, 16)
			frame.add_child(map_view)
			map_view.setup(self, _player, get_parent())
		"Settings":
			settings_view = InvSettingsView.new()
			settings_view.size = body.size
			container.add_child(settings_view)
			settings_view.setup(self)

# --- popups ----------------------------------------------------------------------------------------------------------------------------

func popup_open() -> bool:
	return popup_view != null and is_instance_valid(popup_view)

func close_popup() -> void:
	if popup_layer == null:
		return
	for c in popup_layer.get_children():
		popup_layer.remove_child(c)
		c.queue_free()
	popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_view = null
	popup_kind = ""
	popup_member = null
	popup_category = ""

# The frame every popup wears: a dimmed backdrop over the window, a panel with a header (icon, title, who it is for, a close button)
# and an area for the content. Returns that area.
func _open_popup_frame(icon_name: String, title_text: String, sub_text: String, size_px: Vector2) -> Control:
	close_popup()
	popup_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.05, 0.72)
	dim.size = WINDOW_SIZE
	dim.position = window.position
	dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: close_popup())
	popup_layer.add_child(dim)
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", PixelKit.frame("panel"))
	frame.size = size_px
	frame.position = window.position + ((WINDOW_SIZE - size_px) / 2.0).round()
	popup_layer.add_child(frame)
	var inner := Control.new()
	inner.position = Vector2(14, 14)
	inner.size = size_px - Vector2(28, 28)
	frame.add_child(inner)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.position = Vector2(0, 0)
	head.size = Vector2(inner.size.x, 48)
	inner.add_child(head)
	if icon_name != "":
		head.add_child(PixelKit.icon(icon_name, 32))
	head.add_child(PixelKit.label(title_text, "head", PixelKit.GOLD3))
	head.add_child(PixelKit.label(sub_text, "body", PixelKit.DIM))
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(fill)
	var x := PixelButton.make("×", "", close_popup)
	x.custom_minimum_size = Vector2(52, 48)
	head.add_child(x)
	var area := Control.new()
	area.position = Vector2(0, 56)
	area.size = Vector2(inner.size.x, inner.size.y - 56.0 - 28.0)
	inner.add_child(area)
	var hint := PixelKit.label("Esc  Back", "body", PixelKit.DIM)
	hint.position = Vector2(0, inner.size.y - 24)
	inner.add_child(hint)
	return area

# The picker for one slot of one unit: the same grid and detail as the Gear tab, with whatever is worn marked.
func open_gear_popup(member, category: String) -> void:
	var who := "for you" if member == null else "for %s" % member.name
	var area := _open_popup_frame(InvData.CATEGORY_ICONS.get(category, "tab_gear"), category, who, POPUP_SIZE)
	var view := InvGearView.new()
	view.size = area.size
	area.add_child(view)
	view.setup(self, _player, "gear", {"member": member, "fixed": category, "cols": 4, "left_w": 568.0, "detail_w": area.size.x - 568.0 - 12.0, "state": _state("popup_" + category)})
	popup_view = view
	popup_kind = "gear"
	popup_member = member
	popup_category = category

func open_talisman_popup(member) -> void:
	var who := "You" if member == null else str(member.name)
	var level: int = _player.level if member == null else member.level
	var slots := InvData.talisman_slots(_player, member)
	var area := _open_popup_frame("tab_talismans", "Talismans", "%s · Level %d · %d of %d slots open" % [who, level, int(slots.open), talisman_slot_count()], POPUP_SIZE)
	var view := InvTalismanPopup.new()
	view.size = area.size
	area.add_child(view)
	view.setup(self, _player, member, _state("popup_talismans"))
	popup_view = view
	popup_kind = "talisman"
	popup_member = member

func talisman_slot_count() -> int:
	return load("res://scripts/Talismans.gd").SLOT_LEVELS.size() + 1

# A short list to choose from: rows of {label, right, disabled, pick (a Callable)}; choosing one runs it and closes the popup.
func open_pick_popup(title_text: String, sub_text: String, rows: Array) -> void:
	var area := _open_popup_frame("stat_crit", title_text, sub_text, Vector2(720, minf(120.0 + 52.0 * rows.size(), 560.0)))
	var scroll := ScrollContainer.new()
	scroll.size = area.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	PixelKit.style_scroll(scroll)
	area.add_child(scroll)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	for r in rows:
		var text := str(r.label) + (("   [%s]" % r.right) if str(r.get("right", "")) != "" else "")
		var pick: Callable = r.pick
		var b := PixelButton.make(text, "", func():
			close_popup()
			pick.call()
		)
		b.disabled = bool(r.get("disabled", false))
		col.add_child(b)
	popup_view = scroll
	popup_kind = "pick"

# After any change: rebuild whatever popup is open so it shows the new truth (or close it if what it was for is gone).
func _refresh_popup() -> void:
	if not popup_open():
		return
	match popup_kind:
		"gear":
			if popup_view is InvGearView:
				popup_view.rebuild()
		"talisman":
			if popup_view is InvTalismanPopup:
				popup_view.rebuild()

# --- input -----------------------------------------------------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	# A key rebind that is waiting takes the next key.
	if active_tab == "Settings" and settings_view != null and is_instance_valid(settings_view) and settings_view.rebinding != "":
		if settings_view.handle_key(event):
			get_viewport().set_input_as_handled()
			return
	if event.keycode == KEY_ESCAPE and popup_open():
		close_popup()
		get_viewport().set_input_as_handled()
		return
	var typing := get_viewport().gui_get_focus_owner() is LineEdit
	if not typing and not popup_open() and (event.keycode == KEY_Q or event.keycode == KEY_E):
		var i := TABS.find(active_tab)
		i = posmod(i + (1 if event.keycode == KEY_E else -1), TABS.size())
		_select_tab(TABS[i])
		get_viewport().set_input_as_handled()

# --- doing things to the player ---------------------------------------------------------------------------------------------------------

# Pressing the button under an item (or double-clicking its card) for the unit being dressed.
func apply_entry_action(member, entry: Dictionary) -> void:
	var ok := InvData.apply_action(_player, member, entry)
	_play_sfx("purchase" if ok else "error")
	_refresh()

func apply_talisman_action(member, entry: Dictionary) -> void:
	var ok := InvData.talisman_apply(_player, member, entry)
	_play_sfx("purchase" if ok else "error")
	_refresh()

func _on_weapon_cell_pressed(variant: Dictionary) -> void:
	if variant.get("id", "") == _player.current_weapon_base.get("id", ""):
		return
	# Same rule as the shop: a weapon needing more Might/Intimidation than you have cannot be wielded.
	if not InvData.lacking(_player, variant).is_empty():
		_play_sfx("error")
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
	_player.equip_shield(shield)
	_play_sfx("purchase")
	_refresh()

# Wearing an armour (it is owned, so this costs nothing).
func _on_armor_picked(armor: Dictionary) -> void:
	_player.try_buy_armor(armor)
	_refresh()

func _on_potion_cell_pressed(potion_id: String) -> void:
	var result: Dictionary = _player.use_specific_potion(potion_id)
	if result.is_empty():
		return
	_play_sfx("heal")
	_refresh()

func _on_talisman_cell_pressed(talisman_id: String) -> void:
	var ok := false
	if _player.equipped_talismans.has(talisman_id):
		ok = _player.unequip_talisman(talisman_id)
	else:
		ok = _player.equip_talisman(talisman_id)
	_play_sfx("purchase" if ok else "error")
	_refresh()

func _on_member_weapon_picked(member, weapon_id: String) -> void:
	var ok := true
	if weapon_id == "":
		_player.unequip_ally_weapon(member)
	else:
		ok = _player.equip_ally_weapon(member, weapon_id)
	_play_sfx("purchase" if ok else "error")
	_refresh()

func _on_member_armor_picked(member, armor_id: String) -> void:
	var ok := true
	if armor_id == "":
		_player.unequip_ally_armor(member)
	else:
		ok = _player.equip_ally_armor(member, armor_id)
	_play_sfx("purchase" if ok else "error")
	_refresh()

func _on_member_shield_picked(member, shield_id: String) -> void:
	var ok := true
	if shield_id == "":
		_player.unequip_ally_shield(member)
	else:
		ok = _player.equip_ally_shield(member, shield_id)
	_play_sfx("purchase" if ok else "error")
	_refresh()

# A bonus pick spent on one of the member's stats.
func _on_member_pick_spent(member, stat: String) -> void:
	var ok: bool = member.spend_pick(stat)
	_play_sfx("purchase" if ok else "error")
	_refresh()

# Puts a special ("" = empty) into one of the member's loadout slots.
func _on_member_special_slot(member, slot: int, special_id: String) -> void:
	var pool_ids: Array = get_parent().member_special_pool(member).map(func(e): return str(e.special.get("id", "")))
	member.set_loadout_slot(slot, special_id, pool_ids)
	_play_sfx("purchase")
	_refresh()

func _on_member_loadout_reset(member) -> void:
	member.reset_loadout()
	_play_sfx("purchase")
	_refresh()

# Why a member cannot be sent away right now ("" = they can): Friends in High Places is what allows it, and not in the middle of a fight.
func dismiss_block_reason() -> String:
	if _player == null or not _player.can_dismiss():
		return "Friends in High Places (the Church) lets you send members away for a while."
	var parent := get_parent()
	if parent != null and bool(parent.get("in_battle")):
		return "Not in the middle of a battle."
	return ""

# Sends a member to the bench: they keep their level, picks and gear, and can be called back from the Party tab.
func _on_member_dismissed(member) -> void:
	var ok: bool = member != null and dismiss_block_reason() == "" and _player.send_to_bench(member.id)
	if ok and party_selected_id == member.id:
		party_selected_id = PartyScreen.HERO_ID
	_play_sfx("menu_move" if ok else "error")
	_refresh()

# Brings a benched member back into the party, if there is a place for them.
func _on_member_called_back(member) -> void:
	var ok: bool = member != null and _player.call_back(member.id)
	if ok:
		party_selected_id = member.id
	_play_sfx("purchase" if ok else "error")
	_refresh()

# The Debug menu's shortcut: a brand-new member of any kind, straight into the party (a full party still refuses). Only while the
# Debug menu (F1) is switched on in Settings; it is how the six members without a recruiting side-quest yet get into a real run.
func debug_quick_add_allowed() -> bool:
	var parent := get_parent()
	return parent != null and parent.get("settings") != null and bool(parent.settings.debug_menu_enabled)

func _on_member_quick_added(kind: String) -> void:
	var member = null
	if debug_quick_add_allowed() and _player.can_recruit(kind):
		member = _player.recruit(kind)
	if member != null:
		party_selected_id = member.id
	_play_sfx("purchase" if member != null else "error")
	_refresh()

func _on_member_talisman_added(member, talisman_id: String) -> void:
	if talisman_id == "":
		return
	var ok: bool = _player.equip_ally_talisman(member, talisman_id)
	_play_sfx("purchase" if ok else "error")
	_refresh()

func _on_member_talisman_removed(member, talisman_id: String) -> void:
	var ok: bool = _player.unequip_ally_talisman(member, talisman_id)
	_play_sfx("purchase" if ok else "error")
	_refresh()

func _play_sfx(sfx_name: String) -> void:
	var parent := get_parent()
	if parent != null and parent.has_method("play_sfx"):
		parent.play_sfx(sfx_name)
