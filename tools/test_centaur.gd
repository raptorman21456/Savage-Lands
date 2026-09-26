extends SceneTree

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	var centaur_script = load("res://scripts/Centaur.gd")

	# --- No Centaurs spawn before CENTAUR_WAVE_START. ---
	main.wave = main.CENTAUR_WAVE_START - 1
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await physics_frame
	main.enemies_alive = 0
	main._spawn_wave()
	await physics_frame
	var centaurs_before_gate: int = main.get_tree().get_nodes_in_group("enemies").filter(func(e): return e.get_display_name() in ["Centaur Archer", "Centaur Lancer"]).size()
	print("no Centaurs spawn before CENTAUR_WAVE_START: %d (expected 0)" % [centaurs_before_gate])

	# --- Exactly 3 spawn at/after it -- a fixed pack size, not scaled by
	# wave the way Goblin/Orc counts are. ---
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await physics_frame
	main.enemies_alive = 0
	main.wave = main.CENTAUR_WAVE_START
	main._spawn_wave()
	await physics_frame
	var centaurs_after_gate: int = main.get_tree().get_nodes_in_group("enemies").filter(func(e): return e.get_display_name() in ["Centaur Archer", "Centaur Lancer"]).size()
	print("a pack of exactly CENTAUR_PACK_SIZE Centaurs spawns starting at CENTAUR_WAVE_START: %d (expected %d)" % [centaurs_after_gate, main.CENTAUR_PACK_SIZE])

	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await physics_frame

	# --- ENEMY_TRAITS/ENEMY_ICONS resolve for both display names -- a
	# mismatch here would silently fall back to all-default combat stats or
	# an invisible battle-grid icon. ---
	print("ENEMY_TRAITS has entries for both: Archer=%s Lancer=%s (expected true, true)" % [
		main.ENEMY_TRAITS.has("Centaur Archer"), main.ENEMY_TRAITS.has("Centaur Lancer")
	])
	print("HUD.ENEMY_ICONS has entries for both: Archer=%s Lancer=%s (expected true, true)" % [
		main.hud.ENEMY_ICONS.has("Centaur Archer"), main.hud.ENEMY_ICONS.has("Centaur Lancer")
	])

	# --- The bow/spear roll is roughly 50/50 per spawn, over many trials
	# (same statistical-check shape as the Traitor Wolf spawn-rate test). ---
	var trials := 400
	var archer_count := 0
	for i in trials:
		var c = centaur_script.new()
		if c.has_bow:
			archer_count += 1
		c.free()
	var expected_archers: float = trials * 0.5
	print("the bow/spear roll is roughly 50/50 over %d trials: %d archers (expected roughly %.0f, within +/-40%%)" % [
		trials, archer_count, expected_archers
	])
	print("that's within a sane range: %s (expected true)" % [
		archer_count > expected_archers * 0.6 and archer_count < expected_archers * 1.4
	])

	# --- The Lancer hits harder in melee than the Archer, on both the
	# overworld contact path and the display-name branch it shares with it. ---
	var lancer = centaur_script.new()
	while lancer.has_bow:
		lancer.free()
		lancer = centaur_script.new()
	var archer = centaur_script.new()
	while not archer.has_bow:
		archer.free()
		archer = centaur_script.new()
	print("the Lancer's contact damage exceeds the Archer's: lancer=%d archer=%d (expected lancer > archer)" % [
		lancer.get_contact_damage(), archer.get_contact_damage()
	])
	print("display names match the roll: lancer_name=%s (expected Centaur Lancer), archer_name=%s (expected Centaur Archer)" % [
		lancer.get_display_name(), archer.get_display_name()
	])
	lancer.free()
	archer.free()

	quit()
