extends SceneTree

# The Inventory screen: tabbed (Weapons/Items/Party/Map/Settings), grid-
# based, and interactive for Weapons/Shields/Potions -- see InventoryPanel.gd
# for why Armor stays a single non-clickable card (no ownership model to
# browse) while Weapons/Shields are real collections.

func _collect_labels(node: Node) -> String:
	var text := ""
	if node is Label:
		text += node.text + "\n"
	for child in node.get_children():
		text += _collect_labels(child)
	return text

func _collect_buttons(node: Node) -> Array:
	var found := []
	if node is Button:
		found.append(node)
	for child in node.get_children():
		found.append_array(_collect_buttons(child))
	return found

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var player = main.player
	var weapons_script = load("res://scripts/Weapons.gd")
	var shields_script = load("res://scripts/Shields.gd")
	var armor_script = load("res://scripts/Armor.gd")

	player.owned_weapons["spear_masterwork_steel"] = true
	player.owned_shields["shield_heavy"] = true
	player.equipped_shield = shields_script.SHIELDS["shield_heavy"]
	player.equipped_armor = armor_script.TIERS[2]
	player.add_potion("potion_health")
	player.add_potion("potion_health")
	player.add_potion("potion_attack")
	player.owned_arrows["flame"] = 3
	player.party_wolf = {"name": "Traitor Wolf", "dmg_mult": 0.6}
	player.party_members.append({"name": "Blade Ally", "dmg_mult": 0.75})

	var panel = main.inventory_panel
	var was_paused_initially: bool = main.get_tree().paused
	panel.open(player)
	print("opening pauses the tree and defaults to the Weapons tab: paused=%s (expected true), tab=%s (expected Weapons)" % [
		main.get_tree().paused, panel.active_tab
	])

	# --- Weapons tab: owned weapons are reconstructed and shown; Club (the
	# equipped default) is styled as equipped; the owned Spear is a separate,
	# clickable cell. ---
	var weapons_text := _collect_labels(panel.tab_containers.Weapons)
	print("both owned weapons show up: club=%s spear=%s (expected true, true)" % [
		weapons_text.contains("Club"), weapons_text.contains("Masterwork") and weapons_text.contains("Spear")
	])
	print("the equipped armor's info card shows its name and damage reduction: %s (expected true)" % [
		weapons_text.contains(armor_script.TIERS[2].name) and weapons_text.contains("-%d%%" % int(armor_script.TIERS[2].damage_reduction * 100))
	])
	print("the owned shield shows up with its block chance: %s (expected true)" % [
		weapons_text.contains("Heavy Shield") and weapons_text.contains("%d%% block" % int(shields_script.SHIELDS.shield_heavy.block_chance * 100))
	])

	# Click the Spear cell to equip it.
	var weapon_buttons: Array = _collect_buttons(panel.tab_containers.Weapons)
	var spear_button: Button = null
	for b in weapon_buttons:
		if b.tooltip_text == weapons_script.get_owned_variant("spear_masterwork_steel").description:
			spear_button = b
	spear_button.pressed.emit()
	print("clicking an owned weapon equips it: current_weapon=%s (expected spear_masterwork_steel)" % [player.current_weapon_base.id])

	# --- Items tab: potions grouped with counts, clickable; arrows shown
	# read-only. ---
	panel._select_tab("Items")
	var items_text := _collect_labels(panel.tab_containers.Items)
	print("potions grouped with counts and descriptions: health_x2=%s attack_x1=%s (expected true, true)" % [
		items_text.contains("Health Potion x2"), items_text.contains("Attack Potion x1")
	])
	print("arrow count shown: %s (expected true)" % [items_text.contains("Flame Arrow x3")])

	var health_before: int = player.health
	player.health = 1
	var potions_script = load("res://scripts/Potions.gd")
	var potion_buttons: Array = _collect_buttons(panel.tab_containers.Items)
	var health_potion_button: Button = null
	for b in potion_buttons:
		if b.tooltip_text == potions_script.get_tier("potion_health").description:
			health_potion_button = b
	health_potion_button.pressed.emit()
	print("clicking a potion drinks exactly ONE of that type (not the whole stack) and heals: health=%d (expected > 1), potions_left=%d (expected 2, one Health + the Attack potion)" % [
		player.health, player.potion_queue.size()
	])
	player.health = health_before

	# --- Party tab: shows the recruited roster. ---
	panel._select_tab("Party")
	var party_text := _collect_labels(panel.tab_containers.Party)
	print("party roster shows the wolf and the recruited ally: %s (expected true)" % [
		party_text.contains("Traitor Wolf") and party_text.contains("Blade Ally")
	])

	# --- Map tab: the schematic draws without erroring (see _on_map_draw). ---
	# (_on_map_draw's own discovered_locations/reveal_all_locations gating for
	# Pathfinder's Compass is covered directly in test_talismans.gd -- Godot
	# only allows draw_* calls inside a real draw callback, so it can't be
	# invoked standalone here the way other methods on this panel are.)
	panel._select_tab("Map")
	print("the map canvas exists and is sized: %s (expected true)" % [panel.map_canvas != null and panel.map_canvas.custom_minimum_size.x > 0])

	# --- Settings tab: a passthrough, not a real tab -- opens the pause menu
	# + settings screen underneath instead of leaving the game paused with
	# nothing visible once Settings' own Back button is used. ---
	panel._on_tab_pressed("Settings")
	print("Settings hands off to the pause menu + settings screen, staying paused: inventory_visible=%s (expected false), menu_open=%s (expected true), settings_open=%s (expected true), paused=%s (expected true)" % [
		panel.visible, main.menu_open, main.settings_open, main.get_tree().paused
	])
	main._on_settings_back_pressed()
	main._close_pause_menu()
	print("backing all the way out leaves the game fully unpaused: paused=%s (expected false)" % [main.get_tree().paused])

	# --- No shield equipped still renders cleanly (Armor always has one). ---
	player.equipped_shield = {}
	player.owned_shields.clear()
	panel.open(player)
	var no_shield_text := _collect_labels(panel.tab_containers.Weapons)
	print("no shields owned shows a plain message, no crash: %s (expected true)" % [no_shield_text.contains("None owned.")])
	panel.close()
	print("closing restores the prior unpaused state: %s (expected %s)" % [main.get_tree().paused, was_paused_initially])

	main.queue_free()
	await process_frame
	quit()
