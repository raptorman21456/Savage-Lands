extends SceneTree

# Two rules straight from the design doc (2026-10-30): a weapon carries flat Strength (or Magic) for every rung of the
# quality ladder it sits on -- "+4 STR per quality tier" for a Spear, the Club a flat +2 -- and tile movement is
# 1 tile + 0.05 per point of speed, rounded down.

# base id => STR (or Magic) per quality tier, as the doc lists them
const PER_TIER := {"spear": 4, "greatsword": 6, "hammer": 7, "battle_axe": 5, "dagger": 4, "bow": 5, "knuckle_gloves": 4, "hand_picks": 4}

func _make_goblin(main, tile: Vector2i, hp: int = 99999) -> Dictionary:
	var g = load("res://scripts/Enemy.gd").new()
	main.add_child(g)
	g.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	return {
		"ref": g, "tile": tile, "hp": hp, "max_hp": hp, "move_range": 2, "damage": 1,
		"name": "Goblin", "winding_up": false, "stunned": false, "attack_range": 1,
		"concussed_turns": 0, "frozen_turns": 0, "burning": false, "armored": false,
		"disarmed_tile": Vector2i(-1, -1), "vulnerable_turns": 0, "aware_of_player": true, "size": 1,
	}

func _init() -> void:
	seed(20261107)
	var weapons = load("res://scripts/Weapons.gd")
	var main = load("res://Main.tscn").instantiate()
	main.regional_world = false
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	main.settings.attack_minigame_enabled = false
	main.settings.combat_minigames_enabled = false
	player.max_party_slots = 8
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	print("--- the ladder: Broken, Worn, Fine, Masterwork, Legendary, Mythic = rungs 0 to 5")
	var wrong := []
	for base_id in PER_TIER:
		var base: Dictionary = {}
		for b in weapons.UPGRADABLE_TYPES:
			if b.id == base_id:
				base = b
		for tier in weapons.TIERS:
			var v: Dictionary = weapons._build_tiered_variant(base, tier, weapons.MATERIALS[1])
			if int(v.get("str_bonus", -1)) != int(PER_TIER[base_id]) * int(tier.rank):
				wrong.append("%s %s" % [base_id, tier.tier_name])
	print("every weapon type carries the doc's STR per tier, times its tier's rung: wrong=%s (expected [])" % [wrong])
	var fine_spear: Dictionary = weapons.get_owned_variant("spear_fine_steel")
	var broken_spear: Dictionary = weapons.get_owned_variant("spear_broken_steel")
	var legendary_spear: Dictionary = weapons.get_owned_variant("spear_legendary_steel")
	print("a Spear: Broken +%d, Fine +%d, Legendary +%d STR (expected 0, 8, 16)" % [broken_spear.str_bonus, fine_spear.str_bonus, legendary_spear.str_bonus])
	var mythic_spear: Dictionary = weapons.get_owned_variant("spear_mythic")
	print("a Mythic carries the top rung: the Great Toothpicke +%d STR (expected 20)" % [mythic_spear.str_bonus])
	print("the Club is a flat +%d STR (expected 2), and has no tiers to grow it" % [weapons.CLUB.str_bonus])
	var staff: Dictionary = weapons.get_owned_variant("staff_fine_steel")
	var wand_legendary: Dictionary = weapons.get_owned_variant("wand_legendary_steel")
	var moonstick: Dictionary = weapons.get_owned_variant("wand_mythic")
	print("Staff +5 Magic per tier, Wand +6: a Fine Staff +%d, a Legendary Wand +%d, Moonstick +%d (expected 10, 24, 30)" % [staff.magic_bonus, wand_legendary.magic_bonus, moonstick.magic_bonus])
	print("the unique Retribution sits on the Legendary rung: +%d STR (expected 16)" % [weapons.get_owned_variant("dagger_retribution").str_bonus])

	print("--- the hero swings on Strength + the weapon's STR")
	player.stat_strength = 10
	player.attack_damage = 10
	player.stamina = player.max_stamina
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_allies = []
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_turn = "player"
	main.battle_first_attack_used = true
	main.tutorial_active = false
	player.max_health = 100
	player.health = 100
	player.current_weapon = weapons.CLUB
	var t1 := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [t1]
	main._battle_player_fight()
	print("a Club hit: (10 + 2) x 1.0 = %d (expected 12)" % [99999 - t1.hp])
	player.current_weapon = fine_spear
	player.stamina = player.max_stamina
	main.battle_turn = "player"
	var t2 := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [t2]
	main._battle_player_fight()
	var expect_spear: int = int(round((10.0 + 8.0) * float(fine_spear.damage_mult)))
	print("a Fine Spear hit: (10 + 8) x %.2f = %d (expected %d)" % [fine_spear.damage_mult, 99999 - t2.hp, expect_spear])
	print("the card's damage number agrees: %d (expected %d)" % [player.weapon_damage_preview(fine_spear), expect_spear])
	print("the estimate over the target agrees on its low end: %d (expected %d)" % [main._estimate_hit(_make_goblin(main, Vector2i(3, 2)), 1.0).x, expect_spear])
	main.in_battle = false

	print("--- members: the weapon's STR joins their own, a Staff's Magic joins theirs")
	var knight = player.recruit("knight")
	var gs: Dictionary = weapons.get_owned_variant("greatsword_fine_steel")
	player.owned_weapons["greatsword_fine_steel"] = true
	player.equip_ally_weapon(knight, "greatsword_fine_steel")
	var ku: Dictionary = main._make_member_battle_unit(knight, Vector2i(1, 2), 1.0)
	print("a Knight with a Fine Greatsword: attack %.1f = his own %.1f + %d (expected %.1f)" % [ku.attack, knight.attack(), gs.str_bonus, knight.attack() + 12.0])
	var druid = player.recruit("druid")
	player.owned_weapons["staff_fine_steel"] = true
	player.equip_ally_weapon(druid, "staff_fine_steel")
	var du: Dictionary = main._make_member_battle_unit(druid, Vector2i(1, 3), 1.0)
	print("a Druid with a Fine Staff: magic %.2f = (10 + 10) x 1.15 (expected 23.00); her mana still comes from Intelligence: %d (expected 50)" % [du.magic, du.max_mana])

	print("--- tile movement: 1 + 0.05 per speed point, rounded down")
	var agi0: int = player.AGILITY_START
	var rows := []
	for rating in [5, 19, 20, 39, 40, 60]:
		player.stat_agility = agi0 + (rating - 5) * player.AGILITY_BONUS_PER_LEVEL
		rows.append("%d->%d" % [rating, main._battle_player_move_range()])
	print("the hero at speed rating 5, 19, 20, 39, 40, 60: %s (expected 5->1, 19->1, 20->2, 39->2, 40->3, 60->4)" % [", ".join(rows)])
	player.stat_agility = agi0
	var shaman = player.recruit("shaman")
	var necro = player.recruit("necromancer")
	print("a new Shaman and Necromancer walk %d and %d tile (expected 1 and 1)" % [shaman.move_tiles(), necro.move_tiles()])
	shaman.bonus["speed"] = 15.0   # fifteen picks of speed, so the rating reaches 20 (levels alone add only 0.2 a time)
	print("a Shaman at speed rating %.1f: %d tiles (expected 2 once the rating reaches 20)" % [shaman.raw_stat("speed"), shaman.move_tiles()])
	var guardian = player.recruit("guardian")
	var rogue = player.recruit("rogue")
	var marksman = player.recruit("marksman")
	var wolf = player.recruit("wolf")
	print("kinds with their own rule keep it: Guardian %d (always 1), Rogue %d (2 + 0.12 x 5), Marksman %d (1 + 0.075 x 5, up), Wolf %d (x1.5, up) (expected 1, 2, 2, 2)" % [guardian.move_tiles(), rogue.move_tiles(), marksman.move_tiles(), wolf.move_tiles()])
	quit()
