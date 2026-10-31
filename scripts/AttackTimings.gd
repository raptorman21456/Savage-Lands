extends RefCounted

# Timing commands for the weapon attack minigame (AttackMinigame.gd): every weapon family has
# its own short action command, and how well it is executed scales the attack's damage
# (miss / hit / perfect -- the multipliers live in Main.gd: ATTACK_TIMING_*_MULT).
#
# A command is a Dictionary:
#   kind      how it plays and is drawn -- see KINDS and COMMANDS below
#   name      shown in the popup
# plus per-kind fields. Everything here is a first draft meant to be tuned by feel.
#
# A command is a TEMPLATE: the random parts (the dagger's markers, the gloves' two circles and where they sit, the axe's target
# band, the picks' drifting zone, the wand's shape, the staff's arrow keys) are rolled fresh for every swing by roll().
#
# The classify_* functions are pure (times in, a grade out) and unit-tested.

const MISS := "miss"
const HIT := "hit"
const PERFECT := "perfect"

# How a multi-tap command (markers, twin) scores: each tap is worth SCORE_*, the result is PERFECT when
# nothing missed and the average reaches BEATS_PERFECT_AVG, HIT from BEATS_HIT_AVG, otherwise MISS.
# BEATS_STRAY_LIMIT or more taps that belonged to no target (spamming) drop the result one tier.
const SCORE_PERFECT := 1.0
const SCORE_HIT := 0.6
const BEATS_PERFECT_AVG := 0.85
const BEATS_HIT_AVG := 0.4
const BEATS_STRAY_LIMIT := 2

const COMMANDS := {
	# Undertale-style: a marker slides across a bar and you press while it is inside the zone in the middle.
	"club": {"kind": "slide", "name": "Swing", "target_ms": 550, "hit_ms": 130, "perfect_ms": 45, "end_ms": 1100},
	# A ring shrinks onto a bullseye: narrow, high risk.
	"spear": {"kind": "ring", "name": "Thrust", "target_ms": 650, "hit_ms": 95, "perfect_ms": 32, "end_ms": 1000},
	# The Club's bar, bent into an arc: the marker rides the curve and the zone sits at the top of it.
	"greatsword": {"kind": "arc", "name": "Cleave", "target_ms": 800, "hit_ms": 140, "perfect_ms": 50, "end_ms": 1600},
	# Hold to fill a meter, release inside the zone (overcharging is a miss).
	"hammer": {"kind": "hold", "name": "Windup", "fill_ms": 1000, "zone": [0.72, 0.92], "perfect": [0.80, 0.88], "wait_ms": 1500},
	# Spam the button to push a constantly falling gauge up into a random band, and keep it there for a moment.
	"battle_axe": {"kind": "mash", "name": "Heave", "limit_ms": 3200, "fall_per_s": 0.5, "gain": 0.075, "need_ms": 450,
		"zone_width": 0.2, "zone_range": [0.42, 0.86], "core_share": 0.6},
	# The Club's bar with a random number of markers in a random rhythm: every marker you hit is another strike.
	"dagger": {"kind": "markers", "name": "Flurry", "count": [2, 4], "first_ms": [450, 700], "gap_ms": [230, 470], "travel_ms": 900,
		"hit_ms": 120, "perfect_ms": 42},
	# Two circles with closing rings somewhere on the screen: one is for Z, one for X.
	"knuckle_gloves": {"kind": "twin", "name": "One-Two", "first_ms": [700, 850], "gap_ms": [260, 460], "close_ms": 700,
		"hit_ms": 130, "perfect_ms": 50},
	# The Hammer, but round: hold to sweep an arm round a dial and release it inside a zone that keeps drifting.
	"hand_picks": {"kind": "orbit", "name": "Pick Pick", "fill_ms": 1500, "drift_dps": [70, 120], "hit_deg": 24.0, "perfect_deg": 9.0, "wait_ms": 1600},
	# A crosshair swings back and forth -- press as it crosses the centre (your first press counts).
	"bow": {"kind": "cross", "name": "Steady Aim", "crossings": [450, 900, 1350], "hit_ms": 85, "perfect_ms": 30, "end_ms": 1650},
	# Trace a random shape with the mouse; the harder the shape, the more power the spell gets.
	"wand": {"kind": "trace", "name": "Sigil", "limit_ms": 5000, "tolerance": 16.0},
	# Press 4-7 random arrow keys in order (how many depends on the spell).
	"staff": {"kind": "arrows", "name": "Incantation", "count": 5, "per_key_ms": 800, "fast_per_key_ms": 380},
}

const KINDS := ["slide", "ring", "arc", "hold", "mash", "markers", "twin", "orbit", "cross", "trace", "arrows"]

# The wand's shapes, in a unit box (y down), each with how hard it is: `power` is the multiplier a perfect trace of it gives the
# spell. A closed shape is walked round and back to its start; the spiral is open.
const SHAPES := {
	"circle": {"name": "Circle", "power": 1.0, "closed": true},
	"triangle": {"name": "Triangle", "power": 1.1, "closed": true},
	"square": {"name": "Square", "power": 1.15, "closed": true},
	"diamond": {"name": "Diamond", "power": 1.15, "closed": true},
	"pentagon": {"name": "Pentagon", "power": 1.25, "closed": true},
	"star": {"name": "Star", "power": 1.4, "closed": true},
	"spiral": {"name": "Spiral", "power": 1.5, "closed": false},
}
const TRACE_PERFECT_COVERAGE := 0.9
const TRACE_PERFECT_PRECISION := 0.85
const TRACE_HIT_COVERAGE := 0.6
const TRACE_HIT_PRECISION := 0.55

# How many arrow keys each spell asks for (draft): the bigger the spell, the longer the incantation. Anything else asks for 5.
const ARROW_COUNTS := {
	"druid_heal": 4, "druid_buff": 4, "shaman_how_charming": 4,
	"druid_sprint": 5, "shaman_soothing_rain": 5, "shaman_cleansing_chant": 5, "necromancer_curse_of_rot": 5,
	"necromancer_revival_blessing": 6, "necromancer_summon_the_dead": 6, "staff_i_cast_fireball": 6, "staff_landfall": 6,
	"staff_i_summon_thee": 7,
}
const ARROW_DIRS := ["up", "down", "left", "right"]

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

# --------------------------------------------------------------------------------------------- the random parts

# A command with this swing's dice rolled into it (the original is untouched). `opts` may carry the spell ("spell_id") for the staff's
# arrow count. Seed the generator to repeat a roll. Anything the command already spells out (a test's own beats, say) is left alone.
static func roll(command: Dictionary, opts: Dictionary = {}, rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var cmd: Dictionary = command.duplicate(true)
	match str(cmd.get("kind", "")):
		"markers":
			if cmd.has("beats"):
				return cmd
			var count: int = rng.randi_range(int(cmd.count[0]), int(cmd.count[1]))
			var times: Array = []
			var t: float = float(rng.randi_range(int(cmd.first_ms[0]), int(cmd.first_ms[1])))
			for i in count:
				times.append(t)
				t += float(rng.randi_range(int(cmd.gap_ms[0]), int(cmd.gap_ms[1])))
			cmd["beats"] = times
			cmd["end_ms"] = float(times[times.size() - 1]) + float(cmd.travel_ms) * 0.5 + 60.0
		"twin":
			if cmd.has("targets"):
				return cmd
			var first: float = float(rng.randi_range(int(cmd.first_ms[0]), int(cmd.first_ms[1])))
			var second: float = first + float(rng.randi_range(int(cmd.gap_ms[0]), int(cmd.gap_ms[1])))
			var keys: Array = ["z", "x"]
			if rng.randf() < 0.5:
				keys.reverse()
			# Two spots in the unit box that sit well apart (each kept off the very edge).
			var a := Vector2(rng.randf_range(0.18, 0.82), rng.randf_range(0.2, 0.8))
			var b := a
			for attempt in 40:
				b = Vector2(rng.randf_range(0.18, 0.82), rng.randf_range(0.2, 0.8))
				if a.distance_to(b) >= 0.4:
					break
			if a.distance_to(b) < 0.4:
				b = Vector2(0.2 if a.x > 0.5 else 0.8, 0.25 if a.y > 0.5 else 0.75)
			cmd["targets"] = [{"ms": first, "key": keys[0], "pos": a}, {"ms": second, "key": keys[1], "pos": b}]
			cmd["end_ms"] = second + float(cmd.hit_ms) + 120.0
		"mash":
			if cmd.has("zone"):
				return cmd
			var width: float = float(cmd.zone_width)
			var lo: float = rng.randf_range(float(cmd.zone_range[0]), float(cmd.zone_range[1]) - width)
			cmd["zone"] = [lo, lo + width]
		"orbit":
			if cmd.has("start_deg"):
				return cmd
			cmd["start_deg"] = rng.randf_range(0.0, 360.0)
			cmd["drift_dps"] = float(rng.randf_range(float(cmd.drift_dps[0]), float(cmd.drift_dps[1]))) * (1.0 if rng.randf() < 0.5 else -1.0)
		"trace":
			if cmd.has("shape"):
				return cmd
			var ids: Array = SHAPES.keys()
			cmd["shape"] = str(ids[rng.randi() % ids.size()])
			cmd["spin"] = rng.randf_range(-0.35, 0.35) if cmd.shape != "circle" else 0.0
		"arrows":
			if cmd.has("sequence"):
				return cmd
			var n: int = int(ARROW_COUNTS.get(str(opts.get("spell_id", "")), int(cmd.count)))
			var seq: Array = []
			for i in n:
				seq.append(ARROW_DIRS[rng.randi() % ARROW_DIRS.size()])
			cmd["sequence"] = seq
			cmd["limit_ms"] = float(cmd.per_key_ms) * float(n)
			cmd["fast_ms"] = float(cmd.fast_per_key_ms) * float(n)
	return cmd

# --------------------------------------------------------------------------------------------- grading

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

# A run of beats (the dagger's markers): each press is matched to the nearest unmatched beat it is within hit_ms of;
# presses that match nothing are strays. Returns {"result", "beats": [grade per beat], "strays", "hits", "perfects"}: `hits` counts the
# beats that were not missed -- for the dagger, one strike each.
static func classify_beats(presses: Array, beats: Array, hit_ms: float, perfect_ms: float) -> Dictionary:
	var used := []
	for i in presses.size():
		used.append(false)
	var grades := []
	var total := 0.0
	var misses := 0
	var hits := 0
	var perfects := 0
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
			PERFECT:
				total += SCORE_PERFECT
				hits += 1
				perfects += 1
			HIT:
				total += SCORE_HIT
				hits += 1
			_:
				misses += 1
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
	return {"result": result, "beats": grades, "strays": strays, "hits": hits, "perfects": perfects}

# The gloves' two circles: `presses` are [ms, key] pairs ("z" / "x"), `targets` the {ms, key} of each circle. A press only counts for
# the circle with its own key; each circle takes the nearest such press inside hit_ms. Scored like the dagger's beats (spamming counts
# as strays). Returns {"result", "grades": [per target], "strays"}.
static func classify_twin(presses: Array, targets: Array, hit_ms: float, perfect_ms: float) -> Dictionary:
	var used := []
	for i in presses.size():
		used.append(false)
	var grades := []
	var total := 0.0
	var misses := 0
	for t in targets:
		var best_i := -1
		var best_off: float = INF
		for i in presses.size():
			if used[i] or str(presses[i][1]) != str(t.key):
				continue
			var off: float = absf(float(presses[i][0]) - float(t.ms))
			if off <= hit_ms and off < best_off:
				best_off = off
				best_i = i
		var grade := MISS
		if best_i >= 0:
			used[best_i] = true
			grade = classify_tap(float(presses[best_i][0]), float(t.ms), hit_ms, perfect_ms)
		grades.append(grade)
		match grade:
			PERFECT: total += SCORE_PERFECT
			HIT: total += SCORE_HIT
			_: misses += 1
	var strays := 0
	for u in used:
		if not u:
			strays += 1
	var avg: float = total / maxf(1.0, float(targets.size()))
	var result := MISS
	if misses == 0 and avg >= BEATS_PERFECT_AVG:
		result = PERFECT
	elif avg >= BEATS_HIT_AVG:
		result = HIT
	if strays >= BEATS_STRAY_LIMIT:
		result = HIT if result == PERFECT else MISS
	return {"result": result, "grades": grades, "strays": strays}

# The axe's gauge, replayed from the presses so far: it starts empty, every press adds `gain`, it falls `fall_per_s` every second and
# stays within 0..1. The swing succeeds once the gauge has spent `need_ms` inside the target band; it is perfect when at least
# `core_share` of that time was in the middle third of the band, a plain hit otherwise. Running out of `limit_ms` first is a miss.
# Returns {"value", "in_zone_ms", "in_core_ms", "result" ("" while it is still going), "done_ms"}.
static func mash_replay(presses: Array, cmd: Dictionary, now_ms: float) -> Dictionary:
	var zone: Array = cmd.zone
	var lo: float = float(zone[0])
	var hi: float = float(zone[1])
	var third: float = (hi - lo) / 3.0
	var core_lo: float = lo + third
	var core_hi: float = hi - third
	var fall: float = float(cmd.fall_per_s) / 1000.0
	var gain: float = float(cmd.gain)
	var step := 5.0
	var value := 0.0
	var in_zone := 0.0
	var in_core := 0.0
	var next_press := 0
	var sorted: Array = presses.duplicate()
	sorted.sort()
	var t := 0.0
	var limit: float = minf(now_ms, float(cmd.limit_ms))
	while t < limit:
		while next_press < sorted.size() and float(sorted[next_press]) <= t:
			value = minf(1.0, value + gain)
			next_press += 1
		value = maxf(0.0, value - fall * step)
		t += step
		if value >= lo and value <= hi:
			in_zone += step
			if value >= core_lo and value <= core_hi:
				in_core += step
		if in_zone >= float(cmd.need_ms):
			var res: String = PERFECT if in_core >= in_zone * float(cmd.core_share) else HIT
			return {"value": value, "in_zone_ms": in_zone, "in_core_ms": in_core, "result": res, "done_ms": t}
	var done := ""
	if now_ms >= float(cmd.limit_ms):
		done = MISS
	return {"value": value, "in_zone_ms": in_zone, "in_core_ms": in_core, "result": done, "done_ms": minf(now_ms, float(cmd.limit_ms))}

# The picks' dial: the arm sweeps 360 degrees over fill_ms while held (so it points at held_ms / fill_ms of a turn, clockwise from the
# top); the zone's centre is `zone_deg` at the moment of release. Past a full turn is overcharged. Returns the grade.
static func classify_orbit(held_ms: float, fill_ms: float, zone_deg: float, hit_deg: float, perfect_deg: float) -> String:
	if held_ms > fill_ms:
		return MISS
	var arm: float = 360.0 * held_ms / maxf(1.0, fill_ms)
	var off: float = absf(fposmod(arm - zone_deg + 180.0, 360.0) - 180.0)
	if off <= perfect_deg:
		return PERFECT
	if off <= hit_deg:
		return HIT
	return MISS

# Where the drifting zone's centre is, in degrees clockwise from the top, `ms` into the swing.
static func orbit_zone_deg(cmd: Dictionary, ms: float) -> float:
	return fposmod(float(cmd.start_deg) + float(cmd.drift_dps) * ms / 1000.0, 360.0)

# The staff: `presses` are [ms, dir] pairs in the order they came. Each must be the next arrow in `sequence`; a wrong key ends it as a
# miss, and so does running out of `limit_ms`. Finishing within `fast_ms` is perfect, otherwise a hit. Returns {"result" ("" while it
# is still going), "progress" (how many are right so far), "wrong" (whether a wrong key ended it)}.
static func classify_arrows(presses: Array, sequence: Array, limit_ms: float, fast_ms: float, now_ms: float = INF) -> Dictionary:
	var progress := 0
	var last_ms := 0.0
	for p in presses:
		if float(p[0]) > limit_ms:
			break
		if str(p[1]) != str(sequence[progress]):
			return {"result": MISS, "progress": progress, "wrong": true}
		progress += 1
		last_ms = float(p[0])
		if progress >= sequence.size():
			return {"result": PERFECT if last_ms <= fast_ms else HIT, "progress": progress, "wrong": false}
	if now_ms > limit_ms:
		return {"result": MISS, "progress": progress, "wrong": false}
	return {"result": "", "progress": progress, "wrong": false}

# --------------------------------------------------------------------------------------------- the wand's shapes

# A shape's outline as points in the unit box (-1..1, y down), closed shapes ending where they began. `spin` turns it (radians).
static func shape_points(shape_id: String, spin: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match shape_id:
		"circle":
			for i in 49:
				var a: float = TAU * float(i) / 48.0 - PI / 2.0
				pts.append(Vector2(cos(a), sin(a)))
		"triangle":
			pts = _polygon(3, 1.0)
		"square":
			pts = PackedVector2Array([Vector2(-0.8, -0.8), Vector2(0.8, -0.8), Vector2(0.8, 0.8), Vector2(-0.8, 0.8), Vector2(-0.8, -0.8)])
		"diamond":
			pts = PackedVector2Array([Vector2(0, -1), Vector2(0.8, 0), Vector2(0, 1), Vector2(-0.8, 0), Vector2(0, -1)])
		"pentagon":
			pts = _polygon(5, 1.0)
		"star":
			for i in 11:
				var a2: float = TAU * float(i % 10) / 10.0 - PI / 2.0
				var r: float = 1.0 if i % 2 == 0 else 0.42
				pts.append(Vector2(cos(a2), sin(a2)) * r)
		"spiral":
			for i in 61:
				var f: float = float(i) / 60.0
				var a3: float = f * TAU * 1.75 - PI / 2.0
				pts.append(Vector2(cos(a3), sin(a3)) * (0.12 + 0.88 * f))
	if spin != 0.0:
		for i in pts.size():
			pts[i] = pts[i].rotated(spin)
	return pts

static func _polygon(sides: int, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in sides + 1:
		var a: float = TAU * float(i % sides) / float(sides) - PI / 2.0
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts

# Points along a polyline, evenly spaced (`count` of them).
static func resample(path: PackedVector2Array, count: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	if path.size() < 2 or count < 2:
		return path
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i].distance_to(path[i - 1])
	if total <= 0.0:
		return path
	var step: float = total / float(count - 1)
	var walked := 0.0
	var seg := 1
	var seg_start: float = 0.0
	out.append(path[0])
	for k in range(1, count):
		var want: float = step * float(k)
		while seg < path.size() - 1 and seg_start + path[seg].distance_to(path[seg - 1]) < want:
			seg_start += path[seg].distance_to(path[seg - 1])
			seg += 1
		var seg_len: float = path[seg].distance_to(path[seg - 1])
		var f: float = 0.0 if seg_len <= 0.0 else clampf((want - seg_start) / seg_len, 0.0, 1.0)
		out.append(path[seg - 1].lerp(path[seg], f))
	return out

static func _dist_to_path(p: Vector2, path: PackedVector2Array) -> float:
	var best: float = INF
	for i in range(1, path.size()):
		var a: Vector2 = path[i - 1]
		var b: Vector2 = path[i]
		var ab: Vector2 = b - a
		var len2: float = ab.length_squared()
		var f: float = 0.0 if len2 <= 0.0 else clampf((p - a).dot(ab) / len2, 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * f))
	return best

# How well a drawn line follows the shape: `coverage` is the share of the shape that has some of the line within `tolerance` of it,
# `precision` the share of the line that stays within 1.25x tolerance of the shape. Both must be high to be perfect. Scribbling all over
# covers the shape but ruins the precision; a short stroke is precise but covers little. Returns {"result", "coverage", "precision"}.
static func trace_score(drawn: PackedVector2Array, shape: PackedVector2Array, tolerance: float) -> Dictionary:
	if drawn.size() < 4 or shape.size() < 2:
		return {"result": MISS, "coverage": 0.0, "precision": 0.0}
	var shape_samples: PackedVector2Array = resample(shape, 64)
	var drawn_samples: PackedVector2Array = resample(drawn, 96)
	var covered := 0
	for s in shape_samples:
		if _dist_to_path(s, drawn) <= tolerance:
			covered += 1
	var near := 0
	for d in drawn_samples:
		if _dist_to_path(d, shape) <= tolerance * 1.25:
			near += 1
	var coverage: float = float(covered) / float(shape_samples.size())
	var precision: float = float(near) / float(drawn_samples.size())
	var result := MISS
	if coverage >= TRACE_PERFECT_COVERAGE and precision >= TRACE_PERFECT_PRECISION:
		result = PERFECT
	elif coverage >= TRACE_HIT_COVERAGE and precision >= TRACE_HIT_PRECISION:
		result = HIT
	return {"result": result, "coverage": coverage, "precision": precision}

# What a shape is worth to a spell: its `power` (a circle 1.0, a star 1.4, a spiral 1.5).
static func shape_power(shape_id: String) -> float:
	return float(SHAPES.get(shape_id, SHAPES["circle"]).power)
