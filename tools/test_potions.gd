extends SceneTree

# Potions: 6 distinct types, no longer "same heal, bigger number" -- Health
# is a plain heal (matching wild meat drops), Cleansing heals and washes
# away every negative status, and Attack/Resilience/Energy are temporary
# combat buffs with no healing at all. Stamina is an instant refill.

func _make_goblin(main, tile: Vector2i, hp: int = 999999) -> Dictionary:
	var goblin_script = load("res://scripts/Enemy.gd")
	var g = goblin_script.new()
	main.add_child(g)
	g.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	return {
		"ref": g, "tile": tile, "hp": hp, "max_hp": hp, "move_range": 2,
		"damage": 0, "name": "Goblin", "winding_up": false, "stunned": false,
	}

func _init() -> void:
	var potions_script = load("res://scripts/Potions.gd")
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player

	print("catalog has 6 tiers: %d (expected 6)" % potions_script.TIERS.size())
	print("Health Potion has no secondary effect: '%s' (expected empty)" % [potions_script.get_tier("potion_health").effect])
	print("Attack Potion's effect is 'attack_buff', no healing: %s heal=%d (expected true, 0)" % [
		potions_script.get_tier("potion_attack").effect == "attack_buff", potions_script.get_tier("potion_attack").heal_amount
	])
	print("Resilience Potion's effect is 'resilience_buff', no healing: %s heal=%d (expected true, 0)" % [
		potions_script.get_tier("potion_resilience").effect == "resilience_buff", potions_script.get_tier("potion_resilience").heal_amount
	])
	print("Energy Potion's effect is 'energy_buff', no healing: %s heal=%d (expected true, 0)" % [
		potions_script.get_tier("potion_energy").effect == "energy_buff", potions_script.get_tier("potion_energy").heal_amount
	])
	print("Stamina Potion's effect is 'restore_stamina', no healing: %s heal=%d (expected true, 0)" % [
		potions_script.get_tier("potion_stamina").effect == "restore_stamina", potions_script.get_tier("potion_stamina").heal_amount
	])
	print("Cleansing Potion's effect is 'cleanse': %s (expected true)" % [potions_script.get_tier("potion_regular").effect == "cleanse"])
	print("An unknown id returns {}: %s (expected true)" % [potions_script.get_tier("potion_nonexistent").is_empty()])

	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_allies = []
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_target_index = 0
	main.battle_turn = "player"
	player.meta_healing_bonus_pct = 0.0
	player.meta_battle_medic = false
	player.stat_strength = 10
	player.attack_damage = 10
	player.max_health = 100

	# --- Health Potion: plain heal, no other effect. ---
	player.potion_queue = ["potion_health"]
	player.healing_items = 1
	player.health = 50
	main._battle_player_item()
	print("Health Potion heals 20 HP: health=%d (expected 70)" % [player.health])

	# --- Cleansing Potion: heals 12 AND strips every negative status. ---
	main.player_poison_turns = 3
	main.player_poison_dmg = 4
	main.player_burning = true
	main.player_bleeding = true
	main.player_concussed_turns = 2
	main.player_blind_turns = 2
	player.potion_queue = ["potion_regular"]
	player.healing_items = 1
	player.health = 50
	main.battle_turn = "player"
	main._battle_player_item()
	print("Cleansing Potion heals 12 HP: health=%d (expected 62)" % [player.health])
	print("...and strips every negative status: poison_turns=%d poison_dmg=%d burning=%s bleeding=%s concussed_turns=%d blind_turns=%d (expected 0, 0, false, false, 0, 0)" % [
		main.player_poison_turns, main.player_poison_dmg, main.player_burning, main.player_bleeding, main.player_concussed_turns, main.player_blind_turns
	])

	# --- Attack Potion: no healing, but +25% damage dealt for a few turns. ---
	player.potion_queue = ["potion_attack"]
	player.healing_items = 1
	player.health = 50
	main.battle_turn = "player"
	main._battle_player_item()
	print("Attack Potion heals nothing and arms the buff: health=%d (expected unchanged 50), potion_attack_turns=%d (expected 3)" % [
		player.health, player.potion_attack_turns
	])

	player.stamina = player.MAX_STAMINA
	var g_buffed := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [g_buffed]
	main._battle_player_fight()
	var buffed_dealt: int = 999999 - g_buffed.hp
	var expected_buffed_dealt: int = int(round(10 * player.current_weapon.damage_mult * 1.25))
	print("...+25%% damage actually applies while active: dealt=%d (expected %d)" % [buffed_dealt, expected_buffed_dealt])

	player.potion_attack_turns = 0
	var g_expired := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [g_expired]
	player.stamina = player.MAX_STAMINA
	main._battle_player_fight()
	var expired_dealt: int = 999999 - g_expired.hp
	print("...and once the buff runs out, damage is plain again: dealt=%d (expected %d)" % [expired_dealt, int(round(10 * player.current_weapon.damage_mult))])

	# --- Resilience Potion: no healing, but a flat incoming-damage cut for
	# a few turns. ---
	player.potion_queue = ["potion_resilience"]
	player.healing_items = 1
	player.health = 50
	main.battle_turn = "player"
	main._battle_player_item()
	print("Resilience Potion heals nothing and arms the buff: health=%d (expected unchanged 50), potion_resilience_turns=%d (expected 3)" % [
		player.health, player.potion_resilience_turns
	])
	player.equipped_armor = {"damage_reduction": 0.0}
	player.resilience_reduction = 0.0
	player.meta_war_chest_reduction = 0.0
	player.equipped_shield = {}
	main.battle_player_defending = false
	print("...-20%% incoming damage actually applies while active: dmg=%d (expected 80)" % [main._apply_incoming_reductions(100, {})])
	player.potion_resilience_turns = 0
	print("...and once it runs out, incoming damage is unreduced: dmg=%d (expected 100)" % [main._apply_incoming_reductions(100, {})])

	# --- Energy Potion: no healing, but +1 battle move range for a few
	# turns. ---
	var base_move_range: int = main._battle_player_move_range()
	player.potion_queue = ["potion_energy"]
	player.healing_items = 1
	player.health = 50
	main.battle_turn = "player"
	main._battle_player_item()
	print("Energy Potion heals nothing and arms the buff: health=%d (expected unchanged 50), potion_energy_turns=%d (expected 3)" % [
		player.health, player.potion_energy_turns
	])
	print("...+1 move range actually applies while active: range=%d (expected %d)" % [main._battle_player_move_range(), base_move_range + 1])
	player.potion_energy_turns = 0
	print("...and once it runs out, move range is back to normal: range=%d (expected %d)" % [main._battle_player_move_range(), base_move_range])

	# --- Stamina Potion: no healing, instantly refills stamina, no
	# duration to track at all. ---
	player.stamina = 0
	player.potion_queue = ["potion_stamina"]
	player.healing_items = 1
	player.health = 50
	main.battle_turn = "player"
	main._battle_player_item()
	print("Stamina Potion heals nothing and instantly refills stamina: health=%d (expected unchanged 50), stamina=%d (expected %d, full)" % [
		player.health, player.stamina, player.MAX_STAMINA
	])

	# --- No items to use is a graceful no-op. ---
	player.potion_queue = []
	player.healing_items = 0
	main.battle_turn = "player"
	main._battle_player_item()
	print("No items to use is a no-op, doesn't end the turn: battle_turn=%s (expected still player)" % [main.battle_turn])

	quit()
