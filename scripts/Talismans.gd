extends Node
class_name Talismans

# Talismans: small charms sold by the town Seer (all but four, which are FOUND in the world and never sold: Ember
# Charm in the Lava Causeway, Wildfire Core in the Crater, Stone Amulet in the Old Mine and Lucky Clover by luck on the
# Great Expanse -- an item with "found": true; see Main.gd's chests), each granting one passive
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
#   wolf_slot               1 = one extra party slot that only a Fickle Wolf can
#                           fill (Player.wolf_only_slots)
#   wolf_stay_bonus         extra battles of loyalty for a newly recruited wolf
#   special_stamina_discount  -x% stamina cost on specials (stamped at equip).
#                           Reserved: Duelist's Coin used to carry this, no
#                           current talisman does -- the Player.gd hook
#                           (_apply_talisman_to_weapon) is still live for
#                           whichever one picks it up next.
#   break_reduction         -x% weapon break chance (stamped at equip).
#                           Reserved the same way -- Whetstone used to
#                           carry this.
#   arrow_unlimited         1 = no cap on carried special arrows
#   arrow_price_pct         +x% to special-arrow prices
#   damage_reduction        +x damage reduction (added to armour + clothes).
#                           Reserved: Stone Amulet used to carry this, no
#                           current talisman does.
#   ember_burn              1 = a burn this player inflicts through burn_chance
#                           uses the Pyrogenesis Organ formula (5 + attack/5, then
#                           x0.7 per turn, rounded up) instead of a share of
#                           the target's max HP (Main.gd:_ignite_with_ember)
#   double_secondary_chance 1 = every on-hit proc chance is doubled (capped at
#                           100%) -- Main.gd:_proc, Player.secondary_chance_mult
#   material_passive_boost  1 = Stone Amulet: doubles whichever weapon material
#                           the current weapon is forged from -- its dmg/price/
#                           stamina deviation from 1.0, its break chance and its
#                           passive -- see Player._apply_talisman_to_weapon and
#                           the material_id checks in Main.gd:_apply_single_hit
#                           /_battle_perform_attack
#   max_hp                  +n max HP (applied in Player._recalc_stats).
#                           Reserved: Turtle Shell used to carry this, no
#                           current talisman does.
#   dodge_chance            +x dodge chance. Reserved: Wind Chime used to
#                           carry this, no current talisman does.
#   block_heal              +n HP healed on Defend. Reserved: BFF Bracelet
#                           used to carry this, no current talisman does.
#   survive_lethal          x chance to survive a killing blow at 1 HP (once
#                           per battle, alongside the Favour skill node)
#   fall_reduction          -x% cliff-fall damage, 1.0 = immune
#   ignore_ledge_attack     1 = can attack up a ledge/cliff drop with any
#                           weapon, not just something long_range
#   water_push_prompt       1 = the current can't sweep you off a water tile
#                           without asking first (Main.gd:_prompt_water_push)
#   ally_defense_pct        +x (as a fraction: 0.40 = +40 points) of Defense and Fortitude for every ally (their only
#                           reduction source -- see _enemy_apply_damage)
#   taunt_confusion         1 = Taunt enrages instead of drawing focus: each
#                           enemy attacks whichever combatant (player, ally,
#                           or another enemy) is nearest to IT
#   hp_regen_turn           +n HP at the start of each of your battle turns
#   hp_regen_per_20_max_hp  +n more of the above per 20 max HP you have
#                           (Player.hp_regen_per_turn)
#   heal_pct                +x% to all healing from potions and food
#   heal_on_kill            +n HP whenever an enemy dies
#   stamina_regen           +n stamina regained per battle turn
#   max_stamina             +n max stamina. Reserved: Protein Bars used to
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
#   damage_pct_per_coin   +x damage (as a fraction: 0.0003 = 0.03%) per coin currently
#                           held (Player.coin_damage_mult, read live -- Gilded Scarab)
#   reduction_per_coin      +x of every incoming blow turned aside per coin held
#                           (Player.coin_reduction, read live; Main.gd caps it at half)
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
#   phoenix                 1 = survive a killing blow on full HP and stamina; the ash is then spent
#                           (leaves the collection and the slot -- Player._try_phoenix)
#   fishing_luck            +x bigger bite window and rarer catches at the pond
#
# --- The doc's 2026-10-30 roster (Player.gd/Main.gd, search the key name for the read site) ---
#   poison_chance           +x chance per landed hit to poison the target (Rusted Edge)
#   random_status_chance    +x chance per landed hit to leave a random negative status (Fake PHD)
#   direct_only             1 = only a direct attack hurts you: burning, poison, bleeding, blasts, falls and
#                           your own stumbles are spared (Honour -- Player.take_battle_damage(indirect))
#   damage_taken_pct        +x (or -x) to every blow that lands on the wearer, hero or member (Thorny Ring +1.0,
#                           BFF Bracelet -0.33 -- Main.gd:_apply_incoming_reductions / _enemy_apply_damage)
#   status_turns_cut        -n turns on every negative status inflicted on the hero (Rebound -- Main._status_len)
#   dot_heals               1 = poison, burning and bleeding heal you instead (Masochist -- Main._hero_dot_damage)
#   heal_per_tile           +n HP for every tile the wearer moves (Fitbit -- Main._fitbit_heal)
#   (allies_only: true on an item = only a party member may wear it; the hero's collection holds it but cannot equip it)
#
# --- Wildcard keys (Player.gd/Main.gd, search the key name for the read site) ---
#   max_hp_pct              +x% (or -x%) to max HP, multiplicative, applied
#                           after the flat max_hp bonus above (_recalc_stats)
#   lifesteal_pct           +x% of damage dealt healed back, on any of the
#                           player's own landed hits
#   disable_healing_items   1 = potions/food no longer have any effect
#                           (use_healing_item/use_specific_potion)
#   momentum_chain          1 = each hit landed without taking damage first
#                           adds +8% damage, uncapped; taking a hit resets it
#                           and costs a turn (battle_momentum_chain_stacks)
#   whirlwind_double_melee  1 = every melee (non-long_range) regular Attack
#                           lands twice (_battle_perform_attack)
#   weapon_whisperer        1 = current_weapon's specials are overridden by
#                           Player.weapon_whisperer_specials, any 3 learned
#                           moves regardless of weapon type (see
#                           _apply_talisman_to_weapon, DojoPanel.gd)
#   special_stamina_pct_increase  +x% stamina cost on every special (stamped
#                           at equip, the inverse of special_stamina_discount)
#   chaos_shard             1 = every landed hit's damage is rerolled to a
#                           random 90%-125% of normal
#   lock_hp_to_one          1 = max HP (and current HP) forced to 1, overriding
#                           every other max-HP source (_recalc_stats)
#   oneshot_regular_enemies 1 = every landed hit instantly kills a non-boss
#                           enemy outright
#   bloodmoon_fang          1 = each hit you land stacks Bloodlust (Player.bloodmoon_stacks,
#                           +5% damage/+7.5% move speed each); 3 turns with
#                           no damage dealt or taken by anyone crashes it
#                           (Player.bloodmoon_debuffed, -50% to combat stats)
#   ironclad_ward           1 = Move only works on alternating player turns
#                           (Main.gd:battle_ironclad_move_allowed); defense
#                           (armor_damage_reduction) is multiplied by 2.5
#   wildfire_core           1 = a burning enemy's death explodes for 3x its
#                           fire damage per turn, damaging and igniting
#                           everything nearby (_trigger_wildfire_explosion)
#
# The Sorcery keys (read only for a unit that casts; every member can wear them, the hero casts nothing):
#   mana_regen_pct          +x of max mana back at the end of each of the unit's turns (HP for the Necromancer) -- Main._end_ally_command
#   spell_cost_pct          spells cost this share less mana (mana-worth: a Necromancer pays that share less HP) -- Main._spell_cost_adjust
#   res_ftd_per_3_mag       +x Resilience and Fortitude for every 3 Magic the unit has (Heavy Cloak) -- Main._make_member_battle_unit
#   spell_potency_pct       +x spell potency, added together with every other source -- Main._potency
#   spell_echo_chance       chance a spell casts a second time, free, with the target chosen again -- Main._after_spell
#   fireball_instant        1 = I CAST FIREBALL needs no charging turn -- Main._resolve_fireball
#   summon_double           1 = every summon (skeletons, spectres) is doubled -- Main._summon_mult
#   spell_clapback_chance   chance a cast spell is followed by a STR + MAG/2 strike on the nearest enemy, spell_clapback_mage_pct more vs a mage

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
	{"id": "ember_charm", "name": "Pyrogenesis Organ", "rarity": "common", "price": 70, "found": true,
		"effects": {"ember_burn": 1},
		"description": "Fire damage you set is now (5 + your attack / 5), then 70% of that again every turn after, rounded up, until it burns out."},
	{"id": "wolf_fang", "name": "Wolf Fang", "rarity": "common", "price": 70,
		"effects": {"traitor_wolf_chance_pct": 0.25, "wolf_recruit_chance_min": 0.30},
		"description": "Traitor Wolves replace ordinary wolves 25% more often, and are at least 30% likely to join your pack when they fall."},
	{"id": "berserkers_knot", "name": "Berserk Brace", "rarity": "uncommon", "price": 110,
		"effects": {"low_hp_damage_pct": 1.0, "low_hp_threshold": 0.20},
		"description": "+100% damage while at or below 20% HP."},
	{"id": "duelists_coin", "name": "Duelist's Coin", "rarity": "uncommon", "price": 110,
		"effects": {"damage_pct": -0.15, "crit_chance": 0.05, "crit_damage_mult_bonus": 0.5},
		"description": "-15% damage on every hit, but critical hits deal 300% damage and are 5% more likely to land."},
	{"id": "rusted_edge", "name": "Rusted Edge", "rarity": "uncommon", "price": 80,
		"effects": {"poison_chance": 0.10},
		"description": "A 10% chance for any hit you land to poison the enemy."},
	{"id": "whetstone_pendant", "name": "Whetstone", "rarity": "common", "price": 60,
		"effects": {"first_attack_damage_pct": 0.50},
		"description": "The first hit its wearer lands each battle deals 50% more damage."},
	{"id": "fake_phd", "name": "Fake PHD", "rarity": "rare", "price": 90,
		"effects": {"random_status_chance": 0.10},
		"description": "A 10% chance for a hit to inflict a random negative status on the enemy."},
	{"id": "honour", "name": "Honour", "rarity": "uncommon", "price": 70,
		"effects": {"direct_only": 1},
		"description": "You take damage only from direct attacks: no burning, poison, bleeding, blasts, falls or hazards."},
	{"id": "thorny_ring", "name": "Thorny Ring", "rarity": "epic", "price": 120,
		"effects": {"damage_pct": 1.0, "damage_taken_pct": 1.0},
		"description": "All damage you give and take is doubled."},
	{"id": "fletchers_ring", "name": "Fletcher's Ring", "rarity": "common", "price": 60,
		"effects": {"arrow_unlimited": 1, "arrow_price_pct": 0.10},
		"description": "No limit on carried special arrows, but they cost 10% more."},
	# --- Defense ---
	{"id": "stone_amulet", "name": "Stone Amulet", "rarity": "uncommon", "price": 120, "found": true,
		"effects": {"material_passive_boost": 1},
		"description": "Doubles what your current weapon's material does -- its damage, price, stamina and break-chance swings from plain steel are all doubled, and so is its passive. Steel itself becomes 1.2x damage at 0.8x price and 0.8x stamina."},
	{"id": "turtle_shell", "name": "Turtle Shell", "rarity": "common", "price": 70,
		"effects": {"water_push_prompt": 1},
		"description": "The current can't sweep you off a water tile without asking first."},
	{"id": "wind_chime", "name": "Wind Chime", "rarity": "uncommon", "price": 90,
		"effects": {"taunt_confusion": 1},
		"description": "Your Taunt enrages the enemy past reason -- instead of converging on you, each one attacks whoever's nearest, even each other, picking randomly on an exact tie."},
	{"id": "guardian_knot", "name": "BFF Bracelet", "rarity": "common", "price": 70, "allies_only": true,
		"effects": {"damage_taken_pct": -0.33},
		"description": "Can only be worn by your allies, who then take 33% less damage."},
	{"id": "iron_will_band", "name": "Iron Will Ring", "rarity": "rare", "price": 90,
		"effects": {"survive_lethal": 0.25}, "description": "25% chance to survive a killing blow with 1 HP (once a battle)."},
	{"id": "rebound", "name": "Rebound", "rarity": "uncommon", "price": 65,
		"effects": {"status_turns_cut": 1},
		"description": "Negative statuses inflicted on you last one turn less."},
	{"id": "masochist", "name": "Masochist", "rarity": "rare", "price": 85,
		"effects": {"dot_heals": 1},
		"description": "Poison, burning and bleeding heal you instead of hurting you."},
	{"id": "cliffwalkers_bead", "name": "Cliffwalker's Beadstring", "rarity": "common", "price": 50,
		"effects": {"fall_reduction": 1.0, "ignore_ledge_attack": 1},
		"description": "Cliff falls deal no damage, and you can attack up a ledge or cliff drop with any weapon."},
	# --- Sorcery (every member can wear them; they only do anything for whoever casts). The design doc's list, 2026-10-27; its prices are "xx", so these are my drafts ---
	{"id": "clapback", "name": "Clapback", "rarity": "rare", "price": 85,
		"effects": {"spell_clapback_chance": 0.20, "spell_clapback_mage_pct": 0.30},
		"description": "Whenever you cast a spell, a 20% chance you also strike the nearest enemy for your STR + half your MAG, with +30% damage if it is a mage."},
	{"id": "heavy_cloak", "name": "Heavy Cloak", "rarity": "common", "price": 55,
		"effects": {"res_ftd_per_3_mag": 1},
		"description": "+1 Resilience and Fortitude for every 3 Magic you have."},
	{"id": "spell_bank", "name": "Spell Bank", "rarity": "uncommon", "price": 70,
		"effects": {"mana_regen_pct": 0.05},
		"description": "Regain 5% of your max mana at the end of each of your turns (the Necromancer heals 5% of her max HP)."},
	{"id": "dreamcatcher", "name": "Dreamcatcher", "rarity": "uncommon", "price": 75,
		"effects": {"spell_cost_pct": 0.33},
		"description": "Spells cost 33% less mana (a Necromancer pays 33% less HP)."},
	{"id": "snail_shell", "name": "Snail Shell", "rarity": "rare", "price": 95,
		"effects": {"spell_potency_pct": 0.25},
		"description": "Spells have +25% potency."},
	{"id": "lingering_echo", "name": "Lingering Echo", "rarity": "common", "price": 60,
		"effects": {"spell_echo_chance": 0.10},
		"description": "10% chance for a spell to cast twice: the second cast is free, and you choose its target again."},
	{"id": "blazing_battery", "name": "Blazing Battery", "rarity": "rare", "price": 90,
		"effects": {"fireball_instant": 1},
		"description": "I CAST FIREBALL skips its charging turn."},
	{"id": "loud_whistle", "name": "Loud Whistle", "rarity": "rare", "price": 100,
		"effects": {"summon_double": 1},
		"description": "Every summon is doubled: twice the skeletons, twice the spectres."},
	# --- Sustain ---
	{"id": "moss_charm", "name": "Mossy Rock", "rarity": "uncommon", "price": 55,
		"effects": {"hp_regen_turn": 1, "hp_regen_per_20_max_hp": 1},
		"description": "Regain 1 HP at the start of each of your battle turns, plus 1 more for every 20 max HP you have."},
	{"id": "healers_knot", "name": "Little Sprout", "rarity": "common", "price": 35,
		"effects": {"heal_pct": 0.25}, "description": "Potions and food heal 25% more."},
	{"id": "bloodstone", "name": "Bloodstone", "rarity": "uncommon", "price": 60,
		"effects": {"heal_on_kill": 3}, "description": "Heal 3 HP whenever an enemy falls."},
	{"id": "second_wind_whistle", "name": "Fitbit", "rarity": "common", "price": 40,
		"effects": {"heal_per_tile": 1}, "description": "Heal 1 HP for every tile you move."},
	{"id": "deep_lung_charm", "name": "Protein Bars", "rarity": "common", "price": 70,
		"effects": {"special_stamina_flat_reduction": 5},
		"description": "Every weapon special costs 5 less stamina."},
	# --- Economy ---
	{"id": "lucky_clover", "name": "Lucky Clover", "rarity": "uncommon", "price": 110, "found": true,
		"effects": {"double_secondary_chance": 1},
		"description": "Double chance for secondary effects to occur -- burning, bleeding, stuns, extra strikes, material passives and every other on-hit proc."},
	{"id": "merchants_coin", "name": "Metal Detector", "rarity": "common", "price": 40,
		"effects": {"coin_pct": 0.10}, "description": "+10% coins from every source."},
	{"id": "hagglers_tooth", "name": "Haggler's Tooth", "rarity": "uncommon", "price": 65,
		"effects": {"shop_discount": 0.10}, "description": "-10% off every shop price."},
	{"id": "gilded_scarab", "name": "Gilded Scarab", "rarity": "rare", "price": 70,
		"effects": {"damage_pct_per_coin": 0.0003, "reduction_per_coin": 0.0001},
		"description": "+0.03% damage and +0.01% damage reduction for every coin you're holding -- the more you hoard, the stronger you get."},
	{"id": "tax_collectors_seal", "name": "Tax Collector's Seal", "rarity": "rare", "price": 160,
		"effects": {"coin_drop_chance": 0.20},
		"description": "20% chance for any landed hit to drop an extra coin (bosses excluded)."},
	# --- Utility ---
	{"id": "scholars_quill", "name": "Scholar's Quill", "rarity": "common", "price": 45,
		"effects": {"xp_pct": 0.50}, "description": "+50% experience gained."},
	{"id": "swift_feather", "name": "Scroll of the Swift", "rarity": "common", "price": 60,
		"effects": {"move_speed_pct": 0.35}, "description": "+35% movement speed in the field."},
	{"id": "pathfinders_compass", "name": "Compass", "rarity": "rare", "price": 100,
		"effects": {"reveal_all_locations": 1},
		"description": "Every town and outskirts venue shows on your map immediately, instead of only once you've actually found it."},
	{"id": "gamblers_die", "name": "Gambler's Die", "rarity": "uncommon", "price": 45,
		"effects": {"gambling_luck": 0.05}, "description": "Better odds at the Wishing Well and the horse races."},
	{"id": "anglers_hook", "name": "Angler's Hook", "rarity": "rare", "price": 60,
		"effects": {"fishing_luck": 0.25}, "description": "A wider bite window and rarer catches at the fishing hole."},
	{"id": "phoenix_ash", "name": "Phoenix Ash", "rarity": "epic", "price": 140,
		"effects": {"phoenix": 1}, "description": "Survive a killing blow and rise with full HP and stamina. The ash is spent: it has to be bought again."},
	# --- Wildcard: extreme, build-defining trade-offs -------------------------------
	{"id": "glass_cannon_charm", "name": "Glass Cannon", "rarity": "epic", "price": 150,
		"effects": {"max_hp_pct": -0.5, "damage_pct": 0.75},
		"description": "-50% max HP, but +75% damage on everything you deal."},
	{"id": "vampires_pact", "name": "Bat Fang", "rarity": "epic", "price": 150,
		"effects": {"lifesteal_pct": 0.25, "disable_healing_items": 1},
		"description": "Heal 25% of all damage you deal, but healing from anywhere else stops working on you."},
	{"id": "momentum_chain", "name": "Momentum Chain", "rarity": "epic", "price": 140,
		"effects": {"momentum_chain": 1},
		"description": "Each hit you land without taking damage first adds +8% damage, uncapped -- but the instant you're hit, the chain breaks and stuns you."},
	{"id": "whirlwind_charm", "name": "Double-Blade Technique", "rarity": "epic", "price": 130,
		"effects": {"whirlwind_double_melee": 1, "damage_pct": -0.6},
		"description": "Every melee attack strikes twice, but all damage (from any source) is cut to 40%."},
	{"id": "weapon_whisperer", "name": "Weapon Whisperer", "rarity": "epic", "price": 160,
		"effects": {"weapon_whisperer": 1, "special_stamina_pct_increase": 0.3},
		"description": "Pick any 3 specials you've learned at the Dojo (from any weapon) as your loadout, regardless of what you're holding -- but every special costs 30% more stamina."},
	{"id": "chaos_shard", "name": "Chaos Shard", "rarity": "rare", "price": 100,
		"effects": {"chaos_shard": 1},
		"description": "Every hit deals somewhere between 90% and 125% of its normal damage, rerolled each time."},
	{"id": "last_stand_idol", "name": "Last Stand Idol", "rarity": "epic", "price": 180,
		"effects": {"lock_hp_to_one": 1, "oneshot_regular_enemies": 1},
		"description": "Every attack instantly kills a regular enemy (bosses unaffected) -- but your HP is permanently locked at 1, no matter what else you wear."},
	{"id": "bloodmoon_fang", "name": "Bloodthirsty Idol", "rarity": "epic", "price": 140,
		"effects": {"bloodmoon_fang": 1},
		"description": "Each hit on anything (an enemy striking an ally, an ally striking an enemy, anyone at all) stacks +5% damage and +7.5% move speed. Three turns with no hit landed by anyone crashes it and halves your stats."},
	{"id": "ironclad_ward", "name": "Steelclad Band", "rarity": "epic", "price": 130,
		"effects": {"ironclad_ward": 1},
		"description": "You can only Move on every other turn, but your defense is multiplied by 250%."},
	{"id": "wildfire_core", "name": "Wildfire Core", "rarity": "epic", "price": 130, "found": true,
		"effects": {"wildfire_core": 1},
		"description": "A burning enemy that dies explodes into 3x its fire damage, hurting and igniting everything nearby -- allies and you included."},
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

# The summed effect values of a set of talisman ids -- the same sum Player's own cache holds,
# so a party member wearing talismans gets exactly the numbers the hero would.
static func sum_effects(ids: Array) -> Dictionary:
	var total := {}
	for id in ids:
		var effects: Dictionary = get_talisman(str(id)).get("effects", {})
		for key in effects:
			total[key] = float(total.get(key, 0.0)) + float(effects[key])
	return total

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
		if not owned.has(item.id) and not item.get("found", false):
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
