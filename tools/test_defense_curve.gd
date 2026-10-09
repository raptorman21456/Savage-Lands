extends SceneTree

# The Defense curve (scripts/Defense.gd): points of Defense / Fortitude bend into a cut with
# diminishing returns, towards an 80% ceiling (the Guardian's is 90%) that is never reached.

const DefenseScript := preload("res://scripts/Defense.gd")

func _reset(main, player) -> void:
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_allies = []
	main.battle_units = []
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_player_defending = false
	main.battle_spellward_used = false
	main.tutorial_active = false
	player.resilience_reduction = 0.0
	player.stat_fortitude = 0
	player.equipped_armor = {"damage_reduction": 0.0, "fortitude": 0}
	player.equipped_shield = {}
	player.equipped_talismans = []
	player._rebuild_talisman_cache()
	player.potion_resilience_turns = 0
	player.meta_last_stand_pct_per_10 = 0.0
	player.meta_war_chest_reduction = 0.0
	player.equipped_clothing = {"head": "", "body": "", "feet": ""}
	player.max_health = 100
	player.health = 100

func _init() -> void:
	seed(20261011)
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player

	# --- the curve itself ---
	print("0 points cut nothing: %.4f (expected 0.0000)" % [DefenseScript.reduction(0.0)])
	print("60 points (HALF_POINTS) earn half the 80%% ceiling: %.4f (expected 0.4000)" % [DefenseScript.reduction(DefenseScript.HALF_POINTS)])
	print("20 points: %.4f (expected 0.2000); 100 points: %.4f (expected 0.5000)" % [DefenseScript.reduction(20.0), DefenseScript.reduction(100.0)])
	var first_ten: float = DefenseScript.reduction(10.0) - DefenseScript.reduction(0.0)
	var next_ten: float = DefenseScript.reduction(110.0) - DefenseScript.reduction(100.0)
	print("Diminishing returns: the first 10 points are worth %.3f, points 100-110 only %.3f (expected the first to be bigger): %s" % [first_ten, next_ten, first_ten > next_ten * 3.0])
	var climbing := true
	var last := -1.0
	for p in [1.0, 5.0, 20.0, 80.0, 300.0, 1000.0, 100000.0]:
		var r: float = DefenseScript.reduction(p)
		if r <= last or r >= 0.8:
			climbing = false
		last = r
	print("It only ever climbs and never reaches 80%%: %s (expected true); 1,000,000 points = %.5f (expected < 0.8)" % [climbing, DefenseScript.reduction(1000000.0)])
	print("The Guardian's ceiling is 90%%: 100 points = %.4f (expected 0.5625); a million = %.5f (expected < 0.9)" % [DefenseScript.reduction(100.0, DefenseScript.GUARDIAN_CAP), DefenseScript.reduction(1000000.0, DefenseScript.GUARDIAN_CAP)])
	print("Negative points curve towards -50%%: -5 = %.4f (expected -0.0385), -100000 = %.4f (expected about -0.5)" % [DefenseScript.reduction(-5.0), DefenseScript.reduction(-100000.0)])

	# --- the hero ---
	_reset(main, player)
	player.equipped_armor = {"damage_reduction": 0.30, "fortitude": 0}
	print("30 points of armour: bodily harm cut %.4f (expected 0.2667), a hit of 100 = %d (expected 73)" % [player.bodily_reduction(), main._apply_incoming_reductions(100, {})])
	player.resilience_reduction = 0.30
	print("...plus 30 Resilience pool into 60 points: cut %.4f (expected 0.4000), a hit of 100 = %d (expected 60)" % [player.bodily_reduction(), main._apply_incoming_reductions(100, {})])
	player.equipped_shield = {"damage_reduction_pct": 0.10, "block_chance": 0.0}
	player.current_weapon = load("res://scripts/Weapons.gd").CLUB
	player.meta_war_chest_reduction = 0.10
	print("...a shield (+10) and War Chest (+10) join the pool too (80 points): %.1f points, a hit of 100 = %d (expected 80.0 points, 54)" % [player.bodily_defense_points(), main._apply_incoming_reductions(100, {})])
	player.equipped_shield = {}
	player.meta_war_chest_reduction = 0.0

	# Last Stand and the Resilience Potion pool as points too, so the ceiling holds for them as well.
	player.resilience_reduction = 0.0
	player.equipped_armor = {"damage_reduction": 100.0, "fortitude": 0}
	player.potion_resilience_turns = 3
	player.meta_last_stand_pct_per_10 = 0.10
	player.health = 1
	var worst: int = main._apply_incoming_reductions(100, {})
	print("Everything stacked on a near-dead hero still lets some through: %d (expected 20, never less than 20 for 100)" % [worst])
	player.potion_resilience_turns = 0
	player.meta_last_stand_pct_per_10 = 0.0
	player.health = 100

	# Fortitude uses the same curve
	_reset(main, player)
	player.stat_fortitude = 60
	print("60 Fortitude = %.4f magical cut (expected 0.4000): a spell of 100 = %d (expected 60), a sword of 100 = %d (expected 100)" % [player.fortitude_reduction(), main._apply_incoming_reductions(100, {"harm": "magical"}), main._apply_incoming_reductions(100, {})])

	# Defend, cover and the like are not stats: they still apply on top.
	player.equipped_armor = {"damage_reduction": 0.60, "fortitude": 0}
	main.battle_player_defending = true
	print("Defend still halves what the curve lets through (60 points -> 100 becomes 50, then 40%% off): %d (expected 30)" % [main._apply_incoming_reductions(100, {})])
	main.battle_player_defending = false

	# --- allies ---
	var attacker := {"ref": null, "tile": Vector2i(9, 9), "name": "Goblin", "hp": 100, "max_hp": 100, "attack_range": 1, "size": 1, "burning": false}
	var knight := {"tile": Vector2i(0, 0), "hp": 1000, "max_hp": 1000, "dmg_mult": 1.0, "name": "Knight", "kind": "knight", "defense_pct": 60.0, "fortitude": 60.0, "move_range": 1, "attack_range": 1}
	main.battle_allies = [knight]
	await main._enemy_apply_damage(attacker, Vector2i(0, 0), 100, {})
	print("An ally with 60 Defense takes 60 of 100: %d (expected 60)" % [1000 - knight.hp])
	knight.hp = 1000
	await main._enemy_apply_damage(attacker, Vector2i(0, 0), 100, {"harm": "magical"})
	print("...and 60 Fortitude does the same against a spell: %d (expected 60)" % [1000 - knight.hp])
	knight.defense_pct = 1000000.0
	knight.hp = 1000
	await main._enemy_apply_damage(attacker, Vector2i(0, 0), 100, {})
	print("A million Defense is still short of 80%%: %d (expected 20)" % [1000 - knight.hp])
	var guardian_member = load("res://scripts/PartyMember.gd").create(1, "guardian")
	var knight_member = load("res://scripts/PartyMember.gd").create(2, "knight")
	print("Only the Guardian reaches for 90%%: guardian cap %.2f (expected 0.90), knight cap %.2f (expected 0.80)" % [guardian_member.defense_cap(), knight_member.defense_cap()])
	knight["defense_cap"] = guardian_member.defense_cap()
	knight.hp = 1000
	await main._enemy_apply_damage(attacker, Vector2i(0, 0), 100, {})
	print("...so a Guardian with a million Defense takes: %d (expected 10)" % [1000 - knight.hp])
	knight["defense_cap"] = 0.9
	knight["defense_pct"] = 0.0
	knight["fortitude"] = 1000000.0
	knight.hp = 1000
	await main._enemy_apply_damage(attacker, Vector2i(0, 0), 100, {"harm": "magical"})
	print("...and its Fortitude shares the 90%% ceiling: %d (expected 10)" % [1000 - knight.hp])

	main.in_battle = false
	quit()
