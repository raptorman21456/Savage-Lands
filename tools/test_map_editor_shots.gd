extends SceneTree

# Screenshots of the Map Editor into ui_screenshots/map_editor/, and a check that every panel fits the window with the REAL fonts (a headless
# run measures text with a stand-in font, so this is where the fit is checked). Named test_* so any SaveData use stays in scratch files; the
# editor itself never touches saves, and every Save here goes to a scratch folder. Needs a real window (it skips itself headless).
#
#   Godot --path . --resolution 1152x648 --script res://tools/test_map_editor_shots.gd

var out_dir := ""
var count := 0
var ed

func _shot(label: String, frames: int = 20) -> void:
	for i in frames:
		await process_frame
	count += 1
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s%02d_%s.png" % [out_dir, count, label])
	print("shot %02d %s" % [count, label])

# Every control in the panel stays inside it, the top bar fits the window, the tab row is one line.
func _fit(label: String) -> void:
	for i in 4:
		await process_frame
	var ui = ed.ui
	var panel_rect: Rect2 = ui._panel.get_global_rect()
	var out: Array = []
	_collect_outside(ui._body, panel_rect, out)
	var top_need: float = ui._top_row.get_combined_minimum_size().x
	print("fit [%s]: tab row %d px tall (expected under 50), top bar needs %d of %d px (expected within), controls outside the panel: %s (expected [])" % [label, int(ui._tab_row.size.y), int(top_need), int(root.size.x), out.slice(0, 4)])

func _collect_outside(node: Node, panel_rect: Rect2, out: Array) -> void:
	for c in node.get_children():
		if c is Control and c.is_visible_in_tree():
			var r: Rect2 = c.get_global_rect()
			if r.end.x > panel_rect.end.x - 8.0 + 0.5 or r.position.x < panel_rect.position.x:
				if r.size.x > 4.0:
					out.append("%s %s" % [c.get_class(), r])
		_collect_outside(c, panel_rect, out)

func _init() -> void:
	if DisplayServer.get_name() == "headless":
		print("test_map_editor_shots: needs a window, skipped (run it without --headless)")
		quit()
		return
	out_dir = ProjectSettings.globalize_path("res://ui_screenshots/map_editor/")
	DirAccess.make_dir_recursive_absolute(out_dir)
	for f in DirAccess.get_files_at(out_dir):
		if f.ends_with(".png"):
			DirAccess.remove_absolute(out_dir + f)
	await process_frame
	await process_frame
	ed = load("res://MapEditor.tscn").instantiate()
	# keep any save out of the real data folder
	ed.data_dir = "user://map_editor_shots_data"
	root.add_child(ed)
	await _shot("opens_on_the_spawn_room", 90)
	await _fit("opening view, Room tab")
	ed.focus_world()
	await _shot("whole_world", 40)
	ed.pick_cell(Vector2i(4, 3))
	ed.focus_room()
	await _shot("spawn_room_room_tab", 90)
	ed.set_tab("floor")
	ed.select_item(0)
	await _shot("floor_tab_oval_picked", 30)
	await _fit("Floor tab, shape picked")
	ed.select_item(1)
	await _fit("Floor tab, path picked")
	ed.set_tab("decor")
	ed.select_item(1)
	await _shot("decor_tab", 30)
	await _fit("Decor tab")
	ed.set_tab("props")
	ed.pick_cell(Vector2i(0, 2))
	ed.focus_room()
	ed.select_item(0)
	await _shot("props_tab_camp", 90)
	await _fit("Props tab")
	ed.set_tab("doors")
	ed.pick_cell(Vector2i(4, 3))
	ed.focus_room()
	await _shot("doors_tab", 90)
	ed.select_side("4,3|5,3")
	ed.set_edge("4,3|5,3", [[1082, 600], [300, 400]])
	await _shot("doors_two_doorways", 40)
	await _fit("Doors tab, side with two doorways")
	ed.undo()
	ed.set_tab("world")
	await _shot("world_tab_places", 20)
	await _fit("World tab, places")
	ed.sel_id = "heartwood"
	ed.ui.refresh()
	await _fit("World tab, a place picked")
	ed.set_world_tab("roads")
	ed.sel_i = 1
	ed.ui.refresh()
	await _fit("World tab, a road picked")
	ed.set_world_tab("regions")
	ed.sel_id = "woods"
	ed.ui.refresh()
	await _shot("world_tab_regions", 20)
	await _fit("World tab, a region picked")
	ed.set_tab("room")
	ed.pick_cell(Vector2i(0, 9))
	ed.focus_room()
	await _shot("generated_room", 40)
	await _fit("Room tab, a generated room")
	# the map check, with a mistake in it: the Wolf Den shut in
	ed.pick_cell(Vector2i(0, 4))
	for s in ed.room_sides():
		ed.set_edge(s.name, "closed")
	ed.ui.run_check()
	await _shot("map_check_finds_a_shut_in_room", 20)
	ed.ui.close_popups()
	while not ed.undo_stack.is_empty():
		ed.undo()
	# an edit in progress: a new cut shape being drawn in the Floor tab
	ed.pick_cell(Vector2i(2, 3))
	ed.focus_room()
	ed.set_tab("floor")
	ed.set_new_mode("cut")
	ed.arm({"type": "shape", "kind": "disc", "mode": "cut"})
	await _shot("drawing_a_cut", 60)
	ed.disarm()
	ed.set_tab("room")
	await _fit("Room tab, hand-made room")
	# the status line must never need cutting: the longest hint with the longest read-out
	ed.pick_cell(Vector2i(10, 10))
	ed.make_handmade()
	ed.set_tab("floor")
	ed.arm({"type": "shape", "kind": "poly", "mode": "floor"})
	ed.ui.set_cursor_info(ed.cell_rect(Vector2i(10, 10)).end - Vector2(5, 5))
	await process_frame
	await process_frame
	var hint_w: float = ed.ui._status_hint.get_minimum_size().x
	var read_w: float = ed.ui._status_cursor.get_minimum_size().x
	print("fit [status line]: hint %d px + read-out %d px of %d (expected within, with room to spare)" % [int(hint_w), int(read_w), int(root.size.x - 24)])
	ed.disarm()
	ed.undo()
	ed.set_tab("room")
	# a saved-state shot: after Save the 'unsaved' chip is gone
	ed.save()
	await _shot("after_save", 20)
	ed.ui.toggle_help()
	await _shot("help", 10)
	ed.ui.close_popups()
	ed.ui.choose("What the walls are made of", ed.MapDataScript.MASSES.map(func(m): return [m, ed.ShapesScript.MASS_NAMES.get(m, m)]), "forest", func(id): pass)
	await _shot("chooser", 10)
	ed.ui.close_popups()
	ed.ui._on_exit()
	await _shot("leave_box_no_unsaved", 5)
	ed.queue_free()
	await process_frame
	await process_frame
	# the title screen with its new entry
	var sd = load("res://scripts/SaveData.gd")
	sd.sandbox_active = false
	sd.delete_slot(1)
	sd.init_slot(1, "hard", "The Barbarian")
	sd.active_slot = 1
	var title = load("res://TitleScreen.tscn").instantiate()
	root.add_child(title)
	await process_frame
	await process_frame
	title._leave_splash()
	title._on_slot_pressed(1)
	title.map_editor_button.grab_focus()
	await _shot("title_menu_map_editor", 30)
	print("The title menu with the Map Editor entry: description \"%s\" (expected two lines at most)" % [title.description_label.text])
	print("DONE: %d screenshots in %s" % [count, out_dir])
	quit()
