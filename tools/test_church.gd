extends SceneTree

# The Church (ChurchPanel.gd + AscensionView.gd): the skill tree, moved off the
# title screen into a town building. Covers the data feeding the constellation
# (every skill in exactly one wing, an icon each, a collision-free layout), the
# per-node states, buying (persisted to the slot AND applied to the run in
# progress), the tooltip, and the Worldwalker lifetime gate.

func _init() -> void:
	var save_data_script = load("res://scripts/SaveData.gd")
	var view_script = load("res://scripts/AscensionView.gd")
	# Clean slate: the slot and lifetime files are shared scratch paths.
	save_data_script.save_lifetime_data({})
	save_data_script.save_data({"essence": 0, "upgrades": {}, "best_wave": 0})

	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)
	var player = main.player

	# --- The building itself ---
	var entry: Dictionary = main.TOWN_LAYOUT.get("church", {})
	print("the church has a town layout slot and a placed door: layout=%s door=%s (expected true, true)" % [
		not entry.is_empty(), main.town_building_positions.has("church")
	])
	print("the church is a built kind with a registered panel: built=%s panel=%s (expected true, true)" % [
		main.TOWN_BUILT_KINDS.has("church"), main.town_panels.has("church")
	])
	var panel = main.town_panels["church"]

	# --- Data feeding the constellation ---
	var wing_counts := {}
	for wing in panel.WING_MEMBERS:
		for id in panel.WING_MEMBERS[wing]:
			wing_counts[id] = wing_counts.get(id, 0) + 1
	var every_skill_once: bool = wing_counts.size() == save_data_script.UPGRADE_IDS.size()
	for id in save_data_script.UPGRADE_IDS:
		if wing_counts.get(id, 0) != 1:
			every_skill_once = false
			print("  wing membership wrong for %s: %d" % [id, wing_counts.get(id, 0)])
	print("all %d skills belong to exactly one wing: %s (expected true)" % [save_data_script.UPGRADE_IDS.size(), every_skill_once])
	var all_icons := true
	for id in save_data_script.UPGRADE_IDS:
		if not ResourceLoader.exists("res://assets/%s.png" % panel.NODE_ICONS.get(id, "missing")):
			all_icons = false
			print("  no icon for %s" % id)
	print("every skill has an icon that exists: %s (expected true)" % [all_icons])
	print("the view built one node per skill: %d (expected %d)" % [panel.view.node_ids().size(), save_data_script.UPGRADE_IDS.size()])

	var pos: Dictionary = view_script.compute_layout(panel._node_defs())
	var all_placed: bool = pos.size() == save_data_script.UPGRADE_IDS.size()
	var min_gap := 99999.0
	var ids: Array = pos.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			min_gap = minf(min_gap, pos[ids[i]].distance_to(pos[ids[j]]))
	print("layout positions every skill: %s (expected true)" % [all_placed])
	print("no two nodes crowd each other (nearest pair >= 2 node radii + gap): %.1f (expected >= %.1f)" % [min_gap, view_script.NODE_RADIUS * 2.0 + 8.0])
	print("Worldwalker sits far out on its own: dist=%.0f (expected >= 1000)" % [pos["worldwalker"].length()])
	print("wing roots start apart around the hub: strength=%s coins=%s stamina=%s" % [pos["strength"].round(), pos["coins"].round(), pos["stamina"].round()])

	# --- Opening ---
	main._try_open_panel("church")
	await process_frame
	await process_frame
	print("the church door opens its panel and pauses the game: visible=%s paused=%s (expected true, true)" % [panel.visible, main.get_tree().paused])
	print("opening focuses a starting node for the keyboard without popping its tooltip: focused=%s tooltip=%s (expected true, false)" % [
		panel.view.button_for("strength").has_focus(), panel.tooltip.visible
	])
	print("a broke player sees 0 Essence: '%s' (expected '0 Essence')" % [panel.essence_label.text])
	print("root skill with no Essence is unaffordable, deeper ones locked: strength=%s agility=%s worldwalker=%s (expected unaffordable, locked, locked)" % [
		panel.state_for("strength"), panel.state_for("agility"), panel.state_for("worldwalker")
	])
	# --- Reveal: a fresh save shows only the three roots ---
	var shown: Array = panel.view.node_ids().filter(func(id): return panel.view.is_revealed(id))
	shown.sort()
	print("a fresh save shows only the three wing roots: %s (expected [coins, stamina, strength])" % [shown])
	print("...the rest are really hidden, not just dimmed: agility_visible=%s worldwalker_visible=%s strength_visible=%s (expected false, false, true)" % [
		panel.view.button_for("agility").visible, panel.view.button_for("worldwalker").visible, panel.view.button_for("strength").visible
	])

	# --- Buying: persisted, and felt by the run in progress ---
	var cost_strength: int = save_data_script.get_upgrade_cost("strength", 0)
	save_data_script.save_data({"essence": 100, "upgrades": {}, "best_wave": 0})
	panel._refresh()
	print("with Essence the root skill becomes available: %s (expected available)" % [panel.state_for("strength")])
	panel._on_node_pressed("agility")
	print("a locked skill can't be bought: agility level=%d (expected 0), essence=%d (expected 100)" % [
		panel.level_of("agility"), save_data_script.load_data().essence
	])
	panel._on_node_pressed("strength")
	var reloaded: Dictionary = save_data_script.load_data()
	print("buying spends Essence and persists to the slot: essence=%d (expected %d), strength=%d (expected 1)" % [
		reloaded.essence, 100 - cost_strength, reloaded.upgrades.get("strength", 0)
	])
	print("...the label follows: '%s' (expected '%d Essence')" % [panel.essence_label.text, 100 - cost_strength])
	print("...and it is applied to the run already in progress: meta_levelup_bonus_strength=%d (expected 1)" % [player.meta_levelup_bonus_strength])
	print("an owned skill you can afford again reads upgradable, its child is available: strength=%s agility=%s (expected upgradable, available)" % [
		panel.state_for("strength"), panel.state_for("agility")
	])
	print("multi-level skills badge their level: '%s' (expected '1')" % [panel._badge_for("strength")])
	print("owning a skill reveals the next one, but not the one after: agility=%s vigor=%s (expected true, false)" % [
		panel.view.is_revealed("agility"), panel.view.is_revealed("vigor")
	])
	print("...and the newly revealed node is really on screen: %s (expected true)" % [panel.view.button_for("agility").visible])
	save_data_script.save_data({"essence": 5, "upgrades": {"strength": 1}, "best_wave": 0})
	panel._refresh()
	print("owned but the next level is out of reach reads owned: %s (expected owned)" % [panel.state_for("strength")])

	# --- One-shot grants land exactly once, immediately ---
	save_data_script.save_data({"essence": 5000, "upgrades": {}, "best_wave": 0})
	panel._refresh()
	var coins_before: int = player.coins
	panel._on_node_pressed("coins")
	print("Nest Egg hands over its coins right away: +%d (expected +%d)" % [player.coins - coins_before, save_data_script.UPGRADES.coins.stat_bonus])
	var stamina_before: int = player.max_stamina
	panel._on_node_pressed("stamina")
	print("Endurance raises max stamina right away: +%d (expected +%d)" % [player.max_stamina - stamina_before, save_data_script.UPGRADES.stamina.stat_bonus])
	panel._on_node_pressed("resilience_unlock")
	var potions_before: int = player.potion_queue.size()
	panel._on_node_pressed("potions")
	print("Provisions adds a healing item right away: +%d (expected +1)" % [player.potion_queue.size() - potions_before])
	print("Resilience unlocks its level-up stat right away: %s (expected true)" % [player.meta_resilience_unlocked])
	print("a single-purchase skill reads mastered and shows no badge: %s '%s' (expected mastered, '')" % [panel.state_for("resilience_unlock"), panel._badge_for("resilience_unlock")])
	var essence_before: int = save_data_script.load_data().essence
	panel._on_node_pressed("resilience_unlock")
	print("...and can't be bought twice: essence_unchanged=%s (expected true)" % [save_data_script.load_data().essence == essence_before])

	# --- Allies from the capstones ---
	save_data_script.save_data({"essence": 5000, "upgrades": {"strength": 1, "agility": 1, "vigor": 1, "berserker_edge": 3, "reflexes_unlock": 1, "adrenaline": 2}, "best_wave": 0})
	panel._refresh()
	var ally_before: int = player.party_members.filter(func(m): return m.get("name", "") == "Blade Ally").size()
	panel._on_node_pressed("battle_hardened")
	var ally_after: int = player.party_members.filter(func(m): return m.get("name", "") == "Blade Ally").size()
	print("the Blade Ally joins at once, once: before=%d after=%d (expected 0, 1)" % [ally_before, ally_after])
	panel._on_node_pressed("pack_leader")
	print("Pack Leader opens a party slot right away: max_party_slots=%d (expected 3)" % [player.max_party_slots])
	main.wolf_waves_remaining = 0
	player.party_wolf = {}
	panel._on_node_pressed("beastmaster")
	print("Beastmaster puts a wolf in the pack with its stay timer running: wolf=%s waves=%d (expected true, %d)" % [
		not player.party_wolf.is_empty(), main.wolf_waves_remaining, main.WOLF_BASE_STAY_WAVES + player.meta_wolf_bonus_waves
	])

	# --- Worldwalker: gated by the lifetime flag ---
	save_data_script.save_data({"essence": 5000, "upgrades": {}, "best_wave": 0})
	panel._refresh()
	panel._on_node_pressed("worldwalker")
	print("Worldwalker is locked until the game has been beaten: state=%s level=%d (expected locked, 0)" % [panel.state_for("worldwalker"), panel.level_of("worldwalker")])
	print("...and stays hidden rather than teasing: revealed=%s visible=%s (expected false, false)" % [
		panel.view.is_revealed("worldwalker"), panel.view.button_for("worldwalker").visible
	])
	save_data_script.mark_game_completed()
	panel._refresh()
	print("...it appears and opens up once it has: revealed=%s state=%s (expected true, available)" % [
		panel.view.is_revealed("worldwalker"), panel.state_for("worldwalker")
	])
	panel._on_node_pressed("worldwalker")
	print("...then buys and applies: level=%d (expected 1), meta_worldwalker=%s (expected true)" % [panel.level_of("worldwalker"), player.meta_worldwalker])

	# --- Tooltip ---
	save_data_script.save_data({"essence": 0, "upgrades": {}, "best_wave": 0})
	panel._refresh()
	panel._on_node_hover_changed("strength")
	print("hovering a node shows its name, level and description: shown=%s name='%s' (expected true, '%s')" % [
		panel.tooltip.visible, panel.tooltip_name_label.text, save_data_script.UPGRADES.strength.name
	])
	print("...with the cost in red when you can't afford it: '%s'" % [panel.tooltip_cost_label.text])
	# A convergence node shows as soon as ONE of its parents is owned, and its
	# tooltip names the parent still missing.
	save_data_script.save_data({"essence": 0, "upgrades": {"battle_hardened": 1}, "best_wave": 0})
	panel._refresh()
	print("a node with two parents appears once one is owned: warband=%s (expected true); one whose parents are both unowned stays hidden: field_surgeon=%s (expected false)" % [
		panel.view.is_revealed("warband"), panel.view.is_revealed("field_surgeon")
	])
	panel._on_node_hover_changed("warband")
	print("a revealed-but-locked node lists its missing prerequisite: '%s' (expected 'Requires: %s')" % [
		panel.tooltip_cost_label.text, save_data_script.UPGRADES.golden_touch.name
	])
	panel._on_node_hover_changed("strength")
	# The tooltip settles its size over a frame or two, like it does in play.
	await process_frame
	await process_frame
	var rect: Rect2 = panel.view.node_rect_in_view("strength")
	print("the tooltip stays inside the view: %s (expected true)" % [Rect2(Vector2.ZERO, panel.view.size).encloses(Rect2(panel.tooltip.position, panel.tooltip.size))])
	print("...and never covers the node it describes: %s (expected false)" % [Rect2(panel.tooltip.position, panel.tooltip.size).intersects(rect)])
	panel._on_node_hover_changed("")
	print("moving off a node hides the tooltip: %s (expected false)" % [panel.tooltip.visible])

	# --- Closing ---
	panel.close()
	print("closing the church unpauses the game: visible=%s paused=%s (expected false, false)" % [panel.visible, main.get_tree().paused])

	# Reset the shared scratch files.
	save_data_script.save_lifetime_data({})
	save_data_script.save_data({"essence": 0, "upgrades": {}, "best_wave": 0})
	quit()
