extends "res://scripts/DebugViewBase.gd"

# WORLD: teleport to any place, region, room, town venue or building interior; reveal the whole map; set the difficulty enemies use;
# put a chosen enemy (any count, danger tier, elite or not) near you; clear the map of enemies.

const WorldMapScript := preload("res://scripts/WorldMap.gd")
const RoomsScript := preload("res://scripts/Rooms.gd")

const LEFT_W := 520.0
const TOP := 52.0

var ws: Dictionary = {}          # this tab's remembered state (menu.state.world)
var _list: VBoxContainer = null

func build() -> void:
	clear()
	if not menu.state.has("world"):
		menu.state["world"] = {"cat": "Places", "search": ""}
	ws = menu.state.world
	_enemy_state()
	_left_column()
	_right_column()

# The enemy chosen for spawning and for battles, shared with the Battle tab.
func _enemy_state() -> Dictionary:
	if not menu.state.has("enemy_cfg"):
		menu.state["enemy_cfg"] = {"enemy": "Goblin", "enemy_search": "", "count": 1, "tier": maxi(1, DebugWorldScript.current_tier(main)) if bool(main.regional_world) else 1, "elite": false, "power": 1.0, "level": 0}
	return menu.state.enemy_cfg

# --- where to go --------------------------------------------------------------------------------------------------------------------

func _left_column() -> void:
	var k := DebugKitScript
	var tabs := k.flow(self)
	tabs.position = Vector2.ZERO
	tabs.size = Vector2(LEFT_W, 44)
	for c in DebugWorldScript.CATEGORIES:
		tabs.add_child(k.button(c, func():
			ws["cat"] = c
			refresh()
		, c == str(ws.cat)))
	var bar := k.hbox(self, 10)
	bar.position = Vector2(0, TOP)
	bar.size = Vector2(LEFT_W, 40)
	bar.add_child(k.search_field(str(ws.search), func(t):
		ws["search"] = t
		_fill_list()
	))
	var hint := PixelKit.label("Press a name to go there.", "body", PixelKit.DIM)
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(hint)
	var frame_and_box: Array = k.framed_scroll(Vector2(LEFT_W, size.y - TOP - 48))
	frame_and_box[0].position = Vector2(0, TOP + 48)
	add_child(frame_and_box[0])
	_list = frame_and_box[1]
	_fill_list()

func _fill_list() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var needle := str(ws.search).to_lower()
	var shown := 0
	for entry in DebugWorldScript.destinations(main, str(ws.cat)):
		if needle != "" and not (str(entry.name).to_lower().contains(needle) or str(entry.sub).to_lower().contains(needle)):
			continue
		var e: Dictionary = entry
		var line := DebugKitScript.hbox(_list, 8)
		var go: PixelButton = DebugKitScript.button(str(entry.name), func(): act(DebugWorldScript.go(main, e)))
		line.add_child(go)
		var sub := PixelKit.label(str(entry.sub), "body", PixelKit.DIM)
		sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.add_child(sub)
		shown += 1
	if shown == 0:
		_list.add_child(PixelKit.label("Nothing matches.", "body", PixelKit.DIM))

# --- everything else -----------------------------------------------------------------------------------------------------------------

func _right_column() -> void:
	var k := DebugKitScript
	var x := LEFT_W + 12.0
	var scroll: ScrollContainer = k.scroll(Vector2(size.x - x, size.y))
	scroll.position = Vector2(x, 0)
	add_child(scroll)
	var col: VBoxContainer = k.vbox(scroll, 4)
	var p = player()
	var cfg := _enemy_state()
	k.section(col, "You are here")
	var region: Dictionary = WorldMapScript.region_at(p.global_position)
	var room: Dictionary = RoomsScript.room_at(p.global_position)
	if bool(main.in_interior):
		readout(col, "Inside", "a building", PixelKit.GOLD3)
	else:
		readout(col, "Region", "%s  (danger %d)" % [str(region.name), int(region.tier)])
		readout(col, "Room", str(room.name) if str(room.name) != "" else "Room %d,%d" % [int(room.cell.x), int(room.cell.y)])
	readout(col, "Position", "%d, %d" % [int(p.global_position.x), int(p.global_position.y)], PixelKit.DIM)
	var here := k.flow(col)
	if bool(main.in_interior):
		here.add_child(k.button("Leave the building", func(): act(DebugWorldScript.leave_interior(main)), true))
	here.add_child(k.button("Unstick me", func(): act(DebugWorldScript.unstick(main)), false, "", "Moves you to the nearest open ground if you are wedged in a wall or a tree."))
	k.section(col, "Map")
	var map_row := k.flow(col)
	map_row.add_child(k.button("Reveal the whole map", func(): act(DebugWorldScript.reveal_map(main)), false, "", "The Compass without the talisman: every room counts as visited, every place as found."))
	map_row.add_child(k.button("Hide it again", func(): act(DebugWorldScript.hide_map(main))))
	readout(col, "Rooms visited", "%d of %d" % [main.visited_rooms.size(), RoomsScript.rooms.size()], PixelKit.DIM)
	k.section(col, "Difficulty")
	var diff_row: HBoxContainer = k.row(col, "Enemies use", 150.0, "Changes how hard enemies hit and how much HP they have in this run. The slot's own saved difficulty stays as it is.")
	var diffs: Array = []
	for d in DebugWorldScript.DIFFICULTIES:
		diffs.append([d, str(d).capitalize()])
	k.choice_row(diff_row, diffs, str(p.difficulty_id), func(id): act(DebugWorldScript.set_difficulty(main, str(id))))
	readout(col, "Now", "x%s HP and damage" % DebugActionsScript._fmt(p.difficulty_mult), PixelKit.DIM)
	k.section(col, "Enemies")
	enemy_picker(col, cfg)
	var set_count := func(v):
		cfg["count"] = v
		return DebugActionsScript.ok("Count: %d." % v)
	num(col, "How many", int(cfg.count), set_count, {"min": 1, "max": 12, "steps": [1], "label_w": 150})
	var set_tier := func(v):
		cfg["tier"] = v
		return DebugActionsScript.ok("Danger tier %d: enemies get x%s HP and damage." % [v, DebugActionsScript._fmt(DebugWorldScript.tier_power(v))])
	num(col, "Danger tier", int(cfg.tier), set_tier, {"min": 1, "max": 8, "steps": [1], "label_w": 150},
		"The region danger tiers go from 1 (the plains) to 8 (the Voidlands); each multiplies enemy HP and damage (x%s at tier %d)." % [DebugActionsScript._fmt(DebugWorldScript.tier_power(int(cfg.tier))), int(cfg.tier)])
	enemy_level_row(col, cfg)
	var set_elite := func(v):
		cfg["elite"] = v
		return DebugActionsScript.ok("Elite: %s." % ("on" if v else "off"))
	switch_row(col, "Elite", bool(cfg.elite), set_elite)
	var spawn := k.flow(col)
	spawn.add_child(k.button("Spawn near me", func(): act(DebugWorldScript.spawn_near(main, str(cfg.enemy), int(cfg.count), int(cfg.tier), bool(cfg.elite), float(cfg.power), int(cfg.get("level", 0)))), true))
	spawn.add_child(k.button("Remove all enemies", func(): act(DebugWorldScript.clear_enemies(main))))
	spawn.add_child(k.button("Refill wild enemies", func(): act(DebugWorldScript.refill_enemies(main))))
	if not bool(main.regional_world):
		k.section(col, "Old arena worlds")
		var arena := k.flow(col)
		arena.add_child(k.button("Previous world", func():
			main._debug_jump_world(-1)
			act(DebugActionsScript.ok("World: %s." % str(main.WORLDS[main.current_world_index].name)))))
		arena.add_child(k.button("Next world", func():
			main._debug_jump_world(1)
			act(DebugActionsScript.ok("World: %s." % str(main.WORLDS[main.current_world_index].name)))))
	k.spacer(col, 12)
