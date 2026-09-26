extends TownPanel
class_name DojoPanel

# The town Dojo: a list of every weapon type you hold, each with its three
# special moves and a Learn button. The rules (costs, which types teach) live
# in Dojo.gd; what's been learned is Player.learned_specials.

const DojoScript := preload("res://scripts/Dojo.gd")
const WeaponsScript := preload("res://scripts/Weapons.gd")

var coins_label: Label
var speech_label: Label
var lessons_box: VBoxContainer

func _panel_title() -> String:
	return "THE DOJO"

func _window_size() -> Vector2:
	return Vector2(700, 600)

func _build_content(outer: VBoxContainer) -> void:
	speech_label = _make_label("", 14, Color(0.8, 0.8, 0.75))
	outer.add_child(speech_label)
	coins_label = _make_label("", 15, Color(1.0, 0.85, 0.3))
	outer.add_child(coins_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	lessons_box = VBoxContainer.new()
	lessons_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lessons_box.add_theme_constant_override("separation", 6)
	scroll.add_child(lessons_box)

func _on_opened() -> void:
	speech_label.text = "\"A weapon is only as good as the moves you've drilled into it. Pay the fee, put in the hours, and it's yours for good.\""

func _refresh() -> void:
	if _player == null or lessons_box == null:
		return
	coins_label.text = "Coins: %d" % _player.coins
	_clear(lessons_box)
	var current_base_id: String = WeaponsScript.get_base_type(_player.current_weapon_base).get("id", "")
	for base in DojoScript.owned_bases(_player.owned_weapons):
		var heading: String = base.name.to_upper()
		if base.id == current_base_id:
			heading += "  (in hand)"
		lessons_box.add_child(_make_label(heading, 13, Color(1.0, 0.9, 0.3)))
		var specials: Array = base.specials
		for i in specials.size():
			var special: Dictionary = specials[i]
			var learned: bool = _player.knows_special(special.id)
			var cost: int = DojoScript.lesson_cost(i)
			var description: String = "%s  [%d STA]" % [special.description, special.stamina_cost]
			var button_text := "Learn"
			var price_text := "%d c" % cost
			var disabled: bool = _player.coins < cost
			if learned:
				button_text = "Learned"
				price_text = ""
				disabled = true
			lessons_box.add_child(_make_shop_row(
				"weapon_%s" % base.get("icon", ""), special.name, description, price_text, button_text, disabled,
				_on_learn_pressed.bind(special.id), learned
			))
	if lessons_box.get_child_count() == 0:
		lessons_box.add_child(_make_label("You hold no weapons with moves to teach.", 13, Color(0.7, 0.7, 0.65)))

# Returns whether the lesson went through (tests drive this directly).
func learn(special_id: String) -> bool:
	var ok: bool = _player.try_learn_special(special_id)
	_play_sfx("purchase" if ok else "error")
	if ok:
		speech_label.text = "\"Good. Again -- until you stop thinking about it.\""
		_announce_learned(special_id)
	else:
		speech_label.text = "\"Not enough coin, or you already know it. Come back when you've earned more.\""
	_refresh()
	return ok

func _announce_learned(special_id: String) -> void:
	var main := get_parent()
	var found: Dictionary = DojoScript.locate_special(special_id)
	if not found.is_empty() and main != null and main.hud != null:
		main.hud.show_message("You learned %s!" % found.special.name)

func _on_learn_pressed(special_id: String) -> void:
	learn(special_id)
