extends SceneTree

func _init() -> void:
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var player = main.player
	print("initial level=%d int=%d str=%d vig=%d agi=%d hp=%d/%d dmg=%d speed=%.1f cooldown=%.3f xp_to_next=%d" % [
		player.level, player.stat_intimidation, player.stat_strength, player.stat_vigor, player.stat_agility,
		player.health, player.max_health, player.attack_damage, player.move_speed, player.attack_cooldown_max, player.xp_to_next
	])

	player.gain_xp(30)
	await process_frame

	print("after +30 xp: level=%d choosing_stat=%s paused=%s xp=%d/%d" % [
		player.level, main.choosing_stat, paused, player.xp, player.xp_to_next
	])

	if main.choosing_stat:
		main.player.apply_bonus_stat("vigor")
		main.hud.hide_levelup_choice()
		paused = false
		main.choosing_stat = false

	print("after choosing vigor bonus: level=%d int=%d str=%d vig=%d agi=%d hp=%d/%d dmg=%d speed=%.1f cooldown=%.3f" % [
		player.level, player.stat_intimidation, player.stat_strength, player.stat_vigor, player.stat_agility,
		player.health, player.max_health, player.attack_damage, player.move_speed, player.attack_cooldown_max
	])

	quit()
