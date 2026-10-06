extends SceneTree

# Fidelity check for the standalone battle simulator (tools/battle_sim/).
# Generates a few hundred random builds / hits / incoming-damage scenarios, runs
# them through the REAL game code (Player.gd + Main.gd) and writes both the inputs
# and the game's answers to tools/battle_sim/parity_data.js. The simulator's
# self-test replays the same inputs through its JS port and diffs the answers.
#   Godot --headless --path . --script res://tools/export_battle_sim_parity.gd
#   bash tools/battle_sim/build.sh   # then open tools/battle_sim/selftest.html

const OUT_PATH := "res://tools/battle_sim/parity_data.js"
const CASES_STATS := 160
const CASES_HIT := 420
const CASES_INCOMING := 160

# Talismans whose effect on a single hit is random (can't be compared exactly).
const RANDOM_HIT_TALISMANS := ["chaos_shard", "duelists_coin", "iron_will_band"]

var rng := RandomNumberGenerator.new()
var main
var player

func _pick(arr: Array):
	return arr[rng.randi() % arr.size()]

func _init() -> void:
	rng.seed = 20261003
	seed(20261003)
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	player = main.player
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	var cases := []
	for i in CASES_STATS:
		var b := _random_build(false)
		_apply_build(b)
		cases.append({"kind": "stats", "build": b, "expect": _read_stats()})
	for i in CASES_HIT:
		cases.append(_hit_case())
	for i in CASES_INCOMING:
		cases.append(_incoming_case())
	for i in CASES_ENEMY:
		var ec := _enemy_turn_case()
		if ec.units.is_empty():
			continue
		ec["expect"] = await _run_enemy_turn_case(ec)
		cases.append(ec)
	for i in CASES_ACTION:
		var ac := _player_action_case()
		if ac.units.is_empty():
			continue
		ac["expect"] = await _run_player_action_case(ac)
		cases.append(ac)

	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	f.store_string("const PARITY = " + JSON.stringify(cases) + ";\n")
	f.close()
	print("export_battle_sim_parity: wrote %d cases to %s" % [cases.size(), ProjectSettings.globalize_path(OUT_PATH)])
	quit()

# ---------------------------------------------------------------- builds
func _random_build(for_hit: bool) -> Dictionary:
	var level: int = 1 + rng.randi() % 60
	var core := ["strength", "vigor", "agility", "might", "intimidation"]
	var picks := {}
	for l in range(1, level):
		var s: String = _pick(core)
		picks[s] = int(picks.get(s, 0)) + 1
	var upgrades := {}
	for id in SaveData.UPGRADE_IDS:
		if for_hit and id in ["dexterity_unlock", "block_master", "favour"]:
			continue
		if rng.randf() < 0.3:
			var mx: int = int(SaveData.UPGRADES[id].get("max_level", 4))
			upgrades[id] = rng.randi() % (mx + 1)
	var bases := [Weapons.CLUB]
	bases.append_array(Weapons.UPGRADABLE_TYPES)
	var base: Dictionary = _pick(bases)
	var tier: String = _pick(Weapons.TIERS).tier_name
	var material: String = _pick(Weapons.MATERIALS).id
	var tal := []
	var tal_count: int = rng.randi() % 5
	for k in tal_count:
		var t: String = _pick(Talismans.ITEMS).id
		if for_hit and t in RANDOM_HIT_TALISMANS:
			continue
		if not tal.has(t):
			tal.append(t)
	var armor: Dictionary = _pick(Armor.TIERS)
	var clothing := {"head": _pick(["", "cloth_cap", "cloth_hood", "cloth_pelt_hood"]), "body": _pick(["", "cloth_tunic", "cloth_cloak"]), "feet": _pick(["", "cloth_boots", "cloth_trail_boots"])}
	return {
		"level": level, "picks": picks, "upgrades": upgrades, "waves_cleared": rng.randi() % 10, "coins": rng.randi() % 300,
		"weapon": {"base": base.id, "tier": tier, "material": material}, "blacksmith": rng.randi() % 6,
		"rune": _pick(["", "", "ember", "leech", "tempest", "warding"]),
		"talismans": tal, "armor": armor.id, "armor_level": rng.randi() % 4, "clothing": clothing,
		"shield": _pick(["", "shield_buckler", "shield_heavy", "shield_bulwark", "shield_phantom", "shield_brawler"]),
	}

func _find(arr: Array, key: String, value):
	for item in arr:
		if item[key] == value:
			return item
	return {}

func _build_weapon(sel: Dictionary) -> Dictionary:
	if sel.base == "club":
		return Weapons.CLUB.duplicate(true)
	var base: Dictionary = _find(Weapons.UPGRADABLE_TYPES, "id", sel.base)
	var tier: Dictionary = _find(Weapons.TIERS, "tier_name", sel.tier)
	if sel.tier == "Mythic" and Weapons.MYTHIC_WEAPONS.has(base.id):
		return Weapons._build_mythic_variant(base, tier)
	return Weapons._build_tiered_variant(base, tier, _find(Weapons.MATERIALS, "id", sel.material))

func _apply_build(b: Dictionary) -> void:
	var p = player
	p.stat_intimidation = 0
	p.stat_strength = 1
	p.stat_vigor = 20
	p.stat_agility = PlayerScript().AGILITY_START
	p.stat_might = 0
	p.stat_resilience = 0
	p.stat_reflexes = 0
	p.stat_dexterity = 0
	p.level = 1
	p.hardened_hp_bonus = 0
	p.equipped_talismans = []
	p.owned_talismans = {}
	p.bloodmoon_stacks = 0
	p.bloodmoon_debuffed = false
	p.phoenix_used = false
	p.second_chance_used_this_battle = false
	var bonuses := {}
	for id in SaveData.UPGRADE_IDS:
		bonuses[id] = SaveData.UPGRADES[id].stat_bonus * int(b.upgrades.get(id, 0))
	p._refresh_meta_passives(bonuses)
	for l in range(2, int(b.level) + 1):
		p.level += 1
		p.stat_intimidation += 1
		p.stat_strength += 1
		p.stat_vigor += 1
		p.stat_agility += 1
		p.stat_might += 1
		if p.meta_resilience_unlocked:
			p.stat_resilience += 1
		if p.meta_reflexes_unlocked:
			p.stat_reflexes += 1
		if p.meta_dexterity_unlocked:
			p.stat_dexterity += 1
	for s in b.picks:
		for n in int(b.picks[s]):
			p.apply_bonus_stat(s)
	p.hardened_hp_bonus = p.meta_hardened_hp_per_wave * int(b.waves_cleared)
	p.max_stamina = 100 + int(bonuses.get("stamina", 0))
	p._base_max_stamina = p.max_stamina
	p.coins = int(b.coins)
	var armor: Dictionary = _find(Armor.TIERS, "id", b.armor)
	p.equipped_armor = armor
	p.armor_upgrade_levels = {}
	p.armor_upgrade_levels[armor.id] = int(b.armor_level) if armor.get("metal", false) else 0
	p.equipped_clothing = b.clothing.duplicate()
	p.equipped_shield = Shields.SHIELDS[b.shield].duplicate(true) if b.shield != "" else {}
	p.equipped_talismans = b.talismans.duplicate()
	p._rebuild_talisman_cache()
	p._recalc_stats()
	p.health = p.max_health
	p.learn_all_specials()
	var weapon := _build_weapon(b.weapon)
	p.weapon_upgrade_levels = {}
	p.weapon_upgrade_levels[weapon.id] = int(b.blacksmith)
	p.weapon_enchantments = {}
	if b.rune != "" and weapon.id != "club":
		p.weapon_enchantments[weapon.id] = b.rune
	p._equip_weapon(weapon)
	# fresh battle-scoped state
	p.berserk_turns_remaining = 0
	p.potion_attack_turns = 0
	p.potion_resilience_turns = 0
	p.pichaku_active = false
	p.stealth_turns_remaining = 0
	p.shield_vengeance_active = false
	main.player_burning = false
	main.player_blind_turns = 0

func PlayerScript():
	return load("res://scripts/Player.gd")

func _weapon_summary(w: Dictionary) -> Dictionary:
	var out := {"damage_mult": w.damage_mult, "break_chance": w.get("break_chance", 0.0), "specials": []}
	for sp in w.get("specials", []):
		out.specials.append({"id": sp.id, "stamina_cost": sp.stamina_cost})
	for k in w:
		if str(k).begins_with("passive_"):
			out[k] = w[k]
	return out

func _read_stats() -> Dictionary:
	var p = player
	return {
		"max_health": p.max_health, "attack_damage": p.attack_damage, "max_stamina": p.max_stamina,
		"stat_might": p.stat_might, "stat_intimidation": p.stat_intimidation, "stat_agility": p.stat_agility,
		"dodge": p.dodge_chance_total(), "crit": p.crit_chance_total(), "armor_dr": p.armor_damage_reduction(),
		"resilience": p.resilience_reduction, "move_range": main._battle_player_move_range(),
		"hp_regen": p.hp_regen_per_turn(), "stamina_regen": p.stamina_regen_per_turn(), "block_heal": p.block_heal_amount(),
		"luck": p.total_luck(), "low_hp_bonus": p.low_hp_damage_bonus_total(), "crit_mult": p.crit_damage_mult(),
		"shield_block": p.shield_block_chance(), "shield_threshold": p.shield_defend_threshold_bonus(),
		"shield_penalty": p.shield_damage_penalty_pct(), "shield_dr": p.shield_damage_reduction_pct(),
		"shield_push_immune": p.shield_push_immune(), "party_capacity": p.party_capacity(),
		"miss_mastered": p.miss_chance_for(p.current_weapon),
		"weapon": _weapon_summary(p.current_weapon),
	}

# ---------------------------------------------------------------- hits
func _hit_case() -> Dictionary:
	var b := _random_build(true)
	if b.weapon.tier == "Mythic" and b.weapon.base in ["battle_axe", "spear"]:
		b.weapon.tier = "Legendary"
	_apply_build(b)
	var w: Dictionary = player.current_weapon
	var actions := [{"name": "Attack", "effect": "", "dmg_mult": 1.0}, {"name": "Heavy", "effect": "", "dmg_mult": 1.75}]
	var skip := ["bleed_or_crit", "target_practice", "execution", "wide_cleave", "diamonds", "pichaku"]
	for sp in w.get("specials", []):
		if not (sp.effect in skip):
			actions.append({"name": sp.name, "effect": sp.effect, "dmg_mult": sp.get("split_dmg_mult", sp.dmg_mult)})
	var action: Dictionary = _pick(actions)
	var hp_pool := [30, 120, 500, 4000]
	var enemy_names := ["Goblin", "Orc", "Brute", "Wolf", "Gnome", "Treant", "Elder Oak", "Iron Construct", "Archmage"]
	var ename: String = _pick(enemy_names)
	var enemy := {
		"name": ename, "max_hp": _pick(hp_pool), "armored": rng.randf() < 0.4, "frozen": rng.randi() % 3 == 0, "vulnerable": rng.randi() % 4 == 0,
		"rock": rng.randf() < 0.35,
	}
	enemy.hp = enemy.max_hp if rng.randf() < 0.5 else maxi(2, int(enemy.max_hp * rng.randf_range(0.05, 1.0)))
	var state := {
		"health_frac": _pick([1.0, 0.5, 0.2, 0.1]), "attack_potion": rng.randi() % 4 == 0, "berserk": rng.randi() % 4 == 0,
		"pichaku": rng.randi() % 5 == 0, "stealth": rng.randi() % 5 == 0, "first_used": rng.randf() < 0.6,
		"momentum": rng.randi() % 4, "chain": rng.randi() % 3, "burning": rng.randi() % 8 == 0, "bloodmoon": rng.randi() % 4,
		"distance": 1 + rng.randi() % 4,
	}
	var out := _run_hit(b, action, enemy, state)
	# a kill triggers XP/loot/level-up side effects in the real game that the harness does not model -- retry with a sturdier target
	var tries := 0
	while out.killed and tries < 6:
		enemy.max_hp = int(enemy.max_hp) * 6
		enemy.hp = int(enemy.hp) * 6
		out = _run_hit(b, action, enemy, state)
		tries += 1
	out.erase("killed")
	return {"kind": "hit", "build": b, "action": action, "enemy": enemy, "state": state, "expect": out}

func _run_hit(b: Dictionary, action: Dictionary, enemy: Dictionary, st: Dictionary) -> Dictionary:
	var p = player
	_apply_build(b)
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_allies = []
	main.battle_player_tile = Vector2i(2, 2)
	var etile := Vector2i(2 + int(st.distance), 2)
	if enemy.rock:
		main.battle_terrain[etile + Vector2i(0, -1)] = {"type": "rock"}
	main.battle_first_attack_used = st.first_used
	main.battle_momentum_stacks = st.momentum
	main.battle_momentum_chain_stacks = st.chain
	main.player_burning = st.burning
	main.player_blind_turns = 0
	p.health = maxi(1, int(round(p.max_health * float(st.health_frac))))
	p.potion_attack_turns = 2 if st.attack_potion else 0
	p.berserk_turns_remaining = 2 if st.berserk else 0
	p.pichaku_active = st.pichaku
	p.stealth_turns_remaining = 2 if st.stealth else 0
	if p.talisman_bonus("bloodmoon_fang") > 0.0:
		p.bloodmoon_stacks = int(st.bloodmoon)
		p._recalc_stats()
	var traits: Dictionary = main.ENEMY_TRAITS.get(enemy.name, {})
	var unit := {
		"ref": null, "tile": etile, "hp": int(enemy.hp), "max_hp": int(enemy.max_hp), "move_range": 2, "damage": 1, "name": enemy.name,
		"winding_up": false, "stunned": false, "size": traits.get("size", 1), "attack_range": 1, "is_elite": false,
		"concussed_turns": 0, "frozen_turns": 2 if enemy.frozen else 0, "burning": false, "vulnerable_turns": 2 if enemy.vulnerable else 0,
		"aware_of_player": false, "armored": enemy.armored, "disarmed_tile": Vector2i(-1, -1),
	}
	main.battle_units = [unit]
	var hp_before: int = unit.hp
	var player_before: int = p.health
	main._apply_single_hit(0, float(action.dmg_mult), str(action.effect), p.current_weapon, "You", Vector2i(-1, -1), -1, false, -1.0)
	var res := {"dmg": hp_before - int(unit.hp), "player_delta": p.health - player_before, "killed": int(unit.hp) <= 0}
	main.battle_units = []
	main.in_battle = false
	main.battle_terrain.clear()
	return res

# ---------------------------------------------------------------- incoming
func _incoming_case() -> Dictionary:
	var b := _random_build(true)
	_apply_build(b)
	var c := {
		"dmg": 1 + rng.randi() % 80, "defending": rng.randf() < 0.5, "berserk": rng.randi() % 4 == 0, "resilience_potion": rng.randi() % 4 == 0,
		"rock": rng.randf() < 0.4, "ignore_cover": rng.randi() % 4 == 0, "health_frac": _pick([1.0, 0.7, 0.4, 0.1]),
	}
	var p = player
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(2, 2)
	if c.rock:
		main.battle_terrain[Vector2i(2, 1)] = {"type": "rock"}
	main.battle_player_defending = c.defending
	p.berserk_turns_remaining = 2 if c.berserk else 0
	p.potion_resilience_turns = 2 if c.resilience_potion else 0
	p.health = maxi(1, int(round(p.max_health * float(c.health_frac))))
	var reduced: int = main._apply_incoming_reductions(int(c.dmg), {"ignore_cover": c.ignore_cover})
	main.battle_player_defending = false
	main.battle_terrain.clear()
	p.berserk_turns_remaining = 0
	p.potion_resilience_turns = 0
	return {"kind": "incoming", "build": b, "scenario": c, "expect": {"reduced": reduced}}

# ---------------------------------------------------------------- enemy turns (AI parity)
const AI_ENEMIES := ["Goblin", "Brute", "Wolf", "Centaur Lancer", "Centaur Archer", "Gnome", "Leviathan",
	"Black Dragonlet", "Treant", "Elder Oak", "White Dragon", "Lava Construct", "Red Wyrm",
	"Archmage"]
const AI_TERRAIN := ["rock", "water", "ledge", "cliff", "ice", "embers", "poison_bog", "quicksand", "spring", "crumbling", "thicket", "caltrops", "rubble"]
const CASES_ENEMY := 220

func _enemy_turn_case() -> Dictionary:
	var big: bool = rng.randf() < 0.3
	var gw: int = 15 if big else 8
	var ptile := [rng.randi() % gw, rng.randi() % gw]
	var used := {}
	used[str(ptile)] = true
	var terrain := []
	var tcount: int = 3 + rng.randi() % (14 if big else 6)
	for i in tcount:
		var t := [rng.randi() % gw, rng.randi() % gw]
		if used.has(str(t)):
			continue
		used[str(t)] = true
		var kind: String = _pick(AI_TERRAIN)
		var dirs := [[0, -1], [0, 1], [-1, 0], [1, 0]]
		terrain.append({"x": t[0], "y": t[1], "type": kind, "dir": _pick(dirs), "push_dir": _pick(dirs)})
	var units := []
	var ucount: int = 1 + rng.randi() % 4
	for i in ucount:
		var name: String = _pick(AI_ENEMIES)
		var size: int = int(main.ENEMY_TRAITS.get(name, {}).get("size", 1))
		var t := [rng.randi() % (gw - size + 1), rng.randi() % (gw - size + 1)]
		var ok := true
		for dx in size:
			for dy in size:
				if used.has(str([t[0] + dx, t[1] + dy])):
					ok = false
		if not ok:
			continue
		for dx in size:
			for dy in size:
				used[str([t[0] + dx, t[1] + dy])] = true
		var hp: int = 20 + rng.randi() % 400
		units.append({"uid": units.size() + 1, "name": name, "tile": t, "hp": hp, "max_hp": hp + rng.randi() % 100, "damage": 1 + rng.randi() % 40,
			"winding": rng.randf() < 0.25, "move_range": int(main.ENEMY_TRAITS.get(name, {}).get("move_range", 2)), "armored": rng.randf() < 0.3,
			"buffed": rng.randf() < 0.1})
	var allies := []
	for i in rng.randi() % 3:
		var t := [rng.randi() % gw, rng.randi() % gw]
		if used.has(str(t)):
			continue
		used[str(t)] = true
		var hp: int = 30 + rng.randi() % 100
		allies.append({"tile": t, "hp": hp, "max_hp": hp, "name": "Ally%d" % i, "defense_pct": _pick([0.0, 5.0, 20.0]), "defending": rng.randf() < 0.3})
	var b := _random_build(true)
	b.upgrades = {}
	b.talismans = []
	b.shield = ""
	return {"kind": "enemy_turn", "build": b, "grid": gw, "player_tile": ptile, "terrain": terrain, "units": units, "allies": allies,
		"state": {"defending": rng.randf() < 0.4, "taunting": rng.randf() < 0.3, "health_frac": _pick([1.0, 0.5]), "stealth": rng.randi() % 6 == 0, "turns": 1 + rng.randi() % 3,
			"unaware_some": rng.randf() < 0.3 and not allies.is_empty()}}

func _vi(a: Array) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))

func _run_enemy_turn_case(c: Dictionary) -> Dictionary:
	var p = player
	_apply_build(c.build)
	p.level = 99
	p.health = maxi(1, int(round(p.max_health * float(c.state.health_frac))))
	main.in_battle = true
	main.BATTLE_GRID_W = int(c.grid)
	main.BATTLE_GRID_H = int(c.grid)
	main.battle_terrain.clear()
	for t in c.terrain:
		var entry := {"type": t.type}
		if t.type == "water":
			entry["push_dir"] = _vi(t.push_dir)
		if t.type == "ledge" or t.type == "cliff":
			entry["dir"] = _vi(t.dir)
		main.battle_terrain[Vector2i(int(t.x), int(t.y))] = entry
	main.battle_player_tile = _vi(c.player_tile)
	main.battle_player_defending = c.state.defending
	main.battle_player_taunting = c.state.taunting
	p.stealth_turns_remaining = 5 if c.state.stealth else 0
	main.player_poison_turns = 0
	main.player_burning = false
	main.player_bleed_turns = 0
	main.player_concussed_turns = 0
	main.player_blind_turns = 0
	main.battle_player_turns_to_skip = 0
	main.battle_allies = []
	for a in c.allies:
		main.battle_allies.append({"tile": _vi(a.tile), "hp": int(a.hp), "max_hp": int(a.max_hp), "name": a.name, "kind": "mercenary", "dmg_mult": 1.0,
			"defense_pct": float(a.defense_pct), "move_range": 2, "attack_range": 1, "defending": a.defending})
	main.battle_units = []
	var refs := {}
	var idx := 0
	for u in c.units:
		var e = load("res://scripts/Enemy.gd").new()
		main.add_child(e)
		e.died.connect(main._on_enemy_died)
		main.enemies_alive += 1
		var traits: Dictionary = main.ENEMY_TRAITS.get(u.name, {})
		var aware: bool = not (c.state.unaware_some and idx % 2 == 1)
		main.battle_units.append({
			"ref": e, "uid": u.uid, "tile": _vi(u.tile), "hp": int(u.hp), "max_hp": int(u.max_hp), "move_range": int(u.move_range), "damage": int(u.damage), "name": u.name,
			"winding_up": u.winding, "stunned": false, "size": traits.get("size", 1), "attack_range": traits.get("attack_range", 1), "is_elite": false,
			"concussed_turns": 0, "frozen_turns": 0, "burning": false, "vulnerable_turns": 0, "aware_of_player": aware, "armored": u.armored or traits.get("armored", false),
			"disarmed_tile": Vector2i(-1, -1), "buffed_dmg_turns": 2 if u.buffed else 0, "buffed_dmg_pct": 0.3,
		})
		refs[u.uid] = e
		idx += 1
	main.battle_target_index = 0
	for t in int(c.state.turns):
		if main.battle_units.is_empty() or not main.in_battle:
			break
		await main._process_enemy_turn()
		main.battle_player_defending = c.state.defending
		main.battle_player_taunting = c.state.taunting
	var out_units := {}
	for u in main.battle_units:
		out_units[str(int(u.uid))] = {"tile": [u.tile.x, u.tile.y], "hp": int(u.hp), "winding": bool(u.get("winding_up", false)), "stunned": bool(u.get("stunned", false))}
	var out_allies := []
	for a in main.battle_allies:
		out_allies.append(int(a.hp))
	var res := {"units": out_units, "player_hp": p.health, "allies": out_allies, "n_units": main.battle_units.size()}
	# cleanup
	for k in refs:
		if is_instance_valid(refs[k]):
			refs[k].queue_free()
	main.battle_units = []
	main.battle_allies = []
	main.battle_terrain.clear()
	main.in_battle = false
	main.game_over = false
	main.battle_player_defending = false
	main.battle_player_taunting = false
	return res

# ---------------------------------------------------------------- player actions (whole round)
const CASES_ACTION := 200
const ACTION_SKIP_EFFECTS := ["low_sweep", "bonk", "wrist_strike", "knife_throw", "target_practice", "diamonds", "bleed_or_crit", "devastating_slash", "pichaku"]
const ACTION_ENEMIES := ["Goblin", "Wolf", "Gnome", "Iron Construct", "Centaur Lancer", "Centaur Archer"]

func _player_action_case() -> Dictionary:
	var c := _enemy_turn_case()
	c.kind = "player_action"
	var b: Dictionary = c.build
	var bases := ["club", "spear", "greatsword", "hammer", "battle_axe", "dagger", "bow", "hand_picks"]
	b.weapon = {"base": _pick(bases), "tier": _pick(["Broken", "Worn", "Fine", "Masterwork", "Legendary", "Mythic"]), "material": _pick(["steel", "gold", "silver"])}
	if b.weapon.tier == "Mythic" and b.weapon.base in ["battle_axe", "spear", "hammer", "hand_picks"]:
		b.weapon.tier = "Legendary"
	b.rune = _pick(["", "", "leech", "tempest"])
	# keep the squad to enemies without random behaviour, and put the first one within reach
	var units := []
	for u in c.units:
		var name: String = _pick(ACTION_ENEMIES)
		if main.ENEMY_TRAITS.get(name, {}).get("quick_jab_chance", 0.0) > 0.0 or main.ENEMY_TRAITS.get(name, {}).get("inflicts_concussion", false):
			continue
		u.name = name
		u.move_range = int(main.ENEMY_TRAITS.get(name, {}).get("move_range", 2))
		units.append(u)
	if units.is_empty():
		c.units = []
		return c
	c.units = units
	c.state.unaware_some = false
	var first_tile: Array = units[0].tile
	var cand := [first_tile[0] - 1, first_tile[1]]
	if cand[0] >= 0:
		c.player_tile = cand
	_apply_build(b)
	var w: Dictionary = player.current_weapon
	var actions := [{"name": "Attack", "effect": "", "dmg_mult": 1.0, "stamina_cost": int(w.get("regular_attack_stamina_cost", 0)), "is_regular_attack": true},
		{"name": "Heavy Attack", "effect": "", "dmg_mult": 1.75, "stamina_cost": int(w.get("heavy_stamina_cost_override", 40))}]
	for sp in w.get("specials", []):
		if not (sp.effect in ACTION_SKIP_EFFECTS) and not sp.has("hit_count_min") and not sp.has("pass_count_min"):
			var a: Dictionary = sp.duplicate(true)
			a["stamina_cost"] = int(sp.stamina_cost)
			actions.append(a)
	c["action"] = _pick(actions)
	c.state["stamina"] = _pick([0, 20, 40, 60, 100, int(player.max_stamina)])
	c.state.turns = 1
	return c

func _run_player_action_case(c: Dictionary) -> Dictionary:
	var p = player
	_apply_build(c.build)
	p.level = 99
	p.health = maxi(1, int(round(p.max_health * float(c.state.health_frac))))
	p.stamina = int(c.state.stamina)
	p.exhausted = false
	main.in_battle = true
	main.BATTLE_GRID_W = int(c.grid)
	main.BATTLE_GRID_H = int(c.grid)
	main.battle_terrain.clear()
	for t in c.terrain:
		var entry := {"type": t.type}
		if t.type == "water":
			entry["push_dir"] = _vi(t.push_dir)
		if t.type == "ledge" or t.type == "cliff":
			entry["dir"] = _vi(t.dir)
		main.battle_terrain[Vector2i(int(t.x), int(t.y))] = entry
	main.battle_player_tile = _vi(c.player_tile)
	main.battle_player_defending = false
	main.battle_player_taunting = false
	main.battle_first_attack_used = false
	main.battle_momentum_stacks = 0
	main.player_poison_turns = 0
	main.player_burning = false
	main.player_bleed_turns = 0
	main.player_concussed_turns = 0
	main.player_blind_turns = 0
	main.battle_player_turns_to_skip = 0
	main.battle_allies = []
	main.battle_units = []
	var refs := {}
	for u in c.units:
		var e = load("res://scripts/Enemy.gd").new()
		main.add_child(e)
		e.died.connect(main._on_enemy_died)
		main.enemies_alive += 1
		var traits: Dictionary = main.ENEMY_TRAITS.get(u.name, {})
		main.battle_units.append({
			"ref": e, "uid": u.uid, "tile": _vi(u.tile), "hp": int(u.hp), "max_hp": int(u.max_hp), "move_range": int(u.move_range), "damage": int(u.damage), "name": u.name,
			"winding_up": u.winding, "stunned": false, "size": traits.get("size", 1), "attack_range": traits.get("attack_range", 1), "is_elite": false,
			"concussed_turns": 0, "frozen_turns": 0, "burning": false, "vulnerable_turns": 0, "aware_of_player": true, "armored": u.armored or traits.get("armored", false),
			"disarmed_tile": Vector2i(-1, -1), "buffed_dmg_turns": 0, "buffed_dmg_pct": 0.3,
		})
		refs[u.uid] = e
	main.battle_target_index = 0
	main.battle_turn = "player"
	await main._battle_perform_attack(c.action.duplicate(true))
	var out_units := {}
	for u in main.battle_units:
		out_units[str(int(u.uid))] = {"tile": [u.tile.x, u.tile.y], "hp": int(u.hp), "winding": bool(u.get("winding_up", false)), "stunned": bool(u.get("stunned", false))}
	var res := {"units": out_units, "player_hp": p.health, "stamina": p.stamina, "player_tile": [main.battle_player_tile.x, main.battle_player_tile.y],
		"skip": main.battle_player_turns_to_skip, "n_units": main.battle_units.size(), "in_battle": main.in_battle}
	for k in refs:
		if is_instance_valid(refs[k]):
			refs[k].queue_free()
	main.battle_units = []
	main.battle_allies = []
	main.battle_terrain.clear()
	main.in_battle = false
	main.game_over = false
	return res
