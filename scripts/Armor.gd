extends Node
class_name Armor

# Body armour. Fourteen kinds, each with its own way of playing -- not a ladder any more. Every
# entry carries:
#   damage_reduction  points of Defense against BODILY harm (weapons, claws, arrows...), written as a
#                     fraction (0.30 = 30 points); the key other code has always read, plus Blacksmith
#                     levels for metal armour. Points are pooled with Resilience and the shield and bent
#                     into a cut by Defense.gd (diminishing returns, never past 80%).
#   fortitude         points of protection against MAGICAL harm, on the same curve (see
#                     Player.fortitude_reduction). May be negative: Thornmail's spikes make you
#                     easier to burn with spells.
#   fall_damage_mult  scales cliff-fall damage (1.0 normal, 0.0 none).
#   trait / trait_params  the armour's signature effect and drawback, read at the combat sites
#                     named next to each trait below (Player.armor_trait / armor_trait_value).
#   metal             the Blacksmith will upgrade it (+2.5 Defense per level).
#   recipe            pelt armours are crafted, not bought: {"materials": {id: n}, "coins": n}
#                     (Materials.gd; the Blacksmith's Craft tab). They are the ones with the most
#                     Fortitude.
#   icon              assets/ stem; a sprite named after the armour's id (armor_stonehide.png...)
#                     is used automatically once the art exists, see icon_path().
#
# Every number here is a DRAFT for the user to tune. The statuses (burn, poison, bleeding...) are
# never reduced or prevented by armour -- they are flat damage and nothing stops them.
#
# Trait ids and where they act:
#   fortress     move_bonus -1, push_immune          Main.gd:_battle_player_move_range, Player.shield_push_immune
#   stonehide    flat_reduction 3                    Main.gd:_reduce_bodily
#   bastion      defend_threshold_bonus 8, defend_stamina_bonus 10   Main.gd Defend / Taunt
#   martyr       bodily_per_10_missing 0.03          Main.gd:_reduce_bodily
#   thorns       reflect_pct 0.30                    Main.gd:_land_enemy_hit_on_player
#   cinder       ignites melee attackers, max_stamina_bonus -10      Main.gd:_land_enemy_hit_on_player, Player
#   bloodrage    stacks 5, dmg_per_stack 0.10, turns 2               Main.gd:_apply_single_hit
#   shadowweave  dodge_bonus 0.10, then a crit        Player.dodge_chance_total, Main.gd
#   windrunner   move_bonus +1, speed_bonus +2        Main.gd:_battle_player_move_range
#   spellward    first magic hit negated, +10 stamina per magic hit  Main.gd:_reduce_magical
#   warden       ally_reduction 0.15 within 2 tiles   Main.gd:_enemy_apply_damage

static var TIERS := [
	{
		"id": "armor_rags", "name": "Rags", "price": 0,
		"damage_reduction": 0.0, "fortitude": 0, "fall_damage_mult": 1.0,
		"trait": "", "trait_params": {},
		"description": "No protection of any kind.",
		"shop_description": "Technically clothing. I wouldn't call it armor, but it's free.",
		"icon": "armor_rags",
	},
	{
		"id": "armor_gambeson", "name": "Gambeson", "price": 20,
		"damage_reduction": 0.15, "fortitude": 5, "fall_damage_mult": 1.0,
		"trait": "", "trait_params": {},
		"description": "+15 Defense, +5 Fortitude. A quilted coat: nothing fancy, and nothing missing either.",
		"shop_description": "A step up from bare skin. Modest, but modest beats dead.",
		"icon": "armor_leather", "icon_fallback": "armor_leather",
	},
	{
		"id": "armor_thornmail", "name": "Thornmail", "price": 85, "metal": true,
		"damage_reduction": 0.30, "fortitude": -5, "fall_damage_mult": 1.0,
		"trait": "thorns", "trait_params": {"reflect_pct": 0.30},
		"description": "+30 Defense, -5 Fortitude. 30% of the damage a melee attacker deals to you is thrown straight back. Ranged and magical attacks sail past the spikes, and spells hurt a little more.",
		"shop_description": "Hit it and you'll wish you hadn't. Spells don't mind it nearly as much.",
		"icon": "armor_steel", "icon_fallback": "armor_steel",
	},
	{
		"id": "armor_fortress", "name": "Fortress Plate", "price": 90, "metal": true, "high_grade": true,
		"damage_reduction": 0.55, "fortitude": 0, "fall_damage_mult": 1.5,
		"trait": "fortress", "trait_params": {"move_bonus": -1, "push_immune": true},
		"description": "+55 Defense, 0 Fortitude. Nothing sweeps you off a water tile -- but you move 1 tile less, and cliff falls deal 50% more damage.",
		"shop_description": "Stops almost anything short. Just don't trip near a cliff wearing it.",
		"icon": "armor_steel", "icon_fallback": "armor_steel",
	},
	{
		"id": "armor_dragonskin", "name": "Dragonskin Plating", "price": 160, "high_grade": true,
		"damage_reduction": 0.45, "fortitude": 35, "fall_damage_mult": 0.0,
		"trait": "", "trait_params": {},
		"recipe": {"materials": {"dragon_scale": 8}, "coins": 120},
		"description": "+45 Defense, +35 Fortitude, and cliff falls deal no damage at all. Scaled by hand from something that shouldn't have died so easily.",
		"shop_description": "Don't ask where I got this. Just know it used to be attached to something much bigger than you.",
		"icon": "armor_dragonskin", "icon_fallback": "armor_dragonskin",
	},
	{
		"id": "armor_stonehide", "name": "Stonehide Mail", "price": 60, "metal": true,
		"damage_reduction": 0.10, "fortitude": 5, "fall_damage_mult": 1.0,
		"trait": "stonehide", "trait_params": {"flat_reduction": 3},
		"description": "+10 Defense, +5 Fortitude, and every bodily hit that lands does 3 less damage (never below 1). A wall against goblin packs; a big single blow shrugs it off.",
		"shop_description": "Small hits just stop mattering. Big ones, well. Let's not talk about the big ones.",
		"icon": "armor_iron", "icon_fallback": "armor_iron",
	},
	{
		"id": "armor_bastion", "name": "Bastion Mail", "price": 80, "metal": true,
		"damage_reduction": 0.25, "fortitude": 5, "fall_damage_mult": 1.0,
		"trait": "bastion", "trait_params": {"defend_threshold_bonus": 8, "defend_stamina_bonus": 10},
		"description": "+25 Defense, +5 Fortitude. Built for bracing: Defend negates hits 8 points bigger than usual, and Defend and Taunt give back 10 more stamina. Nothing special unless you brace.",
		"shop_description": "Plant your feet and let them come. It's meant for exactly that.",
		"icon": "armor_iron", "icon_fallback": "armor_iron",
	},
	{
		"id": "armor_martyr", "name": "Martyr's Mantle", "price": 75,
		"damage_reduction": 0.05, "fortitude": 10, "fall_damage_mult": 1.0,
		"trait": "martyr", "trait_params": {"bodily_per_10_missing": 0.03},
		"description": "+5 Defense, +10 Fortitude, and a further +3 Defense for every 10% of your HP you're missing. Frail at full health; stubborn when you're not.",
		"shop_description": "It hardens with every wound. I'd rather not say how I know.",
		"icon": "armor_rags", "icon_fallback": "armor_rags",
	},
	{
		"id": "armor_cinder", "name": "Cinder Mail", "price": 100, "metal": true,
		"damage_reduction": 0.25, "fortitude": 10, "fall_damage_mult": 1.0,
		"trait": "cinder", "trait_params": {"ignite_melee": true, "max_stamina_bonus": -10},
		"description": "+25 Defense, +10 Fortitude. Whatever hits you in melee catches fire. The heat wears you down: -10 max stamina.",
		"shop_description": "Still warm from the forge. Stays that way, somehow.",
		"icon": "armor_iron", "icon_fallback": "armor_iron",
	},
	{
		"id": "armor_bloodrage", "name": "Bloodrage Hide", "price": 70,
		"damage_reduction": 0.10, "fortitude": 26, "fall_damage_mult": 1.0,
		"trait": "bloodrage", "trait_params": {"max_stacks": 5, "dmg_per_stack": 0.10, "turns": 2},
		"recipe": {"materials": {"mage_hair": 3, "bear_pelt": 3}, "coins": 40},
		"description": "+10 Defense, +26 Fortitude. Every hit you take stacks +10% damage dealt (up to 5 stacks, lasting 2 turns). Thin protection for a short temper.",
		"shop_description": "It remembers every blow. And returns them.",
		"icon": "armor_leather", "icon_fallback": "armor_leather",
	},
	{
		"id": "armor_shadowweave", "name": "Shadowweave", "price": 110,
		"damage_reduction": 0.05, "fortitude": 30, "fall_damage_mult": 1.0,
		"trait": "shadowweave", "trait_params": {"dodge_bonus": 0.10},
		"recipe": {"materials": {"spider_silk": 6}, "coins": 60},
		"description": "+5 Defense, +30 Fortitude, +10% dodge, and a dodge makes your next attack a crit. Anything that does land hurts.",
		"shop_description": "You won't even feel it. Neither will they -- until it's too late.",
		"icon": "armor_leather", "icon_fallback": "armor_leather",
	},
	{
		"id": "armor_windrunner", "name": "Windrunner's Jerkin", "price": 95,
		"damage_reduction": 0.10, "fortitude": 28, "fall_damage_mult": 0.0,
		"trait": "windrunner", "trait_params": {"move_bonus": 1, "speed_bonus": 2},
		"recipe": {"materials": {"feather": 5}, "coins": 50},
		"description": "+10 Defense, +28 Fortitude, +1 move tile, +2 Speed (it moves you up the turn order), and cliff falls deal no damage. Very thin.",
		"shop_description": "Light enough to forget you're wearing it. Fast enough to forget they were chasing you.",
		"icon": "armor_leather", "icon_fallback": "armor_leather",
	},
	{
		"id": "armor_spellward", "name": "Spellward Robes", "price": 120,
		"damage_reduction": 0.05, "fortitude": 25, "fall_damage_mult": 1.0,
		"trait": "spellward", "trait_params": {"magic_hit_stamina": 10},
		"description": "+5 Defense, +25 Fortitude. The first magical hit of every battle is negated outright, and each magical hit that reaches you gives back 10 stamina. Almost no protection against steel.",
		"shop_description": "Stitched with wards by someone who clearly hated wizards.",
		"icon": "armor_rags", "icon_fallback": "armor_rags",
	},
	{
		"id": "armor_warden", "name": "Warden's Aegis", "price": 130, "metal": true,
		"damage_reduction": 0.20, "fortitude": 5, "fall_damage_mult": 1.0,
		"trait": "warden", "trait_params": {"ally_reduction": 0.15, "ally_radius": 2},
		"description": "+20 Defense, +5 Fortitude. Allies within 2 tiles of you take 15% less damage.",
		"shop_description": "Made for standing in front of other people.",
		"icon": "armor_steel", "icon_fallback": "armor_steel",
	},
]

# "metal" tags the plate armours the town Blacksmith will upgrade (Blacksmith.gd) -- he won't
# work cloth, hide or dragonskin.
static func is_metal(id: String) -> bool:
	return bool(find(id).get("metal", false))

# The armour with this id, or {}.
static func find(id: String) -> Dictionary:
	for tier in TIERS:
		if tier.id == id:
			return tier
	return {}

# Pelt armours are crafted from enemy drops instead of bought.
static func is_crafted(armor: Dictionary) -> bool:
	return armor.has("recipe")

# What the shop can roll: everything that is not crafted.
static func shop_pool() -> Array:
	return TIERS.filter(func(a): return not a.has("recipe"))

# Returns the first armour not yet owned (kept for the older callers), or an empty Dictionary.
static func get_next_tier(owned_armor: Dictionary) -> Dictionary:
	for tier in TIERS:
		if not owned_armor.has(tier.id):
			return tier
	return {}

# Position of an armour in TIERS, found by id -- the shop hands out tagged COPIES of these entries
# (Main._tagged adds a "category" key), which never compare equal to the originals. -1 if unknown.
static func tier_rank(armor: Dictionary) -> int:
	var id: String = armor.get("id", "")
	for i in TIERS.size():
		if TIERS[i].id == id:
			return i
	return -1

# The art for an armour: a sprite named after its id once someone has drawn one, otherwise the
# stand-in it shares with a similar armour.
static func icon_path(armor: Dictionary) -> String:
	var own := "res://assets/%s.png" % str(armor.get("id", ""))
	if ResourceLoader.exists(own):
		return own
	return "res://assets/%s.png" % str(armor.get("icon_fallback", armor.get("icon", "armor_rags")))
