extends Node
class_name Weapons

# Battle (tile-grid) heavy attack: costs a chunk of stamina, hits much
# harder, available regardless of which weapon is equipped.
const HEAVY_DAMAGE_MULT := 1.75
const HEAVY_STAMINA_COST := 40

# shape: "rect" (directional rectangle), "circle" (radial slam), or
# "sweep" (rectangle that rotates through sweep_angle_deg during the swing).
#
# Each weapon also carries 3 "specials" for the tile battle -- stamina-gated
# alternatives to the free regular attack, each with its own damage
# multiplier and effect. Effects (handled in Main.gd's battle code):
#   ignore_cover        - skips the rock-cover damage reduction
#   execute             - +50% damage if the target is below 30% HP
#   self_heal           - also heals the player a little
#   cleave_all          - hits every currently targetable enemy, not just one
#   guaranteed_knockback - knockback always lands (Orc can't resist) and
#                          pushes 2 tiles instead of 1
#   double_hit          - the hit-and-knockback sequence happens twice
#   stun_bypass         - always stuns the target, not just when blocked by
#                          a rock
#   lifesteal           - heals the player for a cut of the damage just dealt
const CLUB := {
	"id": "club", "name": "Club", "price": 0,
	"damage_mult": 1.0, "cooldown_mult": 1.0, "active_duration": 0.15,
	"shape": "rect", "reach": 40.0, "width": 36.0,
	"description": "Simple wooden club. Balanced, free.",
	"icon": "club",
	"specials": [
		{"id": "club_leg_blow", "name": "Leg Blow", "stamina_cost": 20, "dmg_mult": 1.2, "effect": "leg_blow", "description": "120% damage that ignores rock cover, and permanently slows the target by 1 tile of movement."},
		{"id": "club_second_wind", "name": "Second Wind", "stamina_cost": 20, "dmg_mult": 0.6, "effect": "self_heal", "description": "60% damage, and heals you for ~20% of your max HP."},
		{"id": "club_heavy_swing", "name": "Heavy Swing", "stamina_cost": 25, "dmg_mult": 1.3, "effect": "execute", "description": "130% damage, plus 50% more against targets below 30% HP."},
	],
}

# These are the "standard" tier baseline for each upgradeable weapon type.
# The shop rolls a random quality tier (see TIERS) on top of these each time
# it opens, so "some spears are better than others" -- only damage and price
# vary between tiers, reach/cooldown/shape stay true to the weapon type.
const SPEAR := {
	"id": "spear", "name": "Spear", "price": 15,
	"damage_mult": 0.55, "cooldown_mult": 0.45, "active_duration": 0.12,
	"shape": "rect", "reach": 75.0, "width": 18.0,
	"long_range": true,
	"description": "Great reach, hits diagonally, fast, light damage.",
	"icon": "spear",
	"specials": [
		{"id": "spear_piercing_thrust", "name": "Piercing Thrust", "stamina_cost": 33, "dmg_mult": 1.25, "effect": "piercing_thrust", "description": "125% damage that ignores rock cover and pierces through to a second enemy standing one tile beyond the first."},
		{"id": "spear_wombo_combo", "name": "Wombo Combo", "stamina_cost": 40, "dmg_mult": 0.17, "effect": "", "hit_count_min": 5, "hit_count_max": 10, "luck_scales_hits": true, "description": "5-10 rapid jabs at 17% damage each -- the odds of extra hits rise with your Fortune."},
		{"id": "spear_target_practice", "name": "Target Practice", "stamina_cost": 50, "dmg_mult": 0.0, "effect": "target_practice", "description": "30%% chance to instantly kill a regular enemy (5%% vs. a boss). On a miss, your spear flies to a random tile and you can't Fight until you reach it."},
	],
}

const GREATSWORD := {
	"id": "greatsword", "name": "Greatsword", "price": 25,
	"damage_mult": 1.9, "cooldown_mult": 1.7, "active_duration": 0.22,
	"shape": "rect", "reach": 32.0, "width": 70.0,
	"description": "Wide horizontal slash, heavy damage, slow.",
	"icon": "greatsword",
	"specials": [
		{"id": "greatsword_whirlwind_strike", "name": "Whirlwind Strike", "stamina_cost": 70, "dmg_mult": 0.4, "effect": "whirlwind_strike", "pass_count_min": 2, "pass_count_max": 5, "description": "2-5 spinning passes, each dealing 40% damage to every enemy in range."},
		{"id": "greatsword_low_sweep", "name": "Low Sweep", "stamina_cost": 40, "dmg_mult": 0.7, "effect": "low_sweep", "description": "70% damage, with an 80% chance to sweep the target's legs out, halving its movement for the rest of the battle."},
		{"id": "greatsword_wide_cleave", "name": "Wide Cleave", "stamina_cost": 25, "dmg_mult": 0.9, "effect": "wide_cleave", "description": "90% damage to everyone standing in the 3 tiles directly toward your target. Refused outright if cover blocks the way."},
	],
}

const HAMMER := {
	"id": "hammer", "name": "Hammer", "price": 30,
	"damage_mult": 1.6, "cooldown_mult": 2.2, "active_duration": 0.28,
	"shape": "circle", "radius": 50.0, "offset": 26.0,
	"description": "Huge spreading slam, very slow.",
	"icon": "hammer",
	"specials": [
		{"id": "hammer_crushing_collision", "name": "Crushing Collision", "stamina_cost": 50, "dmg_mult": 0.8, "effect": "crushing_collision", "description": "80% damage, and permanently shatters the target's armor."},
		{"id": "hammer_maracas", "name": "Maracas", "stamina_cost": 35, "dmg_mult": 1.3, "effect": "maracas", "description": "130% damage -- 195% if the target is armored."},
		{"id": "hammer_bonk", "name": "BONK", "stamina_cost": 60, "dmg_mult": 1.1, "effect": "bonk", "description": "110% damage. Leaves the target Concussed: a 33% chance to hit itself instead of you for the next few turns."},
	],
}

const BATTLE_AXE := {
	"id": "battle_axe", "name": "Battle Axe", "price": 40,
	"damage_mult": 2.3, "cooldown_mult": 2.5, "active_duration": 0.35,
	"shape": "sweep", "reach": 48.0, "width": 24.0, "sweep_angle_deg": 120.0,
	"ohko_chance": 0.2,
	"description": "Slow sweeping cleave, huge damage, 20% instant kill.",
	"icon": "battle_axe",
	"specials": [
		{"id": "battle_axe_devastating_slash", "name": "Devastating Slash", "stamina_cost": 90, "dmg_mult": 1.8, "effect": "devastating_slash", "description": "180% damage -- but the follow-through leaves you unable to act next turn."},
		{"id": "battle_axe_execution", "name": "Execution", "stamina_cost": 60, "dmg_mult": 0.0, "effect": "execution", "description": "Instantly kills an armorless enemy. Deals no damage at all against an armored one."},
		{"id": "battle_axe_oldest_trick", "name": "Oldest Trick in the Book", "stamina_cost": 20, "dmg_mult": 0.4, "effect": "stun_bypass", "description": "40% damage, and the target loses its next turn."},
	],
}

const DAGGER := {
	"id": "dagger", "name": "Dagger", "price": 12,
	"damage_mult": 0.45, "cooldown_mult": 0.3, "active_duration": 0.1,
	"shape": "rect", "reach": 28.0, "width": 20.0,
	"description": "Very fast, light damage, favors relentless pressure.",
	"icon": "dagger",
	"specials": [
		{"id": "dagger_flurry_slice", "name": "Flurry Slice", "stamina_cost": 40, "dmg_mult": 0.1, "effect": "", "hit_count_min": 8, "hit_count_max": 13, "description": "8-13 lightning-fast slices at 10% damage each."},
		{"id": "dagger_bleeding_cut", "name": "Bleeding Cut", "stamina_cost": 20, "dmg_mult": 0.9, "effect": "lifesteal", "description": "90% damage, healing you for half of what you deal."},
		{"id": "dagger_knife_throw", "name": "Knife Throw", "stamina_cost": 10, "dmg_mult": 2.0, "effect": "knife_throw", "description": "200% damage for almost nothing -- but the throw always leaves you disarmed, weapon flung to a random tile."},
	],
}

const BOW := {
	"id": "bow", "name": "Bow", "price": 20,
	"damage_mult": 0.5, "cooldown_mult": 0.9, "active_duration": 0.12,
	"shape": "rect", "reach": 110.0, "width": 14.0,
	"long_range": true,
	# No specials of its own -- replaced entirely by the purchasable special
	# arrows below (ARROW_TYPES), fired from a dedicated battle-menu button
	# instead of the usual 3-special list.
	"description": "Long reach, light damage, attacks from range 2 in battle.",
	"icon": "bow",
	"specials": [],
}

# Special arrows: purchased 1 at a time (only while the Bow is equipped, so
# they don't pollute the loot pool -- see get_arrow_price/try_buy_arrow in
# Player.gd), but usable and sellable regardless of what's currently
# equipped once owned. Not weapon "specials" -- fired from their own battle
# button, consuming 1 arrow and no stamina.
const ARROW_TYPES := {
	"flame": {
		"name": "Flame Arrow", "price": 5,
		"description": "A small flat hit plus half your damage stat, then sets the target Burning: loses HP and deals 25% less damage every turn until it steps into water.",
	},
	"freeze": {
		"name": "Freeze Arrow", "price": 5,
		"description": "5 flat damage. Freezes the target for 2-4 turns -- it can't act, and takes 20% more damage while frozen.",
	},
	"bomb": {
		"name": "Bomb Arrow", "price": 7,
		"description": "20 flat damage to every unit in a 3x3 area centered on the target -- allies and you included, if you're standing in the blast.",
	},
}
const ARROW_MAX_HELD := 10
const ARROW_SELL_PRICE := 2
# Buying an arrow gets 30% more expensive per arrow you currently hold of
# that type -- using some down brings the next purchase's price back down.
const ARROW_PRICE_GROWTH := 1.3

const KNUCKLE_GLOVES := {
	"id": "knuckle_gloves", "name": "Knuckle Gloves", "price": 14,
	"damage_mult": 0.4, "cooldown_mult": 0.32, "active_duration": 0.1,
	"shape": "rect", "reach": 22.0, "width": 30.0,
	# Innate, not a special -- every plain Attack always lands twice (each hit
	# at reduced damage, so total DPS isn't literally doubled). Checked
	# directly in Player.gd's overworld swing and Main.gd's tile-battle
	# regular-attack path, the same way Battle Axe's ohko_chance is a base
	# weapon flag rather than something routed through the specials list.
	"double_strike": true,
	"description": "Every attack lands twice in a flurry of jabs. Very close range.",
	"icon": "knuckle_gloves",
	"specials": [
		{"id": "knuckle_gloves_ol_one_two", "name": "The 'Ol One-Two", "stamina_cost": 30, "dmg_mult": 0.75, "split_dmg_mult": 0.7, "effect": "ol_one_two", "description": "Hits your target twice at 75% damage each -- or, if a second enemy is in range, splits between both at 70% each instead."},
		{"id": "knuckle_gloves_wrist_strike", "name": "Wrist Strike", "stamina_cost": 25, "dmg_mult": 0.65, "effect": "wrist_strike", "description": "65% damage, and knocks the target's weapon loose -- it can't attack until it reaches the tile it lands on."},
		{"id": "knuckle_gloves_clotheslined", "name": "Clothesliner", "stamina_cost": 50, "dmg_mult": 1.5, "effect": "clotheslined", "description": "150% damage, hurling the target to the tile directly behind you."},
	],
}

const HAND_PICKS := {
	"id": "hand_picks", "name": "Hand Picks", "price": 18,
	"damage_mult": 0.85, "cooldown_mult": 0.6, "active_duration": 0.16,
	"shape": "rect", "reach": 34.0, "width": 26.0,
	# Innate -- a mining tool built to tear through the hardest material, so
	# every hit (any attack, not just a named special) cuts deeper into
	# anything armored. Reliably relevant (an armored target or it isn't)
	# rather than the old rock-cover-ignore, which only ever mattered on the
	# rare turn a target happened to be standing next to a rock.
	"passive_armor_pierce_pct": 0.3,
	"description": "Built to tear through the hardest material -- +30% damage against armored enemies, with any attack.",
	"icon": "hand_picks",
	"specials": [
		{"id": "hand_picks_pichaku", "name": "Pichaku", "stamina_cost": 0, "dmg_mult": 0.0, "effect": "pichaku", "description": "Costs your turn. For the rest of the battle, your attacks deal 80% damage but every regular or heavy attack has a 20% chance to strike twice."},
		{"id": "hand_picks_diamonds", "name": "DIAMONDS", "stamina_cost": 100, "dmg_mult": 2.0, "effect": "diamonds", "description": "Jump onto any enemy on the grid, ignoring terrain entirely. 200% damage, knocking them back a tile as you land."},
		{"id": "hand_picks_minernado", "name": "Minernado", "stamina_cost": 40, "dmg_mult": 0.2, "effect": "", "hit_count_min": 4, "hit_count_max": 7, "description": "4-7 whirling pickaxe strikes at 20% damage each."},
	],
}

const UPGRADABLE_TYPES := [SPEAR, GREATSWORD, HAMMER, BATTLE_AXE, DAGGER, BOW, KNUCKLE_GLOVES, HAND_PICKS]

# Quality tiers rolled for each upgradeable weapon whenever the shop opens.
# weight is out of 100 total across all tiers. rank orders them worst-to-best
# so a shop roll can be restricted to "at least as good as what you own."
# required_might: the player's Might stat needed to equip a weapon of this
# tier at all (see Main.gd's buy/equip gate and HUD.gd's shop row locking).
# Only the top 3 tiers actually gate anything -- Broken/Worn/Fine stay
# available to a fresh level-1 run.
const TIERS := [
	{"tier_name": "Broken", "damage_scale": 0.55, "price_scale": 0.35, "weight": 10, "rank": 0, "required_might": 0},
	{"tier_name": "Worn", "damage_scale": 0.8, "price_scale": 0.65, "weight": 35, "rank": 1, "required_might": 0},
	{"tier_name": "Fine", "damage_scale": 1.0, "price_scale": 1.0, "weight": 30, "rank": 2, "required_might": 0},
	{"tier_name": "Masterwork", "damage_scale": 1.3, "price_scale": 1.7, "weight": 18, "rank": 3, "required_might": 8},
	{"tier_name": "Legendary", "damage_scale": 1.7, "price_scale": 2.6, "weight": 6.5, "rank": 4, "required_might": 16},
	# A jackpot roll -- weight 0.5 against everything else summing to 100
	# means this lands almost exactly 0.5% of the time. Deliberately way
	# past the smooth Broken->Legendary curve (which never even triples base
	# damage) so it actually feels broken to find, not just "one more step up."
	{"tier_name": "Mythic", "damage_scale": 3.0, "price_scale": 6.0, "weight": 0.5, "rank": 5, "required_might": 24},
]

# A Mythic roll isn't "a Mythic Spear" -- it's a specific, fixed named
# artifact per weapon type, each with its own always-on passive (checked in
# Main.gd's battle code via the passive_* keys below). make_variant() looks
# these up directly instead of generically scaling the base weapon, so a
# Mythic pull always produces the exact same item and never rolls a material
# on top of it (see make_variant).
const MYTHIC_WEAPONS := {
	"spear": {
		"name": "Stormfang",
		"description": "A spear said to have been forged in a lightning strike. It drinks deep with every strike, healing its wielder as it draws blood.",
		"passive": {"passive_lifesteal_pct": 0.25},
	},
	"greatsword": {
		"name": "Duskrender",
		"description": "A colossal blade that seems to cut the space around its target as well as the target itself -- every swing spills over onto whoever else is standing nearby.",
		"passive": {"passive_cleave_pct": 0.4},
	},
	"hammer": {
		"name": "Worldbreaker",
		"description": "Said to have leveled a mountain in one blow. Nothing it connects with stays standing where it was.",
		"passive": {"passive_guaranteed_knockback": true},
	},
	"battle_axe": {
		"name": "Bloodreaver",
		"description": "It hungers for the wounded, striking hardest at whatever is already closest to falling.",
		"passive": {"passive_execute_bonus": 0.5},
	},
	"dagger": {
		"name": "Nightwhisper",
		"description": "Faster than the eye can follow -- more often than not, it's already struck twice before the first cut is even felt.",
		"passive": {"passive_double_hit_chance": 0.3},
	},
	"bow": {
		"name": "Starfall",
		"description": "Its arrows fall like the light of a dying star, passing through stone as easily as air.",
		"passive": {"passive_ignore_cover": true},
	},
	"knuckle_gloves": {
		"name": "Thunderclap",
		"description": "The ultimate expression of a knuckle-fighter's craft -- every motion, not just the plain jab, lands as a doubled flurry.",
		"passive": {"passive_double_hit_chance": 1.0},
	},
	"hand_picks": {
		"name": "Gravedigger",
		"description": "A pick that has dug through more than stone. It never tires -- every technique flows as freely as the last.",
		"passive": {"passive_free_specials": true},
	},
}

# Weapon construction material -- an axis orthogonal to quality tier, rolled
# alongside a tier for every non-Mythic shop offering (a named Mythic
# legendary is a fixed known artifact and bypasses this entirely -- see
# make_variant). weight sums to 100, same convention as TIERS. Not luck-
# biased -- Fortune only shifts the tier roll, not which material shows up.
const MATERIALS := [
	{"id": "wood", "name": "Wooden", "damage_scale": 0.65, "price_scale": 0.5, "stamina_scale": 0.5, "cooldown_scale": 1.0, "break_chance": 0.0, "weight": 25},
	{"id": "steel", "name": "Steel", "damage_scale": 1.0, "price_scale": 1.0, "stamina_scale": 1.0, "cooldown_scale": 1.0, "break_chance": 0.0, "weight": 35},
	{"id": "gold", "name": "Golden", "damage_scale": 1.25, "price_scale": 1.3, "stamina_scale": 1.0, "cooldown_scale": 0.8, "break_chance": 0.05, "weight": 15},
	{"id": "bone", "name": "Bone", "damage_scale": 1.4, "price_scale": 0.8, "stamina_scale": 0.85, "cooldown_scale": 1.0, "break_chance": 0.12, "weight": 10},
	{"id": "silver", "name": "Silver", "damage_scale": 0.9, "price_scale": 1.15, "stamina_scale": 0.6, "cooldown_scale": 0.85, "break_chance": 0.0, "weight": 10},
	{"id": "obsidian", "name": "Obsidian", "damage_scale": 1.5, "price_scale": 1.8, "stamina_scale": 1.1, "cooldown_scale": 1.1, "break_chance": 0.08, "weight": 5},
]

static func _pick_material() -> Dictionary:
	var roll := randf() * 100.0
	var cumulative := 0.0
	for m in MATERIALS:
		cumulative += m.weight
		if roll <= cumulative:
			return m
	return MATERIALS[-1]

static func _pick_tier(min_rank: int, luck_bonus: float = 0.0) -> Dictionary:
	var eligible := []
	var weights := []
	var total_weight := 0.0
	for t in TIERS:
		if t.rank >= min_rank:
			# The Fortune meta-upgrade shifts odds toward higher tiers,
			# scaled by how high the tier's rank is -- Worn (rank 0) never
			# gets a boost, Masterwork (rank 2) gets the biggest one.
			var w: float = t.weight * (1.0 + luck_bonus * t.rank)
			eligible.append(t)
			weights.append(w)
			total_weight += w
	var roll := randf() * total_weight
	var cumulative := 0.0
	for i in eligible.size():
		cumulative += weights[i]
		if roll <= cumulative:
			return eligible[i]
	return eligible[-1]

static func make_variant(base: Dictionary, min_rank: int = 0, luck_bonus: float = 0.0) -> Dictionary:
	var tier: Dictionary = _pick_tier(min_rank, luck_bonus)
	# A deep duplicate -- not the shallow default -- since material rolling
	# below mutates each special's stamina_cost in place. A shallow duplicate
	# would still share the same nested `specials` array/dicts as the base
	# const, silently corrupting it for every future variant of this weapon.
	var variant: Dictionary = base.duplicate(true)
	variant.tier_name = tier.tier_name
	variant.required_might = tier.required_might
	if tier.tier_name == "Mythic" and MYTHIC_WEAPONS.has(base.id):
		var mythic: Dictionary = MYTHIC_WEAPONS[base.id]
		variant.id = "%s_mythic" % base.id
		variant.name = mythic.name
		variant.description = mythic.description
		variant.damage_mult = base.damage_mult * tier.damage_scale
		variant.price = int(round(base.price * tier.price_scale))
		for key in mythic.passive:
			variant[key] = mythic.passive[key]
		# Thunderclap's passive_double_hit_chance (1.0, i.e. guaranteed)
		# already subsumes Knuckle Gloves' inherited innate double_strike --
		# both mechanisms firing independently would triple-hit (primary +
		# double_strike's bonus hit + the passive's own bonus hit) instead
		# of the intended double.
		if mythic.passive.has("passive_double_hit_chance"):
			variant.double_strike = false
		return variant

	var material: Dictionary = _pick_material()
	variant.material_name = material.name
	variant.damage_mult = base.damage_mult * tier.damage_scale * material.damage_scale
	variant.price = int(round(base.price * tier.price_scale * material.price_scale))
	variant.cooldown_mult = base.cooldown_mult * material.cooldown_scale
	variant.break_chance = material.break_chance
	for special in variant.specials:
		special.stamina_cost = int(round(special.stamina_cost * material.stamina_scale))
	variant.id = "%s_%s_%s" % [base.id, tier.tier_name.to_lower(), material.id]

	# Display name omits both "Fine" and "Steel" -- each axis's implicit
	# baseline -- so a fully-default roll still reads as just "Spear", and
	# only genuinely notable rolls grow a prefix.
	var name_parts := []
	if tier.tier_name != "Fine":
		name_parts.append(tier.tier_name)
	if material.id != "steel":
		name_parts.append(material.name)
	name_parts.append(base.name)
	variant.name = " ".join(name_parts)
	return variant
