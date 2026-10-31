extends SceneTree

# The Church's tree (SaveData.gd): roots, prerequisite chains, convergence nodes needing two branches, the cross-branch capstones, the
# lifetime-gated Worldwalker, and Otherworldly Power wanting every other upgrade; then what a few purchases do to a fresh Player.

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var save_data_script = load("res://scripts/SaveData.gd")
	save_data_script.save_lifetime_data({})
	save_data_script.save_data({"essence": 0, "upgrades": {}, "best_wave": 0})

	print("the tree is Legacy + Physical 16 + Economy 12 + Sustain 12 + Sorcery 5 + 3 cross-branch + Otherworldly Power (the doc of 2026-10-27, with Friends in High Places under Economy and Dense Muscles under Sustain): %d ids (expected 50)" % [save_data_script.UPGRADE_IDS.size()])

	var data: Dictionary = save_data_script.load_data()
	data.essence = 10000

	# --- roots have no prerequisites, always unlocked ---
	var roots: Array = []
	for id in save_data_script.UPGRADE_IDS:
		if save_data_script.UPGRADES[id].get("prereqs", []).is_empty() and not save_data_script.UPGRADES[id].has("requires_lifetime_flag") and not save_data_script.UPGRADES[id].has("requires_all"):
			roots.append(id)
	print("the only root is Legacy, the hub: %s (expected [legacy])" % [roots])

	print("every wing's first upgrade asks for Legacy and nothing else: %s (expected true)" % [["strength", "agility", "continual_growth", "painful_memories", "vigor", "coins", "stamina", "release_grudge", "smart_savage", "continual_learning"].all(func(id): return save_data_script.UPGRADES[id].prereqs.size() == 1 and save_data_script.UPGRADES[id].prereqs[0].id == "legacy")])
	print("Physical Training is locked before Legacy: %s (expected false)" % [save_data_script.is_upgrade_unlocked(data, "strength")])
	save_data_script.try_buy_upgrade(data, "legacy")

	# --- a node deeper in is locked until what it asks for is owned ---
	print("Sharp Mind (reflexes_unlock) starts locked: unlocked=%s (expected false)" % [save_data_script.is_upgrade_unlocked(data, "reflexes_unlock")])
	var blocked: bool = save_data_script.try_buy_upgrade(data, "reflexes_unlock")
	print("buying a locked node is rejected: %s (expected false), essence_unchanged=%s (expected true)" % [blocked, data.essence == 10000 - save_data_script.get_upgrade_cost("legacy", 0)])
	save_data_script.try_buy_upgrade(data, "strength")
	save_data_script.try_buy_upgrade(data, "agility")
	print("Sharp Mind needs ALL THREE of Physical Training, Endurance Training and Dense Muscles -- with two it stays locked: %s (expected false)" % [save_data_script.is_upgrade_unlocked(data, "reflexes_unlock")])
	save_data_script.try_buy_upgrade(data, "vigor")
	print("...and unlocks with all three: %s (expected true)" % [save_data_script.is_upgrade_unlocked(data, "reflexes_unlock")])
	save_data_script.try_buy_upgrade(data, "reflexes_unlock")

	# --- Friends in High Places is a CONVERGE point: Pure Spite AND Adrenaline ---
	for i in 5:
		save_data_script.try_buy_upgrade(data, "berserker_edge")
	print("Friends in High Places stays locked with only Pure Spite (a requirement means FULLY bought: all 5 levels): %s (expected false)" % [save_data_script.is_upgrade_unlocked(data, "battle_hardened")])
	for i in 2:
		save_data_script.try_buy_upgrade(data, "adrenaline")
	print("...still locked with Adrenaline at 2 of 3: %s (expected false)" % [save_data_script.is_upgrade_unlocked(data, "battle_hardened")])
	save_data_script.try_buy_upgrade(data, "adrenaline")
	print("...and unlocks once Adrenaline is at its top too: %s (expected true)" % [save_data_script.is_upgrade_unlocked(data, "battle_hardened")])

	# --- a capstone is a one-time purchase (max_level 1) ---
	var bought_capstone: bool = save_data_script.try_buy_upgrade(data, "battle_hardened")
	print("capstone purchase succeeds: %s (expected true), level=%d (expected 1)" % [bought_capstone, data.upgrades.battle_hardened])
	var bought_again: bool = save_data_script.try_buy_upgrade(data, "battle_hardened")
	print("capstone can't be bought a second time: %s (expected false), still level=%d (expected 1)" % [bought_again, data.upgrades.battle_hardened])

	# --- Leader's Instincts has two levels; Man's Best Friend wants the SECOND ---
	save_data_script.try_buy_upgrade(data, "pack_leader")
	print("Scholar wants Leader's Instincts at level 2 as well: %s (expected false)" % [save_data_script.is_upgrade_unlocked(data, "prodigy")])
	print("Man's Best Friend is locked with Leader's Instincts at level 1: %s (expected false)" % [save_data_script.is_upgrade_unlocked(data, "beastmaster")])
	save_data_script.try_buy_upgrade(data, "pack_leader")
	print("...and open at level 2: %s (expected true)" % [save_data_script.is_upgrade_unlocked(data, "beastmaster")])

	# --- the Economy wing is untouched by the Physical purchases ---
	print("Economy wing: Inheritance is independently unlocked (%s, expected true), Presence still locked (%s, expected false -- it wants all 5 levels of Inheritance)" % [
		save_data_script.is_upgrade_unlocked(data, "coins"), save_data_script.is_upgrade_unlocked(data, "intimidation")
	])

	# --- War Profiteer is a CROSS-BRANCH capstone: Friends in High Places (Physical) AND Merchant's Favour (Economy) ---
	print("War Profiteer stays locked with only the Physical side owned: %s (expected false)" % [save_data_script.is_upgrade_unlocked(data, "war_profiteer")])
	for id in ["coins", "coins", "coins", "coins", "coins", "intimidation", "luck", "haggling", "haggling", "haggling", "haggling", "haggling", "silver_muscles", "golden_touch"]:
		save_data_script.try_buy_upgrade(data, id)
	print("Merchant's Favour purchased: level=%d (expected 1)" % [data.upgrades.get("golden_touch", 0)])
	print("War Profiteer unlocks once BOTH sides are owned: %s (expected true)" % [save_data_script.is_upgrade_unlocked(data, "war_profiteer")])
	save_data_script.try_buy_upgrade(data, "war_profiteer")

	# --- Light Metal asks for RAGE and Merchant's Favour ---
	print("Light Metal (RAGE + Merchant's Favour) is locked without RAGE: %s (expected false)" % [save_data_script.is_upgrade_unlocked(data, "light_metal")])

	# --- Unbreakable Guard wants every other Sustain upgrade ---
	var sustain_prereqs: Array = save_data_script.UPGRADES.unbreakable_guard.prereqs.map(func(p): return p.id)
	print("Unbreakable Guard asks for all nine other Sustain upgrades (Innate Power moved to Sorcery): %d prerequisites (expected 9)" % [sustain_prereqs.size()])
	print("...so it is locked now: %s (expected false)" % [save_data_script.is_upgrade_unlocked(data, "unbreakable_guard")])

	# --- Worldwalker: the lifetime gate ---
	print("Worldwalker is locked until the game has been beaten: %s (expected false)" % [save_data_script.is_upgrade_unlocked(data, "worldwalker")])

	# --- Otherworldly Power: every other upgrade, each at its top level ---
	print("Otherworldly Power is locked while anything is missing: %s (expected false)" % [save_data_script.is_upgrade_unlocked(data, "otherworldly_power")])
	var full: Dictionary = {"essence": 99999, "upgrades": {}}
	for id in save_data_script.UPGRADE_IDS:
		if id != "otherworldly_power":
			full.upgrades[id] = int(save_data_script.UPGRADES[id].max_level)
	print("...and open once every one is at its max (Worldwalker included): %s (expected true)" % [save_data_script.is_upgrade_unlocked(full, "otherworldly_power")])
	full.upgrades["rage"] = 4
	print("...but not with just ONE level short: %s (expected false)" % [save_data_script.is_upgrade_unlocked(full, "otherworldly_power")])

	save_data_script.save_data(data)

	# --- the purchases actually apply to a fresh Player ---
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	var bonuses: Dictionary = save_data_script.get_applied_bonuses()

	# Dense Muscles no longer touches starting max_health at all -- it's stored as a level-up bonus instead (see
	# Player.gd:apply_bonus_stat), so max_health here should be exactly the base stat_vigor, untouched.
	print("Dense Muscles adds no flat starting max_health: max_health=%d (expected base stat_vigor %d)" % [player.max_health, player.stat_vigor])
	print("health matches max_health: health=%d (expected %d)" % [player.health, player.max_health])
	print("Dense Muscles' bonus is stored for level-up time: meta_levelup_bonus_vigor=%d (expected %d, +2)" % [player.meta_levelup_bonus_vigor, bonuses.vigor])
	print("Leader's Instincts (2 levels): max_party_slots=%d (expected 4)" % [player.max_party_slots])
	print("Pure Spite's passive is live on the equipped weapon: passive_double_hit_chance=%.2f (expected 0.05, 5 levels)" % [player.current_weapon.get("passive_double_hit_chance", 0.0)])
	print("Sharp Mind unlocks Reflexes, which starts at 0 until levelled: meta_reflexes_unlocked=%s (expected true), dodge=%.2f (expected 0.0), Adrenaline low-HP bonus=%.2f (expected 0.24, 3 levels * 0.08)" % [
		player.meta_reflexes_unlocked, player.meta_dodge_chance, player.meta_low_hp_damage_bonus_pct
	])
	print("Merchant's Favour is on, Guardian's Ultimatum is gone from the tree: has_merchant_prince=%s has_guardian_skill=%s (expected true, false)" % [player.has_merchant_prince, player.has_guardian_skill])
	print("War Profiteer is live: %.4f of the price per kill (expected 0.0020)" % [player.meta_war_profiteer_pct_per_kill])
	print("Silver Muscles is live: %d (expected 5)" % [player.meta_special_stamina_flat])

	# Reset the scratch save for whatever test runs next.
	save_data_script.save_data({"essence": 0, "upgrades": {}, "best_wave": 0})

	quit()
