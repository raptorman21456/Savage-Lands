extends RefCounted

# The Debug menu's way to do LITERALLY anything: type a GDScript expression or an assignment and it runs against the live game.
#
#   player.coins = 500                    set a variable (also  +=  -=  *=  /=)
#   units[0].hp = 1                       a battle unit is a Dictionary: .name or ["name"] both work
#   main.battle_player_tile = Vector2i(3, 2)
#   player.heal(50)                       call any method, its answer is printed
#   _finish_enemy_actions([])             bare names are looked up on Main itself, so its own private functions work too
#   A.set_level(main, 20)                 the Debug menu's own actions: A (player and items), B (battles), W (world), P (progress)
#   props player coin                     list a thing's variables and their values (an optional filter word narrows it)
#   methods main battle                   list a thing's methods
#   a ; b                                 several statements in a row
#
# Names in scope: main, player, hud, settings, party, bench, units (the enemies in the battle), allies, tree, plus A B W P and the
# game's data scripts (Weapons, Armor, Shields, Talismans, Potions, Clothing, PartyRules, SaveData). Everything here is static and
# returns plain results, so a test can drive it with no screen.

const DebugActionsScript := preload("res://scripts/DebugActions.gd")
const DebugBattleScript := preload("res://scripts/DebugBattle.gd")
const DebugWorldScript := preload("res://scripts/DebugWorld.gd")
const DebugProgressScript := preload("res://scripts/DebugProgress.gd")
const WeaponsScript := preload("res://scripts/Weapons.gd")
const ArmorScript := preload("res://scripts/Armor.gd")
const ShieldsScript := preload("res://scripts/Shields.gd")
const TalismansScript := preload("res://scripts/Talismans.gd")
const PotionsScript := preload("res://scripts/Potions.gd")
const ClothingScript := preload("res://scripts/Clothing.gd")
const PartyRulesScript := preload("res://scripts/PartyRules.gd")
const SaveDataScript := preload("res://scripts/SaveData.gd")

const MAX_LINE := 400            # one printed value is cut here
const MAX_LISTED := 80           # lines `props` and `methods` print

const HELP_LINES := [
	"Type an expression and press Enter: its answer is printed.   player.max_health   units.size()   main.battle_turn",
	"Assign with =  += -= *= /=:   player.coins = 500   units[0].hp = 1   main.battle_player_tile = Vector2i(3, 2)",
	"Call anything:   player.heal(50)   A.set_level(main, 20)   _battle_victory()   (bare names are looked up on Main)",
	"props <thing> [word]   lists variables and values (props player coin)      methods <thing> [word]   lists methods",
	"Several statements:  player.coins = 99 ; player.runic_shards = 9",
	"In scope: main player hud settings party bench units allies tree  |  A B W P (Debug actions)  |  Weapons Armor Shields",
	"Talismans Potions Clothing PartyRules SaveData.     Up / Down recalls what you typed.   `clear` empties this list.",
]

static func ok(msg: String, lines: Array = [], value = null) -> Dictionary:
	return {"ok": true, "msg": msg, "lines": lines, "value": value}

static func fail(msg: String, lines: Array = []) -> Dictionary:
	return {"ok": false, "msg": msg, "lines": lines if not lines.is_empty() else [msg], "value": null}

# --- what is in scope ---------------------------------------------------------------------------------------------------

static func context(main) -> Dictionary:
	return {
		"main": main, "player": main.player, "hud": main.hud, "settings": main.settings,
		"party": main.player.party, "bench": main.player.bench,
		"units": main.battle_units, "allies": main.battle_allies, "tree": main.get_tree(),
		"A": DebugActionsScript.new(), "B": DebugBattleScript.new(), "W": DebugWorldScript.new(), "P": DebugProgressScript.new(),
		"Weapons": WeaponsScript, "Armor": ArmorScript, "Shields": ShieldsScript, "Talismans": TalismansScript,
		"Potions": PotionsScript, "Clothing": ClothingScript, "PartyRules": PartyRulesScript, "SaveData": SaveDataScript,
	}

# --- running a line ----------------------------------------------------------------------------------------------------

# Runs what was typed (one or more statements) and returns {ok, msg, lines, value}: `lines` is what to print under it.
static func run(main, text: String) -> Dictionary:
	var statements: Array = _split_top(text.strip_edges(), ";")
	var out: Array = []
	var last = null
	var did := 0
	for raw in statements:
		var s: String = str(raw).strip_edges()
		if s == "":
			continue
		var r: Dictionary = _run_one(main, s)
		out.append_array(r.lines)
		if not bool(r.ok):
			return {"ok": false, "msg": str(r.msg), "lines": out, "value": null}
		last = r.value
		did += 1
	if did == 0:
		return {"ok": true, "msg": "", "lines": [], "value": null}
	return {"ok": true, "msg": str(out[out.size() - 1]) if not out.is_empty() else "Done.", "lines": out, "value": last}

static func _run_one(main, s: String) -> Dictionary:
	if s == "help" or s == "?":
		return ok("Help.", HELP_LINES.duplicate())
	var words: PackedStringArray = s.split(" ", false)
	if words.size() >= 2 and (words[0] == "props" or words[0] == "methods"):
		return _list_command(main, words[0], s)
	var ctx: Dictionary = context(main)
	var op: Dictionary = _find_assignment(s)
	if not op.is_empty():
		return _assign(main, ctx, s.substr(0, int(op.index)).strip_edges(), str(op.op), s.substr(int(op.index) + str(op.op).length()).strip_edges())
	var r: Dictionary = _eval(main, ctx, s)
	if not bool(r.ok):
		return fail(str(r.error))
	# One of the Debug menu's own actions answers {ok, msg}: say its message (red when it refused) rather than the raw Dictionary.
	if r.value is Dictionary and r.value.has("ok") and r.value.has("msg") and typeof(r.value.ok) == TYPE_BOOL:
		var line := str(r.value.msg)
		return {"ok": bool(r.value.ok), "msg": line, "lines": [line], "value": r.value}
	return ok(show(r.value), [show(r.value)], r.value)

# Evaluates one expression: {ok, value} or {ok: false, error}.
static func _eval(main, ctx: Dictionary, expr_text: String) -> Dictionary:
	var e := Expression.new()
	var err: int = e.parse(expr_text, PackedStringArray(ctx.keys()))
	if err != OK:
		return {"ok": false, "error": "Can't read that: %s" % e.get_error_text()}
	var value = e.execute(ctx.values(), main, false)
	if e.has_execute_failed():
		return {"ok": false, "error": "That failed: %s" % e.get_error_text()}
	return {"ok": true, "value": value}

# --- assignment --------------------------------------------------------------------------------------------------------

# Where the assignment operator is in a statement: {index, op} for  =  +=  -=  *=  /=  (not ==  !=  <=  >=), or {} if there is none.
static func _find_assignment(s: String) -> Dictionary:
	var depth := 0
	var quote := ""
	var i := 0
	while i < s.length():
		var c: String = s[i]
		if quote != "":
			if c == "\\":
				i += 1
			elif c == quote:
				quote = ""
		elif c == "\"" or c == "'":
			quote = c
		elif c == "(" or c == "[" or c == "{":
			depth += 1
		elif c == ")" or c == "]" or c == "}":
			depth -= 1
		elif c == "=" and depth == 0:
			var prev: String = s[i - 1] if i > 0 else ""
			var next: String = s[i + 1] if i + 1 < s.length() else ""
			if next == "=":
				i += 1       # an  ==  comparison: skip both
			elif prev in ["!", "<", ">"]:
				pass         # !=  <=  >=
			elif prev in ["+", "-", "*", "/", "%"]:
				return {"index": i - 1, "op": prev + "="}
			else:
				return {"index": i, "op": "="}
		i += 1
	return {}

static func _assign(main, ctx: Dictionary, lhs: String, op: String, rhs: String) -> Dictionary:
	if lhs == "" or rhs == "":
		return fail("Write it as   thing = value")
	var value_text: String = rhs if op == "=" else "(%s) %s (%s)" % [lhs, op.trim_suffix("="), rhs]
	var r: Dictionary = _eval(main, ctx, value_text)
	if not bool(r.ok):
		return fail(str(r.error))
	var value = r.value
	# split the left side into what holds it and which part of it
	var base_text := ""
	var key_text := ""
	var by_index := false
	if lhs.ends_with("]"):
		var open := _matching_open(lhs)
		if open <= 0:
			return fail("Can't read the left side: %s" % lhs)
		base_text = lhs.substr(0, open)
		key_text = lhs.substr(open + 1, lhs.length() - open - 2)
		by_index = true
	else:
		var dot := _last_top_level_dot(lhs)
		if dot > 0:
			base_text = lhs.substr(0, dot)
			key_text = lhs.substr(dot + 1).strip_edges()
		else:
			key_text = lhs.strip_edges()
	if not by_index and not key_text.is_valid_identifier():
		return fail("'%s' is not a variable name." % key_text)
	var holder = main
	if base_text != "":
		var b: Dictionary = _eval(main, ctx, base_text)
		if not bool(b.ok):
			return fail(str(b.error))
		holder = b.value
	var key = key_text
	if by_index:
		var k: Dictionary = _eval(main, ctx, key_text)
		if not bool(k.ok):
			return fail(str(k.error))
		key = k.value
	return set_in(holder, key, value, lhs)

# Sets `key` inside `holder` (an Object's variable, a Dictionary's key or an Array's index), converting the number type to fit.
static func set_in(holder, key, value, label: String = "") -> Dictionary:
	if label == "":
		label = str(key)
	if holder is Object:
		if not is_instance_valid(holder):
			return fail("%s is gone." % label)
		var name := str(key)
		if not has_property(holder, name):
			return fail("%s has no variable called '%s'. (props <thing> lists them.)" % [_what(holder), name])
		var before = holder.get(name)
		var fitted = fit(value, before)
		holder.set(name, fitted)
		var after = holder.get(name)
		return ok("%s = %s   (was %s)" % [label, show(after), show(before)], ["%s = %s   (was %s)" % [label, show(after), show(before)]], after)
	if holder is Dictionary:
		var existed: bool = holder.has(key)
		var old_value = holder.get(key)
		holder[key] = fit(value, old_value) if existed else value
		var line := "%s = %s   (%s)" % [label, show(holder[key]), ("was %s" % show(old_value)) if existed else "new key"]
		return ok(line, [line], holder[key])
	if holder is Array:
		var index := int(key)
		if index < 0 or index >= holder.size():
			return fail("%s: there is no item %d (size %d)." % [label, index, holder.size()])
		var old_item = holder[index]
		holder[index] = fit(value, old_item)
		var line2 := "%s = %s   (was %s)" % [label, show(holder[index]), show(old_item)]
		return ok(line2, [line2], holder[index])
	return fail("Can't set something inside a %s. Assign the whole thing instead (for a Vector2i write  main.battle_player_tile = Vector2i(3, 2))." % type_string(typeof(holder)))

# A value turned into the type the thing it replaces has (a whole number stays whole, a Vector2 into a Vector2i...).
static func fit(value, current):
	match typeof(current):
		TYPE_INT:
			if typeof(value) == TYPE_FLOAT:
				return int(round(value))
			if typeof(value) == TYPE_BOOL:
				return 1 if value else 0
		TYPE_FLOAT:
			if typeof(value) == TYPE_INT or typeof(value) == TYPE_BOOL:
				return float(value)
		TYPE_BOOL:
			if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
				return value != 0
		TYPE_VECTOR2I:
			if typeof(value) == TYPE_VECTOR2:
				return Vector2i(value)
		TYPE_VECTOR2:
			if typeof(value) == TYPE_VECTOR2I:
				return Vector2(value)
		TYPE_STRING_NAME:
			if typeof(value) == TYPE_STRING:
				return StringName(value)
		TYPE_STRING:
			if typeof(value) == TYPE_STRING_NAME:
				return String(value)
	return value

static func has_property(obj: Object, name: String) -> bool:
	for p in obj.get_property_list():
		if str(p.name) == name:
			return true
	return false

# --- listing -------------------------------------------------------------------------------------------------------------

# `props <thing> [word]` and `methods <thing> [word]`.
static func _list_command(main, which: String, s: String) -> Dictionary:
	var rest: String = s.substr(which.length()).strip_edges()
	var ctx: Dictionary = context(main)
	# A last word after a space (outside brackets and quotes) is a filter, as long as what is left of it is a thing on its own;
	# otherwise the whole of it is the thing (props units[0], props player.coins + 1).
	var pieces: Array = _split_top(rest, " ")
	var r: Dictionary = {}
	var needle := ""
	if pieces.size() >= 2 and str(pieces[pieces.size() - 1]).strip_edges() != "":
		var left: String = " ".join(pieces.slice(0, pieces.size() - 1)).strip_edges()
		var left_result: Dictionary = _eval(main, ctx, left)
		if bool(left_result.ok):
			r = left_result
			needle = str(pieces[pieces.size() - 1]).strip_edges().to_lower()
	if r.is_empty():
		r = _eval(main, ctx, rest)
	if not bool(r.ok):
		return fail(str(r.error))
	var target = r.value
	var lines: Array = []
	if which == "props":
		lines = describe_props(target, needle)
	else:
		lines = describe_methods(target, needle)
	if lines.is_empty():
		lines = ["Nothing matches%s." % ((" '%s'" % needle) if needle != "" else "")]
	return ok("%d line%s." % [lines.size(), "" if lines.size() == 1 else "s"], lines)

static func script_variable_names(obj: Object) -> Array:
	var names: Array = []
	for p in obj.get_property_list():
		if int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and not str(p.name).ends_with(".gd"):
			names.append(str(p.name))
	return names

static func describe_props(target, needle: String = "") -> Array:
	var lines: Array = []
	if target is Object and is_instance_valid(target):
		for name in script_variable_names(target):
			if needle != "" and not name.to_lower().contains(needle):
				continue
			lines.append("%s = %s" % [name, show(target.get(name))])
	elif target is Dictionary:
		for key in target.keys():
			if needle != "" and not str(key).to_lower().contains(needle):
				continue
			lines.append("%s = %s" % [str(key), show(target[key])])
	elif target is Array:
		for i in target.size():
			lines.append("[%d] = %s" % [i, show(target[i])])
	else:
		lines.append(show(target))
	return _capped(lines)

static func describe_methods(target, needle: String = "") -> Array:
	var lines: Array = []
	var names: Array = []
	if target is Object and is_instance_valid(target):
		for m in target.get_method_list():
			var name := str(m.name)
			if names.has(name) or (needle != "" and not name.to_lower().contains(needle)):
				continue
			names.append(name)
			var args: Array = []
			for a in m.get("args", []):
				args.append(str(a.name))
			lines.append("%s(%s)" % [name, ", ".join(args)])
	else:
		lines.append("%s has no methods to list; try  props  on it." % type_string(typeof(target)))
	return _capped(lines)

static func _capped(lines: Array) -> Array:
	if lines.size() > MAX_LISTED:
		var extra: int = lines.size() - MAX_LISTED
		lines = lines.slice(0, MAX_LISTED)
		lines.append("... and %d more (add a word to narrow it)" % extra)
	return lines

# --- showing a value -----------------------------------------------------------------------------------------------------

static func _what(obj: Object) -> String:
	var script = obj.get_script()
	if script != null and str(script.resource_path) != "":
		return str(script.resource_path).get_file().get_basename()
	return obj.get_class()

static func show(v) -> String:
	var text := ""
	match typeof(v):
		TYPE_NIL:
			text = "null"
		TYPE_STRING:
			text = "\"%s\"" % str(v)
		TYPE_OBJECT:
			if v == null or not is_instance_valid(v):
				text = "<freed>"
			else:
				text = "<%s>" % _what(v)
				if v.has_method("get_display_name"):
					text = "<%s %s>" % [_what(v), str(v.get_display_name())]
				elif "name" in v and typeof(v.get("name")) == TYPE_STRING and str(v.get("name")) != "":
					text = "<%s %s>" % [_what(v), str(v.get("name"))]
		_:
			text = str(v)
	if text.length() > MAX_LINE:
		text = text.substr(0, MAX_LINE) + "..."
	return text

# --- reading a statement -------------------------------------------------------------------------------------------------

# Splits at `sep` where it is not inside quotes or brackets.
static func _split_top(s: String, sep: String) -> Array:
	var out: Array = []
	var depth := 0
	var quote := ""
	var start := 0
	var i := 0
	while i < s.length():
		var c: String = s[i]
		if quote != "":
			if c == "\\":
				i += 1
			elif c == quote:
				quote = ""
		elif c == "\"" or c == "'":
			quote = c
		elif c == "(" or c == "[" or c == "{":
			depth += 1
		elif c == ")" or c == "]" or c == "}":
			depth -= 1
		elif c == sep and depth == 0:
			out.append(s.substr(start, i - start))
			start = i + 1
		i += 1
	out.append(s.substr(start))
	return out

# The `[` that closes with the final `]` of s.
static func _matching_open(s: String) -> int:
	var depth := 0
	var i := s.length() - 1
	while i >= 0:
		if s[i] == "]":
			depth += 1
		elif s[i] == "[":
			depth -= 1
			if depth == 0:
				return i
		i -= 1
	return -1

# The last `.` outside quotes and brackets (the start of the final name), or -1.
static func _last_top_level_dot(s: String) -> int:
	var depth := 0
	var quote := ""
	var found := -1
	var i := 0
	while i < s.length():
		var c: String = s[i]
		if quote != "":
			if c == "\\":
				i += 1
			elif c == quote:
				quote = ""
		elif c == "\"" or c == "'":
			quote = c
		elif c == "(" or c == "[" or c == "{":
			depth += 1
		elif c == ")" or c == "]" or c == "}":
			depth -= 1
		elif c == "." and depth == 0:
			found = i
		i += 1
	return found
