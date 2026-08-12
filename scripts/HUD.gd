extends CanvasLayer
class_name HUD

const WeaponsScript := preload("res://scripts/Weapons.gd")
const PlayerScript := preload("res://scripts/Player.gd")

# Flat cost to lock a rolled (non-Club) weapon offer so a reroll can't take
# it away -- kept in sync with the identical const in Main.gd, which is
# what actually spends the coins; this copy is display-text only.
const SHOP_LOCK_COST := 5

# The battle grid shows each enemy as its actual overworld sprite instead of
# a generic letter, keyed by the same display name battle_units already
# carries.
const BLADE_ALLY_ICON := preload("res://assets/blade_ally.png")
const TOGGLE_OFF_ICON := preload("res://assets/toggle_off.png")
const TOGGLE_ON_ICON := preload("res://assets/toggle_on.png")

const ENEMY_ICONS := {
	"Goblin": preload("res://assets/enemy_goblin.png"),
	"Orc": preload("res://assets/enemy_orc.png"),
	"Boss": preload("res://assets/enemy_boss.png"),
	"Owlbear": preload("res://assets/enemy_owlbear.png"),
	"Apprentice Mage": preload("res://assets/enemy_apprentice_mage.png"),
	"Shaman": preload("res://assets/enemy_shaman.png"),
	"Brute": preload("res://assets/enemy_brute.png"),
	"Shade": preload("res://assets/enemy_shade.png"),
	# Traitor Wolf shares Wolf's sprite -- distinguished by tint at spawn
	# time (Main.gd:TRAITOR_WOLF_TINT), not a second hand-drawn sprite.
	"Wolf": preload("res://assets/enemy_wolf.png"),
	"Traitor Wolf": preload("res://assets/enemy_wolf.png"),
	# Unlike Wolf/Traitor Wolf, a Centaur's two variants fight differently
	# often within the same pack, so they get distinct sprites instead of a
	# shared one with a tint.
	"Centaur Lancer": preload("res://assets/enemy_centaur_lancer.png"),
	"Centaur Archer": preload("res://assets/enemy_centaur_archer.png"),
	"Fae Hut": preload("res://assets/enemy_fae_hut.png"),
	"Fae": preload("res://assets/enemy_fae.png"),
	"Gnome": preload("res://assets/enemy_gnome.png"),
	"Druid": preload("res://assets/enemy_druid.png"),
	"Aboleth": preload("res://assets/enemy_aboleth.png"),
	"Water Elemental": preload("res://assets/enemy_water_elemental.png"),
	"Lizard Soldier Swarm": preload("res://assets/enemy_lizard_soldier_swarm.png"),
	"Black Dragonlet": preload("res://assets/enemy_black_dragonlet.png"),
	"Treant": preload("res://assets/enemy_treant.png"),
	"Elder Oak": preload("res://assets/enemy_elder_oak.png"),
	"Gibbering Mouther": preload("res://assets/enemy_gibbering_mouther.png"),
	"Iron Golem": preload("res://assets/enemy_iron_golem.png"),
	"Stone Giant": preload("res://assets/enemy_stone_giant.png"),
	"Beholder": preload("res://assets/enemy_beholder.png"),
	"Frost Giant": preload("res://assets/enemy_frost_giant.png"),
	"White Dragon": preload("res://assets/enemy_white_dragon.png"),
	"Roc": preload("res://assets/enemy_roc.png"),
	"Blue Dragon": preload("res://assets/enemy_blue_dragon.png"),
	"Lava Golem": preload("res://assets/enemy_lava_golem.png"),
	"Red Wyrm": preload("res://assets/enemy_red_wyrm.png"),
	"Voidwing": preload("res://assets/enemy_voidwing.png"),
	"Supreme Warlock": preload("res://assets/enemy_supreme_warlock.png"),
	"Demogorgon": preload("res://assets/enemy_demogorgon.png"),
	"Tiamat": preload("res://assets/enemy_tiamat.png"),
	"Count Strahd": preload("res://assets/enemy_count_strahd.png"),
	"Duke Zalto": preload("res://assets/enemy_duke_zalto.png"),
	"Acererak": preload("res://assets/enemy_acererak.png"),
}

# Battle-grid terrain tiles -- the other 3 match battle_terrain's "type"
# strings exactly. Grass (the default, terrain-less tile) and water aren't
# here -- both are AnimatedTextures built in _ready() from the *_FRAME_
# TEXTURES arrays below instead of a single static frame.
const TERRAIN_TILE_ICONS := {
	"rock": preload("res://Sprites/Rock.png"),
	"cliff": preload("res://Sprites/Cliff.png"),
	"ledge": preload("res://Sprites/Ledge.png"),
	# Reserved terrain (Main.gd:RESERVED_TERRAIN_TYPES) -- never rolled by a
	# real battle yet, but rendered correctly the moment one of them is, via
	# the same static-lookup path as rock/cliff/ledge above (procedurally
	# generated into res://assets/ instead of hand-drawn, like every other
	# gen_sprites.gd icon).
	"ice": preload("res://assets/terrain_ice.png"),
	"embers": preload("res://assets/terrain_embers.png"),
	"poison_bog": preload("res://assets/terrain_poison_bog.png"),
	"quicksand": preload("res://assets/terrain_quicksand.png"),
	"spring": preload("res://assets/terrain_spring.png"),
	"crumbling": preload("res://assets/terrain_crumbling.png"),
	"thicket": preload("res://assets/terrain_thicket.png"),
	"caltrops": preload("res://assets/terrain_caltrops.png"),
	"rubble": preload("res://assets/terrain_rubble.png"),
}

const WATER_FRAME_TEXTURES := [
	preload("res://Sprites/Water_0.png"),
	preload("res://Sprites/Water_1.png"),
	preload("res://Sprites/Water_2.png"),
]

# Order (0, +1 shift, -1 shift) reads as a gentle side-to-side sway when
# looped, rather than a one-directional scroll like water's current.
const GRASS_FRAME_TEXTURES := [
	preload("res://Sprites/GrassTile.png"),
	preload("res://Sprites/GrassTile_1.png"),
	preload("res://Sprites/GrassTile_2.png"),
]

# HP/Stamina bars: a dark tinted trough behind a bright fill, same
# background/fill-pair idiom the battle ally health bars already use
# (see battle_ally_hp_bg/battle_ally_hp_fill).
const HEALTH_BAR_BG_COLOR := Color(0.18, 0.05, 0.06, 1.0)
const HEALTH_BAR_FILL_COLOR := Color(0.82, 0.16, 0.22, 1.0)
const STAMINA_BAR_BG_COLOR := Color(0.06, 0.09, 0.17, 1.0)
const STAMINA_BAR_FILL_COLOR := Color(0.25, 0.55, 0.95, 1.0)

# The game's one shared "window" chrome -- a bronze/gold frame around dark
# purple-leaning cards. Originally just the shop's own palette; now the
# standard look every bordered panel/window uses (see _framed_panel below),
# so every screen reads as the same game instead of a pile of ad hoc dark
# rectangles. Shop's own offering rows additionally tint their border by
# category on top of this base.
const PANEL_BG := Color(0.09, 0.08, 0.12, 0.97)
const PANEL_BORDER := Color(0.62, 0.48, 0.2, 1.0)
const SHOP_CATEGORY_ACCENT_HOVER := Color(1.0, 0.95, 0.55, 1.0)
const SHOP_CATEGORY_COLOR := {
	"weapon": Color(0.82, 0.42, 0.26, 1.0),
	"armor": Color(0.58, 0.63, 0.72, 1.0),
	"shield": Color(0.35, 0.55, 0.85, 1.0),
	"potion": Color(0.56, 0.78, 0.36, 1.0),
	"enchant": Color(0.75, 0.55, 1.0, 1.0),
}

var health_label: Label
var health_bar_bg: ColorRect
var health_bar_fill: ColorRect
var health_heart_label: Label
var quiver_icon: TextureButton
var quiver_tooltip_label: Label
var coins_label: Label
var items_label: Label
var wave_label: Label
var world_label: Label
var enemies_label: Label
var level_label: Label
var xp_label: Label
var stats_label: Label
var message_label: Label
var levelup_panel: ColorRect
var levelup_label: Label
var levelup_description_label: Label
var levelup_box: VBoxContainer
var levelup_buttons := {}
var event_panel: ColorRect
var event_label: Label
var event_description_label: Label
var event_yes_button: Button
var event_no_button: Button
var menu_panel: ColorRect
var menu_resume_button: Button
var menu_settings_button: Button
var settings_panel: ColorRect
var settings_master_slider: HSlider
var settings_sfx_slider: HSlider
var settings_music_slider: HSlider
var settings_master_value_label: Label
var settings_sfx_value_label: Label
var settings_music_value_label: Label
var settings_shake_checkbox: CheckButton
var settings_damage_numbers_checkbox: CheckButton
var settings_rebind_buttons := {}
var settings_back_button: Button
var settings_node: Node
# Empty when no rebind is in progress; set to the action name while a rebind
# row's button is waiting for the next key press.
var rebinding_action := ""
var shop_panel: ColorRect
var shop_window: Panel
var shop_coins_label: Label
var shop_shards_label: Label
var shop_weapon_tag: Label
var shop_armor_tag: Label
var shop_shield_tag: Label
var shop_potions_tag: Label
var shop_footer_label: Label
var shop_description_label: Label
var shop_row_box: VBoxContainer
var shop_row_scroll: ScrollContainer
var shop_reroll_button: Button
var shop_continue_button: Button
var shop_row_nodes := []
var shop_gear_tab_button: Button
var shop_enchant_tab_button: Button
var shop_enchant_scroll: ScrollContainer
var shop_enchant_row_box: VBoxContainer
var shop_enchant_weapon_label: Label
var shop_enchant_row_nodes := []
var game_over_panel: ColorRect
var game_over_label: Label
var game_over_stats_scroll: ScrollContainer
var game_over_stats_box: VBoxContainer
var game_over_return_button: Button

signal battle_main_action(action: String)
signal battle_fight_action(action: String)
signal battle_move_action(action: String)
signal battle_arrow_action(action: String)
signal battle_tactics_action(action: String)
signal battle_evasion_confirm_pressed
signal enemy_hovered(index: int)
signal enemy_unhovered
signal rock_target_selected(tile: Vector2i)
signal levelup_choice_pressed(stat_name: String)
signal event_choice_pressed(accepted: bool)
signal menu_resume_pressed
signal settings_pressed
signal settings_back_pressed
signal shop_buy_pressed(index: int)
signal shop_lock_pressed(index: int)
signal shop_reroll_pressed
signal shop_continue_pressed
signal enchant_apply_pressed(rune_id: String)
signal arrow_buy_pressed(kind: String)
signal arrow_sell_pressed(kind: String)
signal game_over_return_pressed
signal enemy_target_selected(index: int)

var battle_panel: ColorRect
var battle_tile_rects := {}
var battle_tile_icons := {}
var battle_tile_markers := {}
var player_marker: Label
var battle_unit_markers := []
var battle_unit_icons := []
# Second, independent per-unit indicator (see update_battle_grid) -- the red
# "!" shown above a unit's sprite once it's spotted a stealthed player.
# Separate pool from battle_unit_markers since it renders at a different
# position (centered above, not the corner badge slot) and can be visible at
# the same time as that badge.
var battle_unit_aware_markers := []
# Hover-LOS overlay: shown over whichever tiles the currently-hovered enemy
# can see (see enemy_hovered/enemy_unhovered and show_sight_tiles/
# hide_sight_tiles). Sized for the largest possible grid.
var battle_sight_tile_rects := []
var battle_ally_icons := []
var battle_ally_hp_bg := []
var battle_ally_hp_fill := []
var battle_trail_markers := []
var battle_status_label: Label
var battle_status_label2: Label
var battle_hp_heart_label: Label
var battle_hp_bar_bg: ColorRect
var battle_hp_bar_fill: ColorRect
var battle_hp_number_label: Label
var battle_stamina_bar_bg: ColorRect
var battle_stamina_bar_fill: ColorRect
var battle_stamina_number_label: Label
var battle_log_label: Label
var battle_description_label: Label
var battle_log_lines := []
var battle_grid_origin := Vector2(20, 60)
var battle_tile_size := 56.0
# Matches Main.gd:BOSS_BATTLE_GRID_SIZE -- the biggest grid any battle uses
# (a boss fight), so the tile pool below is sized for the max case. The
# footprint every grid renders within stays fixed regardless of size (see
# update_battle_grid); a smaller battle just uses fewer, larger tiles -- this
# is what keeps the grid "centered"/stable on screen across every size (6x6
# through 15x15) rather than the box itself growing or shifting.
const MAX_BATTLE_GRID_SIZE := 15
const BATTLE_GRID_FOOTPRINT_PX := 336.0
# Kept in sync by hand with Main.gd:MAX_BATTLE_SQUAD_SIZE_CEILING -- the enemy
# icon/marker pools below must be at least this big or a heavily-scaled squad
# (see _squad_size_bonus) would index past the pool.
const MAX_BATTLE_UNITS := 6
# Kept in sync by hand with Main.gd:FAE_HUT_SPAWN_INTERVAL, purely for the
# battle-marker countdown text below (see update_battle_grid).
const FAE_HUT_SPAWN_INTERVAL := 3
var water_animated_texture: AnimatedTexture
var grass_animated_texture: AnimatedTexture

var battle_main_menu_box: HBoxContainer
var battle_fight_submenu_box: HBoxContainer
var battle_move_submenu_box: HBoxContainer
var battle_arrow_submenu_box: HBoxContainer
var battle_tactics_submenu_box: HBoxContainer
var battle_evasion_submenu_box: HBoxContainer
var battle_main_buttons := {}
var battle_fight_buttons := {}
var battle_move_buttons := {}
var battle_arrow_buttons := {}
var battle_tactics_buttons := {}

func _ready() -> void:
	layer = 10
	# See Player.gd/Main.gd for why this is a cached runtime node lookup
	# instead of the bare "Settings" autoload identifier.
	settings_node = get_node("/root/Settings")

	water_animated_texture = AnimatedTexture.new()
	water_animated_texture.frames = WATER_FRAME_TEXTURES.size()
	for i in WATER_FRAME_TEXTURES.size():
		water_animated_texture.set_frame_texture(i, WATER_FRAME_TEXTURES[i])
		water_animated_texture.set_frame_duration(i, 0.35)

	grass_animated_texture = AnimatedTexture.new()
	grass_animated_texture.frames = GRASS_FRAME_TEXTURES.size()
	for i in GRASS_FRAME_TEXTURES.size():
		grass_animated_texture.set_frame_texture(i, GRASS_FRAME_TEXTURES[i])
		grass_animated_texture.set_frame_duration(i, 0.6)

	health_label = Label.new()
	health_label.position = Vector2(16, 16)
	health_label.add_theme_font_size_override("font_size", 20)
	add_child(health_label)

	# A red heart-bar next to the "HP: X / Y" text -- the numbers stay
	# (health_label above is untouched), this is purely a visual read-at-a-
	# glance addition. Same bg/fill ColorRect-pair idiom the battle ally
	# health bars already use.
	health_heart_label = Label.new()
	health_heart_label.text = "♥"
	health_heart_label.position = Vector2(180, 12)
	health_heart_label.add_theme_font_size_override("font_size", 22)
	health_heart_label.add_theme_color_override("font_color", HEALTH_BAR_FILL_COLOR)
	add_child(health_heart_label)

	health_bar_bg = ColorRect.new()
	health_bar_bg.color = HEALTH_BAR_BG_COLOR
	health_bar_bg.position = Vector2(204, 18)
	health_bar_bg.size = Vector2(110, 16)
	add_child(health_bar_bg)

	health_bar_fill = ColorRect.new()
	health_bar_fill.color = HEALTH_BAR_FILL_COLOR
	health_bar_fill.position = Vector2(204, 18)
	health_bar_fill.size = Vector2(110, 16)
	add_child(health_bar_fill)

	# Quiver: only visible while a Bow is equipped (see update_quiver), one
	# row below the HP bar so it clears it with a clean gutter. Hovering
	# shows the live flame/freeze/bomb counts in quiver_tooltip_label, same
	# "hover reveals detail" idea as every other hover-description in this
	# game, just a floating label next to the icon instead of a shared
	# status-line -- there's no natural shared description bar out here on
	# the overworld HUD the way battle/shop have one.
	quiver_icon = TextureButton.new()
	quiver_icon.texture_normal = load("res://assets/quiver.png")
	quiver_icon.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	quiver_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	quiver_icon.position = Vector2(180, 40)
	quiver_icon.size = Vector2(22, 22)
	quiver_icon.focus_mode = Control.FOCUS_NONE
	quiver_icon.visible = false
	quiver_icon.mouse_entered.connect(func(): quiver_tooltip_label.text = quiver_icon.get_meta("tooltip", ""))
	quiver_icon.mouse_exited.connect(func(): quiver_tooltip_label.text = "")
	add_child(quiver_icon)

	quiver_tooltip_label = Label.new()
	quiver_tooltip_label.position = Vector2(206, 42)
	quiver_tooltip_label.add_theme_font_size_override("font_size", 14)
	quiver_tooltip_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.6))
	add_child(quiver_tooltip_label)

	level_label = Label.new()
	level_label.position = Vector2(16, 44)
	level_label.add_theme_font_size_override("font_size", 20)
	add_child(level_label)

	xp_label = Label.new()
	xp_label.position = Vector2(16, 72)
	xp_label.add_theme_font_size_override("font_size", 18)
	add_child(xp_label)

	stats_label = Label.new()
	stats_label.position = Vector2(16, 98)
	stats_label.add_theme_font_size_override("font_size", 18)
	add_child(stats_label)

	coins_label = Label.new()
	coins_label.position = Vector2(16, 126)
	coins_label.add_theme_font_size_override("font_size", 20)
	coins_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	add_child(coins_label)

	items_label = Label.new()
	items_label.position = Vector2(16, 154)
	items_label.add_theme_font_size_override("font_size", 20)
	items_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	add_child(items_label)

	wave_label = Label.new()
	wave_label.position = Vector2(16, 182)
	wave_label.add_theme_font_size_override("font_size", 20)
	add_child(wave_label)

	# Sits beside wave_label rather than stacking a new row -- Main.gd's
	# WORLDS-driven text (e.g. "World: Beach (3/10)") is short enough to fit.
	world_label = Label.new()
	world_label.position = Vector2(140, 182)
	world_label.add_theme_font_size_override("font_size", 20)
	world_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	add_child(world_label)

	enemies_label = Label.new()
	enemies_label.position = Vector2(16, 210)
	enemies_label.add_theme_font_size_override("font_size", 20)
	add_child(enemies_label)

	message_label = Label.new()
	message_label.position = Vector2(16, 242)
	message_label.add_theme_font_size_override("font_size", 24)
	message_label.add_theme_color_override("font_color", Color(1, 0.9, 0.2))
	add_child(message_label)

	var help_label := Label.new()
	help_label.position = Vector2(16, 278)
	help_label.text = "Arrows to move, WASD to attack, C for menu"
	add_child(help_label)

	menu_panel = ColorRect.new()
	menu_panel.color = Color(0, 0, 0, 0.65)
	menu_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_panel.visible = false
	add_child(menu_panel)
	_framed_panel(Vector2(260, 200), Vector2(240, 220), menu_panel)

	var menu_label := Label.new()
	menu_label.position = Vector2(300, 250)
	menu_label.add_theme_font_size_override("font_size", 32)
	menu_label.text = "PAUSED"
	menu_panel.add_child(menu_label)

	menu_resume_button = Button.new()
	menu_resume_button.position = Vector2(300, 310)
	menu_resume_button.custom_minimum_size = Vector2(160, 36)
	menu_resume_button.text = "Resume"
	menu_resume_button.pressed.connect(func(): menu_resume_pressed.emit())
	_style_standard_button(menu_resume_button)
	_add_hover_color(menu_resume_button)
	menu_panel.add_child(menu_resume_button)

	menu_settings_button = Button.new()
	menu_settings_button.position = Vector2(300, 354)
	menu_settings_button.custom_minimum_size = Vector2(160, 36)
	menu_settings_button.text = "Settings"
	menu_settings_button.pressed.connect(func(): settings_pressed.emit())
	_style_standard_button(menu_settings_button)
	_add_hover_color(menu_settings_button)
	menu_panel.add_child(menu_settings_button)

	_build_settings_panel()

	levelup_panel = ColorRect.new()
	levelup_panel.color = Color(0, 0, 0, 0.75)
	levelup_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	levelup_panel.visible = false
	add_child(levelup_panel)
	_framed_panel(Vector2(200, 180), Vector2(460, 470), levelup_panel)

	levelup_label = Label.new()
	levelup_label.position = Vector2(230, 200)
	levelup_label.add_theme_font_size_override("font_size", 26)
	levelup_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	levelup_panel.add_child(levelup_label)

	# Room for up to 8 rows now (the 4 original stats plus Might, always
	# shown, plus Resilience/Reflexes/Dexterity once each is unlocked) --
	# the description label moved down accordingly. See show_levelup_choice
	# for the actual row-building (rebuilt fresh every time the panel opens,
	# same clear-and-rebuild idiom show_shop uses for its offering rows).
	levelup_description_label = Label.new()
	levelup_description_label.position = Vector2(230, 560)
	levelup_description_label.size = Vector2(400, 60)
	levelup_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	levelup_description_label.add_theme_font_size_override("font_size", 14)
	levelup_description_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.6))
	levelup_panel.add_child(levelup_description_label)

	levelup_box = VBoxContainer.new()
	levelup_box.position = Vector2(230, 260)
	levelup_box.add_theme_constant_override("separation", 6)
	levelup_panel.add_child(levelup_box)

	# Random events -- same full-screen-overlay + title + description +
	# button shape as the level-up panel above, just fixed at exactly 2
	# buttons (Yes/No) instead of one per stat.
	event_panel = ColorRect.new()
	event_panel.color = Color(0, 0, 0, 0.75)
	event_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	event_panel.visible = false
	add_child(event_panel)
	_framed_panel(Vector2(200, 180), Vector2(460, 280), event_panel)

	event_label = Label.new()
	event_label.position = Vector2(230, 200)
	event_label.add_theme_font_size_override("font_size", 26)
	event_label.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	event_panel.add_child(event_label)

	event_description_label = Label.new()
	event_description_label.position = Vector2(230, 250)
	event_description_label.size = Vector2(400, 80)
	event_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	event_description_label.add_theme_font_size_override("font_size", 16)
	event_description_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	event_panel.add_child(event_description_label)

	var event_box := VBoxContainer.new()
	event_box.position = Vector2(230, 350)
	event_box.add_theme_constant_override("separation", 8)
	event_panel.add_child(event_box)

	event_yes_button = Button.new()
	event_yes_button.custom_minimum_size = Vector2(320, 32)
	event_yes_button.pressed.connect(func(): event_choice_pressed.emit(true))
	_style_standard_button(event_yes_button)
	_add_hover_color(event_yes_button)
	event_box.add_child(event_yes_button)

	event_no_button = Button.new()
	event_no_button.custom_minimum_size = Vector2(320, 32)
	event_no_button.pressed.connect(func(): event_choice_pressed.emit(false))
	_style_standard_button(event_no_button)
	_add_hover_color(event_no_button)
	event_box.add_child(event_no_button)

	# The shop is the first screen to get a real bordered "window" treatment
	# (StyleBoxFlat cards/frame) instead of a flat ColorRect -- scoped to just
	# the shop for now rather than a shared Theme resource, since it's the
	# only screen currently asking for it.
	shop_panel = ColorRect.new()
	shop_panel.color = Color(0, 0, 0, 0.55)
	shop_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	shop_panel.visible = false
	add_child(shop_panel)

	var shop_window_size := Vector2(720, 560)
	shop_window = Panel.new()
	shop_window.size = shop_window_size
	shop_window.add_theme_stylebox_override("panel", _make_stylebox(PANEL_BG, PANEL_BORDER, 3, 0, 0))
	shop_panel.add_child(shop_window)
	# Centered on whatever the viewport actually is rather than a hardcoded
	# resolution, so this can't quietly drift off-center later.
	shop_window.position = ((get_viewport().get_visible_rect().size - shop_window_size) / 2).round()

	var shop_margin := MarginContainer.new()
	shop_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		shop_margin.add_theme_constant_override("margin_%s" % side, 20)
	shop_window.add_child(shop_margin)

	var shop_column := VBoxContainer.new()
	shop_column.add_theme_constant_override("separation", 10)
	shop_margin.add_child(shop_column)

	var shop_title_row := HBoxContainer.new()
	shop_column.add_child(shop_title_row)

	var shop_title_label := Label.new()
	shop_title_label.text = "SHOP"
	shop_title_label.add_theme_font_size_override("font_size", 28)
	shop_title_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	shop_title_row.add_child(shop_title_label)

	var shop_title_spacer := Control.new()
	shop_title_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_title_row.add_child(shop_title_spacer)

	var shop_coin_icon := TextureRect.new()
	shop_coin_icon.texture = load("res://assets/coin.png")
	shop_coin_icon.custom_minimum_size = Vector2(22, 22)
	shop_coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shop_title_row.add_child(shop_coin_icon)

	shop_coins_label = Label.new()
	shop_coins_label.add_theme_font_size_override("font_size", 24)
	shop_coins_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	shop_title_row.add_child(shop_coins_label)

	var shop_shard_icon := TextureRect.new()
	shop_shard_icon.texture = load("res://assets/runic_shard.png")
	shop_shard_icon.custom_minimum_size = Vector2(22, 22)
	shop_shard_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shop_title_row.add_child(shop_shard_icon)

	shop_shards_label = Label.new()
	shop_shards_label.add_theme_font_size_override("font_size", 24)
	shop_shards_label.add_theme_color_override("font_color", Color(0.75, 0.55, 1.0))
	shop_title_row.add_child(shop_shards_label)

	var shop_separator := ColorRect.new()
	shop_separator.color = PANEL_BORDER
	shop_separator.custom_minimum_size = Vector2(0, 2)
	shop_column.add_child(shop_separator)

	# Two tabs sharing the same content area below -- Gear (the existing
	# offering list) and Enchant (runes for whatever weapon is currently
	# equipped). Toggling swaps which scroll container is visible; both stay
	# populated underneath so switching back and forth never needs a rebuild.
	var shop_tab_row := HBoxContainer.new()
	shop_tab_row.add_theme_constant_override("separation", 8)
	shop_column.add_child(shop_tab_row)

	shop_gear_tab_button = Button.new()
	shop_gear_tab_button.text = "Gear"
	shop_gear_tab_button.custom_minimum_size = Vector2(100, 32)
	shop_gear_tab_button.toggle_mode = true
	shop_gear_tab_button.button_pressed = true
	shop_tab_row.add_child(shop_gear_tab_button)

	shop_enchant_tab_button = Button.new()
	shop_enchant_tab_button.text = "Enchant"
	shop_enchant_tab_button.custom_minimum_size = Vector2(100, 32)
	shop_enchant_tab_button.toggle_mode = true
	shop_tab_row.add_child(shop_enchant_tab_button)

	shop_gear_tab_button.pressed.connect(func(): _select_shop_tab("gear"))
	shop_enchant_tab_button.pressed.connect(func(): _select_shop_tab("enchant"))
	_style_shop_tab_button(shop_gear_tab_button)
	_style_shop_tab_button(shop_enchant_tab_button)

	var shop_status_row := HBoxContainer.new()
	shop_status_row.add_theme_constant_override("separation", 24)
	shop_column.add_child(shop_status_row)

	shop_weapon_tag = Label.new()
	shop_weapon_tag.add_theme_color_override("font_color", SHOP_CATEGORY_COLOR["weapon"])
	shop_status_row.add_child(shop_weapon_tag)

	shop_armor_tag = Label.new()
	shop_armor_tag.add_theme_color_override("font_color", SHOP_CATEGORY_COLOR["armor"])
	shop_status_row.add_child(shop_armor_tag)

	shop_shield_tag = Label.new()
	shop_shield_tag.add_theme_color_override("font_color", SHOP_CATEGORY_COLOR["shield"])
	shop_status_row.add_child(shop_shield_tag)

	shop_potions_tag = Label.new()
	shop_potions_tag.add_theme_color_override("font_color", SHOP_CATEGORY_COLOR["potion"])
	shop_status_row.add_child(shop_potions_tag)

	# Scrolled and height-capped rather than left to grow the panel freely --
	# the offering can run to 8+ rows (3 rolled weapons + club + armor + 3
	# potions), which was tall enough to run into the description/Reroll/
	# Continue/footer elements below it when they were all just absolutely
	# positioned assuming a shorter list.
	shop_row_scroll = ScrollContainer.new()
	shop_row_scroll.custom_minimum_size = Vector2(0, 260)
	shop_row_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_row_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shop_column.add_child(shop_row_scroll)

	shop_row_box = VBoxContainer.new()
	shop_row_box.add_theme_constant_override("separation", 8)
	shop_row_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_row_scroll.add_child(shop_row_box)

	# Enchant tab -- same scroll/row-list shape as the Gear tab above, but
	# starts hidden and occupies the same slot in shop_column (toggled by
	# _select_shop_tab), plus a label naming whatever weapon is being
	# enchanted since there's no weapon-picker (see Player.gd:
	# try_apply_enchantment -- there's no general "browse every owned
	# weapon" inventory in this game, only current_weapon_base is ever a
	# full Dictionary in memory).
	shop_enchant_scroll = ScrollContainer.new()
	shop_enchant_scroll.custom_minimum_size = Vector2(0, 260)
	shop_enchant_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_enchant_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shop_enchant_scroll.visible = false
	shop_column.add_child(shop_enchant_scroll)

	var shop_enchant_column := VBoxContainer.new()
	shop_enchant_column.add_theme_constant_override("separation", 8)
	shop_enchant_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_enchant_scroll.add_child(shop_enchant_column)

	shop_enchant_weapon_label = Label.new()
	shop_enchant_weapon_label.add_theme_font_size_override("font_size", 16)
	shop_enchant_weapon_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	shop_enchant_column.add_child(shop_enchant_weapon_label)

	shop_enchant_row_box = VBoxContainer.new()
	shop_enchant_row_box.add_theme_constant_override("separation", 8)
	shop_enchant_row_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_enchant_column.add_child(shop_enchant_row_box)

	shop_description_label = Label.new()
	shop_description_label.custom_minimum_size = Vector2(0, 36)
	shop_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	shop_description_label.add_theme_font_size_override("font_size", 14)
	shop_description_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.6))
	shop_column.add_child(shop_description_label)

	var shop_action_box := HBoxContainer.new()
	shop_action_box.alignment = BoxContainer.ALIGNMENT_CENTER
	shop_action_box.add_theme_constant_override("separation", 16)
	shop_column.add_child(shop_action_box)

	shop_reroll_button = Button.new()
	shop_reroll_button.custom_minimum_size = Vector2(220, 40)
	shop_reroll_button.pressed.connect(func(): shop_reroll_pressed.emit())
	_setup_hover_button(shop_reroll_button, "Reroll the shop's offering. Costs more each time you use it this visit.", shop_description_label)
	_style_shop_action_button(shop_reroll_button, false)
	shop_action_box.add_child(shop_reroll_button)

	shop_continue_button = Button.new()
	shop_continue_button.custom_minimum_size = Vector2(260, 40)
	shop_continue_button.text = "Continue to Next Wave"
	shop_continue_button.pressed.connect(func(): shop_continue_pressed.emit())
	_setup_hover_button(shop_continue_button, "Leave the shop and start the next wave.", shop_description_label)
	_style_shop_action_button(shop_continue_button, true)
	shop_action_box.add_child(shop_continue_button)

	shop_footer_label = Label.new()
	shop_footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_footer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_footer_label.add_theme_font_size_override("font_size", 13)
	shop_footer_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	shop_footer_label.text = "[1-9] Buy   [R] Reroll   [Enter] Continue"
	shop_column.add_child(shop_footer_label)

	game_over_panel = ColorRect.new()
	game_over_panel.color = Color(0, 0, 0, 0.8)
	game_over_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_over_panel.visible = false
	add_child(game_over_panel)
	_framed_panel(Vector2(200, 100), Vector2(460, 470), game_over_panel)

	game_over_label = Label.new()
	game_over_label.position = Vector2(230, 130)
	game_over_label.add_theme_font_size_override("font_size", 26)
	game_over_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	game_over_panel.add_child(game_over_label)

	# Run recap -- reuses the Shop's ScrollContainer+VBoxContainer "clear and
	# rebuild row list" idiom (see show_shop above) instead of a fixed set of
	# labels, since the per-enemy kill breakdown is variable-length.
	game_over_stats_scroll = ScrollContainer.new()
	game_over_stats_scroll.position = Vector2(230, 210)
	game_over_stats_scroll.custom_minimum_size = Vector2(420, 280)
	game_over_stats_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	game_over_panel.add_child(game_over_stats_scroll)

	game_over_stats_box = VBoxContainer.new()
	game_over_stats_box.add_theme_constant_override("separation", 4)
	game_over_stats_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game_over_stats_scroll.add_child(game_over_stats_box)

	game_over_return_button = Button.new()
	game_over_return_button.position = Vector2(230, 510)
	game_over_return_button.custom_minimum_size = Vector2(220, 40)
	game_over_return_button.text = "Return to Title (R)"
	game_over_return_button.pressed.connect(func(): game_over_return_pressed.emit())
	_style_standard_button(game_over_return_button)
	_add_hover_color(game_over_return_button)
	game_over_panel.add_child(game_over_return_button)

	_build_battle_ui()

# The Cliff/Ledge/Water art is drawn facing "down" (dir/push_dir ==
# Vector2i(0, 1)) at 0 rotation -- every other cardinal direction rotates
# that same source art around the tile's center instead of needing 4 more
# source images.
func _dir_rotation(dir: Vector2i) -> float:
	if dir == Vector2i(0, 1):
		return 0.0
	if dir == Vector2i(0, -1):
		return PI
	if dir == Vector2i(1, 0):
		return -PI / 2.0
	if dir == Vector2i(-1, 0):
		return PI / 2.0
	return 0.0

func _dir_arrow(dir: Vector2i) -> String:
	if dir == Vector2i(0, -1):
		return "^"
	if dir == Vector2i(0, 1):
		return "v"
	if dir == Vector2i(-1, 0):
		return "<"
	if dir == Vector2i(1, 0):
		return ">"
	return ""

func _on_battle_tile_gui_input(event: InputEvent, t: Vector2i) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		rock_target_selected.emit(t)

func _build_battle_ui() -> void:
	# Advance Wars-style tile battle: a 6x6 grid (terrain colored per tile),
	# unit markers, an LV/HP/turn status line, and a log/hint area.
	battle_panel = ColorRect.new()
	battle_panel.color = Color(0.05, 0.05, 0.05, 1.0)
	battle_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	battle_panel.visible = false
	add_child(battle_panel)
	# A full-screen content panel (not a floating dialog like the pause/
	# level-up/event/game-over cards) -- gets an inset picture-frame border
	# around the whole edge instead of a smaller centered card, so it still
	# reads as "the same game" as everywhere else without disturbing any of
	# the grid/HUD elements already positioned inside it.
	_framed_panel(Vector2(8, 8), get_viewport().get_visible_rect().size - Vector2(16, 16), battle_panel)

	# Pooled at the max size any battle can use (a boss fight's 9x9, see
	# Main.gd:BOSS_BATTLE_GRID_SIZE) -- position/size aren't set here since
	# they depend on the current battle's tile_size, which varies (a bigger
	# grid renders smaller tiles to keep the same on-screen footprint); both
	# are computed fresh in update_battle_grid, which also hides whichever
	# tiles the current battle's grid_w/grid_h don't use.
	for y in MAX_BATTLE_GRID_SIZE:
		for x in MAX_BATTLE_GRID_SIZE:
			var t := Vector2i(x, y)
			var rect := ColorRect.new()
			rect.color = Color(0.05, 0.05, 0.05)
			# Clickable for Hand Picks' Mine action (see rock_target_selected)
			# -- reports every tile click unconditionally, same as an enemy
			# icon's press does for its own index; Main.gd's handler is what
			# decides whether this particular tile/turn/weapon actually makes
			# the click mean anything.
			rect.mouse_filter = Control.MOUSE_FILTER_STOP
			rect.gui_input.connect(func(event): _on_battle_tile_gui_input(event, t))
			battle_panel.add_child(rect)
			battle_tile_rects[t] = rect

			# The terrain art tile, drawn over the border-color rect above --
			# scaled to fully fill the cell rather than kept-aspect, since a
			# terrain tile should read as ground, not a padded icon.
			var tile_icon := TextureRect.new()
			tile_icon.pivot_offset = Vector2.ZERO
			tile_icon.stretch_mode = TextureRect.STRETCH_SCALE
			tile_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tile_icon.texture = grass_animated_texture
			battle_panel.add_child(tile_icon)
			battle_tile_icons[t] = tile_icon

			var marker := Label.new()
			marker.add_theme_font_size_override("font_size", 18)
			marker.visible = false
			battle_panel.add_child(marker)
			battle_tile_markers[t] = marker

	# The player's own "@" marker used to double up as battle_unit_markers[0]
	# (with battle_unit_icons[0] reserved, unused, for a single ally icon) --
	# now that up to 4 companions (3 party slots + 1 wolf) need their own
	# icons at once, that one leftover slot doesn't fit anymore. Dedicated
	# label instead, and the enemy pool below goes back to a clean 1:1
	# mapping with no reserved slot.
	player_marker = Label.new()
	player_marker.add_theme_font_size_override("font_size", 24)
	player_marker.visible = false
	battle_panel.add_child(player_marker)

	# Icons are added (and thus drawn) before the markers, so a unit's "!"
	# windup badge always renders on top of its sprite, not behind it.
	# TextureButton (not a plain TextureRect) so an enemy can be targeted by
	# clicking its sprite directly. Sized to MAX_BATTLE_UNITS -- indices map
	# 1:1 to battle_units[0..MAX_BATTLE_UNITS-1], a mapping stable across
	# frames since battle_units only ever shrinks in place, never reorders.
	for i in MAX_BATTLE_UNITS:
		var icon := TextureButton.new()
		icon.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.focus_mode = Control.FOCUS_NONE
		icon.visible = false
		icon.pressed.connect(func(): enemy_target_selected.emit(i))
		# Hover-LOS: reveals which tiles this enemy can currently see while
		# Stealth is active (see Main.gd:_on_enemy_hovered). No-op outside
		# Stealth, handled on the Main.gd side.
		icon.mouse_entered.connect(func(): enemy_hovered.emit(i))
		icon.mouse_exited.connect(func(): enemy_unhovered.emit())
		battle_panel.add_child(icon)
		battle_unit_icons.append(icon)

	for i in MAX_BATTLE_UNITS:
		var unit_marker := Label.new()
		unit_marker.add_theme_font_size_override("font_size", 24)
		unit_marker.visible = false
		battle_panel.add_child(unit_marker)
		battle_unit_markers.append(unit_marker)

	# "Spotted" indicator -- red "!" centered above a unit's sprite once it's
	# spotted the player (see update_battle_grid). Separate pool from
	# battle_unit_markers above: different position (centered above, not the
	# corner badge slot) so the two can be visible on the same unit at once.
	for i in MAX_BATTLE_UNITS:
		var aware_marker := Label.new()
		aware_marker.add_theme_font_size_override("font_size", 22)
		aware_marker.add_theme_color_override("font_color", Color(0.9, 0.15, 0.15))
		aware_marker.visible = false
		battle_panel.add_child(aware_marker)
		battle_unit_aware_markers.append(aware_marker)

	# Hover-LOS overlay tiles (see show_sight_tiles/hide_sight_tiles), sized
	# generously for the largest grid (MAX_BATTLE_GRID_SIZE^2, same bound the
	# terrain tile pool elsewhere in this file already uses).
	for i in MAX_BATTLE_GRID_SIZE * MAX_BATTLE_GRID_SIZE:
		var sight_rect := ColorRect.new()
		sight_rect.color = Color(1.0, 0.95, 0.4, 0.28)
		sight_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sight_rect.visible = false
		battle_panel.add_child(sight_rect)
		battle_sight_tile_rects.append(sight_rect)

	# Companion icons: not click-targetable (plain TextureRect, unlike the
	# enemy pool above) -- allies now stand on their own real battle tile
	# (see Main.gd:battle_allies) rather than a fixed stacked slot, so this
	# pool just needs to be big enough for the max possible simultaneous
	# allies: 3 party_members (2 base + Pack Leader's +1) plus 1 wolf. Each
	# also gets a small health-bar background/fill pair, drawn under its
	# icon.
	for i in 4:
		var ally_icon := TextureRect.new()
		ally_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ally_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ally_icon.visible = false
		battle_panel.add_child(ally_icon)
		battle_ally_icons.append(ally_icon)

		var hp_bg := ColorRect.new()
		hp_bg.color = Color(0.15, 0.1, 0.1)
		hp_bg.visible = false
		battle_panel.add_child(hp_bg)
		battle_ally_hp_bg.append(hp_bg)

		var hp_fill := ColorRect.new()
		hp_fill.color = Color(0.3, 0.85, 0.3)
		hp_fill.visible = false
		battle_panel.add_child(hp_fill)
		battle_ally_hp_fill.append(hp_fill)

	# Pokemon-Conquest-style path arrows for the current pending move -- more
	# than enough slots for any realistic move range.
	for i in 8:
		var trail_marker := Label.new()
		trail_marker.add_theme_font_size_override("font_size", 20)
		trail_marker.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
		trail_marker.visible = false
		battle_panel.add_child(trail_marker)
		battle_trail_markers.append(trail_marker)

	# Top line: level + whose turn it is. HP/Stamina used to be crammed into
	# this same line as plain text -- pulled out into their own bars below
	# (numbers kept, see battle_hp_number_label/battle_stamina_number_label)
	# so the line's a lot shorter now, still comfortably clears
	# battle_log_label starting at x=400.
	battle_status_label = Label.new()
	battle_status_label.position = Vector2(20, 20)
	battle_status_label.add_theme_font_size_override("font_size", 18)
	battle_status_label.add_theme_color_override("font_color", Color(1, 1, 1))
	battle_panel.add_child(battle_status_label)

	# HP row: heart glyph, then bar, then the numbers -- same bg/fill
	# ColorRect-pair idiom the battle ally health bars use.
	battle_hp_heart_label = Label.new()
	battle_hp_heart_label.text = "♥"
	battle_hp_heart_label.position = Vector2(20, 39)
	battle_hp_heart_label.add_theme_font_size_override("font_size", 16)
	battle_hp_heart_label.add_theme_color_override("font_color", HEALTH_BAR_FILL_COLOR)
	battle_panel.add_child(battle_hp_heart_label)

	battle_hp_bar_bg = ColorRect.new()
	battle_hp_bar_bg.color = HEALTH_BAR_BG_COLOR
	battle_hp_bar_bg.position = Vector2(36, 43)
	battle_hp_bar_bg.size = Vector2(95, 12)
	battle_panel.add_child(battle_hp_bar_bg)

	battle_hp_bar_fill = ColorRect.new()
	battle_hp_bar_fill.color = HEALTH_BAR_FILL_COLOR
	battle_hp_bar_fill.position = Vector2(36, 43)
	battle_hp_bar_fill.size = Vector2(95, 12)
	battle_panel.add_child(battle_hp_bar_fill)

	battle_hp_number_label = Label.new()
	battle_hp_number_label.position = Vector2(136, 39)
	battle_hp_number_label.add_theme_font_size_override("font_size", 15)
	battle_hp_number_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.75))
	battle_panel.add_child(battle_hp_number_label)

	# Stamina row: same idiom, no icon -- bar starts at the same x as the HP
	# bar (below the heart glyph's slot) so the two rows stay column-aligned.
	battle_stamina_bar_bg = ColorRect.new()
	battle_stamina_bar_bg.color = STAMINA_BAR_BG_COLOR
	battle_stamina_bar_bg.position = Vector2(206, 43)
	battle_stamina_bar_bg.size = Vector2(95, 12)
	battle_panel.add_child(battle_stamina_bar_bg)

	battle_stamina_bar_fill = ColorRect.new()
	battle_stamina_bar_fill.color = STAMINA_BAR_FILL_COLOR
	battle_stamina_bar_fill.position = Vector2(206, 43)
	battle_stamina_bar_fill.size = Vector2(95, 12)
	battle_panel.add_child(battle_stamina_bar_fill)

	battle_stamina_number_label = Label.new()
	battle_stamina_number_label.position = Vector2(306, 39)
	battle_stamina_number_label.add_theme_font_size_override("font_size", 15)
	battle_stamina_number_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	battle_panel.add_child(battle_stamina_number_label)

	# Everything that used to be battle_status_label's 2nd+ lines (Target/
	# Shield/BERSERK) -- a separate label now that the bars sit where those
	# lines used to start, positioned just above the grid's own top edge
	# (battle_grid_origin.y == 60).
	battle_status_label2 = Label.new()
	battle_status_label2.position = Vector2(20, 58)
	battle_status_label2.add_theme_font_size_override("font_size", 18)
	battle_status_label2.add_theme_color_override("font_color", Color(1, 1, 1))
	battle_panel.add_child(battle_status_label2)

	battle_log_label = Label.new()
	battle_log_label.position = Vector2(400, 60)
	battle_log_label.add_theme_font_size_override("font_size", 15)
	battle_log_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	battle_panel.add_child(battle_log_label)

	battle_description_label = Label.new()
	battle_description_label.position = Vector2(20, 470)
	battle_description_label.size = Vector2(560, 40)
	battle_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	battle_description_label.add_theme_font_size_override("font_size", 14)
	battle_description_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.6))
	battle_panel.add_child(battle_description_label)

	battle_main_menu_box = HBoxContainer.new()
	battle_main_menu_box.position = Vector2(20, 425)
	battle_main_menu_box.add_theme_constant_override("separation", 8)
	battle_panel.add_child(battle_main_menu_box)
	for action in [
		["Move", "move", "Reposition on the grid. Doesn't end your turn."],
		["Fight", "fight", "Choose an attack: a free regular hit, a costly heavy hit, or one of your weapon's specials."],
		["Item", "item", "Use a healing potion."],
		["Defend", "defend", "Brace for impact -- reduces damage taken this turn and recovers a big chunk of stamina (+25)."],
		["Skill", "skill", "Guardian's Ultimatum: instantly heal 40% of max HP. Once every 4 turns."],
		["Arrow", "arrow", "Fire a purchased special arrow. Costs no stamina, but consumes 1 of that arrow."],
		["Tactics", "tactics", "Taunt to force every enemy's attention onto you, or vanish into Stealth."],
		["Flee", "flee", "Retreat from this battle."],
	]:
		var button := Button.new()
		button.text = action[0]
		button.pressed.connect(func(): battle_main_action.emit(action[1]))
		_setup_hover_button(button, action[2], battle_description_label)
		_style_standard_button(button)
		battle_main_menu_box.add_child(button)
		battle_main_buttons[action[1]] = button

	battle_fight_submenu_box = HBoxContainer.new()
	battle_fight_submenu_box.position = Vector2(20, 425)
	battle_fight_submenu_box.add_theme_constant_override("separation", 8)
	battle_fight_submenu_box.visible = false
	battle_panel.add_child(battle_fight_submenu_box)
	for action in [
		["Attack", "attack", "A standard attack with your equipped weapon. Free."],
		["Heavy Attack", "heavy", "A powerful strike. Costs %d stamina." % WeaponsScript.HEAVY_STAMINA_COST],
		["Special 1", "special_0", ""],
		["Special 2", "special_1", ""],
		["Special 3", "special_2", ""],
		["Mine", "mine", "Break apart a rock or rubble tile next to you. Free."],
		["Back", "back", "Return to the main menu."],
	]:
		var button := Button.new()
		button.text = action[0]
		button.pressed.connect(func(): battle_fight_action.emit(action[1]))
		_setup_hover_button(button, action[2], battle_description_label)
		_style_standard_button(button)
		battle_fight_submenu_box.add_child(button)
		battle_fight_buttons[action[1]] = button

	battle_tactics_submenu_box = HBoxContainer.new()
	battle_tactics_submenu_box.position = Vector2(20, 425)
	battle_tactics_submenu_box.add_theme_constant_override("separation", 8)
	battle_tactics_submenu_box.visible = false
	battle_panel.add_child(battle_tactics_submenu_box)
	for action in [
		["Taunt", "taunt", "Force every enemy's attention onto you this turn -- also reduces damage taken, same as Defend."],
		["Stealth", "stealth", "Vanish for a few turns: unaware enemies can't target you. Your next attack is a guaranteed crit."],
		["Back", "back", "Return to the main menu."],
	]:
		var button := Button.new()
		button.text = action[0]
		button.pressed.connect(func(): battle_tactics_action.emit(action[1]))
		_setup_hover_button(button, action[2], battle_description_label)
		_style_standard_button(button)
		battle_tactics_submenu_box.add_child(button)
		battle_tactics_buttons[action[1]] = button

	battle_move_submenu_box = HBoxContainer.new()
	battle_move_submenu_box.position = Vector2(20, 425)
	battle_move_submenu_box.add_theme_constant_override("separation", 8)
	battle_move_submenu_box.visible = false
	battle_panel.add_child(battle_move_submenu_box)
	for action in [
		["Confirm (Z)", "confirm", "Lock in your current position."],
		["Cancel (X)", "cancel", "Undo this move -- back to where you started, no harm done."],
	]:
		var button := Button.new()
		button.text = action[0]
		button.pressed.connect(func(): battle_move_action.emit(action[1]))
		# Arrows are exclusively grid movement in this menu, so these two
		# don't take keyboard focus -- mouse hover still highlights them.
		_setup_hover_button(button, action[2], battle_description_label, false)
		_style_standard_button(button)
		battle_move_submenu_box.add_child(button)
		battle_move_buttons[action[1]] = button

	# Phantom Guard's evasion reposition: shown mid-"enemy" turn, while the
	# attacker that just missed is paused waiting on the player -- same
	# Confirm-only shape as Move's submenu (arrows freely reposition, no
	# Cancel since there's nothing to undo about a dodge that already
	# happened). See update_battle_grid's is_evasion_prompt param for why
	# this box's visibility isn't gated behind is_player_turn like the rest.
	battle_evasion_submenu_box = HBoxContainer.new()
	battle_evasion_submenu_box.position = Vector2(20, 425)
	battle_evasion_submenu_box.add_theme_constant_override("separation", 8)
	battle_evasion_submenu_box.visible = false
	battle_panel.add_child(battle_evasion_submenu_box)
	var evasion_confirm_button := Button.new()
	evasion_confirm_button.text = "Confirm (Z)"
	evasion_confirm_button.pressed.connect(func(): battle_evasion_confirm_pressed.emit())
	_setup_hover_button(evasion_confirm_button, "Lock in your reposition and let the attack resolve.", battle_description_label, false)
	_style_standard_button(evasion_confirm_button)
	battle_evasion_submenu_box.add_child(evasion_confirm_button)

	# Arrow submenu -- only ever reachable while the Bow is equipped (see
	# update_battle_grid's arrow-button visibility gate), same shape as the
	# Fight submenu: one button per option plus Back. Text/disabled state is
	# refreshed every update_battle_grid call from the live owned_arrows
	# count, same as the Fight submenu's specials.
	battle_arrow_submenu_box = HBoxContainer.new()
	battle_arrow_submenu_box.position = Vector2(20, 425)
	battle_arrow_submenu_box.add_theme_constant_override("separation", 8)
	battle_arrow_submenu_box.visible = false
	battle_panel.add_child(battle_arrow_submenu_box)
	for action in [
		["Flame", "flame", ""],
		["Freeze", "freeze", ""],
		["Bomb", "bomb", ""],
		["Back", "back", "Return to the main menu."],
	]:
		var button := Button.new()
		button.text = action[0]
		button.pressed.connect(func(): battle_arrow_action.emit(action[1]))
		_setup_hover_button(button, action[2], battle_description_label)
		_style_standard_button(button)
		battle_arrow_submenu_box.add_child(button)
		battle_arrow_buttons[action[1]] = button

# Wires up the shared hover/focus behavior every clickable menu button uses
# across the whole HUD: a yellow highlight and a description shown in
# whichever label belongs to that screen, for both mouse hover and (when
# keyboard_focusable) keyboard focus navigation via the arrow keys, which
# Godot's Control focus system handles natively.
func _setup_hover_button(button: Button, description: String, description_label: Label, keyboard_focusable: bool = true) -> void:
	button.focus_mode = Control.FOCUS_ALL if keyboard_focusable else Control.FOCUS_NONE
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.2))
	button.add_theme_color_override("font_focus_color", Color(1.0, 0.9, 0.2))
	button.set_meta("description", description)
	button.mouse_entered.connect(func(): description_label.text = button.get_meta("description", ""))
	button.mouse_exited.connect(func(): description_label.text = "")
	button.focus_entered.connect(func(): description_label.text = button.get_meta("description", ""))
	button.focus_exited.connect(func(): description_label.text = "")

# The other half of _setup_hover_button's job -- yellow hover/focus text --
# for a button on a screen with no dedicated description_label to write
# into (pause menu, settings, game-over, event Yes/No), so it still feels
# alive on hover instead of a dead stock-grey Godot Button.
func _add_hover_color(button: Button) -> void:
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.2))
	button.add_theme_color_override("font_focus_color", Color(1.0, 0.9, 0.2))

# Volume sliders + one rebindable row per Settings.ACTION_ORDER entry -- each
# row's button doubles as both the live reference display (it always shows
# the currently-bound key) and the rebind entry point (clicking it starts
# capture; see _input()).
func _build_settings_panel() -> void:
	settings_panel = ColorRect.new()
	settings_panel.color = Color(0.05, 0.05, 0.07, 1.0)
	settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_panel.visible = false
	add_child(settings_panel)
	_framed_panel(Vector2(8, 8), get_viewport().get_visible_rect().size - Vector2(16, 16), settings_panel)

	var title_label := Label.new()
	title_label.position = Vector2(280, 30)
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.text = "SETTINGS"
	settings_panel.add_child(title_label)

	var volume_rows := [
		["Master Volume", "master"],
		["SFX Volume", "sfx"],
		["Music Volume", "music"],
	]
	for i in volume_rows.size():
		var row_label := Label.new()
		row_label.position = Vector2(60, 80 + i * 34)
		row_label.text = volume_rows[i][0]
		settings_panel.add_child(row_label)

		var slider := HSlider.new()
		slider.position = Vector2(250, 80 + i * 34)
		slider.size = Vector2(240, 20)
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = 1.0
		# Same dark-groove/yellow-fill look the rest of the game's bars use,
		# instead of the stock grey Godot slider -- the round grabber icon
		# itself is left as the theme default, just recolored track/fill.
		slider.add_theme_stylebox_override("slider", _make_stylebox(Color(0.13, 0.13, 0.15, 0.92), Color(0.45, 0.45, 0.48, 0.9), 1, 0, 0))
		slider.add_theme_stylebox_override("grabber_area", _make_stylebox(Color(0.85, 0.7, 0.15, 0.95), Color(0.45, 0.45, 0.48, 0.9), 1, 0, 0))
		slider.add_theme_stylebox_override("grabber_area_highlight", _make_stylebox(Color(1.0, 0.9, 0.2, 1.0), Color(1.0, 0.9, 0.2), 1, 0, 0))
		settings_panel.add_child(slider)

		var value_label := Label.new()
		value_label.position = Vector2(500, 80 + i * 34)
		value_label.text = "100%"
		settings_panel.add_child(value_label)

		match volume_rows[i][1]:
			"master":
				settings_master_slider = slider
				settings_master_value_label = value_label
				slider.value_changed.connect(func(v): settings_node.set_master_volume(v); value_label.text = "%d%%" % [roundi(v * 100)])
			"sfx":
				settings_sfx_slider = slider
				settings_sfx_value_label = value_label
				slider.value_changed.connect(func(v): settings_node.set_sfx_volume(v); value_label.text = "%d%%" % [roundi(v * 100)])
			"music":
				settings_music_slider = slider
				settings_music_value_label = value_label
				slider.value_changed.connect(func(v): settings_node.set_music_volume(v); value_label.text = "%d%%" % [roundi(v * 100)])

	# Accessibility/comfort toggles -- gated at the source in Main.gd
	# (_shake_camera/_shake_battle, spawn_damage_number_world/
	# _spawn_battle_damage_number), so flipping these here immediately
	# affects every existing juice call site with no further wiring.
	var toggle_rows := [
		["Screen Shake", "shake"],
		["Damage Numbers", "damage_numbers"],
	]
	for i in toggle_rows.size():
		var row_label := Label.new()
		row_label.position = Vector2(60, 190 + i * 32)
		row_label.text = toggle_rows[i][0]
		settings_panel.add_child(row_label)

		var checkbox := CheckButton.new()
		checkbox.position = Vector2(250, 186 + i * 32)
		checkbox.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		checkbox.add_theme_icon_override("on", TOGGLE_ON_ICON)
		checkbox.add_theme_icon_override("off", TOGGLE_OFF_ICON)
		checkbox.add_theme_icon_override("on_disabled", TOGGLE_ON_ICON)
		checkbox.add_theme_icon_override("off_disabled", TOGGLE_OFF_ICON)
		settings_panel.add_child(checkbox)

		match toggle_rows[i][1]:
			"shake":
				settings_shake_checkbox = checkbox
				checkbox.toggled.connect(func(v): settings_node.set_screen_shake_enabled(v))
			"damage_numbers":
				settings_damage_numbers_checkbox = checkbox
				checkbox.toggled.connect(func(v): settings_node.set_damage_numbers_enabled(v))

	var controls_label := Label.new()
	controls_label.position = Vector2(60, 262)
	controls_label.add_theme_font_size_override("font_size", 18)
	controls_label.text = "Controls"
	settings_panel.add_child(controls_label)

	var controls_scroll := ScrollContainer.new()
	controls_scroll.position = Vector2(60, 292)
	controls_scroll.custom_minimum_size = Vector2(680, 260)
	controls_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	settings_panel.add_child(controls_scroll)

	var controls_box := VBoxContainer.new()
	controls_box.add_theme_constant_override("separation", 6)
	controls_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_scroll.add_child(controls_box)

	for action in settings_node.ACTION_ORDER:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		controls_box.add_child(row)

		var action_label := Label.new()
		action_label.custom_minimum_size = Vector2(220, 0)
		action_label.text = settings_node.ACTION_LABELS.get(action, action)
		row.add_child(action_label)

		var rebind_button := Button.new()
		rebind_button.custom_minimum_size = Vector2(160, 0)
		rebind_button.pressed.connect(func():
			_cancel_rebind()
			rebinding_action = action
			rebind_button.text = "Press any key..."
		)
		_style_standard_button(rebind_button, 6)
		_add_hover_color(rebind_button)
		row.add_child(rebind_button)
		settings_rebind_buttons[action] = rebind_button

	settings_back_button = Button.new()
	settings_back_button.position = Vector2(300, 570)
	settings_back_button.custom_minimum_size = Vector2(160, 36)
	settings_back_button.text = "Back"
	settings_back_button.pressed.connect(func(): settings_back_pressed.emit())
	_style_standard_button(settings_back_button)
	_add_hover_color(settings_back_button)
	settings_panel.add_child(settings_back_button)

# Swaps which scroll container is visible; both stay populated underneath so
# switching tabs back and forth never needs a rebuild, just a visibility
# flip. The two toggle buttons are kept in sync (exactly one pressed) since
# Godot doesn't have a built-in radio-button-group for plain Buttons. tab is
# one of "gear"/"enchant".
func _select_shop_tab(tab: String) -> void:
	shop_row_scroll.visible = tab == "gear"
	shop_enchant_scroll.visible = tab == "enchant"
	shop_gear_tab_button.button_pressed = tab == "gear"
	shop_enchant_tab_button.button_pressed = tab == "enchant"
	shop_description_label.text = ""

func _style_shop_tab_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _make_stylebox(Color(0.13, 0.12, 0.15, 0.92), PANEL_BORDER, 2, 0, 8))
	button.add_theme_stylebox_override("hover", _make_stylebox(Color(0.2, 0.19, 0.13, 0.96), Color(1.0, 0.9, 0.2), 2, 0, 8))
	button.add_theme_stylebox_override("pressed", _make_stylebox(Color(0.22, 0.18, 0.05, 0.95), Color(1.0, 0.85, 0.2, 1.0), 2, 0, 8))
	button.add_theme_stylebox_override("disabled", _make_stylebox(Color(0.08, 0.08, 0.09, 0.6), Color(0.25, 0.25, 0.25, 0.6), 2, 0, 8))
	button.add_theme_stylebox_override("focus", _make_stylebox(Color(0, 0, 0, 0), Color(1.0, 0.9, 0.2), 2, 0, 8))

# Flat rectangular panel with no rounded corners or anti-aliasing, so edges
# stay crisp like the rest of the game's NEAREST-filtered pixel art.
func _make_stylebox(bg: Color, border: Color, border_width: int, corner_radius: int, content_margin: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(corner_radius)
	sb.anti_aliasing = false
	sb.set_content_margin_all(content_margin)
	return sb

# The shop's bordered "window" card, generalized into a decorative backdrop
# any dialog-style overlay (pause menu, level-up, event, game-over) can drop
# behind its own existing content -- added as the FIRST child of that
# overlay's scrim ColorRect so it renders behind everything already
# positioned there, without reparenting a single existing label/button (all
# of which are positioned in coordinates relative to that same scrim, and
# would need repositioning if they moved to a new parent). Purely
# decorative: MOUSE_FILTER_IGNORE so it never steals a click meant for
# whatever's drawn on top of it.
func _framed_panel(rect_position: Vector2, rect_size: Vector2, parent: Control) -> Panel:
	var panel := Panel.new()
	panel.position = rect_position
	panel.size = rect_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _make_stylebox(PANEL_BG, PANEL_BORDER, 3, 0, 0))
	parent.add_child(panel)
	parent.move_child(panel, 0)
	return panel

# General-purpose "card" look for any plain action button that isn't a shop
# row/skill node (those get their own tinted variants above/in TitleScreen.gd)
# -- bronze-border/yellow-hover/gold-pressed recipe matching PANEL_BORDER
# (the same bronze the window frames use) and TitleScreen.gd's
# _style_skill_node_button, so every menu in the game -- battle actions,
# level-up, settings, pause, game-over, title screen -- shares one real
# look instead of half of them defaulting to a flatter neutral grey.
func _style_standard_button(button: Button, content_margin: int = 10) -> void:
	button.add_theme_stylebox_override("normal", _make_stylebox(Color(0.13, 0.12, 0.15, 0.92), PANEL_BORDER, 2, 0, content_margin))
	button.add_theme_stylebox_override("hover", _make_stylebox(Color(0.2, 0.19, 0.13, 0.96), Color(1.0, 0.9, 0.2), 2, 0, content_margin))
	button.add_theme_stylebox_override("pressed", _make_stylebox(Color(0.16, 0.15, 0.1, 0.96), Color(1.0, 0.9, 0.2), 2, 0, content_margin))
	button.add_theme_stylebox_override("disabled", _make_stylebox(Color(0.08, 0.08, 0.09, 0.6), Color(0.25, 0.25, 0.25, 0.6), 2, 0, content_margin))
	button.add_theme_stylebox_override("focus", _make_stylebox(Color(0, 0, 0, 0), Color(1.0, 0.9, 0.2), 2, 0, content_margin))

# Card-styled buy button for a shop row: a category-tinted border (weapon/
# armor/potion) so the offering reads at a glance, plus a real hover/disabled
# look instead of the stock grey Godot button. A Mythic roll (the ~0.5%
# jackpot weapon tier) overrides the category accent entirely with a bright
# gold treatment and a thicker border, so it visibly doesn't belong next to
# the normal rows -- the rarity should be obvious before you even read it.
func _style_shop_row_button(button: Button, category: String, tier_name: String = "") -> void:
	if tier_name == "Mythic":
		button.add_theme_stylebox_override("normal", _make_stylebox(Color(0.22, 0.18, 0.05, 0.95), Color(1.0, 0.85, 0.2, 1.0), 3, 0, 12))
		button.add_theme_stylebox_override("hover", _make_stylebox(Color(0.34, 0.27, 0.06, 0.98), Color(1.0, 0.95, 0.55, 1.0), 3, 0, 12))
		button.add_theme_stylebox_override("pressed", _make_stylebox(Color(0.28, 0.22, 0.05, 0.98), Color(1.0, 0.95, 0.55, 1.0), 3, 0, 12))
		button.add_theme_stylebox_override("disabled", _make_stylebox(Color(0.1, 0.09, 0.05, 0.6), Color(0.5, 0.42, 0.15, 0.6), 3, 0, 12))
		button.add_theme_stylebox_override("focus", _make_stylebox(Color(0, 0, 0, 0), Color(1.0, 0.95, 0.55, 1.0), 3, 0, 12))
	else:
		var accent: Color = SHOP_CATEGORY_COLOR.get(category, Color(0.6, 0.6, 0.6))
		button.add_theme_stylebox_override("normal", _make_stylebox(Color(0.15, 0.14, 0.18, 0.92), accent.lerp(Color.BLACK, 0.35), 2, 0, 12))
		button.add_theme_stylebox_override("hover", _make_stylebox(Color(0.24, 0.2, 0.12, 0.96), Color(1.0, 0.9, 0.2), 2, 0, 12))
		button.add_theme_stylebox_override("pressed", _make_stylebox(Color(0.2, 0.17, 0.1, 0.96), Color(1.0, 0.9, 0.2), 2, 0, 12))
		button.add_theme_stylebox_override("disabled", _make_stylebox(Color(0.08, 0.08, 0.09, 0.6), Color(0.25, 0.25, 0.25, 0.6), 2, 0, 12))
		button.add_theme_stylebox_override("focus", _make_stylebox(Color(0, 0, 0, 0), Color(1.0, 0.9, 0.2), 2, 0, 12))
	button.add_theme_constant_override("icon_max_width", 32)
	button.add_theme_constant_override("h_separation", 12)

# Reroll/Continue get the same card treatment, but Continue (the "go forward"
# action) is tinted green as the visually primary choice while Reroll (a
# secondary utility) stays neutral grey.
func _style_shop_action_button(button: Button, primary: bool) -> void:
	if primary:
		button.add_theme_stylebox_override("normal", _make_stylebox(Color(0.16, 0.26, 0.12, 0.95), Color(0.55, 0.75, 0.3), 2, 0, 10))
		button.add_theme_stylebox_override("hover", _make_stylebox(Color(0.22, 0.34, 0.15, 0.97), Color(0.75, 0.95, 0.4), 2, 0, 10))
		button.add_theme_stylebox_override("pressed", _make_stylebox(Color(0.12, 0.2, 0.09, 0.97), Color(0.75, 0.95, 0.4), 2, 0, 10))
	else:
		button.add_theme_stylebox_override("normal", _make_stylebox(Color(0.13, 0.12, 0.15, 0.92), PANEL_BORDER, 2, 0, 10))
		button.add_theme_stylebox_override("hover", _make_stylebox(Color(0.2, 0.19, 0.13, 0.96), Color(1.0, 0.9, 0.2), 2, 0, 10))
		button.add_theme_stylebox_override("pressed", _make_stylebox(Color(0.16, 0.15, 0.1, 0.96), Color(1.0, 0.9, 0.2), 2, 0, 10))
	button.add_theme_stylebox_override("disabled", _make_stylebox(Color(0.08, 0.08, 0.09, 0.6), Color(0.25, 0.25, 0.25, 0.6), 2, 0, 10))
	button.add_theme_stylebox_override("focus", _make_stylebox(Color(0, 0, 0, 0), Color(1.0, 0.9, 0.2), 2, 0, 10))

func update_health(current: int, max_health: int) -> void:
	health_label.text = "HP: %d / %d" % [current, max_health]
	var ratio: float = clampf(float(current) / float(max(1, max_health)), 0.0, 1.0)
	health_bar_fill.size = Vector2(health_bar_bg.size.x * ratio, health_bar_bg.size.y)

# Quiver only shows up while a Bow is equipped -- hovering it reveals the
# live held count of each arrow type via quiver_tooltip_label. The tooltip
# text is refreshed here (stored as meta, same lookup-on-hover shape
# _setup_hover_button uses elsewhere) rather than live every frame, since
# Main.gd only calls this at the few points owned_arrows/the equipped
# weapon can actually change (buy/sell in the shop, firing an arrow in
# battle, leaving either back to the overworld).
func update_quiver(has_bow: bool, owned_arrows: Dictionary) -> void:
	quiver_icon.visible = has_bow
	if not has_bow:
		quiver_tooltip_label.text = ""
		return
	var lines := []
	for kind in ["flame", "freeze", "bomb"]:
		var info: Dictionary = WeaponsScript.ARROW_TYPES[kind]
		lines.append("%s: %d" % [info.name, owned_arrows.get(kind, 0)])
	quiver_icon.set_meta("tooltip", "\n".join(lines))

func update_enemies(count: int) -> void:
	enemies_label.text = "Enemies remaining: %d" % count

func update_wave(wave: int) -> void:
	wave_label.text = "Wave: %d" % wave

func update_world(text: String) -> void:
	world_label.text = text

func update_level(level: int) -> void:
	level_label.text = "Level: %d" % level

func update_xp(current: int, needed: int) -> void:
	if needed <= 0:
		xp_label.text = "XP: MAX LEVEL"
	else:
		xp_label.text = "XP: %d / %d" % [current, needed]

func update_stats(intimidation: int, strength: int, vigor: int, agility: int, might: int) -> void:
	# stat_agility is a real move-speed value in pixels/sec (starts at 180),
	# wildly out of scale next to the other stats' small whole numbers --
	# shown here as a small rating instead (starts at 5, +1 per full
	# AGILITY_BONUS_PER_LEVEL gained) purely for display. The real
	# stat_agility driving movement/attack cooldown is untouched.
	var speed_display: int = 5 + int(agility - PlayerScript.AGILITY_START) / PlayerScript.AGILITY_BONUS_PER_LEVEL
	stats_label.text = "INT %d   STR %d   VIG %d   AGI %d   MGT %d" % [intimidation, strength, vigor, speed_display, might]

func update_items(count: int) -> void:
	items_label.text = "Items: %d" % count

func show_message(text: String) -> void:
	message_label.text = text

func show_game_over(essence_earned: int, total_essence: int, stats: Dictionary = {}) -> void:
	game_over_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	game_over_label.text = "You died!"
	_populate_game_over_stats(essence_earned, total_essence, stats)
	game_over_panel.visible = true
	game_over_return_button.grab_focus()

# Reuses the same panel/label/button as show_game_over (the run ends and
# resets the same permadeath way either way) -- just framed as a win, gold
# instead of red, and calling out the one-time Worldwalker unlock.
func show_victory(essence_earned: int, total_essence: int, stats: Dictionary = {}) -> void:
	game_over_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	game_over_label.text = "You have conquered the Nothingness!\n\nWorldwalker is now unlocked in the skill tree."
	_populate_game_over_stats(essence_earned, total_essence, stats)
	game_over_panel.visible = true
	game_over_return_button.grab_focus()

# Shared run-recap body for show_game_over/show_victory -- a scrollable list
# of rows (same "clear and rebuild" idiom as show_shop's offering list)
# rather than fixed labels, since the per-enemy kill breakdown is
# variable-length. stats is Main.gd's _run_stats_summary() dict; defaults to
# {} so a caller without a real run (none currently) still renders cleanly.
func _populate_game_over_stats(essence_earned: int, total_essence: int, stats: Dictionary) -> void:
	for c in game_over_stats_box.get_children():
		c.queue_free()

	var summary_lines := [
		"This run earned %d Essence. (Total: %d)" % [essence_earned, total_essence],
		"Waves cleared: %d" % stats.get("waves_cleared", 0),
		"World reached: %s" % stats.get("world_reached", "Plains"),
		"Bosses/minibosses defeated: %d" % stats.get("bosses_defeated", 0),
		"Damage dealt: %d" % stats.get("damage_dealt", 0),
		"Damage taken: %d" % stats.get("damage_taken", 0),
	]
	for line in summary_lines:
		var row := Label.new()
		row.text = line
		row.add_theme_font_size_override("font_size", 15)
		row.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		game_over_stats_box.add_child(row)

	var kills_by_name: Dictionary = stats.get("kills_by_name", {})
	if not kills_by_name.is_empty():
		var kills_header := Label.new()
		kills_header.text = "Kills:"
		kills_header.add_theme_font_size_override("font_size", 15)
		kills_header.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
		game_over_stats_box.add_child(kills_header)

		var names: Array = kills_by_name.keys()
		# Most-killed first -- ties broken alphabetically for a stable order.
		names.sort_custom(func(a, b):
			if kills_by_name[a] != kills_by_name[b]:
				return kills_by_name[a] > kills_by_name[b]
			return a < b
		)
		for enemy_name in names:
			var kill_row := Label.new()
			kill_row.text = "  %s x%d" % [enemy_name, kills_by_name[enemy_name]]
			kill_row.add_theme_font_size_override("font_size", 14)
			kill_row.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
			game_over_stats_box.add_child(kill_row)

# Rebuilt fresh every open (clear-and-rebuild, same idiom show_shop uses for
# its offering rows) -- the row list itself is dynamic: the 4 original stats
# plus Might are always shown, Resilience/Reflexes/Dexterity only once each
# is unlocked via its own skill-tree node. Main.gd:_levelup_choice_order()
# mirrors this exact same order for its number-key (1-8) shortcuts.
func show_levelup_choice(new_level: int, intimidation: int, strength: int, vigor: int, agility: int, might: int, resilience: int, reflexes: int, dexterity: int, resilience_unlocked: bool, reflexes_unlocked: bool, dexterity_unlocked: bool) -> void:
	levelup_label.text = "LEVEL UP! Now level %d\nAll stats +1. Choose ONE bonus +1:" % new_level
	for c in levelup_box.get_children():
		c.queue_free()
	levelup_buttons.clear()

	# Same display-only rating as update_stats -- the raw move-speed value
	# would look wildly out of scale next to the other stats here too.
	var speed_display: int = 5 + int(agility - PlayerScript.AGILITY_START) / PlayerScript.AGILITY_BONUS_PER_LEVEL
	var rows := [
		["intimidation", "Intimidation (%d)" % intimidation, "-1% shop prices per point (capped at -75%)."],
		["strength", "Strength (%d)" % strength, "+1 damage per point on every attack you land."],
		["vigor", "Vigor (%d)" % vigor, "+1 max HP per point."],
		["agility", "Agility (%d)" % speed_display, "+1 overworld speed per point, a faster attack cooldown, and +1 battle move tile every 20 points."],
		["might", "Might (%d)" % might, "Better weapons require higher Might to equip; boosts recruited party/wolf damage."],
	]
	if resilience_unlocked:
		rows.append(["resilience", "Resilience (%d)" % resilience, "1% damage reduction per point, capped at 20%, stacking with armor."])
	if reflexes_unlocked:
		rows.append(["reflexes", "Reflexes (%d)" % reflexes, "0.75% dodge chance per point, capped at 15%."])
	if dexterity_unlocked:
		rows.append(["dexterity", "Dexterity (%d)" % dexterity, "0.75% crit chance per point (double damage, ignores cover), capped at 15%."])

	for i in rows.size():
		var row: Array = rows[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(320, 28)
		button.text = "[%d] %s" % [i + 1, row[1]]
		button.pressed.connect(func(): levelup_choice_pressed.emit(row[0]))
		_setup_hover_button(button, row[2], levelup_description_label)
		_style_standard_button(button)
		levelup_box.add_child(button)
		levelup_buttons[row[0]] = button

	levelup_panel.visible = true
	levelup_buttons["intimidation"].grab_focus()

func hide_levelup_choice() -> void:
	levelup_panel.visible = false

func show_event_choice(title: String, description: String, yes_label: String, no_label: String) -> void:
	event_label.text = title
	event_description_label.text = description
	event_yes_button.text = yes_label
	event_no_button.text = no_label
	event_panel.visible = true
	event_yes_button.grab_focus()

func hide_event_choice() -> void:
	event_panel.visible = false

func show_menu() -> void:
	menu_panel.visible = true

func hide_menu() -> void:
	menu_panel.visible = false

func show_settings() -> void:
	menu_panel.visible = false
	settings_panel.visible = true
	_refresh_settings_display()

func hide_settings() -> void:
	_cancel_rebind()
	settings_panel.visible = false
	menu_panel.visible = true

func _refresh_settings_display() -> void:
	settings_master_slider.value = settings_node.master_volume
	settings_sfx_slider.value = settings_node.sfx_volume
	settings_music_slider.value = settings_node.music_volume
	settings_master_value_label.text = "%d%%" % [roundi(settings_node.master_volume * 100)]
	settings_sfx_value_label.text = "%d%%" % [roundi(settings_node.sfx_volume * 100)]
	settings_music_value_label.text = "%d%%" % [roundi(settings_node.music_volume * 100)]
	settings_shake_checkbox.button_pressed = settings_node.screen_shake_enabled
	settings_damage_numbers_checkbox.button_pressed = settings_node.damage_numbers_enabled
	for action in settings_node.ACTION_ORDER:
		settings_rebind_buttons[action].text = settings_node.key_name(action)

func _cancel_rebind() -> void:
	if rebinding_action != "":
		settings_rebind_buttons[rebinding_action].text = settings_node.key_name(rebinding_action)
		rebinding_action = ""

func _input(event: InputEvent) -> void:
	if rebinding_action == "" or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	if event.keycode == KEY_ESCAPE:
		_cancel_rebind()
		return
	settings_node.rebind(rebinding_action, event.keycode)
	rebinding_action = ""
	_refresh_settings_display()

func update_coins(amount: int) -> void:
	coins_label.text = "Coins: %d" % amount

func show_shop(coins: int, runic_shards: int, offering: Array, prices: Array, current_weapon_name: String, owned_weapons: Dictionary, current_armor_name: String, potion_count: int, reroll_cost: int, is_bow_equipped: bool = false, owned_arrows: Dictionary = {}, arrow_prices: Dictionary = {}, arrow_cap: int = WeaponsScript.ARROW_MAX_HELD, current_shield_name: String = "None", owned_shields: Dictionary = {}, player_might: int = 0) -> void:
	for n in shop_row_nodes:
		n.queue_free()
	shop_row_nodes.clear()

	shop_coins_label.text = str(coins)
	shop_shards_label.text = str(runic_shards)
	shop_weapon_tag.text = "Weapon: %s" % current_weapon_name
	shop_armor_tag.text = "Armor: %s" % current_armor_name
	shop_shield_tag.text = "Shield: %s" % current_shield_name
	shop_potions_tag.text = "Potions: %d" % potion_count

	for i in offering.size():
		var item: Dictionary = offering[i]
		var already_owned: bool = (item.category == "weapon" and owned_weapons.has(item.id)) or (item.category == "shield" and owned_shields.has(item.id))
		var tier_name: String = item.get("tier_name", "")
		var is_mythic: bool = tier_name == "Mythic"
		var is_locked: bool = item.get("locked", false)
		# Only a rolled (non-Club) weapon offer is ever lockable -- armor and
		# potions are already deterministic every reroll (Main.gd:
		# _roll_shop_offering always regenerates the same next-armor-tier/
		# full-potion-list), so there's nothing for a lock to protect there.
		var is_lockable: bool = item.category == "weapon" and item.id != "club" and not already_owned
		# Might gate: Masterwork/Legendary/Mythic (Weapons.gd:required_might)
		# render locked, same visual treatment as an unaffordable item, until
		# the player's Might stat meets the requirement -- see Player.gd:
		# try_buy_weapon for the matching server-side block.
		var required_might: int = int(item.get("required_might", 0))
		var might_locked: bool = item.category == "weapon" and required_might > player_might

		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 52)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.icon = load("res://assets/weapon_%s.png" % item.icon if item.category == "weapon" else "res://assets/%s.png" % item.icon)
		button.expand_icon = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "[%d] %s%s%s" % [i + 1, "🔒 " if is_locked else "", "★ " if is_mythic else "", item.name]
		button.disabled = (not already_owned and coins < prices[i]) or might_locked
		button.pressed.connect(func(): shop_buy_pressed.emit(i))
		var description: String = item.description + " This shouldn't even be possible." if is_mythic else item.description
		if might_locked:
			description += " Requires %d Might (you have %d)." % [required_might, player_might]
		_setup_hover_button(button, description, shop_description_label)
		_style_shop_row_button(button, item.category, tier_name)

		# A single overlay label docked to the button's right edge -- the rest
		# of the row (icon + name) stays native Button drawing, so click/
		# hover/focus/disabled behavior is untouched.
		var price_label := Label.new()
		price_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		price_label.offset_left = -90
		price_label.offset_right = -12
		price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		price_label.text = ("MGT %d" % required_might) if might_locked else ("OWNED" if already_owned else "%d" % prices[i])
		price_label.add_theme_font_size_override("font_size", 15)
		price_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4) if might_locked else (Color(0.55, 0.85, 0.4) if already_owned else Color(1, 0.85, 0.3)))
		button.add_child(price_label)

		if is_lockable and not is_locked:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			row.add_child(button)

			var lock_button := Button.new()
			lock_button.custom_minimum_size = Vector2(96, 52)
			lock_button.text = "Lock (%dg)" % SHOP_LOCK_COST
			lock_button.disabled = coins < SHOP_LOCK_COST
			lock_button.pressed.connect(func(): shop_lock_pressed.emit(i))
			_setup_hover_button(lock_button, "Protect this offer from being rerolled away, for %d gold." % SHOP_LOCK_COST, shop_description_label)
			_style_shop_row_button(lock_button, item.category, tier_name)
			row.add_child(lock_button)

			shop_row_box.add_child(row)
			shop_row_nodes.append(row)
		else:
			shop_row_box.add_child(button)
			shop_row_nodes.append(button)

	# Special arrows: only reachable while the Bow is equipped, appended
	# after the rolled offering rather than living in their own tab -- a
	# fixed 3-row catalog (flame/freeze/bomb), not something that reroll
	# ever touches. Each row is a Buy button (shows held count, price
	# scales with how many are already held -- see Player.gd:
	# get_arrow_price) plus a flat-rate Sell button.
	if is_bow_equipped:
		for kind in ["flame", "freeze", "bomb"]:
			var info: Dictionary = WeaponsScript.ARROW_TYPES[kind]
			var held: int = owned_arrows.get(kind, 0)
			var price: int = arrow_prices.get(kind, 0)
			var at_cap: bool = held >= arrow_cap

			var arrow_row := HBoxContainer.new()
			arrow_row.add_theme_constant_override("separation", 8)

			var buy_button := Button.new()
			buy_button.custom_minimum_size = Vector2(0, 52)
			buy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			buy_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			buy_button.text = "%s (held: %d)" % [info.name, held]
			buy_button.disabled = at_cap or coins < price
			buy_button.pressed.connect(func(): arrow_buy_pressed.emit(kind))
			_setup_hover_button(buy_button, info.description, shop_description_label)
			_style_shop_row_button(buy_button, "arrow")
			arrow_row.add_child(buy_button)

			var arrow_price_label := Label.new()
			arrow_price_label.set_anchors_preset(Control.PRESET_FULL_RECT)
			arrow_price_label.offset_left = -70
			arrow_price_label.offset_right = -12
			arrow_price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			arrow_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			arrow_price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			arrow_price_label.text = "MAX" if at_cap else "%d" % price
			arrow_price_label.add_theme_font_size_override("font_size", 15)
			arrow_price_label.add_theme_color_override("font_color", Color(0.55, 0.85, 0.4) if at_cap else Color(1, 0.85, 0.3))
			buy_button.add_child(arrow_price_label)

			var sell_button := Button.new()
			sell_button.custom_minimum_size = Vector2(96, 52)
			sell_button.text = "Sell (+%d)" % WeaponsScript.ARROW_SELL_PRICE
			sell_button.disabled = held <= 0
			sell_button.pressed.connect(func(): arrow_sell_pressed.emit(kind))
			_setup_hover_button(sell_button, "Sell one %s for %d coins." % [info.name, WeaponsScript.ARROW_SELL_PRICE], shop_description_label)
			_style_shop_row_button(sell_button, "arrow")
			arrow_row.add_child(sell_button)

			shop_row_box.add_child(arrow_row)
			shop_row_nodes.append(arrow_row)

	shop_reroll_button.text = "Reroll (%d)" % reroll_cost
	shop_reroll_button.disabled = coins < reroll_cost
	shop_panel.visible = true
	if shop_row_box.get_child_count() > 0:
		var first_row: Control = shop_row_box.get_child(0)
		if first_row is Button:
			first_row.grab_focus()
		elif first_row.get_child_count() > 0:
			first_row.get_child(0).grab_focus()

func hide_shop() -> void:
	shop_panel.visible = false

# Runes are a fixed catalog (not rolled), always targeting whatever weapon is
# currently equipped -- see Player.gd:try_apply_enchantment for why there's
# no weapon-picker. applied_rune_id is "" if the current weapon has none yet.
func show_enchant_tab(coins: int, runic_shards: int, current_weapon_name: String, current_weapon_id: String, applied_rune_id: String, runes: Array) -> void:
	for n in shop_enchant_row_nodes:
		n.queue_free()
	shop_enchant_row_nodes.clear()

	var can_enchant: bool = current_weapon_id != "" and current_weapon_id != "club" and applied_rune_id == ""
	if current_weapon_id == "club":
		shop_enchant_weapon_label.text = "Equip a real weapon before enchanting it."
	elif applied_rune_id != "":
		shop_enchant_weapon_label.text = "%s already bears an enchantment." % current_weapon_name
	else:
		shop_enchant_weapon_label.text = "Enchanting: %s" % current_weapon_name

	for rune in runes:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 52)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = rune.name
		var affordable: bool = coins >= rune.cost_coins and runic_shards >= rune.cost_shards
		button.disabled = not can_enchant or not affordable
		var rune_id: String = rune.id
		button.pressed.connect(func(): enchant_apply_pressed.emit(rune_id))
		_setup_hover_button(button, rune.description, shop_description_label)
		_style_shop_row_button(button, "enchant")
		shop_enchant_row_box.add_child(button)

		var cost_label := Label.new()
		cost_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		cost_label.offset_left = -130
		cost_label.offset_right = -12
		cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost_label.text = "%d + %d" % [rune.cost_shards, rune.cost_coins]
		cost_label.add_theme_font_size_override("font_size", 15)
		cost_label.add_theme_color_override("font_color", Color(0.75, 0.55, 1.0) if affordable else Color(0.6, 0.6, 0.6))
		button.add_child(cost_label)

		shop_enchant_row_nodes.append(button)

func show_battle(background_color: Color = Color(0.05, 0.05, 0.05)) -> void:
	battle_log_lines.clear()
	battle_panel.color = background_color
	battle_log_label.text = ""
	battle_panel.modulate.a = 0.0
	battle_panel.visible = true
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(battle_panel, "modulate:a", 1.0, 0.4)

# Hover-LOS overlay -- see enemy_hovered/enemy_unhovered and
# Main.gd:_on_enemy_hovered/_on_enemy_unhovered.
func show_sight_tiles(tiles: Array) -> void:
	hide_sight_tiles()
	for i in min(tiles.size(), battle_sight_tile_rects.size()):
		var tile: Vector2i = tiles[i]
		var rect: ColorRect = battle_sight_tile_rects[i]
		rect.position = battle_grid_origin + Vector2(tile.x, tile.y) * battle_tile_size
		rect.size = Vector2(battle_tile_size, battle_tile_size)
		rect.visible = true

func hide_sight_tiles() -> void:
	for rect in battle_sight_tile_rects:
		rect.visible = false

func update_battle_grid(grid_w: int, grid_h: int, terrain: Dictionary, player_tile: Vector2i, units: Array, player_hp: int, player_max_hp: int, player_level: int, turn: String, target_index: int, moves_left: int, stamina: int, max_stamina: int, current_weapon: Dictionary, menu_state: String, healing_items: int, move_trail: Array, allies: Array, has_guardian_skill: bool, skill_cooldown: int, is_disarmed: bool = false, owned_arrows: Dictionary = {}, is_evasion_prompt: bool = false, can_mine: bool = false, shield_name: String = "", shield_block_pct: float = 0.0, berserk_turns: int = 0, stealth_turns: int = 0, stealth_cost: int = 0) -> void:
	# The grid always renders within the same on-screen footprint regardless
	# of size (a boss fight's bigger grid_w/grid_h -- see
	# Main.gd:BOSS_BATTLE_GRID_SIZE -- just packs in smaller tiles) rather
	# than growing past the fixed-position log/menu UI around it.
	battle_tile_size = BATTLE_GRID_FOOTPRINT_PX / float(grid_w)

	for t in battle_tile_rects:
		var rect: ColorRect = battle_tile_rects[t]
		var icon: TextureRect = battle_tile_icons[t]
		var marker: Label = battle_tile_markers[t]
		if t.x >= grid_w or t.y >= grid_h:
			# Pooled for the max possible grid size but unused by this
			# battle -- hide rather than render past the current bounds.
			rect.visible = false
			icon.visible = false
			marker.visible = false
			continue
		rect.visible = true
		icon.visible = true
		rect.position = battle_grid_origin + Vector2(t.x, t.y) * battle_tile_size
		# rect fills the full cell (no gap, no battle_panel background
		# bleeding through); icon insets by exactly 1px so a thin single-
		# pixel barrier of rect's dark color shows between tiles instead of
		# either a thick gridline or none at all.
		rect.size = Vector2(battle_tile_size, battle_tile_size)
		icon.position = rect.position
		icon.size = Vector2(battle_tile_size - 1, battle_tile_size - 1)
		icon.pivot_offset = icon.size / 2.0
		marker.position = rect.position + Vector2(4, 0)
		var terrain_data = terrain.get(t, null)
		marker.visible = false
		icon.rotation = 0.0
		if terrain_data == null:
			icon.texture = grass_animated_texture
		elif terrain_data.type == "water":
			icon.texture = water_animated_texture
			# Unlike Cliff/Ledge, Water's source frames aren't a static
			# silhouette -- cross-checking the raw GIF frames shows the
			# droplets natively drift UP (toward push_dir's opposite) at 0
			# rotation, not down, so the current has to rotate against the
			# push direction for the visible flow to match push_dir instead
			# of running backwards against it.
			icon.rotation = _dir_rotation(-terrain_data.push_dir)
			marker.text = _dir_arrow(terrain_data.push_dir)
			marker.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
			marker.visible = true
		else:
			icon.texture = TERRAIN_TILE_ICONS[terrain_data.type]
			match terrain_data.type:
				"ledge":
					icon.rotation = _dir_rotation(terrain_data.dir)
					marker.text = _dir_arrow(terrain_data.dir)
					marker.add_theme_color_override("font_color", Color(1, 1, 0.6))
					marker.visible = true
				"cliff":
					icon.rotation = _dir_rotation(terrain_data.dir)
					marker.text = _dir_arrow(terrain_data.dir)
					marker.add_theme_color_override("font_color", Color(1, 0.5, 0.4))
					marker.visible = true

	player_marker.text = "@"
	player_marker.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	player_marker.position = battle_grid_origin + Vector2(player_tile.x, player_tile.y) * battle_tile_size + Vector2(battle_tile_size / 2.0 - 8, battle_tile_size / 2.0 - 14)
	player_marker.visible = true

	# Party members now have a real tile of their own (Main.gd:battle_allies)
	# -- rendered the same way as an enemy icon (tile origin + padding), plus
	# a small health bar under it. Traitor Wolf reuses the enemy Wolf icon;
	# any other ally (Blade Ally, Warrior) uses the shared companion icon.
	for i in battle_ally_icons.size():
		var ally_icon: TextureRect = battle_ally_icons[i]
		var hp_bg: ColorRect = battle_ally_hp_bg[i]
		var hp_fill: ColorRect = battle_ally_hp_fill[i]
		if i < allies.size():
			var a: Dictionary = allies[i]
			var a_tile_origin: Vector2 = battle_grid_origin + Vector2(a.tile.x, a.tile.y) * battle_tile_size
			var a_padding := 6.0
			ally_icon.texture = ENEMY_ICONS.get("Wolf", null) if a.name == "Traitor Wolf" else BLADE_ALLY_ICON
			ally_icon.position = a_tile_origin + Vector2(a_padding, a_padding)
			ally_icon.size = Vector2(battle_tile_size - a_padding * 2, battle_tile_size - a_padding * 2)
			ally_icon.visible = ally_icon.texture != null

			var bar_width: float = battle_tile_size - a_padding * 2
			var bar_height := 5.0
			var bar_pos: Vector2 = a_tile_origin + Vector2(a_padding, battle_tile_size - a_padding - bar_height)
			hp_bg.position = bar_pos
			hp_bg.size = Vector2(bar_width, bar_height)
			hp_bg.visible = true
			var hp_ratio: float = clampf(float(a.hp) / float(max(1, a.max_hp)), 0.0, 1.0)
			hp_fill.position = bar_pos
			hp_fill.size = Vector2(bar_width * hp_ratio, bar_height)
			hp_fill.visible = true
		else:
			ally_icon.visible = false
			hp_bg.visible = false
			hp_fill.visible = false

	for i in battle_unit_markers.size():
		battle_unit_markers[i].visible = false
		battle_unit_icons[i].visible = false
		battle_unit_aware_markers[i].visible = false

	# Live Gnome pack count -- units is battle_units itself, so counting
	# same-named entries here mirrors exactly what Main.gd's own live
	# damage-scaling check counts, no separate bookkeeping needed.
	var gnome_pack_count := 0
	for u in units:
		if u.name == "Gnome":
			gnome_pack_count += 1

	for i in units.size():
		var u: Dictionary = units[i]
		var marker: Label = battle_unit_markers[i]
		var icon: TextureButton = battle_unit_icons[i]
		var is_target: bool = i == target_index
		var is_winding_up: bool = u.get("winding_up", false)
		# A multi-tile unit (the Brute) is centered and sized over its whole
		# footprint instead of just its anchor tile.
		var size: int = u.get("size", 1)
		var footprint_span: float = battle_tile_size * size
		var tile_origin: Vector2 = battle_grid_origin + Vector2(u.tile.x, u.tile.y) * battle_tile_size

		var icon_padding := 6.0
		icon.texture_normal = ENEMY_ICONS.get(u.name, null)
		icon.position = tile_origin + Vector2(icon_padding, icon_padding)
		icon.size = Vector2(footprint_span - icon_padding * 2, footprint_span - icon_padding * 2)
		# A warm highlight on the sprite itself marks the current target,
		# rather than tinting it a flat color that'd wash out the art.
		icon.modulate = Color(1.3, 1.15, 0.6, 1.0) if is_target else Color(1, 1, 1, 1)
		icon.visible = icon.texture_normal != null

		# One shared badge slot per unit, same as the "!" windup marker --
		# priority order below picks whichever single status is most urgent
		# to surface; a unit rarely shows more than one of these at once.
		var is_buffed: bool = u.get("buffed_dmg_turns", 0) > 0
		var badge_text := ""
		var badge_color := Color(1.0, 0.55, 0.05)
		if is_winding_up:
			badge_text = "!"
		elif u.name == "Fae Hut":
			badge_text = str(FAE_HUT_SPAWN_INTERVAL - u.get("turns_since_spawn", 0))
			badge_color = Color(0.75, 0.4, 1.0)
		elif is_buffed:
			badge_text = "^"
			badge_color = Color(1.0, 0.85, 0.2)
		elif u.get("vulnerable_turns", 0) > 0:
			badge_text = "V"
			badge_color = Color(0.9, 0.2, 0.6)
		elif u.name == "Gnome" and gnome_pack_count > 1:
			badge_text = "x%d" % gnome_pack_count
			badge_color = Color(0.4, 0.9, 0.5)

		marker.text = badge_text
		marker.add_theme_color_override("font_color", badge_color)
		marker.add_theme_font_size_override("font_size", 22 if size > 1 else 18)
		marker.position = tile_origin + Vector2(footprint_span - 20, -4)
		marker.visible = badge_text != ""

		# Stealth's "spotted" indicator -- a second, independent marker (not
		# fighting the badge slot above for room) centered above the sprite.
		# u["spotted_you"] is stamped fresh by Main.gd's _refresh_battle_
		# display every call, so this reacts live as the player moves.
		var aware_marker: Label = battle_unit_aware_markers[i]
		aware_marker.text = "!"
		aware_marker.position = tile_origin + Vector2(footprint_span / 2.0 - 6, -18)
		aware_marker.visible = u.get("spotted_you", false)

	var turn_text: String = ("Your turn (moves left: %d)" % moves_left) if turn == "player" else "Enemy turn..."
	battle_status_label.text = "LV %d   %s" % [player_level, turn_text]

	var hp_ratio: float = clampf(float(player_hp) / float(max(1, player_max_hp)), 0.0, 1.0)
	battle_hp_bar_fill.size = Vector2(battle_hp_bar_bg.size.x * hp_ratio, battle_hp_bar_bg.size.y)
	battle_hp_number_label.text = "%d / %d" % [player_hp, player_max_hp]

	var stamina_ratio: float = clampf(float(stamina) / float(max(1, max_stamina)), 0.0, 1.0)
	battle_stamina_bar_fill.size = Vector2(battle_stamina_bar_bg.size.x * stamina_ratio, battle_stamina_bar_bg.size.y)
	battle_stamina_number_label.text = "%d / %d" % [stamina, max_stamina]

	battle_status_label2.text = ""
	if turn == "player" and target_index >= 0 and target_index < units.size():
		var target: Dictionary = units[target_index]
		battle_status_label2.text += "Target: %s   %d / %d HP" % [target.name, target.hp, target.max_hp]

	# Shield block chance is otherwise invisible mid-battle (only shown in
	# the shop) -- 0% still prints (e.g. an off-hand shield on an
	# incompatible weapon) so it's clear the shield is just inert, not gone.
	if shield_name != "":
		if battle_status_label2.text != "":
			battle_status_label2.text += "\n"
		battle_status_label2.text += "Shield: %s (%d%% block)" % [shield_name, int(round(shield_block_pct * 100))]

	# Rage/Berserk: the one status here with real drawbacks (no shield,
	# gutted block/dodge) alongside the damage boost, so it's surfaced
	# prominently rather than left to the battle log alone.
	if berserk_turns > 0:
		if battle_status_label2.text != "":
			battle_status_label2.text += "\n"
		battle_status_label2.text += "BERSERK (%d turn%s left)" % [berserk_turns, "" if berserk_turns == 1 else "s"]

	if stealth_turns > 0:
		if battle_status_label2.text != "":
			battle_status_label2.text += "\n"
		battle_status_label2.text += "STEALTHED (%d turn%s left)" % [stealth_turns, "" if stealth_turns == 1 else "s"]

	for i in battle_trail_markers.size():
		var trail_marker: Label = battle_trail_markers[i]
		if i < move_trail.size():
			var step: Dictionary = move_trail[i]
			trail_marker.text = _dir_arrow(step.dir)
			trail_marker.position = battle_grid_origin + Vector2(step.tile.x, step.tile.y) * battle_tile_size + Vector2(battle_tile_size / 2.0 - 6, battle_tile_size / 2.0 - 30)
			trail_marker.visible = true
		else:
			trail_marker.visible = false

	var is_player_turn: bool = turn == "player"
	battle_main_menu_box.visible = is_player_turn and menu_state == "main" and not is_evasion_prompt
	battle_fight_submenu_box.visible = is_player_turn and menu_state == "fight" and not is_evasion_prompt
	battle_move_submenu_box.visible = is_player_turn and menu_state == "move" and not is_evasion_prompt
	battle_arrow_submenu_box.visible = is_player_turn and menu_state == "arrow" and not is_evasion_prompt
	battle_tactics_submenu_box.visible = is_player_turn and menu_state == "tactics" and not is_evasion_prompt
	# Independent of is_player_turn -- this shows mid-"enemy" turn, the one
	# moment the player acts without it technically being their turn.
	battle_evasion_submenu_box.visible = is_evasion_prompt

	battle_main_buttons["item"].disabled = healing_items <= 0
	battle_main_buttons["move"].disabled = moves_left <= 0
	# Disarmed (Spear's Target Practice miss, Dagger's Knife Throw): Fight is
	# off-limits until you're standing back on the tile your weapon landed on
	# -- everything else (Move/Item/Defend/Flee/Skill/Arrow) stays available.
	battle_main_buttons["fight"].disabled = is_disarmed
	battle_main_buttons["skill"].visible = has_guardian_skill
	battle_main_buttons["skill"].disabled = skill_cooldown > 0
	battle_main_buttons["skill"].text = "Skill" if skill_cooldown <= 0 else "Skill (%d)" % skill_cooldown
	# Only the Bow can fire arrows -- the button is hidden (not just
	# disabled) the same way Skill is gated on has_guardian_skill.
	var is_bow_equipped: bool = current_weapon.get("id", "").begins_with("bow")
	battle_main_buttons["arrow"].visible = is_bow_equipped
	# Mine only shows up with Hand Picks equipped AND an actual rock/rubble
	# in reach -- can_mine already folds both checks together (see Main.gd:
	# _refresh_battle_display).
	battle_fight_buttons["mine"].visible = can_mine

	var specials: Array = current_weapon.get("specials", [])
	var special_keys := ["special_0", "special_1", "special_2"]
	battle_fight_buttons["heavy"].text = "Heavy Attack (%d STA)" % WeaponsScript.HEAVY_STAMINA_COST
	battle_fight_buttons["heavy"].disabled = stamina < WeaponsScript.HEAVY_STAMINA_COST
	battle_tactics_buttons["stealth"].text = "Stealth (%d STA)" % stealth_cost
	battle_tactics_buttons["stealth"].disabled = stamina < stealth_cost
	for i in special_keys.size():
		var button: Button = battle_fight_buttons[special_keys[i]]
		if i < specials.size():
			var special: Dictionary = specials[i]
			button.text = "%s (%d STA)" % [special.name, special.stamina_cost]
			button.disabled = stamina < special.stamina_cost
			button.set_meta("description", special.description)
			button.visible = true
		else:
			button.visible = false

	for kind in ["flame", "freeze", "bomb"]:
		var arrow_button: Button = battle_arrow_buttons[kind]
		var info: Dictionary = WeaponsScript.ARROW_TYPES[kind]
		var held: int = owned_arrows.get(kind, 0)
		arrow_button.text = "%s (%d)" % [info.name, held]
		arrow_button.disabled = held <= 0
		arrow_button.set_meta("description", info.description)

func battle_log(msg: String) -> void:
	battle_log_lines.append(msg)
	if battle_log_lines.size() > 4:
		battle_log_lines.pop_front()
	battle_log_label.text = "\n".join(battle_log_lines)

func hide_battle() -> void:
	battle_panel.visible = false
