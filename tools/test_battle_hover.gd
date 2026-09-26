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

	var hud = main.hud
	main.in_battle = true
	main.battle_menu_state = "main"
	main._refresh_battle_display()

	# Hovering a main-menu button shows its yellow highlight color and its
	# description; leaving it clears the description again.
	var fight_button: Button = hud.battle_main_buttons["fight"]
	var yellow := Color(1.0, 0.9, 0.2)
	print("hover color configured on the button: hover=%s focus=%s (expected both %s)" % [
		fight_button.get_theme_color("font_hover_color"), fight_button.get_theme_color("font_focus_color"), yellow
	])

	fight_button.mouse_entered.emit()
	print("hovering Fight shows its description: text=%s (expected non-empty, mentions attack)" % [hud.battle_description_label.text])
	fight_button.mouse_exited.emit()
	print("leaving Fight clears the description: text='%s' (expected empty)" % [hud.battle_description_label.text])

	# Keyboard focus does the exact same thing as mouse hover.
	fight_button.focus_entered.emit()
	print("focusing Fight via keyboard shows the same description: text=%s (expected non-empty)" % [hud.battle_description_label.text])
	fight_button.focus_exited.emit()
	print("unfocusing Fight clears the description: text='%s' (expected empty)" % [hud.battle_description_label.text])

	# Main and Fight submenu buttons accept keyboard focus (for arrow-key
	# navigation); Move's Confirm/Cancel don't, since arrows are needed
	# exclusively for grid movement in that menu.
	print("main menu buttons are keyboard-focusable: %s (expected true)" % [fight_button.focus_mode == Control.FOCUS_ALL])
	print("fight submenu buttons are keyboard-focusable: %s (expected true)" % [hud.battle_fight_buttons["attack"].focus_mode == Control.FOCUS_ALL])
	print("move submenu buttons are NOT keyboard-focusable: %s (expected true)" % [hud.battle_move_buttons["confirm"].focus_mode == Control.FOCUS_NONE])

	# Special buttons' descriptions update to match the equipped weapon.
	var weapons_script = load("res://scripts/Weapons.gd")
	main.player.current_weapon = weapons_script.GREATSWORD
	main._refresh_battle_display()
	var special_button: Button = hud.battle_fight_buttons["special_0"]
	print("special button description matches the equipped weapon: %s (expected %s)" % [
		special_button.get_meta("description"), weapons_script.GREATSWORD.specials[0].description
	])

	# Going back from the Fight submenu is mouse-only now (click Back) --
	# confirm the button itself still does the right thing.
	main.battle_menu_state = "fight"
	main.battle_turn = "player"
	hud.battle_fight_buttons["back"].pressed.emit()
	print("clicking Back in the fight submenu returns to the main menu: state=%s (expected main)" % [main.battle_menu_state])

	quit()
