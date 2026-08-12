extends SceneTree

func _init() -> void:
	var save_data_script = load("res://scripts/SaveData.gd")
	save_data_script.save_data({"essence": 0, "upgrades": {}, "best_wave": 0})

	print("tree has grown noticeably bigger, now with block/riposte/momentum/wolf-duration/shield/Dexterity/Rage/etc. nodes too: %d ids (expected 48)" % [save_data_script.UPGRADE_IDS.size()])

	var data: Dictionary = save_data_script.load_data()
	data.essence = 10000

	# --- tier 1 (wing root) has no prereqs, always unlocked ---
	print("strength (root, no prereqs) starts unlocked: %s (expected true)" % [
		save_data_script.is_upgrade_unlocked(data, "strength")
	])

	# --- tier 2 is locked until tier 1 is owned ---
	print("agility (tier 2) starts locked: %s (expected false)" % [save_data_script.is_upgrade_unlocked(data, "agility")])
	var blocked: bool = save_data_script.try_buy_upgrade(data, "agility")
	print("buying a locked node is rejected: %s (expected false), essence_unchanged=%s (expected true)" % [
		blocked, data.essence == 10000
	])

	# --- buying tier 1 unlocks tier 2, which then SPLITS into two branches ---
	save_data_script.try_buy_upgrade(data, "strength")
	print("agility unlocks once strength is owned: %s (expected true)" % [save_data_script.is_upgrade_unlocked(data, "agility")])
	save_data_script.try_buy_upgrade(data, "agility")
	print("vigor (branch A) and reflexes_unlock (branch B) both unlock off the same agility node: vigor=%s reflexes_unlock=%s (both expected true)" % [
		save_data_script.is_upgrade_unlocked(data, "vigor"), save_data_script.is_upgrade_unlocked(data, "reflexes_unlock")
	])

	# --- Blade Ally is now a CONVERGE point: both branch A (Berserker's
	# Edge) and branch B (Adrenaline) must be independently satisfied, not
	# just one of them -- the real "converging paths" this whole redesign
	# was about. ---
	save_data_script.try_buy_upgrade(data, "vigor")
	save_data_script.try_buy_upgrade(data, "berserker_edge")
	save_data_script.try_buy_upgrade(data, "berserker_edge")
	save_data_script.try_buy_upgrade(data, "berserker_edge")
	print("berserker_edge now at level 3: %d (expected 3)" % [data.upgrades.berserker_edge])
	print("Blade Ally stays locked with ONLY branch A satisfied (branch B/Adrenaline untouched): %s (expected false)" % [
		save_data_script.is_upgrade_unlocked(data, "battle_hardened")
	])

	save_data_script.try_buy_upgrade(data, "reflexes_unlock")
	save_data_script.try_buy_upgrade(data, "adrenaline")
	print("Blade Ally still locked with Adrenaline at only level 1 (needs 2): %s (expected false)" % [
		save_data_script.is_upgrade_unlocked(data, "battle_hardened")
	])
	save_data_script.try_buy_upgrade(data, "adrenaline")
	print("adrenaline now at level 2: %d (expected 2)" % [data.upgrades.adrenaline])
	print("Blade Ally unlocks once BOTH branches are satisfied: %s (expected true)" % [
		save_data_script.is_upgrade_unlocked(data, "battle_hardened")
	])

	# --- capstone is a one-time purchase (max_level 1) ---
	var bought_capstone: bool = save_data_script.try_buy_upgrade(data, "battle_hardened")
	print("capstone purchase succeeds: %s (expected true), level=%d (expected 1)" % [bought_capstone, data.upgrades.battle_hardened])
	var bought_again: bool = save_data_script.try_buy_upgrade(data, "battle_hardened")
	print("capstone can't be bought a second time: %s (expected false), still level=%d (expected 1)" % [bought_again, data.upgrades.battle_hardened])

	# --- other two wings are untouched by buying into the Warrior wing ---
	print("Merchant wing root (coins) is still independently unlocked: %s (expected true)" % [
		save_data_script.is_upgrade_unlocked(data, "coins")
	])
	print("Merchant wing tier 2 (intimidation) is still locked: %s (expected false)" % [
		save_data_script.is_upgrade_unlocked(data, "intimidation")
	])

	# --- Warband is a CROSS-WING convergence: requires a capstone from TWO
	# different wings (Blade Ally already owned above, Merchant Prince not
	# yet) -- locked until both, not just one. ---
	print("Warband (cross-wing) stays locked with only the Warrior side owned: %s (expected false)" % [
		save_data_script.is_upgrade_unlocked(data, "warband")
	])
	for id in ["coins", "intimidation", "luck", "haggling", "silver_tongue", "appraisal"]:
		save_data_script.try_buy_upgrade(data, id)
	save_data_script.try_buy_upgrade(data, "golden_touch")
	print("Merchant Prince purchased: level=%d (expected 1)" % [data.upgrades.get("golden_touch", 0)])
	print("Warband unlocks once BOTH Blade Ally and Merchant Prince are owned: %s (expected true)" % [
		save_data_script.is_upgrade_unlocked(data, "warband")
	])
	save_data_script.try_buy_upgrade(data, "warband")

	save_data_script.save_data(data)

	# --- capstone bonuses actually apply to a fresh Player ---
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	var bonuses: Dictionary = save_data_script.get_applied_bonuses()

	# Vitality no longer touches starting max_health at all -- it's stored as
	# a level-up bonus instead (see Player.gd:apply_bonus_stat), so
	# max_health here should be exactly the base stat_vigor, untouched.
	print("Vitality no longer adds a flat starting max_health bonus: max_health=%d (expected base stat_vigor, unaffected by owning the skill)" % [player.max_health])
	print("health matches max_health: health=%d (expected %d)" % [player.health, player.max_health])
	print("Vitality's bonus is instead stored for level-up time: meta_levelup_bonus_vigor=%d (expected %d, 1 level * 2)" % [player.meta_levelup_bonus_vigor, bonuses.vigor])

	# --- the capstone's real effect is a party member, not a stat ---
	print("owning the Blade Ally capstone adds a party member: %d members (expected 1), name=%s (expected Blade Ally)" % [
		player.party_members.size(), player.party_members[0].name if not player.party_members.is_empty() else "none"
	])
	print("Berserker's Edge's account-wide passive is live on the equipped weapon: passive_double_hit_chance=%.2f (expected >= %.2f, 3 levels * 0.08)" % [
		player.current_weapon.get("passive_double_hit_chance", 0.0), 0.24
	])
	# Reflexes' own dodge chance is now derived from stat_reflexes (a
	# level-up stat, only reachable once reflexes_unlock is owned -- see
	# Player.gd:_recalc_stats), not a direct %/level skill bonus, so a fresh
	# level-1 run reads 0.0 here even with reflexes_unlock purchased above.
	# Adrenaline's low-HP damage bonus is unaffected by that change.
	print("Reflexes is unlocked but its stat (and dodge chance) starts at 0 until leveled: meta_reflexes_unlocked=%s (expected true), dodge=%.2f (expected 0.0), low_hp_damage_bonus=%.2f (expected 0.16)" % [
		player.meta_reflexes_unlocked, player.meta_dodge_chance, player.meta_low_hp_damage_bonus_pct
	])

	# --- Merchant Prince is owned too (bought above for the Warband check),
	# but Guardian's Ultimatum (untouched Survivor wing) stays off. ---
	print("Merchant Prince is on, Guardian's Ultimatum stays off (Survivor wing untouched): has_merchant_prince=%s has_guardian_skill=%s (expected true, false)" % [
		player.has_merchant_prince, player.has_guardian_skill
	])
	print("Warband's cross-wing bonus is live: meta_warband_bonus=%.2f (expected 0.15)" % [player.meta_warband_bonus])

	# Reset the scratch save for whatever test runs next.
	save_data_script.save_data({"essence": 0, "upgrades": {}, "best_wave": 0})

	quit()
