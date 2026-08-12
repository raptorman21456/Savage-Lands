extends SceneTree

func _init() -> void:
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var player = main.player
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	var wolf_script = load("res://scripts/Wolf.gd")

	# --- Display name branches on is_traitor, matching the Elite bool-flag
	# precedent (tint/stats already branch this way; name is the new part). ---
	var w = wolf_script.new()
	print("a plain wolf's display name: %s (expected Wolf)" % [w.get_display_name()])
	w.is_traitor = true
	print("a traitor wolf's display name: %s (expected Traitor Wolf)" % [w.get_display_name()])

	# --- ENEMY_TRAITS resolves for both display names (a mismatch here would
	# silently fall back to all-default combat stats, no error). ---
	print("ENEMY_TRAITS has entries for both: Wolf=%s Traitor Wolf=%s (expected true, true)" % [
		main.ENEMY_TRAITS.has("Wolf"), main.ENEMY_TRAITS.has("Traitor Wolf")
	])

	# --- ENEMY_ICONS resolves for both (HUD.gd has no fallback -- a missing
	# key means an invisible battle-grid icon). ---
	print("HUD.ENEMY_ICONS has entries for both: Wolf=%s Traitor Wolf=%s (expected true, true)" % [
		main.hud.ENEMY_ICONS.has("Wolf"), main.hud.ENEMY_ICONS.has("Traitor Wolf")
	])

	# --- Wolf only spawns from WOLF_WAVE_START onward. ---
	main.wave = main.WOLF_WAVE_START - 1
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await physics_frame
	main.enemies_alive = 0
	main._spawn_wave()
	await physics_frame
	var wolves_before_gate: int = main.get_tree().get_nodes_in_group("enemies").filter(func(e): return e.get_display_name() in ["Wolf", "Traitor Wolf"]).size()
	print("no wolves spawn before WOLF_WAVE_START: %d (expected 0)" % [wolves_before_gate])

	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await physics_frame
	main.enemies_alive = 0
	main.wave = main.WOLF_WAVE_START
	main._spawn_wave()
	await physics_frame
	var wolves_after_gate: int = main.get_tree().get_nodes_in_group("enemies").filter(func(e): return e.get_display_name() in ["Wolf", "Traitor Wolf"]).size()
	print("a wolf spawns starting at WOLF_WAVE_START: %d (expected 1)" % [wolves_after_gate])

	# --- Traitor Wolf spawn rate roughly matches TRAITOR_WOLF_CHANCE, over
	# many trials (same statistical-check shape as this session's other
	# probability-driven tests, e.g. orc knockback resistance). ---
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await physics_frame
	main.enemies_alive = 0
	var trials := 400
	main._spawn_enemies(wolf_script, trials)
	await physics_frame
	var traitor_count: int = main.get_tree().get_nodes_in_group("enemies").filter(func(e): return e.get_display_name() == "Traitor Wolf").size()
	var expected_traitors: float = trials * main.TRAITOR_WOLF_CHANCE
	print("traitor wolf spawn rate is roughly TRAITOR_WOLF_CHANCE over %d trials: %d (expected roughly %.0f, within +/-50%%)" % [
		trials, traitor_count, expected_traitors
	])
	print("that's within a sane range: %s (expected true)" % [
		traitor_count > expected_traitors * 0.5 and traitor_count < expected_traitors * 1.5
	])

	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await physics_frame
	main.enemies_alive = 0

	# --- Killing a plain (non-traitor) Wolf never touches party_wolf. ---
	player.party_wolf = {}
	var plain_wolf = wolf_script.new()
	main.add_child(plain_wolf)
	plain_wolf.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	plain_wolf.take_damage(9999)
	print("killing a plain Wolf never grants party_wolf: %s (expected true, still empty)" % [player.party_wolf.is_empty()])

	# --- Killing a Traitor Wolf with a wolf already in the party never
	# overwrites it. ---
	player.party_wolf = {"name": "Traitor Wolf", "dmg_mult": 0.6}
	var traitor_occupied = wolf_script.new()
	traitor_occupied.is_traitor = true
	main.add_child(traitor_occupied)
	traitor_occupied.died.connect(main._on_wolf_died)
	traitor_occupied.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	traitor_occupied.take_damage(9999)
	print("an already-occupied party_wolf slot is never overwritten by a second recruit: %s (expected 0.6, unchanged)" % [player.party_wolf.dmg_mult])

	# --- Over many trials, an unoccupied party_wolf slot gets filled roughly
	# TRAITOR_WOLF_RECRUIT_CHANCE of the time. ---
	var recruit_trials := 200
	var recruited := 0
	for i in recruit_trials:
		player.party_wolf = {}
		var t = wolf_script.new()
		t.is_traitor = true
		main.add_child(t)
		t.died.connect(main._on_wolf_died)
		t.died.connect(main._on_enemy_died)
		main.enemies_alive += 1
		t.take_damage(9999)
		if not player.party_wolf.is_empty():
			recruited += 1
	var expected_recruits: float = recruit_trials * main.TRAITOR_WOLF_RECRUIT_CHANCE
	print("recruitment rate roughly matches TRAITOR_WOLF_RECRUIT_CHANCE over %d trials: %d (expected roughly %.0f)" % [
		recruit_trials, recruited, expected_recruits
	])
	print("that's within a sane range: %s (expected true)" % [
		recruited > expected_recruits * 0.5 and recruited < expected_recruits * 1.5
	])

	quit()
