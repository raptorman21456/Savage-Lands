extends SceneTree

# Two id-matching bugs that quietly made things inert:
#  - Shield compatibility/synergy compared a shop weapon's FULL id
#    ("spear_fine_steel") to base type names ("spear"), so a shield only worked
#    with the exact "club" id. Shields.base_weapon_id now reduces it.
#  - _gear_quality_score looked armour up with TIERS.find(equipped_armor), but
#    the shop hands out tagged copies that never compare equal, so bought Steel
#    or Dragonskin never counted. Armor.tier_rank matches by id.
# Plus the Hardened skill's HP growth surviving a stat recalculation.

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var shields_script = load("res://scripts/Shields.gd")
	var armor_script = load("res://scripts/Armor.gd")

	# --- Pure id matching ---
	print("a rolled one-handed id reduces to its base type: spear=%s dagger_mythic=%s knuckle=%s club=%s (expected spear, dagger, knuckle_gloves, club)" % [
		shields_script.base_weapon_id("spear_fine_steel"), shields_script.base_weapon_id("dagger_mythic"),
		shields_script.base_weapon_id("knuckle_gloves_worn_wood"), shields_script.base_weapon_id("club")
	])
	print("shop-rolled one-handed weapons are shield-compatible: %s (expected true)" % [
		shields_script.is_weapon_compatible("spear_fine_steel") and shields_script.is_weapon_compatible("hammer_masterwork_gold")
		and shields_script.is_weapon_compatible("dagger_mythic") and shields_script.is_weapon_compatible("knuckle_gloves_broken_bone")
	])
	print("...and rolled two-handed ones are not: %s (expected false)" % [
		shields_script.is_weapon_compatible("battle_axe_fine_steel") or shields_script.is_weapon_compatible("greatsword_worn_wood")
		or shields_script.is_weapon_compatible("bow_fine_wood") or shields_script.is_weapon_compatible("hand_picks_fine_steel")
	])

	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	# --- A real shield with a real rolled weapon ---
	var heavy: Dictionary = shields_script.SHIELDS.shield_heavy
	player.equipped_shield = heavy
	player.meta_shield_universal = false
	player.berserk_turns_remaining = 0
	player.current_weapon = {"id": "spear_fine_steel"}
	print("a Heavy Shield blocks with a rolled Spear: chance=%.2f (expected %.2f)" % [player.shield_block_chance(), heavy.block_chance])
	print("...and gets its Spear synergy: special_pct=%.2f (expected %.2f)" % [player.shield_special_pct(), heavy.synergy_special_pct])
	player.current_weapon = {"id": "dagger_fine_steel"}
	print("off its synergy weapon it still blocks but loses the bonus: chance=%.2f (expected %.2f), special_pct=%.2f (expected %.2f)" % [
		player.shield_block_chance(), heavy.block_chance, player.shield_special_pct(), heavy.special_pct
	])
	player.current_weapon = {"id": "battle_axe_fine_steel"}
	print("a two-handed rolled Battle Axe still shuts the shield off: chance=%.2f (expected 0.00)" % [player.shield_block_chance()])

	# --- Gear score with shop-tagged armour ---
	var steel: Dictionary = armor_script.TIERS[3]
	var tagged: Dictionary = main._tagged(steel, "armor")
	print("Armor.tier_rank finds a tagged copy by id: %d (expected 3), untagged: %d (expected 3), unknown: %d (expected -1)" % [
		armor_script.tier_rank(tagged), armor_script.tier_rank(steel), armor_script.tier_rank({"id": "armor_nope"})
	])
	player.current_weapon = {"id": "spear_fine_steel", "tier_name": "Fine"}
	player.equipped_armor = armor_script.TIERS[1]
	var score_leather: int = main._gear_quality_score()
	player.equipped_armor = tagged
	var score_tagged_steel: int = main._gear_quality_score()
	player.equipped_armor = armor_script.TIERS[4]
	player.current_weapon = {"id": "spear_legendary_steel", "tier_name": "Legendary"}
	var score_full: int = main._gear_quality_score()
	print("gear score counts bought Steel Plate: leather=%d (expected 0), tagged steel=%d (expected 1), dragonskin + Legendary weapon=%d (expected 2)" % [
		score_leather, score_tagged_steel, score_full
	])

	# --- Hardened survives a recalculation ---
	player.meta_hardened_hp_per_wave = 3
	player.hardened_hp_bonus = 0
	player._recalc_stats()
	var base_hp: int = player.max_health
	player.health = player.max_health
	player.add_hardened_hp(3)
	player.add_hardened_hp(3)
	print("Hardened adds max HP and heals by the same amount: max=%d (expected %d), hp=%d (expected %d)" % [player.max_health, base_hp + 6, player.health, base_hp + 6])
	player.stat_vigor += 5
	player._recalc_stats()
	print("...and a level-up recalculation keeps it: max=%d (expected %d)" % [player.max_health, base_hp + 5 + 6])
	player.hardened_hp_bonus = 0
	player.meta_hardened_hp_per_wave = 0
	player._recalc_stats()

	quit()
