extends RefCounted

# In-game Sandbox (debug) -- the logic half. SandboxPanel.gd is the screen.
#
# Lets you configure a whole build (level, stat points, weapon, gear, talismans,
# Astral upgrades, party) and an enemy squad, then drops you into a REAL tile
# battle through the real Main.gd code. Nothing it does is saved: while
# SaveData.sandbox_active is set, every SaveData read/write goes to an in-memory
# copy (see SaveData.gd), so Essence, upgrades, the Beastiary and lifetime stats
# on the real slots are never touched.

const PlayerScript := preload("res://scripts/Player.gd")
const WeaponsScript := preload("res://scripts/Weapons.gd")
const ArmorScript := preload("res://scripts/Armor.gd")
const ClothingScript := preload("res://scripts/Clothing.gd")
const ShieldsScript := preload("res://scripts/Shields.gd")
const PotionsScript := preload("res://scripts/Potions.gd")
const FoodsScript := preload("res://scripts/Foods.gd")
const EnchantmentsScript := preload("res://scripts/Enchantments.gd")
const TalismansScript := preload("res://scripts/Talismans.gd")
const SaveDataScript := preload("res://scripts/SaveData.gd")
const PartyRulesScript := preload("res://scripts/PartyRules.gd")

# The saved configuration (just the sandbox's own settings -- never a save slot). Test scripts
# get a scratch file so running the suite can't touch the real one.
static func config_path() -> String:
	for arg in OS.get_cmdline_args():
		if arg.contains("res://tools/test_"):
			return "user://test_sandbox_config.json"
	return "user://sandbox_config.json"

# Every enemy script the tile battle knows, by file. Display names (and the
# Wolf / Centaur variants) are read from the scripts themselves.
const ENEMY_FILES := [
	"Enemy", "Orc", "Archer", "Brute", "Shade", "Wolf", "Centaur", "FaeHut", "Fae", "Gnome",
	# the 5 minibosses, then the 6 full bosses
	"BlackDragonlet", "Treant", "IronConstruct", "LavaConstruct", "Voidwing",
	"Leviathan", "LizenWarband", "ElderOak", "WhiteDragon", "RedWyrm", "Archmage",
]
# The Nothingness boss rush's per-fight power (Main.NOTHINGNESS_POWER_TIERS).
const NOTHINGNESS_ORDER := ["Leviathan", "Lizen Warband", "Elder Oak", "White Dragon", "Red Wyrm", "Archmage"]

# Upgrades that actually change how a tile battle plays (the rest are shop /
# economy / run-start perks) -- the panel's "combat only" filter and "max combat".
const COMBAT_UPGRADES := ["strength", "agility", "vigor", "reflexes_unlock", "berserker_edge", "adrenaline", "dexterity_unlock",
	"battle_hardened", "pack_leader", "prodigy", "warlord", "beastmaster", "pack_bond", "riposte", "momentum", "rage", "hardened",
	"intimidation", "luck", "silver_tongue", "haggling", "warded_mind", "mental_mush", "smort_savage",
	"stamina", "resilience_unlock", "herbalism", "vampiric_grit",
	"vigilant_defense", "undying", "block_master", "second_breath", "favour", "last_stand", "shield_mastery", "unbreakable_guard",
	"warband", "battle_medic", "war_chest", "war_profiteer", "windfall"]

const SQUAD_PRESETS := [
	["Goblin pair", ["Goblin", "Goblin"]], ["Goblin trio", ["Goblin", "Goblin", "Goblin"]], ["Orc", ["Orc"]],
	["Orc + 2 Goblins", ["Orc", "Goblin", "Goblin"]], ["Brute + Orc", ["Brute", "Orc"]], ["Brute pair", ["Brute", "Brute"]],
	["Mage + 2 Goblins", ["Apprentice Mage", "Goblin", "Goblin"]], ["Wolf pack (3)", ["Wolf", "Wolf", "Wolf"]],
	["Gnome mob (5)", ["Gnome", "Gnome", "Gnome", "Gnome", "Gnome"]], ["Centaur pack", ["Centaur Lancer", "Centaur Archer", "Centaur Archer"]],
	["Shades (2)", ["Shade", "Shade"]],
]

static var _catalog: Array = []

# ---------------------------------------------------------------- config
static func default_config() -> Dictionary:
	return {
		"level": 10, "picks": {}, "upgrades": {}, "difficulty": "normal", "coins": 0, "waves_cleared": 0,
		"weapon": {"base": "club", "tier": "Fine", "material": "steel"}, "blacksmith": 0, "rune": "", "learn_all": true, "whisperer": [],
		"materials": {},
	"armor": "armor_rags", "armor_level": 0, "clothing": {"head": "", "body": "", "feet": ""}, "shield": "",
		"talismans": [], "ignore_slots": false, "arrows": {"flame": 0, "freeze": 0, "bomb": 0},
		"consumables": [{"id": "potion_health", "n": 2}], "party": [],
		"enemies": [{"name": "Goblin", "elite": false, "power_tier": 1.0}, {"name": "Goblin", "elite": false, "power_tier": 1.0}],
		"world": "plains", "seed": 12345,
		# Dodge / block timing minigames in sandbox battles: "setting" (follow the Settings menu), "random", "dodge", "block" or "off".
		"minigames": "setting",
		# The weapon attack timing minigame in sandbox battles: "setting" (follow the Settings menu), "on" or "off".
		"attack_minigame": "setting",
	}

# Overlays a saved/partial config onto the defaults (and fixes JSON's float ints).
static func merged_config(saved: Dictionary) -> Dictionary:
	var cfg := default_config()
	for key in saved:
		if cfg.has(key):
			cfg[key] = saved[key]
	return cfg

static func load_config() -> Dictionary:
	if not FileAccess.file_exists(config_path()):
		return default_config()
	var f := FileAccess.open(config_path(), FileAccess.READ)
	if f == null:
		return default_config()
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return default_config()
	return merged_config(parsed)

static func save_config(cfg: Dictionary) -> void:
	var f := FileAccess.open(config_path(), FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(cfg))
	f.close()

# ---------------------------------------------------------------- lookups
static func find_in(arr: Array, key: String, value) -> Dictionary:
	for item in arr:
		if item[key] == value:
			return item
	return {}

static func weapon_bases() -> Array:
	var out := [WeaponsScript.CLUB]
	out.append_array(WeaponsScript.UPGRADABLE_TYPES)
	return out

# What a party member can be handed: everything you can use, plus the party-only weapons.
static func party_weapon_bases() -> Array:
	var out := [WeaponsScript.CLUB]
	out.append_array(WeaponsScript.all_base_types())
	return out

static func build_weapon(sel: Dictionary) -> Dictionary:
	if sel.get("base", "club") == "club":
		return WeaponsScript.CLUB.duplicate(true)
	var base: Dictionary = find_in(WeaponsScript.all_base_types(), "id", sel.base)
	var tier: Dictionary = find_in(WeaponsScript.TIERS, "tier_name", sel.get("tier", "Fine"))
	if sel.get("tier", "") == "Mythic" and WeaponsScript.MYTHIC_WEAPONS.has(base.id):
		return WeaponsScript._build_mythic_variant(base, tier)
	var material: Dictionary = find_in(WeaponsScript.MATERIALS, "id", sel.get("material", "steel"))
	return WeaponsScript._build_tiered_variant(base, tier, material)

static func enemy_catalog() -> Array:
	if not _catalog.is_empty():
		return _catalog
	for file in ENEMY_FILES:
		var path := "res://scripts/%s.gd" % file
		var script: Script = load(path)
		var variants := [{}]
		if file == "Wolf":
			variants = [{"is_traitor": false}, {"is_traitor": true}]
		elif file == "Centaur":
			variants = [{"has_bow": false}, {"has_bow": true}]
		var constants: Dictionary = script.get_script_constant_map()
		for props in variants:
			var inst = script.new()
			for key in props:
				inst.set(key, props[key])
			var entry := {"name": inst.get_display_name(), "path": path, "props": props, "hp": int(constants.get("MAX_HEALTH", 1)),
				"dmg": int(inst.get_contact_damage()), "xp": int(constants.get("XP_REWARD", 0))}
			inst.free()
			_catalog.append(entry)
	return _catalog

static func enemy_names() -> Array:
	var out := []
	for e in enemy_catalog():
		out.append(e.name)
	return out

static func is_boss(main, enemy_name: String) -> bool:
	return bool(main.ENEMY_TRAITS.get(enemy_name, {}).get("is_boss_tier", false))

static func pickable_stats(player) -> Array:
	var out := ["strength", "vigor", "agility", "might", "intimidation"]
	if player.meta_resilience_unlocked:
		out.append("resilience")
	if player.meta_reflexes_unlocked:
		out.append("reflexes")
	if player.meta_dexterity_unlocked:
		out.append("dexterity")
	if player.meta_fortitude_unlocked:
		out.append("fortitude")
	return out

# ---------------------------------------------------------------- applying a build
# Rebuilds the live player from `cfg` from scratch (idempotent -- safe to call on
# every edit for the panel's previews, and again before every battle).
static func apply_build(main, cfg: Dictionary) -> void:
	var p = main.player
	var upgrades := {}
	for id in cfg.upgrades:
		if SaveDataScript.UPGRADES.has(id) and int(cfg.upgrades[id]) > 0:
			upgrades[id] = int(cfg.upgrades[id])
	SaveDataScript.sandbox_data = {"essence": 0, "upgrades": upgrades, "best_wave": 0, "difficulty": str(cfg.difficulty)}
	var bonuses: Dictionary = SaveDataScript.get_applied_bonuses()
	p.max_party_slots = PlayerScript.BASE_PARTY_SLOTS
	p._refresh_meta_passives(bonuses)
	p.difficulty_mult = SaveDataScript.get_difficulty_mult(str(cfg.difficulty))
	p.difficulty_id = str(cfg.difficulty)

	# stats: starting values, +1 to each core stat per level-up, then the placed bonus points
	p.stat_intimidation = 0
	p.stat_strength = 1
	p.stat_vigor = 20
	p.stat_agility = PlayerScript.AGILITY_START
	p.stat_might = 0
	p.stat_resilience = 0
	p.stat_reflexes = 0
	p.stat_dexterity = 0
	p.stat_fortitude = 0
	p.level = clampi(int(cfg.level), 1, PlayerScript.MAX_LEVEL)
	p.xp = 0
	p.xp_to_next = 0 if p.level >= PlayerScript.MAX_LEVEL else PlayerScript.XP_BASE + PlayerScript.XP_PER_LEVEL * p.level
	p.awaiting_bonus = false
	for l in range(2, p.level + 1):
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
		if p.meta_fortitude_unlocked:
			p.stat_fortitude += 1 + p.meta_fortitude_passive_bonus
	var allowed_picks: int = p.level - 1
	for stat in cfg.picks:
		for n in int(cfg.picks[stat]):
			if allowed_picks <= 0:
				break
			p.apply_bonus_stat(stat)
			allowed_picks -= 1
	p.hardened_hp_bonus = p.meta_hardened_hp_per_wave * int(cfg.waves_cleared)
	p.max_stamina = PlayerScript.MAX_STAMINA + int(bonuses.get("stamina", 0))
	p._base_max_stamina = p.max_stamina
	p.coins = int(cfg.coins)
	p.phoenix_used = false
	p.second_chance_used_this_battle = false

	# gear
	var armor: Dictionary = find_in(ArmorScript.TIERS, "id", cfg.armor)
	if armor.is_empty():
		armor = ArmorScript.TIERS[0]
	p.equipped_armor = armor
	p.owned_armor = {armor.id: true}
	p.armor_upgrade_levels = {}
	p.armor_upgrade_levels[armor.id] = int(cfg.armor_level) if armor.get("metal", false) else 0
	p.materials = {}
	for material_id in cfg.get("materials", {}):
		p.materials[str(material_id)] = int(cfg.materials[material_id])
	p.equipped_clothing = {"head": str(cfg.clothing.get("head", "")), "body": str(cfg.clothing.get("body", "")), "feet": str(cfg.clothing.get("feet", ""))}
	var shield_id: String = str(cfg.shield)
	p.equipped_shield = ShieldsScript.SHIELDS[shield_id].duplicate(true) if ShieldsScript.SHIELDS.has(shield_id) else {}

	# items
	p.potion_queue = []
	for entry in cfg.consumables:
		for i in int(entry.n):
			p.potion_queue.append(str(entry.id))
	p.healing_items = p.potion_queue.size()
	p.owned_arrows = {"flame": int(cfg.arrows.get("flame", 0)), "freeze": int(cfg.arrows.get("freeze", 0)), "bomb": int(cfg.arrows.get("bomb", 0))}

	# talismans (no slot check here -- the panel enforces the limit unless told to ignore it)
	p.equipped_talismans = []
	p.owned_talismans = {}
	var slot_cap: int = 99 if bool(cfg.get("ignore_slots", false)) else TalismansScript.slots_for_level(p.level)
	for id in cfg.talismans:
		if p.equipped_talismans.size() >= slot_cap:
			break
		if not TalismansScript.get_talisman(str(id)).is_empty():
			p.equipped_talismans.append(str(id))
			p.owned_talismans[str(id)] = true
	p.weapon_whisperer_specials = []
	for sid in cfg.whisperer:
		if str(sid) != "" and p.weapon_whisperer_specials.size() < 3:
			p.weapon_whisperer_specials.append(str(sid))
	p._rebuild_talisman_cache()
	# Max stamina counts talismans and the worn armour (Cinder Mail's heat).
	p.max_stamina = p._base_max_stamina + int(p.talisman_bonus("max_stamina")) + p.armor_max_stamina_bonus()
	p.stamina = mini(p.stamina, p.max_stamina)

	# weapon
	p.learned_specials = {}
	if bool(cfg.learn_all):
		p.learn_all_specials()
	var weapon := build_weapon(cfg.weapon)
	p.owned_weapons = {weapon.id: true}
	p.weapon_upgrade_levels = {}
	p.weapon_upgrade_levels[weapon.id] = int(cfg.blacksmith)
	p.weapon_enchantments = {}
	if str(cfg.rune) != "" and weapon.id != "club":
		p.weapon_enchantments[weapon.id] = str(cfg.rune)
	p.current_weapon_base = weapon
	p._recalc_stats()
	p.health = p.max_health
	p._equip_weapon(weapon)

	# party: the Astral-unlocked companions first (as a real run does), then the chosen members
	p.party_members = []
	p.party = []
	if bonuses.get("battle_hardened", 0) > 0:
		p.party_members.append({"name": "Knight", "dmg_mult": 0.75})
	if bonuses.get("beastmaster", 0) > 0:
		p.recruit("wolf")
	for entry in cfg.party:
		var member = p.recruit(str(entry.kind))
		if member == null or not member.levels():
			continue
		for i in range(int(entry.level) - 1):
			member._level_up()
		var picks: Dictionary = entry.get("picks", {})
		for stat in picks:
			for n in int(picks[stat]):
				member.spend_pick(str(stat))
		_apply_party_gear(p, member, entry)
		# A chosen loadout (three special ids, "" = empty); without one the member keeps its default.
		if entry.has("specials"):
			var pool_ids: Array = main.member_special_pool(member).map(func(e): return str(e.special.get("id", "")))
			for slot in PartyRulesScript.SPECIAL_SLOTS:
				var chosen: Array = entry.specials
				member.set_loadout_slot(slot, str(chosen[slot]) if slot < chosen.size() else "", pool_ids)

	# fresh battle-scoped state
	p.berserk_turns_remaining = 0
	p.stealth_turns_remaining = 0
	p.potion_attack_turns = 0
	p.potion_resilience_turns = 0
	p.potion_energy_turns = 0
	p.pichaku_active = false
	p.disarmed_tile = Vector2i(-1, -1)
	p.shield_vengeance_active = false
	p.bloodmoon_stacks = 0
	p.bloodmoon_debuffed = false

# A member's sandbox gear: any weapon (the Staff included) and talismans, free of the ownership
# rules -- but still one holder per item, so a talisman you or an earlier member wears is skipped.
static func _apply_party_gear(p, member, entry: Dictionary) -> void:
	if not member.can_carry_gear():
		return
	var wsel: Dictionary = entry.get("weapon", {})
	if str(wsel.get("base", "")) != "":
		var weapon: Dictionary = build_weapon(wsel)
		if not weapon.is_empty():
			p.owned_weapons[weapon.id] = true
			if weapon.id == "club" or (p.weapon_holder(weapon.id) == null and p.current_weapon_base.get("id", "") != weapon.id):
				member.gear.weapon = weapon.id
	# Armour and shield: any, free of the ownership rules, but still one holder per item (the free
	# Buckler excepted), so one you or an earlier member already has is skipped.
	var armor_id: String = str(entry.get("armor", ""))
	if armor_id != "" and armor_id != "armor_rags" and not ArmorScript.find(armor_id).is_empty():
		p.owned_armor[armor_id] = true
		if str(p.equipped_armor.get("id", "")) != armor_id and p.armor_holder(armor_id) == null:
			member.gear.armor = armor_id
	var shield_id: String = str(entry.get("shield", ""))
	if shield_id != "" and ShieldsScript.SHIELDS.has(shield_id):
		p.owned_shields[shield_id] = true
		if p._shield_is_free(shield_id) or (str(p.equipped_shield.get("id", "")) != shield_id and p.shield_holder(shield_id) == null):
			member.gear.shield = shield_id
	member.gear.talismans = []
	for id in entry.get("talismans", []):
		if member.gear.talismans.size() >= member.talisman_slot_count():
			break
		if p.equipped_talismans.has(id) or p.talisman_holder(str(id)) != null:
			continue
		member.gear.talismans.append(str(id))

# ---------------------------------------------------------------- the squad
static func world_index(main, world_id: String) -> int:
	for i in main.WORLDS.size():
		if main.WORLDS[i].id == world_id:
			return i
	return 0

# Spawns the (parked, non-processing) enemy nodes a battle squad is made of.
static func build_squad(main, cfg: Dictionary) -> Array:
	var squad := []
	for entry in cfg.enemies:
		var found := {}
		for e in enemy_catalog():
			if e.name == entry.name:
				found = e
				break
		if found.is_empty():
			continue
		var node = load(found.path).new()
		for key in found.props:
			node.set(key, found.props[key])
		node.is_elite = bool(entry.get("elite", false))
		var tier := float(entry.get("power_tier", 1.0))
		if not is_equal_approx(tier, 1.0):
			node.set_meta("sandbox_power_tier", tier)
		main.add_child(node)
		node.set_physics_process(false)
		node.set_process(false)
		node.died.connect(main._on_enemy_died.bind(node.get_display_name()))
		main.enemies_alive += 1
		squad.append(node)
	return squad

# Frees every enemy node left over from a sandbox battle (a flee leaves them alive).
static func clear_enemies(main) -> void:
	for node in main.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node):
			node.queue_free()
	main.enemies_alive = 0

# ---------------------------------------------------------------- summary text for the panel
static func summary(main, cfg: Dictionary) -> String:
	var p = main.player
	var foes := []
	for e in cfg.enemies:
		foes.append("%s%s" % [e.name, "*" if e.get("elite", false) else ""])
	return "Lv %d | %s | %s | %d HP / %d ATK | %d talismans | %d allies | vs %s" % [
		p.level, p.current_weapon.get("name", "?"), p.equipped_armor.get("name", "?"), p.max_health, p.attack_damage,
		p.equipped_talismans.size(), p.party_members.size() + p.party.size(), ", ".join(foes) if not foes.is_empty() else "nothing",
	]
