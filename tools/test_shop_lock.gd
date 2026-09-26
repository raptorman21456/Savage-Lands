extends SceneTree

# Shop locking: pay a flat cost to protect a rolled (non-Club) weapon offer
# from being rerolled away. Covers the refusal cases (can't afford, already
# locked, not a lockable row), that a lock actually survives a reroll, and
# that locks are scoped to a single shop visit (not carried into the next).

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var player = main.player
	player.coins = 1000
	main._open_shop()

	# Find a lockable row (any non-Club weapon offer). The shop is a flat
	# random lootpool now (see Main.gd:_roll_shop_offering), so a single
	# roll isn't guaranteed to include a weapon at all -- reroll until one
	# turns up rather than risk an occasional flaky "no lockable row found".
	var lockable_idx := -1
	var attempts := 0
	while lockable_idx < 0 and attempts < 50:
		for i in main.current_shop_offering.size():
			var item: Dictionary = main.current_shop_offering[i]
			if item.category == "weapon" and item.id != "club":
				lockable_idx = i
				break
		if lockable_idx < 0:
			main._roll_shop_offering()
			attempts += 1
	print("the offering has at least one lockable (non-Club) weapon row: %s (expected true)" % [lockable_idx >= 0])

	# --- Can't afford: 0 coins refuses the lock, nothing changes. ---
	player.coins = 0
	main._on_shop_lock_pressed(lockable_idx)
	print("locking without enough coins fails: locked=%s coins=%d (expected false, 0)" % [
		main.current_shop_offering[lockable_idx].get("locked", false), player.coins
	])

	# --- Club (index 0) is never lockable, regardless of coins. ---
	player.coins = 1000
	main._on_shop_lock_pressed(0)
	print("Club can't be locked: locked=%s coins_unchanged=%s (expected false, true)" % [
		main.current_shop_offering[0].get("locked", false), player.coins == 1000
	])

	# --- A successful lock spends the flat cost and flags the row. ---
	var coins_before_lock: int = player.coins
	main._on_shop_lock_pressed(lockable_idx)
	var locked_item_id: String = main.current_shop_offering[lockable_idx].id
	var locked_item_tier: String = main.current_shop_offering[lockable_idx].get("tier_name", "")
	print("locking a weapon row spends %d coins and flags it: locked=%s coins=%d (expected true, %d)" % [
		main.SHOP_LOCK_COST, main.current_shop_offering[lockable_idx].get("locked", false), player.coins, coins_before_lock - main.SHOP_LOCK_COST
	])

	# --- Locking an already-locked row is a no-op (refuses, no double
	# charge). ---
	var coins_before_relock: int = player.coins
	main._on_shop_lock_pressed(lockable_idx)
	print("locking an already-locked row doesn't charge again: coins_unchanged=%s (expected true)" % [player.coins == coins_before_relock])

	# --- Rerolling preserves the locked item (same id + tier), while the
	# rest of the offering is still regenerated around it. ---
	var offering_size_before: int = main.current_shop_offering.size()
	main._reroll_shop()
	var still_present := false
	for item in main.current_shop_offering:
		if item.get("locked", false) and item.id == locked_item_id and item.get("tier_name", "") == locked_item_tier:
			still_present = true
			break
	print("the locked item survives a reroll: %s (expected true)" % [still_present])
	print("the offering size is unchanged by the reroll: %d (expected %d)" % [main.current_shop_offering.size(), offering_size_before])

	# Reroll again for good measure -- the lock isn't a one-shot protection.
	main._reroll_shop()
	still_present = false
	for item in main.current_shop_offering:
		if item.get("locked", false) and item.id == locked_item_id and item.get("tier_name", "") == locked_item_tier:
			still_present = true
			break
	print("the locked item survives a second reroll too: %s (expected true)" % [still_present])

	# --- Armor/potion rows are never lockable -- they're already
	# deterministic every roll, nothing for a lock to protect. ---
	var armor_idx := -1
	for i in main.current_shop_offering.size():
		if main.current_shop_offering[i].category == "armor":
			armor_idx = i
			break
	if armor_idx >= 0:
		var armor_coins_before: int = player.coins
		main._on_shop_lock_pressed(armor_idx)
		print("an armor row can't be locked: locked=%s coins_unchanged=%s (expected false, true)" % [
			main.current_shop_offering[armor_idx].get("locked", false), player.coins == armor_coins_before
		])

	# --- Locks are scoped to a single shop visit -- opening a fresh shop
	# (next wave) starts with nothing locked, even though the item was
	# never bought. ---
	main._open_shop()
	var any_locked := false
	for item in main.current_shop_offering:
		if item.get("locked", false):
			any_locked = true
			break
	print("a fresh shop visit starts with nothing locked: %s (expected false)" % [any_locked])

	quit()
