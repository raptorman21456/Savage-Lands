extends RefCounted

# How points of Defense (bodily harm) and Fortitude (magical harm) turn into a share of damage cut.
# Diminishing returns, Brotato-style: every point helps, but each one helps a little less than the
# last, and the cut creeps towards a ceiling it never reaches.
#
#     cut = cap x points / (points + HALF_POINTS)
#
# A "point" is what a 1% flat cut used to be, so existing armour / Resilience / Fortitude numbers
# carry over unchanged -- only the way they add up changed. HALF_POINTS is the number of points that
# earn half the ceiling (the single knob for tuning how fast it flattens out). A NEGATIVE total
# (Thornmail's spikes, a Wolf's Fortitude) curves the same way towards NEGATIVE_FLOOR, so spells can
# hurt up to 50% more but no worse.
#
# The ceiling is BASE_CAP (80%) for everyone; the Guardian's own is GUARDIAN_CAP (90%). Tactical
# layers that are not stats -- Defend, rock cover, Stalwart, Warden's aura, Stonehide's flat cut --
# are applied separately and are not part of this.

const BASE_CAP := 0.80
const GUARDIAN_CAP := 0.90
const NEGATIVE_FLOOR := -0.5
const HALF_POINTS := 60.0

# The share of damage that `points` of protection cut, under a ceiling of `cap`.
static func reduction(points: float, cap: float = BASE_CAP) -> float:
	if points >= 0.0:
		return cap * points / (points + HALF_POINTS)
	var p := -points
	return NEGATIVE_FLOOR * p / (p + HALF_POINTS)
