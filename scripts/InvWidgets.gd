extends RefCounted
class_name InvWidgets

# The small pieces the inventory's detail panels are made of: a "what it does to you" row (icon, label, before > after, the change),
# a plain icon row, a sunken description box. The arrow is the chevron the pixel fonts have (they have no real arrow).

const ARROW := "›"
const ROW_W := 420.0   # the room a row has inside the narrowest detail card (the gear popup's), past which a value drops below its label
const UIIconsScript := preload("res://scripts/UIIcons.gd")

# Row labels -> the icon in front of them.
const LABEL_ICONS := {
	"Damage": "stat_damage", "Attack": "stat_damage", "Defense": "stat_defense", "Bodily harm": "stat_defense", "Block chance": "stat_defense",
	"FTD": "stat_fortitude", "HP": "stat_health", "Stamina": "stat_stamina", "Mana": "stat_mana", "Speed": "stat_speed", "Passive": "stat_crit",
	"Rune": "stat_magic", "Magic": "stat_magic", "Needs": "stat_might",
}
# Abbreviated labels with a longer tooltip.
const LABEL_TIPS := {"FTD": "Fortitude (FTD): magical defense"}

# One "what it does to you" row appended to `parent`. [label, from, to, note, icons]; from may be "" (just the value).
static func stat_row(parent: Control, label: String, from: String, to: String, note: String = "", icons: Array = []) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, 36)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	var left := HBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(left)
	var shown_icons: Array = icons if not icons.is_empty() else ([LABEL_ICONS[label]] if LABEL_ICONS.has(label) else [])
	for icon_name in shown_icons:
		left.add_child(PixelKit.icon(str(icon_name), 32))
	var name_label := PixelKit.label(label)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(name_label)
	var value_text := ("%s %s %s" % [from, ARROW, to]) if from != "" else to
	# a value too long to sit beside its label (a Mythic's passive) drops below it as a wrapped paragraph instead of running off the card
	var f: Font = PixelKit.font("body")
	var fs := PixelKit.font_size("body")
	var used := 32.0 * shown_icons.size() + 8.0 * shown_icons.size() + f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 12.0
	var value_w := f.get_string_size(value_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var note_w := (f.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 12.0) if note != "" else 0.0
	var block := used + value_w + note_w + 12.0 > ROW_W
	if block:
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(gap)
		if note != "":
			row.add_child(_note_label(note))
		var text := PixelKit.label(value_text, "body", PixelKit.CREAM)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.custom_minimum_size = Vector2(0, 0)
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pad := MarginContainer.new()
		pad.add_theme_constant_override("margin_left", 40)
		pad.add_theme_constant_override("margin_bottom", 6)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pad.add_child(text)
		box.add_child(pad)
	else:
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(spacer)
		var value := PixelKit.label(value_text)
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(value)
		if note != "":
			row.add_child(_note_label(note))
	box.add_child(PixelKit.rule())
	if LABEL_TIPS.has(label):
		box.tooltip_text = str(LABEL_TIPS[label])
	parent.add_child(box)
	return box

static func _note_label(note: String) -> Label:
	var color: Color = PixelKit.GOOD if note.begins_with("+") else (PixelKit.BAD if note.begins_with("−") or note.begins_with("-") else PixelKit.DIM)
	var note_label := PixelKit.label(note, "body", color)
	note_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return note_label

# A row of an icon, a name and a right-aligned gold value (stats, run totals).
static func icon_row(parent: Control, icon_name: String, left_text: String, right_text: String, tip: String = "", right_color: Color = PixelKit.GOLD3) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, 36)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	if icon_name != "":
		row.add_child(PixelKit.icon(icon_name, 32))
	else:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(32, 0)
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(gap)
	var l := PixelKit.label(left_text)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	var r := PixelKit.label(right_text, "body", right_color)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(r)
	box.add_child(PixelKit.rule())
	if tip != "":
		box.tooltip_text = tip
	parent.add_child(box)
	return box

# A sunken box with wrapped text in it (descriptions).
static func desc_box(text: String, color: Color = PixelKit.CREAM, min_height: float = 0.0) -> PanelContainer:
	var p := PixelKit.panel("inset", 4, 2)
	p.custom_minimum_size = Vector2(0, min_height)
	var l := PixelKit.label(text, "body", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	p.set_meta("label", l)
	return p

# A small dim caption ("Specials", "Charm slots").
static func caption(text: String) -> Label:
	var l := PixelKit.label(text, "body", PixelKit.DIM)
	return l

# A wrapped dim paragraph.
static func paragraph(text: String, color: Color = PixelKit.DIM, centered: bool = false) -> Label:
	var l := PixelKit.label(text, "body", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

static func stat_tooltip(abbr: String) -> String:
	for id in UIIconsScript.STAT_ORDER:
		if UIIconsScript.stat_abbr(id) == abbr:
			return UIIconsScript.stat_tooltip(id)
	return ""
