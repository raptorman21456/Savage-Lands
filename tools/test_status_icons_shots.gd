extends SceneTree

# Not a test: screenshots of the hand-drawn status icons in the battle screen (party cards, the popup over a unit, the details box, the
# shaking eyes), the dropped coin and the coin in the overworld HUD, into ui_screenshots/icons/. Needs a real window (it skips itself
# headless). Named test_* so SaveData uses scratch saves and never touches your real ones.
#
#   Godot --path . --resolution 1152x648 --script res://tools/test_status_icons_shots.gd

var out_dir := ""
var count := 0

func _shot(label: String, frames: int = 8) -> void:
	for i in frames:
		await process_frame
	count += 1
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s%02d_%s.png" % [out_dir, count, label])
	print("shot %02d %s" % [count, label])

func _init() -> void:
	if DisplayServer.get_name() == "headless":
		print("test_status_icons_shots: needs a window, skipped (run it without --headless)")
		quit()
		return
	seed(20261030)
	out_dir = ProjectSettings.globalize_path("res://ui_screenshots/icons/")
	DirAccess.make_dir_recursive_absolute(out_dir)
	for f in DirAccess.get_files_at(out_dir):
		if f.ends_with(".png"):
			DirAccess.remove_absolute(out_dir + f)
	load("res://scripts/SaveData.gd").mark_tutorial_completed()
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.player
	var hud = main.hud
	player.max_party_slots = 20
	for kind in ["knight", "druid", "rogue"]:
		player.recruit(kind)
	player.coins = 245
	main.hud.update_coins(245)
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)
	var coin = load("res://scripts/Pickup.gd").new()
	coin.kind = "coin"
	main.add_child(coin)
	coin.global_position = player.global_position + Vector2(40, 10)
	await _shot("overworld_coin_hud_and_drop", 12)
	coin.queue_free()

	var orc = load("res://scripts/Orc.gd").new()
	main.add_child(orc)
	orc.global_position = player.global_position + Vector2(30, 0)
	main.trigger_battle(orc)
	for i in 6:
		await process_frame
	main.battle_terrain.clear()
	main.battle_turn = "player"
	main.battle_menu_state = "main"
	# Every status that has a picture, spread over the party and the foe.
	main.player_burning = true
	main.player_poison_turns = 3
	main.player_poison_dmg = 1
	player.stealth_turns_remaining = 2
	player.bloodmoon_stacks = 3
	main.battle_player_defending = true
	for a in main.battle_allies:
		if a.kind == "rogue":
			a["stealth_turns"] = 3
			a["disarmed_tile"] = main._pick_disarm_tile()
		elif a.kind == "druid":
			a["charm_turns"] = 2
			a["defending"] = true
	var foe: Dictionary = main.battle_units[0]
	foe["poison_turns"] = 2
	foe["burning"] = true
	foe["frozen_turns"] = 2
	foe["bleed_turns"] = 2
	foe["vulnerable_turns"] = 2
	main._refresh_battle_display()
	await _shot("battle_cards_with_status_icons", 12)
	main._on_unit_clicked("enemy", 0)
	await _shot("battle_enemy_details_with_status_icons", 12)
	main._on_unit_clicked("hero", 0)
	await _shot("battle_hero_details_bloodboost_eye", 6)
	await _shot("battle_hero_details_bloodboost_eye_next_frame", 4)
	main._on_unit_clicked("none", 0)
	player.bloodmoon_stacks = 0
	player.bloodmoon_debuffed = true
	main._refresh_battle_display()
	await _shot("battle_hero_bloodcrash", 12)
	print("DONE: %d screenshots in %s" % [count, out_dir])
	quit()
