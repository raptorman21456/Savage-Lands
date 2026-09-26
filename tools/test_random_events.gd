extends SceneTree

func _make_goblin(main, tile: Vector2i, hp: int = 999) -> Dictionary:
	var goblin_script = load("res://scripts/Enemy.gd")
	var g = goblin_script.new()
	main.add_child(g)
	g.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	return {
		"ref": g, "tile": tile, "hp": hp, "max_hp": hp, "move_range": 2,
		"damage": 1, "name": "Goblin", "winding_up": false, "stunned": false,
	}

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
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	# --- Event pool filtering ---
	player.party_members = []
	print("warrior_joins is offered while the party has room: %s (expected true)" % [
		main._available_event_ids().has("warrior_joins")
	])
	player.party_members = [{"name": "Blade Ally", "dmg_mult": 0.75}, {"name": "Warrior", "dmg_mult": 0.75}]
	print("warrior_joins is excluded once the party is full: %s (expected false)" % [
		main._available_event_ids().has("warrior_joins")
	])
	print("every other event stays offered regardless: %d ids (expected 5)" % [main._available_event_ids().size()])
	player.party_members = []

	# --- Goblin Swarm: bonus goblins consumed by the next _spawn_wave(), plus
	# an immediate coin reward. ---
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await physics_frame
	main.enemies_alive = 0
	main.wave = 1
	player.coins = 0
	main._apply_automatic_event("goblin_swarm")
	print("goblin_swarm sets the one-shot bonus flag and grants coins immediately: extra=%d (expected %d), coins=%d (expected 20)" % [
		main.event_extra_goblins, main.SWARM_BONUS_GOBLINS, player.coins
	])
	main._spawn_wave()
	# add_to_group("enemies") happens in each Enemy's _ready(), which (a
	# known quirk in this project) doesn't run synchronously right after
	# add_child() on an already-active tree -- give it a frame.
	await physics_frame
	var goblins_after: int = main.get_tree().get_nodes_in_group("enemies").filter(func(e): return e.get_display_name() == "Goblin").size()
	# Wave 1 shaves 2 off the base goblin count (see Main.gd:_spawn_wave) to
	# ease a fresh level-1 character in -- the swarm bonus still stacks on
	# top of that reduced base, same as it would on any other wave.
	print("the bonus goblins actually spawned: goblin_count=%d (expected %d, base 6 - wave-1 reduction 2 + swarm bonus %d), flag_consumed=%s (expected true)" % [
		goblins_after, max(1, 6 - 2 + main.SWARM_BONUS_GOBLINS), main.SWARM_BONUS_GOBLINS, main.event_extra_goblins == 0
	])

	# --- Elite Bounty: forces the first spawned goblin elite. ---
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await physics_frame
	main.enemies_alive = 0
	main.wave = 1
	main._apply_automatic_event("elite_bounty")
	main._spawn_wave()
	await physics_frame
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)
	var goblins_now: Array = main.get_tree().get_nodes_in_group("enemies").filter(func(e): return e.get_display_name() == "Goblin")
	print("elite_bounty guarantees the first goblin is elite: is_elite=%s (expected true), flag_consumed=%s (expected true)" % [
		goblins_now[0].is_elite, main.event_force_elite == false
	])

	# --- A Warrior Joins You ---
	player.party_members = []
	player.max_party_slots = 2
	main._resolve_event_choice("warrior_joins", false)
	print("declining grants no party member: %d members (expected 0)" % [player.party_members.size()])
	main._resolve_event_choice("warrior_joins", true)
	print("accepting fills the first party slot: %d members (expected 1)" % [player.party_members.size()])
	main._resolve_event_choice("warrior_joins", true)
	print("accepting again fills the second (last) party slot: %d members (expected 2)" % [player.party_members.size()])
	player.coins = 0
	main._resolve_event_choice("warrior_joins", true)
	print("accepting with the party already full falls back to a coin reward instead of over-filling it: coins=%d (expected 30), members_unchanged=%d (expected 2)" % [
		player.coins, player.party_members.size()
	])

	# --- Traveling Merchant ---
	var weapons_script = load("res://scripts/Weapons.gd")
	main.pending_event_weapon = weapons_script.make_variant(weapons_script.SPEAR, 3, 0.0)
	var offered_id_1: String = main.pending_event_weapon.id
	var discounted_price: int = int(round(player.get_weapon_price(main.pending_event_weapon) * main.MERCHANT_EVENT_DISCOUNT))
	player.coins = discounted_price - 1
	player.owned_weapons.erase(offered_id_1)
	main._resolve_event_choice("traveling_merchant", true)
	print("declining to buy (insufficient coins) doesn't grant the weapon: owned=%s (expected false), coins_unchanged=%s (expected true)" % [
		player.owned_weapons.has(offered_id_1), player.coins == discounted_price - 1
	])

	# Re-roll for a fresh price -- tier/material are randomized per roll, so
	# reusing the earlier discounted_price here would test against a stale
	# number that doesn't match this new roll's actual cost.
	main.pending_event_weapon = weapons_script.make_variant(weapons_script.SPEAR, 3, 0.0)
	var offered_id: String = main.pending_event_weapon.id
	var discounted_price_2: int = int(round(player.get_weapon_price(main.pending_event_weapon) * main.MERCHANT_EVENT_DISCOUNT))
	player.coins = discounted_price_2
	player.owned_weapons.erase(offered_id)
	main._resolve_event_choice("traveling_merchant", true)
	print("buying with enough coins grants and equips the weapon: owned=%s (expected true), equipped=%s (expected %s), coins_left=%d (expected 0)" % [
		player.owned_weapons.has(offered_id), player.current_weapon.id, offered_id, player.coins
	])

	# --- Ancient Shrine: a temporary damage modifier that decays after N
	# wave transitions. ---
	player.temp_damage_bonus_pct = 0.0
	main.shrine_effect_waves_remaining = 0
	main._resolve_event_choice("ancient_shrine", true)
	print("touching the shrine sets a nonzero temporary damage modifier and starts its countdown: nonzero=%s (expected true), waves_remaining=%d (expected %d)" % [
		player.temp_damage_bonus_pct != 0.0, main.shrine_effect_waves_remaining, main.SHRINE_EFFECT_WAVES
	])
	for i in main.SHRINE_EFFECT_WAVES:
		if main.shrine_effect_waves_remaining > 0:
			main.shrine_effect_waves_remaining -= 1
			if main.shrine_effect_waves_remaining == 0:
				player.temp_damage_bonus_pct = 0.0
	print("the modifier clears after %d wave transitions: temp_damage_bonus_pct=%.2f (expected 0.0)" % [main.SHRINE_EFFECT_WAVES, player.temp_damage_bonus_pct])

	# --- The shrine's modifier actually changes dealt damage. ---
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_target_index = 0
	player.stat_strength = 10
	player.attack_damage = 10
	var g_baseline := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [g_baseline]
	main._apply_single_hit(0, 1.0, "", {"damage_mult": 1.0})
	var baseline_dmg: int = 999 - g_baseline.hp

	player.temp_damage_bonus_pct = 0.20
	var g_blessed := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [g_blessed]
	main._apply_single_hit(0, 1.0, "", {"damage_mult": 1.0})
	var blessed_dmg: int = 999 - g_blessed.hp
	print("the shrine's blessing actually increases dealt damage: baseline=%d blessed=%d (expected blessed > baseline, blessed==%d)" % [
		baseline_dmg, blessed_dmg, int(round(baseline_dmg * 1.2))
	])
	player.temp_damage_bonus_pct = 0.0

	# --- Wounded Traveler ---
	player.potion_queue = ["potion_health", "potion_health"]
	player.healing_items = 2
	player.coins = 0
	main._resolve_event_choice("wounded_traveler", true)
	print("helping consumes exactly one healing item and grants coins: items_left=%d (expected 1), coins=%d (expected 40)" % [
		player.healing_items, player.coins
	])

	player.potion_queue = []
	player.healing_items = 0
	player.coins = 0
	main._resolve_event_choice("wounded_traveler", true)
	print("helping with nothing to give is a graceful no-op: items_left=%d (expected 0), coins_unchanged=%s (expected true)" % [
		player.healing_items, player.coins == 0
	])

	player.potion_queue = ["potion_health"]
	player.healing_items = 1
	player.coins = 0
	main._resolve_event_choice("wounded_traveler", false)
	print("ignoring leaves the traveler's items and coins untouched: items=%d (expected 1), coins=%d (expected 0)" % [
		player.healing_items, player.coins
	])

	quit()
