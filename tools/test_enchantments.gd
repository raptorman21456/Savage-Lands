extends SceneTree

func _init() -> void:
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var player = main.player
	var weapons_script = load("res://scripts/Weapons.gd")
	var enchant_script = load("res://scripts/Enchantments.gd")
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	print("catalog has 4 runes: %d (expected 4)" % enchant_script.RUNES.size())

	# --- can't enchant Club ---
	player.runic_shards = 100
	player.coins = 1000
	player.current_weapon_base = weapons_script.CLUB
	player.current_weapon = weapons_script.CLUB
	print("can't enchant Club: %s (expected false)" % player.try_apply_enchantment("ember"))

	# --- basic apply: costs currency, merges both halves of the pact -- the
	# damage buff AND the recoil downside -- and leaves every special slot
	# untouched (no more active-slot replacement). ---
	var spear: Dictionary = weapons_script.SPEAR.duplicate(true)
	spear.id = "spear_test_enchant"
	player.owned_weapons[spear.id] = true
	player._equip_weapon(spear)
	player.runic_shards = 10
	player.coins = 100
	var applied: bool = player.try_apply_enchantment("ember")
	print("applying Rune of Bloodlust: applied=%s (expected true), shards_left=%d (expected 7), coins_left=%d (expected 60)" % [
		applied, player.runic_shards, player.coins
	])
	var expected_dmg: float = weapons_script.SPEAR.damage_mult * 1.5
	print("Bloodlust's +50%% damage_bonus_pct merged: dmg=%.3f (expected %.3f)" % [player.current_weapon.damage_mult, expected_dmg])
	print("Bloodlust's recoil downside merged: passive_self_damage_pct=%.2f (expected 0.15)" % player.current_weapon.get("passive_self_damage_pct", 0.0))
	print("no special slot is replaced -- all 3 names unchanged: %s, %s, %s (expected Piercing Thrust, Wombo Combo, Target Practice)" % [
		player.current_weapon.specials[0].name, player.current_weapon.specials[1].name, player.current_weapon.specials[2].name
	])

	# --- one rune per weapon max ---
	var second_try: bool = player.try_apply_enchantment("tempest")
	print("a second enchantment on the same weapon is rejected: %s (expected false)" % second_try)

	# --- re-equipping the same weapon doesn't double-apply ---
	player._equip_weapon(player.current_weapon_base)
	print("re-equipping doesn't double-apply the passive: dmg=%.3f (expected still %.3f, not %.3f)" % [
		player.current_weapon.damage_mult, expected_dmg, weapons_script.SPEAR.damage_mult * 1.5 * 1.5
	])

	# --- insufficient currency fails cleanly ---
	var spear2: Dictionary = weapons_script.SPEAR.duplicate(true)
	spear2.id = "spear_test_enchant_2"
	player.owned_weapons[spear2.id] = true
	player._equip_weapon(spear2)
	player.runic_shards = 0
	player.coins = 0
	print("can't afford a rune: %s (expected false)" % player.try_apply_enchantment("leech"))

	# --- lifesteal stacks with a Mythic weapon's own passive (the Great
	# Toothpicke's own 25% + Rune of the Leech's own 25%) ---
	var mythic_spear: Dictionary = weapons_script.make_variant(weapons_script.SPEAR, 5)
	player.owned_weapons[mythic_spear.id] = true
	player._equip_weapon(mythic_spear)
	player.runic_shards = 10
	player.coins = 100
	player.try_apply_enchantment("leech")
	print("Mythic spear + Rune of the Leech stacks lifesteal: %.2f (expected 0.50 = 0.25+0.25)" % player.current_weapon.passive_lifesteal_pct)
	print("Leech's -20%% damage downside merged: dmg=%.3f (expected %.3f)" % [
		player.current_weapon.damage_mult, mythic_spear.damage_mult * 0.8
	])

	# --- Warding merges its control upside and its (reworked) recoil
	# downside together, same shape as Bloodlust's but a smaller cut. ---
	var hammer: Dictionary = weapons_script.HAMMER.duplicate(true)
	hammer.id = "hammer_test_enchant"
	player.owned_weapons[hammer.id] = true
	player._equip_weapon(hammer)
	player.runic_shards = 10
	player.coins = 100
	player.try_apply_enchantment("warding")
	print("Warding merges guaranteed_knockback=%s, ignore_cover=%s, self_damage_pct=%.2f (expected true, true, 0.10)" % [
		player.current_weapon.get("passive_guaranteed_knockback", false),
		player.current_weapon.get("passive_ignore_cover", false),
		player.current_weapon.get("passive_self_damage_pct", 0.0),
	])

	# --- battle behavior: Bloodlust's recoil actually fires in battle, on a
	# plain Fight -- not gated behind any particular special. ---
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_target_index = 0
	player.stat_strength = 10
	player.attack_damage = 10
	var spear3: Dictionary = weapons_script.SPEAR.duplicate(true)
	spear3.id = "spear_test_enchant_3"
	player.owned_weapons[spear3.id] = true
	player._equip_weapon(spear3)
	player.runic_shards = 10
	player.coins = 100
	player.try_apply_enchantment("ember")
	player.stamina = player.MAX_STAMINA
	player.health = player.max_health
	var goblin_script = load("res://scripts/Enemy.gd")
	var g := {
		"ref": goblin_script.new(), "tile": Vector2i(3, 2), "hp": 999, "max_hp": 999,
		"move_range": 2, "damage": 0, "name": "Goblin", "winding_up": false, "stunned": false,
	}
	main.add_child(g.ref)
	g.ref.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	main.battle_units = [g]
	main._battle_player_fight()
	var dealt: int = 999 - g.hp
	var expected_recoil: int = max(1, int(round(dealt * 0.15)))
	print("Bloodlust's recoil actually fires in battle: dealt=%d, player_health=%d (expected max_health-%d = %d)" % [
		dealt, player.health, expected_recoil, player.max_health - expected_recoil
	])

	quit()
