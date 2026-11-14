extends SceneTree

# The Debug menu's console (DebugConsole.gd): any GDScript expression runs against the live game, assignments (= += -= *= /=) reach a
# variable, a Dictionary key, an Array item, and the Debug menu's own actions are one call away. No screen is needed.

const ConsoleScript := preload("res://scripts/DebugConsole.gd")

func _init() -> void:
	seed(20261108)
	var main = load("res://Main.tscn").instantiate()
	main.regional_world = false
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	print("--- reading")
	player.coins = 120
	var r: Dictionary = ConsoleScript.run(main, "player.coins")
	print("a variable: ok=%s value=%s (expected true, 120)" % [r.ok, r.value])
	r = ConsoleScript.run(main, "player.coins + 5 * 2")
	print("arithmetic on it: %s (expected 130)" % [r.value])
	r = ConsoleScript.run(main, "player.coins == 120")
	print("== is a comparison, not an assignment: %s, coins still %d (expected true, 120)" % [r.value, player.coins])
	r = ConsoleScript.run(main, "\"a=b\"")
	print("an = inside a string is just text: %s (expected \"a=b\")" % [r.msg])
	r = ConsoleScript.run(main, "player.max_health >= 1 and player.level <= 99")
	print(">= and <= are comparisons: %s (expected true)" % [r.value])
	r = ConsoleScript.run(main, "_any_town_panel_open()")
	print("a bare name is looked up on Main (its private functions too): %s (expected false)" % [r.value])
	r = ConsoleScript.run(main, "Vector2i(3, 2) + Vector2i(1, 1)")
	print("built-in types work: %s (expected (4, 3))" % [r.value])

	print("--- assigning")
	r = ConsoleScript.run(main, "player.coins = 500")
	print("set a variable: ok=%s coins=%d (expected true, 500)" % [r.ok, player.coins])
	print("...and it says what it was: '%s' (expected player.coins = 500   (was 120))" % [r.msg])
	ConsoleScript.run(main, "player.coins += 25")
	ConsoleScript.run(main, "player.coins -= 5")
	ConsoleScript.run(main, "player.coins *= 2")
	ConsoleScript.run(main, "player.coins /= 4")
	print("+= -= *= /= : %d (expected 260)" % [player.coins])
	ConsoleScript.run(main, "player.coins = 12.7")
	print("a fraction into a whole-number variable rounds: %d (expected 13)" % [player.coins])
	ConsoleScript.run(main, "player.debug_god_mode = true")
	print("a bool: %s (expected true)" % [player.debug_god_mode])
	player.debug_god_mode = false
	ConsoleScript.run(main, "player.debug_speed_mult = 2")
	print("a whole number into a float variable: %s (expected 2.0)" % [player.debug_speed_mult])
	player.debug_speed_mult = 1.0
	ConsoleScript.run(main, "main.battle_player_tile = Vector2i(3, 2)")
	print("a Vector2i: %s (expected (3, 2))" % [main.battle_player_tile])
	ConsoleScript.run(main, "player.coins = 1 ; player.runic_shards = 7")
	print("two statements in a row: %d and %d (expected 1, 7)" % [player.coins, player.runic_shards])
	r = ConsoleScript.run(main, "player.coins = \"x;y\".length()")
	print("a ; inside a string does not split: coins=%d (expected 3)" % [player.coins])

	print("--- dictionaries and arrays (a battle unit is a Dictionary)")
	main.battle_units = [{"name": "Goblin", "hp": 9, "max_hp": 9, "tile": Vector2i(4, 1), "burning": false}]
	ConsoleScript.run(main, "units[0].hp = 1")
	print("units[0].hp = 1: %d (expected 1)" % [main.battle_units[0].hp])
	ConsoleScript.run(main, "units[0][\"max_hp\"] = 40")
	print("units[0][\"max_hp\"] = 40: %d (expected 40)" % [main.battle_units[0].max_hp])
	ConsoleScript.run(main, "units[0].burning = true")
	print("a flag on a unit: %s (expected true)" % [main.battle_units[0].burning])
	ConsoleScript.run(main, "units[0].tile = Vector2i(2, 2)")
	print("a tile on a unit: %s (expected (2, 2))" % [main.battle_units[0].tile])
	r = ConsoleScript.run(main, "units[0].poison_turns = 3")
	print("a key it did not have is added: %s, says '%s' (expected 3, ... new key)" % [main.battle_units[0].get("poison_turns"), r.msg])
	ConsoleScript.run(main, "units[0].hp += 4")
	print("compound on a key: %d (expected 5)" % [main.battle_units[0].hp])
	r = ConsoleScript.run(main, "units[3].hp = 1")
	print("an item that is not there: ok=%s (expected false)" % [r.ok])
	r = ConsoleScript.run(main, "units.size()")
	print("the units list is the live battle: %d (expected 1)" % [r.value])
	main.battle_units = []

	print("--- calling things")
	r = ConsoleScript.run(main, "A.set_level(main, 3)")
	print("the Debug actions are A: ok=%s, level now %d (expected true, 3)" % [bool(r.value.ok) if r.value is Dictionary else r.ok, player.level])
	print("...and the console says the action's own words: '%s' (expected Level 3.)" % [r.msg])
	r = ConsoleScript.run(main, "B.end_my_turn(main)")
	print("an action that refuses shows as an error with its reason: ok=%s, '%s' (expected false, There is no battle.)" % [r.ok, r.msg])
	r = ConsoleScript.run(main, "A.set_coins(main, 777)")
	print("another one: coins %d (expected 777)" % [player.coins])
	r = ConsoleScript.run(main, "player.heal(1)")
	print("a method call runs: ok=%s (expected true)" % [r.ok])
	r = ConsoleScript.run(main, "Weapons.CLUB.name")
	print("the data scripts are in scope: %s (expected \"Club\")" % [r.msg])
	r = ConsoleScript.run(main, "party.size()")
	print("party is the roster: %s (expected 0 or more, a number)" % [r.value])

	print("--- mistakes say so and change nothing")
	var before: int = player.coins
	r = ConsoleScript.run(main, "player.not_a_thing = 5")
	print("an unknown variable: ok=%s, says '%s' (expected false, ... has no variable called 'not_a_thing')" % [r.ok, r.msg.substr(0, 60)])
	r = ConsoleScript.run(main, "player.coins = ")
	print("nothing to assign: ok=%s (expected false)" % [r.ok])
	r = ConsoleScript.run(main, "player.coins = (")
	print("a broken expression: ok=%s, coins still %d (expected false, %d)" % [r.ok, player.coins, before])
	r = ConsoleScript.run(main, "1 +")
	print("a half sentence: ok=%s (expected false)" % [r.ok])
	r = ConsoleScript.run(main, "nothing_here.x")
	print("an unknown name: ok=%s (expected false)" % [r.ok])
	r = ConsoleScript.run(main, "player.coins = 1 ; player.nope = 2 ; player.coins = 99")
	print("a statement that fails stops the rest: coins=%d (expected 1)" % [player.coins])
	r = ConsoleScript.run(main, "main.battle_player_tile.x = 5")
	print("a part of a Vector2i can't be set, and it says how: ok=%s (expected false)" % [r.ok])

	print("--- listing")
	r = ConsoleScript.run(main, "props player coin")
	print("props lists matching variables: %s (expected true) -> %s" % [r.lines.any(func(l): return str(l).begins_with("coins = ")), r.lines.slice(0, 2)])
	r = ConsoleScript.run(main, "props player")
	print("without a word it lists them all, capped: %d lines (expected 81 or fewer, more than 20)" % [r.lines.size()])
	r = ConsoleScript.run(main, "methods player heal")
	print("methods lists matching ones: %s (expected true)" % [r.lines.any(func(l): return str(l).begins_with("heal("))])
	main.battle_units = [{"name": "Goblin", "hp": 9}]
	r = ConsoleScript.run(main, "props units[0]")
	print("props on a Dictionary lists its keys: %s (expected true)" % [r.lines.has("hp = 9")])
	main.battle_units = []
	r = ConsoleScript.run(main, "help")
	print("help prints a few lines: %d (expected 7)" % [r.lines.size()])
	r = ConsoleScript.run(main, "")
	print("an empty line does nothing: ok=%s lines=%d (expected true, 0)" % [r.ok, r.lines.size()])

	print("--- the Object / value display")
	r = ConsoleScript.run(main, "player")
	print("an object shows its kind: %s (expected a <Player...> tag)" % [r.msg])
	r = ConsoleScript.run(main, "player.coins")
	print("a number shows plain: %s (expected 1)" % [r.msg])

	await _inspector_logic(main, player)
	await _tab_ui(main, player)
	quit()

# ---------------------------------------------------------------------------------------------------------------------------
# The Inspector's logic
# ---------------------------------------------------------------------------------------------------------------------------

func _inspector_logic(main, player) -> void:
	var ins = load("res://scripts/DebugInspector.gd")
	print("--- the Inspector: what can be looked at")
	player.party.clear()
	player.bench.clear()
	player.max_party_slots = 6
	var knight = player.recruit("knight")
	var wolf = player.recruit("wolf")
	player.send_to_bench(wolf.id)
	var ids: Array = ins.roots(main).map(func(e): return str(e.id))
	print("outside a battle: you, the game, settings, the Knight, the benched Wolf, your weapon: %s (expected player, main, settings, member, bench, weapon)" % [
		ids.map(func(i): return i.get_slice(":", 0))])
	main.in_battle = true
	main.battle_units = [{"name": "Goblin", "hp": 9, "max_hp": 9, "tile": Vector2i(4, 1)}, {"name": "Orc", "hp": 20, "max_hp": 20, "tile": Vector2i(5, 2)}]
	main.battle_allies = [{"name": "Knight", "hp": 30, "max_hp": 30, "tile": Vector2i(1, 1)}]
	ids = ins.roots(main).map(func(e): return str(e.id))
	print("in a battle the units and the terrain join them: enemy:1=%s ally:0=%s terrain=%s (expected true, true, true)" % [ids.has("enemy:1"), ids.has("ally:0"), ids.has("terrain")])
	var res: Dictionary = ins.resolve(main, "enemy:1", [])
	print("an enemy resolves to its Dictionary: %s, label %s (expected Orc, units[1])" % [res.value.name, res.label])
	res = ins.resolve(main, "enemy:1", ["tile"])
	print("walking into a key: %s (expected (5, 2)), label %s (expected units[1][\"tile\"])" % [res.value, res.label])
	res = ins.resolve(main, "player", ["owned_weapons"])
	print("walking into a variable that is a Dictionary: ok=%s, is a Dictionary: %s (expected true, true)" % [res.ok, res.value is Dictionary])
	res = ins.resolve(main, "main", ["battle_units", 0, "name"])
	print("two steps deep, through an Array then a Dictionary: %s (expected Goblin)" % [res.value])
	res = ins.resolve(main, "enemy:9", [])
	print("a unit that is gone: ok=%s (expected false)" % [res.ok])
	res = ins.resolve(main, "player", ["no_such_variable"])
	print("a path that does not exist: ok=%s (expected false)" % [res.ok])

	print("--- the rows")
	var rows: Array = ins.entries(main.battle_units[1])
	var keys: Array = rows.map(func(e): return str(e.key))
	print("a unit's rows are its keys, sorted: %s (expected hp first among hp, max_hp, name, tile)" % [keys.slice(0, 4)])
	rows = ins.entries(main.battle_units[1], "hp")
	print("the search narrows by name: %s (expected [hp, max_hp])" % [rows.map(func(e): return str(e.key))])
	rows = ins.entries(player, "coins")
	print("you: a search for coins finds it, with its value: %s (expected true)" % [rows.any(func(e): return str(e.key) == "coins")])
	var node_rows: Array = ins.entries(player, "position")
	print("a Node shows its position without the engine switch: %s (expected true)" % [node_rows.any(func(e): return str(e.key) == "position")])
	var engine_rows: Array = ins.entries(player, "", true)
	var plain_rows: Array = ins.entries(player, "", false)
	print("the Engine switch adds more rows: %s (expected true)" % [engine_rows.size() > plain_rows.size()])
	print("an Array's rows are its indices: %s (expected [0, 1])" % [ins.entries(main.battle_units).map(func(e): return e.key)])

	print("--- how each kind of value is edited")
	var kinds := {"int": 5, "float": 0.5, "bool": true, "text": "x", "vector2i": Vector2i(1, 2), "vector2": Vector2(1, 2), "color": Color.RED, "open": {}, "readonly": null}
	var wrong := []
	for want in kinds:
		if ins.editor_for(kinds[want]) != want:
			wrong.append(want)
	print("each kind of value gets its editor: wrong=%s (expected [])" % [wrong])
	print("an Array also steps in: %s (expected open)" % [ins.editor_for([1, 2])])
	var p: Dictionary = ins.parse_edit("12", 3)
	print("a whole number: %s (expected true, 12)" % [[p.ok, p.value]])
	p = ins.parse_edit("2.6", 3)
	print("a fraction into a whole-number row rounds: %s (expected 3)" % [p.value])
	p = ins.parse_edit("abc", 3)
	print("words in a number row: ok=%s (expected false)" % [p.ok])
	p = ins.parse_edit("off", true)
	print("off for a switch: %s (expected false)" % [p.value])
	p = ins.parse_edit("3, 4", Vector2i.ZERO)
	print("a tile: %s (expected (3, 4))" % [p.value])
	p = ins.parse_edit("(5,6)", Vector2i.ZERO)
	print("a tile in brackets: %s (expected (5, 6))" % [p.value])
	p = ins.parse_edit("3", Vector2i.ZERO)
	print("half a tile: ok=%s (expected false)" % [p.ok])
	p = ins.parse_edit("#ff0000", Color.BLUE)
	print("a colour: %s (expected true)" % [p.value == Color.RED])
	var edit: Dictionary = ins.apply_edit(main.battle_units[1], "hp", "7", "units[1].hp")
	print("an edit lands in the unit: ok=%s hp=%d (expected true, 7)" % [edit.ok, main.battle_units[1].hp])
	edit = ins.apply_edit(main.battle_units[1], "tile", "2, 2", "units[1].tile")
	print("a tile edit: %s (expected (2, 2))" % [main.battle_units[1].tile])
	edit = ins.apply_edit(player, "coins", "4242", "player.coins")
	print("an edit on you: %d (expected 4242)" % [player.coins])
	edit = ins.apply_edit(player, "coins", "lots", "player.coins")
	print("a bad edit changes nothing: ok=%s coins=%d (expected false, 4242)" % [edit.ok, player.coins])
	edit = ins.apply_edit(main.battle_units, 0, "x", "units[0]")
	print("an Array item that holds a Dictionary can't be typed over: ok=%s (expected false)" % [edit.ok])
	main.in_battle = false
	main.battle_units = []
	main.battle_allies = []
	player.party.clear()
	player.bench.clear()

# ---------------------------------------------------------------------------------------------------------------------------
# The Console tab on screen
# ---------------------------------------------------------------------------------------------------------------------------

func _find_all(node: Node, matches: Callable, out: Array) -> void:
	if matches.call(node):
		out.append(node)
	for c in node.get_children():
		_find_all(c, matches, out)

func _tab_ui(main, player) -> void:
	print("--- the Console tab")
	var settings = root.get_node("Settings")
	var was: bool = settings.debug_menu_enabled
	settings.debug_menu_enabled = true
	var menu = main.debug_menu
	menu.open()
	await process_frame
	await process_frame
	menu._select_tab("Console")
	await process_frame
	var view = menu.view
	print("the tab exists and builds: %s (expected true)" % [menu.TABS.any(func(t): return t[0] == "Console")])
	var inputs: Array = []
	_find_all(view, func(n): return n is LineEdit, inputs)
	print("it has a box to type in, which the menu focuses first: %s (expected true)" % [view.preferred_focus() != null])
	player.coins = 10
	view._submit("player.coins = 321")
	print("typing a command and pressing Enter runs it: coins=%d (expected 321)" % [player.coins])
	var lines: int = view.cs.lines.size()
	print("...and the answer is listed under what was typed: %d lines (expected 3: the hint, the command, the answer)" % [lines])
	view._submit("player.nope = 1")
	print("a mistake is listed too, as an error: last line type '%s' (expected err)" % [view.cs.lines[view.cs.lines.size() - 1].t])
	view._submit("player.coins")
	view._submit("player.coins")
	print("the same command twice is remembered once: history=%s (expected 3 distinct)" % [view.cs.history.size()])
	var up := InputEventKey.new()
	up.keycode = KEY_UP
	up.pressed = true
	view._input_key(up)
	print("Up recalls the last command: '%s' (expected player.coins)" % [view._input.text])
	view._input_key(up)
	print("Up again goes further back: '%s' (expected player.nope = 1)" % [view._input.text])
	var down := InputEventKey.new()
	down.keycode = KEY_DOWN
	down.pressed = true
	view._input_key(down)
	view._input_key(down)
	print("Down past the end empties the box: '%s' (expected nothing)" % [view._input.text])
	view._submit("clear")
	print("clear empties the list: %d (expected 0)" % [view.cs.lines.size()])

	print("--- the Inspector page")
	player.coins = 55
	menu.open_inspector("player")
	await process_frame
	view = menu.view
	print("open_inspector switches to the Console tab's Inspector page: tab=%s page=%s (expected Console, Inspector)" % [menu.active_tab, view.cs.page])
	var fields: Array = []
	_find_all(view, func(n): return n is LineEdit and n.text == "55", fields)
	print("your coins are a row with a field showing 55: %d (expected 1 or more)" % [fields.size()])
	view.ins["search"] = "coins"
	view.refresh()
	await process_frame
	fields.clear()
	_find_all(view, func(n): return n is LineEdit and n.text == "55", fields)
	fields[0].text_submitted.emit("901")
	print("typing a value into its field and pressing Enter edits it: coins=%d (expected 901)" % [player.coins])
	menu.open_inspector("main")
	await process_frame
	view = menu.view
	view.ins["search"] = "battle_units"
	view.refresh()
	await process_frame
	var opens: Array = []
	_find_all(view, func(n): return n is PixelButton and n.text == "Open", opens)
	print("a variable that holds an Array has an Open button: %d (expected 1)" % [opens.size()])
	opens[0].pressed.emit()
	await process_frame
	print("Open steps into it: path=%s (expected [battle_units])" % [view.ins.path])
	var ups: Array = []
	_find_all(menu.view, func(n): return n is PixelButton and n.text == "Up", ups)
	print("and an Up button appears: %d (expected 1)" % [ups.size()])
	ups[0].pressed.emit()
	await process_frame
	print("Up steps back out: path=%s (expected [])" % [menu.view.ins.path])
	menu.close()
	settings.debug_menu_enabled = was
