extends TownPanel
class_name BlacksmithPanel

# The town Blacksmith: pay coins to upgrade any owned weapon (up to +5) or your
# metal armour (up to +3). The rules and numbers live in Blacksmith.gd; the
# levels themselves are Player state (weapon_upgrade_levels /
# armor_upgrade_levels), applied whenever a weapon is equipped or damage is
# reduced -- so an upgrade takes effect everywhere at once.

const BlacksmithScript := preload("res://scripts/Blacksmith.gd")
const ArmorScript := preload("res://scripts/Armor.gd")
const WeaponsScript := preload("res://scripts/Weapons.gd")

var coins_label: Label
var weapons_box: VBoxContainer
var armor_box: VBoxContainer
var speech_label: Label

func _panel_title() -> String:
	return "THE BLACKSMITH"

func _window_size() -> Vector2:
	return Vector2(680, 580)

func _build_content(outer: VBoxContainer) -> void:
	speech_label = _make_label("", 14, Color(0.8, 0.8, 0.75))
	outer.add_child(speech_label)
	coins_label = _make_label("", 15, Color(1.0, 0.85, 0.3))
	outer.add_child(coins_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 8)
	scroll.add_child(stack)
	stack.add_child(_make_label("WEAPONS", 13, Color(1.0, 0.9, 0.3)))
	weapons_box = VBoxContainer.new()
	weapons_box.add_theme_constant_override("separation", 6)
	stack.add_child(weapons_box)
	stack.add_child(_make_label("ARMOUR", 13, Color(1.0, 0.9, 0.3)))
	armor_box = VBoxContainer.new()
	armor_box.add_theme_constant_override("separation", 6)
	stack.add_child(armor_box)

func _on_opened() -> void:
	speech_label.text = "\"Bring me steel and coin and I'll make it bite harder. Metal armour too -- I don't work leather.\""

func _refresh() -> void:
	if _player == null or weapons_box == null:
		return
	coins_label.text = "Coins: %d" % _player.coins
	_clear(weapons_box)
	_clear(armor_box)

	var current_id: String = _player.current_weapon_base.get("id", "")
	for id in _player.owned_weapons:
		var variant: Dictionary = WeaponsScript.get_owned_variant(id)
		if variant.is_empty():
			continue
		var level: int = _player.get_weapon_upgrade_level(id)
		var cost: int = BlacksmithScript.weapon_cost(level)
		var title: String = variant.name if level == 0 else "%s +%d" % [variant.name, level]
		var desc := "+%d%% damage per level (max +%d), and fewer breaks." % [int(BlacksmithScript.WEAPON_DAMAGE_PCT_PER_LEVEL * 100), BlacksmithScript.WEAPON_MAX_LEVEL]
		var button_text := "Upgrade"
		var price_text := "%d c" % cost
		var disabled: bool = _player.coins < cost
		if cost < 0:
			button_text = "Maxed"
			price_text = ""
			disabled = true
		weapons_box.add_child(_make_shop_row(
			"weapon_%s" % variant.get("icon", ""), title, desc, price_text, button_text, disabled,
			_on_upgrade_weapon_pressed.bind(id), id == current_id
		))

	for armor in ArmorScript.TIERS:
		if not _player.owned_armor.has(armor.id) or armor.id == "armor_rags":
			continue
		var equipped: bool = armor.id == _player.equipped_armor.get("id", "")
		if not armor.get("metal", false):
			armor_box.add_child(_make_shop_row(
				armor.icon, armor.name, "Not metal -- the smith won't touch it.", "", "Can't", true, Callable(), equipped
			))
			continue
		var level: int = _player.get_armor_upgrade_level(armor.id)
		var cost: int = BlacksmithScript.armor_cost(level)
		var title: String = armor.name if level == 0 else "%s +%d" % [armor.name, level]
		var desc := "+%.1f%% damage reduction per level (max +%d)." % [BlacksmithScript.ARMOR_DR_PER_LEVEL * 100.0, BlacksmithScript.ARMOR_MAX_LEVEL]
		var button_text := "Upgrade"
		var price_text := "%d c" % cost
		var disabled: bool = _player.coins < cost
		if cost < 0:
			button_text = "Maxed"
			price_text = ""
			disabled = true
		armor_box.add_child(_make_shop_row(
			armor.icon, title, desc, price_text, button_text, disabled,
			_on_upgrade_armor_pressed.bind(armor.id), equipped
		))
	if armor_box.get_child_count() == 0:
		armor_box.add_child(_make_label("You own no armour worth working yet.", 13, Color(0.7, 0.7, 0.65)))

# Both return whether the upgrade went through (tests drive these directly).
func upgrade_weapon(weapon_id: String) -> bool:
	var ok: bool = _player.try_upgrade_weapon(weapon_id)
	_play_sfx("purchase" if ok else "error")
	speech_label.text = "\"There. Sharper than the day it was forged.\"" if ok else "\"Can't do that one -- not enough coin, or it's already as good as I can make it.\""
	_refresh()
	return ok

func upgrade_armor(armor_id: String) -> bool:
	var ok: bool = _player.try_upgrade_armor(armor_id)
	_play_sfx("purchase" if ok else "error")
	speech_label.text = "\"Reinforced. That'll turn a blade.\"" if ok else "\"No. Not enough coin, not metal, or already maxed.\""
	_refresh()
	return ok

func _on_upgrade_weapon_pressed(weapon_id: String) -> void:
	upgrade_weapon(weapon_id)

func _on_upgrade_armor_pressed(armor_id: String) -> void:
	upgrade_armor(armor_id)
