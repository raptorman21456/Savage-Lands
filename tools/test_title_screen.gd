extends SceneTree

func _init() -> void:
	var title_scene = load("res://TitleScreen.tscn")
	var title = title_scene.instantiate()
	root.add_child(title)
	await process_frame
	await process_frame

	print("title screen builds its buttons: play=%s quit=%s (expected both true)" % [
		title.play_button != null, title.quit_button != null
	])

	# Hovering shows a description, same pattern as the rest of the UI.
	title.play_button.mouse_entered.emit()
	print("hovering Play shows a description: text=%s (expected non-empty)" % [title.description_label.text])
	title.play_button.mouse_exited.emit()
	print("leaving Play clears the description: text='%s' (expected empty)" % [title.description_label.text])

	# Clicking Play transitions to the actual game scene.
	title.play_button.pressed.emit()
	await process_frame
	await process_frame
	await process_frame
	var current_scene := root.get_child(root.get_child_count() - 1)
	print("clicking Play loads the game scene: current_scene_name=%s (expected Main)" % [current_scene.name])

	quit()
