extends SceneTree

# Every node touched by the "make the tree EXPANSIVE" redesign: the 4
# level-up-bonus stats (Might/Swiftness/Vitality/Presence), the 4 repurposed
# nodes (Adrenaline/Beastmaster/Investor/Resilience -- Adrenaline's own
# damage-boost half is covered in test_skill_tree.gd, not repeated here),
# and all 13 brand-new nodes.

func _make_goblin(main, tile: Vector2i, hp: int = 999) -> Dictionary:
	var goblin_script = load("res://scripts/Enemy.gd")
	var g = goblin_script.new()
	main.add_child(g)
	g.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	return {
		"ref": g, "tile": tile, "hp": hp, "max_hp": hp, "move_range": 2,
		"damage": 3, "name": "Goblin", "winding_up": false, "stunned": false,
		"attack_range": 1, "concussed_turns": 0, "frozen_turns": 0,
		"burning": false, "armored": false,
		"disarmed_tile": Vector2i(-1, -1),
	}

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var save_data_script = load("res://scripts/SaveData.gd")
	var weapons_script = load("res://scripts/Weapons.gd")

	# --- _apply_meta_upgrades wires every node's owned level into the right
	# Player field (or, for the plain stat-scaling nodes, the right stat),
	# all via a single save. ---
	save_data_script.save_data({
		"essence": 0,
		"upgrades": {
			"haggling": 3, "herbalism": 2,
			"prodigy": 1, "warlord": 1, "beastmaster": 1, "pack_bond": 2,
			"appraisal": 2, "investor": 1,
			"warband": 1, "battle_medic": 1, "war_chest": 1, "war_profiteer": 2,
			"block_master": 1, "second_breath": 2, "favour": 1, "last_stand": 3,
			"riposte": 2, "momentum": 1, "hardened": 1,
			"fletcher": 2, "field_surgeon": 1, "windfall": 1, "black_market": 1,
		},
		"best_wave": 0,
	})
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player

	print("Haggling: meta_bonus_coin_pct=%.2f (expected 0.30, 3 levels * 0.10)" % [player.meta_bonus_coin_pct])
	print("Herbalism: meta_healing_bonus_pct=%.2f (expected 0.30, 2 levels * 0.15)" % [player.meta_healing_bonus_pct])
	print("Prodigy: meta_bonus_levelup_stat=%s (expected true)" % [player.meta_bonus_levelup_stat])
	print("Warlord: max_party_slots=%d (expected 4 -- applies unconditionally once owned, independent of whether Pack Leader is also in this save)" % [player.max_party_slots])
	print("Warband/Battle Medic/War Chest flags are live: warband=%.2f battle_medic=%s war_chest=%.2f (expected 0.15, true, 0.05)" % [
		player.meta_warband_bonus, player.meta_battle_medic, player.meta_war_chest_reduction
	])

	# --- Beastmaster (repurposed): guarantees a Traitor Wolf from the start
	# of the run, no recruit roll needed -- and its loyalty timer is already
	# ticking. Pack Bond (2 levels) extends how long it lasts. ---
	print("Beastmaster guarantees a starting Traitor Wolf: %s (expected true, non-empty)" % [not player.party_wolf.is_empty()])
	print("...and Pack Bond's bonus waves are stored for it: meta_wolf_bonus_waves=%d (expected 6, 2 levels * 3)" % [player.meta_wolf_bonus_waves])
	print("...the wolf's stay timer is set at run start (WOLF_BASE_STAY_WAVES + Pack Bond): wolf_waves_remaining=%d (expected %d)" % [
		main.wolf_waves_remaining, main.WOLF_BASE_STAY_WAVES + player.meta_wolf_bonus_waves
	])

	# --- Appraisal is a plain stacking stat node (extra starting coins). ---
	print("Appraisal stacks with Nest Egg's starting coins: coins=%d (expected >= %d from Appraisal alone, 2 * 20)" % [
		player.coins, 2 * 20
	])

	# --- Investor (repurposed): extra weapon slots in every shop offering,
	# not a stat bonus anymore. ---
	print("Investor stores its shop-slot bonus: meta_investor_bonus_slots=%d (expected 3)" % [player.meta_investor_bonus_slots])
	main._open_shop()
	# The shop is a flat lootpool now (see Main.gd:_roll_shop_offering) --
	# Investor's bonus slots roll from the same shared pool as everything
	# else, not guaranteed weapons specifically, so this checks the total
	# offering size rather than assuming every bonus slot is a weapon.
	print("Investor rolls 3 more slots into the shop: %d total offers (expected %d, Club + %d rolled)" % [
		main.current_shop_offering.size(), 1 + main.SHOP_TOTAL_SLOTS + 3, main.SHOP_TOTAL_SLOTS + 3
	])
	main.shop_open = false
	main.get_tree().paused = false

	# --- Black Market: a straight discount on the escalating reroll cost. ---
	var undiscounted_cost: int = main.REROLL_BASE_COST + main.REROLL_COST_INCREMENT * main.shop_reroll_count
	var expected_reroll_cost: int = int(round(undiscounted_cost * (1.0 - player.meta_reroll_discount_pct)))
	print("Black Market discounts the reroll cost by 20%%: %d (expected %d, undiscounted %d)" % [
		main._get_shop_reroll_cost(), expected_reroll_cost, undiscounted_cost
	])

	# --- Fletcher: cheaper arrows with a higher held-count cap. ---
	player.current_weapon = weapons_script.BOW
	player.owned_arrows = {"flame": 0, "freeze": 0, "bomb": 0}
	player.stat_intimidation = 0
	var base_flame_price: int = weapons_script.ARROW_TYPES.flame.price
	var expected_flame_price: int = int(round(base_flame_price * (1.0 - player.meta_arrow_discount_pct)))
	print("Fletcher discounts arrow prices by 30%% (2 levels * 15%%): %d (expected %d, base %d)" % [
		player.get_arrow_price("flame"), expected_flame_price, base_flame_price
	])
	print("...and raises the held-arrow cap by 10 (2 levels * 5): meta_arrow_cap_bonus=%d (expected 10)" % [player.meta_arrow_cap_bonus])
	player.coins = 100000
	var raised_cap: int = weapons_script.ARROW_MAX_HELD + player.meta_arrow_cap_bonus
	for i in raised_cap:
		player.try_buy_arrow("flame")
	print("Fletcher's raised cap can actually be filled past the normal 10: held=%d (expected %d)" % [player.owned_arrows.flame, raised_cap])
	var bought_past_cap: bool = player.try_buy_arrow("flame")
	print("...and still refuses a purchase past the raised cap: bought=%s held_unchanged=%s (expected false, true)" % [
		bought_past_cap, player.owned_arrows.flame == raised_cap
	])

	# --- Field Surgeon: cheaper shop potions. ---
	var potions_script = load("res://scripts/Potions.gd")
	var potion_tier: Dictionary = potions_script.TIERS[0]
	player.stat_intimidation = 0
	var expected_potion_price: int = int(round(potion_tier.price * (1.0 - player.meta_field_surgeon_discount_pct)))
	print("Field Surgeon discounts shop potions by 15%%: %d (expected %d, base %d)" % [
		player.get_potion_price(potion_tier), expected_potion_price, potion_tier.price
	])

	# --- Prodigy doubles the level-up stat choice (still works the same
	# way, just now stacking with the level-up-bonus stats below). ---
	player.meta_bonus_levelup_stat = true
	player.stat_strength = 5
	player.apply_bonus_stat("strength")
	print("Prodigy doubles the level-up stat gain: stat_strength=%d (expected 7, +2 instead of +1, no Might owned in this save)" % [player.stat_strength])
	player.meta_bonus_levelup_stat = false

	# --- Might/Swiftness/Vitality/Presence: no longer a starting bonus --
	# apply_bonus_stat reads meta_levelup_bonus_* directly. Set by hand here
	# (rather than round-tripping through another save) since the field is
	# what apply_bonus_stat actually reads. ---
	player.meta_levelup_bonus_strength = 2
	player.stat_strength = 5
	player.apply_bonus_stat("strength")
	print("Might adds its bonus to a level-up's Strength gain: stat_strength=%d (expected 8, 5 + 1 base + 2 from Might)" % [player.stat_strength])
	player.meta_levelup_bonus_strength = 0

	player.meta_levelup_bonus_agility = 20
	var agility_before: int = player.stat_agility
	player.apply_bonus_stat("agility")
	print("Swiftness adds its bonus to a level-up's Agility gain: gained=%d (expected %d, AGILITY_BONUS_PER_LEVEL + 20)" % [
		player.stat_agility - agility_before, player.AGILITY_BONUS_PER_LEVEL + 20
	])
	player.meta_levelup_bonus_agility = 0

	player.meta_levelup_bonus_vigor = 3
	player.stat_vigor = 10
	player.apply_bonus_stat("vigor")
	print("Vitality adds its bonus to a level-up's Vigor gain: stat_vigor=%d (expected 14, 10 + 1 base + 3 from Vitality)" % [player.stat_vigor])
	player.meta_levelup_bonus_vigor = 0

	player.meta_levelup_bonus_intimidation = 4
	player.stat_intimidation = 0
	player.apply_bonus_stat("intimidation")
	print("Presence adds its bonus to a level-up's Intimidation gain: stat_intimidation=%d (expected 5, 1 base + 4 from Presence)" % [player.stat_intimidation])
	player.meta_levelup_bonus_intimidation = 0

	# =========================================================
	# Battle mechanics: Block Master, Last Stand, Riposte, Momentum,
	# Favour, Second Breath, Vigilant Defense (repurposed).
	# =========================================================
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_allies = []
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_target_index = 0
	player.equipped_armor = {"damage_reduction": 0.0}
	player.resilience_reduction = 0.0
	player.meta_war_chest_reduction = 0.0
	player.max_health = 100
	player.health = 100

	# --- Block Master: a 100% chance fully negates a Defended hit. ---
	main.battle_player_defending = true
	player.meta_block_negate_chance = 1.0
	print("Block Master can fully negate a Defended hit: dmg=%d (expected 0)" % [main._apply_incoming_reductions(100, {})])
	player.meta_block_negate_chance = 0.0
	print("...and does nothing at 0%% chance, Defend's normal reduction still applies (100 is well above the full-negate threshold, so it's only halved): dmg=%d (expected 50)" % [
		main._apply_incoming_reductions(100, {})
	])

	# --- Defend's own threshold: a glancing blow below it is fully negated
	# outright, no Block Master needed, and a better shield raises how big a
	# hit still counts as "glancing." ---
	player.equipped_shield = {}
	print("A hit below Defend's base threshold (10) is fully negated on its own: dmg=%d (expected 0)" % [main._apply_incoming_reductions(5, {})])
	print("...one at or above it still only gets halved: dmg=%d (expected 6, half of 12)" % [main._apply_incoming_reductions(12, {})])
	player.owned_shields = {}
	player.try_buy_shield(load("res://scripts/Shields.gd").SHIELDS.shield_bulwark)
	player.current_weapon = load("res://scripts/Weapons.gd").CLUB
	print("...but the same 12-damage hit is fully negated with Iron Bulwark's +8 threshold bonus (10+8=18): dmg=%d (expected 0)" % [main._apply_incoming_reductions(12, {})])
	player.equipped_shield = {}

	main.battle_player_defending = false

	# --- Last Stand: reduction scales with how much HP is missing. ---
	player.meta_last_stand_pct_per_10 = 0.05
	player.health = 100
	print("Last Stand does nothing at full HP: dmg=%d (expected 100)" % [main._apply_incoming_reductions(100, {})])
	player.health = 45  # 55% missing -> 5 steps of 10% -> 5 * 5% = 25%
	print("Last Stand scales with missing HP: dmg=%d (expected 75, 25%% reduction at 55%% missing)" % [main._apply_incoming_reductions(100, {})])
	player.meta_last_stand_pct_per_10 = 0.0
	player.health = 100

	# --- Riposte: a guaranteed dodge with a guaranteed riposte counters the
	# attacker for RIPOSTE_DAMAGE_PCT of a normal hit. ---
	player.meta_dodge_chance = 1.0
	player.meta_riposte_chance = 1.0
	player.stat_strength = 10
	player.attack_damage = 10
	player.current_weapon = weapons_script.CLUB
	var g_riposte := _make_goblin(main, Vector2i(2, 3), 999)
	main.battle_units = [g_riposte]
	var riposte_result: Dictionary = main._enemy_apply_damage(g_riposte, main.battle_player_tile, 50, {})
	var expected_riposte_dmg: int = int(round(10 * weapons_script.CLUB.damage_mult * main.RIPOSTE_DAMAGE_PCT))
	print("Riposte counters a guaranteed dodge: player_dodged=%s (expected true), goblin_dealt=%d (expected %d)" % [
		riposte_result.dodged, 999 - g_riposte.hp, expected_riposte_dmg
	])
	player.meta_dodge_chance = 0.0
	player.meta_riposte_chance = 0.0

	# --- Momentum: stacks per kill THIS battle, boosting the player's own
	# damage on top. ---
	player.meta_momentum_pct_per_kill = 0.1
	main.battle_momentum_stacks = 0
	var g_before_momentum := _make_goblin(main, Vector2i(3, 2), 999999)
	main.battle_units = [g_before_momentum]
	main._apply_single_hit(0, 1.0, "", weapons_script.CLUB)
	var base_hit: int = 999999 - g_before_momentum.hp
	main.battle_momentum_stacks = 3
	var g_after_momentum := _make_goblin(main, Vector2i(3, 2), 999999)
	main.battle_units = [g_after_momentum]
	main._apply_single_hit(0, 1.0, "", weapons_script.CLUB)
	var boosted_hit: int = 999999 - g_after_momentum.hp
	print("Momentum boosts damage per stack: base=%d boosted=%d (expected boosted == round(base * 1.3), 3 stacks * 10%%)" % [
		base_hit, boosted_hit
	])
	print("...matches exactly: %s" % [boosted_hit == int(round(base_hit * 1.3))])
	player.meta_momentum_pct_per_kill = 0.0
	main.battle_momentum_stacks = 0

	# --- Favour (renamed from Second Chance): a %-chance (pinned to 100%
	# here so the outcome is deterministic) to survive a killing blow at 1 HP
	# once per battle, then dies normally on the next one. main._on_player_died
	# is already connected to player.died (wired in Main.gd:_spawn_player when
	# this same Main.tscn instance was built above), so main.game_over is a
	# reliable, non-closure way to observe whether the second hit actually
	# killed the player. ---
	player.meta_favour_chance = 1.0
	player.second_chance_used_this_battle = false
	player.max_health = 50
	player.health = 50
	player.take_battle_damage(999)
	print("Favour saves you from a killing blow once: health=%d (expected 1), game_over=%s (expected false)" % [player.health, main.game_over])
	player.take_battle_damage(999)
	print("...but not a second time in the same battle: health=%d (expected 0), game_over=%s (expected true)" % [player.health, main.game_over])
	player.meta_favour_chance = 0.0
	# _on_player_died's cascade (game_over/in_battle/permadeath slot wipe) is
	# a real side effect of the second hit above -- reset before the
	# sections below, which assume a live, ongoing battle again.
	main.game_over = false
	main.in_battle = true

	# --- Second Breath: passive Stamina regen at the start of every player
	# turn, wired into the enemy-turn-cycle's tail -- that tail is only
	# reached with at least one living unit in battle_units (an empty
	# battle_units short-circuits into an instant victory instead), so a
	# harmless, far-off, zero-damage goblin stands in for "a fight in
	# progress" without actually landing a hit this turn.
	player.meta_stamina_regen_per_turn = 12
	player.max_stamina = 100
	player.stamina = 0
	var g_second_breath := _make_goblin(main, Vector2i(5, 5), 999)
	g_second_breath.damage = 0
	main.battle_units = [g_second_breath]
	main.in_battle = true
	main._process_enemy_turn()
	print("Second Breath regens Stamina at the start of the player's turn: stamina=%d (expected 12)" % [player.stamina])
	player.meta_stamina_regen_per_turn = 0

	# --- Vigilant Defense (repurposed, was named Resilience): heals a flat
	# amount every time you Defend, instead of boosting max Stamina. ---
	player.meta_block_heal_amount = 7
	player.max_health = 50
	player.health = 10
	main.in_battle = false  # halts the cascade before it can further alter health via a counter-attack
	main._battle_player_defend()
	main.in_battle = true
	print("Vigilant Defense heals a flat amount on Defend: health=%d (expected 17, 10 + 7)" % [player.health])
	player.meta_block_heal_amount = 0

	# --- Windfall: a chance for a defeated enemy to drop bonus gold. ---
	# Haggling (3 levels, +30%) and War Profiteer (2 levels, +2/kill) are
	# both still active from earlier in this save and legitimately stack
	# onto/alongside Windfall's gold too -- add_coins() boosts every coin
	# gain "from every source" per its own description, and War Profiteer
	# fires unconditionally on any kill, not just the ones this file happens
	# to test in isolation. Both zeroed here so this check isolates
	# Windfall's own range instead of also re-deriving their contributions.
	player.meta_bonus_coin_pct = 0.0
	player.meta_war_profiteer_coins = 0
	player.meta_windfall_chance = 1.0
	player.coins = 0
	main._on_enemy_died(0)
	print("Windfall grants bonus gold on a kill at 100%% chance: coins=%d (expected between 5 and 15)" % [player.coins])
	print("...within the promised range: %s" % [player.coins >= 5 and player.coins <= 15])
	player.meta_windfall_chance = 0.0

	# --- War Profiteer: flat coins per kill, on top of Windfall. ---
	player.meta_war_profiteer_coins = 2
	var coins_before_profiteer: int = player.coins
	main._on_enemy_died(0)
	print("War Profiteer grants flat coins per kill: coins=%d (expected %d, +2)" % [player.coins, coins_before_profiteer + 2])
	player.meta_war_profiteer_coins = 0

	# --- Hardened: permanent max-HP growth per wave cleared this run. ---
	player.meta_hardened_hp_per_wave = 4
	player._recalc_stats()
	var hardened_base_hp: int = player.max_health
	player.health = player.max_health
	main.shrine_effect_waves_remaining = 0
	main.wolf_waves_remaining = 0
	player.party_wolf = {}
	main.wave = 1
	main._advance_wave_tier()
	print("Hardened permanently grows max HP each wave cleared: max_health=%d health=%d (expected %d, %d)" % [player.max_health, player.health, hardened_base_hp + 4, hardened_base_hp + 4])
	player._recalc_stats()
	print("...and survives a stat recalculation (a level-up, a Church purchase): max_health=%d (expected %d)" % [player.max_health, hardened_base_hp + 4])
	player.hardened_hp_bonus = 0
	player.meta_hardened_hp_per_wave = 0
	player._recalc_stats()

	# --- Wolf expiry: a recruited wolf's loyalty runs out after
	# WOLF_BASE_STAY_WAVES (+ Pack Bond) waves cleared, then leaves. ---
	player.party_wolf = {"name": "Traitor Wolf", "dmg_mult": 0.6}
	main.wolf_waves_remaining = 1
	main._advance_wave_tier()
	print("A Traitor Wolf's loyalty runs out and it leaves the pack: party_wolf_empty=%s (expected true)" % [player.party_wolf.is_empty()])

	# Reset the scratch save for whatever test runs next.
	save_data_script.save_data({"essence": 0, "upgrades": {}, "best_wave": 0})

	quit()
