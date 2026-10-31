extends SceneTree

# Not a test: takes a screenshot of every page and popup of the new inventory into ui_screenshots/inventory/ -- a well-stocked player (a
# weapon of every quality, a Mythic, armour, shields, clothes, potions, arrows, talismans, a full party), for checking the look. Needs a
# real window (it skips itself headless). Named test_* so SaveData uses scratch saves and never touches your real ones.
#
#   Godot --path . --resolution 1152x648 --script res://tools/test_inventory_shots.gd

var out_dir := ""
var count := 0

func _shot(label: String, frames: int = 6) -> void:
	for i in frames:
		await process_frame
	count += 1
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s%02d_%s.png" % [out_dir, count, label])
	print("shot %02d %s" % [count, label])

func _init() -> void:
	if DisplayServer.get_name() == "headless":
		print("test_inventory_shots: needs a window, skipped (run it without --headless)")
		quit()
		return
	seed(20261017)
	out_dir = ProjectSettings.globalize_path("res://ui_screenshots/inventory/")
	DirAccess.make_dir_recursive_absolute(out_dir)
	for f in DirAccess.get_files_at(out_dir):
		if f.ends_with(".png"):
			DirAccess.remove_absolute(out_dir + f)
	load("res://scripts/SaveData.gd").mark_tutorial_completed()
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)
	var weapons = load("res://scripts/Weapons.gd")
	var armor = load("res://scripts/Armor.gd")
	var shields = load("res://scripts/Shields.gd")
	player.level = 13
	player.stat_might = 20
	player.stat_intimidation = 20
	player.meta_resilience_unlocked = true
	player.meta_reflexes_unlocked = true
	player.meta_dexterity_unlocked = true
	player.meta_fortitude_unlocked = true
	for id in ["spear_masterwork_obsidian", "dagger_fine_silver", "greatsword_worn_steel", "hand_picks_broken_bone", "knuckle_gloves_masterwork_gold", "battle_axe_fine_steel", "hammer_legendary_gold", "spear_mythic", "staff_worn_wood", "bow_fine_wood"]:
		player.owned_weapons[id] = true
	player.weapon_enchantments["dagger_fine_silver"] = "ember"
	player.learned_specials["spear_piercing_thrust"] = true
	for id in ["armor_gambeson", "armor_fortress", "armor_spellward", "armor_bloodrage", "armor_windrunner"]:
		player.owned_armor[id] = true
	player.try_buy_armor(armor.find("armor_gambeson"))
	for id in ["shield_heavy", "shield_bulwark", "shield_brawler"]:
		player.owned_shields[id] = true
	player.equip_shield(shields.SHIELDS["shield_bulwark"])
	for id in ["cloth_cap", "cloth_hood", "cloth_boots", "cloth_sandals", "cloth_cloak", "cloth_tunic"]:
		player.owned_clothing[id] = true
	player.equip_clothing("cloth_hood")
	player.equip_clothing("cloth_boots")
	for id in ["potion_health", "potion_health", "potion_attack", "food_jerky", "food_jerky", "food_jerky"]:
		player.add_potion(id)
	player.owned_arrows["flame"] = 6
	player.owned_arrows["freeze"] = 3
	player.owned_arrows["bomb"] = 4
	for id in ["ember_charm", "moss_charm", "guardian_knot", "vampires_pact", "gilded_scarab", "wildfire_core", "merchants_coin", "healers_knot", "swift_feather", "berserkers_knot", "iron_will_band", "bloodstone"]:
		player.owned_talismans[id] = true
	player.equip_talisman("moss_charm")
	player.equip_talisman("scholars_quill") if player.owned_talismans.has("scholars_quill") else null
	player.max_party_slots = 20
	for kind in ["knight", "necromancer", "druid", "rogue", "guardian", "wolf"]:
		player.recruit(kind)
	for m in player.party:
		if m.kind == "knight":
			player.equip_ally_weapon(m, "greatsword_worn_steel")
			player.equip_ally_armor(m, "armor_fortress")
			player.equip_ally_talisman(m, "guardian_knot")
		elif m.kind == "druid":
			player.equip_ally_weapon(m, "staff_worn_wood")
			m.picks = 2
		elif m.kind == "rogue":
			player.equip_ally_weapon(m, "dagger_fine_silver")
	player._equip_weapon(weapons.get_owned_variant("hammer_legendary_gold"))
	player.party_members.append({"name": "Warrior", "dmg_mult": 0.75})
	main.run_bosses_defeated = 2
	main.wave = 7

	var panel = main.inventory_panel
	panel.open(player)
	await _shot("gear_weapons")
	panel.view_states["gear"]["sel"] = {"Weapons": "spear_mythic"}
	panel._refresh()
	await _shot("gear_weapons_mythic")
	panel.view_states["gear"]["cat"] = "Armour"
	panel._refresh()
	await _shot("gear_armour")
	panel.view_states["gear"]["cat"] = "Clothes"
	panel._refresh()
	await _shot("gear_clothes")
	panel.view_states["gear"]["cat"] = "Shields"
	panel._refresh()
	await _shot("gear_shields")
	panel._select_tab("Items")
	await _shot("items_potions")
	panel.view_states["items"]["cat"] = "Arrows"
	panel._refresh()
	await _shot("items_arrows")
	for pg in ["Equipment", "Specials", "Stats", "Defense", "Run"]:
		panel.party_selected_id = -2
		panel.party_page = pg
		panel._select_tab("Party")
		await _shot("party_you_%s" % pg.to_lower())
	var knight = null
	var druid = null
	for m in player.party:
		if m.kind == "knight":
			knight = m
		elif m.kind == "druid":
			druid = m
	for pg in ["Equipment", "Specials", "Stats"]:
		panel.party_selected_id = knight.id
		panel.party_page = pg
		panel._select_tab("Party")
		await _shot("party_knight_%s" % pg.to_lower())
	panel.party_selected_id = druid.id
	panel.party_page = "Stats"
	panel._select_tab("Party")
	await _shot("party_druid_stats")
	panel.open_gear_popup(knight, "Weapons")
	await _shot("popup_gear_knight_weapons")
	panel.open_gear_popup(null, "Armour")
	await _shot("popup_gear_you_armour")
	panel.open_talisman_popup(null)
	await _shot("popup_talismans_you")
	panel.open_talisman_popup(knight)
	await _shot("popup_talismans_knight")
	panel.close_popup()
	panel._select_tab("Map")
	await _shot("map")
	for pg in ["Audio", "Controls", "Gameplay"]:
		panel.settings_page = pg
		panel._select_tab("Settings")
		await _shot("settings_%s" % pg.to_lower())
	panel.close()
	print("DONE: %d screenshots in %s" % [count, out_dir])
	quit()
