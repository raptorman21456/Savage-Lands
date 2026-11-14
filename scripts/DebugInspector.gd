extends RefCounted

# The Debug menu's Inspector, without the screen: what can be looked at (you, the game, the settings, each party member, every unit on
# the battle grid), how to walk into a variable that holds more variables (a Dictionary, an Array, another object), the rows to show for
# whatever is open, and how a typed edit becomes a value of the right type. The Console tab's second page is built on this; every edit
# goes through DebugConsole.set_in, the same way a typed assignment does.

const ConsoleScript := preload("res://scripts/DebugConsole.gd")

# Engine variables worth showing next to a Node's own (the rest are behind the "Engine" switch).
const NODE_BASICS := ["position", "global_position", "visible", "scale", "modulate", "z_index"]

static func ok(msg: String, value = null) -> Dictionary:
	return {"ok": true, "msg": msg, "value": value}

static func fail(msg: String) -> Dictionary:
	return {"ok": false, "msg": msg, "value": null}

# --- what can be looked at ----------------------------------------------------------------------------------------------

# The things to pick from: [{id, label}]. Ids are stable across rebuilds ("member:7" is that party member, "enemy:1" the second enemy).
static func roots(main) -> Array:
	var out: Array = [
		{"id": "player", "label": "You"}, {"id": "main", "label": "The game"}, {"id": "settings", "label": "Settings"},
	]
	for m in main.player.party:
		out.append({"id": "member:%d" % int(m.id), "label": str(m.name)})
	for m in main.player.bench:
		out.append({"id": "bench:%d" % int(m.id), "label": "%s (bench)" % str(m.name)})
	if bool(main.in_battle):
		for i in main.battle_allies.size():
			out.append({"id": "ally:%d" % i, "label": "Ally: %s" % str(main.battle_allies[i].get("name", "?"))})
		for i in main.battle_units.size():
			out.append({"id": "enemy:%d" % i, "label": "Enemy %d: %s" % [i + 1, str(main.battle_units[i].get("name", "?"))]})
		out.append({"id": "terrain", "label": "Terrain"})
	out.append({"id": "weapon", "label": "Your weapon"})
	return out

# The thing a root id stands for: {ok, value, label}.
static func root_value(main, root_id: String) -> Dictionary:
	var p = main.player
	match root_id:
		"player": return {"ok": true, "value": p, "label": "player"}
		"main": return {"ok": true, "value": main, "label": "main"}
		"settings": return {"ok": true, "value": main.settings, "label": "settings"}
		"weapon": return {"ok": true, "value": p.current_weapon, "label": "player.current_weapon"}
		"terrain": return {"ok": true, "value": main.battle_terrain, "label": "main.battle_terrain"}
	var kind: String = root_id.get_slice(":", 0)
	var n: int = int(root_id.get_slice(":", 1))
	match kind:
		"member":
			for m in p.party:
				if int(m.id) == n:
					return {"ok": true, "value": m, "label": "member %s" % str(m.name)}
		"bench":
			for m in p.bench:
				if int(m.id) == n:
					return {"ok": true, "value": m, "label": "bench %s" % str(m.name)}
		"ally":
			if bool(main.in_battle) and n >= 0 and n < main.battle_allies.size():
				return {"ok": true, "value": main.battle_allies[n], "label": "allies[%d]" % n}
		"enemy":
			if bool(main.in_battle) and n >= 0 and n < main.battle_units.size():
				return {"ok": true, "value": main.battle_units[n], "label": "units[%d]" % n}
	return {"ok": false, "value": null, "label": root_id}

# Walks `path` (a list of keys: a variable name, a Dictionary key, an Array index) down from the root: {ok, value, label}.
static func resolve(main, root_id: String, path: Array) -> Dictionary:
	var r: Dictionary = root_value(main, root_id)
	if not bool(r.ok):
		return {"ok": false, "value": null, "label": root_id}
	var value = r.value
	var label: String = str(r.label)
	for key in path:
		if value is Object and is_instance_valid(value):
			if not ConsoleScript.has_property(value, str(key)):
				return {"ok": false, "value": null, "label": label}
			value = value.get(str(key))
			label += ".%s" % str(key)
		elif value is Dictionary and value.has(key):
			value = value[key]
			label += "[%s]" % _key_text(key)
		elif value is Array and typeof(key) == TYPE_INT and key >= 0 and key < value.size():
			value = value[key]
			label += "[%d]" % int(key)
		else:
			return {"ok": false, "value": null, "label": label}
	return {"ok": true, "value": value, "label": label}

static func _key_text(key) -> String:
	return "\"%s\"" % str(key) if typeof(key) == TYPE_STRING or typeof(key) == TYPE_STRING_NAME else str(key)

# --- the rows ------------------------------------------------------------------------------------------------------------

# One row per variable of `value`: [{key, value}]. `needle` narrows by name; `engine` adds a Node's engine variables.
static func entries(value, needle: String = "", engine: bool = false) -> Array:
	var out: Array = []
	var low := needle.to_lower()
	if value is Object and is_instance_valid(value):
		var names: Array = ConsoleScript.script_variable_names(value)
		if value is Node:
			for n in NODE_BASICS:
				if not names.has(n):
					names.append(n)
		if engine:
			for p in value.get_property_list():
				var name := str(p.name)
				if int(p.usage) & PROPERTY_USAGE_EDITOR and not names.has(name) and name != "script" and not name.contains("/"):
					names.append(name)
		for name in names:
			if low != "" and not str(name).to_lower().contains(low):
				continue
			out.append({"key": str(name), "value": value.get(str(name))})
	elif value is Dictionary:
		var keys: Array = value.keys()
		keys.sort_custom(func(a, b): return str(a) < str(b))
		for k in keys:
			if low != "" and not str(k).to_lower().contains(low):
				continue
			out.append({"key": k, "value": value[k]})
	elif value is Array:
		for i in value.size():
			if low != "" and not str(i).contains(low) and not ConsoleScript.show(value[i]).to_lower().contains(low):
				continue
			out.append({"key": i, "value": value[i]})
	return out

# How a row is edited: "int", "float", "bool", "text", "vector2i", "vector2", "color", "open" (holds more variables: step into it),
# or "readonly".
static func editor_for(value) -> String:
	match typeof(value):
		TYPE_INT: return "int"
		TYPE_FLOAT: return "float"
		TYPE_BOOL: return "bool"
		TYPE_STRING, TYPE_STRING_NAME: return "text"
		TYPE_VECTOR2I: return "vector2i"
		TYPE_VECTOR2: return "vector2"
		TYPE_COLOR: return "color"
		TYPE_DICTIONARY, TYPE_ARRAY: return "open"
		TYPE_OBJECT:
			return "open" if value != null and is_instance_valid(value) else "readonly"
	return "readonly"

# What a row says next to its name when it has no field of its own.
static func summary(value) -> String:
	if value is Dictionary:
		return "Dictionary, %d key%s" % [value.size(), "" if value.size() == 1 else "s"]
	if value is Array:
		return "Array, %d item%s" % [value.size(), "" if value.size() == 1 else "s"]
	return ConsoleScript.show(value)

# What typed text means for a row whose current value is `current`: {ok, value} or {ok: false, msg}.
static func parse_edit(text: String, current) -> Dictionary:
	var t := text.strip_edges()
	match typeof(current):
		TYPE_INT:
			if not (t.is_valid_int() or t.is_valid_float()):
				return fail("'%s' is not a number." % t)
			return ok("", int(round(t.to_float())))
		TYPE_FLOAT:
			if not (t.is_valid_float() or t.is_valid_int()):
				return fail("'%s' is not a number." % t)
			return ok("", t.to_float())
		TYPE_BOOL:
			var low := t.to_lower()
			if low in ["true", "on", "yes", "1"]:
				return ok("", true)
			if low in ["false", "off", "no", "0"]:
				return ok("", false)
			return fail("'%s' is not on or off." % t)
		TYPE_STRING:
			return ok("", text)
		TYPE_STRING_NAME:
			return ok("", StringName(text))
		TYPE_VECTOR2I, TYPE_VECTOR2:
			var parts: PackedStringArray = t.trim_prefix("(").trim_suffix(")").split(",")
			if parts.size() != 2 or not parts[0].strip_edges().is_valid_float() or not parts[1].strip_edges().is_valid_float():
				return fail("Write it as  x, y")
			var x: float = parts[0].strip_edges().to_float()
			var y: float = parts[1].strip_edges().to_float()
			if typeof(current) == TYPE_VECTOR2I:
				return ok("", Vector2i(int(round(x)), int(round(y))))
			return ok("", Vector2(x, y))
		TYPE_COLOR:
			if not Color.html_is_valid(t):
				return fail("Write a colour as  #rrggbb")
			return ok("", Color.html(t))
	return fail("That kind of value can't be typed in; use the Console.")

# What goes in the field for a row (the text it starts with).
static func field_text(value) -> String:
	match typeof(value):
		TYPE_FLOAT:
			return ("%.3f" % float(value)).rstrip("0").rstrip(".") if not is_equal_approx(float(value), round(float(value))) else str(int(value))
		TYPE_VECTOR2I:
			return "%d, %d" % [value.x, value.y]
		TYPE_VECTOR2:
			return "%s, %s" % [str(snappedf(value.x, 0.01)), str(snappedf(value.y, 0.01))]
		TYPE_COLOR:
			return "#" + value.to_html()
	return str(value)

# Sets one row of whatever is open (`holder`) from typed text.
static func apply_edit(holder, key, text: String, label: String) -> Dictionary:
	var current = null
	if holder is Object and is_instance_valid(holder):
		current = holder.get(str(key))
	elif holder is Dictionary:
		current = holder.get(key)
	elif holder is Array and typeof(key) == TYPE_INT and key >= 0 and key < holder.size():
		current = holder[key]
	var parsed: Dictionary = parse_edit(text, current)
	if not bool(parsed.ok):
		return {"ok": false, "msg": str(parsed.msg), "lines": [str(parsed.msg)], "value": null}
	return ConsoleScript.set_in(holder, key, parsed.value, label)
