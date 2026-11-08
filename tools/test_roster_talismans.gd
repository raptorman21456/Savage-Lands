extends SceneTree

# The talisman roster as the design doc (2026-10-30) lists it: the new ones (Rusted Edge, Fake PHD, Honour, Thorny Ring,
# Rebound, Masochist, BFF Bracelet, Fitbit) and the reworked numbers (Whetstone per wearer, Gilded Scarab in percent, Phoenix
# Ash spent on use). The older talismans keep their own checks in test_talismans.gd.

func _make_goblin(main, tile: Vector2i, hp: int = 999) -> Dictionary:
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

func _reset(player) -> void:
	player.equipped_talismans.clear()
	player.owned_talismans.clear()
	player._on_talismans_changed()
	player.level = 20

# Wearing re-sums the stats (which can clamp health), so health is put back to what the check wants afterwards.
func _wear(player, ids: Array, health: int = -1) -> void:
	for id in ids:
		player.owned_talismans[id] = true
		player.equipped_talismans.append(id)
	player._on_talismans_changed()
	player.max_health = 100
	player.health = health if health >= 0 else 100

func _battle(main, player) -> void:
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_allies = []
	main.battle_downed_allies = []
	main.battle_actor = {}
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_turn = "player"
	main.battle_first_attack_used = false
	main.battle_first_hit_allies = {}
	main.tutorial_active = false
	player.max_health = 100
	player.health = 100

func _init() -> void:
	# These checks predate the doc's flat weapon Strength (Club +2, Spear +4 per quality tier...), which has its own test
	# (test_weapon_stat_bonuses.gd): here weapons add nothing, so every damage figure below stays as it was.
	var _stat_weapons = load("res://scripts/Weapons.gd")
	_stat_weapons.CLUB["str_bonus"] = 0
	for _stat_base in _stat_weapons.UPGRADABLE_TYPES:
		_stat_base["str_per_tier"] = 0
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
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)
	player.meta_favour_chance = 0.0
	player.max_party_slots = 6

	print("--- the roster, by the doc's names and numbers")
	var tals = load("res://scripts/Talismans.gd")
	var names := {"berserkers_knot": "Berserk Brace", "whetstone_pendant": "Whetstone", "rusted_edge": "Rusted Edge", "fake_phd": "Fake PHD", "honour": "Honour",
		"thorny_ring": "Thorny Ring", "guardian_knot": "BFF Bracelet", "iron_will_band": "Iron Will Ring", "rebound": "Rebound", "masochist": "Masochist",
		"cliffwalkers_bead": "Cliffwalker's Beadstring", "moss_charm": "Mossy Rock", "healers_knot": "Little Sprout", "second_wind_whistle": "Fitbit",
		"deep_lung_charm": "Protein Bars", "merchants_coin": "Metal Detector", "glass_cannon_charm": "Glass Cannon", "vampires_pact": "Bat Fang",
		"whirlwind_charm": "Double-Blade Technique", "bloodmoon_fang": "Bloodthirsty Idol", "ironclad_ward": "Steelclad Band", "ember_charm": "Pyrogenesis Organ",
		"swift_feather": "Scroll of the Swift", "pathfinders_compass": "Compass"}
	var wrong := []
	for id in names:
		if str(tals.get_talisman(id).get("name", "")) != names[id]:
			wrong.append(id)
	print("every renamed talisman carries the doc's name: wrong=%s (expected [])" % [wrong])
	print("Rusted Edge is uncommon: %s, Thorny Ring epic: %s, BFF Bracelet allies-only: %s (expected uncommon, epic, true)" % [tals.get_talisman("rusted_edge").rarity, tals.get_talisman("thorny_ring").rarity, tals.get_talisman("guardian_knot").get("allies_only", false)])

	print("--- Rusted Edge and Fake PHD")
	_reset(player)
	_battle(main, player)
	player.current_weapon = weapons.CLUB
	player.stat_strength = 10
	player.attack_damage = 10
	player.stamina = player.max_stamina
	_wear(player, ["rusted_edge"])
	player._talisman_cache["poison_chance"] = 1.0
	var t1 := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [t1]
	main._battle_player_fight()
	print("Rusted Edge poisons a target it hits: poisoned=%s (expected true)" % [int(t1.get("poison_turns", 0)) > 0])
	player._talisman_cache["poison_chance"] = 0.0
	var t2 := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [t2]
	main._battle_player_fight()
	print("...and without the chance it does not: poison_turns=%d (expected 0)" % [int(t2.get("poison_turns", 0))])
	_reset(player)
	_battle(main, player)
	_wear(player, ["fake_phd"])
	player._talisman_cache["random_status_chance"] = 1.0
	var seen := {}
	for i in 60:
		var g := _make_goblin(main, Vector2i(3, 2))
		main.battle_units = [g]
		main._apply_single_hit(0, 1.0, "", weapons.CLUB, "You", Vector2i(-1, -1), 1, false)
		var got := []
		if int(g.get("poison_turns", 0)) > 0: got.append("poison")
		if g.get("burning", false): got.append("burn")
		if int(g.get("bleed_turns", 0)) > 0: got.append("bleed")
		if int(g.get("frozen_turns", 0)) > 0: got.append("freeze")
		if int(g.get("concussed_turns", 0)) > 0: got.append("concuss")
		if int(g.get("blind_turns", 0)) > 0: got.append("blind")
		if int(g.get("vulnerable_turns", 0)) > 0: got.append("vulnerable")
		if g.get("stunned", false): got.append("stun")
		if int(g.get("fear_turns", 0)) > 0: got.append("fear")
		for k in got:
			seen[k] = true
	print("Fake PHD leaves some negative status on every hit, and over 60 hits shows at least five kinds: kinds=%d (expected >= 5)" % [seen.size()])

	print("--- Honour, Masochist, Rebound")
	_reset(player)
	_battle(main, player)
	player.health = 80
	player.take_battle_damage(10, true)
	print("without Honour a blast hurts: %d (expected 70)" % [player.health])
	_wear(player, ["honour"], 70)
	player.take_battle_damage(10, true)
	print("Honour spares you an indirect hit: %d (expected 70)" % [player.health])
	player.take_battle_damage(10)
	print("...but not a direct attack: %d (expected 60)" % [player.health])
	main._hero_dot_damage(8, "You burn for %d damage!", "fire")
	print("...nor does a burn tick hurt: %d (expected 60)" % [player.health])
	_reset(player)
	player.max_health = 100
	player.health = 60
	main._hero_dot_damage(8, "You burn for %d damage!", "fire")
	print("a burn tick normally hurts: %d (expected 52)" % [player.health])
	_wear(player, ["masochist"], 52)
	main._hero_dot_damage(8, "You burn for %d damage!", "fire")
	print("Masochist turns the tick into healing: %d (expected 60)" % [player.health])
	_reset(player)
	print("Rebound: a 5-turn poison lasts %d without it (expected 5)" % [main._status_len(5)])
	_wear(player, ["rebound"])
	print("...and %d with it (expected 4), never below one: %d (expected 1)" % [main._status_len(5), main._status_len(1)])

	print("--- Thorny Ring, BFF Bracelet, Gilded Scarab")
	_reset(player)
	_battle(main, player)
	player.equipped_armor = load("res://scripts/Armor.gd").TIERS[0]
	player.equipped_clothing = {"head": "", "body": "", "feet": ""}
	player.resilience_reduction = 0.0
	player.meta_war_chest_reduction = 0.0
	player.meta_last_stand_pct_per_10 = 0.0
	player.equipped_shield = {}
	player.potion_resilience_turns = 0
	main.battle_player_defending = false
	print("a 20-point blow lands for %d (expected 20)" % [main._apply_incoming_reductions(20, {})])
	_wear(player, ["thorny_ring"])
	print("Thorny Ring doubles what lands on you: %d (expected 40)" % [main._apply_incoming_reductions(20, {})])
	player.current_weapon = weapons.CLUB
	player.stat_strength = 10
	player.attack_damage = 10
	player.stamina = player.max_stamina
	var t3 := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [t3]
	main._battle_player_fight()
	print("...and doubles what you deal: %d (expected 20)" % [999 - t3.hp])
	_reset(player)
	print("the hero cannot wear a BFF Bracelet: equip=%s (expected false)" % [(func(): player.owned_talismans["guardian_knot"] = true; return player.equip_talisman("guardian_knot")).call()])
	player.coins = 500
	_reset(player)
	var bought: bool = player.try_buy_talisman("guardian_knot")
	print("buying one puts it in the collection without wearing it: bought=%s (expected true), worn=%s (expected [])" % [bought, player.equipped_talismans])
	var knight = player.recruit("knight")
	var worn: bool = player.equip_ally_talisman(knight, "guardian_knot")
	print("a member can wear it: %s (expected true)" % [worn])
	var ku: Dictionary = main._make_member_battle_unit(knight, Vector2i(1, 2), 1.0)
	print("...and her unit carries damage_taken_pct %.2f (expected -0.33)" % [main._unit_effect(ku, "damage_taken_pct")])
	_reset(player)
	_battle(main, player)
	player.coins = 1000
	_wear(player, ["gilded_scarab"])
	print("Gilded Scarab at 1000 coins: damage x%.2f (expected 1.30), a 100-point blow becomes %d (expected 90)" % [player.coin_damage_mult(), main._apply_incoming_reductions(100, {})])
	player.coins = 0

	print("--- Fitbit, Whetstone per wearer")
	_reset(player)
	_battle(main, player)
	player.health = 50
	main._fitbit_heal()
	print("without Fitbit a step heals nothing: %d (expected 50)" % [player.health])
	_wear(player, ["second_wind_whistle"], 50)
	main._fitbit_heal()
	main._fitbit_heal()
	print("Fitbit heals 1 HP per tile: %d (expected 52)" % [player.health])
	var fit_member = player.recruit("brawler")
	player.equip_ally_talisman(fit_member, "deep_lung_charm")
	_reset(player)
	var bu: Dictionary = main._make_member_battle_unit(fit_member, Vector2i(1, 2), 1.0)
	bu.hp = bu.max_hp - 5
	bu.mods = {"heal_per_tile": 1.0}
	main._fitbit_heal(bu)
	print("a member wearing it heals too: %d of %d (expected %d of %d)" % [bu.hp, bu.max_hp, bu.max_hp - 4, bu.max_hp])
	_reset(player)
	_battle(main, player)
	player.owned_talismans["whetstone_pendant"] = true
	var wm = player.recruit("rogue")
	wm.gear.talismans = ["whetstone_pendant"]
	var wu: Dictionary = main._make_member_battle_unit(wm, Vector2i(1, 2), 1.0)
	main.battle_allies = [wu]
	main.battle_actor = wu
	var wt := _make_goblin(main, Vector2i(2, 2))
	main.battle_units = [wt]
	main._apply_single_hit(0, 1.0, "", {"damage_mult": 1.0}, "Your Rogue", Vector2i(1, 2))
	var first_dealt: int = 999 - wt.hp
	var wt2 := _make_goblin(main, Vector2i(2, 2))
	main.battle_units = [wt2]
	main._apply_single_hit(0, 1.0, "", {"damage_mult": 1.0}, "Your Rogue", Vector2i(1, 2))
	var second_dealt: int = 999 - wt2.hp
	print("Whetstone on a member: her first hit lands harder than her second: first>second=%s (expected true) [%d vs %d]" % [first_dealt > second_dealt, first_dealt, second_dealt])
	print("...and the hero's own first hit is still unused: %s (expected false)" % [main.battle_first_attack_used])
	main.battle_actor = {}
	main.in_battle = false
	quit()
