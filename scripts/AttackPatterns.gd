extends RefCounted

# Timing patterns for the dodge / block minigames (DefenseMinigame.gd).
#
# A pattern is ONE enemy attack as the player sees it. Every number is tunable:
#   name         shown in the popup
#   style        how the telegraph is drawn: "flash" | "bar" | "ring" | "sweep" | "volley"
#   impacts      [{"ms": when the blow lands (from the popup opening), "mult": its share of the
#                 enemy's normal damage}] -- more than one entry means a multi-hit attack
#   dodge_ms     half-width of the dodge window around each impact (the dodge is the easier input)
#   weight       how often a boss rolls this attack
#
# Plain enemies have one attack (a quick jab and a heavy post-wind-up blow where they have
# them); bosses have up to three. Everything below is a first draft meant to be tuned by feel.

const PARRY_MS := 45

# ---- the archetypes plain enemies share (tuned by hand per enemy where it matters) ----
const JAB := {"name": "Quick Strike", "style": "flash", "impacts": [{"ms": 520, "mult": 1.0}], "dodge_ms": 180, "weight": 1.0}
const HEAVY := {"name": "Heavy Blow", "style": "ring", "impacts": [{"ms": 950, "mult": 1.0}], "dodge_ms": 150, "weight": 1.0}
const LUNGE := {"name": "Lunge", "style": "bar", "impacts": [{"ms": 580, "mult": 1.0}], "dodge_ms": 170, "weight": 1.0}
const PROJECTILE := {"name": "Projectile", "style": "bar", "impacts": [{"ms": 720, "mult": 1.0}], "dodge_ms": 180, "weight": 1.0}
const SWEEP := {"name": "Wide Sweep", "style": "sweep", "impacts": [{"ms": 1050, "mult": 1.0}], "dodge_ms": 140, "weight": 1.0}

# Plain enemies: name -> {"normal": pattern, "jab": pattern (quick jab), "heavy": pattern (the blow after a wind-up)}.
# Anything missing falls back to an archetype chosen from its traits (see pattern_for).
const PLAIN := {
	"Goblin": {"normal": {"name": "Stab", "style": "flash", "impacts": [{"ms": 500, "mult": 1.0}], "dodge_ms": 185, "weight": 1.0}},
	"Orc": {
		"normal": {"name": "Overhead Smash", "style": "ring", "impacts": [{"ms": 950, "mult": 1.0}], "dodge_ms": 150, "weight": 1.0},
		"heavy": {"name": "Overhead Smash", "style": "ring", "impacts": [{"ms": 950, "mult": 1.0}], "dodge_ms": 150, "weight": 1.0},
		"jab": {"name": "Quick Jab", "style": "flash", "impacts": [{"ms": 470, "mult": 1.0}], "dodge_ms": 170, "weight": 1.0},
	},
	"Brute": {"normal": {"name": "Haymaker", "style": "ring", "impacts": [{"ms": 880, "mult": 1.0}], "dodge_ms": 155, "weight": 1.0}},
	"Shade": {"normal": {"name": "Shadow Strike", "style": "flash", "impacts": [{"ms": 420, "mult": 1.0}], "dodge_ms": 160, "weight": 1.0}},
	"Wolf": {"normal": {"name": "Pounce", "style": "bar", "impacts": [{"ms": 540, "mult": 1.0}], "dodge_ms": 175, "weight": 1.0}},
	"Traitor Wolf": {"normal": {"name": "Pounce", "style": "bar", "impacts": [{"ms": 540, "mult": 1.0}], "dodge_ms": 175, "weight": 1.0}},
	"Apprentice Mage": {"normal": {"name": "Arcane Bolt", "style": "bar", "impacts": [{"ms": 760, "mult": 1.0}], "dodge_ms": 180, "weight": 1.0}},
	"Centaur Lancer": {"normal": {"name": "Charge", "style": "bar", "impacts": [{"ms": 640, "mult": 1.0}], "dodge_ms": 165, "weight": 1.0}},
	"Centaur Archer": {"normal": {"name": "Arrow Shot", "style": "bar", "impacts": [{"ms": 600, "mult": 1.0}], "dodge_ms": 175, "weight": 1.0}},
	"Gnome": {"normal": {"name": "Pointy Stick", "style": "flash", "impacts": [{"ms": 480, "mult": 1.0}], "dodge_ms": 185, "weight": 1.0}},
	"Fae": {"normal": {"name": "Sting", "style": "flash", "impacts": [{"ms": 450, "mult": 1.0}], "dodge_ms": 185, "weight": 1.0}},
	# Not an enemy: the Guardian's Earbursting Bellow, which the hero has to avoid (Main.gd:_resolve_bellow).
	"Guardian": {"normal": {"name": "Earbursting Bellow", "style": "ring", "impacts": [{"ms": 950, "mult": 1.0}], "dodge_ms": 175, "weight": 1.0}},
}

# Bosses and mini-bosses: up to three attacks each. The first is their heavy blow (what they land after
# a wind-up); the second is a quicker multi-hit; the third is their signature move.
const BOSS_NAMES := {
	"Leviathan": ["Tentacle Lash", "Mind Pulse", "Tidal Crush"],
	"Lizen Warband": ["Spear Volley", "Scurry Stab", "Shield Rush"],
	"Black Dragonlet": ["Claw Swipe", "Tail Whip", "Smoky Breath"],
	"Treant": ["Root Slam", "Branch Jab", "Thorn Sweep"],
	"Elder Oak": ["Trunk Smash", "Twig Barrage", "Canopy Sweep"],
	"Iron Construct": ["Piston Punch", "Rivet Jabs", "Slag Sweep"],
	"White Dragon": ["Frost Bite", "Wing Slap", "Blizzard Breath"],
	"Lava Construct": ["Magma Fist", "Ember Jabs", "Eruption"],
	"Red Wyrm": ["Wyrm Bite", "Tail Lash", "Inferno Breath"],
	"Voidwing": ["Void Rend", "Shadow Flicker", "Starless Gust"],
	"Archmage": ["Hex Bolt", "Rapid Curses", "Doom Wave"],
}

static var _cache := {}

static func is_boss(enemy_name: String, traits: Dictionary) -> bool:
	return bool(traits.get("is_boss_tier", false)) or BOSS_NAMES.has(enemy_name)

# Every attack this enemy can use (a fresh copy -- callers may tweak it).
static func patterns_for(enemy_name: String, traits: Dictionary) -> Array:
	var key := enemy_name
	if not _cache.has(key):
		_cache[key] = _build(enemy_name, traits)
	return _cache[key].duplicate(true)

static func _build(enemy_name: String, traits: Dictionary) -> Array:
	if is_boss(enemy_name, traits):
		return _boss_patterns(enemy_name, traits)
	var entry: Dictionary = PLAIN.get(enemy_name, {})
	var normal: Dictionary = entry.get("normal", _archetype(traits))
	var out := [normal.duplicate(true)]
	if entry.has("heavy"):
		out.append(entry.heavy.duplicate(true))
	if entry.has("jab"):
		out.append(entry.jab.duplicate(true))
	return out

static func _archetype(traits: Dictionary) -> Dictionary:
	if traits.get("sweeps", false):
		return SWEEP
	if int(traits.get("attack_range", 1)) > 1:
		return PROJECTILE
	if traits.get("windup", false):
		return HEAVY
	return JAB

# A small deterministic wobble so no two bosses share a timing (stable per name).
static func _wobble(enemy_name: String, slot: int, spread: int) -> int:
	return int(posmod(hash("%s/%d" % [enemy_name, slot]), spread * 2 + 1)) - spread

static func _boss_patterns(enemy_name: String, traits: Dictionary) -> Array:
	var names: Array = BOSS_NAMES.get(enemy_name, ["Heavy Blow", "Flurry", "Signature Attack"])
	var heavy_ms: int = 1000 + _wobble(enemy_name, 0, 120)
	var flurry_a: int = 430 + _wobble(enemy_name, 1, 50)
	var flurry_b: int = flurry_a + 340 + _wobble(enemy_name, 2, 40)
	var sig_ms: int = 1080 + _wobble(enemy_name, 3, 100)
	var signature_style := "sweep" if traits.get("sweeps", false) else ("volley" if int(traits.get("attack_range", 1)) > 1 else "ring")
	var heavy := {"name": names[0], "style": "ring", "impacts": [{"ms": heavy_ms, "mult": 1.0}], "dodge_ms": 140 + _wobble(enemy_name, 4, 15), "weight": 2.0}
	var flurry := {"name": names[1], "style": "flash", "impacts": [{"ms": flurry_a, "mult": 0.6}, {"ms": flurry_b, "mult": 0.6}], "dodge_ms": 160 + _wobble(enemy_name, 5, 15), "weight": 2.0}
	var signature := {"name": names[2], "style": signature_style, "impacts": [{"ms": sig_ms, "mult": 1.15}], "dodge_ms": 135 + _wobble(enemy_name, 6, 15), "weight": 1.0}
	if signature_style == "volley":
		signature.impacts = [{"ms": sig_ms - 380, "mult": 0.45}, {"ms": sig_ms, "mult": 0.45}, {"ms": sig_ms + 380, "mult": 0.45}]
	return [heavy, flurry, signature]

# Which attack an enemy uses this time. `kind` is how the caller reached the attack:
# "heavy" (the blow after a wind-up), "jab" (a quick jab instead of winding up), "normal".
static func pick(enemy_name: String, traits: Dictionary, kind: String, rng: RandomNumberGenerator = null) -> Dictionary:
	var all: Array = patterns_for(enemy_name, traits)
	if is_boss(enemy_name, traits):
		if kind == "heavy":
			return all[0]
		if kind == "jab" and all.size() > 1:
			return all[1]
		return _weighted(all, rng)
	if kind == "heavy" and all.size() > 1:
		return all[1]
	if kind == "jab" and all.size() > 2:
		return all[2]
	return all[0]

static func _weighted(all: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0.0
	for p in all:
		total += float(p.get("weight", 1.0))
	var roll: float = (rng.randf() if rng != null else randf()) * total
	for p in all:
		roll -= float(p.get("weight", 1.0))
		if roll <= 0.0:
			return p
	return all[all.size() - 1]

# Total share of the enemy's damage the pattern delivers if nothing is avoided.
static func total_mult(pattern: Dictionary) -> float:
	var total := 0.0
	for hit in pattern.impacts:
		total += float(hit.mult)
	return total

# ---------------------------------------------------------------- pure timing maths (unit-tested)
# How well a single press landed against an impact: "perfect" (inside the inner 40%
# of the window), "good" (inside the window), or "miss".
static func classify_dodge(press_ms: float, impact_ms: float, window_ms: float) -> String:
	var off: float = absf(press_ms - impact_ms)
	if off <= window_ms * 0.4:
		return "perfect"
	if off <= window_ms:
		return "good"
	return "miss"

# What the shield did at an impact. `events` is [[time_ms, pressed_bool], ...] in order and
# `held_at_start` whether the key was already down when the popup opened. A raise OR a
# lower within parry_ms of the impact is a "parry"; otherwise the shield being up at the
# impact is a "block"; down is a "fail".
static func classify_block(events: Array, held_at_start: bool, impact_ms: float, parry_ms: float) -> String:
	var held := held_at_start
	var parried := false
	for e in events:
		var t: float = float(e[0])
		if t > impact_ms + parry_ms:
			break
		if absf(t - impact_ms) <= parry_ms:
			parried = true
		if t <= impact_ms:
			held = bool(e[1])
	if parried:
		return "parry"
	return "block" if held else "fail"
