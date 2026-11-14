extends SceneTree

# Sending members away and getting new ones in (the Party tab): Dismiss puts a member on the BENCH, keeping their level, picks, gear and a
# wolf's loyalty, and the Bench button calls them back when there is a place for them. Dismissing needs Friends in High Places (the doc) and
# a calm moment; the quick "Add member" shortcut only exists while the Debug menu is switched on.

func _find_button(node: Node, wanted: String):
	if node is PixelButton and node.text == wanted:
		return node
	for c in node.get_children():
		var found = _find_button(c, wanted)
		if found != null:
			return found
	return null

func _button_starting(node: Node, prefix: String):
	if node is PixelButton and node.text.begins_with(prefix):
		return node
	for c in node.get_children():
		var found = _button_starting(c, prefix)
		if found != null:
			return found
	return null

func _pick_rows(panel) -> Array:
	# The rows of the open pick popup: each is a PixelButton inside the popup's scroll box.
	var out := []
	if panel.popup_view == null or not is_instance_valid(panel.popup_view):
		return out
	_collect_buttons(panel.popup_view, out)
	return out

func _collect_buttons(node: Node, out: Array) -> void:
	if node is PixelButton and node.text != "×":
		out.append(node)
	for c in node.get_children():
		_collect_buttons(c, out)

func _init() -> void:
	seed(20261108)
	var main = load("res://Main.tscn").instantiate()
	main.regional_world = false
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	player.party.clear()
	player.bench.clear()
	player.max_party_slots = 2
	player.meta_battle_hardened = false
	main.settings.debug_menu_enabled = false
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)
	var panel = main.inventory_panel

	var knight = player.recruit("knight")
	var wolf = player.recruit("wolf")
	player.owned_weapons["greatsword_fine_steel"] = true
	player.equip_ally_weapon(knight, "greatsword_fine_steel")
	knight.level = 4
	knight.picks = 3
	wolf.battles_left = 7

	print("--- the rules: who may send members away")
	panel.party_selected_id = knight.id
	panel.open(player)
	panel._select_tab("Party")
	var dismiss = _find_button(panel.party_screen, "Dismiss")
	print("a Dismiss button sits on a member's page: %s (expected true)" % [dismiss != null])
	print("...greyed out until Friends in High Places is bought: disabled=%s (expected true), says '%s'" % [dismiss.disabled, dismiss.tooltip_text])
	panel._on_member_dismissed(knight)
	print("pressing it anyway does nothing: party=%d bench=%d (expected 2, 0)" % [player.party.size(), player.bench.size()])
	panel.party_selected_id = PartyScreen.HERO_ID
	panel._refresh()
	print("the hero's own page has no Dismiss: %s (expected true)" % [_find_button(panel.party_screen, "Dismiss") == null])
	print("no Bench button either, with nobody on it: %s (expected true)" % [_button_starting(panel.party_screen, "Bench") == null])

	print("--- sending a member away")
	player.meta_battle_hardened = true
	panel.party_selected_id = knight.id
	panel._refresh()
	dismiss = _find_button(panel.party_screen, "Dismiss")
	print("with Friends in High Places the button is live: disabled=%s (expected false)" % [dismiss.disabled])
	var bench_button = _button_starting(panel.party_screen, "Bench")
	print("...and the Bench button is there, reading 0: '%s' (expected Bench  0)" % [bench_button.text if bench_button != null else "missing"])
	main.in_battle = true
	panel._on_member_dismissed(knight)
	print("not in the middle of a battle: party=%d bench=%d (expected 2, 0)" % [player.party.size(), player.bench.size()])
	main.in_battle = false
	dismiss.pressed.emit()
	print("pressing Dismiss: party=%d bench=%d (expected 1, 1); the page falls back to you: %s (expected true)" % [
		player.party.size(), player.bench.size(), panel.party_selected_id == PartyScreen.HERO_ID])
	print("the roster no longer shows him: %s (expected false); the Bench button reads: '%s' (expected Bench  1)" % [
		panel.party_screen.roster_tiles.has(knight.id), _button_starting(panel.party_screen, "Bench").text])
	print("he keeps everything: level %d, %d picks, %s (expected 4, 3, greatsword_fine_steel)" % [knight.level, knight.picks, knight.weapon_id()])
	print("his weapon still counts as held: holder=%s (expected %s)" % [player.weapon_holder("greatsword_fine_steel").name, knight.name])
	var brawler = load("res://scripts/PartyMember.gd").create(900, "brawler")
	print("...so nobody else can take it: block='%s' (expected Knight is using it.)" % [player.ally_weapon_block_reason(brawler, "greatsword_fine_steel")])
	print("everyone you own: %d (expected 2), those who fight: %d (expected 1)" % [player.all_members().size(), player.fielded_party().size()])

	print("--- you take his weapon: it comes off him even on the bench")
	player._equip_weapon(load("res://scripts/Weapons.gd").get_owned_variant("greatsword_fine_steel"))
	print("the Knight now holds: '%s' (expected nothing)" % [knight.weapon_id()])
	player._equip_weapon(load("res://scripts/Weapons.gd").CLUB)   # you put it down again, and hand it back to him on the bench
	print("he can be handed it back while benched: %s (expected true)" % [player.equip_ally_weapon(knight, "greatsword_fine_steel")])

	print("--- calling him back")
	var recruit_two = player.recruit("guardian")
	print("a third member fills the party: size=%d of %d (expected 2 of 2)" % [player.party.size(), player.party_capacity()])
	panel._refresh()
	panel.party_screen._open_bench()
	var rows := _pick_rows(panel)
	print("the Bench popup lists him: '%s' (expected one row for the Knight)" % [rows[0].text if not rows.is_empty() else "none"])
	print("...greyed because the party is full: disabled=%s (expected true)" % [rows[0].disabled if not rows.is_empty() else "n/a"])
	panel._on_member_called_back(knight)
	print("calling him back with no place does nothing: party=%d bench=%d (expected 2, 1)" % [player.party.size(), player.bench.size()])
	player.dismiss_party_member(recruit_two.id)
	panel.close_popup()
	panel.party_screen._open_bench()
	rows = _pick_rows(panel)
	print("once a place is free the row is live: disabled=%s (expected false)" % [rows[0].disabled])
	rows[0].pressed.emit()
	print("pressing it: party=%d bench=%d (expected 2, 0); the same Knight, level %d, picks %d, weapon %s (expected 4, 3, greatsword_fine_steel)" % [
		player.party.size(), player.bench.size(), knight.level, knight.picks, knight.weapon_id()])
	print("he is selected again: %s (expected true)" % [panel.party_selected_id == knight.id])

	print("--- a wolf keeps its loyalty on the bench")
	player.send_to_bench(wolf.id)
	print("battles left on the bench: %d (expected 7); wolf-only slots don't matter for the way back: can call back=%s (expected true)" % [wolf.battles_left, player.call_back_block_reason(wolf) == ""])
	player.call_back(wolf.id)
	print("back in the pack: %d members (expected 2), still %d battles (expected 7)" % [player.party.size(), wolf.battles_left])

	print("--- the quick add shortcut belongs to the Debug menu")
	player.dismiss_party_member(wolf.id)
	panel._refresh()
	print("Debug menu off: no Add member button: %s (expected true)" % [_find_button(panel.party_screen, "Add member") == null])
	panel._on_member_quick_added("rogue")
	print("...and the handler refuses too: party=%d (expected 1)" % [player.party.size()])
	main.settings.debug_menu_enabled = true
	panel._refresh()
	var add_button = _find_button(panel.party_screen, "Add member")
	print("Debug menu on: the button appears: %s (expected true)" % [add_button != null])
	add_button.pressed.emit()
	rows = _pick_rows(panel)
	var kinds: Dictionary = load("res://scripts/PartyRules.gd").KINDS
	print("it lists every kind of member: %d rows (expected %d)" % [rows.size(), kinds.size()])
	var rogue_row = null
	for r in rows:
		if r.text.begins_with("Rogue"):
			rogue_row = r
	rogue_row.pressed.emit()
	print("choosing the Rogue adds a level-1 Rogue: party=%s (expected [Knight, Rogue]), selected=%s (expected Rogue)" % [
		player.party.map(func(m): return str(m.name)), str(panel.party_screen.unit_member().name) if panel.party_screen.unit_member() != null else "you"])
	panel._on_member_quick_added("shaman")
	print("a full party refuses a third: party=%d (expected 2)" % [player.party.size()])
	panel.party_screen._open_add()
	rows = _pick_rows(panel)
	print("...and the add list greys every row: %s (expected true)" % [rows.all(func(b): return b.disabled)])

	print("--- Debug's Dismiss everyone clears the bench as well")
	player.send_to_bench(player.party[0].id)
	var DA = load("res://scripts/DebugActions.gd")
	DA.dismiss_all(main)
	print("party=%d bench=%d (expected 0, 0)" % [player.party.size(), player.bench.size()])
	panel.close()
	quit()
