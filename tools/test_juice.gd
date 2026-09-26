extends SceneTree

func _make_goblin(main, tile: Vector2i, hp: int = 999) -> Dictionary:
	var goblin_script = load("res://scripts/Enemy.gd")
	var g = goblin_script.new()
	main.add_child(g)
	g.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	return {
		"ref": g, "tile": tile, "hp": hp, "max_hp": hp, "move_range": 2,
		"damage": 1, "name": "Goblin", "winding_up": false, "stunned": false,
	}

# Count of currently-alive tweened juice nodes (Label damage numbers +
# ColorRect flashes/particles) under a container, identified by class --
# used to confirm a helper actually spawned something without caring about
# exact node identity.
func _count_by_class(container: Node, cls: String) -> int:
	var n := 0
	for c in container.get_children():
		if c.get_class() == cls:
			n += 1
	return n

func _find_label_with_text(container: Node, text: String) -> bool:
	for c in container.get_children():
		if c is Label and c.text == text:
			return true
	return false

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	var player = main.player
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	# --- Shake: a smaller shake in progress does not cut a bigger one short,
	# a bigger one always overrides. Same rule for both camera (overworld)
	# and battle (tile-battle panel) shake. ---
	main.camera_shake_timer = 0.0
	main._shake_camera(4.0, 0.15)
	print("camera shake triggers: timer=%.2f strength=%.1f (expected 0.15, 4.0)" % [main.camera_shake_timer, main.camera_shake_strength])
	main._shake_camera(2.0, 0.1)
	print("a smaller camera shake does not cut a bigger one short: timer=%.2f strength=%.1f (expected still 0.15, 4.0)" % [main.camera_shake_timer, main.camera_shake_strength])
	main._shake_camera(8.0, 0.25)
	print("a bigger camera shake overrides: timer=%.2f strength=%.1f (expected 0.25, 8.0)" % [main.camera_shake_timer, main.camera_shake_strength])

	main.battle_shake_timer = 0.0
	main._shake_battle(4.0, 0.15)
	main._shake_battle(2.0, 0.1)
	main._shake_battle(8.0, 0.25)
	print("battle shake follows the same override rule: timer=%.2f strength=%.1f (expected 0.25, 8.0)" % [main.battle_shake_timer, main.battle_shake_strength])

	# --- _update_shake: decays over time and stays within the strength bound;
	# resets the shaken node back to zero once the timer runs out. ---
	main.camera_shake_timer = 1.0
	main.camera_shake_duration = 1.0
	main.camera_shake_strength = 10.0
	main._update_shake(0.016)
	var within_bound: bool = abs(main.camera.offset.x) <= 10.0 and abs(main.camera.offset.y) <= 10.0
	print("camera offset stays within the shake's strength bound: within_bound=%s (expected true), timer=%.3f (expected ~0.984)" % [within_bound, main.camera_shake_timer])
	main.camera_shake_timer = 0.0
	main._update_shake(0.016)
	print("camera offset resets to zero once the shake ends: offset=%s (expected (0, 0))" % [main.camera.offset])

	# --- World-space helpers, called directly (no physics needed): a damage
	# number labeled with the exact amount, and a death burst of
	# DEATH_BURST_PARTICLE_COUNT particles, both parented under main. ---
	var world_pos := Vector2(100, 100)
	main.spawn_damage_number_world(world_pos, 42)
	print("world damage number shows the exact amount: found=%s (expected true)" % [_find_label_with_text(main, "42")])

	var particles_before: int = _count_by_class(main, "ColorRect")
	main.spawn_death_burst(world_pos)
	var particles_after: int = _count_by_class(main, "ColorRect")
	print("world death burst spawns %d particles: got %d (expected %d)" % [main.DEATH_BURST_PARTICLE_COUNT, particles_after - particles_before, main.DEATH_BURST_PARTICLE_COUNT])

	# --- An enemy's own death (Enemy.gd:take_damage) triggers a death burst
	# without crashing, via the same has_method() duck-typing pattern used
	# for trigger_battle elsewhere. ---
	var dying_goblin = load("res://scripts/Enemy.gd").new()
	main.add_child(dying_goblin)
	dying_goblin.died.connect(main._on_enemy_died)
	main.enemies_alive += 1
	dying_goblin.global_position = Vector2(200, 200)
	dying_goblin.health = 1
	var pre_death_particles: int = _count_by_class(main, "ColorRect")
	dying_goblin.take_damage(99)
	var post_death_particles: int = _count_by_class(main, "ColorRect")
	print("a real enemy death spawns a death burst too: got %d new particles (expected %d)" % [post_death_particles - pre_death_particles, main.DEATH_BURST_PARTICLE_COUNT])
	await physics_frame

	# --- Player hit-flash + damage number + camera shake, all on take_damage. ---
	player.invincible_timer = 0.0
	player.flash_timer = 0.0
	main.camera_shake_timer = 0.0
	player.health = 50
	player.max_health = 100
	var player_labels_before: int = _count_by_class(main, "Label")
	player.take_damage(5)
	print("player.take_damage sets the hit-flash timer: flash_timer=%.2f (expected %.2f)" % [player.flash_timer, player.FLASH_DURATION])
	print("player.take_damage deals the exact amount: health=%d (expected 45)" % [player.health])
	print("player.take_damage spawns a matching world damage number: found=%s (expected true)" % [_find_label_with_text(main, "5")])
	print("player.take_damage triggers a camera shake: timer=%.2f (expected > 0)" % [main.camera_shake_timer])

	# --- Tile battle: _apply_single_hit spawns a damage number that matches
	# the ACTUAL damage dealt (not just some number), a flash overlay on the
	# hit tile, and a battle shake -- verifying the juice never desyncs from
	# the underlying combat math. ---
	main.in_battle = true
	main.battle_terrain.clear()
	main.battle_player_tile = Vector2i(2, 2)
	main.battle_target_index = 0
	player.stat_strength = 10
	player.attack_damage = 10
	player.stamina = player.MAX_STAMINA

	var g_hit := _make_goblin(main, Vector2i(3, 2))
	main.battle_units = [g_hit]
	var panel_labels_before: int = _count_by_class(main.hud.battle_panel, "Label")
	main.battle_shake_timer = 0.0
	main._battle_player_fight()
	var actual_dmg: int = 999 - g_hit.hp
	print("battle hit damage number matches actual damage dealt: found=%s (expected true, dealt %d)" % [_find_label_with_text(main.hud.battle_panel, str(actual_dmg)), actual_dmg])
	print("battle hit spawns more label nodes on the panel: %s (expected true)" % [_count_by_class(main.hud.battle_panel, "Label") > panel_labels_before])
	print("battle hit triggers a battle shake: timer=%.2f (expected > 0)" % [main.battle_shake_timer])

	# --- A kill in the tile battle spawns a death burst on top of the hit
	# flash and the attack lunge -- DEATH_BURST_PARTICLE_COUNT particles plus
	# the 1 flash overlay plus the 1 attack-lunge bolt. ---
	var g_kill := _make_goblin(main, Vector2i(3, 2), 1)
	main.battle_units = [g_kill]
	var panel_rects_before: int = _count_by_class(main.hud.battle_panel, "ColorRect")
	main._battle_player_fight()
	var panel_rects_after: int = _count_by_class(main.hud.battle_panel, "ColorRect")
	print("a battle kill spawns a death burst (+flash, +lunge bolt) on the panel: got %d new rects (expected %d)" % [panel_rects_after - panel_rects_before, main.DEATH_BURST_PARTICLE_COUNT + 2])

	# --- _enemy_apply_damage, player-target branch: the returned dmg matches
	# the player's actual HP loss, and spawns a matching damage number. ---
	player.health = 50
	main.battle_shake_timer = 0.0
	var attacker_a := {"tile": Vector2i(1, 1)}
	var result_player: Dictionary = main._enemy_apply_damage(attacker_a, main.battle_player_tile, 7, {})
	print("_enemy_apply_damage (player target) deals the returned dmg exactly: health=%d (expected %d)" % [player.health, 50 - result_player.dmg])
	print("_enemy_apply_damage (player target) spawns a matching damage number: found=%s (expected true)" % [_find_label_with_text(main.hud.battle_panel, str(result_player.dmg))])
	print("_enemy_apply_damage (player target) triggers a battle shake: timer=%.2f (expected > 0)" % [main.battle_shake_timer])

	# --- _enemy_apply_damage, ally-target branch: same guarantees, against a
	# battle_allies entry instead of the player. ---
	var ally_tile := Vector2i(6, 6)
	main.battle_allies = [{"tile": ally_tile, "hp": 20, "max_hp": 20, "dmg_mult": 1.0, "name": "Blade Ally", "move_range": 2, "attack_range": 1}]
	main.battle_shake_timer = 0.0
	var attacker_b := {"tile": Vector2i(7, 5)}
	var result_ally: Dictionary = main._enemy_apply_damage(attacker_b, ally_tile, 6, {})
	print("_enemy_apply_damage (ally target) deals the returned dmg exactly: hp=%d (expected %d)" % [main.battle_allies[0].hp, 20 - result_ally.dmg])
	print("_enemy_apply_damage (ally target) spawns a matching damage number: found=%s (expected true)" % [_find_label_with_text(main.hud.battle_panel, str(result_ally.dmg))])
	print("_enemy_apply_damage (ally target) triggers a battle shake: timer=%.2f (expected > 0)" % [main.battle_shake_timer])

	# --- Direct coverage of _spawn_battle_attack_lunge: both the melee jab
	# and the ranged traveling-shot variant spawn a transient node on the
	# panel without touching anything else. ---
	var lunge_rects_before: int = _count_by_class(main.hud.battle_panel, "ColorRect")
	main._spawn_battle_attack_lunge(Vector2i(0, 0), Vector2i(2, 2), main.ATTACK_LUNGE_PLAYER_COLOR, false)
	print("a melee attack lunge spawns a transient node on the panel: %s (expected true)" % [_count_by_class(main.hud.battle_panel, "ColorRect") > lunge_rects_before])
	var ranged_rects_before: int = _count_by_class(main.hud.battle_panel, "ColorRect")
	main._spawn_battle_attack_lunge(Vector2i(0, 0), Vector2i(4, 4), main.ATTACK_LUNGE_ENEMY_COLOR, true)
	print("a ranged attack lunge (a traveling shot) also spawns a transient node: %s (expected true)" % [_count_by_class(main.hud.battle_panel, "ColorRect") > ranged_rects_before])

	# --- A ranged enemy's own attack_range trait (>1) automatically routes
	# _enemy_apply_damage into the traveling-shot variant, with zero extra
	# wiring at the call site -- and still doesn't desync the damage dealt. ---
	player.health = 50
	main.battle_shake_timer = 0.0
	var mage_attacker := {"tile": Vector2i(0, 0)}
	var mage_traits := {"attack_range": 4}
	var mage_rects_before: int = _count_by_class(main.hud.battle_panel, "ColorRect")
	var result_ranged: Dictionary = main._enemy_apply_damage(mage_attacker, main.battle_player_tile, 3, mage_traits)
	print("a ranged enemy trait still deals the exact returned dmg: health=%d (expected %d)" % [player.health, 50 - result_ranged.dmg])
	print("...and still spawns a lunge node on the panel: %s (expected true)" % [_count_by_class(main.hud.battle_panel, "ColorRect") > mage_rects_before])

	# --- Player overworld attack animation: the sprite visibly lunges
	# mid-swing and returns to its exact resting position/scale once the
	# swing (and its tween) finishes -- confirms _play_attack_animation
	# doesn't leave the sprite stuck offset. ---
	var weapons_script = load("res://scripts/Weapons.gd")
	player.current_weapon = weapons_script.CLUB
	player.facing = Vector2.DOWN
	player.cooldown_timer = 0.0
	player._start_attack()
	print("_start_attack creates a valid attack_tween: %s (expected true)" % [player.attack_tween != null and player.attack_tween.is_valid()])
	# Headless test frames can carry a much larger delta than a real 60fps
	# frame (however long the engine actually took between yields), so a
	# short tween can fully complete within a single awaited frame -- not
	# reliable for observing a MID-swing value, only that it eventually
	# settles back to rest without getting stuck.
	for i in 20:
		await process_frame
	print("the player's sprite returns to its resting position/scale after the swing: pos=%s scale=%s (expected (0, 0), %s)" % [
		player.sprite.position, player.sprite.scale, player.BASE_SPRITE_SCALE
	])

	# A fast re-trigger (e.g. a weapon whose cooldown undercuts its own
	# active_duration) kills the in-flight tween and snaps back to rest
	# before starting the next one -- confirms that guard leaves the sprite
	# clean rather than stuck mid-lunge.
	player._start_attack()
	player._start_attack()
	for i in 20:
		await process_frame
	print("a fast re-trigger doesn't leave the sprite stuck offset: pos=%s scale=%s (expected (0, 0), %s)" % [
		player.sprite.position, player.sprite.scale, player.BASE_SPRITE_SCALE
	])

	# --- Enemy overworld attack lunge: runs without touching health or
	# crashing, for a fresh enemy instance called directly. ---
	var lunge_enemy = load("res://scripts/Enemy.gd").new()
	main.add_child(lunge_enemy)
	var health_before_lunge: int = lunge_enemy.health
	lunge_enemy.global_position = Vector2(300, 300)
	lunge_enemy._play_attack_lunge(Vector2(320, 300))
	print("an enemy's attack lunge doesn't touch its own health: %s (expected true)" % [lunge_enemy.health == health_before_lunge])
	await physics_frame

	# Reset the scratch save for whatever test runs next.
	var save_data_script = load("res://scripts/SaveData.gd")
	save_data_script.save_data({"essence": 0, "upgrades": {}, "best_wave": 0})

	quit()
