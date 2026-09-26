extends SceneTree

# Shopkeeper.get_item_line: per-weapon-type reactions layered on top of a
# hovered weapon's own flat shop_description, gated by quality tier and how
# far into the run the player is (see Shopkeeper.gd's header note -- the
# actual line content is the user's to write via text/strings.json, this
# only proves the selection/fallback logic itself).

func _init() -> void:
	var shopkeeper_script = load("res://scripts/Shopkeeper.gd")
	var weapons_script = load("res://scripts/Weapons.gd")

	# Every UPGRADABLE_TYPES id (plus club) has a slot -- nothing throws for
	# any real weapon id, and an unknown id just falls back cleanly.
	var all_known := true
	if not shopkeeper_script.ITEM_LINES.has("club"):
		all_known = false
	for base in weapons_script.UPGRADABLE_TYPES:
		if not shopkeeper_script.ITEM_LINES.has(base.id):
			all_known = false
	print("every weapon type (plus club) has an ITEM_LINES slot: %s (expected true)" % all_known)

	# Empty by default (content is the user's to write) -- falls back to the
	# item's own shop_description untouched. hand_picks rather than spear,
	# since spear now carries a real worked example (see Shopkeeper.gd).
	print("with nothing written yet, falls back to the item's shop_description: %s (expected true)" % [
		shopkeeper_script.get_item_line("hand_picks", 2, 0, "a plain pick, nothing fancy") == "a plain pick, nothing fancy"
	])
	print("an unknown weapon_id also just falls back: %s (expected true)" % [
		shopkeeper_script.get_item_line("not_a_real_weapon", 0, 0, "fallback text") == "fallback text"
	])

	# Wire in temporary test content directly (not the user's real lines) to
	# prove the tier/world priority ordering itself, independent of whatever
	# the user has or hasn't written yet.
	shopkeeper_script.ITEM_LINES["spear"] = {
		"base": ["base line A", "base line B"],
		"high_quality": ["fancy spear line"],
		"familiar": ["old friend, this spear again"],
	}

	var saw_base := false
	for i in 20:
		if shopkeeper_script.get_item_line("spear", 0, 0, "fallback") in ["base line A", "base line B"]:
			saw_base = true
	print("low tier, early world picks from base: %s (expected true)" % saw_base)

	print("high tier (rank >= HIGH_QUALITY_MIN_RANK) picks the high_quality line: %s (expected true)" % [
		shopkeeper_script.get_item_line("spear", shopkeeper_script.HIGH_QUALITY_MIN_RANK, 0, "fallback") == "fancy spear line"
	])
	print("still base below the high_quality rank threshold: %s (expected true)" % [
		shopkeeper_script.get_item_line("spear", shopkeeper_script.HIGH_QUALITY_MIN_RANK - 1, 0, "fallback") in ["base line A", "base line B"]
	])

	print("late-world (>= FAMILIAR_MIN_WORLD_INDEX) picks the familiar line even for a low tier: %s (expected true)" % [
		shopkeeper_script.get_item_line("spear", 0, shopkeeper_script.FAMILIAR_MIN_WORLD_INDEX, "fallback") == "old friend, this spear again"
	])
	print("familiar wins over high_quality when both apply: %s (expected true)" % [
		shopkeeper_script.get_item_line("spear", shopkeeper_script.HIGH_QUALITY_MIN_RANK, shopkeeper_script.FAMILIAR_MIN_WORLD_INDEX, "fallback") == "old friend, this spear again"
	])

	# A type with lines only partially filled in (e.g. base written, the
	# other two tiers still empty) falls back to base rather than an empty
	# string for the tiers that have nothing yet.
	shopkeeper_script.ITEM_LINES["greatsword"] = {"base": ["a greatsword line"], "high_quality": [], "familiar": []}
	print("high tier with no high_quality lines written yet falls back to base, not empty: %s (expected true)" % [
		shopkeeper_script.get_item_line("greatsword", shopkeeper_script.HIGH_QUALITY_MIN_RANK, 0, "fallback") == "a greatsword line"
	])

	quit()
