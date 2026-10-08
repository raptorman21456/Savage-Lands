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
	for kind in ["Button", "Label", "OptionButton"]:
		var found := []
		_find_all(node, kind, found)
		for n in found:
			if kind == "OptionButton":
				for i in n.item_count:
					out.append(n.get_item_text(i))
			else:
				out.append(n.text)
	return out

func _init() -> void:
	seed(20261006)
	var weapons = load("res://scripts/Weapons.gd")
	var main = load("res://Main.tscn").instantiate()
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
	for i in main.current_shop_offering.size():
		if main.current_shop_offering[i].get("ally_only", false):
			staff_index = i
	print("With a Druid in the party, one Staff is on offer: %s (expected true)" % [staff_index >= 0])
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
	var weapons_tab_texts: Array = _texts(panel.tab_containers.Weapons)
	print("The Staff does NOT clutter your own Weapons tab: %s (expected true)" % [not weapons_tab_texts.any(func(t): return str(t).contains("Staff"))])
	var party_texts: Array = _texts(panel.tab_containers.Party)
	print("The Party tab lists PARTY GEAR with a weapon picker that offers the Staff: %s / %s (expected true, true)" % [party_texts.has("PARTY GEAR"), party_texts.any(func(t): return str(t).begins_with("Staff") or str(t).contains(" Staff"))])
	panel._on_member_weapon_picked(druid, offer.id)
	print("Picking it equips it on her: %s (expected %s)" % [druid.weapon_id(), offer.id])
	await process_frame
	var selected_ok := false
	var option_buttons := []
	_find_all(panel.tab_containers.Party, "OptionButton", option_buttons)
	for ob in option_buttons:
		if ob.get_item_text(ob.selected).contains("Staff") and ob.item_count > 2:
			selected_ok = true
	print("...and the picker shows it selected after the rebuild: %s (expected true)" % [selected_ok])
	player.owned_talismans["moss_charm"] = true
	panel._on_member_talisman_added(druid, "moss_charm")
	print("Adding a talisman puts it on her: %s (expected [moss_charm])" % [druid.talisman_ids()])
	await process_frame
	print("...her row shows it with a remove button: %s (expected true)" % [_texts(panel.tab_containers.Party).any(func(t): return str(t).begins_with("Moss Charm"))])
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
	print("...talismans respect her 2 slots (level 4) and skip the one YOU wear: %s (expected [wolf_fang, ember_charm])" % [member.talisman_ids()])
	var unit: Dictionary = main._make_member_battle_unit(member, Vector2i(1, 4), 1.0)
	print("...and she takes the field armed: %s, mana=%d range=%d (expected Staff, a positive mana pool, 3)" % [unit.weapon.get("name", "?"), unit.max_mana, unit.attack_range])
	cfg.party[0].weapon = {"base": "", "tier": "Fine", "material": "steel"}
	cfg.party[0].talismans = []
	SandboxScript.apply_build(main, cfg)
	print("Clearing the config clears the gear: weapon='%s' talismans=%s (expected '' and [])" % [player.party[0].weapon_id(), player.party[0].talisman_ids()])

	quit()
