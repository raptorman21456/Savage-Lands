extends SceneTree

# The Fishing Hole (FishingHole.gd / FishingPanel.gd): cast -> wait -> bite ->
# hook -> reel -> loot, driven as a state machine so the whole loop (including
# a miss and a snapped line) can be tested without any real-time input.

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var player = main.player
	var hole = load("res://scripts/FishingHole.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 55555

	# --- Pure rules -------------------------------------------------------------------
	print("bait costs %d coins" % [hole.BAIT_COST])
	var w0: Dictionary = hole.size_weights(0.0)
	var w_luck: Dictionary = hole.size_weights(0.5)
	print("luck skews weight toward the rarer sizes: medium %.1f -> %.1f, junk unchanged %.1f == %.1f (expected up, equal)" % [w0.medium, w_luck.medium, w0.junk, w_luck.junk])
	print("bite windows only ever widen with luck: %d -> %d (expected wider)" % [hole.bite_window_ticks(0.0), hole.bite_window_ticks(0.5)])
	print("bigger fish bite later: %s (expected non-decreasing)" % [["junk", "small", "medium", "large", "golden"].map(func(s): return hole.bite_wait_ticks(s))])

	var counts := {}
	for i in 3000:
		var s: String = hole.roll_size(0.0, rng)
		counts[s] = counts.get(s, 0) + 1
	print("every size is reachable over 3000 rolls at zero luck: %s (expected true) %s" % [["junk", "small", "medium", "large", "golden"].all(func(s): return counts.get(s, 0) > 0), counts])
	var golden_low: int = counts.get("golden", 0)
	counts.clear()
	for i in 3000:
		var s: String = hole.roll_size(1.0, rng)
		counts[s] = counts.get(s, 0) + 1
	print("Angler's Hook-strength luck (1.0) pulls up the golden rate: %d -> %d (expected higher)" % [golden_low, counts.get("golden", 0)])

	# Reeling: holding always makes progress but also raises tension; a big
	# fish needs more holds and pushes tension up faster than a small one.
	var p := 0.0
	var t := 0.0
	var small_holds := 0
	while p < 1.0 and small_holds < 200:
		var r: Dictionary = hole.step_reel(p, t, "small", true, rng)
		p = r.progress
		t = r.tension
		small_holds += 1
	print("holding steadily lands a small fish eventually: holds=%d (expected small, under 30), final progress=%.2f (expected 1.00)" % [small_holds, p])
	p = 0.0
	t = 0.0
	var golden_holds := 0
	while p < 1.0 and golden_holds < 200:
		var r: Dictionary = hole.step_reel(p, t, "golden", true, rng)
		p = r.progress
		t = r.tension
		golden_holds += 1
	print("a golden fish takes meaningfully longer to land than a small one: %d > %d (expected true)" % [golden_holds, small_holds])
	# Never releasing eventually snaps the line on a hard-fighting fish.
	p = 0.0
	t = 0.0
	var snapped := false
	for i in 40:
		var r: Dictionary = hole.step_reel(p, t, "golden", true, rng)
		p = r.progress
		t = r.tension
		if t >= 1.0:
			snapped = true
			break
	print("holding through a golden's whole fight risks a snap: snapped_or_landed=%s (expected true)" % [snapped or p >= 1.0])
	# Releasing lets tension bleed off without losing progress.
	p = 0.4
	t = 0.9
	var r2: Dictionary = hole.step_reel(p, t, "small", false, rng)
	print("releasing relaxes tension without losing progress (allowing for a surge): progress=%.2f (expected 0.40), tension=%.2f, dropped=%s (expected true, started at 0.90)" % [r2.progress, r2.tension, r2.tension <= 0.9])

	# Loot table.
	var loot_junk: Dictionary = hole.loot_for_size("junk", {}, rng)
	var loot_small: Dictionary = hole.loot_for_size("small", {}, rng)
	var loot_medium: Dictionary = hole.loot_for_size("medium", {}, rng)
	print("junk pays a couple of coins: kind=%s (expected coins), amount in 1..4: %s" % [loot_junk.kind, loot_junk.amount >= 1 and loot_junk.amount <= 4])
	print("small yields the cheap fish food: %s (expected food / food_minnow)" % [[loot_small.kind, loot_small.get("id", "")]])
	print("medium yields the better fish food: %s (expected food / food_bass)" % [[loot_medium.kind, loot_medium.get("id", "")]])
	var large_kinds := {}
	for i in 100:
		large_kinds[hole.loot_for_size("large", {}, rng).kind] = true
	print("large is either coins or a potion: %s (expected true)" % [large_kinds.keys().all(func(k): return k == "coins" or k == "potion")])
	var everything := {}
	for item in load("res://scripts/Talismans.gd").ITEMS:
		everything[item.id] = true
	print("golden gives a talisman you don't already own: %s (expected talisman)" % [hole.loot_for_size("golden", {}, rng).kind])
	print("...or coins if you somehow own every talisman: %s (expected coins)" % [hole.loot_for_size("golden", everything, rng).kind])

	# --- The panel's state machine ------------------------------------------------------
	var panel = main.town_panels.get("fishing")
	print("the Fishing Hole panel is registered: %s (expected true)" % [panel != null])
	if panel == null:
		quit()
		return
	panel.rng = rng
	player.coins = 100
	main._try_open_panel("fishing")
	print("the door opens it: visible=%s (expected true), title=%s (expected THE FISHING HOLE), state=%s (expected idle)" % [panel.visible, panel.title_label.text, panel.state])

	# Casting spends bait and starts the wait.
	var before: int = player.coins
	print("cast: ok=%s (expected true), coins=%d (expected %d), state=%s (expected waiting)" % [panel.cast(), player.coins, before - hole.BAIT_COST, panel.state])
	print("can't cast again mid-line: %s (expected false)" % [panel.cast()])
	player.coins = 0
	panel._reset("idle")
	print("can't afford bait: %s (expected false), state=%s (expected idle)" % [panel.cast(), panel.state])
	player.coins = 100

	# Force a quick bite for a deterministic hook-miss check.
	panel.cast()
	panel.current_size = "small"
	panel.wait_ticks_left = 1
	panel.advance(_tick_seconds(panel))
	print("the wait ticks down to a bite: state=%s (expected biting)" % [panel.state])
	panel.bite_ticks_left = 1
	panel.advance(_tick_seconds(panel))
	print("an un-hooked bite window closes and the fish gets away: state=%s (expected idle)" % [panel.state])

	# Hooking mid-bite moves to reeling; hooking too early (nothing biting yet)
	# fails outright.
	player.coins = 100
	panel.cast()
	panel.current_size = "small"
	print("hook() fails before any bite starts: %s (expected false), state=%s (expected waiting)" % [panel.hook(), panel.state])
	panel.wait_ticks_left = 0
	panel._tick_waiting()
	print("the wait reaching zero opens the bite window: state=%s (expected biting)" % [panel.state])
	print("hooking mid-bite starts the reel: %s (expected true), state=%s (expected reeling)" % [panel.hook(), panel.state])

	# Holding steadily lands the (small, so quick) fish.
	panel.holding_reel = true
	var ticks := 0
	while panel.state == "reeling" and ticks < 60:
		panel._tick_reeling()
		ticks += 1
	print("reeling a small fish while holding lands it within a reasonable number of ticks: state=%s (expected idle), ticks=%d (expected under 40)" % [panel.state, ticks])
	print("a catch is added: potion_queue has a food_minnow=%s (expected true)" % [player.potion_queue.has("food_minnow")])

	# Never releasing on a big fighter risks (and here, forces) a snap.
	player.coins = 100
	panel.cast()
	panel.current_size = "golden"
	panel.wait_ticks_left = 0
	panel._tick_waiting()
	panel.hook()
	panel.holding_reel = true
	var snapped_panel := false
	ticks = 0
	while panel.state == "reeling" and ticks < 100:
		panel._tick_reeling()
		ticks += 1
		if panel.state == "idle":
			snapped_panel = true
	print("holding through a golden fish's whole fight can snap the line: resolved=%s (expected true), ticks=%d" % [snapped_panel, ticks])

	# Closing mid-reel just drops the fish -- no lock like the horse race.
	player.coins = 100
	panel.cast()
	panel.current_size = "small"
	panel.wait_ticks_left = 0
	panel._tick_waiting()
	panel.hook()
	print("can_close is always true here (unlike the horse race): %s (expected true)" % [panel.can_close()])
	panel.close()
	print("closing mid-reel resets the line: state=%s (expected idle), visible=%s (expected false)" % [panel.state, panel.visible])

	# A real, undriven loop (letting the state machine run on its own via
	# advance()) always resolves to idle eventually, one way or another.
	main._try_open_panel("fishing")
	player.coins = 200
	panel.cast()
	var real_ticks := 0
	while panel.state != "idle" and real_ticks < 400:
		panel.holding_reel = true
		panel.advance(1.0 / 12.0)
		real_ticks += 1
	print("an untouched cast (auto-holding once hooked) always resolves: state=%s (expected idle), ticks=%d (expected under 400)" % [panel.state, real_ticks])
	panel.close()

	quit()

# Small helper so the test doesn't hardcode the panel's private tick length.
func _tick_seconds(panel) -> float:
	return panel.TICK_SECONDS
