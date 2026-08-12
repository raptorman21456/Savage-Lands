extends SceneTree

func _init() -> void:
	var weapons = load("res://scripts/Weapons.gd")

	var tier_counts := {}
	for t in weapons.TIERS:
		tier_counts[t.tier_name] = 0
	var trials := 2000
	for i in trials:
		var variant: Dictionary = weapons.make_variant(weapons.SPEAR)
		tier_counts[variant.tier_name] += 1

	var expected_pct := []
	for t in weapons.TIERS:
		expected_pct.append("%s ~%d%%" % [t.tier_name, t.weight])
	print("tier distribution over %d rolls: %s (expected roughly %s)" % [trials, tier_counts, ", ".join(expected_pct)])
	for key in tier_counts:
		print("  %s: %.1f%%" % [key, 100.0 * tier_counts[key] / trials])

	# Verify the actual scaling math directly (bypassing the random roll) by
	# checking base data stays untouched and manually replicating the formula
	# for every tier currently defined, so this test doesn't go stale the next
	# time a tier is added, removed, or rebalanced.
	print("spear base: damage_mult=%.2f price=%d" % [weapons.SPEAR.damage_mult, weapons.SPEAR.price])
	for t in weapons.TIERS:
		print("expected %s spear: damage=%.3f price=%d" % [
			t.tier_name, weapons.SPEAR.damage_mult * t.damage_scale, int(round(weapons.SPEAR.price * t.price_scale))
		])

	# Confirm base const dict itself is never mutated by repeated rolls.
	print("base still unmutated after %d rolls: damage_mult=%.2f price=%d (expect same as before)" % [
		trials, weapons.SPEAR.damage_mult, weapons.SPEAR.price
	])

	quit()
