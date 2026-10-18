extends SceneTree

# The title screen's walk: the splash ("Press anything to continue"), Select a File (three cards), the main menu, and the smaller screens.
# Also pins two things that went wrong before: no screen says "Wave", and the framed panels never change size when the words in them do.

func _all_text(node: Node, out: Array) -> void:
	if node is Label or node is Button:
		out.append(str(node.text))
	elif node is LineEdit:
		out.append(str(node.placeholder_text))
		out.append(str(node.text))
	for c in node.get_children():
		_all_text(c, out)

# The words on every screen of the title (not the Beastiary overlay, which is its own screen).
func _all_text_of_screens(title: Node, out: Array) -> void:
	for c in title.get_children():
		if c != title.beastiary_panel:
			_all_text(c, out)

func _key(code: int, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = pressed
	ev.echo = echo
	return ev

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result is a real change, not luck.
	seed(20260926)
	var sd = load("res://scripts/SaveData.gd")
	for n in [1, 2, 3]:
		sd.delete_slot(n)
	sd.init_slot(1, "hard", "The Barbarian")
	sd.active_slot = 1
	var data: Dictionary = sd.load_data()
	data.essence = 1438
	data.best_wave = 23
	data.upgrades = {"hardened": 3, "nest_egg": 2, "brawn": 4}
	sd.save_data(data)
	sd.active_slot = 1

	# the game's own wording (text/strings.json) is applied by an autoload a frame after a script starts; in the real game it is there first
	await process_frame
	await process_frame
	var title_scene = load("res://TitleScreen.tscn")
	var title = title_scene.instantiate()
	root.add_child(title)
	await process_frame
	await process_frame

	# --- The splash ---
	print("the title opens on the splash and nothing else: screen=%s (expected splash), splash=%s files=%s menu=%s (expected true, false, false)" % [
		title.screen, title.splash_box.visible, title.select_save_box.visible, title.main_menu_box.visible
	])
	var splash_texts := []
	_all_text(title.splash_box, splash_texts)
	print("it says to press anything: %s (expected true)" % [splash_texts.any(func(t): return str(t).to_lower().contains("press anything to continue"))])
	print("the logo is the big one on the splash: compact=%s (expected false)" % [title.logo_compact])
	title._input(_key(KEY_SPACE))
	print("a key in the first half second is ignored (a held key can't skip it): screen=%s (expected splash)" % [title.screen])
	title._age = 1.0
	title._input(_key(KEY_SPACE, false))
	print("a key RELEASE doesn't move on: screen=%s (expected splash)" % [title.screen])
	title._input(_key(KEY_SPACE, true, true))
	print("a held key's repeat doesn't either: screen=%s (expected splash)" % [title.screen])
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	title._input(click)
	print("a mouse click moves on to Select a File: screen=%s (expected files)" % [title.screen])
	print("...and the logo is the small one from now on: compact=%s (expected true)" % [title.logo_compact])

	# --- Select a File: three cards ---
	print("three cards, each a save slot: %d (expected 3), only Select a File is showing: files=%s splash=%s (expected true, false)" % [
		title.slot_buttons.size(), title.select_save_box.visible, title.splash_box.visible
	])
	var card_text: String = title.slot_buttons[1].text
	print("a played file's card says its name, difficulty, Essence and upgrades: %s (expected true, 'The Barbarian', 'Hard Mode', '1,438 Essence', '9 upgrades')" % [
		card_text.contains("The Barbarian") and card_text.contains("Hard Mode") and card_text.contains("1,438 Essence") and card_text.contains("9 upgrades")
	])
	print("an empty slot's card says New Game: %s (expected true)" % [title.slot_buttons[2].text.contains("New Game")])
	print("only a played file has a gear for its options: %s, %s (expected true, false)" % [title.options_buttons[1].visible, title.options_buttons[2].visible])
	print("the cursor starts on the first card: %s (expected true)" % [title.slot_buttons[1].has_focus()])
	title.slot_buttons[2].mouse_entered.emit()
	print("hovering a card chooses it: %s (expected true)" % [title.slot_buttons[2].has_focus()])

	# no screen says "Wave" (the game has no waves to show), whatever the save holds
	var every_text := []
	_all_text_of_screens(title, every_text)
	title._show_main_menu()
	_all_text_of_screens(title, every_text)
	title._on_stats_pressed()
	_all_text_of_screens(title, every_text)
	title._show_select_save_screen()
	print("not one word on the title screens says wave: %s (expected true)" % [not every_text.any(func(t): return str(t).to_lower().contains("wave"))])

	# --- Back and X ---
	title._unhandled_key_input(_key(KEY_ESCAPE))
	print("Esc on Select a File goes back to the splash: screen=%s (expected splash)" % [title.screen])
	title._leave_splash()
	title.slot_buttons[1].grab_focus()
	title._unhandled_key_input(_key(KEY_X))
	print("X on a played file's card opens its options: screen=%s (expected slot_options), target=%d (expected 1)" % [title.screen, title.slot_options_target])
	title._unhandled_key_input(_key(KEY_ESCAPE))
	print("Esc there goes back to Select a File: screen=%s (expected files)" % [title.screen])
	title.slot_buttons[2].grab_focus()
	title._unhandled_key_input(_key(KEY_X))
	print("X on an empty card does nothing: screen=%s (expected files)" % [title.screen])

	# --- The main menu ---
	title._on_slot_pressed(1)
	print("choosing a played file reaches the menu with that file active: screen=%s (expected menu), active_slot=%d (expected 1)" % [title.screen, sd.active_slot])
	var entries: Array = [title.play_button, title.stats_button, title.beastiary_button, title.sandbox_button, title.switch_save_button, title.quit_button]
	print("the menu's choices, in order: %s (expected Play, Stats, Beastiary, Sandbox, Switch File, Quit)" % [", ".join(entries.map(func(e): return e.text))])
	print("the cursor starts on Play, whose words are under it: focus=%s (expected true), description='%s' (expected 'Begin your adventure.')" % [title.play_button.has_focus(), title.description_label.text])
	title.sandbox_button.mouse_entered.emit()
	print("hovering Sandbox chooses it and swaps the words: focus=%s (expected true), starts '%s' (expected Debug sandbox)" % [title.sandbox_button.has_focus(), title.description_label.text.substr(0, 13)])
	title._unhandled_key_input(_key(KEY_ESCAPE))
	print("Esc on the menu is Switch File: screen=%s (expected files)" % [title.screen])
	title._on_slot_pressed(1)

	# --- The difficulty screen never changes size ---
	title._on_slot_pressed(3)
	print("an empty slot goes to the difficulty screen: screen=%s (expected difficulty)" % [title.screen])
	await process_frame
	await process_frame
	var base_size: Vector2 = title.difficulty_box.get_combined_minimum_size()
	var sizes := []
	var same := true
	var wrapped := true
	var shown_words := []
	for d in sd.DIFFICULTIES:
		title.difficulty_buttons[d.id].grab_focus()
		await process_frame
		await process_frame
		var s: Vector2 = title.difficulty_box.get_combined_minimum_size()
		sizes.append(s)
		if s != base_size:
			same = false
		shown_words.append("%d vs %d" % [title.description_label.text.length(), str(d.description).length()])
		if title.description_label.text != d.description:
			wrapped = false
	print("each difficulty's words show under it: %s (expected true) %s" % [wrapped, shown_words])
	print("the panel is exactly the same size whichever difficulty is chosen (words change, the panel doesn't): %s (expected true), sizes=%s" % [same, sizes])
	var longest := 0
	for d in sd.DIFFICULTIES:
		longest = maxi(longest, str(d.description).length())
	print("the longest description (%d letters) wraps inside it rather than widening it: width=%s (expected %s)" % [longest, base_size.x, title.difficulty_box.custom_minimum_size.x])
	title._on_difficulty_back_pressed()
	print("Back from difficulty returns to Select a File: screen=%s (expected files)" % [title.screen])

	# --- Choosing a difficulty makes the file ---
	title._on_slot_pressed(3)
	title.new_save_name_edit.text = "  Conan  "
	title._on_difficulty_pressed("apocalyptic")
	print("picking a difficulty creates the file and reaches the menu: name=%s (expected Conan), difficulty=%s (expected apocalyptic), screen=%s (expected menu)" % [
		sd.slot_summary(3).name, sd.slot_summary(3).difficulty_id, title.screen
	])

	# --- Coming back to the title skips the splash ---
	var again = title_scene.instantiate()
	root.add_child(again)
	await process_frame
	print("a second visit to the title (after a run) skips the splash: screen=%s (expected files)" % [again.screen])
	again.queue_free()

	# --- Play still starts the game ---
	title._on_slot_pressed(1)
	title.play_button.pressed.emit()
	await process_frame
	await process_frame
	await process_frame
	var current_scene := root.get_child(root.get_child_count() - 1)
	print("clicking Play loads the game scene: current_scene_name=%s (expected Main)" % [current_scene.name])

	# leave the scratch slots as the rest of the suite expects them: blank
	for n in [1, 2, 3]:
		sd.active_slot = n
		sd.save_data({"essence": 0, "upgrades": {}, "best_wave": 0})
	sd.active_slot = 1
	quit()
