extends RefCounted

# The Debug menu's hands, part 1: everything it does to the hero, the inventory and the party. Each function takes the live Main,
# does its job through the game's OWN functions where one exists (Player.gain_xp, add_coins_flat, equip_ally_weapon...) and only
# touches a field where the game has no setter, and returns a result {ok, msg} that the menu shows in its log strip. The views
# (DebugPlayerView.gd and friends) only call these; so can a test, with no screen at all.
#
# New scripts avoid class_name (they are preloaded by path); other debug files reach this one as DebugActionsScript.

const WeaponsScript := preload("res://scripts/Weapons.gd")
const ArmorScript := preload("res://scripts/Armor.gd")
const ShieldsScript := preload("res://scripts/Shields.gd")
const ClothingScript := preload("res://scripts/Clothing.gd")
const TalismansScript := preload("res://scripts/Talismans.gd")
const PotionsScript := preload("res://scripts/Potions.gd")
const FoodsScript := preload("res://scripts/Foods.gd")
const MaterialsScript := preload("res://scripts/Materials.gd")
const EnchantmentsScript := preload("res://scripts/Enchantments.gd")
const BlacksmithScript := preload("res://scripts/Blacksmith.gd")
const PartyRulesScript := preload("res://scripts/PartyRules.gd")
const SandboxScript := preload("res://scripts/Sandbox.gd")
const SaveDataScript := preload("res://scripts/SaveData.gd")
const PlayerScript := preload("res://scripts/Player.gd")

# One big number: a hit multiplied by this kills anything (used by one-hit kills through the shrine-blessing slot).
const ONE_HIT_BONUS := 100000.0

static func ok(msg: String, extra: Dictionary = {}) -> Dictionary:
	var r := {"ok": true, "msg": msg}
	r.merge(extra, true)
	return r

static func fail(msg: String) -> Dictionary:
	return {"ok": false, "msg": msg}

static func player_of(main):
	return main.player if main != null else null

# ---------------------------------------------------------------------------------------------------------------------------
# PLAYER
# ---------------------------------------------------------------------------------------------------------------------------

# The hero's level-up stats, in the order the Stats screen lists them: [{id, name, abbr, locked}] for every stat the Player
# actually has (so a stat another worker adds to Player.gd shows up here without a change).
static func stat_rows(main) -> Array:
	var p = player_of(main)
	var out: Array = []
	var UIIconsScript := load("res://scripts/UIIcons.gd")
	for id in UIIconsScript.STAT_ORDER:
		if p.get("stat_" + str(id)) == null:
			continue
		var locked := false
		match str(id):
			"resilience": locked = not p.meta_resilience_unlocked
			"reflexes": locked = not p.meta_reflexes_unlocked
			"dexterity": locked = not p.meta_dexterity_unlocked
			"fortitude": locked = not p.meta_fortitude_unlocked
			"rage": locked = not p.meta_rage_unlocked
		out.append({"id": str(id), "name": UIIconsScript.stat_name(str(id)), "abbr": UIIconsScript.stat_abbr(str(id)), "locked": locked})
	return out

static func set_stat(main, stat_id: String, value: int) -> Dictionary:
	var p = player_of(main)
	var key := "stat_" + stat_id
	if p.get(key) == null:
		return fail("There is no stat called %s." % stat_id)
	var floor_value := 0
	if stat_id == "vigor":
		floor_value = 1
	elif stat_id == "agility":
		floor_value = 5
	p.set(key, maxi(floor_value, value))
	p._recalc_stats()
	return ok("%s is now %d." % [load("res://scripts/UIIcons.gd").stat_name(stat_id), int(p.get(key))])

# Agility is a walking speed in pixels a second (180 to start), shown everywhere as a small speed RATING (5 to start, +1 for every
# 5 px/s); the Debug menu speaks in the rating like the rest of the game does.
static func agility_rating(main) -> int:
	return 5 + int(player_of(main).stat_agility - PlayerScript.AGILITY_START) / PlayerScript.AGILITY_BONUS_PER_LEVEL

static func set_agility_rating(main, rating: int) -> Dictionary:
	rating = clampi(rating, 1, 99)
	var r := set_stat(main, "agility", PlayerScript.AGILITY_START + (rating - 5) * PlayerScript.AGILITY_BONUS_PER_LEVEL)
	r["msg"] = "Agility is now speed rating %d." % rating
	return r

# Puts every core stat back to its level-1 value, as a fresh hero has them.
static func _reset_core_stats(p) -> void:
	p.stat_intimidation = 0
	p.stat_strength = 1
	p.stat_vigor = 20
	p.stat_agility = PlayerScript.AGILITY_START
	p.stat_might = 0
	p.stat_resilience = 0
	p.stat_reflexes = 0
	p.stat_dexterity = 0
	p.stat_fortitude = 0
	p.stat_rage = 0

# Runs `call` with the level-up screen switched off (the hero's leveled_up signal is what opens it), then restores it.
static func _without_levelup_screen(main, call: Callable) -> void:
	var p = player_of(main)
	var handler := Callable(main, "_on_player_leveled_up")
	var was_connected: bool = p.leveled_up.is_connected(handler)
	if was_connected:
		p.leveled_up.disconnect(handler)
	call.call()
	if was_connected:
		p.leveled_up.connect(handler)

# Sets the hero's level through the game's own level-up (+1 to each stat per level), without the level-up picker. Going down
# starts the stats over and climbs again, so any stat picks made along the way are lost.
static func set_level(main, level: int) -> Dictionary:
	var p = player_of(main)
	level = clampi(level, 1, PlayerScript.MAX_LEVEL)
	if level == p.level:
		return ok("You are already level %d." % level)
	var lowered: bool = level < p.level
	_without_levelup_screen(main, func():
		if lowered:
			_reset_core_stats(p)
			p.level = 1
			p.xp_to_next = PlayerScript.XP_BASE + PlayerScript.XP_PER_LEVEL * p.level
		while p.level < level:
			p._level_up()
	)
	p.awaiting_bonus = false
	p.xp = 0
	p.xp_to_next = 0 if p.level >= PlayerScript.MAX_LEVEL else PlayerScript.XP_BASE + PlayerScript.XP_PER_LEVEL * p.level
	# fewer talisman slots at a lower level: the extras come off
	while p.equipped_talismans.size() > p.talisman_slots():
		p.unequip_talisman(str(p.equipped_talismans[p.equipped_talismans.size() - 1]))
	p._recalc_stats()
	if main.hud != null:
		main.hud.update_level(p.level)
		main.hud.update_xp(p.xp, p.xp_to_next)
	return ok("Level %d%s." % [p.level, " (stat picks reset)" if lowered else ""])

# XP the normal way: it can level you up, and then the level-up picker opens as usual.
static func give_xp(main, amount: int) -> Dictionary:
	var p = player_of(main)
	if p.level >= PlayerScript.MAX_LEVEL:
		return fail("Already at the top level.")
	var before: int = p.level
	p.gain_xp(maxi(0, amount))
	if main.hud != null:
		main.hud.update_level(p.level)
	var text := "+%d XP." % amount
	if p.level > before:
		text += " Level %d now" % p.level
		text += " - pick a stat when you close this menu." if bool(main.choosing_stat) else "."
	return ok(text)

static func heal_hero(main) -> Dictionary:
	var p = player_of(main)
	p.restore_health(p.max_health)
	p.reset_stamina()
	return ok("You are at full HP and stamina.")

static func set_health(main, value: int) -> Dictionary:
	var p = player_of(main)
	p.restore_health(clampi(value, 1, p.max_health))
	return ok("HP is now %d / %d." % [p.health, p.max_health])

static func set_stamina(main, value: int) -> Dictionary:
	var p = player_of(main)
	p.stamina = clampi(value, 0, p.max_stamina)
	p.exhausted = p.stamina <= 0
	p.stamina_changed.emit(p.stamina, p.max_stamina)
	return ok("Stamina is now %d / %d." % [p.stamina, p.max_stamina])

# Max HP the game's own way: the Hardened bonus (it also heals by the same amount).
static func add_max_hp(main, amount: int) -> Dictionary:
	var p = player_of(main)
	p.add_hardened_hp(amount)
	return ok("Max HP is now %d." % p.max_health)

static func set_coins(main, value: int) -> Dictionary:
	var p = player_of(main)
	value = maxi(0, value)
	if value >= p.coins:
		p.add_coins_flat(value - p.coins)
	else:
		p.try_spend_coins(p.coins - value)
	return ok("You have %d coins." % p.coins)

static func set_shards(main, value: int) -> Dictionary:
	var p = player_of(main)
	value = maxi(0, value)
	if value >= p.runic_shards:
		p.add_runic_shards(value - p.runic_shards)
	else:
		p.try_spend_runic_shards(p.runic_shards - value)
	return ok("You have %d runic shards." % p.runic_shards)

# Banked Essence is in the slot's save file (the Church's money), not in the run.
static func set_essence(main, value: int) -> Dictionary:
	var data: Dictionary = SaveDataScript.load_data()
	data["essence"] = maxi(0, value)
	SaveDataScript.save_data(data)
	if main != null and main.has_method("refresh_church_marker"):
		main.refresh_church_marker()
	return ok("Banked Essence is %d." % int(data.essence))

static func essence(_main) -> int:
	return int(SaveDataScript.load_data().get("essence", 0))

# --- cheats ---------------------------------------------------------------------------------------------------------------

static func set_god_mode(main, on: bool) -> Dictionary:
	player_of(main).debug_god_mode = on
	return ok("God mode on: nothing can hurt you." if on else "God mode off.")

static func set_infinite_stamina(main, on: bool) -> Dictionary:
	var p = player_of(main)
	p.debug_infinite_stamina = on
	if on:
		p.reset_stamina()
	return ok("Infinite stamina on." if on else "Infinite stamina off.")

# Every hit you land (and your party's) is multiplied far beyond anything's HP, through the game's temporary damage bonus
# (the Ancient Shrine's slot). The menu keeps it topped up every frame while it is on, since the shrine and the Wishing Well also
# write to that slot.
static func set_one_hit_kills(main, on: bool) -> Dictionary:
	var p = player_of(main)
	p.set_meta("debug_ohko", on)
	if on:
		p.temp_damage_bonus_pct = ONE_HIT_BONUS
	elif p.temp_damage_bonus_pct == ONE_HIT_BONUS:
		p.temp_damage_bonus_pct = 0.0
	return ok("One-hit kills on: any hit that lands destroys its target." if on else "One-hit kills off.")

static func one_hit_kills_on(main) -> bool:
	return bool(player_of(main).get_meta("debug_ohko", false))

# Every cheat back to normal (the menu does this itself when it is switched off).
static func reset_cheats(main) -> void:
	var p = player_of(main)
	p.debug_god_mode = false
	p.debug_infinite_stamina = false
	p.debug_speed_mult = 1.0
	p.debug_always_crit = false
	p.debug_enemies_pass = false
	p.miss_chance_override = 0.0 if OS.get_cmdline_args().has("--script") else -1.0   # as a fresh Player starts: the real miss chances (none under a test run)
	set_one_hit_kills(main, false)
	load("res://scripts/DebugProgress.gd").restore_engine(main.get_tree() if main.is_inside_tree() else null)

static func set_speed_mult(main, mult: float) -> Dictionary:
	var p = player_of(main)
	p.debug_speed_mult = clampf(mult, 0.1, 10.0)
	return ok("Walking speed x%s." % _fmt(p.debug_speed_mult))

static func _fmt(v: float) -> String:
	return ("%d" % int(v)) if is_equal_approx(v, round(v)) else ("%.2f" % v).rstrip("0").rstrip(".")

# ---------------------------------------------------------------------------------------------------------------------------
# ITEMS
# ---------------------------------------------------------------------------------------------------------------------------

# --- weapons ---

# A weapon built from its three parts: base id ("spear"), tier name ("Fine") and material id ("steel"). Mythic ignores the
# material (it is a fixed artifact); the Club has no variants at all.
static func build_weapon(base_id: String, tier_name: String, material_id: String) -> Dictionary:
	if base_id == "club":
		return WeaponsScript.CLUB.duplicate(true)
	return SandboxScript.build_weapon({"base": base_id, "tier": tier_name, "material": material_id})

# Every base weapon type there is, in the order the game lists them: the Club, then what you can wield, then the party-only Staff.
static func weapon_bases() -> Array:
	var out: Array = [WeaponsScript.CLUB]
	out.append_array(WeaponsScript.all_base_types())
	return out

static func give_weapon(main, base_id: String, tier_name: String, material_id: String, equip: bool) -> Dictionary:
	var p = player_of(main)
	var variant: Dictionary = build_weapon(base_id, tier_name, material_id)
	if variant.is_empty():
		return fail("Could not build that weapon.")
	p.grant_weapon(str(variant.id))
	var text := "Gave %s." % _weapon_label(variant)
	if equip:
		if WeaponsScript.is_ally_only(variant):
			text += " (A Staff is for party members; you cannot wield it.)"
		else:
			p._equip_weapon(variant)
			text += " Equipped."
			var need_might: int = int(variant.get("required_might", 0))
			var need_intimidation: int = int(variant.get("required_intimidation", 0))
			if need_might > p.stat_might or need_intimidation > p.stat_intimidation:
				text += " (The shop would want %d Might%s for it.)" % [need_might, " and %d Intimidation" % need_intimidation if need_intimidation > 0 else ""]
	return ok(text)

static func _weapon_label(variant: Dictionary) -> String:
	var parts: Array = []
	if str(variant.get("tier_name", "")) != "":
		parts.append(str(variant.tier_name))
	if str(variant.get("material_name", "")) != "":
		parts.append(str(variant.material_name))
	parts.append(str(variant.get("name", "weapon")) if str(variant.get("tier_name", "")) == "Mythic" else str(WeaponsScript.get_base_type(variant).get("name", variant.get("name", ""))))
	return " ".join(parts)

static func remove_weapon(main, weapon_id: String) -> Dictionary:
	var p = player_of(main)
	if weapon_id == "club":
		return fail("The Club is always yours.")
	if not p.owned_weapons.has(weapon_id):
		return fail("You do not have that weapon.")
	p.owned_weapons.erase(weapon_id)
	p.weapon_upgrade_levels.erase(weapon_id)
	p.weapon_enchantments.erase(weapon_id)
	for m in p.all_members():
		if m.weapon_id() == weapon_id:
			m.gear.weapon = ""
	if str(p.current_weapon_base.get("id", "")) == weapon_id:
		p._equip_weapon(WeaponsScript.CLUB)
	return ok("Removed %s." % weapon_id)

static func equip_weapon(main, weapon_id: String) -> Dictionary:
	var p = player_of(main)
	var variant: Dictionary = WeaponsScript.get_owned_variant(weapon_id)
	if variant.is_empty() or not p.owned_weapons.has(weapon_id):
		return fail("You do not have that weapon.")
	if WeaponsScript.is_ally_only(variant):
		return fail("A Staff is for party members.")
	p._equip_weapon(variant)
	return ok("Equipped %s." % _weapon_label(variant))

# Weapons you own, as full variants.
static func owned_weapon_variants(main) -> Array:
	var out: Array = []
	for id in player_of(main).owned_weapons:
		var v: Dictionary = WeaponsScript.get_owned_variant(str(id))
		if not v.is_empty():
			out.append(v)
	return out

# --- armour, shields, clothes, talismans ---

static func give_armor(main, armor_id: String, wear: bool) -> Dictionary:
	var p = player_of(main)
	var armor: Dictionary = ArmorScript.find(armor_id)
	if armor.is_empty():
		return fail("No such armour.")
	p.owned_armor[armor_id] = true
	if wear:
		p.try_buy_armor(armor)
	return ok("Gave %s%s." % [armor.name, " and put it on" if wear else ""])

static func remove_armor(main, armor_id: String) -> Dictionary:
	var p = player_of(main)
	if armor_id == "armor_rags":
		return fail("You cannot lose your rags.")
	if not p.owned_armor.has(armor_id):
		return fail("You do not have that armour.")
	p.owned_armor.erase(armor_id)
	p.armor_upgrade_levels.erase(armor_id)
	for m in p.all_members():
		if m.armor_id() == armor_id:
			m.gear.armor = ""
	if str(p.equipped_armor.get("id", "")) == armor_id:
		p.try_buy_armor(ArmorScript.find("armor_rags"))
	return ok("Removed %s." % str(ArmorScript.find(armor_id).get("name", armor_id)))

static func give_shield(main, shield_id: String, hold: bool) -> Dictionary:
	var p = player_of(main)
	if not ShieldsScript.SHIELDS.has(shield_id):
		return fail("No such shield.")
	p.owned_shields[shield_id] = true
	if hold:
		p.equip_shield(ShieldsScript.SHIELDS[shield_id])
	return ok("Gave %s%s." % [ShieldsScript.SHIELDS[shield_id].name, " and raised it" if hold else ""])

static func remove_shield(main, shield_id: String) -> Dictionary:
	var p = player_of(main)
	if not p.owned_shields.has(shield_id):
		return fail("You do not have that shield.")
	p.owned_shields.erase(shield_id)
	for m in p.all_members():
		if m.shield_id() == shield_id:
			m.gear.shield = ""
	if str(p.equipped_shield.get("id", "")) == shield_id:
		p.equip_shield({})
	return ok("Removed %s." % str(ShieldsScript.SHIELDS[shield_id].name))

static func give_clothing(main, piece_id: String, wear: bool) -> Dictionary:
	var p = player_of(main)
	var piece: Dictionary = ClothingScript.get_piece(piece_id)
	if piece.is_empty():
		return fail("No such clothing.")
	p.owned_clothing[piece_id] = true
	if wear:
		p.equip_clothing(piece_id)
	return ok("Gave %s%s." % [piece.name, " and put it on" if wear else ""])

static func remove_clothing(main, piece_id: String) -> Dictionary:
	var p = player_of(main)
	var piece: Dictionary = ClothingScript.get_piece(piece_id)
	if piece.is_empty() or not p.owned_clothing.has(piece_id):
		return fail("You do not have that.")
	p.owned_clothing.erase(piece_id)
	if str(p.equipped_clothing.get(piece.slot, "")) == piece_id:
		p.equipped_clothing[piece.slot] = ""
		p._rebuild_talisman_cache()
	return ok("Removed %s." % piece.name)

static func give_talisman(main, talisman_id: String, wear: bool) -> Dictionary:
	var p = player_of(main)
	var t: Dictionary = TalismansScript.get_talisman(talisman_id)
	if t.is_empty():
		return fail("No such talisman.")
	p.owned_talismans[talisman_id] = true
	var text := "Gave %s." % t.name
	if wear:
		if p.equipped_talismans.has(talisman_id):
			text += " Already worn."
		elif p.equip_talisman(talisman_id):
			text += " Worn."
		else:
			text += " (No free slot; free one up or raise your level.)"
	return ok(text)

static func remove_talisman(main, talisman_id: String) -> Dictionary:
	var p = player_of(main)
	if not p.owned_talismans.has(talisman_id):
		return fail("You do not have that talisman.")
	p.unequip_talisman(talisman_id)
	p.owned_talismans.erase(talisman_id)
	for m in p.all_members():
		m.gear.talismans.erase(talisman_id)
	return ok("Removed %s." % str(TalismansScript.get_talisman(talisman_id).get("name", talisman_id)))

static func give_all_talismans(main) -> Dictionary:
	var p = player_of(main)
	for item in TalismansScript.ITEMS:
		p.owned_talismans[str(item.id)] = true
	return ok("You now own all %d talismans." % TalismansScript.ITEMS.size())

# --- potions, food, arrows, materials ---

static func give_potion(main, id: String, count: int) -> Dictionary:
	var p = player_of(main)
	if p.get_consumable(id).is_empty():
		return fail("No such item.")
	for i in maxi(0, count):
		p.add_potion(id)
	return ok("Gave %d x %s." % [count, str(p.get_consumable(id).get("name", id))])

static func remove_potion(main, id: String, count: int) -> Dictionary:
	var p = player_of(main)
	var removed := 0
	for i in maxi(0, count):
		var at: int = p.potion_queue.find(id)
		if at < 0:
			break
		p.potion_queue.remove_at(at)
		removed += 1
	p.healing_items = p.potion_queue.size()
	p.items_changed.emit(p.healing_items)
	return ok("Removed %d x %s." % [removed, str(p.get_consumable(id).get("name", id))])

static func potion_count(main, id: String) -> int:
	return player_of(main).potion_queue.count(id)

static func give_arrows(main, kind: String, count: int) -> Dictionary:
	var p = player_of(main)
	if not p.owned_arrows.has(kind):
		return fail("No such arrow.")
	p.owned_arrows[kind] = maxi(0, int(p.owned_arrows[kind]) + count)
	if main.hud != null:
		main.hud.update_quiver(main._player_has_bow(), p.owned_arrows)
	return ok("%s: %d held." % [str(WeaponsScript.ARROW_TYPES[kind].name), int(p.owned_arrows[kind])])

static func give_material(main, id: String, count: int) -> Dictionary:
	var p = player_of(main)
	if not MaterialsScript.ITEMS.has(id):
		return fail("No such material.")
	var had: int = p.material_count(id)
	if count >= 0:
		p.add_material(id, count)
	else:
		p.materials[id] = maxi(0, had + count)
	return ok("%s: %d held." % [MaterialsScript.name_of(id), p.material_count(id)])

static func set_pelts(main, count: int) -> Dictionary:
	player_of(main).pelts = maxi(0, count)
	return ok("Pelts: %d." % player_of(main).pelts)

static func set_bait(main, count: int) -> Dictionary:
	player_of(main).bait = maxi(0, count)
	return ok("Bait: %d." % player_of(main).bait)

static func set_rod(main, rod_id: String, owned: bool) -> Dictionary:
	var p = player_of(main)
	var rod: Dictionary = load("res://scripts/FishingHole.gd").rod(rod_id)
	if str(rod.get("id", "")) != rod_id:
		return fail("No such rod.")
	if owned:
		p.owned_rods[rod_id] = true
	elif rod_id == "rod_driftwood":
		return fail("Everyone has the Driftwood Rod.")
	else:
		p.owned_rods.erase(rod_id)
	return ok("%s: %s." % [rod.name, "yours" if owned else "gone"])

# Every piece of a kind of gear at once: "armor", "shield", "clothing", "talisman" or "weapon" (every base x tier x material: a lot).
static func give_all(main, kind: String) -> Dictionary:
	var p = player_of(main)
	var n := 0
	match kind:
		"armor":
			for a in ArmorScript.TIERS:
				p.owned_armor[str(a.id)] = true
				n += 1
		"shield":
			for id in ShieldsScript.SHIELD_IDS:
				p.owned_shields[str(id)] = true
				n += 1
		"clothing":
			for piece in ClothingScript.PIECES:
				p.owned_clothing[str(piece.id)] = true
				n += 1
		"talisman":
			return give_all_talismans(main)
		_:
			return fail("Nothing to give for %s." % kind)
	return ok("You now own all %d." % n)

# Takes every piece of a kind of gear away (never what you cannot lose: the Club, the Jacket, the Buckler).
static func remove_all(main, kind: String) -> Dictionary:
	var p = player_of(main)
	var n := 0
	match kind:
		"weapon":
			for id in p.owned_weapons.keys():
				if str(id) != "club":
					remove_weapon(main, str(id))
					n += 1
		"armor":
			for id in p.owned_armor.keys():
				if str(id) != "armor_rags":
					remove_armor(main, str(id))
					n += 1
		"shield":
			for id in p.owned_shields.keys():
				remove_shield(main, str(id))
				n += 1
		"clothing":
			for id in p.owned_clothing.keys():
				remove_clothing(main, str(id))
				n += 1
		"talisman":
			for id in p.owned_talismans.keys():
				remove_talisman(main, str(id))
				n += 1
		_:
			return fail("Nothing to remove for %s." % kind)
	return ok("Removed %d." % n)

# --- the Blacksmith's levels, runes ---

static func set_weapon_smith_level(main, level: int) -> Dictionary:
	var p = player_of(main)
	var id := str(p.current_weapon_base.get("id", ""))
	if id == "":
		return fail("No weapon in hand.")
	level = clampi(level, 0, BlacksmithScript.WEAPON_MAX_LEVEL)
	p.weapon_upgrade_levels[id] = level
	p._equip_weapon(p.current_weapon_base)
	return ok("Your weapon is at Blacksmith level %d." % level)

static func set_armor_smith_level(main, level: int) -> Dictionary:
	var p = player_of(main)
	var id := str(p.equipped_armor.get("id", ""))
	if not ArmorScript.is_metal(id):
		return fail("Only metal armour can be upgraded.")
	level = clampi(level, 0, BlacksmithScript.ARMOR_MAX_LEVEL)
	p.armor_upgrade_levels[id] = level
	p.refresh_armor_effects()
	return ok("Your armour is at Blacksmith level %d." % level)

static func set_rune(main, rune_id: String) -> Dictionary:
	var p = player_of(main)
	var id := str(p.current_weapon_base.get("id", ""))
	if id == "" or id == "club":
		return fail("The Club cannot be enchanted.")
	if rune_id == "":
		p.weapon_enchantments.erase(id)
	else:
		if EnchantmentsScript.get_rune(rune_id).is_empty():
			return fail("No such rune.")
		p.weapon_enchantments[id] = rune_id
	p._equip_weapon(p.current_weapon_base)
	return ok("Rune: %s." % (str(EnchantmentsScript.get_rune(rune_id).name) if rune_id != "" else "none"))

# ---------------------------------------------------------------------------------------------------------------------------
# PARTY
# ---------------------------------------------------------------------------------------------------------------------------

# Every kind of member there is: [{kind, name, levels}].
static func member_kinds() -> Array:
	var out: Array = []
	for kind in PartyRulesScript.KINDS:
		out.append({"kind": str(kind), "name": str(PartyRulesScript.KINDS[kind].name), "levels": PartyRulesScript.levels(str(kind))})
	return out

# Recruits a member. A full party refuses unless `override` raises the party's slot cap just enough for one more.
static func recruit(main, kind: String, override: bool) -> Dictionary:
	var p = player_of(main)
	if not PartyRulesScript.exists(kind):
		return fail("No such party member.")
	if not p.can_recruit(kind):
		if not override:
			return fail("The party is full (%d of %d). Turn on 'Ignore the party limit' to add more." % [p.party_members.size() + p.party.size(), p.party_capacity()])
		var guard := 0
		while not p.can_recruit(kind) and guard < 40:
			p.max_party_slots += 1
			guard += 1
	var member = p.recruit(kind)
	if member == null:
		return fail("Could not recruit %s." % kind)
	return ok("%s joins the party." % member.name)

static func find_member(main, member_id: int):
	for m in player_of(main).party:
		if m.id == member_id:
			return m
	return null

static func dismiss(main, member_id: int) -> Dictionary:
	var m = find_member(main, member_id)
	if m == null:
		return fail("That member is not in the party.")
	var label: String = m.name
	player_of(main).dismiss_party_member(member_id)
	return ok("%s leaves the party." % label)

# The older flat companions (a Knight from the old skill tree, a recruited Warrior) are not roster members; they go by position.
static func remove_mercenary(main, index: int) -> Dictionary:
	var p = player_of(main)
	if index < 0 or index >= p.party_members.size():
		return fail("That companion is gone.")
	var label := str(p.party_members[index].get("name", "companion"))
	p.party_members.remove_at(index)
	return ok("%s leaves the party." % label)

static func dismiss_all(main) -> Dictionary:
	var p = player_of(main)
	var n: int = p.party.size() + p.party_members.size() + p.bench.size()
	p.party.clear()
	p.party_members.clear()
	p.bench.clear()   # the bench too: "dismiss everyone" leaves nobody anywhere
	return ok("The party is empty (%d left)." % n)

# A member's level, through its own level-up (+ a bonus pick each level, unspent). Going down starts it over.
static func set_member_level(main, member_id: int, level: int) -> Dictionary:
	var m = find_member(main, member_id)
	if m == null:
		return fail("That member is not in the party.")
	if not m.levels():
		return fail("%s never levels." % m.name)
	level = clampi(level, 1, PartyRulesScript.MAX_LEVEL)
	if level < m.level:
		m.level = 1
		m.xp = 0
		m.picks = 0
		m.bonus = {"hp": 0.0, "attack": 0.0, "defense": 0.0, "speed": 0.0, "magic": 0.0, "fortitude": 0.0}
	while m.level < level:
		m._level_up()
	player_of(main).trim_ally_talismans(m)
	return ok("%s is level %d (%d picks to spend)." % [m.name, m.level, m.picks])

static func grant_picks(main, member_id: int, amount: int) -> Dictionary:
	var m = find_member(main, member_id)
	if m == null:
		return fail("That member is not in the party.")
	if not m.levels():
		return fail("%s never levels." % m.name)
	m.picks = maxi(0, m.picks + amount)
	return ok("%s has %d picks to spend." % [m.name, m.picks])

static func spend_pick(main, member_id: int, stat: String) -> Dictionary:
	var m = find_member(main, member_id)
	if m == null:
		return fail("That member is not in the party.")
	if m.spend_pick(stat):
		return ok("%s: +1 %s (%d picks left)." % [m.name, stat, m.picks])
	return fail("%s cannot spend a pick on %s." % [m.name, stat])

# Hands a member a piece of gear, taking it from whoever has it (another member; for the hero's own the answer is no).
# slot: "weapon", "armor", "shield" or "talisman". The item is granted to your collection first if you do not own it.
static func equip_member(main, member_id: int, slot: String, item_id: String) -> Dictionary:
	var p = player_of(main)
	var m = find_member(main, member_id)
	if m == null:
		return fail("That member is not in the party.")
	if not m.can_carry_gear():
		return fail("%s cannot carry gear." % m.name)
	match slot:
		"weapon":
			p.owned_weapons[item_id] = true
			if item_id != "club":
				var holder = p.weapon_holder(item_id)
				if holder != null and holder != m:
					holder.gear.weapon = ""
			return _equip_result(m, p.equip_ally_weapon(m, item_id), p.ally_weapon_block_reason(m, item_id), "weapon")
		"armor":
			p.owned_armor[item_id] = true
			var holder_a = p.armor_holder(item_id)
			if holder_a != null and holder_a != m:
				holder_a.gear.armor = ""
			return _equip_result(m, p.equip_ally_armor(m, item_id), p.ally_armor_block_reason(m, item_id), "armour")
		"shield":
			p.owned_shields[item_id] = true
			var holder_s = p.shield_holder(item_id)
			if holder_s != null and holder_s != m and not p._shield_is_free(item_id):
				holder_s.gear.shield = ""
			return _equip_result(m, p.equip_ally_shield(m, item_id), p.ally_shield_block_reason(m, item_id), "shield")
		"talisman":
			p.owned_talismans[item_id] = true
			var holder_t = p.talisman_holder(item_id)
			if holder_t != null and holder_t != m:
				holder_t.gear.talismans.erase(item_id)
			return _equip_result(m, p.equip_ally_talisman(m, item_id), p.ally_talisman_block_reason(m, item_id), "talisman")
	return fail("Unknown slot.")

static func _equip_result(m, done: bool, reason: String, what: String) -> Dictionary:
	if done:
		return ok("%s now has the %s." % [m.name, what])
	return fail(reason if reason != "" else "%s cannot take that." % m.name)

static func unequip_member(main, member_id: int, slot: String, item_id: String = "") -> Dictionary:
	var p = player_of(main)
	var m = find_member(main, member_id)
	if m == null:
		return fail("That member is not in the party.")
	match slot:
		"weapon": p.unequip_ally_weapon(m)
		"armor": p.unequip_ally_armor(m)
		"shield": p.unequip_ally_shield(m)
		"talisman":
			if item_id == "":
				m.gear.talismans = []
			else:
				p.unequip_ally_talisman(m, item_id)
		_: return fail("Unknown slot.")
	return ok("%s took off the %s." % [m.name, slot])

# Heals the whole party. In a battle: every ally to full HP and resources, and the downed stand back up. Out of one the
# members have no HP of their own (every battle starts them fresh), so it only tops up what carries over: a wolf's faints and loyalty.
static func heal_party(main) -> Dictionary:
	var p = player_of(main)
	var healed := 0
	var revived := 0
	if bool(main.in_battle):
		for a in main.battle_downed_allies.duplicate():
			main._revive_downed(a, 1.0)
			revived += 1
		for a in main.battle_allies:
			a["hp"] = int(a.max_hp)
			if a.has("max_stamina"):
				a["stamina"] = int(a.max_stamina)
			if a.has("max_mana"):
				a["mana"] = int(a.max_mana)
			healed += 1
	for m in p.party:
		m.faints = 0
		if m.is_wolf():
			m.battles_left = PartyRulesScript.wolf_stay_battles(int(p.talisman_bonus("wolf_stay_bonus")), p.meta_wolf_bonus_waves)
	if bool(main.in_battle):
		main._refresh_battle_display()
		return ok("%d allies healed, %d stood back up." % [healed, revived])
	return ok("Wolves' faints and loyalty are reset. (Members are at full health at the start of every battle.)")

static func revive_party(main) -> Dictionary:
	if not bool(main.in_battle):
		return fail("Only in a battle: that is the only time members can be downed.")
	var n := 0
	for a in main.battle_downed_allies.duplicate():
		main._revive_downed(a, 1.0)
		n += 1
	main._refresh_battle_display()
	return ok("%d stood back up." % n if n > 0 else "Nobody is downed.")
