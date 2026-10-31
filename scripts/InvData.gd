extends RefCounted
class_name InvData

# What the new inventory shows, turned into plain data, and what pressing its button does. Everything here reads the game's own
# models (Player, PartyMember, Weapons, Armor, Shields, Clothing, Potions, Foods, Talismans) and calls the same equip functions the
# old screen did; the screens only draw what comes back. A "unit" is the hero (member == null) or a PartyMember.
#
# An entry is {kind, id, name, sub, quality, art, number, lore, desc, mythic, holders, lack, specials, data, tint, qty, key, tooltip,
# sort_quality, sort_number, sort_new, rune}.

const WeaponsScript := preload("res://scripts/Weapons.gd")
const ArmorScript := preload("res://scripts/Armor.gd")
const ShieldsScript := preload("res://scripts/Shields.gd")
const ClothingScript := preload("res://scripts/Clothing.gd")
const DefenseScript := preload("res://scripts/Defense.gd")
const EnchantmentsScript := preload("res://scripts/Enchantments.gd")
const PotionsScript := preload("res://scripts/Potions.gd")
const FoodsScript := preload("res://scripts/Foods.gd")
const TalismansScript := preload("res://scripts/Talismans.gd")
const ItemLoreScript := preload("res://scripts/ItemLore.gd")

const GEAR_CATEGORIES := ["Weapons", "Armour", "Clothes", "Shields"]
const ITEM_CATEGORIES := ["Potions", "Food", "Arrows"]
# The sub-tab icons (assets/ui/sub_*.png).
const CATEGORY_ICONS := {
	"Weapons": "sub_weapons", "Armour": "sub_armour", "Clothes": "sub_clothes", "Shields": "sub_shields",
	"Potions": "sub_potions", "Food": "sub_food", "Arrows": "sub_arrows",
}
const POTION_TINT := Color(0.85, 0.35, 0.35, 0.2)
const FOOD_TINT := Color(0.78, 0.63, 0.38, 0.2)
const ARROW_TINTS := {"flame": Color(1.0, 0.48, 0.23, 0.2), "freeze": Color(0.48, 0.82, 1.0, 0.2), "bomb": Color(0.75, 0.75, 0.75, 0.2)}

# --- who is who -------------------------------------------------------------------------------------------------------------------------

static func unit_name(member) -> String:
	return "You" if member == null else str(member.name)

static func is_hero(member) -> bool:
	return member == null

# --- entries ----------------------------------------------------------------------------------------------------------------------------

static func gear_entries(player, category: String, member = null) -> Array:
	match category:
		"Weapons":
			return weapon_entries(player, member)
		"Armour":
			return armor_entries(player, member)
		"Clothes":
			return clothing_entries(player, member)
		"Shields":
			return shield_entries(player, member)
	return []

static func item_entries(player, category: String) -> Array:
	match category:
		"Potions":
			return consumable_entries(player, false)
		"Food":
			return consumable_entries(player, true)
		"Arrows":
			return arrow_entries(player)
	return []

# A weapon's plain name: its type ("Spear"), never its tier or material (the glow and the picture say those); a Mythic keeps its own.
static func weapon_name(variant: Dictionary) -> String:
	if str(variant.get("tier_name", "")) == "Mythic":
		return str(variant.get("name", ""))
	var base: Dictionary = WeaponsScript.get_base_type(variant)
	return str(base.get("name", variant.get("name", "")))

static func weapon_entries(player, member = null) -> Array:
	var out: Array = []
	var order := 0
	for id in player.owned_weapons:
		var variant: Dictionary = WeaponsScript.get_owned_variant(id)
		order += 1
		if variant.is_empty():
			continue
		# The Staff is for party members only: the hero's list never shows it.
		if member == null and WeaponsScript.is_ally_only(variant):
			continue
		var e := weapon_entry(player, variant, member)
		e.sort_new = order
		out.append(e)
	return out

static func weapon_entry(player, variant: Dictionary, member = null) -> Dictionary:
	var id := str(variant.get("id", ""))
	var base: Dictionary = WeaponsScript.get_base_type(variant)
	var base_id := str(base.get("id", variant.get("icon", "")))
	var quality := PixelKit.quality_of(variant)
	var level: int = player.get_weapon_upgrade_level(id)
	var parts: Array = []
	if str(variant.get("material_name", "")) != "":
		parts.append(str(variant.material_name))
	parts.append(quality)
	var holders: Array = []
	if str(player.current_weapon_base.get("id", "")) == id:
		holders.append("You")
	for m in player.party:
		if m.weapon_id() == id:
			holders.append(str(m.name))
	var unit_is_caster: bool = member != null and member.is_caster()
	var specials: Array = []
	for s in variant.get("specials", []):
		var unit_word := " MP" if bool(variant.get("uses_magic", false)) and unit_is_caster else " STA"
		specials.append({
			"id": str(s.get("id", "")), "n": str(s.get("name", "")), "c": "%d%s" % [int(s.get("stamina_cost", 0)), unit_word],
			"d": str(s.get("description", "")).replace("%%", "%"), "learned": bool(player.learned_specials.get(str(s.get("id", "")), false)),
		})
	var rune_id := str(player.weapon_enchantments.get(id, ""))
	var damage: int = player.weapon_damage_preview(variant)
	return {
		"kind": "weapon", "id": id, "name": weapon_name(variant), "sub": " · ".join(parts) + (" +%d" % level if level > 0 else ""),
		"quality": quality, "art": WeaponIcons.texture_for(variant), "number": str(damage), "lore": ItemLoreScript.weapon(variant, base_id),
		"desc": str(variant.get("description", "")).replace("%%", "%"), "mythic": quality == "Mythic", "holders": holders, "lack": lacking(player, variant),
		"specials": specials, "data": variant, "tint": Color(0, 0, 0, 0), "qty": 1, "key": id, "level": level,
		"rune": str(EnchantmentsScript.get_rune(rune_id).get("name", "")) if rune_id != "" else "",
		"sort_quality": float(_tier_rank(variant)) * 1000.0 + float(damage), "sort_number": float(damage), "sort_new": 0,
		"tooltip": "",
	}

static func _tier_rank(variant: Dictionary) -> int:
	for tier in WeaponsScript.TIERS:
		if tier.tier_name == variant.get("tier_name", ""):
			return int(tier.rank)
	return -1

# What a weapon asks of you that you do not have: [{"stat": "MGT", "need": 15, "have": 6}, ...] (empty = nothing lacking).
static func lacking(player, variant: Dictionary) -> Array:
	var out: Array = []
	var need_might: int = player.might_needed(variant)
	if need_might > player.stat_might:
		out.append({"stat": "MGT", "need": need_might, "have": int(player.stat_might)})
	var need_intimidation := int(variant.get("required_intimidation", 0))
	if need_intimidation > player.stat_intimidation:
		out.append({"stat": "INM", "need": need_intimidation, "have": int(player.stat_intimidation)})
	return out

static func armor_entries(player, member = null) -> Array:
	var out: Array = []
	var worn_id := str(player.equipped_armor.get("id", ""))
	var order := 0
	for armor in ArmorScript.TIERS:
		var id := str(armor.id)
		if member != null and id == "armor_rags":
			continue
		if not player.owned_armor.has(id) and id != worn_id:
			continue
		order += 1
		var level: int = player.get_armor_upgrade_level(id)
		var points: int = int(round(player.armor_defense_fraction(armor) * 100.0))
		var holders: Array = []
		if worn_id == id:
			holders.append("You")
		for m in player.party:
			if m.armor_id() == id:
				holders.append(str(m.name))
		out.append({
			"kind": "armor", "id": id, "name": str(armor.name), "sub": ("+%d" % level) if level > 0 else "", "quality": "",
			"art": PixelKit.texture_at(ArmorScript.icon_path(armor)), "number": str(points), "lore": str(ItemLoreScript.ARMOR.get(id, "")),
			"desc": str(armor.get("description", "")), "mythic": false, "holders": holders, "lack": [], "specials": [], "data": armor,
			"tint": Color(0, 0, 0, 0), "qty": 1, "key": id, "level": level,
			"sort_quality": float(ArmorScript.tier_rank(armor)), "sort_number": float(points), "sort_new": order, "tooltip": "", "rune": "",
		})
	return out

static func clothing_entries(player, member = null) -> Array:
	var out: Array = []
	if member != null:
		return out   # members don't wear clothes
	var order := 0
	for piece in ClothingScript.PIECES:
		if not player.owned_clothing.has(piece.id):
			continue
		order += 1
		var holders: Array = []
		if str(player.equipped_clothing.get(piece.slot, "")) == str(piece.id):
			holders.append("You")
		out.append({
			"kind": "clothing", "id": str(piece.id), "name": str(piece.name), "sub": str(ClothingScript.SLOT_LABELS[piece.slot]), "quality": "",
			"art": PixelKit.texture_at("res://assets/%s.png" % piece.icon), "number": "+%d" % int(round(float(piece.damage_reduction) * 100.0)),
			"lore": str(ItemLoreScript.CLOTHING.get(str(piece.id), "")), "desc": str(piece.get("description", "")), "mythic": false,
			"holders": holders, "lack": [], "specials": [], "data": piece, "tint": Color(0, 0, 0, 0), "qty": 1, "key": str(piece.id), "level": 0,
			"sort_quality": float(piece.damage_reduction) * 100.0, "sort_number": float(piece.damage_reduction) * 100.0, "sort_new": order,
			"tooltip": "", "rune": "",
		})
	return out

static func shield_entries(player, member = null) -> Array:
	var out: Array = []
	var worn_id := str(player.equipped_shield.get("id", ""))
	var order := 0
	for id in ShieldsScript.SHIELD_IDS:
		var shield: Dictionary = ShieldsScript.SHIELDS[id]
		var is_free: bool = int(shield.get("price", 1)) == 0
		if not player.owned_shields.has(id) and not is_free:
			continue
		order += 1
		var holders: Array = []
		if worn_id == id:
			holders.append("You")
		for m in player.party:
			if m.shield_id() == id:
				holders.append(str(m.name))
		var block := int(round(float(shield.get("block_chance", 0.0)) * 100.0))
		out.append({
			"kind": "shield", "id": str(id), "name": str(shield.name), "sub": "", "quality": "",
			"art": PixelKit.texture_at("res://assets/%s.png" % shield.get("icon", "")), "number": "%d%%" % block,
			"lore": str(ItemLoreScript.SHIELDS.get(str(id), "")), "desc": str(shield.get("description", "")), "mythic": false, "holders": holders,
			"lack": [], "specials": [], "data": shield, "tint": Color(0, 0, 0, 0), "qty": 1, "key": str(id), "level": 0, "free": is_free,
			"sort_quality": float(block), "sort_number": float(block), "sort_new": order, "tooltip": "", "rune": "",
		})
	return out

static func consumable_entries(player, want_food: bool) -> Array:
	var counts := {}
	var order: Array = []
	for id in player.potion_queue:
		if not counts.has(id):
			counts[id] = 0
			order.append(id)
		counts[id] += 1
	var out: Array = []
	var n := 0
	for id in order:
		if FoodsScript.is_food(str(id)) != want_food:
			continue
		var tier: Dictionary = player.get_consumable(id)
		n += 1
		out.append({
			"kind": "food" if want_food else "potion", "id": str(id), "name": str(tier.get("name", id)), "sub": "", "quality": "",
			"art": PixelKit.texture_at("res://assets/%s.png" % tier.get("icon", "potion")), "number": "x%d" % int(counts[id]),
			"lore": "", "desc": str(tier.get("description", "")), "mythic": false, "holders": [], "lack": [], "specials": [], "data": tier,
			"tint": FOOD_TINT if want_food else POTION_TINT, "qty": int(counts[id]), "key": str(id), "level": 0,
			"sort_quality": 0.0, "sort_number": float(counts[id]), "sort_new": n, "tooltip": "", "rune": "",
		})
	return out

static func arrow_entries(player) -> Array:
	var out: Array = []
	var n := 0
	for kind in ["flame", "freeze", "bomb"]:
		var held: int = int(player.owned_arrows.get(kind, 0))
		if held <= 0:
			continue
		var info: Dictionary = WeaponsScript.ARROW_TYPES[kind]
		n += 1
		out.append({
			"kind": "arrow", "id": kind, "name": str(info.name), "sub": "", "quality": "", "art": PixelKit.texture_at("res://assets/arrow_%s.png" % kind),
			"number": "x%d" % held, "lore": "", "desc": str(info.get("description", "")), "mythic": false, "holders": [], "lack": [],
			"specials": [], "data": info, "tint": ARROW_TINTS[kind], "qty": held, "key": kind, "level": 0, "sort_quality": 0.0,
			"sort_number": float(held), "sort_new": n, "tooltip": "", "rune": "",
		})
	return out

# --- the "what it does to you" rows -----------------------------------------------------------------------------------------------------
# Each row: [label, from, to, note, icons]. For the hero, before -> after with the change; for a member, the item's own numbers.

static func _signed(v: int) -> String:
	return ("+%d" % v) if v >= 0 else ("−%d" % absi(v))

static func rows(player, member, entry: Dictionary) -> Array:
	var out: Array = []
	var worn_here: bool = entry.holders.has(unit_name(member))
	match str(entry.kind):
		"weapon":
			var variant: Dictionary = entry.data
			if member == null:
				var now: int = player.weapon_damage_preview(player.current_weapon_base) if not player.current_weapon_base.is_empty() else 0
				var after := int(entry.number)
				if worn_here:
					out.append(["Damage", "", str(after), "equipped"])
				else:
					out.append(["Damage", str(now), str(after), _signed(after - now)])
			else:
				var cur_variant: Dictionary = WeaponsScript.get_owned_variant(member.weapon_id()) if member.weapon_id() != "" else {}
				var mult := "×%.2f" % float(variant.get("damage_mult", 1.0))
				if worn_here:
					out.append(["Damage", "", mult, "equipped"])
				elif not cur_variant.is_empty():
					out.append(["Damage", "×%.2f" % float(cur_variant.get("damage_mult", 1.0)), mult, ""])
				else:
					out.append(["Damage", "", mult, ""])
			var lack_notes: Array = []
			var need_parts: Array = []
			var icons: Array = []
			var might: int = player.might_needed(variant)
			if might > 0:
				need_parts.append("MGT %d" % might)
				icons.append("stat_might")
			var intim := int(variant.get("required_intimidation", 0))
			if intim > 0:
				need_parts.append("INM %d" % intim)
				icons.append("stat_intimidation")
			if member == null:
				for l in entry.lack:
					lack_notes.append("%s %d" % [l.stat, l.have])
			if not need_parts.is_empty():
				out.append(["Needs", "", " · ".join(need_parts), ("you have " + " · ".join(lack_notes)) if not lack_notes.is_empty() else "", icons])
			if str(entry.rune) != "":
				out.append(["Rune", "", str(entry.rune), "", ["stat_magic"]])
			if bool(entry.mythic) and str(entry.desc) != "":
				out.append(["Passive", "", str(entry.desc), "", ["stat_crit"]])
		"armor":
			var armor: Dictionary = entry.data
			var points: int = int(round(player.armor_defense_fraction(armor) * 100.0))
			var fort := int(armor.get("fortitude", 0))
			if member == null:
				var now_points: float = player.bodily_defense_points()
				var after_points: float = now_points + (player.armor_defense_fraction(armor) - player.armor_tier_damage_reduction()) * 100.0
				var now_fort: float = player.fortitude_total()
				var after_fort: float = now_fort - float(player.equipped_armor.get("fortitude", 0)) + float(fort)
				if worn_here:
					out.append(["Defense", "", str(int(round(now_points))), "equipped"])
					out.append(["FTD", "", str(int(round(now_fort))), ""])
					out.append(["Bodily harm", "", "−%d%%" % int(round(DefenseScript.reduction(now_points) * 100.0)), ""])
				else:
					out.append(["Defense", str(int(round(now_points))), str(int(round(after_points))), _signed(int(round(after_points)) - int(round(now_points)))])
					out.append(["FTD", str(int(round(now_fort))), str(int(round(after_fort))), _signed(int(round(after_fort)) - int(round(now_fort)))])
					out.append(["Bodily harm", "−%d%%" % int(round(DefenseScript.reduction(now_points) * 100.0)), "−%d%%" % int(round(DefenseScript.reduction(after_points) * 100.0)), ""])
			else:
				out.append(["Defense", "", "+%d" % points, ""])
				out.append(["FTD", "", _signed(fort), ""])
		"clothing":
			var piece: Dictionary = entry.data
			var gain: int = int(round(float(piece.damage_reduction) * 100.0))
			if member == null:
				var now_def: float = player.bodily_defense_points()
				var worn_piece: Dictionary = ClothingScript.get_piece(str(player.equipped_clothing.get(piece.slot, "")))
				var after_def: float = now_def + (float(piece.damage_reduction) - float(worn_piece.get("damage_reduction", 0.0))) * 100.0
				if worn_here:
					out.append(["Defense", "", str(int(round(now_def))), "equipped"])
				else:
					out.append(["Defense", str(int(round(now_def))), str(int(round(after_def))), _signed(int(round(after_def)) - int(round(now_def)))])
			else:
				out.append(["Defense", "", "+%d" % gain, ""])
		"shield":
			var shield: Dictionary = entry.data
			var block := int(round(float(shield.get("block_chance", 0.0)) * 100.0))
			var cur_shield: Dictionary = player.equipped_shield if member == null else (ShieldsScript.SHIELDS.get(member.shield_id(), {}) if member.shield_id() != "" else {})
			var cur_block := int(round(float(cur_shield.get("block_chance", 0.0)) * 100.0))
			if worn_here:
				out.append(["Block chance", "", "%d%%" % block, "equipped"])
			elif not cur_shield.is_empty():
				out.append(["Block chance", "%d%%" % cur_block, "%d%%" % block, _signed(block - cur_block) + "%"])
			else:
				out.append(["Block chance", "", "%d%%" % block, ""])
			var shield_fort := int(shield.get("fortitude", 0))
			if shield_fort != 0:
				out.append(["FTD", "", _signed(shield_fort), ""])
		"potion", "food":
			var tier: Dictionary = entry.data
			var blocked: bool = player.talisman_bonus("disable_healing_items") > 0.0
			var heal: int = int(tier.get("heal_amount", 0))
			var bonus: float = player.meta_healing_bonus_pct + player.talisman_bonus("heal_pct")
			if bonus > 0.0:
				heal = int(round(heal * (1.0 + bonus)))
			if heal > 0:
				var after_hp: int = mini(int(player.max_health), int(player.health) + heal)
				out.append(["HP", str(int(player.health)), str(after_hp), "no effect: Vampire's Pact" if blocked else _signed(after_hp - int(player.health))])
			var sta := int(tier.get("stamina_amount", 0))
			if sta > 0:
				var after_sta: int = mini(int(player.max_stamina), int(player.stamina) + sta)
				out.append(["Stamina", str(int(player.stamina)), str(after_sta), _signed(after_sta - int(player.stamina))])
	return out

# --- pressing the button ----------------------------------------------------------------------------------------------------------------

# The member (never the hero) other than `member` who holds this item, or null.
static func _other_holder(player, member, kind: String, id: String):
	var holder = null
	match kind:
		"weapon":
			holder = player.weapon_holder(id)
		"armor":
			holder = player.armor_holder(id)
		"shield":
			holder = player.shield_holder(id)
		"talisman":
			holder = player.talisman_holder(id)
	return holder if holder != null and holder != member else null

# Whether `member` can take the item, and from whom: {"reason": "" when nothing blocks it, "take_from": the ally who has it now}.
# The game's own block reasons are used; "<ally> is using it" becomes a Take-from instead (the hero's own items are never taken).
static func ally_state(player, member, kind: String, id: String) -> Dictionary:
	var reason := ""
	match kind:
		"weapon":
			reason = player.ally_weapon_block_reason(member, id)
		"armor":
			reason = player.ally_armor_block_reason(member, id)
		"shield":
			reason = player.ally_shield_block_reason(member, id)
		"talisman":
			reason = player.ally_talisman_block_reason(member, id)
	var take_from := ""
	if reason != "":
		var holder = _other_holder(player, member, kind, id)
		if holder != null and (reason == "%s is using it." % holder.name or reason == "%s is wearing it." % holder.name):
			reason = ""
			take_from = str(holder.name)
			if kind == "talisman" and member.talisman_ids().size() >= member.talisman_slot_count():
				reason = "No free slot."
				take_from = ""
	return {"reason": reason, "take_from": take_from}

# The button under an item: {"label", "enabled", "reason", "act": "equip"|"unequip"|"none"}.
static func action_for(player, member, entry: Dictionary) -> Dictionary:
	var kind := str(entry.kind)
	var id := str(entry.id)
	var mine: bool = entry.holders.has(unit_name(member))
	if kind in ["potion", "food", "arrow"]:
		return {"label": "", "enabled": false, "reason": "", "act": "none"}
	if member == null:
		if mine:
			var cannot_remove: bool = (kind == "weapon" and id == "club") or (kind == "armor" and id == "armor_rags")
			return {"label": "Equipped" if cannot_remove else "Take off", "enabled": not cannot_remove, "reason": "", "act": "unequip"}
		if not entry.lack.is_empty():
			var l: Dictionary = entry.lack[0]
			return {"label": "Equip", "enabled": false, "reason": "Needs %d %s (you have %d)." % [l.need, l.stat, l.have], "act": "equip"}
		var holders_other: Array = entry.holders.filter(func(h): return h != "You")
		var is_free_item: bool = (kind == "weapon" and id == "club") or (kind == "shield" and bool(entry.get("free", false)))
		if not holders_other.is_empty() and not is_free_item:
			return {"label": "Take from %s" % holders_other[0], "enabled": true, "reason": "", "act": "equip"}
		return {"label": "Equip", "enabled": true, "reason": "", "act": "equip"}
	if mine:
		return {"label": "Take off", "enabled": true, "reason": "", "act": "unequip"}
	var state := ally_state(player, member, kind, id)
	if state.reason != "":
		return {"label": "Equip", "enabled": false, "reason": state.reason, "act": "equip"}
	if state.take_from != "":
		return {"label": "Take from %s" % state.take_from, "enabled": true, "reason": "", "act": "equip"}
	return {"label": "Equip", "enabled": true, "reason": "", "act": "equip"}

# Does what action_for says; true if something changed.
static func apply_action(player, member, entry: Dictionary) -> bool:
	var act := action_for(player, member, entry)
	if not act.enabled or act.act == "none":
		return false
	var kind := str(entry.kind)
	var id := str(entry.id)
	if act.act == "unequip":
		return unequip(player, member, kind, id, entry)
	return equip(player, member, kind, id, entry)

static func equip(player, member, kind: String, id: String, entry: Dictionary) -> bool:
	if member == null:
		match kind:
			"weapon":
				player._equip_weapon(entry.data)
				return true
			"armor":
				return player.try_buy_armor(entry.data)
			"clothing":
				return player.equip_clothing(id)
			"shield":
				player.equip_shield(entry.data)
				return true
		return false
	var state := ally_state(player, member, kind, id)
	if state.reason != "":
		return false
	var holder = _other_holder(player, member, kind, id) if state.take_from != "" else null
	if holder != null:
		_strip(holder, kind, id)
	match kind:
		"weapon":
			return player.equip_ally_weapon(member, id)
		"armor":
			return player.equip_ally_armor(member, id)
		"shield":
			return player.equip_ally_shield(member, id)
	return false

static func unequip(player, member, kind: String, id: String, entry: Dictionary) -> bool:
	if member == null:
		match kind:
			"weapon":
				if id == "club":
					return false
				player._equip_weapon(WeaponsScript.CLUB)
				return true
			"armor":
				var rags: Dictionary = ArmorScript.find("armor_rags")
				return not rags.is_empty() and player.try_buy_armor(rags)
			"clothing":
				var piece: Dictionary = entry.data
				player.equipped_clothing[piece.slot] = ""
				return true
			"shield":
				player.equip_shield({})
				return true
		return false
	match kind:
		"weapon":
			player.unequip_ally_weapon(member)
		"armor":
			player.unequip_ally_armor(member)
		"shield":
			player.unequip_ally_shield(member)
		_:
			return false
	return true

static func _strip(holder, kind: String, id: String) -> void:
	match kind:
		"weapon":
			holder.gear.weapon = ""
		"armor":
			holder.gear.armor = ""
		"shield":
			holder.gear.shield = ""
		"talisman":
			holder.gear.talismans.erase(id)

# --- talismans -------------------------------------------------------------------------------------------------------------------------

# Everyone's talismans in one list: [{id, name, rarity, group, overview, lore, art, owned, holder ("You", a member's name, or "")}].
static func talisman_entries(player) -> Array:
	var out: Array = []
	for item in TalismansScript.ITEMS:
		var info: Dictionary = ItemLoreScript.talisman(str(item.id))
		var holder := ""
		if player.equipped_talismans.has(item.id):
			holder = "You"
		else:
			var h = player.talisman_holder(str(item.id))
			if h != null:
				holder = str(h.name)
		out.append({
			"id": str(item.id), "name": str(item.name), "rarity": str(item.rarity), "group": str(info.get("group", "")),
			"overview": str(info.get("overview", item.get("description", ""))), "lore": str(info.get("lore", "")),
			"description": str(item.get("description", "")), "art": PixelKit.texture_at("res://assets/%s.png" % TalismansScript.get_talisman(str(item.id)).icon),
			"owned": player.owned_talismans.has(item.id), "holder": holder,
		})
	return out

# How many charm slots `member` (null = the hero) has open and how many it is wearing.
static func talisman_slots(player, member) -> Dictionary:
	if member == null:
		return {"open": int(player.talisman_slots()), "worn": player.equipped_talismans.duplicate()}
	return {"open": int(member.talisman_slot_count()), "worn": member.talisman_ids().duplicate()}

# The button under a picked talisman: {"label", "enabled", "reason"}.
static func talisman_action(player, member, entry: Dictionary) -> Dictionary:
	var id := str(entry.id)
	var slots := talisman_slots(player, member)
	if slots.worn.has(id):
		return {"label": "Take off", "enabled": true, "reason": ""}
	if member == null:
		if slots.worn.size() >= slots.open:
			return {"label": "No free slot", "enabled": false, "reason": "All your slots are full."}
		var holder := str(entry.holder)
		return {"label": "Take from %s" % holder if holder != "" else "Wear", "enabled": true, "reason": ""}
	var state := ally_state(player, member, "talisman", id)
	if state.reason == "No free slot.":
		return {"label": "No free slot", "enabled": false, "reason": state.reason}
	if state.reason != "":
		return {"label": "Wear", "enabled": false, "reason": state.reason}
	if state.take_from != "":
		return {"label": "Take from %s" % state.take_from, "enabled": true, "reason": ""}
	return {"label": "Wear", "enabled": true, "reason": ""}

static func talisman_apply(player, member, entry: Dictionary) -> bool:
	var act := talisman_action(player, member, entry)
	if not act.enabled:
		return false
	var id := str(entry.id)
	var slots := talisman_slots(player, member)
	if slots.worn.has(id):
		return player.unequip_talisman(id) if member == null else player.unequip_ally_talisman(member, id)
	if member == null:
		return player.equip_talisman(id)
	var state := ally_state(player, member, "talisman", id)
	if state.take_from != "":
		var holder = _other_holder(player, member, "talisman", id)
		if holder != null:
			_strip(holder, "talisman", id)
	return player.equip_ally_talisman(member, id)
