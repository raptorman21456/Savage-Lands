extends SceneTree

# Dodge / block timing minigames: the pure timing maths (AttackPatterns.gd), the per-enemy
# pattern tables, the popup's own input timing (DefenseMinigame.gd), and how the outcomes
# change a real battle (Main.gd: _enemy_apply_damage / _resolve_minigame_results).
# Every other test runs with the minigames OFF (Settings turns them off under --script); this
# one switches them on and puts the setting back at the end.

const AttackPatterns := preload("res://scripts/AttackPatterns.gd")
const DefenseMinigame := preload("res://scripts/DefenseMinigame.gd")
const Sandbox := preload("res://scripts/Sandbox.gd")

var _done := false

func _make_goblin(main, tile: Vector2i, hp: int = 999) -> Dictionary:
	var g = load("res://scripts/Enemy.gd").new()
	main.add_child(g)
	g.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	return {
		"ref": g, "tile": tile, "hp": hp, "max_hp": hp, "move_range": 2,
		"damage": 3, "name": "Goblin", "winding_up": false, "stunned": false,
		"attack_range": 1, "concussed_turns": 0, "frozen_turns": 0,
		"burning": false, "armored": false,
		"disarmed_tile": Vector2i(-1, -1),
	}

# Runs one popup with real input timing: starts it, injects the given presses/events (times in
# ms from the popup opening), then waits for it to finish and returns its per-impact results.
func _run_popup(dm, mode: String, pattern: Dictionary, events: Array = [], presses: Array = [], opts: Dictionary = {}) -> Array:
	dm._resolved = []
	var finished := [false]
	dm.finished.connect(func(): finished[0] = true, CONNECT_ONE_SHOT)
	dm.run(mode, pattern, opts)
	for e in events:
		dm._events.append(e)
	for p in presses:
		dm._presses.append(p)
	var started: int = Time.get_ticks_msec()
	while not finished[0] and Time.get_ticks_msec() - started < 5000:
		await process_frame
	return dm._resolved.duplicate(true)

func _init() -> void:
	seed(20261004)

	# =========================================================
	# Timing maths
	# =========================================================
	print("PARRY_MS is the 45 ms the user asked for: %d (expected 45)" % [AttackPatterns.PARRY_MS])
	var d_cases := [
		["dead on", 500.0, 500.0, 160.0, "perfect"],
		["inside the inner 40%", 564.0, 500.0, 160.0, "perfect"],
		["just outside the inner 40%", 565.0, 500.0, 160.0, "good"],
		["early edge of the window", 340.0, 500.0, 160.0, "good"],
		["late edge of the window", 660.0, 500.0, 160.0, "good"],
		["just past the window", 661.0, 500.0, 160.0, "miss"],
		["way too early", 100.0, 500.0, 160.0, "miss"],
	]
	for c in d_cases:
		var got: String = AttackPatterns.classify_dodge(c[1], c[2], c[3])
		print("dodge: %s -> %s (expected %s)" % [c[0], got, c[4]])
	var b_cases := [
		["raise 30 ms before the impact", [[470.0, true]], false, "parry"],
		["raise exactly 45 ms before", [[455.0, true]], false, "parry"],
		["raise 46 ms before is only a block", [[454.0, true]], false, "block"],
		["raise on the impact", [[500.0, true]], false, "parry"],
		["raise 30 ms AFTER the impact", [[530.0, true]], false, "parry"],
		["raise 46 ms after is too late", [[546.0, true]], false, "fail"],
		["never raised", [], false, "fail"],
		["held the whole time, no change", [], true, "block"],
		["held, then LOWERED 40 ms before", [[460.0, false]], true, "parry"],
		["held, lowered 80 ms before: down at impact", [[420.0, false]], true, "fail"],
		["held, lowered 30 ms after", [[530.0, false]], true, "parry"],
		["raise early, lower much later: held at impact", [[200.0, true], [900.0, false]], false, "block"],
	]
	for c in b_cases:
		var got: String = AttackPatterns.classify_block(c[1], c[2], 500.0, 45.0)
		print("block: %s -> %s (expected %s)" % [c[0], got, c[3]])
	print("a wider parry window (shield bonus) catches a press 60 ms early: %s (expected parry)" % [AttackPatterns.classify_block([[440.0, true]], false, 500.0, 60.0)])

	# =========================================================
	# Pattern tables
	# =========================================================
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	main.regional_world = false  # this test drives the old wave-ladder world
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	var settings = main.settings
	var saved_minigames: bool = settings.combat_minigames_enabled
	var saved_block_key: int = settings.get_key("block")

	var bad := []
	var no_pattern := []
	var styles_ok := ["flash", "bar", "ring", "sweep", "volley"]
	var catalog_names: Array = Sandbox.enemy_names()
	for enemy_name in catalog_names:
		var traits: Dictionary = main.ENEMY_TRAITS.get(enemy_name, {})
		var pats: Array = AttackPatterns.patterns_for(enemy_name, traits)
		if pats.is_empty():
			no_pattern.append(enemy_name)
			continue
		for p in pats:
			var ok: bool = styles_ok.has(p.style) and p.has("name") and p.name != "" and float(p.dodge_ms) > 0.0 and not p.impacts.is_empty()
			var last := 0.0
			for hit in p.impacts:
				if float(hit.ms) <= last or float(hit.mult) <= 0.0:
					ok = false
				last = float(hit.ms)
			if not ok:
				bad.append("%s/%s" % [enemy_name, p.get("name", "?")])
	print("Every enemy in the catalog (%d) has at least one attack pattern: missing=%s (expected [])" % [catalog_names.size(), no_pattern])
	print("Every pattern has a name, a known style, positive timings and ascending impacts: bad=%s (expected [])" % [bad])

	var boss_problems := []
	var boss_heavy_ms := {}
	for enemy_name in AttackPatterns.BOSS_NAMES:
		var traits: Dictionary = main.ENEMY_TRAITS.get(enemy_name, {})
		var pats: Array = AttackPatterns.patterns_for(enemy_name, traits)
		var names := {}
		for p in pats:
			names[p.name] = true
		if pats.size() != 3 or names.size() != 3 or not AttackPatterns.is_boss(enemy_name, traits):
			boss_problems.append(enemy_name)
		boss_heavy_ms[int(pats[0].impacts[0].ms)] = true
	print("Every boss has exactly 3 differently-named attacks: problems=%s (expected [])" % [boss_problems])
	print("Bosses do not all share one timing (distinct heavy-blow timings >= 8): %s (expected true)" % [boss_heavy_ms.size() >= 8])
	var every_boss_in_catalog := true
	for enemy_name in catalog_names:
		if main.ENEMY_TRAITS.get(enemy_name, {}).get("is_boss_tier", false) and not AttackPatterns.BOSS_NAMES.has(enemy_name):
			every_boss_in_catalog = false
			print("   boss without named attacks: %s" % enemy_name)
	print("Every is_boss_tier enemy has hand-named attacks: %s (expected true)" % [every_boss_in_catalog])
	var plain_ids := {}
	for enemy_name in ["Goblin", "Orc", "Brute", "Shade", "Wolf", "Gnome"]:
		plain_ids[AttackPatterns.patterns_for(enemy_name, main.ENEMY_TRAITS.get(enemy_name, {}))[0].name] = true
	print("Plain enemies differ from each other (distinct first-attack names across 6 enemies >= 5): %d" % [plain_ids.size()])

	var orc_traits: Dictionary = main.ENEMY_TRAITS.get("Orc", {})
	print("Orc: normal/heavy/jab pick three attacks: %s / %s / %s (expected Overhead Smash / Overhead Smash / Quick Jab)" % [
		AttackPatterns.pick("Orc", orc_traits, "normal").name, AttackPatterns.pick("Orc", orc_traits, "heavy").name, AttackPatterns.pick("Orc", orc_traits, "jab").name
	])
	var boss_traits: Dictionary = main.ENEMY_TRAITS.get("Elder Oak", {})
	var boss_pats: Array = AttackPatterns.patterns_for("Elder Oak", boss_traits)
	print("Boss: a heavy wind-up blow is always its first attack, a jab its second: %s, %s (expected true, true)" % [
		AttackPatterns.pick("Elder Oak", boss_traits, "heavy").name == boss_pats[0].name, AttackPatterns.pick("Elder Oak", boss_traits, "jab").name == boss_pats[1].name
	])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var seen := {}
	for i in 60:
		seen[AttackPatterns.pick("Elder Oak", boss_traits, "normal", rng).name] = true
	print("Boss: its normal attack rolls across all 3 patterns over 60 tries: %d (expected 3)" % [seen.size()])
	print("A pattern's total damage share: flurry=%.2f heavy=%.2f (expected 1.20, 1.00)" % [AttackPatterns.total_mult(boss_pats[1]), AttackPatterns.total_mult(boss_pats[0])])
	var mutate: Array = AttackPatterns.patterns_for("Elder Oak", boss_traits)
	mutate[0]["name"] = "tampered"
	print("patterns_for hands out copies (a caller tweaking one can't corrupt the table): %s (expected true)" % [AttackPatterns.patterns_for("Elder Oak", boss_traits)[0].name != "tampered"])

	# =========================================================
	# The popup's own input timing (real clock)
	# =========================================================
	var dm = DefenseMinigame.new()
	root.add_child(dm)
	await process_frame
	var quick := {"name": "Test Swing", "style": "flash", "impacts": [{"ms": 120, "mult": 1.0}], "dodge_ms": 100, "weight": 1.0}
	var r1: Array = await _run_popup(dm, "dodge", quick, [], [[118.0, Vector2i(1, 0)]])
	print("Popup dodge: a press 2 ms from the impact is PERFECT and remembers its direction: %s dir=%s (expected perfect, (1, 0))" % [r1[0].outcome if r1.size() > 0 else "?", r1[0].dir if r1.size() > 0 else "?"])
	var r2: Array = await _run_popup(dm, "dodge", quick, [], [[40.0, Vector2i(0, -1)]])
	print("Popup dodge: a press 80 ms early (inside the 100 ms window, outside the inner 40) is GOOD: %s (expected good)" % [r2[0].outcome if r2.size() > 0 else "?"])
	var r3: Array = await _run_popup(dm, "dodge", quick, [], [])
	print("Popup dodge: no press at all is a MISS: %s (expected miss)" % [r3[0].outcome if r3.size() > 0 else "?"])
	var r4: Array = await _run_popup(dm, "block", quick, [[100.0, true]])
	print("Popup block: raising the shield 20 ms before the impact PARRIES: %s (expected parry)" % [r4[0].outcome if r4.size() > 0 else "?"])
	var r5: Array = await _run_popup(dm, "block", quick, [[10.0, true]])
	print("Popup block: raised early and held through the impact is a plain BLOCK: %s (expected block)" % [r5[0].outcome if r5.size() > 0 else "?"])
	var r6: Array = await _run_popup(dm, "block", quick, [])
	print("Popup block: never raised is a FAIL: %s (expected fail)" % [r6[0].outcome if r6.size() > 0 else "?"])
	var r7: Array = await _run_popup(dm, "block", quick, [[100.0, true]], [], {"parry_ms": 10.0})
	print("Popup block: a tighter parry window (10 ms) turns that same 20 ms-early raise into a block: %s (expected block)" % [r7[0].outcome if r7.size() > 0 else "?"])
	var twin := {"name": "Test Flurry", "style": "flash", "impacts": [{"ms": 100, "mult": 0.6}, {"ms": 260, "mult": 0.6}], "dodge_ms": 60, "weight": 1.0}
	var r8: Array = await _run_popup(dm, "dodge", twin, [], [[102.0, Vector2i(-1, 0)]])
	print("Popup dodge flurry: one press covers only ONE impact: %s (expected [perfect, miss]) mults=%s" % [[r8[0].outcome, r8[1].outcome] if r8.size() == 2 else r8, [r8[0].mult, r8[1].mult] if r8.size() == 2 else "?"])
	var key_ev := InputEventKey.new()
	key_ev.keycode = KEY_SPACE
	key_ev.pressed = true
	var key_dm = DefenseMinigame.new()
	root.add_child(key_dm)
	await process_frame
	key_dm.run("block", quick, {})
	key_dm._input(key_ev)
	key_ev.pressed = false
	key_dm._input(key_ev)
	var arrow := InputEventKey.new()
	arrow.keycode = KEY_UP
	arrow.pressed = true
	key_dm._input(arrow)
	print("Popup input: Space down/up are logged as block events, an arrow key as a dodge press: events=%s presses=%s (expected [true, false], [(0, -1)])" % [[key_dm._events[0][1], key_dm._events[1][1]] if key_dm._events.size() == 2 else key_dm._events, [key_dm._presses[0][1]] if key_dm._presses.size() == 1 else key_dm._presses])
	key_dm.queue_free()
	dm.queue_free()

	# Forced results short-circuit the UI completely (the test hook the combat flows below use).
	var fm = DefenseMinigame.new()
	root.add_child(fm)
	DefenseMinigame.forced_results = ["perfect", {"outcome": "good", "dir": Vector2i(0, 1)}]
	var fres: Array = await fm.run("dodge", twin, {})
	print("forced_results answers instantly, per impact, and is consumed: %s dir=%s left=%d (expected [perfect, good], (0, 0)/(0, 1), 0)" % [
		[fres[0].outcome, fres[1].outcome], [fres[0].dir, fres[1].dir], DefenseMinigame.forced_results.size()
	])
	fm.queue_free()

	# =========================================================
	# Settings
	# =========================================================
	print("The block action is rebindable and defaults to Space: %s / %s (expected true, true)" % [settings.ACTION_ORDER.has("block"), settings.get_key("block") == KEY_SPACE])
	settings.rebind("block", KEY_Z)
	print("...but can't be rebound onto a key another action already owns (Confirm = Z): %s (expected Space still)" % [settings.key_name("block")])
	settings.rebind("block", KEY_F)
	print("...and a free key sticks: %s (expected F)" % [settings.key_name("block")])
	settings.rebind("block", saved_block_key)
	print("The minigames start OFF in scripted runs (so every other test is unaffected): %s (expected false)" % [saved_minigames])

	# =========================================================
	# Combat flows
	# =========================================================
	var shields_script = load("res://scripts/Shields.gd")
	var weapons_script = load("res://scripts/Weapons.gd")
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_allies = []
	main.battle_player_tile = Vector2i(4, 4)
	main.battle_target_index = 0
	main.battle_turn = "enemy"
	main.tutorial_active = false
	main.battle_player_defending = false
	player.equipped_armor = {"damage_reduction": 0.0}
	player.resilience_reduction = 0.0
	player.meta_war_chest_reduction = 0.0
	player.meta_last_stand_pct_per_10 = 0.0
	player.meta_dodge_chance = 0.0
	player.meta_riposte_chance = 0.0
	player.meta_block_negate_chance = 0.0
	player.meta_shield_block_bonus_pct = 0.0
	player.berserk_turns_remaining = 0
	player.potion_resilience_turns = 0
	player.max_health = 200
	player.health = 200
	player.attack_damage = 10
	player.coins = 1000
	player.current_weapon = weapons_script.CLUB
	player.owned_shields = {}
	player.equipped_shield = {}
	settings.combat_minigames_enabled = true
	var attacker := _make_goblin(main, Vector2i(4, 5))
	main.battle_units = [attacker]

	# -- the odds: which popup, how generous --
	main.debug_minigame_mode = ""
	var s0: Dictionary = main._minigame_setup("dodge")
	print("Dodge opening: 30%% base with no dodge stat: %.2f (expected 0.30), window x%.2f (expected 1.00)" % [s0.opening_chance, s0.opts.window_mult])
	player.meta_dodge_chance = 0.2
	var s1: Dictionary = main._minigame_setup("dodge")
	print("...Reflexes/dodge chance widens both the opening and the window: opening=%.2f window=x%.2f (expected 0.50, x1.20)" % [s1.opening_chance, s1.opts.window_mult])
	player.meta_dodge_chance = 3.0
	var s2: Dictionary = main._minigame_setup("dodge")
	print("...both capped: opening=%.2f window=x%.2f (expected 0.90, x1.60)" % [s2.opening_chance, s2.opts.window_mult])
	player.berserk_turns_remaining = 2
	player.meta_dodge_chance = 0.2
	var s3: Dictionary = main._minigame_setup("dodge")
	print("...Berserk quarters the dodge bonus: opening=%.2f (expected 0.35)" % [s3.opening_chance])
	player.berserk_turns_remaining = 0
	player.meta_dodge_chance = 0.0
	var sb: Dictionary = main._minigame_setup("block")
	print("Parry window with no shield / no Block Master is exactly 45 ms: %.1f (expected 45.0)" % [sb.opts.parry_ms])
	var heavy: Dictionary = shields_script.SHIELDS.shield_heavy
	player.try_buy_shield(heavy)
	player.equipped_shield = player.equipped_shield.duplicate()
	player.equipped_shield.block_chance = 0.25
	var sb2: Dictionary = main._minigame_setup("block")
	print("...a shield's block chance widens it (0.25 -> +15 ms): %.1f (expected 60.0)" % [sb2.opts.parry_ms])
	player.meta_block_negate_chance = 5.0
	var sb3: Dictionary = main._minigame_setup("block")
	print("...and the bonus is capped at +30 ms: %.1f (expected 75.0)" % [sb3.opts.parry_ms])
	player.meta_block_negate_chance = 0.0
	player.equipped_shield = {}
	player.owned_shields = {}
	var chose_dodge := 0
	for i in 400:
		if main._minigame_setup().mode == "dodge":
			chose_dodge += 1
	print("With no dodge stat, about 30%% of attacks open a dodge (400 rolls): %d (expected roughly 120, within 90..150)" % [chose_dodge])

	# -- dodge outcomes --
	main.debug_minigame_mode = "dodge"
	main.battle_player_tile = Vector2i(4, 4)
	main.battle_units = [attacker]
	player.health = 200
	DefenseMinigame.forced_results = [{"outcome": "perfect", "dir": Vector2i(0, -1)}]
	var d1: Dictionary = await main._enemy_apply_damage(attacker, main.battle_player_tile, 50, {})
	print("Perfect dodge: no damage, flagged dodged: dmg=%d dodged=%s hp=%d (expected 0, true, 200)" % [d1.dmg, d1.get("dodged", false), player.health])
	print("...and the pressed direction (back, away from the attacker) rolled the hero there: %s (expected (4, 3))" % [main.battle_player_tile])

	main.battle_player_tile = Vector2i(4, 4)
	DefenseMinigame.forced_results = [{"outcome": "good", "dir": Vector2i(0, 1)}]
	var d2: Dictionary = await main._enemy_apply_damage(attacker, main.battle_player_tile, 50, {})
	print("Good dodge toward the attacker: still dodged, but no roll into the enemy: dodged=%s tile=%s (expected true, (4, 4))" % [d2.get("dodged", false), main.battle_player_tile])

	DefenseMinigame.forced_results = [{"outcome": "good", "dir": Vector2i(1, 0)}]
	main.battle_terrain[Vector2i(5, 4)] = {"type": "rock"}
	var d3: Dictionary = await main._enemy_apply_damage(attacker, main.battle_player_tile, 50, {})
	print("A dodge-roll into a rock stays put: tile=%s (expected (4, 4))" % [main.battle_player_tile])
	main.battle_terrain.clear()

	DefenseMinigame.forced_results = [{"outcome": "good", "dir": Vector2i(-1, 0)}]
	var d3b: Dictionary = await main._enemy_apply_damage(attacker, main.battle_player_tile, 50, {})
	print("A sideways dodge-roll moves the hero one tile that way: %s (expected (3, 4))" % [main.battle_player_tile])
	main.battle_player_tile = Vector2i(4, 4)

	DefenseMinigame.forced_results = ["miss"]
	player.health = 200
	var d4: Dictionary = await main._enemy_apply_damage(attacker, main.battle_player_tile, 50, {})
	print("Missed dodge: the full hit lands: dmg=%d hp=%d (expected 50, 150) dodged=%s" % [d4.dmg, player.health, d4.get("dodged", false)])
	print("...and the dodge popup did not downgrade into a block (no 'blocked' flag): %s (expected false)" % [d4.get("blocked", false)])

	# -- block outcomes --
	main.debug_minigame_mode = "block"
	player.health = 200
	DefenseMinigame.forced_results = ["parry"]
	var b1: Dictionary = await main._enemy_apply_damage(attacker, main.battle_player_tile, 50, {})
	print("Parry: the whole hit is negated: dmg=%d blocked=%s parried=%d hp=%d (expected 0, true, 1, 200)" % [b1.dmg, b1.get("blocked", false), b1.get("parried", 0), player.health])

	DefenseMinigame.forced_results = ["block"]
	var b2: Dictionary = await main._enemy_apply_damage(attacker, main.battle_player_tile, 40, {})
	print("Held guard with NO shield braces for 25%% off: dmg=%d (expected 30)" % [b2.dmg])
	player.try_buy_shield(heavy)
	player.equipped_shield = player.equipped_shield.duplicate()
	player.equipped_shield.block_chance = 0.0
	player.equipped_shield.damage_reduction_pct = 0.0
	player.current_weapon = weapons_script.CLUB
	DefenseMinigame.forced_results = ["block"]
	var b3: Dictionary = await main._enemy_apply_damage(attacker, main.battle_player_tile, 40, {})
	print("Held guard WITH a shield halves it: dmg=%d (expected 20)" % [b3.dmg])
	DefenseMinigame.forced_results = ["fail"]
	var b4: Dictionary = await main._enemy_apply_damage(attacker, main.battle_player_tile, 40, {})
	print("Shield never raised: full damage: dmg=%d (expected 40)" % [b4.dmg])

	player.equipped_armor = {"damage_reduction": 0.5}
	DefenseMinigame.forced_results = ["block"]
	var b5: Dictionary = await main._enemy_apply_damage(attacker, main.battle_player_tile, 40, {})
	print("Armour still stacks on a held guard (50%% shield, then 50 points of armour on the curve, of 40): dmg=%d (expected 13)" % [b5.dmg])
	player.equipped_armor = {"damage_reduction": 0.0}

	# A parry also fires the shield's special (Heavy Shield: knockback).
	var knock := _make_goblin(main, Vector2i(4, 5))
	main.battle_units = [knock]
	main.battle_player_tile = Vector2i(4, 4)
	DefenseMinigame.forced_results = ["parry"]
	await main._enemy_apply_damage(knock, main.battle_player_tile, 50, {})
	print("A parry triggers the shield's special (Heavy Shield shoves the attacker back): %s (expected (4, 6))" % [knock.tile])
	var plain := _make_goblin(main, Vector2i(4, 5))
	main.battle_units = [plain]
	DefenseMinigame.forced_results = ["block"]
	await main._enemy_apply_damage(plain, main.battle_player_tile, 50, {})
	print("...but a plain held block does not: %s (expected (4, 5))" % [plain.tile])
	player.equipped_shield = {}
	player.owned_shields = {}

	# -- riposte --
	main.debug_minigame_mode = "dodge"
	var rip := _make_goblin(main, Vector2i(4, 5), 999)
	main.battle_units = [rip]
	player.meta_riposte_chance = 0.01
	DefenseMinigame.forced_results = [{"outcome": "perfect", "dir": Vector2i.ZERO}]
	main.battle_player_tile = Vector2i(4, 4)
	await main._enemy_apply_damage(rip, main.battle_player_tile, 50, {})
	print("A perfect dodge always triggers an owned Riposte (even at 1%%): attacker hurt=%s (expected true)" % [rip.hp < 999])
	var rip2 := _make_goblin(main, Vector2i(4, 5), 999)
	main.battle_units = [rip2]
	player.meta_riposte_chance = 0.0
	DefenseMinigame.forced_results = [{"outcome": "perfect", "dir": Vector2i.ZERO}]
	await main._enemy_apply_damage(rip2, main.battle_player_tile, 50, {})
	print("...and no Riposte skill means no counter: attacker hurt=%s (expected false)" % [rip2.hp < 999])

	# -- multi-impact boss attacks --
	var boss_unit := _make_goblin(main, Vector2i(4, 5), 999)
	boss_unit.name = "Elder Oak"
	main.battle_units = [boss_unit]
	var bt: Dictionary = main.ENEMY_TRAITS.get("Elder Oak", {})
	main.debug_minigame_mode = "dodge"
	player.health = 200
	DefenseMinigame.forced_results = [{"outcome": "good", "dir": Vector2i.ZERO}, "miss"]
	var f1: Dictionary = await main._enemy_apply_damage(boss_unit, main.battle_player_tile, 50, bt, "jab")
	print("Flurry (2 x 60%%): dodge one, eat the other for 30: dmg=%d hp=%d (expected 30, 170) dodged-all=%s (expected false)" % [f1.dmg, player.health, f1.get("dodged", false)])
	player.health = 200
	DefenseMinigame.forced_results = ["perfect", "good"]
	var f2: Dictionary = await main._enemy_apply_damage(boss_unit, main.battle_player_tile, 50, bt, "jab")
	print("Flurry fully dodged: dmg=%d dodged=%s hp=%d (expected 0, true, 200)" % [f2.dmg, f2.get("dodged", false), player.health])
	player.health = 200
	DefenseMinigame.forced_results = ["miss", "miss"]
	var f3: Dictionary = await main._enemy_apply_damage(boss_unit, main.battle_player_tile, 50, bt, "jab")
	print("Flurry fully missed: both land for 30 each: dmg=%d (expected 60)" % [f3.dmg])
	main.debug_minigame_mode = "block"
	player.health = 200
	DefenseMinigame.forced_results = ["parry", "block"]
	var f4: Dictionary = await main._enemy_apply_damage(boss_unit, main.battle_player_tile, 50, bt, "jab")
	print("Flurry: parry the first, brace the second (30 x 75%%): dmg=%d (expected 23) parried=%d" % [f4.dmg, f4.get("parried", 0)])

	# -- the bypasses: these keep the classic rolls and never touch the popup --
	main.debug_minigame_mode = "dodge"
	player.health = 200
	DefenseMinigame.forced_results = ["perfect"]
	main.battle_player_defending = true
	var by1: Dictionary = await main._enemy_apply_damage(attacker, main.battle_player_tile, 50, {})
	print("Defending skips the popup (classic Defend: 50 halves to 25): dmg=%d forced_results untouched=%s (expected 25, true)" % [by1.dmg, DefenseMinigame.forced_results.size() == 1])
	main.battle_player_defending = false
	settings.combat_minigames_enabled = false
	var by2: Dictionary = await main._enemy_apply_damage(attacker, main.battle_player_tile, 50, {})
	print("The setting OFF skips the popup (classic: full 50 lands, no dodge stat): dmg=%d forced_results untouched=%s (expected 50, true)" % [by2.dmg, DefenseMinigame.forced_results.size() == 1])
	settings.combat_minigames_enabled = true
	main.tutorial_active = true
	var by3: Dictionary = await main._enemy_apply_damage(attacker, main.battle_player_tile, 50, {})
	print("The tutorial battle skips the popup: dmg=%d forced_results untouched=%s (expected 50, true)" % [by3.dmg, DefenseMinigame.forced_results.size() == 1])
	main.tutorial_active = false
	var ally_unit := {"name": "Knight", "tile": Vector2i(2, 2), "hp": 100, "max_hp": 100}
	main.battle_allies = [ally_unit]
	var by4: Dictionary = await main._enemy_apply_damage(attacker, ally_unit.tile, 20, {})
	print("An enemy hitting an ALLY never opens the popup: ally hp=%d (expected 80) forced_results untouched=%s (expected true)" % [ally_unit.hp, DefenseMinigame.forced_results.size() == 1])
	main.battle_allies = []
	DefenseMinigame.forced_results = []

	# -- on-hit statuses still ride along with a landed minigame hit --
	main.debug_minigame_mode = "block"
	main.player_bleed_turns = 0
	DefenseMinigame.forced_results = ["fail"]
	await main._enemy_apply_damage(attacker, main.battle_player_tile, 20, {"inflicts_bleed": true})
	print("A landed minigame hit still inflicts the attacker's bleed: %s (expected true)" % [main.player_bleed_turns > 0])
	main.player_bleed_turns = 0
	DefenseMinigame.forced_results = ["parry"]
	await main._enemy_apply_damage(attacker, main.battle_player_tile, 20, {"inflicts_bleed": true})
	print("...but a parried hit does not: %s (expected false)" % [main.player_bleed_turns > 0])

	# -- end to end through the real enemy turn --
	main.debug_minigame_mode = "dodge"
	main.battle_player_tile = Vector2i(4, 4)
	var turn_goblin := _make_goblin(main, Vector2i(4, 5), 999)
	turn_goblin.aware_of_player = true
	main.battle_units = [turn_goblin]
	main.battle_turn = "enemy"
	player.health = 200
	DefenseMinigame.forced_results = ["miss"]
	await main._process_enemy_turn()
	print("A full enemy turn runs through the popup: goblin (3 dmg) landed -> hp=%d (expected 197), forced_results consumed=%s (expected true)" % [player.health, DefenseMinigame.forced_results.is_empty()])

	settings.combat_minigames_enabled = saved_minigames
	main.debug_minigame_mode = ""
	DefenseMinigame.forced_results = []
	_done = true
	quit()
