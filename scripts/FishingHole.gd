extends Node
class_name FishingHole

# The Fishing Hole's rules, as pure functions (no scene) -- a Link's Awakening-
# style cast/bite/reel loop rather than the steerable-lure version originally
# sketched: pay for bait, cast, wait for a bite, hook it inside a short window,
# then reel a tension bar without either running out of progress or snapping
# the line. FishingPanel.gd drives the actual state machine tick by tick and
# owns the drawing; everything here is either a one-shot roll (what's on the
# line, how long the wait is) or a pure step function so the whole loop can be
# tested without a Control node.
#
# Sizes, worst to best: junk, small, medium, large, golden. Loot follows
# straight from size -- see loot_for_size.

const BAIT_COST := 8

# Base weights (out of 100) before fishing_luck (the Angler's Hook talisman)
# skews them toward the rarer, better catches -- same additive-then-renormalize
# shape as WishingWell.gd's wager tilt.
const SIZE_WEIGHTS := {
	"junk": 25.0, "small": 38.0, "medium": 22.0, "large": 11.0, "golden": 4.0,
}
const RARE_SIZES := ["medium", "large", "golden"]

# How long (in ticks -- see FishingPanel.TICK_SECONDS) a cast waits before a
# bite starts, and how long the bite window stays open once it does. A bigger
# fish is warier and bites later but leaves a similar window; luck only ever
# widens the window, never the wait.
const BITE_WAIT_TICKS := {"junk": 20, "small": 25, "medium": 35, "large": 45, "golden": 55}
const BASE_BITE_WINDOW_TICKS := 18
const LUCK_WINDOW_BONUS_TICKS_PER_POINT := 20.0

# Reeling: progress must reach 1.0 to land the fish; tension reaching 1.0 snaps
# the line. Bigger fish need more progress per reel and push tension up faster.
const PROGRESS_PER_REEL_TICK := {"junk": 0.16, "small": 0.12, "medium": 0.08, "large": 0.055, "golden": 0.045}
const TENSION_PER_REEL_TICK := {"junk": 0.05, "small": 0.07, "medium": 0.09, "large": 0.11, "golden": 0.12}
const TENSION_RELAX_PER_TICK := 0.05
# A random extra tug most ticks regardless of whether you're reeling -- what
# makes just holding the button down the whole time a losing strategy.
const SURGE_CHANCE := 0.18
const SURGE_TENSION := 0.10

static func size_weights(luck: float) -> Dictionary:
	var result := {}
	for size in SIZE_WEIGHTS:
		var w: float = SIZE_WEIGHTS[size]
		if RARE_SIZES.has(size):
			w *= 1.0 + 3.0 * maxf(0.0, luck)
		result[size] = w
	return result

static func roll_size(luck: float = 0.0, rng: RandomNumberGenerator = null) -> String:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var weights: Dictionary = size_weights(luck)
	var total := 0.0
	for w in weights.values():
		total += w
	var pick: float = rng.randf() * total
	for size in weights:
		pick -= weights[size]
		if pick <= 0.0:
			return size
	return "junk"

static func bite_wait_ticks(size: String) -> int:
	return BITE_WAIT_TICKS.get(size, 30)

# Ticks the bite window stays open -- widened by fishing_luck, never shrunk.
static func bite_window_ticks(luck: float = 0.0) -> int:
	return BASE_BITE_WINDOW_TICKS + int(round(maxf(0.0, luck) * LUCK_WINDOW_BONUS_TICKS_PER_POINT))

# One tick of reeling. `holding` is whether the player is pressing reel THIS
# tick; releasing lets tension bleed off but earns no progress. Returns the new
# {progress, tension} state; the caller (FishingPanel) checks for >=1.0 on
# either. `rng` makes the surge roll seedable for tests.
static func step_reel(progress: float, tension: float, size: String, holding: bool, rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	if holding:
		progress += PROGRESS_PER_REEL_TICK.get(size, 0.08)
		tension += TENSION_PER_REEL_TICK.get(size, 0.09)
	else:
		tension = maxf(0.0, tension - TENSION_RELAX_PER_TICK)
	if rng.randf() < SURGE_CHANCE:
		tension += SURGE_TENSION
	return {"progress": clampf(progress, 0.0, 1.0), "tension": clampf(tension, 0.0, 1.0)}

# What a landed catch of this size actually gives. `owned_talismans` only
# matters for "golden" (so a wish never re-offers one you already hold).
# Returns {kind: "coins"/"food"/"potion"/"talisman", ...}.
static func loot_for_size(size: String, owned_talismans: Dictionary = {}, rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	match size:
		"junk":
			return {"kind": "coins", "amount": rng.randi_range(1, 4), "label": "An old boot"}
		"small":
			return {"kind": "food", "id": "food_minnow", "label": "Fried Minnow"}
		"medium":
			return {"kind": "food", "id": "food_bass", "label": "Grilled Bass"}
		"large":
			if rng.randf() < 0.5:
				return {"kind": "coins", "amount": rng.randi_range(20, 40), "label": "A waterlogged coin purse"}
			var potions := ["potion_health", "potion_attack", "potion_resilience", "potion_energy", "potion_stamina", "potion_regular"]
			return {"kind": "potion", "id": potions[rng.randi() % potions.size()], "label": "A sealed bottle"}
		"golden":
			var talismans_script := load("res://scripts/Talismans.gd")
			var pick: Array = talismans_script.roll_stock(1, owned_talismans, rng)
			if pick.is_empty():
				return {"kind": "coins", "amount": 60, "label": "The golden fish slips away, but leaves gold dust behind"}
			return {"kind": "talisman", "id": pick[0], "label": "A talisman, snagged on its fin"}
	return {"kind": "coins", "amount": 1, "label": "Something"}
