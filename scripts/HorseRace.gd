extends Node
class_name HorseRace

# The Horse Racing Grounds' simulation, as pure functions (no scene): a field
# of five horses, each with a hidden speed / stamina / finishing burst, run
# through a tick-by-tick race. The panel (HorseRacePanel.gd) animates a
# precomputed race; the displayed ODDS come from running the very same
# simulation hundreds of times, so they honestly reflect each horse's chance,
# minus a house edge.
#
# Positions are normalised: 0.0 = the gate, 1.0 = the finish line.

const HORSE_COUNT := 5
# Ticks of simulation per unit of "race length" (also the animation's frame
# budget); a typical winner crosses the line around tick TICKS.
const TICKS := 300
# The winning horse's real-time run in the panel, in seconds.
const RACE_SECONDS := 7.0
# Fraction of the money the house keeps: payouts are wager x odds where
# odds ~= (1 - HOUSE_EDGE) / win_probability.
const HOUSE_EDGE := 0.10
const MIN_ODDS := 1.2
const MAX_ODDS := 30.0
const ODDS_SAMPLES := 250
# Safety cap so a pathological field can't loop forever.
const MAX_TICKS := TICKS * 4

const NAMES := [
	"Thunderhoof", "Sir Trotsalot", "Mudslinger", "Glue Factory", "Lucky Biscuit",
	"Dust Devil", "Old Faithful", "Bramble", "Nightmare Fuel", "Cinnamon",
	"Neigh-Sayer", "Buttercup", "Gallopin' Gary", "Iron Mane", "Widow's Peak",
]
const COLORS := [
	Color(0.95, 0.45, 0.45), Color(0.45, 0.7, 0.95), Color(0.55, 0.9, 0.5),
	Color(0.95, 0.85, 0.4), Color(0.85, 0.55, 0.95),
]

# A fresh field: 5 distinct names, each horse with its own hidden stats.
#   speed   -- base pace (1.0 = average)
#   stamina -- the fraction of the race it can hold full pace for, then tires
#   burst   -- extra pace in the final quarter
static func make_field(rng: RandomNumberGenerator = null) -> Array:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var names: Array = NAMES.duplicate()
	var field := []
	for i in HORSE_COUNT:
		var pick: int = rng.randi() % names.size()
		field.append({
			"name": names[pick],
			"color": COLORS[i],
			"speed": 1.0 + rng.randf_range(-0.05, 0.05),
			"stamina": rng.randf_range(0.6, 0.92),
			"burst": rng.randf_range(0.0, 0.15),
		})
		names.remove_at(pick)
	return field

# Runs one race. Returns:
#   positions    -- Array (per horse) of PackedFloat32Array, one entry per tick
#                   (index 0 = the gate)
#   finish_ticks -- the tick each horse crossed 1.0
#   order        -- horse indices, first place to last
#   winner_tick  -- when the winner crossed
static func simulate(field: Array, rng: RandomNumberGenerator = null, record: bool = true) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var n: int = field.size()
	var pos: Array = []
	var form: Array = []
	var momentum: Array = []
	var finish: Array = []
	var trail: Array = []
	for i in n:
		pos.append(0.0)
		# The hidden "how is it feeling today" -- the reason the favourite
		# doesn't always win.
		form.append(rng.randf_range(0.94, 1.06))
		finish.append(-1)
		momentum.append(1.0)
		var t := PackedFloat32Array()
		t.append(0.0)
		trail.append(t)
	var unfinished: int = n
	var tick := 0
	while unfinished > 0 and tick < MAX_TICKS:
		tick += 1
		# Normalised so an average horse just about finishes at tick TICKS.
		var step := 1.15 / float(TICKS)
		for i in n:
			if finish[i] >= 0:
				if record:
					trail[i].append(1.0)
				continue
			var horse: Dictionary = field[i]
			var f: float = float(tick) / float(TICKS)
			var pace: float = horse.speed * form[i]
			if f > horse.stamina:
				# Tiring: pace drops off the further past its limit it runs.
				pace *= maxf(0.6, 1.0 - 0.7 * (f - horse.stamina))
			if f > 0.75:
				pace *= 1.0 + horse.burst
			# Momentum: a slowly wandering surge or lag (an Ornstein-Uhlenbeck walk)
			# rather than independent per-tick noise, which would average away
			# over 300 ticks and leave the fastest horse winning almost every time.
			momentum[i] = clampf(momentum[i] - 0.06 * (momentum[i] - 1.0) + rng.randfn(0.0, 0.06), 0.5, 1.5)
			pace *= momentum[i]
			pos[i] += maxf(0.0, pace) * step
			if pos[i] >= 1.0:
				pos[i] = 1.0
				finish[i] = tick
				unfinished -= 1
			if record:
				trail[i].append(pos[i])
	# Anyone still running at the cap is placed by how far they got.
	var order: Array = []
	for i in n:
		order.append(i)
	order.sort_custom(func(a, b):
		var fa: int = finish[a] if finish[a] >= 0 else MAX_TICKS + 1
		var fb: int = finish[b] if finish[b] >= 0 else MAX_TICKS + 1
		if fa != fb:
			return fa < fb
		return pos[a] > pos[b]
	)
	return {
		"positions": trail,
		"finish_ticks": finish,
		"order": order,
		"winner_tick": finish[order[0]] if finish[order[0]] >= 0 else tick,
	}

# Each horse's chance to win, from `samples` simulated races of the same field.
static func estimate_win_probs(field: Array, samples: int = ODDS_SAMPLES, rng: RandomNumberGenerator = null) -> Array:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var wins: Array = []
	for i in field.size():
		wins.append(0)
	for s in samples:
		var result: Dictionary = simulate(field, rng, false)
		wins[result.order[0]] += 1
	var probs := []
	for w in wins:
		probs.append(float(w) / float(samples))
	return probs

# Decimal odds for each probability: what a winning wager multiplies by
# (stake included). ~(1 - HOUSE_EDGE) / p, snapped to 0.1 and clamped.
static func odds_from_probs(probs: Array) -> Array:
	var odds := []
	for p in probs:
		if p <= 0.0:
			odds.append(MAX_ODDS)
		else:
			odds.append(clampf(snappedf((1.0 - HOUSE_EDGE) / p, 0.1), MIN_ODDS, MAX_ODDS))
	return odds

# Total coins returned on a winning bet (stake included); `luck` is the Gambler's
# Die bonus, a small extra percentage on the payout.
static func payout(wager: int, odds: float, luck: float = 0.0) -> int:
	return int(round(wager * odds * (1.0 + luck)))
