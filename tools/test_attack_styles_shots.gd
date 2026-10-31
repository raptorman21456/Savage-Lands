extends SceneTree

# Not a test: screenshots of every weapon attack style (the Club's slide, the Spear's bullseye, the Greatsword's arc, the Hammer's meter, the
# Axe's falling gauge, the Dagger's markers, the Gloves' two circles, the Picks' drifting dial, the Bow's crosshair, the Wand's shape and the
# Staff's arrows), mid-swing and after the result, into ui_screenshots/attack_styles/. Needs a real window (it skips itself headless). Named
# test_* so SaveData uses scratch saves and never touches your real ones.
#
#   Godot --path . --resolution 1280x720 --script res://tools/test_attack_styles_shots.gd

const AT := preload("res://scripts/AttackTimings.gd")

var out_dir := ""
var count := 0
var main = null
var dm = null

func _shot(label: String) -> void:
	await process_frame
	await process_frame
	count += 1
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s%02d_%s.png" % [out_dir, count, label])
	print("shot %02d %s" % [count, label])

func _wait_ms(ms: float) -> void:
	var start: int = Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - start) < ms:
		await process_frame

func _finish() -> void:
	var guard: int = Time.get_ticks_msec()
	while dm._running and Time.get_ticks_msec() - guard < 8000:
		await process_frame

func _init() -> void:
	if DisplayServer.get_name() == "headless":
		print("test_attack_styles_shots: needs a window, skipped (run it without --headless)")
		quit()
		return
	seed(20261031)
	out_dir = ProjectSettings.globalize_path("res://ui_screenshots/attack_styles/")
	DirAccess.make_dir_recursive_absolute(out_dir)
	for f in DirAccess.get_files_at(out_dir):
		if f.ends_with(".png"):
			DirAccess.remove_absolute(out_dir + f)
	load("res://scripts/SaveData.gd").mark_tutorial_completed()
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)
	main.player.max_party_slots = 20
	for kind in ["knight", "druid"]:
		main.player.recruit(kind)
	var orc = load("res://scripts/Orc.gd").new()
	main.add_child(orc)
	orc.global_position = main.player.global_position + Vector2(30, 0)
	main.trigger_battle(orc)
	for i in 8:
		await process_frame
	main.battle_turn = "player"
	main.battle_menu_state = "main"
	main._refresh_battle_display()
	dm = main._get_attack_minigame()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7

	# --- Club ---
	dm.run(AT.command_for("club"))
	await _wait_ms(330)
	await _shot("club_slide_midway")
	dm._events.append([float(dm._now_ms()) - 5.0, true])
	await _wait_ms(120)
	await _shot("club_slide_result")
	await _finish()

	# --- Spear ---
	dm.run(AT.command_for("spear"))
	await _wait_ms(380)
	await _shot("spear_bullseye_closing")
	await _finish()

	# --- Greatsword ---
	dm.run(AT.command_for("greatsword"))
	await _wait_ms(520)
	await _shot("greatsword_arc_midway")
	dm._events.append([float(dm._now_ms()) + 270.0, true])
	await _wait_ms(450)
	await _shot("greatsword_arc_result")
	await _finish()

	# --- Hammer (unchanged) ---
	dm.run(AT.command_for("hammer"))
	dm._events.append([10.0, true])
	await _wait_ms(640)
	await _shot("hammer_hold")
	await _finish()

	# --- Battle axe ---
	dm.run(AT.command_for("battle_axe"))
	for i in 10:
		dm._events.append([float(dm._now_ms()) + float(i) * 40.0, true])
	await _wait_ms(620)
	await _shot("battle_axe_gauge")
	await _finish()

	# --- Dagger ---
	dm.run(AT.command_for("dagger"))
	await _wait_ms(620)
	await _shot("dagger_markers")
	await _finish()

	# --- Knuckle gloves ---
	dm.run(AT.command_for("knuckle_gloves"))
	await _wait_ms(480)
	await _shot("gloves_two_circles_closing")
	await _finish()

	# --- Hand picks ---
	dm.run(AT.command_for("hand_picks"))
	dm._events.append([10.0, true])
	await _wait_ms(760)
	await _shot("picks_orbit_dial")
	await _finish()

	# --- Bow (as it was) ---
	dm.run(AT.command_for("bow"))
	await _wait_ms(620)
	await _shot("bow_crosshair")
	await _finish()

	# --- Wand: a star, traced by hand with a little wobble ---
	var star_cmd: Dictionary = AT.command_for("wand")
	star_cmd["shape"] = "star"
	star_cmd["spin"] = 0.0
	dm.run(star_cmd, {"verb": "CAST", "spell_id": "druid_heal"})
	await _wait_ms(250)
	await _shot("wand_star_to_trace")
	var wobble := PackedVector2Array()
	for p in AT.resample(dm._trace_shape, 90):
		wobble.append(p + Vector2(sin(p.x * 0.2) * 5.0, cos(p.y * 0.2) * 5.0))
	dm.inject_trace(wobble)
	await _wait_ms(200)
	await _shot("wand_star_result")
	await _finish()
	var spiral_cmd: Dictionary = AT.command_for("wand")
	spiral_cmd["shape"] = "spiral"
	spiral_cmd["spin"] = 0.0
	dm.run(spiral_cmd, {"verb": "CAST", "spell_id": "druid_heal"})
	await _wait_ms(250)
	await _shot("wand_spiral_to_trace")
	dm._running = false
	dm.finished.emit()
	await process_frame

	# --- Staff ---
	dm.run(AT.command_for("staff"), {"verb": "CAST", "spell_id": "staff_poison_bomb"})
	await _wait_ms(200)
	var seq: Array = dm._cmd.sequence
	dm._events.append([float(dm._now_ms()), true, str(seq[0])])
	dm._events.append([float(dm._now_ms()) + 120.0, true, str(seq[1])])
	await _wait_ms(450)
	await _shot("staff_arrows_two_right")
	await _finish()
	print("DONE: %d screenshots in %s" % [count, out_dir])
	quit()
