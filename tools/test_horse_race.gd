extends SceneTree

# The Horse Racing Grounds (HorseRace.gd / HorseRacePanel.gd), the second
# gambling venue: five horses with hidden stats, odds derived from simulating
# the same race hundreds of times (minus a house edge), an animated playback,
# and a panel that locks itself while a race runs. The wager is spent up front
# and a win pays wager x odds, unaffected by the coin bonus.

func _init() -> void:
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var player = main.player
	var race = load("res://scripts/HorseRace.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 987654

	# --- The field ---------------------------------------------------------------------
	var field: Array = race.make_field(rng)
	var names := {}
	var stats_ok := true
	for h in field:
		names[h.name] = true
		if h.speed < 0.9 or h.speed > 1.1 or h.stamina < 0.55 or h.stamina > 0.95 or h.burst < 0.0 or h.burst > 0.22:
			stats_ok = false
	print("five horses with five different names and in-range stats: %d, %d distinct, stats_ok=%s (expected 5 5 true)" % [field.size(), names.size(), stats_ok])

	# --- One simulated race -----------------------------------------------------------------
	var result: Dictionary = race.simulate(field, rng)
	var order: Array = result.order
	var sorted_order: Array = order.duplicate()
	sorted_order.sort()
	print("the finishing order is a permutation of the horses: %s (expected [0, 1, 2, 3, 4])" % [sorted_order])
	var winner_tick: int = result.winner_tick
	print("the winner crosses the line within the tick budget: tick=%d (expected between 150 and %d)" % [winner_tick, race.MAX_TICKS])
	var monotonic := true
	var same_length := true
	var length: int = result.positions[0].size()
	for i in field.size():
		var trail: PackedFloat32Array = result.positions[i]
		if trail.size() != length:
			same_length = false
		for t in range(1, trail.size()):
			if trail[t] < trail[t - 1] - 0.00001:
				monotonic = false
	print("nobody ever runs backwards, and every trail is the same length: %s / %s (expected true / true)" % [monotonic, same_length])
	var ended_at_line := true
	for i in field.size():
		if result.finish_ticks[i] >= 0 and result.positions[i][result.positions[i].size() - 1] != 1.0:
			ended_at_line = false
	print("finished horses end exactly on the line: %s (expected true)" % [ended_at_line])
	var first_finish: int = result.finish_ticks[order[0]]
	var last_finish: int = result.finish_ticks[order[4]]
	print("first place finished no later than last: %s (expected true)" % [first_finish <= last_finish])

	# --- Odds ---------------------------------------------------------------------------------
	var probs: Array = race.estimate_win_probs(field, 300, rng)
	var total_p := 0.0
	for p in probs:
		total_p += p
	print("win probabilities sum to 1: %.3f (expected 1.000)" % [total_p])
	var odds: Array = race.odds_from_probs(probs)
	var in_range: bool = odds.all(func(o): return o >= race.MIN_ODDS and o <= race.MAX_ODDS)
	var implied := 0.0
	for o in odds:
		implied += 1.0 / o
	print("every horse is priced within the limits: %s (expected true)" % [in_range])
	print("implied probabilities (1/odds) total more than 1 -- the house edge: %.2f (expected between 1.05 and 1.5)" % [implied])
	print("a favourite pays less than an outsider: %s (expected true)" % [odds[probs.find(probs.max())] <= odds[probs.find(probs.min())]])
	print("a horse that never wins is capped at %.0fx: %.1f (expected 30.0)" % [race.MAX_ODDS, race.odds_from_probs([0.0])[0]])
	print("odds snap to 0.1: %s (expected true)" % [odds.all(func(o): return absf(o * 10.0 - round(o * 10.0)) < 0.0001)])

	# Return-to-player over a long run stays near 90% -- the odds are honest.
	var rtp_field: Array = race.make_field(rng)
	var rtp_odds: Array = race.odds_from_probs(race.estimate_win_probs(rtp_field, 400, rng))
	var win_counts := [0, 0, 0, 0, 0]
	var sims := 600
	for i in sims:
		var r: Dictionary = race.simulate(rtp_field, rng, false)
		win_counts[r.order[0]] += 1
	# A 1-coin bet on horse i returns odds[i] whenever it wins; averaged over
	# all five horses that's each horse's expected return, ~1 - HOUSE_EDGE.
	var rtp := 0.0
	for i in 5:
		rtp += float(win_counts[i]) / float(sims) * rtp_odds[i]
	rtp /= 5.0
	print("betting on every horse in turn returns roughly the house-edge fraction: %.2f (expected between 0.75 and 1.10, ~0.90)" % [rtp])

	print("payout maths: 10 at x3.5 = %d (expected 35); with Gambler's Die (+5%%) = %d (expected 37)" % [race.payout(10, 3.5), race.payout(10, 3.5, 0.05)])

	# --- The panel ---------------------------------------------------------------------------------
	var panel = main.town_panels.get("horse_racing")
	print("the Racing Grounds panel is registered: %s (expected true)" % [panel != null])
	if panel == null:
		quit()
		return
	panel.rng = rng
	player.coins = 200
	player.meta_bonus_coin_pct = 0.5   # winnings must not be inflated by this
	main._try_open_panel("horse_racing")
	print("the door opens it: visible=%s (expected true), title=%s (expected THE RACING GROUNDS)" % [panel.visible, panel.title_label.text])
	print("odds start posting rather than freezing the panel open: pending=%s (expected true), bettable_yet=%s (expected false)" % [panel._odds_pending, panel.can_place_bet()])
	# Tests want the odds settled immediately rather than stepping frame by
	# frame; the real panel posts them over a few frames instead (_step_odds).
	panel.finish_odds_now()
	print("five horse cards with odds once posted: %d (expected 5), first says: %s" % [panel.horse_buttons.size(), panel.horse_buttons[0].text.replace("\n", " ")])
	print("no bet yet: can_place=%s (expected false)" % [panel.can_place_bet()])
	print("starting without a pick does nothing: %s (expected false), coins=%d (expected 200)" % [panel.start_race(), player.coins])
	panel.set_pick(2)
	panel.set_wager(50)
	print("pick + wager makes a bet possible: %s (expected true)" % [panel.can_place_bet()])
	player.coins = 20
	print("...but not one you can't afford: %s (expected false)" % [panel.can_place_bet()])
	player.coins = 200

	# Run a race: the wager is spent, the panel locks, then it resolves.
	var odds_at_bet: Array = panel.odds.duplicate()
	var picked_odds: float = odds_at_bet[2]
	print("start_race: ok=%s (expected true), coins=%d (expected 150), racing=%s (expected true)" % [panel.start_race(), player.coins, panel.racing])
	print("...the panel refuses to be closed mid-race: can_close=%s (expected false), close button disabled=%s (expected true)" % [panel.can_close(), panel.close_button.disabled])
	panel.close()
	print("...close() is ignored: still visible=%s (expected true)" % [panel.visible])
	# Escape doesn't get you out either.
	main._close_open_town_panels()
	print("...and neither does Escape: still visible=%s (expected true)" % [panel.visible])
	panel.set_pick(0)
	panel.set_wager(10)
	print("...picks and wagers are frozen: pick=%d (expected 2), wager=%d (expected 50)" % [panel.pick, panel.wager])
	print("...can't start another race meanwhile: %s (expected false)" % [panel.start_race()])
	panel.advance(2.0)
	print("mid-race the horses have left the gate: %s (expected true)" % [panel.lane_horses[0].position.x > panel._horse_x(0.0)])
	var race_result: Dictionary = panel.race
	# Force a win for the deterministic payout check.
	panel._race_pick = race_result.order[0]
	panel._race_odds = [picked_odds, picked_odds, picked_odds, picked_odds, picked_odds]
	panel.advance(100.0)
	var expected_win: int = race.payout(50, picked_odds, 0.0)
	print("the race finishes: racing=%s (expected false), last winnings=%d (expected %d), coins=%d (expected %d)" % [panel.racing, panel.last_winnings, expected_win, player.coins, 150 + expected_win])
	print("...winnings ignore the coin bonus: %s (expected true)" % [player.coins == 150 + expected_win])
	print("...and the panel unlocks: can_close=%s (expected true), a fresh field is up (pick reset to -1): %d" % [panel.can_close(), panel.pick])
	print("the result text names the podium: %s (expected true)" % [panel.result_label.text.begins_with("1st ")])

	# A lost bet just costs the wager.
	# _finish_race lined up a fresh field for us -- its odds are pending again.
	panel.finish_odds_now()
	panel.set_pick(1)
	panel.set_wager(25)
	player.coins = 100
	panel.start_race()
	panel._race_pick = panel.race.order[4]
	panel.advance(100.0)
	print("a losing bet costs only the wager: coins=%d (expected 75), winnings=%d (expected 0)" % [player.coins, panel.last_winnings])
	panel.close()
	print("closes normally after the race: visible=%s (expected false), paused=%s (expected false)" % [panel.visible, paused])

	# The Gambler's Die adds to a winning payout.
	player.owned_talismans["gamblers_die"] = true
	player.level = 1
	player.equip_talisman("gamblers_die")
	main._try_open_panel("horse_racing")
	panel.finish_odds_now()
	panel.set_pick(3)
	panel.set_wager(10)
	player.coins = 100
	panel.start_race()
	# Force the win by promoting the actual pick's odds to whichever horse won.
	panel._race_pick = panel.race.order[0]
	var odds_die: float = panel._race_odds[panel._race_pick]
	panel.advance(100.0)
	print("Gambler's Die adds 5%% to a win: winnings=%d (expected %d)" % [panel.last_winnings, race.payout(10, odds_die, 0.05)])
	panel.close()

	quit()
