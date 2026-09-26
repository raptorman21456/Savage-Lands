extends CanvasLayer
class_name TavernPanel

# The Bounty Hunter's Tavern (see Main.gd:_build_town) -- one rotating
# bounty plus two simple wager minigames, tabbed exactly like the Inventory
# screen (TABS/tab_buttons/tab_containers/_on_tab_pressed copied verbatim;
# see InventoryPanel.gd), since each activity has its own transient UI
# state (a chosen wager, an in-flight result) best kept isolated per tab.
# Bounty state (bounty_target/bounty_baseline) lives on Main.gd alongside
# run_bosses_defeated, the counter it tracks -- this panel reads/mutates it
# via get_parent(), same as QuestBoardPanel does for quest_slots. The two
# minigames need no shared state at all, so their wager logic lives here
# directly, calling _player.try_spend_coins/add_coins the same way
# HealerPanel calls _player.restore_health/reset_stamina.

const TABS := ["Bounty", "Coin Flip", "Dice Guess"]
const WAGER_PRESETS := [10, 25, 50, 100]
# A player-favored coin isn't a fair 50/50 -- the house always keeps a
# slim edge, disclosed plainly in the tab's own description.
const COIN_FLIP_WIN_CHANCE := 0.45
const DICE_GUESS_PAYOUT_MULT := 5

var _was_paused := false
var _player: Player = null
var active_tab: String = "Bounty"
var tab_buttons := {}
var tab_containers := {}
var coin_flip_wager: int = WAGER_PRESETS[0]
var dice_wager: int = WAGER_PRESETS[0]
var dice_guess: int = 1
var coin_flip_last_result := ""
var dice_last_result := ""

func _ready() -> void:
	layer = 30
	visible = false
	_build()

func _build() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.75)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)

	var window_size := Vector2(620, 520)
	var window := Panel.new()
	window.size = window_size
	var window_style := StyleBoxFlat.new()
	window_style.bg_color = Color(0.08, 0.08, 0.1)
	window_style.border_color = Color(0.4, 0.4, 0.45)
	window_style.set_border_width_all(3)
	window.add_theme_stylebox_override("panel", window_style)
	scrim.add_child(window)
	window.position = ((get_viewport().get_visible_rect().size - window_size) / 2).round()

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 20)
	window.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	margin.add_child(outer)

	var title_row := HBoxContainer.new()
	outer.add_child(title_row)
	var title := Label.new()
	title.text = "BOUNTY HUNTER'S TAVERN"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	title_row.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(spacer)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(close)
	title_row.add_child(close_button)

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	outer.add_child(tab_row)
	for tab_name in TABS:
		var button := Button.new()
		button.text = tab_name
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(130, 34)
		button.button_pressed = tab_name == active_tab
		button.pressed.connect(_on_tab_pressed.bind(tab_name))
		_style_tab_button(button)
		tab_row.add_child(button)
		tab_buttons[tab_name] = button

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var content_stack := VBoxContainer.new()
	content_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content_stack)
	for tab_name in TABS:
		var container := VBoxContainer.new()
		container.add_theme_constant_override("separation", 10)
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.visible = tab_name == active_tab
		content_stack.add_child(container)
		tab_containers[tab_name] = container

func _style_tab_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _make_stylebox(Color(0.13, 0.12, 0.15, 0.92), Color(0.4, 0.4, 0.45), 2))
	button.add_theme_stylebox_override("hover", _make_stylebox(Color(0.2, 0.19, 0.13, 0.96), Color(1.0, 0.9, 0.2), 2))
	button.add_theme_stylebox_override("pressed", _make_stylebox(Color(0.22, 0.18, 0.05, 0.95), Color(1.0, 0.85, 0.2), 2))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _make_stylebox(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(8)
	return style

func open(player_ref: Player) -> void:
	_player = player_ref
	_was_paused = get_tree().paused
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_refresh()
	visible = true

func close() -> void:
	visible = false
	get_tree().paused = _was_paused

func _on_tab_pressed(tab_name: String) -> void:
	active_tab = tab_name
	for name in tab_buttons:
		tab_buttons[name].button_pressed = name == tab_name
	for name in tab_containers:
		tab_containers[name].visible = name == tab_name

func _refresh() -> void:
	for name in tab_containers:
		for c in tab_containers[name].get_children():
			c.queue_free()
	_build_bounty_tab(tab_containers["Bounty"])
	_build_coin_flip_tab(tab_containers["Coin Flip"])
	_build_dice_guess_tab(tab_containers["Dice Guess"])
	_on_tab_pressed(active_tab)

func _add_heading(container: VBoxContainer, text: String) -> void:
	var heading := Label.new()
	heading.text = text
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	container.add_child(heading)

func _add_body_label(container: VBoxContainer, text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", color)
	container.add_child(label)
	return label

# --- Bounty: always "defeat N bosses this run" -- escalates and rebaselines
# on claim (see Main.gd:claim_bounty), a guaranteed Masterwork+ weapon every
# time. Deliberately boss-only so it never overlaps the Quest Board's
# varied everyday tasks. ---------------------------------------------------

func _build_bounty_tab(container: VBoxContainer) -> void:
	var main := get_parent()
	_add_heading(container, "BOUNTY")
	var remaining: int = maxi(0, main.bounty_target - main.bounty_progress())
	_add_body_label(container, "Defeat %d more boss-tier enem%s this run." % [remaining, "y" if remaining == 1 else "ies"], Color(0.85, 0.85, 0.8))
	_add_body_label(container, "Progress: %d / %d" % [mini(main.bounty_progress(), main.bounty_target), main.bounty_target], Color(0.7, 0.8, 0.95))
	_add_body_label(container, "Reward: a guaranteed Masterwork-or-better weapon.", Color(0.6, 0.85, 0.6))

	var claim_button := Button.new()
	claim_button.custom_minimum_size = Vector2(160, 36)
	if main.is_bounty_complete():
		claim_button.text = "Claim Bounty"
		claim_button.pressed.connect(func():
			main.claim_bounty()
			_refresh()
		)
	else:
		claim_button.text = "Not Yet Complete"
		claim_button.disabled = true
	container.add_child(claim_button)

# --- Coin Flip: double or nothing on a wager, house keeps a slim edge. ---

func _build_coin_flip_tab(container: VBoxContainer) -> void:
	_add_heading(container, "COIN FLIP")
	_add_body_label(container, "Double or nothing -- the house keeps a slim edge (%d%% to win)." % int(COIN_FLIP_WIN_CHANCE * 100), Color(0.8, 0.8, 0.75))

	var wager_row := HBoxContainer.new()
	wager_row.add_theme_constant_override("separation", 8)
	container.add_child(wager_row)
	for preset in WAGER_PRESETS:
		var b := Button.new()
		b.text = "%d" % preset
		b.toggle_mode = true
		b.button_pressed = preset == coin_flip_wager
		b.disabled = _player.coins < preset
		b.pressed.connect(func():
			coin_flip_wager = preset
			_refresh()
		)
		wager_row.add_child(b)

	var flip_button := Button.new()
	flip_button.text = "Flip (wager %d)" % coin_flip_wager
	flip_button.custom_minimum_size = Vector2(160, 36)
	flip_button.disabled = _player.coins < coin_flip_wager
	flip_button.pressed.connect(_on_coin_flip_pressed)
	container.add_child(flip_button)

	_add_body_label(container, coin_flip_last_result, Color(0.85, 0.85, 0.8))

func _on_coin_flip_pressed() -> void:
	var wager := coin_flip_wager
	if not _player.try_spend_coins(wager):
		return
	if randf() < COIN_FLIP_WIN_CHANCE:
		_player.add_coins(wager * 2)
		coin_flip_last_result = "Heads! You win %d coins." % (wager * 2)
		_play_sfx("purchase")
	else:
		coin_flip_last_result = "Tails. You lose your %d coins." % wager
		_play_sfx("error")
	_refresh()

# --- Dice Guess: guess a 1-6 roll for a bigger payout multiple. ---

func _build_dice_guess_tab(container: VBoxContainer) -> void:
	_add_heading(container, "DICE GUESS")
	_add_body_label(container, "Guess the roll of a 6-sided die -- guess right, win %dx your wager." % DICE_GUESS_PAYOUT_MULT, Color(0.8, 0.8, 0.75))

	var guess_row := HBoxContainer.new()
	guess_row.add_theme_constant_override("separation", 6)
	container.add_child(guess_row)
	for n in range(1, 7):
		var b := Button.new()
		b.text = "%d" % n
		b.custom_minimum_size = Vector2(36, 36)
		b.toggle_mode = true
		b.button_pressed = n == dice_guess
		b.pressed.connect(func():
			dice_guess = n
			_refresh()
		)
		guess_row.add_child(b)

	var wager_row := HBoxContainer.new()
	wager_row.add_theme_constant_override("separation", 8)
	container.add_child(wager_row)
	for preset in WAGER_PRESETS:
		var b2 := Button.new()
		b2.text = "%d" % preset
		b2.toggle_mode = true
		b2.button_pressed = preset == dice_wager
		b2.disabled = _player.coins < preset
		b2.pressed.connect(func():
			dice_wager = preset
			_refresh()
		)
		wager_row.add_child(b2)

	var roll_button := Button.new()
	roll_button.text = "Roll (wager %d on %d)" % [dice_wager, dice_guess]
	roll_button.custom_minimum_size = Vector2(180, 36)
	roll_button.disabled = _player.coins < dice_wager
	roll_button.pressed.connect(_on_dice_guess_pressed)
	container.add_child(roll_button)

	_add_body_label(container, dice_last_result, Color(0.85, 0.85, 0.8))

func _on_dice_guess_pressed() -> void:
	var wager := dice_wager
	if not _player.try_spend_coins(wager):
		return
	var roll := randi_range(1, 6)
	if roll == dice_guess:
		_player.add_coins(wager * DICE_GUESS_PAYOUT_MULT)
		dice_last_result = "Rolled %d -- you win %d coins!" % [roll, wager * DICE_GUESS_PAYOUT_MULT]
		_play_sfx("purchase")
	else:
		dice_last_result = "Rolled %d -- you lose your %d coins." % [roll, wager]
		_play_sfx("error")
	_refresh()

func _play_sfx(sfx_name: String) -> void:
	var parent := get_parent()
	if parent != null and parent.has_method("play_sfx"):
		parent.play_sfx(sfx_name)
