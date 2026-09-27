extends SceneTree

# The town Dojo (Dojo.gd / DojoPanel.gd): weapons no longer start with their
# three special moves -- each has to be learned, per run, for coins. Learning
# applies to a weapon's whole BASE type (every Spear variant), the battle menu
# shows unlearned moves disabled, and the executor refuses them too.

func _make_goblin(main, tile: Vector2i, hp: int = 999) -> Dictionary:
	var g = load("res://scripts/Enemy.gd").new()
	main.add_child(g)
	g.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	return {
		"ref": g, "tile": tile, "hp": hp, "max_hp": hp, "move_range": 2,
		"damage": 0, "name": "Goblin", "winding_up": false, "stunned": false,
	}

func _labels(node: Node) -> Array:
	var texts := []
	if node is Label:
		texts.append(node.text)
	for child in node.get_children():
		texts.append_array(_labels(child))
	return texts

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var player = main.player
	var weapons = load("res://scripts/Weapons.gd")
	var dojo = load("res://scripts/Dojo.gd")
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	# --- Catalog -------------------------------------------------------------------
	var bases: Array = dojo.teachable_bases()
	var total_specials := 0
	for b in bases:
		total_specials += b.specials.size()
	print("Club plus 7 weapon types teach moves, Bow doesn't: %d types (expected 8), %d moves (expected 24)" % [bases.size(), total_specials])
	print("lesson prices are 15 / 35 / 60 by slot: %d %d %d (expected 15 35 60)" % [dojo.lesson_cost(0), dojo.lesson_cost(1), dojo.lesson_cost(2)])
	var found: Dictionary = dojo.locate_special(weapons.SPEAR.specials[1].id)
	print("a special id maps back to its base and slot: base=%s (expected spear), index=%d (expected 1)" % [found.base.id, found.index])
	print("a made-up id maps to nothing: %s (expected true)" % [dojo.locate_special("nope").is_empty()])

	# --- A fresh run knows nothing -------------------------------------------------
	var club_special_0: Dictionary = weapons.CLUB.specials[0]
	print("nothing is learned at the start: %s (expected true)" % [player.learned_specials.is_empty()])
	print("the equipped Club's three moves start locked: %s (expected [false, false, false])" % [
		player.current_weapon.specials.map(func(s): return s.learned)
	])
	print("the shared base const is never mutated: has_learned_key=%s (expected false)" % [club_special_0.has("learned")])

	# --- Executor gate: an unlearned special is refused, nothing spent -------------
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_allies = []
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_target_index = 0
	main.battle_turn = "player"
	player.stat_strength = 10
	player.attack_damage = 10
	player.stamina = player.MAX_STAMINA
	var g = _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [g]
	main._battle_player_special(0)
	print("an unlearned special does nothing: hp_unchanged=%s (expected true), stamina_unchanged=%s (expected true), still_players_turn=%s (expected true)" % [
		g.hp == 999, player.stamina == player.MAX_STAMINA, main.battle_turn == "player"
	])

	# --- HUD gate: shown, but disabled and labelled -----------------------------------
	main.battle_menu_state = "fight"
	main._refresh_battle_display()
	var b0: Button = main.hud.battle_fight_buttons["special_0"]
	print("the Fight menu shows the locked move disabled: text=%s, disabled=%s (expected true)" % [b0.text, b0.disabled])
	print("...labelled as unlearned so you know where to go: %s (expected true)" % [b0.text.contains("Dojo")])

	# --- Learning ---------------------------------------------------------------------
	player.coins = 20
	var ok: bool = player.try_learn_special(club_special_0.id)
	print("learning the Club's first move costs 15: ok=%s (expected true), coins=%d (expected 5), known=%s (expected true)" % [ok, player.coins, player.knows_special(club_special_0.id)])
	print("...the equipped weapon is refreshed at once: learned=%s (expected [true, false, false])" % [player.current_weapon.specials.map(func(s): return s.learned)])
	print("can't learn it twice: %s (expected false), coins=%d (expected 5)" % [player.try_learn_special(club_special_0.id), player.coins])
	print("can't afford the second (35): %s (expected false), coins=%d (expected 5)" % [player.try_learn_special(weapons.CLUB.specials[1].id), player.coins])
	print("an unknown special can't be learned: %s (expected false)" % [player.try_learn_special("nope")])
	print("a weapon type you don't own can't be taught: %s (expected false)" % [player.try_learn_special(weapons.SPEAR.specials[0].id)])

	# The learned move now works in battle and is enabled in the menu.
	player.stamina = player.MAX_STAMINA
	main._refresh_battle_display()
	print("the learned move is enabled in the Fight menu: disabled=%s (expected false)" % [main.hud.battle_fight_buttons["special_0"].disabled])
	g = _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [g]
	main.battle_turn = "player"
	main._battle_player_special(0)
	print("...and actually fires: dealt>0=%s (expected true), stamina spent=%s (expected true)" % [g.hp < 999, player.stamina < player.MAX_STAMINA])
	main.in_battle = false

	# --- Learning is per BASE type: every variant inherits it ---------------------------
	player.coins = 500
	var spear_a: Dictionary = weapons.get_owned_variant("spear_fine_steel")
	var spear_b: Dictionary = weapons.get_owned_variant("spear_worn_gold")
	player.owned_weapons[spear_a.id] = true
	player.owned_weapons[spear_b.id] = true
	player._equip_weapon(spear_a)
	print("a new weapon's moves start locked: %s (expected [false, false, false])" % [player.current_weapon.specials.map(func(s): return s.learned)])
	print("learning a Spear move: %s (expected true)" % [player.try_learn_special(weapons.SPEAR.specials[1].id)])
	player._equip_weapon(spear_b)
	print("a DIFFERENT Spear variant already knows it: %s (expected [false, true, false])" % [player.current_weapon.specials.map(func(s): return s.learned)])
	print("...and the Club's learned move is unaffected by any of this: %s (expected true)" % [player.knows_special(club_special_0.id)])

	# Enchanting/upgrading (which re-equip and deep-copy) must not lose the flag.
	player.weapon_enchantments[spear_b.id] = "warding"
	player._equip_weapon(spear_b)
	print("an enchanted weapon keeps what you've learned: %s (expected [false, true, false])" % [player.current_weapon.specials.map(func(s): return s.learned)])
	player.weapon_enchantments.erase(spear_b.id)

	# Silver Tongue (free specials) waives the cost but not the lesson.
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_turn = "player"
	player.meta_free_specials = true
	player._equip_weapon(spear_b)
	g = _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [g]
	main._battle_player_special(0)
	print("free-specials still can't fire an unlearned move: hp_unchanged=%s (expected true)" % [g.hp == 999])
	player.meta_free_specials = false
	main.in_battle = false

	# Test helper used by suites that just want every move available.
	player.learn_all_specials()
	print("learn_all_specials teaches every move: %d known (expected 24)" % [player.learned_specials.size()])
	player._equip_weapon(spear_a)
	print("...so a freshly equipped weapon has them all: %s (expected [true, true, true])" % [player.current_weapon.specials.map(func(s): return s.learned)])

	# --- The panel --------------------------------------------------------------------
	var panel = main.town_panels.get("dojo")
	print("the Dojo panel is registered: %s (expected true)" % [panel != null])
	if panel != null:
		player.learned_specials.clear()
		player.owned_weapons = {"club": true}
		player.try_buy_weapon(weapons.CLUB)
		player.coins = 60
		main._try_open_panel("dojo")
		print("the door opens it: visible=%s (expected true), title=%s (expected THE DOJO)" % [panel.visible, panel.title_label.text])
		print("it only offers the types you hold: %s (expected [club])" % [dojo.owned_bases(player.owned_weapons).map(func(b): return b.id)])
		print("learning through the panel: ok=%s (expected true), coins=%d (expected 45)" % [panel.learn(weapons.CLUB.specials[0].id), player.coins])
		print("...and a second lesson: ok=%s (expected true), coins=%d (expected 10)" % [panel.learn(weapons.CLUB.specials[1].id), player.coins])
		print("broke for the third (60): %s (expected false)" % [panel.learn(weapons.CLUB.specials[2].id)])
		player.owned_weapons[spear_a.id] = true
		print("owning a Spear adds it to the list: %s (expected [club, spear])" % [dojo.owned_bases(player.owned_weapons).map(func(b): return b.id)])

		# --- The weapon picker: weapons on the left, the selected one's moves on the right ---
		panel._refresh()
		print("one entry per weapon type you hold, the one in hand first: %s (expected [club, spear])" % [panel.weapon_buttons.keys()])
		print("the weapon in hand starts selected: %s (expected club)" % [panel.selected_base_id])
		var club_texts: Array = _labels(panel.detail_box)
		print("its header counts what you've learned: %s (expected true)" % [club_texts.any(func(t): return t.begins_with("2 of 3 moves learned"))])
		print("three move cards, learned ones locked and the third unaffordable (60, have 10): %s disabled=%s (expected [Learned, Learned, Learn], [true, true, true])" % [
			panel.move_buttons.map(func(b): return b.text), panel.move_buttons.map(func(b): return b.disabled)
		])
		panel.select_base("spear")
		print("picking another weapon shows its own moves: %s (expected spear), buttons %s (expected all Learn, all disabled at 10 coins)" % [
			panel.selected_base_id, panel.move_buttons.map(func(b): return b.text + ("/off" if b.disabled else "/on"))
		])
		player.coins = 20
		panel._refresh()
		print("with 20 coins only the 15-coin first lesson is open: %s (expected [Learn/on, Learn/off, Learn/off])" % [
			panel.move_buttons.map(func(b): return b.text + ("/off" if b.disabled else "/on"))
		])
		panel.move_buttons[0].pressed.emit()
		print("pressing Learn teaches the move and updates the card: known=%s coins=%d text=%s (expected true, 5, Learned)" % [
			player.knows_special(weapons.SPEAR.specials[0].id), player.coins, panel.move_buttons[0].text
		])
		print("...and the weapon's list entry has a lit pip (the entry is rebuilt): %s (expected true)" % [panel.weapon_buttons.has("spear")])
		var all_text: String = " ".join(_labels(panel.detail_box))
		print("move descriptions show plain percent signs, not %%%%: %s (expected true)" % [not all_text.contains("%%")])

		player.owned_talismans["weapon_whisperer"] = true
		player.equip_talisman("weapon_whisperer")
		panel._refresh()
		print("with Weapon Whisperer a learned move offers Whisper: %s (expected Whisper)" % [panel.move_buttons[0].text])
		panel.move_buttons[0].pressed.emit()
		print("...and toggles to Whispered: %s (expected Whispered)" % [panel.move_buttons[0].text])
		player.owned_weapons = {}
		panel._refresh()
		print("with no weapons the picker is empty and says so: entries=%d moves=%d (expected 0, 0), text=%s" % [
			panel.weapon_buttons.size(), panel.move_buttons.size(), " ".join(_labels(panel.detail_box)).left(40)
		])
		panel.close()

	quit()
