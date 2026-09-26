extends SceneTree

# Beastiary: a device-wide "have I ever clicked or defeated this creature"
# log (SaveData.gd's beastiary_seen, same shape as seen_unlocks), browsable
# from a shared BeastiaryPanel instance on both the Title Screen and
# Main.gd's pause menu/in-battle corner button.

func _init() -> void:
	var save_data_script = load("res://scripts/SaveData.gd")
	var beastiary_script = load("res://scripts/Beastiary.gd")
	var hud_script = load("res://scripts/HUD.gd")
	var lifetime_path: String = save_data_script._resolve_lifetime_path()
	if FileAccess.file_exists(lifetime_path):
		DirAccess.remove_absolute(lifetime_path)

	# --- SaveData primitives ---
	print("fresh creature starts unseen: %s (expected true)" % [not save_data_script.is_creature_seen("Goblin")])
	save_data_script.mark_creature_seen("Goblin")
	print("marking it seen sticks: %s (expected true)" % [save_data_script.is_creature_seen("Goblin")])
	save_data_script.active_slot = 2
	print("device-wide -- survives an active_slot switch: %s (expected true)" % [save_data_script.is_creature_seen("Goblin")])
	save_data_script.active_slot = 1
	save_data_script.mark_creature_seen("")
	print("an empty name is a no-op, doesn't crash: %s (expected true)" % [not save_data_script.is_creature_seen("")])

	if FileAccess.file_exists(lifetime_path):
		DirAccess.remove_absolute(lifetime_path)

	# --- Every Beastiary.DESCRIPTIONS key matches a real HUD.ENEMY_ICONS
	# entry, and vice versa -- the two are meant to be kept in lockstep. ---
	var all_match := true
	for creature_name in beastiary_script.DESCRIPTIONS:
		if not hud_script.ENEMY_ICONS.has(creature_name):
			all_match = false
	for creature_name in hud_script.ENEMY_ICONS:
		if not beastiary_script.DESCRIPTIONS.has(creature_name):
			all_match = false
	print("every Beastiary entry has a matching ENEMY_ICONS entry and vice versa: %s (expected true)" % all_match)

	# --- Scenario: Main.gd's click/defeat hooks ---
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	main.in_battle = true
	main.battle_turn = "player"
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(2, 2)
	var goblin_script = load("res://scripts/Enemy.gd")
	var g = goblin_script.new()
	main.add_child(g)
	g.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	var g_unit := {
		"ref": g, "tile": Vector2i(3, 2), "hp": 999, "max_hp": 999, "move_range": 2,
		"damage": 7, "name": "Goblin", "winding_up": false, "stunned": false,
	}
	main.battle_units = [g_unit]
	print("Goblin starts this scenario unseen (fresh lifetime file): %s (expected true)" % [not save_data_script.is_creature_seen("Goblin")])
	main._on_enemy_target_selected(0)
	print("clicking an enemy marks it seen: %s (expected true)" % [save_data_script.is_creature_seen("Goblin")])
	print("...Orc still unseen until actually encountered: %s (expected true)" % [not save_data_script.is_creature_seen("Orc")])
	main._on_enemy_died(0, "Orc")
	print("defeating an enemy (by name) marks it seen too: %s (expected true)" % [save_data_script.is_creature_seen("Orc")])

	# --- Hover stat summary ---
	var summary: String = main._enemy_stat_summary(g_unit)
	print("hover stat summary includes name/HP/damage: %s (expected true)" % [
		summary.contains("Goblin") and summary.contains("999") and summary.contains("7")
	])
	var strahd_unit := {"tile": Vector2i(0, 0), "hp": 50, "max_hp": 100, "damage": 20, "name": "Count Strahd"}
	var strahd_summary: String = main._enemy_stat_summary(strahd_unit)
	print("a boss-tier, armored, evasive enemy's summary tags all three: %s (expected true)" % [
		strahd_summary.contains("Boss") and strahd_summary.contains("Armored") and strahd_summary.contains("Evasive")
	])

	# --- BeastiaryPanel: locked vs. unlocked rows, pause nesting ---
	var panel = main.beastiary_panel
	var was_paused_initially: bool = main.get_tree().paused
	panel.open()
	print("opening pauses the tree: %s (expected true)" % [main.get_tree().paused])
	var goblin_row_text := ""
	var orc_row_text := ""
	var dagger_row_seen := false
	for child in panel.list_box.get_children():
		if child.text == "Goblin":
			goblin_row_text = child.text
		if child.text == "Orc":
			orc_row_text = child.text
		if child.text == "???":
			dagger_row_seen = true
	print("a seen creature shows its real name in the list: goblin=%s orc=%s (expected Goblin, Orc)" % [goblin_row_text, orc_row_text])
	print("an unseen creature shows as '???': %s (expected true)" % [dagger_row_seen])
	print("detail panel auto-selects a seen creature on open: name=%s (expected Goblin or Orc, whichever sorts first)" % [panel.detail_name.text])

	panel._select("Count Strahd")
	print("selecting a creature populates description and traits: desc_nonempty=%s traits_mention_boss=%s (expected true, true)" % [
		panel.detail_description.text != "", panel.detail_traits.text.contains("Boss")
	])

	panel.close()
	print("closing restores the prior (unpaused) state: %s (expected %s)" % [main.get_tree().paused, was_paused_initially])

	# Opened from an already-paused state (e.g. the pause menu), closing
	# should return to paused, not force-unpause the whole game.
	main.get_tree().paused = true
	panel.open()
	panel.close()
	print("closing from an already-paused context stays paused: %s (expected true)" % [main.get_tree().paused])
	main.get_tree().paused = false

	main.queue_free()
	await process_frame

	# --- Scenario: TitleScreen.gd's own BeastiaryPanel instance sees the
	# same device-wide collection ---
	var title_scene = load("res://TitleScreen.tscn")
	var title = title_scene.instantiate()
	root.add_child(title)
	await physics_frame
	await physics_frame

	title.beastiary_panel.open()
	var title_goblin_seen := false
	for child in title.beastiary_panel.list_box.get_children():
		if child.text == "Goblin":
			title_goblin_seen = true
	print("Title Screen's own Beastiary instance reflects the same device-wide log: %s (expected true)" % [title_goblin_seen])
	title.beastiary_panel.close()

	title.queue_free()
	await process_frame

	if FileAccess.file_exists(lifetime_path):
		DirAccess.remove_absolute(lifetime_path)
	quit()
