extends SceneTree

# The Debug menu (F1): the On/Off setting (off by default, F1 does nothing when off), opening and closing without breaking the pause,
# every tab building, the keyboard, and what each tab's actions really do to the game (DebugActions / DebugWorld / DebugBattle /
# DebugProgress). Each line states what it checked and what it expected.

const DA := preload("res://scripts/DebugActions.gd")
const DW := preload("res://scripts/DebugWorld.gd")
const DB := preload("res://scripts/DebugBattle.gd")
const DP := preload("res://scripts/DebugProgress.gd")
const DebugMenuScript := preload("res://scripts/DebugMenu.gd")
const SaveDataScript := preload("res://scripts/SaveData.gd")
const WorldMapScript := preload("res://scripts/WorldMap.gd")
const RoomsScript := preload("res://scripts/Rooms.gd")
const InteriorScript := preload("res://scripts/Interior.gd")

# The suite shares scratch save files between tests: this one puts them back exactly as it found them (including "absent").
const SCRATCH_FILES := ["user://test_save_data_slot_1.json", "user://test_save_data_slot_1_backup.json", "user://test_lifetime_progress.json", "user://test_settings.json"]

var main = null
var player = null
var menu = null
var settings = null

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

func _frames(n: int = 2) -> void:
	for i in n:
		await process_frame

func _key(keycode: int, pressed: bool = true) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _tap_key(keycode: int) -> void:
	_key(keycode, true)
	await _frames(2)
	_key(keycode, false)
	await _frames(1)

func _find_button(node: Node, wanted: String):
	if node is PixelButton and node.text == wanted and node.is_visible_in_tree():
		return node
	for child in node.get_children():
		var found = _find_button(child, wanted)
		if found != null:
			return found
	return null

func _press(wanted: String) -> bool:
	var b = _find_button(menu.view, wanted)
	if b == null:
		return false
	b.pressed.emit()
	return true

func _fresh_main():
	var m = load("res://Main.tscn").instantiate()
	root.add_child(m)
	await physics_frame
	await physics_frame
	for e in m.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)
	return m

# A win pays XP and Essence, so a level-up picker (and, every few kills, a random event) can pop up afterwards: answer them.
func _clear_pending() -> void:
	for i in 6:
		if main.choosing_stat:
			main._on_levelup_choice_pressed("vigor")
		elif main.event_choosing:
			main._on_event_choice_pressed(false)
		else:
			break
	await _frames(1)

# Runs until it is the hero's turn (an enemy's turn is a chain of animated steps).
func _wait_for_hero() -> void:
	for i in 900:
		if main.in_battle and main.battle_turn == "player" and not main.battle_timeline_running:
			return
		if not main.in_battle:
			return
		await process_frame

func _init() -> void:
	# Magic from a Staff or Wand used to be a flat +5 / +6; the doc's per-quality-tier version (test_weapon_stat_bonuses.gd) gives a Fine one
	# (the second rung) the same figures at 2.5 / 3.0 a tier, so these checks keep the numbers they were written against.
	var _magic_weapons = load("res://scripts/Weapons.gd")
	_magic_weapons.STAFF["magic_per_tier"] = 2.5
	_magic_weapons.WAND["magic_per_tier"] = 3.0
	seed(20261018)
	var scratch_before := _snapshot_scratch()
	await _frames(2)
	settings = root.get_node("Settings")
	var setting_before: bool = settings.debug_menu_enabled
	SaveDataScript.save_data({"essence": 0, "upgrades": {}, "best_wave": 0, "difficulty": "normal", "name": "Debug test"})
	SaveDataScript.save_lifetime_data({"tutorial_completed_ever": true})
	main = await _fresh_main()
	player = main.player
	menu = main.debug_menu
	main.ambient_spawn_timer = 1.0e9      # nothing new wanders into the test

	await _section_switch()
	await _section_window()
	await _section_tabs_and_keys()
	await _section_player()
	await _section_items()
	await _section_party()
	await _section_world()
	await _section_battle()
	await _section_progress()
	await _section_game()
	await _section_ui_flows()
	await _section_sandbox_and_loss()
	await _section_old_arena()

	settings.debug_menu_enabled = setting_before
	_restore_scratch(scratch_before)
	quit()

# ---------------------------------------------------------------------------------------------------------------------------
# The On / Off switch
# ---------------------------------------------------------------------------------------------------------------------------

func _section_switch() -> void:
	print("--- the switch ---")
	print("the Debug menu is off by default: Settings.debug_menu_enabled=%s (expected false), is_enabled=%s (expected false)" % [settings.debug_menu_enabled, DebugMenuScript.is_enabled()])
	print("Main builds it anyway but it stays hidden: exists=%s (expected true), visible=%s (expected false)" % [menu != null, menu.visible])
	_key(KEY_F1)
	await _frames(2)
	_key(KEY_F1, false)
	await _frames(1)
	print("F1 does nothing while it is off: visible=%s (expected false), paused=%s (expected false)" % [menu.visible, paused])
	# the old quick keys are part of it: inert while off
	var coins_before: int = player.coins
	_key(KEY_F4)
	await _frames(2)
	_key(KEY_F4, false)
	print("the old F4 +500 coins key is inert while off: %d -> %d (expected no change)" % [coins_before, player.coins])
	# turning it on from Settings > Gameplay in the Inventory
	main.inventory_panel.open(player)
	main.inventory_panel.settings_page = "Gameplay"
	main.inventory_panel._select_tab("Settings")
	await _frames(2)
	var row_found := false
	var toggle = null
	for lab in _labels(main.inventory_panel.settings_view):
		if lab.text == "Debug menu (F1)":
			row_found = true
			var box: Node = lab.get_parent()
			for sibling in box.get_children():
				if sibling is PixelButton:
					toggle = sibling
	print("Settings > Gameplay has a 'Debug menu (F1)' row: %s (expected true), showing Off: %s (expected true)" % [row_found, toggle != null and toggle.text == "Off"])
	if toggle != null:
		toggle.pressed.emit()
	print("pressing it turns the setting on and saves it: enabled=%s (expected true), in the settings file=%s (expected true)" % [
		settings.debug_menu_enabled, bool(SaveDataScript.load_settings().get("debug_menu_enabled", false))])
	main.inventory_panel.close()
	await _frames(1)
	# the old quick keys now work
	coins_before = player.coins
	_key(KEY_F4)
	await _frames(2)
	_key(KEY_F4, false)
	await _frames(1)
	print("with it on the F4 key works again: %d -> %d (expected +500)" % [coins_before, player.coins])
	player.coins = coins_before

func _labels(node: Node) -> Array:
	var out: Array = []
	if node is Label:
		out.append(node)
	for c in node.get_children():
		out.append_array(_labels(c))
	return out

# ---------------------------------------------------------------------------------------------------------------------------
# Opening, closing, pausing
# ---------------------------------------------------------------------------------------------------------------------------

func _section_window() -> void:
	print("--- the window ---")
	_key(KEY_F1)
	await _frames(2)
	_key(KEY_F1, false)
	await _frames(1)
	print("F1 opens it and pauses the game: visible=%s (expected true), paused=%s (expected true)" % [menu.visible, paused])
	var screen := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width", 1152), ProjectSettings.get_setting("display/window/size/viewport_height", 648))
	print("the window fits the default %dx%d screen: window %s (expected 1120x624 or smaller)" % [screen.x, screen.y, menu.window.size])
	print("...and centred on it it is fully on screen: %s (expected true)" % [Rect2(Vector2.ZERO, screen).encloses(Rect2(((screen - menu.window.size) / 2.0).round(), menu.window.size))])
	print("the HUD and Inventory stop hearing keys while it is up: hud=%s inventory=%s (expected false false)" % [main.hud.is_processing_input(), main.inventory_panel.is_processing_input()])
	_key(KEY_F1)
	await _frames(2)
	_key(KEY_F1, false)
	await _frames(1)
	print("F1 again closes it and gives the pause back: visible=%s (expected false), paused=%s (expected false)" % [menu.visible, paused])
	print("...and the HUD and Inventory hear keys again: hud=%s inventory=%s (expected true true)" % [main.hud.is_processing_input(), main.inventory_panel.is_processing_input()])
	# Esc closes
	menu.open()
	await _frames(1)
	await _tap_key(KEY_ESCAPE)
	print("Esc closes it: visible=%s (expected false)" % menu.visible)
	# the pause menu was up (game already paused): it must still be paused after
	main.menu_open = true
	paused = true
	menu.open()
	await _frames(1)
	menu.close()
	print("opened over the pause menu and closed: still paused=%s (expected true)" % paused)
	main.menu_open = false
	paused = false
	# the Inventory is open under it
	main.inventory_panel.open(player)
	_key(KEY_F1)
	await _frames(2)
	_key(KEY_F1, false)
	await _frames(1)
	print("F1 over the open Inventory: debug visible=%s (expected true), inventory visible=%s (expected true)" % [menu.visible, main.inventory_panel.visible])
	var inventory_tab_before: String = main.inventory_panel.active_tab
	await _tap_key(KEY_Q)
	print("Q switches the Debug menu's tab (Player wraps back to Game), not the Inventory's: debug tab=%s (expected Game), inventory tab=%s (expected %s, unchanged)" % [menu.active_tab, main.inventory_panel.active_tab, inventory_tab_before])
	menu.close()
	print("closing it leaves the Inventory open and the game still paused: inventory=%s (expected true), paused=%s (expected true)" % [main.inventory_panel.visible, paused])
	main.inventory_panel.close()
	print("and the Inventory then unpauses as always: paused=%s (expected false)" % paused)
	menu.active_tab = "Player"

# ---------------------------------------------------------------------------------------------------------------------------
# Tabs and the keyboard
# ---------------------------------------------------------------------------------------------------------------------------

func _section_tabs_and_keys() -> void:
	print("--- tabs and keys ---")
	menu.open()
	await _frames(2)
	var names: Array = DebugMenuScript.TABS.map(func(t): return t[0])
	print("the tabs: %s (expected Player, Items, Party, World, Battle, Progress, Game)" % [", ".join(names)])
	for t in names:
		menu._select_tab(t)
		await _frames(2)
		var buttons := _count_buttons(menu.view)
		print("tab %s builds with controls: %d buttons (expected > 3), focusable controls=%d (expected > 3)" % [t, buttons, load("res://scripts/DebugKit.gd").focusables(menu.view).size()])
	menu._select_tab("Player")
	await _frames(1)
	await _tap_key(KEY_E)
	print("E steps to the next tab: %s (expected Items)" % menu.active_tab)
	await _tap_key(KEY_Q)
	await _tap_key(KEY_Q)
	print("Q steps back, wrapping round: %s (expected Game)" % menu.active_tab)
	menu._select_tab("Player")
	await _frames(2)
	# keyboard: the first control has focus; Down moves on; Enter presses
	menu._focus_first()
	await _frames(2)
	var first: Control = root.gui_get_focus_owner()
	print("opening a tab puts the keyboard on its first control: focus=%s (expected a control)" % [first != null])
	await _tap_key(KEY_DOWN)
	var second: Control = root.gui_get_focus_owner()
	print("Down moves the keyboard to another control: moved=%s (expected true)" % [second != null and second != first])
	# Enter presses a focused button
	var press_log: Array = []
	var probe = load("res://scripts/DebugKit.gd").button("probe", func(): press_log.append(1))
	menu.body.add_child(probe)
	await _frames(1)
	probe.grab_focus()
	await _tap_key(KEY_ENTER)
	await _tap_key(KEY_SPACE)
	await _tap_key(KEY_Z)
	print("Enter, Space and Z press a focused button: presses=%d (expected 3)" % press_log.size())
	menu.body.remove_child(probe)
	probe.queue_free()
	# a LineEdit keeps Q / E for typing
	var edit = load("res://scripts/DebugKit.gd").line_edit("", 120.0)
	menu.body.add_child(edit)
	await _frames(1)
	edit.grab_focus()
	var tab_before: String = menu.active_tab
	await _tap_key(KEY_E)
	print("E typed into a text box does not change the tab: %s -> %s (expected unchanged)" % [tab_before, menu.active_tab])
	await _tap_key(KEY_ESCAPE)
	print("Esc in a text box only leaves the box, the menu stays: visible=%s (expected true), focus left it=%s (expected true)" % [menu.visible, root.gui_get_focus_owner() != edit])
	menu.body.remove_child(edit)
	edit.queue_free()
	# the number field
	var applied: Array = []
	var holder := Control.new()
	menu.body.add_child(holder)
	var num = load("res://scripts/DebugKit.gd").number(holder, 5, func(v): applied.append(v), {"min": 0, "max": 20, "steps": [1, 10]})
	var plus_ten = _find_button(holder, "+10")
	var minus_one = _find_button(holder, "−1")
	plus_ten.pressed.emit()
	minus_one.pressed.emit()
	var line: LineEdit = null
	for c in num.get_children():
		if c is LineEdit:
			line = c
	line.text = "99"
	line.text_submitted.emit("99")
	print("a number field steps and clamps: %s (expected [15, 4, 20])" % [str(applied)])
	menu.body.remove_child(holder)
	holder.queue_free()
	# the question box
	var asked: Array = []
	menu.confirm("Sure?", func(): asked.append("yes"))
	await _frames(2)
	print("a question box opens over the window: %s (expected true)" % [menu.confirm_box != null])
	await _tap_key(KEY_ESCAPE)
	print("Esc says no: box closed=%s (expected true), nothing done=%s (expected true), menu still open=%s (expected true)" % [menu.confirm_box == null, asked.is_empty(), menu.visible])
	menu.confirm("Sure?", func(): asked.append("yes"))
	await _frames(2)
	var yes = _find_button(menu.confirm_box, "Yes, do it")
	yes.pressed.emit()
	print("Yes does it and closes the box: %s (expected [yes]), closed=%s (expected true)" % [str(asked), menu.confirm_box == null])
	menu.close()

func _count_buttons(node: Node) -> int:
	var n := 1 if node is PixelButton else 0
	for c in node.get_children():
		n += _count_buttons(c)
	return n

# ---------------------------------------------------------------------------------------------------------------------------
# PLAYER
# ---------------------------------------------------------------------------------------------------------------------------

func _section_player() -> void:
	print("--- player ---")
	var r: Dictionary = DA.set_level(main, 5)
	print("set level 5: %s, level=%d (expected 5), strength=%d (expected 5: +1 a level), max HP=%d (expected 24), level-up picker open=%s (expected false)" % [r.ok, player.level, player.stat_strength, player.max_health, main.choosing_stat])
	r = DA.set_level(main, 2)
	print("lowering to 2 starts the stats over: level=%d (expected 2), strength=%d (expected 2), vigor=%d (expected 21)" % [player.level, player.stat_strength, player.stat_vigor])
	DA.set_level(main, 3)
	var xp_to_next: int = player.xp_to_next
	r = DA.give_xp(main, 10)
	print("give 10 XP: xp=%d (expected 10), level=%d (expected 3)" % [player.xp, player.level])
	r = DA.give_xp(main, xp_to_next + 5)
	print("enough XP levels you up the real way: level=%d (expected 4), the level-up picker is open=%s (expected true)" % [player.level, main.choosing_stat])
	main._on_levelup_choice_pressed("vigor")
	print("...and picking a stat closes it: open=%s (expected false), paused=%s (expected false)" % [main.choosing_stat, paused])
	DA.set_level(main, 1)
	r = DA.set_health(main, 7)
	print("set HP 7: %d (expected 7)" % player.health)
	r = DA.set_health(main, 9999)
	print("set HP far too high clamps to max: %d of %d (expected equal)" % [player.health, player.max_health])
	r = DA.set_stamina(main, 33)
	print("set stamina 33: %d (expected 33)" % player.stamina)
	player.health = 1
	DA.heal_hero(main)
	print("heal fully: HP=%d/%d stamina=%d/%d (expected both full)" % [player.health, player.max_health, player.stamina, player.max_stamina])
	var max_before: int = player.max_health
	DA.add_max_hp(main, 10)
	print("max HP +10 through the Hardened bonus: %d -> %d (expected +10)" % [max_before, player.max_health])
	DA.add_max_hp(main, -10)
	for id in ["might", "strength", "vigor", "intimidation", "resilience", "reflexes", "dexterity", "fortitude", "rage"]:
		DA.set_stat(main, id, 12)
	DA.set_agility_rating(main, 12)
	print("every stat can be set: might=%d str=%d vigor=%d agility rating=%d intimidation=%d resilience=%d reflexes=%d dexterity=%d fortitude=%d rage=%d (expected 12 each)" % [
		player.stat_might, player.stat_strength, player.stat_vigor, DA.agility_rating(main), player.stat_intimidation, player.stat_resilience, player.stat_reflexes, player.stat_dexterity, player.stat_fortitude, player.stat_rage])
	print("...agility is a walking speed underneath: %d px/s (expected 215: 180 + 7 x 5)" % player.stat_agility)
	print("...and the derived numbers followed: max HP=%d (expected 12), attack=%d (expected 12)" % [player.max_health, player.attack_damage])
	var rows: Array = DA.stat_rows(main)
	print("the stat list comes from the Player itself: %d stats incl. might=%s (expected >= 9, true)" % [rows.size(), rows.any(func(s): return s.id == "might")])
	print("...Rage is in it, locked until Painful Memories: %s (expected true)" % [rows.any(func(s): return s.id == "rage" and s.locked)])
	DA.reset_cheats(main)
	DA.set_level(main, 1)
	DA.set_coins(main, 500)
	print("set coins 500: %d (expected 500)" % player.coins)
	DA.set_coins(main, 120)
	print("set coins down to 120: %d (expected 120)" % player.coins)
	DA.set_shards(main, 9)
	print("set runic shards 9: %d (expected 9)" % player.runic_shards)
	DA.set_essence(main, 77)
	print("set banked Essence 77: %d (expected 77), in the save=%d (expected 77)" % [DA.essence(main), SaveDataScript.banked_essence()])
	# cheats
	player.health = player.max_health
	DA.set_god_mode(main, true)
	player.take_battle_damage(5)
	player.take_damage(5)
	print("god mode: a battle hit and an overworld hit change nothing: HP=%d/%d (expected full)" % [player.health, player.max_health])
	DA.set_god_mode(main, false)
	player.invincible_timer = 0.0
	player.take_battle_damage(3)
	print("god mode off: hits land again: HP=%d (expected %d)" % [player.health, player.max_health - 3])
	player.stamina = 50
	DA.set_infinite_stamina(main, true)
	var paid: bool = player.spend_stamina(40)
	print("infinite stamina: spending 40 works=%s (expected true), the bar is full=%s (expected true)" % [paid, player.stamina == player.max_stamina])
	DA.set_infinite_stamina(main, false)
	print("...and off again: infinite=%s (expected false)" % player.debug_infinite_stamina)
	DA.set_one_hit_kills(main, true)
	player.temp_damage_bonus_pct = 0.0
	menu.open()
	await _frames(3)
	print("one-hit kills: the menu holds the damage bonus up even if the shrine resets it: %s (expected true)" % [player.temp_damage_bonus_pct == DA.ONE_HIT_BONUS])
	menu.close()
	DA.set_one_hit_kills(main, false)
	print("...and off: bonus=%s (expected 0)" % player.temp_damage_bonus_pct)
	DA.set_speed_mult(main, 2.0)
	print("walking speed x2: %s (expected 2)" % player.debug_speed_mult)
	DA.set_speed_mult(main, 1.0)
	# put the hero back to a fresh level 1 for the rest
	DA.set_level(main, 2)
	DA.set_level(main, 1)
	DA.heal_hero(main)
	print("back to a fresh hero: level=%d str=%d vigor=%d speed rating=%d HP=%d/%d (expected 1, 1, 20, 5, 20/20)" % [player.level, player.stat_strength, player.stat_vigor, DA.agility_rating(main), player.health, player.max_health])

# ---------------------------------------------------------------------------------------------------------------------------
# ITEMS
# ---------------------------------------------------------------------------------------------------------------------------

func _section_items() -> void:
	print("--- items ---")
	var r: Dictionary = DA.give_weapon(main, "spear", "Masterwork", "gold", true)
	print("give and equip a Masterwork gold Spear (needs 8 Might, you have %d): owned=%s (expected true), equipped=%s (expected true)" % [player.stat_might, player.owned_weapons.has("spear_masterwork_gold"), player.current_weapon_base.get("id", "") == "spear_masterwork_gold"])
	r = DA.give_weapon(main, "dagger", "Broken", "wood", false)
	print("give without equipping: owned=%s (expected true), still wielding the spear=%s (expected true)" % [player.owned_weapons.has("dagger_broken_wood"), player.current_weapon_base.get("id", "") == "spear_masterwork_gold"])
	r = DA.give_weapon(main, "spear", "Mythic", "steel", false)
	print("a Mythic takes no material: owned spear_mythic=%s (expected true)" % player.owned_weapons.has("spear_mythic"))
	r = DA.give_weapon(main, "staff", "Fine", "wood", true)
	print("a Staff is handed over but never wielded by you: owned=%s (expected true), wielding=%s (expected spear_masterwork_gold)" % [player.owned_weapons.has("staff_fine_wood"), player.current_weapon_base.get("id", "")])
	var bases: Array = DA.weapon_bases().map(func(b): return str(b.id))
	print("every base weapon is on offer: %s (expected club, spear, greatsword, hammer, battle_axe, dagger, bow, knuckle_gloves, hand_picks, staff, wand)" % [", ".join(bases)])
	var all_ok := true
	for b in bases:
		for tier in ["Broken", "Worn", "Fine", "Masterwork", "Legendary", "Mythic"]:
			for mat in ["wood", "steel", "gold", "bone", "silver", "obsidian"]:
				var v: Dictionary = DA.build_weapon(str(b), tier, mat)
				if v.is_empty():
					all_ok = false
	print("every base x tier x material builds a weapon: %s (expected true)" % all_ok)
	r = DA.remove_weapon(main, "spear_masterwork_gold")
	print("removing the wielded weapon puts the Club back: removed=%s (expected false), wielding=%s (expected club)" % [player.owned_weapons.has("spear_masterwork_gold"), player.current_weapon_base.get("id", "")])
	print("the Club cannot be removed: %s (expected false)" % DA.remove_weapon(main, "club").ok)
	DA.give_weapon(main, "hammer", "Fine", "steel", true)
	DA.set_weapon_smith_level(main, 3)
	print("Blacksmith level 3 on the weapon in hand: %d (expected 3), damage preview rose=%s (expected true)" % [player.get_weapon_upgrade_level("hammer_fine_steel"), player.weapon_damage_exact(player.current_weapon_base) > player.weapon_damage_exact(player.current_weapon_base, 0)])
	DA.set_rune(main, "leech")
	print("a rune on it: %s (expected leech)" % player.weapon_enchantments.get("hammer_fine_steel", ""))
	DA.set_rune(main, "")
	# armour
	DA.give_armor(main, "armor_gambeson", true)
	print("give and wear armour: owned=%s worn=%s (expected true true)" % [player.owned_armor.has("armor_gambeson"), player.equipped_armor.get("id", "") == "armor_gambeson"])
	DA.remove_armor(main, "armor_gambeson")
	print("removing worn armour puts the Jacket back: %s (expected armor_rags)" % player.equipped_armor.get("id", ""))
	DA.give_all(main, "armor")
	print("give all armour: owns %d (expected %d)" % [player.owned_armor.size(), load("res://scripts/Armor.gd").TIERS.size()])
	DA.remove_all(main, "armor")
	print("remove all armour: owns %d (expected 1, the Jacket)" % player.owned_armor.size())
	# shields, clothes, talismans
	DA.give_shield(main, "shield_heavy", true)
	print("give and raise a shield: %s (expected shield_heavy)" % player.equipped_shield.get("id", ""))
	DA.remove_shield(main, "shield_heavy")
	print("remove it: held=%s (expected empty), owned=%s (expected false)" % [player.equipped_shield.get("id", ""), player.owned_shields.has("shield_heavy")])
	DA.give_clothing(main, "cloth_cap", true)
	print("give and wear a cap: %s (expected cloth_cap)" % player.equipped_clothing.get("head", ""))
	DA.remove_clothing(main, "cloth_cap")
	print("remove it: head=%s (expected empty)" % player.equipped_clothing.get("head", ""))
	DA.give_talisman(main, "moss_charm", true)
	print("give and wear a talisman: owned=%s worn=%s (expected true true)" % [player.owned_talismans.has("moss_charm"), player.equipped_talismans.has("moss_charm")])
	DA.give_all_talismans(main)
	print("give all talismans: %d owned (expected %d, all of them)" % [player.owned_talismans.size(), load("res://scripts/Talismans.gd").ITEMS.size()])
	DA.remove_all(main, "talisman")
	print("remove them all: owned=%d worn=%d (expected 0 0)" % [player.owned_talismans.size(), player.equipped_talismans.size()])
	# potions, food, arrows, materials
	DA.give_potion(main, "potion_health", 3)
	DA.give_potion(main, "food_jerky", 2)
	print("potions and food ride in the same queue: potions=%d (expected 3), jerky=%d (expected 2), the HUD count=%d (expected 5)" % [DA.potion_count(main, "potion_health"), DA.potion_count(main, "food_jerky"), player.healing_items])
	DA.remove_potion(main, "potion_health", 2)
	print("remove 2 potions: %d left (expected 1)" % DA.potion_count(main, "potion_health"))
	DA.remove_potion(main, "potion_health", 99)
	print("removing more than you hold stops at none: %d (expected 0)" % DA.potion_count(main, "potion_health"))
	DA.give_arrows(main, "flame", 12)
	print("12 flame arrows: %d (expected 12, past the shop's cap of 10)" % player.owned_arrows.flame)
	DA.give_arrows(main, "flame", -20)
	print("taking more away than held stops at zero: %d (expected 0)" % player.owned_arrows.flame)
	DA.give_material(main, "dragon_scale", 6)
	print("6 dragon scales: %d (expected 6)" % player.material_count("dragon_scale"))
	DA.give_material(main, "dragon_scale", -2)
	print("take 2 away: %d (expected 4)" % player.material_count("dragon_scale"))
	DA.set_pelts(main, 3)
	DA.set_bait(main, 8)
	DA.set_rod(main, "rod_oak", true)
	print("pelts=%d bait=%d oak rod owned=%s (expected 3, 8, true)" % [player.pelts, player.bait, player.owned_rods.has("rod_oak")])
	# the Items tab itself
	menu.open()
	menu._select_tab("Items")
	await _frames(3)
	var v = menu.view
	print("the Items tab opens on Weapons with a card per base weapon: cards=%d (expected 10)" % v._cards.size())
	for cat in ["Armour", "Shields", "Clothes", "Talismans"]:
		v._on_category(cat)
		await _frames(3)
		print("%s: a card for every item: cards=%d (expected %d)" % [cat, v._cards.size(), {"Armour": load("res://scripts/Armor.gd").TIERS.size(), "Shields": 5, "Clothes": load("res://scripts/Clothing.gd").PIECES.size(), "Talismans": 38}[cat]])
	v._on_category("Armour")
	await _frames(3)
	v._on_pick(v._shown[3])
	await _frames(2)
	var wanted_id: String = str(v._shown[3].id)
	var give_btn = _find_button(v, "Give and wear")
	give_btn.pressed.emit()
	await _frames(2)
	print("picking an armour and pressing 'Give and wear': owned=%s worn=%s (expected true true)" % [player.owned_armor.has(wanted_id), player.equipped_armor.get("id", "") == wanted_id])
	print("the log strip says what happened: '%s' (expected a line about the armour)" % menu.history[menu.history.size() - 1].msg)
	menu.view._on_category("Talismans")
	await _frames(3)
	menu.view.s["search"] = "moss"
	menu.view._on_search("moss")
	await _frames(2)
	print("searching 'moss' narrows the talisman grid: %d card(s) (expected 1)" % menu.view._cards.size())
	menu.view.s["search"] = ""
	for cat in ["Potions", "Food", "Arrows", "Materials", "Smithing"]:
		menu.view._on_category(cat)
		await _frames(3)
		print("%s page builds: buttons=%d (expected > 3)" % [cat, _count_buttons(menu.view)])
	menu.close()
	DA.remove_all(main, "weapon")
	DA.remove_all(main, "armor")

# ---------------------------------------------------------------------------------------------------------------------------
# PARTY
# ---------------------------------------------------------------------------------------------------------------------------

func _section_party() -> void:
	print("--- party ---")
	player.max_party_slots = 2
	var r: Dictionary = DA.recruit(main, "knight", false)
	var r2: Dictionary = DA.recruit(main, "druid", false)
	print("recruit two: %s %s, party=%d (expected true true, 2)" % [r.ok, r2.ok, player.party.size()])
	var r3: Dictionary = DA.recruit(main, "rogue", false)
	print("a third refused when the party is full: ok=%s (expected false), '%s'" % [r3.ok, r3.msg])
	r3 = DA.recruit(main, "rogue", true)
	print("...but the override raises the limit just enough: ok=%s (expected true), party=%d (expected 3), slots=%d (expected 3)" % [r3.ok, player.party.size(), player.max_party_slots])
	for kind in ["wolf", "guardian", "marksman", "necromancer", "brawler", "shaman"]:
		DA.recruit(main, kind, true)
	var kinds: Array = player.party.map(func(m): return m.kind)
	print("every kind of member can be recruited: %d members (expected 9): %s" % [player.party.size(), ", ".join(kinds)])
	var knight = null
	var wolf = null
	var druid = null
	for m in player.party:
		if m.kind == "knight":
			knight = m
		elif m.kind == "wolf":
			wolf = m
		elif m.kind == "druid":
			druid = m
	r = DA.set_member_level(main, knight.id, 5)
	print("knight to level 5: level=%d (expected 5), picks=%d (expected 4)" % [knight.level, knight.picks])
	var hp_before: float = knight.bonus.hp
	DA.grant_picks(main, knight.id, 3)
	print("grant 3 picks: %d (expected 7)" % knight.picks)
	DA.spend_pick(main, knight.id, "hp")
	print("spend one on HP: picks=%d (expected 6), HP bonus rose=%s (expected true)" % [knight.picks, knight.bonus.hp > hp_before])
	DA.set_member_level(main, knight.id, 2)
	print("lowering starts the member over: level=%d (expected 2), picks=%d (expected 1)" % [knight.level, knight.picks])
	r = DA.set_member_level(main, wolf.id, 5)
	print("a wolf never levels: ok=%s (expected false), level=%d (expected 1)" % [r.ok, wolf.level])
	# gear
	r = DA.equip_member(main, knight.id, "weapon", "greatsword_fine_steel")
	print("hand the knight a greatsword (granted to you first): ok=%s (expected true), holds=%s (expected greatsword_fine_steel), you own it=%s (expected true)" % [r.ok, knight.weapon_id(), player.owned_weapons.has("greatsword_fine_steel")])
	r = DA.equip_member(main, druid.id, "weapon", "greatsword_fine_steel")
	print("giving the same weapon to the druid takes it from the knight: ok=%s (expected true), druid=%s, knight=%s (expected empty)" % [r.ok, druid.weapon_id(), knight.weapon_id()])
	r = DA.equip_member(main, druid.id, "armor", "armor_gambeson")
	print("armour: ok=%s (expected true), druid wears %s (expected armor_gambeson)" % [r.ok, druid.armor_id()])
	r = DA.equip_member(main, druid.id, "shield", "shield_heavy")
	print("shield: ok=%s (expected true), druid holds %s (expected shield_heavy)" % [r.ok, druid.shield_id()])
	r = DA.equip_member(main, druid.id, "talisman", "moss_charm")
	print("talisman: ok=%s (expected true), druid wears %s" % [r.ok, str(druid.talisman_ids())])
	r = DA.equip_member(main, wolf.id, "weapon", "dagger_fine_steel")
	print("a wolf carries nothing: ok=%s (expected false)" % r.ok)
	var marks = null
	for m in player.party:
		if m.kind == "marksman":
			marks = m
	r = DA.equip_member(main, marks.id, "weapon", "greatsword_fine_steel")
	print("the Marksman will only use a bow: ok=%s (expected false), '%s'" % [r.ok, r.msg])
	player.grant_weapon("hammer_fine_steel")
	player._equip_weapon(load("res://scripts/Weapons.gd").get_owned_variant("hammer_fine_steel"))
	r = DA.equip_member(main, knight.id, "weapon", "hammer_fine_steel")
	print("what you are wielding stays yours: ok=%s (expected false), '%s'" % [r.ok, r.msg])
	DA.unequip_member(main, druid.id, "weapon")
	DA.unequip_member(main, druid.id, "talisman")
	print("take gear off: weapon='%s' talismans=%s (expected empty, [])" % [druid.weapon_id(), str(druid.talisman_ids())])
	# heal / dismiss
	r = DA.heal_party(main)
	print("heal out of battle resets the wolf's faints: %s, faints=%d (expected 0)" % [r.ok, wolf.faints])
	r = DA.dismiss(main, wolf.id)
	print("dismiss the wolf: ok=%s (expected true), party=%d (expected 8)" % [r.ok, player.party.size()])
	player.party_members.append({"name": "Knight", "dmg_mult": 0.75})
	r = DA.remove_mercenary(main, 0)
	print("the older flat companions can go too: %s, left=%d (expected true, 0)" % [r.ok, player.party_members.size()])
	r = DA.dismiss_all(main)
	print("dismiss everyone: party=%d (expected 0)" % player.party.size())
	# the tab
	DA.recruit(main, "knight", true)
	DA.recruit(main, "druid", true)
	menu.open()
	menu._select_tab("Party")
	await _frames(3)
	var press_ok: bool = _press("Necromancer")
	await _frames(2)
	print("the Party tab's Recruit buttons recruit: pressed=%s (expected true), party=%d (expected 3)" % [press_ok, player.party.size()])
	var found_level := false
	for lab in _labels(menu.view):
		if lab.text.contains("Level"):
			found_level = true
	print("the picked member's sheet has a Level row: %s (expected true)" % found_level)
	menu.close()
	DA.dismiss_all(main)
	player.max_party_slots = 2

# ---------------------------------------------------------------------------------------------------------------------------
# WORLD
# ---------------------------------------------------------------------------------------------------------------------------

func _stands_clear() -> bool:
	return DW.spot_is_clear(main, player.global_position)

# A frame for the physics world to take in what was just built.
func _settle() -> void:
	await physics_frame
	await physics_frame

func _section_world() -> void:
	print("--- world ---")
	var places: Array = DW.destinations(main, "Places")
	print("%d places listed (expected %d: the map's landmarks)" % [places.size(), WorldMapScript.landmarks.size()])
	var failures: Array = []
	for entry in places:
		var r: Dictionary = DW.go(main, entry)
		await _settle()
		if not r.ok or not _stands_clear() or WorldMapScript.is_blocked(player.global_position):
			failures.append(str(entry.name))
	print("every landmark can be teleported to and you stand clear of walls and water: failures=%s (expected [])" % [str(failures)])
	var r: Dictionary = DW.go(main, places[1])
	print("teleport to %s: ok=%s (expected true), asks the menu to close=%s (expected true)" % [places[1].name, r.ok, r.get("close", false)])
	print("the game noticed where you are: region=%s (expected castle-town ground, great_expanse)" % main.current_region_id)
	r = DW.go(main, places[3])
	print("teleport to the HeartWood: ok=%s, region=%s (expected heartwood_grove or woods)" % [r.ok, main.current_region_id])
	var regions: Array = DW.destinations(main, "Regions")
	failures = []
	for entry in regions:
		var rr: Dictionary = DW.go(main, entry)
		await _settle()
		if not rr.ok or not _stands_clear():
			failures.append(str(entry.id))
	print("%d walkable regions listed, every one reachable and clear: failures=%s (expected [])" % [regions.size(), str(failures)])
	var rooms: Array = DW.destinations(main, "Rooms")
	failures = []
	var tried := 0
	for i in range(0, rooms.size(), 4):
		var rr: Dictionary = DW.go(main, rooms[i])
		await _settle()
		tried += 1
		if not rr.ok or not _stands_clear():
			failures.append(str(rooms[i].id))
	print("%d rooms listed; %d sampled, all reachable and clear: failures=%s (expected [])" % [rooms.size(), tried, str(failures)])
	var town: Array = DW.destinations(main, "Town")
	print("%d town venues listed (expected %d)" % [town.size(), main.town_building_positions.size()])
	r = DW.go(main, town[0])
	print("teleport to %s: ok=%s (expected true), in town=%s (expected true)" % [town[0].name, r.ok, main._in_town_area(player.global_position)])
	# interiors
	var inside: Array = DW.destinations(main, "Inside")
	print("%d building interiors listed (expected %d)" % [inside.size(), InteriorScript.DEFS.size()])
	r = DW.go(main, inside[0])
	await create_timer(0.8).timeout
	print("walk into the %s: ok=%s (expected true), inside=%s (expected true)" % [inside[0].name, r.ok, main.in_interior])
	r = DW.go(main, places[0])
	print("travelling from inside a building is refused with a way out: ok=%s (expected false), '%s'" % [r.ok, r.msg])
	r = DW.leave_interior(main)
	await create_timer(0.8).timeout
	print("leave the building: ok=%s (expected true), inside=%s (expected false)" % [r.ok, main.in_interior])
	failures = []
	for entry in inside:
		var ri: Dictionary = DW.go(main, entry)
		await create_timer(0.7).timeout
		if not ri.ok or not main.in_interior:
			failures.append(str(entry.interior))
		DW.leave_interior(main)
		await create_timer(0.7).timeout
		if main.in_interior:
			failures.append("stuck in " + str(entry.interior))
	print("every one of the %d interiors can be entered and left: failures=%s (expected [])" % [inside.size(), str(failures)])
	# map, difficulty, enemies
	DW.reveal_map(main)
	print("reveal the whole map: rooms visited=%d (expected %d), places found=%d (expected > 30)" % [main.visited_rooms.size(), RoomsScript.rooms.size(), player.discovered_locations.size()])
	DW.hide_map(main)
	print("hide it again: visited=%d found=%d (expected 0 0)" % [main.visited_rooms.size(), player.discovered_locations.size()])
	r = DW.set_difficulty(main, "hard")
	print("difficulty hard: id=%s mult=%s (expected hard, 1.75)" % [player.difficulty_id, player.difficulty_mult])
	DW.set_difficulty(main, "normal")
	DW.clear_enemies(main)
	await _frames(2)
	r = DW.spawn_near(main, "Orc", 3, 4, true)
	await _frames(1)
	var orcs: Array = []
	for e in main.get_tree().get_nodes_in_group("enemies"):
		if e.get_display_name() == "Orc":
			orcs.append(e)
	print("spawn 3 elite Orcs at danger 4: ok=%s, found %d (expected 3), all elite=%s (expected true), tier power=%s (expected %s)" % [r.ok, orcs.size(), orcs.all(func(e): return e.is_elite), orcs[0].get_meta("region_tier_power"), WorldMapScript.tier_power(4)])
	print("enemies_alive counts them: %d (expected >= 3)" % main.enemies_alive)
	r = DW.clear_enemies(main)
	await _frames(2)
	print("remove all enemies: left=%d (expected 0), enemies_alive=%d (expected 0)" % [main.get_tree().get_nodes_in_group("enemies").filter(func(e): return not e.is_queued_for_deletion()).size(), main.enemies_alive])
	var names: Array = DW.enemy_list(main).map(func(e): return str(e.name))
	var missing: Array = []
	for n in main.ENEMY_TRAITS:
		if not names.has(str(n)):
			missing.append(str(n))
	print("every enemy in Main.ENEMY_TRAITS can be picked: missing=%s (expected [])" % [str(missing)])
	r = DW.unstick(main)
	print("unstick: ok=%s (expected true)" % r.ok)
	DW.go(main, DW.destinations(main, "Places")[0])
	DW.clear_enemies(main)
	await _frames(2)
	# the tab
	menu.open()
	menu._select_tab("World")
	await _frames(3)
	var listed := 0
	for c in menu.view._list.get_children():
		listed += 1
	print("the World tab lists the places: %d rows (expected %d)" % [listed, places.size()])
	var go_button = _find_button(menu.view._list, "The Castle Town")
	go_button.pressed.emit()
	await _frames(3)
	print("pressing a name teleports and closes the menu: closed=%s (expected true), in town=%s (expected true), paused=%s (expected false)" % [not menu.visible, main._in_town_area(player.global_position), paused])
	DW.go(main, DW.destinations(main, "Places")[0])

# ---------------------------------------------------------------------------------------------------------------------------
# BATTLE
# ---------------------------------------------------------------------------------------------------------------------------

func _section_battle() -> void:
	print("--- battle ---")
	DW.clear_enemies(main)
	var r: Dictionary = DB.start_battle(main, [{"name": "Goblin", "count": 2}], 1, false)
	await _frames(2)
	print("start a battle against 2 Goblins: ok=%s (expected true), in battle=%s (expected true), enemies=%d (expected 2), paused=%s (expected true), menu closed=%s (expected true)" % [r.ok, main.in_battle, main.battle_units.size(), paused, r.get("close", false)])
	var hp_tier1: int = int(main.battle_units[0].max_hp)
	await _wait_for_hero()
	print("the tutorial is not forced on a debug battle: %s (expected false)" % main.tutorial_active)
	r = DB.start_battle(main, [{"name": "Goblin", "count": 1}], 1, false)
	print("a second battle is refused while one is on: ok=%s (expected false)" % r.ok)
	# statuses
	var t: Dictionary = {}
	r = DB.set_status(main, "hero", "poison", 4)
	print("poison on you: turns=%d (expected 4), dmg=%d (expected >= 1), the card lists it=%s (expected true)" % [main.player_poison_turns, main.player_poison_dmg, DB.status_list(main, "hero").any(func(e): return e.id == "poison")])
	DB.set_status(main, "hero", "poison", 0, true)
	print("take it off: turns=%d (expected 0)" % main.player_poison_turns)
	for id in DB.HERO_STATUSES:
		DB.set_status(main, "hero", id, 2)
	var listed: Array = DB.status_list(main, "hero").map(func(e): return e.id)
	print("every hero status can be put on: %d of %d show on the card (expected equal)" % [listed.size(), DB.HERO_STATUSES.size()])
	DB.clear_statuses(main, "hero")
	print("clear all: %d left (expected 0)" % DB.status_list(main, "hero").size())
	for id in DB.ENEMY_STATUSES:
		DB.set_status(main, "enemy:0", id, 2)
	listed = DB.status_list(main, "enemy:0").map(func(e): return e.id)
	print("every enemy status can be put on: %d of %d show on the card (expected equal)" % [listed.size(), DB.ENEMY_STATUSES.size()])
	DB.set_status(main, "all_enemies", "frozen", 3)
	print("a status on all enemies: both frozen=%s (expected true)" % main.battle_units.all(func(u): return int(u.get("frozen_turns", 0)) == 3))
	DB.clear_statuses(main, "all_enemies")
	print("clear them: %s (expected true)" % main.battle_units.all(func(u): return int(u.get("frozen_turns", 0)) == 0 and not u.get("burning", false)))
	r = DB.set_enemy_hp(main, 0, 1)
	print("hurt an enemy: HP=%d (expected 1)" % main.battle_units[0].hp)
	r = DB.kill_enemy(main, 0)
	print("kill one enemy: %s, left=%d (expected 1)" % [r.ok, main.battle_units.size()])
	player.health = 1
	player.stamina = 0
	r = DB.heal_everyone(main)
	print("heal everyone: HP=%d/%d stamina=%d/%d (expected both full)" % [player.health, player.max_health, player.stamina, player.max_stamina])
	main.battle_player_moves_left = 0
	DB.refill_turn(main)
	print("refill my turn: movement=%d (expected > 0)" % main.battle_player_moves_left)
	var kills_before: int = main.run_kills_by_name.get("Goblin", 0)
	r = DB.win_now(main)
	await _frames(2)
	print("win now: ok=%s (expected true), battle over=%s (expected true), the last goblin counted as a kill=%s (expected true)" % [r.ok, not main.in_battle, main.run_kills_by_name.get("Goblin", 0) > kills_before])
	print("...the game is not left paused unless the kill's XP opened the level-up picker: paused=%s, picker=%s (expected equal)" % [paused, main.choosing_stat])
	await _clear_pending()
	print("...and once that is answered the game runs: paused=%s (expected false)" % paused)
	# danger tier scales enemies
	r = DB.start_battle(main, [{"name": "Goblin", "count": 1}], 5, false)
	var hp_tier5: int = int(main.battle_units[0].max_hp)
	await _wait_for_hero()
	print("danger tier 5 makes enemies tougher than tier 1: %d vs %d HP (expected more)" % [hp_tier5, hp_tier1])
	DB.win_now(main)
	await _frames(2)
	main.choosing_stat = true
	r = DB.start_battle(main, [{"name": "Goblin", "count": 1}], 1, false)
	print("a battle is refused while the level-up picker is open: ok=%s (expected false), '%s'" % [r.ok, r.msg])
	main.choosing_stat = false
	await _clear_pending()
	r = DB.start_battle(main, [{"name": "Goblin", "count": 1}], 1, true, 2.0)
	var hp_special: int = int(main.battle_units[0].max_hp)
	await _wait_for_hero()
	print("elite and x2 strength: %d HP vs %d plain (expected over twice as many), elite flag=%s (expected true)" % [hp_special, hp_tier1, main.battle_units[0].is_elite])
	print("...over twice: %s (expected true)" % (hp_special > hp_tier1 * 2))
	DB.win_now(main)
	await _frames(2)
	await _clear_pending()
	# enemy level: as strong as for a hero of that level, whatever yours is
	# (the level scale follows the enemy level asked for; the early-game HP bonus still follows the hero's real level at the time)
	var hero_lv_a: int = player.level
	r = DB.start_battle(main, [{"name": "Orc", "count": 1}], 1, false, 1.0, 11)
	var orc_l11: int = int(main.battle_units[0].max_hp)
	await _wait_for_hero()
	DB.win_now(main)
	await _frames(2)
	await _clear_pending()
	var hero_lv_b: int = player.level
	r = DB.start_battle(main, [{"name": "Orc", "count": 1}], 1, false, 1.0, 1)
	var orc_l1: int = int(main.battle_units[0].max_hp)
	await _wait_for_hero()
	DB.win_now(main)
	await _frames(2)
	await _clear_pending()
	var want_l11: int = int(round(20.0 * 1.5 * (1.0 + main.EARLY_GAME_HP_BONUS / float(hero_lv_a))))
	var want_l1: int = int(round(20.0 * 1.0 * (1.0 + main.EARLY_GAME_HP_BONUS / float(hero_lv_b))))
	print("enemy level 11 and 1 make an Orc (20 HP) %d and %d HP (expected %d and %d: 30 and 20 at the level scale, times the early-game bonus for your own level %d then %d)" % [orc_l11, orc_l1, want_l11, want_l1, hero_lv_a, hero_lv_b])
	# allies in the battle
	DA.recruit(main, "knight", true)
	DA.recruit(main, "druid", true)
	r = DB.start_battle(main, [{"name": "Orc", "count": 1}], 1, false)
	await _wait_for_hero()
	main.battle_allies[0]["hp"] = 1
	r = DB.set_status(main, "ally:0", "stealth", 3)
	print("a status on an ally: %s, stealth turns=%d (expected true, 3)" % [r.ok, main.battle_allies[0].stealth_turns])
	r = DB.set_status(main, "all_allies", "defending", 1)
	print("on all allies: %s (expected true)" % main.battle_allies.all(func(a): return a.get("defending", false)))
	DA.heal_party(main)
	print("heal the party in a battle: ally HP=%d/%d (expected full)" % [main.battle_allies[0].hp, main.battle_allies[0].max_hp])
	var ally = main.battle_allies[1]
	ally["hp"] = 0
	main._remove_fallen_allies()
	print("an ally is downed: downed=%d (expected 1)" % main.battle_downed_allies.size())
	r = DA.revive_party(main)
	print("revive: %s, downed=%d (expected 0), fighting allies=%d (expected 2)" % [r.ok, main.battle_downed_allies.size(), main.battle_allies.size()])
	DB.win_now(main)
	await _frames(2)
	await _clear_pending()
	DA.dismiss_all(main)
	# every enemy there is
	var failures: Array = []
	for name in DW.enemy_list(main).map(func(e): return str(e.name)):
		var rr: Dictionary = DB.start_battle(main, [{"name": name, "count": 1}], 3, false)
		if not rr.ok or main.battle_units.size() != 1:
			failures.append(name)
			continue
		await _wait_for_hero()
		var wr: Dictionary = DB.win_now(main)
		await _frames(2)
		await _clear_pending()
		if not wr.ok or main.in_battle:
			failures.append("win " + name)
	print("a battle can be started and won against each of the %d enemies: failures=%s (expected [])" % [DW.enemy_list(main).size(), str(failures)])
	# a battle in the middle of an enemy turn is refused politely
	r = DB.win_now(main)
	print("win now with no battle: ok=%s (expected false), '%s'" % [r.ok, r.msg])
	# the tab, with a battle going
	DB.start_battle(main, [{"name": "Wolf", "count": 2}], 1, false)
	await _wait_for_hero()
	menu.open()
	menu._select_tab("Battle")
	await _frames(3)
	var enemies_rows := 0
	for l in _labels(menu.view):
		if l.text.contains("HP") and l.text.contains("Wolf"):
			enemies_rows += 1
	print("the Battle tab lists the enemies on the field: %d rows (expected 2)" % enemies_rows)
	var win_btn = _find_button(menu.view, "Win now")
	win_btn.pressed.emit()
	await _frames(3)
	print("pressing Win now ends the battle and closes the menu: in battle=%s (expected false), menu visible=%s (expected false), paused=%s (expected %s: paused only if the win opened a pop-up)" % [main.in_battle, menu.visible, paused, main.choosing_stat or main.event_choosing])
	await _clear_pending()
	print("...after answering any pop-up the game runs: paused=%s (expected false)" % paused)
	# paused state follows a battle that started while the menu was open
	menu.open()
	menu._select_tab("Battle")
	await _frames(2)
	var start = _find_button(menu.view, "Start battle")
	start.pressed.emit()
	await _frames(3)
	print("starting from the tab: in battle=%s (expected true), menu closed=%s (expected true), paused=%s (expected true: the battle's own pause)" % [main.in_battle, not menu.visible, paused])
	await _wait_for_hero()
	# the menu opened INSIDE a battle: pause restored to the battle's
	menu.open()
	menu.close()
	print("open and close inside a battle: still paused=%s (expected true), still in battle=%s (expected true)" % [paused, main.in_battle])
	menu.open()
	DB.win_now(main)
	await _frames(2)
	print("won while the menu was open: the game stays frozen under it: paused=%s (expected true)" % paused)
	var popup_up: bool = main.choosing_stat or main.event_choosing
	menu.close()
	print("...and closing it lets the game go (unless the win opened a pop-up, which keeps it paused): paused=%s (expected %s), in battle=%s (expected false)" % [paused, popup_up, main.in_battle])
	await _clear_pending()
	print("...answered, the game runs: paused=%s (expected false)" % paused)

# ---------------------------------------------------------------------------------------------------------------------------
# PROGRESS
# ---------------------------------------------------------------------------------------------------------------------------

func _section_progress() -> void:
	print("--- progress ---")
	var rows: Array = DP.upgrade_rows()
	print("the Church list is read from SaveData.UPGRADES: %d rows (expected %d)" % [rows.size(), SaveDataScript.UPGRADES.size()])
	var first_id: String = str(rows[0].id)
	var r: Dictionary = DP.grant_upgrade(main, first_id)
	print("grant one level of '%s': ok=%s, saved level=%d (expected 1)" % [rows[0].name, r.ok, DP.upgrade_level(first_id)])
	r = DP.remove_upgrade(main, first_id)
	print("remove it: level=%d (expected 0)" % DP.upgrade_level(first_id))
	r = DP.max_all_upgrades(main)
	var all_max := true
	for row in DP.upgrade_rows():
		if int(row.level) != DP.upgrade_max(str(row.id)):
			all_max = false
	print("max all: ok=%s, every upgrade at its top=%s (expected true), the run picked them up: bonuses=%d (expected > 0)" % [r.ok, all_max, SaveDataScript.get_applied_bonuses().values().filter(func(v): return float(v) > 0.0).size()])
	r = DP.reset_upgrades(main)
	print("reset all: owned=%d (expected 0), Essence kept=%d (expected 77)" % [SaveDataScript.load_data().get("upgrades", {}).size(), DA.essence(main)])
	# lifetime flags
	var flags: Array = DP.lifetime_flags()
	print("lifetime flags listed: %s (expected tutorial, game beaten, Druid)" % [", ".join(flags.slice(0, 3).map(func(f): return str(f.key)))])
	DP.set_lifetime_flag("game_completed_ever", true)
	print("game beaten flag on: %s (expected true)" % SaveDataScript.is_game_completed_ever())
	DP.set_lifetime_flag("game_completed_ever", false)
	DP.set_lifetime_flag("druid_unlocked_ever", true)
	print("Druid freed flag on: %s (expected true)" % SaveDataScript.is_druid_unlocked())
	DP.set_lifetime_flag("druid_unlocked_ever", false)
	DP.set_tutorial_done(main, false)
	print("tutorial back on: done=%s (expected false)" % SaveDataScript.is_tutorial_completed_ever())
	DP.set_tutorial_done(main, true)
	print("tutorial done: %s (expected true)" % SaveDataScript.is_tutorial_completed_ever())
	SaveDataScript.mark_unlock_seen("x")
	DP.reset_seen_unlocks()
	print("one-time pop-ups reset: seen=%s (expected false)" % SaveDataScript.is_unlock_seen("x"))
	# spells and the Dojo
	# (an upgrade belongs to its caster, a party member)
	var spell_member = player.party[0] if not player.party.is_empty() else player.recruit("druid")
	r = DP.set_spell_level(main, spell_member, "druid_heal", 2)
	print("a spell to EX: level=%d (expected 2)" % player.spell_level_of(spell_member, "druid_heal"))
	DP.set_all_spells(main, 1)
	var spell_levels: Array = []
	for s in load("res://scripts/SpellUpgrades.gd").SPELLS:
		spell_levels.append(player.spell_level_of(spell_member, str(s.id)))
	print("all spells to +: %s (expected twelve 1s)" % str(spell_levels))
	DP.set_all_spells(main, 0)
	DP.learn_all_specials(main)
	print("learn every special: %d learned (expected > 20)" % player.learned_specials.size())
	DP.forget_all_specials(main)
	print("forget them: %d (expected 0)" % player.learned_specials.size())
	# the Beastiary
	DP.reveal_beastiary()
	print("Beastiary reveal all: seen %d of %d (expected equal)" % [DP.beastiary_seen_count(), DP.beastiary_names().size()])
	DP.hide_beastiary()
	print("hide all: seen=%d (expected 0)" % DP.beastiary_seen_count())
	# the tab
	menu.open()
	menu._select_tab("Progress")
	await _frames(3)
	print("the Progress tab lists every upgrade: rows=%d (expected %d)" % [menu.view._church_list.get_child_count(), SaveDataScript.UPGRADES.size()])
	_press("Max all")
	await _frames(2)
	print("its Max all button maxes them: %s (expected true)" % [DP.upgrade_level(first_id) == DP.upgrade_max(first_id)])
	menu.close()
	DP.reset_upgrades(main)

# ---------------------------------------------------------------------------------------------------------------------------
# GAME
# ---------------------------------------------------------------------------------------------------------------------------

func _section_game() -> void:
	print("--- game ---")
	DP.set_time_scale(2.0)
	print("game speed x2: %s (expected 2)" % Engine.time_scale)
	DP.set_time_scale(0.01)
	print("a silly speed is clamped: %s (expected 0.05)" % Engine.time_scale)
	DP.set_time_scale(1.0)
	DP.set_collision_view(main, true)
	print("collision view on: %s (expected true)" % DP.collision_view_on(main))
	DP.set_collision_view(main, false)
	print("...off: %s (expected false)" % DP.collision_view_on(main))
	menu.set_overlay(true)
	menu.open()
	await _frames(3)
	menu.close()
	await _frames(2)
	print("the info read-out shows facts: '%s' (expected FPS, position, region)" % menu.overlay_label.text)
	menu.set_overlay(false)
	var dump: String = DP.state_dump(main)
	var parsed = JSON.parse_string(dump)
	print("the state dump is valid JSON with the hero, party, world and slot: %s (expected true)" % [parsed is Dictionary and parsed.has("hero") and parsed.has("party") and parsed.has("world") and parsed.has("slot")])
	var r: Dictionary = DP.print_state(main)
	print("print state: %s (expected true), '%s'" % [r.ok, r.msg])
	# the slot
	SaveDataScript.save_data({"essence": 321, "upgrades": {}, "best_wave": 4, "difficulty": "hard", "name": "Backup me"})
	r = DP.backup_slot()
	print("back up the slot: %s, has a backup=%s (expected true)" % [r.ok, DP.has_backup()])
	DA.set_essence(main, 5)
	r = DP.restore_slot(main)
	print("restore it: %s, Essence back to %d (expected 321), name kept '%s' (expected Backup me)" % [r.ok, DA.essence(main), SaveDataScript.load_data().get("name", "")])
	DA.set_essence(main, 999)
	DP.max_all_upgrades(main)
	r = DP.reset_slot(main)
	var after: Dictionary = SaveDataScript.load_data()
	print("reset the slot: Essence=%d (expected 0), upgrades=%d (expected 0), name='%s' difficulty=%s (expected Backup me, hard kept)" % [int(after.essence), after.upgrades.size(), after.name, after.difficulty])
	print("the slot summary reads: '%s'" % DP.slot_summary())
	# cheats switch off with one button
	DA.set_god_mode(main, true)
	DA.set_speed_mult(main, 3.0)
	DP.set_time_scale(4.0)
	DA.reset_cheats(main)
	print("every cheat off: god=%s speed=%s time=%s (expected false 1 1)" % [player.debug_god_mode, player.debug_speed_mult, Engine.time_scale])
	# turning the setting off kills every cheat and closes the menu
	DA.set_god_mode(main, true)
	menu.open()
	await _frames(2)
	settings.debug_menu_enabled = false
	await _frames(3)
	print("switching the setting off while it is open closes it: visible=%s (expected false), unpaused=%s (expected true)" % [menu.visible, not paused])
	print("...and ends every cheat: god=%s (expected false)" % player.debug_god_mode)
	settings.debug_menu_enabled = true
	DW.go(main, DW.destinations(main, "Places")[0])

# ---------------------------------------------------------------------------------------------------------------------------
# A user's path through the buttons
# ---------------------------------------------------------------------------------------------------------------------------

func _section_ui_flows() -> void:
	print("--- through the buttons ---")
	DA.set_level(main, 1)
	menu.open()
	menu._select_tab("Player")
	await _frames(3)
	_press("To next level")
	await _frames(2)
	print("Player tab > To next level: level=%d (expected 2)" % player.level)
	if main.choosing_stat:
		main._on_levelup_choice_pressed("vigor")
	_press("+100")
	await _frames(2)
	print("Player tab > +100 XP: the log says '%s'" % menu.history[menu.history.size() - 1].msg)
	player.health = 3
	_press("Heal fully")
	await _frames(2)
	print("Player tab > Heal fully: HP=%d/%d (expected full)" % [player.health, player.max_health])
	var god = _find_button(menu.view, "Off")
	var god_toggle_found: bool = god != null
	print("the cheat switches are there: %s (expected true)" % god_toggle_found)
	# a number typed into a field
	var set_coins_line: LineEdit = null
	for c in _all_children(menu.view):
		if c is LineEdit:
			set_coins_line = c
			break
	print("number fields are text boxes: %s (expected true)" % [set_coins_line != null])
	# tab flow for items: pick a weapon base, a tier, a material and give it
	menu._select_tab("Items")
	await _frames(3)
	menu.view.s["cat"] = "Weapons"      # (the tab remembers the page it was left on)
	menu.view.s["weapon"] = {"base": "greatsword", "tier": "Legendary", "material": "obsidian"}
	menu.view.s["sel"] = {"Weapons": "greatsword"}
	menu.view.refresh()
	await _frames(3)
	_press("Give")
	await _frames(2)
	print("Items > Give a Legendary obsidian Greatsword: owned=%s (expected true)" % player.owned_weapons.has("greatsword_legendary_obsidian"))
	_press("Remove")
	await _frames(2)
	print("Items > Remove: owned=%s (expected false)" % player.owned_weapons.has("greatsword_legendary_obsidian"))
	menu.close()
	# the pause when the menu opens in the middle of a level-up
	player.gain_xp(500)
	var picking: bool = main.choosing_stat
	menu.open()
	menu.close()
	print("opened and closed during the level-up picker: still picking=%s paused=%s (expected true true)" % [main.choosing_stat, paused])
	if main.choosing_stat:
		main._on_levelup_choice_pressed("vigor")
	print("picking a stat afterwards unpauses: paused=%s (expected false)" % paused)

# The old arena world (what a few older tests still drive): nowhere to travel to, but the World tab offers its world buttons.
func _section_old_arena() -> void:
	print("--- the old arena world ---")
	settings.debug_menu_enabled = true
	var arena = load("res://Main.tscn").instantiate()
	arena.regional_world = false
	root.add_child(arena)
	await physics_frame
	await physics_frame
	main = arena
	player = arena.player
	menu = arena.debug_menu
	var r: Dictionary = DW.go(main, {"kind": "pos", "pos": Vector2(1000, 1000), "name": "somewhere"})
	print("teleporting in the old arena is refused with a reason: ok=%s (expected false), '%s'" % [r.ok, r.msg])
	menu.open()
	menu._select_tab("World")
	await _frames(3)
	var index_before: int = main.current_world_index
	var next_ok: bool = _press("Next world")
	await _frames(3)
	print("the World tab offers 'Next world' there: pressed=%s (expected true), world index %d -> %d (expected +1)" % [next_ok, index_before, main.current_world_index])
	var prev_ok: bool = _press("Previous world")
	await _frames(3)
	print("...and 'Previous world': pressed=%s (expected true), back to %d (expected %d)" % [prev_ok, main.current_world_index, index_before])
	menu.close()
	arena.queue_free()
	await _frames(2)
	paused = false

func _all_children(node: Node) -> Array:
	var out: Array = []
	for c in node.get_children():
		out.append(c)
		out.append_array(_all_children(c))
	return out

# ---------------------------------------------------------------------------------------------------------------------------
# The Sandbox opens it on its own; a loss
# ---------------------------------------------------------------------------------------------------------------------------

func _section_sandbox_and_loss() -> void:
	print("--- the Sandbox and a loss ---")
	# a lost battle (on this run, last, since it ends the run)
	DW.clear_enemies(main)
	DB.start_battle(main, [{"name": "Goblin", "count": 1}], 1, false)
	await _wait_for_hero()
	var r: Dictionary = DB.lose_now(main)
	await _frames(2)
	print("lose now: ok=%s (expected true), game over=%s (expected true), in battle=%s (expected false)" % [r.ok, main.game_over, main.in_battle])
	r = DB.lose_now(main)
	print("losing twice is refused: ok=%s (expected false)" % r.ok)
	main.queue_free()
	await _frames(3)
	paused = false
	# the Sandbox: F1 works with the setting off
	settings.debug_menu_enabled = false
	SaveDataScript.sandbox_active = true
	SaveDataScript.sandbox_data = {}
	main = await _fresh_main()
	player = main.player
	menu = main.debug_menu
	print("in the Sandbox the menu is on whatever the setting says: is_enabled=%s (expected true), setting=%s (expected false)" % [DebugMenuScript.is_enabled(), settings.debug_menu_enabled])
	_key(KEY_F1)
	await _frames(2)
	_key(KEY_F1, false)
	await _frames(2)
	print("F1 opens it over the Sandbox's own panel: visible=%s (expected true), sandbox panel visible=%s (expected true)" % [menu.visible, main.sandbox_panel.visible])
	var layer_ok: bool = menu.layer > main.sandbox_panel.layer
	print("it sits above the Sandbox panel: %s (expected true)" % layer_ok)
	menu._select_tab("Game")
	await _frames(2)
	var game_text := ""
	for l in _labels(menu.view):
		game_text += l.text + "\n"
	print("the Game tab says the Sandbox's slot is in memory: %s (expected true)" % game_text.contains("Sandbox"))
	var backup_file_before: String = FileAccess.get_file_as_string("user://test_save_data_slot_1_backup.json") if FileAccess.file_exists("user://test_save_data_slot_1_backup.json") else ""
	r = DP.backup_slot()
	var backup_file_after: String = FileAccess.get_file_as_string("user://test_save_data_slot_1_backup.json") if FileAccess.file_exists("user://test_save_data_slot_1_backup.json") else ""
	print("a Sandbox backup stays in memory, the real backup file is untouched: ok=%s (expected true), file unchanged=%s (expected true), '%s'" % [r.ok, backup_file_before == backup_file_after, r.msg])
	_key(KEY_F1)
	await _frames(2)
	_key(KEY_F1, false)
	await _frames(1)
	print("F1 closes it again; the Sandbox panel is still up: menu=%s (expected false), panel=%s (expected true), paused=%s (expected true)" % [menu.visible, main.sandbox_panel.visible, paused])
	SaveDataScript.sandbox_active = false
	main.queue_free()
	await _frames(2)
	paused = false
