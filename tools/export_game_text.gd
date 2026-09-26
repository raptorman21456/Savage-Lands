extends SceneTree

# One-off dev tool: fills in res://text/strings.json with the game's current
# default text, using the exact same key scheme GameText.gd applies at boot.
# Run it after adding a new category to GameText.gd's _process_all(), or to
# bootstrap the file for the first time. Run via:
#   godot --headless --path . --script tools/export_game_text.gd
#
# Only ADDS keys that aren't already in the file -- an existing value (yours,
# hand-edited) is never touched or overwritten. Safe to re-run any time.

# Which section a key belongs in, purely from its own shape (a prefix like
# "shopkeeper."/"beastiary.", or a "field name" suffix after the last dot) --
# never from a lookup table of every key that could ever exist, so a
# category GameText.gd adds later just falls into "other" instead of
# silently needing this function updated too.
func _text_bucket(key: String) -> String:
	if key.begins_with("shopkeeper."):
		return "shopkeeper"
	if key.begins_with("ui."):
		return "ui"
	if key.begins_with("beastiary."):
		return "beastiary"
	var field: String = key.split(".")[-1]
	if field in ["name", "description", "shop_description", "yes_label", "no_label"]:
		return field
	return "other"

func _init() -> void:
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame

	var game_text = root.get_node("/root/GameText")
	var defaults: Dictionary = game_text.export_defaults()

	var existing := {}
	if FileAccess.file_exists("res://text/strings.json"):
		var rf := FileAccess.open("res://text/strings.json", FileAccess.READ)
		var parsed = JSON.parse_string(rf.get_as_text())
		rf.close()
		if parsed is Dictionary:
			existing = parsed

	var added := 0
	for key in defaults:
		if not existing.has(key):
			existing[key] = defaults[key]
			added += 1

	# Grouped by TYPE OF LINE first (all names together, all descriptions
	# together, all shopkeeper barks together, etc.), alphabetical by full
	# key within each group -- easier to scan/hand-edit one kind of text at
	# a time than the old flat alphabetical order, which just grouped by
	# item (a weapon's name/description/shop_description together, then the
	# next weapon's, etc.) instead.
	var bucket_order := ["shopkeeper", "ui", "beastiary", "name", "description", "shop_description", "yes_label", "no_label", "other"]
	var buckets := {}
	for b in bucket_order:
		buckets[b] = []
	for key in existing:
		buckets[_text_bucket(key)].append(key)
	for b in bucket_order:
		buckets[b].sort()

	var ordered_keys := []
	for b in bucket_order:
		ordered_keys.append_array(buckets[b])

	# JSON.stringify() on a Dictionary always alphabetizes its keys during
	# serialization -- confirmed directly (a {"zzz":.., "aaa":.., "mmm":..}
	# dict comes back key-sorted regardless of insertion order) -- so handing
	# it the bucketed `ordered` dict as a whole would silently undo all of
	# the grouping above. Writing the object by hand instead, one line per
	# key in the exact order this file wants, using JSON.stringify only per
	# VALUE (and per KEY) so string escaping still matches what it would
	# have produced.
	var lines := PackedStringArray()
	for k in ordered_keys:
		lines.append("\t%s: %s" % [JSON.stringify(k), JSON.stringify(existing[k])])
	var text := "{\n" + ",\n".join(lines) + "\n}"

	var f := FileAccess.open("res://text/strings.json", FileAccess.WRITE)
	f.store_string(text)
	f.close()
	print("strings.json now has %d string(s) total (%d newly added, nothing existing was changed)." % [ordered_keys.size(), added])
	quit()
