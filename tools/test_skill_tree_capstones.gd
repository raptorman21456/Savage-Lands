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
	var save_data_script = load("res://scripts/SaveData.gd")
	var weapons_script = load("res://scripts/Weapons.gd")

	# --- Meta-passives: stamp onto the equipped weapon, re-stamp on switch,
	# stack with a Mythic weapon's own passive, and never corrupt the shared
	# WeaponsScript.CLUB const. ---
	save_data_script.save_data({
		"essence": 0,
		"upgrades": {"berserker_edge": 3, "vampiric_grit": 2, "silver_tongue": 1},
		"best_wave": 0,
	})
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player

	print("Berserker's Edge (3 levels) is live on the starting Club: passive_double_hit_chance=%.2f (expected 0.24)" % [
		player.current_weapon.get("passive_double_hit_chance", 0.0)
	])
	print("Vampiric Grit (2 levels) is live on the starting Club: passive_lifesteal_pct=%.2f (expected 0.10)" % [
		player.current_weapon.get("passive_lifesteal_pct", 0.0)
	])
	print("Silver Tongue is live on the starting Club: passive_free_specials=%s (expected true)" % [
		player.current_weapon.get("passive_free_specials", false)
	])
	print("WeaponsScript.CLUB itself is untouched (the shared const, not a copy): %s (expected 0.0, false, false)" % [
		[weapons_script.CLUB.get("passive_double_hit_chance", 0.0), weapons_script.CLUB.get("passive_lifesteal_pct", 0.0), weapons_script.CLUB.get("passive_free_specials", false)]
	])

	player.coins = 10000
	player.try_buy_weapon(weapons_script.SPEAR)
	print("switching weapons re-stamps the same meta-passives onto the new weapon: double_hit=%.2f lifesteal=%.2f free_specials=%s (expected 0.24, 0.10, true)" % [
		player.current_weapon.get("passive_double_hit_chance", 0.0), player.current_weapon.get("passive_lifesteal_pct", 0.0), player.current_weapon.get("passive_free_specials", false)
	])

	var nightwhisper: Dictionary = weapons_script.make_variant(weapons_script.DAGGER, 5)
	player._equip_weapon(nightwhisper)
	print("meta double-hit chance stacks additively with a Mythic weapon's own passive: %.2f (expected 0.3+0.24=0.54)" % [
		player.current_weapon.get("passive_double_hit_chance", 0.0)
	])

	# --- Blade Ally (now a party member fighting as a real unit on its own
	# tile, with its own turn): scales off the player's own Strength,
	# independent of whatever weapon is equipped. meta_double_hit_chance is
	# reset to 0 here so the player's own regular attack (which DOES roll
	# for a random double-hit) can't randomly interfere with an otherwise-
	# deterministic damage check. main.battle_allies (not just
	# player.party_members) has to be populated directly, same as
	# main.battle_units already is for the enemy side in this file -- it's
	# the battle-time representation _process_ally_turn actually reads.
	player.meta_double_hit_chance = 0.0
	player.party_members = [{"name": "Blade Ally", "dmg_mult": 0.75}]
	player.stat_strength = 10
	player.attack_damage = 10
	player.try_buy_weapon(weapons_script.CLUB)
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_target_index = 0

	# Called directly first, isolated from the player's own attack entirely,
	# for an exact deterministic damage check -- the ally starts already
	# adjacent to the goblin so it attacks without needing to move first.
	var g_ally_direct := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [g_ally_direct]
	main.battle_allies = [{"tile": Vector2i(3, 3), "hp": 20, "max_hp": 20, "dmg_mult": 0.75, "name": "Blade Ally", "move_range": main.ALLY_MOVE_RANGE, "attack_range": main.ALLY_ATTACK_RANGE}]
	main._process_ally_turn()
	var expected_ally_hit: int = roundi(10 * 0.75)
	print("the party member deals damage scaling off Strength alone, independent of the equipped weapon: dealt=%d (expected %d)" % [
		999 - g_ally_direct.hp, expected_ally_hit
	])

	# Then confirm it's actually wired into the real turn-ending flow, not
	# just directly callable -- a regular attack must deal MORE than the
	# player's own hit alone once the ally is following along.
	var g_via_fight := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [g_via_fight]
	main.battle_allies = [{"tile": Vector2i(3, 3), "hp": 20, "max_hp": 20, "dmg_mult": 0.75, "name": "Blade Ally", "move_range": main.ALLY_MOVE_RANGE, "attack_range": main.ALLY_ATTACK_RANGE}]
	main._battle_player_fight()
	print("the party member also fires automatically when a real turn-ending action is taken: ally_contributed=%s (expected true, total dealt %d > the player's own hit of 10)" % [
		(999 - g_via_fight.hp) > 10, 999 - g_via_fight.hp
	])

	player.party_members = []
	main.battle_allies = []
	var g_no_ally := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [g_no_ally]
	main._battle_player_fight()
	print("with an empty party, only the player's own hit lands: dealt=%d (expected 10)" % [999 - g_no_ally.hp])

	# An ally turn with zero enemies left resolves as an instant victory
	# instead of crashing on an out-of-range battle_units access.
	player.party_members = [{"name": "Blade Ally", "dmg_mult": 0.75}]
	main.battle_allies = [{"tile": Vector2i(3, 3), "hp": 20, "max_hp": 20, "dmg_mult": 0.75, "name": "Blade Ally", "move_range": main.ALLY_MOVE_RANGE, "attack_range": main.ALLY_ATTACK_RANGE}]
	main.battle_units = []
	main.in_battle = true
	main._process_ally_turn()
	print("an ally turn with zero enemies left resolves as an instant victory instead of crashing: in_battle=%s (expected false)" % [main.in_battle])

	# Two party members (Pack Leader's payoff) both land a hit the same turn
	# -- both start adjacent to the goblin, on distinct tiles.
	main.in_battle = true
	player.party_members = [{"name": "Blade Ally", "dmg_mult": 0.75}, {"name": "Warrior", "dmg_mult": 0.75}]
	player.max_party_slots = 3
	main.battle_allies = [
		{"tile": Vector2i(3, 3), "hp": 20, "max_hp": 20, "dmg_mult": 0.75, "name": "Blade Ally", "move_range": main.ALLY_MOVE_RANGE, "attack_range": main.ALLY_ATTACK_RANGE},
		{"tile": Vector2i(4, 2), "hp": 20, "max_hp": 20, "dmg_mult": 0.75, "name": "Warrior", "move_range": main.ALLY_MOVE_RANGE, "attack_range": main.ALLY_ATTACK_RANGE},
	]
	var g_two_allies := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [g_two_allies]
	main.battle_target_index = 0
	main._process_ally_turn()
	print("two party members (Pack Leader's payoff) both land a hit: dealt=%d (expected %d, two hits of %d)" % [
		999 - g_two_allies.hp, expected_ally_hit * 2, expected_ally_hit
	])
	player.max_party_slots = 2
	main.battle_allies = []
	# Cleared rather than left with a Blade Ally in the roster -- the
	# sections below call _setup_battle_grid([]) with no enemies, and an
	# ally turn with a real party member but nothing to fight would resolve
	# as an instant victory (see the "instant victory" check above), ending
	# the battle out from under these unrelated Guardian's Ultimatum /
	# Merchant Prince checks.
	player.party_members = []

	# --- Guardian's Ultimatum: a weapon-independent heal on a per-battle
	# cooldown, gated entirely by has_guardian_skill. ---
	player.has_guardian_skill = false
	main._setup_battle_grid([])
	player.health = 1
	main._battle_player_skill()
	print("the Skill button does nothing without has_guardian_skill: player_health=%d (expected unchanged 1)" % [player.health])

	player.has_guardian_skill = true
	main._setup_battle_grid([])
	print("battle_skill_cooldown resets to 0 at battle start: %d (expected 0)" % [main.battle_skill_cooldown])
	player.health = 1
	main._battle_player_skill()
	var expected_heal: int = roundi(player.max_health * 0.4)
	print("Guardian's Ultimatum heals 40%% of max HP: player_health=%d (expected 1+%d=%d), cooldown=%d (expected 3, one tick already applied by this same _end_player_turn call)" % [
		player.health, expected_heal, 1 + expected_heal, main.battle_skill_cooldown
	])

	var health_before_retry: int = player.health
	main._battle_player_skill()
	print("the skill is blocked while on cooldown: player_health=%d (expected unchanged %d)" % [player.health, health_before_retry])

	main._battle_player_defend()
	print("the cooldown ticks down once per player turn regardless of the action taken: cooldown=%d (expected 2, one tick from casting it and one from this Defend)" % [main.battle_skill_cooldown])

	# --- Merchant Prince: one extra shop weapon, guaranteed Masterwork tier
	# or better. ---
	player.has_merchant_prince = false
	main._roll_shop_offering()
	var weapons_without: int = main.current_shop_offering.filter(func(it): return it.category == "weapon").size()
	print("shop offers the normal weapon count without Merchant Prince: %d (expected 5, Club + 4 rolled)" % [weapons_without])

	player.has_merchant_prince = true
	main._roll_shop_offering()
	var weapon_offers: Array = main.current_shop_offering.filter(func(it): return it.category == "weapon")
	var bonus_weapon: Dictionary = weapon_offers[weapon_offers.size() - 1]
	var bonus_rank: int = 0
	for t in weapons_script.TIERS:
		if t.tier_name == bonus_weapon.tier_name:
			bonus_rank = t.rank
	print("Merchant Prince adds one extra weapon offer: %d (expected 6, Club + 4 rolled + 1 bonus)" % [weapon_offers.size()])
	print("the bonus weapon is at least Masterwork tier: tier=%s rank=%d (expected rank >= 3)" % [bonus_weapon.tier_name, bonus_rank])

	# Reset the scratch save for whatever test runs next.
	save_data_script.save_data({"essence": 0, "upgrades": {}, "best_wave": 0})

	quit()
