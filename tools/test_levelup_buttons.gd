extends SceneTree

func _init() -> void:
	# Fixed seed: every random roll below repeats run to run, so a changed result
	# is a real change, not luck.
	seed(20260926)
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var player = main.player
	player.gain_xp(30)
	await process_frame

	print("level up triggers the button panel: choosing_stat=%s (expected true), panel_visible=%s (expected true)" % [
		main.choosing_stat, main.hud.levelup_panel.visible
	])
	print("buttons show the current stat values: intimidation_text=%s vigor_text=%s" % [
		main.hud.levelup_buttons["intimidation"].text, main.hud.levelup_buttons["vigor"].text
	])

	var vigor_before: int = player.stat_vigor
	main.hud.levelup_buttons["vigor"].pressed.emit()
	print("clicking a stat button applies the bonus: vigor %d -> %d (expected +1), choosing_stat=%s (expected false), panel_visible=%s (expected false), paused=%s (expected false)" % [
		vigor_before, player.stat_vigor, main.choosing_stat, main.hud.levelup_panel.visible, paused
	])

	# Hovering a stat button shows its description in the shared label.
	main.player.gain_xp(1000)
	await process_frame
	main.hud.levelup_buttons["strength"].mouse_entered.emit()
	print("hovering a stat button shows its description: text=%s (expected non-empty, mentions damage)" % [main.hud.levelup_description_label.text])
	main.hud.levelup_buttons["strength"].mouse_exited.emit()
	print("leaving the button clears the description: text='%s' (expected empty)" % [main.hud.levelup_description_label.text])

	quit()
