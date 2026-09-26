extends SceneTree

# The Wishing Well (WishingWell.gd / WishingWellPanel.gd), one of the two
# gambling venues: a wager buys one weighted-random outcome. The odds tilt with
# the wager and with the Gambler's Die talisman; winnings in coins bypass the
# coin-bonus percentage; and nothing here may trigger a level-up (which would
# unpause the game under the open panel).

func _init() -> void:
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var player = main.player
	var well = load("res://scripts/WishingWell.gd")

	# --- Odds ------------------------------------------------------------------------
	print("four wager presets: %s (expected [10, 25, 50, 100])" % [well.WAGERS])
	print("wager tiers: %s (expected [0, 0, 1, 1, 2, 3, 3])" % [[5, 10, 25, 30, 50, 100, 500].map(func(w): return well.wager_tier(w))])
	var w10: Dictionary = well.weights(10)
	var w100: Dictionary = well.weights(100)
	print("a bigger wager tilts toward the good outcomes: blessing %.1f -> %.1f (expected up), curse %.1f -> %.1f (expected down)" % [w10.blessing, w100.blessing, w10.curse, w100.curse])
	print("...and 'nothing' is unaffected: %.1f vs %.1f (expected equal)" % [w10.nothing, w100.nothing])
	var lucky: Dictionary = well.weights(10, 0.05)
	print("Gambler's Die (luck 0.05) tilts it too: blessing %.2f > %.2f, curse %.2f < %.2f (expected true true)" % [lucky.blessing, w10.blessing, lucky.curse, w10.curse])
	print("curses never vanish entirely even with huge luck: %s (expected true)" % [well.weights(100, 5.0).curse > 0.0])

	# Seeded draws: every outcome is reachable, and the distribution follows the weights.
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var counts := {}
	for i in 4000:
		var id: String = well.roll(10, 0.0, rng)
		counts[id] = counts.get(id, 0) + 1
	var all_reachable: bool = well.OUTCOMES.keys().all(func(k): return counts.get(k, 0) > 0)
	print("every outcome shows up in 4000 draws: %s (expected true) %s" % [all_reachable, counts])
	print("'nothing' is the most common (30/96): %d (expected roughly 1250, between 1000 and 1500)" % [counts.nothing])
	var good_low := 0
	var good_high := 0
	for i in 3000:
		if well.OUTCOMES[well.roll(10, 0.0, rng)].good:
			good_low += 1
		if well.OUTCOMES[well.roll(100, 0.0, rng)].good:
			good_high += 1
	print("more good outcomes at the top wager than the bottom over 3000 draws each: %d < %d (expected true)" % [good_low, good_high])

	print("blessing strength grows with the wager: %s (expected [0.1, 0.15, 0.2, 0.25])" % [[10, 25, 50, 100].map(func(w): return snappedf(well.blessing_pct(w), 0.01))])
	print("refund is 2x and jackpot 10x the wager: %d %d (expected 50 500)" % [well.refund_amount(25), well.jackpot_amount(50)])

	# --- The panel -----------------------------------------------------------------------
	var panel = main.town_panels.get("wishing_well")
	print("the Wishing Well panel is registered: %s (expected true)" % [panel != null])
	if panel == null:
		quit()
		return
	player.coins = 500
	main._try_open_panel("wishing_well")
	print("the door opens it: visible=%s (expected true), title=%s (expected THE WISHING WELL)" % [panel.visible, panel.title_label.text])
	print("the wager buttons are all enabled at 500 coins: %s (expected true)" % [panel.wager_buttons.values().all(func(b): return not b.disabled)])
	player.coins = 30
	panel._refresh()
	print("...and the ones you can't afford are disabled: 10=%s 25=%s 50=%s 100=%s (expected false false true true)" % [
		panel.wager_buttons[10].disabled, panel.wager_buttons[25].disabled, panel.wager_buttons[50].disabled, panel.wager_buttons[100].disabled
	])

	# Every throw spends the wager up front.
	player.coins = 100
	panel.set_wager(25)
	var thrown: String = panel.throw("nothing")
	print("a throw spends the wager: outcome=%s (expected nothing), coins=%d (expected 75)" % [thrown, player.coins])
	player.coins = 5
	print("can't throw what you don't have: %s (expected empty), coins=%d (expected 5)" % [panel.throw("nothing"), player.coins])
	player.coins = 500

	# --- Outcomes, one by one --------------------------------------------------------------
	panel.set_wager(50)
	player.meta_bonus_coin_pct = 0.5   # winnings must NOT be inflated by this
	player.coins = 500
	panel.throw("refund")
	print("Refund pays exactly 2x, ignoring the coin bonus: coins=%d (expected 550 = 500 - 50 + 100)" % [player.coins])
	player.coins = 500
	panel.throw("jackpot")
	print("Jackpot pays exactly 10x: coins=%d (expected 950 = 500 - 50 + 500)" % [player.coins])
	player.meta_bonus_coin_pct = 0.0

	player.temp_damage_bonus_pct = 0.0
	main.shrine_effect_waves_remaining = 0
	player.coins = 500
	panel.throw("blessing")
	print("Blessing (50 coins): +20%% damage for 3 waves: bonus=%.2f (expected 0.20), waves=%d (expected 3)" % [player.temp_damage_bonus_pct, main.shrine_effect_waves_remaining])
	player.coins = 500
	panel.throw("curse")
	print("Curse: -10%% damage for 3 waves: bonus=%.2f (expected -0.10), waves=%d (expected 3)" % [player.temp_damage_bonus_pct, main.shrine_effect_waves_remaining])
	for i in 3:
		main._advance_wave_tier()
	print("...and both wear off after 3 wave milestones: bonus=%.2f (expected 0.00), waves=%d (expected 0)" % [player.temp_damage_bonus_pct, main.shrine_effect_waves_remaining])

	player.health = 1
	player.stamina = 0
	player.coins = 500
	panel.throw("healing")
	print("Healing Waters restores everything: health=%d/%d stamina=%d/%d (expected full)" % [player.health, player.max_health, player.stamina, player.max_stamina])

	player.potion_queue.clear()
	player.healing_items = 0
	player.coins = 500
	panel.throw("potion")
	print("A Gift adds a potion: %d held (expected 1)" % [player.potion_queue.size()])

	var strength_before: int = player.stat_strength
	var vigor_before: int = player.stat_vigor
	var agility_before: int = player.stat_agility
	player.coins = 500
	panel.throw("stat")
	print("A Surge raises one of strength/vigor/agility: %s (expected true)" % [
		player.stat_strength > strength_before or player.stat_vigor > vigor_before or player.stat_agility > agility_before
	])
	print("...without triggering a level-up (which would unpause the game): choosing_stat=%s (expected false), level=%d (expected 1)" % [main.choosing_stat, player.level])

	player.owned_talismans.clear()
	player.equipped_talismans.clear()
	player._on_talismans_changed()
	player.level = 1
	player.coins = 500
	panel.throw("wish")
	print("A Wish grants a talisman and wears it in the free slot: owned=%d (expected 1), worn=%d (expected 1)" % [player.owned_talismans.size(), player.equipped_talismans.size()])
	player.coins = 500
	panel.throw("wish")
	print("...a second wish with no free slot is owned but unworn: owned=%d (expected 2), worn=%d (expected 1)" % [player.owned_talismans.size(), player.equipped_talismans.size()])
	var everything := {}
	for item in load("res://scripts/Talismans.gd").ITEMS:
		everything[item.id] = true
	player.owned_talismans = everything
	player.coins = 500
	panel.throw("wish")
	print("owning every talisman turns a wish into coins: coins=%d (expected 500 - 50 + 250 = 700)" % [player.coins])
	player.owned_talismans.clear()

	player.coins = 500
	panel.throw("purse")
	print("The Well Takes More: an extra wager's worth: coins=%d (expected 400)" % [player.coins])
	player.coins = 30
	panel.set_wager(10)
	panel.throw("purse")
	print("...never takes more than a wager's worth: coins=%d (expected 10 = 30 - 10 - 10)" % [player.coins])
	player.coins = 10
	panel.throw("purse")
	print("...and never goes negative when the well takes everything: coins=%d (expected 0)" % [player.coins])

	# A real random throw always resolves to something and always charges.
	player.coins = 1000
	var real_outcomes := {}
	panel.set_wager(10)
	for i in 60:
		var before: int = player.coins
		var id: String = panel.throw()
		real_outcomes[id] = true
		if id == "" or player.coins > before + 200:
			print("  odd throw: %s coins %d -> %d" % [id, before, player.coins])
		player.coins = maxi(player.coins, 200)
	print("60 real throws all resolved (%d distinct outcomes seen): %s (expected true)" % [real_outcomes.size(), not real_outcomes.has("")])
	panel.close()

	quit()
