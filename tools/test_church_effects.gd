extends SceneTree

# What the rebuilt Church's newer nodes DO once bought: Silver Muscles, Light Metal, Take a Breather, Battle Medic, Heroic Destiny, War
# Profiteer, Release Grudge, Otherworldly Power, Smart Savage, Continual Growth and the Sorcery wing's passives -- plus the one-time refund of a save from
# the old tree.

func _make_goblin(main, tile: Vector2i, hp: int = 999) -> Dictionary:
	var g = load("res://scripts/Enemy.gd").new()
	main.add_child(g)
	g.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	return {
		"ref": g, "tile": tile, "hp": hp, "max_hp": hp, "move_range": 2, "damage": 0,
		"name": "Goblin", "winding_up": false, "stunned": false, "attack_range": 1,
		"concussed_turns": 0, "frozen_turns": 0, "burning": false, "armored": false,
		"disarmed_tile": Vector2i(-1, -1), "vulnerable_turns": 0, "aware_of_player": true, "size": 1,
	}

func _init() -> void:
	seed(20261018)
	var save_data_script = load("res://scripts/SaveData.gd")
	var weapons_script = load("res://scripts/Weapons.gd")

	# =========================================================
	# The save from the OLD tree is refunded, once
	# =========================================================
	var path: String = save_data_script._resolve_save_path()
	var legacy := FileAccess.open(path, FileAccess.WRITE)
	legacy.store_string(JSON.stringify({"essence": 10, "upgrades": {"strength": 2, "warlord": 1, "silver_tongue": 1, "unknown_thing": 5}, "best_wave": 3, "difficulty": "normal", "name": "Old"}))
	legacy.close()
	var expected_refund: int = (15 + 23) + 600 + 120
	var migrated: Dictionary = save_data_script.load_data()
	print("A save with no Church version is refunded at the OLD prices (2 Brawn 15+23, Warlord 600, Silver Tongue 120): essence=%d (expected %d)" % [migrated.essence, 10 + expected_refund])
	print("...it starts the new tree empty and stamped: upgrades=%s church_version=%d (expected {}, %d)" % [migrated.upgrades, int(migrated.church_version), save_data_script.CHURCH_VERSION])
	print("...the rest of the save is untouched: best_wave=%d difficulty=%s name=%s (expected 3, normal, Old)" % [migrated.best_wave, migrated.difficulty, migrated.name])
	print("...and the refund is paid once, not on every load: essence=%d (expected %d)" % [save_data_script.load_data().essence, 10 + expected_refund])
	var other_path: String = save_data_script._resolve_save_path(2)
	var other := FileAccess.open(other_path, FileAccess.WRITE)
	var other_text: String = JSON.stringify({"essence": 5, "upgrades": {"strength": 1}, "best_wave": 1, "difficulty": "hard", "name": "Other"})
	other.store_string(other_text)
	other.close()
	var summary: Dictionary = save_data_script.slot_summary(2)
	print("The file select shows a not-yet-loaded old save as it will be: upgrades=%d essence=%d (expected 0, %d)" % [summary.upgrades, summary.essence, 5 + 15])
	print("...without touching the file: %s (expected true)" % [FileAccess.get_file_as_string(other_path) == other_text])
	save_data_script.delete_slot(2)
	# a save from the short-lived first rebuild (version 2) is refunded at ITS prices
	var v2 := FileAccess.open(path, FileAccess.WRITE)
	v2.store_string(JSON.stringify({"essence": 5, "upgrades": {"legacy": 1, "stamina": 3, "steady_flow": 2}, "best_wave": 0, "church_version": 2}))
	v2.close()
	var after_v2: Dictionary = save_data_script.load_data()
	print("A version-2 save is refunded at the first rebuild's prices (Legacy 1, Deep Lungs 1+1+2, 2 levels of the dropped Steady Flow 8+12): essence=%d (expected %d), upgrades=%s, version=%d (expected 3)" % [after_v2.essence, 5 + 1 + 4 + 8 + 12, after_v2.upgrades, int(after_v2.church_version)])

	# =========================================================
	# Every node's effect, through a real save
	# =========================================================
	save_data_script.save_data({
		"essence": 0,
		"upgrades": {
			"silver_muscles": 1, "light_metal": 1, "take_a_breather": 1, "battle_medic": 1, "heroic_destiny": 1, "war_profiteer": 1,
			"release_grudge": 1, "deep_well": 1, "continual_learning": 1, "innate_power": 1, "smart_savage": 1, "continual_growth": 1, "painful_memories": 1,
			"otherworldly_power": 1,
		},
		"best_wave": 0,
	})
	var main = load("res://Main.tscn").instantiate()
	main.regional_world = false
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	print("The Sorcery wing's passives are live: grudge=%s (expected true), +%.1f magic per level for members (1.0), deep_well=%d (20), continual_learning=%s (true), potency=%.2f (0.33)" % [
		player.meta_release_grudge, player.meta_member_magic_per_level, player.meta_max_mana_flat, player.meta_intellect, player.meta_spell_potency_pct
	])
	print("Otherworldly Power is recorded: %s (expected true)" % [player.meta_otherworldly_power])

	# --- Heroic Destiny: the wooden shield (the wooden club is what every run starts with) ---
	print("Heroic Destiny starts you with a wooden shield in hand: %s (expected Wooden Buckler), owned=%s (expected true), weapon=%s (expected Club)" % [
		player.equipped_shield.get("name", "none"), player.owned_shields.has("shield_buckler"), player.current_weapon.get("id", "?")
	])

	# --- Light Metal: half the Might ---
	# (a Masterwork asks for 8 Might, a Legendary 15 -- Weapons.gd TIERS)
	var masterwork: Dictionary = weapons_script.SPEAR.duplicate(true)
	masterwork["required_might"] = 8
	var legendary: Dictionary = weapons_script.SPEAR.duplicate(true)
	legendary["required_might"] = 15
	print("Light Metal halves the Might asked, rounding up: Masterwork %d -> %d (expected 8 -> 4), Legendary %d -> %d (expected 15 -> 8)" % [
		int(masterwork.required_might), player.might_needed(masterwork), int(legendary.required_might), player.might_needed(legendary)
	])
	player.stat_might = 4
	player.coins = 99999
	print("...so Might 4 now buys a Masterwork weapon: %s (expected true)" % [player.try_buy_weapon(masterwork)])
	player.stat_might = 3
	print("...but not at Might 3: %s (expected false)" % [player.try_buy_weapon(weapons_script.DAGGER.merged({"required_might": 8}, true))])
	player.meta_light_metal = false
	player.stat_might = 4
	print("Without Light Metal Might 4 is not enough: %s (expected false)" % [player.try_buy_weapon(weapons_script.GREATSWORD.merged({"required_might": 8}, true))])
	player.meta_light_metal = true

	# --- Silver Muscles reaches the equipped weapon (the capstones test covers the numbers) ---
	print("Silver Muscles: meta_special_stamina_flat=%d (expected 5)" % [player.meta_special_stamina_flat])

	# --- Take a Breather: Defend heals 1/16 of max HP ---
	main.in_battle = true
	main.battle_allies = []
	main.battle_units = [_make_goblin(main, Vector2i(5, 5))]
	main.battle_player_tile = Vector2i(0, 0)
	player.max_health = 160
	player.health = 100
	main.in_battle = false    # halts the cascade before it can alter health through the enemy turn
	main._battle_player_defend()
	main.in_battle = true
	print("Take a Breather: Defending heals max HP / 16 (160 / 16 = 10): health=%d (expected 110)" % [player.health])

	# --- Battle Medic: a healing item used in battle hurts every enemy for 5 ---
	player.health = 50
	player.add_potion("potion_health")
	var foe_a: Dictionary = _make_goblin(main, Vector2i(5, 5))
	var foe_b: Dictionary = _make_goblin(main, Vector2i(6, 6))
	main.battle_units = [foe_a, foe_b]
	main.battle_turn = "player"
	main._battle_player_item()
	print("Battle Medic: using a potion in battle deals 5 damage to every enemy: %d and %d damage (expected 5 and 5)" % [999 - foe_a.hp, 999 - foe_b.hp])
	player.meta_battle_medic_damage = 0
	player.add_potion("potion_health")
	var foe_c: Dictionary = _make_goblin(main, Vector2i(5, 5))
	main.battle_units = [foe_c]
	main._battle_player_item()
	print("...and nothing without it: %d damage (expected 0)" % [999 - foe_c.hp])

	# --- The Wizard's Tower: the doc says + costs 10 and EX 40 more, and an upgrade belongs to its caster ---
	player.party = []
	var tower_druid = player.recruit("druid")
	var tower_shaman = player.recruit("shaman")
	print("The Tower's prices: + %d (expected 10), EX %d (expected 40)" % [player.spell_upgrade_price(1), player.spell_upgrade_price(2)])
	var rows: Array = main.spell_upgrade_rows()
	print("...one row per spell per caster (the Druid and the Shaman have 3 each): %d rows (expected 6), the first reads '%s' (expected '10 Essence')" % [rows.size(), rows[0].price_text])
	save_data_script.save_data({"essence": 9, "upgrades": {}, "best_wave": 0})
	print("...9 Essence is not enough for 10: bought=%s (expected false)" % [player.try_upgrade_spell(tower_druid, "druid_heal")])
	save_data_script.save_data({"essence": 12, "upgrades": {}, "best_wave": 0})
	print("...12 is: bought=%s (expected true), left=%d (expected 2), and it is HERS: druid %d, shaman %d (expected 1, 0)" % [player.try_upgrade_spell(tower_druid, "druid_heal"), save_data_script.banked_essence(), player.spell_level_of(tower_druid, "druid_heal"), player.spell_level_of(tower_shaman, "druid_heal")])

	# --- War Profiteer is on a per-run counter that resets with a new Player (checked in test_skill_tree_new_nodes) ---
	print("War Profiteer: %.3f per kill (expected 0.002)" % [player.meta_war_profiteer_pct_per_kill])

	# --- Release Grudge gates the Druid ---
	player.meta_release_grudge = false
	player.party = []
	main.druid_recruited = false
	print("Without Release Grudge the Druid refuses to join: %s (expected false), party=%d (expected 0)" % [main._try_recruit_druid(), player.party.size()])
	player.meta_release_grudge = true
	print("With it she joins: %s (expected true), party=%d (expected 1)" % [main._try_recruit_druid(), player.party.size()])
	player.party = []
	main.druid_recruited = false
	player.meta_release_grudge = false
	save_data_script.sandbox_active = true
	print("The sandbox lets anyone join: %s (expected true)" % [main._try_recruit_druid()])
	save_data_script.sandbox_active = false

	# --- Release Grudge lifts a non-caster member's magic as they level ---
	player.party = []
	player.meta_release_grudge = true
	var knight = player.recruit("knight")
	knight.level = 4
	player.meta_member_magic_per_level = 0.0
	var plain_magic: float = main._make_member_battle_unit(knight, Vector2i(1, 1), 1.0).magic
	player.meta_member_magic_per_level = 1.0
	var trained_magic: float = main._make_member_battle_unit(knight, Vector2i(1, 1), 1.0).magic
	print("Release Grudge gives +1 Magic per level gained (3 levels): %.1f -> %.1f (expected +3.0)" % [plain_magic, trained_magic])

	# --- Smart Savage, Continual Growth, Painful Memories ---
	print("Smart Savage unlocks Fortitude: %s (expected true), with no pick-doubling left: %s (expected false)" % [player.meta_fortitude_unlocked, player.meta_fortitude_pick_doubled])
	player.meta_levelup_bonus_might = 2
	var might_before: int = player.stat_might
	player.apply_bonus_stat("might")
	print("Continual Growth makes a level-up put into Might worth more: +%d (expected +3, 1 and 2 more)" % [player.stat_might - might_before])
	print("Painful Memories is recorded (Rage is not a stat yet): %s (expected true)" % [player.meta_rage_unlocked])

	save_data_script.save_data({"essence": 0, "upgrades": {}, "best_wave": 0})
	quit()
