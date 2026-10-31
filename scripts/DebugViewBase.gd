extends Control

# What every tab of the Debug menu stands on: it knows the menu and the live Main, builds its controls in build(), and after any action
# (act) shows the result in the menu's log strip and rebuilds itself so every number is current -- keeping its scroll position and
# which control had the keyboard.

const DebugKitScript := preload("res://scripts/DebugKit.gd")
const DebugActionsScript := preload("res://scripts/DebugActions.gd")
const DebugWorldScript := preload("res://scripts/DebugWorld.gd")
const DebugBattleScript := preload("res://scripts/DebugBattle.gd")
const DebugProgressScript := preload("res://scripts/DebugProgress.gd")

var menu = null          # the DebugMenu
var main = null          # the live Main

func setup(menu_ref, main_ref) -> void:
	menu = menu_ref
	main = main_ref
	build()

func player():
	return main.player

# Override: fill this control. Called again by refresh(), so start with clear().
func build() -> void:
	pass

func clear() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()

# A tab's whole area is one scrolling column.
func column() -> VBoxContainer:
	var s: ScrollContainer = DebugKitScript.scroll(size)
	add_child(s)
	var box: VBoxContainer = DebugKitScript.vbox(s, 4)
	return box

# Shows a result in the menu's log; closes the menu if the result asks to (a teleport, a battle starting); otherwise rebuilds.
func act(result: Dictionary) -> void:
	menu.report(result)
	if bool(result.get("close", false)) and bool(result.get("ok", false)):
		return
	refresh()

# Rebuild, keeping the scroll positions and the keyboard focus.
func refresh() -> void:
	if not is_inside_tree():
		build()
		return
	var snap: Dictionary = DebugKitScript.snapshot(self)
	build()
	DebugKitScript.restore(self, snap)

# A "label: stepper" row. setter(new_value) returns a result. opts as DebugKit.number takes them (min, max, steps, float, width).
func num(parent: Node, label_text: String, value, setter: Callable, opts: Dictionary = {}, tip: String = "") -> HBoxContainer:
	var r: HBoxContainer = DebugKitScript.row(parent, label_text, float(opts.get("label_w", 230.0)), tip)
	DebugKitScript.number(r, value, func(v): act(setter.call(v)), opts)
	return r

# A button that runs an action returning a result.
func btn(parent: Node, text: String, action: Callable, on: bool = false, tip: String = "") -> PixelButton:
	var b: PixelButton = DebugKitScript.button(text, func(): act(action.call()), on, "", tip)
	parent.add_child(b)
	return b

# "label: [On]/[Off]" -- pressing flips it through setter(new_value).
func switch_row(parent: Node, label_text: String, value: bool, setter: Callable, tip: String = "") -> PixelButton:
	var r: HBoxContainer = DebugKitScript.row(parent, label_text, 230.0, tip)
	var b: PixelButton = DebugKitScript.button("On" if value else "Off", func(): act(setter.call(not value)), value)
	b.custom_minimum_size = Vector2(96, 0)
	r.add_child(b)
	return b

# Pick an enemy by name: a search box and the matching names as buttons. The pick is kept in st["enemy"] (menu.state), so the
# World and Battle tabs share it. `world_tab` only changes the hint.
func enemy_picker(parent: Node, st: Dictionary) -> void:
	var names: Array = DebugWorldScript.enemy_list(main)
	if not st.has("enemy") or DebugWorldScript.enemy_entry(main, str(st.enemy)).is_empty():
		st["enemy"] = "Goblin"
	var box: VBoxContainer = DebugKitScript.vbox(parent, 4)
	var head: HBoxContainer = DebugKitScript.hbox(box, 8)
	var chosen := PixelKit.label("Enemy: %s" % str(st.enemy), "body", PixelKit.GOLD3)
	chosen.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(chosen)
	DebugKitScript.fill(head)
	var results: HFlowContainer = DebugKitScript.flow(null)
	var fill_results := func():
		for c in results.get_children():
			results.remove_child(c)
			c.queue_free()
		var needle := str(st.get("enemy_search", "")).to_lower()
		for e in names:
			if needle != "" and not str(e.name).to_lower().contains(needle):
				continue
			var tag := " (boss)" if e.boss else (" (mini)" if e.miniboss else "")
			results.add_child(DebugKitScript.button(str(e.name) + tag, func():
				st["enemy"] = str(e.name)
				chosen.text = "Enemy: %s" % str(e.name)
				for b in results.get_children():
					b.on = b.get_meta("enemy", "") == str(e.name)
			, str(e.name) == str(st.enemy), "", "HP %d  ·  hits for %d  ·  %d XP%s" % [int(e.hp), int(e.dmg), int(e.xp), "  ·  boss" if e.boss else ("  ·  miniboss" if e.miniboss else "")]))
			results.get_child(results.get_child_count() - 1).set_meta("enemy", str(e.name))
	head.add_child(DebugKitScript.search_field(str(st.get("enemy_search", "")), func(t):
		st["enemy_search"] = t
		fill_results.call()
	, "Search enemies"))
	box.add_child(results)
	fill_results.call()

# "Enemy level": how strong the enemies are, as a hero's level (the game scales enemies by YOUR level; pick another and they are as
# strong as for a hero of that level). Kept in cfg["level"]; 0 = as the game would make them for you right now.
func enemy_level_row(parent: Node, cfg: Dictionary) -> void:
	var chosen: int = int(cfg.get("level", 0))
	var set_level := func(v):
		cfg["level"] = v
		return DebugActionsScript.ok("Enemies will be as strong as for a level %d hero." % v)
	var r: HBoxContainer = num(parent, "Enemy level", chosen if chosen > 0 else int(player().level), set_level, {"min": 1, "max": 99, "steps": [1, 10], "label_w": 150},
		"The game makes every enemy stronger the higher YOUR level is. Pick a level here and they are as strong as they would be for a hero of that level (bosses grow more slowly).")
	if chosen > 0:
		r.add_child(DebugKitScript.button("Same as mine", func():
			cfg["level"] = 0
			refresh()))

# A small "Name: value" line for read-outs.
func readout(parent: Node, label_text: String, value_text: String, value_color: Color = PixelKit.CREAM) -> HBoxContainer:
	var h: HBoxContainer = DebugKitScript.row(parent, label_text)
	var v := PixelKit.label(value_text, "body", value_color)
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(v)
	return h

# Wraps a call that returns a result so it can be bound to a button.
func do(call: Callable) -> Callable:
	return func(): act(call.call())
