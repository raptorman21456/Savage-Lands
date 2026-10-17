extends SceneTree

# The Inventory window: five tabs (Gear / Items / Party / Map / Settings), a grid of cards with a detail card for Gear and Items, popups for
# the pickers -- see InventoryPanel.gd, InvGearView.gd and InvData.gd. What a press does comes from InvData; this checks it through the
# panel the way the game drives it.

func _collect_labels(node: Node) -> String:
	var text := ""
	if node is Label:
		text += node.text + "\n"
	elif node is PixelButton:
		text += node.text + "\n"
	for child in node.get_children():
		text += _collect_labels(child)
	return text

func _find_button(node: Node, wanted: String):
	if node is PixelButton and node.text == wanted:
		return node
	for child in node.get_children():
		var found = _find_button(child, wanted)
		if found != null:
			return found
	return null

func _entry(entries: Array, id: String) -> Dictionary:
	for e in entries:
		if str(e.id) == id:
			return e
	return {}

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result is a real change, not luck.
	seed(20260926)
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var player = main.player
	var shields_script = load("res://scripts/Shields.gd")
	var armor_script = load("res://scripts/Armor.gd")

	player.owned_weapons["spear_masterwork_steel"] = true
	# Masterwork needs 8 Might; the Inventory enforces that on equip, like the shop.
	player.stat_might = 8
	player.owned_shields["shield_heavy"] = true
	player.equipped_shield = shields_script.SHIELDS["shield_heavy"]
	player.equipped_armor = armor_script.TIERS[2]
	player.add_potion("potion_health")
	player.add_potion("potion_health")
	player.add_potion("potion_attack")
	player.owned_arrows["flame"] = 3
	player.recruit("wolf")
	player.party_members.append({"name": "Knight", "dmg_mult": 0.75})

	var panel = main.inventory_panel
	var was_paused_initially: bool = main.get_tree().paused
	panel.open(player)
	print("opening pauses the tree and defaults to the Gear tab: paused=%s (expected true), tab=%s (expected Gear)" % [
		main.get_tree().paused, panel.active_tab
	])
	print("the five tabs: %s (expected Gear, Items, Party, Map, Settings)" % [", ".join(panel.TABS)])
	print("talismans have no tab of their own: %s (expected false)" % [panel.TABS.has("Talismans")])

	# --- Gear: weapons ---
	var weapon_entries: Array = InvData.gear_entries(player, "Weapons")
	var spear: Dictionary = _entry(weapon_entries, "spear_masterwork_steel")
	var club: Dictionary = _entry(weapon_entries, "club")
	print("both owned weapons are listed: club=%s spear=%s (expected true, true)" % [not club.is_empty(), not spear.is_empty()])
	print("a weapon's name is just its type, never its tier or material: '%s' (expected Spear), sub='%s' (expected Steel · Masterwork)" % [spear.name, spear.sub])
	print("the quality drives the glow, not the title: quality=%s (expected Masterwork), rays=%s (expected true)" % [spear.quality, PixelRays.has_rays(spear.quality)])
	print("the equipped Club is marked as yours: holders=%s (expected [\"You\"])" % [str(club.holders)])
	var gear_text: String = _collect_labels(panel.gear_view)
	print("the grid shows a card per weapon: cards=%d (expected %d), Spear on show=%s (expected true)" % [panel.gear_view.cards.size(), weapon_entries.size(), gear_text.contains("Spear")])
	print("no tier word in any card title: %s (expected false)" % [panel.gear_view.cards.any(func(c): return str(c.info.name).contains("Masterwork") or str(c.info.name).contains("Worn"))])

	# Pick the spear: the detail card shows what equipping does to you; pressing its button equips it.
	panel.gear_view.state["sel"] = {"Weapons": "spear_masterwork_steel"}
	panel._refresh()
	var detail_text: String = _collect_labels(panel.gear_view)
	print("the detail card names it and offers Equip: name=%s (expected true), equip=%s (expected true)" % [detail_text.contains("Spear"), _find_button(panel.gear_view, "Equip") != null])
	var equip_button = _find_button(panel.gear_view, "Equip")
	equip_button.pressed.emit()
	print("pressing Equip wields it: current_weapon=%s (expected spear_masterwork_steel)" % [player.current_weapon_base.id])
	print("...and the detail card now offers Take off: %s (expected true)" % [_find_button(panel.gear_view, "Take off") != null])
	_find_button(panel.gear_view, "Take off").pressed.emit()
	print("Take off puts the Club back: current_weapon=%s (expected club)" % [player.current_weapon_base.id])
	panel.gear_view._on_card_double(_entry(InvData.gear_entries(player, "Weapons"), "spear_masterwork_steel"))
	print("double-clicking a card equips it too: current_weapon=%s (expected spear_masterwork_steel)" % [player.current_weapon_base.id])

	# A weapon you cannot wield (not enough Might): the button says so and does nothing.
	player.owned_weapons["hammer_legendary_gold"] = true
	var hammer: Dictionary = _entry(InvData.gear_entries(player, "Weapons"), "hammer_legendary_gold")
	if not hammer.is_empty():
		var hammer_act: Dictionary = InvData.action_for(player, null, hammer)
		print("a weapon you lack the stats for can't be equipped: enabled=%s (expected false), reason='%s'" % [hammer_act.enabled, hammer_act.reason])

	# --- Gear: armour, shields ---
	var armor_entries: Array = InvData.gear_entries(player, "Armour")
	var worn_armor: Dictionary = _entry(armor_entries, str(armor_script.TIERS[2].id))
	print("the worn armour is listed with you holding it: %s (expected true)" % [not worn_armor.is_empty() and worn_armor.holders.has("You")])
	var shield_entries: Array = InvData.gear_entries(player, "Shields")
	var heavy: Dictionary = _entry(shield_entries, "shield_heavy")
	print("the owned shield is listed with its block chance: %s (expected %d%%)" % [heavy.number, int(shields_script.SHIELDS.shield_heavy.block_chance * 100)])
	panel.gear_view._on_category("Shields")
	print("the Shields sub-tab shows a card per shield: cards=%d (expected %d)" % [panel.gear_view.cards.size(), shield_entries.size()])

	# --- Items: potions grouped with counts; clicking drinks exactly one ---
	panel._select_tab("Items")
	var items_text := _collect_labels(panel.items_view)
	print("potions grouped with counts: health_x2=%s attack_x1=%s (expected true, true)" % [items_text.contains("x2"), items_text.contains("x1")])
	var potion_entries: Array = InvData.item_entries(player, "Potions")
	print("two kinds of potion: %d (expected 2), the Health stack: %s (expected x2)" % [potion_entries.size(), _entry(potion_entries, "potion_health").get("number", "")])
	panel.items_view._on_category("Arrows")
	print("arrow count shown: %s (expected true)" % [_collect_labels(panel.items_view).contains("x3")])
	panel.items_view._on_category("Potions")
	var health_before: int = player.health
	player.health = 1
	panel.items_view._on_card(_entry(InvData.item_entries(player, "Potions"), "potion_health"))
	print("clicking a potion drinks exactly ONE of that type and heals: health=%d (expected > 1), potions_left=%d (expected 2, one Health + the Attack potion)" % [
		player.health, player.potion_queue.size()
	])
	player.health = health_before

	# --- Party: you first, then the recruits; the older flat companions get one dim line ---
	panel._select_tab("Party")
	var party_text := _collect_labels(panel.party_screen)
	print("the party page lists you and the wolf: %s (expected true)" % [party_text.contains("You") and party_text.contains("Fickle Wolf")])
	print("the older flat companion is mentioned: %s (expected true)" % [party_text.contains("Knight") and party_text.contains("75%")])
	print("you are the sheet shown first: %s (expected true)" % [panel.party_screen.selected_id == PartyScreen.HERO_ID])
	print("it has the hero's five pages: %s (expected true)" % [["Equipment", "Specials", "Stats", "Defense", "Run"].all(func(p): return _find_button(panel.party_screen, p) != null)])

	# --- Popups: a picker for a slot, closed with Esc / the close button ---
	panel.open_gear_popup(null, "Armour")
	print("pressing the Armour tile opens its picker: open=%s (expected true), kind=%s (expected gear)" % [panel.popup_open(), panel.popup_kind])
	panel.close_popup()
	panel.open_talisman_popup(null)
	print("the Talismans line opens the talisman popup: open=%s (expected true), kind=%s (expected talisman)" % [panel.popup_open(), panel.popup_kind])
	panel.close_popup()
	print("closing it leaves the window: open=%s (expected false), visible=%s (expected true)" % [panel.popup_open(), panel.visible])

	# --- Map: the real map draws without erroring, zooms and clamps ---
	panel._select_tab("Map")
	print("the map view exists and is sized: %s (expected true)" % [panel.map_view != null and panel.map_view.size.x > 0])
	panel.map_view._zoom_by(0.4)
	var zoomed: float = panel.map_view.zoom
	panel.map_view._zoom_by(-9.0)
	print("zoom steps up and clamps at 1x: %.1f (expected 1.4), then %.1f (expected 1.0)" % [zoomed, panel.map_view.zoom])

	# --- Settings: a real tab now (it used to hand over to the pause menu) ---
	panel._select_tab("Settings")
	print("Settings is a page of the inventory, game stays paused and no pause menu opens: tab=%s (expected Settings), menu_open=%s (expected false), settings_open=%s (expected false), paused=%s (expected true)" % [
		panel.active_tab, main.menu_open, main.settings_open, main.get_tree().paused
	])
	var settings = root.get_node_or_null("Settings")
	if settings != null and panel.settings_view != null:
		panel.settings_view._on_page("Gameplay")
		var before: bool = settings.screen_shake_enabled
		var toggle = _find_button(panel.settings_view, "On" if before else "Off")
		toggle.pressed.emit()
		print("a Gameplay toggle flips the real setting: %s -> %s (expected flipped)" % [before, settings.screen_shake_enabled])
		_find_button(panel.settings_view, "On" if settings.screen_shake_enabled else "Off").pressed.emit()
		print("...and flips back: %s (expected %s)" % [settings.screen_shake_enabled, before])
		panel.settings_view._on_page("Controls")
		print("Controls lists the rebindable actions: %d buttons (expected %d)" % [panel.settings_view._rebind_buttons.size(), settings.ACTION_ORDER.size()])

	# --- Q / E switch tabs ---
	panel._select_tab("Gear")
	var ev := InputEventKey.new()
	ev.keycode = KEY_E
	ev.pressed = true
	panel._input(ev)
	print("E moves to the next tab: %s (expected Items)" % [panel.active_tab])
	ev = InputEventKey.new()
	ev.keycode = KEY_Q
	ev.pressed = true
	panel._input(ev)
	print("Q moves back: %s (expected Gear)" % [panel.active_tab])

	# --- No shield equipped still renders cleanly ---
	panel.close()
	player.equipped_shield = {}
	player.owned_shields.clear()
	panel.open(player)
	panel.gear_view._on_category("Shields")
	print("no shield owned still builds the Shields tab: cards=%d (expected at least the free one), no crash" % [panel.gear_view.cards.size()])
	panel.close()
	print("closing restores the prior unpaused state: %s (expected %s)" % [main.get_tree().paused, was_paused_initially])

	main.queue_free()
	await process_frame
	quit()
