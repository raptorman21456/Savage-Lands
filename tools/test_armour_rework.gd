extends SceneTree

# The armour rework: fourteen armours each with a trait, bodily vs magical harm (Fortitude),
# pelt armours crafted from enemy drops, and Fortitude as an Astral-unlocked stat.

func _wear(player, id: String) -> void:
	var armor: Dictionary = load("res://scripts/Armor.gd").find(id)
	player.owned_armor[id] = true
	player.equipped_armor = armor
	player.refresh_armor_effects()
	# refreshing recalculates stats from Vigor; the checks below want a round 100 HP hero
	player.max_health = 100
	player.health = clampi(player.health, 0, 100)

func _foe(tile: Vector2i, range_: int = 1) -> Dictionary:
	return {"tile": tile, "name": "Goblin", "hp": 100, "max_hp": 100, "attack_range": range_, "size": 1, "burning": false}

func _reset(main, player) -> void:
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_allies = []
	main.battle_units = []
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_player_defending = false
	main.battle_spellward_used = false
	main.battle_bloodrage_stacks = 0
	main.battle_bloodrage_turns = 0
	main.battle_shadow_crit = false
	main.tutorial_active = false
	player.resilience_reduction = 0.0
	player.stat_fortitude = 0
	player.equipped_shield = {}
	player.equipped_talismans = []
	player._rebuild_talisman_cache()
	player.potion_resilience_turns = 0
	player.meta_last_stand_pct_per_10 = 0.0
	player.meta_war_chest_reduction = 0.0
	player.equipped_clothing = {"head": "", "body": "", "feet": ""}
	player.miss_chance_override = 0.0
	player.max_health = 100
	player.health = 100
	player.max_stamina = 100
	player.stamina = 100

func _init() -> void:
	seed(20261010)
	var armor_script = load("res://scripts/Armor.gd")
	var materials_script = load("res://scripts/Materials.gd")
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player

	# =========================================================
	# The roster
	# =========================================================
	var names := []
	for a in armor_script.TIERS:
		names.append(a.name)
	print("Fourteen armours: %d (expected 14) -- %s" % [armor_script.TIERS.size(), names])
	var crafted := []
	for a in armor_script.TIERS:
		if armor_script.is_crafted(a):
			crafted.append(a.name)
	print("The pelt armours are crafted, not bought: %s (expected Dragonskin, Bloodrage Hide, Shadowweave, Windrunner's Jerkin)" % [crafted])
	print("The shop only rolls the other ten: %d (expected 10), crafted among them: %s (expected false)" % [armor_script.shop_pool().size(), armor_script.shop_pool().any(func(a): return a.has("recipe"))])
	var pelt_fort := []
	var plain_fort := []
	for a in armor_script.TIERS:
		if armor_script.is_crafted(a):
			pelt_fort.append(int(a.fortitude))
		elif a.id != "armor_spellward":
			plain_fort.append(int(a.fortitude))
	print("Pelt armours carry more Fortitude than the ordinary ones (their lowest %d vs the ordinary ones' top %d, Spellward aside): %s (expected true)" % [pelt_fort.min(), plain_fort.max(), pelt_fort.min() > plain_fort.max()])
	var icons_ok := true
	for a in armor_script.TIERS:
		if not ResourceLoader.exists(armor_script.icon_path(a)):
			icons_ok = false
	print("Every armour finds a picture (its own or its stand-in): %s (expected true)" % [icons_ok])

	# =========================================================
	# Bodily vs magical harm
	# =========================================================
	_reset(main, player)
	_wear(player, "armor_rags")
	print("Bare, both kinds of harm land in full: bodily=%d magical=%d both=%d (expected 100 100 100)" % [main._apply_incoming_reductions(100, {}), main._apply_incoming_reductions(100, {"harm": "magical"}), main._apply_incoming_reductions(100, {"harm": "both"})])
	_wear(player, "armor_gambeson")
	print("Gambeson: -15%% bodily, +5 Fortitude: bodily=%d magical=%d (expected 85, 95)" % [main._apply_incoming_reductions(100, {}), main._apply_incoming_reductions(100, {"harm": "magical"})])
	print("...a blast of both is half and half: %d (expected 91 = 42.5 -> 43 bodily + 47.5 -> 48 magical)" % [main._apply_incoming_reductions(100, {"harm": "both"})])
	player.resilience_reduction = 0.20
	print("Resilience cuts BODILY harm only: bodily=%d magical=%d (expected 65, 95)" % [main._apply_incoming_reductions(100, {}), main._apply_incoming_reductions(100, {"harm": "magical"})])
	player.resilience_reduction = 0.0
	player.stat_fortitude = 70
	print("Fortitude is capped at 75%%: 5 + 70 points = %.2f reduction, magical hit of 100 = %d (expected 0.75, 25)" % [player.fortitude_reduction(), main._apply_incoming_reductions(100, {"harm": "magical"})])
	player.stat_fortitude = 0
	_wear(player, "armor_thornmail")
	print("Thornmail's -5 Fortitude makes spells hurt more: reduction %.2f, magical hit of 100 = %d (expected -0.05, 105); bodily = %d (expected 70)" % [player.fortitude_reduction(), main._apply_incoming_reductions(100, {"harm": "magical"}), main._apply_incoming_reductions(100, {})])
	print("A potion of resilience and Last Stand cut BOTH kinds: potion on, Gambeson magical: (set below)")
	_wear(player, "armor_gambeson")
	player.potion_resilience_turns = 2
	print("...a Resilience Potion (-20%%): bodily=%d magical=%d (expected 65, 75)" % [main._apply_incoming_reductions(100, {}), main._apply_incoming_reductions(100, {"harm": "magical"})])
	player.potion_resilience_turns = 0
	main.battle_player_defending = true
	print("Defend halves either kind (when it's not small enough to negate): bodily=%d magical=%d (expected 43, 48)" % [main._apply_incoming_reductions(100, {}), main._apply_incoming_reductions(100, {"harm": "magical"})])
	main.battle_player_defending = false
	print("Enemies are tagged: Apprentice Mage=%s Archmage=%s Black Dragonlet=%s Lava Construct=%s Goblin=%s (expected magical magical both both bodily)" % [
		main.ENEMY_TRAITS["Apprentice Mage"].get("harm", "bodily"), main.ENEMY_TRAITS["Archmage"].get("harm", "bodily"),
		main.ENEMY_TRAITS["Black Dragonlet"].get("harm", "bodily"), main.ENEMY_TRAITS["Lava Construct"].get("harm", "bodily"),
		main.ENEMY_TRAITS.get("Goblin", {}).get("harm", "bodily")])

	# =========================================================
	# The traits
	# =========================================================
	_reset(main, player)
	_wear(player, "armor_stonehide")
	print("Stonehide Mail: -10%% then -3 flat: a hit of 100 = %d (expected 87); a hit of 3 = %d (expected 1, never 0); magical 100 = %d (expected 95, flat cut is bodily only)" % [main._apply_incoming_reductions(100, {}), main._apply_incoming_reductions(3, {}), main._apply_incoming_reductions(100, {"harm": "magical"})])

	_wear(player, "armor_martyr")
	player.max_health = 100
	player.health = 100
	var martyr_full: int = main._apply_incoming_reductions(100, {})
	player.health = 50
	print("Martyr's Mantle at full health: %d (expected 95); at half health (-5%% +15%%): %d (expected 80)" % [martyr_full, main._apply_incoming_reductions(100, {})])
	player.health = 100

	_wear(player, "armor_bastion")
	main.battle_player_defending = true
	print("Bastion Mail: Defend negates hits up to 17 (usual threshold 10 + 8): 17 -> %d (expected 0), 18 -> %d (expected 9 after Defend's halving, then -25%% = 7)" % [main._apply_incoming_reductions(17, {}), main._apply_incoming_reductions(18, {})])
	main.battle_player_defending = false
	player.stamina = 10
	player.regen_stamina(main.STAMINA_REGEN_ON_DEFEND + int(player.armor_trait_value("defend_stamina_bonus", 0)))
	print("...and Defend gives back 15 + 10 stamina: %d (expected 35)" % [player.stamina])

	_wear(player, "armor_fortress")
	var move_with_fortress: int = main._battle_player_move_range()
	_wear(player, "armor_rags")
	var move_bare: int = main._battle_player_move_range()
	_wear(player, "armor_windrunner")
	var move_with_wind: int = main._battle_player_move_range()
	print("Fortress Plate costs a move tile, Windrunner's gives one: bare=%d fortress=%d windrunner=%d (expected %d, %d, %d)" % [move_bare, move_with_fortress, move_with_wind, move_bare, move_bare - 1, move_bare + 1])
	_wear(player, "armor_fortress")
	print("Fortress Plate can't be swept off a water tile: %s (expected true); Gambeson: %s (expected false)" % [player.shield_push_immune(), (func(): _wear(player, "armor_gambeson"); return player.shield_push_immune()).call()])
	print("Windrunner's Jerkin adds 2 Speed for turn order: %d (expected 2)" % [(func(): _wear(player, "armor_windrunner"); return player.armor_speed_bonus()).call()])

	# Thornmail / Cinder
	_reset(main, player)
	_wear(player, "armor_thornmail")
	var melee_foe := _foe(Vector2i(3, 2))
	main._land_enemy_hit_on_player(melee_foe, 10, {})
	print("Thornmail throws back 30%% of a melee hit: foe 100 -> %d (expected 97)" % [melee_foe.hp])
	var archer := _foe(Vector2i(6, 2), 3)
	main._land_enemy_hit_on_player(archer, 10, {})
	var mage := _foe(Vector2i(3, 3))
	main._land_enemy_hit_on_player(mage, 10, {"harm": "magical"})
	print("...but not an archer's arrow (%d) or a spell (%d) (expected 100 and 100)" % [archer.hp, mage.hp])
	_wear(player, "armor_cinder")
	var melee_foe2 := _foe(Vector2i(3, 2))
	var archer2 := _foe(Vector2i(6, 2), 3)
	main._land_enemy_hit_on_player(melee_foe2, 10, {})
	main._land_enemy_hit_on_player(archer2, 10, {})
	print("Cinder Mail sets a melee attacker alight (%s, expected true) but not an archer (%s, expected false)" % [melee_foe2.burning, archer2.burning])
	print("...and its heat costs 10 max stamina: %d (expected 90); taking it off restores it: %d (expected 100)" % [player.max_stamina, (func(): _wear(player, "armor_rags"); return player.max_stamina).call()])

	# Bloodrage
	_reset(main, player)
	_wear(player, "armor_bloodrage")
	var rager := _foe(Vector2i(3, 2))
	main._land_enemy_hit_on_player(rager, 5, {})
	main._land_enemy_hit_on_player(rager, 5, {})
	print("Bloodrage Hide: two hits taken = %d stacks (expected 2), lasting %d turns (expected 2)" % [main.battle_bloodrage_stacks, main.battle_bloodrage_turns])
	var target := _foe(Vector2i(3, 2))
	target.hp = 999
	target.max_hp = 999
	target["ref"] = null
	target["armored"] = false
	player.attack_damage = 100
	main.battle_units = [target]
	main.battle_stat_override = -1.0
	var stacked_before: int = target.hp
	main._apply_single_hit(0, 1.0, "", {"damage_mult": 1.0})
	var stacked_dmg: int = stacked_before - target.hp
	main.battle_bloodrage_stacks = 0
	target.hp = 999
	main._apply_single_hit(0, 1.0, "", {"damage_mult": 1.0})
	var plain_dmg: int = 999 - target.hp
	print("...and your own hits deal +20%% for it: %d vs %d without (expected 1.2x)" % [stacked_dmg, plain_dmg])

	# Shadowweave
	_reset(main, player)
	_wear(player, "armor_shadowweave")
	print("Shadowweave adds 10%% dodge: %.2f (expected 0.10)" % [player.dodge_chance_total()])
	main._on_hero_dodged()
	var sw_target := _foe(Vector2i(3, 2))
	sw_target.hp = 999
	sw_target.max_hp = 999
	sw_target["ref"] = null
	main.battle_units = [sw_target]
	player.attack_damage = 10
	main._apply_single_hit(0, 1.0, "", {"damage_mult": 1.0})
	var crit_dmg: int = 999 - sw_target.hp
	sw_target.hp = 999
	sw_target["vulnerable_turns"] = 0
	main._apply_single_hit(0, 1.0, "", {"damage_mult": 1.0})
	print("...a dodge makes the NEXT attack a crit, once: %d then %d (expected 20 then 10)" % [crit_dmg, 999 - sw_target.hp])

	# Spellward
	_reset(main, player)
	_wear(player, "armor_spellward")
	player.stamina = 10
	var first: int = main._apply_incoming_reductions(100, {"harm": "magical"})
	var second: int = main._apply_incoming_reductions(100, {"harm": "magical"})
	print("Spellward Robes swallow the first magical hit of a battle (%d, expected 0), then 30 Fortitude cuts the next (%d, expected 70); each gave 10 stamina: %d (expected 30)" % [first, second, player.stamina])
	print("Their bodily protection is slight: %d (expected 95)" % [main._apply_incoming_reductions(100, {})])

	# Warden's Aegis on an ally
	_reset(main, player)
	var ally := {"tile": Vector2i(3, 2), "hp": 100, "max_hp": 100, "name": "Test", "defense_pct": 0.0, "fortitude": 0.0, "kind": "x"}
	var far_ally := {"tile": Vector2i(7, 7), "hp": 100, "max_hp": 100, "name": "Far", "defense_pct": 0.0, "fortitude": 0.0, "kind": "x"}
	main.battle_allies = [ally, far_ally]
	var attacker := _foe(Vector2i(4, 2))
	_wear(player, "armor_rags")
	await main._enemy_apply_damage(attacker, ally.tile, 20, {})
	var without_aegis: int = 100 - ally.hp
	ally.hp = 100
	_wear(player, "armor_warden")
	await main._enemy_apply_damage(attacker, ally.tile, 20, {})
	await main._enemy_apply_damage(attacker, far_ally.tile, 20, {})
	print("Warden's Aegis: an ally near you takes 15%% less (%d vs %d, expected 17 vs 20); one far away does not (%d, expected 20)" % [100 - ally.hp, without_aegis, 100 - far_ally.hp])

	# Allies and Fortitude
	_reset(main, player)
	_wear(player, "armor_rags")
	var member := {"tile": Vector2i(3, 2), "hp": 100, "max_hp": 100, "name": "Knight", "defense_pct": 30.0, "fortitude": 10.0, "kind": "knight"}
	main.battle_allies = [member]
	await main._enemy_apply_damage(attacker, member.tile, 100, {})
	var bodily_taken: int = 100 - member.hp
	member.hp = 100
	await main._enemy_apply_damage(attacker, member.tile, 100, {"harm": "magical"})
	var magical_taken: int = 100 - member.hp
	member.hp = 100
	await main._enemy_apply_damage(attacker, member.tile, 100, {"harm": "both"})
	print("An ally's defense cuts bodily harm and its Fortitude magical harm: bodily=%d (expected 70), magical=%d (expected 90), both=%d (expected 80)" % [bodily_taken, magical_taken, 100 - member.hp])

	# =========================================================
	# Shields lean towards Fortitude
	# =========================================================
	_reset(main, player)
	_wear(player, "armor_rags")
	var shields = load("res://scripts/Shields.gd")
	player.equipped_shield = shields.SHIELDS["shield_phantom"].duplicate(true)
	player.current_weapon = load("res://scripts/Weapons.gd").CLUB
	print("The Phantom Guard leans furthest towards Fortitude: +%d (expected +12); it blocks magic too (block chance %.2f for any hit, expected 0.18)" % [int(player.shield_fortitude()), player.shield_block_chance()])
	print("...so magical harm drops by it: %d (expected 88)" % [main._apply_incoming_reductions(100, {"harm": "magical"})])
	player.equipped_shield = {}

	# =========================================================
	# Materials and crafting
	# =========================================================
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var dragon: Dictionary = materials_script.roll_drops("Black Dragonlet", rng)
	print("A dragon always drops scales (2-4): %s (expected true)" % [int(dragon.get("dragon_scale", 0)) >= 2 and int(dragon.get("dragon_scale", 0)) <= 4])
	var mage_drops := 0
	for i in 200:
		if materials_script.roll_drops("Apprentice Mage", rng).has("mage_hair"):
			mage_drops += 1
	print("An Apprentice Mage sometimes drops hair (about 35%% of 200): %d (expected 50-90); a Goblin never drops any: %s (expected {})" % [mage_drops, materials_script.roll_drops("Goblin", rng)])
	player.materials = {}
	player.coins = 500
	var dragonskin: Dictionary = armor_script.find("armor_dragonskin")
	print("Can't be bought: %s (expected false); can't be crafted without scales: %s (expected false)" % [player.try_buy_armor(dragonskin), player.try_craft_armor(dragonskin)])
	main.in_battle = false
	main._on_enemy_died(5, "Black Dragonlet")
	main._on_enemy_died(5, "White Dragon")
	print("Killing dragons drops scales for you: %d (expected 5-9)" % [player.material_count("dragon_scale")])
	player.materials["dragon_scale"] = 8
	var coins_before: int = player.coins
	print("With 8 scales and the coin it's crafted: %s (expected true), scales left %d (expected 0), coins %d -> %d (expected -120), worn: %s (expected armor_dragonskin)" % [player.try_craft_armor(dragonskin), player.material_count("dragon_scale"), coins_before, player.coins, player.equipped_armor.id])
	print("...and only once: %s (expected false)" % [player.can_craft_armor(dragonskin)])
	print("Recipe text reads naturally: '%s' (expected 3 Mage Hair + 3 Bear Pelt + 40 coins)" % [materials_script.recipe_text(armor_script.find("armor_bloodrage").recipe)])

	# The Blacksmith's commissions
	main.in_battle = false
	# The dragon kills above levelled the hero up: close that choice before walking into a shop.
	main.choosing_stat = false
	main.hud.hide_levelup_choice()
	main.game_over = false
	main.get_tree().paused = false
	var smith = main.town_panels.get("blacksmith")
	player.owned_armor = {"armor_rags": true}
	player.equipped_armor = armor_script.find("armor_rags")
	player.materials = {"feather": 5}
	player.coins = 100
	player.owned_weapons = {"club": true}
	main._try_open_panel("blacksmith")
	smith._refresh()
	var commissions: Array = smith.entry_buttons.keys().filter(func(k): return str(k).begins_with("recipe:"))
	print("The smith lists the four pelt armours as commissions: %d (expected 4)" % [commissions.size()])
	smith.select("recipe", "armor_windrunner")
	print("...and with 5 Feathers and 50 coins he makes the Windrunner's Jerkin: %s (expected true), worn %s" % [smith.craft_armor("armor_windrunner"), player.equipped_armor.id])
	smith.close()

	# =========================================================
	# Fortitude as a stat (the Church's magical wing)
	# =========================================================
	_reset(main, player)
	var save_data = load("res://scripts/SaveData.gd")
	print("Three new Church nodes in a wing of their own: %s (expected warded_mind, mental_mush, smort_savage)" % [["warded_mind", "mental_mush", "smort_savage"].filter(func(id): return save_data.UPGRADES.has(id))])
	player._refresh_meta_passives({})
	var locked_level: int = player.level
	player._level_up()
	print("Before Warded Mind Fortitude stays 0 on level-up: %d (expected 0)" % [player.stat_fortitude])
	player._refresh_meta_passives({"warded_mind": 1})
	player._level_up()
	print("Warded Mind unlocks it (+1 a level): %d (expected 1)" % [player.stat_fortitude])
	player._refresh_meta_passives({"warded_mind": 1, "mental_mush": 2})
	player._level_up()
	print("Mental Mush level 2 adds 2 more every level-up: %d (expected 1 + 3 = 4)" % [player.stat_fortitude])
	player.apply_bonus_stat("fortitude")
	print("The bonus pick is +1 normally: %d (expected 5)" % [player.stat_fortitude])
	player._refresh_meta_passives({"warded_mind": 1, "mental_mush": 2, "smort_savage": 1})
	player.apply_bonus_stat("fortitude")
	print("...and +2 with Smort Savage: %d (expected 7)" % [player.stat_fortitude])
	print("Sandbox offers it as a pickable stat once unlocked: %s (expected true)" % [load("res://scripts/Sandbox.gd").pickable_stats(player).has("fortitude")])
	player._refresh_meta_passives({})

	quit()
