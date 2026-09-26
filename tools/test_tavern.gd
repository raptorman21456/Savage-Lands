extends SceneTree

# Bounty Hunter's Tavern -- the bounty (Main.gd:bounty_target/bounty_baseline/
# bounty_progress/claim_bounty, always boss-tier so it never overlaps the
# Quest Board's varied everyday tasks) plus the two wager minigames
# (TavernPanel.gd's Coin Flip / Dice Guess tabs).

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

	# --- Bounty: always boss-tier, escalates and rebaselines on claim. ---
	print("bounty starts at target 1: %d (expected 1)" % [main.bounty_target])
	print("not complete with zero bosses defeated: %s (expected false)" % [main.is_bounty_complete()])
	main.run_bosses_defeated = 1
	print("complete once a boss falls: %s (expected true)" % [main.is_bounty_complete()])
	var owned_before: int = player.owned_weapons.size()
	main.claim_bounty()
	print("claiming grants a guaranteed weapon and equips it: owned_grew=%s (expected true), equipped_matches=%s (expected true)" % [
		player.owned_weapons.size() > owned_before, player.owned_weapons.has(player.current_weapon_base.id)
	])
	print("...and escalates + rebaselines for next time: target=%d (expected 2), baseline=%d (expected 1)" % [
		main.bounty_target, main.bounty_baseline
	])
	print("no longer complete until another boss falls: %s (expected false)" % [main.is_bounty_complete()])

	# --- Minigames: TavernPanel wagers directly against the player's coins. ---
	var panel = main.tavern_panel
	panel.open(player)

	player.coins = 100
	panel._on_tab_pressed("Coin Flip")
	panel.coin_flip_wager = 20
	var coins_before_flip: int = player.coins
	panel._on_coin_flip_pressed()
	print("Coin Flip always spends the wager up front, then may pay double: coins_changed=%s (expected true), spent_or_won=%s (expected true)" % [
		player.coins != coins_before_flip, player.coins == coins_before_flip - 20 or player.coins == coins_before_flip + 20
	])

	player.coins = 5
	var coins_before_broke_flip: int = player.coins
	panel.coin_flip_wager = 20
	panel._on_coin_flip_pressed()
	print("Coin Flip can't be played on a wager bigger than the current balance: coins_unchanged=%s (expected true)" % [
		player.coins == coins_before_broke_flip
	])

	player.coins = 100
	panel._on_tab_pressed("Dice Guess")
	panel.dice_wager = 10
	panel.dice_guess = 3
	var coins_before_dice: int = player.coins
	panel._on_dice_guess_pressed()
	var possible_after := [coins_before_dice - 10, coins_before_dice + 10 * panel.DICE_GUESS_PAYOUT_MULT]
	print("Dice Guess spends the wager, paying %dx only on an exact match: result_is_sane=%s (expected true)" % [
		panel.DICE_GUESS_PAYOUT_MULT, player.coins in possible_after
	])

	panel.close()
	quit()
