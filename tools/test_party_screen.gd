extends SceneTree

# The Party screen: each member's special loadout (3 slots, chosen from kit + weapon), the stats sheet
# (the numbers the fight itself uses), the description / portrait, spending bonus picks, and the pickers.

func _find_all(node: Node, type_name: String, out: Array) -> void:
	for c in node.get_children():
		if c.get_class() == type_name:
			out.append(c)
		_find_all(c, type_name, out)

func _texts(node: Node) -> Array:
	var out := []
	for kind in ["Button", "Label", "OptionButton"]:
		var found := []
		_find_all(node, kind, found)
		for n in found:
			if kind == "OptionButton":
				for i in n.item_count:
					out.append(n.get_item_text(i))
			else:
				out.append(n.text)
	return out

func _names(specials: Array) -> Array:
	return specials.map(func(s): return s.name)

func _pool_ids(main, member) -> Array:
	return main.member_special_pool(member).map(func(e): return str(e.special.get("id", "")))

func _init() -> void:
	seed(20261014)
	var rules = load("res://scripts/PartyRules.gd")
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	player.party.clear()
	player.max_party_slots = 20
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	var knight = player.recruit("knight")
	var druid = player.recruit("druid")
	var wolf = player.recruit("wolf")
	var guardian = player.recruit("guardian")

	# =========================================================
	# The loadout
	# =========================================================
	print("Every member has 3 special slots: %d (expected 3)" % [rules.SPECIAL_SLOTS])
	var kp: Array = _pool_ids(main, knight)
	print("A bare-handed Knight's pool is its three kit specials: %s (expected [Rallying Cry, CHARGE!!, Stalwart])" % [_names(main.member_special_pool(knight).map(func(e): return e.special))])
	print("Until anything is picked the loadout is the first three of the pool: %s (expected the same three)" % [knight.resolved_loadout(kp)])
	player.owned_weapons["greatsword_fine_steel"] = true
	player.equip_ally_weapon(knight, "greatsword_fine_steel")
	var kp2: Array = _pool_ids(main, knight)
	print("A greatsword adds its own three to the pool: %d specials (expected 6)" % [kp2.size()])
	print("...but the default is still only the first three (kit first): %d (expected 3), 4th slot would be '%s' (expected nothing)" % [knight.resolved_loadout(kp2).size(), knight.loadout_slot(3, kp2)])
	var unit: Dictionary = main.member_preview(knight)
	print("In battle only those three are in the menu: %s (expected [Rallying Cry, CHARGE!!, Stalwart])" % [_names(main._ally_specials(unit))])

	knight.set_loadout_slot(2, kp2[4], kp2)
	print("Putting a greatsword special into slot 3 freezes the other slots: %s (expected [kit1, kit2, the weapon special])" % [[knight.loadout_slot(0, kp2) == kp2[0], knight.loadout_slot(1, kp2) == kp2[1], knight.loadout_slot(2, kp2) == kp2[4]]])
	unit = main.member_preview(knight)
	print("...and the menu follows the slots in order: %s (expected [Rallying Cry, CHARGE!!, the 5th pool entry])" % [_names(main._ally_specials(unit))])
	knight.set_loadout_slot(0, kp2[2], kp2)
	knight.set_loadout_slot(2, kp2[2], kp2)
	print("Putting a special that is already in another slot into slot 3 moves it, never doubles it: slots %s (expected [empty, CHARGE!!, Stalwart])" % [[knight.loadout_slot(0, kp2) == "", knight.loadout_slot(1, kp2) == kp2[1], knight.loadout_slot(2, kp2) == kp2[2]]])
	knight.set_loadout_slot(1, "", kp2)
	print("Emptying a slot leaves it empty: %d special active (expected 1)" % [knight.resolved_loadout(kp2).size()])
	player.unequip_ally_weapon(knight)
	var kp3: Array = _pool_ids(main, knight)
	knight.set_loadout_slot(0, kp3[0], kp3)
	knight.set_loadout_slot(1, kp2[4], kp3)   # a special of a weapon it is no longer holding
	print("Specials of a weapon it no longer holds simply stop being active: %s (expected only the kit special)" % [knight.resolved_loadout(kp3).size()])
	knight.reset_loadout()
	print("Reset goes back to the default: set=%s (expected false), %d active (expected 3)" % [knight.loadout_set, knight.resolved_loadout(kp3).size()])

	# a caster takes the Staff's three INSTEAD of her spells
	player.owned_weapons["staff_fine_steel"] = true
	player.equip_ally_weapon(druid, "staff_fine_steel")
	var dp: Array = _pool_ids(main, druid)
	print("The Druid's pool: three spells plus the Staff's three = %d (expected 6)" % [dp.size()])
	druid.set_loadout_slot(0, dp[3], dp)
	druid.set_loadout_slot(1, dp[4], dp)
	druid.set_loadout_slot(2, dp[5], dp)
	print("She can swap all three spells out for the Staff's: %s (expected [I CAST FIREBALL, Landfall, Channel])" % [_names(main._ally_specials(main.member_preview(druid)))])
	print("A wolf has only its three kit specials and fills all three slots: %d (expected 3)" % [wolf.resolved_loadout(_pool_ids(main, wolf)).size()])
	print("The Guardian's four kit specials don't all fit: default slots %s (expected Taunt, Body Slam, Haymaker -- Earbursting Bellow waits in the pool)" % [_names(main._ally_specials(main.member_preview(guardian)))])
	print("Units without a loadout (mercenaries, skeletons) keep the whole pool: %s (expected true)" % [not main._make_skeleton(Vector2i(0, 0)).has("special_ids")])
	main.enforce_special_loadouts = false
	var all_on: Dictionary = main.member_preview(guardian)
	main.enforce_special_loadouts = true
	print("With enforcement off (tests only) a unit has the whole pool: %d (expected 4)" % [all_on.special_ids.size()])

	# =========================================================
	# The data a member sheet is made of
	# =========================================================
	var missing := []
	for kind in rules.KINDS:
		if str(rules.KINDS[kind].get("description", "")) == "":
			missing.append(kind)
	print("Every kind has a description: missing %s (expected [])" % [missing])
	var game_text = root.get_node("GameText")
	game_text._data["party.knight.description"] = "Edited in strings.json."
	game_text._process_all(game_text.MODE_APPLY)
	print("A description edited in strings.json shows up (the const table is never written to): %s (expected Edited in strings.json.)" % [rules.description_for("knight")])
	game_text.reload()
	print("...and reloading the file puts the shipped text back: %s (expected true)" % [rules.description_for("knight").begins_with("A veteran who holds the line")])
	print("A member's portrait falls back to a stand-in until the art exists: wolf=%s knight=%s (expected the wolf icon, the companion icon)" % [load("res://scripts/PartyScreen.gd").new().portrait_texture("wolf").resource_path.get_file(), load("res://scripts/PartyScreen.gd").new().portrait_texture("knight").resource_path.get_file()])

	# =========================================================
	# The screen
	# =========================================================
	player.owned_armor["armor_gambeson"] = true
	player.equip_ally_armor(knight, "armor_gambeson")
	knight.reset_loadout()
	main.in_battle = false
	var panel = main.inventory_panel
	panel.party_selected_id = -1
	panel.open(player)
	await process_frame
	var texts: Array = _texts(panel.tab_containers.Party)
	print("The roster lists every member: %s (expected true for Knight, Druid, Fickle Wolf, Guardian)" % [[texts.has("Knight"), texts.has("Druid"), texts.has("Fickle Wolf"), texts.has("Guardian")]])
	print("The first member's sheet opens by default: heading is the Knight's: %s (expected true)" % [texts.has("Knight") and texts.has("STATS")])
	print("Her description is on show: %s (expected true)" % [texts.any(func(t): return str(t).begins_with("A veteran who holds the line"))])
	print("The sheet has the stat rows: %s (expected all true)" % [["Max HP", "Attack", "Defense", "Fortitude", "Speed", "Move", "Reach"].map(func(s): return texts.has(s))])
	var u2: Dictionary = main.member_preview(knight)
	print("The numbers are the fight's own: Defense %d (expected 18 = 3 + the Gambeson's 15), shows '%s'" % [int(u2.defense_pct), "18" if texts.has("18") else "?"])
	print("...with what it means (the diminishing-returns cut): %s (expected true)" % [texts.any(func(t): return str(t).begins_with("bodily harm -"))])
	print("Equipment and Specials sections are there: %s, %s (expected true, true)" % [texts.has("EQUIPMENT"), texts.has("SPECIALS")])
	var slot_pickers := 0
	var option_buttons := []
	_find_all(panel.tab_containers.Party, "OptionButton", option_buttons)
	for ob in option_buttons:
		if ob.get_item_text(0) == "(empty)":
			slot_pickers += 1
	print("Three special pickers: %d (expected 3)" % [slot_pickers])
	print("...listing the three kit specials with their costs: %s (expected true)" % [texts.any(func(t): return str(t).begins_with("Rallying Cry (25 STA)"))])

	# selecting someone else
	panel.party_selected_id = druid.id
	panel._refresh()
	await process_frame
	texts = _texts(panel.tab_containers.Party)
	print("Selecting the Druid shows her sheet (mana pool, her spells): %s, %s (expected true, true)" % [texts.any(func(t): return str(t).ends_with(" mana")), texts.any(func(t): return str(t).begins_with("Restore (40 MP)"))])

	# a wolf has no equipment
	panel.party_selected_id = wolf.id
	panel._refresh()
	await process_frame
	texts = _texts(panel.tab_containers.Party)
	print("A wolf wears and carries nothing: %s (expected true), and shows its loyalty: %s (expected true)" % [texts.any(func(t): return str(t).contains("doesn't wear or carry anything")), texts.any(func(t): return str(t).begins_with("Loyal for"))])

	# picks
	druid.picks = 0
	druid._level_up()
	var picks_before: int = druid.picks
	var hp_before: int = main.member_preview(druid).max_hp
	panel.party_selected_id = druid.id
	panel._refresh()
	await process_frame
	var plus_buttons := []
	_find_all(panel.tab_containers.Party, "Button", plus_buttons)
	var pluses: Array = plus_buttons.filter(func(b): return b.text == "+")
	print("With a pick banked every pickable stat gets a + button: %d (expected %d)" % [pluses.size(), druid.pickable_stats().size()])
	panel._on_member_pick_spent(druid, "hp")
	print("Spending it on HP: picks %d -> %d (expected -1), max HP %d -> %d (expected up)" % [picks_before, druid.picks, hp_before, main.member_preview(druid).max_hp])
	await process_frame
	await process_frame
	var left_over := []
	_find_all(panel.tab_containers.Party, "Button", left_over)
	print("...and with none left there are no + buttons: %s (expected true)" % [left_over.filter(func(b): return b.text == "+").is_empty()])

	# loadout through the panel
	panel.party_selected_id = knight.id
	panel._refresh()
	await process_frame
	var kpool: Array = _pool_ids(main, knight)
	panel._on_member_special_slot(knight, 1, "")
	print("Emptying slot 2 through the screen: %s (expected '')" % [knight.loadout_slot(1, kpool)])
	panel._on_member_loadout_reset(knight)
	print("The reset button restores the default: %s (expected false)" % [knight.loadout_set])
	panel.close()

	# Sandbox loadouts
	var SandboxScript = load("res://scripts/Sandbox.gd")
	var cfg: Dictionary = SandboxScript.default_config()
	cfg.party = [{"kind": "knight", "level": 1, "picks": {}, "weapon": {"base": "greatsword", "tier": "Fine", "material": "steel"}, "specials": ["", "knight_charge", ""]}]
	SandboxScript.apply_build(main, cfg)
	var sk = player.party[0]
	var sk_pool: Array = _pool_ids(main, sk)
	print("A sandbox member can be given a loadout: slot 2 = %s (expected knight_charge), slot 1 empty: %s (expected true)" % [sk.loadout_slot(1, sk_pool), sk.loadout_slot(0, sk_pool) == ""])

	quit()
