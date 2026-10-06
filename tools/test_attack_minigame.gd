extends SceneTree

# Weapon attack timing minigame: the pure grading maths and per-weapon commands (AttackTimings.gd),
# the popup's own real-time input handling (AttackMinigame.gd), and how a result scales a real attack
# (Main.gd: _battle_perform_attack). Every other test runs with the minigames OFF (Settings turns
# them off under --script); this one switches the attack minigame on and restores it at the end.

const AttackTimings := preload("res://scripts/AttackTimings.gd")
const AttackMinigame := preload("res://scripts/AttackMinigame.gd")

func _make_goblin(main, tile: Vector2i, hp: int = 999999) -> Dictionary:
	var g = load("res://scripts/Enemy.gd").new()
	main.add_child(g)
	g.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	return {
		"ref": g, "tile": tile, "hp": hp, "max_hp": hp, "move_range": 2,
		"damage": 1, "name": "Goblin", "winding_up": false, "stunned": false,
		"attack_range": 1, "concussed_turns": 0, "frozen_turns": 0,
		"burning": false, "armored": false,
		"disarmed_tile": Vector2i(-1, -1),
	}

# Runs one popup with real input timing: starts it, injects the given [ms, pressed] events (their
# timestamps are honoured against the real clock), waits for it to finish, returns the result string.
func _run_popup(dm, command: Dictionary, events: Array = []) -> String:
	var finished := [false]
	dm.finished.connect(func(): finished[0] = true, CONNECT_ONE_SHOT)
	dm.run(command)
	for e in events:
		dm._events.append(e)
	var started: int = Time.get_ticks_msec()
	while not finished[0] and Time.get_ticks_msec() - started < 6000:
		await process_frame
	return dm._result

func _setup_duel(main, hp: int = 999999) -> Dictionary:
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_allies = []
	main.battle_player_tile = Vector2i(4, 4)
	main.battle_target_index = 0
	main.battle_turn = "player"
	main.tutorial_active = false
	main.battle_player_defending = false
	var g := _make_goblin(main, Vector2i(5, 4), hp)
	main.battle_units = [g]
	return g

func _attack(main, g: Dictionary, action: Dictionary, forced: Array, seed_value: int = 7) -> int:
	g.hp = g.max_hp
	main.battle_turn = "player"
	main.battle_units = [g]
	main.battle_player_tile = Vector2i(4, 4)
	g.tile = Vector2i(5, 4)
	AttackMinigame.forced_results = forced.duplicate()
	seed(seed_value)
	await main._battle_perform_attack(action.duplicate(true))
	return g.max_hp - g.hp

func _init() -> void:
	seed(20261005)

	# =========================================================
	# Grading maths
	# =========================================================
	var tap_cases := [
		["dead on", 700.0, 700.0, 140.0, 50.0, "perfect"],
		["edge of perfect", 750.0, 700.0, 140.0, 50.0, "perfect"],
		["just outside perfect", 751.0, 700.0, 140.0, 50.0, "hit"],
		["edge of hit (early)", 560.0, 700.0, 140.0, 50.0, "hit"],
		["just outside hit", 841.0, 700.0, 140.0, 50.0, "miss"],
		["way early", 100.0, 700.0, 140.0, 50.0, "miss"],
	]
	for c in tap_cases:
		print("tap: %s -> %s (expected %s)" % [c[0], AttackTimings.classify_tap(c[1], c[2], c[3], c[4]), c[5]])
	var cross := [450.0, 900.0, 1350.0]
	print("cross: a press at the second pass (+20) -> %s (expected perfect)" % [AttackTimings.classify_cross(920.0, cross, 85.0, 30.0)])
	print("cross: a press between passes -> %s (expected miss)" % [AttackTimings.classify_cross(675.0, cross, 85.0, 30.0)])
	print("cross: a press 60 ms off the third pass -> %s (expected hit)" % [AttackTimings.classify_cross(1410.0, cross, 85.0, 30.0)])
	var zone := [0.72, 0.92]
	var perfect := [0.80, 0.88]
	var hold_cases := [
		["released at 84%", 840.0, "perfect"], ["released at 75%", 750.0, "hit"], ["released at 91%", 910.0, "hit"],
		["released at 50%", 500.0, "miss"], ["released at 95%", 950.0, "miss"], ["held past 100% (overcharged)", 1200.0, "miss"],
	]
	for c in hold_cases:
		print("hold: %s -> %s (expected %s)" % [c[0], AttackTimings.classify_hold(c[1], 1000.0, zone, perfect), c[2]])
	var beats := [400.0, 640.0, 880.0]
	var beat_cases := [
		["all three dead on", [400.0, 640.0, 880.0], "perfect"],
		["two perfect, one hit", [400.0, 640.0, 960.0], "perfect"],
		["one perfect, two hits", [400.0, 700.0, 940.0], "hit"],
		["a beat missed entirely", [400.0, 640.0], "hit"],
		["only one beat landed", [400.0], "miss"],
		["no taps at all", [], "miss"],
		["perfect but two stray taps (spamming)", [100.0, 400.0, 640.0, 880.0, 1500.0], "hit"],
		["hits plus two stray taps", [400.0, 700.0, 940.0, 100.0, 1500.0], "miss"],
	]
	for c in beat_cases:
		var out: Dictionary = AttackTimings.classify_beats(c[1], beats, 110.0, 45.0)
		print("beats: %s -> %s (expected %s) strays=%d" % [c[0], out.result, c[2], out.strays])
	print("beats: one press can only satisfy one beat: %s (expected miss)" % [AttackTimings.classify_beats([400.0], [400.0, 420.0, 440.0], 110.0, 45.0).result])

	# =========================================================
	# Commands
	# =========================================================
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	var settings = main.settings
	var saved_attack_setting: bool = settings.attack_minigame_enabled
	var weapons_script = load("res://scripts/Weapons.gd")

	var bases := [weapons_script.CLUB]
	bases.append_array(weapons_script.UPGRADABLE_TYPES)
	var cmd_problems := []
	var kinds_seen := {}
	for base in bases:
		var cmd: Dictionary = AttackTimings.command_for(str(base.id))
		kinds_seen[cmd.get("kind", "?")] = true
		var ok: bool = AttackTimings.COMMANDS.has(str(base.id)) and AttackTimings.KINDS.has(cmd.get("kind", "")) and str(cmd.get("name", "")) != ""
		match cmd.get("kind", ""):
			"hold":
				ok = ok and float(cmd.fill_ms) > 0.0 and cmd.zone[0] < cmd.zone[1] and cmd.perfect[0] >= cmd.zone[0] and cmd.perfect[1] <= cmd.zone[1] and cmd.zone[1] < 1.0
			"beats":
				ok = ok and cmd.beats.size() >= 2 and float(cmd.perfect_ms) < float(cmd.hit_ms)
				for i in range(1, cmd.beats.size()):
					ok = ok and float(cmd.beats[i]) - float(cmd.beats[i - 1]) > 2.0 * float(cmd.hit_ms) * 0.9
			"cross":
				ok = ok and cmd.crossings.size() >= 2 and float(cmd.perfect_ms) < float(cmd.hit_ms)
			_:
				ok = ok and float(cmd.target_ms) < float(cmd.end_ms) and float(cmd.perfect_ms) < float(cmd.hit_ms)
		if not ok:
			cmd_problems.append(base.id)
	print("Every weapon family (%d) has a valid command: problems=%s (expected [])" % [bases.size(), cmd_problems])
	print("The 6 command styles are all in use: %s (expected 6)" % [kinds_seen.size()])
	print("An unknown weapon id plays like the Club: %s (expected Swing)" % [AttackTimings.command_for("mystery_blade").name])
	var id_cases := {"club": "club", "spear_fine_steel": "spear", "battle_axe_worn_wood": "battle_axe", "hammer_mythic": "hammer", "bow": "bow",
		"knuckle_gloves_masterwork_gold": "knuckle_gloves", "hand_picks_fine_bone": "hand_picks", "greatsword": "greatsword", "dagger_legendary_silver": "dagger", "mystery_blade": "club"}
	var id_bad := []
	for id in id_cases:
		if AttackTimings.base_id_for(id) != id_cases[id]:
			id_bad.append(id)
	print("A weapon id resolves to its family (variants, Mythics, base ids; unknown -> club): problems=%s (expected [])" % [id_bad])
	print("command_for_weapon follows the wielded weapon: %s / %s / %s (expected Heave / Quick Taps / Steady Aim)" % [
		AttackTimings.command_for_weapon({"id": "battle_axe_fine_steel"}).name, AttackTimings.command_for_weapon({"id": "dagger_mythic"}).name, AttackTimings.command_for_weapon({"id": "bow_worn_wood"}).name
	])
	var tampered: Dictionary = AttackTimings.command_for("club")
	tampered["name"] = "tampered"
	print("command_for hands out copies: %s (expected true)" % [AttackTimings.command_for("club").name != "tampered"])

	# =========================================================
	# The popup's own input timing (real clock)
	# =========================================================
	var dm = AttackMinigame.new()
	root.add_child(dm)
	await process_frame
	var slide := {"kind": "slide", "name": "T", "target_ms": 150, "hit_ms": 60, "perfect_ms": 20, "end_ms": 300}
	print("Popup slide: a press 2 ms off the target is %s (expected perfect)" % [await _run_popup(dm, slide, [[148.0, true]])])
	print("Popup slide: a press 50 ms off is %s (expected hit)" % [await _run_popup(dm, slide, [[200.0, true]])])
	print("Popup slide: a press 140 ms off is %s (expected miss)" % [await _run_popup(dm, slide, [[290.0, true]])])
	print("Popup slide: no press at all times out as %s (expected miss)" % [await _run_popup(dm, slide, [])])
	print("Popup slide: only the FIRST press counts (a good one, then a bad one): %s (expected perfect)" % [await _run_popup(dm, slide, [[149.0, true], [290.0, true]])])
	print("Popup slide: a release alone is ignored: %s (expected miss)" % [await _run_popup(dm, slide, [[150.0, false]])])
	var ring := {"kind": "ring", "name": "T", "target_ms": 150, "hit_ms": 60, "perfect_ms": 20, "end_ms": 300}
	print("Popup ring: a press dead on is %s (expected perfect)" % [await _run_popup(dm, ring, [[150.0, true]])])
	var sweep := {"kind": "sweep", "name": "T", "target_ms": 150, "hit_ms": 60, "perfect_ms": 20, "end_ms": 300}
	print("Popup sweep: a press 40 ms late is %s (expected hit)" % [await _run_popup(dm, sweep, [[190.0, true]])])
	var cross_cmd := {"kind": "cross", "name": "T", "crossings": [100, 250, 400], "hit_ms": 60, "perfect_ms": 20, "end_ms": 500}
	print("Popup cross: a press at the second crossing is %s (expected perfect)" % [await _run_popup(dm, cross_cmd, [[252.0, true]])])
	var hold := {"kind": "hold", "name": "T", "fill_ms": 300, "zone": [0.7, 0.95], "perfect": [0.8, 0.9], "wait_ms": 500}
	print("Popup hold: press at 10, release at 260 (83%%) is %s (expected perfect)" % [await _run_popup(dm, hold, [[10.0, true], [260.0, false]])])
	print("Popup hold: release at 72%% is %s (expected hit)" % [await _run_popup(dm, hold, [[10.0, true], [225.0, false]])])
	print("Popup hold: an early release (33%%) is %s (expected miss)" % [await _run_popup(dm, hold, [[10.0, true], [110.0, false]])])
	print("Popup hold: never releasing overcharges into a %s (expected miss)" % [await _run_popup(dm, hold, [[10.0, true]])])
	print("Popup hold: never pressing times out as %s (expected miss)" % [await _run_popup(dm, hold, [])])
	var beats_cmd := {"kind": "beats", "name": "T", "beats": [100, 250, 400], "hit_ms": 50, "perfect_ms": 20}
	print("Popup beats: three clean taps are %s (expected perfect)" % [await _run_popup(dm, beats_cmd, [[100.0, true], [251.0, true], [398.0, true]])])
	print("Popup beats: the last beat dropped is %s (expected hit)" % [await _run_popup(dm, beats_cmd, [[100.0, true], [250.0, true]])])
	print("Popup beats: no taps is %s (expected miss)" % [await _run_popup(dm, beats_cmd, [])])
	var widened := {"kind": "slide", "name": "T", "target_ms": 150, "hit_ms": 20, "perfect_ms": 10, "end_ms": 300}
	var wide_result := [""]
	dm.finished.connect(func(): wide_result[0] = dm._result, CONNECT_ONE_SHOT)
	dm.run(widened, {"window_mult": 3.0})
	dm._events.append([190.0, true])
	var wide_started: int = Time.get_ticks_msec()
	while wide_result[0] == "" and Time.get_ticks_msec() - wide_started < 4000:
		await process_frame
	print("Popup: a window_mult of 3 widens a 20 ms hit window to 60 (a press 40 ms off is %s, expected hit)" % [wide_result[0]])

	var ev := InputEventKey.new()
	dm.run(slide)
	ev.keycode = settings.get_key("block")
	ev.pressed = true
	dm._input(ev)
	ev.keycode = settings.get_key("confirm")
	dm._input(ev)
	var echo := InputEventKey.new()
	echo.keycode = settings.get_key("block")
	echo.pressed = true
	echo.echo = true
	dm._input(echo)
	var other := InputEventKey.new()
	other.keycode = KEY_Q
	other.pressed = true
	dm._input(other)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	dm._input(click)
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	dm._input(right_click)
	print("Popup input: Space, Z and a left click each log a strike; echoes, other keys and right-click do not: events=%d (expected 3)" % [dm._events.size()])
	dm._running = false
	dm.finished.emit()
	await process_frame
	dm.queue_free()

	# Forced results short-circuit the UI completely.
	var fm = AttackMinigame.new()
	root.add_child(fm)
	AttackMinigame.forced_results = ["perfect", {"result": "hit", "note": 1}]
	var f1: Dictionary = await fm.run(slide)
	var f2: Dictionary = await fm.run(slide)
	print("forced_results answers instantly and is consumed: %s / %s left=%d (expected perfect / hit, 0)" % [f1.result, f2.result, AttackMinigame.forced_results.size()])
	fm.queue_free()

	# =========================================================
	# Settings
	# =========================================================
	print("The attack minigame starts OFF in scripted runs (so every other test is unaffected): %s (expected false)" % [saved_attack_setting])

	# =========================================================
	# Combat flows
	# =========================================================
	player.equipped_armor = {"damage_reduction": 0.0}
	player.max_health = 500
	player.health = 500
	player.attack_damage = 100
	player.meta_crit_chance = 0.0
	player.current_weapon = weapons_script.CLUB
	player.max_stamina = 100
	settings.attack_minigame_enabled = true
	var g := _setup_duel(main)
	var plain := {"stamina_cost": 0, "dmg_mult": 1.0, "effect": "", "name": "Attack", "is_regular_attack": true}

	var d_hit: int = await _attack(main, g, plain, ["hit"])
	var d_perfect: int = await _attack(main, g, plain, ["perfect"])
	var d_miss: int = await _attack(main, g, plain, ["miss"])
	var d_off: int = 0
	settings.attack_minigame_enabled = false
	d_off = await _attack(main, g, plain, [])
	settings.attack_minigame_enabled = true
	print("A HIT deals the weapon's normal damage (the same as with the minigame off): hit=%d off=%d (expected equal)" % [d_hit, d_off])
	print("A PERFECT deals about 125%%: perfect=%d vs hit=%d, ratio=%.2f (expected ~1.25)" % [d_perfect, d_hit, float(d_perfect) / float(maxi(1, d_hit))])
	print("A MISS deals about 80%%: miss=%d vs hit=%d, ratio=%.2f (expected ~0.80)" % [d_miss, d_hit, float(d_miss) / float(maxi(1, d_hit))])
	print("...and the forced results were all consumed: left=%d (expected 0)" % [AttackMinigame.forced_results.size()])

	# stamina: a perfect refunds a little
	player.stamina = 20
	await _attack(main, g, plain, ["hit"])
	var stamina_after_hit: int = player.stamina
	player.stamina = 20
	await _attack(main, g, plain, ["perfect"])
	var stamina_after_perfect: int = player.stamina
	player.stamina = 20
	await _attack(main, g, plain, ["miss"])
	print("A perfect refunds %d stamina on top of the normal regen: hit=%d perfect=%d miss=%d (expected perfect = hit + %d, miss = hit)" % [
		main.ATTACK_TIMING_PERFECT_STAMINA, stamina_after_hit, stamina_after_perfect, player.stamina, main.ATTACK_TIMING_PERFECT_STAMINA
	])

	# heavy attack and damaging specials use it too; a flurry scales every hit
	var heavy_hit: int = await _attack(main, g, {"stamina_cost": 0, "dmg_mult": 1.5, "effect": "", "name": "Heavy Attack"}, ["hit"])
	var heavy_perfect: int = await _attack(main, g, {"stamina_cost": 0, "dmg_mult": 1.5, "effect": "", "name": "Heavy Attack"}, ["perfect"])
	print("Heavy Attack scales too: hit=%d perfect=%d ratio=%.2f (expected ~1.25)" % [heavy_hit, heavy_perfect, float(heavy_perfect) / float(maxi(1, heavy_hit))])
	var flurry := {"stamina_cost": 0, "dmg_mult": 0.5, "effect": "", "name": "Test Flurry", "hit_count_min": 3, "hit_count_max": 3}
	var flurry_hit: int = await _attack(main, g, flurry, ["hit"])
	var flurry_perfect: int = await _attack(main, g, flurry, ["perfect"])
	print("A 3-hit flurry scales every hit: hit=%d perfect=%d ratio=%.2f (expected ~1.25)" % [flurry_hit, flurry_perfect, float(flurry_perfect) / float(maxi(1, flurry_hit))])

	# the bypasses: forced results must stay untouched
	AttackMinigame.forced_results = ["perfect"]
	var zero_a := {"stamina_cost": 0, "dmg_mult": 0.0, "effect": "pichaku", "name": "Pichaku"}
	g.hp = g.max_hp
	main.battle_turn = "player"
	main.battle_units = [g]
	await main._battle_perform_attack(zero_a)
	print("A non-damaging special (dmg_mult 0) skips the popup: forced left=%d (expected 1)" % [AttackMinigame.forced_results.size()])
	player.pichaku_active = false   # the special above switched it on; it would skew every later damage reading
	settings.attack_minigame_enabled = false
	var by_off: int = await _attack(main, g, plain, ["perfect"])
	print("The setting OFF skips the popup: damage=%d (expected the normal %d), forced left=%d (expected 1)" % [by_off, d_hit, AttackMinigame.forced_results.size()])
	settings.attack_minigame_enabled = true
	main.tutorial_active = true
	var by_tutorial: int = await _attack(main, g, plain, ["perfect"])
	print("The tutorial battle skips the popup: damage=%d (expected the normal %d), forced left=%d (expected 1)" % [by_tutorial, d_hit, AttackMinigame.forced_results.size()])
	main.tutorial_active = false
	AttackMinigame.forced_results = []

	# no target / not enough stamina: the popup never opens
	g.tile = Vector2i(0, 0)
	main.battle_units = [g]
	main.battle_turn = "player"
	AttackMinigame.forced_results = ["perfect"]
	await main._battle_perform_attack(plain.duplicate())
	print("With nothing in range the popup never opens: forced left=%d (expected 1), turn=%s (expected player)" % [AttackMinigame.forced_results.size(), main.battle_turn])
	AttackMinigame.forced_results = []
	player.stamina = 0
	g.tile = Vector2i(5, 4)
	await main._battle_perform_attack({"stamina_cost": 50, "dmg_mult": 1.0, "effect": "", "name": "Costly"})
	AttackMinigame.forced_results = ["perfect"]
	await main._battle_perform_attack({"stamina_cost": 50, "dmg_mult": 1.0, "effect": "", "name": "Costly"})
	print("Without the stamina the popup never opens either: forced left=%d (expected 1)" % [AttackMinigame.forced_results.size()])
	AttackMinigame.forced_results = []
	player.stamina = 100

	# the full chain with a REAL popup (club, perfect press near 700 ms): the turn parks on "attack",
	# the menus hide, other input is refused, and the damage matches a forced perfect.
	g.hp = g.max_hp
	g.tile = Vector2i(5, 4)
	main.battle_turn = "player"
	main.battle_units = [g]
	main.battle_player_tile = Vector2i(4, 4)
	seed(7)
	main._battle_perform_attack(plain.duplicate())
	print("While the popup is up the turn is parked on 'attack': %s (expected attack)" % [main.battle_turn])
	print("...the battle menus are hidden: main=%s fight=%s (expected false, false)" % [main.hud.battle_main_menu_box.visible, main.hud.battle_fight_submenu_box.visible])
	var hp_during: int = g.hp
	main._on_battle_fight_action("attack")
	main._on_battle_main_action("fight")
	print("...and other battle input is refused: hp unchanged=%s turn still attack=%s (expected true, true)" % [g.hp == hp_during, main.battle_turn == "attack"])
	main.attack_minigame._events.append([695.0, true])
	var chain_started: int = Time.get_ticks_msec()
	while g.hp == g.max_hp and Time.get_ticks_msec() - chain_started < 5000:
		await process_frame
	var d_real: int = g.max_hp - g.hp
	print("A real, well-timed Club swing deals the same as a forced perfect: real=%d forced=%d (expected equal)" % [d_real, d_perfect])
	print("...and the turn passed on normally: turn=%s (expected player)" % [main.battle_turn])

	settings.attack_minigame_enabled = saved_attack_setting
	AttackMinigame.forced_results = []
	quit()
