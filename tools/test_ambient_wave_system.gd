extends SceneTree

# Enemies roam persistently now instead of gating progress on being fully
# cleared (see Main.gd:_on_enemy_died/_advance_wave_tier/KILLS_PER_TIER).
# This covers the three load-bearing safety properties that redesign
# depends on: the ambient population cap actually clamps _spawn_enemies,
# bosses bypass that cap entirely, and the Nothingness rush (still a fixed
# sequential solo-boss gauntlet, not part of the ambient wilderness) still
# clears stray roamers between its own fights.

func _init() -> void:
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await physics_frame
	main.enemies_alive = 0

	# --- Population cap ---
	main.enemies_alive = main.MAX_AMBIENT_ENEMIES - 2
	main._spawn_enemies(main.EnemyScript, 10)
	print("_spawn_enemies clamps to the remaining headroom under the cap: enemies_alive=%d (expected %d)" % [
		main.enemies_alive, main.MAX_AMBIENT_ENEMIES
	])
	main._spawn_enemies(main.EnemyScript, 5)
	print("...and spawns nothing at all once already at the cap: enemies_alive=%d (expected %d, unchanged)" % [
		main.enemies_alive, main.MAX_AMBIENT_ENEMIES
	])

	# --- Bosses bypass the cap ---
	var enemies_before_boss: int = main.enemies_alive
	main._spawn_boss_wave()
	print("a boss/miniboss spawns straight through the cap, since it's already maxed: enemies_alive=%d (expected %d, +1)" % [
		main.enemies_alive, enemies_before_boss + 1
	])

	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await physics_frame
	main.enemies_alive = 0

	# --- Kill milestones advance the tier, and every BOSS_WAVE_INTERVAL-th
	# one still spawns that world's boss/miniboss instead of the normal mix,
	# exactly like the old wave-clear model did. ---
	main.wave = main.BOSS_WAVE_INTERVAL - 1
	for i in main.KILLS_PER_TIER:
		main._on_enemy_died(0)
		if main.event_choosing:
			# A random event can defer _spawn_wave() until answered (see
			# _maybe_trigger_event) -- force it through so this stays
			# deterministic instead of depending on the event roll.
			main.event_choosing = false
			main.get_tree().paused = false
			main._spawn_wave()
	await physics_frame
	var boss_tier_enemies: Array = main.get_tree().get_nodes_in_group("enemies")
	print("a milestone landing on a BOSS_WAVE_INTERVAL wave spawns the solo boss mix, not the normal one: wave=%d (expected %d), count=%d (expected 1)" % [
		main.wave, main.BOSS_WAVE_INTERVAL, boss_tier_enemies.size()
	])

	# --- The Nothingness rush stays a clean sequential 1-on-1 gauntlet: a
	# stray ambient roamer left over from before entering it gets cleared the
	# moment the rush's own wave-advance runs. ---
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await physics_frame
	main.enemies_alive = 0
	main.current_world_index = main.WORLDS.size() - 1
	main.nothingness_rush_complete = false
	main.wave = main.WAVES_PER_WORLD * (main.WORLDS.size() - 1)
	# A straggler that has nothing to do with the rush itself.
	var straggler = main.EnemyScript.new()
	main.add_child(straggler)
	main.enemies_alive += 1
	main._advance_wave_tier()
	if main.event_choosing:
		# A random event can defer _spawn_wave() until answered (see
		# _maybe_trigger_event) -- force it through so this stays
		# deterministic instead of depending on the event roll.
		main.event_choosing = false
		main.get_tree().paused = false
		main._spawn_wave()
	await physics_frame
	var rush_enemies: Array = main.get_tree().get_nodes_in_group("enemies")
	print("entering the Nothingness rush clears stray roamers first, leaving only its own solo fight: count=%d (expected 1)" % [rush_enemies.size()])

	quit()
