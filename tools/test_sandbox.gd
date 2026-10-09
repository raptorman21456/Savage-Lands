extends SceneTree

# The in-game Sandbox (title screen > Sandbox): configure any build + squad and
# fight a real battle without touching the real save. Covers the SaveData
# isolation, applying a build to the live player, building squads, the whole
# start -> victory / fled / defeat -> back-to-the-panel loop, and the panel's
# controls.

const SandboxScript := preload("res://scripts/Sandbox.gd")
const SaveDataScript := preload("res://scripts/SaveData.gd")

const SCRATCH_FILES := ["user://test_save_data_slot_1.json", "user://test_lifetime_progress.json"]

# The suite shares scratch save files between tests, so this test puts them back
# exactly as it found them (including "absent").
func _snapshot_scratch() -> Dictionary:
	var snap := {}
	for path in SCRATCH_FILES:
		snap[path] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else null
	return snap

func _restore_scratch(snap: Dictionary) -> void:
	for path in snap:
		if snap[path] == null:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else:
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_string(snap[path])
			f.close()

func _init() -> void:
	seed(20261003)
	var scratch_before := _snapshot_scratch()
	# --- The real (scratch) save is untouched by anything the sandbox does ----------
	SaveDataScript.save_data({"essence": 123, "upgrades": {"strength": 2}, "best_wave": 7})
	SaveDataScript.save_lifetime_data({"total_runs": 9})
	SaveDataScript.sandbox_active = true
	SaveDataScript.sandbox_data = {"essence": 5, "upgrades": {"vigor": 3}}
	print("sandbox mode reads its own in-memory data: essence=%d vigor=%d (expected 5, 3)" % [SaveDataScript.load_data().essence, SaveDataScript.load_data().upgrades.vigor])
	var d := SaveDataScript.load_data()
	d.essence = 999
	SaveDataScript.save_data(d)
	SaveDataScript.record_run_result(50, 4)
	SaveDataScript.mark_creature_seen("Goblin")
	print("run results are never banked in the sandbox: essence=%d (expected 999, set directly), record_run_result=%d (expected 0)" % [SaveDataScript.load_data().essence, SaveDataScript.record_run_result(50, 4)])
	SaveDataScript.sandbox_active = false
	var real := SaveDataScript.load_data()
	print("...and the real save is exactly as it was: essence=%d upgrades=%s best_wave=%d (expected 123 {strength: 2} 7)" % [real.essence, real.upgrades, real.best_wave])
	print("...with the lifetime stats and Beastiary untouched: runs=%d seen=%s (expected 9, false)" % [SaveDataScript.load_lifetime_data().get("total_runs", 0), SaveDataScript.is_creature_seen("Goblin")])

	# --- Booting Main in sandbox mode opens the panel -------------------------------
	SaveDataScript.sandbox_active = true
	SaveDataScript.sandbox_data = {}
	var main = load("res://Main.tscn").instantiate()
	main.regional_world = false  # this test drives the old wave-ladder world
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	var panel = main.sandbox_panel
	print("Main opens the sandbox panel on boot: panel=%s visible=%s registered=%s (expected true true true)" % [panel != null, panel.visible, main.town_panels.has("sandbox")])
	print("no overworld enemies are left roaming: %d (expected 0)" % main.get_tree().get_nodes_in_group("enemies").size())
	print("the panel has every tab: %s (expected 9: Character Weapon Gear Items Talismans Astral Party Encounter Options)" % [panel.tabs.get_tab_count()])
	print("it can't be closed with Escape/Close: %s (expected false)" % [panel.can_close()])

	# --- Applying a build -------------------------------------------------------------
	var cfg := SandboxScript.default_config()
	cfg.level = 20
	cfg.picks = {"strength": 10, "vigor": 9}
	cfg.upgrades = {"vigor": 2, "adrenaline": 2}
	cfg.weapon = {"base": "spear", "tier": "Legendary", "material": "obsidian"}
	cfg.blacksmith = 2
	cfg.armor = "armor_thornmail"
	cfg.armor_level = 1
	cfg.shield = "shield_heavy"
	cfg.talismans = ["ember_charm", "stone_amulet", "moss_charm", "healers_knot", "bloodstone"]
	cfg.coins = 77
	cfg.arrows = {"flame": 2, "freeze": 1, "bomb": 0}
	cfg.consumables = [{"id": "potion_health", "n": 3}, {"id": "food_haunch", "n": 1}]
	SandboxScript.apply_build(main, cfg)
	print("level and stat points apply (Vitality level 2 makes each Vigor point worth +5): level=%d strength=%d (expected 20, 30) vigor=%d (expected 20+19+9*5=84)" % [player.level, player.stat_strength, player.stat_vigor])
	print("max HP / attack follow: %d / %d (expected 84 / 30)" % [player.max_health, player.attack_damage])
	print("the weapon is the chosen variant with Blacksmith applied: id=%s upgrade=%d (expected spear_legendary_obsidian, 2)" % [player.current_weapon_base.id, player.get_weapon_upgrade_level(player.current_weapon_base.id)])
	print("talismans respect the slot limit (4 at level 20): %s (expected 4 of 5, the first four)" % [player.equipped_talismans])
	cfg.ignore_slots = true
	SandboxScript.apply_build(main, cfg)
	print("...unless told to ignore it: %d (expected 5)" % player.equipped_talismans.size())
	print("armor, shield, coins, arrows and items apply: %s +%d / %s / %d / %s / %d items (expected Thornmail +1 / Heavy Shield / 77 / {flame: 2, freeze: 1, bomb: 0} / 4)" % [player.equipped_armor.name, player.get_armor_upgrade_level("armor_thornmail"), player.equipped_shield.name, player.coins, player.owned_arrows, player.potion_queue.size()])
	print("Adrenaline's passive reaches the player: %.2f (expected 0.16)" % player.meta_low_hp_damage_bonus_pct)
	var first_hp: int = player.max_health
	SandboxScript.apply_build(main, cfg)
	print("applying twice gives the same player (idempotent): %s (expected true)" % [player.max_health == first_hp])

	# --- Party ------------------------------------------------------------------------
	cfg.upgrades = {"pack_leader": 1, "battle_hardened": 1}
	cfg.party = [{"kind": "guardian", "level": 5, "picks": {"hp": 2, "defense": 2}}, {"kind": "wolf", "level": 1, "picks": {}}]
	SandboxScript.apply_build(main, cfg)
	print("the Astral-granted Knight plus chosen members join (capacity 3): mercenaries=%d party=%d (expected 1, 2)" % [player.party_members.size(), player.party.size()])
	print("...and the Knight is named as such: %s (expected Knight)" % [player.party_members[0].name])
	var guardian = player.party[0]
	print("a levelled party member has its points placed: level=%d picks left=%d hp=%d (expected 5, 0, %d)" % [guardian.level, guardian.picks, guardian.max_hp(), int(round((25.0 + 4 * 1.25 + 2 * 1.25)))])

	# --- Squads -------------------------------------------------------------------------
	cfg = SandboxScript.default_config()
	cfg.level = 10
	cfg.enemies = [{"name": "Goblin", "elite": false, "power_tier": 1.0}, {"name": "Brute", "elite": true, "power_tier": 1.0}, {"name": "Orc", "elite": false, "power_tier": 2.0}]
	var squad: Array = SandboxScript.build_squad(main, cfg)
	var names := []
	for e in squad:
		names.append(e.get_display_name())
	print("the squad is built from the chosen names: %s (expected [Goblin, Brute, Orc])" % [names])
	print("elite flag and power tier carry over: brute elite=%s, orc tier meta=%.1f (expected true, 2.0)" % [squad[1].is_elite, squad[2].get_meta("sandbox_power_tier", 1.0)])
	print("the catalog covers every enemy incl. variants: %d names (expected >= 20), Traitor Wolf=%s Centaur Archer=%s" % [SandboxScript.enemy_names().size(), SandboxScript.enemy_names().has("Traitor Wolf"), SandboxScript.enemy_names().has("Centaur Archer")])

	# --- A full battle: start -> flee -> back at the panel ------------------------------
	SandboxScript.apply_build(main, cfg)
	panel.visible = false
	main.start_sandbox_battle(squad, SandboxScript.world_index(main, "plains"))
	print("a sandbox battle starts for real: in_battle=%s units=%d (expected true, 3)" % [main.in_battle, main.battle_units.size()])
	var scale: float = 1.0 + (player.level - 1) * main.ENEMY_LEVEL_SCALING
	var orc_base: int = 20
	print("enemy stats scale off the player's level, elite and power tier: Brute hp=%d (expected %d), Orc hp=%d (expected %d)" % [
		main.battle_units[1].max_hp, int(round(35 * scale * 1.6)), main.battle_units[2].max_hp, int(round(orc_base * scale * 2.0))
	])
	main._battle_flee()
	await process_frame
	await process_frame
	print("fleeing returns to the sandbox panel: in_battle=%s panel visible=%s result=%s (expected false, true, fled)" % [main.in_battle, panel.visible, main.sandbox_result])
	print("...with the leftover enemies cleaned up: %d (expected 0), paused=%s (expected true)" % [main.get_tree().get_nodes_in_group("enemies").size(), main.get_tree().paused])
	print("...and a result line on the panel: %s" % [panel.result_label.text.begins_with("Last battle: FLED")])

	# --- Victory through a real attack --------------------------------------------------
	cfg.enemies = [{"name": "Goblin", "elite": false, "power_tier": 1.0}]
	cfg.level = 10
	cfg.picks = {"strength": 9}
	cfg.weapon = {"base": "club", "tier": "Fine", "material": "steel"}
	SandboxScript.apply_build(main, cfg)
	squad = SandboxScript.build_squad(main, cfg)
	panel.visible = false
	main.start_sandbox_battle(squad, 0)
	main.battle_units[0].tile = main.battle_player_tile + Vector2i(1, 0)
	main.battle_units[0].hp = 1
	main.battle_target_index = 0
	main._battle_player_fight()
	await process_frame
	print("winning returns to the panel: in_battle=%s visible=%s result=%s (expected false, true, victory)" % [main.in_battle, panel.visible, main.sandbox_result])
	print("...without banking anything: essence=%d (expected 0), wave=%d (expected 1)" % [SaveDataScript.load_data().essence, main.wave])

	# --- Defeat ----------------------------------------------------------------------------
	SandboxScript.apply_build(main, cfg)
	squad = SandboxScript.build_squad(main, cfg)
	panel.visible = false
	main.start_sandbox_battle(squad, 0)
	player.take_battle_damage(99999)
	await process_frame
	print("dying returns to the panel, not the game-over screen: in_battle=%s game_over=%s visible=%s result=%s (expected false, false, true, defeat)" % [main.in_battle, main.game_over, panel.visible, main.sandbox_result])

	# --- The panel's controls -----------------------------------------------------------------
	panel.cfg = SandboxScript.default_config()
	panel.cfg.level = 10
	panel._fill_picks("balanced")
	print("Balanced spreads the 9 level-up points evenly: %s (expected strength 2 vigor 2 agility 2 might 2 intimidation 1)" % [panel.cfg.picks])
	panel._pick("strength", 1)
	print("a pick over the budget is refused: used=%d (expected 9)" % panel._picks_used())
	panel.cfg.level = 3
	panel._trim_picks()
	print("lowering the level trims the placed points: used=%d (expected 2)" % panel._picks_used())
	panel._load_preset("p3")
	print("a squad preset loads: %s (expected Orc, Goblin, Goblin)" % [panel.cfg.enemies.map(func(e): return e.name)])
	panel._load_preset("b0")
	print("a world boss preset loads the boss and its world: %s / %s (expected [Lizen Warband] / plains)" % [panel.cfg.enemies.map(func(e): return e.name), panel.cfg.world])
	panel._set_item_count("potion_attack", 4)
	print("item counts keep the potion-then-food order: %s (expected potion_health first, potion_attack present)" % [panel.cfg.consumables.map(func(e): return "%s x%d" % [e.id, e.n])])
	panel._party_pick(0, "hp", 1) if panel.cfg.party.size() > 0 else null
	panel.cfg.party = [{"kind": "rogue", "level": 3, "picks": {}}]
	panel._party_pick(0, "attack", 1)
	panel._party_pick(0, "attack", 1)
	panel._party_pick(0, "attack", 1)
	print("party points are capped at level-1 (2 for a level-3 rogue): %d (expected 2)" % panel._party_picks_used(0))
	panel.cfg.upgrades = {}
	panel._changed(["Astral", "Character", "Party"])
	panel.cfg.enemies = []
	panel._start_battle()
	print("starting with no enemies is refused: in_battle=%s msg=%s (expected false, true)" % [main.in_battle, panel.result_label.text.begins_with("Add at least one enemy")])
	# toggling every tab's builder once, to catch any broken control
	panel._fill_all_tabs()
	panel.show_noncombat = true
	panel._rebuild(["Astral"])
	print("every tab rebuilds cleanly (including the long non-combat Astral list): true")
	var round_trip := SandboxScript.merged_config({"level": 33, "weapon": {"base": "hammer", "tier": "Mythic", "material": "gold"}})
	print("a saved config merges onto the defaults: level=%d weapon=%s enemies kept=%d (expected 33, hammer, 2)" % [round_trip.level, round_trip.weapon.base, round_trip.enemies.size()])

	# --- Title screen entry -----------------------------------------------------------------------
	SaveDataScript.sandbox_active = true
	var title = load("res://TitleScreen.tscn").instantiate()
	root.add_child(title)
	await process_frame
	print("the title screen offers a Sandbox button: %s text=%s (expected true, Sandbox)" % [title.sandbox_button != null, title.sandbox_button.text])
	print("...and coming back to the title screen re-arms the real save: sandbox_active=%s (expected false)" % SaveDataScript.sandbox_active)
	_restore_scratch(scratch_before)
	quit()
