extends SceneTree

# The redesigned battle screen: party cards down the left, a plate over every unit, the action lists that float beside the acting unit
# (Attack / Strategy / Item for the hero; Attack / Magic / Strategy for a member), hovering and clicking units (popup, details box,
# the tiles a unit could walk to), the History panel, and the damage chip.

func _visible_texts(buttons: Array) -> Array:
	var out: Array = []
	for b in buttons:
		if b.visible:
			out.append(b.text)
	return out

func _list_texts(menu: Dictionary) -> Array:
	return _visible_texts(menu.list.get_children())

func _make_goblin(main, tile: Vector2i, hp: int = 999) -> Dictionary:
	var g = load("res://scripts/Enemy.gd").new()
	main.add_child(g)
	g.set_physics_process(false)
	g.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	return {
		"ref": g, "tile": tile, "hp": hp, "max_hp": hp, "move_range": 2, "damage": 1, "name": "Goblin", "winding_up": false,
		"stunned": false, "attack_range": 1, "concussed_turns": 0, "frozen_turns": 0, "burning": false, "armored": false,
		"disarmed_tile": Vector2i(-1, -1), "vulnerable_turns": 0, "aware_of_player": true, "size": 1,
	}

func _init() -> void:
	seed(20261016)
	load("res://scripts/SaveData.gd").mark_tutorial_completed()
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	var hud = main.hud
	player.max_party_slots = 20
	for kind in ["knight", "necromancer", "druid", "rogue", "guardian"]:
		player.recruit(kind)
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)
	var orc = load("res://scripts/Orc.gd").new()
	main.add_child(orc)
	orc.global_position = player.global_position + Vector2(30, 0)
	main.trigger_battle(orc)
	await process_frame
	await process_frame
	main.enforce_special_loadouts = false
	main.battle_terrain.clear()
	main.battle_turn = "player"
	main.battle_menu_state = "main"
	main._refresh_battle_display()

	# ---------------------------------------------------------------- the party cards and plates
	var shown := 0
	var names: Array = []
	for c in hud.battle_party_cards:
		if c.panel.visible:
			shown += 1
			names.append(c.name.text)
	print("A card for you and for each member, and no more: %d showing (expected 6), %s (expected [You, Knight, Necromancer, Druid, Rogue, Guardian])" % [shown, names])
	var acting_card: String = ""
	for i in hud.battle_party_cards.size():
		if hud.battle_party_cards[i].panel.visible and hud.battle_party_rows[i].acting:
			acting_card = hud.battle_party_cards[i].name.text
	print("On your turn your card is the lit one: %s (expected You)" % [acting_card])
	var kn_card = hud.battle_party_cards[1]
	var nec_card = hud.battle_party_cards[2]
	var dru_card = hud.battle_party_cards[3]
	print("A fighter's second bar is stamina, a caster's is mana, and the Necromancer (whose mana is her HP) has none: %s / %s / %s (expected true / true / false)" % [kn_card.res_bar.bg.visible, dru_card.res_bar.bg.visible, nec_card.res_bar.bg.visible])
	print("The hero's plate and the plates over the members and the foe are up: hero=%s, members=%d (expected true, 5), foe=%s (expected true)" % [
		hud.battle_hero_plate.hp.bg.visible, hud.battle_ally_plates.filter(func(p): return p.hp.bg.visible).size(), hud.battle_enemy_plates[0].hp.bg.visible])
	print("The battle log is gone from the screen: label visible=%s (expected false)" % [hud.battle_log_label.visible])

	# statuses on the cards
	var rogue_unit: Dictionary = {}
	for a in main.battle_allies:
		if a.kind == "rogue":
			rogue_unit = a
	rogue_unit["stealth_turns"] = 3
	main.player_burning = true
	main._refresh_battle_display()
	var rogue_card = hud.battle_party_cards[4]
	print("Statuses show as chips on the card: rogue '%s' (expected Stealth (3)), you '%s' (expected Burning); the card's tooltip says what they do: %s (expected true)" % [
		rogue_card.status.text, hud.battle_party_cards[0].status.text, rogue_card.panel.tooltip_text.begins_with("Stealth: ")])
	main.player_burning = false
	rogue_unit["stealth_turns"] = 0

	# ---------------------------------------------------------------- the hero's lists
	main.battle_menu_state = "main"
	main._refresh_battle_display()
	print("The hero's root list is Attack / Strategy / Item: %s (expected [Attack, Strategy, Item]), showing=%s (expected true)" % [_list_texts(hud.battle_menus.main), hud.battle_main_menu_box.visible])
	main._on_battle_main_action("strategy")
	print("Strategy holds Move, Defend, Taunt, Stealth and Flee (no Skill without the Guardian's ultimatum): %s (expected [Move, Defend, Taunt, Stealth (20 STA), Flee])" % [_list_texts(hud.battle_menus.strategy)])
	print("...and the root list has gone: strategy showing=%s (expected true), root showing=%s (expected false)" % [hud.battle_strategy_menu_box.visible, hud.battle_main_menu_box.visible])
	main._on_battle_main_action("main_back")
	main._on_battle_main_action("fight")
	print("The attack list: state=%s (expected fight), showing=%s (expected true), first entries %s (expected [Attack, Heavy Attack (...)...])" % [main.battle_menu_state, hud.battle_fight_submenu_box.visible, _list_texts(hud.battle_menus.fight).slice(0, 2)])
	main._on_battle_fight_action("back")
	# (A headless window snaps back to 64x64 a frame after it is set, which would squash the layout; lay it out as the real 1152x648.)
	root.size = Vector2i(1152, 648)
	hud.battle_grid_origin = Vector2(348, 68)
	main.battle_player_tile = Vector2i(1, 2)
	main._refresh_battle_display()
	var anchor_x: float = hud.battle_menus.main.panel.position.x
	var tile_px: float = hud.battle_grid_origin.x + main.battle_player_tile.x * hud.battle_tile_size
	print("The root list floats beside the hero's tile (to its right when he stands in the left half): list x=%.0f, tile x=%.0f, within the screen=%s (expected the list right of the tile, true)" % [anchor_x, tile_px, anchor_x > tile_px and anchor_x + hud.battle_menus.main.panel.size.x <= 1152.0])
	main.battle_player_tile = Vector2i(5, 2)
	main._refresh_battle_display()
	print("...and to its left when he stands in the right half: list x=%.0f, tile x=%.0f (expected the list left of the tile)" % [hud.battle_menus.main.panel.position.x, hud.battle_grid_origin.x + 5 * hud.battle_tile_size])

	# ---------------------------------------------------------------- a member's lists
	var knight_unit: Dictionary = {}
	var druid_unit: Dictionary = {}
	var guardian_unit: Dictionary = {}
	for a in main.battle_allies:
		match a.kind:
			"knight": knight_unit = a
			"druid": druid_unit = a
			"guardian": guardian_unit = a
	main.battle_menu_state = "main"
	main.battle_commanding_ally = knight_unit
	main.battle_ally_moves_left = 3
	main._refresh_battle_display()
	print("A member with no spells has no Magic entry: %s (expected [Attack, Strategy])" % [_list_texts(hud.battle_menus.ally_main)])
	main._on_battle_ally_action("open_attack")
	print("The Knight's attack list opens with the plain attack, then his fighting moves: %s (expected Attack first; Rallying Cry, CHARGE!!, Stalwart after)" % [_list_texts(hud.battle_menus.ally_list)])
	main._on_battle_ally_action("back")
	main._on_battle_ally_action("open_strategy")
	print("His strategy list: %s (expected [Move, Defend, Stealth (20 STA), Skip turn])" % [_list_texts(hud.battle_menus.ally_list)])
	main._on_battle_ally_action("back")
	main.battle_commanding_ally = druid_unit
	main.battle_ally_moves_left = 3
	main.battle_menu_state = "main"
	main._refresh_battle_display()
	print("A caster has Magic: %s (expected [Attack, Magic, Strategy])" % [_list_texts(hud.battle_menus.ally_main)])
	main._on_battle_ally_action("open_magic")
	print("The Druid's magic list is her three spells: %s (expected [Restore (40 MP), Empower (30 MP), Vitalize (40 MP)])" % [_list_texts(hud.battle_menus.ally_list)])
	main._on_battle_ally_action("back")
	print("Backing out of a list returns to the member's root list: state=%s (expected main)" % [main.battle_menu_state])
	main.battle_commanding_ally = guardian_unit
	main.battle_menu_state = "main"
	main._on_battle_ally_action("open_strategy")
	print("The Guardian's Taunt is a strategy: %s (expected Taunt among them)" % [_list_texts(hud.battle_menus.ally_list)])
	main.battle_commanding_ally = null
	main.battle_menu_state = "main"
	var cats := []
	for sp in [{"id": "druid_heal"}, {"id": "staff_landfall"}, {"id": "guardian_taunt", "effect": "taunt"}, {"id": "ally_stealth", "effect": "ally_stealth"}, {"id": "knight_charge", "effect": "charge"}, {"id": "weapon_x", "effect": ""}]:
		cats.append(main._ally_special_category(sp))
	print("Spells are Magic, Taunt and Stealth are Strategy, everything else an Attack: %s (expected [magic, magic, strategy, strategy, attack, attack])" % [cats])

	# ---------------------------------------------------------------- the tiles a unit could walk to
	main.battle_units = []
	main.battle_allies = []
	main.battle_terrain.clear()
	main.BATTLE_GRID_W = 8
	main.BATTLE_GRID_H = 8
	main.battle_player_tile = Vector2i(7, 7)
	print("Two moves on open ground reach the 12 tiles around you: %d (expected 12)" % [main._reachable_tiles(Vector2i(3, 3), 2).size()])
	main.battle_terrain[Vector2i(4, 3)] = {"type": "rock"}
	var with_rock: Array = main._reachable_tiles(Vector2i(3, 3), 2)
	print("A rock blocks its own tile and the tile behind it (which would take three moves round): %d (expected 10), has the rock=%s (expected false)" % [with_rock.size(), with_rock.has(Vector2i(4, 3))])
	main.battle_terrain[Vector2i(3, 4)] = {"type": "caltrops"}
	var with_caltrops: Array = main._reachable_tiles(Vector2i(3, 3), 2)
	print("Caltrops cost a second move, so nothing lies beyond them: has (3,4)=%s (expected true), has (3,5)=%s (expected false)" % [with_caltrops.has(Vector2i(3, 4)), with_caltrops.has(Vector2i(3, 5))])
	main.battle_terrain.clear()

	# ---------------------------------------------------------------- hovering and clicking
	main.battle_units = [_make_goblin(main, Vector2i(4, 3))]
	main.battle_allies = [knight_unit]
	knight_unit.tile = Vector2i(1, 3)
	main.battle_player_tile = Vector2i(0, 0)
	main.battle_turn = "player"
	main.battle_menu_state = "main"
	main._refresh_battle_display()
	hud.unit_hovered.emit("enemy", 0)
	var lit: int = hud.battle_range_rects.filter(func(r): return r.visible).size()
	print("Hovering a foe raises its popup and lights where it could walk (red): popup=%s (expected true), tiles lit=%d (expected 12 or fewer, more than 0)" % [hud.battle_popup.panel.visible, lit])
	print("...its popup names it: '%s' (expected Goblin)" % [hud.battle_popup.name.text])
	hud.unit_unhovered.emit()
	print("Moving the mouse away clears both: popup=%s (expected false), tiles lit=%d (expected 0)" % [hud.battle_popup.panel.visible, hud.battle_range_rects.filter(func(r): return r.visible).size()])
	knight_unit["stealth_turns"] = 2
	hud.unit_clicked.emit("ally", 0)
	print("Clicking a member opens the details box: showing=%s (expected true), name '%s' (expected Knight), status rows showing=%d (expected 1)" % [
		hud.battle_details.panel.visible, hud.battle_details.name.text, hud.battle_details.rows.filter(func(r): return r.row.visible).size()])
	hud.battle_details.rows[0].row.mouse_entered.emit()
	print("Hovering its status reads what it does: tooltip showing=%s (expected true), '%s' (expected to start Stealth:)" % [hud.battle_status_tooltip.panel.visible, hud.battle_status_tooltip.text.text.substr(0, 8)])
	hud.battle_details.rows[0].row.mouse_exited.emit()
	hud.unit_clicked.emit("none", 0)
	print("Clicking bare ground (or the box's close button) shuts it: showing=%s (expected false)" % [hud.battle_details.panel.visible])
	knight_unit["stealth_turns"] = 0
	main.battle_menu_state = "move"
	main._refresh_battle_display()
	var move_tiles: int = hud.battle_range_rects.filter(func(r): return r.visible).size()
	print("In move mode your own remaining reach is lit: %d tiles (expected the 2-move diamond around the hero, a few fewer at the corner)" % [move_tiles])
	main.battle_menu_state = "main"
	# Tab: the keyboard's way to the details box -- you, then each member, then each foe, then shut.
	main.battle_details_unit = {}
	var tabbed := []
	for i in 4:
		hud.inspect_cycled.emit()
		tabbed.append(hud.battle_details.name.text if hud.battle_details.panel.visible else "(closed)")
	print("Tab steps the details box through everyone and then closes it: %s (expected [You, Knight, Goblin, (closed)])" % [tabbed])

	# ---------------------------------------------------------------- the History panel
	hud.battle_history.clear()
	hud.battle_log("one")
	hud.battle_history_new_turn(2)
	hud.battle_log("two")
	hud.battle_history_new_turn(3)
	hud.battle_log("three")
	hud.battle_history_new_turn(4)
	hud.battle_log("four")
	print("History keeps the last three turns: %d blocks (expected 3), turns %s (expected [2, 3, 4])" % [hud.battle_history.size(), hud.battle_history.map(func(b): return b.turn)])
	hud.toggle_history()
	print("The History panel opens (newest first, 'one' forgotten): showing=%s (expected true), has four=%s, has one=%s (expected true, false)" % [
		hud.history_open(), hud.battle_history_text.text.contains("four"), hud.battle_history_text.text.contains("one")])
	hud.unit_clicked.emit("ally", 0)
	main._on_unit_clicked("ally", 0)
	print("Opening details closes it (they share the place): history showing=%s (expected false)" % [hud.history_open()])
	main._on_unit_clicked("none", 0)

	# ---------------------------------------------------------------- the damage chip
	# One plain hit, no crit, no miss, on open ground: the chip's lowest figure is what the hit really does.
	main.battle_terrain.clear()
	player.miss_chance_override = 0.0
	player.meta_crit_chance = 0.0
	player.current_weapon = load("res://scripts/Weapons.gd").CLUB
	player.attack_damage = 14
	var dummy := _make_goblin(main, Vector2i(2, 0), 999)
	main.battle_units = [dummy]
	main.battle_allies = []
	main.battle_player_tile = Vector2i(1, 0)
	var est: Vector2i = main._estimate_hit(dummy, 1.0)
	main._apply_single_hit(0, 1.0, "", player.current_weapon)
	var done: int = 999 - int(dummy.hp)
	print("The chip's lowest figure is what a plain hit does: estimate %d-%d, actual %d (expected the actual equal to the lowest)" % [est.x, est.y, done])
	var heavy: Vector2i = main._estimate_hit(dummy, load("res://scripts/Weapons.gd").HEAVY_DAMAGE_MULT)
	print("A heavy attack's chip is bigger: %d-%d vs %d-%d (expected larger)" % [heavy.x, heavy.y, est.x, est.y])
	dummy.hp = 999
	dummy.vulnerable_turns = 2
	var marked: Vector2i = main._estimate_hit(dummy, 1.0)
	print("A marked (Vulnerable) target takes 25%% more: %d vs %d (expected %d)" % [marked.x, est.x, int(round(est.x * 1.25))])
	main.battle_preview_action = "attack"
	main.battle_menu_state = "fight"
	main.battle_commanding_ally = null
	main.battle_turn = "player"
	dummy.tile = Vector2i(2, 0)               # (the club's blow shoved it back)
	main._refresh_battle_display()
	print("Resting on Attack in the list shows the chip over the foe: showing=%s (expected true), '%s'" % [hud.battle_preview.panel.visible, hud.battle_preview.line1.text])
	main.battle_preview_action = ""
	main._refresh_battle_display()
	print("...and it goes when the mouse leaves: showing=%s (expected false)" % [hud.battle_preview.panel.visible])

	# ---------------------------------------------------------------- the key line
	var hints := [hud._battle_key_hints("main", false, true, false, false), hud._battle_key_hints("move", false, true, false, false), hud._battle_key_hints("fight", false, true, false, false), hud._battle_key_hints("main", false, false, false, false)]
	print("The bottom bar tells the keys for the menu showing: %s (expected a main line, a move line, a back line, and nothing on the enemy's turn)" % [hints])
	quit()
