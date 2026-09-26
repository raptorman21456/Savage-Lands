extends Node
class_name WishingWell

# The Wishing Well's rules, as pure functions so they can be tested without a
# scene: throw coins in, get one weighted-random outcome. Some are good, some
# aren't; a bigger wager tilts the odds (and the size of the good outcomes)
# your way a little, and so does the Gambler's Die talisman (gambling_luck).
# The panel (WishingWellPanel.gd) applies whichever outcome comes up.
#
# Deliberately no XP outcome: gain_xp can trigger the level-up choice, which
# unpauses the game underneath an open panel. Permanent-for-the-run stat bumps
# go through Player.apply_bonus_stat instead.

const WAGERS := [10, 25, 50, 100]

# outcome id -> {weight (at the smallest wager, no luck), good (bool), text}
# "good" ones are scaled up by wager tier and luck, "bad" ones scaled down.
const OUTCOMES := {
	"nothing": {"weight": 30.0, "good": false, "neutral": true, "label": "Nothing"},
	"blessing": {"weight": 16.0, "good": true, "label": "A Blessing"},
	"refund": {"weight": 12.0, "good": true, "label": "Coins Returned Twice Over"},
	"healing": {"weight": 10.0, "good": true, "label": "Healing Waters"},
	"potion": {"weight": 8.0, "good": true, "label": "A Gift"},
	"stat": {"weight": 3.0, "good": true, "label": "A Surge of Strength"},
	"wish": {"weight": 2.0, "good": true, "label": "A Wish Granted"},
	"jackpot": {"weight": 1.0, "good": true, "label": "JACKPOT"},
	"curse": {"weight": 8.0, "good": false, "label": "A Curse"},
	"purse": {"weight": 6.0, "good": false, "label": "The Well Takes More"},
}

# Waves a blessing/curse lasts (same idea as Main.gd's Ancient Shrine).
const EFFECT_WAVES := 3

# 0..3 for the four presets (anything above the top preset counts as top tier).
static func wager_tier(wager: int) -> int:
	var tier := 0
	for i in WAGERS.size():
		if wager >= WAGERS[i]:
			tier = i
	return tier

# The live weight of every outcome for this wager and luck.
static func weights(wager: int, luck: float = 0.0) -> Dictionary:
	var tier: int = wager_tier(wager)
	var result := {}
	for id in OUTCOMES:
		var info: Dictionary = OUTCOMES[id]
		var w: float = info.weight
		if info.get("neutral", false):
			pass
		elif info.good:
			w *= 1.0 + 0.15 * tier + 2.0 * luck
		else:
			w *= maxf(0.1, 1.0 - 0.10 * tier - 2.0 * luck)
		result[id] = w
	return result

# One weighted draw. rng is optional so tests can seed it.
static func roll(wager: int, luck: float = 0.0, rng: RandomNumberGenerator = null) -> String:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var table: Dictionary = weights(wager, luck)
	var total := 0.0
	for id in table:
		total += table[id]
	var pick := rng.randf() * total
	for id in table:
		pick -= table[id]
		if pick <= 0.0:
			return id
	return "nothing"

# How strong a blessing is: +10% damage at the smallest wager, +5% more per tier.
static func blessing_pct(wager: int) -> float:
	return 0.10 + 0.05 * wager_tier(wager)

# The curse is a flat -10%: it doesn't get worse with a bigger wager.
static func curse_pct() -> float:
	return 0.10

# Coins a Refund pays back (2x the wager) and a Jackpot (10x), inclusive of the
# stake already spent.
static func refund_amount(wager: int) -> int:
	return wager * 2

static func jackpot_amount(wager: int) -> int:
	return wager * 10
