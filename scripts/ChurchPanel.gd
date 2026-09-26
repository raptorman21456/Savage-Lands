extends TownPanel

# The Church: where banked Essence is spent on the permanent skill tree. It used
# to live on the title screen; it now sits in town as a starfield constellation
# (see AscensionView.gd) -- a hub at the centre, three wings fanning out from it
# (Warrior / Merchant / Survivor), a few cross-wing nodes between them, and the
# post-game Worldwalker floating far off on its own.
#
# The panel owns the game rules (what a node is called, what state it's in, what
# a purchase does); AscensionView only draws and reports clicks. Essence and
# levels persist across deaths (the run resets, the slot doesn't), so a purchase
# is written straight to the save slot and then handed to Main.apply_meta_purchase
# so the run in progress feels it right away.

const AscensionViewScript := preload("res://scripts/AscensionView.gd")
const SaveDataScript := preload("res://scripts/SaveData.gd")
const PixelUIScript := preload("res://scripts/PixelUI.gd")

# Which wing each skill belongs to (tints its nodes and picks where its roots
# fan out from). Every id in SaveData.UPGRADE_IDS must appear exactly once --
# test_church.gd checks.
const WING_MEMBERS := {
	"warrior": [
		"strength", "agility", "dexterity_unlock", "vigor", "reflexes_unlock", "berserker_edge",
		"adrenaline", "battle_hardened", "pack_leader", "prodigy", "warlord", "beastmaster",
		"hardened", "pack_bond", "riposte", "momentum", "rage",
	],
	"merchant": [
		"coins", "intimidation", "luck", "haggling", "silver_tongue", "appraisal", "golden_touch",
		"investor", "fletcher", "field_surgeon", "windfall", "black_market",
	],
	"survivor": [
		"stamina", "resilience_unlock", "potions", "herbalism", "vampiric_grit", "vigilant_defense",
		"undying", "second_wind", "second_breath", "block_master", "last_stand", "shield_mastery",
		"unbreakable_guard", "favour",
	],
	"convergence": ["warband", "war_chest", "battle_medic", "war_profiteer"],
	"isolated": ["worldwalker"],
}

# assets/ filename stems, borrowed from the game's existing art so the tree
# needs no new sprites.
const NODE_ICONS := {
	"strength": "weapon_battle_axe", "agility": "cloth_feet", "dexterity_unlock": "weapon_dagger",
	"vigor": "food_meat", "reflexes_unlock": "shield_buckler", "berserker_edge": "weapon_hand_picks",
	"adrenaline": "potion", "battle_hardened": "blade_ally", "pack_leader": "barbarian",
	"prodigy": "talisman_uncommon", "warlord": "weapon_greatsword", "beastmaster": "enemy_wolf",
	"hardened": "armor_iron", "pack_bond": "meat", "riposte": "weapon_knuckle_gloves",
	"momentum": "weapon_spear", "rage": "enemy_orc",
	"coins": "coin", "intimidation": "cloth_head", "luck": "talisman_common", "haggling": "market_stall",
	"silver_tongue": "talisman_rare", "appraisal": "building_shop", "golden_touch": "talisman_epic",
	"investor": "quest_board", "fletcher": "quiver", "field_surgeon": "building_healer",
	"windfall": "runic_shard", "black_market": "building_enchanter",
	"stamina": "food_bread", "resilience_unlock": "armor_leather", "potions": "potion",
	"herbalism": "flower_bed", "vampiric_grit": "enemy_shade", "vigilant_defense": "shield_round",
	"undying": "building_church", "second_wind": "food_fish", "second_breath": "cloth_body",
	"block_master": "shield_bulwark", "last_stand": "armor_rags", "shield_mastery": "shield_brawler",
	"unbreakable_guard": "shield_phantom", "favour": "talisman_epic",
	"warband": "enemy_brute", "war_chest": "armor_steel", "battle_medic": "meat", "war_profiteer": "coin",
	"worldwalker": "enemy_voidwing",
}

const TOOLTIP_WIDTH := 330.0
const COLOR_GOOD := Color(0.55, 0.95, 0.55)
const COLOR_BAD := Color(1.0, 0.5, 0.45)
const COLOR_DIM := Color(0.68, 0.68, 0.72)

var essence_label: Label
var hint_label: Label
var recenter_button: Button
var view: Control
var tooltip: PanelContainer
var tooltip_name_label: Label
var tooltip_level_label: Label
var tooltip_desc_label: Label
var tooltip_cost_label: Label

var _data := {}
var _hover_id := ""

func _panel_title() -> String:
	return "THE CHURCH"

func _window_size() -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	return Vector2(maxf(viewport_size.x - 80.0, 640.0), maxf(viewport_size.y - 60.0, 480.0))

func _build_content(outer: VBoxContainer) -> void:
	window.add_theme_stylebox_override("panel", PixelUIScript.panel_style(true))
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	title_label.add_theme_color_override("font_outline_color", PixelUIScript.OUTLINE)
	title_label.add_theme_constant_override("outline_size", 6)
	PixelUIScript.skin_button(close_button)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	outer.add_child(header)
	var shard := TextureRect.new()
	shard.texture = load("res://assets/runic_shard.png")
	shard.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shard.custom_minimum_size = Vector2(30, 30)
	shard.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shard.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(shard)
	essence_label = Label.new()
	essence_label.add_theme_font_size_override("font_size", 24)
	essence_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.36))
	essence_label.add_theme_color_override("font_outline_color", PixelUIScript.OUTLINE)
	essence_label.add_theme_constant_override("outline_size", 5)
	header.add_child(essence_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	hint_label = _make_label("Drag to look around  |  Click a glowing node to spend Essence  |  Boons work at once", 13, COLOR_DIM)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(hint_label)
	recenter_button = Button.new()
	recenter_button.text = "Recenter"
	PixelUIScript.skin_button(recenter_button)
	recenter_button.pressed.connect(func(): view.center_on_hub())
	header.add_child(recenter_button)

	view = AscensionViewScript.new()
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.custom_minimum_size = Vector2(0, 260)
	outer.add_child(view)
	view.build(_node_defs(), load("res://assets/runic_shard.png"))
	view.node_pressed.connect(_on_node_pressed)
	view.node_hover_changed.connect(_on_node_hover_changed)
	_build_tooltip()

# --- Node data ---------------------------------------------------------------

func _wing_of(id: String) -> String:
	for wing in WING_MEMBERS:
		if id in WING_MEMBERS[wing]:
			return wing
	return "convergence"

func _node_defs() -> Array:
	var defs := []
	for id in SaveDataScript.UPGRADE_IDS:
		var parents := []
		for prereq in SaveDataScript.UPGRADES[id].get("prereqs", []):
			parents.append(prereq.id)
		var icon_path := "res://assets/%s.png" % NODE_ICONS.get(id, "runic_shard")
		var def := {
			"id": id,
			"parents": parents,
			"wing": _wing_of(id),
			"icon": load(icon_path) if ResourceLoader.exists(icon_path) else null,
		}
		if _wing_of(id) == "isolated":
			def["isolated"] = true
		defs.append(def)
	return defs

# --- State -------------------------------------------------------------------

func level_of(id: String) -> int:
	return int(_data.get("upgrades", {}).get(id, 0))

func max_level_of(id: String) -> int:
	return int(SaveDataScript.UPGRADES[id].get("max_level", 999999))

func next_cost_of(id: String) -> int:
	return SaveDataScript.get_upgrade_cost(id, level_of(id))

func can_afford(id: String) -> bool:
	return int(_data.get("essence", 0)) >= next_cost_of(id)

# The node's visual/logic state: "locked" (prereqs unmet), "unaffordable",
# "available" (buy its first level now), "owned", "upgradable" (owned, and the
# next level is affordable) or "mastered" (max level).
func state_for(id: String) -> String:
	var level := level_of(id)
	if level >= max_level_of(id):
		return "mastered"
	if not SaveDataScript.is_upgrade_unlocked(_data, id):
		return "locked"
	if level == 0:
		return "available" if can_afford(id) else "unaffordable"
	return "upgradable" if can_afford(id) else "owned"

func _badge_for(id: String) -> String:
	var level := level_of(id)
	if level <= 0 or max_level_of(id) == 1:
		return ""
	return str(level)

func _refresh() -> void:
	_data = SaveDataScript.load_data()
	if essence_label == null:
		return
	essence_label.text = "%d Essence" % int(_data.get("essence", 0))
	for id in SaveDataScript.UPGRADE_IDS:
		view.set_state(id, state_for(id), _badge_for(id))
	_update_tooltip()

func _on_opened() -> void:
	view.reset_view()
	# Keyboard/gamepad players need something focused to start from -- the first
	# node they can buy, else the tree's first root.
	var first := "strength"
	for id in SaveDataScript.UPGRADE_IDS:
		var state := state_for(id)
		if state == "available" or state == "upgradable":
			first = id
			break
	view.button_for(first).grab_focus()

func _on_closing() -> void:
	_hover_id = ""
	tooltip.visible = false

# --- Buying ------------------------------------------------------------------

func _on_node_pressed(id: String) -> void:
	var state := state_for(id)
	if state != "available" and state != "upgradable":
		_play_sfx("error")
		return
	if not SaveDataScript.try_buy_upgrade(_data, id):
		_play_sfx("error")
		return
	SaveDataScript.save_data(_data)
	_play_sfx("purchase")
	var main := get_parent()
	if main != null and main.has_method("apply_meta_purchase"):
		main.apply_meta_purchase(id)
	_refresh()

# --- Tooltip -----------------------------------------------------------------

func _build_tooltip() -> void:
	tooltip = PanelContainer.new()
	tooltip.visible = false
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.custom_minimum_size = Vector2(TOOLTIP_WIDTH, 0)
	var style: StyleBoxTexture = PixelUIScript.panel_style(true).duplicate()
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	tooltip.add_theme_stylebox_override("panel", style)
	view.add_child(tooltip)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.add_child(box)
	tooltip_name_label = _make_label("", 20, Color(1, 0.9, 0.4))
	tooltip_name_label.add_theme_color_override("font_outline_color", PixelUIScript.OUTLINE)
	tooltip_name_label.add_theme_constant_override("outline_size", 4)
	box.add_child(tooltip_name_label)
	tooltip_level_label = _make_label("", 13, COLOR_DIM)
	box.add_child(tooltip_level_label)
	tooltip_desc_label = _make_label("", 14, Color(0.92, 0.9, 0.84))
	# A fixed wrap width, so the tooltip never has to guess its height from a
	# not-yet-laid-out label (which reads as one character per line).
	tooltip_desc_label.custom_minimum_size = Vector2(TOOLTIP_WIDTH - 52.0, 0)
	box.add_child(tooltip_desc_label)
	tooltip_cost_label = _make_label("", 15, COLOR_GOOD)
	box.add_child(tooltip_cost_label)

func _on_node_hover_changed(id: String) -> void:
	_hover_id = id
	_update_tooltip()

func _update_tooltip() -> void:
	if tooltip == null:
		return
	if _hover_id == "" or not SaveDataScript.UPGRADES.has(_hover_id):
		tooltip.visible = false
		return
	var def: Dictionary = SaveDataScript.UPGRADES[_hover_id]
	var state := state_for(_hover_id)
	tooltip_name_label.text = def.name
	tooltip_name_label.add_theme_color_override("font_color", view.tint_of(_hover_id).lightened(0.25))
	tooltip_level_label.text = _level_text(_hover_id)
	tooltip_desc_label.text = def.description
	match state:
		"mastered":
			tooltip_cost_label.text = "Mastered"
			tooltip_cost_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.45))
		"locked":
			tooltip_cost_label.text = _requirement_text(_hover_id)
			tooltip_cost_label.add_theme_color_override("font_color", COLOR_BAD)
		_:
			var cost := next_cost_of(_hover_id)
			var missing: int = cost - int(_data.get("essence", 0))
			if missing > 0:
				tooltip_cost_label.text = "Cost: %d Essence (need %d more)" % [cost, missing]
				tooltip_cost_label.add_theme_color_override("font_color", COLOR_BAD)
			else:
				tooltip_cost_label.text = "Cost: %d Essence" % cost
				tooltip_cost_label.add_theme_color_override("font_color", COLOR_GOOD)
	tooltip.reset_size()
	tooltip.visible = true
	_reposition_tooltip()

func _level_text(id: String) -> String:
	var level := level_of(id)
	var max_level := max_level_of(id)
	if max_level == 1:
		return "Owned" if level >= 1 else "Not yet learned"
	if max_level >= 999999:
		return "Level %d" % level
	return "Level %d / %d" % [level, max_level]

# Every unmet prerequisite, or the lifetime gate for Worldwalker.
func _requirement_text(id: String) -> String:
	var def: Dictionary = SaveDataScript.UPGRADES[id]
	var lines: Array = []
	var flag: String = def.get("requires_lifetime_flag", "")
	if flag != "" and not SaveDataScript.load_lifetime_data().get(flag, false):
		lines.append("Beat the Nothingness once")
	var owned: Dictionary = _data.get("upgrades", {})
	for prereq in def.get("prereqs", []):
		if int(owned.get(prereq.id, 0)) < int(prereq.min_level):
			var need: Dictionary = SaveDataScript.UPGRADES[prereq.id]
			lines.append("%s (Lv %d)" % [need.name, prereq.min_level] if int(prereq.min_level) > 1 else need.name)
	return "Requires: " + ", ".join(lines)

func _reposition_tooltip() -> void:
	if tooltip == null or not tooltip.visible or _hover_id == "" or not view.node_ids().has(_hover_id):
		return
	var rect: Rect2 = view.node_rect_in_view(_hover_id)
	var size_now := tooltip.get_combined_minimum_size()
	tooltip.size = size_now
	var gap := 16.0
	var x := rect.end.x + gap
	if x + size_now.x > view.size.x - 8.0:
		x = rect.position.x - gap - size_now.x
	var y := rect.position.y + rect.size.y * 0.5 - size_now.y * 0.5
	tooltip.position = Vector2(
		clampf(x, 8.0, maxf(8.0, view.size.x - size_now.x - 8.0)),
		clampf(y, 8.0, maxf(8.0, view.size.y - size_now.y - 8.0))
	).round()

# The tooltip follows its node while the view pans (a focus-scroll or drag).
func _process(_delta: float) -> void:
	if visible and tooltip != null and tooltip.visible:
		_reposition_tooltip()
