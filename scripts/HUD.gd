extends CanvasLayer
class_name HUD

const WeaponsScript := preload("res://scripts/Weapons.gd")
const WeaponIconsScript := preload("res://scripts/WeaponIcons.gd")
const PlayerScript := preload("res://scripts/Player.gd")

# Flat cost to lock a rolled (non-Club) weapon offer so a reroll can't take
# it away -- kept in sync with the identical const in Main.gd, which is
# what actually spends the coins; this copy is display-text only.
const SHOP_LOCK_COST := 5

# The battle grid shows each enemy as its actual overworld sprite instead of
# a generic letter, keyed by the same display name battle_units already
# carries.
const BLADE_ALLY_ICON := preload("res://assets/blade_ally.png")
# The most ally icons a battle can show: a full party of 4 plus the wolf-only slot, the fallen who
# still lie on the field, and the Necromancer's summoned skeletons.
const MAX_BATTLE_ALLIES := 16
const TOGGLE_OFF_ICON := preload("res://assets/toggle_off.png")
const TOGGLE_ON_ICON := preload("res://assets/toggle_on.png")

const ENEMY_ICONS := {
	"Goblin": preload("res://assets/enemy_goblin.png"),
	"Orc": preload("res://assets/enemy_orc.png"),
	"Apprentice Mage": preload("res://assets/enemy_apprentice_mage.png"),
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
	"Leviathan": preload("res://assets/enemy_aboleth.png"),
	"Lizen Warband": preload("res://assets/enemy_lizard_soldier_swarm.png"),
	"Black Dragonlet": preload("res://assets/enemy_black_dragonlet.png"),
	"Treant": preload("res://assets/enemy_treant.png"),
	"Elder Oak": preload("res://assets/enemy_elder_oak.png"),
	"Iron Construct": preload("res://assets/enemy_iron_golem.png"),
	"White Dragon": preload("res://assets/enemy_white_dragon.png"),
	"Lava Construct": preload("res://assets/enemy_lava_golem.png"),
	"Red Wyrm": preload("res://assets/enemy_red_wyrm.png"),
	"Voidwing": preload("res://assets/enemy_voidwing.png"),
	"Archmage": preload("res://assets/enemy_supreme_warlock.png"),
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
var xp_bar_bg: ColorRect
var xp_bar_fill: ColorRect
var quiver_row: HBoxContainer
var danger_caption: Label
var danger_pips: Array = []
var minimap: Control
var message_toast: PanelContainer
var message_tween: Tween
var health_bar_bg: ColorRect
var health_bar_fill: ColorRect
var health_heart_label: Label
var quiver_icon: TextureButton
var quiver_tooltip_label: Label
var coins_label: Label
var items_label: Label
var wave_label: Label
var world_label: Label
var room_label: Label
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
var menu_beastiary_button: Button
var menu_inventory_button: Button
var menu_settings_button: Button
var battle_beastiary_button: Button
# The turn-order strip along the top of a battle (Main.gd:_turn_order_rows): who acts now and
# who is next, fastest first. Rebuilt on every refresh.
var turn_order_box: HBoxContainer
var settings_panel: ColorRect
var settings_master_slider: HSlider
var settings_sfx_slider: HSlider
var settings_music_slider: HSlider
var settings_master_value_label: Label
var settings_sfx_value_label: Label
var settings_music_value_label: Label
var settings_shake_checkbox: CheckButton
var settings_damage_numbers_checkbox: CheckButton
var settings_minigames_checkbox: CheckButton
var settings_attack_minigame_checkbox: CheckButton
var settings_rebind_buttons := {}
var settings_back_button: Button
var settings_node: Node
# Empty when no rebind is in progress; set to the action name while a rebind
# row's button is waiting for the next key press.
var rebinding_action := ""
var shop_panel: ColorRect
var shop_window: Panel
var shop_keeper_portrait: TextureRect
var shop_keeper_textbox: Label
# Typewriter reveal state for the shopkeeper's speech bubble (see
# set_shopkeeper_line/_process/skip_shopkeeper_reveal). A float, not an int,
# so SHOPKEEPER_CHARS_PER_SEC's fractional per-frame advance doesn't get
# truncated away at high framerates.
var shopkeeper_full_text := ""
var shopkeeper_revealed_chars := 0.0
const SHOPKEEPER_CHARS_PER_SEC := 46.0
var shop_coins_label: Label
var shop_shards_label: Label
var shop_weapon_tag: Label
var shop_armor_tag: Label
var shop_shield_tag: Label
var shop_potions_tag: Label
var shop_footer_label: Label
var shop_title_label: Label
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
var shop_spells_tab_button: Button
var shop_spells_scroll: ScrollContainer
var shop_spells_row_box: VBoxContainer
var shop_spells_note_label: Label
var shop_spells_row_nodes := []
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
# The 4 generic actions available while commanding a party member's own turn
# (see Main.gd's battle_commanding_ally) -- Move/Attack/Guard/Skip. A kit's
# own specials/spells (Wolf, Druid, Guardian, Marksman, Rogue) aren't built
# yet; this signal grows a "special"/"spell" action once one exists.
signal battle_ally_action(action: String)
signal battle_evasion_direction_pressed(label: String)
# Turtle Shell's "the water wants to carry you, go with it?" prompt -- the
# same shape as battle_evasion_direction_pressed, just yes/no instead of a
# compass pick. See Main.gd:_prompt_water_push.
signal battle_confirm_choice(accepted: bool)
signal enemy_hovered(index: int)
signal enemy_unhovered
# The mouse over a unit on the grid (kind "hero", "ally" or "enemy"; index into the allies / enemies last drawn), and a click on
# one or on a party card.
signal unit_hovered(kind: String, index: int)
signal unit_unhovered
signal unit_clicked(kind: String, index: int)
# The mouse or keyboard focus on an entry of an attack list (for the damage preview over the target): the hero's own "attack",
# "heavy", "special_<i>", or a member's "ally:attack" / "ally:special_<i>".
signal action_previewed(action: String)
signal action_preview_cleared
# Tab: step the details box on to the next unit (the keyboard's way in; see Main.gd:_cycle_battle_details).
signal inspect_cycled
signal rock_target_selected(tile: Vector2i)
signal levelup_choice_pressed(stat_name: String)
signal event_choice_pressed(accepted: bool)
signal menu_resume_pressed
signal beastiary_pressed
signal inventory_pressed
# Fired once per _process tick that reveals at least one non-space character
# of the shopkeeper's line -- Main.gd plays the talk-blip SFX off of this
# rather than HUD reaching for play_sfx itself (that pool lives on Main).
signal shopkeeper_blip
signal settings_pressed
signal settings_back_pressed
signal shop_buy_pressed(index: int)
signal shop_lock_pressed(index: int)
signal shop_reroll_pressed
signal shop_continue_pressed
signal enchant_apply_pressed(rune_id: String)
signal spell_upgrade_pressed(spell_id: String)
signal arrow_buy_pressed(kind: String)
signal arrow_sell_pressed(kind: String)
signal game_over_return_pressed
signal enemy_target_selected(index: int)
signal tutorial_skip_pressed

var battle_panel: ColorRect
var battle_gradient_rect: TextureRect
var battle_content_root: Control
var overworld_hud_root: Control
var battle_hint_panel: Panel
var battle_hint_label: Label
var battle_tutorial_skip_button: Button
# "First time you obtained X" card -- a direct child of HUD itself (not
# nested in battle_panel/shop_window), so it stays on top and visible
# regardless of which sub-panel is currently active. See _build_unlock_popup.
var unlock_popup_panel: Panel
var unlock_popup_name_label: Label
var unlock_popup_desc_label: Label
var unlock_popup_dismiss_button: Button
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
# The redesigned screen's own pieces (built in _build_battle_shell): the party cards, the plates over every unit, the bottom
# bar's key-hint line.
var battle_range_rects := []
var battle_range_styles := {}
var battle_history: Array = []                    # [{turn, lines}], the last three turns, newest last
var battle_history_panel: Panel
var battle_history_text: RichTextLabel
var battle_history_button: Button
var battle_preview: Dictionary = {}               # the damage chip over the target of the attack being considered
var battle_popup: Dictionary = {}                 # the small card over a hovered unit
var battle_details: Dictionary = {}               # the big box a click opens at the side
var battle_status_tooltip: Dictionary = {}        # what a hovered status does
var battle_hover_key := ""                        # "hero", "ally:<i>", "enemy:<i>" under the mouse ("" = none)
var battle_units_now: Array = []                  # the last grid state drawn, for finding the unit under the mouse
var battle_allies_now: Array = []
var battle_player_tile_now := Vector2i(-1, -1)
var battle_grid_size_now := Vector2i(6, 6)
var battle_party_cards := []
var battle_hero_plate: Dictionary = {}
var battle_ally_plates := []
var battle_enemy_plates := []
var battle_key_hint_label: Label
var battle_party_rows: Array = []
var battle_grid_origin := Vector2(348, 68)       # re-centred from the viewport in _build_battle_ui
var battle_tile_size := 76.0
# Matches Main.gd:BOSS_BATTLE_GRID_SIZE -- the biggest grid any battle uses
# (a boss fight), so the tile pool below is sized for the max case. The
# footprint every grid renders within stays fixed regardless of size (see
# update_battle_grid); a smaller battle just uses fewer, larger tiles -- this
# is what keeps the grid "centered"/stable on screen across every size (6x6
# through 15x15) rather than the box itself growing or shifting.
const MAX_BATTLE_GRID_SIZE := 15
const BATTLE_GRID_FOOTPRINT_PX := 456.0
# The redesigned battle screen (see _build_battle_shell): party cards down the left, the grid centred, the turn order along
# the top, a status/key-hint bar along the bottom. Everything in battle_content_root is placed in screen coordinates.
const BATTLE_GRID_TOP := 68.0
const BATTLE_CARD_X := 24.0
const BATTLE_CARD_W := 200.0
const BATTLE_CARD_H := 88.0
const BATTLE_CARD_STEP := 92.0
const BATTLE_CARD_SLOTS := 7                  # the hero and up to six more (a full roster and the wolf)
const BATTLE_MENU_X := 240.0
const BATTLE_BAR_H := 30.0                    # the bottom status/key-hint bar
const BattleStyleScript := preload("res://scripts/BattleStyle.gd")
const BattleStatusesScript := preload("res://scripts/BattleStatuses.gd")
const UIIconsScript := preload("res://scripts/UIIcons.gd")
const IconStripScript := preload("res://scripts/IconStrip.gd")
# Battle status pictures are 16x16 art: shown one-to-one beside a card's chip line or a popup's, and doubled in the details box's rows.
const STATUS_ICON_PX := 16.0
const BATTLE_GOLD := BattleStyleScript.GOLD
const BATTLE_ALLY_BLUE := BattleStyleScript.ALLY_BLUE
const BATTLE_ENEMY_RED := BattleStyleScript.ENEMY_RED
const BATTLE_TEXT := BattleStyleScript.TEXT
const BATTLE_DIM := BattleStyleScript.DIM
const BATTLE_MP_COLOR := Color(0.6, 0.36, 0.88)
# Hand-measured estimate of the overworld HUD block's own widest row (the
# HP bar reaches to x=314) -- see overworld_hud_root's construction in
# _ready() for why this exists.
const OVERWORLD_HUD_WIDTH := 340.0
# The overworld readout's panels are a touch see-through so the world stays visible behind them.
const HUD_PANEL_BG := Color(0.07, 0.065, 0.09, 0.86)
const XP_BAR_BG_COLOR := Color(0.09, 0.09, 0.17, 1.0)
const XP_BAR_FILL_COLOR := Color(0.45, 0.5, 0.95, 1.0)
const DANGER_PIPS := 8
const MiniMapScript := preload("res://scripts/MiniMap.gd")
# Kept in sync by hand with Main.gd:MAX_BATTLE_SQUAD_SIZE_CEILING -- the enemy
# icon/marker pools below must be at least this big or a heavily-scaled squad
# (see _squad_size_bonus) would index past the pool.
const MAX_BATTLE_UNITS := 6
# Kept in sync by hand with Main.gd:FAE_HUT_SPAWN_INTERVAL, purely for the
# battle-marker countdown text below (see update_battle_grid).
const FAE_HUT_SPAWN_INTERVAL := 3
# static: built once for the whole process, not once per HUD instance. A
# fresh run (death -> title -> new game, or title -> new game again) tears
# down the old HUD and builds a new one, and Godot does not animate
# correctly when a second AnimatedTexture instance wraps the same underlying
# frame files a still-cached first instance already wrapped -- confirmed by
# reproducing it directly (a second Main.tscn instantiation in the same
# process renders every grass tile solid white instead of stuck-on-frame-0,
# which is what the water-frames version of this same conflict looked like
# when it was first found). Reusing one instance for the process's whole
# lifetime sidesteps the conflict entirely instead of triggering it once per
# run.
static var water_animated_texture: AnimatedTexture
static var grass_animated_texture: AnimatedTexture

# The action menus are short framed lists that float beside the acting unit (see _build_battle_menus): the root list
# (Attack / Strategy / Item for the hero; Attack / Magic / Strategy for a member), and the lists they open, each with a round
# back button on its top-left corner. battle_menus holds {panel, list, back} for each; the *_box vars are their panels.
var battle_menus := {}
var battle_main_menu_box: Control
var battle_strategy_menu_box: Control
var battle_fight_submenu_box: Control
var battle_move_submenu_box: Control
var battle_arrow_submenu_box: Control
var battle_ally_menu_box: Control
var battle_ally_buttons := {}
# The ally's attack / magic / strategy lists and the friendly-target picker: a fixed pool of buttons relabelled
# every refresh from battle_ally_menu_info (set by Main.gd:_refresh_battle_display each frame).
const ALLY_SPECIAL_SLOTS := 12
const ALLY_PICK_SLOTS := 24                # Summon the Dead's "how many" picker has a button per number (Main.SUMMON_PICK_LIMIT)
var battle_ally_special_box: Control
var battle_ally_special_buttons := []
var battle_ally_special_back: Button
var battle_ally_pick_box: Control
var battle_ally_pick_buttons := []
var battle_ally_pick_back: Button
var battle_ally_pick_grid: GridContainer
var battle_ally_menu_info: Dictionary = {}
var battle_evasion_submenu_box: HBoxContainer
var battle_confirm_box: HBoxContainer
var battle_confirm_yes_button: Button
var battle_confirm_no_button: Button
var battle_main_buttons := {}
var battle_fight_buttons := {}
var battle_move_buttons := {}
var battle_arrow_buttons := {}
var battle_tactics_buttons := {}
var battle_evasion_buttons := {}

# Every hover-hint/description string that ISN'T a data-driven item's own
# field (those already live on Weapons.gd/Armor.gd/etc. and are covered by
# GameText.gd directly) -- battle action explanations, the shop's own
# mechanic hints. Walked by GameText.gd the same way any other flat string
# dictionary is, keyed "ui.<key>" in strings.json, so these are just as
# reskinnable as everything else instead of being permanently hardcoded.
static var UI_TEXT := {
	"battle.main.move": "Reposition on the grid. Doesn't end your turn.",
	"battle.main.strategy": "Reposition, brace, taunt, vanish into stealth, or retreat.",
	"battle.main.fight": "Choose an attack: a free regular hit, a costly heavy hit, or one of your weapon's specials.",
	"battle.main.item": "Use a healing potion.",
	"battle.main.defend": "Brace for impact -- reduces damage taken this turn and recovers a big chunk of stamina (+15).",
	"battle.main.skill": "Guardian's Ultimatum: instantly heal 40% of max HP. Once every 4 turns.",
	"battle.main.arrow": "Fire a purchased special arrow. Costs no stamina, but consumes 1 of that arrow.",
	"battle.main.tactics": "Taunt to force every enemy's attention onto you, or vanish into Stealth.",
	"battle.main.flee": "Retreat from this battle.",
	"battle.fight.attack": "A standard attack with your equipped weapon. Free.",
	"battle.fight.heavy": "A powerful strike. Costs %d stamina.",
	"battle.fight.mine": "Break apart a rock or rubble tile next to you. Free.",
	"battle.fight.back": "Return to the main menu.",
	"battle.tactics.taunt": "Force every enemy's attention onto you this turn -- also reduces damage taken, same as Defend.",
	"battle.tactics.stealth": "Vanish for a few turns: unaware enemies can't target you. Your next attack is a guaranteed crit.",
	"battle.tactics.back": "Return to the main menu.",
	"battle.move.confirm": "Lock in your current position.",
	"battle.move.cancel": "Undo this move -- back to where you started, no harm done.",
	"battle.evasion.back": "Roll straight back and away from the attacker.",
	"battle.evasion.left": "Roll to your left, relative to the attacker.",
	"battle.evasion.right": "Roll to your right, relative to the attacker.",
	"battle.arrow.back": "Return to the main menu.",
	"battle.ally.move": "Move this ally on the grid. Doesn't end its turn.",
	"battle.ally.attack": "This ally attacks with its own weapon and stats.",
	"battle.ally.open_attack": "This ally's attacks: its plain attack and the weapon and fighting moves that hurt.",
	"battle.ally.open_magic": "This ally's spells.",
	"battle.ally.open_strategy": "Reposition this ally, have it guard, or use a tactic.",
	"battle.ally.special": "Open this ally's special moves (its weapon's, and its own).",
	"battle.ally.back": "Back to this ally's main menu.",
	"battle.ally.guard": "This ally braces for impact, taking less damage until its next turn.",
	"battle.ally.skip": "This ally does nothing this turn.",
	"shop.reroll": "Reroll the shop's offering. Costs more each time you use it this visit.",
	"shop.continue": "Step back outside.",
	"shop.lock": "Protect this offer from being rerolled away, for %d gold.",
	"shop.arrow_sell": "Sell one %s for %d coins.",
	"levelup.intimidation": "-1% shop prices per point (capped at -75%).",
	"levelup.strength": "+1 damage per point on every attack you land.",
	"levelup.vigor": "+1 max HP per point.",
	"levelup.agility": "+1 overworld speed per point, a faster attack cooldown, and +1 battle move tile every 20 points.",
	"levelup.might": "Better weapons require higher Might to equip; boosts recruited party/wolf damage.",
	"levelup.resilience": "+1 Defense per point, pooled with your armour and bent into less BODILY harm with diminishing returns (never past 80%).",
	"levelup.fortitude": "+1 Fortitude per point, on top of your armour's, bent into less MAGICAL harm with diminishing returns (never past 80%).",
	"levelup.reflexes": "0.75% dodge chance per point, capped at 15%.",
	"levelup.dexterity": "0.75% crit chance per point (double damage, ignores cover), capped at 15%.",
}

func _ready() -> void:
	layer = 10
	# See Player.gd/Main.gd for why this is a cached runtime node lookup
	# instead of the bare "Settings" autoload identifier.
	settings_node = get_node("/root/Settings")

	# A soft radial vignette, added first so every other HUD element (info
	# block, buttons, panels) draws on top of it and stays fully readable --
	# only the screen's own corners/edges darken. Every full-screen opaque
	# overlay this file has (battle/shop/pause/etc.) naturally covers it
	# outright when visible, so this only ever reads during plain overworld
	# walking, exactly where the "flat, no depth" complaint was about.
	var vignette := TextureRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vignette_gradient := Gradient.new()
	vignette_gradient.set_color(0, Color(0, 0, 0, 0))
	vignette_gradient.set_color(1, Color(0, 0, 0, 0.5))
	var vignette_tex := GradientTexture2D.new()
	vignette_tex.gradient = vignette_gradient
	vignette_tex.fill = GradientTexture2D.FILL_RADIAL
	vignette_tex.fill_from = Vector2(0.5, 0.5)
	vignette_tex.fill_to = Vector2(1.0, 1.0)
	vignette_tex.width = 64
	vignette_tex.height = 64
	vignette.texture = vignette_tex
	add_child(vignette)

	if water_animated_texture == null:
		water_animated_texture = AnimatedTexture.new()
		water_animated_texture.frames = WATER_FRAME_TEXTURES.size()
		for i in WATER_FRAME_TEXTURES.size():
			water_animated_texture.set_frame_texture(i, WATER_FRAME_TEXTURES[i])
			water_animated_texture.set_frame_duration(i, 0.35)

	if grass_animated_texture == null:
		grass_animated_texture = AnimatedTexture.new()
		grass_animated_texture.frames = GRASS_FRAME_TEXTURES.size()
		for i in GRASS_FRAME_TEXTURES.size():
			grass_animated_texture.set_frame_texture(i, GRASS_FRAME_TEXTURES[i])
			grass_animated_texture.set_frame_duration(i, 0.6)

	# The overworld readout: a compact card for you in the top-left corner (level, HP and XP bars, stats), a banner
	# in the top-right (where you are, how dangerous it is, coins, items, and a small map of the continent), the
	# controls tucked low in the bottom-left, and messages that pop up near the bottom and fade on their own.
	# Everything hangs off the screen's corners so the middle of the screen stays clear to play in.
	overworld_hud_root = Control.new()
	overworld_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overworld_hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overworld_hud_root)

	# --- the player card (top-left) ---
	var card := PanelContainer.new()
	card.position = Vector2(14, 14)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _make_stylebox(HUD_PANEL_BG, PANEL_BORDER, 2, 0, 9))
	overworld_hud_root.add_child(card)
	var card_box := VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 5)
	card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(card_box)

	var card_top := HBoxContainer.new()
	card_top.add_theme_constant_override("separation", 9)
	card_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_box.add_child(card_top)

	var level_badge := PanelContainer.new()
	level_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_badge.add_theme_stylebox_override("panel", _make_stylebox(Color(0.22, 0.17, 0.05, 1.0), Color(1.0, 0.85, 0.2), 2, 0, 5))
	card_top.add_child(level_badge)
	level_label = Label.new()
	level_label.add_theme_font_size_override("font_size", 18)
	level_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35))
	level_label.custom_minimum_size = Vector2(44, 0)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_badge.add_child(level_label)

	var bars := VBoxContainer.new()
	bars.add_theme_constant_override("separation", 3)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_top.add_child(bars)

	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 6)
	hp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.add_child(hp_row)
	health_heart_label = Label.new()
	health_heart_label.text = "♥"
	health_heart_label.add_theme_font_size_override("font_size", 18)
	health_heart_label.add_theme_color_override("font_color", HEALTH_BAR_FILL_COLOR)
	hp_row.add_child(health_heart_label)
	health_bar_bg = ColorRect.new()
	health_bar_bg.color = HEALTH_BAR_BG_COLOR
	health_bar_bg.custom_minimum_size = Vector2(190, 20)
	health_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_row.add_child(health_bar_bg)
	health_bar_fill = ColorRect.new()
	health_bar_fill.color = HEALTH_BAR_FILL_COLOR
	health_bar_fill.size = health_bar_bg.custom_minimum_size
	health_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_bar_bg.add_child(health_bar_fill)
	health_label = Label.new()
	health_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	health_label.add_theme_font_size_override("font_size", 13)
	health_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	health_label.add_theme_constant_override("outline_size", 4)
	health_bar_bg.add_child(health_label)

	var xp_row := HBoxContainer.new()
	xp_row.add_theme_constant_override("separation", 6)
	xp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.add_child(xp_row)
	var xp_pad := Control.new()
	xp_pad.custom_minimum_size = Vector2(18, 0)
	xp_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_row.add_child(xp_pad)
	xp_bar_bg = ColorRect.new()
	xp_bar_bg.color = XP_BAR_BG_COLOR
	xp_bar_bg.custom_minimum_size = Vector2(190, 9)
	xp_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_row.add_child(xp_bar_bg)
	xp_bar_fill = ColorRect.new()
	xp_bar_fill.color = XP_BAR_FILL_COLOR
	xp_bar_fill.size = Vector2(0, xp_bar_bg.custom_minimum_size.y)
	xp_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_bar_bg.add_child(xp_bar_fill)

	xp_label = Label.new()
	xp_label.add_theme_font_size_override("font_size", 11)
	xp_label.add_theme_color_override("font_color", Color(0.6, 0.62, 0.8))
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	card_box.add_child(xp_label)

	stats_label = Label.new()
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.add_theme_color_override("font_color", Color(0.78, 0.76, 0.68))
	card_box.add_child(stats_label)

	# Quiver: only visible while a Bow is equipped (see update_quiver). Hovering the icon shows the live
	# flame/freeze/bomb counts beside it.
	quiver_row = HBoxContainer.new()
	quiver_row.add_theme_constant_override("separation", 6)
	quiver_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quiver_row.visible = false
	card_box.add_child(quiver_row)
	quiver_icon = TextureButton.new()
	quiver_icon.texture_normal = load("res://assets/quiver.png")
	quiver_icon.ignore_texture_size = true
	quiver_icon.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	quiver_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	quiver_icon.custom_minimum_size = Vector2(22, 22)
	quiver_icon.focus_mode = Control.FOCUS_NONE
	quiver_icon.visible = false
	quiver_icon.mouse_entered.connect(func(): quiver_tooltip_label.text = quiver_icon.get_meta("tooltip", ""))
	quiver_icon.mouse_exited.connect(func(): quiver_tooltip_label.text = "")
	quiver_row.add_child(quiver_icon)
	quiver_tooltip_label = Label.new()
	quiver_tooltip_label.add_theme_font_size_override("font_size", 12)
	quiver_tooltip_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.6))
	quiver_row.add_child(quiver_tooltip_label)

	# --- the banner (top-right) ---
	var banner := PanelContainer.new()
	banner.anchor_left = 1.0
	banner.anchor_right = 1.0
	banner.anchor_top = 0.0
	banner.anchor_bottom = 0.0
	banner.offset_left = -14.0
	banner.offset_right = -14.0
	banner.offset_top = 14.0
	banner.offset_bottom = 14.0
	banner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_stylebox_override("panel", _make_stylebox(HUD_PANEL_BG, PANEL_BORDER, 2, 0, 9))
	overworld_hud_root.add_child(banner)
	var banner_box := VBoxContainer.new()
	banner_box.add_theme_constant_override("separation", 4)
	banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(banner_box)

	world_label = Label.new()
	world_label.add_theme_font_size_override("font_size", 19)
	world_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.62))
	world_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	world_label.custom_minimum_size = Vector2(MiniMapScript.MAP_PX.x, 0)
	banner_box.add_child(world_label)
	room_label = Label.new()
	room_label.add_theme_font_size_override("font_size", 13)
	room_label.add_theme_color_override("font_color", Color(0.78, 0.76, 0.7))
	room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	room_label.custom_minimum_size = Vector2(MiniMapScript.MAP_PX.x, 0)
	room_label.clip_text = true
	banner_box.add_child(room_label)

	var danger_row := HBoxContainer.new()
	danger_row.add_theme_constant_override("separation", 3)
	danger_row.alignment = BoxContainer.ALIGNMENT_END
	danger_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_box.add_child(danger_row)
	danger_caption = Label.new()
	danger_caption.text = "Danger"
	danger_caption.add_theme_font_size_override("font_size", 11)
	danger_caption.add_theme_color_override("font_color", Color(0.65, 0.63, 0.58))
	danger_row.add_child(danger_caption)
	danger_pips = []
	for i in DANGER_PIPS:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(10, 10)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		danger_row.add_child(pip)
		danger_pips.append(pip)
	set_danger(0)

	var purse_row := HBoxContainer.new()
	purse_row.add_theme_constant_override("separation", 5)
	purse_row.alignment = BoxContainer.ALIGNMENT_END
	purse_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_box.add_child(purse_row)
	var coin_icon := TextureRect.new()
	coin_icon.texture = UIIconsScript.texture("stat_coin")
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	coin_icon.custom_minimum_size = Vector2(16, 16)
	purse_row.add_child(coin_icon)
	coins_label = Label.new()
	coins_label.add_theme_font_size_override("font_size", 17)
	coins_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	purse_row.add_child(coins_label)
	var purse_gap := Control.new()
	purse_gap.custom_minimum_size = Vector2(10, 0)
	purse_row.add_child(purse_gap)
	var item_icon := TextureRect.new()
	item_icon.texture = load("res://assets/potion.png")
	item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	item_icon.custom_minimum_size = Vector2(18, 18)
	purse_row.add_child(item_icon)
	items_label = Label.new()
	items_label.add_theme_font_size_override("font_size", 17)
	items_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	purse_row.add_child(items_label)

	var tally_row := HBoxContainer.new()
	tally_row.add_theme_constant_override("separation", 10)
	tally_row.alignment = BoxContainer.ALIGNMENT_END
	tally_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_box.add_child(tally_row)
	wave_label = Label.new()
	wave_label.add_theme_font_size_override("font_size", 12)
	wave_label.add_theme_color_override("font_color", Color(0.75, 0.74, 0.7))
	tally_row.add_child(wave_label)
	enemies_label = Label.new()
	enemies_label.add_theme_font_size_override("font_size", 12)
	enemies_label.add_theme_color_override("font_color", Color(0.9, 0.55, 0.5))
	tally_row.add_child(enemies_label)

	minimap = MiniMapScript.new()
	minimap.size_flags_horizontal = Control.SIZE_SHRINK_END
	banner_box.add_child(minimap)

	# --- messages and the controls reminder (bottom) ---
	message_toast = PanelContainer.new()
	message_toast.anchor_left = 0.5
	message_toast.anchor_right = 0.5
	message_toast.anchor_top = 1.0
	message_toast.anchor_bottom = 1.0
	message_toast.offset_top = -86.0
	message_toast.offset_bottom = -86.0
	message_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	message_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	message_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_toast.add_theme_stylebox_override("panel", _make_stylebox(Color(0.05, 0.045, 0.07, 0.82), PANEL_BORDER, 2, 0, 9))
	message_toast.visible = false
	overworld_hud_root.add_child(message_toast)
	message_label = Label.new()
	message_label.add_theme_font_size_override("font_size", 20)
	message_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_toast.add_child(message_label)

	var help_label := Label.new()
	help_label.text = "Arrows move   ·   WASD attack   ·   C menu   ·   I inventory"
	help_label.add_theme_font_size_override("font_size", 12)
	help_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8, 0.5))
	help_label.anchor_top = 1.0
	help_label.anchor_bottom = 1.0
	help_label.offset_left = 16.0
	help_label.offset_top = -30.0
	help_label.offset_bottom = -30.0
	help_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	help_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overworld_hud_root.add_child(help_label)

	menu_panel = ColorRect.new()
	menu_panel.color = Color(0, 0, 0, 0.65)
	menu_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_panel.visible = false
	add_child(menu_panel)
	_framed_panel(Vector2(260, 200), Vector2(240, 308), menu_panel)

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

	menu_beastiary_button = Button.new()
	menu_beastiary_button.position = Vector2(300, 354)
	menu_beastiary_button.custom_minimum_size = Vector2(160, 36)
	menu_beastiary_button.text = "Beastiary"
	menu_beastiary_button.pressed.connect(func(): beastiary_pressed.emit())
	_style_standard_button(menu_beastiary_button)
	_add_hover_color(menu_beastiary_button)
	menu_panel.add_child(menu_beastiary_button)

	menu_inventory_button = Button.new()
	menu_inventory_button.position = Vector2(300, 398)
	menu_inventory_button.custom_minimum_size = Vector2(160, 36)
	menu_inventory_button.text = "Inventory"
	menu_inventory_button.pressed.connect(func(): inventory_pressed.emit())
	_style_standard_button(menu_inventory_button)
	_add_hover_color(menu_inventory_button)
	menu_panel.add_child(menu_inventory_button)

	menu_settings_button = Button.new()
	menu_settings_button.position = Vector2(300, 442)
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

	var shop_window_size := Vector2(940, 560)
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

	var shop_hbox := HBoxContainer.new()
	shop_hbox.add_theme_constant_override("separation", 16)
	shop_margin.add_child(shop_hbox)

	# The shopkeeper: a portrait placeholder (no texture yet -- sprites and
	# animations are added later) above a speech-bubble textbox, reacting to
	# shop entry/exit, purchases, and whichever row is currently hovered --
	# see set_shopkeeper_line and _hook_shopkeeper_hover. Fixed-width column
	# so the rest of the shop (shop_column below) keeps its existing layout,
	# just narrower than before.
	var shop_keeper_box := VBoxContainer.new()
	shop_keeper_box.custom_minimum_size = Vector2(200, 0)
	shop_keeper_box.add_theme_constant_override("separation", 10)
	shop_hbox.add_child(shop_keeper_box)

	var shop_keeper_portrait_frame := PanelContainer.new()
	shop_keeper_portrait_frame.custom_minimum_size = Vector2(200, 200)
	shop_keeper_portrait_frame.add_theme_stylebox_override("panel", _make_stylebox(Color(0.1, 0.1, 0.12), PANEL_BORDER, 2, 0, 0))
	shop_keeper_box.add_child(shop_keeper_portrait_frame)

	shop_keeper_portrait = TextureRect.new()
	shop_keeper_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shop_keeper_portrait_frame.add_child(shop_keeper_portrait)

	var shop_keeper_textbox_frame := PanelContainer.new()
	shop_keeper_textbox_frame.custom_minimum_size = Vector2(200, 140)
	shop_keeper_textbox_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_keeper_textbox_frame.add_theme_stylebox_override("panel", _make_stylebox(Color(0.1, 0.1, 0.12), PANEL_BORDER, 2, 16, 12))
	shop_keeper_textbox_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	shop_keeper_textbox_frame.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			skip_shopkeeper_reveal()
	)
	shop_keeper_box.add_child(shop_keeper_textbox_frame)

	# The tail: a small border-colored triangle poking out of the bubble's
	# top edge with a slightly smaller background-colored one layered right
	# on top of it, same "outer ring peeking out from behind" trick a 2px
	# border on a flat shape always uses -- just done by hand here since
	# StyleBoxFlat has no notion of a speech-bubble tail. Positioned at a
	# fixed local offset (Polygon2D isn't a Control, so the containers above
	# never touch its transform) pointing straight up at the portrait.
	var tail_border := Polygon2D.new()
	tail_border.polygon = PackedVector2Array([Vector2(-11, 2), Vector2(11, 2), Vector2(0, -12)])
	tail_border.color = PANEL_BORDER
	tail_border.position = Vector2(28, 0)
	shop_keeper_textbox_frame.add_child(tail_border)
	var tail_fill := Polygon2D.new()
	tail_fill.polygon = PackedVector2Array([Vector2(-8, 3), Vector2(8, 3), Vector2(0, -8)])
	tail_fill.color = Color(0.1, 0.1, 0.12)
	tail_fill.position = Vector2(28, 0)
	shop_keeper_textbox_frame.add_child(tail_fill)

	shop_keeper_textbox = Label.new()
	shop_keeper_textbox.autowrap_mode = TextServer.AUTOWRAP_WORD
	shop_keeper_textbox.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	shop_keeper_textbox.add_theme_font_size_override("font_size", 15)
	shop_keeper_textbox.add_theme_color_override("font_color", Color(0.9, 0.9, 0.85))
	shop_keeper_textbox_frame.add_child(shop_keeper_textbox)

	var shop_column := VBoxContainer.new()
	shop_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_column.add_theme_constant_override("separation", 10)
	shop_hbox.add_child(shop_column)

	var shop_title_row := HBoxContainer.new()
	shop_column.add_child(shop_title_row)

	shop_title_label = Label.new()
	shop_title_label.text = "SHOP"
	shop_title_label.add_theme_font_size_override("font_size", 28)
	shop_title_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	shop_title_row.add_child(shop_title_label)

	var shop_title_spacer := Control.new()
	shop_title_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_title_row.add_child(shop_title_spacer)

	var shop_coin_icon := TextureRect.new()
	shop_coin_icon.texture = UIIconsScript.texture("stat_coin")
	shop_coin_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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

	shop_spells_tab_button = Button.new()
	shop_spells_tab_button.text = "Spells"
	shop_spells_tab_button.custom_minimum_size = Vector2(100, 32)
	shop_spells_tab_button.toggle_mode = true
	shop_tab_row.add_child(shop_spells_tab_button)

	shop_gear_tab_button.pressed.connect(func(): _select_shop_tab("gear"))
	shop_enchant_tab_button.pressed.connect(func(): _select_shop_tab("enchant"))
	shop_spells_tab_button.pressed.connect(func(): _select_shop_tab("spells"))
	_style_shop_tab_button(shop_gear_tab_button)
	_style_shop_tab_button(shop_enchant_tab_button)
	_style_shop_tab_button(shop_spells_tab_button)

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

	# The Wizard's Tower's second tab: upgrade spells (SpellUpgrades.gd), one row per spell.
	shop_spells_scroll = ScrollContainer.new()
	shop_spells_scroll.custom_minimum_size = Vector2(0, 260)
	shop_spells_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_spells_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shop_spells_scroll.visible = false
	shop_column.add_child(shop_spells_scroll)
	var shop_spells_column := VBoxContainer.new()
	shop_spells_column.add_theme_constant_override("separation", 8)
	shop_spells_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_spells_scroll.add_child(shop_spells_column)
	shop_spells_note_label = Label.new()
	shop_spells_note_label.add_theme_font_size_override("font_size", 14)
	shop_spells_note_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	shop_spells_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	shop_spells_column.add_child(shop_spells_note_label)
	shop_spells_row_box = VBoxContainer.new()
	shop_spells_row_box.add_theme_constant_override("separation", 8)
	shop_spells_row_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_spells_column.add_child(shop_spells_row_box)

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
	_setup_hover_button(shop_reroll_button, UI_TEXT["shop.reroll"], shop_description_label)
	_style_shop_action_button(shop_reroll_button, false)
	shop_action_box.add_child(shop_reroll_button)

	shop_continue_button = Button.new()
	shop_continue_button.custom_minimum_size = Vector2(260, 40)
	shop_continue_button.text = "Leave"
	shop_continue_button.pressed.connect(func(): shop_continue_pressed.emit())
	_setup_hover_button(shop_continue_button, UI_TEXT["shop.continue"], shop_description_label)
	_style_shop_action_button(shop_continue_button, true)
	shop_action_box.add_child(shop_continue_button)

	shop_footer_label = Label.new()
	shop_footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_footer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_footer_label.add_theme_font_size_override("font_size", 13)
	shop_footer_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	shop_footer_label.text = "[1-9] Buy   [R] Reroll   [Enter/Esc] Leave"
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
	_build_unlock_popup()

# Advances the shopkeeper's typewriter reveal -- runs regardless of pause
# (inherited PROCESS_MODE_ALWAYS from Main, same as everything else here)
# since the shop pauses the tree while open. A fractional float count, not
# an int index, so the per-frame advance stays framerate-independent instead
# of revealing in big framerate-dependent jumps.
func _process(delta: float) -> void:
	_track_battle_hover()
	if shopkeeper_revealed_chars >= shopkeeper_full_text.length():
		return
	var prev_int: int = int(shopkeeper_revealed_chars)
	shopkeeper_revealed_chars = minf(shopkeeper_revealed_chars + SHOPKEEPER_CHARS_PER_SEC * delta, shopkeeper_full_text.length())
	var new_int: int = int(shopkeeper_revealed_chars)
	shop_keeper_textbox.text = shopkeeper_full_text.substr(0, new_int)
	for i in range(prev_int, new_int):
		if shopkeeper_full_text[i] != " ":
			shopkeeper_blip.emit()
			break

# "First time you obtained X" card, shared across skills/weapons/shields/
# arrows/runes (see Main.gd:_maybe_announce_unlock). Added last -- and
# directly to HUD itself rather than nested in any sub-panel -- so it's
# always the topmost sibling Control no matter which other panel (shop,
# battle, pause) is currently showing. Non-blocking: mouse_filter=IGNORE on
# the backdrop, no pause/focus-grab, just an informational overlay.
func _build_unlock_popup() -> void:
	unlock_popup_panel = Panel.new()
	unlock_popup_panel.size = Vector2(280, 100)
	unlock_popup_panel.position = Vector2(get_viewport().get_visible_rect().size.x - 300, 20)
	unlock_popup_panel.visible = false
	unlock_popup_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	unlock_popup_panel.add_theme_stylebox_override("panel", _make_stylebox(PANEL_BG, PANEL_BORDER, 3, 0, 10))
	add_child(unlock_popup_panel)

	unlock_popup_name_label = Label.new()
	unlock_popup_name_label.position = Vector2(10, 8)
	unlock_popup_name_label.size = Vector2(260, 22)
	unlock_popup_name_label.add_theme_font_size_override("font_size", 16)
	unlock_popup_name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	unlock_popup_panel.add_child(unlock_popup_name_label)

	unlock_popup_desc_label = Label.new()
	unlock_popup_desc_label.position = Vector2(10, 32)
	unlock_popup_desc_label.size = Vector2(260, 50)
	unlock_popup_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	unlock_popup_desc_label.add_theme_font_size_override("font_size", 13)
	unlock_popup_desc_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	unlock_popup_panel.add_child(unlock_popup_desc_label)

	unlock_popup_dismiss_button = Button.new()
	unlock_popup_dismiss_button.text = "X"
	unlock_popup_dismiss_button.position = Vector2(250, 6)
	unlock_popup_dismiss_button.size = Vector2(22, 20)
	unlock_popup_dismiss_button.pressed.connect(hide_unlock_popup)
	_add_hover_color(unlock_popup_dismiss_button)
	_style_standard_button(unlock_popup_dismiss_button, 4)
	unlock_popup_panel.add_child(unlock_popup_dismiss_button)

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
	var battle_frame := _framed_panel(Vector2(8, 8), get_viewport().get_visible_rect().size - Vector2(16, 16), battle_panel)

	# The framed panel above is what's actually visible across nearly the
	# whole screen (its own opaque PANEL_BG fill) -- battle_panel's own flat
	# .color only ever shows as the thin 8px ring around that inset frame.
	# A gradient there reads as a real background instead of a flat fill:
	# this rect sits BEHIND the frame (index 0) showing through it, and the
	# frame's own stylebox gets its background dropped to fully transparent
	# (border kept) rather than touching _framed_panel itself, which every
	# other dialog-style screen in this file also shares.
	# The gradient lives inside a rounded backdrop that clips it, so the screen's corners are round like its frame.
	var backdrop := Panel.new()
	backdrop.position = battle_frame.position
	backdrop.size = battle_frame.size
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_theme_stylebox_override("panel", _battle_box(Color(0.02, 0.12, 0.16), Color(0, 0, 0, 0), 0, BattleStyleScript.CORNER + 6))
	backdrop.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	battle_panel.add_child(backdrop)
	battle_panel.move_child(backdrop, 0)
	battle_gradient_rect = TextureRect.new()
	battle_gradient_rect.position = Vector2.ZERO
	battle_gradient_rect.size = battle_frame.size
	battle_gradient_rect.stretch_mode = TextureRect.STRETCH_SCALE
	battle_gradient_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(battle_gradient_rect)
	battle_frame.add_theme_stylebox_override("panel", _battle_box(Color(0, 0, 0, 0), PANEL_BORDER, 2, BattleStyleScript.CORNER + 6))
	_set_battle_gradient(BATTLE_GRADIENT_TOP)

	# Every battle element below (grid, HP/stamina bars, log, menus) was
	# originally positioned as a direct battle_panel child in absolute
	# coordinates starting near x=20 -- fine at first, but it left the whole
	# interactive cluster crammed into the left ~40% of the window with a
	# big empty void on the right. Wrapping them all in this one Control and
	# shifting IT right instead re-centers the entire cluster as a unit
	# without having to touch a single one of their existing relative
	# positions (a child's position is relative to whichever parent it's
	# actually under). BATTLE_CONTENT_WIDTH is a hand-measured estimate of
	# the cluster's own rightmost extent (the main action menu's row of up
	# to 8 buttons is the widest single element) -- the 3 elements that are
	# deliberately anchored to the WINDOW's own corners regardless of this
	# (Beastiary button, tutorial skip button, tutorial hint bubble) stay
	# direct battle_panel children instead, so they don't get shifted twice.
	# (The redesigned screen no longer shifts this: its pieces are placed in screen coordinates -- the grid centred from the
	# viewport width, the party cards down the left, the bars along the bottom. See _build_battle_shell.)
	battle_content_root = Control.new()
	battle_content_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var battle_view: Vector2 = get_viewport().get_visible_rect().size
	battle_grid_origin = Vector2(roundf((battle_view.x - BATTLE_GRID_FOOTPRINT_PX) / 2.0), BATTLE_GRID_TOP)
	battle_content_root.position = Vector2.ZERO
	battle_panel.add_child(battle_content_root)

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
			battle_content_root.add_child(rect)
			battle_tile_rects[t] = rect

			# The terrain art tile, drawn over the border-color rect above --
			# scaled to fully fill the cell rather than kept-aspect, since a
			# terrain tile should read as ground, not a padded icon.
			var tile_icon := TextureRect.new()
			tile_icon.pivot_offset = Vector2.ZERO
			tile_icon.stretch_mode = TextureRect.STRETCH_SCALE
			tile_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tile_icon.texture = grass_animated_texture
			battle_content_root.add_child(tile_icon)
			battle_tile_icons[t] = tile_icon

			var marker := Label.new()
			marker.add_theme_font_size_override("font_size", 18)
			marker.visible = false
			battle_content_root.add_child(marker)
			battle_tile_markers[t] = marker

	# The tiles a hovered unit could walk to (or the mover's own reach in move mode): drawn over the ground and under the units.
	for i in MAX_BATTLE_GRID_SIZE * MAX_BATTLE_GRID_SIZE:
		var range_rect := Panel.new()
		range_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		range_rect.visible = false
		battle_content_root.add_child(range_rect)
		battle_range_rects.append(range_rect)

	# The player's own "@" marker used to double up as battle_unit_markers[0]
	# (with battle_unit_icons[0] reserved, unused, for a single ally icon) --
	# now that up to 4 companions (3 party slots + 1 wolf) need their own
	# icons at once, that one leftover slot doesn't fit anymore. Dedicated
	# label instead, and the enemy pool below goes back to a clean 1:1
	# mapping with no reserved slot.
	player_marker = Label.new()
	player_marker.add_theme_font_size_override("font_size", 24)
	player_marker.visible = false
	battle_content_root.add_child(player_marker)

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
		battle_content_root.add_child(icon)
		battle_unit_icons.append(icon)

	for i in MAX_BATTLE_UNITS:
		var unit_marker := Label.new()
		unit_marker.add_theme_font_size_override("font_size", 24)
		unit_marker.visible = false
		battle_content_root.add_child(unit_marker)
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
		battle_content_root.add_child(aware_marker)
		battle_unit_aware_markers.append(aware_marker)

	# Hover-LOS overlay tiles (see show_sight_tiles/hide_sight_tiles), sized
	# generously for the largest grid (MAX_BATTLE_GRID_SIZE^2, same bound the
	# terrain tile pool elsewhere in this file already uses).
	for i in MAX_BATTLE_GRID_SIZE * MAX_BATTLE_GRID_SIZE:
		var sight_rect := ColorRect.new()
		sight_rect.color = Color(1.0, 0.95, 0.4, 0.28)
		sight_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sight_rect.visible = false
		battle_content_root.add_child(sight_rect)
		battle_sight_tile_rects.append(sight_rect)

	# Companion icons: not click-targetable (plain TextureRect, unlike the
	# enemy pool above) -- allies now stand on their own real battle tile
	# (see Main.gd:battle_allies) rather than a fixed stacked slot, so this
	# pool just needs to be big enough for the max possible simultaneous
	# allies: a full party of 4 plus the 1 slot Wolf Fang adds for a wolf. Each
	# also gets a small health-bar background/fill pair, drawn under its
	# icon.
	for i in MAX_BATTLE_ALLIES:
		var ally_icon := TextureRect.new()
		ally_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ally_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ally_icon.visible = false
		battle_content_root.add_child(ally_icon)
		battle_ally_icons.append(ally_icon)

		var hp_bg := ColorRect.new()
		hp_bg.color = Color(0.15, 0.1, 0.1)
		hp_bg.visible = false
		battle_content_root.add_child(hp_bg)
		battle_ally_hp_bg.append(hp_bg)

		var hp_fill := ColorRect.new()
		hp_fill.color = Color(0.3, 0.85, 0.3)
		hp_fill.visible = false
		battle_content_root.add_child(hp_fill)
		battle_ally_hp_fill.append(hp_fill)

	# Pokemon-Conquest-style path arrows for the current pending move -- more
	# than enough slots for any realistic move range.
	for i in 8:
		var trail_marker := Label.new()
		trail_marker.add_theme_font_size_override("font_size", 20)
		trail_marker.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
		trail_marker.visible = false
		battle_content_root.add_child(trail_marker)
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
	battle_content_root.add_child(battle_status_label)

	# HP row: heart glyph, then bar, then the numbers -- same bg/fill
	# ColorRect-pair idiom the battle ally health bars use.
	battle_hp_heart_label = Label.new()
	battle_hp_heart_label.text = "♥"
	battle_hp_heart_label.position = Vector2(20, 39)
	battle_hp_heart_label.add_theme_font_size_override("font_size", 16)
	battle_hp_heart_label.add_theme_color_override("font_color", HEALTH_BAR_FILL_COLOR)
	battle_content_root.add_child(battle_hp_heart_label)

	battle_hp_bar_bg = ColorRect.new()
	battle_hp_bar_bg.color = HEALTH_BAR_BG_COLOR
	battle_hp_bar_bg.position = Vector2(36, 43)
	battle_hp_bar_bg.size = Vector2(95, 12)
	battle_content_root.add_child(battle_hp_bar_bg)

	battle_hp_bar_fill = ColorRect.new()
	battle_hp_bar_fill.color = HEALTH_BAR_FILL_COLOR
	battle_hp_bar_fill.position = Vector2(36, 43)
	battle_hp_bar_fill.size = Vector2(95, 12)
	battle_content_root.add_child(battle_hp_bar_fill)

	battle_hp_number_label = Label.new()
	battle_hp_number_label.position = Vector2(136, 39)
	battle_hp_number_label.add_theme_font_size_override("font_size", 15)
	battle_hp_number_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.75))
	battle_content_root.add_child(battle_hp_number_label)

	# Stamina row: same idiom, no icon -- bar starts at the same x as the HP
	# bar (below the heart glyph's slot) so the two rows stay column-aligned.
	battle_stamina_bar_bg = ColorRect.new()
	battle_stamina_bar_bg.color = STAMINA_BAR_BG_COLOR
	battle_stamina_bar_bg.position = Vector2(206, 43)
	battle_stamina_bar_bg.size = Vector2(95, 12)
	battle_content_root.add_child(battle_stamina_bar_bg)

	battle_stamina_bar_fill = ColorRect.new()
	battle_stamina_bar_fill.color = STAMINA_BAR_FILL_COLOR
	battle_stamina_bar_fill.position = Vector2(206, 43)
	battle_stamina_bar_fill.size = Vector2(95, 12)
	battle_content_root.add_child(battle_stamina_bar_fill)

	battle_stamina_number_label = Label.new()
	battle_stamina_number_label.position = Vector2(306, 39)
	battle_stamina_number_label.add_theme_font_size_override("font_size", 15)
	battle_stamina_number_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	battle_content_root.add_child(battle_stamina_number_label)

	# Everything that used to be battle_status_label's 2nd+ lines (Target/
	# Shield/BERSERK) -- a separate label now that the bars sit where those
	# lines used to start, positioned just above the grid's own top edge
	# (battle_grid_origin.y == 60).
	battle_status_label2 = Label.new()
	battle_status_label2.position = Vector2(20, 58)
	battle_status_label2.add_theme_font_size_override("font_size", 18)
	battle_status_label2.add_theme_color_override("font_color", Color(1, 1, 1))
	battle_content_root.add_child(battle_status_label2)

	battle_log_label = Label.new()
	battle_log_label.position = Vector2(400, 60)
	battle_log_label.add_theme_font_size_override("font_size", 15)
	battle_log_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	battle_content_root.add_child(battle_log_label)

	battle_description_label = Label.new()
	battle_description_label.position = Vector2(20, 470)
	battle_description_label.size = Vector2(560, 40)
	battle_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	battle_description_label.add_theme_font_size_override("font_size", 14)
	battle_description_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.6))
	battle_content_root.add_child(battle_description_label)

	_build_battle_menus()

	# First-ever-battle tutorial hint bubble + its Skip control -- see
	# Main.gd's tutorial_active/tutorial_step for the sequencing logic that
	# drives show_battle_hint/hide_battle_hint below. Both live as children
	# of battle_panel so they fade in/out with it for free.
	battle_hint_panel = Panel.new()
	battle_hint_panel.size = Vector2(220, 50)
	battle_hint_panel.visible = false
	battle_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle_hint_panel.add_theme_stylebox_override("panel", _battle_box(PANEL_BG, Color(1.0, 0.9, 0.2, 1.0), 2, BattleStyleScript.CORNER, true))
	battle_panel.add_child(battle_hint_panel)

	battle_hint_label = Label.new()
	battle_hint_label.position = Vector2(8, 6)
	battle_hint_label.size = Vector2(204, 38)
	battle_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	battle_hint_label.add_theme_font_size_override("font_size", 14)
	battle_hint_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	battle_hint_panel.add_child(battle_hint_label)

	battle_tutorial_skip_button = Button.new()
	battle_tutorial_skip_button.text = "Skip Tutorial"
	battle_tutorial_skip_button.visible = false
	battle_tutorial_skip_button.position = Vector2(get_viewport().get_visible_rect().size.x - 160, 76)
	battle_tutorial_skip_button.pressed.connect(func(): tutorial_skip_pressed.emit())
	_add_hover_color(battle_tutorial_skip_button)
	_style_standard_button(battle_tutorial_skip_button)
	_round_button(battle_tutorial_skip_button)
	battle_panel.add_child(battle_tutorial_skip_button)

	# Always visible during battle regardless of menu state or whose turn it
	# is -- a read-only lookup (BeastiaryPanel.gd pauses the game while
	# open), so there's no turn-order reason to hide it the way every real
	# action button already is.
	battle_beastiary_button = Button.new()
	battle_beastiary_button.text = "Beastiary"
	battle_beastiary_button.position = Vector2(get_viewport().get_visible_rect().size.x - 160, 20)
	battle_beastiary_button.pressed.connect(func(): beastiary_pressed.emit())
	_add_hover_color(battle_beastiary_button)
	_style_standard_button(battle_beastiary_button)
	_round_button(battle_beastiary_button)
	battle_panel.add_child(battle_beastiary_button)

	# The turn order runs along the top, centred (anchored to the middle and growing both ways as units are added).
	turn_order_box = HBoxContainer.new()
	turn_order_box.anchor_left = 0.5
	turn_order_box.anchor_right = 0.5
	turn_order_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	turn_order_box.offset_top = 14.0
	turn_order_box.add_theme_constant_override("separation", 5)
	turn_order_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	turn_order_box.visible = false
	battle_panel.add_child(turn_order_box)

	_build_battle_shell()

# --- The redesigned battle screen ---------------------------------------------------------------------------------
# Built once, after the older pieces above, and it re-places them: the party cards down the left, a plate over every unit,
# a bar along the bottom with the turn line and the key hints. The old top-left HP/stamina readouts and the battle log are
# retired -- the hero's card and plate carry that now, and the log lives on as history (battle_log_lines).
func _build_battle_shell() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var bar_y: float = view.y - 14.0 - BATTLE_BAR_H
	var grid_bottom: float = battle_grid_origin.y + BATTLE_GRID_FOOTPRINT_PX
	for n in [battle_hp_heart_label, battle_hp_bar_bg, battle_hp_bar_fill, battle_hp_number_label, battle_stamina_bar_bg, battle_stamina_bar_fill, battle_stamina_number_label, battle_log_label]:
		n.visible = false

	# The grid sits on a rounded board, so the field reads as one soft shape rather than a hard square block.
	var board := Panel.new()
	board.position = battle_grid_origin - Vector2(8, 8)
	board.size = Vector2(BATTLE_GRID_FOOTPRINT_PX + 16.0, BATTLE_GRID_FOOTPRINT_PX + 16.0)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_theme_stylebox_override("panel", _battle_box(Color(0.04, 0.04, 0.07, 0.8), Color(0.35, 0.28, 0.14), 1, BattleStyleScript.CORNER, true))
	battle_content_root.add_child(board)
	battle_content_root.move_child(board, 0)
	# The bottom bar: whose turn it is on the left, the keys on the right.
	var bar := Panel.new()
	bar.position = Vector2(BATTLE_CARD_X, bar_y)
	bar.size = Vector2(view.x - BATTLE_CARD_X * 2.0, BATTLE_BAR_H)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("panel", _battle_box(PANEL_BG, Color(0.35, 0.28, 0.14), 1, BattleStyleScript.CORNER_SMALL + 3))
	battle_content_root.add_child(bar)
	battle_content_root.move_child(bar, 0)
	battle_status_label.position = Vector2(BATTLE_CARD_X + 12.0, bar_y + 3.0)
	battle_status_label.add_theme_font_size_override("font_size", 16)
	battle_status_label.add_theme_color_override("font_color", BATTLE_TEXT)
	battle_key_hint_label = Label.new()
	battle_key_hint_label.position = Vector2(view.x * 0.38, bar_y + 6.0)
	battle_key_hint_label.size = Vector2(view.x * 0.62 - BATTLE_CARD_X - 12.0, 20.0)
	battle_key_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	battle_key_hint_label.add_theme_font_size_override("font_size", 13)
	battle_key_hint_label.add_theme_color_override("font_color", BATTLE_DIM)
	battle_key_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle_content_root.add_child(battle_key_hint_label)

	# Hover text for the menu buttons sits just above the bar; the Target/Shield/Berserk lines go in the right column.
	battle_description_label.position = Vector2(BATTLE_MENU_X, bar_y - 24.0)
	battle_description_label.size = Vector2(view.x - BATTLE_MENU_X - BATTLE_CARD_X, 22.0)
	battle_description_label.add_theme_font_size_override("font_size", 13)
	battle_description_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.55))
	var grid_right: float = battle_grid_origin.x + BATTLE_GRID_FOOTPRINT_PX
	battle_status_label2.position = Vector2(grid_right + 16.0, bar_y - 104.0)
	battle_status_label2.size = Vector2(view.x - grid_right - 16.0 - BATTLE_CARD_X, 96.0)
	battle_status_label2.autowrap_mode = TextServer.AUTOWRAP_WORD
	battle_status_label2.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	battle_status_label2.add_theme_font_size_override("font_size", 14)
	battle_status_label2.add_theme_color_override("font_color", BATTLE_TEXT)

	# The action lists float beside the acting unit (_place_menu); the two prompts that interrupt an enemy's turn stay a row of
	# buttons under the grid.
	for box in [battle_evasion_submenu_box, battle_confirm_box]:
		box.position = Vector2(BATTLE_MENU_X, grid_bottom + 10.0)

	# Party cards, and a plate over every unit.
	for i in BATTLE_CARD_SLOTS:
		battle_party_cards.append(_make_party_card(i))
	battle_hero_plate = _make_plate()
	for i in MAX_BATTLE_ALLIES:
		battle_ally_plates.append(_make_plate())
	for i in MAX_BATTLE_UNITS:
		battle_enemy_plates.append(_make_plate())
	# The lists float above everything on the grid, the plates included.
	for key in battle_menus:
		battle_content_root.move_child(battle_menus[key].panel, -1)
	_build_battle_overlays()

# --- The action menus -------------------------------------------------------------------------------------------
# Every menu is a short framed list that floats beside the acting unit; picking an entry that opens another list swaps the
# first for the second, which carries a small round back button on its top-left corner (the keyboard's X does the same).
const BATTLE_MENU_ROW_H := 34.0
const BATTLE_MENU_PAD := 5.0

func _list_stylebox(bg: Color, lit: bool) -> StyleBoxFlat:
	# A softly rounded highlight (a thin gold edge when lit) inside the list's frame.
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(BattleStyleScript.CORNER_SMALL)
	sb.anti_aliasing = true
	if lit:
		sb.border_color = Color(BATTLE_GOLD.r, BATTLE_GOLD.g, BATTLE_GOLD.b, 0.75)
		sb.set_border_width_all(1)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	return sb

# A flat list entry: no box until it is hovered or focused, then a lit bar on its left edge.
func _style_list_button(button: Button) -> void:
	var clear := _list_stylebox(Color(0, 0, 0, 0), false)
	var lit := _list_stylebox(Color(0.2, 0.16, 0.08, 0.96), true)
	button.add_theme_stylebox_override("normal", clear)
	button.add_theme_stylebox_override("hover", lit)
	button.add_theme_stylebox_override("pressed", lit)
	button.add_theme_stylebox_override("focus", lit)
	button.add_theme_stylebox_override("disabled", clear)
	button.add_theme_color_override("font_color", BATTLE_TEXT)
	button.add_theme_color_override("font_disabled_color", Color(0.42, 0.4, 0.36))
	button.add_theme_font_size_override("font_size", 16)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT

func _make_back_circle(on_press: Callable) -> Button:
	var back := Button.new()
	back.text = "‹"
	back.size = Vector2(28, 28)
	back.focus_mode = Control.FOCUS_NONE
	back.tooltip_text = "Back"
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.22, 0.18, 0.09) if state == "hover" else Color(0.09, 0.08, 0.12)
		sb.border_color = BATTLE_GOLD
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(14)
		back.add_theme_stylebox_override(state, sb)
	back.add_theme_color_override("font_color", BATTLE_GOLD)
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(on_press)
	return back

# A framed list. {panel, list, back}: `back` is the round button on the panel's top-left corner (null for the root list).
func _make_menu_list(width: float, on_back: Callable = Callable()) -> Dictionary:
	var panel := Panel.new()
	panel.size = Vector2(width, BATTLE_MENU_ROW_H + BATTLE_MENU_PAD * 2.0)
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _battle_box(PANEL_BG, PANEL_BORDER, 1, BattleStyleScript.CORNER, true))
	battle_content_root.add_child(panel)
	var list := VBoxContainer.new()
	list.position = Vector2(BATTLE_MENU_PAD, BATTLE_MENU_PAD)
	list.add_theme_constant_override("separation", 0)
	panel.add_child(list)
	var menu := {"panel": panel, "list": list, "back": null, "min_w": width}
	if on_back.is_valid():
		var back := _make_back_circle(on_back)
		back.position = Vector2(-13, -13)
		panel.add_child(back)
		menu["back"] = back
	return menu

func _menu_button(list: Control, text: String, description: String, on_press: Callable = Callable(), focusable: bool = true) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, BATTLE_MENU_ROW_H)
	_setup_hover_button(button, description, battle_description_label, focusable)
	_style_list_button(button)
	list.add_child(button)
	if on_press.is_valid():
		button.pressed.connect(on_press)
	return button

func _build_battle_menus() -> void:
	# The hero's root list: Attack opens the attack list, Strategy the strategy list, Item drinks a potion.
	var main := _make_menu_list(150.0)
	battle_menus["main"] = main
	battle_main_menu_box = main.panel
	for action in [
		["Attack", "fight", UI_TEXT["battle.main.fight"]],
		["Strategy", "strategy", UI_TEXT["battle.main.strategy"]],
		["Item", "item", UI_TEXT["battle.main.item"]],
	]:
		battle_main_buttons[action[1]] = _menu_button(main.list, action[0], action[2], func(): battle_main_action.emit(action[1]))

	# Strategy: everything that is not an attack -- Move (which does not end the turn), Defend, Taunt, Stealth, the Guardian's
	# Skill, Flee. Taunt and Stealth are the old Tactics pair; they still emit through battle_tactics_action.
	var strat := _make_menu_list(190.0, func(): battle_main_action.emit("main_back"))
	battle_menus["strategy"] = strat
	battle_strategy_menu_box = strat.panel
	battle_main_buttons["move"] = _menu_button(strat.list, "Move", UI_TEXT["battle.main.move"], func(): battle_main_action.emit("move"))
	battle_main_buttons["defend"] = _menu_button(strat.list, "Defend", UI_TEXT["battle.main.defend"], func(): battle_main_action.emit("defend"))
	battle_tactics_buttons["taunt"] = _menu_button(strat.list, "Taunt", UI_TEXT["battle.tactics.taunt"], func(): battle_tactics_action.emit("taunt"))
	battle_tactics_buttons["stealth"] = _menu_button(strat.list, "Stealth", UI_TEXT["battle.tactics.stealth"], func(): battle_tactics_action.emit("stealth"))
	battle_main_buttons["skill"] = _menu_button(strat.list, "Skill", UI_TEXT["battle.main.skill"], func(): battle_main_action.emit("skill"))
	battle_main_buttons["flee"] = _menu_button(strat.list, "Flee", UI_TEXT["battle.main.flee"], func(): battle_main_action.emit("flee"))

	# The attack list: the plain attack, the heavy one, the weapon's three specials, Mine (Hand Picks), and the arrows (Bow).
	var fight := _make_menu_list(250.0, func(): battle_fight_action.emit("back"))
	battle_menus["fight"] = fight
	battle_fight_submenu_box = fight.panel
	for action in [
		["Attack", "attack", UI_TEXT["battle.fight.attack"]],
		["Heavy Attack", "heavy", UI_TEXT["battle.fight.heavy"] % WeaponsScript.HEAVY_STAMINA_COST],
		["Special 1", "special_0", ""],
		["Special 2", "special_1", ""],
		["Special 3", "special_2", ""],
		["Mine", "mine", UI_TEXT["battle.fight.mine"]],
	]:
		battle_fight_buttons[action[1]] = _menu_button(fight.list, action[0], action[2], func(): battle_fight_action.emit(action[1]))
	battle_fight_buttons["arrow"] = _menu_button(fight.list, "Arrows", UI_TEXT["battle.main.arrow"], func(): battle_main_action.emit("arrow"))
	battle_fight_buttons["back"] = fight.back
	# Resting the mouse (or the focus) on an attack shows what it would do to the target.
	for key in ["attack", "heavy", "special_0", "special_1", "special_2"]:
		var attack_button: Button = battle_fight_buttons[key]
		attack_button.mouse_entered.connect(func(): action_previewed.emit(key))
		attack_button.focus_entered.connect(func(): action_previewed.emit(key))
		attack_button.mouse_exited.connect(func(): action_preview_cleared.emit())
		attack_button.focus_exited.connect(func(): action_preview_cleared.emit())

	var arrow := _make_menu_list(200.0, func(): battle_arrow_action.emit("back"))
	battle_menus["arrow"] = arrow
	battle_arrow_submenu_box = arrow.panel
	for action in [["Flame", "flame"], ["Freeze", "freeze"], ["Bomb", "bomb"]]:
		battle_arrow_buttons[action[1]] = _menu_button(arrow.list, action[0], "", func(): battle_arrow_action.emit(action[1]))
	battle_arrow_buttons["back"] = arrow.back

	# Moving: Confirm, with the round button on the corner as Cancel (hero and members alike). Neither takes focus: the
	# arrow keys are for walking the unit, Z confirms and X cancels.
	var move := _make_menu_list(150.0, func(): battle_move_action.emit("cancel"))
	battle_menus["move"] = move
	battle_move_submenu_box = move.panel
	battle_move_buttons["confirm"] = _menu_button(move.list, "Confirm", UI_TEXT["battle.move.confirm"], func(): battle_move_action.emit("confirm"), false)
	battle_move_buttons["cancel"] = move.back
	move.back.tooltip_text = "Cancel: undo this move"

	# A member's root list: Attack, Magic (only if it has spells), Strategy.
	var ally_main := _make_menu_list(150.0)
	battle_menus["ally_main"] = ally_main
	battle_ally_menu_box = ally_main.panel
	for action in [
		["Attack", "attack", "open_attack"],
		["Magic", "magic", "open_magic"],
		["Strategy", "strategy", "open_strategy"],
	]:
		battle_ally_buttons[action[0].to_lower()] = _menu_button(ally_main.list, action[0], UI_TEXT["battle.ally." + action[2]], func(): battle_ally_action.emit(action[2]))

	# A member's attack / magic / strategy list: one pool of buttons, relabelled every refresh. Each carries the action it sends.
	var ally_list := _make_menu_list(260.0, func(): battle_ally_action.emit("back"))
	battle_menus["ally_list"] = ally_list
	battle_ally_special_box = ally_list.panel
	battle_ally_special_back = ally_list.back
	for i in ALLY_SPECIAL_SLOTS:
		var special_button := _menu_button(ally_list.list, "", "")
		special_button.pressed.connect(func(): battle_ally_action.emit(str(special_button.get_meta("action", ""))))
		special_button.mouse_entered.connect(func(): action_previewed.emit("ally:" + str(special_button.get_meta("action", ""))))
		special_button.focus_entered.connect(func(): action_previewed.emit("ally:" + str(special_button.get_meta("action", ""))))
		special_button.mouse_exited.connect(func(): action_preview_cleared.emit())
		special_button.focus_exited.connect(func(): action_preview_cleared.emit())
		battle_ally_special_buttons.append(special_button)

	# The friendly-target picker (Channel: who gets the mana; Revival Blessing: who stands up; Summon the Dead: how many). A
	# long list wraps into more columns.
	var pick := _make_menu_list(240.0, func(): battle_ally_action.emit("back"))
	battle_menus["ally_pick"] = pick
	battle_ally_pick_box = pick.panel
	battle_ally_pick_back = pick.back
	battle_ally_pick_grid = GridContainer.new()
	battle_ally_pick_grid.position = Vector2(BATTLE_MENU_PAD, BATTLE_MENU_PAD)
	battle_ally_pick_grid.add_theme_constant_override("h_separation", 0)
	battle_ally_pick_grid.add_theme_constant_override("v_separation", 0)
	pick.panel.add_child(battle_ally_pick_grid)
	pick.list.visible = false
	for i in ALLY_PICK_SLOTS:
		var pick_button := Button.new()
		pick_button.custom_minimum_size = Vector2(228, BATTLE_MENU_ROW_H)
		pick_button.pressed.connect(func(): battle_ally_action.emit("pick_%d" % i))
		_style_list_button(pick_button)
		battle_ally_pick_grid.add_child(pick_button)
		battle_ally_pick_buttons.append(pick_button)

	# Phantom Guard's evasion dodge-roll: shown mid-"enemy" turn, while the attacker that just missed is paused waiting on the
	# player to pick one of up to 3 directions relative to it. These two prompts stay a row of buttons along the bottom; their
	# buttons are focusable (Z activates the focused one).
	battle_evasion_submenu_box = HBoxContainer.new()
	battle_evasion_submenu_box.add_theme_constant_override("separation", 8)
	battle_evasion_submenu_box.visible = false
	battle_content_root.add_child(battle_evasion_submenu_box)
	for entry in [
		["back", "Dodge Back", UI_TEXT["battle.evasion.back"]],
		["left", "Dodge Left", UI_TEXT["battle.evasion.left"]],
		["right", "Dodge Right", UI_TEXT["battle.evasion.right"]],
	]:
		var button := Button.new()
		button.text = entry[1]
		button.pressed.connect(func(): battle_evasion_direction_pressed.emit(entry[0]))
		_setup_hover_button(button, entry[2], battle_description_label)
		_style_standard_button(button)
		_round_button(button)
		battle_evasion_submenu_box.add_child(button)
		battle_evasion_buttons[entry[0]] = button

	# Turtle Shell's water-push confirm -- the same row, never shown at once with the evasion one.
	battle_confirm_box = HBoxContainer.new()
	battle_confirm_box.add_theme_constant_override("separation", 8)
	battle_confirm_box.visible = false
	battle_content_root.add_child(battle_confirm_box)
	battle_confirm_yes_button = Button.new()
	battle_confirm_yes_button.pressed.connect(func(): battle_confirm_choice.emit(true))
	_style_standard_button(battle_confirm_yes_button)
	_round_button(battle_confirm_yes_button)
	battle_confirm_box.add_child(battle_confirm_yes_button)
	battle_confirm_no_button = Button.new()
	battle_confirm_no_button.pressed.connect(func(): battle_confirm_choice.emit(false))
	_style_standard_button(battle_confirm_no_button)
	_round_button(battle_confirm_no_button)
	battle_confirm_box.add_child(battle_confirm_no_button)

# Sizes a list to the entries showing now.
func _fit_menu(menu: Dictionary) -> void:
	var rows := 0
	var widest := 0.0
	for c in menu.list.get_children():
		if c.visible:
			rows += 1
			var button := c as Button
			if button != null:
				widest = maxf(widest, button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x)
	# Wide enough for its longest entry (the button's own margins are 12 and 8).
	var w: float = maxf(float(menu.min_w), widest + 20.0 + BATTLE_MENU_PAD * 2.0 + 6.0)
	menu.panel.size = Vector2(w, rows * BATTLE_MENU_ROW_H + BATTLE_MENU_PAD * 2.0)
	menu.list.size = Vector2(w - BATTLE_MENU_PAD * 2.0, rows * BATTLE_MENU_ROW_H)

# Floats a list beside the acting unit: on the side of it with more room, level with its tile, kept clear of the cards and the bar.
func _place_menu(menu: Dictionary, anchor_tile: Vector2i, grid_w: int) -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var panel: Control = menu.panel
	var tile_px: Vector2 = battle_grid_origin + Vector2(anchor_tile) * battle_tile_size
	var on_right_half: bool = anchor_tile.x * 2 >= grid_w
	var x: float = tile_px.x - panel.size.x - 8.0 if on_right_half else tile_px.x + battle_tile_size + 8.0
	x = clampf(x, BATTLE_CARD_X + BATTLE_CARD_W + 10.0, view.x - panel.size.x - 10.0)
	var bottom_limit: float = view.y - 14.0 - BATTLE_BAR_H - 30.0
	var y: float = clampf(tile_px.y - 4.0, BATTLE_GRID_TOP, maxf(BATTLE_GRID_TOP, bottom_limit - panel.size.y))
	panel.position = Vector2(roundf(x), roundf(y))

func _battle_label(parent: Control, pos: Vector2, size_px: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

# A rounded box in the battle screen's look (see BattleStyle): `radius` defaults to the panel roundness.
func _battle_box(bg: Color, border: Color, border_width: int, radius: int = BattleStyleScript.CORNER, shadow: bool = false) -> StyleBoxFlat:
	return BattleStyleScript.box(bg, border, border_width, radius, shadow)

# A button given the battle screen's rounded look (over whatever _style_standard_button gave it).
func _round_button(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb: StyleBoxFlat = button.get_theme_stylebox(state).duplicate()
		sb.set_corner_radius_all(BattleStyleScript.CORNER_SMALL + 1)
		sb.anti_aliasing = true
		button.add_theme_stylebox_override(state, sb)

func _bar_style(color: Color, height: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(ceil(height / 2.0)))
	sb.anti_aliasing = true
	return sb

# A bar drawn from two rounded Panels (the track and the fill); returns both and its full width.
func _battle_bar(parent: Control, pos: Vector2, size_px: Vector2, track: Color, fill: Color) -> Dictionary:
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", _bar_style(track, size_px.y))
	bg.position = pos
	bg.size = size_px
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	var fg := Panel.new()
	fg.add_theme_stylebox_override("panel", _bar_style(fill, size_px.y))
	fg.position = pos
	fg.size = size_px
	fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(fg)
	return {"bg": bg, "fill": fg, "width": size_px.x, "height": size_px.y}

func _set_bar_color(bar: Dictionary, color: Color) -> void:
	var sb: StyleBoxFlat = bar.fill.get_theme_stylebox("panel")
	if sb.bg_color != color:
		sb.bg_color = color

func _set_battle_bar(bar: Dictionary, ratio: float, shown: bool = true) -> void:
	bar.bg.visible = shown
	bar.fill.visible = shown
	bar.fill.size = Vector2(float(bar.width) * clampf(ratio, 0.0, 1.0), float(bar.height))

func _make_party_card(i: int) -> Dictionary:
	var panel := Panel.new()
	panel.position = Vector2(BATTLE_CARD_X, BATTLE_GRID_TOP + i * BATTLE_CARD_STEP)
	panel.size = Vector2(BATTLE_CARD_W, BATTLE_CARD_H)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.visible = false
	battle_content_root.add_child(panel)
	var card := {"panel": panel}
	# Hovering a card is hovering that unit; clicking it opens the unit's details.
	panel.mouse_entered.connect(func(): _card_hover(i))
	panel.mouse_exited.connect(func(): battle_card_hover_key = "")
	panel.gui_input.connect(func(event: InputEvent): _card_input(i, event))
	# The portrait: the hero is the blue "@", everyone else wears the icon the grid gives them.
	var frame := Panel.new()
	frame.position = Vector2(10, 12)
	frame.size = Vector2(46, 46)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", _battle_box(Color(0.05, 0.05, 0.08), BATTLE_ALLY_BLUE, 1, BattleStyleScript.CORNER_SMALL + 1))
	panel.add_child(frame)
	card["frame"] = frame
	card["at"] = _battle_label(frame, Vector2(11, 3), 30, BATTLE_ALLY_BLUE)
	card["at"].text = "@"
	var icon := TextureRect.new()
	icon.position = Vector2(3, 3)
	icon.size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(icon)
	card["icon"] = icon
	card["name"] = _battle_label(panel, Vector2(66, 4), 15, BATTLE_TEXT)
	card["level"] = _battle_label(panel, Vector2(168, 7), 11, BATTLE_DIM)
	card["hp_bar"] = _battle_bar(panel, Vector2(66, 30), Vector2(76, 9), HEALTH_BAR_BG_COLOR, HEALTH_BAR_FILL_COLOR)
	card["hp_text"] = _battle_label(panel, Vector2(148, 25), 12, Color(1.0, 0.75, 0.75))
	card["res_bar"] = _battle_bar(panel, Vector2(66, 48), Vector2(76, 7), STAMINA_BAR_BG_COLOR, STAMINA_BAR_FILL_COLOR)
	card["res_text"] = _battle_label(panel, Vector2(148, 43), 12, Color(0.7, 0.85, 1.0))
	card["status"] = _battle_label(panel, Vector2(10, 66), 12, BATTLE_GOLD)
	card["status"].size = Vector2(BATTLE_CARD_W - 16, 18)
	card["status"].clip_text = true
	card["tray"] = _make_status_tray(panel, Vector2(10, 65), 3)
	return card

# A row of small status pictures that sits ahead of a chip line. The slots are made once and stay hidden until a unit has a
# status with a picture to show in them.
func _make_status_tray(parent: Control, origin: Vector2, count: int) -> Array:
	var slots: Array = []
	for i in count:
		var slot: TextureRect = IconStripScript.new()
		slot.position = origin + Vector2(i * (STATUS_ICON_PX + 2.0), 0.0)
		slot.size = Vector2(STATUS_ICON_PX, STATUS_ICON_PX)
		slot.visible = false
		parent.add_child(slot)
		slots.append(slot)
	return slots

# Puts the statuses' pictures in a tray (each status with one, once, in order) and gives back the width they take, 0 with none.
func _fill_status_tray(slots: Array, statuses: Array) -> float:
	var ids: Array = BattleStatusesScript.ids_with_icons(statuses)
	for i in slots.size():
		if i < ids.size():
			UIIconsScript.show_status(slots[i], str(ids[i]))
		else:
			slots[i].show_strip(null)
	return mini(ids.size(), slots.size()) * (STATUS_ICON_PX + 2.0)

# A plate over a unit: a health bar with a thin resource bar under it (stamina or mana; none for a foe).
func _make_plate() -> Dictionary:
	var plate := {}
	plate["hp"] = _battle_bar(battle_content_root, Vector2.ZERO, Vector2(40, 6), Color(0.1, 0.03, 0.04, 0.92), HEALTH_BAR_FILL_COLOR)
	plate["res"] = _battle_bar(battle_content_root, Vector2.ZERO, Vector2(40, 3), Color(0.04, 0.06, 0.12, 0.92), STAMINA_BAR_FILL_COLOR)
	_set_battle_bar(plate.hp, 0.0, false)
	_set_battle_bar(plate.res, 0.0, false)
	return plate

# Puts a plate across the top of a unit's tile(s). res_ratio < 0 = no resource bar.
func _place_plate(plate: Dictionary, tile_origin: Vector2, span: float, hp_ratio: float, res_ratio: float, res_color: Color) -> void:
	var w: float = clampf(span * 0.7, 28.0, 64.0)
	var x: float = tile_origin.x + (span - w) / 2.0
	var y: float = tile_origin.y + 3.0
	plate.hp.bg.position = Vector2(x, y)
	plate.hp.fill.position = Vector2(x, y)
	plate.hp.width = w
	plate.hp.bg.size = Vector2(w, 6)
	_set_battle_bar(plate.hp, hp_ratio)
	plate.res.bg.position = Vector2(x, y + 7.0)
	plate.res.fill.position = Vector2(x, y + 7.0)
	plate.res.width = w
	plate.res.bg.size = Vector2(w, 3)
	_set_bar_color(plate.res, res_color)
	_set_battle_bar(plate.res, maxf(res_ratio, 0.0), res_ratio >= 0.0)

func _hide_plate(plate: Dictionary) -> void:
	_set_battle_bar(plate.hp, 0.0, false)
	_set_battle_bar(plate.res, 0.0, false)

# A unit's resource as a plate or card shows it: {ratio (-1 = none), color}. Casters show mana, everyone else stamina, and the
# Necromancer (whose mana is her HP) none.
func _unit_res(a: Dictionary) -> Dictionary:
	if int(a.get("max_mana", 0)) > 0 and not bool(a.get("hp_as_mana", false)):
		return {"ratio": float(a.get("mana", 0)) / float(a.max_mana), "color": BATTLE_MP_COLOR}
	if int(a.get("max_stamina", 0)) > 0:
		return {"ratio": float(a.get("stamina", 0)) / float(a.max_stamina), "color": STAMINA_BAR_FILL_COLOR}
	return {"ratio": -1.0, "color": STAMINA_BAR_FILL_COLOR}

# "Stealth (2)": a status as the card's chip line shows it.
func _status_chip_text(e: Dictionary) -> String:
	var detail: String = str(e.get("detail", ""))
	if detail.ends_with(" turns") or detail.ends_with(" turn"):
		return "%s (%s)" % [e.name, detail.split(" ")[0]]
	return "%s %s" % [e.name, detail] if detail != "" else str(e.name)

# The party cards: rows from Main.gd:_battle_party_rows -- the hero first, then every roster member.
func set_party_cards(rows: Array) -> void:
	battle_party_rows = rows
	for i in battle_party_cards.size():
		var c: Dictionary = battle_party_cards[i]
		c.panel.visible = i < rows.size()
		if i >= rows.size():
			continue
		var r: Dictionary = rows[i]
		var hero: bool = str(r.get("side", "")) == "hero"
		var acting: bool = bool(r.get("acting", false))
		var downed: bool = bool(r.get("downed", false))
		c.panel.add_theme_stylebox_override("panel", _battle_box(PANEL_BG, BATTLE_GOLD if acting else Color(0.36, 0.29, 0.15), 2 if acting else 1, BattleStyleScript.CORNER))
		c.at.visible = hero
		c.icon.visible = not hero
		if not hero:
			var is_wolf: bool = str(r.get("kind", "")) == "wolf"
			c.icon.texture = ENEMY_ICONS.get("Wolf", null) if is_wolf else BLADE_ALLY_ICON
			c.icon.modulate = Color(1, 1, 1) if is_wolf else r.get("tint", Color(1, 1, 1))
			if downed:
				c.icon.modulate = c.icon.modulate * Color(0.45, 0.45, 0.5, 0.7)
		c.name.text = str(r.get("name", "?"))
		c.name.add_theme_color_override("font_color", BATTLE_GOLD if acting else BATTLE_TEXT)
		c.level.text = "Lv %d" % int(r.get("level", 1))
		var max_hp: int = maxi(1, int(r.get("max_hp", 1)))
		_set_battle_bar(c.hp_bar, float(r.get("hp", 0)) / float(max_hp))
		c.hp_text.text = "%d/%d" % [int(r.get("hp", 0)), max_hp]
		var res_kind: String = str(r.get("res_kind", ""))
		var has_res: bool = res_kind != "" and int(r.get("max_res", 0)) > 0
		_set_battle_bar(c.res_bar, float(r.get("res", 0)) / float(maxi(1, int(r.get("max_res", 1)))), has_res)
		_set_bar_color(c.res_bar, BATTLE_MP_COLOR if res_kind == "MP" else STAMINA_BAR_FILL_COLOR)
		c.res_text.visible = has_res
		c.res_text.text = "%d/%d" % [int(r.get("res", 0)), int(r.get("max_res", 0))]
		c.res_text.add_theme_color_override("font_color", Color(0.78, 0.62, 1.0) if res_kind == "MP" else Color(0.7, 0.85, 1.0))
		var statuses: Array = r.get("statuses", [])
		var chips: Array = []
		var any_bad := false
		var tip_lines: Array = []
		for e in statuses:
			if chips.size() < 2:
				chips.append(_status_chip_text(e))
			if not bool(e.get("good", false)):
				any_bad = true
			tip_lines.append("%s: %s" % [e.name, e.desc])
		if statuses.size() > 2:
			chips.append("+%d" % (statuses.size() - 2))
		c.status.text = "  ".join(chips)
		c.status.add_theme_color_override("font_color", Color(1.0, 0.6, 0.45) if any_bad else BATTLE_GOLD)
		var tray_w: float = _fill_status_tray(c.tray, statuses)
		var text_x: float = 10.0 + (tray_w + 2.0 if tray_w > 0.0 else 0.0)
		c.status.position.x = text_x
		c.status.size.x = BATTLE_CARD_W - 6.0 - text_x
		# Hovering the card reads out what each status does.
		c.panel.tooltip_text = "\n".join(tip_lines)

# The bottom bar's key line for the menu showing now.
func _battle_key_hints(menu_state: String, in_ally_turn: bool, is_player_turn: bool, is_evasion_prompt: bool, is_confirm_prompt: bool) -> String:
	if is_evasion_prompt:
		return "Arrows  Choose a direction      Z  Roll"
	if is_confirm_prompt:
		return "Z  Confirm      X  Cancel"
	if not is_player_turn and not in_ally_turn:
		return ""
	if menu_state == "move":
		return "Arrows  Choose a tile      Z  Confirm      X  Cancel"
	if menu_state == "main":
		return "Arrows  Select      Z  Confirm      Tab  Inspect      H  History"
	return "Arrows  Select      Z  Confirm      X  Back      Tab  Inspect"

func _card_hover(i: int) -> void:
	if i >= battle_party_rows.size():
		return
	var row: Dictionary = battle_party_rows[i]
	battle_card_hover_key = "hero" if str(row.get("side", "")) == "hero" else "ally:%d" % int(row.get("index", 0))

func _card_input(i: int, event: InputEvent) -> void:
	if i >= battle_party_rows.size() or not (event is InputEventMouseButton) or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var row: Dictionary = battle_party_rows[i]
	unit_clicked.emit("hero" if str(row.get("side", "")) == "hero" else "ally", int(row.get("index", 0)))

# --- Hovering and clicking units ------------------------------------------------------------------------------------
# Hovering a unit (on the grid or its party card) raises a small popup over it and lights up where it could walk; clicking one
# opens the bigger details box at the side, where hovering a status reads what it does. Main.gd answers the signals (it owns
# the movement rules and the statuses) and calls show_unit_popup / show_unit_details / show_move_range.

# What is on this tile: "hero", "ally:<i>", "enemy:<i>" (an index into the lists last drawn), or "".
func _battle_unit_key_at(tile: Vector2i) -> String:
	if tile == battle_player_tile_now:
		return "hero"
	for i in battle_allies_now.size():
		if battle_allies_now[i].tile == tile:
			return "ally:%d" % i
	for i in battle_units_now.size():
		var u: Dictionary = battle_units_now[i]
		var span: int = int(u.get("size", 1))
		if tile.x >= u.tile.x and tile.x < u.tile.x + span and tile.y >= u.tile.y and tile.y < u.tile.y + span:
			return "enemy:%d" % i
	return ""

func _battle_mouse_tile() -> Vector2i:
	var rel: Vector2 = (battle_content_root.get_local_mouse_position() - battle_grid_origin) / battle_tile_size
	var tile := Vector2i(floori(rel.x), floori(rel.y))
	if tile.x < 0 or tile.y < 0 or tile.x >= battle_grid_size_now.x or tile.y >= battle_grid_size_now.y:
		return Vector2i(-1, -1)
	return tile

# Is the mouse over one of the floating lists or the details box (so it is not "over" the unit underneath)?
func _mouse_over_battle_overlay() -> bool:
	var mouse: Vector2 = get_viewport().get_mouse_position()
	for key in battle_menus:
		var panel: Control = battle_menus[key].panel
		if panel.visible and Rect2(panel.global_position, panel.size).has_point(mouse):
			return true
	if not battle_details.is_empty() and battle_details.panel.visible and Rect2(battle_details.panel.global_position, battle_details.panel.size).has_point(mouse):
		return true
	return false

var battle_card_hover_key := ""

func _track_battle_hover() -> void:
	if battle_panel == null or not battle_panel.visible:
		if battle_hover_key != "":
			battle_hover_key = ""
			unit_unhovered.emit()
		return
	var key := battle_card_hover_key
	if key == "" and not _mouse_over_battle_overlay():
		var tile: Vector2i = _battle_mouse_tile()
		if tile.x >= 0:
			key = _battle_unit_key_at(tile)
	if key == battle_hover_key:
		return
	battle_hover_key = key
	if key == "":
		unit_unhovered.emit()
	else:
		var parts: PackedStringArray = key.split(":")
		unit_hovered.emit(parts[0], int(parts[1]) if parts.size() > 1 else 0)

func _battle_click() -> void:
	if _mouse_over_battle_overlay() or battle_card_hover_key != "":
		return
	var tile: Vector2i = _battle_mouse_tile()
	if tile.x < 0:
		return
	var key: String = _battle_unit_key_at(tile)
	if key == "":
		unit_clicked.emit("none", 0)          # bare ground: close the details box
		return
	var parts: PackedStringArray = key.split(":")
	unit_clicked.emit(parts[0], int(parts[1]) if parts.size() > 1 else 0)

# The tiles a unit could walk to: blue for one of ours, red for a foe. An empty list clears them.
func show_move_range(tiles: Array, hostile: bool) -> void:
	var style: StyleBoxFlat = _range_style(hostile)
	for i in battle_range_rects.size():
		var rect: Panel = battle_range_rects[i]
		if i < tiles.size():
			# Inset a touch, so each lit tile is its own soft shape.
			rect.position = battle_grid_origin + Vector2(tiles[i]) * battle_tile_size + Vector2(2, 2)
			rect.size = Vector2(battle_tile_size - 4.0, battle_tile_size - 4.0)
			rect.add_theme_stylebox_override("panel", style)
			rect.visible = true
		else:
			rect.visible = false

func _range_style(hostile: bool) -> StyleBoxFlat:
	var key: String = "hostile" if hostile else "friendly"
	if not battle_range_styles.has(key):
		var base: Color = BATTLE_ENEMY_RED if hostile else BATTLE_ALLY_BLUE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(base.r, base.g, base.b, 0.30)
		sb.border_color = Color(base.r, base.g, base.b, 0.8)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(6)
		sb.anti_aliasing = true
		battle_range_styles[key] = sb
	return battle_range_styles[key]

# A row, as the popup and the details box take it: {side, name, level?, hp, max_hp, res, max_res, res_kind, statuses, note?}.
func _fill_unit_bars(p: Dictionary, row: Dictionary) -> void:
	var max_hp: int = maxi(1, int(row.get("max_hp", 1)))
	_set_battle_bar(p.hp_bar, float(row.get("hp", 0)) / float(max_hp))
	p.hp_text.text = "%d/%d HP" % [maxi(0, int(row.get("hp", 0))), max_hp]
	var res_kind: String = str(row.get("res_kind", ""))
	var has_res: bool = res_kind != "" and int(row.get("max_res", 0)) > 0
	_set_battle_bar(p.res_bar, float(row.get("res", 0)) / float(maxi(1, int(row.get("max_res", 1)))), has_res)
	_set_bar_color(p.res_bar, BATTLE_MP_COLOR if res_kind == "MP" else STAMINA_BAR_FILL_COLOR)
	p.res_text.visible = has_res
	p.res_text.text = "%d/%d %s" % [int(row.get("res", 0)), int(row.get("max_res", 0)), res_kind]
	p.res_text.add_theme_color_override("font_color", Color(0.78, 0.62, 1.0) if res_kind == "MP" else Color(0.7, 0.85, 1.0))

func _build_battle_overlays() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	# The popup over a hovered unit.
	var popup := Panel.new()
	popup.size = Vector2(184, 96)
	popup.visible = false
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_theme_stylebox_override("panel", _battle_box(PANEL_BG, PANEL_BORDER, 1, BattleStyleScript.CORNER, true))
	battle_panel.add_child(popup)
	battle_popup = {"panel": popup}
	battle_popup["name"] = _battle_label(popup, Vector2(8, 3), 15, BATTLE_GOLD)
	battle_popup["level"] = _battle_label(popup, Vector2(144, 6), 11, BATTLE_DIM)
	battle_popup["hp_bar"] = _battle_bar(popup, Vector2(8, 28), Vector2(88, 9), HEALTH_BAR_BG_COLOR, HEALTH_BAR_FILL_COLOR)
	battle_popup["hp_text"] = _battle_label(popup, Vector2(102, 24), 12, Color(1.0, 0.75, 0.75))
	battle_popup["res_bar"] = _battle_bar(popup, Vector2(8, 46), Vector2(88, 7), STAMINA_BAR_BG_COLOR, STAMINA_BAR_FILL_COLOR)
	battle_popup["res_text"] = _battle_label(popup, Vector2(102, 41), 12, Color(0.7, 0.85, 1.0))
	battle_popup["status"] = _battle_label(popup, Vector2(8, 62), 12, BATTLE_GOLD)
	battle_popup["status"].size = Vector2(170, 30)
	battle_popup["status"].autowrap_mode = TextServer.AUTOWRAP_WORD
	battle_popup["tray"] = _make_status_tray(popup, Vector2(8, 62), 4)

	# The details box a click opens, down the right-hand side.
	var grid_right: float = battle_grid_origin.x + BATTLE_GRID_FOOTPRINT_PX
	var box_w: float = view.x - grid_right - 16.0 - BATTLE_CARD_X
	var box := Panel.new()
	box.position = Vector2(grid_right + 16.0, BATTLE_GRID_TOP)
	box.size = Vector2(box_w, 220)
	box.visible = false
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.add_theme_stylebox_override("panel", _battle_box(PANEL_BG, PANEL_BORDER, 1, BattleStyleScript.CORNER, true))
	battle_panel.add_child(box)
	battle_details = {"panel": box}
	battle_details["name"] = _battle_label(box, Vector2(14, 8), 19, BATTLE_GOLD)
	battle_details["sub"] = _battle_label(box, Vector2(14, 34), 13, BATTLE_ALLY_BLUE)
	var close := Button.new()
	close.text = "x"
	close.size = Vector2(24, 24)
	close.position = Vector2(box_w - 32, 8)
	close.focus_mode = Control.FOCUS_NONE
	close.tooltip_text = "Close"
	_style_standard_button(close, 2)
	_round_button(close)
	close.pressed.connect(func(): unit_clicked.emit("none", 0))
	box.add_child(close)
	battle_details["hp_bar"] = _battle_bar(box, Vector2(14, 64), Vector2(box_w - 28, 10), HEALTH_BAR_BG_COLOR, HEALTH_BAR_FILL_COLOR)
	battle_details["hp_text"] = _battle_label(box, Vector2(14, 76), 13, Color(1.0, 0.75, 0.75))
	battle_details["res_bar"] = _battle_bar(box, Vector2(14, 102), Vector2(box_w - 28, 8), STAMINA_BAR_BG_COLOR, STAMINA_BAR_FILL_COLOR)
	battle_details["res_text"] = _battle_label(box, Vector2(14, 112), 13, Color(0.7, 0.85, 1.0))
	battle_details["note"] = _battle_label(box, Vector2(14, 104), 12, BATTLE_DIM)
	battle_details["caption"] = _battle_label(box, Vector2(14, 140), 11, BATTLE_DIM)
	battle_details["caption"].text = "STATUS EFFECTS"
	battle_details["rows"] = []
	for i in 8:
		var row := Control.new()
		row.position = Vector2(8, 160 + i * 38)
		row.size = Vector2(box_w - 16, 36)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.visible = false
		box.add_child(row)
		var mark := ColorRect.new()
		mark.color = BATTLE_GOLD
		mark.size = Vector2(8, 8)
		mark.position = Vector2(10, 14)
		mark.rotation = PI / 4.0
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(mark)
		# A status with a picture shows it (doubled) where the gold diamond would be, and its words move over to make room.
		var picture: TextureRect = IconStripScript.new()
		picture.position = Vector2(4, 2)
		picture.size = Vector2(32, 32)
		picture.visible = false
		row.add_child(picture)
		var name_label := _battle_label(row, Vector2(26, 2), 14, BATTLE_TEXT)
		var detail_label := _battle_label(row, Vector2(26, 19), 11, BATTLE_DIM)
		var entry := {"row": row, "mark": mark, "picture": picture, "name": name_label, "detail": detail_label, "desc": ""}
		row.mouse_entered.connect(func(): _show_status_tooltip(entry))
		row.mouse_exited.connect(_hide_status_tooltip)
		battle_details["rows"].append(entry)
	# The History button (key H) and the panel it opens in the same place: the last three turns, newest first.
	battle_history_button = Button.new()
	battle_history_button.text = "History (H)"
	battle_history_button.position = Vector2(view.x - 300, 20)
	battle_history_button.focus_mode = Control.FOCUS_NONE
	battle_history_button.pressed.connect(toggle_history)
	_add_hover_color(battle_history_button)
	battle_history_button.focus_mode = Control.FOCUS_NONE
	_style_standard_button(battle_history_button)
	_round_button(battle_history_button)
	battle_panel.add_child(battle_history_button)
	battle_history_panel = Panel.new()
	battle_history_panel.position = Vector2(grid_right + 16.0, BATTLE_GRID_TOP)
	battle_history_panel.size = Vector2(box_w, 430)
	battle_history_panel.visible = false
	battle_history_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	battle_history_panel.add_theme_stylebox_override("panel", _battle_box(PANEL_BG, PANEL_BORDER, 1, BattleStyleScript.CORNER, true))
	battle_panel.add_child(battle_history_panel)
	var history_title := _battle_label(battle_history_panel, Vector2(14, 8), 12, BATTLE_DIM)
	history_title.text = "THE LAST THREE TURNS"
	battle_history_text = RichTextLabel.new()
	battle_history_text.bbcode_enabled = true
	battle_history_text.position = Vector2(12, 32)
	battle_history_text.size = Vector2(box_w - 24, 388)
	battle_history_text.scroll_active = true
	battle_history_text.add_theme_font_size_override("normal_font_size", 13)
	battle_history_text.add_theme_font_size_override("bold_font_size", 13)
	battle_history_text.mouse_filter = Control.MOUSE_FILTER_PASS
	battle_history_panel.add_child(battle_history_text)

	# The damage chip over the enemy an attack would hit.
	var chip := Panel.new()
	chip.size = Vector2(176, 46)
	chip.visible = false
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", _battle_box(PANEL_BG, BATTLE_GOLD, 1, BattleStyleScript.CORNER_SMALL + 2, true))
	battle_panel.add_child(chip)
	battle_preview = {"panel": chip, "line1": _battle_label(chip, Vector2(10, 4), 14, BATTLE_TEXT), "line2": _battle_label(chip, Vector2(10, 23), 12, BATTLE_GOLD)}

	# What a hovered status does: a card to the left of the box.
	var tip := Panel.new()
	tip.size = Vector2(250, 60)
	tip.visible = false
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.add_theme_stylebox_override("panel", _battle_box(PANEL_BG, BATTLE_GOLD, 1, BattleStyleScript.CORNER_SMALL + 2, true))
	battle_panel.add_child(tip)
	battle_status_tooltip = {"panel": tip, "text": _battle_label(tip, Vector2(10, 7), 13, BATTLE_TEXT)}
	battle_status_tooltip["text"].size = Vector2(230, 46)
	battle_status_tooltip["text"].autowrap_mode = TextServer.AUTOWRAP_WORD

func show_unit_popup(row: Dictionary, tile: Vector2i, span: int = 1) -> void:
	var p: Dictionary = battle_popup
	var statuses: Array = row.get("statuses", [])
	var has_res: bool = str(row.get("res_kind", "")) != "" and int(row.get("max_res", 0)) > 0
	p.name.text = str(row.get("name", "?"))
	p.name.add_theme_color_override("font_color", BATTLE_ENEMY_RED if str(row.get("side", "")) == "enemy" else BATTLE_GOLD)
	p.level.text = ("Lv %d" % int(row.level)) if int(row.get("level", 0)) > 0 else ""
	_fill_unit_bars(p, row)
	var chips: Array = []
	for e in statuses:
		chips.append(_status_chip_text(e))
	p.status.text = "  ".join(chips)
	var status_y: float = 62.0 if has_res else 46.0
	var tray_w: float = _fill_status_tray(p.tray, statuses)
	for slot in p.tray:
		slot.position.y = status_y - 1.0
	var text_x: float = 8.0 + (tray_w + 2.0 if tray_w > 0.0 else 0.0)
	p.status.position = Vector2(text_x, status_y)
	# The chip line wraps at about 25 letters across the whole card (fewer when pictures take some of the width); the card grows a line for each.
	var per_line: float = 25.0 * (178.0 - text_x) / 170.0
	var chip_lines: int = ceili(float(p.status.text.length()) / per_line) if chips.size() > 0 else 0
	p.status.size = Vector2(178.0 - text_x, maxf(16.0, chip_lines * 15.0))
	var height: float = (62.0 if has_res else 46.0) + (chip_lines * 15.0 + 6.0 if chips.size() > 0 else 0.0) + 8.0
	p.panel.size = Vector2(184, height)
	var origin: Vector2 = battle_grid_origin + Vector2(tile) * battle_tile_size
	var x: float = origin.x + battle_tile_size * span / 2.0 - 92.0
	var y: float = origin.y - height - 6.0
	if y < 4.0:
		y = origin.y + battle_tile_size * span + 6.0
	var view: Vector2 = get_viewport().get_visible_rect().size
	p.panel.position = Vector2(clampf(x, 8.0, view.x - 192.0), y)
	p.panel.visible = true

func hide_unit_popup() -> void:
	if not battle_popup.is_empty():
		battle_popup.panel.visible = false

# The damage chip over the enemy an attack would hit.
func show_damage_preview(tile: Vector2i, span: int, line1: String, line2: String) -> void:
	var p: Dictionary = battle_preview
	p.line1.text = line1
	p.line2.text = line2
	p.line2.visible = line2 != ""
	p.panel.size = Vector2(176, 46 if line2 != "" else 28)
	var origin: Vector2 = battle_grid_origin + Vector2(tile) * battle_tile_size
	var view: Vector2 = get_viewport().get_visible_rect().size
	var y: float = origin.y - p.panel.size.y - 4.0
	if y < 4.0:
		y = origin.y + battle_tile_size * span + 4.0
	p.panel.position = Vector2(clampf(origin.x + battle_tile_size * span / 2.0 - 88.0, 8.0, view.x - 184.0), y)
	p.panel.visible = true

func hide_damage_preview() -> void:
	if not battle_preview.is_empty():
		battle_preview.panel.visible = false

func details_open() -> bool:
	return not battle_details.is_empty() and battle_details.panel.visible

func show_unit_details(row: Dictionary) -> void:
	var d: Dictionary = battle_details
	var enemy: bool = str(row.get("side", "")) == "enemy"
	d.name.text = str(row.get("name", "?"))
	d.sub.text = ("Lv %d   " % int(row.level) if int(row.get("level", 0)) > 0 else "") + ("Enemy" if enemy else ("You" if str(row.get("side", "")) == "hero" else "Ally"))
	d.sub.add_theme_color_override("font_color", BATTLE_ENEMY_RED if enemy else BATTLE_ALLY_BLUE)
	_fill_unit_bars(d, row)
	d.res_bar.bg.size = Vector2(d.res_bar.width, 8)
	var has_res: bool = str(row.get("res_kind", "")) != "" and int(row.get("max_res", 0)) > 0
	d.note.visible = not has_res
	d.note.text = str(row.get("note", ""))
	var statuses: Array = row.get("statuses", [])
	for i in d.rows.size():
		var r: Dictionary = d.rows[i]
		r.row.visible = i < statuses.size()
		if i < statuses.size():
			var e: Dictionary = statuses[i]
			r.name.text = str(e.name)
			r.detail.text = str(e.get("detail", ""))
			r.desc = "%s: %s" % [e.name, e.desc]
			r.mark.color = BATTLE_GOLD if bool(e.get("good", false)) else Color(1.0, 0.55, 0.4)
			var pictured: bool = UIIconsScript.show_status(r.picture, str(e.get("id", "")))
			r.mark.visible = not pictured
			r.name.position.x = 44.0 if pictured else 26.0
			r.detail.position.x = 44.0 if pictured else 26.0
	if statuses.is_empty():
		d.caption.text = "STATUS EFFECTS: none"
	else:
		d.caption.text = "STATUS EFFECTS"
	d.panel.size = Vector2(d.panel.size.x, 160.0 + maxi(0, statuses.size()) * 38.0 + 10.0)
	d.panel.visible = true
	# The details box and the History panel share the same place.
	if battle_history_panel != null:
		battle_history_panel.visible = false

func hide_unit_details() -> void:
	if not battle_details.is_empty():
		battle_details.panel.visible = false
	_hide_status_tooltip()

func _show_status_tooltip(entry: Dictionary) -> void:
	var t: Dictionary = battle_status_tooltip
	t.text.text = str(entry.desc)
	var row: Control = entry.row
	var lines: int = maxi(1, ceili(float(str(entry.desc).length()) / 30.0))
	t.panel.size = Vector2(250, 20.0 + lines * 18.0)
	t.text.size = Vector2(230, lines * 18.0)
	t.panel.position = Vector2(row.global_position.x - 258.0, clampf(row.global_position.y - 4.0, 8.0, 560.0))
	t.panel.visible = true

func _hide_status_tooltip() -> void:
	if not battle_status_tooltip.is_empty():
		battle_status_tooltip.panel.visible = false

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
		["Dodge / Block Minigames", "minigames"],
		["Attack Timing Minigame", "attack_minigame"],
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
			"minigames":
				settings_minigames_checkbox = checkbox
				checkbox.toggled.connect(func(v): settings_node.set_combat_minigames_enabled(v))
			"attack_minigame":
				settings_attack_minigame_checkbox = checkbox
				checkbox.toggled.connect(func(v): settings_node.set_attack_minigame_enabled(v))

	var controls_label := Label.new()
	controls_label.position = Vector2(60, 322)
	controls_label.add_theme_font_size_override("font_size", 18)
	controls_label.text = "Controls"
	settings_panel.add_child(controls_label)

	var controls_scroll := ScrollContainer.new()
	controls_scroll.position = Vector2(60, 350)
	controls_scroll.custom_minimum_size = Vector2(680, 204)
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
	shop_spells_scroll.visible = tab == "spells"
	shop_gear_tab_button.button_pressed = tab == "gear"
	shop_enchant_tab_button.button_pressed = tab == "enchant"
	shop_spells_tab_button.button_pressed = tab == "spells"
	shop_description_label.text = ""

# Gear and Enchant used to be two clicks apart no matter which building's
# door you walked through -- now whichever one you DIDN'T walk into isn't
# even shown, not just unclickable, so the Shopkeeper and Enchanter read as
# two distinct services in two distinct places rather than one panel with a
# free toggle sitting right there. Always a full reassignment (not
# cumulative), so repeated opens through either door never leave the wrong
# tab hidden.
func lock_shop_tab(active_tab: String) -> void:
	shop_gear_tab_button.visible = active_tab == "gear"
	shop_enchant_tab_button.visible = active_tab == "enchant"
	shop_spells_tab_button.visible = active_tab == "enchant"          # the Tower has both of its tabs
	# The same panel now presents as whichever building you walked into --
	# the tower has no gear to reroll and none of the [1-9]/[R] shortcuts
	# apply there, so it shouldn't advertise them (Main.gd:_handle_shop_input
	# ignores them in that mode too).
	var in_tower: bool = active_tab == "enchant"
	shop_title_label.text = "WIZARD'S TOWER" if in_tower else "SHOP"
	shop_reroll_button.visible = not in_tower
	shop_footer_label.text = "[Enter/Esc] Leave" if in_tower else "[1-9] Buy   [R] Reroll   [Enter/Esc] Leave"

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
	sb.anti_aliasing = corner_radius > 0       # a rounded corner is smoothed; a square one stays crisp
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
	health_label.text = "%d / %d" % [current, max_health]
	var ratio: float = clampf(float(current) / float(max(1, max_health)), 0.0, 1.0)
	health_bar_fill.size = Vector2(health_bar_bg.custom_minimum_size.x * ratio, health_bar_bg.custom_minimum_size.y)

# Quiver only shows up while a Bow is equipped -- hovering it reveals the
# live held count of each arrow type via quiver_tooltip_label. The tooltip
# text is refreshed here (stored as meta, same lookup-on-hover shape
# _setup_hover_button uses elsewhere) rather than live every frame, since
# Main.gd only calls this at the few points owned_arrows/the equipped
# weapon can actually change (buy/sell in the shop, firing an arrow in
# battle, leaving either back to the overworld).
func update_quiver(has_bow: bool, owned_arrows: Dictionary) -> void:
	quiver_icon.visible = has_bow
	quiver_row.visible = has_bow
	if not has_bow:
		quiver_tooltip_label.text = ""
		return
	var lines := []
	for kind in ["flame", "freeze", "bomb"]:
		var info: Dictionary = WeaponsScript.ARROW_TYPES[kind]
		lines.append("%s: %d" % [info.name, owned_arrows.get(kind, 0)])
	quiver_icon.set_meta("tooltip", "\n".join(lines))

func update_enemies(count: int) -> void:
	enemies_label.text = "%d nearby" % count

func update_wave(wave: int) -> void:
	wave_label.text = "%s %d" % [Wording.DANGER, wave]

func update_world(text: String) -> void:
	world_label.text = text

# The name of the room (Rooms.gd) you are in, under the region's name.
func update_room(text: String) -> void:
	if room_label != null:
		room_label.text = text
		room_label.visible = text != ""

# How dangerous the ground you stand on is (WorldMap.gd tier, 0 = none, e.g. inside the town): filled pips,
# green through red.
func set_danger(tier: int) -> void:
	for i in danger_pips.size():
		var pip: ColorRect = danger_pips[i]
		if i < tier:
			pip.color = Color(0.45, 0.85, 0.35).lerp(Color(0.95, 0.2, 0.15), float(i) / float(maxi(1, danger_pips.size() - 1)))
		else:
			pip.color = Color(0.2, 0.19, 0.22, 0.9)
	if danger_caption != null:
		danger_caption.visible = tier > 0
	for pip in danger_pips:
		pip.visible = tier > 0

func update_minimap(world_pos: Vector2) -> void:
	if minimap != null:
		minimap.set_player(world_pos)

func update_level(level: int) -> void:
	level_label.text = "LV %d" % level

func update_xp(current: int, needed: int) -> void:
	if needed <= 0:
		xp_label.text = "XP  MAX LEVEL"
		xp_bar_fill.size = Vector2(xp_bar_bg.custom_minimum_size.x, xp_bar_bg.custom_minimum_size.y)
	else:
		xp_label.text = "XP  %d / %d" % [current, needed]
		var ratio: float = clampf(float(current) / float(needed), 0.0, 1.0)
		xp_bar_fill.size = Vector2(xp_bar_bg.custom_minimum_size.x * ratio, xp_bar_bg.custom_minimum_size.y)

func update_stats(intimidation: int, strength: int, vigor: int, agility: int, might: int) -> void:
	# stat_agility is a real move-speed value in pixels/sec (starts at 180),
	# wildly out of scale next to the other stats' small whole numbers --
	# shown here as a small rating instead (starts at 5, +1 per full
	# AGILITY_BONUS_PER_LEVEL gained) purely for display. The real
	# stat_agility driving movement/attack cooldown is untouched.
	var speed_display: int = 5 + int(agility - PlayerScript.AGILITY_START) / PlayerScript.AGILITY_BONUS_PER_LEVEL
	stats_label.text = "INM %d   STR %d   VGR %d   AGI %d   MGT %d" % [intimidation, strength, vigor, speed_display, might]

func update_items(count: int) -> void:
	items_label.text = "%d" % count

# A message pops up near the bottom of the screen and fades away on its own (it used to sit in a text stack
# until something replaced it).
func show_message(text: String) -> void:
	message_label.text = text
	if message_tween != null:
		message_tween.kill()
	if text == "":
		message_toast.visible = false
		return
	message_toast.visible = true
	message_toast.modulate.a = 1.0
	message_tween = create_tween()
	message_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	message_tween.tween_interval(3.4)
	message_tween.tween_property(message_toast, "modulate:a", 0.0, 0.9)
	message_tween.tween_callback(func(): message_toast.visible = false)

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
	game_over_label.text = "You have conquered the Nothingness!\n\nWorldwalker is now unlocked at the Church."
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
		"Spend it at the Church in town.",
		"%s reached: %d" % [Wording.DANGER, stats.get("waves_cleared", 0)],
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
func show_levelup_choice(new_level: int, intimidation: int, strength: int, vigor: int, agility: int, might: int, resilience: int, reflexes: int, dexterity: int, resilience_unlocked: bool, reflexes_unlocked: bool, dexterity_unlocked: bool, fortitude: int = 0, fortitude_unlocked: bool = false) -> void:
	levelup_label.text = "LEVEL UP! Now level %d\nAll stats +1. Choose ONE bonus +1:" % new_level
	for c in levelup_box.get_children():
		c.queue_free()
	levelup_buttons.clear()

	# Same display-only rating as update_stats -- the raw move-speed value
	# would look wildly out of scale next to the other stats here too.
	var speed_display: int = 5 + int(agility - PlayerScript.AGILITY_START) / PlayerScript.AGILITY_BONUS_PER_LEVEL
	var rows := [
		["intimidation", "Intimidation (%d)" % intimidation, UI_TEXT["levelup.intimidation"]],
		["strength", "Strength (%d)" % strength, UI_TEXT["levelup.strength"]],
		["vigor", "Vigor (%d)" % vigor, UI_TEXT["levelup.vigor"]],
		["agility", "Agility (%d)" % speed_display, UI_TEXT["levelup.agility"]],
		["might", "Might (%d)" % might, UI_TEXT["levelup.might"]],
	]
	if resilience_unlocked:
		rows.append(["resilience", "Resilience (%d)" % resilience, UI_TEXT["levelup.resilience"]])
	if reflexes_unlocked:
		rows.append(["reflexes", "Reflexes (%d)" % reflexes, UI_TEXT["levelup.reflexes"]])
	if dexterity_unlocked:
		rows.append(["dexterity", "Dexterity (%d)" % dexterity, UI_TEXT["levelup.dexterity"]])
	if fortitude_unlocked:
		rows.append(["fortitude", "Fortitude (%d)" % fortitude, UI_TEXT["levelup.fortitude"]])

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

# Relabels the ally special / picker buttons from the info Main.gd handed over this refresh.
func _refresh_ally_submenus() -> void:
	# The attack / magic / strategy list: info.list = [{label, action, disabled, tip}], each button sending its entry's action.
	var entries: Array = battle_ally_menu_info.get("list", [])
	for i in battle_ally_special_buttons.size():
		var button: Button = battle_ally_special_buttons[i]
		button.visible = i < entries.size()
		if i < entries.size():
			button.text = str(entries[i].label)
			button.disabled = bool(entries[i].disabled)
			button.set_meta("action", str(entries[i].action))
			button.set_meta("description", str(entries[i].tip))
	var picks: Array = battle_ally_menu_info.get("picks", [])
	for i in battle_ally_pick_buttons.size():
		var pick_button: Button = battle_ally_pick_buttons[i]
		pick_button.visible = i < picks.size()
		if i < picks.size():
			pick_button.text = str(picks[i].label)
	# A long picker (Summon the Dead's numbers) wraps into columns of at most eight.
	var columns: int = maxi(1, ceili(float(picks.size()) / 8.0))
	battle_ally_pick_grid.columns = columns
	var pick_menu: Dictionary = battle_menus["ally_pick"]
	pick_menu.panel.size = Vector2(columns * 228.0 + BATTLE_MENU_PAD * 2.0, minf(float(picks.size()), 8.0) * BATTLE_MENU_ROW_H + BATTLE_MENU_PAD * 2.0)

# Keyboard focus on the first of these buttons that is showing and enabled.
func focus_first_usable(buttons: Array) -> void:
	for b in buttons:
		if b != null and b.visible and not b.disabled:
			b.grab_focus()
			return

# Puts keyboard focus on the first usable button of whichever ally submenu is showing.
func focus_ally_submenu() -> void:
	var group: Array = []
	if battle_ally_pick_box != null and battle_ally_pick_box.visible:
		group = battle_ally_pick_buttons
	elif battle_ally_special_box != null and battle_ally_special_box.visible:
		group = battle_ally_special_buttons
	elif battle_ally_menu_box != null and battle_ally_menu_box.visible:
		group = [battle_ally_buttons["attack"], battle_ally_buttons["magic"], battle_ally_buttons["strategy"]]
	for b in group:
		if b.visible and not b.disabled:
			b.grab_focus()
			return

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
	settings_minigames_checkbox.button_pressed = settings_node.combat_minigames_enabled
	settings_attack_minigame_checkbox.button_pressed = settings_node.attack_minigame_enabled
	for action in settings_node.ACTION_ORDER:
		settings_rebind_buttons[action].text = settings_node.key_name(action)

func _cancel_rebind() -> void:
	if rebinding_action != "":
		settings_rebind_buttons[rebinding_action].text = settings_node.key_name(rebinding_action)
		rebinding_action = ""

func _input(event: InputEvent) -> void:
	# A click on a unit (or on bare ground, which closes the details box) while a battle is up. The click is not consumed:
	# an enemy's own button still picks it as the target.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and battle_panel != null and battle_panel.visible:
		_battle_click()
	# H opens and closes the History panel; Tab steps the details box through the units (and is kept from hopping the focus).
	if event is InputEventKey and event.pressed and not event.echo and battle_panel != null and battle_panel.visible and rebinding_action == "":
		if event.keycode == KEY_H:
			toggle_history()
		elif event.keycode == KEY_TAB:
			get_viewport().set_input_as_handled()
			inspect_cycled.emit()
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
	coins_label.text = "%d" % amount

func show_shop(coins: int, runic_shards: int, offering: Array, prices: Array, current_weapon_name: String, owned_weapons: Dictionary, current_armor_name: String, potion_count: int, reroll_cost: int, is_bow_equipped: bool = false, owned_arrows: Dictionary = {}, arrow_prices: Dictionary = {}, arrow_cap: int = WeaponsScript.ARROW_MAX_HELD, current_shield_name: String = "None", owned_shields: Dictionary = {}, player_might: int = 0, shopkeeper_lines: Array = [], unlimited_arrows: bool = false, player_intimidation: int = 0, light_metal: bool = false) -> void:
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
		# try_buy_weapon for the matching server-side block. Mythic alone also
		# gates on a second stat, required_intimidation.
		var required_might: int = int(item.get("required_might", 0))
		if light_metal:
			required_might = int(ceil(float(required_might) / 2.0))     # Light Metal (Church): half the Might
		var might_locked: bool = item.category == "weapon" and required_might > player_might
		var required_intimidation: int = int(item.get("required_intimidation", 0))
		var intimidation_locked: bool = item.category == "weapon" and required_intimidation > player_intimidation
		var stat_locked: bool = might_locked or intimidation_locked

		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 52)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.icon = WeaponIconsScript.texture_for(item) if item.category == "weapon" else load("res://assets/%s.png" % item.icon)
		button.expand_icon = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "[%d] %s%s%s%s" % [i + 1, "🔒 " if is_locked else "", "★ " if is_mythic else "", item.name, "  (for your party)" if item.get("ally_only", false) else ""]
		button.disabled = (not already_owned and coins < prices[i]) or stat_locked
		button.pressed.connect(func(): shop_buy_pressed.emit(i))
		# Stat descriptions live in the Inventory screen now, not here --
		# the shop only ever shows the Shopkeeper's own flavor bark on hover.
		# For weapons, that's Main.gd's already-resolved per-type/tier/
		# familiarity pick (Shopkeeper.get_item_line) when one's been
		# written; shopkeeper_lines[i] falls back to the item's own flat
		# shop_description otherwise, so armor/shield/potion rows (and any
		# weapon type without its own lines yet) are unaffected.
		var keeper_line: String = shopkeeper_lines[i] if i < shopkeeper_lines.size() else item.get("shop_description", "")
		_hook_shopkeeper_hover(button, keeper_line)
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
		var stat_lock_label := ""
		if might_locked:
			stat_lock_label = "MGT %d" % required_might
		if intimidation_locked:
			stat_lock_label = ("%s/INM %d" % [stat_lock_label, required_intimidation]) if stat_lock_label != "" else ("INM %d" % required_intimidation)
		price_label.text = stat_lock_label if stat_locked else ("OWNED" if already_owned else "%d" % prices[i])
		price_label.add_theme_font_size_override("font_size", 15)
		price_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4) if stat_locked else (Color(0.55, 0.85, 0.4) if already_owned else Color(1, 0.85, 0.3)))
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
			_setup_hover_button(lock_button, UI_TEXT["shop.lock"] % SHOP_LOCK_COST, shop_description_label)
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
			# Fletcher's Ring (talisman): no cap, ever.
			var at_cap: bool = not unlimited_arrows and held >= arrow_cap

			var arrow_row := HBoxContainer.new()
			arrow_row.add_theme_constant_override("separation", 8)

			var buy_button := Button.new()
			buy_button.custom_minimum_size = Vector2(0, 52)
			buy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			buy_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			buy_button.text = "%s (held: %d)" % [info.name, held]
			buy_button.disabled = at_cap or coins < price
			buy_button.pressed.connect(func(): arrow_buy_pressed.emit(kind))
			_hook_shopkeeper_hover(buy_button, info.get("shop_description", ""))
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
			_setup_hover_button(sell_button, UI_TEXT["shop.arrow_sell"] % [info.name, WeaponsScript.ARROW_SELL_PRICE], shop_description_label)
			_hook_shopkeeper_hover(sell_button, info.get("shop_description", ""))
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

# The shopkeeper's current line -- called directly by Main.gd for shop-flow
# moments (entering, buying, failing to afford something) and internally by
# _hook_shopkeeper_hover for whichever row the mouse is currently over. A
# hover doesn't get cleared back to blank on mouse-exit -- the last thing he
# said just stays up, same as a real conversation would. Revealed a letter
# at a time (see _process) rather than set instantly -- Main.gd's own
# talk-blip SFX rides along with that reveal via shopkeeper_blip.
func set_shopkeeper_line(text: String) -> void:
	shopkeeper_full_text = text
	shopkeeper_revealed_chars = 0.0
	shop_keeper_textbox.text = ""

# Skips straight to the full line -- wired to a click/key on the textbox so
# an impatient player isn't stuck waiting out a long line one letter at a
# time (same escape hatch Undertale itself offers).
func skip_shopkeeper_reveal() -> void:
	shopkeeper_revealed_chars = shopkeeper_full_text.length()
	shop_keeper_textbox.text = shopkeeper_full_text

# Wires a shop row's hover to also update the shopkeeper's line, alongside
# whatever _setup_hover_button already wired for the plain description
# tooltip -- the two are independent texts (see GameText.gd's header note).
# No-op if this particular row has no shop_description of its own.
func _hook_shopkeeper_hover(button: Button, line: String) -> void:
	if line == "":
		return
	button.mouse_entered.connect(func(): set_shopkeeper_line(line))

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
		_hook_shopkeeper_hover(button, rune.get("shop_description", ""))
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

# The Wizard's Tower's Spells tab: one row per spell. rows: [{id, title, owner, effect, level, price_text, can_buy, maxed}].
func show_spells_tab(note: String, rows: Array) -> void:
	for n in shop_spells_row_nodes:
		n.queue_free()
	shop_spells_row_nodes.clear()
	shop_spells_note_label.text = note
	for row in rows:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 64)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%s   (%s)\n%s" % [row.title, row.owner, row.effect]
		button.disabled = bool(row.maxed) or not bool(row.can_buy)
		var spell_id: String = row.id
		button.pressed.connect(func(): spell_upgrade_pressed.emit(spell_id))
		_style_shop_row_button(button, "enchant")
		shop_spells_row_box.add_child(button)

		var cost_label := Label.new()
		cost_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		cost_label.offset_left = -170
		cost_label.offset_right = -12
		cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost_label.text = row.price_text
		cost_label.add_theme_font_size_override("font_size", 15)
		cost_label.add_theme_color_override("font_color", Color(0.75, 0.55, 1.0) if (bool(row.can_buy) and not bool(row.maxed)) else Color(0.6, 0.6, 0.6))
		button.add_child(cost_label)
		shop_spells_row_nodes.append(button)

# background_color (each world's own WORLDS.battle_bg, see Main.gd) is
# accepted but no longer used for the gradient itself -- a fixed green-to-
# cyan look, not a per-world tint, is what was actually asked for. Kept as
# a parameter rather than removed outright so callers don't need touching.
func show_battle(background_color: Color = Color(0.05, 0.05, 0.05)) -> void:
	battle_log_lines.clear()
	battle_history.clear()
	if battle_history_panel != null:
		battle_history_panel.visible = false
	_set_battle_gradient(background_color)
	# The thin 8px ring around the inset frame (battle_panel's own raw
	# fill) -- matches the gradient's own top stop so it reads as a
	# continuation of it instead of a mismatched flat border.
	battle_panel.color = BATTLE_GRADIENT_TOP
	battle_log_label.text = ""
	battle_panel.modulate.a = 0.0
	battle_panel.visible = true
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(battle_panel, "modulate:a", 1.0, 0.4)

# A fixed cyan-to-green top-to-bottom gradient (green on the bottom) for the
# battle screen's backdrop, replacing the old flat single-color fill (and,
# before that, a subtle per-world tint that didn't read as intended).
# base_color is unused now but kept as a parameter for callers.
const BATTLE_GRADIENT_TOP := Color(0.0, 0.22, 0.3)
const BATTLE_GRADIENT_BOTTOM := Color(0.02, 0.18, 0.1)
func _set_battle_gradient(_base_color: Color) -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, BATTLE_GRADIENT_TOP)
	gradient.set_color(1, BATTLE_GRADIENT_BOTTOM)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 8
	tex.height = 8
	battle_gradient_rect.texture = tex

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

# The hovered enemy's HP/damage/notable-traits line (Main.gd:
# _enemy_stat_summary) -- shares battle_description_label with every menu
# button's own hover text, same as the shop's single description_label
# already juggles several different row types.
func show_enemy_stats(text: String) -> void:
	battle_description_label.text = text

# Turtle Shell's water-push confirm: puts the prompt text where the battle
# description normally goes and swaps the two buttons' labels. The visibility
# itself is driven by update_battle_grid's own is_confirm_prompt param (set
# every refresh, same as is_evasion_prompt), not by this call directly.
func show_battle_confirm(prompt: String, yes_label: String, no_label: String) -> void:
	battle_description_label.text = prompt
	battle_confirm_yes_button.text = yes_label
	battle_confirm_no_button.text = no_label
	battle_confirm_yes_button.grab_focus()

func update_battle_grid(grid_w: int, grid_h: int, terrain: Dictionary, player_tile: Vector2i, units: Array, player_hp: int, player_max_hp: int, player_level: int, turn: String, target_index: int, moves_left: int, stamina: int, max_stamina: int, current_weapon: Dictionary, menu_state: String, healing_items: int, move_trail: Array, allies: Array, has_guardian_skill: bool, skill_cooldown: int, is_disarmed: bool = false, owned_arrows: Dictionary = {}, is_evasion_prompt: bool = false, can_mine: bool = false, shield_name: String = "", shield_block_pct: float = 0.0, berserk_turns: int = 0, stealth_turns: int = 0, stealth_cost: int = 0, evasion_options: Dictionary = {}, feared_unreachable: bool = false, is_confirm_prompt: bool = false, commanding_ally_name: String = "") -> void:
	# commanding_ally_name is non-empty while Main.gd is running a party member's own
	# commanded turn (see battle_commanding_ally) -- moves_left/player_hp/player_max_hp
	# are already that ally's own numbers in this case, not the hero's; only the name
	# and which menu box shows need to branch on it here.
	var in_ally_turn: bool = commanding_ally_name != ""
	# What is on the grid now, for finding the unit under the mouse.
	battle_units_now = units
	battle_allies_now = allies
	battle_player_tile_now = player_tile
	battle_grid_size_now = Vector2i(grid_w, grid_h)
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
	# The hero's plate: his own health and stamina (the numbers passed in are the commanded ally's during its turn).
	var hero_row: Dictionary = battle_party_rows[0] if not battle_party_rows.is_empty() else {}
	if hero_row.is_empty():
		_hide_plate(battle_hero_plate)
	else:
		_place_plate(battle_hero_plate, battle_grid_origin + Vector2(player_tile.x, player_tile.y) * battle_tile_size, battle_tile_size, float(hero_row.hp) / float(maxi(1, int(hero_row.max_hp))), float(hero_row.res) / float(maxi(1, int(hero_row.max_res))), STAMINA_BAR_FILL_COLOR)

	# Party members now have a real tile of their own (Main.gd:battle_allies)
	# -- rendered the same way as an enemy icon (tile origin + padding), plus
	# a small health bar under it. Traitor Wolf reuses the enemy Wolf icon;
	# any other ally (Knight, Warrior) uses the shared companion icon.
	for i in battle_ally_icons.size():
		var ally_icon: TextureRect = battle_ally_icons[i]
		var hp_bg: ColorRect = battle_ally_hp_bg[i]
		var hp_fill: ColorRect = battle_ally_hp_fill[i]
		if i < allies.size():
			var a: Dictionary = allies[i]
			var a_tile_origin: Vector2 = battle_grid_origin + Vector2(a.tile.x, a.tile.y) * battle_tile_size
			var a_padding := 6.0
			var is_wolf_ally: bool = a.get("kind", "") == "wolf"
			ally_icon.texture = ENEMY_ICONS.get("Wolf", null) if is_wolf_ally else BLADE_ALLY_ICON
			# Roster members wear their kind's colour on the shared companion icon.
			ally_icon.modulate = a.member.rules().get("tint", Color(1, 1, 1)) if (a.has("member") and not is_wolf_ally) else (Color(0.82, 0.88, 0.8) if a.get("kind", "") == "skeleton" else Color(1, 1, 1))
			if a.get("kind", "") == "spectre":
				ally_icon.modulate = Color(0.65, 0.85, 1.0, 0.8)   # I SUMMON THEE's spectre: a pale, see-through blue
			# Whoever the player is commanding right now glows, like the current target.
			if a.get("acting", false):
				ally_icon.modulate = ally_icon.modulate * Color(1.4, 1.4, 0.75)
			# A member hiding in the shadows (Stealth) is drawn faded.
			if int(a.get("stealth_turns", 0)) > 0:
				ally_icon.modulate.a = 0.5
			ally_icon.position = a_tile_origin + Vector2(a_padding, a_padding)
			ally_icon.size = Vector2(battle_tile_size - a_padding * 2, battle_tile_size - a_padding * 2)
			ally_icon.visible = ally_icon.texture != null
			# A downed ally lies dimmed on its tile; its health bar is hidden.
			if a.get("downed", false):
				ally_icon.modulate = ally_icon.modulate * Color(0.45, 0.45, 0.5, 0.7)

			# The plate over the unit carries the health (and stamina/mana) bars now; the old one under the icon is retired.
			hp_bg.visible = false
			hp_fill.visible = false
			if a.get("downed", false):
				_hide_plate(battle_ally_plates[i])
			else:
				var res: Dictionary = _unit_res(a)
				_place_plate(battle_ally_plates[i], a_tile_origin, battle_tile_size, float(a.hp) / float(max(1, a.max_hp)), res.ratio, res.color)
		else:
			ally_icon.visible = false
			hp_bg.visible = false
			hp_fill.visible = false
			_hide_plate(battle_ally_plates[i])

	for i in battle_unit_markers.size():
		battle_unit_markers[i].visible = false
		battle_unit_icons[i].visible = false
		battle_unit_aware_markers[i].visible = false
		_hide_plate(battle_enemy_plates[i])

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
		_place_plate(battle_enemy_plates[i], tile_origin, footprint_span, float(u.hp) / float(maxi(1, int(u.get("max_hp", 1)))), -1.0, STAMINA_BAR_FILL_COLOR)

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

	var turn_text: String
	if in_ally_turn:
		turn_text = "%s's turn (moves left: %d)" % [commanding_ally_name, moves_left]
	elif turn == "player":
		turn_text = "Your turn (moves left: %d)" % moves_left
	elif turn == "attack":
		turn_text = "Attacking..."
	else:
		turn_text = "Enemy turn..."
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

	# battle_turn stays "player" throughout a party member's commanded turn too
	# (see Main.gd:battle_commanding_ally) -- in_ally_turn is what actually tells
	# the hero's own menus and the ally's apart, not turn itself.
	var is_player_turn: bool = turn == "player" and not in_ally_turn
	battle_key_hint_label.text = _battle_key_hints(menu_state, in_ally_turn, is_player_turn, is_evasion_prompt, is_confirm_prompt)
	var prompt_free: bool = not is_evasion_prompt and not is_confirm_prompt
	battle_main_menu_box.visible = is_player_turn and menu_state == "main" and prompt_free
	battle_strategy_menu_box.visible = is_player_turn and (menu_state == "strategy" or menu_state == "tactics") and prompt_free
	battle_ally_menu_box.visible = in_ally_turn and menu_state == "main" and prompt_free
	battle_ally_special_box.visible = in_ally_turn and menu_state == "ally_special" and prompt_free
	battle_ally_pick_box.visible = in_ally_turn and menu_state == "ally_pick" and prompt_free
	_refresh_ally_submenus()
	battle_fight_submenu_box.visible = is_player_turn and menu_state == "fight" and prompt_free
	# Move is the one submenu shared by both -- Confirm/Cancel behave the same
	# shape for an ally as for the hero (see Main.gd's _on_battle_move_action).
	battle_move_submenu_box.visible = (is_player_turn or in_ally_turn) and menu_state == "move" and prompt_free
	battle_arrow_submenu_box.visible = is_player_turn and menu_state == "arrow" and prompt_free
	# Independent of is_player_turn -- this shows mid-"enemy" turn, the one
	# moment the player acts without it technically being their turn. Only
	# whichever directions are actually free tiles (evasion_options, from
	# Main.gd's _evasion_directions) are enabled.
	battle_evasion_submenu_box.visible = is_evasion_prompt
	for label in battle_evasion_buttons:
		battle_evasion_buttons[label].disabled = not evasion_options.has(label)
	# Turtle Shell's water-push confirm -- fires right as the player's own
	# turn is ending, so is_player_turn can already read false by the time
	# this refresh lands; shown purely off is_confirm_prompt for that reason.
	battle_confirm_box.visible = is_confirm_prompt

	battle_main_buttons["item"].disabled = healing_items <= 0 or feared_unreachable
	battle_main_buttons["move"].disabled = moves_left <= 0
	# A member with no spells has no Magic entry at all.
	battle_ally_buttons["magic"].visible = bool(battle_ally_menu_info.get("has_magic", false))
	# Disarmed (Spear's Target Practice miss, Dagger's Knife Throw): Fight is
	# off-limits until you're standing back on the tile your weapon landed on
	# -- everything else (Move/Item/Defend/Flee/Skill/Arrow) stays available.
	battle_main_buttons["fight"].disabled = is_disarmed or feared_unreachable
	battle_main_buttons["skill"].visible = has_guardian_skill
	battle_main_buttons["skill"].disabled = skill_cooldown > 0 or feared_unreachable
	battle_main_buttons["skill"].text = "Skill" if skill_cooldown <= 0 else "Skill (%d)" % skill_cooldown
	# Only the Bow can fire arrows -- the button is hidden (not just
	# disabled) the same way Skill is gated on has_guardian_skill.
	var is_bow_equipped: bool = current_weapon.get("id", "").begins_with("bow")
	battle_fight_buttons["arrow"].visible = is_bow_equipped
	battle_fight_buttons["arrow"].disabled = feared_unreachable
	# Fear, target out of reach (Main.gd:battle_feared_unreachable): Move/
	# Defend/Flee stay available (Defend specifically so a kiting enemy that
	# never re-enters weapon range can't force a real soft-lock where Flee
	# is the only repeatable option turn after turn) -- Taunt and Stealth have
	# no disabled-state of their own otherwise, so this is the only place they
	# need one.
	battle_tactics_buttons["taunt"].disabled = feared_unreachable
	# Mine only shows up with Hand Picks equipped AND an actual rock/rubble
	# in reach -- can_mine already folds both checks together (see Main.gd:
	# _refresh_battle_display).
	battle_fight_buttons["mine"].visible = can_mine

	var specials: Array = current_weapon.get("specials", [])
	var special_keys := ["special_0", "special_1", "special_2"]
	# The Bow overrides both of these with its own, flat costs (2026-09-29) --
	# every other weapon's regular Attack stays free, Heavy stays the usual rate.
	var regular_cost: int = int(current_weapon.get("regular_attack_stamina_cost", 0))
	battle_fight_buttons["attack"].text = "Attack (%d STA)" % regular_cost if regular_cost > 0 else "Attack"
	battle_fight_buttons["attack"].disabled = stamina < regular_cost
	var heavy_cost: int = int(current_weapon.get("heavy_stamina_cost_override", WeaponsScript.HEAVY_STAMINA_COST))
	battle_fight_buttons["heavy"].text = "Heavy Attack (%d STA)" % heavy_cost
	battle_fight_buttons["heavy"].disabled = stamina < heavy_cost
	battle_tactics_buttons["stealth"].text = "Stealth (%d STA)" % stealth_cost
	battle_tactics_buttons["stealth"].disabled = stamina < stealth_cost or feared_unreachable
	for i in special_keys.size():
		var button: Button = battle_fight_buttons[special_keys[i]]
		if i < specials.size():
			var special: Dictionary = specials[i]
			# A move not yet learned at the Dojo stays visible (so you know what
			# training there would unlock) but can't be picked. A special with no
			# "learned" key at all counts as learned.
			if special.get("learned", true):
				button.text = "%s (%d STA)" % [special.name, special.stamina_cost]
				button.disabled = stamina < special.stamina_cost
				button.set_meta("description", special.description)
			else:
				button.text = "%s (Unlearned - Dojo)" % special.name
				button.disabled = true
				button.set_meta("description", "You haven't learned this move yet. Train at the Dojo in town to unlock it.")
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

	# Float whichever list is showing beside the unit whose turn it is, now that every entry's visibility is settled.
	var anchor: Vector2i = player_tile
	for a in allies:
		if a.get("acting", false):
			anchor = a.tile
	for key in ["main", "strategy", "fight", "arrow", "move", "ally_main", "ally_list", "ally_pick"]:
		var menu: Dictionary = battle_menus[key]
		if menu.panel.visible:
			if key != "ally_pick":
				_fit_menu(menu)
			_place_menu(menu, anchor, grid_w)

func battle_log(msg: String) -> void:
	# There is no log on the screen any more: the lines are kept (the last 80 flat, and the last three turns by turn, for the
	# History panel).
	battle_log_lines.append(msg)
	if battle_log_lines.size() > 80:
		battle_log_lines.pop_front()
	if battle_history.is_empty():
		battle_history.append({"turn": 1, "lines": []})
	battle_history[battle_history.size() - 1].lines.append(msg)
	if battle_history_panel != null and battle_history_panel.visible:
		_refresh_history()

# A new turn of the battle begins (the hero's turn comes round): start a fresh block of history, keeping the last three.
func battle_history_new_turn(turn: int) -> void:
	if not battle_history.is_empty() and battle_history[battle_history.size() - 1].lines.is_empty():
		battle_history[battle_history.size() - 1].turn = turn
		return
	battle_history.append({"turn": turn, "lines": []})
	while battle_history.size() > 3:
		battle_history.pop_front()
	if battle_history_panel != null and battle_history_panel.visible:
		_refresh_history()

func _refresh_history() -> void:
	var text := ""
	for i in range(battle_history.size() - 1, -1, -1):
		var block: Dictionary = battle_history[i]
		text += "[color=#%s]Turn %d%s[/color]\n" % [BATTLE_GOLD.to_html(false) if i == battle_history.size() - 1 else BATTLE_TEXT.to_html(false), int(block.turn), "  (now)" if i == battle_history.size() - 1 else ""]
		if block.lines.is_empty():
			text += "[color=#%s]  Nothing yet.[/color]\n" % BATTLE_DIM.to_html(false)
		for line in block.lines:
			text += "[color=#%s]  %s[/color]\n" % [BATTLE_DIM.to_html(false), str(line).replace("[", "(").replace("]", ")")]
		text += "\n"
	battle_history_text.text = text

func toggle_history() -> void:
	if battle_history_panel == null:
		return
	if battle_history_panel.visible:
		battle_history_panel.visible = false
		return
	unit_clicked.emit("none", 0)          # closes any open details box: the two share a place
	hide_unit_details()
	_refresh_history()
	battle_history_panel.visible = true

func history_open() -> bool:
	return battle_history_panel != null and battle_history_panel.visible

# The turn-order strip: rows = [{side: "hero"|"ally"|"enemy", name, current, hp_frac, kind?, tint?}], the one
# in progress first. Hero rows are gold-blue, allies green, enemies red; whoever acts now is lit up.
func set_turn_order(rows: Array) -> void:
	if turn_order_box == null:
		return
	for child in turn_order_box.get_children():
		turn_order_box.remove_child(child)
		child.queue_free()
	turn_order_box.visible = not rows.is_empty()
	if rows.is_empty():
		return
	var title := Label.new()
	title.text = "TURN"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", BATTLE_DIM)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(0, 44)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	turn_order_box.add_child(title)
	for r in rows:
		turn_order_box.add_child(_make_turn_order_row(r))

# One tile of the turn-order strip: the unit's picture in a frame (blue for the hero and allies' side, red for foes, gold and
# larger for whoever is acting) with a thin health bar under it. Hover for its name.
func _make_turn_order_row(r: Dictionary) -> Control:
	var side: String = str(r.get("side", "enemy"))
	var accent: Color = BATTLE_ENEMY_RED if side == "enemy" else BATTLE_ALLY_BLUE
	var current: bool = bool(r.get("current", false))
	var px: float = 38.0 if current else 30.0
	var panel := PanelContainer.new()
	panel.tooltip_text = str(r.get("name", "?"))
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", _battle_box(PANEL_BG, BATTLE_GOLD if current else accent * Color(1, 1, 1, 0.8), 2 if current else 1, BattleStyleScript.CORNER_SMALL, false))
	(panel.get_theme_stylebox("panel") as StyleBoxFlat).set_content_margin_all(3)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	# The unit's picture: the hero is the blue "@", everyone else wears the icon the battle grid gives them.
	var icon_holder := Control.new()
	icon_holder.custom_minimum_size = Vector2(px, px)
	icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(icon_holder)
	if side == "hero":
		var at := Label.new()
		at.text = "@"
		at.add_theme_font_size_override("font_size", int(px * 0.85))
		at.add_theme_color_override("font_color", accent)
		at.position = Vector2(px * 0.2, -px * 0.12)
		at.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_holder.add_child(at)
	else:
		var icon := TextureRect.new()
		var is_wolf: bool = str(r.get("kind", "")) == "wolf"
		icon.texture = ENEMY_ICONS.get("Wolf", null) if is_wolf else (BLADE_ALLY_ICON if side == "ally" else ENEMY_ICONS.get(str(r.get("name", "")), null))
		icon.modulate = r.get("tint", Color(1, 1, 1)) if side == "ally" and not is_wolf else Color(1, 1, 1)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.size = Vector2(px, px)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_holder.add_child(icon)
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.15, 0.15, 0.15)
	bar_bg.custom_minimum_size = Vector2(px, 3)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(bar_bg)
	var bar_fill := ColorRect.new()
	bar_fill.color = HEALTH_BAR_FILL_COLOR if side == "enemy" else Color(0.5, 0.9, 0.55)
	bar_fill.size = Vector2(px * clampf(float(r.get("hp_frac", 1.0)), 0.0, 1.0), 3)
	bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg.add_child(bar_fill)
	return panel

func hide_battle() -> void:
	battle_panel.visible = false
	battle_card_hover_key = ""
	hide_unit_popup()
	hide_unit_details()
	hide_damage_preview()
	show_move_range([], false)
	if battle_history_panel != null:
		battle_history_panel.visible = false

# Positioned fresh every call (not cached) -- called from Main.gd's
# _refresh_battle_display, which already recomputes the rest of the battle
# HUD every frame during the player's turn, so this stays correct with no
# extra layout-timing handling needed.
func show_battle_hint(text: String, target_button: Control) -> void:
	battle_hint_label.text = text
	battle_hint_panel.visible = true
	battle_tutorial_skip_button.visible = true
	if target_button == null:
		return
	var anchor: Vector2 = target_button.global_position - battle_panel.global_position
	var desired := anchor + Vector2(target_button.size.x / 2.0 - battle_hint_panel.size.x / 2.0, -battle_hint_panel.size.y - 10)
	var bounds: Vector2 = get_viewport().get_visible_rect().size
	desired.x = clampf(desired.x, 10, bounds.x - battle_hint_panel.size.x - 10)
	desired.y = clampf(desired.y, 10, bounds.y - battle_hint_panel.size.y - 10)
	battle_hint_panel.position = desired

func hide_battle_hint() -> void:
	battle_hint_panel.visible = false
	battle_tutorial_skip_button.visible = false

# Simultaneous unlocks: deliberately non-queued -- a second call while one
# is already showing just overwrites the text and stays visible. All five
# acquisition points are one-at-a-time player clicks, so this is a rare
# edge case and not worth a queue for a purely informational card.
func show_unlock_popup(title: String, description: String) -> void:
	unlock_popup_name_label.text = title
	unlock_popup_desc_label.text = description
	unlock_popup_panel.visible = true

func hide_unlock_popup() -> void:
	unlock_popup_panel.visible = false
