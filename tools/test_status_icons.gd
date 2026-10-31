extends SceneTree

# The artists' hand-drawn icons in use: the battle status pictures (party cards, hover popup, details box), the two shaking eyes
# (Bloodboost / Bloodcrash), the coin that drops, the per-kind arrow art, and the coin icon wherever coins are counted.

func _init() -> void:
	seed(20261030)
	load("res://scripts/SaveData.gd").mark_tutorial_completed()
	var statuses_script = load("res://scripts/BattleStatuses.gd")
	var icons = load("res://scripts/UIIcons.gd")

	# --- the status list itself ---
	var sample: Array = [statuses_script.entry("poison", "2 turns"), statuses_script.entry("stealth", "3 turns"), statuses_script.entry("burn"), statuses_script.entry("poison", "1 turn")]
	print("only statuses with a picture go in a tray, each once, in order: %s (expected [poison, burn])" % [statuses_script.ids_with_icons(sample)])
	var hero_entries: Array = statuses_script.for_hero({"bloodboost": 3, "bloodcrash": true})
	print("the hero's Bloodboost and Bloodcrash are statuses now: %s (expected [Bloodboost x3, Bloodcrash])" % [hero_entries.map(func(e): return (e.name + " " + e.detail).strip_edges())])
	print("...with pictures, and the Bloodboost reads as a blessing and the crash as a curse: boost good=%s crash good=%s (expected true, false)" % [hero_entries[0].good, hero_entries[1].good])
	print("a status with no art has no entry in the tray: %s (expected [])" % [statuses_script.ids_with_icons([statuses_script.entry("stealth"), statuses_script.entry("berserk"), statuses_script.entry("downed")])])

	# --- the battle screen ---
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	var hud = main.hud
	player.max_party_slots = 20
	for kind in ["knight", "rogue"]:
		player.recruit(kind)
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)
	var orc = load("res://scripts/Orc.gd").new()
	main.add_child(orc)
	orc.global_position = player.global_position + Vector2(30, 0)
	main.trigger_battle(orc)
	await process_frame
	await process_frame
	main.battle_terrain.clear()
	main.battle_turn = "player"
	main.battle_menu_state = "main"
	var hero_card = hud.battle_party_cards[0]
	main._refresh_battle_display()
	var shown_slots := func(card: Dictionary) -> Array:
		return card.tray.filter(func(s): return s.visible)
	print("a card with no statuses has an empty tray and its chip line at the left edge: shown=%d x=%.0f (expected 0, 10)" % [shown_slots.call(hero_card).size(), hero_card.status.position.x])

	main.player_burning = true
	main.player_poison_turns = 2
	main.player_poison_dmg = 1
	player.stealth_turns_remaining = 3
	main._refresh_battle_display()
	var slots: Array = shown_slots.call(hero_card)
	print("burning + poison + stealth on the hero: two pictures in the tray (stealth has none), words kept: shown=%d (expected 2), text='%s' (expected one that names all three)" % [slots.size(), hero_card.status.text])
	print("the pictures are the poison drop then the burning flame (the order the card lists them), 16x16: %s %s (expected true true)" % [
		slots[0].texture == icons.texture("status_poison"), slots[1].texture == icons.texture("status_burned")])
	print("the chip line moved right to make room and still fits the card: x=%.0f (expected 48), right edge %.0f (expected <= 198)" % [hero_card.status.position.x, hero_card.status.position.x + hero_card.status.size.x])
	print("the card's tooltip is unchanged by the pictures: begins with a status name = %s (expected true)" % [hero_card.panel.tooltip_text.contains("Burning: ")])

	# the hover popup over a unit
	var row: Dictionary = main._hero_info_row()
	hud.show_unit_popup(row, Vector2i(2, 2), 1)
	var popup_slots: Array = hud.battle_popup.tray.filter(func(s): return s.visible)
	print("the popup over a unit shows the same two pictures ahead of its words: shown=%d (expected 2), text x=%.0f (expected 46)" % [popup_slots.size(), hud.battle_popup.status.position.x])
	hud.hide_unit_popup()

	# the details box
	hud.show_unit_details(row)
	var rows: Array = hud.battle_details.rows
	var by_name := {}
	for r in rows:
		if r.row.visible:
			by_name[r.name.text] = r
	print("the details box rows: %s (expected Stealth, Burning, Poison in some order)" % [by_name.keys()])
	print("a status with a picture shows it doubled (32px) in place of the gold diamond, words shifted: poison picture=%s mark hidden=%s text x=%.0f size=%s (expected true, true, 44, (32, 32))" % [
		by_name["Poison"].picture.visible and by_name["Poison"].picture.texture == icons.texture("status_poison"), not by_name["Poison"].mark.visible, by_name["Poison"].name.position.x, by_name["Poison"].picture.size])
	print("a status without one keeps the diamond and the old text position: picture visible=%s mark visible=%s text x=%.0f (expected false, true, 26)" % [
		by_name["Stealth"].picture.visible, by_name["Stealth"].mark.visible, by_name["Stealth"].name.position.x])
	hud.hide_unit_details()
	main.player_burning = false
	main.player_poison_turns = 0
	player.stealth_turns_remaining = 0

	# the eyes
	player.bloodmoon_stacks = 2
	main._refresh_battle_display()
	hud.show_unit_details(main._hero_info_row())
	var eye_row = null
	for r in hud.battle_details.rows:
		if r.row.visible and r.name.text == "Bloodboost":
			eye_row = r
	print("Bloodboost (the shaking eye) is in the details box with its animation running: found=%s, playing=%s (expected true, true), words='%s' (expected x2)" % [
		eye_row != null, eye_row != null and eye_row.picture.texture is AtlasTexture and eye_row.picture.is_processing(), eye_row.detail.text if eye_row != null else ""])
	player.bloodmoon_stacks = 0
	player.bloodmoon_debuffed = true
	main._refresh_battle_display()
	var crash_slots: Array = shown_slots.call(hero_card)
	print("after the crash the card shows the other eye: shown=%d (expected 1), it is the crash picture=%s (expected true)" % [crash_slots.size(), crash_slots.size() > 0 and crash_slots[0].texture is AtlasTexture and crash_slots[0].texture.atlas == icons.strip("status_bloodcrash")])
	player.bloodmoon_debuffed = false
	hud.hide_unit_details()

	# --- the coin that drops ---
	var coin = load("res://scripts/Pickup.gd").new()
	coin.kind = "coin"
	main.add_child(coin)
	var shard = load("res://scripts/Pickup.gd").new()
	shard.kind = "shard"
	main.add_child(shard)
	print("a dropped coin is the 8x8 drawing at 2x: %s at scale %s (expected (8, 8) at (2, 2)); other pickups keep 1.5x: %s (expected (1.5, 1.5))" % [coin.sprite.texture.get_size(), coin.sprite.scale, shard.sprite.scale])

	# --- the arrows ---
	player.owned_arrows = {"flame": 2, "freeze": 1, "bomb": 3}
	var arrows: Array = load("res://scripts/InvData.gd").arrow_entries(player)
	var pictures := {}
	var sizes: Array = []
	for a in arrows:
		pictures[a.art.get_image().get_data().hex_encode()] = a.id
		sizes.append(a.art.get_size())
	print("each kind of arrow has its own picture in the inventory, 16x16: %d kinds, %d different pictures, sizes %s (expected 3, 3, all (16, 16))" % [arrows.size(), pictures.size(), sizes])
	var quiver_img: Image = load("res://assets/quiver.png").get_image()
	print("...and none is the old shared quiver: %s (expected true)" % [not pictures.has(quiver_img.get_data().hex_encode())])
	print("the coin used where coins are counted is the 16x16 stat_coin: %s (expected (16, 16))" % [icons.texture("stat_coin").get_size()])
	quit()
