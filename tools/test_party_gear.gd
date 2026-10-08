extends SceneTree

# Party gear: the Staff (a party-only weapon), who may hold which weapon/talisman (an item is
# on one unit at a time -- you or exactly one member -- except the Club), slot caps by level,
# and how a member's weapon is rebuilt (its own talismans, the Astral weapon passives).

func _init() -> void:
	seed(20261006)
	var weapons = load("res://scripts/Weapons.gd")
	var rules = load("res://scripts/PartyRules.gd")
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player

	# =========================================================
	# The Staff
	# =========================================================
	var staff: Dictionary = weapons.get_owned_variant("staff_fine_steel")
	print("The Staff resolves from an id like any weapon: name=%s base=%s (expected Staff, staff)" % [staff.get("name", "?"), weapons.get_base_type(staff).get("id", "")])
	print("...is party-only: ally_only=%s base_const=%s (expected true, true)" % [weapons.is_ally_only(staff), weapons.is_ally_only(weapons.STAFF)])
	print("Normal weapons are not: spear=%s club=%s (expected false, false)" % [weapons.is_ally_only(weapons.get_owned_variant("spear_fine_steel")), weapons.is_ally_only(weapons.CLUB)])
	print("It never shows up in the player's weapon pool: %s (expected false)" % [weapons.UPGRADABLE_TYPES.any(func(w): return w.id == "staff")])
	print("...but all_base_types() knows it: %s (expected true)" % [weapons.all_base_types().any(func(w): return w.id == "staff")])
	print("Its numbers (the user's doc): +2 range=%d, +6 magic=%d, magic damage=%s, blind chance=%.2f (expected 2, 6, true, 0.10)" % [staff.range_bonus, staff.magic_bonus, staff.uses_magic, staff.passive_ranged_blind_chance])
	var special_names := []
	for s in staff.specials:
		special_names.append(s.name)
	print("Its three specials: %s (expected I CAST FIREBALL, Landfall, Channel)" % [special_names])
	var mythic: Dictionary = weapons.get_owned_variant("staff_mythic")
	print("The Mythic Staff is Moonstick and doubles magic gain: %s / %.1f (expected Moonstick, 2.0)" % [mythic.get("name", "?"), float(mythic.get("passive_magic_gain_mult", 0.0))])

	player.coins = 1000
	var coins_before: int = player.coins
	var bought_as_player: bool = player.try_buy_weapon(staff)
	print("You can't buy the Staff as a weapon for yourself: %s, owned=%s (expected false, false)" % [bought_as_player, player.owned_weapons.has("staff_fine_steel")])
	var base_before: String = player.current_weapon_base.get("id", "")
	player._equip_weapon(staff)
	print("...and can't equip it either: weapon still %s (expected %s)" % [player.current_weapon_base.get("id", ""), base_before])
	var bought_for_party: bool = player.try_buy_weapon_for_party(staff)
	print("Buying it FOR THE PARTY works, takes the price, and doesn't equip it: bought=%s coins_spent=%d (expected true, %d), still %s" % [bought_for_party, coins_before - player.coins, player.get_weapon_price(staff), player.current_weapon_base.get("id", "")])
	print("...a second purchase of the same one is refused: %s (expected false)" % [player.try_buy_weapon_for_party(staff)])

	# =========================================================
	# Who may hold what
	# =========================================================
	player.party.clear()
	player.max_party_slots = 4
	var druid = player.recruit("druid")
	var guardian = player.recruit("guardian")
	var wolf = player.recruit("wolf")
	print("Recruited a Druid, a Guardian and a Wolf: %d members (expected 3)" % [player.party.size()])
	print("A wolf carries nothing: can_carry=%s, slots=%d (expected false, 0)" % [wolf.can_carry_gear(), wolf.talisman_slot_count()])
	print("...equip refused: %s (expected false)" % [player.equip_ally_weapon(wolf, "club")])
	print("A weapon you don't own is refused: %s / %s (expected false, You don't own that weapon.)" % [player.equip_ally_weapon(druid, "spear_masterwork_gold"), player.ally_weapon_block_reason(druid, "spear_masterwork_gold")])
	print("The Druid takes the Staff: %s, wielding %s (expected true, staff_fine_steel)" % [player.equip_ally_weapon(druid, "staff_fine_steel"), druid.weapon_id()])
	print("The Guardian can't take it too: %s -- %s (expected false, Druid is using it.)" % [player.equip_ally_weapon(guardian, "staff_fine_steel"), player.ally_weapon_block_reason(guardian, "staff_fine_steel")])
	print("...the holder lookup agrees: %s (expected Druid)" % [player.weapon_holder("staff_fine_steel").name])
	player.owned_weapons["club"] = true
	print("The Club is shareable: druid=%s guardian=%s (expected true, true)" % [player.equip_ally_weapon(druid, "club"), player.equip_ally_weapon(guardian, "club")])
	player.equip_ally_weapon(druid, "staff_fine_steel")
	var spear: Dictionary = weapons.get_owned_variant("spear_fine_steel")
	player.owned_weapons["spear_fine_steel"] = true
	player.equip_ally_weapon(guardian, "spear_fine_steel")
	print("The Guardian wields the spear: %s (expected spear_fine_steel)" % [guardian.weapon_id()])
	player.try_buy_weapon(spear)
	print("You equip that same spear -- you have the final say, it leaves the Guardian: guardian=%s player=%s (expected '', spear_fine_steel)" % [guardian.weapon_id(), player.current_weapon_base.get("id", "")])
	print("...and you can't give it to a member while you use it: %s (expected You are using it.)" % [player.ally_weapon_block_reason(guardian, "spear_fine_steel")])
	player.unequip_ally_weapon(druid)
	print("Unequipping frees it: druid=%s holder=%s (expected '', <null>)" % [druid.weapon_id(), player.weapon_holder("staff_fine_steel")])

	# talismans
	player.owned_talismans["ember_charm"] = true
	player.owned_talismans["wolf_fang"] = true
	player.owned_talismans["moss_charm"] = true
	player.equipped_talismans.clear()
	print("Members have 2 talisman slots from the start whatever their level (4 for the Shaman): %s (expected [2, 2, 2, 2, 4])" % [[rules.talisman_slots("druid", 1), rules.talisman_slots("druid", 4), rules.talisman_slots("druid", 8), rules.talisman_slots("druid", 12), rules.talisman_slots("shaman", 1)]])
	print("A level-1 Druid has two slots: %d (expected 2)" % [druid.talisman_slot_count()])
	print("She wears Ember Charm: %s (expected true)" % [player.equip_ally_talisman(druid, "ember_charm")])
	print("A second one fits: %s (expected true)" % [player.equip_ally_talisman(druid, "wolf_fang")])
	print("A third doesn't: %s -- %s (expected false, No free slot.)" % [player.equip_ally_talisman(druid, "moss_charm"), player.ally_talisman_block_reason(druid, "moss_charm")])
	print("The Guardian can't wear what the Druid wears: %s (expected Druid is wearing it.)" % [player.ally_talisman_block_reason(guardian, "ember_charm")])
	print("She can't wear it twice: %s (expected Already worn.)" % [player.ally_talisman_block_reason(druid, "ember_charm")])
	player.equipped_talismans.append("moss_charm")
	print("Nor can a member wear what YOU wear: %s (expected You are wearing it.)" % [player.ally_talisman_block_reason(guardian, "moss_charm")])
	player.equipped_talismans.clear()
	var equipped_ok: bool = player.equip_talisman("ember_charm")
	print("You put on the Ember Charm -- it comes off the Druid: you=%s druid_still=%s (expected true, false)" % [equipped_ok, druid.talisman_ids().has("ember_charm")])
	print("Effects of what she still wears (Wolf Fang): %s (expected {wolf_slot: 1, ...})" % [druid.talisman_effects().get("wolf_slot", 0.0)])
	print("Unequipping works: %s then %s (expected true, false)" % [player.unequip_ally_talisman(druid, "wolf_fang"), player.unequip_ally_talisman(druid, "wolf_fang")])

	# =========================================================
	# Favours and the member's own weapon
	# =========================================================
	print("The Druid favours the Staff (magic x1.15): %s / other weapons: %s (expected 1.15, {})" % [rules.favour_for("druid", "staff").get("magic_mult", 0.0), rules.favour_for("druid", "club")])
	print("A kind with no favour gets none: %s (expected {})" % [rules.favour_for("guardian", "staff")])
	var mods: Dictionary = druid.effect_mods("staff")
	print("effect_mods leaves the structural favour keys out: has_magic_mult=%s has_weapon=%s (expected false, false)" % [mods.has("magic_mult"), mods.has("weapon")])

	player.owned_weapons["staff_fine_steel"] = true
	player.equip_ally_weapon(druid, "staff_fine_steel")
	var druid_weapon: Dictionary = player.build_ally_weapon(druid)
	print("A member's weapon is rebuilt from its id: %s (expected Staff), uses_magic=%s" % [druid_weapon.get("name", "?"), druid_weapon.get("uses_magic", false)])
	player.unequip_ally_weapon(druid)
	print("With no weapon it fights bare-handed: %s (expected {damage_mult: 1.0})" % [player.build_ally_weapon(druid)])

	var plain_staff: Dictionary = weapons.get_owned_variant("staff_fine_steel")
	var stamped: Dictionary = player._apply_talisman_to_weapon(plain_staff, {"special_stamina_flat_reduction": 5.0})
	var costs := []
	for s in stamped.specials:
		costs.append(s.stamina_cost)
	print("A member's own talismans cheapen ITS specials (-5 flat): %s (expected [35, 55, 15])" % [costs])
	var untouched := []
	for s in plain_staff.specials:
		untouched.append(s.stamina_cost)
	print("...without touching the shared weapon data: %s (expected [40, 60, 20])" % [untouched])
	player.meta_double_hit_chance = 0.1
	player.meta_lifesteal_pct = 0.05
	player.owned_weapons["club"] = true
	player.equip_ally_weapon(guardian, "club")
	var club_ally: Dictionary = player.build_ally_weapon(guardian)
	print("The Astral weapon passives reach a member's weapon: double_hit=%.2f lifesteal=%.2f (expected 0.10, 0.05)" % [club_ally.get("passive_double_hit_chance", 0.0), club_ally.get("passive_lifesteal_pct", 0.0)])
	print("...and the shared Club const stays clean: %s (expected false)" % [weapons.CLUB.has("passive_double_hit_chance")])
	player.meta_double_hit_chance = 0.0
	player.meta_lifesteal_pct = 0.0

	quit()
