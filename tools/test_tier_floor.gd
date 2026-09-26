extends SceneTree

func _init() -> void:
	var weapons = load("res://scripts/Weapons.gd")

	# Rolling with min_rank=1 should never produce the bottom tier (Broken).
	var bottom_name: String = weapons.TIERS[0].tier_name
	var top_name: String = weapons.TIERS[-1].tier_name
	var saw_bottom := false
	for i in 500:
		var v: Dictionary = weapons.make_variant(weapons.SPEAR, 1)
		if v.tier_name == bottom_name:
			saw_bottom = true
	print("min_rank=1 over 500 rolls: saw_%s=%s (expect false)" % [bottom_name, saw_bottom])

	# min_rank=top rank should always produce the top tier (Legendary).
	var top_rank: int = weapons.TIERS[-1].rank
	var all_top := true
	for i in 100:
		var v: Dictionary = weapons.make_variant(weapons.HAMMER, top_rank)
		if v.tier_name != top_name:
			all_top = false
	print("min_rank=%d over 100 rolls: all_%s=%s (expect true)" % [top_rank, top_name, all_top])

	# Full integration: own a Masterwork spear, confirm get_owned_tier_rank
	# reports Masterwork's actual rank and Main's roll formula would floor there.
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var player = main.player
	var masterwork_rank: int = 0
	for t in weapons.TIERS:
		if t.tier_name == "Masterwork":
			masterwork_rank = t.rank
	# Non-Mythic ids now carry a material suffix (see test_weapon_materials.gd)
	# -- "steel" is the baseline material, but any material works here since
	# get_owned_tier_rank checks across all of them.
	player.owned_weapons["spear_masterwork_steel"] = true
	var rank: int = player.get_owned_tier_rank("spear")
	print("owned rank for spear after owning masterwork: %d (expected %d)" % [rank, masterwork_rank])

	var rank_none: int = player.get_owned_tier_rank("greatsword")
	print("owned rank for greatsword (never bought): %d (expected -1)" % rank_none)

	# The shop's own roll no longer floors weapon quality at what you already
	# own (see Main.gd:_roll_shop_offering/_roll_random_shop_item) -- it's a
	# flat lootpool now, every tier equally reachable regardless of
	# ownership, with TIERS' own weights (Weapons.gd) the only thing making
	# a high tier rare. get_owned_tier_rank above is still accurate; the
	# shop just no longer consults it as a floor. Confirmed here by actually
	# seeing a worse-than-Masterwork spear turn up over enough rerolls.
	var saw_worse := false
	for i in 200:
		main._roll_shop_offering()
		for w in main.current_shop_offering:
			if w.id.begins_with("spear"):
				var offered_rank: int = 0
				for t in weapons.TIERS:
					if t.tier_name == w.tier_name:
						offered_rank = t.rank
				if offered_rank < masterwork_rank:
					saw_worse = true
	print("after owning masterwork spear, the shop's lootpool can still roll a worse spear (no ownership floor): %s (expected true)" % saw_worse)

	quit()
