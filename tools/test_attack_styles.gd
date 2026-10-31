extends SceneTree

# The new weapon attack styles: the pure grading of each (AttackTimings.gd), the dice each swing rolls, and how the popup plays them
# with real input timing (AttackMinigame.gd), plus how a result reaches a real attack -- the Dagger's extra strikes, and a party
# caster's spell potency (Main.gd). Every other test runs with the minigames off; this one switches the attack minigame on and
# restores it at the end.

const AT := preload("res://scripts/AttackTimings.gd")
const AM := preload("res://scripts/AttackMinigame.gd")

func _run_popup(dm, command: Dictionary, events: Array = [], opts: Dictionary = {}, inject: PackedVector2Array = PackedVector2Array()) -> Dictionary:
	var finished := [false]
	var out := [{}]
	dm.finished.connect(func(): finished[0] = true, CONNECT_ONE_SHOT)
	dm.run(command, opts)
	for e in events:
		dm._events.append(e)
	if inject.size() > 0:
		dm.inject_trace(inject)
	var started: int = Time.get_ticks_msec()
	while not finished[0] and Time.get_ticks_msec() - started < 7000:
		await process_frame
	out[0] = {"result": dm._result}
	out[0].merge(dm._extra)
	return out[0]

func _make_goblin(main, tile: Vector2i, hp: int = 999999) -> Dictionary:
	var g = load("res://scripts/Enemy.gd").new()
	main.add_child(g)
	g.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	return {
		"ref": g, "tile": tile, "hp": hp, "max_hp": hp, "move_range": 2, "damage": 1, "name": "Goblin", "winding_up": false, "stunned": false,
		"attack_range": 1, "concussed_turns": 0, "frozen_turns": 0, "burning": false, "armored": false, "disarmed_tile": Vector2i(-1, -1),
	}

func _init() -> void:
	seed(20261031)

	# --- Club: the zone is dead centre of the bar ---
	var club: Dictionary = AT.command_for("club")
	print("Club: the marker slides across the bar and the zone is dead centre: kind=%s target=%d of %d (expected slide, 550 of 1100)" % [club.kind, club.target_ms, club.end_ms])

	# --- Greatsword: the same, on an arc ---
	var gs: Dictionary = AT.command_for("greatsword")
	print("Greatsword: the Club's bar, curved: kind=%s, zone centred=%s (expected arc, true)" % [gs.kind, absf(float(gs.target_ms) * 2.0 - float(gs.end_ms)) < 1.0])

	# --- Battle axe: the falling gauge ---
	var axe: Dictionary = AT.roll(AT.command_for("battle_axe"))
	print("Axe: a random band is rolled inside the allowed range: zone=%s (expected a 0.2-wide band between 0.42 and 0.86)" % [axe.zone])
	var hammered: Array = []
	for i in 40:
		hammered.append(float(AT.roll(AT.command_for("battle_axe")).zone[0]))
	print("...and it really is random: %d different bands in 40 rolls (expected many)" % [_distinct(hammered)])
	var steady := {"limit_ms": 3200.0, "fall_per_s": 0.5, "gain": 0.075, "need_ms": 450.0, "zone": [0.4, 0.6], "core_share": 0.6}
	var no_clicks: Dictionary = AT.mash_replay([], steady, 1500.0)
	print("Axe: with no clicks the gauge sits empty and nothing happens yet: value=%.2f result='%s' (expected 0.00, '')" % [no_clicks.value, no_clicks.result])
	print("...and the time running out is a miss: '%s' (expected miss)" % [AT.mash_replay([], steady, 3300.0).result])
	# a quick burst to lift the gauge into the band, then a steady click every 150 ms (just enough to cancel the fall) to hold it there
	var spam: Array = []
	for i in 10:
		spam.append(100.0 + float(i) * 40.0)
	for i in 20:
		spam.append(520.0 + float(i) * 150.0)
	var spam_result: Dictionary = AT.mash_replay(spam, steady, 3200.0)
	print("Axe: a burst then a steady rhythm lifts the gauge into the band and holds it there: result=%s in_zone=%.0f ms (expected hit or perfect, 450)" % [spam_result.result, spam_result.in_zone_ms])
	var heavy: Array = []
	for i in 60:
		heavy.append(50.0 + float(i) * 40.0)
	print("...clicking far too fast overshoots the band and the gauge sits at the top: result='%s' by 1500ms (expected '' or a result reached early)" % [AT.mash_replay(heavy, steady, 1500.0).result])
	print("A gauge that falls cannot be left alone: one early burst then nothing = %s at the limit (expected miss)" % [AT.mash_replay([100.0, 120.0, 140.0, 160.0, 180.0], steady, 3300.0).result])

	# --- Dagger: markers ---
	var rolled_counts := {}
	var rolled_ok := true
	for i in 60:
		var d: Dictionary = AT.roll(AT.command_for("dagger"))
		rolled_counts[d.beats.size()] = true
		for k in range(1, d.beats.size()):
			if float(d.beats[k]) - float(d.beats[k - 1]) < 230.0:
				rolled_ok = false
	print("Dagger: 2 to 4 markers are rolled, in a random rhythm: counts seen=%s, gaps >= 230 ms: %s (expected [2, 3, 4], true)" % [rolled_counts.keys(), rolled_ok])
	var dag_beats := [450.0, 700.0, 1000.0]
	var dag_all: Dictionary = AT.classify_beats([452.0, 699.0, 1003.0], dag_beats, 120.0, 42.0)
	var dag_two: Dictionary = AT.classify_beats([452.0, 699.0], dag_beats, 120.0, 42.0)
	print("Dagger: every marker hit counts as a hit for a strike: all three -> hits=%d perfects=%d (expected 3, 3); two of three -> hits=%d (expected 2)" % [dag_all.hits, dag_all.perfects, dag_two.hits])

	# --- Knuckle gloves: two circles, Z and X ---
	var twin_cmd: Dictionary = AT.roll(AT.command_for("knuckle_gloves"))
	var key_set := [twin_cmd.targets[0].key, twin_cmd.targets[1].key]
	key_set.sort()
	print("Gloves: two circles, one for each key, the second after the first: keys=%s (expected [x, z]), %d ms then %d ms" % [key_set, twin_cmd.targets[0].ms, twin_cmd.targets[1].ms])
	var apart_ok := true
	for i in 40:
		var t: Dictionary = AT.roll(AT.command_for("knuckle_gloves"))
		if Vector2(t.targets[0].pos).distance_to(Vector2(t.targets[1].pos)) < 0.3:
			apart_ok = false
	print("...and they sit apart from each other somewhere on the screen: %s (expected true)" % [apart_ok])
	var targets := [{"ms": 700.0, "key": "z"}, {"ms": 1000.0, "key": "x"}]
	print("Gloves: both on time with the right keys is %s (expected perfect)" % [AT.classify_twin([[702.0, "z"], [998.0, "x"]], targets, 130.0, 50.0).result])
	print("...the right time on the WRONG keys is %s (expected miss)" % [AT.classify_twin([[700.0, "x"], [1000.0, "z"]], targets, 130.0, 50.0).result])
	print("...only one circle answered is %s (expected hit, it is worth a tap at the first one)" % [AT.classify_twin([[700.0, "z"]], targets, 130.0, 50.0).result])
	print("...nothing pressed is %s (expected miss)" % [AT.classify_twin([], targets, 130.0, 50.0).result])

	# --- Hand picks: the shifting dial ---
	var orbit_cmd := {"fill_ms": 1500.0, "start_deg": 100.0, "drift_dps": 90.0}
	print("Picks: the zone drifts round the dial: at 0 ms %.0f deg, at 1000 ms %.0f deg (expected 100, 190); reversed it goes the other way: %.0f (expected 10)" % [
		AT.orbit_zone_deg(orbit_cmd, 0.0), AT.orbit_zone_deg(orbit_cmd, 1000.0), AT.orbit_zone_deg({"start_deg": 100.0, "drift_dps": -90.0}, 1000.0)])
	print("Picks: releasing with the arm inside the zone: arm at 190 deg vs zone at 190 -> %s (expected perfect)" % [AT.classify_orbit(1500.0 * 190.0 / 360.0, 1500.0, 190.0, 24.0, 9.0)])
	print("...20 degrees off is %s (expected hit), 60 off is %s (expected miss), and across the top of the dial (arm 350, zone 10) is %s (expected hit)" % [
		AT.classify_orbit(1500.0 * 210.0 / 360.0, 1500.0, 190.0, 24.0, 9.0), AT.classify_orbit(1500.0 * 250.0 / 360.0, 1500.0, 190.0, 24.0, 9.0),
		AT.classify_orbit(1500.0 * 350.0 / 360.0, 1500.0, 10.0, 24.0, 9.0)])
	print("...holding past a full turn overcharges: %s (expected miss)" % [AT.classify_orbit(1600.0, 1500.0, 90.0, 24.0, 9.0)])

	# --- Wand: shapes ---
	var shape_ok := true
	for id in AT.SHAPES:
		var pts: PackedVector2Array = AT.shape_points(id)
		var closed: bool = AT.SHAPES[id].closed
		if pts.size() < 4 or (closed and pts[0].distance_to(pts[pts.size() - 1]) > 0.001):
			shape_ok = false
	print("Wand: all %d shapes have an outline, the closed ones end where they start: %s (expected true)" % [AT.SHAPES.size(), shape_ok])
	print("...the harder the shape the more it is worth: circle %.2f, square %.2f, star %.2f, spiral %.2f (expected rising, 1.0 to 1.5)" % [AT.shape_power("circle"), AT.shape_power("square"), AT.shape_power("star"), AT.shape_power("spiral")])
	var circle := PackedVector2Array()
	for p in AT.shape_points("circle"):
		circle.append(Vector2(200, 200) + p * 100.0)
	var wobbly := PackedVector2Array()
	for i in circle.size():
		wobbly.append(circle[i] + Vector2(sin(float(i) * 1.3) * 6.0, cos(float(i) * 1.7) * 6.0))
	var perfect_trace: Dictionary = AT.trace_score(circle, circle, 16.0)
	var wobbly_trace: Dictionary = AT.trace_score(wobbly, circle, 16.0)
	var half_circle := PackedVector2Array()
	for i in 25:
		half_circle.append(circle[i])
	var half_trace: Dictionary = AT.trace_score(half_circle, circle, 16.0)
	var scribble := PackedVector2Array()
	for i in 80:
		scribble.append(Vector2(100.0 + float(i % 9) * 25.0, 100.0 + float((i * 7) % 11) * 20.0))
	print("Wand: the exact outline is %s (cover %.2f, precise %.2f; expected perfect), a slightly wobbly one %s (expected perfect or hit)" % [perfect_trace.result, perfect_trace.coverage, perfect_trace.precision, wobbly_trace.result])
	print("...half the circle is %s (cover %.2f; expected miss), a scribble is %s (precision %.2f; expected miss), no stroke is %s (expected miss)" % [
		half_trace.result, half_trace.coverage, AT.trace_score(scribble, circle, 16.0).result, AT.trace_score(scribble, circle, 16.0).precision, AT.trace_score(PackedVector2Array(), circle, 16.0).result])
	var shifted := PackedVector2Array()
	for p in circle:
		shifted.append(p + Vector2(70, 0))
	print("...the right shape in the wrong place is %s (expected miss)" % [AT.trace_score(shifted, circle, 16.0).result])
	var resampled: PackedVector2Array = AT.resample(circle, 32)
	print("resample() spreads points evenly along the line: %d points, ends kept: %s (expected 32, true)" % [resampled.size(), resampled[0].is_equal_approx(circle[0]) and resampled[31].distance_to(circle[circle.size() - 1]) < 1.0])

	# --- Staff: arrow keys ---
	var counts_ok := true
	for spell in AT.ARROW_COUNTS:
		var c: int = int(AT.ARROW_COUNTS[spell])
		if c < 4 or c > 7:
			counts_ok = false
	print("Staff: every spell asks for 4 to 7 arrows: %s (expected true); Vitalize %d, Poison Bomb %d, I SUMMON THEE %d, anything else %d (expected 4, 6, 7, 5)" % [
		counts_ok, AT.roll(AT.command_for("staff"), {"spell_id": "druid_heal"}).sequence.size(), AT.roll(AT.command_for("staff"), {"spell_id": "staff_poison_bomb"}).sequence.size(),
		AT.roll(AT.command_for("staff"), {"spell_id": "staff_i_summon_thee"}).sequence.size(), AT.roll(AT.command_for("staff")).sequence.size()])
	var seen_dirs := {}
	for i in 30:
		for d in AT.roll(AT.command_for("staff")).sequence:
			seen_dirs[d] = true
	print("...made of random arrows (all four turn up): %s (expected 4)" % [seen_dirs.size()])
	var seq := ["up", "left", "left", "down"]
	print("Staff: the right keys in order, fast, is %s (expected perfect); slowly, %s (expected hit)" % [
		AT.classify_arrows([[100.0, "up"], [300.0, "left"], [500.0, "left"], [700.0, "down"]], seq, 3200.0, 1500.0).result,
		AT.classify_arrows([[500.0, "up"], [1100.0, "left"], [1900.0, "left"], [2500.0, "down"]], seq, 3200.0, 1500.0).result])
	var wrong: Dictionary = AT.classify_arrows([[100.0, "up"], [300.0, "right"]], seq, 3200.0, 1500.0)
	print("...a wrong key ends it as a miss: %s after %d right (expected miss, 1), wrong=%s (expected true)" % [wrong.result, wrong.progress, wrong.wrong])
	print("...stopping half way is still going until the limit: '%s' at 2000ms, '%s' at 3300ms (expected '', miss)" % [
		AT.classify_arrows([[100.0, "up"]], seq, 3200.0, 1500.0, 2000.0).result, AT.classify_arrows([[100.0, "up"]], seq, 3200.0, 1500.0, 3300.0).result])
	print("...a key pressed after the limit does not count: %s (expected miss)" % [AT.classify_arrows([[100.0, "up"], [300.0, "left"], [500.0, "left"], [3300.0, "down"]], seq, 3200.0, 1500.0, 3400.0).result])

	# --- rolls are repeatable and leave the template alone ---
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 99
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 99
	var roll_a: Dictionary = AT.roll(AT.command_for("dagger"), {}, rng_a)
	var roll_b: Dictionary = AT.roll(AT.command_for("dagger"), {}, rng_b)
	print("A seeded roll repeats: %s (expected true); the template has no markers of its own: %s (expected true)" % [roll_a.beats == roll_b.beats, not AT.COMMANDS["dagger"].has("beats")])
	var preset := {"kind": "markers", "beats": [10, 20], "travel_ms": 100, "count": [2, 4], "first_ms": [1, 2], "gap_ms": [1, 2], "hit_ms": 5, "perfect_ms": 2}
	print("A command that spells out its own markers keeps them: %s (expected [10, 20])" % [AT.roll(preset).beats])

	# =========================================================
	# The popup, in real time
	# =========================================================
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var settings = main.settings
	var saved_setting: bool = settings.attack_minigame_enabled
	var dm = AM.new()
	root.add_child(dm)
	await process_frame

	var mash_cmd := {"kind": "mash", "name": "T", "limit_ms": 1500.0, "fall_per_s": 0.5, "gain": 0.075, "need_ms": 300.0, "zone": [0.3, 0.6], "zone_width": 0.3, "zone_range": [0.3, 0.6], "core_share": 0.6}
	var mash_presses: Array = []
	for i in 14:
		mash_presses.append([60.0 + float(i) * 55.0, true])
	var mash_out: Dictionary = await _run_popup(dm, mash_cmd, mash_presses)
	print("Popup mash: steady clicking holds the gauge in the band: %s (expected hit or perfect)" % [mash_out.result])
	print("Popup mash: no clicks at all times out as %s (expected miss)" % [(await _run_popup(dm, mash_cmd, [])).result])

	var markers_cmd := {"kind": "markers", "name": "T", "beats": [100.0, 260.0, 420.0], "travel_ms": 300.0, "hit_ms": 50.0, "perfect_ms": 20.0}
	var m_out: Dictionary = await _run_popup(dm, markers_cmd, [[101.0, true], [259.0, true], [600.0, true]])
	print("Popup markers: two of three hit (a stray press late): hits=%s markers=%s (expected 2, 3)" % [m_out.get("hits"), m_out.get("markers")])

	var twin_cmd2 := {"kind": "twin", "name": "T", "targets": [{"ms": 150.0, "key": "z", "pos": Vector2(0.3, 0.4)}, {"ms": 320.0, "key": "x", "pos": Vector2(0.7, 0.6)}],
		"close_ms": 200.0, "end_ms": 460.0, "hit_ms": 60.0, "perfect_ms": 25.0}
	print("Popup twin: Z then X on time is %s (expected perfect)" % [(await _run_popup(dm, twin_cmd2, [[151.0, true, "z"], [319.0, true, "x"]])).result])
	print("Popup twin: the right times on the wrong keys is %s (expected miss)" % [(await _run_popup(dm, twin_cmd2, [[150.0, true, "x"], [320.0, true, "z"]])).result])
	var kev := InputEventKey.new()
	dm.run(twin_cmd2)
	kev.keycode = settings.get_key("confirm")
	kev.pressed = true
	dm._input(kev)
	kev = InputEventKey.new()
	kev.keycode = settings.get_key("cancel")
	kev.pressed = true
	dm._input(kev)
	var stray := InputEventKey.new()
	stray.keycode = KEY_Q
	stray.pressed = true
	dm._input(stray)
	var tags: Array = dm._events.map(func(e): return e[2])
	print("Popup twin: the Confirm key logs a Z press and the Cancel key an X press, other keys nothing: %s (expected [z, x])" % [tags])
	dm._running = false
	dm.finished.emit()
	await process_frame

	var orbit_popup := {"kind": "orbit", "name": "T", "fill_ms": 400.0, "start_deg": 180.0, "drift_dps": 0.0, "hit_deg": 30.0, "perfect_deg": 10.0, "wait_ms": 600.0}
	print("Popup orbit: held for half a turn (200 ms) with the zone at 180 degrees is %s (expected perfect)" % [(await _run_popup(dm, orbit_popup, [[10.0, true], [210.0, false]])).result])
	print("Popup orbit: released at a quarter turn is %s (expected miss)" % [(await _run_popup(dm, orbit_popup, [[10.0, true], [110.0, false]])).result])
	print("Popup orbit: never releasing overcharges into a %s (expected miss)" % [(await _run_popup(dm, orbit_popup, [[10.0, true]])).result])

	var arrows_cmd := {"kind": "arrows", "name": "T", "sequence": ["up", "down", "left"], "limit_ms": 700.0, "fast_ms": 300.0, "count": 3, "per_key_ms": 230.0, "fast_per_key_ms": 100.0}
	print("Popup arrows: three right keys quickly is %s (expected perfect)" % [(await _run_popup(dm, arrows_cmd, [[50.0, true, "up"], [120.0, true, "down"], [200.0, true, "left"]])).result])
	var arrows_wrong: Dictionary = await _run_popup(dm, arrows_cmd, [[50.0, true, "up"], [120.0, true, "left"]])
	print("Popup arrows: a wrong key is a %s after %s right (expected miss, 1)" % [arrows_wrong.result, arrows_wrong.get("progress")])
	print("Popup arrows: pressing nothing runs out as %s (expected miss)" % [(await _run_popup(dm, arrows_cmd, [])).result])
	var aev := InputEventKey.new()
	dm.run(arrows_cmd)
	aev.keycode = KEY_UP
	aev.pressed = true
	dm._input(aev)
	var aecho := InputEventKey.new()
	aecho.keycode = KEY_UP
	aecho.pressed = true
	aecho.echo = true
	dm._input(aecho)
	var arel := InputEventKey.new()
	arel.keycode = KEY_UP
	arel.pressed = false
	dm._input(arel)
	var aother := InputEventKey.new()
	aother.keycode = KEY_Z
	aother.pressed = true
	dm._input(aother)
	print("Popup arrows: an arrow key logs once; echoes, releases and other keys do not: events=%d (expected 1)" % [dm._events.size()])
	dm._running = false
	dm.finished.emit()
	await process_frame

	var trace_cmd := {"kind": "trace", "name": "T", "shape": "circle", "spin": 0.0, "limit_ms": 600.0, "tolerance": 16.0}
	# The popup places the shape itself; build a stroke along that same outline so the injected line matches.
	dm.run(trace_cmd)
	var on_shape: PackedVector2Array = dm._trace_shape.duplicate()
	dm._running = false
	dm.finished.emit()
	await process_frame
	var trace_good: Dictionary = await _run_popup(dm, trace_cmd, [], {}, on_shape)
	print("Popup trace: a stroke along the outline is %s, and says which shape and what it is worth: %s x%.2f (expected perfect, circle x1.00)" % [trace_good.result, trace_good.get("shape"), float(trace_good.get("power", 0.0))])
	var off_stroke := PackedVector2Array()
	for p in on_shape:
		off_stroke.append(p + Vector2(0, 160))
	print("Popup trace: the right shape drawn somewhere else is %s (expected miss)" % [(await _run_popup(dm, trace_cmd, [], {}, off_stroke)).result])
	print("Popup trace: never drawing anything times out as %s (expected miss)" % [(await _run_popup(dm, trace_cmd, [])).result])
	var star_cmd := {"kind": "trace", "name": "T", "shape": "star", "spin": 0.0, "limit_ms": 600.0, "tolerance": 16.0}
	dm.run(star_cmd)
	var star_line: PackedVector2Array = dm._trace_shape.duplicate()
	dm._running = false
	dm.finished.emit()
	await process_frame
	var star_out: Dictionary = await _run_popup(dm, star_cmd, [], {}, star_line)
	print("Popup trace: a star traced well is worth more than a circle: x%.2f (expected x1.40)" % [float(star_out.get("power", 0.0))])
	dm.queue_free()

	# =========================================================
	# What a result does to a real attack
	# =========================================================
	var player = main.player
	var weapons_script = load("res://scripts/Weapons.gd")
	player.equipped_armor = {"damage_reduction": 0.0}
	player.max_health = 500
	player.health = 500
	player.attack_damage = 100
	player.meta_crit_chance = 0.0
	player.max_stamina = 100
	player.stamina = 100
	settings.attack_minigame_enabled = true
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_allies = []
	main.battle_player_tile = Vector2i(4, 4)
	main.battle_target_index = 0
	main.battle_turn = "player"
	main.tutorial_active = false
	var g := _make_goblin(main, Vector2i(5, 4))
	main.battle_units = [g]
	var plain := {"stamina_cost": 0, "dmg_mult": 1.0, "effect": "", "name": "Attack", "is_regular_attack": true}
	player.current_weapon = weapons_script.CLUB
	var club_hit: int = await _attack(main, g, plain, ["hit"])
	player.current_weapon = weapons_script.DAGGER
	var one: int = await _attack(main, g, plain, [{"result": "hit", "hits": 1, "markers": 3}])
	var three: int = await _attack(main, g, plain, [{"result": "perfect", "hits": 3, "markers": 3}])
	var none: int = await _attack(main, g, plain, [{"result": "miss", "hits": 0, "markers": 3}])
	print("Dagger: each marker hit is a strike -- one hit deals %d, three hits deal %d (ratio %.2f, expected about 3), none still lands one weak strike %d (expected under the one-hit damage)" % [one, three, float(three) / float(maxi(1, one)), none])
	print("...a strike is worth %.0f%% of the swing: one marker deals %d, against the same swing's plain %d (expected about 45%% of it)" % [main.ATTACK_MARKER_STRIKE_MULT * 100.0, one, club_hit * int(round(weapons_script.DAGGER.damage_mult * 100.0)) / 100])
	var dagger_special := {"stamina_cost": 0, "dmg_mult": 1.0, "effect": "", "name": "Special"}
	var sp_hit: int = await _attack(main, g, dagger_special, [{"result": "hit", "hits": 3, "markers": 3}])
	print("A dagger SPECIAL keeps the usual miss/hit/perfect scaling (the markers' hit count does not add strikes): %d (expected the one-strike damage at 1.0x, not three)" % [sp_hit])

	# a caster's spell: the grade and the shape scale the spell's potency
	main.battle_actor = {"kind": "druid", "weapon": {"id": "staff_fine_silver"}, "name": "Druid", "tile": Vector2i(3, 3), "hp": 10, "max_hp": 10}
	main.battle_cast_mult = 1.0
	var base_potency: float = main._potency(main.battle_actor)
	main.battle_cast_mult = 1.25
	print("A spell's minigame grade multiplies its potency while it is cast: %.2f -> %.2f (expected x1.25)" % [base_potency, main._potency(main.battle_actor)])
	var other_unit := {"kind": "druid", "name": "Other", "tile": Vector2i(1, 1), "hp": 5, "max_hp": 5}
	print("...and only for the caster: another unit's potency is untouched: %.2f (expected %.2f)" % [main._potency(other_unit), base_potency])
	main.battle_cast_mult = 1.0
	var spell_action := {"id": "druid_heal", "stamina_cost": 0, "dmg_mult": 0.0, "effect": "", "name": "Restore"}
	print("A party member casting a spell with a Staff plays the minigame (even a healing spell with no damage): %s (expected true)" % [main._attack_minigame_on(spell_action)])
	main.battle_actor["weapon"] = {"id": "wand_fine_silver"}
	print("...a Wand too: %s (expected true)" % [main._attack_minigame_on(spell_action)])
	main.battle_actor["weapon"] = {"id": "club"}
	var club_caster: bool = main._attack_minigame_on(spell_action)
	main.battle_actor["weapon"] = {"id": "staff_fine_silver"}
	var staff_plain: bool = main._attack_minigame_on(plain)
	print("...but not a member with a Club: %s (expected false); not their plain attack with a Staff: %s (expected false)" % [club_caster, staff_plain])
	main.battle_actor["echo"] = true
	print("...nor an Echo's free recast: %s (expected false)" % [main._attack_minigame_on(spell_action)])
	main.battle_actor = {}
	print("...and the hero's own attack still does: %s (expected true)" % [main._attack_minigame_on(plain)])

	# the Debug menu's tester
	var DB = load("res://scripts/DebugBattle.gd")
	var all_commands := true
	for style in DB.ATTACK_STYLES:
		if not AT.COMMANDS.has(str(style[0])):
			all_commands = false
	print("The Debug menu's tester lists %d styles and every one is a real command: %s (expected 11, true)" % [DB.ATTACK_STYLES.size(), all_commands])
	AM.forced_results = []
	var tester = main._get_attack_minigame()
	var played: Dictionary = DB.play_attack_style(main, "club")
	await process_frame
	print("Playing one opens the popup and asks the menu to close: ok=%s close=%s running=%s (expected true, true, true)" % [played.ok, played.get("close"), tester._running])
	print("...a second one while it is open is refused: ok=%s (expected false)" % [DB.play_attack_style(main, "spear").ok])
	tester._events.append([float(tester._now_ms()) + 540.0, true])
	var tester_started: int = Time.get_ticks_msec()
	while tester._running and Time.get_ticks_msec() - tester_started < 4000:
		await process_frame
	print("...and it ends on its own with a grade: running=%s result=%s (expected false, hit or perfect)" % [tester._running, tester._result])
	settings.attack_minigame_enabled = saved_setting
	AM.forced_results = []
	quit()


func _attack(main, g: Dictionary, action: Dictionary, forced: Array, seed_value: int = 7) -> int:
	g.hp = g.max_hp
	main.battle_turn = "player"
	main.battle_units = [g]
	main.battle_player_tile = Vector2i(4, 4)
	g.tile = Vector2i(5, 4)
	AM.forced_results = forced.duplicate()
	seed(seed_value)
	await main._battle_perform_attack(action.duplicate(true))
	return g.max_hp - g.hp

func _distinct(values: Array) -> int:
	var seen := {}
	for v in values:
		seen[snappedf(float(v), 0.0001)] = true
	return seen.size()
