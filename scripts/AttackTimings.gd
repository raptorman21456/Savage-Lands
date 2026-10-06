extends RefCounted

# Timing commands for the weapon attack minigame (AttackMinigame.gd): every weapon family has
# its own short action command, and how well it is executed scales the attack's damage
# (miss / hit / perfect -- the multipliers live in Main.gd: ATTACK_TIMING_*_MULT).
#
# A command is a Dictionary:
#   kind      "slide" | "ring" | "sweep" | "hold" | "beats" | "cross" -- how it plays and is drawn
#   name      shown in the popup
#   hit_ms / perfect_ms   half-width of the hit / perfect window around the target time(s)
# plus per-kind fields (see COMMANDS). Everything here is a first draft meant to be tuned by feel.
#
# The classify_* functions are pure (times in, a grade out) and unit-tested.

const MISS := "miss"
const HIT := "hit"
const PERFECT := "perfect"

# How a multi-tap command (beats) scores: each beat is worth SCORE_*, the result is PERFECT when
# nothing missed and the average reaches BEATS_PERFECT_AVG, HIT from BEATS_HIT_AVG, otherwise MISS.
# BEATS_STRAY_LIMIT or more taps that belonged to no beat (spamming) drop the result one tier.
const SCORE_PERFECT := 1.0
const SCORE_HIT := 0.6
const BEATS_PERFECT_AVG := 0.85
const BEATS_HIT_AVG := 0.4
const BEATS_STRAY_LIMIT := 2

const COMMANDS := {
	# A marker slides along a bar -- press while it is in the zone.
	"club": {"kind": "slide", "name": "Swing", "target_ms": 700, "hit_ms": 140, "perfect_ms": 50, "end_ms": 1150},
	# A ring shrinks onto a target: narrow, high risk.
	"spear": {"kind": "ring", "name": "Thrust", "target_ms": 650, "hit_ms": 95, "perfect_ms": 32, "end_ms": 1000},
	# An arm sweeps round a circle -- press while it is inside the highlighted arc.
	"greatsword": {"kind": "sweep", "name": "Cleave", "target_ms": 950, "hit_ms": 150, "perfect_ms": 55, "end_ms": 1300},
	# Hold to fill a meter, release inside the zone (overcharging is a miss).
	"hammer": {"kind": "hold", "name": "Windup", "fill_ms": 1000, "zone": [0.72, 0.92], "perfect": [0.80, 0.88], "wait_ms": 1500},
	"battle_axe": {"kind": "hold", "name": "Heave", "fill_ms": 1200, "zone": [0.78, 0.94], "perfect": [0.85, 0.91], "wait_ms": 1500},
	# Tap a short run of pulses.
	"dagger": {"kind": "beats", "name": "Quick Taps", "beats": [400, 640, 880], "hit_ms": 110, "perfect_ms": 45},
	"knuckle_gloves": {"kind": "beats", "name": "One-Two", "beats": [450, 770], "hit_ms": 120, "perfect_ms": 48},
	"hand_picks": {"kind": "beats", "name": "Pick Pick", "beats": [420, 680], "hit_ms": 115, "perfect_ms": 46},
	# A crosshair swings back and forth -- press as it crosses the centre (your first press counts).
	"bow": {"kind": "cross", "name": "Steady Aim", "crossings": [450, 900, 1350], "hit_ms": 85, "perfect_ms": 30, "end_ms": 1650},
}

const KINDS := ["slide", "ring", "sweep", "hold", "beats", "cross"]

# The command for a weapon's base id ("club", "spear", ...); anything unknown plays like the Club.
# A fresh copy -- callers (the popup, tests) may tweak it.
static func command_for(base_id: String) -> Dictionary:
	return COMMANDS.get(base_id, COMMANDS["club"]).duplicate(true)

# The family a weapon id belongs to: ids are "<base>", "<base>_<tier>_<material>" or "<base>_mythic"
# (see Weapons.get_base_type); anything unrecognised plays like the Club.
static func base_id_for(weapon_id: String) -> String:
	for base in COMMANDS:
		if weapon_id == base or weapon_id.begins_with("%s_" % base):
			return base
	return "club"

static func command_for_weapon(weapon: Dictionary) -> Dictionary:
	return command_for(base_id_for(str(weapon.get("id", ""))))

# Grades a single press against a single target time.
static func classify_tap(press_ms: float, target_ms: float, hit_ms: float, perfect_ms: float) -> String:
	var off: float = absf(press_ms - target_ms)
	if off <= perfect_ms:
		return PERFECT
	if off <= hit_ms:
		return HIT
	return MISS

# The bow's crosshair passes the centre repeatedly: a press is graded against the nearest pass.
static func classify_cross(press_ms: float, crossings: Array, hit_ms: float, perfect_ms: float) -> String:
	var best: float = INF
	for c in crossings:
		best = minf(best, absf(press_ms - float(c)))
	if best == INF:
		return MISS
	return classify_tap(0.0, best, hit_ms, perfect_ms)

# Hold-and-release: the meter reads held_ms / fill_ms; it must stop inside `zone` ([lo, hi]),
# and inside `perfect_zone` to be perfect. Past 1.0 (still holding when it overfills) is a miss.
static func classify_hold(held_ms: float, fill_ms: float, zone: Array, perfect_zone: Array) -> String:
	var v: float = held_ms / maxf(1.0, fill_ms)
	if v > 1.0:
		return MISS
	if v >= float(perfect_zone[0]) and v <= float(perfect_zone[1]):
		return PERFECT
	if v >= float(zone[0]) and v <= float(zone[1]):
		return HIT
	return MISS

# A run of beats: each press is matched to the nearest unmatched beat it is within hit_ms of;
# presses that match nothing are strays. Returns {"result", "beats": [grade per beat], "strays"}.
static func classify_beats(presses: Array, beats: Array, hit_ms: float, perfect_ms: float) -> Dictionary:
	var used := []
	for i in presses.size():
		used.append(false)
	var grades := []
	var total := 0.0
	var misses := 0
	for b in beats:
		var best_i := -1
		var best_off: float = INF
		for i in presses.size():
			if used[i]:
				continue
			var off: float = absf(float(presses[i]) - float(b))
			if off <= hit_ms and off < best_off:
				best_off = off
				best_i = i
		var grade := MISS
		if best_i >= 0:
			used[best_i] = true
			grade = classify_tap(float(presses[best_i]), float(b), hit_ms, perfect_ms)
		grades.append(grade)
		match grade:
			PERFECT: total += SCORE_PERFECT
			HIT: total += SCORE_HIT
			_: misses += 1
	var strays := 0
	for u in used:
		if not u:
			strays += 1
	var avg: float = total / maxf(1.0, float(beats.size()))
	var result := MISS
	if misses == 0 and avg >= BEATS_PERFECT_AVG:
		result = PERFECT
	elif avg >= BEATS_HIT_AVG:
		result = HIT
	if strays >= BEATS_STRAY_LIMIT:
		result = HIT if result == PERFECT else MISS
	return {"result": result, "beats": grades, "strays": strays}
