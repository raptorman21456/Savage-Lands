extends SceneTree

# Isolated on purpose: clicking Quit calls get_tree().quit() directly, so a
# clean process exit here (no hang, no error) IS the confirmation -- mixing
# this into the main title-screen test would make it unclear whether the
# script's own quit() or the button's quit() ended the process.
func _init() -> void:
	var title_scene = load("res://TitleScreen.tscn")
	var title = title_scene.instantiate()
	root.add_child(title)
	await process_frame
	await process_frame

	print("about to click Quit -- a clean exit right after this line is the pass condition")
	title.quit_button.pressed.emit()
