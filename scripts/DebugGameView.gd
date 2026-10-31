extends "res://scripts/DebugViewBase.gd"

# GAME: the game's speed, an info read-out and the collision view, a state dump for the console, the save slot (back up, restore,
# reset -- the last with a confirm), every cheat's switch, and the way back to the title screen.

const SPEEDS := [["0.1", "x0.1"], ["0.25", "x0.25"], ["0.5", "x0.5"], ["1", "x1"], ["2", "x2"], ["4", "x4"], ["8", "x8"]]

func build() -> void:
	clear()
	var k := DebugKitScript
	var col: VBoxContainer = column()
	var p = player()

	k.section(col, "Game speed")
	var speed_row: HBoxContainer = k.row(col, "Speed", 150.0, "Slows or speeds up everything: walking, battles' animations, timers.")
	k.choice_row(speed_row, SPEEDS, DebugActionsScript._fmt(Engine.time_scale), func(id): act(DebugProgressScript.set_time_scale(float(id))))

	k.section(col, "What to see")
	var set_overlay := func(v):
		menu.set_overlay(v)
		return DebugActionsScript.ok("The read-out in the corner is %s." % ("on" if v else "off"))
	switch_row(col, "Info read-out", menu.show_overlay, set_overlay, "A line at the top left: frames per second, your position, region, room, enemies, speed.")
	switch_row(col, "Collision shapes", DebugProgressScript.collision_view_on(main), func(v): return DebugProgressScript.set_collision_view(main, v),
		"Draws every wall, tree and hit area. Rooms that load later are drawn too.")

	k.section(col, "Console")
	var dump := k.flow(col)
	dump.add_child(k.button("Print state to the console", func(): act(DebugProgressScript.print_state(main)), false, "", "Writes everything about the run (stats, gear, party, position, battle, save) to the console and copies it, so it can be pasted into a chat."))

	k.section(col, "Save slot")
	k.note(col, DebugProgressScript.slot_summary(), PixelKit.CREAM)
	if SaveData.sandbox_active:
		k.note(col, "This is the Sandbox: its slot lives in memory only, so none of this touches a real save.")
	var slot := k.flow(col)
	slot.add_child(k.button("Back up the slot", func(): act(DebugProgressScript.backup_slot()), false, "", "Copies the slot's Essence, upgrades, name and difficulty aside."))
	var restore: PixelButton = k.button("Restore the backup", func(): menu.confirm("Put the backed-up slot back? What the slot holds now is replaced.", func(): act(DebugProgressScript.restore_slot(main))))
	k.set_enabled(restore, DebugProgressScript.has_backup())
	slot.add_child(restore)
	slot.add_child(k.button("Reset the slot", func(): menu.confirm("Wipe this slot's Essence and Church upgrades? Its name and difficulty stay. (Back it up first if you might want it back.)", func(): act(DebugProgressScript.reset_slot(main))), false, "", "Essence, upgrades and best are wiped; name and difficulty stay."))

	k.section(col, "Cheats now")
	var cheats: Array = []
	if p.debug_god_mode:
		cheats.append("god mode")
	if p.debug_infinite_stamina:
		cheats.append("infinite stamina")
	if DebugActionsScript.one_hit_kills_on(main):
		cheats.append("one-hit kills")
	if p.debug_speed_mult != 1.0:
		cheats.append("walking x%s" % DebugActionsScript._fmt(p.debug_speed_mult))
	if Engine.time_scale != 1.0:
		cheats.append("game speed x%s" % DebugActionsScript._fmt(Engine.time_scale))
	k.note(col, ", ".join(cheats) if not cheats.is_empty() else "none on", PixelKit.CREAM if not cheats.is_empty() else PixelKit.DIM)
	var off := k.flow(col)
	var all_off: PixelButton = k.button("Turn every cheat off", func():
		DebugActionsScript.reset_cheats(main)
		act(DebugActionsScript.ok("Every cheat is off.")))
	k.set_enabled(all_off, not cheats.is_empty())
	off.add_child(all_off)

	k.section(col, "Leave")
	var leave := k.flow(col)
	leave.add_child(k.button("Back to the title screen", func(): menu.confirm("Leave this run for the title screen? The run is lost.", func(): act(DebugProgressScript.go_to_title(main)))))
	var settings = main.settings
	if not SaveData.sandbox_active and settings != null:
		leave.add_child(k.button("Turn this menu off", func():
			menu.confirm("Turn the Debug menu off? It stays off (F1 does nothing) until you turn it on again in Settings > Gameplay.", func():
				DebugActionsScript.reset_cheats(main)
				settings.set_debug_menu_enabled(false)
				menu.close())))
	k.note(col, "The menu is turned on or off in Settings > Gameplay > Debug menu (F1).")
	k.spacer(col, 12)
