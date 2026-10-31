extends SceneTree

# The places party gear is reached from: the shop (a Staff is bought FOR a caster), the Inventory's
# Party tab (weapon + talisman pickers), and the Sandbox (any weapon / talismans on any member).

const SandboxScript := preload("res://scripts/Sandbox.gd")

func _find_all(node: Node, type_name: String, out: Array) -> void:
	for c in node.get_children():
		if c.get_class() == type_name:
			out.append(c)
		_find_all(c, type_name, out)

func _texts(node: Node) -> Array:
	var out := []
	_gather_texts(node, out)
	return out

func _gather_texts(node: Node, out: Array) -> void:
	if node is OptionButton:
		for i in node.item_count:
			out.append(node.get_item_text(i))
	elif node is Label or node is Button or node is PixelButton:
		out.append(node.text)
	for c in node.get_children():
		_gather_texts(c, out)

func _init() -> void:
	seed(20261006)
	var weapons = load("res://scripts/Weapons.gd")
	var main = load("res://Main.tscn").instantiate()
	main.regional_world = false  # this test drives the old wave-ladder world
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	player.party.clear()
	player.max_party_slots = 4
	player.coins = 1000

	# =========================================================
	# The shop
	# =========================================================
	main._roll_shop_offering()
	var staffs_without_caster: int = main.current_shop_offering.filter(func(i): return i.get("ally_only", false)).size()
	print("With no caster in the party the shop never offers a Staff: %d (expected 0)" % [staffs_without_caster])
	var druid = player.recruit("druid")
	main._roll_shop_offering()
	var staff_index := -1
	var wand_offers := 0
	for i in main.current_shop_offering.size():
		if main.current_shop_offering[i].get("ally_only", false):
			if weapons.get_base_type(main.current_shop_offering[i]).get("id", "") == "wand":
				wand_offers += 1
			else:
				staff_index = i
	print("With a Druid in the party, one Staff is on offer: %s (expected true), and one Wand beside it: %d (expected 1)" % [staff_index >= 0, wand_offers])
	var offer: Dictionary = main.current_shop_offering[staff_index]
	print("...it is a real Staff variant: base=%s ally_only=%s (expected staff, true)" % [weapons.get_base_type(offer).get("id", ""), weapons.is_ally_only(offer)])
	var coins_before: int = player.coins
	var current_before: String = player.current_weapon_base.get("id", "")
	main._on_shop_buy_pressed(staff_index)
	print("Buying it goes into your collection and is NOT equipped: owned=%s coins_spent=%d (expected true, %d), still wielding %s (expected %s)" % [player.owned_weapons.has(offer.id), coins_before - player.coins, player.get_weapon_price(offer), player.current_weapon_base.get("id", ""), current_before])

	# =========================================================
	# The Inventory's Party tab
	# =========================================================
	var panel = main.inventory_panel
	panel.open(player)
	await process_frame
	var own_card_names: Array = panel.gear_view.cards.map(func(c): return str(c.info.name))
	print("The Staff does NOT clutter your own Weapons tab: %s (expected true)" % [not own_card_names.has("Staff") and not InvData.gear_entries(player, "Weapons").any(func(e): return str(e.name) == "Staff")])
	panel.party_selected_id = druid.id
	panel.party_page = "Equipment"
	panel._select_tab("Party")
	await process_frame
	var party_texts: Array = _texts(panel.tab_containers.Party)
	print("The Party tab's Equipment page has a weapon tile and a Talismans line: %s / %s (expected true, true)" % [party_texts.has("Weapon"), party_texts.has("Talismans")])
	panel.open_gear_popup(druid, "Weapons")
	await process_frame
	var staff_entry := {}
	for e in panel.popup_view.shown:
		if str(e.name) == "Staff":
			staff_entry = e
	print("Her weapon picker offers the Staff: %s (expected true)" % [not staff_entry.is_empty()])
	var staff_action: Dictionary = InvData.action_for(player, druid, staff_entry)
	print("...with an enabled Equip button: label=%s enabled=%s (expected Equip, true)" % [staff_action.label, staff_action.enabled])
	panel.apply_entry_action(druid, staff_entry)
	print("Pressing it equips it on her: %s (expected %s)" % [druid.weapon_id(), offer.id])
	await process_frame
	print("...and the picker shows it worn after the rebuild: %s (expected true)" % [panel.popup_view.cards.any(func(c): return c.worn and str(c.info.name) == "Staff")])
	panel.close_popup()
	player.owned_talismans["moss_charm"] = true
	panel._on_member_talisman_added(druid, "moss_charm")
	print("Adding a talisman puts it on her: %s (expected [moss_charm])" % [druid.talisman_ids()])
	panel._state("popup_talismans")["sel"] = "moss_charm"
	panel.open_talisman_popup(druid)
	await process_frame
	var popup_texts: Array = _texts(panel.popup_view)
	print("...her talisman popup shows it with a Take off button: name=%s take_off=%s (expected true, true)" % [popup_texts.has("Moss Charm"), popup_texts.has("Take off")])
	panel.close_popup()
	panel._on_member_talisman_removed(druid, "moss_charm")
	panel._on_member_weapon_picked(druid, "")
	print("Removing both leaves her empty-handed: weapon='%s' talismans=%s (expected '' and [])" % [druid.weapon_id(), druid.talisman_ids()])
	panel.close()

	# =========================================================
	# The Sandbox
	# =========================================================
	var cfg: Dictionary = SandboxScript.default_config()
	cfg.talismans = ["moss_charm"]
	cfg.ignore_slots = true
	cfg.party = [{"kind": "druid", "level": 4, "picks": {}, "weapon": {"base": "staff", "tier": "Fine", "material": "steel"}, "talismans": ["moss_charm", "wolf_fang", "ember_charm"]}]
	SandboxScript.apply_build(main, cfg)
	var member = player.party[0]
	print("A sandbox member gets the Staff on request: %s (expected staff_fine_steel), owned=%s" % [member.weapon_id(), player.owned_weapons.has("staff_fine_steel")])
	print("...your own weapon is not the Staff: %s (expected club)" % [player.current_weapon_base.get("id", "")])
	print("...talismans respect her 2 slots (any level) and skip the one YOU wear: %s (expected [wolf_fang, ember_charm])" % [member.talisman_ids()])
	var unit: Dictionary = main._make_member_battle_unit(member, Vector2i(1, 4), 1.0)
	print("...and she takes the field armed: %s, mana=%d range=%d (expected Staff, a positive mana pool, 3)" % [unit.weapon.get("name", "?"), unit.max_mana, unit.attack_range])
	cfg.party[0].weapon = {"base": "", "tier": "Fine", "material": "steel"}
	cfg.party[0].talismans = []
	SandboxScript.apply_build(main, cfg)
	print("Clearing the config clears the gear: weapon='%s' talismans=%s (expected '' and [])" % [player.party[0].weapon_id(), player.party[0].talisman_ids()])

	quit()
