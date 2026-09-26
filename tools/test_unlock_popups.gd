extends SceneTree

# Covers the "first time you obtained X" popup system: device-wide seen-set
# in SaveData.gd, Weapons.gd's base-type derivation, and the 5 acquisition
# call sites (skill tree in TitleScreen.gd; weapons/shields/arrows/runes in
# Main.gd), each showing exactly once ever, non-blocking, no queue.

func _init() -> void:
	var save_data_script = load("res://scripts/SaveData.gd")
	var weapons_script = load("res://scripts/Weapons.gd")
	var lifetime_path: String = save_data_script._resolve_lifetime_path()
	if FileAccess.file_exists(lifetime_path):
		DirAccess.remove_absolute(lifetime_path)

	# --- SaveData primitives ---
	print("fresh key starts unseen: %s (expected true)" % [not save_data_script.is_unlock_seen("weapon:spear")])
	print("try_mark_unlock_seen returns true the first time: %s (expected true)" % [save_data_script.try_mark_unlock_seen("weapon:spear")])
	print("...and false every time after: %s (expected false)" % [save_data_script.try_mark_unlock_seen("weapon:spear")])
	print("is_unlock_seen reflects it: %s (expected true)" % [save_data_script.is_unlock_seen("weapon:spear")])
	save_data_script.active_slot = 2
	print("device-wide -- survives an active_slot switch: %s (expected true)" % [save_data_script.is_unlock_seen("weapon:spear")])
	save_data_script.active_slot = 1
	if FileAccess.file_exists(lifetime_path):
		DirAccess.remove_absolute(lifetime_path)

	# --- Weapons.get_base_type ---
	var all_match := true
	for base in weapons_script.UPGRADABLE_TYPES:
		var variant: Dictionary = weapons_script.make_variant(base, 0)
		if weapons_script.get_base_type(variant).id != base.id:
			all_match = false
		var mythic_variant := {"id": "%s_mythic" % base.id}
		if weapons_script.get_base_type(mythic_variant).id != base.id:
			all_match = false
	print("get_base_type round-trips every UPGRADABLE_TYPES base (tier variant + mythic), no prefix collisions: %s (expected true)" % all_match)
	print("get_base_type handles Club (no variants): %s (expected true)" % [weapons_script.get_base_type(weapons_script.CLUB).id == "club"])

	# --- Scenario: Main.gd acquisition points ---
	var main_scene = load("res://Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame

	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)

	var player = main.player
	player.coins = 100000
	player.runic_shards = 100

	# Weapon: first Spear variant purchased -> popup fires with SPEAR's own
	# name/description (never the composed variant's).
	var spear_variant_1: Dictionary = weapons_script.make_variant(weapons_script.SPEAR, 0)
	main.current_shop_offering = [main._tagged(spear_variant_1, "weapon")]
	main._on_shop_buy_pressed(0)
	print("first weapon (Spear) purchase shows the popup: visible=%s title=%s (expected true, %s)" % [
		main.hud.unlock_popup_panel.visible, main.hud.unlock_popup_name_label.text, weapons_script.SPEAR.name
	])
	print("...with the base type's description, not the variant's: %s (expected true)" % [
		main.hud.unlock_popup_desc_label.text == weapons_script.SPEAR.description
	])
	print("...and the key is marked seen: %s (expected true)" % [save_data_script.is_unlock_seen("weapon:spear")])

	# A different Spear variant (new owned_weapons entry, same base type) does
	# NOT re-trigger.
	main.hud.hide_unlock_popup()
	main.current_shop_offering = [main._tagged(weapons_script.make_variant(weapons_script.SPEAR, 0), "weapon")]
	main._on_shop_buy_pressed(0)
	print("a second, different Spear variant does not re-trigger: %s (expected false)" % [main.hud.unlock_popup_panel.visible])

	# Re-equipping the same already-owned item (not a new grant) does not
	# trigger either -- reuse the exact first variant dict (a stub with only
	# id/name/price is missing fields _equip_weapon/show_shop need, like icon).
	player._equip_weapon(weapons_script.CLUB)
	main.current_shop_offering = [main._tagged(spear_variant_1, "weapon")]
	main._on_shop_buy_pressed(0)
	print("re-equipping an already-owned weapon does not trigger: %s (expected false)" % [main.hud.unlock_popup_panel.visible])

	# A genuinely new base type (Dagger) does trigger.
	main.current_shop_offering = [main._tagged(weapons_script.make_variant(weapons_script.DAGGER, 0), "weapon")]
	main._on_shop_buy_pressed(0)
	print("a new weapon type (Dagger) triggers its own popup: title=%s (expected %s)" % [main.hud.unlock_popup_name_label.text, weapons_script.DAGGER.name])
	main.hud.hide_unlock_popup()

	# Shield: first Buckler purchase triggers; a second shield (Heavy) also
	# triggers its own; rebuying Buckler doesn't.
	var shields_script = load("res://scripts/Shields.gd")
	main.current_shop_offering = [main._tagged(shields_script.SHIELDS["shield_buckler"], "shield")]
	main._on_shop_buy_pressed(0)
	print("first shield (Buckler) purchase shows the popup: visible=%s title=%s key_seen=%s (expected true, %s, true)" % [
		main.hud.unlock_popup_panel.visible, main.hud.unlock_popup_name_label.text, save_data_script.is_unlock_seen("shield:buckler"), shields_script.SHIELDS["shield_buckler"].name
	])
	main.hud.hide_unlock_popup()
	main.current_shop_offering = [main._tagged(shields_script.SHIELDS["shield_buckler"], "shield")]
	main._on_shop_buy_pressed(0)
	print("rebuying the same shield does not re-trigger: %s (expected false)" % [main.hud.unlock_popup_panel.visible])
	main.current_shop_offering = [main._tagged(shields_script.SHIELDS["shield_heavy"], "shield")]
	main._on_shop_buy_pressed(0)
	print("a different shield (Heavy) triggers its own popup: title=%s (expected %s)" % [main.hud.unlock_popup_name_label.text, shields_script.SHIELDS["shield_heavy"].name])
	main.hud.hide_unlock_popup()

	# Arrow: first flame arrow triggers; buying more, or selling to 0 and
	# rebuying, doesn't (lifetime-seen, not run-local).
	main._on_arrow_buy_pressed("flame")
	print("first arrow (Flame) purchase shows the popup: visible=%s key_seen=%s (expected true, true)" % [
		main.hud.unlock_popup_panel.visible, save_data_script.is_unlock_seen("arrow:flame")
	])
	main.hud.hide_unlock_popup()
	main._on_arrow_buy_pressed("flame")
	print("a second Flame arrow does not re-trigger: %s (expected false)" % [main.hud.unlock_popup_panel.visible])
	player.owned_arrows["flame"] = 0
	main._on_arrow_buy_pressed("flame")
	print("selling back to 0 and rebuying still does not re-trigger (lifetime, not run-local): %s (expected false)" % [main.hud.unlock_popup_panel.visible])
	main._on_arrow_buy_pressed("freeze")
	print("a different arrow kind (Freeze) triggers its own popup: visible=%s (expected true)" % [main.hud.unlock_popup_panel.visible])
	main.hud.hide_unlock_popup()

	# Rune: first Ember application triggers; reapplying (even to a
	# different weapon, simulating a later run) doesn't.
	var enchantments_script = load("res://scripts/Enchantments.gd")
	var spear_a: Dictionary = weapons_script.SPEAR.duplicate(true)
	spear_a.id = "spear_rune_test_a"
	player.owned_weapons[spear_a.id] = true
	player._equip_weapon(spear_a)
	main._on_enchant_apply_pressed("ember")
	print("first rune (Ember) application shows the popup: visible=%s title=%s key_seen=%s (expected true, %s, true)" % [
		main.hud.unlock_popup_panel.visible, main.hud.unlock_popup_name_label.text, save_data_script.is_unlock_seen("rune:ember"), enchantments_script.get_rune("ember").name
	])
	main.hud.hide_unlock_popup()
	player.weapon_enchantments.clear()
	var spear_b: Dictionary = weapons_script.SPEAR.duplicate(true)
	spear_b.id = "spear_rune_test_b"
	player.owned_weapons[spear_b.id] = true
	player._equip_weapon(spear_b)
	main._on_enchant_apply_pressed("ember")
	print("reapplying Ember to a different weapon (later-run scenario) does not re-trigger: %s (expected false)" % [main.hud.unlock_popup_panel.visible])

	# A fresh, still-unenchanted weapon for the Leech check -- a weapon can
	# only hold one rune at a time, so reusing spear_b (already Ember'd above)
	# would fail the apply outright rather than testing anything about Leech.
	var spear_c: Dictionary = weapons_script.SPEAR.duplicate(true)
	spear_c.id = "spear_rune_test_c"
	player.owned_weapons[spear_c.id] = true
	player._equip_weapon(spear_c)
	main._on_enchant_apply_pressed("leech")
	print("a different rune (Leech) triggers its own popup: visible=%s (expected true)" % [main.hud.unlock_popup_panel.visible])
	main.hud.hide_unlock_popup()

	# Failed purchase never announces.
	player.coins = 0
	main.current_shop_offering = [main._tagged(weapons_script.make_variant(weapons_script.GREATSWORD, 0), "weapon")]
	main._on_shop_buy_pressed(0)
	print("a failed purchase (no coins) never announces: visible=%s key_seen=%s (expected false, false)" % [
		main.hud.unlock_popup_panel.visible, save_data_script.is_unlock_seen("weapon:greatsword")
	])

	# Simultaneous overwrite -- no queue, second call just overwrites.
	player.coins = 100000
	main.current_shop_offering = [
		main._tagged(weapons_script.make_variant(weapons_script.HAMMER, 0), "weapon"),
		main._tagged(shields_script.SHIELDS["shield_bulwark"], "shield"),
	]
	main._on_shop_buy_pressed(0)
	main._on_shop_buy_pressed(1)
	print("two unlocks fired back-to-back without dismissing -- final text is the second one, no crash: %s (expected %s)" % [
		main.hud.unlock_popup_name_label.text, shields_script.SHIELDS["shield_bulwark"].name
	])

	# Dismiss button + non-blocking.
	var paused_before: bool = main.get_tree().paused
	var in_battle_before: bool = main.in_battle
	var shop_open_before: bool = main.shop_open
	main.hud.unlock_popup_dismiss_button.pressed.emit()
	print("dismiss hides the panel without touching paused/in_battle/shop_open: hidden=%s state_unchanged=%s (expected true, true)" % [
		not main.hud.unlock_popup_panel.visible,
		main.get_tree().paused == paused_before and main.in_battle == in_battle_before and main.shop_open == shop_open_before
	])

	main.queue_free()
	await process_frame

	# --- Scenario: TitleScreen.gd skill tree ---
	if FileAccess.file_exists(lifetime_path):
		DirAccess.remove_absolute(lifetime_path)

	var title_scene = load("res://TitleScreen.tscn")
	var title = title_scene.instantiate()
	root.add_child(title)
	await physics_frame
	await physics_frame

	title.save_data = {"essence": 100000, "upgrades": {}, "best_wave": 0}
	title._on_buy_upgrade_pressed("strength")
	print("first skill-node level (Brawn) shows the popup: visible=%s title=%s key_seen=%s (expected true, %s, true)" % [
		title.unlock_popup_panel.visible, title.unlock_popup_name_label.text, save_data_script.is_unlock_seen("skill:strength"), save_data_script.UPGRADES["strength"].name
	])
	title.hide_unlock_popup()
	title._on_buy_upgrade_pressed("strength")
	print("a later level of the same node does not re-trigger: %s (expected false)" % [title.unlock_popup_panel.visible])

	title.queue_free()
	await process_frame

	if FileAccess.file_exists(lifetime_path):
		DirAccess.remove_absolute(lifetime_path)
	quit()
