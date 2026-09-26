extends SceneTree

# The special-arrow economy (Bow's specials replaced entirely by this, see
# the plan): Player.gd's buy/sell price scaling and 10-cap, then the 3
# arrow effects (Flame/Freeze/Bomb) and the _battle_player_arrow wrapper
# (consumption, refusal cases, Bow-only gating).

func _make_goblin(main, tile: Vector2i, hp: int = 999) -> Dictionary:
	var goblin_script = load("res://scripts/Enemy.gd")
	var g = goblin_script.new()
	main.add_child(g)
	g.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	return {
		"ref": g, "tile": tile, "hp": hp, "max_hp": hp, "move_range": 2,
		"damage": 1, "name": "Goblin", "winding_up": false, "stunned": false,
		"attack_range": 1, "concussed_turns": 0, "frozen_turns": 0,
		"burning": false, "armored": false,
		"disarmed_tile": Vector2i(-1, -1),
	}

func _init() -> void:
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var player = main.player
	var weapons_script = load("res://scripts/Weapons.gd")
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_allies = []
	player.stat_strength = 10
	player.attack_damage = 10
	player.stat_intimidation = 0
	player.current_weapon = weapons_script.BOW
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_target_index = 0

	# =========================================================
	# Player.gd data layer: price scaling with held count, the 10-arrow
	# cap, and a flat sell price.
	# =========================================================
	player.coins = 1000
	player.owned_arrows = {"flame": 0, "freeze": 0, "bomb": 0}

	var base_price: int = weapons_script.ARROW_TYPES.flame.price
	print("Arrow price starts at the base price with none held: %d (expected %d)" % [player.get_arrow_price("flame"), base_price])

	var bought: bool = player.try_buy_arrow("flame")
	print("Buying an arrow succeeds, deducts coins, and increments held count: bought=%s held=%d coins=%d (expected true, 1, %d)" % [
		bought, player.owned_arrows.flame, player.coins, 1000 - base_price
	])

	var expected_next_price: int = int(round(base_price * pow(weapons_script.ARROW_PRICE_GROWTH, 1)))
	print("...and the next purchase costs more, scaled by how many are currently held: %d (expected %d)" % [player.get_arrow_price("flame"), expected_next_price])

	var coins_before_sell: int = player.coins
	var sold: bool = player.try_sell_arrow("flame")
	print("Selling one back returns a flat price and lowers held count: sold=%s held=%d coins=%d (expected true, 0, %d)" % [
		sold, player.owned_arrows.flame, player.coins, coins_before_sell + weapons_script.ARROW_SELL_PRICE
	])
	print("...and the price drops back down with it, since it scales off currently-held count: %d (expected %d)" % [player.get_arrow_price("flame"), base_price])

	var sold_empty: bool = player.try_sell_arrow("flame")
	print("Selling with none held fails outright: %s (expected false)" % [sold_empty])

	player.owned_arrows.freeze = 10
	var coins_before_cap: int = player.coins
	var bought_at_cap: bool = player.try_buy_arrow("freeze")
	print("Buying at the 10-arrow cap fails, spending nothing: bought=%s held=%d coins_unchanged=%s (expected false, 10, true)" % [
		bought_at_cap, player.owned_arrows.freeze, player.coins == coins_before_cap
	])

	player.owned_arrows = {"flame": 0, "freeze": 0, "bomb": 0}

	# =========================================================
	# Battle effects: Flame, Freeze, Bomb. Direct _apply_single_hit /
	# _resolve_bomb_arrow calls (not the full _battle_player_arrow) so the
	# turn cascade _end_player_turn() would otherwise trigger can't consume
	# frozen_turns before these checks observe them -- same reasoning as
	# BONK/Concussed elsewhere in this session's tests. Burn itself has no
	# turn counter to protect anymore (see BURN_DAMAGE_DIVISOR), so there's
	# nothing time-sensitive about the burning flag specifically.
	# =========================================================
	var g_flame := _make_goblin(main, Vector2i(3, 2), 999999)
	main.battle_units = [g_flame]
	main.battle_target_index = 0
	var flame_dmg: int = main.ARROW_FLAME_FLAT_DMG + int(round(10 * main.ARROW_FLAME_DMG_STAT_PCT))
	main._apply_single_hit(0, 1.0, "arrow_flame", player.current_weapon, "You", Vector2i(-1, -1), flame_dmg)
	print("Flame Arrow deals a flat 2 + 50%% of your damage stat, and sets Burn (no turn counter, cleared only by water): dealt=%d (expected %d), burning=%s (expected true)" % [
		999999 - g_flame.hp, flame_dmg, g_flame.burning
	])

	var g_freeze := _make_goblin(main, Vector2i(3, 2), 999999)
	main.battle_units = [g_freeze]
	main.battle_target_index = 0
	main._apply_single_hit(0, 1.0, "arrow_freeze", player.current_weapon, "You", Vector2i(-1, -1), main.ARROW_FREEZE_FLAT_DMG)
	print("Freeze Arrow deals a flat 5 damage and freezes for 2-4 turns: dealt=%d (expected %d), frozen_turns=%d (expected between %d and %d)" % [
		999999 - g_freeze.hp, main.ARROW_FREEZE_FLAT_DMG, g_freeze.frozen_turns, main.ARROW_FREEZE_MIN_TURNS, main.ARROW_FREEZE_MAX_TURNS
	])

	# Bomb Arrow: flat 20 damage to every unit in the 3x3 blast -- the
	# corner enemy (diagonal from center) is the key check that this is a
	# true Chebyshev 3x3 square, not the Manhattan "plus" shape the rest of
	# the codebase's _footprint_dist uses everywhere else.
	player.max_health = 100
	player.health = 100
	main.battle_player_tile = Vector2i(2, 2)
	var g_center := _make_goblin(main, Vector2i(3, 2), 999999)
	var g_corner := _make_goblin(main, Vector2i(4, 3), 999999)
	var g_outside := _make_goblin(main, Vector2i(5, 2), 999999)
	main.battle_units = [g_center, g_corner, g_outside]
	main.battle_allies = [{"tile": Vector2i(3, 3), "hp": 999999, "max_hp": 999999, "dmg_mult": 1.0, "name": "Blade Ally", "move_range": 2, "attack_range": 1}]
	main._resolve_bomb_arrow(Vector2i(3, 2))
	print("Bomb Arrow hits the center and the diagonal corner of the 3x3 blast: center=%s corner=%s (expected true, true, %d damage each)" % [
		999999 - g_center.hp == main.ARROW_BOMB_FLAT_DMG, 999999 - g_corner.hp == main.ARROW_BOMB_FLAT_DMG, main.ARROW_BOMB_FLAT_DMG
	])
	print("...but leaves a unit outside the 3x3 untouched: %s (expected true, still 999999)" % [g_outside.hp == 999999])
	print("...and also hits an ally standing in the blast: %s (expected true, %d damage)" % [
		main.battle_allies[0].hp == 999999 - main.ARROW_BOMB_FLAT_DMG, main.ARROW_BOMB_FLAT_DMG
	])
	print("...and the player themself, if standing in the blast: %d (expected %d)" % [player.health, 100 - main.ARROW_BOMB_FLAT_DMG])

	# =========================================================
	# _battle_player_arrow wrapper: consumption, refusal cases (no ammo, no
	# target in range), and the Bow-only gate.
	# =========================================================
	main.battle_allies = []
	player.owned_arrows = {"flame": 3, "freeze": 0, "bomb": 0}
	main.battle_player_tile = Vector2i(2, 2)
	var g_wrap := _make_goblin(main, Vector2i(3, 2), 999999)
	main.battle_units = [g_wrap]
	main.battle_target_index = 0
	main._battle_player_arrow("flame")
	print("Firing a held arrow consumes exactly 1: held=%d (expected 2), dealt=%s (expected true)" % [
		player.owned_arrows.flame, 999999 - g_wrap.hp > 0
	])

	player.owned_arrows.freeze = 0
	var g_no_ammo := _make_goblin(main, Vector2i(3, 2), 999999)
	main.battle_units = [g_no_ammo]
	main.battle_target_index = 0
	main._battle_player_arrow("freeze")
	print("Firing with none held does nothing and consumes nothing: dealt=%s held=%d (expected false, 0)" % [
		999999 - g_no_ammo.hp > 0, player.owned_arrows.freeze
	])

	player.owned_arrows.freeze = 5
	main.battle_units = []
	main._battle_player_arrow("freeze")
	print("Firing with no enemy in range does nothing and doesn't consume the arrow: held=%d (expected 5)" % [player.owned_arrows.freeze])

	player.current_weapon = weapons_script.BOW
	print("_player_has_bow is true while the Bow is equipped: %s (expected true)" % [main._player_has_bow()])
	player.current_weapon = weapons_script.CLUB
	print("...and false for anything else: %s (expected false)" % [main._player_has_bow()])

	# Reset the scratch save for whatever test runs next.
	var save_data_script = load("res://scripts/SaveData.gd")
	save_data_script.save_data({"essence": 0, "upgrades": {}, "best_wave": 0})

	quit()
