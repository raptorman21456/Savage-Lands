extends SceneTree

# The Church (ChurchPanel.gd + AscensionView.gd): the skill tree, moved off the
# title screen into a town building. Covers the data feeding the constellation
# (every skill in exactly one wing, an icon each, a collision-free layout, Legacy as the hub), the
# per-node states, buying (persisted to the slot AND applied to the run in
# progress), the tooltip, and the Worldwalker lifetime gate. EVERY upgrade is on show at all times.

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
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
	print("Legacy is the hub, dead centre: %s (expected (0, 0))" % [pos["legacy"]])
	print("Worldwalker and Otherworldly Power sit far out on their own: dist=%.0f and %.0f (expected >= 1000 each)" % [pos["worldwalker"].length(), pos["otherworldly_power"].length()])
	print("wing roots start apart around the hub: strength=%s coins=%s stamina=%s release_grudge=%s" % [pos["strength"].round(), pos["coins"].round(), pos["stamina"].round(), pos["release_grudge"].round()])

	# --- Opening ---
	main._try_open_panel("church")
	await process_frame
	await process_frame
	print("the church door opens its panel and pauses the game: visible=%s paused=%s (expected true, true)" % [panel.visible, main.get_tree().paused])
	print("opening focuses the hub for the keyboard without popping its tooltip: focused=%s tooltip=%s (expected true, false)" % [
		panel.view.button_for("legacy").has_focus(), panel.tooltip.visible
	])
	print("a broke player sees 0 Essence: '%s' (expected '0 Essence')" % [panel.essence_label.text])
	print("Legacy with no Essence is unaffordable, everything behind it locked: legacy=%s strength=%s worldwalker=%s (expected unaffordable, locked, locked)" % [
		panel.state_for("legacy"), panel.state_for("strength"), panel.state_for("worldwalker")
	])
	# --- Reveal: EVERY upgrade is on show, owned or not ---
	var shown: Array = panel.view.node_ids().filter(func(id): return panel.view.is_revealed(id))
	print("a fresh save shows the whole tree: %d of %d upgrades on show (expected all)" % [shown.size(), save_data_script.UPGRADE_IDS.size()])
	print("...locked ones included, really on screen: agility_visible=%s worldwalker_visible=%s otherworldly_visible=%s (expected true, true, true)" % [
		panel.view.button_for("agility").visible, panel.view.button_for("worldwalker").visible, panel.view.button_for("otherworldly_power").visible
	])

	# --- Buying: persisted, and felt by the run in progress ---
	var cost_legacy: int = save_data_script.get_upgrade_cost("legacy", 0)
	var cost_strength: int = save_data_script.get_upgrade_cost("strength", 0)
	save_data_script.save_data({"essence": 100, "upgrades": {}, "best_wave": 0})
	panel._refresh()
	print("with Essence the hub becomes available: %s (expected available)" % [panel.state_for("legacy")])
	panel._on_node_pressed("strength")
	print("a locked skill can't be bought (Physical Training wants Legacy): strength level=%d (expected 0), essence=%d (expected 100)" % [
		panel.level_of("strength"), save_data_script.load_data().essence
	])
	panel._on_node_pressed("legacy")
	print("buying Legacy spends %d Essence and persists to the slot: essence=%d (expected %d), legacy=%d (expected 1)" % [
		cost_legacy, save_data_script.load_data().essence, 100 - cost_legacy, save_data_script.load_data().upgrades.get("legacy", 0)
	])
	print("...the label follows: '%s' (expected '%d Essence')" % [panel.essence_label.text, 100 - cost_legacy])
	panel._on_node_pressed("strength")
	var reloaded: Dictionary = save_data_script.load_data()
	print("then the wings open: strength=%d (expected 1), essence=%d (expected %d)" % [reloaded.upgrades.get("strength", 0), reloaded.essence, 100 - cost_legacy - cost_strength])
	print("...and it is applied to the run already in progress: meta_levelup_bonus_strength=%d (expected 1)" % [player.meta_levelup_bonus_strength])
	print("a single-purchase skill you own reads mastered; what asked only for Legacy is open: strength=%s agility=%s (expected mastered, available)" % [
		panel.state_for("strength"), panel.state_for("agility")
	])
	print("single-level skills show no level badge: '%s' (expected '')" % [panel._badge_for("strength")])
	save_data_script.save_data({"essence": 100, "upgrades": {"legacy": 1, "stamina": 1}, "best_wave": 0})
	panel._refresh()
	print("a multi-level skill badges its level: '%s' (expected '1'), and reads upgradable while the next level is in reach: %s (expected upgradable)" % [panel._badge_for("stamina"), panel.state_for("stamina")])
	save_data_script.save_data({"essence": 0, "upgrades": {"legacy": 1, "stamina": 1}, "best_wave": 0})
	panel._refresh()
	print("owned but the next level is out of reach reads owned: %s (expected owned)" % [panel.state_for("stamina")])

	# --- One-shot grants land exactly once, immediately ---
	save_data_script.save_data({"essence": 5000, "upgrades": {"legacy": 1}, "best_wave": 0})
	panel._refresh()
	var coins_before: int = player.coins
	panel._on_node_pressed("coins")
	print("Inheritance hands over its coins right away: +%d (expected +%d)" % [player.coins - coins_before, save_data_script.UPGRADES.coins.stat_bonus])
	var stamina_before: int = player.max_stamina
	panel._on_node_pressed("stamina")
	print("Deep Lungs raises max stamina right away: +%d (expected +%d)" % [player.max_stamina - stamina_before, save_data_script.UPGRADES.stamina.stat_bonus])
	panel._on_node_pressed("stamina")
	panel._on_node_pressed("stamina")
	panel._on_node_pressed("resilience_unlock")
	var potions_before: int = player.potion_queue.size()
	panel._on_node_pressed("potions")
	print("Preparations adds a healing item right away: +%d (expected +1)" % [player.potion_queue.size() - potions_before])
	print("Leather Skin unlocks Resilience as a level-up stat right away: %s (expected true)" % [player.meta_resilience_unlocked])
	print("a single-purchase skill reads mastered and shows no badge: %s '%s' (expected mastered, '')" % [panel.state_for("resilience_unlock"), panel._badge_for("resilience_unlock")])
	var essence_before: int = save_data_script.load_data().essence
	panel._on_node_pressed("resilience_unlock")
	print("...and can't be bought twice: essence_unchanged=%s (expected true)" % [save_data_script.load_data().essence == essence_before])

	# --- Allies from the capstones (every requirement is the node FULLY bought) ---
	save_data_script.save_data({"essence": 5000, "upgrades": {"legacy": 1, "strength": 1, "agility": 1, "vigor": 1, "berserker_edge": 5, "reflexes_unlock": 1, "adrenaline": 3}, "best_wave": 0})
	panel._refresh()
	var flag_before: bool = player.meta_battle_hardened
	panel._on_node_pressed("battle_hardened")
	var placeholders: int = player.party_members.filter(func(m): return m.get("name", "") == "Knight").size()
	print("Friends in High Places puts the Knight within reach (he is found in the ruins, nothing joins at once): flag %s -> %s (expected false -> true), placeholder knights=%d (expected 0)" % [flag_before, player.meta_battle_hardened, placeholders])
	panel._on_node_pressed("pack_leader")
	print("Leader's Instincts opens a party slot right away: max_party_slots=%d (expected 3)" % [player.max_party_slots])
	panel._on_node_pressed("pack_leader")
	print("...and a second level opens another: max_party_slots=%d (expected 4)" % [player.max_party_slots])
	player.party = []
	panel._on_node_pressed("beastmaster")
	var church_wolves: Array = player.party_wolves()
	print("Man's Best Friend puts a wolf in the pack, loyal for 25 battles: wolves=%d battles_left=%d (expected 1, %d)" % [
		church_wolves.size(), church_wolves[0].battles_left if not church_wolves.is_empty() else -1, player.MAN_BEST_FRIEND_WOLF_BATTLES
	])

	# --- Worldwalker: gated by the lifetime flag ---
	save_data_script.save_data({"essence": 5000, "upgrades": {}, "best_wave": 0})
	panel._refresh()
	panel._on_node_pressed("worldwalker")
	print("Worldwalker is locked until the game has been beaten: state=%s level=%d (expected locked, 0)" % [panel.state_for("worldwalker"), panel.level_of("worldwalker")])
	print("...and is shown (everything is) but locked: revealed=%s visible=%s (expected true, true)" % [
		panel.view.is_revealed("worldwalker"), panel.view.button_for("worldwalker").visible
	])
	save_data_script.mark_game_completed()
	panel._refresh()
	print("...it opens up once it has: revealed=%s state=%s (expected true, available)" % [
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
	print("...a locked node names what it wants first: '%s' (expected 'Requires: Legacy')" % [panel.tooltip_cost_label.text])
	# A locked node is on show too, and its tooltip names the parents still missing.
	save_data_script.save_data({"essence": 0, "upgrades": {"battle_hardened": 1}, "best_wave": 0})
	panel._refresh()
	print("a node with two parents shows even with neither owned: war_profiteer=%s, golden_touch=%s (expected true, true)" % [
		panel.view.is_revealed("war_profiteer"), panel.view.is_revealed("golden_touch")
	])
	panel._on_node_hover_changed("war_profiteer")
	print("a locked node lists its missing prerequisite: '%s' (expected 'Requires: %s')" % [
		panel.tooltip_cost_label.text, save_data_script.UPGRADES.golden_touch.name
	])
	save_data_script.save_data({"essence": 0, "upgrades": {"legacy": 1, "strength": 1, "berserker_edge": 2, "adrenaline": 1}, "best_wave": 0})
	panel._refresh()
	panel._on_node_hover_changed("battle_hardened")
	print("a requirement is the node FULLY bought, and the tooltip says how far it needs to go: '%s' (expected 'Requires: Pure Spite (Lv 5), Adrenaline (Lv 3)')" % [panel.tooltip_cost_label.text])
	panel._on_node_hover_changed("otherworldly_power")
	print("Otherworldly Power says it wants everything: '%s' (expected 'Requires: every other upgrade, fully bought')" % [panel.tooltip_cost_label.text])
	panel._on_node_hover_changed("strength")
	# The tooltip settles its size over a frame or two, like it does in play.
	await process_frame
	await process_frame
	var rect: Rect2 = panel.view.node_rect_in_view("strength")
	print("the tooltip stays inside the view: %s (expected true)" % [Rect2(Vector2.ZERO, panel.view.size).encloses(Rect2(panel.tooltip.position, panel.tooltip.size))])
	print("...and never covers the node it describes: %s (expected false)" % [Rect2(panel.tooltip.position, panel.tooltip.size).intersects(rect)])
	panel._on_node_hover_changed("")
	print("moving off a node hides the tooltip: %s (expected false)" % [panel.tooltip.visible])

	# --- Polish: node styling, multi-buy, progress, wing labels, door marker ---
	save_data_script.save_data({"essence": 400, "upgrades": {"legacy": 1, "stamina": 1, "strength": 1, "agility": 1, "vigor": 1, "reflexes_unlock": 1}, "best_wave": 0})
	panel._refresh()
	var mastered_box: StyleBoxFlat = panel.view.button_for("reflexes_unlock").get_theme_stylebox("normal")
	var upgradable_box: StyleBoxFlat = panel.view.button_for("stamina").get_theme_stylebox("normal")
	print("a maxed-out node gets a thick golden border: state=%s width=%d gold=%s (expected mastered, 6, true)" % [
		panel.state_for("reflexes_unlock"), mastered_box.border_width_left, mastered_box.border_color == view_script.GOLD
	])
	print("...an owned node that isn't maxed does not: width=%d gold=%s (expected 4, false)" % [
		upgradable_box.border_width_left, upgradable_box.border_color == view_script.GOLD
	])
	var hub_box: StyleBoxFlat = panel.view.button_for("legacy").get_theme_stylebox("normal")
	print("the hub button is bigger than a node: size=%s corner=%d (expected 92 wide, round to the hub's radius %d)" % [panel.view.button_for("legacy").size, hub_box.corner_radius_top_left, int(view_script.HUB_RADIUS)])
	print("progress line counts the skills you own: '%s' (expected '6 / %d skills')" % [panel.progress_label.text, save_data_script.UPGRADE_IDS.size()])
	print("wing names are set on the four roots: %s (expected physical=strength, economy=coins, sustain=stamina, sorcery=release_grudge)" % [
		"physical=%s, economy=%s, sustain=%s, sorcery=%s" % [panel.view._wing_roots.get("physical"), panel.view._wing_roots.get("economy"), panel.view._wing_roots.get("sustain"), panel.view._wing_roots.get("sorcery")]
	])
	panel._on_node_hover_changed("stamina")
	print("a stackable buyable node advertises Shift+click: shown=%s text='%s' (expected true, 'Shift+click: buy up to 2 levels')" % [
		panel.tooltip_hint_label.visible, panel.tooltip_hint_label.text
	])
	panel._on_node_hover_changed("reflexes_unlock")
	print("...a maxed one does not: shown=%s (expected false)" % [panel.tooltip_hint_label.visible])
	panel._on_node_hover_changed("")

	save_data_script.save_data({"essence": 0, "upgrades": {"legacy": 1, "stamina": 1}, "best_wave": 0})
	panel._refresh()
	var owned_box: StyleBoxFlat = panel.view.button_for("stamina").get_theme_stylebox("normal")
	var greyed_owned: float = panel.view.button_for("stamina").get_child(0).modulate.r
	var greyed_unaffordable: float = panel.view.button_for("coins").get_child(0).modulate.r
	print("a node you can't buy is a little greyed out: owned=%s icon=%.2f, unaffordable=%s icon=%.2f (expected owned/unaffordable, both < 1.0)" % [
		panel.state_for("stamina"), greyed_owned, panel.state_for("coins"), greyed_unaffordable
	])
	print("...but an owned one keeps its wing colour, not gold: gold=%s (expected false)" % [owned_box.border_color == view_script.GOLD])

	save_data_script.save_data({"essence": 1000, "upgrades": {"legacy": 1}, "best_wave": 0})
	panel._refresh()
	# (the player still carries the Deep Lungs bought earlier in this test; line it up with the emptied save first)
	player._base_max_stamina = player.MAX_STAMINA
	player.max_stamina = player.MAX_STAMINA
	var stamina_before_stack: int = player.max_stamina
	var got: int = panel.buy_levels("stamina", 3)
	var expected_spend: int = save_data_script.get_upgrade_cost("stamina", 0) + save_data_script.get_upgrade_cost("stamina", 1) + save_data_script.get_upgrade_cost("stamina", 2)
	print("Shift+click style buying takes several levels: bought=%d level=%d essence_left=%d (expected 3, 3, %d)" % [
		got, panel.level_of("stamina"), save_data_script.load_data().essence, 1000 - expected_spend
	])
	print("...each level is applied to the run: +%d max stamina (expected +%d)" % [player.max_stamina - stamina_before_stack, 3 * int(save_data_script.UPGRADES.stamina.stat_bonus)])
	save_data_script.save_data({"essence": 1, "upgrades": {"legacy": 1}, "best_wave": 0})
	panel._refresh()
	print("...it stops when you run out of Essence: bought=%d (expected 1: Deep Lungs level 1 costs 1, level 2 costs 1 more but only 1 is in hand)" % [panel.buy_levels("stamina", 5)])
	save_data_script.save_data({"essence": 1000, "upgrades": {"legacy": 1, "agility": 1, "strength": 1, "vigor": 1}, "best_wave": 0})
	panel._refresh()
	print("...and at a skill's max level: bought=%d (expected 1 for a single-purchase skill asked for 5)" % [panel.buy_levels("reflexes_unlock", 5)])

	save_data_script.save_data({"essence": 0, "upgrades": {}, "best_wave": 0})
	main.refresh_church_marker()
	var marker_broke: bool = main.church_marker.visible
	save_data_script.save_data({"essence": 100, "upgrades": {}, "best_wave": 0})
	main.refresh_church_marker()
	print("the Church door shows a marker only when something is buyable: broke=%s afford=%s (expected false, true)" % [marker_broke, main.church_marker.visible])
	print("can_buy_any_upgrade: 0 essence=%s, 1 essence=%s (expected false, true: Legacy costs 1)" % [
		save_data_script.can_buy_any_upgrade({"essence": 0, "upgrades": {}}), save_data_script.can_buy_any_upgrade({"essence": 1, "upgrades": {}})
	])

	# --- The tree as a whole ---
	print("the whole tree costs %d Essence (expected 1588: the visualizer's prices where a node had one, drafts for the new ones; the doc's old total was 1,536)" % [save_data_script.total_tree_cost()])
	print("...every node keeps the visualizer's per-level prices: Pure Spite %s (expected [2, 3, 4, 6, 10]), Pack Bond %s (expected [40, 60, 90]), Otherworldly Power %s (expected [184])" % [save_data_script.UPGRADES.berserker_edge.costs, save_data_script.UPGRADES.pack_bond.costs, save_data_script.UPGRADES.otherworldly_power.costs])

	# --- Closing ---
	panel.close()
	print("closing the church unpauses the game: visible=%s paused=%s (expected false, false)" % [panel.visible, main.get_tree().paused])

	# Reset the shared scratch files.
	save_data_script.save_lifetime_data({})
	save_data_script.save_data({"essence": 0, "upgrades": {}, "best_wave": 0})
	quit()
