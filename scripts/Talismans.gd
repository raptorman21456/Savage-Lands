extends Node
class_name Talismans

# Talismans: small charms sold by the town Seer, each granting one passive
# effect while EQUIPPED. You can own as many as you like, but only a few slots
# are open at once -- and slots grow with player level (SLOT_LEVELS).
#
# Every talisman is {id, name, rarity, price, effects: {key: value}, description,
# icon}. `effects` uses a small fixed key vocabulary; Player.talisman_bonus(key)
# sums a key across everything equipped, and each key is read at exactly one
# place in the game (listed next to it below), so adding a talisman never means
# touching combat code -- only picking keys from this list.
#
#   damage_pct              +x% damage dealt (Main.gd damage calc); negative
#                           values work too (Duelist's Coin)
#   crit_chance             +x crit chance
#   crit_damage_mult_bonus  +x added to the crit multiplier (2.0 base -- see
#                           Player.crit_damage_mult)
#   low_hp_damage_pct       +x% damage while at or below the low-HP threshold
#                           (same gate as the Last Stand-style skill node)
#   low_hp_threshold        overrides that threshold (default 30% of max HP,
#                           see Player.low_hp_threshold) -- a SMALLER value is
#                           riskier, not safer
#   burn_chance             chance per landed hit to set the target on fire
#   burn_chance_multihit    the same, for hits from a multi-hit action (a much
#                           smaller number, since those land several hits per
#                           use -- see is_multihit in Main.gd:_apply_single_hit)
#   first_attack_damage_pct +x% damage on the first hit landed each battle,
#                           by the player OR an ally, whichever comes first
#   traitor_wolf_chance_pct relative bump to how often a spawned Wolf is a
#                           Traitor Wolf (0.25 = 25% more often, not +25 points)
#   wolf_recruit_chance_min floor on a fallen Traitor Wolf's chance to join
#                           your pack (only ever raises it, never lowers it)
#   special_stamina_discount  -x% stamina cost on specials (stamped at equip).
#                           Reserved: Duelist's Coin used to carry this, no
#                           current talisman does -- the Player.gd hook
#                           (_apply_talisman_to_weapon) is still live for
#                           whichever one picks it up next.
#   break_reduction         -x% weapon break chance (stamped at equip).
#                           Reserved the same way -- Whetstone Pendant used to
#                           carry this.
#   arrow_unlimited         1 = no cap on carried special arrows
#   arrow_price_pct         +x% to special-arrow prices
#   damage_reduction        +x damage reduction (added to armour + clothes).
#                           Reserved: Stone Amulet used to carry this, no
#                           current talisman does.
#   material_passive_boost  1 = amplifies whichever weapon-material passive
#                           (Weapons.gd:MATERIALS) is active for your current
#                           weapon -- see the material_id checks in
#                           Main.gd:_apply_single_hit/_battle_perform_attack
#   max_hp                  +n max HP (applied in Player._recalc_stats).
#                           Reserved: Turtle Shell used to carry this, no
#                           current talisman does.
#   dodge_chance            +x dodge chance. Reserved: Wind Chime used to
#                           carry this, no current talisman does.
#   block_heal              +n HP healed on Defend. Reserved: Guardian Knot
#                           used to carry this, no current talisman does.
#   survive_lethal          x chance to survive a killing blow at 1 HP (once
#                           per battle, alongside the Favour skill node)
#   fall_reduction          -x% cliff-fall damage, 1.0 = immune
#   ignore_ledge_attack     1 = can attack up a ledge/cliff drop with any
#                           weapon, not just something long_range
#   water_push_prompt       1 = the current can't sweep you off a water tile
#                           without asking first (Main.gd:_prompt_water_push)
#   ally_defense_pct        +x% damage reduction for every ally (their only
#                           reduction source -- see _enemy_apply_damage)
#   taunt_confusion         1 = Taunt enrages instead of drawing focus: each
#                           enemy attacks whichever combatant (player, ally,
#                           or another enemy) is nearest to IT
#   hp_regen_turn           +n HP at the start of each of your battle turns
#   heal_pct                +x% to all healing from potions and food
#   heal_on_kill            +n HP whenever an enemy dies
#   stamina_regen           +n stamina regained per battle turn
#   max_stamina             +n max stamina. Reserved: Deep Lung Charm used to
#                           carry this, no current talisman does.
#   special_stamina_flat_reduction  -n stamina cost on every weapon special
#                           (stamped at equip, floored at 1 -- see
#                           Player.gd:_apply_talisman_to_weapon)
#   luck                    +x luck (weapon tier rolls)
#   coin_pct                +x% coins found
#   shop_discount           -x off shop prices
#   windfall_chance         +x chance of a bonus-coin windfall on each kill.
#                           Reserved: Gilded Scarab used to carry this, no
#                           current talisman does.
#   attack_per_coin         +x flat attack power per coin currently held
#                           (Player.coin_scaled_attack_bonus, read live)
#   defense_per_coin        +x damage reduction per coin currently held
#                           (Player.coin_scaled_defense_bonus, read live --
#                           the overall 90% reduction cap still applies)
#   coins_per_kill          +n coins per kill (still summed with the War
#                           Profiteer skill node, see Player.coins_per_kill).
#                           Reserved: Tax Collector's Seal used to carry
#                           this, no current talisman does.
#   coin_drop_chance        +x chance for any landed hit (not on a boss-tier
#                           enemy) to drop an extra coin
#   xp_pct                  +x% XP gained
#   move_speed_pct          +x% overworld move speed
#   move_range              +n battle movement range. Reserved: Pathfinder's
#                           Compass used to carry this, no current talisman
#                           does.
#   reveal_all_locations    1 = every town/outskirts venue shows on the Map
#                           tab immediately, bypassing the normal
#                           visit-it-first requirement (Player.discovered_
#                           locations, InventoryPanel.gd:_on_map_draw)
#   gambling_luck           +x better odds at the Wishing Well and the races
#   phoenix                 1 = once per run, survive a killing blow at 1 HP
#   fishing_luck            +x bigger bite window and rarer catches at the pond

# The player levels at which the 2nd, 3rd and 4th slots open (the 1st is
# always available).
const SLOT_LEVELS := [4, 8, 12]

const RARITY_WEIGHTS := {"common": 50, "uncommon": 30, "rare": 15, "epic": 5}
const RARITY_COLORS := {
	"common": Color(0.85, 0.85, 0.8),
	"uncommon": Color(0.45, 0.85, 0.45),
	"rare": Color(0.45, 0.65, 1.0),
	"epic": Color(0.85, 0.5, 1.0),
}

static var ITEMS := [
	# --- Offense ---
	{"id": "ember_charm", "name": "Ember Charm", "rarity": "common", "price": 70,
		"effects": {"burn_chance": 0.10, "burn_chance_multihit": 0.02},
		"description": "10% chance for any attack to set the target on fire (2% per hit on multi-hit moves). No extra damage."},
	{"id": "wolf_fang", "name": "Wolf Fang", "rarity": "common", "price": 70,
		"effects": {"traitor_wolf_chance_pct": 0.25, "wolf_recruit_chance_min": 0.30},
		"description": "Traitor Wolves replace ordinary wolves 25% more often, and are at least 30% likely to join your pack when they fall."},
	{"id": "berserkers_knot", "name": "Berserker's Knot", "rarity": "uncommon", "price": 110,
		"effects": {"low_hp_damage_pct": 1.0, "low_hp_threshold": 0.20},
		"description": "+100% damage while at or below 20% HP."},
	{"id": "duelists_coin", "name": "Duelist's Coin", "rarity": "uncommon", "price": 110,
		"effects": {"damage_pct": -0.15, "crit_chance": 0.05, "crit_damage_mult_bonus": 0.5},
		"description": "-15% damage on every hit, but critical hits deal 250% damage and are 5% more likely to land."},
	{"id": "whetstone_pendant", "name": "Whetstone Pendant", "rarity": "common", "price": 60,
		"effects": {"first_attack_damage_pct": 0.33},
		"description": "Whoever lands the first hit each battle -- you or an ally -- deals 33% more damage with it."},
	{"id": "fletchers_ring", "name": "Fletcher's Ring", "rarity": "common", "price": 60,
		"effects": {"arrow_unlimited": 1, "arrow_price_pct": 0.10},
		"description": "No limit on carried special arrows, but they cost 10% more."},
	# --- Defense ---
	{"id": "stone_amulet", "name": "Stone Amulet", "rarity": "uncommon", "price": 120,
		"effects": {"material_passive_boost": 1},
			"description": "Strengthens whichever material your current weapon is forged from -- its passive trait hits noticeably harder or more often."},
	{"id": "turtle_shell", "name": "Turtle Shell", "rarity": "common", "price": 70,
		"effects": {"water_push_prompt": 1},
		"description": "The current can't sweep you off a water tile without asking first."},
	{"id": "wind_chime", "name": "Wind Chime", "rarity": "uncommon", "price": 90,
		"effects": {"taunt_confusion": 1},
		"description": "Your Taunt enrages the enemy past reason -- instead of converging on you, each one attacks whoever's nearest, even each other."},
	{"id": "guardian_knot", "name": "Guardian Knot", "rarity": "common", "price": 70,
		"effects": {"ally_defense_pct": 0.20},
		"description": "Your allies take 20% less damage."},
	{"id": "iron_will_band", "name": "Iron Will Band", "rarity": "rare", "price": 90,
		"effects": {"survive_lethal": 0.10}, "description": "10% chance to survive a killing blow with 1 HP (once a battle)."},
	{"id": "cliffwalkers_bead", "name": "Cliffwalker's Bead", "rarity": "common", "price": 50,
		"effects": {"fall_reduction": 1.0, "ignore_ledge_attack": 1},
		"description": "Cliff falls deal no damage, and you can attack up a ledge or cliff drop with any weapon."},
	# --- Sustain ---
	{"id": "moss_charm", "name": "Moss Charm", "rarity": "uncommon", "price": 55,
		"effects": {"hp_regen_turn": 1}, "description": "Regain 1 HP at the start of each of your battle turns."},
	{"id": "healers_knot", "name": "Healer's Knot", "rarity": "common", "price": 35,
		"effects": {"heal_pct": 0.25}, "description": "Potions and food heal 25% more."},
	{"id": "bloodstone", "name": "Bloodstone", "rarity": "uncommon", "price": 60,
		"effects": {"heal_on_kill": 3}, "description": "Heal 3 HP whenever an enemy falls."},
	{"id": "second_wind_whistle", "name": "Second Wind Whistle", "rarity": "common", "price": 40,
		"effects": {"stamina_regen": 3}, "description": "Regain 3 extra stamina each battle turn."},
	{"id": "deep_lung_charm", "name": "Deep Lung Charm", "rarity": "common", "price": 70,
		"effects": {"special_stamina_flat_reduction": 5},
		"description": "Every weapon special costs 5 less stamina."},
	# --- Economy ---
	{"id": "lucky_clover", "name": "Lucky Clover", "rarity": "uncommon", "price": 110,
		"effects": {"luck": 0.50},
		"description": "+0.50 luck: dramatically better weapon tiers in the shop."},
	{"id": "merchants_coin", "name": "Merchant's Coin", "rarity": "common", "price": 40,
		"effects": {"coin_pct": 0.10}, "description": "+10% coins from every source."},
	{"id": "hagglers_tooth", "name": "Haggler's Tooth", "rarity": "uncommon", "price": 65,
		"effects": {"shop_discount": 0.10}, "description": "-10% off every shop price."},
	{"id": "gilded_scarab", "name": "Gilded Scarab", "rarity": "common", "price": 70,
		"effects": {"attack_per_coin": 0.125, "defense_per_coin": 0.1},
		"description": "+0.125 attack power and +0.1 damage reduction for every coin you're currently holding -- the more you hoard, the stronger you get."},
	{"id": "tax_collectors_seal", "name": "Tax Collector's Seal", "rarity": "rare", "price": 160,
		"effects": {"coin_drop_chance": 0.20},
		"description": "20% chance for any landed hit to drop an extra coin (bosses excluded)."},
	# --- Utility ---
	{"id": "scholars_quill", "name": "Scholar's Quill", "rarity": "common", "price": 45,
		"effects": {"xp_pct": 0.15}, "description": "+15% experience gained."},
	{"id": "swift_feather", "name": "Swift Feather", "rarity": "common", "price": 60,
		"effects": {"move_speed_pct": 0.35}, "description": "+35% movement speed in the field."},
	{"id": "pathfinders_compass", "name": "Pathfinder's Compass", "rarity": "rare", "price": 100,
		"effects": {"reveal_all_locations": 1},
		"description": "Every town and outskirts venue shows on your map immediately, instead of only once you've actually found it."},
	{"id": "gamblers_die", "name": "Gambler's Die", "rarity": "uncommon", "price": 45,
		"effects": {"gambling_luck": 0.05}, "description": "Better odds at the Wishing Well and the horse races."},
	{"id": "anglers_hook", "name": "Angler's Hook", "rarity": "rare", "price": 60,
		"effects": {"fishing_luck": 0.25}, "description": "A wider bite window and rarer catches at the fishing hole."},
	{"id": "phoenix_ash", "name": "Phoenix Ash", "rarity": "epic", "price": 140,
		"effects": {"phoenix": 1}, "description": "Once per run, survive a killing blow with 1 HP."},
]

static func get_talisman(id: String) -> Dictionary:
	for item in ITEMS:
		if item.id == id:
			return _with_icon(item)
	return {}

# Every entry carries an icon stem derived from its rarity (one generated
# gem-charm icon per rarity -- see gen_sprites.gd:make_icon_talisman).
static func _with_icon(item: Dictionary) -> Dictionary:
	if item.has("icon"):
		return item
	var copy: Dictionary = item.duplicate()
	copy.icon = "talisman_%s" % item.rarity
	return copy

# How many talismans a player of this level can have equipped at once.
static func slots_for_level(level: int) -> int:
	var slots := 1
	for required in SLOT_LEVELS:
		if level >= required:
			slots += 1
	return slots

# The level at which slot number `slot` (1-based) opens; 1 for the first.
static func level_for_slot(slot: int) -> int:
	if slot <= 1:
		return 1
	return SLOT_LEVELS[mini(slot - 2, SLOT_LEVELS.size() - 1)]

# Draws `count` distinct talisman ids the player doesn't own yet, weighted by
# rarity (RARITY_WEIGHTS). Returns fewer if fewer remain. `rng` lets tests
# make the roll deterministic.
static func roll_stock(count: int, owned: Dictionary, rng: RandomNumberGenerator = null) -> Array:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var pool: Array = []
	for item in ITEMS:
		if not owned.has(item.id):
			pool.append(item)
	var result := []
	while result.size() < count and not pool.is_empty():
		var total := 0.0
		for item in pool:
			total += RARITY_WEIGHTS[item.rarity]
		var roll := rng.randf() * total
		var picked := 0
		for i in pool.size():
			roll -= RARITY_WEIGHTS[pool[i].rarity]
			if roll <= 0.0:
				picked = i
				break
		result.append(pool[picked].id)
		pool.remove_at(picked)
	return result
