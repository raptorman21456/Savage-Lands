extends SceneTree

# PartyRulesScript.gd / PartyMember.gd: the party member model on its own (no battle, no
# Player). Checks the level-up model against the user's worked example, each kind's
# starting stats and growth multipliers, movement, Mana, the wolf's fixed stats and
# faint/loyalty rules, and that the XP curve is still the hero's.

const PartyRulesScript := preload("res://scripts/PartyRules.gd")
const PartyMemberScript := preload("res://scripts/PartyMember.gd")

func _levelled(kind: String, levels: int, pick_stat: String) -> RefCounted:
	var m: RefCounted = PartyMemberScript.create(1, kind)
	for i in levels:
		m.gain_xp(m.xp_to_next())
	while m.picks > 0:
		m.spend_pick(pick_stat)
	return m

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var player_script = load("res://scripts/Player.gd")

	# --- Shared with the hero ---
	print("the XP curve is the hero's: base %s/%s, per level %s/%s, cap %s/%s (expected equal)" % [
		PartyRulesScript.XP_BASE, player_script.XP_BASE, PartyRulesScript.XP_PER_LEVEL, player_script.XP_PER_LEVEL, PartyRulesScript.MAX_LEVEL, player_script.MAX_LEVEL
	])
	print("the hero's speed rating starts at 5 and gives a tile per 4 points: SPEED_START=%.0f per_tile=%.0f (expected 5, 4)" % [PartyRulesScript.SPEED_START, PartyRulesScript.SPEED_PER_EXTRA_TILE])
	print("a pick of speed is worth 1 rating point and a level 0.2, the same as the hero's +5 and +1 agility out of 5: %.1f / %.1f (expected 1.0 / 0.2)" % [PartyRulesScript.PICK_GAIN.speed, PartyRulesScript.PASSIVE_GAIN.speed])

	# --- The user's worked example: Druid, 10 HP, five levels, every pick into HP = 22 ---
	var druid: RefCounted = PartyMemberScript.create(1, "druid")
	print("a fresh Druid: level=%d hp=%d (expected 1, 10)" % [druid.level, druid.max_hp()])
	for i in 5:
		druid.gain_xp(druid.xp_to_next())
	print("five levels earn five bonus picks: level=%d picks=%d (expected 6, 5)" % [druid.level, druid.picks])
	print("...and the passive gain alone is 5 x 1.2 = 6: hp=%d (expected 16)" % [druid.max_hp()])
	while druid.picks > 0:
		druid.spend_pick("hp")
	print("all five picks into HP: hp=%d (expected 22, the worked example)" % [druid.max_hp()])
	print("Druid attack grows at x0.5: 1 + 5 x 0.5 = %.1f (expected 3.5)" % [druid.attack()])
	print("Druid defense grows at x0.66: 5 x 0.66 = %.2f%% (expected 3.30)" % [druid.defense_pct()])

	# --- Each kind's start ---
	var guardian: RefCounted = PartyMemberScript.create(2, "guardian")
	var marksman: RefCounted = PartyMemberScript.create(3, "marksman")
	var rogue: RefCounted = PartyMemberScript.create(4, "rogue")
	print("starting HP: guardian=%d marksman=%d rogue=%d druid=%d (expected 25, 10, 20, 10)" % [guardian.max_hp(), marksman.max_hp(), rogue.max_hp(), PartyMemberScript.create(9, "druid").max_hp()])
	print("Guardian starts with 5 defense = a 5%% cut: %.1f (expected 5.0)" % [guardian.defense_pct()])

	# --- Growth multipliers ---
	var g3: RefCounted = _levelled("guardian", 3, "hp")
	print("Guardian HP grows at x1.25: 25 + (3 passive + 3 chosen) x 1.25 = %.1f (expected 32.5)" % [g3.stat("hp")])
	var g_def: RefCounted = _levelled("guardian", 2, "defense")
	print("Guardian defense grows at x2: 5 + (2 + 2) x 2 = %.1f (expected 13.0)" % [g_def.defense_pct()])
	var m3: RefCounted = _levelled("marksman", 4, "hp")
	print("Marksman HP grows 75%% slower: 10 + (4 + 4) x 0.25 = %.1f (expected 12.0)" % [m3.stat("hp")])
	print("...and its defense is always 0, so it can't even be picked: %.1f, pickable=%s (expected 0.0, no defense)" % [m3.defense_pct(), m3.pickable_stats()])
	var r2: RefCounted = _levelled("rogue", 2, "attack")
	print("Rogue attack grows +30%%: 1 + (2 + 2) x 1.3 = %.1f (expected 6.2)" % [r2.attack()])
	var r_speed: RefCounted = _levelled("rogue", 2, "speed")
	print("Rogue speed grows +40%%: 5 + (2 x 0.2 + 2 x 1.0) x 1.4 = %.2f (expected 8.36)" % [r_speed.speed()])
	var r_def: RefCounted = _levelled("rogue", 2, "hp")
	print("Rogue defense grows -30%% (passive only here): 0 + 2 x 0.7 = %.1f (expected 1.4)" % [r_def.defense_pct()])

	# --- Picks ---
	var fresh: RefCounted = PartyMemberScript.create(5, "druid")
	print("no pick to spend, no gain: %s (expected false)" % [fresh.spend_pick("hp")])
	fresh.gain_xp(fresh.xp_to_next())
	print("a stat a kind can't improve refuses the pick and keeps it: guardian speed -> %s (expected false, pick kept)" % [_levelled("guardian", 1, "hp").spend_pick("speed")])

	# --- Movement ---
	print("normal movement is the hero's 2 tiles: druid=%d rogue=%d (expected 2, 2)" % [PartyMemberScript.create(6, "druid").move_tiles(), PartyMemberScript.create(7, "rogue").move_tiles()])
	print("Guardian speed is ALWAYS one tile, even after speed-ish levels: %d (expected 1)" % [_levelled("guardian", 8, "hp").move_tiles()])
	print("Marksman: 1 tile + 0.07 per speed point = 1 at the start (rating 5): %d (expected 1)" % [marksman.move_tiles()])
	var m_fast: RefCounted = _levelled("marksman", 10, "speed")
	print("...and a Marksman with ten speed picks (rating %.1f) reaches %d tiles (expected 2)" % [m_fast.raw_stat("speed"), m_fast.move_tiles()])
	var d_fast: RefCounted = _levelled("druid", 4, "speed")
	print("a Druid with four speed picks (rating %.1f) gains a tile like the hero would: %d (expected 3)" % [d_fast.raw_stat("speed"), d_fast.move_tiles()])
	# Rogue: its own formula, not the hero's tile-per-4-rating one -- 2 + 0.12 x rating.
	print("Rogue: 2 + 0.12 x rating = 2 at the start (rating 5): %d (expected 2)" % [PartyMemberScript.create(13, "rogue").move_tiles()])
	var r_fast: RefCounted = _levelled("rogue", 3, "speed")
	print("...and with three speed picks (rating %.2f): 2 + 0.12 x %.2f = %d tiles (expected 3)" % [r_fast.raw_stat("speed"), r_fast.raw_stat("speed"), r_fast.move_tiles()])

	# --- Mana ---
	print("Druid Mana is 5 per point of Magic: magic=%.0f mana=%d (expected 10, 50)" % [PartyMemberScript.create(8, "druid").magic(), PartyMemberScript.create(8, "druid").max_mana()])
	var d_magic: RefCounted = _levelled("druid", 2, "magic")
	print("...and grows with it: magic=%.0f mana=%d (expected 14, 70)" % [d_magic.magic(), d_magic.max_mana()])
	print("a non-caster has no Mana: guardian=%d rogue=%d (expected 0, 0)" % [guardian.max_mana(), rogue.max_mana()])

	# --- The wolf ---
	var wolf: RefCounted = PartyMemberScript.create(10, "wolf")
	print("Fickle Wolf: hp=%d (20 x 0.9 = 18), attack=%.2f (1 x 1.25), defense=%.1f (0 x 0.75), speed rating=%.1f (5 x 1.5) (expected 18, 1.25, 0.0, 7.5)" % [wolf.max_hp(), wolf.attack(), wolf.defense_pct(), wolf.speed()])
	print("its 1.5x speed is 3 tiles instead of 2: %d (expected 3); stamina %d (expected 150)" % [wolf.move_tiles(), wolf.max_stamina()])
	print("a wolf does not level: gained=%d level=%d picks=%d (expected 0, 1, 0)" % [wolf.gain_xp(1000), wolf.level, wolf.picks])
	print("it faints twice and lives, the third time it dies: %s %s %s (expected false false true)" % [wolf.record_faint(), wolf.record_faint(), wolf.record_faint()])
	wolf.battles_left = 2
	print("loyalty counts down battle by battle and it leaves at zero: %s %s (expected false true)" % [wolf.spend_loyalty_battle(), wolf.spend_loyalty_battle()])
	var stayer: RefCounted = PartyMemberScript.create(11, "guardian")
	print("a member with no loyalty limit never leaves: %s (expected false)" % [stayer.spend_loyalty_battle()])
	print("how long a wolf stays: base %d, +5 Wolf Fang %d, +5 and Pack Bond III (+9) %d (expected 10, 15, 24)" % [
		PartyRulesScript.wolf_stay_battles(0, 0), PartyRulesScript.wolf_stay_battles(5, 0), PartyRulesScript.wolf_stay_battles(5, 9)
	])

	# --- XP ---
	var xp_m: RefCounted = PartyMemberScript.create(12, "rogue")
	print("XP below the threshold banks it: gained=%d xp=%d level=%d (expected 0, 10, 1)" % [xp_m.gain_xp(10), xp_m.xp, xp_m.level])
	print("a big award can level more than once: gained=%d (expected 2), level=%d picks=%d (expected 3, 2)" % [xp_m.gain_xp(28 + 36), xp_m.level, xp_m.picks])

	quit()
